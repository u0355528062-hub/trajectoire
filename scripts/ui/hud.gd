class_name Hud
extends Control
## Interface en jeu : horloge, objectif, statistiques, notifications,
## réticule et invite d'interaction.

var _clock: Label
var _day: Label
var _next: Label
var _waiting: Label
var _objective: Label
var _objective_panel: PanelContainer
var _rep_bar: ProgressBar
var _rep_value: Label
var _money: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _crosshair: Control
var _toasts: VBoxContainer
var _focused := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	Game.stats_changed.connect(_update_stats)
	_update_stats()
	set_clock(Game.clock_text())


func _build() -> void:
	# Bloc horloge (haut gauche)
	var tl := PanelContainer.new()
	tl.theme_type_variation = "Card"
	tl.add_theme_stylebox_override("panel", _glass())
	tl.position = Vector2(32, 28)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	var v := UITheme.vbox(2)
	tl.add_child(v)
	_day = UITheme.label("JOUR %d" % Game.day, "AccentCaption")
	v.add_child(_day)
	var row := UITheme.hbox(14)
	v.add_child(row)
	_clock = UITheme.label("08:20", "Mono")
	_clock.add_theme_font_override("font", UITheme.font("display"))
	_clock.add_theme_font_size_override("font_size", 40)
	row.add_child(_clock)
	var col := UITheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_next = UITheme.label("", "Muted")
	_next.add_theme_font_size_override("font_size", 14)
	col.add_child(_next)
	_waiting = UITheme.label("", "Muted")
	_waiting.add_theme_font_size_override("font_size", 14)
	col.add_child(_waiting)

	# Objectif
	var obj := PanelContainer.new()
	_objective_panel = obj
	obj.add_theme_stylebox_override("panel", _glass())
	obj.position = Vector2(32, 132)
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obj)
	var oh := UITheme.hbox(14)
	obj.add_child(oh)
	var bar := ColorRect.new()
	bar.color = UITheme.ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	oh.add_child(bar)
	var ov := UITheme.vbox(3)
	oh.add_child(ov)
	ov.add_child(UITheme.label("OBJECTIF", "AccentCaption"))
	_objective = UITheme.label("", "Body")
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(380, 0)
	_objective.add_theme_font_size_override("font_size", 16)
	ov.add_child(_objective)

	# Statistiques (haut droite)
	var tr := PanelContainer.new()
	tr.add_theme_stylebox_override("panel", _glass())
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.offset_right = -32
	tr.offset_left = -32
	tr.offset_top = 28
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	var sv := UITheme.hbox(28)
	tr.add_child(sv)
	var rep_box := UITheme.vbox(6)
	sv.add_child(rep_box)
	var rep_head := UITheme.hbox(8)
	rep_box.add_child(rep_head)
	rep_head.add_child(UITheme.label("RÉPUTATION", "Caption"))
	rep_head.add_child(UITheme.spacer(false))
	_rep_value = UITheme.label("50", "Caption")
	_rep_value.add_theme_color_override("font_color", UITheme.TEXT)
	rep_head.add_child(_rep_value)
	_rep_bar = ProgressBar.new()
	_rep_bar.custom_minimum_size = Vector2(170, 7)
	_rep_bar.show_percentage = false
	_rep_bar.max_value = 100
	rep_box.add_child(_rep_bar)
	var money_box := UITheme.vbox(2)
	sv.add_child(money_box)
	money_box.add_child(UITheme.label("HONORAIRES", "Caption"))
	_money = UITheme.label("0 €", "H3")
	money_box.add_child(_money)

	# Notifications
	_toasts = UITheme.vbox(10)
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.custom_minimum_size = Vector2(440, 0)
	_toasts.offset_right = -32
	_toasts.offset_left = -472
	_toasts.offset_top = 124
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# Réticule
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)

	# Invite d'interaction
	_prompt_panel = PanelContainer.new()
	_prompt_panel.theme_type_variation = "Pill"
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	add_child(_prompt_panel)
	var ph := UITheme.hbox(10)
	_prompt_panel.add_child(ph)
	var key := PanelContainer.new()
	key.add_theme_stylebox_override("panel", UITheme.box(Color(1, 1, 1, 0.92), 6, Color(0, 0, 0, 0), 0, 8, 1))
	var kl := UITheme.label("E")
	kl.add_theme_font_override("font", UITheme.font("bold"))
	kl.add_theme_color_override("font_color", Color(0.05, 0.08, 0.12))
	kl.add_theme_font_size_override("font_size", 15)
	key.add_child(kl)
	ph.add_child(key)
	_prompt_label = UITheme.label("", "H3")
	_prompt_label.add_theme_font_size_override("font_size", 17)
	ph.add_child(_prompt_label)

	# Aide des touches
	var help := UITheme.label("ZQSD / WASD  Se déplacer     MAJ  Courir     E  Interagir     TAB  Agenda     ÉCHAP  Pause", "Caption")
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help.offset_top = -44
	help.offset_bottom = -20
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	add_child(help)


