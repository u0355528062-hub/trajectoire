class_name UiKit
extends RefCounted
## Composants d'interface aux couleurs de la charte (voir UiStyle) : bouton (principal, secondaire,
## segment, onglet, discret), interrupteur, curseur, capsule de touche, rangée de réglage.
## Utilisés par le menu Échap, les réglages et l'écran titre.

# Anciens noms conservés : ils pointent vers la nouvelle palette
const AMBER := UiStyle.RED
const AMBER_SOFT := Color(0.925, 0.2, 0.15, 0.18)
const GLASS := UiStyle.INK_PANEL
const GLASS_LIGHT := Color(0.1, 0.095, 0.105, 0.94)
const TEXT := UiStyle.PAPER
const MUTED := UiStyle.PAPER_DIM
const LINE := UiStyle.LINE


static func title_font() -> Font:
	return UiStyle.font("marker")


static func style(bg: Color, radius := 6, border := LINE, bw := 1, margin := 12.0, shadow := 0) -> StyleBoxFlat:
	var s := UiStyle.box(bg, radius, border, bw, margin)
	if shadow > 0:
		UiStyle.soft_shadow(s, 0.5, shadow, Vector2(0, 6))
	return s


static func label(text: String, size := 16, color := TEXT, kind := "regular") -> Label:
	return UiStyle.label(text, size, color, kind)


