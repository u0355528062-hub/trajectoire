"""Construit les personnages (joueur + PNJ) depuis les données MakeHuman (CC0).
Chaque variante : morphologie, teinte, cheveux, barbe ; toutes les pièces de tenue sont
incluses (sweat, capuche relevée, doudoune, t-shirt, gilet jaune, jean, baskets, bonnet,
casquette, cagoule, bandana, sac à dos, cheveux longs) et activées à l'exécution.
Usage : MH_DATA=<makehuman>/makehuman/data/ python3 tools/build_character.py [variante ...]"""
import sys, os, shutil, json
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from mh_lib import *
import textures_gen as TG

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "character")
os.makedirs(OUT, exist_ok=True)
SHIFT = 0.022  # épaisseur de semelle : le sol (y=0) est le dessous des baskets

VARIANTS = {
    # nom : sexe, origines, âge (0 jeune -> 1 âgé), muscle/poids (-1..1), taille, couleurs
    "male_a":   dict(sex="male", race={"caucasian": 1.0}, old=0.0, muscle=0.38, weight=0.0, height=1.80,
                     skin=(0.80, 0.58, 0.47), hair=(0.13, 0.085, 0.06), beard=0.5, tex=2048),
    "male_b":   dict(sex="male", race={"african": 1.0}, old=0.0, muscle=0.2, weight=0.35, height=1.83,
                     skin=(0.34, 0.22, 0.16), hair=(0.04, 0.035, 0.03), beard=0.75, lip=(0.36, 0.2, 0.2)),
    "male_c":   dict(sex="male", race={"asian": 1.0}, old=0.0, muscle=-0.2, weight=-0.3, height=1.71,
                     skin=(0.82, 0.64, 0.5), hair=(0.04, 0.035, 0.035), beard=0.15),
    "male_d":   dict(sex="male", race={"caucasian": 1.0}, old=0.45, muscle=0.0, weight=0.3, height=1.76,
                     skin=(0.82, 0.6, 0.5), hair=(0.36, 0.34, 0.32), beard=1.0),
    "male_e":   dict(sex="male", race={"african": 0.5, "caucasian": 0.5}, old=0.0, muscle=0.55, weight=0.0, height=1.78,
                     skin=(0.55, 0.37, 0.27), hair=(0.05, 0.04, 0.03), beard=0.6, lip=(0.45, 0.25, 0.24)),
    "female_a": dict(sex="female", race={"caucasian": 1.0}, old=0.0, muscle=0.0, weight=0.0, height=1.66,
                     skin=(0.85, 0.65, 0.55), hair=(0.30, 0.18, 0.10), longhair=True, lip=(0.68, 0.32, 0.33)),
    "female_b": dict(sex="female", race={"african": 1.0}, old=0.0, muscle=0.1, weight=0.15, height=1.69,
                     skin=(0.38, 0.25, 0.19), hair=(0.03, 0.025, 0.02), longhair=True, lip=(0.42, 0.22, 0.22)),
    "female_c": dict(sex="female", race={"asian": 1.0}, old=0.0, muscle=-0.2, weight=-0.2, height=1.60,
                     skin=(0.86, 0.68, 0.56), hair=(0.03, 0.03, 0.03), longhair=True, lip=(0.66, 0.34, 0.34)),
    "female_d": dict(sex="female", race={"caucasian": 0.6, "african": 0.4}, old=0.1, muscle=0.0, weight=0.0, height=1.70,
                     skin=(0.66, 0.46, 0.35), hair=(0.12, 0.07, 0.04), longhair=True, lip=(0.52, 0.27, 0.26)),
}

V0, VT, faces = load_obj(MH + "3dobjs/base.obj")
body_faces = [f for f in faces if f[0] == "body"]
NB = max(v for _, idx in body_faces for v, _ in idx) + 1
SK = load_skeleton()
BONES = SK["bones"]
ORDER = []
def _visit(b):
    if b in ORDER:
        return
    p = BONES[b]["parent"]
    if p:
        _visit(p)
    ORDER.append(b)
for _b in sorted(BONES):
    _visit(_b)
BIDX = {b: i for i, b in enumerate(ORDER)}
TV, TT = [], []
for _g, _idx in body_faces:
    for _t in triangulate(_idx):
        TV.append([v for v, _ in _t]); TT.append([vt for _, vt in _t])
TV, TT = np.array(TV), np.array(TT)

# arêtes du maillage (lissage des vêtements)
_E = np.concatenate([TV[:, [0, 1]], TV[:, [1, 2]], TV[:, [2, 0]]])
EDGES = np.unique(np.sort(_E, axis=1), axis=0)

