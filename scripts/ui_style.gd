class_name UiStyle
extends RefCounted
## Charte graphique de toute l'interface, façon « affiche militante / sérigraphie » :
## encre noire translucide, papier crème, rouge vif d'accent, jaune signalétique pour les alertes.
## Titres en Permanent Marker, texte en Inter. Fournit le thème Godot partagé (appliqué à la fenêtre),
## les polices, des fabriques de styles et de libellés, et quelques animations communes.

# ------------------------------------------------------------------ couleurs
const INK := Color(0.063, 0.058, 0.066)                 ## noir d'encre
const INK_PANEL := Color(0.05, 0.046, 0.055, 0.86)      ## panneau d'encre translucide
const INK_SOFT := Color(0.05, 0.046, 0.055, 0.62)
const PAPER := Color(0.953, 0.925, 0.86)                ## papier crème
const PAPER_DIM := Color(0.953, 0.925, 0.86, 0.66)
const PAPER_MUTE := Color(0.953, 0.925, 0.86, 0.42)
const PAPER_FAINT := Color(0.953, 0.925, 0.86, 0.13)
const LINE := Color(0.953, 0.925, 0.86, 0.11)
const RED := Color(0.925, 0.2, 0.15)                    ## rouge d'accent
const RED_DEEP := Color(0.56, 0.08, 0.06)
const YELLOW := Color(1.0, 0.82, 0.16)                  ## jaune signalétique (alertes)
const BLUE := Color(0.26, 0.5, 1.0)                     ## gyrophare
## Couleur de chaque stade de tension, de CALME à ÉMEUTE
const STAGE_COL := [Color(0.6, 0.8, 0.62), Color(1.0, 0.82, 0.16), Color(1.0, 0.55, 0.12), Color(0.93, 0.24, 0.16), Color(1.0, 0.12, 0.24)]

const _FONT_FILES := {
	"marker": "PermanentMarker-Regular.ttf",
	"regular": "Inter-Regular.otf",
	"semibold": "Inter-SemiBold.otf",
	"bold": "Inter-Bold.otf",
	"black": "InterDisplay-Black.otf",
}

static var _fonts := {}
static var _theme: Theme
static var _tex := {}


# ------------------------------------------------------------------ polices
## Police par usage : "marker" (titres), "regular", "semibold", "bold", "black" (chiffres),
## "caps" (petites capitales espacées pour les intitulés)
static func font(kind := "regular") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	if kind == "caps" or kind == "caps_black":
		var fv := FontVariation.new()
		fv.base_font = font("bold" if kind == "caps" else "black")
		fv.spacing_glyph = 2 if kind == "caps" else 1
		f = fv
	else:
		var r: Variant = load("res://assets/fonts/" + str(_FONT_FILES.get(kind, "Inter-Regular.otf")))
		f = r if r is Font else ThemeDB.fallback_font
	_fonts[kind] = f
	return f


