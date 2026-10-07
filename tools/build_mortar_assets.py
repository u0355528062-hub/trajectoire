"""Textures du mortier : tube en carton imprimé (étiquette lisible dans le sens de la longueur,
feuille dorée aux extrémités, étoiles, spirale de collage)."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from textures_gen import tile_noise, to_normal

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "mortar")
os.makedirs(OUT, exist_ok=True)
L, C = 1024, 512   # dessin « paysage » : x = longueur du tube, y = tour du tube
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"

red = np.array([150, 18, 14], dtype=np.float32)
base = np.tile(red, (C, L, 1))
grain = np.tile(tile_noise(512, 20, 120, 11), (1, 2))[:C, :L]
base *= (0.9 + 0.07 * grain[..., None])
img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)
gold = (214, 160, 52)
cream = (236, 222, 190)

def foil(x0, x1):
    for x in range(x0, x1):
        t = (x - x0) / max(1, x1 - x0 - 1)
        k = 0.78 + 0.35 * np.sin(t * np.pi)
        d.line([(x, 0), (x, C)], fill=tuple(int(c * k) for c in gold))
foil(0, 62); foil(L - 74, L)
for x in (70, L - 82):
    d.line([(x, 0), (x, C)], fill=(40, 6, 4), width=3)
for x in (80, L - 92):
    d.line([(x, 0), (x, C)], fill=gold, width=4)
# spirale du collage
for k in range(-6, 10):
    d.line([(0, 40 + k * 100), (L, 40 + k * 100 + 120)], fill=(110, 12, 9), width=2)

# étiquette crème (lisible dans le sens de la longueur)
lx0, lx1, ly0, ly1 = 110, L - 120, 56, 330
d.rounded_rectangle([lx0, ly0, lx1, ly1], radius=22, fill=cream, outline=(60, 10, 8), width=5)
d.rounded_rectangle([lx0 + 12, ly0 + 12, lx1 - 12, ly1 - 12], radius=14, outline=(150, 18, 14), width=3)
f1 = ImageFont.truetype(SERIF, 64); f2 = ImageFont.truetype(BOLD, 34); f3 = ImageFont.truetype(BOLD, 25)
def ctext(txt, y, font, fill):
    w = d.textlength(txt, font=font)
    d.text(((lx0 + lx1) / 2 - w / 2, y), txt, font=font, fill=fill)
ctext("FEU D'ARTIFICE", ly0 + 26, f1, (120, 12, 10))
ctext("MORTIER DE LANCEMENT", ly0 + 112, f2, (40, 20, 16))
ctext("★ ★ ★   6 TIRS   ★ ★ ★", ly0 + 162, f2, (150, 18, 14))
tx, ty = lx0 + 40, ly0 + 205
d.polygon([(tx, ty + 56), (tx + 64, ty + 56), (tx + 32, ty)], outline=(30, 20, 16), fill=(245, 200, 40), width=4)
d.text((tx + 26, ty + 14), "!", font=ImageFont.truetype(BOLD, 36), fill=(30, 20, 16))
d.text((tx + 90, ty - 2), "NE PAS PENCHER LA TÊTE AU-DESSUS DU TUBE", font=f3, fill=(40, 20, 16))
d.text((tx + 90, ty + 30), "Allumer à bout de bras — tenir à distance", font=f3, fill=(120, 12, 10))
# étoiles dorées sur le reste du tour
f4 = ImageFont.truetype(BOLD, 50)
for x in range(150, L - 140, 120):
    d.text((x, 372), "✦", font=f4, fill=gold)
    d.text((x + 60, 440), "✦", font=f4, fill=gold)
img = img.filter(ImageFilter.GaussianBlur(0.6))
img = img.rotate(90, expand=True)           # x -> y : le texte se lit de bas en haut
img.save(os.path.join(OUT, "tube_albedo.png"))

yy, xx = np.mgrid[0:L, 0:C].astype(np.float32)
g2 = np.tile(tile_noise(512, 30, 160, 13), (2, 1))[:L, :C]
h = g2 * 0.5 + np.exp(-((((yy * 0.75 + xx) % 100) - 50) / 2.2) ** 2) * -1.2
Image.fromarray(to_normal(h, 0.7)).save(os.path.join(OUT, "tube_n.png"))
print("ok", img.size)
