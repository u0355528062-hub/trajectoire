"""Textures des accessoires : pancartes (4 + banderole), écrans de téléphone, flammes,
fumée, carton, journal, fumigène. Polices : Permanent Marker, Rock Salt (Apache 2.0)."""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from textures_gen import tile_noise, to_normal

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "props")
os.makedirs(OUT, exist_ok=True)
F = os.path.join(os.path.dirname(__file__), "fonts")
MARKER = F + "/PermanentMarker-Regular.ttf"
SCRIPT = F + "/RockSalt-Regular.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
random.seed(3)
rng = np.random.default_rng(3)


def noise_img(w, h, lo, hi, seed):
    n = tile_noise(max(w, h), lo, hi, seed)
    return n[:h, :w]


def cardboard(w, h, seed=1, tone=(0.62, 0.46, 0.30)):
    v = 1.0 + 0.06 * noise_img(w, h, 2, 12, seed) + 0.03 * noise_img(w, h, 30, 120, seed + 1)
    yy = np.arange(h)[:, None]
    corr = 1.0 + 0.025 * np.sin(yy / 7.0)  # cannelures
    a = np.stack([tone[0] * v * corr, tone[1] * v * corr, tone[2] * v * corr], -1)
    # taches
    for k in range(5):
        cx, cy, r = rng.integers(0, w), rng.integers(0, h), rng.integers(20, 90)
        Y, X = np.ogrid[:h, :w]
        m = np.exp(-(((X - cx) ** 2 + (Y - cy) ** 2) / (2 * r * r)))
        a *= (1 - 0.12 * m)[..., None]
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).convert("RGBA")


