class_name TractTool
extends KitTool
## Tracts : une pile de feuilles A5 dans la main gauche ; E (ou clic gauche) devant un passant lui en tend une.
## Beaucoup refusent, certains s'arrêtent pour discuter, d'autres prennent… et jettent plus loin. La pile est
## limitée : on en reprend au QG (le Zinc de Jo). Événements : tract_given, tract_refused {"pos", "by": "player"}.

const MAX := 40
const OFFER_T := 1.15             # bras tendu, puis retour
const DECIDE_T := 0.45
const REFILL_R := 3.5

var count := MAX
var _t := -1.0
var _who: Actor
var _decided := false
var _stack: Node3D
var _sheet: Node3D
var _refill_cd := 0.0


func _build() -> void:
	if _stack == null:
		_stack = _make_stack(0.03)
		add_child(_stack)
		_sheet = _make_stack(0.0012)
		add_child(_sheet)


static func _make_stack(thick: float) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	var white := paper_mat(Color(0.95, 0.94, 0.9))
	var red := paper_mat(Color(0.82, 0.12, 0.1))
	var ink := paper_mat(Color(0.12, 0.12, 0.13))
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.148, 0.21, thick), minf(0.001, thick * 0.4), 1), white, Vector3(0, 0, thick * 0.5), Vector3.ZERO, root)
	# recto imprimé : bandeau rouge, titre, lignes de texte
	var z := thick + 0.0004
	MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.14, 0.05, 0.0006), 0.0002, 1), red, Vector3(0, 0.072, z), Vector3.ZERO, root)
	for i in 6:
		MeshKit.mesh_instance(MeshKit.rbox(Vector3(0.11 if i % 3 != 2 else 0.07, 0.006, 0.0005), 0.0002, 1), ink, Vector3(-0.01 if i % 3 == 2 else 0.0, 0.02 - i * 0.02, z), Vector3.ZERO, root)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if c.get_index() > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


func _show(on: bool) -> void:
	if _stack:
		_stack.visible = on and count > 0
	if _sheet:
		_sheet.visible = on and _t >= 0.0 and _t < DECIDE_T + 0.1 and count > 0


func _cancel() -> void:
	_t = -1.0
	_who = null


## Clic gauche : tendre un tract à la personne devant soi
func use() -> void:
	if not equipped or busy or equip_t < 0.5:
		return
	var tgt: Actor = player.talk.target if player and player.talk else null
	if tgt == null or not (tgt is Passerby or tgt is Npc):
		say("Approche-toi d'un passant pour lui tendre un tract")
		return
	offer(tgt)


## Tendre un tract à `a` (passant ou manifestant)
func offer(a: Actor) -> void:
	if busy or a == null or not is_instance_valid(a):
		return
	if count <= 0:
		say("Plus de tracts : il en reste au Zinc")
		return
	busy = true
	_t = 0.0
	_who = a
	_decided = false


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
		return [["—"], "Plus de tracts : il en reste au Zinc (QG)"]
	if player and player.talk and player.talk.target != null and (player.talk.target is Passerby or player.talk.target is Npc):
		return [["E"], "Tendre un tract"]
	return [["E"], "Approche-toi d'un passant"]


func step(delta: float) -> void:
	super.step(delta)
	# réassort au QG : la pile du comptoir du Zinc (ou une pile posée dans le décor)
	_refill_cd -= delta
	if count < MAX and _refill_cd <= 0.0 and player:
		_refill_cd = 0.5
		if _near_refill():
			count = MAX
			say("Tu reprends une pile de tracts")
			count_changed.emit()
	if _t < 0.0:
		return
	_t += delta
	if not _decided and _t >= DECIDE_T:
		_decided = true
		_decide()
	if _t >= OFFER_T:
		_t = -1.0
		_who = null
		busy = false


func _near_refill() -> bool:
	var me := player.global_position
	for n in get_tree().get_nodes_in_group("tract_stacks"):
		if n is Node3D and (n as Node3D).global_position.distance_to(me) < REFILL_R:
			return true
	return Quartier.SPOTS.has("bar_qg") and Vector2(me.x - Quartier.spot("bar_qg").x, me.z - Quartier.spot("bar_qg").z).length() < REFILL_R


func _decide() -> void:
	var a := _who
	if a == null or not is_instance_valid(a):
		return
	var pos := a.global_position
	var r := ""
	if a is Passerby:
		var op := Campaign.stat("opinion") if Campaign.active else 30.0
		r = (a as Passerby).offer_tract(player.global_position, op)
	elif a is Npc:
		r = (a as Npc).offer_tract(player.global_position)
	var who := ("Passante" if a.female else "Passant") if a is Passerby else ("Manifestante" if a.female else "Manifestant")
	AudioLib.play_at(self, "paper_rustle", pos + Vector3.UP * 1.1, -10.0, 3.0, _rng.randf_range(0.95, 1.1))
	match r:
		"take", "talk":
			count -= 1
			var lines: Array = TalkInteract.TRACT_TALK_LINES if r == "talk" else TalkInteract.TRACT_TAKE_LINES
			say("%s : « %s »" % [who, lines[_rng.randi() % lines.size()]])
			emit_event("tract_given", {"pos": pos, "by": "player"})
			if r == "talk":
				emit_event("talk", {"who": "passant", "node": a})
			count_changed.emit()
		"refuse":
			say("%s : « %s »" % [who, TalkInteract.TRACT_REFUSE_LINES[_rng.randi() % TalkInteract.TRACT_REFUSE_LINES.size()]])
			emit_event("tract_refused", {"pos": pos, "by": "player"})
		"already":
			say("%s : « %s »" % [who, "Déjà eu, merci !" if a is Npc else "On m'en a déjà donné un."])
		_:
			emit_event("tract_refused", {"pos": pos, "by": "player"})


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var w := ease01(equip_t)
	var k := human.arm_length() / 0.58
	var shl := human.shoulder_world("L")
	var shr := human.shoulder_world("R")
	# main gauche : la pile tenue devant, à hauteur de taille
	var l := hand(shl + bdir(Vector3(0.1, -0.36, 0.26) * k), bdir(Vector3(0.35, 0.1, 1.0)), Vector3.UP, 0.75, w)
	var r: Variant = null
	if _t >= 0.0:
		# main droite : prend une feuille sur la pile et la tend vers la personne
		var dir := body_fwd()
		if _who != null and is_instance_valid(_who):
			var to := (_who.global_position - shr) * Vector3(1, 0, 1)
			if to.length() > 0.1:
				dir = to.normalized()
		var out := shr + dir * 0.5 * k + Vector3(0, -0.18, 0)
		var rest := shr + bdir(Vector3(-0.05, -0.36, 0.28) * k)
		var u := ease01(_t / DECIDE_T) * (1.0 - ease01((_t - DECIDE_T - 0.25) / (OFFER_T - DECIDE_T - 0.25)))
		r = hand(rest.lerp(out, u), dir + Vector3.UP * 0.2, Vector3.DOWN.lerp(-bdir(Vector3.RIGHT), 0.5), 0.55, w * ease01(_t / 0.15) * (1.0 - ease01((_t - OFFER_T + 0.15) / 0.15)))
	if _stack and _stack.visible:
		on_palm(_stack, "L", "f", human.palm("L")["p"], Vector3(0, 0.04, 0.012))
	if _sheet and _sheet.visible:
		on_palm(_sheet, "R", "f", Vector3.UP, Vector3(0, 0.05, 0.008))
	return [r, l]
