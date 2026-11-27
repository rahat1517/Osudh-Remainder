#!/usr/bin/env bash
# Fine-tunes PaddleOCR's English PP-OCRv4 recognition model for Bangla prescription lines on a CPU
# (no GPU needed; about 1.5 hours for ~35k lines on 4 cores). Used for backend/models/rec.onnx.
#
#   bash paddleocr/cpu/train_rec_cpu.sh data/synth data/synth2 [more dataset dirs]
#
# PaddlePaddle trains very slowly on a CPU, so the backbone stays frozen: its features are computed
# once with ONNX Runtime, then only the sequence neck and CTC head are trained (minutes per epoch).
# Each dataset dir is in PaddleOCR recognition format (images/, train.txt, val.txt), as made by
# oshudh_ml.synth_rec and oshudh_ml.export_rec. HOLDOUT=<dir> adds an extra validation set (e.g. a
# font kept out of training). Output: out/rec.onnx and out/dict.txt.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
DATA_DIRS=("$@")
[ ${#DATA_DIRS[@]} -ge 1 ] || { echo "usage: $0 <dataset dir>..." >&2; exit 2; }
EPOCHS=${EPOCHS:-12}
WORK=$(realpath -m "${WORK:-work-cpu}"); OUT=$(realpath -m "${OUT:-out}")
mkdir -p "$WORK/cache" "$OUT"

# 1. Python 3.11 with the CPU build of PaddlePaddle 2.6 (no build for newer Pythons) and PaddleOCR 2.9
command -v uv >/dev/null || pip install -q uv
[ -x "$WORK/py311/bin/python" ] || uv venv -q --python 3.11 "$WORK/py311"
PY="$WORK/py311/bin/python"
uv pip install -q --python "$PY" "numpy<2" paddlepaddle==2.6.2 paddle2onnx==1.3.1 setuptools \
  onnx onnxruntime pillow
[ -d "$WORK/PaddleOCR" ] || git clone -q --depth 1 -b release/2.9 https://github.com/PaddlePaddle/PaddleOCR "$WORK/PaddleOCR"
uv pip install -q --python "$PY" -r "$WORK/PaddleOCR/requirements.txt" "numpy<2"

# 2. Pretrained English model (resumable: the server sometimes drops long downloads)
TAR="$WORK/en_PP-OCRv4_rec_train.tar"
if [ ! -d "$WORK/en_PP-OCRv4_rec_train" ]; then
  for _ in $(seq 1 20); do
    curl -sS -m 300 -C - -o "$TAR" https://paddleocr.bj.bcebos.com/PP-OCRv4/english/en_PP-OCRv4_rec_train.tar && break
    sleep 3
  done
  tar xf "$TAR" -C "$WORK"
fi

# 3. Labels with absolute paths; dictionary = English + Bangla, keeping the English head weights
: > "$WORK/train.txt"; : > "$WORK/val.txt"
for d in "${DATA_DIRS[@]}"; do
  abs=$(cd "$d" && pwd)
  sed "s#^#$abs/#" "$d/train.txt" >> "$WORK/train.txt"
  [ -f "$d/val.txt" ] && sed "s#^#$abs/#" "$d/val.txt" >> "$WORK/val.txt"
done
VALS="$WORK/cache/val"
if [ -n "${HOLDOUT:-}" ]; then
  abs=$(cd "$HOLDOUT" && pwd)
  cat "$HOLDOUT"/train.txt "$HOLDOUT"/val.txt 2>/dev/null | sed "s#^#$abs/#" > "$WORK/holdout.txt"
  VALS="$VALS,$WORK/cache/holdout"
fi
"$PY" -I "$HERE/extend_head.py" "$WORK/PaddleOCR/ppocr/utils/en_dict.txt" \
  "$WORK/en_PP-OCRv4_rec_train/best_accuracy.pdparams" "$WORK/train.txt,$WORK/val.txt" \
  "$OUT/dict.txt" "$WORK/init.pdparams"
CLASSES=$(( $(grep -c . "$OUT/dict.txt") + 2 ))  # + CTC blank + space

# 4. Frozen backbone → ONNX, then its features for every image
"$PY" -I "$HERE/export_backbone.py" "$WORK/PaddleOCR" "$WORK/init.pdparams" "$CLASSES" "$WORK/backbone/inference"
"$WORK/py311/bin/paddle2onnx" --model_dir "$WORK/backbone" --model_filename inference.pdmodel \
  --params_filename inference.pdiparams --save_file "$WORK/backbone.onnx" --opset_version 11
"$PY" -I "$HERE/flush_denormals.py" "$WORK/backbone.onnx" "$WORK/backbone.onnx"
for part in train val holdout; do
  [ -f "$WORK/$part.txt" ] || continue
  "$PY" -I "$HERE/cache_feats.py" "$WORK/backbone.onnx" "$WORK/$part.txt" "$WORK/cache/$part"
done

# 5. Train the neck and head, then export the whole model to ONNX
"$PY" -I "$HERE/train_head.py" "$WORK/PaddleOCR" "$OUT/dict.txt" "$WORK/init.pdparams" \
  "$WORK/cache/train" "$VALS" "$WORK/best.pdparams" "$EPOCHS"
(cd "$WORK/PaddleOCR" && "$PY" tools/export_model.py -c "$HERE/rec_ctc.yml" -o \
  Global.pretrained_model="$WORK/best" Global.character_dict_path="$OUT/dict.txt" \
  Global.save_inference_dir="$WORK/inference")
"$WORK/py311/bin/paddle2onnx" --model_dir "$WORK/inference" --model_filename inference.pdmodel \
  --params_filename inference.pdiparams --save_file "$OUT/rec.onnx" --opset_version 11
"$PY" -I "$HERE/flush_denormals.py" "$OUT/rec.onnx" "$OUT/rec.onnx"
echo "Done: $OUT/rec.onnx and $OUT/dict.txt. Run the eval gate before using it (backend/models/README.md)."