def hand_text(img, text, box, font_path, size, color, jitter=4.0, drip=0.0, outline=None, seed=0):
    """Texte « fait main » : chaque lettre légèrement tournée, taille variable, coulures."""
    r = random.Random(seed)
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, size)
    x0, y0, x1, y1 = box
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths)
    scale = min(1.0, (x1 - x0) / max(total, 1))
    font = ImageFont.truetype(font_path, int(size * scale))
    widths = [d.textlength(c, font=font) for c in text]
    total = sum(widths)
    x = x0 + (x1 - x0 - total) / 2
    cy = (y0 + y1) / 2
    for c, wc in zip(text, widths):
        if c == " ":
            x += wc
            continue
        s = int(font.size * r.uniform(0.92, 1.08))
        fnt = ImageFont.truetype(font_path, s)
        tile = Image.new("RGBA", (int(s * 1.6), int(s * 1.8)), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        if outline:
            for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
                td.text((s * 0.2 + dx, s * 0.1 + dy), c, font=fnt, fill=outline)
        td.text((s * 0.2, s * 0.1), c, font=fnt, fill=color)
        tile = tile.rotate(r.uniform(-jitter, jitter), resample=Image.BICUBIC, expand=False)
        img.alpha_composite(tile, (int(x - s * 0.2), int(cy - s * 0.95 + r.uniform(-4, 4))))
        if drip > 0 and r.random() < drip:
            dx = int(x + r.uniform(0.2, 0.8) * wc)
            dy = int(cy + s * 0.45)
            ln = r.randint(15, 70)
            d.line([(dx, dy), (dx, dy + ln)], fill=color, width=r.randint(3, 6))
            d.ellipse([dx - 4, dy + ln - 3, dx + 4, dy + ln + 5], fill=color)
        x += wc


def tape(img, x, y, w, h, ang):
    t = Image.new("RGBA", (w, h), (225, 215, 180, 170))
    t = t.rotate(ang, expand=True)
    img.alpha_composite(t, (x, y))


def signs():
    # 1 : carton, marqueur noir
    a = cardboard(1024, 768, 11)
    hand_text(a, "ON LÂCHE", (60, 120, 964, 330), MARKER, 210, (20, 18, 18, 255), seed=1)
    hand_text(a, "RIEN !", (160, 380, 864, 640), MARKER, 250, (20, 18, 18, 255), seed=2)
    ImageDraw.Draw(a).line([(200, 640), (830, 625)], fill=(170, 20, 20, 255), width=14)
    tape(a, 20, 20, 160, 40, 30); tape(a, 850, 700, 160, 40, 20)
    a.convert("RGB").save(OUT + "/sign_1.png")
    # 2 : carton plume blanc, peinture rouge et noire
    a = Image.new("RGBA", (1024, 768), (240, 238, 232, 255))
    an = np.array(a).astype(np.float32)
    an[..., :3] *= (0.97 + 0.03 * noise_img(1024, 768, 3, 40, 21))[..., None]
    a = Image.fromarray(np.clip(an, 0, 255).astype(np.uint8), "RGBA")
    hand_text(a, "TOUS", (100, 90, 924, 330), MARKER, 230, (200, 25, 25, 255), drip=0.5, seed=3)
    hand_text(a, "ENSEMBLE", (60, 380, 964, 610), MARKER, 200, (25, 25, 30, 255), seed=4)
    d = ImageDraw.Draw(a)
    for i in range(7):  # bonshommes qui se tiennent la main
        cx = 150 + i * 120
        d.ellipse([cx - 16, 645, cx + 16, 677], outline=(25, 25, 30), width=6)
        d.line([(cx, 677), (cx, 725)], fill=(25, 25, 30), width=6)
        d.line([(cx - 60, 690), (cx + 60, 690)], fill=(25, 25, 30), width=6)
        d.line([(cx, 725), (cx - 22, 760)], fill=(25, 25, 30), width=6)
        d.line([(cx, 725), (cx + 22, 760)], fill=(25, 25, 30), width=6)
    a.convert("RGB").save(OUT + "/sign_2.png")
    # 3 : panneau jaune, marqueur noir, flèche
    a = Image.new("RGBA", (1024, 768), (246, 205, 40, 255))
    an = np.array(a).astype(np.float32)
    an[..., :3] *= (0.95 + 0.05 * noise_img(1024, 768, 3, 40, 31))[..., None]
    a = Image.fromarray(np.clip(an, 0, 255).astype(np.uint8), "RGBA")
    hand_text(a, "LA RUE", (80, 70, 944, 300), MARKER, 230, (20, 20, 20, 255), seed=5)
    hand_text(a, "EST À NOUS", (50, 340, 974, 560), MARKER, 190, (20, 20, 20, 255), seed=6)
    d = ImageDraw.Draw(a)
    d.line([(150, 660), (820, 660)], fill=(20, 20, 20), width=22)
    d.polygon([(820, 610), (900, 660), (820, 710)], fill=(20, 20, 20))
    a.convert("RGB").save(OUT + "/sign_3.png")
    # 4 : carton, peinture bleue, cœurs et étoiles
    a = cardboard(1024, 768, 41, (0.66, 0.5, 0.33))
    hand_text(a, "ON EST", (90, 90, 934, 330), SCRIPT, 170, (25, 70, 190, 255), drip=0.4, seed=7)
    hand_text(a, "LÀ !", (200, 360, 824, 650), MARKER, 280, (25, 70, 190, 255), outline=(250, 250, 250, 255), drip=0.4, seed=8)
    d = ImageDraw.Draw(a)
    for (x, y) in ((90, 640), (900, 120), (880, 600), (110, 110)):
        d.polygon([(x, y - 34), (x + 10, y - 10), (x + 36, y - 10), (x + 15, y + 6), (x + 22, y + 32), (x, y + 16), (x - 22, y + 32), (x - 15, y + 6), (x - 36, y - 10), (x - 10, y - 10)], fill=(200, 30, 40))
    tape(a, 880, 15, 150, 40, -25)
    a.convert("RGB").save(OUT + "/sign_4.png")
    # 5 : banderole (drap peint)
    W, H = 2048, 640
    a = Image.new("RGBA", (W, H), (236, 232, 222, 255))
    an = np.array(a).astype(np.float32)
    fold = 0.94 + 0.06 * np.sin(np.arange(W) / 90.0)[None, :] * np.sin(np.arange(H) / 150.0)[:, None]
    an[..., :3] *= (fold * (0.97 + 0.03 * noise_img(W, H, 4, 60, 51)))[..., None]
    a = Image.fromarray(np.clip(an, 0, 255).astype(np.uint8), "RGBA")
    hand_text(a, "TOUS DEBOUT !", (80, 40, 1968, 380), MARKER, 300, (190, 20, 20, 255), drip=0.6, seed=9)
    hand_text(a, "ON AVANCE, ON LÂCHE RIEN", (120, 390, 1928, 600), MARKER, 150, (20, 20, 24, 255), drip=0.3, seed=10)
    a.convert("RGB").save(OUT + "/banner.png")


def phone_screens():
    # fil d'actualité
    W, H = 360, 760
    a = Image.new("RGB", (W, H), (16, 16, 20))
    d = ImageDraw.Draw(a)
    d.rectangle([0, 0, W, 60], fill=(24, 24, 30))
    d.text((18, 16), "Fil", font=ImageFont.truetype(BOLD, 24), fill=(240, 240, 245))
    y = 76
    for k in range(4):
        d.ellipse([16, y, 52, y + 36], fill=(rng.integers(80, 255), rng.integers(60, 200), rng.integers(60, 230)))
        d.rectangle([62, y + 6, 62 + rng.integers(80, 180), y + 16], fill=(210, 210, 220))
        d.rectangle([62, y + 22, 62 + rng.integers(60, 120), y + 30], fill=(120, 120, 130))
        top = np.array([rng.integers(20, 120), rng.integers(10, 60), rng.integers(40, 160)])
        bot = np.array([255, rng.integers(120, 200), rng.integers(30, 90)])
        for r_ in range(130):
            c = (top + (bot - top) * r_ / 130).astype(int)
            d.line([(16, y + 46 + r_), (W - 16, y + 46 + r_)], fill=tuple(c))
        y += 46 + 130 + 14
    a.save(OUT + "/phone_feed.png")
    # caméra (enregistrement)
    a = Image.new("RGB", (W, H), (0, 0, 0))
    v = np.zeros((H, W, 3), np.float32)
    yy = np.linspace(0, 1, H)[:, None]
    v[..., 0] = 0.25 + 0.6 * np.exp(-((yy - 0.55) / 0.12) ** 2)
    v[..., 1] = 0.12 + 0.3 * np.exp(-((yy - 0.55) / 0.1) ** 2)
    v[..., 2] = 0.15 + 0.1 * (1 - yy)
    v *= (0.85 + 0.15 * noise_img(W, H, 3, 30, 61))[..., None]
    a = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(a)
    d.ellipse([20, 22, 40, 42], fill=(240, 30, 30))
    d.text((48, 18), "REC 00:27", font=ImageFont.truetype(BOLD, 22), fill=(250, 250, 250))
    d.ellipse([W / 2 - 34, H - 100, W / 2 + 34, H - 32], outline=(250, 250, 250), width=6)
    d.ellipse([W / 2 - 22, H - 88, W / 2 + 22, H - 44], fill=(230, 30, 30))
    for x in (W / 3, 2 * W / 3):
        d.line([(x, 70), (x, H - 120)], fill=(255, 255, 255), width=1)
    for y in (H / 3, 2 * H / 3):
        d.line([(0, y), (W, y)], fill=(255, 255, 255), width=1)
    a.save(OUT + "/phone_cam.png")


def flames():
    # atlas 4x4 de flammes (dégradé blanc-jaune -> orange -> rouge, bords bruités)
    S, N = 128, 4
    atlas = np.zeros((S * N, S * N, 4), np.float32)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / S
    for k in range(N * N):
        ph = k / (N * N) * 2 * np.pi
        n1 = tile_noise(S, 3, 14, 70 + k)
        n2 = tile_noise(S, 8, 30, 90 + k)
        x = xx - 0.5 + 0.08 * np.sin(yy * 9 + ph) * yy + 0.05 * n1 * (1 - yy)
        h = 1.0 - yy
        width = 0.26 * np.sqrt(np.clip(yy, 0, 1)) * (1.0 - 0.25 * yy) + 0.02
        d = np.abs(x) / np.maximum(width, 1e-3)
        body = np.clip(1.0 - d, 0, 1) * np.clip((yy - 0.06) / 0.25, 0, 1)
        body *= np.clip(1.0 + 0.6 * n2 * (1 - yy), 0, 1.5)
        top = np.clip((yy - 0.02) / 0.5, 0, 1)
        a = np.clip(body * top * 1.6, 0, 1) ** 1.2
        heat = np.clip(body * (0.5 + yy * 0.8), 0, 1)
        r = np.clip(0.9 + heat * 0.3, 0, 1)
        g = np.clip(0.25 + heat * 0.85, 0, 1)
        b = np.clip(0.04 + (heat - 0.65) * 1.6, 0, 1)
        tile = np.stack([r, g, b, a], -1)
        tile = tile[::-1]  # base en bas
        i, j = k // N, k % N
        atlas[i * S:(i + 1) * S, j * S:(j + 1) * S] = tile
    Image.fromarray((atlas * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.8)).save(OUT + "/flame_atlas.png")
    # fumée : atlas 2x2 de volutes douces (bruit basse fréquence, bords très progressifs)
    S = 256
    atlas = np.zeros((S * 2, S * 2, 4), np.float32)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / S - 0.5
    for k in range(4):
        n1 = tile_noise(S, 2, 7, 101 + k)
        n2 = tile_noise(S, 6, 16, 201 + k)
        ang = np.arctan2(yy, xx)
        r = np.sqrt(xx ** 2 + yy ** 2) * (1.0 + 0.1 * np.sin(ang * 3 + k) + 0.06 * n1)
        a = np.clip((0.47 - r) / 0.32, 0, 1) ** 1.6
        a *= np.clip(0.86 + 0.12 * n1 + 0.05 * n2, 0.35, 1)
        v = 0.86 + 0.05 * n1 + 0.025 * n2 - 0.1 * np.clip(yy + 0.2, 0, 1)
        tile = np.stack([v, v, v, a], -1)
        i, j = k // 2, k % 2
        atlas[i * S:(i + 1) * S, j * S:(j + 1) * S] = tile
    img = Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.5))
    img.save(OUT + "/smoke.png")


