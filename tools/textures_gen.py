"""Textures procédurales : peau (cuite sur l'UV du corps) et tissus (tileables)."""
import numpy as np
from PIL import Image

SIZE = 2048


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def hash3(ix, iy, iz):
    h = (ix * 374761393 + iy * 668265263 + iz * 1274126177) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise3(p, freq):
    q = p * freq
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out


def fbm3(p, base=30.0, octaves=4):
    s, a, tot = 0, 1.0, 0
    for o in range(octaves):
        s = s + a * vnoise3(p, base * (2 ** o))
        tot += a
        a *= 0.5
    return s / tot


def rasterize(Pb, Nb, TV, TT, VT):
    """Renvoie (px_index, pos, nrm) pour chaque texel couvert."""
    idx_l, pos_l, nrm_l = [], [], []
    seen = np.zeros(SIZE * SIZE, dtype=bool)
    uv = np.stack([VT[:, 0] * SIZE, (1.0 - VT[:, 1]) * SIZE], 1)
    for t in range(len(TV)):
        a, b, c = uv[TT[t, 0]], uv[TT[t, 1]], uv[TT[t, 2]]
        x0, x1 = int(np.floor(min(a[0], b[0], c[0]))) - 1, int(np.ceil(max(a[0], b[0], c[0]))) + 1
        y0, y1 = int(np.floor(min(a[1], b[1], c[1]))) - 1, int(np.ceil(max(a[1], b[1], c[1]))) + 1
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, SIZE), min(y1, SIZE)
        if x1 <= x0 or y1 <= y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / d
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / d
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        w0, w1, w2 = w0[m], w1[m], w2[m]
        pid = (ys[m].astype(int) * SIZE + xs[m].astype(int))
        keep = ~seen[pid]
        if not keep.any():
            continue
        pid, w0, w1, w2 = pid[keep], w0[keep], w1[keep], w2[keep]
        seen[pid] = True
        v = TV[t]
        pos = w0[:, None] * Pb[v[0]] + w1[:, None] * Pb[v[1]] + w2[:, None] * Pb[v[2]]
        nrm = w0[:, None] * Nb[v[0]] + w1[:, None] * Nb[v[1]] + w2[:, None] * Nb[v[2]]
        idx_l.append(pid); pos_l.append(pos); nrm_l.append(nrm)
    return np.concatenate(idx_l), np.concatenate(pos_l), np.concatenate(nrm_l), seen


# repères de la tête de référence (homme « male_a », hauteurs sans semelle)
E_REF = np.array([0.0, 1.692, 0.129])   # milieu des yeux
M_REF_Y = 1.6285                         # centre des lèvres


def to_ref(P, ctx):
    """Ramène des points du personnage dans le repère de la tête de référence (traits du visage)."""
    E = ctx["eye"]
    s = ctx["hscale"]
    Q = E_REF + (P - E) / s
    # sous les yeux : on recale verticalement sur la bouche réelle
    below = P[:, 1] < E[1]
    k = (M_REF_Y - E_REF[1]) / (ctx["mouth_y"] - E[1])
    Q[below, 1] = E_REF[1] + (P[below, 1] - E[1]) * k
    return Q


