class_name OpinionHud
extends CanvasLayer
## Jauge d'opinion en jeu (charte UiStyle), en haut à droite : pourcentage de soutien (sondage), barre rouge avec
## le seuil de la majorité, trace de la dernière variation, mobilisation et pastilles « repéré » (notoriété).
## Dans le groupe « campaign » : chaque on_campaign_stat fait naître une petite notification (+0,4 · tract
## distribué), regroupée avec les suivantes de même cause. Masquée pendant les cinématiques. Créée par
## l'OpinionModel du directeur de chapitre.

const W := 340.0
const TOP := 64.0
## Seuils d'affichage des notifications (variation cumulée)
const SHOW_MIN := {"opinion": 0.05, "mobilisation": 0.5, "repression": 0.02, "notoriete": 0.01}
const CHIP_LIFE := 2.8
const CHIPS_TOP := 100.0
const POS_COL := Color(0.6, 0.86, 0.62)

var director: ChapterDirector
var _root: Control
var _panel: PanelContainer
var _value: Label
var _trend: Label
var _bar: Gauge
var _mob: Label
var _pips: Pips
var _chips: Control
var _shown_op := -1.0
var _shown_mob := -1.0
var _alpha := 0.0
var _list: Array = []             # notifications : {key, k, why, acc, age, node, label}


func _ready() -> void:
	layer = 31
	add_to_group("campaign")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	_panel = PanelContainer.new()
	var st := UiStyle.ink_panel(0.0, 8)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", st)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -24
	_panel.offset_top = TOP
	_panel.custom_minimum_size.x = W
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	tv.add_child(UiStyle.label("OPINION", 12, UiStyle.RED, "caps"))
	tv.add_child(UiStyle.label("soutiennent le mouvement", 12, UiStyle.PAPER_MUTE, "regular"))
	_trend = UiStyle.label("", 15, UiStyle.PAPER_MUTE, "bold")
	_trend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_trend)
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	top.add_child(gap)
	_value = UiStyle.label("", 30, UiStyle.PAPER, "black")
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_value)
	_bar = Gauge.new()
	_bar.custom_minimum_size = Vector2(0, 12)
	v.add_child(_bar)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bot)
	bot.add_child(UiStyle.label("MOBILISATION", 11, UiStyle.PAPER_MUTE, "caps"))
	_mob = UiStyle.label("", 13, UiStyle.PAPER, "bold")
	_mob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(_mob)
	bot.add_child(UiStyle.label("REPÉRÉ", 11, UiStyle.PAPER_MUTE, "caps"))
	_pips = Pips.new()
	_pips.custom_minimum_size = Vector2(62, 14)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(_pips)
	_chips = Control.new()
	_chips.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chips)
	_sync(true)


## Notification de campagne (groupe « campaign »)
func on_campaign_stat(k: String, _v: float, delta: float, why: String) -> void:
	if not SHOW_MIN.has(k) or not is_inside_tree():
		return
	if k == "opinion":
		_bar.bump(delta)
	var key := k + "|" + why
	for c in _list:
		if c["key"] == key and float(c["age"]) < CHIP_LIFE * 0.65:
			c["acc"] = float(c["acc"]) + delta
			c["age"] = 0.0
			_chip_text(c)
			if c["node"] != null and (c["node"] as Control).visible:
				UiStyle.pop(c["node"], 1.1, 0.22)
			return
	var c2 := {"key": key, "k": k, "why": why, "acc": delta, "age": 0.0, "node": null, "label": null}
	_list.append(c2)
	_chip_text(c2)


## Nombre de notifications visibles (tests)
func chip_count() -> int:
	var n := 0
	for c in _list:
		if c["node"] != null:
			n += 1
	return n


func _chip_text(c: Dictionary) -> void:
	var k := str(c["k"])
	var acc := float(c["acc"])
	if absf(acc) < float(SHOW_MIN[k]):
		if c["node"] != null:
			(c["node"] as Control).visible = false
		return
	var txt := ""
	var col := POS_COL if acc > 0.0 else UiStyle.RED
	match k:
		"opinion":
			txt = "%s %s" % [NewsTexts.signed(acc, 1), "pt"]
		"mobilisation":
			txt = "%s manifestant%s" % [NewsTexts.signed(roundf(acc), 0), "s" if absf(roundf(acc)) > 1.0 else ""]
		"repression":
			txt = "Répression ↑" if acc > 0.0 else "Répression ↓"
			col = UiStyle.RED if acc > 0.0 else POS_COL
		"notoriete":
			txt = "La police te repère" if acc > 0.0 else "Tu te fais oublier"
			col = UiStyle.YELLOW if acc > 0.0 else POS_COL
	var why := str(c["why"])
	if c["node"] == null:
		var p := PanelContainer.new()
		var st := UiStyle.box(UiStyle.INK_PANEL, 5)
		st.content_margin_left = 10
		st.content_margin_right = 12
		st.content_margin_top = 4
		st.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", st)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(h)
		var a := UiStyle.label("", 14, col, "bold")
		h.add_child(a)
		var b := UiStyle.label("", 12, UiStyle.PAPER_DIM, "regular")
		h.add_child(b)
		_chips.add_child(p)
		p.modulate.a = 0.0
		c["node"] = p
		c["label"] = [a, b]
	var ls: Array = c["label"]
	(ls[0] as Label).text = txt
	(ls[0] as Label).add_theme_color_override("font_color", col)
	(ls[1] as Label).text = why
	(ls[1] as Label).visible = why != ""
	(c["node"] as Control).visible = true
	(c["node"] as Control).size = Vector2.ZERO


