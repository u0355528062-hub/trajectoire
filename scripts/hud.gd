extends CanvasLayer
## Interface : barre d'inventaire en verre sombre avec aperçu 3D du mortier, jauge de
## 6 obus, état de la séquence de tir, touches, viseur et vignettage.

const AMBER := Color(1.0, 0.72, 0.28)
const GLASS := Color(0.045, 0.05, 0.075, 0.82)
const TEXT := Color(0.93, 0.94, 0.97)
const MUTED := Color(0.93, 0.94, 0.97, 0.55)

var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _pivots: Array[Node3D] = []
var _item := 1
var _hint: Label
var _shells: ShellRow
var _count: Label
var _name: Label
var _status: Label
var _bar: ProgressBar
var _prompt: PanelContainer
var _toast: Label
var _crosshair: Control
var _view_chip: Label
var _help: PanelContainer
var _prompt_row: HBoxContainer
var _kick_prompt: PanelContainer
var _kick_prompt_on := false
var _post: ColorRect
var _reticle: Control
var _aim_tween: Tween
var _ammo := 6
var _max := 6
var _selected := true
var _aim_on := false
var _toast_tween: Tween
var _help_tween: Tween
var _player: Player
var _last_cp := ""
var _e_prompt: PanelContainer
var _e_label: Label
var _flares := 5
var _flares_max := 5
var _cmax: Label


# ----------------------------------------------------------------- dessins
class ShellRow extends Control:
	var count := 6
	var maximum := 6
	var pulse := 0.0

	func _draw() -> void:
		var gap := 24.0
		var total := (maximum - 1) * gap
		var x0 := size.x * 0.5 - total * 0.5
		for i in maximum:
			var c := Vector2(x0 + i * gap, size.y * 0.5)
			var full := i < count
			var just_used := i == count and pulse > 0.0
			var a := 1.0 if full else 0.28
			var body := Rect2(c.x - 6, c.y - 8, 12, 16)
			if full:
				draw_rect(Rect2(body.position - Vector2(3, 3), body.size + Vector2(6, 6)), Color(1.0, 0.6, 0.15, 0.12), true)
			draw_rect(body, Color(0.75, 0.1, 0.07, a) if full else Color(1, 1, 1, 0.08), true)
			draw_rect(Rect2(c.x - 6, c.y - 8, 12, 4), Color(0.9, 0.68, 0.22, a), true)
			draw_rect(Rect2(c.x - 1, c.y - 13, 2, 5), Color(0.78, 0.62, 0.35, a), true)
			if full:
				draw_rect(Rect2(c.x - 4, c.y - 3, 2, 9), Color(1, 1, 1, 0.28), true)
			else:
				draw_rect(body, Color(1, 1, 1, 0.25), false, 1.0)
			if just_used:
				draw_circle(c + Vector2(0, -6), 4.0 + 12.0 * (1.0 - pulse), Color(1.0, 0.7, 0.25, pulse * 0.5))


class Cross extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 2.4, Color(1, 1, 1, 0.9))
		draw_arc(c, 9.0, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 1.3, true)
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5)
			draw_line(c + d * 12.0, c + d * 17.0, Color(1, 1, 1, 0.5), 1.4, true)


class Reticle extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var col := Color(1, 1, 1, 0.9)
		draw_arc(c, 17.0, 0.0, TAU, 48, Color(1, 1, 1, 0.38), 1.2, true)
		for a in 4:
			var d := Vector2.from_angle(a * PI * 0.5 + PI * 0.25)
			draw_line(c + d * 17.0, c + d * 23.0, col, 1.4, true)
			var e := Vector2.from_angle(a * PI * 0.5)
			draw_line(c + e * 4.0, c + e * 9.0, Color(1, 1, 1, 0.8), 1.2, true)
		draw_circle(c, 1.6, Color(1.0, 0.82, 0.45, 1.0))


