class_name NpcTag
extends RefCounted
## Tags à la bombe : un manifestant écrit un slogan sur la chaussée, sur un panneau publicitaire ou sur le flanc
## d'un fourgon de police mal gardé. Le texte apparaît lettre par lettre ; les plus anciens finissent par
## disparaître (MAX_TAGS dans la scène).

const SLOGANS := ["RÉSISTE", "TOUS DEBOUT", "ON LÂCHE RIEN", "LA RUE EST À NOUS", "ENSEMBLE", "PAS DE JUSTICE PAS DE PAIX", "ON EST LÀ", "SOLIDARITÉ"]
const COLORS := [Color(0.85, 0.08, 0.1), Color(0.05, 0.05, 0.06), Color(0.95, 0.95, 0.92), Color(0.1, 0.35, 0.85), Color(1.0, 0.8, 0.05)]
const MAX_TAGS := 14
const PAINT_TIME := 3.6

static var _font: FontFile


## Emplacement possible pour un tag : {pos, normal, up, stand, car}
static func pick_spot(n: Npc) -> Dictionary:
	var crowd := n.crowd
	var r := n._rng.randf()
	# flanc d'un fourgon de police mal gardé, à portée de la foule
	if r < 0.3 and crowd.police:
		for v in crowd.police.vehicles:
			if not is_instance_valid(v) or v.kind != "truck" or not v.is_parked() or v.burning:
				continue
			if v.global_position.x > crowd.area_max_x() + 1.0 or v.global_position.distance_to(n.global_position) > 30.0:
				continue
			if crowd.police.nearest_cop(v.global_position, 7.0) != null:
				continue
			var side := v.global_basis.x.normalized()
			if (n.global_position - v.global_position).dot(side) < 0.0:
				side = -side
			var p: Vector3 = v.global_position + side * 1.16 + Vector3.UP * 1.45
			return {"pos": p, "normal": side, "up": Vector3.UP, "stand": p + side * 0.85 - Vector3.UP * 1.45, "car": v}
	# panneau publicitaire
	if r < 0.6:
		for o in n.get_tree().get_nodes_in_group("ad_panels"):
			var ad := o as Node3D
			if ad.global_position.distance_to(n.global_position) > 18.0:
				continue
			var nz := ad.global_basis.z.normalized()
			if (n.global_position - ad.global_position).dot(nz) < 0.0:
				nz = -nz
			var p2: Vector3 = ad.global_position + nz * 0.1 + Vector3.UP * 1.25
			return {"pos": p2, "normal": nz, "up": Vector3.UP, "stand": p2 + nz * 0.8 - Vector3.UP * 1.25, "car": null}
	# chaussée devant la ligne, lisible depuis la foule
	var gx := minf(n.global_position.x + n._rng.randf_range(1.0, 4.0), crowd.area_max_x() - 2.5)
	var gz := clampf(n.global_position.z, -10.2, -4.6)
	var g := Vector3(gx, 0.035, gz)                 # juste au-dessus de l'enrobé (2 cm)
	return {"pos": g, "normal": Vector3.UP, "up": Vector3.RIGHT, "stand": g - Vector3(0.9, 0.035, 0.0), "car": null}


static func start(n: Npc, spot: Dictionary) -> void:
	n._drop_item()
	n.state = "tag"
	n.state_t = 0.0
	n.sub = "go"
	n.sub_t = 0.0
	n.data = spot.duplicate()
	n.data["text"] = SLOGANS[n._rng.randi() % SLOGANS.size()]
	n.data["color"] = COLORS[n._rng.randi() % COLORS.size()]
	n.go(n.crowd.clamp_area(spot["stand"]), false, 0.3)