func _process(delta: float) -> void:
	var hide := director != null and director.cine != null and director.cine.active
	_alpha = UiStyle.damp(_alpha, 0.0 if hide else 1.0, 9.0, delta)
	_root.modulate.a = _alpha
	_root.visible = _alpha > 0.01
	_sync(false, delta)
	# notifications : à gauche de la jauge, sous la jauge de tension (centre haut), trois au plus ;
	# elles montent légèrement et s'effacent
	var y := CHIPS_TOP
	var shown := 0
	var right := _root.size.x - 24.0 - W - 10.0
	for c in _list.duplicate():
		c["age"] = float(c["age"]) + delta
		var node: Control = c["node"]
		if float(c["age"]) > CHIP_LIFE:
			if node != null:
				node.queue_free()
			_list.erase(c)
			continue
		if node == null or not node.visible:
			continue
		shown += 1
		if shown > 3:
			node.modulate.a = 0.0
			continue
		var age := float(c["age"])
		var a := UiStyle.smooth(age / 0.2) * (1.0 - UiStyle.smooth((age - CHIP_LIFE + 0.6) / 0.6))
		node.modulate.a = a
		var sz := node.get_combined_minimum_size()
		node.size = sz
		node.position = Vector2(right - sz.x + (1.0 - UiStyle.smooth(age / 0.25)) * 18.0, y - age * 4.0)
		y += sz.y + 6.0


func _sync(force: bool, delta := 0.0) -> void:
	var op := Campaign.stat("opinion")
	var mob := Campaign.stat("mobilisation")
	if force or _shown_op < 0.0:
		_shown_op = op
		_shown_mob = mob
	else:
		var before := int(round(_shown_op))
		_shown_op = UiStyle.damp(_shown_op, op, 4.0, delta)
		if absf(_shown_op - op) < 0.05:
			_shown_op = op
		if int(round(_shown_op)) != before:
			UiStyle.pop(_value, 1.14, 0.3)
		_shown_mob = UiStyle.damp(_shown_mob, mob, 4.0, delta)
		if absf(_shown_mob - mob) < 0.5:
			_shown_mob = mob
	_value.text = "%d %%" % int(round(_shown_op))
	_mob.text = "%d" % int(round(_shown_mob))
	_bar.value = _shown_op / 100.0
	_pips.level = Campaign.stat("notoriete")
	var tr := _bar.trend()
	_trend.text = "▲" if tr > 0.05 else ("▼" if tr < -0.05 else "")
	_trend.add_theme_color_override("font_color", POS_COL if tr > 0.0 else UiStyle.RED)


## Barre d'opinion : piste pâle, remplissage rouge, seuil de la majorité, trace de la dernière variation
class Gauge extends Control:
	var value := 0.0
	var _ghost := 0.0            # ancienne valeur (trace qui se résorbe)
	var _ghost_a := 0.0
	var _recent := 0.0           # variation récente (tendance)

	func bump(delta: float) -> void:
		if _ghost_a <= 0.01:
			_ghost = value
		_ghost_a = 1.0
		_recent += delta

	func trend() -> float:
		return _recent

	func _process(delta: float) -> void:
		_ghost_a = maxf(_ghost_a - delta * 0.5, 0.0)
		_recent = UiStyle.damp(_recent, 0.0, 0.35, delta)
		if _ghost_a <= 0.0:
			_ghost = value
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var r := Rect2(Vector2(0, 2), Vector2(size.x, h - 4))
		draw_style_box(UiStyle.box(UiStyle.PAPER_FAINT, 3), r)
		var fill := Rect2(r.position, Vector2(r.size.x * clampf(value, 0.0, 1.0), r.size.y))
		if fill.size.x > 1.0:
			draw_style_box(UiStyle.box(UiStyle.RED, 3), fill)
		if _ghost_a > 0.0 and absf(_ghost - value) > 0.0005:
			var a := minf(_ghost, value)
			var b := maxf(_ghost, value)
			var col := Color(OpinionHud.POS_COL, 0.9 * _ghost_a) if value > _ghost else Color(UiStyle.PAPER, 0.55 * _ghost_a)
			draw_rect(Rect2(Vector2(r.position.x + r.size.x * a, r.position.y), Vector2(maxf(r.size.x * (b - a), 2.0), r.size.y)), col)
		# majorité : 50 %
		var x := r.position.x + r.size.x * 0.5
		draw_line(Vector2(x, 0), Vector2(x, h), UiStyle.PAPER_DIM, 2.0)


## Cinq pastilles de notoriété : jaunes quand la police connaît Sam, rouges au-delà de 0,6
class Pips extends Control:
	var level := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var n := 5
		var step := size.x / float(n)
		for i in n:
			var c := Vector2(step * (float(i) + 0.5), size.y * 0.5)
			var f := clampf(level * float(n) - float(i), 0.0, 1.0)
			draw_circle(c, 4.2, UiStyle.PAPER_FAINT)
			if f > 0.0:
				var col := UiStyle.YELLOW if level < 0.6 else UiStyle.RED
				draw_circle(c, 4.2 * (0.45 + 0.55 * f), Color(col, 0.5 + 0.5 * f))