# ------------------------------------------------------------------ thème partagé
## Thème appliqué à la fenêtre racine : Inter partout, boutons, barres de défilement, info-bulles
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = 18
	t.set_color("font_color", "Label", PAPER)
	# barres de défilement fines
	for sb in ["VScrollBar", "HScrollBar"]:
		var track := box(Color(1, 1, 1, 0.0), 3)
		track.set_content_margin_all(3)
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("scroll_focus", sb, track)
		var g := box(Color(PAPER, 0.22), 3)
		g.set_content_margin_all(3)
		t.set_stylebox("grabber", sb, g)
		var gh := box(Color(PAPER, 0.42), 3)
		gh.set_content_margin_all(3)
		t.set_stylebox("grabber_highlight", sb, gh)
		var gp := box(RED, 3)
		gp.set_content_margin_all(3)
		t.set_stylebox("grabber_pressed", sb, gp)
	# info-bulles
	var tip := box(INK, 4, Color(PAPER, 0.2), 1, 8.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# boutons par défaut (les écrans utilisent surtout UiKit.Btn)
	t.set_stylebox("normal", "Button", box(Color(PAPER, 0.06), 4, LINE, 1, 10.0))
	t.set_stylebox("hover", "Button", box(Color(PAPER, 0.14), 4, Color(PAPER, 0.3), 1, 10.0))
	t.set_stylebox("pressed", "Button", box(RED, 4, RED, 1, 10.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", PAPER)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_focus_color", "Button", PAPER)
	_theme = t
	return t


## Applique le thème partagé à la fenêtre (une fois suffit, appelé par chaque écran)
static func apply_theme(tree: SceneTree) -> void:
	if tree != null and tree.root != null and tree.root.theme != theme():
		tree.root.theme = theme()


# ------------------------------------------------------------------ boîtes
## Boîte plate : coins maîtrisés (petits rayons), bordure fine facultative
static func box(bg: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, margin := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	s.corner_detail = 6
	return s


## Ombre douce portée
static func soft_shadow(s: StyleBoxFlat, a := 0.45, size := 14, off := Vector2(0, 5)) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, a)
	s.shadow_size = size
	s.shadow_offset = off
	return s


## Ombre nette décalée, comme un second passage de sérigraphie mal calé
static func print_shadow(s: StyleBoxFlat, col := RED, off := Vector2(5, 5)) -> StyleBoxFlat:
	s.shadow_color = col
	s.shadow_size = 1
	s.shadow_offset = off
	return s


## Panneau d'encre standard du HUD
static func ink_panel(margin := 12.0, radius := 8) -> StyleBoxFlat:
	return soft_shadow(box(INK_PANEL, radius, Color(PAPER, 0.08), 1, margin), 0.35, 12, Vector2(0, 4))


# ------------------------------------------------------------------ texte
static func label(text: String, size := 18, color := PAPER, kind := "regular") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Contour d'encre (texte posé directement sur la scène 3D)
static func ink_outline(l: Label, size := 6, a := 0.75) -> Label:
	l.add_theme_color_override("font_outline_color", Color(INK, a))
	l.add_theme_constant_override("outline_size", size)
	return l


## Ombre décalée de titre (rouge par défaut), effet de repérage sérigraphique
static func misprint(l: Label, col := RED, off := Vector2(5, 4)) -> Label:
	l.add_theme_color_override("font_shadow_color", col)
	l.add_theme_constant_override("shadow_offset_x", int(off.x))
	l.add_theme_constant_override("shadow_offset_y", int(off.y))
	l.add_theme_constant_override("shadow_outline_size", 0)
	return l


## Capsule de touche : papier crème, lettres d'encre, tranche plus épaisse en bas.
## « CLIC GAUCHE », « CLIC DROIT » et « MOLETTE » deviennent une souris dessinée.
static func keycap(text: String, size := 15, bg := PAPER, fg := INK) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := box(bg, 4, bg.darkened(0.5), 0, 0.0)
	s.border_width_bottom = 3
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	var mouse := {"CLIC GAUCHE": "mouse_l", "CLIC DROIT": "mouse_r", "MOLETTE": "mouse_wheel"}
	if mouse.has(text):
		s.content_margin_left = 4
		s.content_margin_right = 4
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		var tr := TextureRect.new()
		tr.texture = UiIcons.tex(mouse[text], 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(size * 1.25, size * 1.45)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
		p.tooltip_text = text.capitalize()
		return p
	var l := label(text, size, fg, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = float(size) * 0.9
	p.add_child(l)
	return p


## Rangée « touches + action »
static func key_row(keys: Array, action: String, size := 15, text_col := PAPER_DIM) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		h.add_child(keycap(str(k), size))
	var sp := Control.new()
	sp.custom_minimum_size.x = 4
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var l := label(action, size + 1, text_col, "semibold")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


# ------------------------------------------------------------------ textures générées
## Dégradé radial plein écran (bords colorés, centre transparent) : flashs de stade, voiles
static func edge_tex() -> Texture2D:
	if _tex.has("edge"):
		return _tex["edge"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 1.0))
	g.add_point(0.55, Color(1, 1, 1, 0.0))
	g.add_point(0.85, Color(1, 1, 1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.08, 1.08)
	gt.width = 256
	gt.height = 256
	_tex["edge"] = gt
	return gt


## Halo radial (centre opaque, bords transparents) : fond de la roue des gestes, taches d'encre
static func spot_tex() -> Texture2D:
	if _tex.has("spot"):
		return _tex["spot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.55, Color(1, 1, 1, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_tex["spot"] = gt
	return gt


## Trame de points de sérigraphie (motif à répéter)
static func halftone_tex() -> Texture2D:
	if _tex.has("halftone"):
		return _tex["halftone"]
	var t: Texture2D = null
	if ResourceLoader.exists("res://assets/ui/halftone.png"):
		t = load("res://assets/ui/halftone.png")
	if t == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 0))
		for y in 8:
			for x in 8:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(4, 4))
				img.set_pixel(x, y, Color(1, 1, 1, clampf(2.2 - d, 0.0, 1.0)))
		t = ImageTexture.create_from_image(img)
	_tex["halftone"] = t
	return t


# ------------------------------------------------------------------ animations
## Petit rebond (sélection, valeur qui change)
static func pop(c: Control, k := 1.12, dur := 0.28) -> Tween:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * k, dur * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Interpolation exponentielle indépendante de la cadence
static func damp(a: float, b: float, rate: float, delta: float) -> float:
	return lerpf(a, b, 1.0 - exp(-rate * delta))


## Courbe douce 0..1
static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
