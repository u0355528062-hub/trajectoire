class_name UITheme
extends RefCounted
## Thème visuel de l'interface : palette, typographie et styles.

const BG := Color(0.035, 0.055, 0.09)
const PANEL := Color(0.055, 0.08, 0.125, 0.94)
const PANEL_SOFT := Color(0.09, 0.125, 0.18, 0.96)
const LINE := Color(1, 1, 1, 0.08)
const TEXT := Color(0.92, 0.95, 0.98)
const MUTED := Color(0.56, 0.63, 0.72)
const ACCENT := Color(0.18, 0.83, 0.75)
const ACCENT_2 := Color(0.22, 0.74, 0.97)
const DANGER := Color(0.96, 0.25, 0.37)
const WARNING := Color(0.96, 0.62, 0.04)
const SUCCESS := Color(0.13, 0.77, 0.37)

static var _theme: Theme
static var _fonts: Dictionary = {}


static func font(weight: String) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var path: String = {
		"regular": "res://assets/fonts/Inter-Regular.ttf",
		"medium": "res://assets/fonts/Inter-Medium.ttf",
		"semibold": "res://assets/fonts/Inter-SemiBold.ttf",
		"bold": "res://assets/fonts/Inter-Bold.ttf",
		"display": "res://assets/fonts/InterDisplay-Bold.ttf",
		"light": "res://assets/fonts/InterDisplay-Light.ttf",
	}.get(weight, "res://assets/fonts/Inter-Regular.ttf")
	var f: Font = load(path)
	_fonts[weight] = f
	return f


static func spaced(weight: String, spacing: int) -> FontVariation:
	var key := "%s_sp%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = font(weight)
	fv.spacing_glyph = spacing
	_fonts[key] = fv
	return fv


