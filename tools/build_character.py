"""Construit assets/character/* (homme jeune, squelette MakeHuman, vêtements).
Source : données MakeHuman (CC0). Usage : python3 tools/build_character.py"""
import sys, os, shutil
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from mh_lib import *
import textures_gen as TG

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "character")
os.makedirs(OUT, exist_ok=True)
HEIGHT_M = 1.80
SHIFT = 0.022  # épaisseur de la semelle : le sol (y=0) est le dessous des baskets

V0, VT, faces = load_obj(MH + "3dobjs/base.obj")
spec = [
    ("macrodetails/universal-male-young-maxmuscle-averageweight.target", 0.38),
    ("macrodetails/caucasian-male-young.target", 1.0),
    ("macrodetails/height/male-young-averagemuscle-averageweight-maxheight.target", 0.35),
]
V = apply_targets(V0, spec)
body_faces = [f for f in faces if f[0] == "body"]
nb = max(v for _, idx in body_faces for v, _ in idx) + 1

sk = load_skeleton()
def jpos(name):
    return V[sk["joints"][name]].mean(axis=0)
bones = sk["bones"]
order = []
def visit(b):
    if b in order:
        return
    p = bones[b]["parent"]
    if p:
        visit(p)
    order.append(b)
for b in sorted(bones):
    visit(b)
bidx = {b: i for i, b in enumerate(order)}

ymin, ymax = V[:nb, 1].min(), V[:nb, 1].max()
S = HEIGHT_M / (ymax - ymin)
def tr(P):
    return (P - np.array([0, ymin, 0])) * S + np.array([0, SHIFT, 0])
Pw = tr(V)
head = {b: tr(jpos(bones[b]["head"])) for b in order}
tail = {b: tr(jpos(bones[b]["tail"])) for b in order}

TV, TT = [], []
for g, idx in body_faces:
    for t in triangulate(idx):
        TV.append([v for v, _ in t]); TT.append([vt for _, vt in t])
TV, TT = np.array(TV), np.array(TT)
Pb = Pw[:nb]
Nb = vertex_normals(Pb, TV)

# --- poids par sommet d'origine
wts = load_weights()
infl = [dict() for _ in range(len(Pw))]
for b, lst in wts.items():
    if b in bidx:
        for v, w in lst:
            infl[v][bidx[b]] = w
Jv = np.zeros((len(Pw), 4), dtype=np.uint16)
Wv = np.zeros((len(Pw), 4), dtype=np.float32)
for v in range(len(Pw)):
    items = sorted(infl[v].items(), key=lambda kv: -kv[1])[:4]
    tot = sum(w for _, w in items) or 1.0
    for k, (b, w) in enumerate(items):
        Jv[v, k] = b; Wv[v, k] = w / tot
    if not items:
        Jv[v, 0] = bidx["root"]; Wv[v, 0] = 1.0

# --------------------------------------------------------------------- utilitaires
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def split_mesh(P, tv, tt, color=None):
    """Sépare les sommets par (v, vt) ; renvoie P,N,UV,J,W,tris,C."""
    vm, src, uvs, tris = {}, [], [], []
    for a, b in zip(tv.reshape(-1), tt.reshape(-1)):
        k = (int(a), int(b))
        if k not in vm:
            vm[k] = len(src); src.append(int(a)); uvs.append([VT[b][0], 1.0 - VT[b][1]])
        tris.append(vm[k])
    src = np.array(src)
    N = vertex_normals(P, tv)
    tris = np.array(tris).reshape(-1, 3)
    return P[src], N[src], np.array(uvs), Jv[src], Wv[src], tris, (None if color is None else color[src])

def nearest_weights(Q):
    """Poids du sommet du corps le plus proche pour chaque point de Q."""
    J = np.zeros((len(Q), 4), dtype=np.uint16); W = np.zeros((len(Q), 4), dtype=np.float32)
    for i0 in range(0, len(Q), 400):
        d = ((Q[i0:i0 + 400, None, :] - Pb[None, :, :]) ** 2).sum(-1)
        j = d.argmin(1)
        J[i0:i0 + 400] = Jv[j]; W[i0:i0 + 400] = Wv[j]
    return J, W

