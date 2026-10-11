"""Textures du quartier (sols, mobilier, végétation) : trottoir en enrobé, pavés de granit, bordures, écorce de platane,
feuilles, fontes (regards, grilles d'arbre, avaloirs), affiches de colonne Morris, métro Guimard, kiosque, square,
panneaux et feux piétons.
Usage : python3 tools/build_quartier_textures.py  ->  assets/quartier/*.png"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = "assets/quartier"
os.makedirs(OUT, exist_ok=True)
FONTS = "/usr/share/fonts/truetype/"


def font(name, size):
	paths = {
		"sans_b": FONTS + "dejavu/DejaVuSans-Bold.ttf", "sans": FONTS + "dejavu/DejaVuSans.ttf",
		"serif_b": FONTS + "dejavu/DejaVuSerif-Bold.ttf", "serif": FONTS + "dejavu/DejaVuSerif.ttf",
		"lib_b": FONTS + "liberation/LiberationSans-Bold.ttf", "lib_serif_b": FONTS + "liberation/LiberationSerif-Bold.ttf",
		"lib_serif_i": FONTS + "liberation/LiberationSerif-Italic.ttf", "cala_b": FONTS + "crosextra/Caladea-Bold.ttf",
		"carl_b": FONTS + "crosextra/Carlito-Bold.ttf", "inter_k": "/usr/share/fonts/opentype/inter/Inter-Black.otf",
		"inter_t": "/usr/share/fonts/opentype/inter/Inter-Thin.otf", "inter_l": "/usr/share/fonts/opentype/inter/Inter-Light.otf",
		"cond": FONTS + "dejavu/DejaVuSansMono-Bold.ttf",
	}
	return ImageFont.truetype(paths[name], size)


# ------------------------------------------------------------------ outils
def tile_noise(n, freqs, seed, m=None):
	"""Bruit tileable (bruit blanc filtré en fréquence). freqs : [(fréquence de coupure, amplitude)]."""
	m = m or n
	r = np.random.default_rng(seed)
	acc = np.zeros((m, n))
	for f, amp in freqs:
		w = r.standard_normal((m, n))
		F = np.fft.fft2(w)
		ky = np.fft.fftfreq(m)[:, None] * m
		kx = np.fft.fftfreq(n)[None, :] * n
		k = np.sqrt(kx * kx + ky * ky)
		F *= np.exp(-(k / f) ** 2)
		a = np.real(np.fft.ifft2(F))
		a = (a - a.mean()) / (a.std() + 1e-9)
		acc += a * amp
	return acc


def to_normal(h, strength):
	gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
	gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
	nx, ny = -gx * strength, gy * strength
	nz = np.ones_like(h)
	l = np.sqrt(nx * nx + ny * ny + nz * nz)
	n = np.stack([nx / l, ny / l, nz / l], -1)
	return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(a, name):
	a = np.clip(a, 0, 1)
	Image.fromarray((a * 255 + 0.5).astype(np.uint8)).save(f"{OUT}/{name}")


def save_n(h, strength, name):
	Image.fromarray(to_normal(h, strength)).save(f"{OUT}/{name}")


def blur(a, r):
	"""Flou gaussien tileable (FFT)."""
	m, n = a.shape[:2]
	ky = np.fft.fftfreq(m)[:, None]
	kx = np.fft.fftfreq(n)[None, :]
	g = np.exp(-2 * (np.pi * r) ** 2 * (kx * kx + ky * ky))
	if a.ndim == 2:
		return np.real(np.fft.ifft2(np.fft.fft2(a) * g))
	return np.stack([np.real(np.fft.ifft2(np.fft.fft2(a[..., c]) * g)) for c in range(a.shape[2])], -1)


def wrap_disc(mask, cx, cy, r, val=1.0, soft=1.0):
	"""Disque (tileable) ajouté au masque : max(masque, disque)."""
	m, n = mask.shape
	y, x = np.mgrid[0:m, 0:n]
	dx = (x - cx + n / 2) % n - n / 2
	dy = (y - cy + m / 2) % m - m / 2
	d = np.sqrt(dx * dx + dy * dy)
	np.maximum(mask, np.clip((r - d) / soft, 0, 1) * val, out=mask)


def voronoi(n, m, pts, warp=None):
	"""Distance au plus proche et au second point (tileable), et indice du plus proche. warp : (dx, dy) en px."""
	y, x = np.mgrid[0:m, 0:n].astype(np.float32)
	if warp is not None:
		x = (x + warp[0]) % n
		y = (y + warp[1]) % m
	d1 = np.full((m, n), 1e9, np.float32)
	d2 = np.full((m, n), 1e9, np.float32)
	idx = np.zeros((m, n), np.int32)
	for i, (px, py) in enumerate(pts):
		dx = np.abs(x - px)
		dx = np.minimum(dx, n - dx)
		dy = np.abs(y - py)
		dy = np.minimum(dy, m - dy)
		d = np.sqrt(dx * dx + dy * dy)
		closer = d < d1
		d2 = np.where(closer, d1, np.minimum(d2, d))
		idx = np.where(closer, i, idx)
		d1 = np.where(closer, d, d1)
	return d1, d2, idx


# ------------------------------------------------------------------ trottoir (enrobé gris clair) : 1024 px = 4 m
def trottoir():
	n = 1024
	r = np.random.default_rng(11)
	big = tile_noise(n, [(3, 1.0), (7, 0.6)], 1)
	mid = tile_noise(n, [(30, 0.6), (80, 0.4)], 2)
	fine = r.standard_normal((n, n))
	# granulats : grains de 1 à 3 px plus clairs ou plus sombres
	grain = blur(r.standard_normal((n, n)), 0.9)
	grain = grain / grain.std()
	agg_l = np.clip(grain - 1.3, 0, 2) * 0.22
	agg_d = np.clip(-grain - 1.5, 0, 2) * 0.25
	quartz = (r.random((n, n)) > 0.9965).astype(float)
	quartz = np.clip(blur(quartz, 0.6) * 6, 0, 1)
	lum = 0.50 + big * 0.022 + mid * 0.018 + fine * 0.018 + agg_l - agg_d + quartz * 0.18
	col = np.stack([lum * 0.985, lum * 0.99, lum * 1.0], -1)
	# taches (eau, huile, café) : larges, douces
	stains = np.zeros((n, n))
	for i in range(14):
		wrap_disc(stains, r.uniform(0, n), r.uniform(0, n), r.uniform(10, 46), r.uniform(0.3, 1.0), r.uniform(6, 20))
	stains *= np.clip(tile_noise(n, [(40, 1.0)], 3) * 0.5 + 0.7, 0, 1)
	col *= (1.0 - stains * 0.13)[..., None]
	col[..., 0] *= 1.0 - stains * 0.02
	# chewing-gums écrasés : petites pastilles grises
	gum = np.zeros((n, n))
	for i in range(140):
		wrap_disc(gum, r.uniform(0, n), r.uniform(0, n), r.uniform(1.6, 3.6), r.uniform(0.5, 1.0), 1.0)
	col = col * (1 - gum[..., None] * 0.45) + gum[..., None] * 0.18
	# rapiéçages : deux rectangles d'enrobé plus récent (plus sombre), bord net
	h = fine * 0.12 + grain * 0.35 + quartz * 0.3
	y, x = np.mgrid[0:n, 0:n]
	for (x0, y0, w, hh, k) in [(120, 600, 260, 140, 0.95), (690, 160, 130, 300, 0.965)]:
		dx = (x - x0) % n
		dy = (y - y0) % n
		m = ((dx < w) & (dy < hh)).astype(float)
		m = blur(m, 0.7)
		col *= (1.0 - m * (1 - k))[..., None]
		h -= m * 0.15
	# fissures : marches aléatoires fines
	crack = np.zeros((n, n))
	for c in range(9):
		px, py = r.uniform(0, n), r.uniform(0, n)
		a = r.uniform(0, np.pi * 2)
		for s in range(int(r.uniform(80, 260))):
			a += r.normal(0, 0.35)
			px = (px + np.cos(a) * 1.5) % n
			py = (py + np.sin(a) * 1.5) % n
			crack[int(py), int(px)] = 1.0
	crack = np.clip(blur(crack, 0.55) * 3.0, 0, 1)
	col *= (1.0 - crack * 0.45)[..., None]
	h -= crack * 1.2
	save(col, "trottoir_a.png")
	save_n(h, 1.8, "trottoir_n.png")


# ------------------------------------------------------------------ pavés de granit en rangées : 1024 px = 2 m
def setts(name, seed, rows=16, minl=0.15, maxl=0.24, tint=(1.0, 1.0, 1.0), joint_w=0.012):
	n = 1024
	r = np.random.default_rng(seed)
	ppm = n / 2.0
	col = np.zeros((n, n, 3))
	h = np.zeros((n, n))
	joint = np.ones((n, n))
	rh = n // rows
	palette = np.array([[0.50, 0.50, 0.50], [0.44, 0.45, 0.48], [0.56, 0.53, 0.50], [0.52, 0.47, 0.45],
		[0.40, 0.41, 0.42], [0.60, 0.58, 0.55], [0.47, 0.46, 0.43]])
	speck = blur(r.standard_normal((n, n)), 0.8)
	speck /= speck.std()
	xs = np.arange(n)
	for row in range(rows):
		# longueurs des pavés de la rangée, normalisées pour boucler exactement sur 2 m
		ls = []
		while sum(ls) < 2.0:
			ls.append(r.uniform(minl, maxl))
		ls = np.array(ls) * (2.0 / sum(ls))
		edges = np.concatenate([[0], np.cumsum(ls)]) * ppm
		off = r.uniform(0, n)
		xx = (xs - off) % n
		k = np.searchsorted(edges, xx, side="right") - 1
		k = np.clip(k, 0, len(ls) - 1)
		u = (xx - edges[k]) / (edges[k + 1] - edges[k])          # 0..1 dans le pavé
		lens = (edges[k + 1] - edges[k])
		y0 = row * rh
		v = (np.arange(rh) + 0.5) / rh
		U, V = np.meshgrid(u, v)
		L = np.broadcast_to(lens, U.shape)
		# distance au bord en px, coins arrondis et bords irréguliers
		dx = np.minimum(U, 1 - U) * L
		dy = np.minimum(V, 1 - V) * rh
		jw = joint_w * ppm
		ir = tile_noise(n, [(60, 1.0)], seed * 100 + row, rh)[:, :] * 1.2
		d = np.minimum(dx, dy) + ir
		cr = 6.0
		cx = np.clip(cr - dx, 0, None)
		cy = np.clip(cr - dy, 0, None)
		dc = cr - np.sqrt(cx * cx + cy * cy)
		d = np.minimum(d, dc + ir)
		m = np.clip((d - jw * 0.5) / 2.0, 0, 1)
		dome = np.clip(d / (rh * 0.45), 0, 1) ** 0.5
		ids = (k * 7 + row * 13 + seed) % len(palette)
		base = palette[ids]                                       # (n, 3)
		bright = r.uniform(0.9, 1.1, len(ls))[k]
		c = base[None, :, :] * bright[None, :, None]
		c = c * (1.0 + speck[y0:y0 + rh, :, None] * 0.07)
		# usure : le dessus des pavés plus lisse et plus clair, bords sales
		c = c * (0.86 + 0.18 * dome[..., None])
		col[y0:y0 + rh] = c
		joint[y0:y0 + rh] = m
		h[y0:y0 + rh] = dome * 0.9 + speck[y0:y0 + rh] * 0.03
	jc = np.array([0.24, 0.22, 0.2])
	sand = tile_noise(n, [(90, 1.0)], seed + 5)
	jcol = jc[None, None, :] * (1 + sand[..., None] * 0.15)
	col = col * joint[..., None] + jcol * (1 - joint[..., None])
	col *= np.array(tint)[None, None, :]
	grime = tile_noise(n, [(4, 1.0), (12, 0.5)], seed + 9)
	col *= (1.0 - np.clip(grime, -1, 2)[..., None] * 0.05)
	save(col, name + "_a.png")
	save_n(h * joint - (1 - joint) * 0.4, 3.5, name + "_n.png")


# ------------------------------------------------------------------ bordure de granit : 1024 x 256 = 4 m x 0,5 m (profil)
def bordure():
	w, hgt = 1024, 256
	r = np.random.default_rng(21)
	speck = blur(r.standard_normal((hgt, w)), 0.7)
	speck /= speck.std()
	blk = (np.clip(-speck - 1.6, 0, 3) * 0.25)
	wht = (np.clip(speck - 1.8, 0, 3) * 0.2)
	base = 0.58 + tile_noise(w, [(20, 1.0)], 22, hgt) * 0.02 - blk + wht
	# quatre pierres de longueurs inégales, teintes légèrement différentes
	cuts = [0, 230, 500, 760, 1024]
	tints = [1.0, 0.95, 1.04, 0.97]
	x = np.arange(w)
	t = np.ones(w)
	j = np.zeros(w)
	for i in range(4):
		t[cuts[i]:cuts[i + 1]] = tints[i]
		j += np.exp(-((x - cuts[i]) / 1.6) ** 2)
	j += np.exp(-((x - 1024) / 1.6) ** 2)
	lum = base * t[None, :] * (1 - np.clip(j, 0, 1)[None, :] * 0.5)
	# saleté : bas du profil (côté chaussée, v petit) plus sombre ; arête usée claire
	v = np.arange(hgt)[:, None] / hgt
	dirt = np.clip(1 - v / 0.18, 0, 1) * 0.35 + np.clip((v - 0.62) / 0.38, 0, 1) * 0.15
	lum *= 1 - dirt
	col = np.stack([lum * 1.0, lum * 0.99, lum * 0.97], -1)
	save(col, "bordure_a.png")
	save_n(speck * 0.05 - j[None, :] * 0.8, 2.0, "bordure_n.png")


# ------------------------------------------------------------------ écorce de platane : 512 x 1024 (tour x 2 m de haut)
def ecorce():
	w, hgt = 512, 1024
	r = np.random.default_rng(31)
	pts = [(r.uniform(0, w), r.uniform(0, hgt)) for _ in range(150)]
	# plaques allongées verticalement : on déforme la grille avant le voronoï
	warp = (tile_noise(w, [(10, 1.0), (30, 0.3)], 32, hgt) * 10, tile_noise(w, [(10, 1.0), (30, 0.3)], 35, hgt) * 18)
	d1, d2, idx = voronoi(w, hgt, pts, warp)
	edge = np.clip((d2 - d1) / 5.0, 0, 1)
	pal = np.array([[0.56, 0.55, 0.47], [0.47, 0.47, 0.40], [0.66, 0.62, 0.50], [0.42, 0.41, 0.35],
		[0.60, 0.56, 0.42], [0.36, 0.35, 0.31], [0.70, 0.68, 0.58], [0.52, 0.49, 0.41], [0.62, 0.62, 0.52]])
	pid = r.integers(0, len(pal), len(pts))
	col = pal[pid[idx]]
	# superposition de deux échelles de plaques (grande mosaïque + petites écailles)
	pts2 = [(r.uniform(0, w), r.uniform(0, hgt)) for _ in range(700)]
	e1, e2, idx2 = voronoi(w, hgt, pts2, (warp[0] * 0.4, warp[1] * 0.4))
	small = np.clip((e2 - e1) / 2.5, 0, 1)
	sid = r.random(len(pts2))[idx2]
	col = col * (0.92 + sid[..., None] * 0.14)
	n1 = tile_noise(w, [(40, 1.0), (120, 0.5)], 33, hgt)
	col *= (1 + n1[..., None] * 0.04)
	col *= (0.7 + 0.3 * edge)[..., None]
	col *= (0.9 + 0.1 * small)[..., None]
	# légère teinte verdâtre (mousse) par endroits
	moss = np.clip(tile_noise(w, [(5, 1.0)], 34, hgt), 0, 2) * 0.035
	col[..., 0] *= 1 - moss
	col[..., 2] *= 1 - moss * 1.5
	save(col, "ecorce_a.png")
	hgt_map = pid[idx] / len(pal) * 0.5 + edge * 0.6 + small * 0.2 + n1 * 0.05
	save_n(hgt_map, 3.0, "ecorce_n.png")


# ------------------------------------------------------------------ feuilles de platane : atlas 2 x 2 bouquets
def leaf_poly(cx, cy, size, ang, r):
	"""Contour d'une feuille de platane (5 lobes pointus) : liste de points."""
	pts = []
	lobes = [(-1.25, 0.55), (-0.62, 0.85), (0.0, 1.0), (0.62, 0.85), (1.25, 0.55)]
	K = 120
	for i in range(K + 1):
		t = -np.pi * 0.62 + (np.pi * 1.24) * i / K
		rad = 0.5
		for la, ll in lobes:
			d = (t - la)
			rad = max(rad, ll * np.exp(-(d / 0.3) ** 2) + 0.55 * np.exp(-(d / 0.8) ** 2))
		rad *= size * r.uniform(0.97, 1.03)
		a = ang + t
		pts.append((cx + np.sin(a) * rad, cy - np.cos(a) * rad))
	# base de la feuille (pétiole)
	pts.append((cx + np.sin(ang + np.pi) * size * 0.12, cy - np.cos(ang + np.pi) * size * 0.12))
	return pts