def misc():
    # carton d'emballage
    a = cardboard(512, 512, 81)
    d = ImageDraw.Draw(a)
    d.rectangle([0, 230, 512, 282], fill=(200, 180, 140, 255))
    d.text((140, 100), "FRAGILE", font=ImageFont.truetype(BOLD, 52), fill=(160, 30, 30, 255))
    d.text((120, 340), "↑ HAUT ↑", font=ImageFont.truetype(BOLD, 40), fill=(40, 40, 40, 255))
    a.convert("RGB").save(OUT + "/box.png")
    # journal
    a = Image.new("RGB", (512, 512), (226, 222, 210))
    d = ImageDraw.Draw(a)
    d.text((20, 14), "LE QUOTIDIEN", font=ImageFont.truetype(SCRIPT, 44), fill=(20, 20, 20))
    d.line([(20, 80), (492, 80)], fill=(20, 20, 20), width=3)
    d.text((20, 92), "La ville se mobilise ce soir", font=ImageFont.truetype(BOLD, 28), fill=(20, 20, 20))
    for c in range(3):
        for r_ in range(26):
            y = 150 + r_ * 13
            d.line([(20 + c * 162, y), (20 + c * 162 + rng.integers(110, 150), y)], fill=(90, 90, 90), width=5)
    d.rectangle([180, 380, 492, 492], fill=(120, 120, 125))
    a.save(OUT + "/newspaper.png")
    # étiquette du fumigène
    a = Image.new("RGB", (512, 256), (190, 20, 18))
    d = ImageDraw.Draw(a)
    d.rectangle([0, 0, 512, 40], fill=(30, 30, 30))
    d.rectangle([0, 216, 512, 256], fill=(30, 30, 30))
    d.text((24, 62), "FUMIGÈNE", font=ImageFont.truetype(BOLD, 64), fill=(250, 250, 250))
    d.text((24, 140), "ROUGE · 60 s · ne pas inhaler", font=ImageFont.truetype(SANS, 26), fill=(250, 230, 220))
    a.save(OUT + "/flare_label.png")
    # dos des pancartes (carton brut)
    cardboard(512, 384, 91).convert("RGB").save(OUT + "/sign_back.png")
    # caisse en bois (planches)
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    g = np.sin((yy + 20 * tile_noise(n, 2, 6, 111)) / n * 2 * np.pi * 10) * 0.5 + 0.5
    gap = (np.abs(((yy / n) * 5) % 1 - 0.5) > 0.47)
    v = np.stack([0.58 * (0.75 + 0.25 * g), 0.42 * (0.75 + 0.25 * g), 0.25 * (0.75 + 0.25 * g)], -1)
    v[gap] *= 0.3
    Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8)).save(OUT + "/crate.png")


if __name__ == "__main__":
    signs(); phone_screens(); flames(); misc()
    print("ok")
