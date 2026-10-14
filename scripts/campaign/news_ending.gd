class_name NewsEnding
extends NewsScreen
## Écran de fin de la campagne : « FIN » (ou « FIN CACHÉE »), titre au marqueur, récit en trois temps, dernier
## titre de Canal Continu, destins des personnages selon les drapeaux, jauges finales, « Retour au menu ».

var ending_id := ""


func _ready() -> void:
	var e := NewsTexts.ending(ending_id)
	backdrop(Color(UiStyle.RED, 0.3) if ending_id != "essoufflement" else Color(UiStyle.PAPER, 0.12))
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var v := vbox(c, 14)
	v.custom_minimum_size.x = 900
	var k := UiStyle.label(str(e.get("tag", "Fin")).to_upper(), 14, UiStyle.RED, "caps")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var t := UiStyle.misprint(UiStyle.label(str(e.get("title", "")), 64, UiStyle.PAPER, "marker"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	reveal(t, 0.2, 0.8)
	var cols := hbox(v, 28)
	var story := vbox(cols, 10)
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.size_flags_stretch_ratio = 1.3
	var i := 0
	for s in e.get("lines", []):
		var l := UiStyle.label(str(s), 16, UiStyle.PAPER, "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.add_child(l)
		reveal(l, 0.8 + 0.5 * i)
		i += 1
	var tv := hbox(story, 0)
	tag(tv, NewsTexts.CHANNEL, UiStyle.RED, UiStyle.PAPER, 11)
	var tvp := PanelContainer.new()
	var st := UiStyle.box(UiStyle.PAPER, 0)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 5
	tvp.add_theme_stylebox_override("panel", st)
	tvp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tvl := UiStyle.label(str(e.get("tv", "")), 13, UiStyle.INK, "bold")
	tvl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tvp.add_child(tvl)
	tv.add_child(tvp)
	reveal(tv, 2.4)
	var side := card(cols, 16.0, 8)
	side.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(UiStyle.label("ET APRÈS", 12, UiStyle.RED, "caps"))
	for f in e.get("fates", []):
		var fv := vbox(side, 1)
		fv.add_child(UiStyle.label(str(f[0]).to_upper(), 11, UiStyle.PAPER_MUTE, "caps"))
		var fl := UiStyle.label(str(f[1]), 13, UiStyle.PAPER_DIM, "regular")
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fv.add_child(fl)
	reveal(side.get_parent(), 1.6)
	var stats := hbox(v, 30)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stat(stats, "OPINION", "%d %%" % int(round(Campaign.stat("opinion"))))
	_stat(stats, "MOBILISATION", NewsTexts.big_number(int(round(Campaign.stat("mobilisation")))))
	_stat(stats, "CASSE", str(int(Campaign.flag("casse_total", 0))))
	_stat(stats, "POLICE : TE CONNAÎT", ["à peine", "un peu", "bien", "très bien"][clampi(int(Campaign.stat("notoriete") * 4.0), 0, 3)])
	reveal(stats, 2.8)
	var row := hbox(v, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(button("Retour au menu", true))
	reveal(row, 3.2)
	focus_first.call_deferred()


func _stat(parent: Control, title: String, value: String) -> void:
	var b := vbox(parent, 0)
	var t := UiStyle.label(title, 11, UiStyle.PAPER_MUTE, "caps")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(t)
	var v := UiStyle.label(value, 26, UiStyle.PAPER, "black")
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(v)
