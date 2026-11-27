"""Builds train_bangla_ocr_colab.ipynb: a self-contained Colab notebook (the repository is private,
so the notebook carries the synthetic-data generator and the training script inside it).

    python ml/paddleocr/make_colab_notebook.py
"""

import json
from pathlib import Path

HERE = Path(__file__).parent
SYNTH = (HERE.parent / "oshudh_ml" / "synth_rec.py").read_text(encoding="utf-8")
TRAIN = (HERE / "train_rec_colab.sh").read_text(encoding="utf-8")

# Google Fonts paths (ofl/ or apache/ is tried in turn)
FONTS = {
    # Bangla
    "NotoSansBengali.ttf": "notosansbengali/NotoSansBengali%5Bwdth%2Cwght%5D.ttf",
    "NotoSerifBengali.ttf": "notoserifbengali/NotoSerifBengali%5Bwdth%2Cwght%5D.ttf",
    "HindSiliguri-Regular.ttf": "hindsiliguri/HindSiliguri-Regular.ttf",
    "HindSiliguri-Medium.ttf": "hindsiliguri/HindSiliguri-Medium.ttf",
    "HindSiliguri-Bold.ttf": "hindsiliguri/HindSiliguri-Bold.ttf",
    "AnekBangla.ttf": "anekbangla/AnekBangla%5Bwdth%2Cwght%5D.ttf",
    "BalooDa2.ttf": "balooda2/BalooDa2%5Bwght%5D.ttf",
    "Galada-Regular.ttf": "galada/Galada-Regular.ttf",
    "Mina-Regular.ttf": "mina/Mina-Regular.ttf",
    "TiroBangla-Regular.ttf": "tirobangla/TiroBangla-Regular.ttf",
    # Latin handwriting: doctors write medicine names, strengths and doses by hand
    "Caveat.ttf": "caveat/Caveat%5Bwght%5D.ttf",
    "IndieFlower.ttf": "indieflower/IndieFlower-Regular.ttf",
    "ShadowsIntoLight.ttf": "shadowsintolight/ShadowsIntoLight.ttf",
    "PatrickHand.ttf": "patrickhand/PatrickHand-Regular.ttf",
    "GochiHand.ttf": "gochihand/GochiHand-Regular.ttf",
    "ArchitectsDaughter.ttf": "architectsdaughter/ArchitectsDaughter-Regular.ttf",
    "Handlee.ttf": "handlee/Handlee-Regular.ttf",
    "NanumPen.ttf": "nanumpenscript/NanumPenScript-Regular.ttf",
    "HomemadeApple.ttf": "homemadeapple/HomemadeApple-Regular.ttf",
    "JustAnotherHand.ttf": "justanotherhand/JustAnotherHand-Regular.ttf",
    "Kalam.ttf": "kalam/Kalam-Regular.ttf",
    "Sacramento.ttf": "sacramento/Sacramento-Regular.ttf",
}
# Never trained on: the quick check reads lines in these to see how the model copes with new hands
HOLDOUT_FONTS = {
    "Atma-Regular.ttf": "atma/Atma-Regular.ttf",
    "ReenieBeanie.ttf": "reeniebeanie/ReenieBeanie.ttf",
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


def fonts_literal(fonts: dict[str, str]) -> str:
    return "\n".join(f'    "{name}": "{path}",' for name, path in fonts.items())

cells = [
    md("""
# ওষুধ রিমাইন্ডার: বাংলা ও হাতের লেখা OCR ট্রেনিং (Bangla + handwriting OCR training)

PaddleOCR-এর লেখা-পড়ার মডেলকে বাংলা ডোজ (১+০+১), "খাবারের আগে", "৭ দিন", ওষুধের নাম আর **হাতে লেখা**
প্রেসক্রিপশন পড়তে শেখানো হবে। পুরো মডেল GPU-তে ট্রেন হয়, তাই হাতের লেখায় সার্ভারের CPU-তে
ট্রেন করা মডেলের চেয়ে ভালো হওয়ার কথা।

**কী করবেন**
1. উপরে **Runtime → Change runtime type → T4 GPU** বেছে **Save**। (নিচে ডানে "T4" লেখা থাকতে হবে।)
2. **Runtime → Run all**।
3. প্রথম ঘরে Google Drive-এর অনুমতি চাইবে: **Connect / Allow** দিন। মডেলটি Drive-এ সেভ হবে, তাই
   Colab বন্ধ হয়ে গেলেও হারাবে না।
4. প্রায় ২ ঘণ্টা ট্যাবটি খোলা রাখুন। শেষে `oshudh_ocr_model.zip` ডাউনলোড হবে, আর Drive-এর
   **My Drive**-এও থাকবে। ফাইলটি Claude-কে পাঠান।

Steps: GPU runtime → Run all → allow Google Drive → keep the tab open (~2 h) → send
`oshudh_ocr_model.zip` (downloaded, and saved in My Drive). No real patient data is used: the
training images are generated.
"""),
    md("## 1. GPU আর Google Drive (Check the GPU, connect Drive)"),
    code("""
import subprocess
gpu = subprocess.run(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"],
                     capture_output=True, text=True).stdout.strip()
assert gpu, "GPU নেই: Runtime → Change runtime type → T4 GPU → Save, তারপর আবার Run all"
print("GPU:", gpu)
# The trained model is copied to Drive at the end, so it survives the Colab session ending
from google.colab import drive
drive.mount("/content/drive")
"""),
    md("## 2. দরকারি জিনিস ইনস্টল (Install tools)"),
    code("""
!apt-get -qq install -y libraqm0 libfribidi0 zip > /dev/null
!pip -q install --upgrade pillow fonttools
import PIL, importlib; importlib.reload(PIL)
from PIL import features
print("Bangla text shaping (raqm):", features.check("raqm"))
"""),
    md("## 3. ফন্ট ডাউনলোড: বাংলা আর হাতের লেখা (Fonts: Bangla and handwriting)"),
    code(f"""
import os, urllib.request
BASE = "https://raw.githubusercontent.com/google/fonts/main"
def fetch(fonts, folder):
    os.makedirs(folder, exist_ok=True)
    for name, path in fonts.items():
        for licence in ("ofl", "apache"):
            try:
                urllib.request.urlretrieve(f"{{BASE}}/{{licence}}/{{path}}", f"{{folder}}/{{name}}")
                break
            except Exception:
                pass
        else:
            print("skipped", name)
    print(folder, len(os.listdir(folder)), "fonts")
fetch({{
{fonts_literal(FONTS)}
}}, "fonts")
fetch({{
{fonts_literal(HOLDOUT_FONTS)}
}}, "fonts_holdout")
"""),
    md(
        "## 4. প্রশিক্ষণের ছবি তৈরি (Generate training images)\nপ্রেসক্রিপশনের মতো লাইন: ওষুধের নাম, বাংলা ডোজ, সময়, দিন; ছাপা আর হাতের লেখার মতো, ফোনের ছবির মতো ঝাপসা/বাঁকা করে।"
    ),
    code("%%writefile synth_rec.py\n" + SYNTH),
    code("""
COUNT = 50000  # more is better; 50k takes a few minutes
!python synth_rec.py --fonts fonts --out data/synth --count $COUNT
!python synth_rec.py --fonts fonts_holdout --out data/holdout --count 600 --seed 99
!head -5 data/synth/train.txt
"""),
    code("""
# A few samples, to check that Bangla is drawn correctly (joined letters, not boxes)
from IPython.display import display
from PIL import Image
for line in open("data/synth/train.txt", encoding="utf-8").readlines()[:8]:
    path, text = line.rstrip("\\n").split("\\t", 1)
    print(text); display(Image.open(f"data/synth/{path}"))
"""),
    md(
        "## 5. মডেল ট্রেনিং (Train, about 1.5–2 hours on a T4)\nট্যাব খোলা রাখুন। EPOCHS কমালে তাড়াতাড়ি শেষ হবে, তবে কম শিখবে।"
    ),
    code("%%writefile train_rec_colab.sh\n" + TRAIN),
    code("""
!EPOCHS=15 bash train_rec_colab.sh data/synth 2>&1 | grep -vE "^\\s*$" | tail -n 40
"""),
    md("## 6. দ্রুত পরীক্ষা (Quick check on unseen lines and unseen fonts)"),
    code("""
!pip -q install rapidocr-onnxruntime
from rapidocr_onnxruntime import RapidOCR
engine = RapidOCR(rec_model_path="out/rec.onnx", rec_keys_path="out/dict.txt")
def check(folder, n=300):
    lines = []
    for name in ("val.txt", "train.txt"):
        if os.path.exists(f"{folder}/{name}"):
            lines += open(f"{folder}/{name}", encoding="utf-8").read().splitlines()
    lines = lines[:n]
    right = 0
    for line in lines:
        path, truth = line.split("\\t", 1)
        result, _ = engine(f"{folder}/{path}", use_det=False, use_cls=False, use_rec=True)
        text = result[0][0] if result else ""
        right += text.replace(" ", "") == truth.replace(" ", "")
    print(f"{folder}: exact lines {right}/{len(lines)} = {right/len(lines):.0%}")
check("data/synth")
check("data/holdout")  # fonts never trained on, incl. a handwriting one
"""),
    md("## 7. সেভ আর ডাউনলোড (Save to Drive, download, send to Claude)"),
    code("""
import shutil
!cd out && zip -q ../oshudh_ocr_model.zip rec.onnx dict.txt && ls -la ../oshudh_ocr_model.zip
shutil.copy("oshudh_ocr_model.zip", "/content/drive/MyDrive/oshudh_ocr_model.zip")
print("Saved in Google Drive: My Drive / oshudh_ocr_model.zip")
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
