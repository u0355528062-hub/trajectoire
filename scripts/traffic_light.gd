class_name TrafficLight
extends StaticBody3D
## Feu tricolore parisien sur poteau : tête principale (rouge / orange / vert) avec visières, répétiteur à hauteur
## des yeux, feu piétons (bonhomme rouge immobile / vert qui marche) et boîtier d'appel. Le cycle est piloté
## par `Controller` : un seul nœud pour tous les feux, qui ne change les matériaux qu'aux changements d'état.

const CYCLE := 48.0
const GREEN_END := 20.0      # vert véhicules [0, 20[, orange [20, 23[, rouge [23, 48[
const AMBER_END := 23.0
const PED_START := 25.0      # vert piétons [25, 40[ (dégagement de 2 s de chaque côté)
const PED_END := 40.0

var car_yaw := 0.0
var ped_yaw := 0.0
var phase := 0.0
var car_state := -1          # 0 rouge, 1 orange, 2 vert
var ped_green := false
var _lamps: Array = []       # [[MeshInstance3D, couleur], ...] (tête + répétiteur)
var _ped_r: MeshInstance3D
var _ped_g: MeshInstance3D
static var _m := {}


static func _mat(key: String) -> Material:
	if _m.is_empty():
		var cols := {"r": Color(1.0, 0.12, 0.06), "a": Color(1.0, 0.55, 0.05), "g": Color(0.2, 1.0, 0.55)}
		for k in cols:
			var on := StandardMaterial3D.new()
			on.albedo_color = cols[k]
			on.emission_enabled = true
			on.emission = cols[k]
			on.emission_energy_multiplier = 5.0
			on.roughness = 0.2
			_m[k + "1"] = on
			var off := StandardMaterial3D.new()
			off.albedo_color = (cols[k] as Color).darkened(0.86)
			off.roughness = 0.15
			off.metallic_specular = 0.8
			_m[k + "0"] = off
		var atlas: Texture2D = load("res://assets/quartier/panneaux_a.png")
		for k in ["pr", "pg"]:
			for on_i in 2:
				var pm := StandardMaterial3D.new()
				pm.albedo_texture = atlas
				pm.uv1_scale = Vector3(0.5, 0.25, 1)
				pm.uv1_offset = Vector3(0.5, 0.5 if k == "pr" else 0.75, 0)
				if on_i == 1:
					pm.emission_enabled = true
					pm.emission_texture = atlas
					pm.emission_energy_multiplier = 3.5
				else:
					pm.albedo_color = Color(0.16, 0.16, 0.16)
				pm.roughness = 0.2
				_m[k + str(on_i)] = pm
		_m["body"] = Furniture.mat("feu_corps", Color(0.07, 0.075, 0.07), 0.45, 0.3)
		_m["pole"] = Furniture.mat("feu_mat", Color(0.13, 0.16, 0.14), 0.5, 0.45)
		_m["call"] = Furniture.mat("feu_appel", Color(0.86, 0.84, 0.78), 0.5)
	return _m[key]