def feuilles():
	n = 1024
	cell = 512
	img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
	r = np.random.default_rng(41)
	greens = [(62, 92, 34), (78, 108, 40), (50, 80, 30), (92, 118, 46), (70, 100, 38), (104, 124, 52), (120, 128, 54)]
	for ci in range(4):
		ox, oy = (ci % 2) * cell, (ci // 2) * cell
		layer = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
		dr = ImageDraw.Draw(layer)
		nl = 34 + ci * 3
		# rameau
		bx, by = cell * 0.5, cell * 0.98
		for k in range(nl):
			a = r.uniform(0, np.pi * 2)
			dist = np.sqrt(r.uniform(0.0, 1.0)) * 0.34 * cell
			cx = cell * 0.5 + np.cos(a) * dist
			cy = cell * 0.46 + np.sin(a) * dist * 0.9
			sz = r.uniform(0.075, 0.12) * cell
			ang = np.arctan2(cx - bx, -(cy - by)) + r.normal(0, 0.5)
			g = np.array(greens[r.integers(0, len(greens))])
			if ci == 3 and r.random() < 0.25:
				g = np.array((150, 140, 60))          # quelques feuilles qui jaunissent
			shade = r.uniform(0.75, 1.15)
			c = tuple(int(v) for v in np.clip(g * shade, 0, 255)) + (255,)
			if k % 4 == 0:
				dr.line([(bx + (cx - bx) * 0.5, by + (cy - by) * 0.5), (cx, cy)], fill=(60, 52, 30, 255), width=2)
			dr.polygon(leaf_poly(cx, cy, sz, ang, r), fill=c)
			# nervures
			vc = tuple(int(v) for v in np.clip(g * shade * 1.25 + 18, 0, 255)) + (255,)
			for la in (-1.25, -0.62, 0.0, 0.62, 1.25):
				a2 = ang + la
				dr.line([(cx, cy), (cx + np.sin(a2) * sz * 0.8, cy - np.cos(a2) * sz * 0.8)], fill=vc, width=1)
		dr.line([(bx, by), (cell * 0.5, cell * 0.55)], fill=(70, 60, 36, 255), width=5)
		a = np.asarray(layer).astype(float)
		# ombrage : centre du bouquet plus sombre, bords éclairés (volume)
		yy, xx = np.mgrid[0:cell, 0:cell]
		dd = np.sqrt((xx - cell * 0.5) ** 2 + (yy - cell * 0.46) ** 2) / (cell * 0.45)
		sh = 0.78 + 0.3 * np.clip(dd, 0, 1)
		nz = blur(r.standard_normal((cell, cell)), 2.0)
		a[..., :3] *= (sh + nz * 0.25)[..., None]
		a[..., :3] = np.clip(a[..., :3], 0, 255)
		img.paste(Image.fromarray(a.astype(np.uint8)), (ox, oy))
	# aplatit le fond : couleur des bords pour éviter les franges sombres au filtrage
	arr = np.asarray(img).astype(float)
	alpha = arr[..., 3:4] / 255
	rgb = arr[..., :3]
	bl = blur(rgb * alpha, 6.0)
	bw = blur(alpha[..., 0], 6.0)[..., None]
	fill = bl / np.maximum(bw, 1e-3)
	rgb = rgb * alpha + fill * (1 - alpha)
	out = np.concatenate([np.clip(rgb, 0, 255), arr[..., 3:4]], -1).astype(np.uint8)
	Image.fromarray(out, "RGBA").save(f"{OUT}/feuilles_a.png")


# ------------------------------------------------------------------ fontes de voirie : atlas 1024, 4 cases de 512
def fontes():
	n = 1024
	c = 512
	col = np.zeros((n, n, 3))
	h = np.zeros((n, n))
	alpha = np.ones((n, n))
	r = np.random.default_rng(51)
	y, x = np.mgrid[0:c, 0:c].astype(float)
	iron = np.array([0.20, 0.19, 0.18])
	rust = np.array([0.30, 0.20, 0.14])
	grain = blur(r.standard_normal((c, c)), 1.0)
	grain /= grain.std()

	def metal(m_relief, rust_amt):
		rr = np.clip(tile_noise(c, [(10, 1.0), (40, 0.5)], int(r.integers(1000))) * 0.5 + rust_amt, 0, 1)
		base = iron[None, None, :] * (1 - rr[..., None]) + rust[None, None, :] * rr[..., None]
		lum = 0.75 + 0.45 * m_relief + grain * 0.05       # reliefs polis par les pas : plus clairs
		return base * lum[..., None]

	# (0,0) regard d'égout rond : anneaux et quadrillage en losanges
	cx = cy = c / 2
	d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (c / 2)
	a = np.arctan2(y - cy, x - cx)
	rel = np.zeros((c, c))
	ring = (d > 0.9) & (d < 0.99)
	rel[ring] = 1.0
	rel[(d > 0.8) & (d < 0.84)] = 1.0
	diam = ((np.abs(((x + y) / 26.0) % 1.0 - 0.5) < 0.12) | (np.abs(((x - y) / 26.0) % 1.0 - 0.5) < 0.12)) & (d < 0.78)
	rel[diam] = 1.0
	rel[(d > 0.3) & (d < 0.34)] = 1.0
	rel = blur(rel, 1.0)
	m = metal(rel, -0.2)
	al = np.clip((1.0 - d) * c * 0.5, 0, 1)
	col[:c, :c] = m
	h[:c, :c] = rel
	alpha[:c, :c] = al
	# (1,0) grille d'arbre carrée : fentes rayonnantes, moyeu central ouvert
	sq = np.maximum(np.abs(x - cx), np.abs(y - cy)) / (c / 2)
	rel = np.ones((c, c))
	slot = (np.abs(((a / (2 * np.pi)) * 72) % 1.0 - 0.5) < 0.2) & (d > 0.36) & (sq < 0.9)
	for rr_ in (0.5, 0.66, 0.82):
		slot &= ~((d > rr_ - 0.015) & (d < rr_ + 0.015))
	rel[slot] = 0.0
	rel[d < 0.3] = 0.0
	rel = blur(rel, 0.8)
	soil = np.array([0.12, 0.09, 0.07]) * (0.8 + 0.4 * blur(r.random((c, c)), 1.5)[..., None])
	m = metal(rel * 0.4 + (sq > 0.9) * 0.6, 0.15)
	col[:c, c:] = m * rel[..., None] + soil * (1 - rel[..., None])
	h[:c, c:] = rel
	# (0,1) avaloir : barreaux parallèles dans un cadre
	rel = np.ones((c, c))
	bars = (np.abs((x / 40.0) % 1.0 - 0.5) < 0.28) & (np.abs(y - cy) < c * 0.38) & (np.abs(x - cx) < c * 0.44)
	rel[bars] = 0.0
	rel = blur(rel, 0.8)
	hole = np.array([0.03, 0.03, 0.03])
	m = metal(rel * 0.6, 0.0)
	col[c:, :c] = m * rel[..., None] + hole * (1 - rel[..., None])
	h[c:, :c] = rel
	# (1,1) plaque carrée de concessionnaire (damier antidérapant)
	chk = ((np.floor(x / 22) + np.floor(y / 22)) % 2).astype(float)
	stud = (np.abs((x % 22) - 11) < 7) & (np.abs((y % 22) - 11) < 2.5)
	stud2 = (np.abs((x % 22) - 11) < 2.5) & (np.abs((y % 22) - 11) < 7)
	rel = np.where(chk > 0, stud, stud2).astype(float)
	frame = (sq > 0.9).astype(float)
	rel = np.maximum(rel, frame)
	rel = blur(rel, 0.8)
	col[c:, c:] = metal(rel, -0.1) * 1.05
	h[c:, c:] = rel
	rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)
	Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fontes_a.png")
	save_n(h, 4.0, "fontes_n.png")