func _make_slot(i: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(88, 88)
	var st := _style(Color(0.1, 0.11, 0.15, 0.9), 16, AMBER, 2, 0.0)
	st.shadow_color = Color(1.0, 0.6, 0.15, 0.4)
	st.shadow_size = 14
	slot.add_theme_stylebox_override("panel", st)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(192, 192)
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	var pcam := Camera3D.new()
	pcam.fov = 26
	vp.add_child(pcam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -150, 0)
	rim.light_energy = 1.0
	rim.light_color = Color(1.0, 0.7, 0.45)
	vp.add_child(rim)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	if i == 0:
		pcam.look_at_from_position(Vector3(0, 0.2, 0.78), Vector3(0, 0.15, 0))
		pivot.rotation = Vector3(0.0, 0.0, deg_to_rad(-16))
		pivot.add_child(MortarModel.build())
	elif i == 2:
		pcam.look_at_from_position(Vector3(0, 0.08, 0.62), Vector3(0, 0.06, 0))
		var paper := Props.newspaper_roll()
		paper.rotation.z = deg_to_rad(-22)
		paper.position.x = -0.03
		pivot.add_child(paper)
		var lt := Props.lighter(Color(0.85, 0.2, 0.1))
		lt.position = Vector3(0.07, -0.02, 0.04)
		lt.rotation.z = deg_to_rad(14)
		pivot.add_child(lt)
	elif i == 3:
		pcam.look_at_from_position(Vector3(0, 0.02, 0.6), Vector3(0, 0.0, 0))
		var fl := Node3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = Flare.R
		tube.bottom_radius = Flare.R
		tube.height = Flare.LEN * 0.78
		var tm := MeshInstance3D.new()
		tm.mesh = tube
		tm.material_override = Props.flare_label_material()
		fl.add_child(tm)
		var cap := CylinderMesh.new()
		cap.top_radius = Flare.R * 1.12
		cap.bottom_radius = Flare.R * 1.12
		cap.height = 0.04
		var cm := MeshInstance3D.new()
		cm.mesh = cap
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.1, 0.1, 0.11)
		cm.material_override = cmat
		cm.position.y = Flare.LEN * 0.41
		fl.add_child(cm)
		var gm := MeshInstance3D.new()
		gm.mesh = cap
		gm.material_override = cmat
		gm.position.y = -Flare.LEN * 0.4
		gm.scale = Vector3(1, 1.6, 1)
		fl.add_child(gm)
		fl.rotation.z = deg_to_rad(-28)
		pivot.add_child(fl)
	else:
		pcam.look_at_from_position(Vector3(0, 0.03, 0.34), Vector3(0, 0.0, 0))
		var mi := MeshInstance3D.new()
		mi.mesh = Stone.make_mesh(5)
		mi.material_override = Stone.material()
		mi.scale = Vector3.ONE * 0.13
		pivot.add_child(mi)
		pivot.rotation = Vector3(0.3, 0, 0)
	var kl := _label(str(i + 1), 13, Color(1, 1, 1, 0.8), false)
	kl.position = Vector2(9, 5)
	slot.add_child(kl)
	_slots.append(slot)
	_slot_styles.append(st)
	_pivots.append(pivot)
	return slot