## Bouton. Variantes : "primary" (rouge), "secondary" (encre), "seg" (segment de choix),
## "tab" (onglet souligné), "ghost" (discret, pour « Retour »). Au survol : papier crème et ombre
## rouge décalée, petit rebond.
class Btn extends Button:
	var kind := "secondary"
	var _hover_k := 0.0

	func _init(txt := "", is_primary := false, variant := "") -> void:
		text = txt
		kind = variant if variant != "" else ("primary" if is_primary else "secondary")
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		match kind:
			"primary":
				_setup(UiStyle.RED, UiStyle.PAPER, 56, 19, "caps")
			"secondary":
				_setup(Color(UiStyle.PAPER, 0.05), UiStyle.PAPER, 50, 17, "caps")
			"seg":
				_setup_seg()
			"tab":
				_setup_tab()
			"ghost":
				_setup_ghost()
		mouse_entered.connect(func(): _hover(true))
		mouse_exited.connect(func(): _hover(false))
		focus_entered.connect(func(): _hover(true))
		focus_exited.connect(func(): _hover(false))

	func _setup(bg: Color, fg: Color, h: int, fs: int, font_kind: String) -> void:
		custom_minimum_size = Vector2(0, h)
		add_theme_font_override("font", UiStyle.font(font_kind))
		add_theme_font_size_override("font_size", fs)
		var n := UiStyle.box(bg, 4, Color(UiStyle.PAPER, 0.0 if kind == "primary" else 0.14), 0 if kind == "primary" else 1, 12.0)
		var hv := UiStyle.print_shadow(UiStyle.box(UiStyle.PAPER, 4, UiStyle.PAPER, 0, 12.0), UiStyle.RED, Vector2(5, 5))
		var p := UiStyle.box(UiStyle.RED_DEEP if kind == "primary" else UiStyle.RED, 4, UiStyle.RED, 0, 12.0)
		var d := UiStyle.box(Color(UiStyle.PAPER, 0.03), 4, Color(UiStyle.PAPER, 0.06), 1, 12.0)
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("hover_pressed", hv)
		add_theme_stylebox_override("pressed", p)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_theme_stylebox_override("disabled", d)
		add_theme_color_override("font_color", fg)
		add_theme_color_override("font_hover_color", UiStyle.INK)
		add_theme_color_override("font_hover_pressed_color", UiStyle.INK)
		add_theme_color_override("font_pressed_color", UiStyle.PAPER)
		add_theme_color_override("font_focus_color", fg)
		add_theme_color_override("font_disabled_color", UiStyle.PAPER_MUTE)

	func _setup_seg() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(0, 38)
		add_theme_font_override("font", UiStyle.font("semibold"))
		add_theme_font_size_override("font_size", 15)
		var n := UiStyle.box(Color(UiStyle.PAPER, 0.04), 3, Color(UiStyle.PAPER, 0.14), 1, 8.0)
		n.content_margin_left = 14
		n.content_margin_right = 14
		var hv := UiStyle.box(Color(UiStyle.PAPER, 0.14), 3, Color(UiStyle.PAPER, 0.4), 1, 8.0)
		hv.content_margin_left = 14
		hv.content_margin_right = 14
		var on := UiStyle.print_shadow(UiStyle.box(UiStyle.PAPER, 3, UiStyle.PAPER, 1, 8.0), UiStyle.RED, Vector2(3, 3))
		on.content_margin_left = 14
		on.content_margin_right = 14
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", on)
		add_theme_stylebox_override("hover_pressed", on)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_theme_color_override("font_color", UiStyle.PAPER_DIM)
		add_theme_color_override("font_hover_color", UiStyle.PAPER)
		add_theme_color_override("font_pressed_color", UiStyle.INK)
		add_theme_color_override("font_hover_pressed_color", UiStyle.INK)
		add_theme_color_override("font_focus_color", UiStyle.PAPER)

	func _setup_tab() -> void:
		toggle_mode = true
		custom_minimum_size = Vector2(0, 46)
		add_theme_font_override("font", UiStyle.font("caps"))
		add_theme_font_size_override("font_size", 16)
		var n := UiStyle.box(Color(0, 0, 0, 0), 0, Color(UiStyle.PAPER, 0.0), 0, 10.0)
		n.border_width_bottom = 3
		n.content_margin_left = 18
		n.content_margin_right = 18
		var hv := n.duplicate() as StyleBoxFlat
		hv.border_color = Color(UiStyle.PAPER, 0.25)
		var on := n.duplicate() as StyleBoxFlat
		on.border_color = UiStyle.RED
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", on)
		add_theme_stylebox_override("hover_pressed", on)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_theme_color_override("font_color", UiStyle.PAPER_MUTE)
		add_theme_color_override("font_hover_color", UiStyle.PAPER_DIM)
		add_theme_color_override("font_pressed_color", UiStyle.PAPER)
		add_theme_color_override("font_hover_pressed_color", UiStyle.PAPER)
		add_theme_color_override("font_focus_color", UiStyle.PAPER)

	func _setup_ghost() -> void:
		custom_minimum_size = Vector2(0, 40)
		add_theme_font_override("font", UiStyle.font("caps"))
		add_theme_font_size_override("font_size", 14)
		var n := UiStyle.box(Color(0, 0, 0, 0), 4, Color(UiStyle.PAPER, 0.16), 1, 8.0)
		n.content_margin_left = 14
		n.content_margin_right = 16
		var hv := UiStyle.box(UiStyle.PAPER, 4, UiStyle.PAPER, 1, 8.0)
		hv.content_margin_left = 14
		hv.content_margin_right = 16
		add_theme_stylebox_override("normal", n)
		add_theme_stylebox_override("hover", hv)
		add_theme_stylebox_override("pressed", hv)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_theme_color_override("font_color", UiStyle.PAPER_DIM)
		add_theme_color_override("font_hover_color", UiStyle.INK)
		add_theme_color_override("font_pressed_color", UiStyle.INK)
		add_theme_color_override("font_focus_color", UiStyle.PAPER)
		add_theme_color_override("icon_normal_color", UiStyle.PAPER_DIM)
		add_theme_color_override("icon_hover_color", UiStyle.INK)
		add_theme_color_override("icon_pressed_color", UiStyle.INK)
		add_theme_color_override("icon_focus_color", UiStyle.PAPER)
		add_theme_constant_override("icon_max_width", 14)
		add_theme_constant_override("h_separation", 8)
		icon = UiIcons.tex("chevron", 28)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5

	func _hover(on: bool) -> void:
		if kind == "tab" or kind == "seg":
			return
		pivot_offset = size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE * (1.03 if on else 1.0), 0.16)


