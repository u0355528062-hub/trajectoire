class_name TitleScreen
extends CanvasLayer
## Écran d'accueil au lancement : la rue vit en arrière-plan, floutée, filmée par une caméra qui
## glisse lentement ; titre « BLOCUS » au marqueur, accroche, boutons Jouer / Réglages / Commandes /
## Quitter, « Appuie sur une touche ». N'apparaît ni sans affichage, ni quand la scène est lancée par
## un script de test, ni après un « Recommencer ». Une fois en jeu, la souris est capturée.

static var force_show := false       ## les scripts de capture peuvent forcer l'affichage
static var _seen := false            ## déjà passé une fois dans cette session

var menu: PauseMenu
var _showing := true
var _leaving := false
var _root: Control
var _bg: ColorRect
var _content: Control
var _col: VBoxContainer
var _press: Control
var _cam: Camera3D
var _hidden: Array = []              # calques d'interface masqués pendant l'accueil
var _frozen: Array = []              # nœuds suspendus pendant l'accueil (joueur, tension)
var _t := 0.0
var _focus_btn: Button


## Faut-il afficher l'écran titre ? (pas en mode sans affichage, pas sous un script de test)
static func should_show(tree: SceneTree) -> bool:
	if force_show:
		return true
	if _seen:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	if tree == null or tree.get_script() != null:
		return false
	return true


func is_showing() -> bool:
	return _showing


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_seen = true
	UiStyle.apply_theme(get_tree())
	_build()
	_freeze_world.call_deferred()


# =================================================================== monde en arrière-plan
func _freeze_world() -> void:
	var main := menu.get_parent() if menu else null
	if main == null:
		return
	for n in main.get_children():
		if n is CanvasLayer and n != menu and (n as CanvasLayer).visible:
			(n as CanvasLayer).visible = false
			_hidden.append(n)
	if menu.player:
		_frozen.append(menu.player)
	if menu.tension:
		_frozen.append(menu.tension)
	for n in _frozen:
		(n as Node).process_mode = Node.PROCESS_MODE_DISABLED
	# caméra de présentation : derrière le cortège, vers la ligne de CRS
	_cam = Camera3D.new()
	_cam.name = "TitleCamera"
	_cam.fov = 52.0
	_cam.far = 1500.0
	main.add_child(_cam)
	_place_cam(0.0)
	_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _focus_btn:
		_focus_btn.grab_focus()


func _place_cam(t: float) -> void:
	if _cam == null:
		return
	var s := sin(t * 0.05)
	var pos := Vector3(-4.0 + 3.5 * s, 2.3 + 0.25 * sin(t * 0.09), 5.5)
	var look := Vector3(30.0 + 4.0 * s, 1.8, -7.0)
	_cam.global_position = pos
	_cam.look_at(look)


