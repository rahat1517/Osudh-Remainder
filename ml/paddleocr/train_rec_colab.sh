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
"${PIP[@]}" "numpy<2" "paddlepaddle-gpu==2.6.2" paddle2onnx==1.3.1 "nvidia-cudnn-cu12==8.9.7.29"
CUDNN_LIB=$("$PY" -c "import nvidia.cudnn, os; print(os.path.join(nvidia.cudnn.__path__[0], 'lib'))")
export LD_LIBRARY_PATH="$CUDNN_LIB:${LD_LIBRARY_PATH:-}"
[ -d "$WORK/PaddleOCR" ] || git clone -q --depth 1 -b release/2.9 https://github.com/PaddlePaddle/PaddleOCR "$WORK/PaddleOCR"
"${PIP[@]}" -r "$WORK/PaddleOCR/requirements.txt" "numpy<2"
# Fail in the first minutes, with a clear message, if PaddlePaddle cannot use the GPU
"$PY" -c "import paddle; assert paddle.device.is_compiled_with_cuda(), 'PaddlePaddle without CUDA'; paddle.utils.run_check()"

# 2. Merge datasets (absolute image paths) and build the character dictionary from all labels
TRAIN="$WORK/train.txt"; VAL="$WORK/val.txt"; : > "$TRAIN"; : > "$VAL"
for d in "${DATA_DIRS[@]}"; do
  abs=$(cd "$d" && pwd)
  sed "s#^#$abs/#" "$d/train.txt" >> "$TRAIN"
  [ -f "$d/val.txt" ] && sed "s#^#$abs/#" "$d/val.txt" >> "$VAL"
done
"$PY" - "$TRAIN" "$VAL" "$OUT/dict.txt" <<'PY'
import sys
chars = set()
for path in sys.argv[1:3]:
    for line in open(path, encoding="utf-8"):
        chars.update(line.rstrip("\n").split("\t", 1)[1])
chars.discard(" ")
open(sys.argv[3], "w", encoding="utf-8").write("\n".join(sorted(chars)) + "\n")
print(f"{len(chars)} characters")
PY

# 3. Start from the pretrained English model and fine-tune
cd "$WORK"
[ -d en_PP-OCRv4_rec_train ] || {
  wget -q https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_train.tar
  tar xf en_PP-OCRv4_rec_train.tar
}
cd PaddleOCR
"$PY" tools/train.py -c configs/rec/PP-OCRv4/en_PP-OCRv4_rec.yml -o \
  Global.pretrained_model="$WORK/en_PP-OCRv4_rec_train/best_accuracy" \
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