## Interrupteur animé : pilule rouge quand activé, pastille crème
class Switch extends Control:
	signal toggled(on: bool)
	var on := false:
		set(v):
			on = v
			queue_redraw()
	var _k := 0.0
	var _hov := false

	func _init(initial := false) -> void:
		on = initial
		_k = 1.0 if initial else 0.0
		custom_minimum_size = Vector2(58, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hov = true; queue_redraw())
		mouse_exited.connect(func(): _hov = false; queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or e.is_action_pressed("ui_accept"):
			on = not on
			toggled.emit(on)
			accept_event()

	func _process(delta: float) -> void:
		var want := 1.0 if on else 0.0
		if absf(_k - want) > 0.001:
			_k = move_toward(_k, want, delta * 7.0)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var e := UiStyle.smooth(_k)
		var bg := Color(UiStyle.PAPER, 0.1 if not _hov else 0.16).lerp(UiStyle.RED, e)
		draw_style_box(UiStyle.box(bg, int(size.y * 0.5), Color(UiStyle.PAPER, 0.22 * (1.0 - e)), 1, 0.0), r)
		var rad := size.y * 0.5 - 4.0
		var cx := lerpf(size.y * 0.5, size.x - size.y * 0.5, e)
		draw_circle(Vector2(cx + 1.0, size.y * 0.5 + 1.5), rad, Color(0, 0, 0, 0.3), true, -1.0, true)
		draw_circle(Vector2(cx, size.y * 0.5), rad, UiStyle.PAPER, true, -1.0, true)
		if e > 0.5:
			var tk := UiIcons.tex("check", 32)
			var s := rad * 1.1
			draw_texture_rect(tk, Rect2(cx - s * 0.5, size.y * 0.5 - s * 0.5, s, s), false, Color(UiStyle.RED, (e - 0.5) * 2.0))
		if has_focus():
			draw_style_box(UiStyle.box(Color(0, 0, 0, 0), int(size.y * 0.5) + 3, UiStyle.PAPER, 2, 0.0), r.grow(3.0))


static func slider(minv: float, maxv: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(240, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := UiStyle.box(Color(UiStyle.PAPER, 0.14), 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := UiStyle.box(UiStyle.RED, 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", UiIcons.tex("grab", 24))
	s.add_theme_icon_override("grabber_highlight", UiIcons.tex("grab_hl", 26))
	s.add_theme_icon_override("grabber_disabled", UiIcons.tex("grab", 24))
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return s


static func keycap(text: String) -> PanelContainer:
	return UiStyle.keycap(text, 15)


## Ligne de réglage : intitulé + description à gauche, contrôle à droite, filet en dessous.
## S'éclaire légèrement au survol.
static func row(title: String, hint: String, control: Control, value_label: Label = null) -> Control:
	var panel := PanelContainer.new()
	var st := UiStyle.box(Color(UiStyle.PAPER, 0.0), 4, UiStyle.LINE, 0, 0.0)
	st.border_width_bottom = 1
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", st)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.mouse_entered.connect(func(): st.bg_color = Color(UiStyle.PAPER, 0.04))
	panel.mouse_exited.connect(func(): st.bg_color = Color(UiStyle.PAPER, 0.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 2)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(left)
	left.add_child(UiStyle.label(title, 18, UiStyle.PAPER, "semibold"))
	if hint != "":
		var hl := UiStyle.label(hint, 14, UiStyle.PAPER_MUTE)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size.x = 260
		left.add_child(hl)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	right.add_child(control)
	if value_label != null:
		value_label.custom_minimum_size.x = 64
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(value_label)
	return panel
