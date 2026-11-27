"""Builds train_bangla_ocr_colab.ipynb: a self-contained Colab notebook (the repository is private,
so the notebook carries the synthetic-data generator and the training script inside it).

    python ml/paddleocr/make_colab_notebook.py
"""

import json
from pathlib import Path

HERE = Path(__file__).parent
SYNTH = (HERE.parent / "oshudh_ml" / "synth_rec.py").read_text(encoding="utf-8")
TRAIN = (HERE / "train_rec_colab.sh").read_text(encoding="utf-8")

FONTS = {
    "NotoSansBengali.ttf": "notosansbengali/NotoSansBengali%5Bwdth%2Cwght%5D.ttf",
    "NotoSerifBengali.ttf": "notoserifbengali/NotoSerifBengali%5Bwdth%2Cwght%5D.ttf",
    "HindSiliguri-Regular.ttf": "hindsiliguri/HindSiliguri-Regular.ttf",
    "HindSiliguri-Medium.ttf": "hindsiliguri/HindSiliguri-Medium.ttf",
    "BalooDa2.ttf": "balooda2/BalooDa2%5Bwght%5D.ttf",
    "Galada-Regular.ttf": "galada/Galada-Regular.ttf",
    "Mina-Regular.ttf": "mina/Mina-Regular.ttf",
    "TiroBangla-Regular.ttf": "tirobangla/TiroBangla-Regular.ttf",
}


def md(text: str) -> dict:
    return {"cell_type": "markdown", "metadata": {}, "source": text.strip("\n").splitlines(True)}


def code(text: str) -> dict:
    return {
        "cell_type": "code",
        "metadata": {},
        "execution_count": None,
        "outputs": [],
        "source": text.strip("\n").splitlines(True),
    }


fonts_py = "\n".join(
    f'    "{name}": "https://raw.githubusercontent.com/google/fonts/main/ofl/{path}",'
    for name, path in FONTS.items()
)

cells = [
    md("""
# ওষুধ রিমাইন্ডার: বাংলা OCR ট্রেনিং (Bangla OCR training)

PaddleOCR-এর লেখা-পড়ার মডেলকে বাংলা ডোজ (১+০+১), "খাবারের আগে", "৭ দিন" আর ওষুধের নাম পড়তে শেখানো হবে।

**কী করবেন**
1. উপরে **Runtime → Change runtime type → T4 GPU** বেছে **Save**।
2. **Runtime → Run all**।
3. প্রায় ১–২ ঘণ্টা পরে শেষ ঘরে `oshudh_ocr_model.zip` ডাউনলোড হবে। ফাইলটি Claude-কে পাঠান।

Steps: GPU runtime → Run all → send the downloaded `oshudh_ocr_model.zip` back.
Nothing here uses real patient data: the training images are generated.
"""),
    md("## 1. GPU আছে কিনা দেখা (Check the GPU)"),
    code("""
!nvidia-smi --query-gpu=name,memory.total --format=csv || echo "No GPU: Runtime > Change runtime type > T4 GPU"
"""),
    md("## 2. দরকারি জিনিস ইনস্টল (Install tools)"),
    code("""
!apt-get -qq install -y libraqm0 libfribidi0 > /dev/null
!pip -q install --upgrade pillow fonttools
import PIL, importlib; importlib.reload(PIL)
from PIL import features
print("Bangla text shaping (raqm):", features.check("raqm"))
"""),
    md("## 3. বাংলা ফন্ট ডাউনলোড (Bangla fonts)"),
    code(f"""
import os, urllib.request
os.makedirs("fonts", exist_ok=True)
FONTS = {{
{fonts_py}
}}
for name, url in FONTS.items():
    try:
        urllib.request.urlretrieve(url, f"fonts/{{name}}")
        print("ok", name)
    except Exception as e:
        print("skipped", name, e)
"""),
    md(
        "## 4. প্রশিক্ষণের ছবি তৈরি (Generate training images)\nপ্রেসক্রিপশনের মতো লাইন: ওষুধের নাম, বাংলা ডোজ, সময়, দিন; ফোনের ছবির মতো ঝাপসা/বাঁকা করে।"
    ),
    code("%%writefile synth_rec.py\n" + SYNTH),
    code("""
COUNT = 40000  # more is better; 40k takes a few minutes
!python synth_rec.py --fonts fonts --out data/synth --count $COUNT
!head -5 data/synth/train.txt
"""),
    code("""
# A few samples, to check that Bangla is drawn correctly (joined letters, not boxes)
from IPython.display import display
from PIL import Image
for line in open("data/synth/train.txt", encoding="utf-8").readlines()[:6]:
    path, text = line.rstrip("\\n").split("\\t", 1)
    print(text); display(Image.open(f"data/synth/{path}"))
"""),
    md(
        "## 5. মডেল ট্রেনিং (Train, about 1–2 hours on a T4)\nEPOCHS কমালে তাড়াতাড়ি শেষ হবে, তবে কম শিখবে।"
    ),
    code("%%writefile train_rec_colab.sh\n" + TRAIN),
    code("""
!EPOCHS=15 bash train_rec_colab.sh data/synth 2>&1 | grep -vE "^\\s*$" | tail -n 40
"""),
    md("## 6. দ্রুত পরীক্ষা (Quick check on unseen lines)"),
    code("""
!pip -q install rapidocr-onnxruntime
from rapidocr_onnxruntime import RapidOCR
engine = RapidOCR(rec_model_path="out/rec.onnx", rec_keys_path="out/dict.txt")
lines = open("data/synth/val.txt", encoding="utf-8").read().splitlines()[:200]
right = 0
for line in lines:
    path, truth = line.split("\\t", 1)
    result, _ = engine(f"data/synth/{path}", use_det=False, use_cls=False, use_rec=True)
    text = result[0][0] if result else ""
    right += text.replace(" ", "") == truth.replace(" ", "")
print(f"exact lines: {right}/{len(lines)} = {right/len(lines):.0%}")
"""),
    md("## 7. ডাউনলোড (Download the model and send it to Claude)"),
    code("""
!cd out && zip -q ../oshudh_ocr_model.zip rec.onnx dict.txt && ls -la ../oshudh_ocr_model.zip
from google.colab import files
files.download("oshudh_ocr_model.zip")
"""),
]

notebook = {
    "cells": cells,
    "metadata": {
        "accelerator": "GPU",
        "colab": {"gpuType": "T4", "provenance": []},
        "kernelspec": {"display_name": "Python 3", "name": "python3"},
        "language_info": {"name": "python"},
    },
    "nbformat": 4,
    "nbformat_minor": 0,
}
out = HERE / "train_bangla_ocr_colab.ipynb"
out.write_text(json.dumps(notebook, ensure_ascii=False, indent=1), encoding="utf-8")
print(f"wrote {out}")
