"""Textures des immeubles parisiens : pierre de taille, enduit, brique, ardoise, zinc (tileables, teinte neutre :
la couleur de chaque immeuble vient des couleurs de sommets), intérieurs de fenêtres (atlas), garde-corps en fer
forgé (alpha), persiennes, rideaux de fer tagués, carrelage de boutique.
Usage : python3 tools/build_paris_textures.py  ->  assets/paris/*.png"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "assets/paris"
rng = np.random.default_rng(7)


def tile_noise(n, freqs, seed):
    """Bruit tileable (somme d'octaves de bruit blanc filtré par FFT)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((n, n))
    for f, amp in freqs:
        w = r.standard_normal((n, n))
        F = np.fft.fft2(w)
        ky = np.fft.fftfreq(n)[:, None]
        kx = np.fft.fftfreq(n)[None, :]
        k = np.sqrt(kx * kx + ky * ky) * n
        F *= np.exp(-(k / f) ** 2)
        a = np.real(np.fft.ifft2(F))
        a = (a - a.mean()) / (a.std() + 1e-9)
        acc += a * amp
    return acc


def to_normal(h, strength):
    gy, gx = np.gradient(h)
    nx, ny = -gx * strength, -gy * strength
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / l, ny / l, nz / l], -1)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(a, name):
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/{name}")


def stone():
    # 1024 px = 2 m de façade : assises de 0,5 m, joints verticaux décalés tous les ~1 m
    n = 1024
    y, x = np.mgrid[0:n, 0:n] / n * 2.0
    course = np.floor(y / 0.5)
    off = (course % 2) * 0.5
    jx = np.abs(((x + off) % 1.0) - 0.5)          # distance au joint vertical (au milieu de la pierre = 0.5)
    jy = np.abs((y % 0.5) - 0.25)
    joint_v = np.clip((jx - 0.4955) / 0.0035, 0, 1)
    joint_h = np.clip((jy - 0.2455) / 0.004, 0, 1)
    joint = np.maximum(joint_v, joint_h)
    fine = tile_noise(n, [(220, 0.5), (90, 0.35), (30, 0.6)], 1)
    blot = tile_noise(n, [(6, 1.0), (3, 0.8)], 2)
    # teinte par pierre (léger écart entre blocs)
    bid = (np.floor((x + off) / 1.0) * 7 + course * 13) % 5
    tint = 1.0 + (bid - 2) * 0.012
    base = np.array([0.95, 0.93, 0.89])        # neutre : la teinte vient des sommets
    bid2 = (np.floor((x + off) / 1.0) * 5 + course * 11) % 7
    lum = 1.0 + fine * 0.03 + blot * 0.018 + (bid2 - 3) * 0.014
    col = base[None, None, :] * (lum * tint)[..., None]
    # salissures sous les joints horizontaux (coulures de pluie)
    drip = np.clip(1.0 - (y % 0.5) / 0.18, 0, 1) * np.clip(tile_noise(n, [(40, 1.0)], 3) * 0.5 + 0.5, 0, 1) * 0.06
    col *= (1.0 - drip)[..., None]
    col = col * (1.0 - joint * 0.5)[..., None]
    save(col, "stone_a.png")
    h = fine * 0.06 - joint * 1.6
    Image.fromarray(to_normal(h, 2.2)).save(f"{OUT}/stone_n.png")


def zinc():
    # 512 px = 1,5 m de toit : joints debout tous les 0,5 m, plaques légèrement ondulées
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n * 1.5
    seam = np.exp(-(((x % 0.5) - 0.25) / 0.012) ** 2)
    sheet = tile_noise(n, [(60, 0.5), (12, 0.6)], 4)
    streak = tile_noise(n, [(3, 1.0)], 5)
    base = np.array([0.43, 0.47, 0.53])
    lum = 1.0 + sheet * 0.03 + streak * 0.05 + seam * 0.18
    col = base[None, None, :] * lum[..., None]
    save(col, "zinc_a.png")
    h = seam * 1.0 + sheet * 0.05
    Image.fromarray(to_normal(h, 6.0)).save(f"{OUT}/zinc_n.png")


