class_name NewsAnchor
extends Control
## Plateau du JT de Canal Continu, dessiné en aplats façon sérigraphie : fond de studio bleu nuit et lumières de
## ville floues, écran d'incrustation (mot-clé du sujet), présentatrice en buste derrière son bureau (bouche
## animée quand elle parle), logo de chaîne, horloge, bandeau « EN DIRECT », titre et ticker défilant.

var headline := ""
var keyword := ""
var ticker := ""
var clock := "20:00"
var talking := false

var _t := 0.0
var _bokeh: Array = []            # [position relative, rayon relatif, couleur]
var _bg: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	for i in 22:
		var warm := rng.randf() < 0.6
		_bokeh.append([Vector2(rng.randf(), rng.randf_range(0.04, 0.7)), rng.randf_range(0.018, 0.06),
			Color(1.0, 0.72, 0.38, rng.randf_range(0.06, 0.16)) if warm else Color(0.45, 0.6, 1.0, rng.randf_range(0.06, 0.14))])
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.13, 0.24))
	g.set_color(1, Color(0.025, 0.03, 0.07))
	_bg = GradientTexture2D.new()
	_bg.gradient = g
	_bg.fill_from = Vector2(0.5, 0.0)
	_bg.fill_to = Vector2(0.5, 1.0)
	_bg.width = 4
	_bg.height = 128


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0:
		return
	draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false)
	for b in _bokeh:
		var p: Vector2 = b[0]
		draw_circle(Vector2(p.x * w, p.y * h), float(b[1]) * h, b[2])
	# écran d'incrustation, à droite
	var sr := Rect2(Vector2(w * 0.6, h * 0.1), Vector2(w * 0.34, h * 0.46))
	draw_style_box(UiStyle.box(Color(UiStyle.RED_DEEP, 0.85), 4, Color(UiStyle.RED, 0.6), 2), sr)
	var ht := UiStyle.halftone_tex()
	draw_texture_rect(ht, sr, true, Color(1, 1, 1, 0.06))
	var kf := UiStyle.font("caps_black")
	var ks := _fit(kf, keyword, sr.size.x * 0.86, int(h * 0.075), 10)
	draw_string(kf, Vector2(sr.position.x + sr.size.x * 0.07, sr.get_center().y + ks * 0.35), keyword, HORIZONTAL_ALIGNMENT_LEFT, -1, ks, UiStyle.PAPER)
	draw_line(Vector2(sr.position.x + sr.size.x * 0.07, sr.get_center().y + ks * 0.75), Vector2(sr.position.x + sr.size.x * 0.4, sr.get_center().y + ks * 0.75), UiStyle.PAPER, 3.0)
	_presenter(w * 0.33, h)
	# bureau
	var desk := PackedVector2Array([Vector2(0, h * 0.8), Vector2(w, h * 0.77), Vector2(w, h), Vector2(0, h)])
	_poly(desk, Color(0.06, 0.06, 0.09))
	draw_line(Vector2(0, h * 0.8), Vector2(w, h * 0.77), UiStyle.RED, maxf(h * 0.008, 2.0), true)
	# logo et horloge
	var lf := UiStyle.font("caps")
	var ls := int(maxf(h * 0.034, 9.0))
	var logo := Rect2(Vector2(w * 0.03, h * 0.05), Vector2(h * 0.09, h * 0.09))
	draw_rect(logo, UiStyle.RED)
	var cc := UiStyle.font("marker")
	draw_string(cc, logo.position + Vector2(logo.size.x * 0.1, logo.size.y * 0.78), "CC", HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.06), UiStyle.PAPER)
	draw_string(lf, Vector2(logo.end.x + h * 0.02, logo.position.y + logo.size.y * 0.42), NewsTexts.CHANNEL, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, UiStyle.PAPER)
	draw_string(lf, Vector2(logo.end.x + h * 0.02, logo.position.y + logo.size.y * 0.92), "LE JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, UiStyle.PAPER_DIM)
	var bf := UiStyle.font("bold")
	var cw := bf.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, ls + 2).x
	draw_string(bf, Vector2(w * 0.97 - cw, h * 0.075 + ls), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, ls + 2, UiStyle.PAPER)
	# bandeau : EN DIRECT, titre, ticker
	var y0 := h * 0.66
	var tagw := lf.get_string_size("EN DIRECT", HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x + h * 0.04
	var blink := 0.75 + 0.25 * sin(_t * 4.0)
	draw_rect(Rect2(Vector2(w * 0.04, y0), Vector2(tagw, h * 0.065)), Color(UiStyle.RED, blink))
	draw_string(lf, Vector2(w * 0.04 + h * 0.02, y0 + h * 0.047), "EN DIRECT", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, UiStyle.PAPER)
	var hr := Rect2(Vector2(w * 0.04, y0 + h * 0.065), Vector2(w * 0.92, h * 0.12))
	draw_rect(hr, UiStyle.PAPER)
	draw_rect(Rect2(hr.position, Vector2(h * 0.012, hr.size.y)), UiStyle.RED)
	var hs := _fit(bf, headline, hr.size.x - h * 0.06, int(h * 0.05), 9)
	var txt := _clip_text(bf, headline, hr.size.x - h * 0.06, hs)
	draw_string(bf, Vector2(hr.position.x + h * 0.035, hr.get_center().y + hs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, UiStyle.INK)
	var tr := Rect2(Vector2(0, hr.end.y + h * 0.02), Vector2(w, h * 0.075))
	draw_rect(tr, Color(UiStyle.INK, 0.94))
	if ticker != "":
		var tf := UiStyle.font("semibold")
		var ts := int(maxf(h * 0.036, 9.0))
		var line := ticker + "   ·   "
		var lw := tf.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var off := fmod(_t * h * 0.16, maxf(lw, 1.0))
		var x := -off
		while x < w:
			draw_string(tf, Vector2(x, tr.get_center().y + ts * 0.36), line, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, UiStyle.PAPER_DIM)
			x += lw
	draw_rect(Rect2(Vector2(0, tr.position.y), Vector2(h * 0.2, tr.size.y)), UiStyle.RED)
	draw_string(lf, Vector2(h * 0.025, tr.get_center().y + ls * 0.36), "INFO", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, UiStyle.PAPER)


## Présentatrice en buste (aplats) ; cx : centre, h : hauteur du cadre
func _presenter(cx: float, h: float) -> void:
	var u := h
	var skin := Color(0.84, 0.64, 0.52)
	var skin_d := Color(0.72, 0.52, 0.42)
	var hair := Color(0.17, 0.1, 0.08)
	var jacket := Color(0.14, 0.17, 0.29)
	var hy := 0.33 * u
	# cheveux (arrière) : carré plongeant
	_oval(Vector2(cx, hy + 0.01 * u), Vector2(0.092 * u, 0.105 * u), hair)
	draw_rect(Rect2(Vector2(cx - 0.092 * u, hy), Vector2(0.184 * u, 0.12 * u)), hair)
	# cou
	draw_rect(Rect2(Vector2(cx - 0.03 * u, hy + 0.06 * u), Vector2(0.06 * u, 0.12 * u)), skin_d)
	# veste et chemisier
	var top := hy + 0.16 * u
	var jac := PackedVector2Array([Vector2(cx - 0.26 * u, u), Vector2(cx - 0.235 * u, top + 0.1 * u), Vector2(cx - 0.17 * u, top + 0.015 * u),
		Vector2(cx - 0.04 * u, top - 0.005 * u), Vector2(cx, top + 0.12 * u), Vector2(cx + 0.04 * u, top - 0.005 * u),
		Vector2(cx + 0.17 * u, top + 0.015 * u), Vector2(cx + 0.235 * u, top + 0.1 * u), Vector2(cx + 0.26 * u, u)])
	_poly(jac, jacket)
	_poly(PackedVector2Array([Vector2(cx - 0.04 * u, top - 0.005 * u), Vector2(cx + 0.04 * u, top - 0.005 * u), Vector2(cx, top + 0.12 * u)]), UiStyle.PAPER)
	_poly(PackedVector2Array([Vector2(cx - 0.028 * u, top - 0.004 * u), Vector2(cx + 0.028 * u, top - 0.004 * u), Vector2(cx, top + 0.05 * u)]), skin_d)
	# revers de la veste
	draw_line(Vector2(cx - 0.04 * u, top), Vector2(cx - 0.012 * u, top + 0.16 * u), Color(0.08, 0.1, 0.18), maxf(u * 0.006, 1.5), true)
	draw_line(Vector2(cx + 0.04 * u, top), Vector2(cx + 0.012 * u, top + 0.16 * u), Color(0.08, 0.1, 0.18), maxf(u * 0.006, 1.5), true)
	# micro-cravate
	draw_circle(Vector2(cx - 0.05 * u, top + 0.06 * u), 0.008 * u, Color(0.05, 0.05, 0.06))
	# visage
	_oval(Vector2(cx, hy), Vector2(0.066 * u, 0.086 * u), skin)
	# frange en biais
	var fr := _ellipse(Vector2(cx, hy - 0.004 * u), Vector2(0.074 * u, 0.094 * u), PI * 1.02, PI * 1.98)
	fr.append(Vector2(cx + 0.072 * u, hy))
	fr.append(Vector2(cx + 0.02 * u, hy - 0.04 * u))
	fr.append(Vector2(cx - 0.06 * u, hy - 0.02 * u))
	_poly(fr, hair)
	# mèches sur les côtés
	_poly(PackedVector2Array([Vector2(cx - 0.074 * u, hy - 0.02 * u), Vector2(cx - 0.058 * u, hy - 0.01 * u),
		Vector2(cx - 0.06 * u, hy + 0.09 * u), Vector2(cx - 0.09 * u, hy + 0.11 * u)]), hair)
	_poly(PackedVector2Array([Vector2(cx + 0.074 * u, hy - 0.02 * u), Vector2(cx + 0.058 * u, hy - 0.01 * u),
		Vector2(cx + 0.06 * u, hy + 0.09 * u), Vector2(cx + 0.09 * u, hy + 0.11 * u)]), hair)
	# yeux (clignement), sourcils, bouche
	var blink := fmod(_t, 4.3) < 0.12
	var ey := hy + 0.004 * u
	for sx: float in [-1.0, 1.0]:
		var ex := cx + sx * 0.026 * u
		if blink:
			draw_line(Vector2(ex - 0.008 * u, ey), Vector2(ex + 0.008 * u, ey), Color(0.15, 0.08, 0.06), maxf(u * 0.004, 1.0))
		else:
			_oval(Vector2(ex, ey), Vector2(0.0075 * u, 0.0055 * u), Color(0.12, 0.07, 0.05))
		draw_line(Vector2(ex - 0.011 * u, ey - 0.017 * u), Vector2(ex + 0.011 * u, ey - 0.019 * u), hair, maxf(u * 0.004, 1.0), true)
	var open := 0.0
	if talking:
		open = absf(sin(_t * 11.0)) * 0.6 + absf(sin(_t * 17.0)) * 0.4
	var my := hy + 0.048 * u
	_oval(Vector2(cx, my), Vector2(0.014 * u, (0.0025 + 0.007 * open) * u), Color(0.5, 0.2, 0.2))
	draw_circle(Vector2(cx - 0.066 * u, hy + 0.02 * u), 0.005 * u, UiStyle.PAPER)
	draw_circle(Vector2(cx + 0.066 * u, hy + 0.02 * u), 0.005 * u, UiStyle.PAPER)


## Polygone plein ; ignoré s'il est dégénéré (la triangulation échouerait)
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, col)


## Ovale plein (cercle mis à l'échelle : pas de triangulation, sûr même tout petit)
func _oval(c: Vector2, r: Vector2, col: Color) -> void:
	if r.x <= 0.01 or r.y <= 0.01:
		return
	draw_set_transform(c, 0.0, Vector2(1.0, r.y / r.x))
	draw_circle(Vector2.ZERO, r.x, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(c: Vector2, r: Vector2, a0: float, a1: float, n := 28) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	if is_equal_approx(a1 - a0, TAU):
		out.remove_at(out.size() - 1)
	return out


## Taille de police pour que `s` tienne dans `maxw` (au moins `min_size`)
func _fit(f: Font, s: String, maxw: float, start: int, min_size: int) -> int:
	var fs := maxi(start, min_size)
	while fs > min_size and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 1
	return fs


func _clip_text(f: Font, s: String, maxw: float, fs: int) -> String:
	if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= maxw:
		return s
	var t := s
	while t.length() > 4 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		t = t.left(t.length() - 1)
	return t.strip_edges() + "…"
