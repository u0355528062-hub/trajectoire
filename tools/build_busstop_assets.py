"""Textures de l'arrêt de bus : affiche rétro-éclairée, panneau, horaires, fissures du verre, béton."""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from textures_gen import tile_noise, to_normal

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "busstop")
os.makedirs(OUT, exist_ok=True)
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
random.seed(7)

# ------------------------------------------------------------- affiche
W, H = 800, 1160
a = np.zeros((H, W, 3), dtype=np.float32)
y = np.linspace(0, 1, H)[:, None]
top = np.array([14, 10, 52]); mid = np.array([150, 28, 96]); low = np.array([255, 150, 50])
c = np.where(y < 0.55, top + (mid - top) * (y / 0.55), mid + (low - mid) * ((y - 0.55) / 0.45))
a[:] = c[:, None, :] if c.ndim == 2 else c
img = Image.fromarray(a.astype(np.uint8))
d = ImageDraw.Draw(img, "RGBA")
# bouquets d'artifice
def burst(cx, cy, r, col, n=70):
    for i in range(n):
        ang = 2 * math.pi * i / n + random.random() * 0.1
        l0 = r * (0.25 + random.random() * 0.15); l1 = r * (0.8 + random.random() * 0.2)
        d.line([(cx + math.cos(ang) * l0, cy + math.sin(ang) * l0), (cx + math.cos(ang) * l1, cy + math.sin(ang) * l1)], fill=col + (200,), width=3)
        d.ellipse([cx + math.cos(ang) * l1 - 4, cy + math.sin(ang) * l1 - 4, cx + math.cos(ang) * l1 + 4, cy + math.sin(ang) * l1 + 4], fill=(255, 245, 220, 255))
burst(250, 330, 210, (255, 190, 60)); burst(560, 230, 150, (120, 200, 255)); burst(520, 480, 120, (255, 90, 120))
img = img.filter(ImageFilter.GaussianBlur(1.2))
d = ImageDraw.Draw(img, "RGBA")
# silhouette de la ville
for i in range(0, W, 46):
    h = random.randint(70, 210)
    d.rectangle([i, H - 240 - h + 120, i + 44, H], fill=(10, 8, 28, 255))
    for wy in range(H - 240 - h + 135, H - 130, 26):
        for wx in range(i + 8, i + 38, 14):
            if random.random() < 0.45:
                d.rectangle([wx, wy, wx + 7, wy + 12], fill=(255, 214, 120, 255))
d.rectangle([0, H - 280, W, H], fill=(8, 6, 24, 255))
d.text((60, 70), "NUIT DES", font=ImageFont.truetype(BOLD, 56), fill=(255, 240, 220, 255))
d.text((60, 130), "LUMIÈRES", font=ImageFont.truetype(SERIF, 112), fill=(255, 200, 90, 255))
d.text((60, H - 250), "Feu d'artifice · Musique · Food trucks", font=ImageFont.truetype(SANS, 30), fill=(255, 240, 220, 255))
d.text((60, H - 190), "SAMEDI 21H", font=ImageFont.truetype(BOLD, 84), fill=(255, 255, 255, 255))
d.text((60, H - 90), "Place de la République · Entrée libre", font=ImageFont.truetype(SANS, 28), fill=(255, 190, 120, 255))
img.save(os.path.join(OUT, "poster.png"))

# ------------------------------------------------------------- panneau d'arrêt
S = 512
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([4, 4, S - 4, S - 4], fill=(235, 238, 240, 255))
d.ellipse([20, 20, S - 20, S - 20], fill=(0, 82, 160, 255))
# bus stylisé
d.rounded_rectangle([110, 170, 402, 330], radius=28, fill=(255, 255, 255, 255))
for i in range(4):
    d.rounded_rectangle([128 + i * 66, 190, 180 + i * 66, 250], radius=8, fill=(0, 82, 160, 255))
