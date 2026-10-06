extends CanvasLayer
## Interface : barre d'inventaire en verre sombre, icône du mortier dessinée en
## vectoriel, jauge de 6 obus, messages, viseur, aide aux touches.

const AMBER := Color(1.0, 0.72, 0.28)
const GLASS := Color(0.05, 0.06, 0.09, 0.78)

var _slot: PanelContainer
var _slot_style: StyleBoxFlat
var _icon: Control
var _pips: Control
var _count_label: Label
var _name_label: Label
var _toast: Label
var _crosshair: Control
var _view_label: Label
var _ammo := 6
var _max := 6
var _selected := true
var _toast_tween: Tween


# ------------------------------------------------------------ dessin de l'icône
class MortarIcon extends Control:
	var dim := 0.0 # 0 = actif, 1 = grisé

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) / 100.0
		var a := 1.0 - dim * 0.6
		draw_set_transform(c, deg_to_rad(18.0), Vector2.ONE * s)
		# ombre portée douce
		draw_rect(Rect2(-14, -38, 30, 82), Color(0, 0, 0, 0.25 * a), true)
		# tube (dégradé horizontal simulé par bandes)
		var bands := 12
		for i in bands:
			var t := float(i) / (bands - 1)
			var shade := 0.55 + 0.75 * sin(t * PI) * (1.0 - 0.35 * t)
			var col := Color(0.78 * shade, 0.12 * shade, 0.08 * shade, a)
			draw_rect(Rect2(-17 + i * (34.0 / bands), -42, 34.0 / bands + 0.6, 80), col, true)
		# bandes dorées
		for y in [-30.0, 22.0]:
			draw_rect(Rect2(-17.5, y, 35, 6), Color(0.95, 0.72, 0.25, a), true)
			draw_rect(Rect2(-17.5, y, 35, 1.6), Color(1, 0.95, 0.7, 0.8 * a), true)
		# embouchure
		draw_set_transform(c + Vector2(0, -42 * s).rotated(deg_to_rad(18.0)), deg_to_rad(18.0), Vector2(s, s * 0.32))
		draw_circle(Vector2.ZERO, 18.5, Color(0.1, 0.1, 0.12, a))
		draw_circle(Vector2.ZERO, 14.5, Color(0.0, 0.0, 0.0, a))
		# pied
		draw_set_transform(c + Vector2(0, 38 * s).rotated(deg_to_rad(18.0)), deg_to_rad(18.0), Vector2(s, s * 0.32))
		draw_circle(Vector2.ZERO, 22, Color(0.12, 0.12, 0.14, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# étincelles
		if dim < 0.5:
			var tip := c + Vector2(0, -42 * s).rotated(deg_to_rad(18.0)) + Vector2(0, -6)
			for k in 7:
				var ang := -PI / 2.0 + (k - 3) * 0.28
				var l := (14.0 + (k % 3) * 6.0) * s
				draw_line(tip, tip + Vector2(cos(ang), sin(ang)) * l, Color(1.0, 0.8, 0.35, 0.85), 1.6 * s, true)
				draw_circle(tip + Vector2(cos(ang), sin(ang)) * l, 1.8 * s, Color(1.0, 0.95, 0.7, 0.95))


class Pips extends Control:
	var count := 6
	var maximum := 6
	var pulse := 0.0 # animation lors d'un tir

	func _draw() -> void:
		var gap := 16.0
		var total := (maximum - 1) * gap
		var x0 := size.x * 0.5 - total * 0.5
		for i in maximum:
			var p := Vector2(x0 + i * gap, size.y * 0.5)
			if i < count:
				draw_circle(p, 7.5, Color(1.0, 0.6, 0.15, 0.18))
				draw_circle(p, 5.2, Color(1.0, 0.72, 0.28))
				draw_circle(p + Vector2(-1.2, -1.4), 2.0, Color(1, 0.95, 0.8, 0.9))
			else:
				var r := 5.2 + pulse * 5.0 * (1.0 if i == count else 0.0)
				draw_arc(p, 4.6, 0.0, TAU, 20, Color(1, 1, 1, 0.22), 1.6, true)
				if i == count and pulse > 0.0:
					draw_arc(p, r, 0.0, TAU, 24, Color(1.0, 0.7, 0.25, pulse * 0.8), 1.8, true)


class Cross extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 2.6, Color(1, 1, 1, 0.85))
		draw_arc(c, 8.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.4, true)


func bind(player: Player) -> void:
	player.equipped_changed.connect(_on_equipped)
	player.ammo_changed.connect(_on_ammo)
	player.message.connect(_toast_show)
	player.view_changed.connect(_on_view)
	_on_equipped(player.mortar.equipped)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# viseur (1re personne uniquement)
	_crosshair = Cross.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(40, 40)
	_crosshair.size = Vector2(40, 40)
	_crosshair.position = Vector2(-20, -20)
	_crosshair.visible = false
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)

	# barre d'inventaire
	var bar := VBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -26
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	bar.add_child(_toast)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_slot = PanelContainer.new()
	_slot.custom_minimum_size = Vector2(112, 112)
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = GLASS
	_slot_style.set_corner_radius_all(20)
	_slot_style.set_border_width_all(2)
	_slot_style.border_color = AMBER
	_slot_style.shadow_color = Color(1.0, 0.6, 0.15, 0.35)
	_slot_style.shadow_size = 16
	_slot_style.set_content_margin_all(8)
	_slot.add_theme_stylebox_override("panel", _slot_style)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_slot)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.add_child(holder)
	_icon = MortarIcon.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_icon)

	var key := Label.new()
	key.text = "1"
	key.add_theme_font_size_override("font_size", 15)
	key.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	key.position = Vector2(8, 2)
	holder.add_child(key)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", AMBER)
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_count_label.add_theme_constant_override("outline_size", 5)
	_count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count_label.offset_right = -4
	_count_label.offset_bottom = -2
	holder.add_child(_count_label)

	_name_label = Label.new()
	_name_label.text = "MORTIER D'ARTIFICE"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_name_label)

	_pips = Pips.new()
	_pips.custom_minimum_size = Vector2(150, 22)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_pips)

	# aide aux touches
	var help_panel := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.04, 0.05, 0.08, 0.55)
	hs.set_corner_radius_all(12)
	hs.set_content_margin_all(12)
	help_panel.add_theme_stylebox_override("panel", hs)
	help_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_panel.offset_left = 20
	help_panel.offset_bottom = -20
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(help_panel)
	var help := Label.new()
	help.text = "ZQSD  Marcher\nMaj  Courir\nEspace  Sauter\nV  Vue 1re / 3e personne\n1  Sortir / ranger le mortier\nClic gauche  Tirer\nÉchap  Libérer la souris"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	help_panel.add_child(help)

	_view_label = Label.new()
	_view_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_view_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_view_label.offset_right = -24
	_view_label.offset_top = 18
	_view_label.add_theme_font_size_override("font_size", 14)
	_view_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_view_label.text = "TROISIÈME PERSONNE"
	root.add_child(_view_label)

	_refresh()


