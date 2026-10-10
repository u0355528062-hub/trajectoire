class_name ParisStreet
extends Node3D
## Le boulevard : deux rangées continues d'immeubles haussmanniens de part et d'autre de la chaussée, trottoirs
## et bordures. Deux immeubles sur trois (dans la zone jouable) ont des boutiques envahissables.

const NORTH_Z := 19.0          # façades côté nord (face à la route, vers -Z)
const SOUTH_Z := -26.0         # façades côté sud (vers +Z)
const X_MIN := -170.0
const X_MAX := 170.0
const SHOP_ZONE := 80.0        # au-delà, façades seules (pas d'intérieurs)

var crowd: Crowd
var buildings: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1871
	for side in [1, -1]:
		var x := X_MIN
		var k := 0
		while x < X_MAX:
			var w := rng.randf_range(13.0, 19.0)
			var b := ParisBuilding.new()
			b.width = w
			b.seed_v = rng.randi()
			b.crowd = crowd
			var mid := x + w * 0.5
			b.lod_far = absf(mid) > 70.0
			if absf(mid) < SHOP_ZONE and (k % 3) != 2:
				b.shops = 1 if w < 15.0 else 2
			if side == 1:
				# rangée nord : façade tournée vers la route (-Z)
				b.position = Vector3(x + w, 0.0, NORTH_Z)
				b.rotation.y = PI
			else:
				b.position = Vector3(x, 0.0, SOUTH_Z)
			add_child(b)
			buildings.append(b)
			x += w
			k += 1
	_sidewalks()


func _sidewalks() -> void:
	var pav := StandardMaterial3D.new()
	pav.albedo_texture = load("res://assets/busstop/paving_a.png")
	pav.normal_enabled = true
	pav.normal_texture = load("res://assets/busstop/paving_n.png")
	pav.normal_scale = 0.8
	pav.uv1_triplanar = true
	pav.uv1_scale = Vector3(0.5, 0.5, 0.5)
	pav.roughness = 0.86
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.62, 0.61, 0.58)
	curb.roughness = 0.8
	var L := X_MAX - X_MIN
	var cx := (X_MAX + X_MIN) * 0.5
	for strip in [[NORTH_Z - 2.6, NORTH_Z], [SOUTH_Z, SOUTH_Z + 2.6]]:
		var z0: float = strip[0]
		var z1: float = strip[1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(L, 0.03, z1 - z0)
		mi.mesh = bm
		mi.material_override = pav
		mi.position = Vector3(cx, 0.015, (z0 + z1) * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var cm := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(L, 0.05, 0.22)
		cm.mesh = cb
		cm.material_override = curb
		var edge := z0 if z0 < z1 and strip[1] == NORTH_Z else z1
		cm.position = Vector3(cx, 0.025, edge + (0.11 if strip[1] == NORTH_Z else -0.11))
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cm)
