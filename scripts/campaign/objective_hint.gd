class_name ObjectiveHint
extends PanelContainer
## Aide contextuelle (hint) : carte d'encre à liseré jaune centrée en haut de l'écran, sous la jauge de tension,
## intitulé « CONSEIL », texte court. Apparaît en fondu ; une nouvelle aide remplace la précédente avec un rebond.

const MAX_W := 540.0

var _label: Label
var _left := 0.0
var _a := 0.0
var _text := ""


func _ready() -> void:
	var st := UiStyle.ink_panel(0.0, 6)
	st.content_margin_left = 18
	st.content_margin_right = 20
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	st.border_width_left = 4
	st.border_color = UiStyle.YELLOW
	add_theme_stylebox_override("panel", st)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 214.0
	offset_bottom = 214.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(UiStyle.label("CONSEIL", 11, UiStyle.YELLOW, "caps"))
	_label = UiStyle.label("", 16, UiStyle.PAPER, "regular")
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_label)


func show_text(text: String, sec := 5.0) -> void:
	_text = text
	_left = maxf(sec, 1.5) if text != "" else 0.0
	if text == "":
		return
	_label.text = text
	# largeur : au plus MAX_W, ajustée au texte
	var f := UiStyle.font("regular")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_label.custom_minimum_size.x = clampf(w + 2.0, 160.0, MAX_W)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 214.0
	offset_bottom = 214.0
	visible = true
	reset_size()
	if _a > 0.3:
		UiStyle.pop(self, 1.04, 0.25)


func current() -> String:
	return _text if _left > 0.0 else ""


func _process(delta: float) -> void:
	_left -= delta
	_a = UiStyle.damp(_a, 1.0 if _left > 0.0 else 0.0, 7.0, delta)
	modulate.a = _a
	if _a < 0.01 and _left <= 0.0:
		visible = false
