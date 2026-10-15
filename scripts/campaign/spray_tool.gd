class_name SprayTool
extends KitTool
## Bombe de peinture : maintenir le clic gauche face à un mur, une vitrine, la chaussée… le slogan s'écrit lettre
## par lettre (relâcher arrête : le tag reste inachevé, sans compter). C'est du vandalisme : l'opinion n'aime pas,
## la police non plus. Événement (tag terminé) : spray_tag {"pos", "text", "surface"}.

const SLOGANS := ["LA HAUSSE TUE", "RETRAIT DE LA LOI", "BAISSEZ LES PRIX", "ON LÂCHE RIEN", "STABILITÉ = MISÈRE", "PAYE TON PLEIN"]
const COLORS := [Color(0.85, 0.08, 0.1), Color(0.05, 0.05, 0.06)]
const MAX := 8                    # tags par bombe
const REACH := 1.6
const PAINT_T := 3.4
const MAX_IN_SCENE := 24

static var _font: FontFile
static var _tags: Array = []

var count := MAX
var _can: Node3D
var _color := COLORS[0]
var _slogan := 0
var _t := -1.0
var _spot := {}
var _label: Label3D
var _snd_t := 0.0
var _aim_cache := ""
var _aim_cd := 0.0


func _build() -> void:
	if _can != null:
		return
	_color = COLORS[_rng.randi() % COLORS.size()]
	_slogan = _rng.randi() % SLOGANS.size()
	var paint := mat("spray" + str(_color), func() -> Material: return MeshKit.std_mat(_color, 0.3, 0.55, 0.6))
	var alu := mat("spray_alu", func() -> Material: return MeshKit.std_mat(Color(0.78, 0.8, 0.82), 0.25, 0.9))
	var cap := mat("spray_cap", func() -> Material: return MeshKit.std_mat(Color(0.92, 0.92, 0.9), 0.45))
	# corps (origine = milieu de la bombe, axe +Y, diffuseur côté +Z)
	_can = Node3D.new()
	_can.top_level = true
	add_child(_can)
	var body := PackedVector2Array([Vector2(0.0, -0.085), Vector2(0.03, -0.085), Vector2(0.033, -0.08), Vector2(0.033, 0.06),
		Vector2(0.03, 0.072), Vector2(0.02, 0.082), Vector2(0.012, 0.086), Vector2(0.0, 0.086)])
	MeshKit.mesh_instance(MeshKit.lathe(body, 20), paint, Vector3.ZERO, Vector3.ZERO, _can)
	MeshKit.mesh_instance(MeshKit.lathe(PackedVector2Array([Vector2(0.0332, 0.035), Vector2(0.0334, 0.036), Vector2(0.0334, 0.055), Vector2(0.0332, 0.056)]), 20), alu, Vector3.ZERO, Vector3.ZERO, _can)
	MeshKit.mesh_instance(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.086), Vector2(0.009, 0.086), Vector2(0.009, 0.1), Vector2(0.0, 0.1)]), 12), cap, Vector3.ZERO, Vector3.ZERO, _can)
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.006, 0.006, 0.008), 0.002, 1), cap, Vector3(0, 0.094, 0.009), Vector3.ZERO, _can)


func _show(on: bool) -> void:
	if _can:
		_can.visible = on


func _cancel() -> void:
	_stop_paint()


func use() -> void:
	if not equipped or busy or equip_t < 0.5:
		return
	if count <= 0:
		say("La bombe est vide")
		return
	var hit := surface_ahead(REACH + 1.8)
	var surf := classify(hit)
	if hit.is_empty() or (hit["pos"] as Vector3).distance_to(player.global_position + Vector3.UP * 1.0) > REACH + 0.4 or surf == "":
		say("Approche-toi d'un mur ou d'une surface à taguer")
		return
	var n: Vector3 = hit["normal"]
	var up := Vector3.UP
	if n.y > 0.7:
		# chaussée : le texte se lit depuis le joueur
		up = (player.global_position - (hit["pos"] as Vector3)) * Vector3(-1, 0, -1)
		up = up.normalized() if up.length() > 0.1 else -body_fwd()
	_spot = {"pos": (hit["pos"] as Vector3) + n * 0.006, "normal": n, "up": up, "surface": surf, "text": SLOGANS[_slogan]}
	_label = _make_label(_spot, _color)
	busy = true
	_t = 0.0
	_snd_t = 0.0


func release() -> void:
	if _t >= 0.0 and _t < PAINT_T:
		say("Tag inachevé")
		_stop_paint()


