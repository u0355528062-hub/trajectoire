class_name DialogueChoice
extends PanelContainer
## Une option de choix de dialogue, à la charte (UiStyle) : capsule de touche (1-4), texte de l'option.
## Panneau d'encre ; au survol (souris ou flèches) : papier crème, encre, ombre rouge décalée de sérigraphie.

signal picked(index: int)

var index := 0
var hot := false
var _n: StyleBoxFlat
var _h: StyleBoxFlat
var _label: Label
var _cap: PanelContainer


func setup(i: int, text: String) -> void:
	index = i
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_n = UiStyle.box(Color(UiStyle.INK, 0.8), 4, Color(UiStyle.PAPER, 0.12), 1, 0.0)
	_h = UiStyle.print_shadow(UiStyle.box(UiStyle.PAPER, 4, UiStyle.PAPER, 1, 0.0), UiStyle.RED, Vector2(5, 4))
	for s in [_n, _h]:
		s.content_margin_left = 12
		s.content_margin_right = 18
		s.content_margin_top = 9
		s.content_margin_bottom = 9
	add_theme_stylebox_override("panel", _n)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_cap = UiStyle.keycap(str(i + 1), 14)
	_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cap)
	_label = UiStyle.label(text, 19, UiStyle.PAPER, "semibold")
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	mouse_entered.connect(func() -> void: set_hot(true))
	mouse_exited.connect(func() -> void: set_hot(false))


func set_hot(on: bool) -> void:
	if on == hot:
		return
	hot = on
	add_theme_stylebox_override("panel", _h if on else _n)
	_label.add_theme_color_override("font_color", UiStyle.INK if on else UiStyle.PAPER)


## Retour visuel du choix retenu
func flash() -> void:
	set_hot(true)
	var s := _h.duplicate() as StyleBoxFlat
	s.bg_color = UiStyle.RED
	s.shadow_color = UiStyle.INK
	add_theme_stylebox_override("panel", s)
	_label.add_theme_color_override("font_color", UiStyle.PAPER)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		picked.emit(index)