def tiles():
    # carrelage de boutique en damier noir et blanc (1 m = 512 px, carreaux de 25 cm)
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n
    chk = ((np.floor(x * 4) + np.floor(y * 4)) % 2)
    g = np.minimum(np.abs((x * 4) % 1 - 0.5), np.abs((y * 4) % 1 - 0.5))
    grout = np.clip((g - 0.485) / 0.01, 0, 1)
    v = 0.12 + chk * 0.72
    v = v * (1.0 + tile_noise(n, [(80, 1.0)], 6) * 0.03)
    v = v * (1.0 - grout * 0.4)
    save(np.stack([v, v * 0.985, v * 0.96], -1), "tiles_a.png")


def plaster():
    # enduit taloché : 1024 px = 2 m ; grain, reprises, fines fissures, auréoles d'humidité
    n = 1024
    fine = tile_noise(n, [(300, 0.6), (120, 0.4)], 11)
    patch = tile_noise(n, [(5, 1.0), (10, 0.5)], 12)
    stain = np.clip(tile_noise(n, [(3, 1.0)], 13), 0, None)
    crack = np.abs(tile_noise(n, [(14, 1.0), (40, 0.3)], 14))
    crack = np.clip((0.035 - crack) / 0.035, 0, 1) * (tile_noise(n, [(4, 1.0)], 15) > 0.8)
    lum = 0.93 + fine * 0.025 + patch * 0.03 - stain * 0.05 - crack * 0.25
    save(np.stack([lum, lum * 0.985, lum * 0.965], -1), "plaster_a.png")
    h = fine * 0.3 + patch * 0.05 - crack * 0.8
    Image.fromarray(to_normal(h, 1.6)).save(f"{OUT}/plaster_n.png")


def brick():
    # briques 22 x 6,5 cm, joints de 1 cm : 1024 px = 1,76 m (8 briques) x 1,76 m (24 rangs)
    n = 1024
    y, x = np.mgrid[0:n, 0:n] / n
    rows = 24
    r = np.floor(y * rows)
    off = (r % 2) * 0.5
    bx = (x * 8 + off) % 1.0
    by = (y * rows) % 1.0
    mortar = np.maximum(np.clip((np.abs(bx - 0.5) - 0.455) / 0.02, 0, 1), np.clip((np.abs(by - 0.5) - 0.36) / 0.06, 0, 1))
    bidx = np.floor(x * 8 + off) + r * 17
    rnd = np.sin(bidx * 12.9898) * 43758.5453
    rnd = rnd - np.floor(rnd)
    fine = tile_noise(n, [(200, 0.6), (60, 0.4)], 21)
    base = np.stack([0.62 + rnd * 0.14, 0.3 + rnd * 0.08, 0.22 + rnd * 0.05], -1)
    burnt = (rnd > 0.88)[..., None] * np.array([-0.2, -0.1, -0.06])
    col = (base + burnt) * (1.0 + fine * 0.05)[..., None]
    mcol = np.array([0.7, 0.67, 0.62]) * (1.0 + fine * 0.04)[..., None]
    col = col * (1 - mortar[..., None]) + mcol * mortar[..., None]
    save(col, "brick_a.png")
    h = (1 - mortar) * 0.6 + fine * 0.1
    Image.fromarray(to_normal(h, 3.0)).save(f"{OUT}/brick_n.png")