def shell(mask_v, offset_v, planes=(), margin=0.01, hfun=None, base=None):
    """Coque de vêtement : sommets sélectionnés, décalés le long des normales,
    coupés proprement par des plans (les sommets qui dépassent sont ramenés sur le plan)."""
    P = (Pb if base is None else base).copy()
    keep = mask_v.copy()
    for p0, n in planes:
        n = np.array(n, float); n /= np.linalg.norm(n)
        d = (P - p0) @ n
        keep &= d > -margin
        out = d < 0
        P[out] -= d[out, None] * n
    if hfun is not None:
        h = hfun(P)
        keep &= h > -margin
        out = h < 0
        P[out, 1] -= h[out]
    # le décalage se fait après la coupe, sinon le bord remonte
    P = P + Nb * offset_v[:, None]
    tri_ok = keep[TV].all(axis=1)
    return P, TV[tri_ok], TT[tri_ok]

def used_remap(P, tv):
    return P  # (les sommets inutilisés restent présents mais non référencés)

# --------------------------------------------------------------------- vêtements
X, Y, Z = Pb[:, 0], Pb[:, 1] - SHIFT, Pb[:, 2]  # Y : hauteur « sans semelle » (repères MakeHuman)
cloth = {}

# Sweat à capuche
arm_axis = {}
for s, sfx in ((1, "L"), (-1, "R")):
    a = head["wrist." + sfx] - head["lowerarm01." + sfx]
    arm_axis[sfx] = a / np.linalg.norm(a)
off = 0.0155 - 0.0035 * smooth(0.0, 1.0, np.abs(X) / 0.55)
# poignets serrés, ourlet et col épais
for sfx in "LR":
    w = head["wrist." + sfx]
    along = (Pb - w) @ arm_axis[sfx]
    off = np.where((np.abs(X) > 0.25), 0.0105 - 0.0045 * smooth(-0.12, -0.02, along) * 0 + 0.0, off)
    off = np.where((np.abs(X) > 0.25) & (along > -0.07), 0.0065 + 0.0025 * smooth(-0.07, -0.025, along), off)
off = off + 0.016 * smooth(1.50, 1.548, Y)            # col de capuche rabattue
off = off + 0.004 * smooth(0.97, 0.88, Y) * 0 + 0.006 * smooth(0.935, 0.885, Y)  # ourlet
region = (Y > 0.86 + SHIFT * 0) & (Y < 1.60)
planes = [(np.array([0, 0.885 + SHIFT, 0]), (0, 1, 0)), (np.array([0, 1.552 + SHIFT, 0]), (0, -1, 0))]
for sfx in "LR":
    planes.append((head["wrist." + sfx] + arm_axis[sfx] * 0.012, tuple(-arm_axis[sfx])))
cloth["Hoodie"] = shell(region, off, planes)

# Jean
off_p = 0.0055 + 0.004 * smooth(0.5, 0.12, Y)
region_p = (Y > 0.09) & (Y < 1.04) & (np.abs(X) < 0.30)
planes_p = [(np.array([0, 1.0 + SHIFT, 0]), (0, -1, 0)), (np.array([0, 0.115 + SHIFT, 0]), (0, 1, 0))]
cloth["Jeans"] = shell(region_p, off_p, planes_p)

# Bonnet
def beanie_h(P):
    yp = 1.729 - 0.20 * (0.15 - P[:, 2]).clip(-0.1, 0.4) + 0.75 * np.clip(np.abs(P[:, 0]) - 0.045, 0, 1)
    return (P[:, 1] - SHIFT) - yp
yb = 1.729 - 0.20 * (0.15 - Z).clip(-0.1, 0.4) + 0.75 * np.clip(np.abs(X) - 0.045, 0, 1)
off_b = 0.0075 + 0.004 * smooth(0.03, 0.0, Y - yb)
cloth["Beanie"] = shell(Y > 1.66, off_b, hfun=beanie_h)