func _refresh() -> void:
	_pips.count = _ammo
	_pips.maximum = _max
	_pips.queue_redraw()
	_count_label.text = "%d/%d" % [_ammo, _max]
	(_icon as MortarIcon).dim = 0.0 if _ammo > 0 else 1.0
	_icon.queue_redraw()
	_slot_style.border_color = AMBER if _selected else Color(1, 1, 1, 0.18)
	_slot_style.shadow_size = 16 if _selected else 0
	_slot.modulate = Color.WHITE if _selected else Color(1, 1, 1, 0.7)


func _on_equipped(on: bool) -> void:
	_selected = on
	_refresh()
	var tw := create_tween()
	_slot.pivot_offset = _slot.size * 0.5
	tw.tween_property(_slot, "scale", Vector2.ONE * (1.08 if on else 0.95), 0.08)
	tw.tween_property(_slot, "scale", Vector2.ONE * (1.0 if on else 0.95), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ammo(count: int, maximum: int) -> void:
	_ammo = count
	_max = maximum
	_refresh()
	_pips.pulse = 1.0
	var tw := create_tween()
	tw.tween_property(_pips, "pulse", 0.0, 0.7)
	tw.parallel().tween_method(func(_v): _pips.queue_redraw(), 0.0, 1.0, 0.7)
	_slot.pivot_offset = _slot.size * 0.5
	var t2 := create_tween()
	t2.tween_property(_slot, "scale", Vector2.ONE * 0.94, 0.05)
	t2.tween_property(_slot, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if count == 0:
		_toast_show("Dernier obus tiré")


func _on_view(first_person: bool) -> void:
	_crosshair.visible = first_person
	_view_label.text = "PREMIÈRE PERSONNE" if first_person else "TROISIÈME PERSONNE"


func _toast_show(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
