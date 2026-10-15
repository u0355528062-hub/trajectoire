class_name KitTool
extends Node3D
## Base des outils du kit de campagne (téléphone, tracts, affiches, mégaphone, bombe de peinture) : même contrat que
## les outils d'origine (attach_to, set_equipped, hide_now, set_aim, use, step, _hand_targets), plus le relâchement du
## clic (release), l'invite contextuelle (prompt) et le compteur affiché dans la barre d'outils (count_text).
## Les événements partent sur le bus de la foule : get_tree().call_group("crowd", "on_event", type, data).

signal message(text: String)
signal count_changed

var human: Human
var player: Player
var equipped := false
var busy := false
var aim_input := false
var equip_t := 0.0
var _rng := RandomNumberGenerator.new()

static var _mats := {}


func _ready() -> void:
	_rng.randomize()


func attach_to(h: Human, p: Player) -> void:
	human = h
	player = p
	h.add_child(self)


func set_equipped(on: bool) -> void:
	if busy and not on:
		return
	equipped = on
	if on:
		_build()


## Rangé d'un coup (changement d'outil, interpellation) : l'action en cours est abandonnée
func hide_now() -> void:
	equipped = false
	equip_t = 0.0
	if busy:
		_cancel()
	busy = false
	aim_input = false
	_show(false)


func set_aim(on: bool) -> void:
	aim_input = on and equipped


## Clic gauche enfoncé / relâché
func use() -> void:
	pass


func release() -> void:
	pass


## Recharge (triche du bac à sable seulement)
func reload_all() -> void:
	pass


func step(delta: float) -> void:
	equip_t = move_toward(equip_t, 1.0 if equipped else 0.0, delta * 3.0)
	_show(equip_t > 0.15)


## [touches, texte] de l'invite en bas de l'écran, ou []
func prompt() -> Array:
	return []


## Pastille de la case d'outil, et grand compteur de la fiche : [valeur, maximum ("" = pas de maximum)]
func count_text() -> String:
	return ""


func count_pair() -> Array:
	return ["", ""]


func is_empty() -> bool:
	return false


func _hand_targets() -> Array:
	return [null, null]


# ------------------------------------------------------------------ à surcharger
func _build() -> void:
	pass


func _show(_on: bool) -> void:
	pass


func _cancel() -> void:
	pass


# ------------------------------------------------------------------ utilitaires
var _crowd: Crowd


## La foule de la scène (null s'il n'y en a pas)
func crowd() -> Crowd:
	if _crowd != null and is_instance_valid(_crowd):
		return _crowd
	_crowd = null
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("crowd"):
			if n is Crowd:
				_crowd = n
				break
	return _crowd


func emit_event(type: String, d: Dictionary) -> void:
	if is_inside_tree():
		get_tree().call_group("crowd", "on_event", type, d)


func say(text: String) -> void:
	message.emit(text)


static func ease01(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Direction exprimée dans le repère du corps (x droite, y haut, z devant) -> monde
func bdir(v: Vector3) -> Vector3:
	return Basis(Vector3.UP, human.global_rotation.y) * Vector3(v.x, v.y, -v.z)


func body_fwd() -> Vector3:
	return Basis(Vector3.UP, human.global_rotation.y) * Vector3(0, 0, -1)


func cam_xf() -> Transform3D:
	return player.camera.global_transform if player and player.camera else global_transform


func cam_fwd() -> Vector3:
	return -cam_xf().basis.z


## Main pour le dictionnaire de Human.hand_provider
func hand(pos: Vector3, f: Vector3, p: Vector3, curl: float, w: float) -> Dictionary:
	return {"pos": pos, "f": f.normalized(), "p": p.normalized(), "curl": curl, "w": w}


## Pose un objet sur la vraie paume : axe +Y de l'objet le long des doigts (f) ou du pouce, face +Z côté `face`
func on_palm(obj: Node3D, side := "R", along := "f", face := Vector3.ZERO, off := Vector3.ZERO) -> void:
	if obj == null or human == null:
		return
	var pr := human.palm(side)
	var up: Vector3 = pr[along]
	var fz: Vector3 = face if face != Vector3.ZERO else -(pr["p"] as Vector3)
	var b := Props.basis_up(up, fz)
	obj.global_transform = Transform3D(b, (pr["pos"] as Vector3) + (pr["p"] as Vector3) * off.z + up * off.y + (pr["thumb"] as Vector3) * off.x)


## Surface devant la caméra (rayon depuis l'œil) : {pos, normal, collider} ou {} si rien à portée
func surface_ahead(reach: float) -> Dictionary:
	if player == null or not is_inside_tree():
		return {}
	var x := cam_xf()
	var from := x.origin
	var fwd := -x.basis.z
	# en vue à la 3e personne la caméra est derrière : on part du niveau de la tête du joueur
	var head := player.global_position + Vector3.UP * 1.55
	var along := (head - from).dot(fwd)
	if along > 0.0:
		from += fwd * along
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * reach, 1 | 32)
	q.exclude = [player.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	return {"pos": r["position"], "normal": r["normal"], "collider": r["collider"]}


## Nature d'une surface pour l'affichage et les tags : morris, panneau (affichage libre), abribus, vehicule, sol, mur
static func classify(hit: Dictionary) -> String:
	if hit.is_empty():
		return ""
	var n: Vector3 = hit["normal"]
	var node: Node = hit.get("collider")
	var pos: Vector3 = hit["pos"]
	while node != null:
		if node.is_in_group("affichage_libre") or node.is_in_group("poster_boards"):
			return "panneau"
		if node.name.begins_with("ColonneMorris"):
			return "morris"
		if node is BusStop or node.is_in_group("ad_panels"):
			return "abribus"
		if node.is_in_group("vehicles") or node.is_in_group("civil_cars"):
			return "vehicule"
		node = node.get_parent()
	if Vector2(pos.x - Quartier.MORRIS.x, pos.z - Quartier.MORRIS.z).length() < 0.95 and pos.y > 0.3 and pos.y < 2.8:
		return "morris"
	if n.y > 0.7:
		return "sol"
	if absf(n.y) < 0.35:
		return "mur"
	return ""


static func mat(key: String, maker: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = maker.call()
	return _mats[key]


static func paper_mat(col: Color) -> Material:
	return mat("paper" + str(col), func() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.92
		m.metallic_specular = 0.2
		return m)
