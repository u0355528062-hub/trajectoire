class_name NewsBilan
extends NewsScreen
## Bilan de fin de chapitre façon journal télévisé : plateau de Canal Continu (présentatrice, titre selon les
## sondages, ticker des faits du chapitre), réplique de la présentatrice qui s'écrit, sondage (oui / non / ne se
## prononcent pas), mobilisation, répression et notoriété avec leur variation sur le chapitre, extraits du journal
## (« Ce qu'on retiendra »), publications du réseau social Fil, puis « Continuer ».
## Données : voir NewsFeed.bilan_data().

var data: Dictionary = {}
var anchor: NewsAnchor
var _quote: Label
var _quote_len := 0


func _ready() -> void:
	backdrop(Color(UiStyle.RED, 0.22))
	var vs := get_viewport_rect().size
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 28)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 22)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var root := vbox(m, 14)
	# ---- en-tête
	var head := hbox(root, 0)
	tag(head, "CANAL", UiStyle.RED, UiStyle.PAPER, 14)
	tag(head, "CONTINU", UiStyle.PAPER, UiStyle.INK, 14)
	var g := Control.new()
	g.custom_minimum_size.x = 14
	head.add_child(g)
	var jt := UiStyle.label("LE JOURNAL  ·  %s" % str(data.get("date", "")).to_upper(), 12, UiStyle.PAPER_DIM, "caps")
	jt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(jt)
	spacer(head)
	var hv := vbox(head, 0)
	var k := UiStyle.label("BILAN · CHAPITRE %d" % int(data.get("index", 0)), 12, UiStyle.RED, "caps")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hv.add_child(k)
	var t := UiStyle.misprint(UiStyle.label(str(data.get("title", "")), 24, UiStyle.PAPER, "marker"), UiStyle.RED, Vector2(3, 2))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hv.add_child(t)
	# ---- deux colonnes
	var cols := hbox(root, 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := vbox(cols, 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45
	var right := vbox(cols, 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	var left_w := (vs.x - 56.0 - 22.0) * 1.45 / 2.45
	anchor = NewsAnchor.new()
	anchor.headline = str(data.get("headline", ""))
	anchor.keyword = str(data.get("keyword", ""))
	anchor.ticker = str(data.get("ticker", ""))
	anchor.clock = str(data.get("clock", "20:00"))
	anchor.custom_minimum_size = Vector2(0, minf(left_w * 9.0 / 16.0, vs.y * 0.46))
	left.add_child(anchor)
	var q := card(left, 14.0, 4)
	q.add_child(UiStyle.label("PRÉSENTATRICE  ·  %s" % NewsTexts.CHANNEL, 11, UiStyle.RED, "caps"))
	_quote = UiStyle.label("« %s »" % " ".join(data.get("lines", [])), 15, UiStyle.PAPER, "regular")
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.visible_characters = 0
	_quote_len = _quote.text.length()
	q.add_child(_quote)
	var jcard := card(left, 14.0, 6)
	jcard.add_child(UiStyle.label("CE QU'ON RETIENDRA", 11, UiStyle.RED, "caps"))
	var hl: Array = data.get("highlights", [])
	if hl.is_empty():
		jcard.add_child(UiStyle.label("Une journée calme. Rien que Canal Continu ait jugé bon de montrer.", 14, UiStyle.PAPER_DIM, "regular"))
	for e in hl:
		var row := hbox(jcard, 10)
		var d := float((e as Dictionary).get("d", 0.0))
		var dot := ColorRect.new()
		dot.color = OpinionHud.POS_COL if d > 0.05 else (UiStyle.RED if d < -0.05 else UiStyle.PAPER_MUTE)
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var l := UiStyle.label(str((e as Dictionary).get("text", "")), 14, UiStyle.PAPER, "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		reveal(row, 1.6 + 0.15 * float(row.get_index()))
	# ---- sondage
	var pc := card(right, 14.0, 7)
	var ph := hbox(pc, 8)
	var pt := UiStyle.label("SONDAGE EXCLUSIF", 12, UiStyle.RED, "caps")
	pt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pt)
	var op := float(data.get("opinion", 0.0))
	var dop := op - float(data.get("opinion_start", op))
	var dl := UiStyle.label(NewsTexts.signed(dop, 1) + " pt" if absf(dop) >= 0.05 else "stable", 13, OpinionHud.POS_COL if dop > 0.0 else (UiStyle.RED if dop < 0.0 else UiStyle.PAPER_MUTE), "bold")
	ph.add_child(dl)
	var qq := UiStyle.label("Soutenez-vous le mouvement contre la loi de Stabilité ?", 13, UiStyle.PAPER_DIM, "regular")
	qq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(qq)
	var poll: Array = data.get("poll", [0, 0, 0])
	var names := ["Oui", "Non", "Ne se prononcent pas"]
	var cols_p := [UiStyle.RED, Color(UiStyle.PAPER, 0.5), Color(UiStyle.PAPER, 0.22)]
	for i in 3:
		var pr := PollRow.new()
		pr.label_text = names[i]
		pr.value = float(poll[i]) / 100.0
		pr.color = cols_p[i]
		pr.delay = 0.5 + 0.2 * i
		pr.custom_minimum_size = Vector2(0, 26)
		pc.add_child(pr)
	reveal(pc.get_parent(), 0.2)
	# ---- jauges
	var sc := card(right, 14.0, 6)
	var srow := hbox(sc, 14)
	var b1 := vbox(srow, 0)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.add_child(UiStyle.label("MOBILISATION", 11, UiStyle.PAPER_MUTE, "caps"))
	var mob := UiStyle.label("", 30, UiStyle.PAPER, "black")
	b1.add_child(mob)
	var mob0 := float(data.get("mob_start", 0.0))
	var mob1 := float(data.get("mob", 0.0))
	count_up(mob, mob0, mob1, "%d", 0.8)
	var dm := mob1 - mob0
	b1.add_child(UiStyle.label(("%s prêts à descendre" % NewsTexts.signed(roundf(dm), 0)) if absf(dm) >= 0.5 else "prêts à descendre", 12, OpinionHud.POS_COL if dm >= 0.5 else UiStyle.PAPER_DIM, "regular"))
	var b2 := vbox(srow, 2)
	b2.add_child(UiStyle.label("RÉPRESSION", 11, UiStyle.PAPER_MUTE, "caps"))
	var rep := float(data.get("repression", 0.0))
	b2.add_child(UiStyle.label(["mesurée", "ferme", "dure", "brutale"][clampi(int(rep * 4.0), 0, 3)], 16, UiStyle.PAPER if rep < 0.5 else UiStyle.RED, "bold"))
	b2.add_child(UiStyle.label("POLICE : TE CONNAÎT", 11, UiStyle.PAPER_MUTE, "caps"))
	var noto := float(data.get("notoriete", 0.0))
	b2.add_child(UiStyle.label(["à peine", "un peu", "bien", "très bien"][clampi(int(noto * 4.0), 0, 3)], 16, UiStyle.PAPER if noto < 0.5 else UiStyle.YELLOW, "bold"))
	reveal(sc.get_parent(), 0.45)
	# ---- réseau social
	var so := card(right, 14.0, 8)
	so.add_child(UiStyle.label("SUR %s" % NewsTexts.NETWORK.to_upper(), 12, UiStyle.RED, "caps"))
	for p in data.get("posts", []):
		var pv := vbox(so, 2)
		var top := hbox(pv, 8)
		top.add_child(UiStyle.label(str(p["handle"]), 13, UiStyle.PAPER, "bold"))
		spacer(top)
		top.add_child(UiStyle.label(NewsTexts.big_number(int(p["likes"])) + " j'aime", 12, UiStyle.PAPER_MUTE, "semibold"))
		var tl := UiStyle.label(str(p["text"]), 13, UiStyle.PAPER_DIM, "regular")
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pv.add_child(tl)
	reveal(so.get_parent(), 0.7)
	spacer(right, true)
	# ---- suite
	var foot := hbox(right, 14)
	var nx := UiStyle.label(str(data.get("next", "")), 12, UiStyle.PAPER_MUTE, "caps")
	nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(nx)
	foot.add_child(button("Continuer", true))
	reveal(foot, 1.0)
	focus_first.call_deferred()


func _process(delta: float) -> void:
	super._process(delta)
	if _quote and _quote.visible_characters >= 0:
		var n := int(maxf(_t - 0.4, 0.0) * 55.0)
		if n >= _quote_len:
			_quote.visible_characters = -1
			anchor.talking = false
		else:
			_quote.visible_characters = n
			anchor.talking = n > 0


## Ligne du sondage : libellé, barre qui se remplit, pourcentage
class PollRow extends Control:
	var label_text := ""
	var value := 0.0
	var color := Color.WHITE
	var delay := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var f := UiStyle.font("semibold")
		var fb := UiStyle.font("black")
		var k := UiStyle.smooth((_t - delay) / 0.9)
		var lw := 150.0
		draw_string(f, Vector2(0, size.y * 0.5 + 5), label_text, HORIZONTAL_ALIGNMENT_LEFT, lw - 8.0, 13, UiStyle.PAPER_DIM)
		var bw := size.x - lw - 52.0
		var r := Rect2(Vector2(lw, size.y * 0.5 - 6), Vector2(bw, 12))
		draw_rect(r, UiStyle.PAPER_FAINT)
		draw_rect(Rect2(r.position, Vector2(bw * value * k, r.size.y)), color)
		var txt := "%d %%" % int(round(value * 100.0 * k))
		var tw := fb.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(fb, Vector2(size.x - tw, size.y * 0.5 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.PAPER)
