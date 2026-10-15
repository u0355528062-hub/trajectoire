"""Textures des personnages (module Personnages), cuites sur l'UV du corps MakeHuman :
peau détaillée (teint, rougeurs, creux, sourcils et barbe poil à poil, brillance), yeux,
vêtements (coutures, poches, côtes, plis : normales + masques partagés par toutes les variantes)
et mèches de cheveux. Appelé par build_character.py."""
import os
import numpy as np
from PIL import Image
import textures_gen as TG
from textures_gen import smooth, vnoise3, fbm3, tile_noise


# ----------------------------------------------------------------------------- rastérisation
def raster(TV, TT, VT, size):
    """Texels couverts par les triangles (UV du corps) : (indice de pixel, triangle, barycentres)."""
    seen = np.full(size * size, -1, dtype=np.int64)
    out_p, out_t, out_w = [], [], []
    uv = np.stack([VT[:, 0] * size, (1.0 - VT[:, 1]) * size], 1)
    for t in range(len(TV)):
        a, b, c = uv[TT[t, 0]], uv[TT[t, 1]], uv[TT[t, 2]]
        x0, x1 = max(int(np.floor(min(a[0], b[0], c[0]))) - 1, 0), min(int(np.ceil(max(a[0], b[0], c[0]))) + 1, size)
        y0, y1 = max(int(np.floor(min(a[1], b[1], c[1]))) - 1, 0), min(int(np.ceil(max(a[1], b[1], c[1]))) + 1, size)
        if x1 <= x0 or y1 <= y0:
            continue
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-12:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        pid = ys[m].astype(np.int64) * size + xs[m].astype(np.int64)
        keep = seen[pid] < 0
        if not keep.any():
            continue
        pid = pid[keep]
        seen[pid] = t
        w = np.stack([w0[m][keep], w1[m][keep], w2[m][keep]], 1).clip(0, 1)
        w /= w.sum(1, keepdims=True)
        out_p.append(pid); out_t.append(np.full(len(pid), t)); out_w.append(w)
    return np.concatenate(out_p), np.concatenate(out_t), np.concatenate(out_w)


def interp(attr, TV, tri, w):
    """Interpole un attribut de sommet (n,) ou (n,k) aux texels."""
    v = TV[tri]
    a = attr[v]
    if attr.ndim == 2:
        return (a * w[:, :, None]).sum(1)
    return (a * w).sum(1)


def dilate(img, cov, it=8):
    """Étend les texels couverts sur leurs voisins (évite les coutures UV avec le filtrage/les mipmaps)."""
    img = img.copy()
    cov = cov.copy()
    for _ in range(it):
        m = ~cov
        if not m.any():
            break
        acc = np.zeros_like(img); cnt = np.zeros(cov.shape)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(img, (dy, dx), (0, 1)); sc = np.roll(cov, (dy, dx), (0, 1))
            acc += sh * (sc[..., None] if img.ndim == 3 else sc); cnt += sc
        fill = m & (cnt > 0)
        img[fill] = acc[fill] / (cnt[fill][:, None] if img.ndim == 3 else cnt[fill])
        cov = cov | fill
    return img, cov


def save_rgba(path, img):
    Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, optimize=True)