def skin_color(P, N, ctx):
    Pv = P
    P = to_ref(P, ctx)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    n1 = fbm3(Pv, 6.0, 3)
    n2 = fbm3(Pv + 11.3, 90.0, 3)
    base = np.array(ctx["skin"])
    col = base[None, :] * np.ones((len(P), 1))
    col *= (0.93 + 0.14 * n1)[:, None]
    dark = 1.0 - float(np.mean(base))  # peaux foncées : rougeurs plus discrètes
    def blob(Q, c, r, amt):
        d = np.sqrt(((Q - np.array(c)) ** 2).sum(1))
        return amt * smooth(r, 0.0, d)
    red = 0
    for sx in (1, -1):
        red = red + blob(P, (sx * 0.045, 1.655, 0.125), 0.035, 0.35)
        red = red + blob(P, (sx * 0.080, 1.675, 0.040), 0.030, 0.55)
    for c in ctx["elbows"] + ctx["knees"]:
        red = red + blob(Pv, c, 0.05, 0.3)
    red = red + blob(P, (0.0, 1.655, 0.170), 0.022, 0.45)
    red *= (1.0 - dark * 0.6)
    col = col * (1 - red[:, None] * 0.25) + red[:, None] * np.array([0.30, 0.04, 0.03])[None, :] * 0.35
    col[:, 1] *= 1 - 0.1 * red
    fr = smooth(0.78, 0.86, vnoise3(P + 5.5, 420.0)) * smooth(1.58, 1.66, y) * (z > 0.0) * ctx.get("freckles", 1.0)
    col *= (1 - 0.07 * fr)[:, None]
    col *= (0.97 + 0.06 * n2)[:, None]

    head_zone = (P[:, 1] > 1.5) & (Pv[:, 1] > ctx["neck_y"])
    face = (N[:, 2] > -0.2) & (z > 0.08) & (y > 1.55) & (y < 1.80) & head_zone
    # lèvres
    rx, ry = 0.0235, 0.0105 * ctx.get("lip_h", 1.0)
    q = (x / rx) ** 2 + ((y - M_REF_Y) / ry) ** 2
    lip = smooth(1.0, 0.7, q) * face * (z > 0.12)
    lip_col = np.array(ctx["lip"])
    col = col * (1 - 0.85 * lip[:, None]) + lip_col[None, :] * 0.85 * lip[:, None]
    mline = np.exp(-((y - (M_REF_Y - 0.0008)) / 0.0007) ** 2) * smooth(0.026, 0.020, ax) * face
    col *= (1 - 0.55 * mline)[:, None]
    hair_col = np.array(ctx["hair"])
    # sourcils
    brow = 0
    bth = ctx.get("brow", 1.0)
    for sx in (1, -1):
        t = np.clip((ax - 0.011) / 0.043, 0, 1)
        yb = 1.7185 + 0.010 * np.sin(np.pi * np.clip(t * 0.85, 0, 1)) - 0.004 * t
        th = (0.0040 + 0.0042 * (1 - t)) * bth
        inb = (sx * x > 0.011) & (ax < 0.056)
        strokes = 0.55 + 0.45 * vnoise3(P * np.array([1.0, 0.2, 1.0]) + 3.1, 700.0)
        brow = brow + inb * smooth(th, th * 0.55, np.abs(y - yb)) * strokes
    brow = np.clip(brow, 0, 1) * face * (z > 0.10)
    col = col * (1 - 0.88 * brow[:, None]) + hair_col[None, :] * 0.88 * brow[:, None]
    # barbe (de naissante à fournie)
    bd = ctx.get("beard", 0.0)
    if bd > 0:
        beard = face * ((ax < 0.075) & (y < 1.66)) * (z > 0.045)
        dens = np.clip(smooth(1.665, 1.60, y) * (1 - lip) * smooth(0.078, 0.06, ax), 0, 1)
        dots = smooth(0.52 - 0.25 * bd, 0.64 - 0.2 * bd, vnoise3(P + 9.9, 1500.0))
        stub = dens * dots * (beard | (face & (y < 1.60)))
        amt = 0.33 + 0.45 * max(0.0, bd - 0.5)
        col = col * (1 - amt * stub[:, None]) + hair_col[None, :] * amt * stub[:, None]
    # cheveux sur le crâne
    hy = 1.775 - 0.115 * np.clip((0.16 - z) / 0.2, 0, 1) - 0.045 * np.clip((ax - 0.04) / 0.04, 0, 1)
    ear = np.sqrt((ax - 0.082) ** 2 + (y - 1.675) ** 2 + (z - 0.04) ** 2)
    hair = smooth(hy - 0.006, hy + 0.006, y) * smooth(0.032, 0.040, ear) * (y < 1.83) * head_zone
    strands = 0.6 + 0.4 * vnoise3(P * np.array([1.0, 3.0, 1.0]) + 1.7, 500.0)
    hair_tex = hair_col[None, :] * (0.6 + 0.8 * strands)[:, None]
    col = col * (1 - 0.95 * hair[:, None]) + hair_tex * 0.95 * hair[:, None]
    return np.clip(col, 0, 1)


def bake_skin(path, Pb, Nb, TV, TT, VT, ctx, size=2048):
    global SIZE
    SIZE = size
    pid, pos, nrm, seen = rasterize(Pb, Nb, TV, TT, VT)
    col = skin_color(pos, nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9), ctx)
    img = np.zeros((SIZE * SIZE, 3), dtype=np.float32)
    img[pid] = col
    img = img.reshape(SIZE, SIZE, 3)
    cov = seen.reshape(SIZE, SIZE)
    # dilatation pour éviter les coutures
    for _ in range(8):
        m = ~cov
        acc = np.zeros_like(img); cnt = np.zeros((SIZE, SIZE))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(img, (dy, dx), (0, 1)); sc = np.roll(cov, (dy, dx), (0, 1))
            acc += sh * sc[..., None]; cnt += sc
        fill = m & (cnt > 0)
        img[fill] = acc[fill] / cnt[fill][:, None]
        cov = cov | fill
    img[~cov] = ctx["skin"]
    Image.fromarray((img * 255).astype(np.uint8)).save(path)