d.rectangle([110, 270, 402, 282], fill=(0, 82, 160, 255))
d.ellipse([145, 300, 205, 360], fill=(255, 255, 255, 255)); d.ellipse([160, 315, 190, 345], fill=(0, 82, 160, 255))
d.ellipse([310, 300, 370, 360], fill=(255, 255, 255, 255)); d.ellipse([325, 315, 355, 345], fill=(0, 82, 160, 255))
d.text((S // 2 - 92, 390), "BUS", font=ImageFont.truetype(BOLD, 96), fill=(255, 255, 255, 255))
im.save(os.path.join(OUT, "sign.png"))

# plaque de ligne
pl = Image.new("RGBA", (512, 256), (245, 246, 248, 255))
d = ImageDraw.Draw(pl)
d.rectangle([0, 0, 511, 255], outline=(0, 70, 140, 255), width=8)
d.rounded_rectangle([24, 28, 140, 112], radius=16, fill=(0, 82, 160, 255))
d.text((44, 30), "12", font=ImageFont.truetype(BOLD, 72), fill=(255, 255, 255, 255))
d.text((160, 36), "CENTRE-VILLE", font=ImageFont.truetype(BOLD, 40), fill=(10, 30, 60, 255))
d.text((160, 86), "Gare · Place de la Mairie", font=ImageFont.truetype(SANS, 26), fill=(60, 70, 90, 255))
d.line([(24, 130), (488, 130)], fill=(0, 82, 160, 255), width=3)
d.text((24, 148), "ARRÊT", font=ImageFont.truetype(BOLD, 34), fill=(10, 30, 60, 255))
d.text((24, 192), "DES LUMIÈRES", font=ImageFont.truetype(BOLD, 40), fill=(0, 82, 160, 255))
pl.save(os.path.join(OUT, "plate.png"))

# horaires
tt = Image.new("RGB", (400, 560), (250, 250, 252))
d = ImageDraw.Draw(tt)
d.rectangle([0, 0, 400, 70], fill=(0, 82, 160))
d.text((20, 12), "Ligne 12 · Horaires", font=ImageFont.truetype(BOLD, 32), fill=(255, 255, 255))
for r in range(11):
    yy = 90 + r * 42
    d.text((24, yy), f"{6 + r:02d} h", font=ImageFont.truetype(BOLD, 26), fill=(10, 30, 60))
    d.text((110, yy), "  ".join(f"{m:02d}" for m in (7, 22, 37, 52)), font=ImageFont.truetype(SANS, 26), fill=(50, 60, 80))
    d.line([(16, yy + 36), (384, yy + 36)], fill=(215, 220, 230), width=1)
tt.save(os.path.join(OUT, "timetable.png"))

# ------------------------------------------------------------- fissures
def cracks(size, rays, rings, seed, spread):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = size / 2
    pts = {}
    for i in range(rays):
        ang = 2 * math.pi * i / rays + rnd.uniform(-0.18, 0.18)
        r = 0
        x, y = c, c
        a = ang
        while r < size * 0.5 * spread:
            step = rnd.uniform(14, 34)
            a += rnd.uniform(-0.12, 0.12)
            nx, ny = x + math.cos(a) * step, y + math.sin(a) * step
            w = max(1, int(4 * (1 - r / (size * 0.5 * spread))) + 1)
            d.line([(x, y), (nx, ny)], fill=(235, 245, 250, 235), width=w)
            if rnd.random() < 0.22:  # branche
                ba = a + rnd.choice([-1, 1]) * rnd.uniform(0.5, 1.0)
                d.line([(nx, ny), (nx + math.cos(ba) * step * 1.6, ny + math.sin(ba) * step * 1.6)], fill=(225, 238, 245, 190), width=max(1, w - 1))
            pts.setdefault(i, []).append((nx, ny))
            x, y, r = nx, ny, r + step
    # anneaux concentriques irréguliers (toile d'araignée)
    for k in range(rings):
        rr = (k + 1) * size * 0.5 * spread / (rings + 0.6)
        poly = []
        for i in range(rays):
            lst = pts.get(i, [])
            if not lst:
                continue
            idx = min(range(len(lst)), key=lambda j: abs(math.hypot(lst[j][0] - c, lst[j][1] - c) - rr))
            poly.append(lst[idx])
        if len(poly) > 3:
            d.line(poly + [poly[0]], fill=(230, 242, 248, 160), width=2)
    # point d'impact : éclat blanc
    d.ellipse([c - 14, c - 14, c + 14, c + 14], fill=(250, 252, 255, 200))
    for _ in range(40):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(6, 30)
        d.ellipse([c + math.cos(a) * r - 2, c + math.sin(a) * r - 2, c + math.cos(a) * r + 2, c + math.sin(a) * r + 2], fill=(255, 255, 255, 230))
    return im.filter(ImageFilter.GaussianBlur(0.7))
cracks(1024, 9, 3, 1, 0.55).save(os.path.join(OUT, "crack1.png"))
cracks(1024, 15, 6, 2, 0.98).save(os.path.join(OUT, "crack2.png"))

# ------------------------------------------------------------- béton
n = 512
h = tile_noise(n, 3, 14, 21) * 0.6 + tile_noise(n, 30, 130, 22) * 0.5
Image.fromarray(to_normal(h, 0.5)).save(os.path.join(OUT, "concrete_n.png"))
v = 0.52 + 0.035 * tile_noise(n, 2, 10, 23) + 0.025 * tile_noise(n, 40, 150, 24)
alb = np.stack([v * 0.62, v * 0.62, v * 0.6], -1)
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "concrete_a.png"))
# bois
yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
g = np.sin((yy + 12 * tile_noise(n, 2, 6, 31)) / n * 2 * np.pi * 14) * 0.5 + 0.5
wood = np.stack([0.50 * (0.7 + 0.3 * g), 0.30 * (0.7 + 0.3 * g), 0.15 * (0.7 + 0.3 * g)], -1)
Image.fromarray((np.clip(wood, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "wood_a.png"))
Image.fromarray(to_normal(g * 0.8 + tile_noise(n, 30, 130, 32) * 0.2, 0.6)).save(os.path.join(OUT, "wood_n.png"))
print("ok")


# =============================================================== v2 : plus de détails
def save_rgba(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))