# ------------------------------------------------------------------ affiches de la colonne Morris : 2048 x 1024 (tour complet)
POSTERS = [
	("LE MISANTHROPE", "Molière", "Théâtre du Quai — jusqu'au 30 nov.", (0.86, 0.18, 0.15), (1, 0.97, 0.9), "serif_b"),
	("JAZZ", "nuits d'automne", "Péniche Opéra · 21h", (0.08, 0.1, 0.16), (0.98, 0.78, 0.22), "inter_k"),
	("CYRANO", "de Bergerac", "Salle Rostand · location ouverte", (0.95, 0.92, 0.84), (0.15, 0.12, 0.1), "lib_serif_b"),
	("EXPOSITION", "Lumières de Seine", "Grand Pavillon · 10h-19h", (0.18, 0.34, 0.5), (0.98, 0.96, 0.9), "inter_t"),
	("CIRQUE", "des Étoiles", "sous chapiteau · Porte Dorée", (0.96, 0.8, 0.12), (0.62, 0.08, 0.1), "cala_b"),
	("BALLET", "Giselle", "Opéra · 4 > 19 déc.", (0.12, 0.1, 0.12), (0.92, 0.88, 0.86), "lib_serif_i"),
	("FESTIVAL", "musiques du monde", "3 jours · 40 concerts", (0.92, 0.36, 0.5), (0.1, 0.06, 0.2), "carl_b"),
	("L'AVARE", "comédie", "Théâtre des Abbesses", (0.32, 0.5, 0.36), (0.98, 0.95, 0.85), "serif_b"),
	("CINÉMA", "ressortie en salles", "version restaurée", (0.9, 0.88, 0.8), (0.75, 0.1, 0.1), "inter_k"),
	("RÉCITAL", "piano · Chopin", "Salle Pleyel · 20h30", (0.42, 0.12, 0.2), (0.96, 0.9, 0.7), "lib_serif_b"),
	("MAGIE", "l'illusionniste", "dès 6 ans", (0.1, 0.16, 0.38), (0.96, 0.82, 0.3), "cala_b"),
	("SALON", "du livre ancien", "entrée libre", (0.85, 0.75, 0.55), (0.25, 0.15, 0.08), "serif"),
]


