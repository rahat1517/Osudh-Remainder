"""Train the SVTR neck + CTC head of PP-OCRv4 rec on cached (frozen) backbone features.

usage: train_head.py <PaddleOCR dir> <dict> <init.pdparams> <train prefixes,> <val prefixes,> <out.pdparams> [epochs]
Model selection uses the mean accuracy over the val sets.
"""

import sys
import time

import numpy as np

paddle_ocr, dict_path, init, train_sets, val_sets, out = sys.argv[1:7]
EPOCHS = int(sys.argv[7]) if len(sys.argv) > 7 else 30
sys.path.insert(0, paddle_ocr)
import paddle
from ppocr.losses.rec_ctc_loss import CTCLoss
from ppocr.modeling.heads.rec_ctc_head import CTCHead
from ppocr.modeling.necks.rnn import SequenceEncoder

chars = [c for c in open(dict_path, encoding="utf-8").read().split("\n") if c] + [" "]
index = {c: i + 1 for i, c in enumerate(chars)}
T = 25


def load(prefix):
    x = np.load(f"{prefix}.npy", mmap_mode="r")
    texts = open(f"{prefix}.txt", encoding="utf-8").read().split("\n")[: len(x)]
    y = np.zeros((len(texts), T), np.int64)
    n = np.zeros(len(texts), np.int64)
    for i, t in enumerate(texts):
        y[i, : len(t)] = [index[c] for c in t]
        n[i] = len(t)
    return np.asarray(x), y, n, texts


class Net(paddle.nn.Layer):
    def __init__(self):
        super().__init__()
        self.neck = SequenceEncoder(
            480, "svtr", dims=120, depth=2, hidden_dims=120, kernel_size=[1, 3], use_guide=True
        )
        self.head = CTCHead(self.neck.out_channels, len(chars) + 1, fc_decay=1e-5)

    def forward(self, f):
        return self.head(self.neck(f))


net = Net()
state = paddle.load(init)
missing = net.set_state_dict({k: v for k, v in state.items() if k.startswith(("neck.", "head."))})
parts = [load(p) for p in train_sets.split(",")]
xt = np.concatenate([p[0] for p in parts])
yt = np.concatenate([p[1] for p in parts])
nt = np.concatenate([p[2] for p in parts])
vals = {p.rsplit("/", 1)[-1]: load(p) for p in val_sets.split(",")}
print(f"train {len(xt)} val {[len(v[0]) for v in vals.values()]}", flush=True)
BS = 128
steps = EPOCHS * (len(xt) // BS)
lr = paddle.optimizer.lr.LinearWarmup(
    paddle.optimizer.lr.CosineAnnealingDecay(1e-3, steps),
    warmup_steps=300,
    start_lr=0.0,
    end_lr=1e-3,
)
opt = paddle.optimizer.AdamW(lr, parameters=net.parameters(), weight_decay=0.01)
loss_fn = CTCLoss()


def decode(logits):
    res = []
    for seq in logits.argmax(-1).numpy():
        s, prev = [], 0
        for k in seq:
            if k != prev and k:
                s.append(chars[k - 1])
            prev = k
        res.append("".join(s))
    return res


def evaluate(show=0):
    accs = {k: evaluate_one(v[0], v[3], show) for k, v in vals.items()}
    print("   " + " ".join(f"{k}={a:.3f}" for k, a in accs.items()), flush=True)
    return sum(accs.values()) / len(accs)


def evaluate_one(xv, tv, show):
    net.eval()
    right = 0
    preds = []
    with paddle.no_grad():
        for i in range(0, len(xv), 256):
            f = paddle.to_tensor(xv[i : i + 256].astype(np.float32)).unsqueeze(2)
            preds += decode(net(f))
    for p, t in zip(preds, tv):
        right += p.replace(" ", "") == t.replace(" ", "")
    wrong = [(t, p) for p, t in zip(preds, tv) if p.replace(" ", "") != t.replace(" ", "")]
    for t, p in wrong[:show]:
        print(f"   {t!r} -> {p!r}")
    net.train()
    return right / len(tv)


print(f"start: mean acc {evaluate():.3f}", flush=True)
rng = np.random.default_rng(0)
best = -1
t0 = time.time()
step = 0
for epoch in range(EPOCHS):
    order = rng.permutation(len(xt))
    for i in range(0, len(order) - BS + 1, BS):
        b = order[i : i + BS]
        f = xt[b].astype(np.float32)
        # Light feature-level augmentation (the images are fixed once cached)
        f *= rng.uniform(0.9, 1.1, (len(b), 1, 1)).astype(np.float32)
        f += rng.normal(0, 0.05, f.shape).astype(np.float32)
        f *= (rng.random((len(b), f.shape[1], 1)) > 0.1).astype(np.float32) / 0.9
        loss = loss_fn(
            net(paddle.to_tensor(f).unsqueeze(2)),
            [None, paddle.to_tensor(yt[b]), paddle.to_tensor(nt[b])],
        )["loss"]
        loss.backward()
        opt.step()
        opt.clear_grad()
        lr.step()
        step += 1
    acc = evaluate(show=3)
    print(
        f"epoch {epoch + 1}/{EPOCHS} loss {loss.item():.3f} mean acc {acc:.3f} "
        f"({(time.time() - t0) / 60:.1f} min)",
        flush=True,
    )
    if acc > best:
        best = acc
        full = dict(state)
        full.update({k: v for k, v in net.state_dict().items()})
        paddle.save(full, out)
print(f"best mean acc {best:.3f}", flush=True)