func _style(bg: Color, radius := 16, border := Color(1, 1, 1, 0.08), bw := 1, margin := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 14
	return s


func _label(text: String, size: int, color := TEXT, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _keycap(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(Color(1, 1, 1, 0.1), 6, Color(1, 1, 1, 0.28), 1, 5.0)
	s.shadow_size = 0
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.border_width_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	p.add_child(_label(text, 13, TEXT, false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _key_row(keys: Array, action: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in keys:
		h.add_child(_keycap(k))
	var l := _label(action, 13, MUTED, false)
	l.custom_minimum_size.x = 0
	h.add_child(l)
	return h


# ------------------------------------------------------------------- liaison
func bind(player: Player) -> void:
	player.item_changed.connect(_on_item)
	player.ammo_changed.connect(_on_ammo)
	player.message.connect(_toast_show)
	player.view_changed.connect(_on_view)
	player.stage_changed.connect(_on_stage)
	player.aim_changed.connect(_on_aim)
	player.near_breakable_changed.connect(func(n): _kick_prompt_on = n)
	player.flares_changed.connect(func(c, m):
		_flares = c
		_flares_max = m
		_refresh())
	_player = player
	_on_item(player.current_item)


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# flou périphérique + aberration chromatique + vignettage, actifs quand on vise
	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psh := Shader.new()
	psh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d * vec2(aspect, 1.0));
	float edge = smoothstep(0.34, 1.0, r) * amount;
	float lod = edge * 2.4;
	vec2 ca = d * 0.006 * edge;
	vec3 col;
	col.r = textureLod(screen_tex, uv + ca, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - ca, lod).b;
	col *= 1.0 - smoothstep(0.35, 1.0, r) * 0.45 * amount;
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.18 * amount);
	COLOR = vec4(col, 1.0);
}"""
	var pm := ShaderMaterial.new()
	pm.shader = psh
	_post.material = pm
	_post.visible = false
	post_layer.add_child(_post)

	# vignettage léger
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(uv * vec2(1.0, 0.85)));
	COLOR = vec4(0.0, 0.0, 0.02, v * 0.5);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vig.material = sm
	root.add_child(vig)

	_reticle = Reticle.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.size = Vector2(80, 80)
	_reticle.position = Vector2(-40, -40)
	_reticle.modulate.a = 0.0
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_reticle)
	_crosshair = Control.new()

	# ---- barre du bas
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -22
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)

	_toast = _label("", 20, Color(1, 0.93, 0.8))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	bottom.add_child(_toast)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(GLASS, 22, Color(1, 1, 1, 0.09), 1, 12.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	bottom.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	# emplacements d'inventaire : aperçus 3D (1 mortier, 2 pierres, 3 briquet, 4 fumigène)
	for i in 4:
		row.add_child(_make_slot(i))

	# infos : nom, obus, état
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.custom_minimum_size = Vector2(232, 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(top)
	_name = _label("MORTIER D'ARTIFICE", 15, TEXT, false)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	_count = _label("6", 26, AMBER, false)
	top.add_child(_count)
	_cmax = _label(" / 6", 15, MUTED, false)
	_cmax.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_cmax)

	_hint = _label("Vise (clic droit) : la trajectoire s'affiche", 12, MUTED, false)
	_hint.custom_minimum_size = Vector2(232, 32)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.visible = false
	info.add_child(_hint)
	_shells = ShellRow.new()
	_shells.custom_minimum_size = Vector2(232, 32)
	_shells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_shells)

	_status = _label("", 12, AMBER, false)
	_status.custom_minimum_size.y = 16
	info.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(232, 5)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = AMBER
	fg.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fg)
	_bar.modulate.a = 0.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_bar)

	# invite contextuelle
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.08, 0.7), 14, Color(1, 1, 1, 0.08), 1, 8.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := CenterContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_prompt)
	bottom.add_child(pc)
	_prompt_row = _key_row(["CLIC DROIT"], "Maintenir pour viser")
	_prompt.add_child(_prompt_row)
	bottom.move_child(pc, 1)
	_kick_prompt = PanelContainer.new()
	_kick_prompt.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.08, 0.7), 14, Color(1, 0.72, 0.28, 0.5), 1, 8.0))
	_kick_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kick_prompt.modulate.a = 0.0
	_kick_prompt.add_child(_key_row(["F"], "Coup de pied"))
	var kc := CenterContainer.new()
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kc.add_child(_kick_prompt)
	bottom.add_child(kc)
	bottom.move_child(kc, 1)
	_e_prompt = PanelContainer.new()
	_e_prompt.add_theme_stylebox_override("panel", _style(Color(0.05, 0.05, 0.08, 0.7), 14, Color(0.6, 0.85, 1.0, 0.45), 1, 8.0))
	_e_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_e_prompt.modulate.a = 0.0
	var er := _key_row(["E"], "Poubelle")
	_e_label = er.get_child(er.get_child_count() - 1)
	_e_prompt.add_child(er)
	var ec := CenterContainer.new()
	ec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ec.add_child(_e_prompt)
	bottom.add_child(ec)
	bottom.move_child(ec, 1)

	# ---- aide (haut gauche)
	_help = PanelContainer.new()
	_help.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, 0.6), 16, Color(1, 1, 1, 0.07), 1, 14.0))
	_help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_help.offset_left = 18
	_help.offset_top = 18
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_help)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 7)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(hv)
	hv.add_child(_label("COMMANDES", 11, MUTED, false))
	hv.add_child(_key_row(["Z", "Q", "S", "D"], "Marcher"))
	hv.add_child(_key_row(["MAJ"], "Courir"))
	hv.add_child(_key_row(["ESPACE"], "Sauter"))
	hv.add_child(_key_row(["CLIC DROIT"], "Viser (obligatoire pour tirer)"))
	hv.add_child(_key_row(["CLIC GAUCHE"], "Tirer"))
	hv.add_child(_key_row(["F"], "Coup de pied"))
	hv.add_child(_key_row(["V"], "Vue 1re / 3e personne"))
	hv.add_child(_key_row(["1"], "Mortier"))
	hv.add_child(_key_row(["2"], "Pierres (lancer)"))
	hv.add_child(_key_row(["3"], "Briquet + journal (mettre le feu)"))
	hv.add_child(_key_row(["4"], "Fumigène (clic droit : brandir)"))
	hv.add_child(_key_row(["E"], "Poubelle : ouvrir · maintenir : déplacer"))
	hv.add_child(_key_row(["G"], "Appeler la foule à casser l'abribus"))
	hv.add_child(_key_row(["R"], "Recharger (test)"))
	hv.add_child(_key_row(["H"], "Masquer l'aide"))

	_view_chip = _label("TROISIÈME PERSONNE", 12, MUTED, false)
	_view_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_view_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_view_chip.offset_right = -24
	_view_chip.offset_top = 20
	root.add_child(_view_chip)

	_refresh()
	_help_tween = create_tween()
	_help_tween.tween_interval(14.0)
	_help_tween.tween_property(_help, "modulate:a", 0.0, 1.5)
	if not Settings.d["show_help"]:
		_help_tween.kill()
		_help.modulate.a = 0.0


func _process(delta: float) -> void:
	for pv in _pivots:
		pv.rotate_y(delta * 0.9)
	if _kick_prompt:
		_kick_prompt.modulate.a = lerpf(_kick_prompt.modulate.a, 1.0 if _kick_prompt_on else 0.0, minf(1.0, delta * 8.0))
	var cp: Array = _player.context_prompt() if _player else []
	if _prompt:
		var key := str(cp)
		if key != _last_cp:
			_last_cp = key
			_set_prompt(cp)
		var show := not cp.is_empty() and (_item != 1 or _ammo > 0) and _status.text == ""
		_prompt.modulate.a = lerpf(_prompt.modulate.a, 1.0 if show else 0.0, minf(1.0, delta * 8.0))
	if _e_prompt and _player:
		var ep := _player.interact_prompt()
		if ep != "":
			_e_label.text = ep
		_e_prompt.modulate.a = lerpf(_e_prompt.modulate.a, 1.0 if ep != "" else 0.0, minf(1.0, delta * 8.0))


func _set_prompt(cp: Array) -> void:
	if cp.is_empty():
		return
	for c in _prompt_row.get_children():
		_prompt_row.remove_child(c)
		c.queue_free()
	for k in cp[0]:
		_prompt_row.add_child(_keycap(k))
	var l := _label(cp[1], 13, MUTED, false)
	_prompt_row.add_child(l)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
		if _help_tween:
			_help_tween.kill()
		_help.modulate.a = 0.0 if _help.modulate.a > 0.5 else 1.0


func _refresh() -> void:
	_shells.count = _ammo
	_shells.maximum = _max
	_shells.queue_redraw()
	if _item == 2 or _item == 3:
		_count.text = "∞"
		_count.add_theme_color_override("font_color", AMBER)
	elif _item == 4:
		_count.text = str(_flares)
		_count.add_theme_color_override("font_color", AMBER if _flares > 0 else Color(1, 0.4, 0.35))
	else:
		_count.text = str(_ammo)
		_count.add_theme_color_override("font_color", AMBER if _ammo > 0 else Color(1, 0.4, 0.35))
	for i in _slots.size():
		var sel := _item == i + 1
		_slot_styles[i].border_color = AMBER if sel else Color(1, 1, 1, 0.18)
		_slot_styles[i].shadow_size = 14 if sel else 0
		_slots[i].modulate = Color.WHITE if sel else Color(1, 1, 1, 0.6)
	_name.text = ["MAINS LIBRES", "MORTIER D'ARTIFICE", "PIERRES", "BRIQUET + DÉCHETS", "FUMIGÈNE"][clampi(_item, 0, 4)]
	_shells.visible = _item <= 1
	_hint.visible = _item >= 2
	_hint.text = ["", "", "Vise (clic droit) : la trajectoire s'affiche", "Dépose le journal (ou ce que tu ramasses avec E) dans une poubelle ou par terre, puis allume", "Craque-le, brandis-le (clic droit), lance-le"][clampi(_item, 0, 4)]
	if _cmax:
		_cmax.text = (" / %d" % _flares_max) if _item == 4 else (" / %d" % _max if _item <= 1 else "")


func _on_item(i: int) -> void:
	_item = i
	_selected = i != 0
	_refresh()
	if i > 0:
		var sl := _slots[i - 1]
		sl.pivot_offset = sl.size * 0.5
		var tw := create_tween()
		tw.tween_property(sl, "scale", Vector2.ONE * 1.1, 0.08)
		tw.tween_property(sl, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_ammo(count: int, maximum: int) -> void:
	_ammo = count
	_max = maximum
	_refresh()
	_shells.pulse = 1.0
	var tw := create_tween()
	tw.tween_method(func(v): _shells.pulse = v; _shells.queue_redraw(), 1.0, 0.0, 0.8)
	if count == 0:
		_toast_show("Dernier obus")


func _on_stage(label: String, progress: float) -> void:
	_status.text = label
	_bar.value = progress
	_bar.modulate.a = 1.0 if label != "" else 0.0


func _on_aim(on: bool) -> void:
	if _aim_tween:
		_aim_tween.kill()
	_aim_on = on
	if on:
		_post.visible = true
	_aim_tween = create_tween().set_parallel(true)
	_aim_tween.tween_method(func(v): (_post.material as ShaderMaterial).set_shader_parameter("amount", v), 0.0 if on else 1.0, 1.0 if on else 0.0, 0.35)
	_aim_tween.tween_property(_reticle, "modulate:a", 1.0 if on else 0.0, 0.25)
	if not on:
		_aim_tween.chain().tween_callback(func(): _post.visible = false)


func _on_view(first_person: bool) -> void:
	_view_chip.text = "PREMIÈRE PERSONNE" if first_person else "TROISIÈME PERSONNE"


func _toast_show(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