def text_fit(dr, txt, fname, box_w, max_size):
	s = max_size
	while s > 8:
		f = font(fname, s)
		w = dr.textlength(txt, font=f)
		if w <= box_w:
			return f, w
		s -= 2
	f = font(fname, 8)
	return f, dr.textlength(txt, font=f)


def poster(w, h, spec, r):
	title, sub, info, bg, fg, fn = spec
	im = Image.new("RGB", (w, h), tuple(int(v * 255) for v in bg))
	dr = ImageDraw.Draw(im)
	fgc = tuple(int(v * 255) for v in fg)
	style = r.integers(0, 4)
	if style == 0:   # grand disque décoratif
		rad = w * r.uniform(0.3, 0.45)
		cx, cy = w * r.uniform(0.3, 0.7), h * r.uniform(0.3, 0.55)
		acc = tuple(int(min(255, v * 255 * 0.6 + 80)) for v in fg)
		dr.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=acc)
	elif style == 1:  # bandes
		for i in range(5):
			yy = h * (0.15 + i * 0.09)
			dr.rectangle([0, yy, w, yy + h * 0.035], fill=fgc)
	elif style == 2:  # cadre
		m = w * 0.05
		dr.rectangle([m, m, w - m, h - m], outline=fgc, width=max(2, int(w * 0.012)))
	else:             # silhouette (personnage stylisé)
		cx = w * 0.5
		dr.ellipse([cx - w * 0.12, h * 0.18, cx + w * 0.12, h * 0.36], fill=fgc)
		dr.polygon([(cx - w * 0.28, h * 0.68), (cx - w * 0.15, h * 0.38), (cx + w * 0.15, h * 0.38), (cx + w * 0.28, h * 0.68)], fill=fgc)
	f, tw = text_fit(dr, title, fn, w * 0.88, int(h * 0.16))
	ty = h * 0.66
	dr.text(((w - tw) / 2, ty), title, font=f, fill=fgc)
	f2, tw2 = text_fit(dr, sub, "lib_serif_i", w * 0.8, int(h * 0.06))
	dr.text(((w - tw2) / 2, ty + h * 0.15), sub, font=f2, fill=fgc)
	f3, tw3 = text_fit(dr, info, "sans", w * 0.86, int(h * 0.035))
	dr.text(((w - tw3) / 2, h * 0.92), info, font=f3, fill=fgc)
	return im


