"""Export the (frozen) backbone of the CTC model as a Paddle inference model, for paddle2onnx.

usage: export_backbone.py <PaddleOCR dir> <init.pdparams> <n classes> <out prefix>
"""

import sys

paddle_ocr, params, n_classes, out_prefix = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
sys.path.insert(0, paddle_ocr)
import paddle
from ppocr.modeling.architectures import build_model

cfg = {
    "model_type": "rec", "algorithm": "SVTR_LCNet", "Transform": None,
    "Backbone": {"name": "PPLCNetV3", "scale": 0.95},
    "Neck": {"name": "SequenceEncoder", "encoder_type": "svtr", "dims": 120, "depth": 2,
             "hidden_dims": 120, "kernel_size": [1, 3], "use_guide": True},
    "Head": {"name": "CTCHead", "fc_decay": 1e-5, "out_channels": n_classes},
}  # fmt: skip
model = build_model(cfg)
model.set_state_dict(paddle.load(params))
model.eval()
spec = [paddle.static.InputSpec([None, 3, 48, 320], "float32", "x")]
paddle.jit.save(model.backbone, out_prefix, input_spec=spec)
