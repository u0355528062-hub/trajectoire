class_name DialoguePanel
extends Control
## Dialogue façon cinématique en bas de l'écran : réplique du personnage
## (sous-titre animé) et choix de questions ou de consignes.
## Fermeture : Échap, clic droit ou « Terminer ».

signal option_chosen(id: String)
signal closed

var mode := "patient"
var _name: Label
var _role: Label
var _line: RichTextLabel
var _options: GridContainer
var _side: VBoxContainer
var _panel: PanelContainer
var _tw: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0.0, 0.01, 0.02, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 0.42
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_panel = Glass.panel(22, 30, 24)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -640
	_panel.offset_right = 640
	_panel.offset_bottom = -34
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	var v := UITheme.vbox(16)
	_panel.add_child(v)

	var head := UITheme.hbox(14)
	v.add_child(head)
	var bubble := Label.new()
	bubble.text = Icons.glyph("messages-square")
	bubble.add_theme_font_override("font", Icons.font())
	bubble.add_theme_font_size_override("font_size", 26)
	bubble.add_theme_color_override("font_color", UITheme.ACCENT)
	head.add_child(bubble)
	_name = UITheme.label("", "H2")
	head.add_child(_name)
	_role = UITheme.label("", "Muted")
	_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_role)
	head.add_child(UITheme.spacer(false))
	var hint := UITheme.label("1–9 : choisir   ·   Échap / clic droit : fermer", "Caption")
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	var close_btn := UITheme.button("", "GhostButton", close)
	close_btn.text = Icons.glyph("x")
	close_btn.add_theme_font_override("font", Icons.font())
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.tooltip_text = "Fermer"
	head.add_child(close_btn)

	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.fit_content = true
	_line.scroll_active = false
	_line.custom_minimum_size = Vector2(0, 58)
	_line.add_theme_font_override("normal_font", UITheme.font("medium"))
	_line.add_theme_font_size_override("normal_font_size", 22)
	v.add_child(_line)
	v.add_child(HSeparator.new())

	var body := UITheme.hbox(20)
	v.add_child(body)
	_options = GridContainer.new()
	_options.columns = 2
	_options.add_theme_constant_override("h_separation", 10)
	_options.add_theme_constant_override("v_separation", 8)
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_options)
	_side = UITheme.vbox(8)
	_side.custom_minimum_size = Vector2(330, 0)
	body.add_child(_side)


func open_patient(r: PatientRecord, opts: Array) -> void:
	mode = "patient"
	_name.text = r.display_name()
	_role.text = "%d ans  ·  %s" % [r.age(), r.data.get("patient", {}).get("job", "")]
	_set_text("Que voulez-vous demander ?", true)
	refresh_options(opts)
	_show()


func open_simple(n: String, role: String, line: String, opts: Array, m: String) -> void:
	mode = m
	_name.text = n
	_role.text = role
	_set_text(line, false)
	refresh_options(opts)
	_show()


func _show() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	Sfx.ui("open")


func set_line(speaker: String, text: String) -> void:
	_name.text = speaker
	_set_text(text, false)


func _set_text(text: String, muted: bool) -> void:
	if muted:
		_line.text = "[color=#8b9bb0]%s[/color]" % text
		_line.visible_ratio = 1.0
		return
	_line.text = "« %s »" % text
	_line.visible_ratio = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_line, "visible_ratio", 1.0, clampf(text.length() / 60.0, 0.4, 2.6))


func refresh_options(opts: Array) -> void:
	for c in _options.get_children():
		c.queue_free()
	for c in _side.get_children():
		c.queue_free()
	var n := 0
	var has_q := false
	for o in opts:
		if o.get("kind", "question") == "question":
			has_q = true
	if has_q:
		var cap := UITheme.label("INTERROGATOIRE", "Caption")
		cap.custom_minimum_size.y = 18
		_options.add_child(cap)
		_options.add_child(Control.new())
	var side_cap_done := false
	for o in opts:
		var kind: String = o.get("kind", "question")
		var b := Button.new()
		b.theme_type_variation = "Chip"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		var done: bool = o.get("done", false)
		n += 1
		var prefix := "%d   " % n if n <= 9 else ""
		b.text = prefix + ("✓  " if done else "") + String(o["text"])
		if done:
			b.add_theme_color_override("font_color", UITheme.MUTED)
		b.pressed.connect(_choose.bind(String(o["id"])))
		b.set_meta("index", n)
		if kind == "question":
			_options.add_child(b)
		else:
			if not side_cap_done:
				side_cap_done = true
				_side.add_child(UITheme.label("CONSIGNES", "Caption"))
			if kind == "end":
				b.add_theme_color_override("font_color", UITheme.ACCENT)
			_side.add_child(b)


func _choose(id: String) -> void:
	Sfx.ui("click")
	option_chosen.emit(id)


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.ui("close")
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_0
			for parent in [_options, _side]:
				for c in parent.get_children():
					if c is Button and int(c.get_meta("index", -1)) == idx:
						get_viewport().set_input_as_handled()
						(c as Button).pressed.emit()
						return