# =================================================================== construction
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# fond : la scène floutée, assombrie à gauche, trame de points
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 ink = vec3(0.063, 0.058, 0.066);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = textureLod(screen_tex, uv, 2.2).rgb;
	float g = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(g) * vec3(1.0, 0.94, 0.88), 0.35);
	float left = smoothstep(0.78, 0.05, uv.x);
	col = mix(col, ink, 0.25 + 0.6 * left);
	vec2 d = uv - 0.5;
	col *= 1.0 - smoothstep(0.35, 0.95, length(d * vec2(1.0, 1.2))) * 0.5;
	COLOR = vec4(col, 1.0);
}"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_bg.material = sm
	_root.add_child(_bg)
	var ht := TextureRect.new()
	ht.texture = UiStyle.halftone_tex()
	ht.stretch_mode = TextureRect.STRETCH_TILE
	ht.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ht.set_anchors_preset(Control.PRESET_FULL_RECT)
	ht.modulate = Color(UiStyle.PAPER, 0.04)
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ht)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)

	# slogan géant, à peine visible, de travers à droite
	var slogan := UiStyle.label("ON LÂCHE RIEN", 170, Color(UiStyle.PAPER, 0.06), "marker")
	slogan.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	slogan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	slogan.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slogan.offset_right = -60
	slogan.offset_bottom = -120
	slogan.rotation = deg_to_rad(-7.0)
	_content.add_child(slogan)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	m.offset_right = 900
	m.add_theme_constant_override("margin_left", 130)
	m.add_theme_constant_override("margin_bottom", 60)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	_col = v
	v.add_child(PauseMenu.tape("PARIS  ·  JOUR DE MANIF"))
	var t := UiStyle.misprint(UiStyle.label("BLOCUS", 230, UiStyle.PAPER, "marker"), UiStyle.RED, Vector2(10, 8))
	t.add_theme_constant_override("line_spacing", -60)
	v.add_child(t)
	var tag := UiStyle.label("Une rue de Paris. Une foule. Une ligne de CRS.", 26, UiStyle.PAPER_DIM, "semibold")
	v.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size.y = 34
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(col)
	var b_play := _btn("Jouer", true)
	b_play.pressed.connect(_start)
	col.add_child(b_play)
	_focus_btn = b_play
	var b_set := _btn("Réglages")
	b_set.pressed.connect(func(): _open_menu("settings"))
	col.add_child(b_set)
	var b_ctl := _btn("Commandes")
	b_ctl.pressed.connect(func(): _open_menu("controls"))
	col.add_child(b_ctl)
	var b_q := _btn("Quitter")
	b_q.pressed.connect(func(): get_tree().quit())
	col.add_child(b_q)

	# « appuie sur une touche »
	var pc := CenterContainer.new()
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.offset_top = -90
	pc.offset_bottom = -40
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(pc)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(ph)
	var dot := ColorRect.new()
	dot.color = UiStyle.RED
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(dot)
	ph.add_child(UiStyle.label("APPUIE SUR UNE TOUCHE POUR DESCENDRE DANS LA RUE", 16, UiStyle.PAPER, "caps"))
	_press = ph

	# entrée en scène
	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, 0.8).set_delay(0.15)


func _btn(text: String, primary := false) -> UiKit.Btn:
	var b := UiKit.Btn.new(text.to_upper(), primary)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 58 if primary else 50)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := b.get_theme_stylebox(k)
		if sb is StyleBoxFlat:
			(sb as StyleBoxFlat).content_margin_left = 24
	return b


# =================================================================== interactions
func _process(delta: float) -> void:
	if not _showing:
		return
	_t += delta
	if not _leaving:
		_place_cam(_t)
	if _press:
		_press.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 3.0))


func _unhandled_input(event: InputEvent) -> void:
	if not _showing or _leaving or (menu and menu.is_open()):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE:
			return
		_start()


func _open_menu(page: String) -> void:
	if menu == null:
		return
	_root.visible = false
	menu.open_from_title(page)


## Retour depuis les réglages ouverts à l'accueil
func back_from_menu() -> void:
	_root.visible = true
	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, 0.25)
	if _focus_btn:
		_focus_btn.grab_focus()


## On entre dans la partie : la caméra rejoint celle du joueur, l'interface revient
func _start() -> void:
	if _leaving:
		return
	_leaving = true
	var to: Camera3D = menu.player.camera if menu and menu.player else null
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_content, "modulate:a", 0.0, 0.35)
	tw.tween_property(_root, "modulate:a", 0.0, 0.9).set_delay(0.2)
	if _cam and to:
		tw.tween_property(_cam, "global_transform", to.global_transform, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cam, "fov", to.fov, 1.0)
	tw.chain().tween_callback(_finish)


func _finish() -> void:
	_showing = false
	for n in _frozen:
		if is_instance_valid(n):
			(n as Node).process_mode = Node.PROCESS_MODE_INHERIT
	for n in _hidden:
		if is_instance_valid(n):
			(n as CanvasLayer).visible = true
	if menu and menu.player and menu.player.camera:
		menu.player.camera.current = true
	if _cam:
		_cam.queue_free()
	get_tree().call_group("hud", "reset_clock")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
