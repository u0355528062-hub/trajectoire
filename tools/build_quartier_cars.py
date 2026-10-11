"""Textures des voitures garées et du parking : plaques d'immatriculation françaises (atlas), panneau « P »,
façade d'horodateur, marquages au sol (numéros de places, taches d'huile).
Usage : python3 tools/build_quartier_cars.py  ->  assets/quartier/*.png"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "assets/quartier"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1871)

FONT_PLATE = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_TXT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

EU_BLUE = (0, 51, 153)
STAR = (255, 204, 0)


def _stars(d, cx, cy, r, n=12, s=2.2):
    for k in range(n):
        a = 2 * np.pi * k / n
        x, y = cx + r * np.cos(a), cy + r * np.sin(a)
        d.ellipse([x - s, y - s, x + s, y + s], fill=STAR)


def plate(text, dept, w=512, h=112):
    """Plaque SIV : bande bleue « F » à gauche, numéro de département à droite."""
    im = Image.new("RGB", (w, h), (12, 12, 14))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([3, 3, w - 4, h - 4], 10, fill=(246, 246, 242))
    band = int(w * 0.085)
    for x0 in (3, w - 4 - band):
        d.rounded_rectangle([x0, 3, x0 + band, h - 4], 9, fill=EU_BLUE)
    d.rectangle([band - 6, 3, band + 3, h - 4], fill=EU_BLUE)
    d.rectangle([w - 4 - band - 3, 3, w - 4 - band + 6, h - 4], fill=EU_BLUE)
    _stars(d, 3 + band / 2, h * 0.32, band * 0.28, s=1.7)
    f = ImageFont.truetype(FONT_BOLD, int(h * 0.36))
    d.text((3 + band / 2, h * 0.74), "F", font=f, fill=(255, 255, 255), anchor="mm")
    # bande de droite : numéro de département sous un petit logo régional
    rx = w - 4 - band / 2
    d.ellipse([rx - band * 0.28, h * 0.16, rx + band * 0.28, h * 0.16 + band * 0.56], fill=(255, 255, 255))
    d.ellipse([rx - band * 0.18, h * 0.16 + band * 0.1, rx + band * 0.18, h * 0.16 + band * 0.46], fill=(200, 40, 40))
    fd = ImageFont.truetype(FONT_BOLD, int(h * 0.3))
    d.text((rx, h * 0.76), dept, font=fd, fill=(255, 255, 255), anchor="mm")
    fp = ImageFont.truetype(FONT_PLATE, int(h * 0.62))
    d.text((w / 2, h / 2 + 2), text, font=fp, fill=(18, 18, 20), anchor="mm")
    # usure : léger voile, poussière dans les coins
    a = np.asarray(im).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - xx), np.minimum(yy, h - yy)) / 18.0
    dirt = (1.0 - np.clip(edge, 0, 1)) * 0.18 * rng.uniform(0.4, 1.0)
    a = a * (1.0 - dirt[..., None]) + np.array([0.35, 0.3, 0.25]) * dirt[..., None]
    a *= rng.uniform(0.86, 1.0)
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def plates():
    letters = "ABCDEFGHJKLMNPQRSTVWXYZ"
    depts = ["75", "75", "75", "92", "93", "94", "91", "78", "77", "95", "69", "13", "33", "59", "75", "92", "44", "67"]
    atlas = Image.new("RGB", (1024, 1024), (20, 20, 22))
    for i in range(18):
        t = "%s%s-%03d-%s%s" % (letters[rng.integers(0, 23)], letters[rng.integers(0, 23)], rng.integers(1, 999),
                                 letters[rng.integers(0, 23)], letters[rng.integers(0, 23)])
        p = plate(t, depts[i])
        atlas.paste(p, ((i % 2) * 512, (i // 2) * 112))
    atlas.save(f"{OUT}/plates.png")


def sign_p():
    """Panneau « P » (bleu, lettre blanche) et panonceau « PARKING » en dessous (256 x 384)."""
    w, h = 256, 384
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 4, w - 5, w - 5], 26, fill=(250, 250, 250, 255))
    d.rounded_rectangle([12, 12, w - 13, w - 13], 20, fill=(16, 72, 168, 255))
    f = ImageFont.truetype(FONT_BOLD, 200)
    d.text((w / 2, w / 2 + 6), "P", font=f, fill=(255, 255, 255, 255), anchor="mm")
    d.rounded_rectangle([4, w + 8, w - 5, h - 5], 12, fill=(250, 250, 250, 255))
    d.rounded_rectangle([10, w + 14, w - 11, h - 11], 8, outline=(16, 72, 168, 255), width=4)
    f2 = ImageFont.truetype(FONT_BOLD, 32)
    d.text((w / 2 - 22, w + 66), "PARKING", font=f2, fill=(16, 72, 168, 255), anchor="mm")
    # flèche vers la droite
    ax, ay = w - 36, w + 66
    d.polygon([(ax - 18, ay - 16), (ax + 10, ay), (ax - 18, ay + 16)], fill=(16, 72, 168, 255))
    im.save(f"{OUT}/sign_p.png")


def paystation():
    """Façade d'horodateur (256 x 512) : bandeau, écran, clavier, fente à carte, pictogrammes."""
    w, h = 256, 512
    base = np.ones((h, w, 3)) * np.array([0.23, 0.25, 0.27])
    n = rng.standard_normal((h, w)) * 0.012
    base += n[..., None]
    im = Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w, 70], fill=(16, 72, 168))
    fb = ImageFont.truetype(FONT_BOLD, 26)
    d.rounded_rectangle([12, 12, 58, 58], 6, fill=(255, 255, 255))
    d.text((35, 37), "P", font=ImageFont.truetype(FONT_BOLD, 40), fill=(16, 72, 168), anchor="mm")
    d.text((70, 22), "PAYEZ", font=fb, fill=(255, 255, 255))
    d.text((70, 44), "ICI", font=ImageFont.truetype(FONT_TXT, 18), fill=(220, 230, 255))
    # écran
    d.rounded_rectangle([28, 96, w - 28, 196], 8, fill=(10, 12, 12))
    d.rectangle([38, 106, w - 38, 186], fill=(120, 170, 120))
    fs = ImageFont.truetype(FONT_BOLD, 18)
    d.text((48, 114), "STATIONNEMENT", font=fs, fill=(20, 40, 20))
    d.text((48, 140), "1H   4,00 EUR", font=fs, fill=(20, 40, 20))
    d.text((48, 162), "Plaque ?", font=ImageFont.truetype(FONT_TXT, 16), fill=(20, 40, 20))
    # clavier
    for r in range(4):
        for c in range(3):
            x0, y0 = 52 + c * 54, 222 + r * 44
            d.rounded_rectangle([x0, y0, x0 + 42, y0 + 34], 6, fill=(150, 152, 156))
            d.rounded_rectangle([x0 + 2, y0 + 2, x0 + 40, y0 + 30], 5, fill=(196, 198, 202))
            lab = "123456789C0V"[r * 3 + c]
            col = (180, 30, 30) if lab == "C" else ((30, 130, 40) if lab == "V" else (30, 30, 34))
            d.text((x0 + 21, y0 + 16), lab, font=fs, fill=col, anchor="mm")
    # fente carte et sans contact
    d.rounded_rectangle([50, 410, 206, 426], 4, fill=(8, 8, 8))
    d.text((128, 440), "CARTE  /  SANS CONTACT", font=ImageFont.truetype(FONT_TXT, 12), fill=(220, 220, 220), anchor="mm")
    d.rounded_rectangle([96, 456, 160, 500], 8, fill=(40, 42, 46), outline=(200, 200, 200), width=2)
    for k in range(3):
        d.arc([110 + k * 6, 466, 150 - k * 6, 492], -60, 60, fill=(230, 230, 230), width=2)
    # salissures et autocollants
    a = np.asarray(im).astype(np.float32) / 255.0
    yy = np.mgrid[0:h, 0:w][0] / h
    a *= (1.0 - 0.12 * yy[..., None] ** 2)
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.rectangle([150, 178, 236, 202], fill=(236, 222, 70))
    d.text((193, 190), "HORS SERVICE", font=ImageFont.truetype(FONT_BOLD, 10), fill=(20, 20, 20), anchor="mm")
    im.save(f"{OUT}/paystation.png")


