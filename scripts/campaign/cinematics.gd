class_name Cinematics
extends Node
## Cinématiques : caméra de cinéma (plans fixes, travellings avec courbes d'accélération, panoramiques, zooms,
## caméra à l'épaule, profondeur de champ), bandes noires animées, fondus, cartons de titre.
## `begin()` prend la main (joueur figé mais vivant, interface de jeu masquée, bandes noires), `end()` la rend et
## ramène la caméra en douceur sur celle du joueur. Spec des plans : docs/CAMPAGNE.md § « Plans ».
## Tout est animé image par image dans _process ; les attentes portent sur le signal `frame` de ce nœud (enfant
## du directeur) : si la scène disparaît, elles ne reprennent jamais.

signal frame                      # émis à chaque image (attentes des plans, fondus et cartons)

const BAR_H := 0.115              # hauteur d'une bande noire (fraction de l'écran) : ≈ 2,35:1 en 16:9
const RETURN_S := 0.7             # retour à la caméra du joueur

var director: ChapterDirector
var active := false
var cam: Camera3D
var _layer: CanvasLayer           # fondu + cartons (sous les sous-titres)
var _bars_layer: CanvasLayer
var _fade: ColorRect
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _bars := 0.0
var _bars_want := 0.0
var _card: Control
var _hidden := {}                 # interface masquée pendant la cinématique : nœud -> visibilité d'avant
var _frozen := false
var _clock := 0.0
var _attrs: CameraAttributesPractical
# plan en cours
var _serial := 0
var _shot := {}
var _shot_t := 0.0
var _blend_t := -1.0
var _blend_from := Transform3D.IDENTITY
var _blend_fov := 50.0
# retour vers la caméra du joueur
var _ret_t := -1.0
var _ret_from := Transform3D.IDENTITY
var _ret_fov := 50.0
# fondu
var _fade_serial := 0
var _fade_from := 0.0
var _fade_to := 0.0
var _fade_t := 0.0
var _fade_d := 0.0


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	_bars_layer = CanvasLayer.new()
	_bars_layer.layer = 34
	add_child(_bars_layer)
	_bar_top = _bar(true)
	_bar_bot = _bar(false)
	_layer = CanvasLayer.new()
	_layer.layer = 33
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0
	r.anchor_bottom = 0.0 if top else 1.0
	r.visible = false
	_bars_layer.add_child(r)
	return r


func _k() -> float:
	return 0.02 if Campaign.autoplay else 1.0


# ------------------------------------------------------------------ prise de main
func begin() -> void:
	if active:
		return
	active = true
	_ret_t = -1.0
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.name = "CineCam"
		cam.near = 0.05
		cam.far = 4000.0
		director.main.add_child(cam)
		_attrs = _world_attrs()
		cam.attributes = _attrs
	var pc := _player_cam()
	if pc:
		cam.global_transform = pc.global_transform
		cam.fov = pc.fov
	cam.current = true
	_shot = {}
	_set_dof(0.0)
	letterbox(true)
	_hide_hud(true)
	_freeze(true)


func end() -> void:
	if not active:
		return
	active = false
	_serial += 1                  # un plan en cours s'arrête
	_shot = {}
	letterbox(false)
	_hide_hud(false)
	_freeze(false)
	var pc := _player_cam()
	if pc == null:
		return
	if Campaign.autoplay or _fade.color.a > 0.5 or cam == null:
		pc.current = true
		return
	_ret_t = 0.0
	_ret_from = cam.global_transform
	_ret_fov = cam.fov


func _player_cam() -> Camera3D:
	var p: Player = director.player if director else null
	return p.camera if p and is_instance_valid(p) and p.camera else null


## Copie des réglages de caméra du monde (exposition) pour y ajouter la profondeur de champ
func _world_attrs() -> CameraAttributesPractical:
	var a: CameraAttributesPractical = null
	for c in director.main.get_children():
		if c is WorldEnvironment and (c as WorldEnvironment).camera_attributes is CameraAttributesPractical:
			a = (c as WorldEnvironment).camera_attributes.duplicate()
			break
	return a if a else CameraAttributesPractical.new()


