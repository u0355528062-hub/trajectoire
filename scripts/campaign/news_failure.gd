class_name NewsFailure
extends NewsScreen
## Écran d'échec du chapitre : tampon rouge de travers (« GARDE À VUE », « TROP TARD »…) qui s'abat, récit court
## de ce qui s'est passé, conséquence (la police te connaît), puis « Recommencer le chapitre » / « Menu principal ».

var reason := ""
var chapter_label := ""
var _stamp: Label


func _ready() -> void:
	backdrop(Color(UiStyle.RED, 0.55))
	var f := NewsTexts.failure(reason)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	var v := vbox(c, 18)
	v.custom_minimum_size.x = 620
	var k := UiStyle.label(chapter_label.to_upper(), 13, UiStyle.PAPER_MUTE, "caps")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(620, 120)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	_stamp = UiStyle.misprint(UiStyle.label(str(f[0]), 76, UiStyle.RED, "marker"), Color(UiStyle.PAPER, 0.18), Vector2(5, 4))
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.size = holder.custom_minimum_size
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.rotation = deg_to_rad(-4.0)
	holder.add_child(_stamp)
	_stamp.scale = Vector2.ONE * 2.2
	_stamp.modulate.a = 0.0
	var tw := _stamp.create_tween().set_parallel(true)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.32).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.12).set_delay(0.15)
	var line := ColorRect.new()
	line.color = Color(UiStyle.RED, 0.8)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	reveal(line, 0.5)
	var txt := UiStyle.label(str(f[1]), 18, UiStyle.PAPER, "regular")
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(txt)
	reveal(txt, 0.6)
	if reason == "arrested":
		var cons := UiStyle.label("La police te connaît mieux. Ça se paiera au prochain contrôle.", 14, UiStyle.YELLOW, "semibold")
		cons.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cons)
		reveal(cons, 0.9)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	v.add_child(gap)
	var row := hbox(v, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(button("Recommencer le chapitre", true))
	row.add_child(button("Menu principal", false))
	reveal(row, 1.1)
	focus_first.call_deferred()
