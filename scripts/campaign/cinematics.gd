class_name Cinematics
extends Node
## Cinématiques : caméra de cinéma (plans fixes, travellings, panoramiques, caméra à l'épaule, profondeur de champ),
## bandes noires, fondus, cartons de titre. `begin()` prend la main (joueur figé, interface de jeu masquée),
## `end()` la rend. Spec des plans : docs/CAMPAGNE.md § « Plans ».
## VERSION SQUELETTE : plans et fondus minimaux ; le module Cinématiques la remplace en gardant l'interface publique.

var director: ChapterDirector
var active := false
var cam: Camera3D
var _layer: CanvasLayer
var _fade: ColorRect
var _title: Label


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_title = Label.new()
	_title.anchor_right = 1.0
	_title.anchor_bottom = 1.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_layer.add_child(_title)


func begin() -> void:
	if active:
		return
	active = true
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 50.0
		director.main.add_child(cam)
	var pc: Camera3D = director.player.camera if director.player else null
	if pc:
		cam.global_transform = pc.global_transform
	cam.current = true
	if director.player:
		director.player.set_physics_process(false)


func end() -> void:
	if not active:
		return
	active = false
	if director.player:
		director.player.set_physics_process(true)
		if director.player.camera:
			director.player.camera.current = true


## Plan : {"from", "to", "look", "look_to", "dur", "fov", "fov_to", "ease", "dof", "shake"}
func shot(spec: Dictionary) -> void:
	if not active:
		begin()
	var from: Vector3 = spec.get("from", cam.global_position)
	var to: Vector3 = spec.get("to", from)
	var look_a := _target(spec.get("look", from + Vector3.FORWARD))
	var look_b := _target(spec.get("look_to", spec.get("look", from + Vector3.FORWARD)))
	var dur := float(spec.get("dur", 3.0)) * (0.02 if Campaign.autoplay else 1.0)
	cam.fov = float(spec.get("fov", 50.0))
	var t := 0.0
	while t < dur:
		var u := t / dur
		cam.global_position = from.lerp(to, u)
		var lk := look_a.lerp(look_b, u)
		if cam.global_position.distance_to(lk) > 0.01:
			cam.look_at(lk)
		await director.sleep(0.033)
		t += 0.033
	cam.global_position = to
	if to.distance_to(look_b) > 0.01:
		cam.look_at(look_b)


func _target(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is String:
		if v == "player" and director.player:
			return director.player.global_position + Vector3.UP * 1.6
		var a := director.cast.get_actor(v)
		if a:
			return a.global_position + Vector3.UP * 1.6
		if Quartier.SPOTS.has(v):
			return Quartier.spot(v) + Vector3.UP * 1.5
	return Vector3.ZERO


func fade_out(sec := 0.6) -> void:
	await _fade_to(1.0, sec)


func fade_in(sec := 0.6) -> void:
	await _fade_to(0.0, sec)


func _fade_to(a: float, sec: float) -> void:
	var d := sec * (0.02 if Campaign.autoplay else 1.0)
	var start := _fade.color.a
	var t := 0.0
	while t < d:
		_fade.color.a = lerpf(start, a, t / d)
		await director.sleep(0.02)
		t += 0.02
	_fade.color.a = a


func title_card(title: String, subtitle := "", sec := 3.5) -> void:
	_title.text = title + ("\n" + subtitle if subtitle != "" else "")
	await director.sleep(sec * (0.02 if Campaign.autoplay else 1.0))
	_title.text = ""


func letterbox(_on: bool) -> void:
	pass