# ----------------------------------------------------------------------- tissus
def tile_noise(n, cutoff_lo, cutoff_hi, seed):
    rng = np.random.default_rng(seed)
    f = np.fft.rfft2(rng.standard_normal((n, n)))
    ky = np.fft.fftfreq(n)[:, None] * n
    kx = np.fft.rfftfreq(n)[None, :] * n
    r = np.sqrt(kx ** 2 + ky ** 2)
    f *= ((r >= cutoff_lo) & (r <= cutoff_hi)) / np.maximum(r, 1) ** 0.6
    h = np.fft.irfft2(f, s=(n, n))
    return (h - h.mean()) / (h.std() + 1e-9)


def to_normal(h, k):
    dx = np.roll(h, -1, 1) - np.roll(h, 1, 1)
    dy = np.roll(h, -1, 0) - np.roll(h, 1, 0)
    n = np.stack([-dx * k, dy * k, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def write_cloth_textures(out):
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    # polaire (sweat) : mailles en V + duvet
    row = (yy / n * 32) % 1.0
    col_ = (xx / n * 32)
    v = np.abs(((col_ % 1.0) - 0.5) * 2)
    knit = np.sin(row * np.pi) * (0.6 + 0.4 * np.cos((col_ + row * 0.5) * 2 * np.pi))
    fuzz = tile_noise(n, 20, 70, 1)
    h = knit * 0.8 + fuzz * 0.5
    Image.fromarray(to_normal(h, 0.9)).save(out + "/knit_n.png")
    # jean : sergé
    tw = np.sin(((xx + yy) / n * 40) * 2 * np.pi) * 0.5 + 0.5
    thr = tile_noise(n, 30, 120, 3)
    h = tw * 1.0 + thr * 0.35 + tile_noise(n, 2, 10, 4) * 0.5
    Image.fromarray(to_normal(h, 1.1)).save(out + "/denim_n.png")
    a = 0.5 + 0.5 * tw
    base = np.array([0.075, 0.12, 0.23])[None, None, :]
    lt = np.array([0.20, 0.27, 0.40])[None, None, :]
    wear = np.clip(0.5 + 0.18 * tile_noise(n, 2, 7, 5), 0, 1)[..., None]
    alb = base * (0.7 + 0.5 * a[..., None]) * (1 - wear * 0.0) + lt * (0.35 * a[..., None] * wear)
    Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(out + "/denim_a.png")
    # côtes du bonnet
    rib = np.sin((xx / n * 32) * 2 * np.pi) * 0.6 + np.sin((yy / n * 64) * 2 * np.pi) * 0.1
    h = rib + tile_noise(n, 30, 100, 6) * 0.2
    Image.fromarray(to_normal(h, 1.0)).save(out + "/rib_n.png")
    # grain de peau
    m = 1024  # pores à l'échelle de l'UV du corps (pas de répétition)
    h = tile_noise(m, 180, 480, 7) + 0.6 * tile_noise(m, 40, 120, 8)
    Image.fromarray(to_normal(h, 0.8)).save(out + "/skin_n.png")
    # bandana / keffieh (motif en niveaux de gris, teinté à l'exécution)
    g1 = (np.sin(xx / n * 2 * np.pi * 24) > 0.55) | (np.sin(yy / n * 2 * np.pi * 24) > 0.55)
    g2 = ((np.floor(xx / n * 48) + np.floor(yy / n * 48)) % 2 == 0) & ~g1
    pat = np.where(g1, 0.12, np.where(g2, 0.95, 0.75))
    pat = pat * (0.9 + 0.1 * tile_noise(n, 40, 160, 15))
    Image.fromarray((np.clip(np.stack([pat, pat, pat], -1), 0, 1) * 255).astype(np.uint8)).save(out + "/bandana_a.png")
    # cheveux : mèches fines
    h = np.tile(tile_noise(n, 60, 250, 16), (1, 1))
    h = np.repeat(h[:, ::8], 8, axis=1)[:, :n] * 0.4 + tile_noise(n, 80, 250, 17) * 0.15
    Image.fromarray(to_normal(h, 1.2)).save(out + "/hair_n.png")
    # nylon (doudoune, sac)
    h = np.sin((xx + yy) / n * 2 * np.pi * 90) * 0.15 + tile_noise(n, 40, 200, 18) * 0.25
    Image.fromarray(to_normal(h, 0.6)).save(out + "/nylon_n.png")
    # toile des baskets
    cv = np.sin(xx / n * 150 * 2 * np.pi) * np.sin(yy / n * 150 * 2 * np.pi)
    h = cv * 0.5 + tile_noise(n, 20, 80, 9) * 0.3
    Image.fromarray(to_normal(h, 0.8)).save(out + "/canvas_n.png")
