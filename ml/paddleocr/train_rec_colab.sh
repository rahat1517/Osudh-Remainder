#!/usr/bin/env bash
# Fine-tunes PaddleOCR's English PP-OCRv4 recognition model on prescription lines (Latin + Bangla),
# then exports it to ONNX for the backend. Run on a GPU machine, e.g. a free Google Colab GPU:
#
#   !git clone https://github.com/rahat1517/Osudh-Remainder && cd Osudh-Remainder/ml
#   !bash paddleocr/train_rec_colab.sh data/rec-v1 data/synth
#
# Inputs (PaddleOCR recognition format, made by oshudh_ml.export_rec and oshudh_ml.synth_rec):
#   <dir>/images/*.jpg, <dir>/train.txt, <dir>/val.txt   ("images/x.jpg<TAB>text" per line)
# Output: out/rec.onnx and out/dict.txt → copy to backend/models/ (see backend/models/README.md).
set -euo pipefail

DATA_DIRS=("$@")
[ ${#DATA_DIRS[@]} -ge 1 ] || { echo "usage: $0 <dataset dir>..." >&2; exit 2; }
EPOCHS=${EPOCHS:-30}
WORK=${WORK:-work}
OUT=${OUT:-out}
mkdir -p "$WORK" "$OUT"
WORK=$(realpath "$WORK"); OUT=$(realpath "$OUT")

# 1. A Python 3.11 environment of its own: PaddlePaddle 2.6 has no build for newer Pythons, and
#    Colab moves on (it ships Python 3.13 now). uv downloads that Python in seconds.
pip install -q uv
VENV="$WORK/py311"
[ -x "$VENV/bin/python" ] || uv venv -q --python 3.11 "$VENV"
PY="$VENV/bin/python"
PIP=(uv pip install -q --python "$PY")
# PaddlePaddle 2.6 is built against NumPy 1.x and dlopens cuDNN 8, which newer Colab images lack:
# install both into the environment and put cuDNN on the library path
# setuptools: PaddlePaddle imports it at start-up, and uv environments do not include it
"${PIP[@]}" "numpy<2" "paddlepaddle-gpu==2.6.2" paddle2onnx==1.3.1 "nvidia-cudnn-cu12==8.9.7.29" setuptools
CUDNN_LIB=$("$PY" -c "import nvidia.cudnn, os; print(os.path.join(nvidia.cudnn.__path__[0], 'lib'))")
export LD_LIBRARY_PATH="$CUDNN_LIB:${LD_LIBRARY_PATH:-}"
[ -d "$WORK/PaddleOCR" ] || git clone -q --depth 1 -b release/2.9 https://github.com/PaddlePaddle/PaddleOCR "$WORK/PaddleOCR"
"${PIP[@]}" -r "$WORK/PaddleOCR/requirements.txt" "numpy<2"
# Fail in the first minutes, with a clear message, if PaddlePaddle cannot use the GPU
"$PY" -c "import paddle; assert paddle.device.is_compiled_with_cuda(), 'PaddlePaddle without CUDA'; paddle.utils.run_check()"

# 2. Merge datasets (absolute image paths) and build the character dictionary: the pretrained
#    English characters first, in their order, then the new ones (Bangla...) found in the labels
TRAIN="$WORK/train.txt"; VAL="$WORK/val.txt"; : > "$TRAIN"; : > "$VAL"
for d in "${DATA_DIRS[@]}"; do
  abs=$(cd "$d" && pwd)
  sed "s#^#$abs/#" "$d/train.txt" >> "$TRAIN"
  [ -f "$d/val.txt" ] && sed "s#^#$abs/#" "$d/val.txt" >> "$VAL"
done
EN_DICT="$WORK/PaddleOCR/ppocr/utils/en_dict.txt"
"$PY" - "$TRAIN" "$VAL" "$EN_DICT" "$OUT/dict.txt" <<'PY'
import sys
train, val, en_dict, out = sys.argv[1:5]
chars = set()
for path in (train, val):
    for line in open(path, encoding="utf-8"):
        chars.update(line.rstrip("\n").split("\t", 1)[1])
chars.discard(" ")
english = [c for c in open(en_dict, encoding="utf-8").read().splitlines() if c != " "]
new = sorted(chars - set(english))
open(out, "w", encoding="utf-8").write("\n".join(english + new) + "\n")
print(f"{len(english)} English + {len(new)} new characters: {''.join(new)}")
PY

# 3. Start from the pretrained English model and fine-tune
cd "$WORK"
[ -d en_PP-OCRv4_rec_train ] || {
  wget -q https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_train.tar
  tar xf en_PP-OCRv4_rec_train.tar
}
cd PaddleOCR
# The larger character list changes the shape of the output layers, and PaddleOCR would drop their
# pretrained weights and start them from random: the model would first forget all English. Copy
# each known character's weights to its new position instead; only new characters start fresh.
"$PY" - "$EN_DICT" "$OUT/dict.txt" "$WORK/en_PP-OCRv4_rec_train/best_accuracy" "$WORK/init" <<'PY'
import sys
import numpy as np
import paddle
sys.path.insert(0, ".")
from ppocr.data.imaug.label_ops import NRTRLabelEncode
from ppocr.postprocess.rec_postprocess import CTCLabelDecode

old_dict, new_dict, src, dst = sys.argv[1:5]
vocab = {
    "ctc": (CTCLabelDecode(old_dict, use_space_char=True).character,
            CTCLabelDecode(new_dict, use_space_char=True).character),
    "gtc": (NRTRLabelEncode(25, old_dict, use_space_char=True).character,
            NRTRLabelEncode(25, new_dict, use_space_char=True).character),
}
state = paddle.load(src + ".pdparams")
rng = np.random.default_rng(0)
for key, head, axis in [
    ("head.ctc_head.fc.weight", "ctc", 1),
    ("head.ctc_head.fc.bias", "ctc", 0),
    ("head.gtc_head.embedding.embedding.weight", "gtc", 0),
    ("head.gtc_head.tgt_word_prj.weight", "gtc", 1),
]:
    old, new = vocab[head]
    t = state[key].numpy()
    if t.shape[axis] == len(old) + 1:  # NRTR has one more token after the characters
        old, new = old + ["<extra>"], new + ["<extra>"]
    shape = list(t.shape)
    shape[axis] = len(new)
    if t.ndim > 1:
        out = rng.normal(0, float(t.std()), shape).astype(t.dtype)
    else:
        out = np.full(shape, t.mean(), t.dtype)
    index = {c: i for i, c in enumerate(old)}
    for j, c in enumerate(new):
        if c in index:
            if axis == 0:
                out[j] = t[index[c]]
            else:
                out[:, j] = t[:, index[c]]
    state[key] = paddle.to_tensor(out)
paddle.save(state, dst + ".pdparams")
print("pretrained weights kept for", sum(c in vocab["ctc"][0] for c in vocab["ctc"][1]), "characters")
PY
"$PY" tools/train.py -c configs/rec/PP-OCRv4/en_PP-OCRv4_rec.yml -o \
  Global.pretrained_model="$WORK/init" \
  Global.character_dict_path="$OUT/dict.txt" \
  Global.use_space_char=true \
  Global.epoch_num="$EPOCHS" \
  Global.save_model_dir="$WORK/rec_output" \
  Train.dataset.data_dir=/ Train.dataset.label_file_list="[$TRAIN]" \
  Eval.dataset.data_dir=/ Eval.dataset.label_file_list="[$VAL]"

# 4. Export the best checkpoint and convert it to ONNX (what the backend's RapidOCR loads)
"$PY" tools/export_model.py -c configs/rec/PP-OCRv4/en_PP-OCRv4_rec.yml -o \
  Global.pretrained_model="$WORK/rec_output/best_accuracy" \
  Global.character_dict_path="$OUT/dict.txt" \
  Global.use_space_char=true \
  Global.save_inference_dir="$WORK/rec_inference"
"$VENV/bin/paddle2onnx" --model_dir "$WORK/rec_inference" --model_filename inference.pdmodel \
  --params_filename inference.pdiparams --save_file "$OUT/rec.onnx" --opset_version 11
echo "Done: $OUT/rec.onnx and $OUT/dict.txt"