def morris():
	W, H = 2048, 1024
	r = np.random.default_rng(61)
	im = Image.new("RGB", (W, H), (200, 196, 180))
	x = 0
	k = 0
	order = list(range(len(POSTERS)))
	r.shuffle(order)
	while x < W:
		w = int(r.uniform(230, 330))
		if x + w > W:
			w = W - x
		if w < 120:
			break
		# deux affiches superposées ou une grande
		if r.random() < 0.45:
			p = poster(w - 6, H - 8, POSTERS[order[k % len(order)]], r)
			im.paste(p, (x + 3, 4))
			k += 1
		else:
			h1 = int(H * r.uniform(0.42, 0.58))
			p = poster(w - 6, h1 - 6, POSTERS[order[k % len(order)]], r)
			im.paste(p, (x + 3, 3))
			k += 1
			p = poster(w - 6, H - h1 - 5, POSTERS[order[k % len(order)]], r)
			im.paste(p, (x + 3, h1 + 2))
			k += 1
		x += w
	a = np.asarray(im).astype(float) / 255
	# papier : plis, usure, coulures, coins déchirés
	wr = tile_noise(W, [(30, 1.0), (90, 0.4)], 62, H)
	a *= (1 + wr[..., None] * 0.03)
	streak = np.clip(tile_noise(W, [(60, 1.0)], 63, H) * 0.5, 0, 1) * np.linspace(0.2, 1, H)[:, None]
	a *= (1 - streak[..., None] * 0.12)
	grime = np.clip(tile_noise(W, [(8, 1.0)], 64, H), 0, 2)
	a = a * (1 - grime[..., None] * 0.08) + np.array([0.3, 0.27, 0.2]) * grime[..., None] * 0.04
	save(a, "morris_a.png")