def height_to_normal(h, k):
    """Carte de hauteur (texels) -> normale tangente (convention OpenGL, comme textures_gen.to_normal)."""
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    n = np.stack([-dx * k, dy * k, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def vertex_curvature(P, N, TV, it=2):
    """Courbure moyenne approchée par sommet (> 0 : creux) : laplacien projeté sur la normale."""
    E = np.concatenate([TV[:, [0, 1]], TV[:, [1, 2]], TV[:, [2, 0]]])
    acc = np.zeros_like(P); deg = np.zeros(len(P))
    np.add.at(acc, E[:, 0], P[E[:, 1]]); np.add.at(acc, E[:, 1], P[E[:, 0]])
    np.add.at(deg, E[:, 0], 1); np.add.at(deg, E[:, 1], 1)
    lap = acc / np.maximum(deg, 1)[:, None] - P
    c = (lap * N).sum(1)
    for _ in range(it):  # léger lissage
        a2 = np.zeros(len(P)); np.add.at(a2, E[:, 0], c[E[:, 1]]); np.add.at(a2, E[:, 1], c[E[:, 0]])
        c = 0.5 * c + 0.5 * a2 / np.maximum(deg, 1)
    return c


class Grid:
    """Grille spatiale des texels (positions 3D) pour dessiner des poils sans tout parcourir."""
    def __init__(self, pos, cell):
        self.cell = cell
        self.pos = pos
        k = np.floor(pos / cell).astype(np.int64)
        self.key = (k[:, 0] * 73856093) ^ (k[:, 1] * 19349663) ^ (k[:, 2] * 83492791)
        order = np.argsort(self.key)
        self.order = order
        self.sk = self.key[order]

    def near(self, p, r):
        lo = np.floor((p - r) / self.cell).astype(np.int64)
        hi = np.floor((p + r) / self.cell).astype(np.int64)
        out = []
        for i in range(lo[0], hi[0] + 1):
            for j in range(lo[1], hi[1] + 1):
                for k in range(lo[2], hi[2] + 1):
                    kk = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
                    a = np.searchsorted(self.sk, kk); b = np.searchsorted(self.sk, kk, side="right")
                    if b > a:
                        out.append(self.order[a:b])
        return np.concatenate(out) if out else np.zeros(0, dtype=np.int64)


def seg_dist(Q, a, b):
    ab = b - a
    t = np.clip(((Q - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(Q - (a + t[:, None] * ab), axis=1), t


def draw_hairs(cover, grid, roots, dirs, lengths, width, rng, dark=(0.55, 1.0)):
    """Poils (segments 3D) : couverture = max des poils proches (0..1)."""
    for p, d, L in zip(roots, dirs, lengths):
        b = p + d * L
        idx = grid.near(0.5 * (p + b), 0.5 * L + width * 2)
        if len(idx) == 0:
            continue
        dist, t = seg_dist(grid.pos[idx], p, b)
        w = width * (1.0 - 0.6 * t)  # effilé vers la pointe
        a = smooth(w, w * 0.25, dist) * rng.uniform(*dark)
        cover[idx] = np.maximum(cover[idx], a)


# ----------------------------------------------------------------------------- peau
def bake_skin(path, Pb, Nb, TV, TT, VT, ctx, size=2048, seed=1):
    """Peau RGBA : RGB = teint (avec sourcils, barbe, cheveux peints sous les mèches), A = brillance (sébum)."""
    rng = np.random.default_rng(seed)
    pid, tri, w = raster(TV, TT, VT, size)
    P = interp(Pb, TV, tri, w)
    N = interp(Nb, TV, tri, w)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    curv = interp(vertex_curvature(Pb, Nb, TV), TV, tri, w)
    R = TG.to_ref(P, ctx)
    x, y, z = R[:, 0], R[:, 1], R[:, 2]
    ax = np.abs(x)
    base = np.array(ctx["skin"], float)
    lum = float(base.mean())
    dark = 1.0 - lum
    n = len(P)
    head_zone = (y > 1.5) & (P[:, 1] > ctx["neck_y"])
    face = (N[:, 2] > -0.2) & (z > 0.06) & (y > 1.55) & (y < 1.80) & head_zone

    # --- teint : variations lentes de valeur et de teinte (rouge / jaune / olive), marbrures fines
    n_lo = fbm3(P, 5.0, 3)
    n_hue = fbm3(P + 7.7, 9.0, 3)
    n_mid = fbm3(P + 3.3, 40.0, 3)
    n_hi = vnoise3(P + 1.1, 900.0)
    col = base[None, :] * (0.92 + 0.16 * n_lo)[:, None]
    warm = (n_hue - 0.5) * 2.0
    col *= (1.0 + 0.05 * warm[:, None] * np.array([1.0, -0.2, -0.9])[None, :])
    col *= (0.965 + 0.07 * n_mid)[:, None]
    col *= (0.985 + 0.03 * n_hi)[:, None]

    def blob(Q, c, r, amt):
        d = np.sqrt(((Q - np.array(c)) ** 2).sum(1))
        return amt * smooth(r, 0.0, d)
    red = np.zeros(n)
    for sx in (1, -1):
        red += blob(R, (sx * 0.048, 1.652, 0.118), 0.034, 0.45)       # pommettes
        red += blob(R, (sx * 0.082, 1.675, 0.035), 0.032, 0.6)        # oreilles
        red += blob(R, (sx * 0.026, 1.692, 0.122), 0.014, 0.25)       # coins internes des yeux
    red += blob(R, (0.0, 1.652, 0.168), 0.024, 0.55)                   # nez
    red += blob(R, (0.0, 1.598, 0.13), 0.03, 0.2)                      # menton
    for c in ctx["elbows"] + ctx["knees"]:
        red += blob(P, c, 0.05, 0.35)
    for c in ctx.get("hands", []):
        red += blob(P, c, 0.07, 0.4)
    red = np.clip(red, 0, 1) * (1.0 - dark * 0.55)
    red_col = np.array([0.62, 0.2, 0.17]) * (0.6 + 0.6 * lum)
    col = col * (1 - 0.3 * red[:, None]) + red_col[None, :] * 0.3 * red[:, None]
    # cernes : un peu plus sombre et violacé sous les yeux, paupières légèrement rosées
    und = np.zeros(n); lid = np.zeros(n)
    for sx in (1, -1):
        und += blob(R * np.array([1.0, 1.6, 1.0]), (sx * 0.032, 1.677 * 1.6, 0.118), 0.022, 1.0)
        lid += blob(R * np.array([1.0, 2.0, 1.0]), (sx * 0.032, 1.704 * 2.0, 0.122), 0.02, 1.0)
    age = ctx.get("age", 0.0)
    und = np.clip(und, 0, 1) * face * (0.16 + 0.15 * age)
    col = col * (1 - und[:, None] * np.array([0.25, 0.32, 0.2])[None, :])
    lid = np.clip(lid, 0, 1) * face
    col = col * (1 - 0.06 * lid[:, None]) + np.array([0.5, 0.25, 0.25])[None, :] * 0.06 * lid[:, None]
    # creux (sillons, orbites, oreilles, aisselles, entre les doigts) : occlusion cuite
    cav = np.clip(curv / 0.0025, -1.0, 1.0)
    col *= (1.0 - 0.2 * np.clip(cav, 0, 1) + 0.04 * np.clip(-cav, 0, 1))[:, None]
    # taches de rousseur et grains de beauté
    fr = smooth(0.74, 0.84, vnoise3(R + 5.5, 380.0)) * smooth(1.58, 1.68, y) * (z > 0.02) * ctx.get("freckles", 0.0)
    col *= (1 - 0.1 * fr)[:, None]
    for _ in range(ctx.get("moles", 4)):
        c = P[rng.integers(n)]
        if c[1] < ctx["neck_y"] - 0.4:
            continue
        m = blob(P, c, rng.uniform(0.0012, 0.0022), 1.0)
        col = col * (1 - 0.45 * m[:, None]) + np.array([0.25, 0.15, 0.1])[None, :] * 0.45 * m[:, None] * (0.5 + lum)
    # rides (personnes âgées) : front, pattes d'oie, sillons nasogéniens
    if age > 0.2:
        wr = np.zeros(n)
        wr += (0.5 + 0.5 * np.sin(y * 2 * np.pi / 0.0055)) ** 6 * smooth(1.725, 1.74, y) * smooth(1.79, 1.765, y) * smooth(0.06, 0.03, ax)
        for sx in (1, -1):
            dd = np.sqrt((x - sx * 0.064) ** 2 + (y - 1.693) ** 2)
            ang = np.arctan2(y - 1.693, (x - sx * 0.064) * sx)
            wr += (0.5 + 0.5 * np.sin(ang * 9.0)) ** 8 * smooth(0.004, 0.012, dd) * smooth(0.026, 0.012, dd) * (sx * x > 0.05)
        wr *= face
        col *= (1 - 0.08 * age * wr * (0.4 + 0.6 * n_mid))[:, None]
    else:
        wr = np.zeros(n)

    # --- lèvres : teinte naturelle, plus sombres sur le contour et à la commissure
    rx, ry = 0.0235, 0.0105 * ctx.get("lip_h", 1.0)
    q = (x / rx) ** 2 + ((y - TG.M_REF_Y) / ry) ** 2
    lip = smooth(1.05, 0.62, q) * face * (z > 0.12)
    lip_col = np.array(ctx["lip"], float) * 0.85 + base * 0.15
    col = col * (1 - 0.8 * lip[:, None]) + lip_col[None, :] * 0.8 * lip[:, None]
    mline = np.exp(-((y - (TG.M_REF_Y - 0.0008)) / 0.0008) ** 2) * smooth(0.027, 0.019, ax) * face
    col *= (1 - 0.6 * mline)[:, None]
    lip_edge = np.exp(-((q - 1.0) / 0.18) ** 2) * face * (z > 0.12)
    col *= (1 - 0.08 * lip_edge)[:, None]

    hair_col = np.array(ctx["hair"], float)
    brow_col = np.array(ctx.get("brow_col", ctx["hair"]), float)
    cell = 0.003
    # --- cils : liseré sombre au bord des paupières (supérieure surtout)
    for e in ctx.get("eyes", []):
        Eref = TG.to_ref(e[None, :], ctx)[0]
        de = np.linalg.norm(R - Eref, axis=1)
        r_eye = 0.0108
        upper = smooth(Eref[1] - 0.003, Eref[1] + 0.002, y)
        lash = smooth(r_eye + 0.0042, r_eye + 0.0016, de) * face * (z > Eref[2] - 0.004)
        lash *= 0.45 + 0.5 * upper
        col = col * (1 - 0.7 * lash[:, None]) + np.array([0.03, 0.025, 0.02])[None, :] * 0.7 * lash[:, None]

    # --- sourcils poil à poil (dans le plan du visage de référence)
    sel = np.where(face & (y > 1.698) & (y < 1.742) & (ax < 0.066) & (z > 0.08))[0]
    brow = np.zeros(n)
    if len(sel):
        Q = np.stack([x[sel], y[sel], np.zeros(len(sel))], 1)
        g = Grid(Q, cell)
        bth = ctx.get("brow", 1.0)
        roots, dirs, lens = [], [], []
        for sx in (1, -1):
            for _ in range(int(340 * bth)):
                t = rng.uniform(0, 1) ** 0.9
                bx = 0.011 + 0.045 * t
                yb = 1.7185 + 0.010 * np.sin(np.pi * np.clip(t * 0.85, 0, 1)) - 0.004 * t
                th = (0.0042 + 0.004 * (1 - t)) * bth
                u = rng.normal(0, th * 0.42)
                ang = np.radians(np.interp(t, [0, 0.18, 0.45, 1.0], [80, 45, 18, -12]) + rng.normal(0, 8))
                d = np.array([np.cos(ang) * sx, np.sin(ang), 0.0])
                L = np.interp(t, [0, 0.3, 1], [0.005, 0.008, 0.006]) * rng.uniform(0.7, 1.15)
                roots.append(np.array([sx * bx, yb + u - 0.4 * L * d[1], 0.0])); dirs.append(d); lens.append(L)
        cov = np.zeros(len(sel))
        draw_hairs(cov, g, roots, dirs, lens, 0.00032, rng, (0.5, 0.95))
        brow[sel] = cov
        # duvet sous les poils (sinon la peau paraît « collée » entre eux)
        for sx in (1, -1):
            t = np.clip((sx * x[sel] - 0.011) / 0.045, 0, 1)
            yb = 1.7185 + 0.010 * np.sin(np.pi * np.clip(t * 0.85, 0, 1)) - 0.004 * t
            th = (0.0042 + 0.004 * (1 - t)) * ctx.get("brow", 1.0)
            soft = smooth(th * 0.9, th * 0.2, np.abs(y[sel] - yb)) * (sx * x[sel] > 0.009) * (sx * x[sel] < 0.058)
            brow[sel] = np.maximum(brow[sel], soft * 0.28)
    col = col * (1 - 0.9 * brow[:, None]) + brow_col[None, :] * 0.9 * brow[:, None]

    # --- barbe : ombre de rasage + poils (de naissante à fournie), moustache
    bd = ctx.get("beard", 0.0)
    beard_cov = np.zeros(n)
    if bd > 0:
        zone = face & (y < 1.668) & (z > 0.03) & (ax < 0.085)
        zone |= head_zone & (y < 1.6) & (P[:, 1] > ctx["neck_y"] + 0.03) & (N[:, 1] < 0.2) & (z > -0.02)
        dens = smooth(1.672, 1.645, y) * (1 - lip) * smooth(0.085, 0.066, ax) * smooth(ctx["neck_y"] + 0.03, ctx["neck_y"] + 0.08, P[:, 1])
        # joues hautes dégarnies, moustache dense
        dens = np.maximum(dens * smooth(1.66, 1.63, y + 0.03 * (ax > 0.04)), 0)
        must = smooth(0.0095, 0.004, np.abs(y - (TG.M_REF_Y + 0.0145))) * smooth(0.03, 0.022, ax)
        dens = np.clip(np.maximum(dens, must * 1.2) * zone, 0, 1)
        dens *= 0.75 + 0.25 * fbm3(P + 2.2, 60.0, 2)
        shadow = dens * (0.35 + 0.3 * bd)
        sh_col = hair_col * 0.6 + base * 0.4
        col = col * (1 - 0.45 * shadow[:, None]) + sh_col[None, :] * 0.45 * shadow[:, None]
        sel = np.where(dens > 0.05)[0]
        if len(sel):
            g = Grid(P[sel], cell)
            cnt = int(len(sel) * (0.02 + 0.06 * bd))
            pick = rng.choice(len(sel), size=min(cnt, len(sel)), p=dens[sel] / dens[sel].sum())
            roots, dirs, lens = [], [], []
            for i in pick:
                p = P[sel[i]]; nn = N[sel[i]]
                down = np.array([0.0, -1.0, 0.0])
                if must[sel[i]] > 0.3:
                    down = np.array([np.sign(x[sel[i]]) * 0.6, -1.0, 0.0])
                d = down - nn * (down @ nn) + rng.normal(0, 0.35, 3)
                d -= nn * (d @ nn)
                d /= max(np.linalg.norm(d), 1e-9)
                L = (0.0009 + 0.012 * bd ** 3) * rng.uniform(0.6, 1.3)
                roots.append(p); dirs.append(d); lens.append(L)
            cov = np.zeros(len(sel))
            draw_hairs(cov, g, roots, dirs, lens, 0.0002 + 0.0001 * bd, rng, (0.5, 0.95))
            beard_cov[sel] = cov
        col = col * (1 - 0.85 * beard_cov[:, None]) + hair_col[None, :] * 0.85 * beard_cov[:, None]

    # --- cheveux peints sous les mèches (racines) et coupe rase
    hy = 1.775 - 0.115 * np.clip((0.16 - z) / 0.2, 0, 1) - 0.045 * np.clip((ax - 0.04) / 0.04, 0, 1)
    hy = hy + ctx.get("hairline", 0.0) + 0.003 * (fbm3(P + 4.4, 120.0, 2) - 0.5)
    ear = np.sqrt((ax - 0.082) ** 2 + (y - 1.675) ** 2 + (z - 0.04) ** 2)
    scalp = smooth(hy - 0.004, hy + 0.008, y) * smooth(0.03, 0.04, ear) * (y < 1.86) * head_zone
    if ctx.get("bald", 0.0) > 0:  # calvitie sur le dessus (même zone que la coupe « dégarni »)
        crown = np.maximum(smooth(1.762, 1.778, y), smooth(1.735, 1.75, y) * smooth(-0.015, 0.02, z))
        scalp *= 1.0 - ctx["bald"] * crown
    dots = smooth(0.45, 0.7, vnoise3(P + 9.1, 2200.0))
    root_col = hair_col * (0.55 + 0.35 * dots[:, None]) * 0.9 + base * 0.1 * (1 - dots[:, None])
    k_scalp = ctx.get("scalp_k", 0.92)
    col = col * (1 - k_scalp * scalp[:, None]) + root_col * k_scalp * scalp[:, None]

    # --- brillance (sébum) : zone T, nez, lèvres ; poils mats
    oil = 0.35 + 0.0 * x
    oil += 0.35 * smooth(0.035, 0.0, ax) * smooth(1.66, 1.70, y) * face          # nez + front
    oil += 0.2 * smooth(1.70, 1.76, y) * smooth(0.06, 0.02, ax) * face
    oil += 0.45 * lip
    oil -= 0.25 * np.clip(cav, 0, 1)
    oil *= 1.0 - 0.8 * np.clip(brow + beard_cov + scalp, 0, 1)
    oil *= 1.0 - 0.3 * age
    oil = np.clip(oil, 0.02, 1.0)

    img = np.zeros((size * size, 4), dtype=np.float32)
    img[pid, :3] = np.clip(col, 0, 1)
    img[pid, 3] = oil
    cov = np.zeros(size * size, bool); cov[pid] = True
    img, cov = dilate(img.reshape(size, size, 4), cov.reshape(size, size), 10)
    img[~cov, :3] = base; img[~cov, 3] = 0.3
    save_rgba(path, img)


# ----------------------------------------------------------------------------- yeux
def write_eyes(out, size=512):
    """Globes oculaires (même projection que les sphères de build_character) : iris détaillés par couleur."""
    yy, xx = (np.mgrid[0:size, 0:size] + 0.5) / size
    irises = {
        "brown": ((0.22, 0.12, 0.06), (0.42, 0.26, 0.12)),
        "dark": ((0.1, 0.06, 0.035), (0.22, 0.13, 0.07)),
        "hazel": ((0.3, 0.22, 0.09), (0.45, 0.42, 0.2)),
        "green": ((0.2, 0.28, 0.16), (0.42, 0.5, 0.28)),
        "blue": ((0.2, 0.32, 0.45), (0.45, 0.6, 0.72)),
        "grey": ((0.32, 0.36, 0.38), (0.55, 0.6, 0.62)),
    }
    rng = np.random.default_rng(5)
    fib_noise = rng.random(720)
    for name, (c_in, c_out) in irises.items():
        img = np.zeros((size, size, 3))
        img[:] = (0.78, 0.74, 0.7)
        for cx, cy in ((0.29, 0.70), (0.70, 0.29)):
            dx, dy = (xx - cx) / 0.185, (yy - cy) / 0.185      # direction (x, y) sur la sphère
            r = np.sqrt(dx * dx + dy * dy)
            front = r < 1.0
            ang = np.arctan2(dy, dx)
            # blanc de l'œil : rosé et plus sombre vers les bords, vaisseaux fins
            scl = np.array([0.52, 0.49, 0.46])[None, None, :] * (1.0 - 0.45 * smooth(0.45, 1.0, r))[..., None]
            ves = (np.abs(np.sin(ang * 23.0 + 3.0 * np.sin(r * 9.0))) < 0.05) * smooth(0.65, 0.95, r) * 0.35
            scl = scl * (1 - ves[..., None]) + np.array([0.7, 0.25, 0.22]) * ves[..., None]
            # iris (rayon ~0.48 de la sphère), fibres radiales, anneau limbique sombre, pupille
            ri = 0.47
            t = r / ri
            fib = fib_noise[((ang + np.pi) / (2 * np.pi) * 720).astype(int) % 720]
            fib2 = 0.5 + 0.5 * np.sin(ang * 61.0 + 4.0 * t)
            base = np.array(c_in)[None, None, :] * (1 - t[..., None]) + np.array(c_out)[None, None, :] * t[..., None]
            ir = base * (0.7 + 0.35 * fib[..., None] * 0.6 + 0.25 * fib2[..., None] * 0.4)
            collar = np.exp(-((t - 0.42) / 0.08) ** 2)
            ir = ir * (1 - 0.25 * collar[..., None]) + np.array(c_out)[None, None, :] * 0.25 * collar[..., None]
            limb = smooth(0.78, 1.0, t)
            ir *= (1 - 0.65 * limb)[..., None]
            pupil = smooth(0.3, 0.26, t)
            ir = ir * (1 - pupil[..., None]) + 0.012 * pupil[..., None]
            m_ir = smooth(1.02, 0.98, t)
            eye = scl * (1 - m_ir[..., None]) + ir * m_ir[..., None]
            img = np.where(front[..., None], eye, img)
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, f"eye_{name}.png"))


# ----------------------------------------------------------------------------- vêtements
class Body:
    """Repères du corps de référence pour placer coutures, poches et plis."""
    def __init__(self, Pb, head, lm):
        self.head = head
        self.lm = lm
        X, Y, Z = Pb[:, 0], Pb[:, 1], Pb[:, 2]
        # centre du tronc (z) par tranche de hauteur
        ys = np.linspace(lm["foot_y"], lm["neck1_y"] + 0.1, 120)
        zc = []
        for yv in ys:
            m = (np.abs(Y - yv) < 0.02) & (np.abs(X) < lm["shoulder_x"] - 0.02)
            zc.append(0.5 * (Z[m].min() + Z[m].max()) if m.sum() > 3 else 0.0)
        self.ys, self.zc = ys, np.array(zc)

    def torso(self, P):
        """(angle autour du tronc : 0 devant, ±pi/2 côtés, pi dos ; rayon)."""
        zc = np.interp(P[:, 1], self.ys, self.zc)
        a = np.arctan2(P[:, 0], P[:, 2] - zc)
        return a, np.sqrt(P[:, 0] ** 2 + (P[:, 2] - zc) ** 2)

    def limb(self, P, names, side, inward):
        """Paramètres le long d'un membre (polyligne d'os) : abscisse (m), angle autour de l'axe
        (0 = côté `inward`), rayon, distance à l'axe."""
        pts = [self.head[nm + "." + side] for nm in names]
        best = np.full(len(P), 1e9); s_out = np.zeros(len(P)); ang = np.zeros(len(P)); rad = np.zeros(len(P))
        acc = 0.0
        for a, b in zip(pts[:-1], pts[1:]):
            ab = b - a; L = np.linalg.norm(ab); u = ab / L
            t = np.clip((P - a) @ u, 0, L)
            q = a + t[:, None] * u
            v = P - q
            d = np.linalg.norm(v, axis=1)
            ref = inward - u * (inward @ u); ref /= np.linalg.norm(ref)
            oth = np.cross(u, ref)
            an = np.arctan2(v @ oth, v @ ref)
            m = d < best
            best[m] = d[m]; s_out[m] = acc + t[m]; ang[m] = an[m]; rad[m] = d[m]
            acc += L
        return s_out, ang, rad


def _ridge(d, w):
    return np.exp(-(d / w) ** 2)


def _stitches(d, along, offsets, period=0.0032, w=0.00045):
    s = np.zeros_like(d)
    on = (np.sin(along * 2 * np.pi / period) > -0.2).astype(float)
    for o in offsets:
        s = np.maximum(s, _ridge(d - o, w) * on)
    return s


def bake_garments(out, Pb, Nb, TV, TT, VT, head, lm, tris, size=2048, msize=1024):
    """Pour chaque vêtement : <nom>_n.png (normales : coutures, poches, côtes, plis) et
    <nom>_m.png (R = ombrage cuit, G = garnitures/fil, B = usure ou bandes, A = zone spéciale)."""
    pid, tri, w = raster(TV, TT, VT, size)
    P = interp(Pb, TV, tri, w)
    B = Body(Pb, head, lm)
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    hip_y, waist_y, neck_y, foot_y = lm["hip_y"], lm["waist_y"], lm["neck1_y"], lm["foot_y"]
    sh_x = lm["shoulder_x"]
    ta, tr = B.torso(P)
    side_arc = tr * np.abs(np.abs(ta) - np.pi / 2)   # distance (m) à la couture de côté
    arm = {}; leg = {}
    for s, sg in (("L", 1.0), ("R", -1.0)):
        arm[s] = B.limb(P, ["upperarm01", "lowerarm01", "wrist"], s, np.array([-sg, -1.0, 0.0]))
        leg[s] = B.limb(P, ["upperleg01", "lowerleg01", "foot"], s, np.array([-sg, 0.0, 0.0]))
    is_armv = np.abs(X) > sh_x + 0.065
    sideL = X > 0
    def pick(d):  # valeur du côté du texel
        return np.where(sideL, d["L"], d["R"])
    a_s = pick({k: v[0] for k, v in arm.items()}); a_a = pick({k: v[1] for k, v in arm.items()}); a_r = pick({k: v[2] for k, v in arm.items()})
    l_s = pick({k: v[0] for k, v in leg.items()}); l_a = pick({k: v[1] for k, v in leg.items()}); l_r = pick({k: v[2] for k, v in leg.items()})
    arm_len = np.linalg.norm(head["lowerarm01.L"] - head["upperarm01.L"]) + np.linalg.norm(head["wrist.L"] - head["lowerarm01.L"])
    elbow_s = np.linalg.norm(head["lowerarm01.L"] - head["upperarm01.L"])
    knee_s = np.linalg.norm(head["lowerleg01.L"] - head["upperleg01.L"])
    leg_len = knee_s + np.linalg.norm(head["foot.L"] - head["lowerleg01.L"])
    noise = fbm3(P + 0.7, 25.0, 3)
    fine = tile_noise(256, 8, 40, 3)

    def border_dist(tri_mask):
        """Distance 3D au bord du vêtement (ourlets, poignets, col) et hauteur du point de bord."""
        tv = TV[tri_mask]
        e = np.sort(np.concatenate([tv[:, [0, 1]], tv[:, [1, 2]], tv[:, [2, 0]]]), axis=1)
        u, cnt = np.unique(e, axis=0, return_counts=True)
        bv = np.unique(u[cnt == 1].reshape(-1))
        Q = Pb[bv]
        d = np.full(len(P), 1e9); by = np.zeros(len(P)); bx = np.zeros(len(P))
        for i0 in range(0, len(P), 20000):
            dd = ((P[i0:i0 + 20000, None, :] - Q[None, :, :]) ** 2).sum(-1)
            j = dd.argmin(1)
            d[i0:i0 + 20000] = np.sqrt(dd[np.arange(len(j)), j]); by[i0:i0 + 20000] = Q[j, 1]; bx[i0:i0 + 20000] = Q[j, 0]
        return d, by, bx

    def finish(name, h, shade, trim, wear, special, sel):
        img_n = np.zeros(size * size); covn = np.zeros(size * size, bool)
        img_n[pid[sel]] = h[sel]; covn[pid[sel]] = True
        hh, _ = dilate(img_n.reshape(size, size), covn.reshape(size, size), 6)
        nrm = height_to_normal(hh * size, 1.0)
        save_rgba(os.path.join(out, f"{name}_n.png"), nrm)
        m = np.zeros((size * size, 4)); m[:, 0] = 1.0
        m[pid[sel]] = np.stack([shade, trim, wear, special], 1)[sel]
        mm, _ = dilate(m.reshape(size, size, 4), covn.reshape(size, size), 6)
        k = size // msize  # réduction par moyenne (PIL prémultiplie l'alpha en RGBA)
        mm = mm.reshape(msize, k, msize, k, 4).mean((1, 3))
        save_rgba(os.path.join(out, f"{name}_m.png"), mm)
        print("   ", name)

    zero = np.zeros(len(P))

    # ---- sweat à capuche : côtes aux poignets et en bas, poche kangourou, cordons, coutures, plis
    def top_common(name, tri_mask, rib_cuff, rib_hem, sleeve_long=True, collar_rib=0.012, drawstrings=False, pocket=False):
        sel = tri_mask[tri]
        d, by, bx = border_dist(tri_mask)
        h = zero.copy(); shade = np.ones(len(P)); trim = zero.copy(); wear = zero.copy(); spec = zero.copy()
        cuff = (np.abs(bx) > sh_x + 0.05) & (by < neck_y - 0.1)
        hem = (np.abs(bx) < sh_x + 0.05) & (by < hip_y + 0.1)
        collar = by > neck_y - 0.1
        # bandes de côtes
        circ = np.where(is_armv, a_a * a_r, ta * tr)
        rib_w = np.where(cuff, rib_cuff, np.where(hem, rib_hem, collar_rib))
        in_rib = (d < rib_w) & (rib_w > 0)
        rib = (0.5 + 0.5 * np.cos(circ * 2 * np.pi / 0.0032)) * in_rib
        h += 0.00045 * rib
        h += 0.0012 * smooth(rib_w, rib_w - 0.004, d) * in_rib          # bourrelet de la bande
        h -= 0.0009 * _ridge(d - rib_w, 0.0012) * (rib_w > 0)            # couture d'assemblage
        trim = np.maximum(trim, in_rib * 0.6)
        shade *= 1.0 - 0.18 * _ridge(d - rib_w, 0.004) * (rib_w > 0)
        # ourlet : bord roulé + légère ombre au bord (épaisseur)
        h += 0.001 * smooth(0.004, 0.0, d)
        shade *= 1.0 - 0.25 * smooth(0.006, 0.0, d)
        # coutures de côté et sous les bras, emmanchures
        sd = np.where(is_armv, np.abs(a_a) * a_r, side_arc)
        h -= 0.0008 * _ridge(sd, 0.0012)
        h += 0.00035 * _stitches(sd, Y + np.where(is_armv, a_s, 0), [0.0022, -0.0022])
        shade *= 1.0 - 0.12 * _ridge(sd, 0.003)
        arm_root = np.where(sideL, arm["L"][0], arm["R"][0])
        armhole = np.abs(arm_root - 0.04) * (np.abs(X) > sh_x - 0.03) * (Y > hip_y + 0.15)
        h -= 0.0007 * _ridge(armhole, 0.0013) * (np.abs(X) > sh_x - 0.03)
        # plis : saignée du coude, avant-bras tassé près du poignet, aisselles, taille
        if sleeve_long:
            el = (a_s - elbow_s) / 0.07
            inner = smooth(1.2, 0.2, np.abs(np.abs(a_a) - np.pi * 0.5) ) if False else smooth(2.2, 0.6, np.abs(a_a))
            fold_e = np.sin(a_s * 2 * np.pi / 0.026 + 3 * noise) * np.exp(-el ** 2) * (0.35 + 0.65 * inner)
            stack = np.sin(a_s * 2 * np.pi / 0.034 + 2.5 * noise + a_a * 0.8) * smooth(arm_len - 0.2, arm_len - 0.06, a_s)
            fl = (fold_e * 0.0035 + stack * 0.0028) * is_armv
            h += fl
            shade *= 1.0 - 0.22 * np.clip(-fl / 0.003, 0, 1)
        pit = smooth(0.13, 0.0, np.abs(np.abs(X) - (sh_x - 0.01))) * smooth(neck_y - 0.3, neck_y - 0.17, Y) * smooth(neck_y - 0.07, neck_y - 0.16, Y) * ~is_armv
        fold_p = np.sin((Y * 1.0 + np.abs(X) * 0.8) * 2 * np.pi / 0.03 + 2 * noise) * pit
        h += 0.0022 * fold_p
        waist = smooth(hip_y + 0.18, hip_y + 0.06, Y) * ~is_armv
        fold_w = np.sin(Y * 2 * np.pi / 0.05 + 9 * noise + 1.5 * np.sin(X * 18)) * waist * (0.3 + 0.7 * noise)
        h += 0.0014 * fold_w
        shade *= 1.0 - 0.15 * np.clip(-(fold_w * waist + fold_p) , 0, 1)
        # poche kangourou : trapèze sur le ventre, ouvertures sur les côtés
        if pocket:
            py0, py1 = hip_y + 0.03, hip_y + 0.2
            front = np.abs(ta) < 1.1
            wtop = 0.07; wbot = 0.135
            yy = np.clip((Y - py0) / (py1 - py0), 0, 1)
            half = wbot + (wtop - wbot) * yy
            inside = front & (Y > py0) & (Y < py1) & (np.abs(X) < half)
            edge_top = np.abs(Y - py1) * (np.abs(X) < wtop) * front
            edge_side = np.abs(np.abs(X) - half) * (Y > py0) * (Y < py1) * front
            dpk = np.minimum(np.where(np.abs(X) < wtop, np.abs(Y - py1), 1.0), np.where((Y > py0) & (Y < py1), np.abs(np.abs(X) - half), 1.0))
            h += 0.0016 * inside * smooth(0.0, 0.01, np.minimum(np.abs(Y - py1), np.abs(np.abs(X) - half)))
            h += 0.0004 * _stitches(dpk, X + Y, [0.003])
            h -= 0.0007 * _ridge(dpk, 0.0012)
            opening = inside * smooth(0.012, 0.0, np.abs(np.abs(X) - half)) * smooth(py1 - 0.03, py1 - 0.08, Y)
            shade *= 1.0 - 0.45 * opening
            shade *= 1.0 - 0.15 * _ridge(dpk, 0.003)
        # cordons de capuche : deux tresses qui pendent du col
        if drawstrings:
            for sx in (1, -1):
                cx = sx * 0.045
                cy0, cy1 = neck_y - 0.035, neck_y - 0.2
                along = np.clip((cy0 - Y) / (cy0 - cy1), 0, 1)
                dx = np.abs(X - cx - sx * 0.012 * along)
                cord = smooth(0.0028, 0.0016, dx) * (Y < cy0) * (Y > cy1) * (np.abs(ta) < 0.9)
                h += 0.0018 * cord * np.sqrt(np.clip(1 - (dx / 0.0028) ** 2, 0, 1))
                aglet = cord * smooth(cy1 + 0.025, cy1 + 0.02, Y)
                trim = np.maximum(trim, cord)
                spec = np.maximum(spec, aglet)
                shade *= 1.0 - 0.3 * smooth(0.0045, 0.0028, dx) * (1 - cord) * (Y < cy0) * (Y > cy1) * (np.abs(ta) < 0.9)
                eye_ = np.sqrt((X - cx) ** 2 + (Y - cy0 - 0.004) ** 2)
                spec = np.maximum(spec, smooth(0.004, 0.003, eye_) * smooth(0.0015, 0.0025, eye_))
        h += 0.00025 * noise
        finish(name, h, shade, trim, wear, spec, sel)

    top_common("cloth_hoodie", tris["Hoodie"], 0.055, 0.06, drawstrings=True, pocket=True)
    top_common("cloth_tshirt", tris["Tshirt"], 0.0, 0.0, sleeve_long=False, collar_rib=0.014)

    # ---- doudoune : piqûres dans les creux du matelassage, zip central, col, poignets élastiques
    sel = tris["Jacket"][tri]
    d, by, bx = border_dist(tris["Jacket"])
    h = 0.0003 * noise; shade = np.ones(len(P)); trim = zero.copy(); spec = zero.copy()
    qy = np.abs(np.sin(np.pi * (Y - hip_y) / 0.075))
    qa = np.abs(np.sin(np.pi * a_s / 0.07))
    q = np.where(is_armv, qa, qy)
    seam_q = smooth(0.12, 0.0, q)
    along = np.where(is_armv, a_a * a_r, X)
    h -= 0.0012 * seam_q
    h += 0.0003 * _stitches(q * 0.02, along, [0.0], 0.003, 0.0006)
    shade *= 1.0 - 0.3 * seam_q
    zip_d = np.abs(X) * (np.abs(ta) < 1.0)
    zip_d = np.where(np.abs(ta) < 1.0, np.abs(X), 1.0)
    teeth = smooth(0.004, 0.0025, zip_d) * (Y < neck_y + 0.03)
    placket = smooth(0.016, 0.012, zip_d)
    h += 0.0012 * placket - 0.0006 * _ridge(zip_d - 0.0145, 0.001) + 0.0004 * teeth * (np.sin(Y * 2 * np.pi / 0.004) > 0)
    spec = np.maximum(spec, teeth)
    shade *= 1.0 - 0.3 * _ridge(zip_d - 0.004, 0.0015)
    cuffj = (np.abs(bx) > sh_x + 0.05) & (by < neck_y - 0.1)
    elastic = (d < 0.025) * (cuffj | (by < hip_y + 0.05))
    h += 0.0003 * elastic * (0.5 + 0.5 * np.sin(np.where(is_armv, a_a * a_r, ta * tr) * 2 * np.pi / 0.006))
    trim = np.maximum(trim, elastic * 0.8)
    h += 0.001 * smooth(0.004, 0.0, d); shade *= 1.0 - 0.25 * smooth(0.007, 0.0, d)
    sd = np.where(is_armv, np.abs(a_a) * a_r, side_arc)
    h -= 0.0006 * _ridge(sd, 0.0012)
    finish("cloth_jacket", h, shade, trim, zero, spec, sel)

    # ---- jean : coutures (fil surpiqué), braguette, poches, ceinture, passants, plis et usure
    sel = tris["Jeans"][tri]
    d, by, bx = border_dist(tris["Jeans"])
    h = 0.0002 * noise; shade = np.ones(len(P)); thread = zero.copy(); wear = zero.copy(); spec = zero.copy()
    on_leg = (Y < hip_y - 0.04)
    # couture extérieure (au côté) et intérieure
    outer = np.abs(np.abs(l_a) - np.pi) * l_r
    inner = np.abs(l_a) * l_r
    for dd, dbl in ((outer, True), (inner, False)):
        dd = np.where(on_leg, dd, side_arc if dbl else 1.0)
        h -= 0.0009 * _ridge(dd, 0.0012)
        st = _stitches(dd, Y, [0.003, 0.0065] if dbl else [0.003], 0.0035, 0.0005)
        h += 0.0003 * st
        thread = np.maximum(thread, st)
        shade *= 1.0 - 0.12 * _ridge(dd, 0.003)
        wear = np.maximum(wear, 0.5 * _ridge(dd - 0.002, 0.003))   # le pli de couture blanchit
    # ceinture (bande de 4 cm) et passants
    wb = (d < 0.038) & (by > waist_y - 0.06)
    h += 0.0012 * wb * smooth(0.038, 0.034, d) - 0.0008 * _ridge(d - 0.038, 0.0012) * (by > waist_y - 0.06)
    st = _stitches(np.abs(d - 0.0335), ta * tr, [0.0, 0.004], 0.0035, 0.0005) * (by > waist_y - 0.06)
    thread = np.maximum(thread, st)
    wear = np.maximum(wear, 0.4 * _ridge(d - 0.036, 0.003) * (by > waist_y - 0.06))
    for la in (0.55, 1.35, 2.3, -0.55, -1.35, -2.3, np.pi):
        loop = smooth(0.006, 0.0045, np.abs((ta - la)) * tr) * (d < 0.045) * (by > waist_y - 0.06)
        h += 0.0016 * loop
        shade *= 1.0 - 0.2 * smooth(0.0075, 0.006, np.abs(ta - la) * tr) * (1 - loop) * (d < 0.045) * (by > waist_y - 0.06)
    # braguette (J) devant
    fy0 = waist_y - 0.035
    fly_x = np.where(Y > hip_y - 0.03, np.abs(X - 0.012) , 1.0)
    fly = np.abs(fly_x - 0.022) * (Y > hip_y - 0.07) * (Y < fy0) * (Z > 0)
    curve = np.sqrt((X - 0.012) ** 2 + (Y - (hip_y - 0.04)) ** 2)
    jline = np.where(Y < hip_y - 0.035, np.abs(curve - 0.022) + 1.0 * (X < 0.012), fly)
    jline = np.where((Z > 0) & (np.abs(ta) < 0.8), jline, 1.0)
    h -= 0.0006 * _ridge(jline, 0.001)
    st = _stitches(jline, Y + X, [0.0], 0.0035, 0.0005)
    thread = np.maximum(thread, st * (Y < fy0))
    shade *= 1.0 - 0.25 * _ridge(np.where((Z > 0) & (np.abs(ta) < 0.4), np.abs(X - 0.002), 1.0), 0.0015) * (Y > hip_y - 0.08) * (Y < fy0)
    # poches avant : ouverture en arc du haut de la ceinture vers la hanche
    for sx in (1, -1):
        cx, cy = sx * 0.155, waist_y - 0.035
        rr = np.sqrt(((X - cx) / 0.085) ** 2 + ((Y - cy) / 0.075) ** 2)
        frontp = (Z > 0) & (np.abs(ta) < 1.35) & (sx * X > 0.04) & (Y < cy) & (Y > hip_y - 0.12)
        arc = np.abs(rr - 1.0) * 0.08 + (1 - frontp) * 1.0
        h -= 0.0012 * _ridge(arc, 0.0015) ; h += 0.0006 * (rr > 1.0) * frontp * smooth(0.0, 0.01, arc)
        st = _stitches(arc - 0.005, X + Y, [0.0], 0.0035, 0.0005)
        thread = np.maximum(thread, st)
        shade *= 1.0 - 0.35 * _ridge(arc, 0.002)
        wear = np.maximum(wear, 0.5 * _ridge(arc - 0.003, 0.003))
    # poches arrière : pentagones sur les fesses
    for sx in (1, -1):
        back = (np.abs(ta) > 2.0)
        cx = sx * 0.085
        u = (X - cx); v = Y - (waist_y - 0.1)
        bound = np.maximum(np.abs(u) / 0.07, np.where(v > 0, v / 0.055, -v / (0.075 - 0.4 * np.abs(u))))
        edge = np.abs(bound - 1.0) * 0.06 + (1 - back) * 1.0
        h += 0.0009 * (bound < 1.0) * back - 0.0007 * _ridge(edge, 0.0012)
        st = _stitches(edge - 0.002, X + Y, [0.0], 0.0035, 0.0005)
        thread = np.maximum(thread, st)
        shade *= 1.0 - 0.2 * _ridge(edge, 0.002)
        wear = np.maximum(wear, 0.45 * _ridge(edge, 0.0025))
    # plis : moustaches à l'aine, creux derrière le genou, tassement à la cheville
    whisk = np.zeros(len(P))
    for sx in (1, -1):
        u = sx * X - 0.04; v = (hip_y - 0.03) - Y
        ang = np.arctan2(v, u)
        rr = np.sqrt(u * u + v * v)
        wk = (0.5 + 0.5 * np.cos(ang * 22 + 2 * noise)) ** 6 * smooth(0.02, 0.05, rr) * smooth(0.16, 0.08, rr)
        wk *= (Z > 0) * (np.abs(ta) < 1.2) * (sx * X > 0) * (ang > -0.2) * (ang < 1.2)
        whisk = np.maximum(whisk, wk)
    h -= 0.0006 * whisk
    wear = np.maximum(wear, 0.55 * whisk)
    knee = np.exp(-((l_s - knee_s) / 0.06) ** 2)
    back_k = smooth(1.3, 0.3, np.abs(l_a))
    fold_k = np.sin(l_s * 2 * np.pi / 0.03 + 3 * noise) * knee * on_leg
    h += 0.0013 * fold_k * (0.15 + 0.85 * back_k)
    shade *= 1.0 - 0.15 * np.clip(-fold_k, 0, 1)
    stack = np.sin(l_s * 2 * np.pi / 0.04 + 3 * noise + l_a) * smooth(leg_len - 0.25, leg_len - 0.06, l_s) * on_leg
    h += 0.0018 * stack
    shade *= 1.0 - 0.15 * np.clip(-stack, 0, 1)
    wear = np.maximum(wear, 0.35 * np.clip(stack, 0, 1))
    # usure : devant des cuisses et genoux plus clairs
    thigh = smooth(0.0, 0.15, l_s) * smooth(knee_s + 0.1, knee_s - 0.1, l_s) * smooth(1.6, 0.2, np.abs(np.abs(l_a) - np.pi * 0.5) + 0.0) * on_leg
    front_leg = (Z > np.interp(Y, B.ys, B.zc) - 0.0)
    wear = np.maximum(wear, (0.55 * thigh * front_leg + 0.3 * knee * front_leg) * (0.7 + 0.3 * noise))
    # ourlet en bas
    hem = by < hip_y - 0.3
    h += 0.0012 * (d < 0.018) * hem - 0.0006 * _ridge(d - 0.018, 0.001) * hem
    thread = np.maximum(thread, _stitches(np.abs(d - 0.015), l_a * l_r, [0.0], 0.0035, 0.0005) * hem)
    shade *= 1.0 - 0.25 * smooth(0.006, 0.0, d)
    finish("cloth_jeans", h, shade, thread, np.clip(wear, 0, 1), spec, sel)

    # ---- gilet (jaune / street medic) : bandes réfléchissantes, biais en bordure, croix
    sel = tris["Vest"][tri]
    d, by, bx = border_dist(tris["Vest"])
    h = 0.0002 * noise; shade = np.ones(len(P)); bands = zero.copy(); cross = zero.copy()
    for yb in (hip_y + 0.07, hip_y + 0.22):
        bd_ = smooth(0.026, 0.024, np.abs(Y - yb))
        bands = np.maximum(bands, bd_)
        h += 0.0004 * bd_ - 0.0005 * _ridge(np.abs(Y - yb) - 0.025, 0.001)
    binding = smooth(0.012, 0.010, d)
    h += 0.0008 * binding
    shade *= 1.0 - 0.25 * smooth(0.005, 0.0, d)
    # croix rouge : dans le dos (grande) et sur la poitrine gauche (petite)
    def cross_at(cx, cy, s, mask):
        u, v = np.abs(X - cx), np.abs(Y - cy)
        return ((u < s) & (v < s * 0.33) | (u < s * 0.33) & (v < s)) * mask
    cross = np.maximum(cross, cross_at(0.0, hip_y + 0.31, 0.075, np.abs(ta) > 2.3))
    cross = np.maximum(cross, cross_at(0.1, hip_y + 0.3, 0.03, (np.abs(ta) < 1.0) & (X > 0)))
    # bande « velcro » d'ouverture devant
    vel = smooth(0.012, 0.009, np.where(np.abs(ta) < 1.0, np.abs(X), 1.0))
    h += 0.0005 * vel
    finish("cloth_vest", h, shade, binding * 1.0, bands, cross, sel)


# ----------------------------------------------------------------------------- cheveux
def write_hair_textures(out, n=512):
    """Mèches : RGB = variation de teinte/ombre entre les mèches, A = couverture (pointes effilées)
    pour l'alpha-coverage. L'axe V suit la mèche (racine en haut)."""
    rng = np.random.default_rng(11)
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / n
    img = np.zeros((n, n, 4))
    shade = np.zeros((n, n)); cov = np.zeros((n, n))
    strands = 900
    for _ in range(strands):
        x0 = rng.random()
        wid = rng.uniform(0.6, 1.6) / n
        tip = rng.uniform(0.75, 1.0)
        wav = rng.uniform(0.002, 0.008)
        ph = rng.random() * 6.28
        xc = (x0 + wav * np.sin(yy * 12 + ph)) % 1.0
        dx = np.abs(((xx - xc) + 0.5) % 1.0 - 0.5)
        taper = smooth(tip, tip - 0.25, yy)
        a = smooth(wid * (0.4 + 0.6 * taper), 0.0, dx) * taper
        cov = np.maximum(cov, a)
        shade = np.maximum(shade, a * rng.uniform(0.55, 1.0))
    base = 0.65 + 0.35 * tile_noise(n, 30, 120, 12)[..., None] * 0.3
    img[..., :3] = np.clip(base * (0.55 + 0.45 * shade[..., None]), 0, 1)
    img[..., 3] = np.clip(cov * 1.3, 0, 1)
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(out, "hair_strands.png"))
    # normales de mèches (rainures verticales)
    hgt = tile_noise(n, 40, 200, 13)
    hgt = np.repeat(hgt[:1, :], n, 0) * 0.7 + tile_noise(n, 60, 250, 14) * 0.1
    Image.fromarray((height_to_normal(hgt, 1.2) * 255).astype(np.uint8)).save(os.path.join(out, "hair_strands_n.png"))
