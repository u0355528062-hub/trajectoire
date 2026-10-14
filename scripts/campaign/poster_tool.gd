class_name PosterTool
extends KitTool
## Affiches + colle : pot de colle dans la main gauche, brosse dans la droite. Clic gauche face à une surface :
## on encolle, on pose l'affiche, on lisse à la brosse (2,4 s, sans bouger). Colonne Morris et panneaux d'affichage
## libre (groupe « affichage_libre ») : légal ; mur, abribus : illégal (la police peut verbaliser).
## Événement : poster_stuck {"pos", "surface": morris|panneau|mur|abribus, "legal"}.

const MAX := 12
const REACH := 1.5
const T_GLUE := 0.9
const T_PLACE := 1.35
const T_DONE := 2.4
const W := 0.32
const H := 0.46
const MAX_IN_SCENE := 40
## Modèles d'affiches : fond, encre du titre, titre, encre du texte, texte
const DESIGNS := [
	[Color(0.94, 0.91, 0.84), Color(0.8, 0.1, 0.08), "NON À LA\nLOI DE\nSTABILITÉ", Color(0.1, 0.1, 0.11), "Rassemblement\nsamedi 14 h · au square"],
	[Color(0.8, 0.11, 0.09), Color(0.97, 0.94, 0.88), "LA VIE\nCHÈRE,\nÇA SUFFIT", Color(0.97, 0.94, 0.88), "Tous ensemble\nsamedi 14 h · au square"],
	[Color(0.98, 0.8, 0.12), Color(0.08, 0.08, 0.09), "GAZOLE 2,79 €\nBAGUETTE 1,65 €\nET NOS SALAIRES ?", Color(0.08, 0.08, 0.09), "Retrait de la loi\nde Stabilité"],
]

static var _font: Font
static var _stuck: Array = []

var count := MAX
var _t := -1.0
var _spot := {}
var _start := Vector3.ZERO
var _design := 0
var _pot: Node3D
var _brush: Node3D
var _poster: Node3D
var _aim_cache := {}
var _aim_cd := 0.0


func _build() -> void:
	if _pot != null:
		return
	var tin := mat("glue_tin", func() -> Material: return MeshKit.std_mat(Color(0.72, 0.73, 0.75), 0.35, 0.8))
	var white := mat("glue_white", func() -> Material: return MeshKit.std_mat(Color(0.93, 0.93, 0.9), 0.4))
	var wood := mat("brush_wood", func() -> Material: return MeshKit.std_mat(Color(0.55, 0.36, 0.2), 0.6))
	var hair := mat("brush_hair", func() -> Material: return MeshKit.std_mat(Color(0.82, 0.78, 0.66), 0.9))
	# pot de colle : seau à anse (origine = prise de l'anse)
	_pot = Node3D.new()
	_pot.top_level = true
	add_child(_pot)
	var body := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.066, 0.004), Vector2(0.072, 0.12), Vector2(0.078, 0.124), Vector2(0.078, 0.13), Vector2(0.068, 0.13), Vector2(0.066, 0.118)])
	MeshKit.mesh_instance(MeshKit.lathe(body, 24), tin, Vector3(0, -0.2, 0), Vector3.ZERO, _pot)
	MeshKit.mesh_instance(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.066, 0.1)]), 20), white, Vector3(0, -0.2, 0), Vector3.ZERO, _pot)
	var arc := PackedVector3Array()
	for i in 9:
		var a := PI * float(i) / 8.0
		arc.append(Vector3(cos(a) * 0.075, -0.075 + sin(a) * 0.075 * 0.9, 0.0))
	MeshKit.mesh_instance(MeshKit.tube(arc, 0.003, 6), tin, Vector3.ZERO, Vector3.ZERO, _pot)
	# brosse à encoller (origine = prise du manche, soies vers +Y)
	_brush = Node3D.new()
	_brush.top_level = true
	add_child(_brush)
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.026, 0.13, 0.018), 0.008, 2), wood, Vector3(0, 0.0, 0), Vector3.ZERO, _brush)
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.07, 0.03, 0.024), 0.004, 1), tin, Vector3(0, 0.075, 0), Vector3.ZERO, _brush)
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.068, 0.06, 0.02), 0.006, 2), hair, Vector3(0, 0.115, 0), Vector3.ZERO, _brush)


func _show(on: bool) -> void:
	if _pot:
		_pot.visible = on
		_brush.visible = on


func _cancel() -> void:
	_t = -1.0
	if _poster and is_instance_valid(_poster) and not _poster.has_meta("done"):
		_poster.queue_free()
	_poster = null