# ------------------------------------------------------------------ métro Guimard : enseigne + carrelage
def metro():
	w, h = 1024, 160
	im = Image.new("RGB", (w, h), (226, 168, 52))
	dr = ImageDraw.Draw(im)
	dr.rectangle([0, 0, w - 1, h - 1], outline=(40, 70, 48), width=10)
	dr.rectangle([14, 14, w - 15, h - 15], outline=(120, 82, 22), width=2)
	f, tw = text_fit(dr, "METROPOLITAIN", "cala_b", w * 0.86, 104)
	bb = dr.textbbox((0, 0), "METROPOLITAIN", font=f)
	dr.text(((w - tw) / 2, (h - (bb[3] - bb[1])) / 2 - bb[1]), "METROPOLITAIN", font=f, fill=(32, 66, 42))
	a = np.asarray(im).astype(float) / 255
	nz = tile_noise(w, [(20, 1.0)], 71, h)
	a *= (1 + nz[..., None] * 0.04)
	g = np.linspace(1.05, 0.9, h)[:, None, None]
	save(a * g, "metro_enseigne.png")
	# carrelage blanc biseauté du métro : 512 px = 0,6 m x 0,6 m (carreaux 15 x 7,5 cm)
	n = 512
	y, x = np.mgrid[0:n, 0:n].astype(float)
	tw_, th_ = n / 4, n / 8
	row = np.floor(y / th_)
	xx = (x + (row % 2) * tw_ * 0.5) % tw_
	yy = y % th_
	dx = np.minimum(xx, tw_ - xx)
	dy = np.minimum(yy, th_ - yy)
	d = np.minimum(dx, dy)
	bev = np.clip(d / 9.0, 0, 1)
	joint = np.clip((d - 2.0) / 1.0, 0, 1)
	r = np.random.default_rng(72)
	tint = r.uniform(0.94, 1.0, (8, 8))
	ti = tint[(row % 8).astype(int), (np.floor((x + (row % 2) * tw_ * 0.5) / tw_) % 8).astype(int)]
	lum = (0.9 * ti) * joint + 0.45 * (1 - joint)
	col = np.stack([lum * 0.98, lum * 0.97, lum * 0.93], -1)
	dirt = np.clip(tile_noise(n, [(5, 1.0)], 73), 0, 2) * 0.08
	col *= (1 - dirt[..., None])
	save(col, "carrelage_a.png")
	save_n(bev * joint * 1.0, 6.0, "carrelage_n.png")


# ------------------------------------------------------------------ kiosque : atlas 1024 (magazines, frontons, affiches)
def kiosque():
	W = 1024
	r = np.random.default_rng(81)
	im = Image.new("RGB", (W, W), (30, 60, 45))
	dr = ImageDraw.Draw(im)
	# haut : mur de magazines (8 x 4 couvertures)
	titles = ["LE MATIN", "SPORT", "AUTO", "MODE", "CINÉ", "JARDIN", "MONDE", "ÉCO", "SCIENCE", "VOYAGE", "CUISINE", "MUSIQUE",
		"DÉCO", "HISTOIRE", "TECH", "FOOT", "TÉLÉ", "ART", "STYLE", "SANTÉ", "PARIS", "LIVRES", "MOTO", "BD",
		"NATURE", "ÉCHECS", "CHATS", "PHOTO", "RUGBY", "VÉLO", "JEUX", "MER"]
	cols, rows = 8, 4
	cw, ch = W / cols, 512 / rows
	k = 0
	for j in range(rows):
		for i in range(cols):
			x0, y0 = i * cw + 4, j * ch + 4
			bg = tuple(int(v) for v in r.integers(30, 240, 3))
			dr.rectangle([x0, y0, x0 + cw - 8, y0 + ch - 8], fill=bg)
			fg = (255, 255, 255) if sum(bg) < 380 else (20, 20, 20)
			t = titles[k % len(titles)]
			f, tw = text_fit(dr, t, ["inter_k", "serif_b", "lib_b", "cala_b"][k % 4], cw - 18, 30)
			dr.text((x0 + (cw - 8 - tw) / 2, y0 + 5), t, font=f, fill=fg)
			pc = tuple(int(v) for v in r.integers(40, 220, 3))
			dr.ellipse([x0 + cw * 0.18, y0 + ch * 0.35, x0 + cw * 0.78, y0 + ch * 0.95], fill=pc)
			for l in range(3):
				dr.rectangle([x0 + 6, y0 + ch * 0.62 + l * 8, x0 + cw * 0.45, y0 + ch * 0.62 + l * 8 + 3], fill=fg)
			k += 1
	# frontons : « JOURNAUX » et « PRESSE » (crème sur vert, filet doré)
	for (txt, y0) in (("JOURNAUX", 512), ("PRESSE", 662)):
		dr.rectangle([0, y0, 511, y0 + 149], fill=(28, 66, 48))
		dr.rectangle([8, y0 + 8, 503, y0 + 141], outline=(190, 160, 80), width=4)
		f, tw = text_fit(dr, txt, "cala_b", 440, 96)
		bb = dr.textbbox((0, 0), txt, font=f)
		dr.text(((512 - tw) / 2, y0 + (150 - (bb[3] - bb[1])) / 2 - bb[1]), txt, font=f, fill=(236, 224, 186))
	# panneau vert mouluré (bas gauche)
	dr.rectangle([0, 812, 511, 1023], fill=(28, 64, 46))
	dr.rectangle([24, 836, 487, 999], outline=(18, 44, 32), width=10)
	# deux affiches
	im.paste(poster(252, 508, POSTERS[4], r), (514, 514))
	im.paste(poster(252, 508, POSTERS[1], r), (770, 514))
	a = np.asarray(im).astype(float) / 255
	a *= (1 + tile_noise(W, [(40, 1.0)], 82)[..., None] * 0.03)
	save(a, "kiosque_a.png")