func _set_dof(dist: float) -> void:
	if _attrs == null:
		return
	var on := dist > 0.05
	_attrs.dof_blur_far_enabled = on
	_attrs.dof_blur_near_enabled = on and dist > 1.2
	if on:
		_attrs.dof_blur_far_distance = dist * 1.25 + 0.6
		_attrs.dof_blur_far_transition = dist * 0.9 + 2.0
		_attrs.dof_blur_near_distance = maxf(dist * 0.55, 0.3)
		_attrs.dof_blur_near_transition = maxf(dist * 0.35, 0.2)
		_attrs.dof_blur_amount = 0.09


## Joueur figé (ni déplacement ni commandes) mais vivant : il respire, cligne des yeux
func _freeze(on: bool) -> void:
	var p: Player = director.player if director else null
	if p == null or not is_instance_valid(p):
		return
	if on and not _frozen:
		_frozen = true
		p.velocity = Vector3.ZERO
		p.set_physics_process(false)
		p.set_process_unhandled_input(false)
	elif not on and _frozen:
		_frozen = false
		p.set_physics_process(true)
		p.set_process_unhandled_input(true)


func _hide_hud(on: bool) -> void:
	if on:
		var lst: Array = []
		for c in director.main.get_children():
			if c is CanvasLayer and not (c is PauseMenu):
				lst.append(c)
		for c in get_tree().get_nodes_in_group("hud"):
			if not lst.has(c):
				lst.append(c)
		if director.objectives:
			lst.append(director.objectives)
		for n in lst:
			if is_instance_valid(n) and not _hidden.has(n) and n.get("visible") != null:
				_hidden[n] = n.visible
				n.visible = false
	else:
		for n in _hidden:
			if is_instance_valid(n):
				n.visible = _hidden[n]
		_hidden.clear()


# ------------------------------------------------------------------ plans
## Plan : {"from", "to", "look", "look_to", "dur", "fov", "fov_to", "ease", "dof", "shake", "cut", "blend"}.
## Cibles : Vector3, Node3D, id de personnage, "player" ou id de lieu. "dof" : distance de mise au point
## (0 = net partout, < 0 = mise au point automatique sur la cible regardée). "cut" : false = la caméra glisse
## depuis sa place actuelle (en "blend" s, 0,8 par défaut) au lieu d'un raccord sec.
func shot(spec: Dictionary) -> void:
	if not active:
		begin()
	_serial += 1
	var my := _serial
	var cur := cam.global_transform
	var s := {}
	s["from"] = _point(spec.get("from", cur.origin), cur.origin)
	s["to"] = _point(spec.get("to", s["from"]), s["from"])
	var ahead: Vector3 = cur.origin - cur.basis.z * 10.0
	s["look"] = spec.get("look", ahead)
	s["look_to"] = spec.get("look_to", s["look"])
	s["dur"] = maxf(float(spec.get("dur", 3.0)) * _k(), 0.001)
	s["fov"] = float(spec.get("fov", cam.fov if spec.has("fov_to") else 50.0))
	s["fov_to"] = float(spec.get("fov_to", s["fov"]))
	s["ease"] = str(spec.get("ease", "inout"))
	s["dof"] = float(spec.get("dof", 0.0))
	s["shake"] = clampf(float(spec.get("shake", 0.0)), 0.0, 1.0)
	_shot = s
	_shot_t = 0.0
	_ret_t = -1.0
	if spec.get("cut", true) == false and not Campaign.autoplay:
		_blend_t = 0.0
		_blend_from = cur
		_blend_fov = cam.fov
		s["blend"] = maxf(float(spec.get("blend", 0.8)), 0.05)
	else:
		_blend_t = -1.0
	_apply_shot(0.0)
	while _serial == my and (_blend_t >= 0.0 or _shot_t < float(s["dur"])):
		await frame


