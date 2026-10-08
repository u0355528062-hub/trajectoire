class_name NpcCare
extends RefCounted
## Entraide : un médic (ou, à défaut, un voisin courageux) secourt un blessé : manifestant à terre, aspergé de gaz
## poivre, gazé qui tousse... et le joueur. Le secouriste accourt, s'agenouille, soigne puis retourne à son poste.

const TREAT_TIME := 3.6          # durée des soins d'un médic
const HELP_TIME := 2.4           # durée d'un coup de main d'un simple manifestant


## Quelqu'un a-t-il besoin d'aide en ce moment ?
static func needs_aid(a: Node3D) -> bool:
	if a is Player:
		var p := a as Player
		return p.arrest_phase == "" and (p.pepper_level > 0.35 or p.gas_level > 0.45 or p.down_t > 0.8)
	if a is Npc:
		var n := a as Npc
		if n.data.get("aided", false):
			return false
		match n.state:
			"hit":
				return n.sub == "down" and n.human.fall > 0.6
			"sprayed":
				return n.state_t > 0.8
			"gassed":
				return not n.has_goal and n.gas_level < 0.3 and n.state_t > 3.0 and n.sub == "tough"
	return false


## Le secouriste part vers le blessé
static func start(h: Npc, patient: Node3D, kind: String) -> void:
	h._drop_item()
	h.state = "aid"
	h.state_t = 0.0
	h.sub = "run"
	h.sub_t = 0.0
	h.data = {"patient": patient, "kind": kind, "side": 1.0 if h._rng.randf() < 0.5 else -1.0}
	h.set_act("fist", {"k": 0.0}, 5.0)
	if kind == "medic":
		h.say_cat("help", true)
	elif h._rng.randf() < 0.7:
		h.say_cat("help", true)
	h.go(_spot(h, patient), true, 0.4)
	if patient is Player:
		(patient as Player).message.emit("Un médic accourt !" if kind == "medic" else "Quelqu'un vient t'aider")


## Place du secouriste près du blessé : à son côté, côté d'où il vient
static func _spot(h: Npc, patient: Node3D) -> Vector3:
	var pp := patient.global_position
	var side := Vector3.RIGHT
	if patient is Npc:
		side = (patient as Npc).global_basis.x
	elif patient is Player:
		side = Vector3.RIGHT
	var s: float = h.data.get("side", 1.0)
	var spot := pp + side * 0.85 * s
	if h.crowd:
		spot = h.crowd.clamp_area(spot)
	return spot


static func finish(h: Npc, healed: bool) -> void:
	var patient: Node3D = h.dnode("patient")
	if h.crowd:
		h.crowd.aid_pairs.erase(patient)
	h.human.kneel = 0.0
	h.human.crouch = 0.0
	if healed and h._rng.randf() < 0.6:
		h.say_cat("calm", false, -2.0)
	h.go_home()


static func think(h: Npc, delta: float) -> void:
	var patient: Node3D = h.dnode("patient")
	var kind: String = h.data.get("kind", "help")
	h.sub_t += delta
	if patient == null or not is_instance_valid(patient) or h.state_t > 40.0:
		finish(h, false)
		return
	var pp := patient.global_position
	var lie := pp + Vector3.UP * 0.3
	match h.sub:
		"run":
			var spot := _spot(h, patient)
			var d := Vector2(spot.x - h.global_position.x, spot.z - h.global_position.z).length()
			h.look(pp + Vector3.UP * 1.0, 1.0)
			if not needs_aid(patient) and h.sub_t > 1.5:
				# quelqu'un d'autre s'en est occupé, ou il va mieux : on laisse
				finish(h, false)
				return
			if d > 0.7:
				if not h.has_goal or h.goal.distance_to(spot) > 0.9:
					h.go(spot, d > 3.0, 0.35)
				h.set_act("fist", {"k": 0.0}, 5.0)
			else:
				h.stop_move()
				h.sub = "treat"
				h.sub_t = 0.0
		"treat":
			h.stop_move()
			h.face(pp)
			h.look(pp + Vector3.UP * 0.6, 1.0)
			# le blessé s'est relevé et est parti de lui-même : inutile d'insister
			if h.sub_t > 0.8 and (not needs_aid(patient) or pp.distance_to(h.global_position) > 2.6):
				finish(h, false)
				return
			var down: bool = patient is Npc and (patient as Npc).state == "hit" or patient is Player and (patient as Player).down_t > 0.5
			h.human.kneel = move_toward(h.human.kneel, 1.0 if down else 0.0, delta * 1.8)
			h.human.crouch = move_toward(h.human.crouch, 0.0 if down else 0.35, delta * 2.0)
			var sprayed := patient is Npc and (patient as Npc).state == "sprayed" or patient is Player and (patient as Player).pepper_level > 0.35
			if sprayed and kind == "medic":
				# on rince les yeux au sérum
				var to_face := (pp + Vector3.UP * 1.45 - h.head_pos())
				h.set_act("give", {"dir": h._wbd(Vector3(to_face.x, 0.0, to_face.z)).normalized()}, 5.0)
			else:
				h.set_act("treat", {"target": h._wb(lie)}, 5.0)
			if patient is Player:
				(patient as Player).receive_aid(delta * (1.4 if kind == "medic" else 0.7))
			var dur := TREAT_TIME if kind == "medic" else HELP_TIME
			if h.sub_t > dur:
				if patient is Npc:
					(patient as Npc).on_aid(h)
				h.sub = "done"
				h.sub_t = 0.0
				if kind == "medic":
					h.say_cat("calm", true)
				else:
					h.say_cat("help", true)
		"done":
			h.human.kneel = move_toward(h.human.kneel, 0.0, delta * 1.8)
			h.human.crouch = move_toward(h.human.crouch, 0.0, delta * 2.0)
			h.set_act("idle", {}, 3.0)
			if h.sub_t > 0.9:
				finish(h, true)