def slate():
    # ardoises 30 x 20 cm (pureau 10 cm) : 512 px = 1,2 m
    n = 512
    y, x = np.mgrid[0:n, 0:n] / n * 1.2
    rows = np.floor(y / 0.1)
    off = (rows % 2) * 0.15
    sx = ((x + off) % 0.3) / 0.3
    sy = (y % 0.1) / 0.1
    edge = np.clip((sy - 0.86) / 0.14, 0, 1)
    gap = np.clip((np.abs(sx - 0.5) - 0.48) / 0.02, 0, 1)
    sid = np.floor((x + off) / 0.3) * 3 + rows * 7
    rnd = np.sin(sid * 78.233) * 43758.5453
    rnd = rnd - np.floor(rnd)
    fine = tile_noise(n, [(120, 1.0)], 31)
    lum = 0.3 + rnd * 0.06 + fine * 0.012 - edge * 0.1 - gap * 0.12
    save(np.stack([lum * 0.95, lum * 0.98, lum * 1.08], -1), "slate_a.png")
    h = sy * 0.6 - gap + fine * 0.05
    Image.fromarray(to_normal(h, 3.0)).save(f"{OUT}/slate_n.png")


def windows():
    # atlas d'intérieurs vus à travers la vitre : 8 colonnes x 2 rangées, cellules 192 x 384 (1 x 2 m)
    W, H, C, R = 192, 384, 8, 2
    img = np.zeros((H * R, W * C, 3))
    r = np.random.default_rng(41)
    y, x = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    walls = [(0.85, 0.78, 0.66), (0.75, 0.8, 0.82), (0.88, 0.84, 0.76), (0.7, 0.62, 0.55), (0.82, 0.86, 0.78), (0.9, 0.88, 0.85),
             (0.6, 0.55, 0.62), (0.86, 0.72, 0.6)]
    curt = [(0.62, 0.12, 0.12), (0.88, 0.85, 0.78), (0.2, 0.3, 0.5), (0.55, 0.5, 0.35), (0.3, 0.45, 0.32), (0.9, 0.9, 0.9), (0.45, 0.3, 0.5), (0.8, 0.6, 0.3)]
    for k in range(C * R):
        cx, cy = k % C, k // C
        wall = np.array(walls[k % len(walls)])
        # fond : mur, plafond plus sombre, sol, halo de lampe
        cell = np.ones((H, W, 3)) * wall
        cell *= (0.55 + 0.45 * np.clip(1.0 - np.abs(y - 0.45) * 1.4, 0, 1))[..., None]
        floor = y > 0.82
        cell[floor] = np.array([0.35, 0.24, 0.16]) * 0.8
        lamp = np.exp(-(((x - r.uniform(0.3, 0.7)) / 0.25) ** 2 + ((y - 0.15) / 0.12) ** 2))
        cell += lamp[..., None] * np.array([0.5, 0.42, 0.28])
        # meubles en silhouette
        kind = k % 4
        if kind == 0:   # bibliothèque
            x0 = r.uniform(0.05, 0.4)
            m = (x > x0) & (x < x0 + 0.45) & (y > 0.35) & (y < 0.85)
            cell[m] = np.array([0.25, 0.16, 0.1])
            for j in range(5):
                yy = 0.38 + j * 0.095
                mm = m & (y > yy) & (y < yy + 0.07)
                books = (np.sin(x * 260 + j * 3) > -0.2)
                cell[mm & books] = np.array([0.6, 0.25, 0.2]) * r.uniform(0.6, 1.2)
        elif kind == 1:  # tableau + lampadaire
            x0 = r.uniform(0.2, 0.5)
            m = (x > x0) & (x < x0 + 0.3) & (y > 0.32) & (y < 0.47)
            cell[m] = np.array([0.3, 0.42, 0.55]) * 0.8
            cell[(np.abs(x - x0 - 0.15) < 0.17) & (np.abs(y - 0.395) < 0.085) & ~m] = np.array([0.6, 0.48, 0.2])
        elif kind == 2:  # plante verte
            px = r.uniform(0.3, 0.7)
            leaf = (((x - px) / 0.18) ** 2 + ((y - 0.6) / 0.16) ** 2) < 1.0
            leaf &= np.sin(x * 70) * np.sin(y * 50) > -0.6
            cell[leaf] = np.array([0.15, 0.35, 0.15])
            cell[(np.abs(x - px) < 0.07) & (y > 0.72) & (y < 0.82)] = np.array([0.6, 0.35, 0.25])
        # rideaux : deux pans plissés (ou voilage)
        cc = np.array(curt[(k * 3) % len(curt)])
        style = k % 3
        folds = 0.75 + 0.25 * np.sin(x * 95)
        if style == 0:
            m = (x < 0.2) | (x > 0.8)
            cell[m] = (cc * folds[..., None])[m]
        elif style == 1:
            sheer = 0.55 * (0.8 + 0.2 * np.sin(x * 120))
            cell = cell * (1 - sheer[..., None]) + np.array([0.95, 0.93, 0.9]) * sheer[..., None]
        else:   # store à lames à moitié baissé
            m = (y < 0.45) & ((y * 60) % 1.0 < 0.75)
            cell[m] = np.array([0.88, 0.86, 0.8]) * 0.8
        cell *= (1.0 + tile_noise(256, [(30, 1.0)], 50 + k)[:H % 256 or 256, :W][:H, :W][..., None] * 0.0) if False else 1.0
        img[cy * H:(cy + 1) * H, cx * W:(cx + 1) * W] = np.clip(cell, 0, 1)
    save(img, "win_atlas.png")