# --------------------------------------------------------------------- baskets (loft)
def make_shoes():
    allP, allN, allUV, allJ, allW, allC, allT = [], [], [], [], [], [], []
    base_idx = 0
    for s in (1, -1):
        m = (Y < 0.15) & (s * X > 0.03) & (Z > -0.12)
        fp = Pb[m]
        z0, z1 = fp[:, 2].min() - 0.004, fp[:, 2].max() + 0.022
        nbin = 26
        edges = np.linspace(z0, z1, nbin + 1)
        rings = []
        for i in range(nbin):
            sel = fp[(fp[:, 2] >= edges[i]) & (fp[:, 2] < edges[i + 1])]
            zc = 0.5 * (edges[i] + edges[i + 1])
            if len(sel) < 2:
                continue
            xmin, xmax = sel[:, 0].min(), sel[:, 0].max()
            if s < 0:
                xmin, xmax = xmax, xmin
            yt = sel[:, 1].max()
            rings.append([zc, 0.5 * (xmin + xmax), abs(xmax - xmin) * 0.5, yt])
        rings = np.array(rings)
        # lissage
        for c in (1, 2, 3):
            k = np.ones(5) / 5
            pad = np.pad(rings[:, c], 2, mode="edge")
            rings[:, c] = np.convolve(pad, k, mode="valid")
        K = 24
        verts, ucols = [], []
        sections = []
        n = len(rings)
        for i, (zc, cx, hw, yt) in enumerate(rings):
            t = i / (n - 1)
            end = 0.0
            sc = 1.0
            if i < 2:   sc = [0.55, 0.85][i]
            if i >= n - 2: sc = [0.88, 0.6][i - (n - 2)]
            hw = (hw + 0.010) * sc
            ysole = 0.0
            ytop = max(yt + 0.012, 0.035) * (1.0 if i < n - 2 else [0.95, 0.8][i - (n - 2)])
            cy = 0.5 * (ysole + ytop)
            hh = 0.5 * (ytop - ysole)
            sec = []
            for k in range(K):
                th = 2 * np.pi * k / K
                c, s_ = np.cos(th), np.sin(th)
                e = 2.0 / 3.2
                px = np.sign(c) * abs(c) ** e * hw
                py = np.sign(s_) * abs(s_) ** e * hh
                sec.append([cx + px, cy + py, zc])
            sections.append(sec)
        sections = np.array(sections)  # (n, K, 3)
        # capuchons aux extrémités
        heel = sections[0].mean(0) + np.array([0, 0, -0.012])
        toe = sections[-1].mean(0) + np.array([0, -0.004, 0.012])
        Pn = np.concatenate([heel[None], sections.reshape(-1, 3), toe[None]])
        tris = []
        for k in range(K):
            tris.append([0, 1 + (k + 1) % K, 1 + k])
        for i in range(n - 1):
            for k in range(K):
                a = 1 + i * K + k; b = 1 + i * K + (k + 1) % K
                c = 1 + (i + 1) * K + k; d = 1 + (i + 1) * K + (k + 1) % K
                tris += [[a, b, c], [b, d, c]]
        last = 1 + (n - 1) * K
        for k in range(K):
            tris.append([last + K, last + k, last + (k + 1) % K])
        tris = np.array(tris)
        # orientation vers l'extérieur
        cen = Pn.mean(0)
        N = vertex_normals(Pn, tris)
        if (N * (Pn - cen)).sum() < 0:
            tris = tris[:, ::-1]; N = vertex_normals(Pn, tris)
        col = np.zeros((len(Pn), 4)); col[:, 3] = 1
        sole = Pn[:, 1] < 0.014
        col[:, :3] = np.where(sole[:, None], [0.88, 0.88, 0.86], [0.09, 0.09, 0.11])
        # bout blanc (gomme) : zone avant
        toecap = (Pn[:, 2] > z1 - 0.06) & (Pn[:, 1] < 0.045)
        col[toecap, :3] = [0.88, 0.88, 0.86]
        UV = np.stack([np.arctan2(Pn[:, 1] - 0.03, Pn[:, 0] - cen[0]) / (2 * np.pi) * 3, Pn[:, 2] * 8], 1)
        J, W = nearest_weights(Pn)
        allP.append(Pn); allN.append(N); allUV.append(UV); allJ.append(J); allW.append(W); allC.append(col)
        allT.append(tris + base_idx); base_idx += len(Pn)
    return (np.concatenate(allP), np.concatenate(allN), np.concatenate(allUV), np.concatenate(allJ),
            np.concatenate(allW), np.concatenate(allT), np.concatenate(allC))

