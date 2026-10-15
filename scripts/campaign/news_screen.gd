class_name NewsScreen
extends Control
## Base des écrans plein écran des actualités (bilan façon JT, échec, fin) : fond d'encre tramé, apparitions
## en cascade, boutons UiKit (le premier a le focus : Entrée valide). Émet `answered(i)` avec l'index du bouton.

signal answered(i: int)

var _t := 0.0
var _buttons: Array = []


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta


## Fond : encre, trame de sérigraphie, halo de couleur sur les bords
func backdrop(tint: Color, a := 0.97) -> void:
	var bg := ColorRect.new()
	bg.color = Color(UiStyle.INK, a)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var ht := TextureRect.new()
	ht.texture = UiStyle.halftone_tex()
	ht.stretch_mode = TextureRect.STRETCH_TILE
	ht.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ht.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ht.modulate = Color(1, 1, 1, 0.035)
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ht)
	var edge := TextureRect.new()
	edge.texture = UiStyle.edge_tex()
	edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	edge.stretch_mode = TextureRect.STRETCH_SCALE
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge.modulate = tint
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)


## Bouton de réponse (index = ordre de création)
func button(text: String, primary: bool) -> Button:
	var b := UiKit.Btn.new(text, primary)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x, 240.0)
	var i := _buttons.size()
	b.pressed.connect(func() -> void: _answer(i))
	_buttons.append(b)
	return b


func focus_first() -> void:
	if not _buttons.is_empty() and is_inside_tree():
		(_buttons[0] as Button).grab_focus()


func _answer(i: int) -> void:
	if _t < 0.4:
		return                       # évite le double clic hérité de l'écran précédent
	answered.emit(i)


## Apparition (fondu) d'un élément après `delay` secondes
func reveal(c: CanvasItem, delay: float, dur := 0.45) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Carte d'encre (panneau + VBox) ; renvoie la VBox
func card(parent: Control, margin := 14.0, sep := 8) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.ink_panel(margin, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return v


func hbox(parent: Control, sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h


func vbox(parent: Control, sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v


func spacer(parent: Control, expand_v := false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand_v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c


## Étiquette pleine (logo de chaîne, « EN DIRECT »)
func tag(parent: Control, text: String, bg: Color, fg: Color, fs := 12) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UiStyle.box(bg, 2)
	st.content_margin_left = 9
	st.content_margin_right = 9
	st.content_margin_top = 3
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(UiStyle.label(text, fs, fg, "caps"))
	parent.add_child(p)
	return p


## Animation d'un nombre (compteur qui défile) dans un libellé
func count_up(l: Label, from: float, to: float, fmt: String, delay: float, dur := 1.1) -> void:
	l.text = fmt % int(round(from))
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(x: float) -> void: l.text = fmt % int(round(x)), from, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