# petites fissures (impacts de pierres)
for i, (rays, rings, seed, spread) in enumerate([(6, 1, 11, 0.7), (7, 2, 12, 0.8), (8, 1, 13, 0.75), (5, 1, 14, 0.65)]):
    cracks(512, rays, rings, seed, spread).save(os.path.join(OUT, f"crack_s{i}.png"))

# roche
n = 512
h = tile_noise(n, 2, 8, 41) * 1.0 + tile_noise(n, 8, 40, 42) * 0.8 + tile_noise(n, 40, 160, 43) * 0.35
Image.fromarray(to_normal(h, 0.9)).save(os.path.join(OUT, "rock_n.png"))
v = 0.38 + 0.09 * tile_noise(n, 2, 8, 44) + 0.06 * tile_noise(n, 10, 60, 45)
alb = np.stack([v * 1.0, v * 0.97, v * 0.92], -1)
Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "rock_a.png"))

# asphalte
h = tile_noise(n, 30, 160, 51) * 0.8 + tile_noise(n, 6, 30, 52) * 0.4
Image.fromarray(to_normal(h, 0.7)).save(os.path.join(OUT, "asphalt_n.png"))
v = 0.17 + 0.03 * tile_noise(n, 2, 12, 53) + 0.04 * np.clip(tile_noise(n, 60, 200, 54), -1, 2)
Image.fromarray((np.clip(np.stack([v, v, v * 1.03], -1), 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "asphalt_a.png"))

# marquages routiers
dash = np.zeros((64, 256, 4)); dash[...] = 0
im = Image.new("RGBA", (256, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.rectangle([0, 18, 150, 46], fill=(235, 235, 225, 235))
im = im.filter(ImageFilter.GaussianBlur(0.8)); im.save(os.path.join(OUT, "road_dash.png"))
im = Image.new("RGBA", (1024, 512), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
f = ImageFont.truetype(BOLD, 330)
d.text((512 - d.textlength("BUS", font=f) / 2, 40), "BUS", font=f, fill=(240, 232, 200, 235))
d.rectangle([40, 440, 984, 480], fill=(240, 232, 200, 235))
arr = np.array(im).astype(np.float32)
wear = np.clip(0.75 + 0.5 * np.tile(tile_noise(512, 20, 120, 61), (1, 2))[:512, :1024], 0.3, 1.2)
arr[..., 3] *= np.clip(wear, 0, 1)
Image.fromarray(arr.astype(np.uint8), "RGBA").save(os.path.join(OUT, "road_bus.png"))

# écran d'information (LED ambre)
W2, H2 = 768, 192
im = Image.new("RGB", (W2, H2), (6, 4, 2)); d = ImageDraw.Draw(im)
fb = ImageFont.truetype(BOLD, 54)
d.text((20, 18), "12  CENTRE-VILLE", font=fb, fill=(255, 170, 30))
d.text((20, 98), "3 min     18 min", font=fb, fill=(255, 190, 60))
a = np.array(im).astype(np.float32)
yy, xx = np.mgrid[0:H2, 0:W2]
led = ((xx % 6) < 5) & ((yy % 6) < 5)
a *= led[..., None] * 1.0 + 0.12
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "ledscreen.png"))

# bande dépolie (sablage) avec pictogramme
fw, fh = 1024, 256
fr = tile_noise(256, 5, 60, 71)
fr = np.tile(fr, (1, 4))[:256, :1024]
alpha = np.clip(0.58 + 0.08 * fr, 0, 1) * 255
rgba = np.zeros((fh, fw, 4)); rgba[..., :3] = (232, 240, 244); rgba[..., 3] = alpha
im = Image.fromarray(rgba.astype(np.uint8), "RGBA"); d = ImageDraw.Draw(im)
for x in range(60, fw, 340):
    d.rounded_rectangle([x, 80, x + 60, 150], radius=10, fill=(0, 82, 160, 190))
    d.text((x + 8, 84), "12", font=ImageFont.truetype(BOLD, 44), fill=(255, 255, 255, 230))
    d.text((x + 74, 92), "CENTRE-VILLE", font=ImageFont.truetype(BOLD, 34), fill=(0, 60, 120, 210))
im.save(os.path.join(OUT, "frost.png"))

# salissures en bas des vitres + coulures
dw, dh = 512, 256
yg = np.linspace(1, 0, dh)[:, None]
dn = np.tile(tile_noise(256, 3, 40, 81), (1, 2))[:256, :512]
streak = np.clip(np.tile(tile_noise(512, 40, 200, 82)[:1, :512], (dh, 1)), -1, 2)
dirt = np.clip(yg ** 2.2 * (0.55 + 0.25 * dn) + 0.10 * np.clip(streak, 0, 2) * yg ** 0.9, 0, 1)
rgba = np.zeros((dh, dw, 4)); rgba[..., 0] = 90; rgba[..., 1] = 84; rgba[..., 2] = 74
rgba[..., 3] = dirt * 120
Image.fromarray(rgba.astype(np.uint8), "RGBA").save(os.path.join(OUT, "dirt.png"))

# plan de quartier (panneau d'information)
mp = Image.new("RGB", (400, 600), (240, 243, 246)); d = ImageDraw.Draw(mp)
d.rectangle([0, 0, 400, 56], fill=(0, 82, 160)); d.text((16, 10), "PLAN DU QUARTIER", font=ImageFont.truetype(BOLD, 28), fill=(255, 255, 255))
rnd = random.Random(5)
for i in range(9):
    d.line([(rnd.randint(0, 400), 56 + i * 60), (rnd.randint(0, 400), 90 + i * 60)], fill=(255, 255, 255), width=14)
    d.line([(rnd.randint(0, 400), 56 + i * 60), (rnd.randint(0, 400), 90 + i * 60)], fill=(255, 214, 120), width=5)
for i in range(18):
    x, y = rnd.randint(10, 340), rnd.randint(70, 540)
    d.rounded_rectangle([x, y, x + rnd.randint(30, 60), y + rnd.randint(20, 50)], radius=4, fill=(205, 214, 222))
d.ellipse([180, 280, 220, 320], fill=(220, 40, 40)); d.text((228, 288), "Vous êtes ici", font=ImageFont.truetype(BOLD, 22), fill=(40, 40, 40))
mp.save(os.path.join(OUT, "map.png"))
print("ok v2")

# dallage (pavés 50x25 cm avec joints)
n = 1024
yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
pw, ph = n / 2.0, n / 4.0   # 2 pavés en x, 4 en y sur la tuile
row = np.floor(yy / ph)
xo = (xx + (row % 2) * pw * 0.5) % pw
yo = yy % ph
edge = np.minimum(np.minimum(xo, pw - xo), np.minimum(yo, ph - yo))
joint = np.clip(1.0 - edge / 5.0, 0, 1)
cell = (np.floor((xx + (row % 2) * pw * 0.5) / pw) * 7 + row * 13) % 5
tone = 0.50 + 0.025 * (cell - 2)
nz = tile_noise(n, 6, 60, 91) * 0.02 + tile_noise(n, 80, 400, 92) * 0.015
v = (tone + nz) * (1 - 0.55 * joint)
Image.fromarray((np.clip(np.stack([v, v, v * 0.98], -1), 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, "paving_a.png"))
h = -joint * 3.0 + tile_noise(n, 80, 400, 93) * 0.35
Image.fromarray(to_normal(h, 0.8)).save(os.path.join(OUT, "paving_n.png"))
print("ok paving")
