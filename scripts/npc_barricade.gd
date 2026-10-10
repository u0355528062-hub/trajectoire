class_name NpcBarricade
extends RefCounted
## Barricade : un manifestant déterminé va chercher une barrière libre, la porte devant lui et la pose en
## travers de la chaussée, entre la foule et la police. Gazé, frappé ou interpellé en route, il la lâche
## (la barrière s'en aperçoit elle-même, voir Barrier._physics_process).

const TIMEOUT := 50.0


static func start(n: Npc, b: Barrier, slot: Vector3, yaw: float, slot_i: int) -> void:
	n._drop_item()
	n.state = "barricade"
	n.state_t = 0.0
	n.sub = "go"
	n.sub_t = 0.0
	n.data = {"b": b, "slot": slot, "yaw": yaw, "i": slot_i}
	n.go(_grab_spot(n, b), false, 0.3)
	if n._rng.randf() < 0.6:
		n.say_cat("allez", true)


## Où se placer pour attraper la barrière : contre son panneau, du côté où l'on arrive
static func _grab_spot(n: Npc, b: Barrier) -> Vector3:
	var nz := b.global_basis.z
	nz.y = 0.0
	nz = nz.normalized() if nz.length() > 0.1 else Vector3.FORWARD
	var side := 1.0 if (n.global_position - b.global_position).dot(nz) >= 0.0 else -1.0
	var p := b.global_position + nz * side * 0.7
	return n.crowd.clamp_area(p) if n.crowd else p


## Où se tenir pour poser la barrière : juste derrière sa place, côté foule
static func _stand_spot(slot: Vector3) -> Vector3:
	return slot + Vector3(-0.75, 0.0, 0.0)


static func _abort(n: Npc) -> void:
	var b := n.dnode("b") as Barrier
	if b != null and b.carrier == n:
		b.drop_carry()
	n.go_home()


static func think(n: Npc, delta: float) -> void:
	n.sub_t += delta
	var b := n.dnode("b") as Barrier
	if b == null or n.state_t > TIMEOUT:
		_abort(n)
		return
	var slot: Vector3 = n.data["slot"]
	match n.sub:
		"go":
			if b.is_busy() or b.barricade:
				n.go_home()
				return
			var gs := _grab_spot(n, b)
			if Vector2(n.global_position.x - gs.x, n.global_position.z - gs.z).length() < 0.6 or (not n.has_goal and n.sub_t > 1.0):
				n.stop_move()
				n.face(b.global_position)
				n.set_act("pick", {"target": n._wb(b.global_position + Vector3.UP * 0.55)}, 4.0)
				n.sub = "grab"
				n.sub_t = 0.0
			elif not n.has_goal or n.goal.distance_to(gs) > 1.0:
				n.go(gs, false, 0.3)
		"grab":
			n.face(b.global_position)
			if n.sub_t > 0.8:
				if not b.begin_carry(n):
					n.go_home()
					return
				n.sub = "carry"
				n.sub_t = 0.0
				n.go(_stand_spot(slot), false, 0.25)
				n.speed_want *= 0.8
		"carry":
			n.set_act("carry", {"w": 0.9}, 3.0)
			b.carry_to(_carried(n))
			var st := _stand_spot(slot)
			if Vector2(n.global_position.x - st.x, n.global_position.z - st.z).length() < 0.45 or (not n.has_goal and n.sub_t > 1.0):
				n.stop_move()
				n.face(slot + Vector3(4.0, 0.0, 0.0))
				n.sub = "place"
				n.sub_t = 0.0
			elif not n.has_goal:
				n.go(st, false, 0.25)
				n.speed_want *= 0.8
		"place":
			n.face(slot + Vector3(4.0, 0.0, 0.0))
			b.carry_to(_carried(n))
			if n.sub_t > 0.6:
				b.set_down_at(slot, float(n.data["yaw"]))
				if n.crowd:
					n.crowd.on_barricade_set(b, int(n.data["i"]), n)
				n.go_home()
				n.react("fist", 2.0, slot + Vector3(6.0, 1.4, 0.0), {"voice": "ouais", "voice_p": 0.6, "prm": {"k": 1.0}})


## Barrière tenue à deux mains par le haut, devant soi, le bas frôlant le sol
static func _carried(n: Npc) -> Transform3D:
	var fwd := n.forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var base := n.global_position + fwd * 0.5 + Vector3.UP * 0.04
	return Transform3D(Basis(right, Vector3.UP, right.cross(Vector3.UP)), base)
