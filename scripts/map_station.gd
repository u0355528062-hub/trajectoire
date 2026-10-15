class_name MapStation
extends Node3D
## Station-service « Carbura » de la rue de la Forge (côté ouest, terrain Quartier.STATION) : piste bétonnée, auvent
## éclairé sur deux îlots de pompes, boutique au fond, murs pignons, et le totem des prix au bord du trottoir
## (prix filmables : groupe « price_tags »). Coordonnées monde (le nœud est à l'origine).

const BRAND := "CARBURA"
const PRICES := [["GAZOLE", "2,19"], ["SP95-E10", "2,27"], ["SP98", "2,41"], ["E85", "1,19"]]
const ORANGE := Color(0.95, 0.42, 0.08)
const NAVY := Color(0.06, 0.12, 0.3)

var _body: StaticBody3D


func _ready() -> void:
	name = "StationCarbura"
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	add_child(_body)
	var r: Rect2 = Quartier.STATION
	var crowd: Crowd = (get_parent() as ParisStreet).crowd if get_parent() is ParisStreet else null
	var c := r.get_center()
	# piste bétonnée (le sol reste plat pour la physique)
	var slab := QuadMesh.new()
	slab.size = Vector2(r.size.x, r.size.y)
	slab.orientation = PlaneMesh.FACE_Y
	var conc := Streetscape.tmat("station_beton", "stabilise_a.png", "", Vector3(0.25, 0.25, 0.25), 0.9, Color(0.62, 0.62, 0.6), true)
	var sm := MapStory._mesh(self, slab, conc, Vector3(c.x, 0.012, c.y))
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# murs pignons (fond et côté sud) : le terrain est coincé entre les immeubles
	var wall := MapMairie.stone_mat(Color(0.8, 0.74, 0.66), "plaster")
	_solid(Vector3(0.6, 15.0, r.size.y), wall, Vector3(r.position.x - 0.3, 7.5, c.y))
	_solid(Vector3(r.size.x, 13.0, 0.6), wall, Vector3(c.x, 6.5, r.position.y - 0.3))
	_solid(Vector3(r.size.x, 12.0, 0.6), wall, Vector3(c.x, 6.0, r.end.y + 0.3))
	# îlots de pompes, piliers et auvent
	var white := MapStory.mat(Color(0.92, 0.92, 0.9), 0.45)
	var isl_x := -89.5
	for iz in [-70.0, -62.0]:
		_solid(Vector3(4.6, 0.16, 1.0), MapStory.mat(Color(0.7, 0.7, 0.68), 0.8), Vector3(isl_x, 0.08, iz))
		_solid(Vector3(0.36, 4.7, 0.36), white, Vector3(isl_x, 2.35, iz))
		for px in [-1.6, 1.6]:
			_pump(Vector3(isl_x + px, 0.16, iz))
		if crowd:
			crowd.add_obstacle(_marker(Vector3(isl_x, 0, iz)), Vector2(2.4, 0.55))
	var roof := Node3D.new()
	roof.position = Vector3(isl_x, 4.85, -66.0)
	add_child(roof)
	MapStory.box(roof, Vector3(8.0, 0.5, 16.0), white, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		MapStory.box(roof, Vector3(8.1, 0.36, 0.06), MapStory.mat(ORANGE, 0.4, 0.6), Vector3(0, 0.02, s * 8.02))
	MapStory.box(roof, Vector3(0.06, 0.36, 16.1), MapStory.mat(ORANGE, 0.4, 0.6), Vector3(4.02, 0.02, 0))
	var lb := MapStory.label(roof, BRAND, 0.012, Color(1, 1, 1), Vector3(4.07, 0.02, 0), 96)
	lb.rotation.y = PI * 0.5
	lb.shaded = false
	for k in 3:
		var pan := MapStory.box(roof, Vector3(1.4, 0.04, 1.4), MapStory.mat(Color(1.0, 0.97, 0.9), 0.3, 2.2), Vector3(0, -0.27, -5.0 + k * 5.0))
		pan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for lz in [-70.0, -62.0]:
		var om := OmniLight3D.new()
		om.position = Vector3(isl_x, 4.3, lz)
		om.light_color = Color(1.0, 0.97, 0.92)
		om.light_energy = 1.6
		om.omni_range = 11.0
		om.shadow_enabled = false
		om.distance_fade_enabled = true
		om.distance_fade_begin = 60.0
		om.distance_fade_length = 20.0
		add_child(om)
	_shop(Vector3(r.position.x + 2.0, 0, -75.5))
	_totem(Vector3(r.end.x - 0.9, 0, r.end.y - 3.2), crowd)
	if crowd:
		crowd.add_obstacle(_marker(Vector3(r.position.x + 2.0, 0, -75.5)), Vector2(2.0, 4.0))


func _marker(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	return n


func _solid(size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MapStory.box(self, size, m, pos)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	_body.add_child(cs)
	return mi


## Pompe : socle, corps blanc, bandeau orange, écran, deux pistolets
func _pump(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	MapStory.box(n, Vector3(0.75, 1.75, 0.45), MapStory.mat(Color(0.93, 0.93, 0.92), 0.4), Vector3(0, 0.875, 0))
	MapStory.box(n, Vector3(0.77, 0.25, 0.47), MapStory.mat(ORANGE, 0.45), Vector3(0, 1.62, 0))
	for s in [-1.0, 1.0]:
		MapStory.box(n, Vector3(0.36, 0.22, 0.02), MapStory.mat(Color(0.15, 0.3, 0.35), 0.2, 0.7), Vector3(0, 1.25, s * 0.235))
		MapStory.box(n, Vector3(0.1, 0.24, 0.08), MapStory.mat(Color(0.12, 0.12, 0.13), 0.5), Vector3(0.22, 0.8, s * 0.27))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.75, 1.75, 0.45)
	cs.shape = sh
	cs.position = p + Vector3(0, 0.875, 0)
	_body.add_child(cs)


## Boutique de la station : petit bloc vitré au fond du terrain, tourné vers la piste (+X)
func _shop(p: Vector3) -> void:
	var w := 8.0
	var d := 4.0
	_solid(Vector3(d, 3.4, w), MapMairie.stone_mat(Color(0.86, 0.85, 0.82), "plaster"), p + Vector3(0, 1.7, 0))
	MapStory.box(self, Vector3(0.05, 2.2, w - 1.4), MapStory.mat(Color(0.95, 0.9, 0.75), 0.15, 0.55), p + Vector3(d * 0.5 + 0.03, 1.3, 0))
	MapStory.box(self, Vector3(0.3, 0.6, w + 0.2), MapStory.mat(NAVY, 0.4), p + Vector3(d * 0.5 + 0.15, 3.2, 0))
	var l := MapStory.label(self, BRAND + "  ·  BOUTIQUE  ·  CAFÉ", 0.006, Color(1, 1, 1), p + Vector3(d * 0.5 + 0.31, 3.2, 0), 80)
	l.rotation.y = PI * 0.5
	l.shaded = false


## Totem des prix (double face, perpendiculaire à la rue) : marque, puis une ligne par carburant
func _totem(p: Vector3, crowd: Crowd) -> void:
	var t := Node3D.new()
	t.name = "TotemPrix"
	t.position = p
	add_child(t)
	_solid(Vector3(0.3, 1.0, 0.3), MapStory.mat(Color(0.3, 0.3, 0.32), 0.6), p + Vector3(0, 0.5, 0))
	MapStory.box(t, Vector3(1.5, 3.6, 0.32), MapStory.mat(NAVY, 0.45), Vector3(0, 2.8, 0))
	MapStory.box(t, Vector3(1.4, 0.7, 0.34), MapStory.mat(ORANGE, 0.4, 0.5), Vector3(0, 4.2, 0))
	for s in [1.0, -1.0]:
		var face := Node3D.new()
		face.rotation.y = 0.0 if s > 0.0 else PI
		t.add_child(face)
		var b := MapStory.label(face, BRAND, 0.0028, Color(1, 1, 1), Vector3(0, 4.2, 0.18), 96)
		b.shaded = false
		for i in PRICES.size():
			var row := Node3D.new()
			row.position = Vector3(0, 3.55 - i * 0.62, 0.17)
			if s > 0.0:
				row.add_to_group("price_tags")
			face.add_child(row)
			MapStory.box(row, Vector3(1.32, 0.5, 0.01), MapStory.mat(Color(0.03, 0.03, 0.04), 0.3), Vector3.ZERO)
			var n := MapStory.label(row, PRICES[i][0], 0.0028, Color(1, 1, 1), Vector3(-0.32, 0.0, 0.008), 48)
			n.shaded = false
			var v := MapStory.label(row, PRICES[i][1], 0.0062, Color(1.0, 0.62, 0.12), Vector3(0.36, 0.0, 0.008), 64)
			v.shaded = false
	if crowd:
		crowd.add_obstacle(t, Vector2(0.8, 0.25))