shoes = make_shoes()

# --------------------------------------------------------------------- yeux
def build_eyes():
    P_o, VT_o, f_o = load_obj(MH + "eyes/high-poly/high-poly.obj")
    scales = {}
    verts = []
    state = None
    for line in open(MH + "eyes/high-poly/high-poly.mhclo"):
        t = line.split()
        if not t or line.startswith("#"):
            continue
        if t[0] in ("x_scale", "y_scale", "z_scale"):
            scales[t[0][0]] = (int(t[1]), int(t[2]), float(t[3])); continue
        if t[0] == "verts":
            state = "verts"; continue
        if state == "verts":
            if len(t) == 9:
                verts.append((list(map(int, t[:3])), list(map(float, t[3:6])), list(map(float, t[6:9]))))
            elif len(t) == 1 and t[0].lstrip("-").isdigit():
                verts.append(([int(t[0])] * 3, [1.0, 0, 0], [0, 0, 0]))
            else:
                state = None
    sc = {}
    for ax, i in (("x", 0), ("y", 1), ("z", 2)):
        a, b, ref = scales[ax]
        sc[i] = abs(V[a][i] - V[b][i]) / ref
    pos = np.zeros((len(verts), 3))
    for i, (idx, w, o) in enumerate(verts):
        pos[i] = sum(wi * V[ii] for ii, wi in zip(idx, w)) + np.array([o[0] * sc[0], o[1] * sc[1], o[2] * sc[2]])
    pos = tr(pos)
    for sx in (1, -1):  # yeux un peu plus saillants
        m_ = np.sign(pos[:, 0]) == sx
        c_ = pos[m_].mean(0)
        pos[m_] = c_ + (pos[m_] - c_) * 1.07 + np.array([0, 0, 0.006])
    # globes oculaires propres : sphère orientée vers +Z, UV planaire sur l'iris de la texture
    Ps, Ns, UVs, Js, Ws, Ts = [], [], [], [], [], []
    base = 0
    for sx, bone, icen in ((1, "eye.L", (0.29, 0.70)), (-1, "eye.R", (0.70, 0.29))):
        c = pos[np.sign(pos[:, 0]) == sx].mean(0) + np.array([0, 0, -0.0045])
        r = 0.0108
        nlat, nlon = 18, 28
        for i in range(nlat + 1):
            th = np.pi * i / nlat
            for j in range(nlon + 1):
                ph = 2 * np.pi * j / nlon
                d = np.array([np.sin(th) * np.cos(ph), np.cos(th), np.sin(th) * np.sin(ph)])  # pôle = +Y
                d = np.array([d[0], d[2], d[1]])  # pôle -> +Z
                Ps.append(c + d * r); Ns.append(d)
                u = icen[0] + 0.185 * d[0]
                v = icen[1] - 0.185 * d[1]
                UVs.append([u, v])
        for i in range(nlat):
            for j in range(nlon):
                a_ = base + i * (nlon + 1) + j; b_ = a_ + 1; c_ = a_ + nlon + 1; d_ = c_ + 1
                Ts += [[a_, c_, b_], [b_, c_, d_]]
        base = len(Ps)
        Js += [[bidx[bone], 0, 0, 0]] * ((nlat + 1) * (nlon + 1))
        Ws += [[1.0, 0, 0, 0]] * ((nlat + 1) * (nlon + 1))
    Ps = np.array(Ps); Ns = np.array(Ns); Ts = np.array(Ts)
    if (np.cross(Ps[Ts[0, 1]] - Ps[Ts[0, 0]], Ps[Ts[0, 2]] - Ps[Ts[0, 0]]) * Ns[Ts[0, 0]]).sum() > 0:
        Ts = Ts[:, ::-1]
    return Ps, Ns, np.array(UVs), np.array(Js, dtype=np.uint16), np.array(Ws, dtype=np.float32), Ts