def ground_marks():
    """Atlas 512 x 512 (cases de 128) : numéros de places 1 à 12 au pochoir, puis 4 taches d'huile."""
    im = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    f = ImageFont.truetype(FONT_BOLD, 92)
    f2 = ImageFont.truetype(FONT_PLATE, 80)
    for i in range(12):
        cell = Image.new("L", (128, 128), 0)
        d = ImageDraw.Draw(cell)
        d.text((64, 66), str(i + 1), font=f if i < 9 else f2, fill=235, anchor="mm")
        a = np.asarray(cell).astype(np.float32) / 255.0
        wear = np.clip(rng.standard_normal((128, 128)) * 0.5 + 0.75, 0, 1)
        wear = np.asarray(Image.fromarray((wear * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0
        a = a * np.clip(wear * 1.3, 0, 1)
        rgba = np.zeros((128, 128, 4), np.uint8)
        rgba[..., :3] = 236
        rgba[..., 3] = (a * 255).astype(np.uint8)
        im.paste(Image.fromarray(rgba), ((i % 4) * 128, (i // 4) * 128))
    for k in range(4):
        s = 128
        yy, xx = np.mgrid[0:s, 0:s] / s * 2 - 1
        acc = np.zeros((s, s))
        for _ in range(6):
            cx, cy = rng.uniform(-0.35, 0.35, 2)
            r = rng.uniform(0.2, 0.5)
            acc += np.exp(-((xx - cx) ** 2 + ((yy - cy) * rng.uniform(0.7, 1.4)) ** 2) / (r * r))
        nz = rng.standard_normal((s, s))
        nz = np.asarray(Image.fromarray(((nz * 0.5 + 0.5).clip(0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))) / 255.0
        a = np.clip((acc * 0.55 + (nz - 0.5) * 0.6) - 0.15, 0, 0.75)
        a *= np.clip(1.2 - np.sqrt(xx * xx + yy * yy), 0, 1)
        rgba = np.zeros((s, s, 4), np.uint8)
        rgba[..., 0] = 14
        rgba[..., 1] = 13
        rgba[..., 2] = 12
        rgba[..., 3] = (a * 255).astype(np.uint8)
        im.paste(Image.fromarray(rgba), (k * 128, 384))
    im.save(f"{OUT}/ground_marks.png")


if __name__ == "__main__":
    plates()
    sign_p()
    paystation()
    ground_marks()
    print("ok")
