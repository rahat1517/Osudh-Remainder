"""Backbone features for every line image, computed once with ONNX Runtime (float16 memmap)."""

import math
import sys
import time

import numpy as np
import onnxruntime as ort
from PIL import Image

onnx_path, label_file, out_prefix = sys.argv[1:4]
H, W = 48, 320
items = [l.rstrip("\n").split("\t", 1) for l in open(label_file, encoding="utf-8")]
items = [(p, t) for p, t in items if len(t) <= 25]


def to_array(path):
    img = Image.open(path).convert("RGB")
    w = min(W, max(8, math.ceil(H * img.width / img.height)))
    a = (np.asarray(img.resize((w, H), Image.BILINEAR), np.float32)[:, :, ::-1] / 255.0 - 0.5) / 0.5
    out = np.zeros((3, H, W), np.float32)
    out[:, :, :w] = a.transpose(2, 0, 1)
    return out


opts = ort.SessionOptions()
opts.intra_op_num_threads = 4
s = ort.InferenceSession(onnx_path, opts, providers=["CPUExecutionProvider"])
feats = np.lib.format.open_memmap(out_prefix + ".npy", "w+", np.float16, (len(items), 480, 40))
t0 = time.time()
for i in range(0, len(items), 64):
    batch = np.stack([to_array(p) for p, _ in items[i : i + 64]])
    feats[i : i + len(batch)] = s.run(None, {"x": batch})[0][:, :, 0, :].astype(np.float16)
    if i % 1280 == 0:
        print(f"{i}/{len(items)} {time.time() - t0:.0f}s", flush=True)
feats.flush()
open(out_prefix + ".txt", "w", encoding="utf-8").write("".join(t + "\n" for _, t in items))
print("done", len(items), flush=True)