static func think(n: Npc, delta: float) -> void:
	n.sub_t += delta
	if n.state_t > 30.0:
		_finish(n)
		return
	var pos: Vector3 = n.data["pos"]
	var stand: Vector3 = n.crowd.clamp_area(n.data["stand"])
	match n.sub:
		"go":
			if Vector2(n.global_position.x - stand.x, n.global_position.z - stand.z).length() < 0.5 or (not n.has_goal and n.sub_t > 1.0):
				n.stop_move()
				n.sub = "paint"
				n.sub_t = 0.0
				n.tag_label = _make_label(n)
				n.tag_can = _make_can(n)
			elif not n.has_goal:
				n.go(stand, false, 0.3)
		"paint":
			var ground: bool = (n.data["normal"] as Vector3).y > 0.5
			n.face(pos)
			n.human.crouch = move_toward(n.human.crouch, 0.55 if ground else 0.0, delta * 3.0)
			var sweep := Vector3((n.data["up"] as Vector3).cross(n.data["normal"])) * sin(n.sub_t * 5.0) * 0.25
			n.set_act("spray", {"target": n._wb(pos + sweep + (n.data["normal"] as Vector3) * 0.25)}, 5.0)
			var lab: Label3D = n.tag_label
			if lab and is_instance_valid(lab):
				var full: String = n.data["text"]
				lab.text = full.substr(0, clampi(int(float(full.length()) * n.sub_t / PAINT_TIME) + 1, 1, full.length()))
			var can: Node3D = n.tag_can
			if can and is_instance_valid(can):
				var pr := n.human.palm("R")
				can.global_transform = Transform3D(Props.basis_up(pr["thumb"], n.forward()), (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.03)
			if int(n.sub_t * 2.0) != int((n.sub_t - delta) * 2.0):
				AudioLib.play_at(n, "pepper_spray", pos, -16.0, 4.0, n._rng.randf_range(1.25, 1.45))
			if n.sub_t > PAINT_TIME:
				var car: Node3D = n.data.get("car")
				if car and is_instance_valid(car) and n.crowd.police:
					n.crowd.police.on_event("car_vandal", {"car": car, "pos": car.global_position})
				_finish(n)
				if n._rng.randf() < 0.6:
					n.react("fist", 1.8, pos + Vector3.UP, {"voice": "ouais", "voice_p": 0.5, "prm": {"k": 1.0}})


static func _finish(n: Npc) -> void:
	if n.tag_label and is_instance_valid(n.tag_label):
		n.tag_label.text = n.data["text"]
	cleanup(n)
	n.go_home()


## Fin (ou interruption) : la bombe disparaît, le tag reste tel qu'il est
static func cleanup(n: Npc) -> void:
	if n.tag_can and is_instance_valid(n.tag_can):
		n.tag_can.queue_free()
	n.tag_can = null
	if n.tag_label and is_instance_valid(n.tag_label) and n.crowd:
		n.crowd.add_tag(n.tag_label)
	n.tag_label = null
	n.human.crouch = 0.0


static func _make_label(n: Npc) -> Label3D:
	if _font == null:
		_font = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	var lab := Label3D.new()
	lab.font = _font
	lab.font_size = 96
	lab.pixel_size = 0.0062 if (n.data["normal"] as Vector3).y > 0.5 else 0.0028
	lab.modulate = n.data["color"]
	lab.outline_size = 0
	lab.shaded = true
	lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	lab.double_sided = false
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.text = ""
	var z: Vector3 = (n.data["normal"] as Vector3).normalized()
	var y: Vector3 = (n.data["up"] as Vector3).normalized()
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	n.get_tree().current_scene.add_child(lab)
	lab.global_transform = Transform3D(Basis(x, y, z), n.data["pos"])
	var car: Node3D = n.data.get("car")
	if car and is_instance_valid(car):
		lab.reparent(car, true)          # le tag part avec le fourgon s'il se déplace
	return lab


static func _make_can(n: Npc) -> Node3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.17
	mi.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = n.data["color"]
	m.metallic = 0.6
	m.roughness = 0.35
	mi.material_override = m
	mi.top_level = true
	n.add_child(mi)
	return mi
