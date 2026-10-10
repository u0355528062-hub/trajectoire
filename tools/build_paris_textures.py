"""Textures des immeubles parisiens (tileables) : pierre de taille calcaire, zinc des toits, carrelage de boutique.
Usage : python3 tools/build_paris_textures.py  ->  assets/paris/*.png"""
import numpy as np
from PIL import Image

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
    joint_v = np.clip((jx - 0.497) / 0.003, 0, 1)
    joint_h = np.clip((jy - 0.2465) / 0.0035, 0, 1)
    joint = np.maximum(joint_v, joint_h)
    fine = tile_noise(n, [(220, 0.5), (90, 0.35), (30, 0.6)], 1)
    blot = tile_noise(n, [(6, 1.0), (3, 0.8)], 2)
    # teinte par pierre (léger écart entre blocs)
    bid = (np.floor((x + off) / 1.0) * 7 + course * 13) % 5
    tint = 1.0 + (bid - 2) * 0.012
    base = np.array([0.86, 0.80, 0.69])
    lum = 1.0 + fine * 0.035 + blot * 0.045
    col = base[None, None, :] * (lum * tint)[..., None]
    # salissures sous les joints horizontaux (coulures de pluie)
    drip = np.clip(1.0 - (y % 0.5) / 0.18, 0, 1) * np.clip(tile_noise(n, [(40, 1.0)], 3) * 0.5 + 0.5, 0, 1) * 0.06
    col *= (1.0 - drip)[..., None]
    col = col * (1.0 - joint * 0.32)[..., None]
    save(col, "stone_a.png")
    h = fine * 0.15 + blot * 0.1 - joint * 1.6
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


stone()
zinc()
tiles()
print("textures écrites dans", OUT)