func _glass() -> StyleBoxFlat:
	var s := UITheme.box(Color(0.04, 0.06, 0.1, 0.72), 16, Color(1, 1, 1, 0.08), 1, 20, 14)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 16
	return s


func _process(_delta: float) -> void:
	if _prompt_panel.visible:
		var vs := get_viewport_rect().size
		_prompt_panel.reset_size()
		_prompt_panel.position = Vector2(vs.x * 0.5 - _prompt_panel.size.x * 0.5, vs.y * 0.5 + 44)
	_crosshair.position = get_viewport_rect().size * 0.5


func _draw_crosshair() -> void:
	if _focused:
		_crosshair.draw_arc(Vector2.ZERO, 11, 0, TAU, 48, Color(UITheme.ACCENT, 0.95), 2.0, true)
		_crosshair.draw_circle(Vector2.ZERO, 2.5, UITheme.ACCENT)
	else:
		_crosshair.draw_circle(Vector2.ZERO, 3.2, Color(0, 0, 0, 0.35))
		_crosshair.draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.9))


func set_crosshair_visible(v: bool) -> void:
	_crosshair.visible = v


func set_prompt(text: String) -> void:
	_focused = text != ""
	_prompt_panel.visible = _focused
	_prompt_label.text = text
	_crosshair.queue_redraw()


func set_clock(text: String) -> void:
	_clock.text = text


func set_next(text: String) -> void:
	_next.text = text


func set_waiting(n: int) -> void:
	_waiting.text = "Salle d'attente  %d" % n


func set_objective(text: String) -> void:
	if _objective.text != text:
		_objective.text = text
		_objective_panel.reset_size()
		UITheme.fade_in(_objective_panel, 0.4)


func _update_stats() -> void:
	_day.text = "JOUR %d  ·  %s" % [Game.day, Cases.day_data(Game.day)["title"].split(" — ")[0].to_upper()]
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rep_bar, "value", Game.reputation, 0.8)
	_rep_value.text = "%d" % int(round(Game.reputation))
	var fill := UITheme.box(_rep_color(), 999, Color(0, 0, 0, 0), 0, 0, 0)
	_rep_bar.add_theme_stylebox_override("fill", fill)
	_money.text = "%d €" % int(Game.money)


func _rep_color() -> Color:
	if Game.reputation >= 65.0:
		return UITheme.SUCCESS
	if Game.reputation >= 40.0:
		return UITheme.ACCENT
	if Game.reputation >= 25.0:
		return UITheme.WARNING
	return UITheme.DANGER


func toast(text: String, kind: String = "info") -> void:
	var color: Color = {"info": UITheme.ACCENT_2, "success": UITheme.SUCCESS, "warning": UITheme.WARNING, "danger": UITheme.DANGER}.get(kind, UITheme.ACCENT_2)
	var p := PanelContainer.new()
	var s := UITheme.box(Color(0.04, 0.06, 0.1, 0.88), 14, Color(color, 0.35), 1, 16, 12)
	s.border_width_left = 4
	s.border_color = Color(color, 0.9)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 12
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(440, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, "Body", true)
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(400, 0)
	p.add_child(l)
	_toasts.add_child(p)
	_toasts.move_child(p, 0)
	UITheme.fade_in(p, 0.3)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(_toasts.get_child_count() - 1)
		_toasts.remove_child(old)
		old.queue_free()
	var life := 7.0 if kind == "danger" else 5.5
	var tw := p.create_tween()
	tw.tween_interval(life)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
