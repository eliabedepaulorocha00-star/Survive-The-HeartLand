#!/usr/bin/env python3
"""Gera os pesos de skinning do modelo apocalypse_survivor.glb (sem Blender).
Lê as posições do GLB, leva para o espaço do jogo (olha para -Z, 1,75 m, pés em y=0)
e escreve scripts/world/survivor_skin_data.gd (base64). Os ossos precisam bater com
BONES em scripts/world/survivor_model.gd."""
import json, struct, base64, sys
import numpy as np

SRC = "assets/models/apocalypse_survivor.glb"
OUT = "scripts/world/survivor_skin_data.gd"
Q = 2048.0  # quantização das posições originais (chave de busca no jogo)

f = open(SRC, "rb").read()
jl = struct.unpack("<I", f[12:16])[0]
j = json.loads(f[20:20 + jl])
binb = f[20 + jl + 8:]
acc = j["accessors"][j["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
bv = j["bufferViews"][acc["bufferView"]]
P = np.frombuffer(binb, dtype="<f4", count=acc["count"] * 3, offset=bv.get("byteOffset", 0) + acc.get("byteOffset", 0)).reshape(-1, 3).astype(np.float64)

# Espaço do jogo: modelo olha para +X, braços em Z; gira 90° em Y, escala 1,75, pés no chão
x, y, z = P[:, 0], P[:, 1], P[:, 2]
gx = z * 1.75
gy = (y + 0.5) * 1.75
gz = -x * 1.75

def sstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

# Índices dos ossos (iguais aos de survivor_model.gd)
ROOT, CHEST, NECK, HEAD = 0, 1, 2, 3
R_UP, R_FORE, R_HAND, L_UP, L_FORE, L_HAND = 4, 5, 6, 7, 8, 9
R_THIGH, R_SHIN, R_FOOT, L_THIGH, L_SHIN, L_FOOT = 10, 11, 12, 13, 14, 15
N = len(P)
W = np.zeros((N, 16))
ax = np.abs(gx)
side_r = sstep(-0.04, 0.04, gx)  # 1 = lado +X

# Região do braço
arm = sstep(0.20, 0.27, ax) * sstep(1.12, 1.24, gy) * (1.0 - sstep(1.56, 1.64, gy))
fore = sstep(0.47, 0.58, ax)
hand = sstep(0.70, 0.80, ax)
upper_w = arm * (1 - fore)
fore_w = arm * fore * (1 - hand)
hand_w = arm * fore * hand
for s_r, (u, fo, h) in ((side_r, (R_UP, R_FORE, R_HAND)), (1 - side_r, (L_UP, L_FORE, L_HAND))):
    W[:, u] += upper_w * s_r
    W[:, fo] += fore_w * s_r
    W[:, h] += hand_w * s_r
rest = 1.0 - arm

# Pernas
leg = sstep(0.98, 0.84, gy)
shin = sstep(0.53, 0.42, gy)
foot = sstep(0.17, 0.09, gy)
for s_r, (t, sh, ft) in ((side_r, (R_THIGH, R_SHIN, R_FOOT)), (1 - side_r, (L_THIGH, L_SHIN, L_FOOT))):
    lw = rest * leg * s_r
    W[:, t] += lw * (1 - shin)
    W[:, sh] += lw * shin * (1 - foot)
    W[:, ft] += lw * shin * foot
trunk = rest * (1.0 - leg)
# Tronco: quadril -> peito -> cabeça (pescoço fica entre os dois)
hips_w = 1.0 - sstep(0.88, 1.08, gy)
head_w = sstep(1.50, 1.66, gy)
W[:, ROOT] += trunk * hips_w
W[:, HEAD] += trunk * (1 - hips_w) * head_w
W[:, CHEST] += trunk * (1 - hips_w) * (1 - head_w)

# Normaliza e fica com as 4 maiores influências
top = np.argsort(-W, axis=1)[:, :4]
tw = np.take_along_axis(W, top, axis=1)
s = tw.sum(axis=1, keepdims=True)
s[s == 0] = 1
tw = tw / s
tw8 = np.round(tw * 255).astype(int)
tw8[:, 0] += 255 - tw8.sum(axis=1)  # soma exata 255

entries = {}
for i in range(N):
    key = (int(round(x[i] * Q)), int(round(y[i] * Q)), int(round(z[i] * Q)))
    entries[key] = (top[i], tw8[i])
out = bytearray(struct.pack("<I", len(entries)))
for (qx, qy, qz), (b, w) in entries.items():
    out += struct.pack("<hhh4B4B", qx, qy, qz, *[int(v) for v in b], *[int(v) for v in w])
b64 = base64.b64encode(bytes(out)).decode()
open(OUT, "w").write("extends RefCounted\n## GERADO por tools/make_skin.py - não edite à mão.\n\nconst COUNT := %d\nconst DATA := \"%s\"\n" % (len(entries), b64))
print("vertices", N, "unicos", len(entries), "bytes", len(out))