func use() -> void:
	if not equipped or busy or equip_t < 0.5:
		return
	if count <= 0:
		say("Plus d'affiches : il en reste au Zinc")
		return
	var hit := surface_ahead(REACH + 1.8)
	var surf := classify(hit)
	if hit.is_empty() or (hit["pos"] as Vector3).distance_to(player.global_position + Vector3.UP * 1.2) > REACH:
		say("Approche-toi d'un mur, d'un panneau ou de la colonne Morris")
		return
	if surf not in ["morris", "panneau", "mur", "abribus"]:
		say("Pas ici : un mur, un panneau d'affichage ou la colonne Morris")
		return
	var n: Vector3 = (hit["normal"] as Vector3)
	n.y = 0.0
	if n.length() < 0.3:
		return
	n = n.normalized()
	var p: Vector3 = hit["pos"]
	p.y = clampf(p.y, 1.15, 2.1)
	if surf == "morris":
		# sur le fût : centre de l'affiche sur le cylindre, face vers l'extérieur
		var c := Vector3(Quartier.MORRIS.x, p.y, Quartier.MORRIS.z)
		n = ((p - c) * Vector3(1, 0, 1)).normalized()
		p = c + n * 0.622
		p.y = clampf(p.y, 1.0, 2.3)
	_spot = {"pos": p, "normal": n, "surface": surf}
	_start = player.global_position
	_design = _rng.randi() % DESIGNS.size()
	busy = true
	_t = 0.0


func count_text() -> String:
	return str(count)


func count_pair() -> Array:
	return [str(count), "/ %d" % MAX]


func is_empty() -> bool:
	return count <= 0


func reload_all() -> void:
	count = MAX
	count_changed.emit()


func prompt() -> Array:
	if count <= 0:
		return [["—"], "Plus d'affiches"]
	if busy:
		return [["…"], "Collage en cours : ne bouge pas"]
	var surf := str(_aim_cache.get("surface", ""))
	match surf:
		"morris":
			return [["CLIC GAUCHE"], "Coller sur la colonne Morris (autorisé)"]
		"panneau":
			return [["CLIC GAUCHE"], "Coller sur le panneau d'affichage libre (autorisé)"]
		"mur":
			return [["CLIC GAUCHE"], "Coller sur le mur (interdit : amende)"]
		"abribus":
			return [["CLIC GAUCHE"], "Coller sur l'abribus (interdit : amende)"]
	return [["CLIC GAUCHE"], "Face à un mur ou à un panneau : coller une affiche"]


func step(delta: float) -> void:
	super.step(delta)
	_aim_cd -= delta
	if equipped and not busy and _aim_cd <= 0.0:
		_aim_cd = 0.2
		var hit := surface_ahead(REACH + 1.8)
		_aim_cache = {}
		if not hit.is_empty() and (hit["pos"] as Vector3).distance_to(player.global_position + Vector3.UP * 1.2) <= REACH:
			_aim_cache = {"surface": classify(hit)}
	if _t < 0.0:
		return
	if player.global_position.distance_to(_start) > 0.7:
		say("Collage interrompu")
		_cancel()
		busy = false
		return
	var was := _t
	_t += delta
	if was < T_GLUE and _t >= T_GLUE:
		_poster = _make_poster(_spot, _design)
		AudioLib.play_at(self, "paper_rustle", _spot["pos"], -8.0, 3.0, _rng.randf_range(0.85, 1.0))
	if _poster and is_instance_valid(_poster) and _t < T_PLACE:
		# l'affiche s'applique sur la surface (léger décollement au début)
		var u := ease01((_t - T_GLUE) / (T_PLACE - T_GLUE))
		_poster.global_position = (_spot["pos"] as Vector3) + (_spot["normal"] as Vector3) * (0.004 + 0.06 * (1.0 - u))
	if int(_t * 3.0) != int(was * 3.0) and (_t < T_GLUE or _t > T_PLACE):
		AudioLib.play_at(self, "paper_rustle", _spot["pos"], -18.0, 2.0, _rng.randf_range(1.4, 1.7))
	if _t >= T_DONE:
		_finish()


