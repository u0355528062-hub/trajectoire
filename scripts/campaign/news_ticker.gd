class_name NewsTicker
extends Control
## Notifications d'actualité pendant le jeu, à gauche de l'écran : bandeau de chaîne d'info (Canal Continu,
## « EN DIRECT », heure) ou notification de téléphone (réseau social Fil, carte crème arrondie). Elles glissent
## depuis le bord, restent le temps de lecture, puis s'effacent ; trois au plus à la fois, les suivantes attendent.

const W := 380.0
const MAX_SHOWN := 3

var _queue: Array = []            # [{kind, title, text}]
var _cards: Array = []            # [{node, age, life}]
var _t0 := 0                      # début du chapitre (ms)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t0 = Time.get_ticks_msec()


## kind : "tv" (Canal Continu) ou "phone" (Fil)
func add(kind: String, title: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	_queue.append({"kind": kind, "title": title, "text": text})
	if _queue.size() > 8:
		_queue.pop_front()


func shown_count() -> int:
	return _cards.size()


## Texte des notifications affichées (tests)
func texts() -> Array:
	var out: Array = []
	for c in _cards:
		out.append(str(c["text"]))
	return out


func _process(delta: float) -> void:
	while not _queue.is_empty() and _cards.size() < MAX_SHOWN:
		var q: Dictionary = _queue.pop_front()
		var node := _build_tv(q) if q["kind"] == "tv" else _build_phone(q)
		add_child(node)
		_cards.append({"node": node, "age": 0.0, "life": clampf(4.5 + str(q["text"]).length() / 16.0, 5.0, 11.0), "text": q["text"]})
	var y := size.y * 0.36
	for c in _cards.duplicate():
		c["age"] = float(c["age"]) + delta
		var node: Control = c["node"]
		var age := float(c["age"])
		var life := float(c["life"])
		if age > life:
			node.queue_free()
			_cards.erase(c)
			continue
		var inn := UiStyle.smooth(age / 0.35)
		var out := UiStyle.smooth((age - life + 0.5) / 0.5)
		var sz := node.get_combined_minimum_size()
		node.size = sz
		node.position = Vector2(24.0 - (1.0 - inn) * (W + 40.0) - out * 30.0, y)
		node.modulate.a = inn * (1.0 - out)
		y += sz.y + 10.0


## Bandeau de chaîne d'info : liseré rouge, logo, « EN DIRECT », heure de jeu, texte
func _build_tv(q: Dictionary) -> Control:
	var p := PanelContainer.new()
	var st := UiStyle.ink_panel(0.0, 6)
	st.content_margin_left = 0
	st.content_margin_right = 16
	st.content_margin_top = 0
	st.content_margin_bottom = 12
	st.border_width_left = 0
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size.x = W
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(_tag(NewsTexts.CHANNEL, UiStyle.RED, UiStyle.PAPER))
	head.add_child(_tag(str(q["title"]) if str(q["title"]) != "" else "EN DIRECT", UiStyle.PAPER, UiStyle.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var clock := UiStyle.label(_clock_txt(), 12, UiStyle.PAPER_MUTE, "caps")
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(clock)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(m)
	var l := UiStyle.label(str(q["text"]), 15, UiStyle.PAPER, "semibold")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 34.0
	m.add_child(l)
	return p


## Notification de téléphone : carte crème, icône de l'appli, « Fil · maintenant », titre, texte
func _build_phone(q: Dictionary) -> Control:
	var p := PanelContainer.new()
	var st := UiStyle.soft_shadow(UiStyle.box(Color(UiStyle.PAPER, 0.96), 14), 0.4, 14, Vector2(0, 5))
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size.x = W
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.RED, 9))
	icon.custom_minimum_size = Vector2(38, 38)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := UiStyle.label("F", 22, UiStyle.PAPER, "marker")
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_child(f)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiStyle.label("%s · maintenant" % NewsTexts.NETWORK.to_upper(), 11, Color(UiStyle.INK, 0.55), "caps"))
	if str(q["title"]) != "":
		v.add_child(UiStyle.label(str(q["title"]), 15, UiStyle.INK, "bold"))
	var l := UiStyle.label(str(q["text"]), 14, Color(UiStyle.INK, 0.85), "regular")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = W - 74.0
	v.add_child(l)
	return p


func _tag(text: String, bg: Color, fg: Color) -> Control:
	var p := PanelContainer.new()
	var st := UiStyle.box(bg, 0)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UiStyle.label(text, 12, fg, "caps"))
	return p


## Heure affichée : l'heure de la date du chapitre (« … — 18 h 30 ») plus le temps de jeu écoulé
func _clock_txt() -> String:
	var date := str(Campaign.chapter_def().get("date", ""))
	var h := 12
	var mi := 0
	var rx := RegEx.create_from_string("(\\d{1,2}) h (\\d{2})")
	var m := rx.search(date)
	if m:
		h = int(m.get_string(1))
		mi = int(m.get_string(2))
	var t := h * 60 + mi + int((Time.get_ticks_msec() - _t0) / 60000.0) % 600
	return "%02d:%02d" % [(t / 60) % 24, t % 60]