eyes = build_eyes()
shutil.copy(MH + "eyes/materials/brown_eye.png", os.path.join(OUT, "eye_brown.png"))

# --------------------------------------------------------------------- texture de peau
print("bake peau…")
TG.bake_skin(os.path.join(OUT, "skin_albedo.png"), Pb, Nb, TV, TT, VT, head)
TG.write_cloth_textures(OUT)

# --------------------------------------------------------------------- glTF
g = Gltf()
g.materials = [{"name": "m", "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 0.6}}]
node_of = {}
for b in order:
    p = bones[b]["parent"]
    off_ = head[b] - (head[p] if p else np.zeros(3))
    node_of[b] = len(g.nodes)
    g.nodes.append({"name": b.replace(".", "_"), "translation": [float(x) for x in off_]})
for b in order:
    p = bones[b]["parent"]
    if p:
        g.nodes[node_of[p]].setdefault("children", []).append(node_of[b])
ibm = np.zeros((len(order), 16), dtype="<f4")
for i, b in enumerate(order):
    m = np.eye(4); m[:3, 3] = -head[b]; ibm[i] = m.T.reshape(-1)
ibm_acc = g.accessor(ibm, 5126, "MAT4")
g.skins.append({"joints": [node_of[b] for b in order], "inverseBindMatrices": ibm_acc, "skeleton": node_of["root"]})
children = [node_of["root"]]

def add(name, P, N, UV, J, W, tris, C=None):
    mi = g.add_mesh(name, P, N, UV, J, W, tris, color=C)
    g.nodes.append({"name": name, "mesh": mi, "skin": 0})
    children.append(len(g.nodes) - 1)

# corps / tête séparés (la tête se masque en 1re personne)
cy = Pb[TV].mean(axis=1)[:, 1]
NECK_CUT = 1.585 + SHIFT
for name, sel in (("Body", cy <= NECK_CUT), ("Head", cy > NECK_CUT)):
    P, N, UV, J, W, tris, _ = split_mesh(Pb, TV[sel], TT[sel])
    add(name, P, N, UV, J, W, tris)
add("Eyes", *eyes)
for name, (Pc, tv, tt) in cloth.items():
    colv = None
    P, N, UV, J, W, tris, _ = split_mesh(np.concatenate([Pc, np.zeros((0, 3))]), tv, tt)
    add(name, P, N, UV, J, W, tris)
add("Shoes", shoes[0], shoes[1], shoes[2], shoes[3], shoes[4], shoes[5], shoes[6])
g.nodes.append({"name": "Character", "children": children})
g.write(os.path.join(OUT, "character.glb"), None, [len(g.nodes) - 1])
print("ok", os.path.getsize(os.path.join(OUT, "character.glb")) // 1024, "Ko")

# --- infos de repos pour l'animation (normale de paume, direction des doigts)
import json
info = {}
for sfx in ("L", "R"):
    ids = [bidx[b] for b in order if b.endswith("." + sfx) and (b.startswith("finger") or b.startswith("metacarpal") or b.startswith("wrist"))]
    sel = np.isin(Jv[:nb, 0], ids)
    pts = Pb[sel]
    c = pts.mean(0)
    w, vecs = np.linalg.eigh(np.cov((pts - c).T))
    n = vecs[:, 0]
    f = head["finger3-1." + sfx] - head["wrist." + sfx]
    f /= np.linalg.norm(f)
    n = n - f * n.dot(f); n /= np.linalg.norm(n)
    info["palm_n_" + sfx] = [float(x) for x in n]
    info["hand_f_" + sfx] = [float(x) for x in f]
json.dump(info, open(os.path.join(OUT, "rig.json"), "w"))
print(info)