func _finish() -> void:
	_t = -1.0
	busy = false
	if _poster == null or not is_instance_valid(_poster):
		return
	_poster.global_position = (_spot["pos"] as Vector3) + (_spot["normal"] as Vector3) * 0.004
	_poster.set_meta("done", true)
	_stuck = _stuck.filter(func(o): return is_instance_valid(o))
	_stuck.append(_poster)
	while _stuck.size() > MAX_IN_SCENE:
		(_stuck.pop_front() as Node).queue_free()
	_poster = null
	count -= 1
	count_changed.emit()
	var surf: String = _spot["surface"]
	var legal := surf in ["morris", "panneau"]
	emit_event("poster_stuck", {"pos": _spot["pos"], "surface": surf, "legal": legal})
	if not legal:
		say("Affiche collée… sur un support interdit")


## Affiche posée : papier (légèrement cintré sur la colonne Morris), titre et texte imprimés
func _make_poster(spot: Dictionary, design: int) -> Node3D:
	if _font == null:
		_font = load("res://assets/fonts/InterDisplay-Black.otf")
	var d: Array = DESIGNS[design]
	var root := Node3D.new()
	get_tree().current_scene.add_child(root)
	var n: Vector3 = spot["normal"]
	var x := Vector3.UP.cross(n).normalized()
	root.global_transform = Transform3D(Basis(x, Vector3.UP, n), (spot["pos"] as Vector3) + n * 0.06)
	var morris: bool = spot["surface"] == "morris"
	var bend := 0.021 if morris else 0.0
	# le cintrage suit le fût (flèche de 2 cm sur 32 cm de large)
	var paper := MeshKit.mesh_instance(MeshKit.curved_panel(W, H, bend, 8 if morris else 1, 1), paper_mat(d[0]), Vector3.ZERO, Vector3.ZERO, root)
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var z0 := 0.0015
	var title := _label(str(d[2]), d[1], _fit(str(d[2]), 0.00062), 0.38)
	title.position = Vector3(0, 0.07, z0)
	root.add_child(title)
	var sub := _label(str(d[4]), d[3], _fit(str(d[4]), 0.0003), 0.4)
	sub.position = Vector3(0, -0.16, z0)
	root.add_child(sub)
	return root


## Taille de pixel pour que la plus longue ligne tienne dans la largeur de l'affiche
static func _fit(text: String, px: float) -> float:
	var longest := 1
	for line in text.split("\n"):
		longest = maxi(longest, line.length())
	return minf(px, W * 0.86 / (float(longest) * 64.0 * 0.62))


func _label(text: String, col: Color, px: float, spacing: float) -> Label3D:
	var l := Label3D.new()
	l.font = _font
	l.font_size = 64
	l.pixel_size = px
	l.text = text
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.line_spacing = -64.0 * spacing * 0.3
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var w := ease01(equip_t)
	var k := human.arm_length() / 0.58
	var shl := human.shoulder_world("L")
	var shr := human.shoulder_world("R")
	# gauche : le pot à l'anse, bras le long du corps ; droite : la brosse, coude plié
	var l := hand(shl + bdir(Vector3(-0.04, -0.5, 0.12) * k), bdir(Vector3(0.2, -0.2, 1.0)), bdir(Vector3(1, 0, 0)), 0.95, w)
	var r := hand(shr + bdir(Vector3(-0.04, -0.34, 0.26) * k), bdir(Vector3(0, 0.6, 0.8)), bdir(Vector3(-1, 0, 0)), 0.9, w)
	if _t >= 0.0:
		var p: Vector3 = _spot["pos"]
		var n: Vector3 = _spot["normal"]
		var x := Vector3.UP.cross(n).normalized()
		var u := ease01(_t / 0.25) * (1.0 - ease01((_t - T_DONE + 0.3) / 0.3))
		var sweep := x * sin(_t * 7.0) * 0.12 + Vector3.UP * cos(_t * 3.5) * 0.12
		if _t >= T_GLUE and _t < T_PLACE:
			# pose de l'affiche : la main gauche (anse du pot au poignet) la plaque en haut
			sweep = Vector3.UP * 0.12
			l = hand(p + n * 0.08 - x * 0.15 + Vector3.UP * 0.12, Vector3.UP, -n, 0.2, w)
		r = hand((r["pos"] as Vector3).lerp(p + n * 0.12 + sweep, u), Vector3.UP.lerp(-n, 0.5), -n, 0.85, w)
	if _brush and _brush.visible:
		on_palm(_brush, "R", "thumb", Vector3.ZERO, Vector3(0, 0.03, 0.025))
	if _pot and _pot.visible:
		var pl := human.palm("L")
		var pf: Vector3 = pl["f"]
		_pot.global_transform = Transform3D(Basis(Vector3.UP, human.global_rotation.y), (pl["pos"] as Vector3) + (pl["p"] as Vector3) * 0.02 + pf * 0.03)
	return [r, l]
