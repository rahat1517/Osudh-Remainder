"""Extend en_PP-OCRv4's dictionary with Bangla and keep the English CTC head weights.

usage: extend_head.py <en_dict.txt> <pretrained.pdparams> <labels,> <out dict.txt> <out.pdparams>

The new dictionary is the English one followed by every Bangla character (and anything else in the
labels), so the pretrained head's English rows are kept and English reading is not lost. The
weights are written for a CTC-only model (backbone, neck, head), as train_head.py uses.
"""

import sys
import unicodedata

import numpy as np
import paddle

en_dict, pretrained, labels, out_dict, out_params = sys.argv[1:6]
en = [c for c in open(en_dict, encoding="utf-8").read().split("\n") if c]
chars = set()
for f in labels.split(","):
    for l in open(f, encoding="utf-8"):
        chars.update(l.rstrip("\n").split("\t", 1)[1])
chars.discard(" ")
bn = [chr(c) for c in range(0x0980, 0x0A00) if unicodedata.category(chr(c)) != "Cn"]
new = sorted((chars | set(bn)) - set(en))
open(out_dict, "w", encoding="utf-8").write("\n".join(en + new) + "\n")
s = paddle.load(pretrained)
w = s["head.ctc_head.fc.weight"].numpy()
b = s["head.ctc_head.fc.bias"].numpy()
n = len(new)
rng = np.random.default_rng(0)
# CTC classes: blank, dict..., space
s["head.ctc_head.fc.weight"] = paddle.to_tensor(
    np.concatenate([w[:, :96], rng.normal(0, 0.02, (w.shape[0], n)).astype(w.dtype), w[:, 96:]], 1)
)
s["head.ctc_head.fc.bias"] = paddle.to_tensor(
    np.concatenate([b[:96], np.full(n, b[1:96].mean(), b.dtype), b[96:]])
)
# CTC-only model: MultiHead's CTC branch becomes the neck and head; the training-only NRTR head goes
out = {}
for k, v in s.items():
    if k.startswith("backbone."):
        out[k] = v
    elif k.startswith("head.ctc_encoder."):
        out["neck." + k.removeprefix("head.ctc_encoder.")] = v
    elif k.startswith("head.ctc_head."):
        out["head." + k.removeprefix("head.ctc_head.")] = v
paddle.save(out, out_params)
print(f"dict {len(en)}+{n}={len(en) + n}; seen in data: {len(chars)}")