func _stop_paint() -> void:
	if _label and is_instance_valid(_label):
		if _label.text == "":
			_label.queue_free()
		else:
			_keep(_label)
	_label = null
	_t = -1.0
	busy = false
	_forced = false


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
		return [["—"], "Bombe vide"]
	if _t >= 0.0:
		return [["CLIC GAUCHE"], "Maintenir : « %s »" % _spot["text"]]
	if _aim_cache != "":
		return [["CLIC GAUCHE"], "Maintenir pour taguer « %s »" % SLOGANS[_slogan]]
	return [["CLIC GAUCHE"], "Face à un mur : taguer (vandalisme)"]


func step(delta: float) -> void:
	super.step(delta)
	_aim_cd -= delta
	if equipped and _t < 0.0 and _aim_cd <= 0.0:
		_aim_cd = 0.25
		var hit := surface_ahead(REACH + 1.8)
		_aim_cache = classify(hit) if not hit.is_empty() and (hit["pos"] as Vector3).distance_to(player.global_position + Vector3.UP * 1.0) <= REACH + 0.4 else ""
	if _t < 0.0:
		return
	if not _forced and not Input.is_action_pressed("fire"):
		release()
		return
	if player.global_position.distance_to(_spot["pos"]) > REACH + 1.2:
		release()
		return
	_t += delta
	var full: String = _spot["text"]
	if _label and is_instance_valid(_label):
		_label.text = full.substr(0, clampi(int(float(full.length()) * _t / PAINT_T) + 1, 1, full.length()))
	_snd_t -= delta
	if _snd_t <= 0.0:
		_snd_t = 0.5
		AudioLib.play_at(self, "pepper_spray", _spot["pos"], -14.0, 4.0, _rng.randf_range(1.25, 1.45))
	if _t >= PAINT_T:
		_label.text = full
		_keep(_label)
		_label = null
		_t = -1.0
		busy = false
		_forced = false
		count -= 1
		_slogan = (_slogan + 1) % SLOGANS.size()
		count_changed.emit()
		emit_event("spray_tag", {"pos": _spot["pos"], "text": full, "surface": _spot["surface"]})


## Tests et scripts : peindre sans tenir le clic
var _forced := false


func paint_now() -> void:
	_forced = true
	use()


static func _keep(l: Label3D) -> void:
	_tags = _tags.filter(func(o): return is_instance_valid(o))
	_tags.append(l)
	while _tags.size() > MAX_IN_SCENE:
		(_tags.pop_front() as Node).queue_free()


func _make_label(spot: Dictionary, col: Color) -> Label3D:
	if _font == null:
		_font = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	var lab := Label3D.new()
	lab.font = _font
	lab.font_size = 96
	var txt_len := float((spot["text"] as String).length())
	lab.pixel_size = minf(0.0045 if (spot["normal"] as Vector3).y > 0.7 else 0.0032, 1.5 / maxf(txt_len * 58.0, 1.0))
	lab.modulate = col
	lab.outline_size = 0
	lab.shaded = true
	lab.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	lab.double_sided = false
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.text = ""
	var z: Vector3 = (spot["normal"] as Vector3).normalized()
	var y: Vector3 = (spot["up"] as Vector3).normalized()
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	get_tree().current_scene.add_child(lab)
	lab.global_transform = Transform3D(Basis(x, y, z), spot["pos"])
	return lab


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var w := ease01(equip_t)
	var k := human.arm_length() / 0.58
	var shr := human.shoulder_world("R")
	var r := hand(shr + bdir(Vector3(-0.02, -0.34, 0.27) * k), bdir(Vector3(0, 0.25, 1)), bdir(Vector3(-1, 0, 0)), 0.85, w)
	if _t >= 0.0:
		# bras tendu, la main balaie la surface en suivant les lettres
		var p: Vector3 = _spot["pos"]
		var n: Vector3 = _spot["normal"]
		var y: Vector3 = (_spot["up"] as Vector3)
		var x := y.cross(n).normalized()
		var prog := clampf(_t / PAINT_T, 0.0, 1.0)
		var tgt := p + n * 0.3 + x * (prog - 0.5) * 0.9 + y * sin(_t * 9.0) * 0.06
		if n.y > 0.7:
			tgt = p + Vector3.UP * 0.45 + x * (prog - 0.5) * 0.9
		var reach := shr + (tgt - shr).limit_length(0.55 * k)
		var u := ease01(_t / 0.25)
		r = hand((r["pos"] as Vector3).lerp(reach, u), (tgt - shr).normalized() + Vector3.UP * 0.4, -x, 0.85, w)
	if _can and _can.visible:
		var pr := human.palm("R")
		var th: Vector3 = pr["thumb"]
		_can.global_transform = Transform3D(Props.basis_up(th, pr["f"]), (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.035)
	return [r, null]