static func box(bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad_h: int = 16, pad_v: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func card(radius: int = 20, alpha: float = 0.94) -> StyleBoxFlat:
	var s := box(Color(PANEL.r, PANEL.g, PANEL.b, alpha), radius, LINE, 1, 28, 24)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 30
	s.shadow_offset = Vector2(0, 10)
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = 18

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 4)
	_variation(t, "Title", "Label", font("display"), 56, TEXT)
	_variation(t, "H1", "Label", font("display"), 36, TEXT)
	_variation(t, "H2", "Label", font("bold"), 24, TEXT)
	_variation(t, "H3", "Label", font("semibold"), 19, TEXT)
	_variation(t, "Body", "Label", font("regular"), 17, TEXT)
	_variation(t, "Muted", "Label", font("regular"), 16, MUTED)
	_variation(t, "Caption", "Label", spaced("semibold", 2), 12, MUTED)
	_variation(t, "AccentCaption", "Label", spaced("bold", 2), 12, ACCENT)
	_variation(t, "Mono", "Label", font("medium"), 30, TEXT)
	_variation(t, "Big", "Label", font("display"), 72, TEXT)

	# Boutons
	t.set_font("font", "Button", font("semibold"))
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_constant("h_separation", "Button", 10)
	t.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.05), 12, Color(1, 1, 1, 0.09), 1, 18, 12))
	t.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.1), 12, Color(ACCENT, 0.55), 1, 18, 12))
	t.set_stylebox("pressed", "Button", box(Color(ACCENT, 0.22), 12, ACCENT, 1, 18, 12))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.02), 12, Color(1, 1, 1, 0.04), 1, 18, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, Color(ACCENT, 0.8), 2, 18, 12))

	_button_variation(t, "PrimaryButton", ACCENT, Color(0.02, 0.1, 0.1))
	_button_variation(t, "DangerButton", DANGER, Color.WHITE)
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", box(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0, 14, 10))
	t.set_stylebox("hover", "GhostButton", box(Color(1, 1, 1, 0.07), 10, Color(0, 0, 0, 0), 0, 14, 10))
	t.set_stylebox("pressed", "GhostButton", box(Color(1, 1, 1, 0.12), 10, Color(0, 0, 0, 0), 0, 14, 10))
	t.set_color("font_color", "GhostButton", MUTED)
	t.set_color("font_hover_color", "GhostButton", TEXT)

	t.set_type_variation("MenuButtonBig", "Button")
	t.set_font("font", "MenuButtonBig", font("semibold"))
	t.set_font_size("font_size", "MenuButtonBig", 20)
	t.set_stylebox("normal", "MenuButtonBig", box(Color(1, 1, 1, 0.0), 14, Color(0, 0, 0, 0), 0, 22, 14))
	t.set_stylebox("hover", "MenuButtonBig", box(Color(1, 1, 1, 0.07), 14, Color(ACCENT, 0.0), 0, 22, 14))
	t.set_stylebox("pressed", "MenuButtonBig", box(Color(ACCENT, 0.18), 14, Color(0, 0, 0, 0), 0, 22, 14))
	t.set_stylebox("disabled", "MenuButtonBig", box(Color(0, 0, 0, 0), 14, Color(0, 0, 0, 0), 0, 22, 14))
	t.set_stylebox("focus", "MenuButtonBig", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "MenuButtonBig", Color(MUTED, 0.45))

	# Option « puce » sélectionnable (examens, traitements…)
	t.set_type_variation("Chip", "Button")
	t.set_font("font", "Chip", font("medium"))
	t.set_font_size("font_size", "Chip", 16)
	t.set_stylebox("normal", "Chip", box(Color(1, 1, 1, 0.045), 12, Color(1, 1, 1, 0.08), 1, 16, 12))
	t.set_stylebox("hover", "Chip", box(Color(1, 1, 1, 0.09), 12, Color(ACCENT, 0.5), 1, 16, 12))
	t.set_stylebox("pressed", "Chip", box(Color(ACCENT, 0.2), 12, ACCENT, 2, 16, 12))
	t.set_stylebox("hover_pressed", "Chip", box(Color(ACCENT, 0.26), 12, ACCENT, 2, 16, 12))
	t.set_stylebox("disabled", "Chip", box(Color(1, 1, 1, 0.025), 12, Color(1, 1, 1, 0.05), 1, 16, 12))
	t.set_stylebox("focus", "Chip", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Chip", Color(TEXT, 0.55))
	t.set_color("font_pressed_color", "Chip", Color.WHITE)

	# Onglets maison
	t.set_type_variation("TabButton", "Button")
	t.set_font("font", "TabButton", font("semibold"))
	t.set_font_size("font_size", "TabButton", 16)
	t.set_color("font_color", "TabButton", MUTED)
	t.set_color("font_pressed_color", "TabButton", Color(0.02, 0.1, 0.1))
	t.set_color("font_hover_pressed_color", "TabButton", Color(0.02, 0.1, 0.1))
	t.set_stylebox("normal", "TabButton", box(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0, 18, 10))
	t.set_stylebox("hover", "TabButton", box(Color(1, 1, 1, 0.06), 10, Color(0, 0, 0, 0), 0, 18, 10))
	t.set_stylebox("pressed", "TabButton", box(ACCENT, 10, Color(0, 0, 0, 0), 0, 18, 10))
	t.set_stylebox("hover_pressed", "TabButton", box(ACCENT.lightened(0.1), 10, Color(0, 0, 0, 0), 0, 18, 10))
	t.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())

	# Panneaux
	t.set_stylebox("panel", "PanelContainer", card())
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card())
	t.set_type_variation("SoftCard", "PanelContainer")
	t.set_stylebox("panel", "SoftCard", box(Color(1, 1, 1, 0.04), 14, Color(1, 1, 1, 0.06), 1, 18, 14))
	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", box(Color(PANEL, 0.82), 999, LINE, 1, 16, 8))

	# Texte riche
	t.set_font("normal_font", "RichTextLabel", font("regular"))
	t.set_font("bold_font", "RichTextLabel", font("bold"))
	t.set_font("italics_font", "RichTextLabel", font("medium"))
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("line_separation", "RichTextLabel", 5)

	# Barres de progression
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.08), 999, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 999, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)

	# Curseurs
	var slider_bg := box(Color(1, 1, 1, 0.1), 999, Color(0, 0, 0, 0), 0, 0, 3)
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 999, Color(0, 0, 0, 0), 0, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.15), 999, Color(0, 0, 0, 0), 0, 0, 3))
	t.set_icon("grabber", "HSlider", _circle_icon(18, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(20, Color.WHITE))

	# Interrupteurs
	t.set_font("font", "CheckButton", font("medium"))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())

	# Barres de défilement fines
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, box(Color(0, 0, 0, 0), 999, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber", sb, box(Color(1, 1, 1, 0.14), 999, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_highlight", sb, box(Color(1, 1, 1, 0.25), 999, Color(0, 0, 0, 0), 0, 3, 3))
		t.set_stylebox("grabber_pressed", sb, box(Color(ACCENT, 0.6), 999, Color(0, 0, 0, 0), 0, 3, 3))

	t.set_stylebox("separator", "HSeparator", box(LINE, 0, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 1)

	t.set_stylebox("panel", "TooltipPanel", box(PANEL_SOFT, 8, LINE, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)

	_theme = t
	return t


static func _variation(t: Theme, name: String, base: String, f: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, base)
	t.set_font("font", name, f)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


static func _button_variation(t: Theme, name: String, color: Color, text: Color) -> void:
	t.set_type_variation(name, "Button")
	t.set_font("font", name, font("bold"))
	t.set_stylebox("normal", name, box(color, 12, Color(0, 0, 0, 0), 0, 22, 13))
	t.set_stylebox("hover", name, box(color.lightened(0.12), 12, Color(0, 0, 0, 0), 0, 22, 13))
	t.set_stylebox("pressed", name, box(color.darkened(0.12), 12, Color(0, 0, 0, 0), 0, 22, 13))
	t.set_stylebox("disabled", name, box(Color(color, 0.25), 12, Color(0, 0, 0, 0), 0, 22, 13))
	t.set_stylebox("focus", name, box(Color(0, 0, 0, 0), 12, Color(1, 1, 1, 0.7), 2, 22, 13))
	t.set_color("font_color", name, text)
	t.set_color("font_hover_color", name, text)
	t.set_color("font_pressed_color", name, text)
	t.set_color("font_focus_color", name, text)
	t.set_color("font_disabled_color", name, Color(text, 0.5))


static func _circle_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


# --- Aides de mise en page -------------------------------------------------------------

static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, variation: String = "", cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(color, 0.16), 999, Color(color, 0.45), 1, 10, 3))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", spaced("bold", 1))
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color.lightened(0.2))
	p.add_child(l)
	return p


static func fade_in(c: Control, duration: float = 0.25) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration)
