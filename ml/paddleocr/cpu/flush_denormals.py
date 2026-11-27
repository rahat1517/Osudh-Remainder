"""Set denormal (tiny, < 1e-30) weights of an ONNX model to zero.

The pretrained English PP-OCRv4 weights contain ~25k denormal floats. CPUs compute with them
very slowly: the convolutions ran 5x slower than the stock model's, for identical results.
"""

import sys

import numpy as np
import onnx
from onnx import numpy_helper

src, dst = sys.argv[1:3]
model = onnx.load(src)
flushed = 0
tensors = list(model.graph.initializer)
tensors += [
    a.t
    for n in model.graph.node
    if n.op_type == "Constant"
    for a in n.attribute
    if a.name == "value"
]
for t in tensors:
    w = numpy_helper.to_array(t)
    if w.dtype == np.float32:
        tiny = (w != 0) & (np.abs(w) < 1e-30)
        if tiny.any():
            flushed += int(tiny.sum())
            t.CopyFrom(numpy_helper.from_array(np.where(tiny, 0, w).astype(np.float32), t.name))
onnx.save(model, dst)
print(f"{flushed} denormal weights set to zero → {dst}")