# ------------------------------------------------------------------ rambarde Guimard : panneau de fonte ajourée (RGBA)
def guimard():
	w, h = 512, 256
	S = 2
	im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
	dr = ImageDraw.Draw(im)
	g = (255, 255, 255, 255)
	lw = 11 * S
	W, H = w * S, h * S
	# cadre
	dr.rectangle([0, 0, W - 1, lw * 1.4], fill=g)
	dr.rectangle([0, H - lw * 1.4, W - 1, H - 1], fill=g)
	dr.rectangle([0, 0, lw * 1.2, H - 1], fill=g)
	dr.rectangle([W - lw * 1.2, 0, W - 1, H - 1], fill=g)
	# écusson central ovale
	cx, cy = W / 2, H / 2
	dr.ellipse([cx - 70 * S, cy - 80 * S, cx + 70 * S, cy + 80 * S], outline=g, width=lw)
	dr.ellipse([cx - 30 * S, cy - 40 * S, cx + 30 * S, cy + 40 * S], outline=g, width=int(lw * 0.8))
	# arabesques en coup de fouet (symétriques)
	for sx in (-1, 1):
		pts = []
		for i in range(60):
			t = i / 59
			x = cx + sx * (70 + t * 160) * S
			y = cy + np.sin(t * np.pi * 1.5) * 70 * S * (1 - t * 0.3)
			pts.append((x, y))
		dr.line(pts, fill=g, width=lw, joint="curve")
		pts = []
		for i in range(60):
			t = i / 59
			x = cx + sx * (60 + t * 170) * S
			y = cy - np.sin(t * np.pi * 1.2 + 0.5) * 60 * S
			pts.append((x, y))
		dr.line(pts, fill=g, width=int(lw * 0.7), joint="curve")
		# tige verticale et bourgeon
		x = cx + sx * 175 * S
		dr.line([(x, lw), (x, H - lw)], fill=g, width=int(lw * 0.8))
		dr.ellipse([x - 16 * S, cy - 16 * S, x + 16 * S, cy + 16 * S], fill=g)
	im = im.resize((w, h), Image.LANCZOS)
	a = np.asarray(im).astype(float)
	alpha = (a[..., 3] > 110).astype(float)
	col = np.zeros((h, w, 3))
	col[...] = np.array([0.2, 0.32, 0.25])
	nz = tile_noise(w, [(30, 1.0)], 111, h)
	col *= (1 + nz[..., None] * 0.06)[...]
	out = np.concatenate([col, alpha[..., None]], -1)
	Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA").save(f"{OUT}/guimard_a.png")


# ------------------------------------------------------------------ square : pelouse, stabilisé, haie, massif de fleurs
def square_tex():
	n = 512
	r = np.random.default_rng(91)
	# pelouse : brins fins, touffes, quelques zones pelées
	bl = blur(r.standard_normal((n, n)), 0.6)
	bl /= bl.std()
	t = tile_noise(n, [(8, 1.0), (24, 0.5)], 92)
	g = np.stack([0.20 + bl * 0.03 + t * 0.03, 0.34 + bl * 0.05 + t * 0.05, 0.12 + bl * 0.02], -1)
	bare = np.clip(tile_noise(n, [(4, 1.0)], 93) - 1.2, 0, 1)
	g = g * (1 - bare[..., None]) + np.array([0.38, 0.33, 0.24]) * bare[..., None]
	save(g, "pelouse_a.png")
	save_n(bl * 0.5, 2.0, "pelouse_n.png")
	# stabilisé (sable-gravier beige compacté)
	gr = blur(r.standard_normal((n, n)), 0.8)
	gr /= gr.std()
	pebble = np.clip(gr - 1.4, 0, 2) * 0.12
	t = tile_noise(n, [(6, 1.0), (30, 0.4)], 94)
	lum = 0.62 + t * 0.03 + gr * 0.025 + pebble
	s = np.stack([lum * 1.0, lum * 0.9, lum * 0.74], -1)
	save(s, "stabilise_a.png")
	save_n(gr * 0.4 + pebble * 2, 2.0, "stabilise_n.png")
	# haie taillée (buis / troène) : feuillage dense
	im = Image.new("RGB", (n, n), (26, 50, 22))
	dr = ImageDraw.Draw(im)
	for i in range(5200):
		x, y = r.uniform(0, n), r.uniform(0, n)
		s_ = r.uniform(3, 7)
		c = (int(r.uniform(28, 70)), int(r.uniform(60, 110)), int(r.uniform(20, 46)))
		for ox in (-n, 0, n):
			for oy in (-n, 0, n):
				dr.ellipse([x + ox - s_, y + oy - s_ * 0.6, x + ox + s_, y + oy + s_ * 0.6], fill=c)
	a = np.asarray(im).astype(float) / 255
	sh = tile_noise(n, [(10, 1.0)], 95)
	a *= (0.85 + sh[..., None] * 0.12)
	save(a, "haie_a.png")
	hh = a.mean(-1)
	save_n(hh, 6.0, "haie_n.png")
	# massif de fleurs : feuillage + fleurs colorées (tons d'automne : chrysanthèmes, cyclamens, bruyères)
	im = Image.new("RGB", (n, n), (30, 52, 24))
	dr = ImageDraw.Draw(im)
	for i in range(2600):
		x, y = r.uniform(0, n), r.uniform(0, n)
		s_ = r.uniform(3, 8)
		c = (int(r.uniform(24, 60)), int(r.uniform(50, 100)), int(r.uniform(18, 40)))
		for ox in (-n, 0, n):
			for oy in (-n, 0, n):
				dr.ellipse([x + ox - s_, y + oy - s_, x + ox + s_, y + oy + s_], fill=c)
	fl = [(220, 60, 90), (240, 190, 40), (250, 245, 235), (180, 60, 160), (235, 110, 40), (200, 30, 40)]
	for i in range(1500):
		x, y = r.uniform(0, n), r.uniform(0, n)
		s_ = r.uniform(2.5, 5)
		c = fl[int(r.integers(0, len(fl)))]
		c = tuple(int(v * r.uniform(0.8, 1.05)) for v in c)
		for ox in (-n, 0, n):
			for oy in (-n, 0, n):
				dr.ellipse([x + ox - s_, y + oy - s_, x + ox + s_, y + oy + s_], fill=c)
				dr.ellipse([x + ox - 1, y + oy - 1, x + ox + 1, y + oy + 1], fill=(250, 220, 90))
	a = np.asarray(im).astype(float) / 255
	save(a, "fleurs_a.png")
	save_n(a.mean(-1), 5.0, "fleurs_n.png")