# poids de skinning (communs à toutes les variantes : même topologie)
_wts = load_weights()
_infl = [dict() for _ in range(len(V0))]
for _b, _lst in _wts.items():
    if _b in BIDX:
        for v, w in _lst:
            _infl[v][BIDX[_b]] = w
JV = np.zeros((len(V0), 4), dtype=np.uint16)
WV = np.zeros((len(V0), 4), dtype=np.float32)
for v in range(len(V0)):
    items = sorted(_infl[v].items(), key=lambda kv: -kv[1])[:4]
    tot = sum(w for _, w in items) or 1.0
    for k, (b, w) in enumerate(items):
        JV[v, k] = b; WV[v, k] = w / tot
    if not items:
        JV[v, 0] = BIDX["root"]; WV[v, 0] = 1.0


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def target_spec(sp):
    g = sp["sex"]
    old = sp.get("old", 0.0)
    out = []
    for race, w in sp["race"].items():
        out.append((f"macrodetails/{race}-{g}-young.target", w * (1 - old)))
        if old > 0:
            out.append((f"macrodetails/{race}-{g}-old.target", w * old))
    m, wt = sp.get("muscle", 0.0), sp.get("weight", 0.0)
    if m > 0:
        out.append((f"macrodetails/universal-{g}-young-maxmuscle-averageweight.target", m))
    elif m < 0:
        out.append((f"macrodetails/universal-{g}-young-minmuscle-averageweight.target", -m))
    if wt > 0:
        out.append((f"macrodetails/universal-{g}-young-averagemuscle-maxweight.target", wt))
    elif wt < 0:
        out.append((f"macrodetails/universal-{g}-young-averagemuscle-minweight.target", -wt))
    hgt = 0.35 if sp["height"] >= 1.76 else (0.0 if sp["height"] >= 1.66 else -0.3)
    if hgt > 0:
        out.append((f"macrodetails/height/{g}-young-averagemuscle-averageweight-maxheight.target", hgt))
    elif hgt < 0:
        out.append((f"macrodetails/height/{g}-young-averagemuscle-averageweight-minheight.target", -hgt))
    return out


