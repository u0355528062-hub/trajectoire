class_name ArcPreview
extends Node3D
## Trajectoire en pointillés + cercle d'impact (aide à la visée des objets lancés).

var _dots: Array[MeshInstance3D] = []
var _marker: MeshInstance3D
var exclude: Array[RID] = []


func _ready() -> void:
	top_level = true
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.95, 0.8, 0.9)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var sm := SphereMesh.new()
	sm.radius = 0.024
	sm.height = 0.048
	sm.radial_segments = 8
	sm.rings = 4
	for i in 26:
		var d := MeshInstance3D.new()
		d.mesh = sm
		d.material_override = dm
		d.visible = false
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.layers = 1
		add_child(d)
		_dots.append(d)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.1
	tm.outer_radius = 0.125
	_marker.mesh = tm
	_marker.material_override = dm
	_marker.visible = false
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func hide_all() -> void:
	for d in _dots:
		d.visible = false
	_marker.visible = false


func show_arc(origin: Vector3, v: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var p := origin
	var hit := false
	var hit_pos := Vector3.ZERO
	var hit_n := Vector3.UP
	var dt := 0.045
	for i in _dots.size():
		var vn := v + Vector3(0, -9.8 * dt, 0)
		var pn := p + (v + vn) * 0.5 * dt
		if not hit:
			var q := PhysicsRayQueryParameters3D.create(p, pn, 1 | 32)
			q.exclude = exclude
			var r := space.intersect_ray(q)
			if r:
				hit = true
				hit_pos = r["position"]
				hit_n = r["normal"]
		_dots[i].visible = not hit and i > 1
		_dots[i].global_position = pn
		_dots[i].scale = Vector3.ONE * (1.0 - float(i) / _dots.size() * 0.6)
		v = vn
		p = pn
	_marker.visible = hit
	if hit:
		_marker.global_position = hit_pos + hit_n * 0.015
		_marker.global_basis = Basis(Quaternion(Vector3.UP, hit_n)) * Basis.from_scale(Vector3(1, 0.15, 1))


## Vitesse initiale (tir tendu) pour atteindre `target` à la vitesse `speed`
static func solve(origin: Vector3, target: Vector3, speed: float, lob := false) -> Vector3:
	var d := Vector3(target.x - origin.x, 0, target.z - origin.z)
	var dist := maxf(d.length(), 0.5)
	var h := target.y - origin.y
	var g := 9.8
	var v := speed
	var disc := v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	var tan_t := 0.75
	if disc >= 0.0:
		tan_t = ((v * v + sqrt(disc)) if lob else (v * v - sqrt(disc))) / (g * dist)
	var ang := atan(tan_t)
	return (d.normalized() * cos(ang) + Vector3.UP * sin(ang)) * v