# ------------------------------------------------------------------ panneaux routiers + feux piétons
def panneaux():
	n = 512
	c = 256
	im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
	dr = ImageDraw.Draw(im)
	blue = (22, 70, 160, 255)
	white = (245, 245, 240, 255)
	black = (20, 20, 22, 255)
	red = (200, 20, 26, 255)

	def walker(cx, cy, s, fill):
		dr.ellipse([cx - s * 0.12, cy - s * 0.62, cx + s * 0.12, cy - s * 0.38], fill=fill)
		dr.polygon([(cx - s * 0.1, cy - s * 0.34), (cx + s * 0.12, cy - s * 0.34), (cx + s * 0.08, cy + s * 0.05), (cx - s * 0.1, cy + s * 0.05)], fill=fill)
		dr.line([(cx, cy), (cx - s * 0.28, cy + s * 0.5)], fill=fill, width=int(s * 0.12))
		dr.line([(cx, cy), (cx + s * 0.22, cy + s * 0.5)], fill=fill, width=int(s * 0.12))
		dr.line([(cx, cy - s * 0.3), (cx - s * 0.25, cy - s * 0.02)], fill=fill, width=int(s * 0.1))
		dr.line([(cx, cy - s * 0.3), (cx + s * 0.28, cy - s * 0.08)], fill=fill, width=int(s * 0.1))

	# (0,0) passage pour piétons (C20a) : carré bleu, triangle blanc, piéton noir
	dr.rounded_rectangle([6, 6, c - 6, c - 6], radius=18, fill=blue, outline=white, width=8)
	dr.polygon([(c / 2, 34), (c - 34, c - 44), (34, c - 44)], fill=white)
	walker(c / 2, c * 0.6, 120, black)
	for i in range(4):
		dr.rectangle([60 + i * 36, c - 62, 80 + i * 36, c - 48], fill=black)
	# (1,0) sens unique : rectangle bleu, flèche blanche
	dr.rounded_rectangle([c + 6, 70, n - 6, c - 70], radius=10, fill=blue, outline=white, width=6)
	dr.polygon([(c + 40, c / 2 - 14), (n - 80, c / 2 - 14), (n - 80, c / 2 - 34), (n - 36, c / 2), (n - 80, c / 2 + 34), (n - 80, c / 2 + 14), (c + 40, c / 2 + 14)], fill=white)
	# (0,1) zone 30 : disque rouge cerclé, 30 noir
	dr.ellipse([12, c + 12, c - 12, n - 12], fill=red)
	dr.ellipse([40, c + 40, c - 40, n - 40], fill=white)
	f = font("sans_b", 96)
	tw = dr.textlength("30", font=f)
	dr.text(((c - tw) / 2, c + 72), "30", font=f, fill=black)
	# (1,1) feux piétons : bonhomme rouge immobile (haut) et vert qui marche (bas), sur fond noir
	dr.rectangle([c, c, n, n], fill=(8, 8, 8, 255))
	cx = c + c / 2
	s = 100
	y1 = c + c * 0.27
	dr.ellipse([cx - s * 0.1, y1 - s * 0.45, cx + s * 0.1, y1 - s * 0.26], fill=(255, 60, 40, 255))
	dr.rectangle([cx - s * 0.14, y1 - s * 0.22, cx + s * 0.14, y1 + s * 0.12], fill=(255, 60, 40, 255))
	dr.rectangle([cx - s * 0.13, y1 + s * 0.1, cx - s * 0.03, y1 + s * 0.42], fill=(255, 60, 40, 255))
	dr.rectangle([cx + s * 0.03, y1 + s * 0.1, cx + s * 0.13, y1 + s * 0.42], fill=(255, 60, 40, 255))
	walker(cx, c + c * 0.78, 92, (60, 255, 140, 255))
	im.save(f"{OUT}/panneaux_a.png")


# ------------------------------------------------------------------ bande podotactile (plots d'éveil de vigilance) : 256 px = 0,4 m
def podo():
	n = 256
	y, x = np.mgrid[0:n, 0:n].astype(float)
	p = n / 6
	dx = (x % p) - p / 2
	dy = (y % p) - p / 2
	d = np.sqrt(dx * dx + dy * dy) / (p * 0.32)
	dome = np.sqrt(np.clip(1 - d * d, 0, 1))
	r = np.random.default_rng(101)
	nz = tile_noise(n, [(30, 1.0)], 102)
	lum = 0.78 + nz * 0.03 + dome * 0.06
	col = np.stack([lum, lum * 0.99, lum * 0.96], -1)
	col *= (1 - np.clip(tile_noise(n, [(4, 1.0)], 103), 0, 2)[..., None] * 0.1)
	save(col, "podo_a.png")
	save_n(dome, 5.0, "podo_n.png")


if __name__ == "__main__":
	trottoir()
	setts("paves", 3)
	setts("paves_route", 4, rows=14, minl=0.18, maxl=0.26, tint=(0.92, 0.93, 0.96))
	bordure()
	ecorce()
	feuilles()
	fontes()
	morris()
	metro()
	kiosque()
	guimard()
	square_tex()
	panneaux()
	podo()
	print("ok")