def build_variant(name, sp):
    print(f"== {name}")
    V = apply_targets(V0, target_spec(sp))
    def jpos(n):
        return V[SK["joints"][n]].mean(axis=0)
    ymin, ymax = V[:NB, 1].min(), V[:NB, 1].max()
    S = sp["height"] / (ymax - ymin)
    def tr(P):
        return (P - np.array([0, ymin, 0])) * S + np.array([0, SHIFT, 0])
    Pw = tr(V)
    head = {b: tr(jpos(BONES[b]["head"])) for b in ORDER}
    Pb = Pw[:NB]
    Nb = vertex_normals(Pb, TV)
    X, Y, Z = Pb[:, 0], Pb[:, 1], Pb[:, 2]

    # ---------------------------------------------------------------- repères
    eye = 0.5 * (head["eye.L"] + head["eye.R"])
    hscale = np.linalg.norm(tr(jpos(BONES["head"]["tail"])) - head["head"]) / 0.15
    mouth_y = 0.5 * (head["oris01"][1] + head["oris06"][1]) + 0.004 * hscale
    hip_y = head["upperleg01.L"][1]
    neck1_y = head["neck01"][1]
    neck2_y = head["neck02"][1]
    waist_y = head["spine05"][1]
    foot_y = head["foot.L"][1]
    shoulder_x = abs(head["upperarm01.L"][0])
    ctx = {"eye": eye, "hscale": hscale, "mouth_y": mouth_y, "neck_y": neck1_y - 0.02}

    def ref(P):
        """Points du personnage -> repère de la tête de référence."""
        return TG.to_ref(P, ctx)
    def from_ref_dy(h):
        return h * hscale

    # ---------------------------------------------------------------- utilitaires
    def split_mesh(P, tv, tt, color=None):
        vm, src, uvs, tris = {}, [], [], []
        for a, b in zip(tv.reshape(-1), tt.reshape(-1)):
            k = (int(a), int(b))
            if k not in vm:
                vm[k] = len(src); src.append(int(a)); uvs.append([VT[b][0], 1.0 - VT[b][1]])
            tris.append(vm[k])
        src = np.array(src)
        N = vertex_normals(P, tv)
        tris = np.array(tris).reshape(-1, 3)
        return P[src], N[src], np.array(uvs), JV[src], WV[src], tris, (None if color is None else color[src])

    def nearest_weights(Q, rigid=None):
        J = np.zeros((len(Q), 4), dtype=np.uint16); W = np.zeros((len(Q), 4), dtype=np.float32)
        if rigid is not None:
            J[:, 0] = BIDX[rigid]; W[:, 0] = 1.0
            return J, W
        for i0 in range(0, len(Q), 400):
            d = ((Q[i0:i0 + 400, None, :] - Pb[None, :, :]) ** 2).sum(-1)
            j = d.argmin(1)
            J[i0:i0 + 400] = JV[j]; W[i0:i0 + 400] = WV[j]
        return J, W

    def shell(mask_v, offset_v, planes=(), margin=0.01, hfun=None, drop=None, smooth_it=0, min_off=0.5, post=None):
        """Coque de vêtement : sommets choisis, coupés par des plans (chaque plan peut ne viser
        qu'une partie des sommets), décalés le long des normales puis lissés comme un tissu
        (les reliefs musculaires disparaissent) sans jamais rentrer dans le corps."""
        P = Pb.copy()
        keep = mask_v.copy()
        for pl in planes:
            p0, n = pl[0], np.array(pl[1], float)
            lim = pl[2] if len(pl) > 2 else None
            n /= np.linalg.norm(n)
            d = (P - p0) @ n
            if lim is not None:
                d = np.where(lim, d, 1.0)
            keep &= d > -margin
            out = d < 0
            P[out] -= d[out, None] * n
        if hfun is not None:
            h = hfun(P)
            keep &= h > -margin
            out = h < 0
            P[out, 1] -= h[out]
        P = P + Nb * offset_v[:, None]
        tri_ok = keep[TV].all(axis=1)
        if drop is not None:
            tri_ok &= ~drop[TV].any(axis=1)
        if smooth_it > 0:
            used = np.zeros(len(P), bool)
            used[TV[tri_ok].reshape(-1)] = True
            e = EDGES[used[EDGES[:, 0]] & used[EDGES[:, 1]]]
            # sommets de bord (arête d'un seul triangle) : on les garde fixes
            tv_ok = TV[tri_ok]
            be = np.sort(np.concatenate([tv_ok[:, [0, 1]], tv_ok[:, [1, 2]], tv_ok[:, [2, 0]]]), axis=1)
            u, cnt = np.unique(be, axis=0, return_counts=True)
            border = np.zeros(len(P), bool)
            border[u[cnt == 1].reshape(-1)] = True
            for _ in range(smooth_it):
                acc = np.zeros_like(P); deg = np.zeros(len(P))
                np.add.at(acc, e[:, 0], P[e[:, 1]]); np.add.at(acc, e[:, 1], P[e[:, 0]])
                np.add.at(deg, e[:, 0], 1); np.add.at(deg, e[:, 1], 1)
                m = used & (deg > 0) & ~border
                P[m] += 0.5 * (acc[m] / deg[m, None] - P[m])
                # jamais sous la peau
                dd = ((P - Pb) * Nb).sum(1)
                lo = offset_v * min_off
                push = np.maximum(0.0, lo - dd)
                P += Nb * push[:, None]
        if post is not None:
            P = P + Nb * post[:, None]
        return P, TV[tri_ok], TT[tri_ok]

    arm_axis = {}
    for sfx in "LR":
        a = head["wrist." + sfx] - head["lowerarm01." + sfx]
        arm_axis[sfx] = a / np.linalg.norm(a)
    up_axis = {}
    for sfx in "LR":
        a = head["lowerarm01." + sfx] - head["upperarm01." + sfx]
        up_axis[sfx] = a / np.linalg.norm(a)
    is_arm = np.abs(X) > shoulder_x + 0.065
    R = ref(Pb)  # coordonnées dans le repère tête de référence
    rx, ry, rz = R[:, 0], R[:, 1], R[:, 2]
    head_v = Y > neck1_y - 0.03
    cloth = {}
    vcolor = {}

    # ---- sweat (manches longues)
    def top_offsets(base_t, base_a, collar, hem, cuff=True):
        off = base_t - 0.0035 * smooth(0.0, 1.0, np.abs(X) / 0.55)
        off = np.where(is_arm, base_a, off)
        if cuff:
            for sfx in "LR":
                along = (Pb - head["wrist." + sfx]) @ arm_axis[sfx]
                off = np.where(is_arm & (along > -0.07), base_a - 0.004 + 0.0025 * smooth(-0.07, -0.025, along), off)
        off = off + collar * smooth(neck1_y - 0.058, neck1_y - 0.01, Y)
        off = off + hem * smooth(hip_y + 0.01, hip_y - 0.035, Y)
        return off
    def top_planes(hem_y, collar_y, sleeve="long"):
        pl = [(np.array([0, hem_y, 0]), (0, 1, 0)), (np.array([0, collar_y, 0]), (0, -1, 0))]
        for sfx in "LR":
            side = (np.sign(X) == (1 if sfx == "L" else -1)) & (np.abs(X) > shoulder_x - 0.04)
            if sleeve == "long":
                pl.append((head["wrist." + sfx] + arm_axis[sfx] * 0.012, tuple(-arm_axis[sfx]), side))
            elif sleeve == "short":
                mid = head["upperarm02." + sfx]
                pl.append((mid + up_axis[sfx] * 0.03, tuple(-up_axis[sfx]), side & is_arm))
        return pl
    region_top = (Y > hip_y - 0.14) & (Y < neck1_y + 0.05)
    cloth["Hoodie"] = shell(region_top, top_offsets(0.0155, 0.0105, 0.016, 0.006),
                            top_planes(hip_y - 0.035, neck1_y - 0.006), smooth_it=10)
    # ---- doudoune : plus épaisse, matelassée (bourrelets horizontaux), col montant
    quilt = 0.006 * np.abs(np.sin(np.pi * (Y - hip_y) / 0.075))
    for sfx in "LR":
        along = (Pb - head["upperarm01." + sfx]) @ up_axis[sfx]
        quilt = np.where(is_arm & (np.sign(X) == (1 if sfx == "L" else -1)), 0.005 * np.abs(np.sin(np.pi * along / 0.07)), quilt)
    off_j = top_offsets(0.026, 0.02, 0.012, 0.004)
    cloth["Jacket"] = shell((Y > hip_y - 0.15) & (Y < neck1_y + 0.07), off_j,
                            top_planes(hip_y - 0.05, neck1_y + 0.022), smooth_it=14, min_off=0.65, post=quilt)
    # ---- t-shirt
    cloth["Tshirt"] = shell(region_top, top_offsets(0.0075, 0.007, 0.002, 0.002, cuff=False),
                            top_planes(hip_y - 0.025, neck1_y - 0.02, "short"), smooth_it=8)
    # ---- gilet jaune (sans manches, bandes réfléchissantes en couleur de sommet)
    off_v = np.full(len(Pb), 0.034) - 0.006 * smooth(0.0, 1.0, np.abs(X) / 0.4)
    armhole = []
    for sfx, sg in (("L", 1), ("R", -1)):
        armhole.append((np.array([sg * (shoulder_x - 0.005), 0, 0]), (-sg, 0, 0), np.sign(X) == sg))
    cloth["Vest"] = shell((Y > hip_y - 0.12) & (Y < neck1_y + 0.02) & (np.abs(X) < shoulder_x + 0.02), off_v,
                          top_planes(hip_y - 0.03, neck1_y - 0.035, "none") + armhole, smooth_it=14, min_off=0.7)
    vc = np.zeros((len(Pb), 4)); vc[:, 3] = 1.0
    vc[:, :3] = [0.95, 0.85, 0.05]
    for yb in (hip_y + 0.07, hip_y + 0.22):
        band = np.abs(Y - yb) < 0.025
        vc[band, :3] = [0.78, 0.8, 0.82]
    vcolor["Vest"] = vc
    # ---- jean
    off_p = 0.0055 + 0.004 * smooth(foot_y + 0.425, foot_y + 0.045, Y)
    region_p = (Y > foot_y + 0.015) & (Y < waist_y + 0.053) & (np.abs(X) < shoulder_x + 0.115)
    cloth["Jeans"] = shell(region_p, off_p, [(np.array([0, waist_y + 0.013, 0]), (0, -1, 0)),
                                             (np.array([0, foot_y + 0.04, 0]), (0, 1, 0))], smooth_it=6)

    # ---- couvre-chefs (dans le repère de la tête de référence)
    def beanie_h(P):
        Q = ref(P)
        yp = 1.729 - 0.20 * (0.15 - Q[:, 2]).clip(-0.1, 0.4) + 0.75 * np.clip(np.abs(Q[:, 0]) - 0.045, 0, 1)
        return (Q[:, 1] - yp) * hscale
    yb_ = 1.729 - 0.20 * (0.15 - rz).clip(-0.1, 0.4) + 0.75 * np.clip(np.abs(rx) - 0.045, 0, 1)
    cloth["Beanie"] = shell(head_v & (ry > 1.66), 0.0075 + 0.004 * smooth(0.03, 0.0, ry - yb_), hfun=beanie_h)
    # casquette : calotte plus haute + visière
    def cap_h(P):
        Q = ref(P)
        yp = 1.752 - 0.16 * (0.15 - Q[:, 2]).clip(-0.1, 0.4) + 0.5 * np.clip(np.abs(Q[:, 0]) - 0.05, 0, 1)
        return (Q[:, 1] - yp) * hscale
    yc_ = 1.752 - 0.16 * (0.15 - rz).clip(-0.1, 0.4) + 0.5 * np.clip(np.abs(rx) - 0.05, 0, 1)
    cloth["Cap"] = shell(head_v & (ry > 1.68), 0.006 + 0.003 * smooth(0.02, 0.0, ry - yc_), hfun=cap_h)
    # cagoule : toute la tête et le cou, ouverture pour les yeux
    eyes_hole = (np.abs(rx) < 0.07) & (ry > 1.692 - 0.019) & (ry < 1.692 + 0.021) & (rz > 0.09)
    cloth["Balaclava"] = shell(Y > neck1_y - 0.035, np.full(len(Pb), 0.0055),
                               [(np.array([0, neck1_y - 0.025, 0]), (0, 1, 0))], drop=eyes_hole)
    # bandana sur le bas du visage
    band_r = (Y > neck1_y - 0.01) & (ry < 1.672) & head_v
    kv = (TG.M_REF_Y - TG.E_REF[1]) / (mouth_y - eye[1])
    band_top = eye[1] + (1.672 - TG.E_REF[1]) / kv
    cloth["Bandana"] = shell(band_r, 0.009 + 0.004 * smooth(1.60, 1.66, ry),
                             [(np.array([0, neck1_y, 0]), (0, 1, 0)), (np.array([0, band_top, 0]), (0, -1, 0))])
    # capuche relevée : coque large autour du crâne, ouverte sur le visage
    face_open = (rz > 0.075) & (((rx / 0.074) ** 2 + ((ry - 1.665) / 0.098) ** 2) < 1.0)
    cloth["Hood"] = shell(Y > neck1_y - 0.04, 0.03 + 0.012 * smooth(1.70, 1.82, ry) + 0.01 * smooth(0.06, 0.0, rz),
                          [(np.array([0, neck1_y - 0.035, 0]), (0, 1, 0))], drop=face_open)

    # ---- cheveux longs (femmes) : calotte + queue de cheval
    extra = {}
    hy = 1.775 - 0.115 * np.clip((0.16 - rz) / 0.2, 0, 1) - 0.045 * np.clip((np.abs(rx) - 0.04) / 0.04, 0, 1)
    if sp.get("longhair"):
        earz = np.sqrt((np.abs(rx) - 0.082) ** 2 + (ry - 1.675) ** 2 + (rz - 0.04) ** 2)
        hairm = head_v & (ry > hy - 0.004) & (earz > 0.03)
        cloth["Hair"] = shell(hairm, 0.008 + 0.01 * smooth(1.72, 1.84, ry), hfun=lambda P: (ref(P)[:, 1] - (1.775 - 0.115 * np.clip((0.16 - ref(P)[:, 2]) / 0.2, 0, 1) - 0.045 * np.clip((np.abs(ref(P)[:, 0]) - 0.04) / 0.04, 0, 1))) * hscale)
        # queue de cheval : tube effilé qui part de l'arrière du crâne
        top = eye + np.array([0, 0.045, -0.135]) * hscale
        pts = [top + np.array([0, -i * 0.035, -0.018 * np.sin(i * 0.4)]) * hscale for i in range(9)]
        rings = []
        K = 14
        for i, c in enumerate(pts):
            r = (0.03 if i < 2 else 0.026 * (1 - i / 10.0) + 0.006) * hscale
            for k in range(K):
                a = 2 * np.pi * k / K
                rings.append(c + np.array([np.cos(a) * r, 0, np.sin(a) * r * 0.8]))
        Pp = np.array(rings)
        tris = []
        for i in range(len(pts) - 1):
            for k in range(K):
                a = i * K + k; b = i * K + (k + 1) % K; c = (i + 1) * K + k; d = (i + 1) * K + (k + 1) % K
                tris += [[a, c, b], [b, c, d]]
        tip = len(Pp)
        Pp = np.vstack([Pp, pts[-1] + np.array([0, -0.02 * hscale, 0])])
        last = (len(pts) - 1) * K
        for k in range(K):
            tris.append([last + k, tip, last + (k + 1) % K])
        tris = np.array(tris)
        N = vertex_normals(Pp, tris)
        cen = np.array(pts).mean(0)
        if (N * (Pp - cen)).sum() < 0:
            tris = tris[:, ::-1]; N = vertex_normals(Pp, tris)
        UVp = np.stack([np.arctan2(Pp[:, 2] - cen[2], Pp[:, 0]) / np.pi, (Pp[:, 1] - cen[1]) * 6], 1)
        J, W = nearest_weights(Pp, rigid="head")
        extra["Ponytail"] = (Pp, N, UVp, J, W, tris, None)

    # ---- visière de casquette
    brim_c = eye + np.array([0.0, 0.052, 0.035]) * hscale
    Kb, Rb = 16, 6
    bp = []
    for i in range(Rb + 1):
        t = i / Rb
        for k in range(Kb + 1):
            a = np.pi * k / Kb
            x = np.cos(a) * (0.085 * (0.55 + 0.45 * t))
            zz = np.sin(a) * 0.078 * t
            y = -0.012 * (zz / 0.078) ** 2 - 0.006 * (x / 0.085) ** 2
            bp.append(brim_c + np.array([x, y, zz]) * hscale)
    bp = np.array(bp)
    nb_ = len(bp)
    btop = bp + np.array([0, 0.004, 0])
    Pv_ = np.vstack([btop, bp])
    tris = []
    for i in range(Rb):
        for k in range(Kb):
            a = i * (Kb + 1) + k; b = a + 1; c = a + Kb + 1; d = c + 1
            tris += [[a, b, c], [b, d, c]]
            tris += [[nb_ + a, nb_ + c, nb_ + b], [nb_ + b, nb_ + c, nb_ + d]]
    for k in range(Kb):  # tranche avant
        a = Rb * (Kb + 1) + k; b = a + 1
        tris += [[a, nb_ + a, b], [b, nb_ + a, nb_ + b]]
    tris = np.array(tris)
    Nbr = vertex_normals(Pv_, tris)
    if Nbr[: nb_, 1].mean() < 0:
        tris = tris[:, ::-1]; Nbr = vertex_normals(Pv_, tris)
    UVb = np.stack([Pv_[:, 0] * 8, Pv_[:, 2] * 8], 1)
    J, W = nearest_weights(Pv_, rigid="head")
    extra["CapBrim"] = (Pv_, Nbr, UVb, J, W, tris, None)

    # ---- sac à dos (lié au haut du dos)
    sp2 = head["spine02"]
    back_z = Pb[(np.abs(Y - sp2[1]) < 0.05) & (np.abs(X) < 0.08), 2].min()
    bc = np.array([0.0, sp2[1] - 0.02, back_z - 0.075])
    bw, bh, bd = 0.15, 0.22, 0.075
    rings = []
    K = 20
    Lr = 9
    for i in range(Lr):
        t = i / (Lr - 1)
        yy = bc[1] - bh + 2 * bh * t
        s_ = np.sin(np.pi * (0.06 + 0.88 * t)) ** 0.35
        for k in range(K):
            a = 2 * np.pi * k / K
            c_, s2 = np.cos(a), np.sin(a)
            px = np.sign(c_) * abs(c_) ** 0.55 * bw * s_
            pz = np.sign(s2) * abs(s2) ** 0.55 * bd * s_
            rings.append([bc[0] + px, yy, bc[2] + pz])
    Pk = np.array(rings)
    tris = []
    for i in range(Lr - 1):
        for k in range(K):
            a = i * K + k; b = i * K + (k + 1) % K; c = (i + 1) * K + k; d = (i + 1) * K + (k + 1) % K
            tris += [[a, b, c], [b, d, c]]
    c0 = len(Pk); Pk = np.vstack([Pk, [bc[0], bc[1] - bh, bc[2]], [bc[0], bc[1] + bh, bc[2]]])
    for k in range(K):
        tris.append([c0, (k + 1) % K, k])
        tris.append([c0 + 1, (Lr - 1) * K + k, (Lr - 1) * K + (k + 1) % K])
    tris = np.array(tris)
    N = vertex_normals(Pk, tris)
    if (N * (Pk - bc)).sum() < 0:
        tris = tris[:, ::-1]; N = vertex_normals(Pk, tris)
    UVk = np.stack([Pk[:, 0] * 4, Pk[:, 1] * 4], 1)
    J, W = nearest_weights(Pk, rigid="spine02")
    extra["Backpack"] = (Pk, N, UVk, J, W, tris, None)

    # ---- baskets (loft autour du pied)
    def make_shoes():
        allP, allN, allUV, allJ, allW, allC, allT = [], [], [], [], [], [], []
        base_idx = 0
        for s in (1, -1):
            m = (Y < foot_y + 0.075) & (s * X > 0.03) & (Z > -0.12)
            fp = Pb[m]
            z0, z1 = fp[:, 2].min() - 0.012, fp[:, 2].max() + 0.022
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
                rings.append([zc, 0.5 * (xmin + xmax), abs(xmax - xmin) * 0.5, sel[:, 1].max()])
            rings = np.array(rings)
            for c in (1, 2, 3):
                pad = np.pad(rings[:, c], 2, mode="edge")
                rings[:, c] = np.convolve(pad, np.ones(5) / 5, mode="valid")
            K = 24
            sections = []
            n = len(rings)
            for i, (zc, cx, hw, yt) in enumerate(rings):
                sc = 1.0
                if i < 2: sc = [0.82, 0.97][i]   # talon bien couvert
                if i >= n - 2: sc = [0.88, 0.6][i - (n - 2)]
                hw = (hw + 0.010) * sc
                ytop = max(yt + 0.012, 0.035) * (1.0 if i < n - 2 else [0.95, 0.8][i - (n - 2)])
                cy, hh = 0.5 * ytop, 0.5 * ytop
                sec = []
                for k in range(K):
                    th = 2 * np.pi * k / K
                    c, s_ = np.cos(th), np.sin(th)
                    e = 2.0 / 3.2
                    sec.append([cx + np.sign(c) * abs(c) ** e * hw, cy + np.sign(s_) * abs(s_) ** e * hh, zc])
                sections.append(sec)
            sections = np.array(sections)
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
            cen = Pn.mean(0)
            N = vertex_normals(Pn, tris)
            if (N * (Pn - cen)).sum() < 0:
                tris = tris[:, ::-1]; N = vertex_normals(Pn, tris)
            col = np.zeros((len(Pn), 4)); col[:, 3] = 1
            sole = Pn[:, 1] < 0.014
            col[:, :3] = np.where(sole[:, None], [0.88, 0.88, 0.86], [1.0, 1.0, 1.0])
            toecap = (Pn[:, 2] > z1 - 0.06) & (Pn[:, 1] < 0.045)
            col[toecap, :3] = [0.88, 0.88, 0.86]
            UV = np.stack([np.arctan2(Pn[:, 1] - 0.03, Pn[:, 0] - cen[0]) / (2 * np.pi) * 3, Pn[:, 2] * 8], 1)
            J, W = nearest_weights(Pn)
            allP.append(Pn); allN.append(N); allUV.append(UV); allJ.append(J); allW.append(W); allC.append(col)
            allT.append(tris + base_idx); base_idx += len(Pn)
        return (np.concatenate(allP), np.concatenate(allN), np.concatenate(allUV), np.concatenate(allJ),
                np.concatenate(allW), np.concatenate(allT), np.concatenate(allC))
    extra["Shoes"] = make_shoes()

    # ---- yeux
    def build_eyes():
        scales, verts, state = {}, [], None
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
            a, b, rf = scales[ax]
            sc[i] = abs(V[a][i] - V[b][i]) / rf
        pos = np.zeros((len(verts), 3))
        for i, (idx, w, o) in enumerate(verts):
            pos[i] = sum(wi * V[ii] for ii, wi in zip(idx, w)) + np.array([o[0] * sc[0], o[1] * sc[1], o[2] * sc[2]])
        pos = tr(pos)
        Ps, Ns, UVs, Js, Ws, Ts = [], [], [], [], [], []
        base = 0
        for sx, bone, icen in ((1, "eye.L", (0.29, 0.70)), (-1, "eye.R", (0.70, 0.29))):
            c = pos[np.sign(pos[:, 0]) == sx].mean(0) + np.array([0, 0, 0.0015])
            r = 0.0108 * hscale
            nlat, nlon = 14, 22
            for i in range(nlat + 1):
                th = np.pi * i / nlat
                for j in range(nlon + 1):
                    ph = 2 * np.pi * j / nlon
                    d = np.array([np.sin(th) * np.cos(ph), np.sin(th) * np.sin(ph), np.cos(th)])
                    Ps.append(c + d * r); Ns.append(d)
                    UVs.append([icen[0] + 0.185 * d[0], icen[1] - 0.185 * d[1]])
            for i in range(nlat):
                for j in range(nlon):
                    a_ = base + i * (nlon + 1) + j; b_ = a_ + 1; c_ = a_ + nlon + 1; d_ = c_ + 1
                    Ts += [[a_, c_, b_], [b_, c_, d_]]
            base = len(Ps)
            Js += [[BIDX[bone], 0, 0, 0]] * ((nlat + 1) * (nlon + 1))
            Ws += [[1.0, 0, 0, 0]] * ((nlat + 1) * (nlon + 1))
        Ps = np.array(Ps); Ns = np.array(Ns); Ts = np.array(Ts)
        if (np.cross(Ps[Ts[0, 1]] - Ps[Ts[0, 0]], Ps[Ts[0, 2]] - Ps[Ts[0, 0]]) * Ns[Ts[0, 0]]).sum() > 0:
            Ts = Ts[:, ::-1]
        return Ps, Ns, np.array(UVs), np.array(Js, dtype=np.uint16), np.array(Ws, dtype=np.float32), Ts
    extra["Eyes"] = build_eyes()

    # ---------------------------------------------------------------- peau
    sctx = dict(ctx)
    sctx.update({"skin": sp["skin"], "hair": sp["hair"], "lip": sp.get("lip", (0.62, 0.30, 0.29)),
                 "beard": sp.get("beard", 0.0) if sp["sex"] == "male" else 0.0,
                 "brow": 0.8 if sp["sex"] == "female" else 1.0,
                 "lip_h": 1.12 if sp["sex"] == "female" else 1.0,
                 "freckles": 1.0 if np.mean(sp["skin"]) > 0.6 else 0.0,
                 "elbows": [head["lowerarm01.L"], head["lowerarm01.R"]],
                 "knees": [head["lowerleg01.L"], head["lowerleg01.R"]]})
    TG.bake_skin(os.path.join(OUT, f"skin_{name}.png"), Pb, Nb, TV, TT, VT, sctx, size=sp.get("tex", 1024))

    # ---------------------------------------------------------------- glTF
    g = Gltf()
    g.materials = [{"name": "m", "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 0.6}}]
    node_of = {}
    for b in ORDER:
        p = BONES[b]["parent"]
        off_ = head[b] - (head[p] if p else np.zeros(3))
        node_of[b] = len(g.nodes)
        g.nodes.append({"name": b.replace(".", "_"), "translation": [float(x) for x in off_]})
    for b in ORDER:
        p = BONES[b]["parent"]
        if p:
            g.nodes[node_of[p]].setdefault("children", []).append(node_of[b])
    ibm = np.zeros((len(ORDER), 16), dtype="<f4")
    for i, b in enumerate(ORDER):
        m = np.eye(4); m[:3, 3] = -head[b]; ibm[i] = m.T.reshape(-1)
    ibm_acc = g.accessor(ibm, 5126, "MAT4")
    g.skins.append({"joints": [node_of[b] for b in ORDER], "inverseBindMatrices": ibm_acc, "skeleton": node_of["root"]})
    children = [node_of["root"]]
    def add(nm, P, N, UV, J, W, tris, C=None):
        mi = g.add_mesh(nm, P, N, UV, J, W, tris, color=C)
        g.nodes.append({"name": nm, "mesh": mi, "skin": 0})
        children.append(len(g.nodes) - 1)
    cy = Pb[TV].mean(axis=1)[:, 1]
    neck_cut = neck2_y + 0.003
    for nm, sel in (("Body", cy <= neck_cut), ("Head", cy > neck_cut)):
        P, N, UV, J, W, tris, _ = split_mesh(Pb, TV[sel], TT[sel])
        add(nm, P, N, UV, J, W, tris)
    for nm, (Pc, tv, tt) in cloth.items():
        P, N, UV, J, W, tris, C = split_mesh(Pc, tv, tt, vcolor.get(nm))
        add(nm, P, N, UV, J, W, tris, C)
    for nm, data in extra.items():
        add(nm, *data)
    g.nodes.append({"name": "Character", "children": children})
    g.write(os.path.join(OUT, f"{name}.glb"), None, [len(g.nodes) - 1])

    # ---------------------------------------------------------------- infos d'animation
    info = {"height": sp["height"], "sex": sp["sex"]}
    for sfx in ("L", "R"):
        ids = [BIDX[b] for b in ORDER if b.endswith("." + sfx) and (b.startswith("finger") or b.startswith("metacarpal") or b.startswith("wrist"))]
        sel = np.isin(JV[:NB, 0], ids)
        pts = Pb[sel]
        c = pts.mean(0)
        w, vecs = np.linalg.eigh(np.cov((pts - c).T))
        n = vecs[:, 0]
        f = head["finger3-1." + sfx] - head["wrist." + sfx]
        f /= np.linalg.norm(f)
        n = n - f * n.dot(f); n /= np.linalg.norm(n)
        info["palm_n_" + sfx] = [float(x) for x in n]
        info["hand_f_" + sfx] = [float(x) for x in f]
    json.dump(info, open(os.path.join(OUT, f"rig_{name}.json"), "w"))
    print("   ", os.path.getsize(os.path.join(OUT, f"{name}.glb")) // 1024, "Ko")


if __name__ == "__main__":
    shutil.copy(MH + "eyes/materials/brown_eye.png", os.path.join(OUT, "eye_brown.png"))
    TG.write_cloth_textures(OUT)
    names = sys.argv[1:] or list(VARIANTS)
    for nm in names:
        build_variant(nm, VARIANTS[nm])