func _point(v: Variant, def: Vector3) -> Vector3:
	if v is Vector3:
		return v
	if v is Node3D or v is String:
		return _target(v)
	return def


func _ease(u: float, kind: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match kind:
		"linear":
			return u
		"in":
			return u * u * u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
	return 0.5 - 0.5 * cos(PI * u)


## Place la caméra du plan en cours (secousses comprises)
func _apply_shot(delta: float) -> void:
	if _shot.is_empty() or cam == null:
		return
	var s := _shot
	if _blend_t < 0.0:
		_shot_t = minf(_shot_t + delta, float(s["dur"]))
	var u := _ease(_shot_t / float(s["dur"]), str(s["ease"]))
	var pos: Vector3 = (s["from"] as Vector3).lerp(s["to"], u)
	var la := _target(s["look"])
	var lb := _target(s["look_to"])
	var lk := la.lerp(lb, u)
	var xf := Transform3D(Basis.IDENTITY, pos)
	if pos.distance_to(lk) > 0.01:
		xf = xf.looking_at(lk, Vector3.UP if absf((lk - pos).normalized().y) < 0.98 else Vector3.FORWARD)
	var sh: float = s["shake"]
	if sh > 0.0:
		var c := _clock
		var rx := (sin(c * 1.13) * 0.6 + sin(c * 2.71 + 1.0) * 0.3 + sin(c * 5.3 + 2.0) * 0.1) * 0.014 * sh
		var ry := (sin(c * 0.87 + 3.0) * 0.6 + sin(c * 2.13 + 0.5) * 0.3 + sin(c * 4.7) * 0.1) * 0.018 * sh
		var rz := (sin(c * 0.61 + 1.7) * 0.7 + sin(c * 1.9) * 0.3) * 0.01 * sh
		xf.basis = xf.basis * Basis.from_euler(Vector3(rx, ry, rz))
		xf.origin += xf.basis * Vector3(sin(c * 1.41) * 0.02, sin(c * 1.77 + 0.4) * 0.015, 0.0) * sh
	var fov := lerpf(float(s["fov"]), float(s["fov_to"]), u)
	if _blend_t >= 0.0:
		_blend_t += delta
		var b := _ease(_blend_t / float(s["blend"]), "inout")
		xf = _blend_from.interpolate_with(xf, b)
		fov = lerpf(_blend_fov, fov, b)
		if _blend_t >= float(s["blend"]):
			_blend_t = -1.0
	cam.global_transform = xf
	cam.fov = fov
	var dof: float = s["dof"]
	_set_dof(pos.distance_to(lk) if dof < 0.0 else dof)


## Position visée : Vector3, nœud, "player", id de personnage (sa tête) ou id de lieu
func _target(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Node3D and is_instance_valid(v):
		if v is Actor and (v as Actor).human:
			return (v as Actor).head_pos()
		return (v as Node3D).global_position + Vector3.UP * 1.5
	if v is String:
		if v == "player" or v == "sam":
			var p: Player = director.player
			if p and is_instance_valid(p):
				return p.human.head_world() if p.human else p.global_position + Vector3.UP * 1.6
		var a := director.cast.get_actor(v) if director.cast else null
		if a:
			return a.head_pos() if a.human else a.global_position + Vector3.UP * 1.6
		if Quartier.SPOTS.has(v):
			return Quartier.spot(v) + Vector3.UP * 1.5
	return cam.global_position - cam.global_basis.z * 10.0 if cam else Vector3.ZERO


# ------------------------------------------------------------------ fondus
func fade_out(sec := 0.6) -> void:
	await _fade_go(1.0, sec)


func fade_in(sec := 0.6) -> void:
	await _fade_go(0.0, sec)


func _fade_go(a: float, sec: float) -> void:
	_fade_serial += 1
	var my := _fade_serial
	_fade_from = _fade.color.a
	_fade_to = a
	_fade_t = 0.0
	_fade_d = sec * _k()
	if _fade_d <= 0.001:
		_fade.color.a = a
		_fade_d = 0.0
		await frame
		return
	while _fade_serial == my and _fade_t < _fade_d:
		await frame


# ------------------------------------------------------------------ cartons
## Carton de titre : titre au feutre, filet rouge, sous-titre en petites capitales (date, lieu : deux lignes
## si le sous-titre contient un retour à la ligne ou « · »). Apparition et disparition en fondu, léger glissement.
func title_card(title: String, subtitle := "", sec := 3.5) -> void:
	if _card and is_instance_valid(_card):
		_card.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	_layer.add_child(root)
	_card = root
	if _fade.color.a < 0.6:
		var veil := TextureRect.new()
		veil.texture = UiStyle.spot_tex()
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.stretch_mode = TextureRect.STRETCH_SCALE
		veil.modulate = Color(0, 0, 0, 0.7)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(veil)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var lines := subtitle.replace(" · ", "\n").split("\n", false)
	if lines.size() > 1:
		var top := UiStyle.label(lines[0].to_upper(), 15, UiStyle.PAPER_DIM, "caps")
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(top)
	var t := UiStyle.misprint(UiStyle.label(title, 68, UiStyle.PAPER, "marker"), UiStyle.RED, Vector2(4, 3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var rule := ColorRect.new()
	rule.color = UiStyle.RED
	rule.custom_minimum_size = Vector2(0, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	if lines.size() > 0:
		var sub := UiStyle.label(lines[-1].to_upper() if lines.size() > 1 else lines[0].to_upper(), 19, UiStyle.PAPER, "caps")
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)
	var d := maxf(sec * _k(), 0.001)
	var fin := minf(0.9, d * 0.3)
	var el := 0.0
	while el < d and is_instance_valid(root):
		await frame
		el += get_process_delta_time()
		var a := minf(el / fin, 1.0) * minf((d - el) / fin, 1.0)
		root.modulate.a = UiStyle.smooth(clampf(a, 0.0, 1.0))
		box.position.y = (root.size.y - box.size.y) * 0.5 - 8.0 * (el / d)
		rule.custom_minimum_size.x = 60.0 + 140.0 * UiStyle.smooth(clampf(el / (fin * 1.6), 0.0, 1.0))
	if is_instance_valid(root):
		root.queue_free()


func letterbox(on: bool) -> void:
	_bars_want = 1.0 if on else 0.0
	if Campaign.autoplay:
		_bars = _bars_want
		_place_bars()


func _place_bars() -> void:
	var h := BAR_H * UiStyle.smooth(_bars)
	_bar_top.anchor_bottom = h
	_bar_bot.anchor_top = 1.0 - h
	_bar_top.offset_bottom = 0.0
	_bar_bot.offset_top = 0.0
	_bar_top.visible = _bars > 0.001
	_bar_bot.visible = _bars > 0.001


# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	_clock += delta
	# bandes noires
	if _bars != _bars_want:
		_bars = move_toward(_bars, _bars_want, delta / 0.6)
		_place_bars()
	# fondu
	if _fade_d > 0.0 and _fade_t < _fade_d:
		_fade_t = minf(_fade_t + delta, _fade_d)
		_fade.color.a = lerpf(_fade_from, _fade_to, UiStyle.smooth(_fade_t / _fade_d))
	# caméra
	if active:
		_apply_shot(delta)
		var p: Player = director.player if director else null
		if _frozen and p and is_instance_valid(p) and p.human:
			p.human.animate(delta, 0.0, 0.0, true, 0.0, 0.0)
	elif _ret_t >= 0.0:
		var pc := _player_cam()
		if pc == null or cam == null:
			_ret_t = -1.0
		else:
			_ret_t += delta
			var b := _ease(_ret_t / RETURN_S, "inout")
			cam.global_transform = _ret_from.interpolate_with(pc.global_transform, b)
			cam.fov = lerpf(_ret_fov, pc.fov, b)
			_set_dof(0.0)
			if _ret_t >= RETURN_S:
				_ret_t = -1.0
				pc.current = true
	frame.emit()