def railings():
    # garde-corps en fer forgé, 3 motifs (rangées), chaque cellule = 1 m x 1 m (512 x 512), canal alpha
    S = 1024     # suréchantillonnage puis réduction : traits lissés
    rows = []
    for motif in range(3):
        im = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(im)
        t = S // 64
        d.rectangle([0, int(S * 0.02), S, int(S * 0.02) + t * 2], fill=255)      # main courante
        d.rectangle([0, int(S * 0.94), S, int(S * 0.94) + t * 2], fill=255)      # lisse basse
        d.rectangle([0, int(S * 0.2), S, int(S * 0.2) + t], fill=255)
        d.rectangle([0, int(S * 0.8), S, int(S * 0.8) + t], fill=255)
        if motif == 0:      # barreaux + rinceaux en S
            for i in range(8):
                xx = int((i + 0.5) * S / 8)
                d.rectangle([xx - t // 2, int(S * 0.2), xx + t // 2, int(S * 0.8)], fill=255)
            for i in range(4):
                cx = int((i + 0.5) * S / 4)
                d.arc([cx - S // 10, int(S * 0.24), cx + S // 10, int(S * 0.5)], 180, 360, fill=255, width=t)
                d.arc([cx - S // 10, int(S * 0.5), cx + S // 10, int(S * 0.76)], 0, 180, fill=255, width=t)
                d.ellipse([cx - S // 32, int(S * 0.5) - S // 32, cx + S // 32, int(S * 0.5) + S // 32], outline=255, width=t)
        elif motif == 1:    # cercles entrelacés et losanges
            for i in range(4):
                cx = int((i + 0.5) * S / 4)
                rr = S // 8 + S // 40
                d.ellipse([cx - rr, int(S * 0.5) - rr, cx + rr, int(S * 0.5) + rr], outline=255, width=t)
                d.ellipse([cx - rr // 2, int(S * 0.5) - rr // 2, cx + rr // 2, int(S * 0.5) + rr // 2], outline=255, width=t)
                d.line([cx, int(S * 0.2), cx, int(S * 0.5) - rr], fill=255, width=t)
                d.line([cx, int(S * 0.5) + rr, cx, int(S * 0.8)], fill=255, width=t)
            for i in range(5):
                xx = int(i * S / 4)
                d.rectangle([xx - t // 2, int(S * 0.2), xx + t // 2, int(S * 0.8)], fill=255)
        else:               # balustres fins et frise de volutes en haut
            for i in range(16):
                xx = int((i + 0.5) * S / 16)
                d.rectangle([xx - t // 3, int(S * 0.2), xx + t // 3, int(S * 0.8)], fill=255)
            for i in range(8):
                cx = int((i + 0.5) * S / 8)
                d.arc([cx - S // 16, int(S * 0.05), cx + S // 16, int(S * 0.2)], 0, 180, fill=255, width=t)
            for i in range(8):
                xx = int((i + 0.5) * S / 8)
                d.polygon([(xx, int(S * 0.6)), (xx + S // 40, int(S * 0.5)), (xx, int(S * 0.4)), (xx - S // 40, int(S * 0.5))], outline=255)
        rows.append(im.resize((512, 512), Image.LANCZOS))
    a = np.concatenate([np.array(r) for r in rows], 0) / 255.0
    rgb = np.ones(a.shape + (3,)) * np.array([0.05, 0.05, 0.055])
    out = np.concatenate([rgb, a[..., None]], -1)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"{OUT}/railing_a.png")


def shutters():
    # persienne / volet à lames (neutre clair, teinté par sommet) : 256 x 512 = 0,6 x 1,2 m
    W, H = 256, 512
    y, x = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    slat = (y * 30) % 1.0
    lum = 0.55 + 0.45 * np.clip(slat * 1.4, 0, 1) - (slat > 0.9) * 0.4
    frame = (x < 0.07) | (x > 0.93) | (y < 0.035) | (y > 0.965) | (np.abs(y - 0.5) < 0.02)
    lum = np.where(frame, 0.9, lum) * (1.0 + tile_noise(256, [(60, 1.0)], 61)[np.arange(H) % 256][:, :W] * 0.03)
    save(np.stack([lum, lum, lum], -1), "shutter_a.png")


def rideaux():
    # rideaux de fer de boutiques fermées, 4 variantes tagguées (1 x 2 m chacune côte à côte : 512 x 1024 px)
    W, H = 512, 1024
    font_p = "assets/fonts/PermanentMarker-Regular.ttf"
    words = ["RÉSISTE", "LIBERTÉ", "ZAD", "AMOUR", "NO JUSTICE", "VIVE LA LUTTE", "RAGE", "PARIS"]
    r = np.random.default_rng(71)
    tiles_ = []
    for k in range(4):
        y = np.arange(H)[:, None] / H
        lam = (y * 90) % 1.0
        g = 0.52 + 0.18 * np.sin(lam * np.pi) + tile_noise(512, [(80, 1.0)], 80 + k)[np.arange(H) % 512][:, :W] * 0.03
        rust = np.clip(tile_noise(512, [(6, 1.0)], 90 + k)[np.arange(H) % 512][:, :W] - 1.2, 0, None) * 0.08
        rgb = np.stack([g + rust * 0.6, g - rust * 0.1, g - rust * 0.4], -1)
        rgb = np.broadcast_to(rgb, (H, W, 3)).copy()
        im = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
        d = ImageDraw.Draw(im)
        # graffitis : traits et mots
        for j in range(r.integers(1, 4)):
            col = tuple(int(c) for c in r.choice([[220, 30, 30], [20, 20, 25], [240, 240, 235], [40, 90, 220], [250, 200, 20], [230, 80, 190]]))
            word = str(r.choice(words))
            sz = int(r.uniform(60, 120))
            try:
                f = ImageFont.truetype(font_p, sz)
            except OSError:
                f = ImageFont.load_default()
            tx = Image.new("RGBA", (W * 2, sz * 2), (0, 0, 0, 0))
            ImageDraw.Draw(tx).text((10, 10), word, font=f, fill=col + (255,))
            tx = tx.rotate(float(r.uniform(-12, 12)), expand=True, resample=Image.BICUBIC)
            bb = tx.getbbox()
            if bb:
                tx = tx.crop(bb)
                if tx.width > W - 20:
                    tx = tx.resize((W - 20, int(tx.height * (W - 20) / tx.width)))
                im.paste(tx, (int(r.uniform(5, max(6, W - tx.width - 5))), int(r.uniform(H * 0.3, H * 0.85))), tx)
        tiles_.append(np.array(im)[..., :3] / 255.0)
    save(np.concatenate(tiles_, 1), "rideau_a.png")


stone()
zinc()
tiles()
plaster()
brick()
slate()
windows()
railings()
shutters()
rideaux()
print("textures écrites dans", OUT)
