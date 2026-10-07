class_name UiKit
extends RefCounted
## Petits composants d'interface soignés (verre sombre, accent ambre) : interrupteur, curseur, bouton,
## capsule de touche, rangée de réglage. Utilisés par le menu Échap.

const AMBER := Color(1.0, 0.72, 0.28)
const AMBER_SOFT := Color(1.0, 0.72, 0.28, 0.18)
const GLASS := Color(0.05, 0.055, 0.085, 0.9)
const GLASS_LIGHT := Color(0.11, 0.12, 0.17, 0.92)
const TEXT := Color(0.94, 0.95, 0.98)
const MUTED := Color(0.94, 0.95, 0.98, 0.58)
const LINE := Color(1, 1, 1, 0.09)

static var _grabber: Texture2D
static var _title_font: Font


static func title_font() -> Font:
	if _title_font == null:
		var f := load("res://assets/fonts/PermanentMarker-Regular.ttf")
		_title_font = f if f is Font else ThemeDB.fallback_font
	return _title_font


static func style(bg: Color, radius := 14, border := LINE, bw := 1, margin := 12.0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
	s.anti_aliasing = true
	return s


static func label(text: String, size := 15, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _grabber_tex() -> Texture2D:
	if _grabber == null:
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		for y in 40:
			for x in 40:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(20, 20))
				var a := clampf(19.0 - d, 0.0, 1.0)
				var ring := clampf(d - 12.0, 0.0, 1.0)
				var col := Color(1.0, 0.86, 0.55).lerp(Color(1.0, 0.72, 0.28), clampf((y - 10.0) / 24.0, 0.0, 1.0))
				col = col.lerp(Color(1, 1, 1), (1.0 - ring) * 0.0)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		_grabber = ImageTexture.create_from_image(img)
	return _grabber


## Bouton principal / secondaire
class Btn extends Button:
	var primary := false
	var _hover := 0.0

	func _init(txt := "", is_primary := false) -> void:
		text = txt
		primary = is_primary
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(0, 52 if is_primary else 46)
		add_theme_font_size_override("font_size", 19 if is_primary else 16)
		add_theme_color_override("font_color", Color(0.1, 0.07, 0.02) if is_primary else UiKit.TEXT)
		add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.02) if is_primary else Color.WHITE)
		add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.02) if is_primary else Color.WHITE)
		add_theme_color_override("font_focus_color", Color(0.1, 0.07, 0.02) if is_primary else Color.WHITE)
		var n := UiKit.style(UiKit.AMBER if is_primary else Color(1, 1, 1, 0.06), 14, Color(1, 1, 1, 0.0) if is_primary else UiKit.LINE, 1, 10.0)
		var h := UiKit.style(Color(1.0, 0.8, 0.42) if is_primary else Color(1, 1, 1, 0.13), 14, UiKit.AMBER if not is_primary else Color(1, 1, 1, 0.5), 1, 10.0)
		var p := UiKit.style(Color(0.9, 0.62, 0.2) if is_primary else Color(1, 1, 1, 0.2), 14, UiKit.AMBER, 1, 10.0)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", h)
		add_theme_stylebox_override("pressed", p)
		add_theme_stylebox_override("focus", h)
		mouse_entered.connect(func(): _tween_scale(1.025))
		mouse_exited.connect(func(): _tween_scale(1.0))
		focus_entered.connect(func(): _tween_scale(1.025))
		focus_exited.connect(func(): _tween_scale(1.0))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5

	func _tween_scale(k: float) -> void:
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE * k, 0.12)


## Interrupteur animé
class Switch extends Control:
	signal toggled(on: bool)
	var on := false:
		set(v):
			on = v
			queue_redraw()
	var _k := 0.0

	func _init(initial := false) -> void:
		on = initial
		_k = 1.0 if initial else 0.0
		custom_minimum_size = Vector2(54, 28)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			on = not on
			toggled.emit(on)
			accept_event()

	func _process(delta: float) -> void:
		var want := 1.0 if on else 0.0
		if absf(_k - want) > 0.001:
			_k = move_toward(_k, want, delta * 9.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var e := _k * _k * (3.0 - 2.0 * _k)
		draw_style_box(UiKit.style(Color(1, 1, 1, 0.1).lerp(UiKit.AMBER, e), int(size.y * 0.5), Color(1, 1, 1, 0.14 * (1.0 - e)), 1, 0.0), r)
		var cx := lerpf(size.y * 0.5, size.x - size.y * 0.5, e)
		draw_circle(Vector2(cx, size.y * 0.5 + 1.0), size.y * 0.5 - 3.0, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(cx, size.y * 0.5), size.y * 0.5 - 3.0, Color(1, 1, 1, 0.96))
		if has_focus():
			draw_arc(Vector2(cx, size.y * 0.5), size.y * 0.5 - 1.0, 0.0, TAU, 24, UiKit.AMBER, 1.5, true)


static func slider(minv: float, maxv: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	var track := style(Color(1, 1, 1, 0.1), 5, Color(0, 0, 0, 0), 0, 0.0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := style(AMBER, 5, Color(0, 0, 0, 0), 0, 0.0)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var gt := _grabber_tex()
	s.add_theme_icon_override("grabber", gt)
	s.add_theme_icon_override("grabber_highlight", gt)
	s.add_theme_icon_override("grabber_disabled", gt)
	return s


static func keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(Color(1, 1, 1, 0.1), 7, Color(1, 1, 1, 0.26), 1, 5.0)
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.border_width_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 13, TEXT))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Ligne de réglage : libellé + description à gauche, contrôle à droite
static func row(title: String, hint: String, control: Control, value_label: Label = null) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(Color(1, 1, 1, 0.035), 12, Color(1, 1, 1, 0.05), 1, 12.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	panel.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 1)
	h.add_child(left)
	left.add_child(label(title, 16, TEXT))
	if hint != "":
		var hl := label(hint, 12, MUTED)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size.x = 230
		left.add_child(hl)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	right.add_child(control)
	if value_label != null:
		value_label.custom_minimum_size.x = 56
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(value_label)
	return panel