func _ready() -> void:
	collision_layer = 1
	var body := _mat("body")
	var pole := _mat("pole")
	var b := MeshBatch.new()
	b.cyl("pole", pole, 0.055, 0.055, 3.25, Vector3(0, 1.625, 0))
	b.cyl("pole", pole, 0.085, 0.1, 0.12, Vector3(0, 0.06, 0))
	b.cyl("pole", pole, 0.06, 0.06, 0.04, Vector3(0, 3.27, 0))
	# tête principale tournée vers les véhicules (+Z local du pivot)
	var cb := Basis(Vector3.UP, car_yaw)
	b.box("body", body, Vector3(0.3, 0.9, 0.2), Vector3(0, 2.75, 0) + cb * Vector3(0, 0, 0.14), cb)
	b.box("body", body, Vector3(0.42, 1.0, 0.02), Vector3(0, 2.75, 0) + cb * Vector3(0, 0, 0.035), cb)   # plaque de contraste
	for i in 3:
		var y := 3.03 - i * 0.28
		b.box("body", body, Vector3(0.26, 0.02, 0.16), Vector3(0, y + 0.12, 0) + cb * Vector3(0, 0, 0.3), cb)   # visière
		for side in [-1.0, 1.0]:
			b.box("body", body, Vector3(0.015, 0.14, 0.14), Vector3(0, y + 0.06, 0) + cb * Vector3(side * 0.125, 0, 0.3), cb)
	# répétiteur à hauteur des yeux (côté poteau)
	b.box("body", body, Vector3(0.12, 0.38, 0.1), Vector3(0, 1.55, 0) + cb * Vector3(0, 0, 0.09), cb)
	# feu piétons, tourné vers l'autre rive
	var pb := Basis(Vector3.UP, ped_yaw)
	b.box("body", body, Vector3(0.28, 0.6, 0.18), Vector3(0, 2.0, 0) + pb * Vector3(0, 0, 0.13), pb)
	b.box("body", body, Vector3(0.3, 0.02, 0.12), Vector3(0, 2.31, 0) + pb * Vector3(0, 0, 0.26), pb)
	# boîtier d'appel sonore (pour les malvoyants)
	b.box("call", _mat("call"), Vector3(0.1, 0.16, 0.07), Vector3(0, 1.1, 0) + pb * Vector3(0, 0, 0.08), pb)
	var mi := b.commit(self, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var lens := CylinderMesh.new()
	lens.top_radius = 0.095
	lens.bottom_radius = 0.095
	lens.height = 0.02
	lens.radial_segments = 20
	var small := CylinderMesh.new()
	small.top_radius = 0.036
	small.bottom_radius = 0.036
	small.height = 0.015
	small.radial_segments = 12
	var keys := ["r", "a", "g"]
	for i in 3:
		var l := _lamp(lens, Vector3(0, 3.03 - i * 0.28, 0) + cb * Vector3(0, 0, 0.245), cb)
		_lamps.append([l, keys[i]])
		var s := _lamp(small, Vector3(0, 1.67 - i * 0.12, 0) + cb * Vector3(0, 0, 0.145), cb)
		_lamps.append([s, keys[i]])
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.22)
	_ped_r = _quad(q, Vector3(0, 2.13, 0) + pb * Vector3(0, 0, 0.225), pb)
	_ped_g = _quad(q, Vector3(0, 1.87, 0) + pb * Vector3(0, 0, 0.225), pb)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.08
	cy.height = 3.2
	cs.shape = cy
	cs.position = Vector3(0, 1.6, 0)
	add_child(cs)
	apply(0, false)


func _lamp(mesh: Mesh, pos: Vector3, b: Basis) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.basis = b * Basis(Vector3.RIGHT, PI * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _quad(mesh: Mesh, pos: Vector3, b: Basis) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.basis = b
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Allume les bonnes lampes (ne fait rien si l'état n'a pas changé)
func apply(car: int, ped: bool) -> void:
	if car == car_state and ped == ped_green:
		return
	car_state = car
	ped_green = ped
	var on_key: String = ["r", "a", "g"][car]
	for l in _lamps:
		(l[0] as MeshInstance3D).material_override = _mat(l[1] + ("1" if l[1] == on_key else "0"))
	_ped_r.material_override = _mat("pr0" if ped else "pr1")
	_ped_g.material_override = _mat("pg1" if ped else "pg0")


## État au temps t : [feu véhicules, vert piétons]
static func state_at(t: float) -> Array:
	var u := fposmod(t, CYCLE)
	var car := 2 if u < GREEN_END else (1 if u < AMBER_END else 0)
	return [car, u >= PED_START and u < PED_END]


## Horloge commune de tous les feux (mise à jour 5 fois par seconde)
class Controller extends Node:
	var lights: Array = []
	var t := 0.0
	var _acc := 0.0

	func add(l: TrafficLight) -> void:
		lights.append(l)
		add_child(l)

	func _process(delta: float) -> void:
		t += delta
		_acc += delta
		if _acc < 0.2:
			return
		_acc = 0.0
		for l in lights:
			var st := TrafficLight.state_at(t + (l as TrafficLight).phase)
			(l as TrafficLight).apply(st[0], st[1])
