class_name NpcLoot
extends RefCounted
## Saccage d'une boutique : un manifestant s'en prend à la vitrine (coups de pied, pavés) jusqu'à ce qu'elle
## cède, puis entre avec les autres, renverse les meubles un par un et ressort parfois les bras chargés.
## Sous-états : go → smash | stone_pick → stone_throw → enter → pick → hit → exit → away.

const MAX_ITEMS := 3


static func start(n: Npc, shop: Shop) -> void:
	if n.busy() or shop == null or not is_instance_valid(shop):
		return
	n._drop_item()
	n.state = "loot"
	n.state_t = 0.0
	n.sub = "go"
	n.sub_t = 0.0
	var side := n._rng.randf_range(-1.0, 1.0)
	var style := "kick" if n._rng.randf() < 0.7 else "stone"
	n.data = {"shop": shop, "side": side, "style": style, "hits": 0, "smashed": 0}
	var dest := shop.front_point(side)
	if style == "stone" and not shop.is_open():
		dest = shop.front_point(side) + _out(shop) * n._rng.randf_range(3.2, 4.5)
	n.go(dest, true, 0.3)


static func _out(shop: Shop) -> Vector3:
	var o := shop.global_basis.z
	o.y = 0.0
	return o.normalized()


## Abandonne (CRS, gaz...) : lâche ce qu'il porte et sort de la boutique s'il y est
static func abort(n: Npc) -> void:
	drop_box(n)
	n.go_home()


static func think(n: Npc, delta: float) -> void:
	n.sub_t += delta
	var shop: Shop = n.dnode("shop") as Shop
	if shop == null or n.state_t > 75.0:
		_leave(n, shop)
		return
	var crowd := n.crowd
	# les CRS chargent : on file (dehors, la panique ordinaire ; dedans, d'abord sortir)
	if crowd and crowd.police and crowd.police.stage >= 1:
		var c: Cop = crowd.police.nearest_cop(n.global_position, 7.0)
		if c != null and c.state in ["charge", "strike", "arrest"] and n.bold < 0.95:
			if n.in_shop != null:
				if n.sub not in ["exit", "away"]:
					_to_exit(n, shop, true)
			else:
				drop_box(n)
				n.panic(c.global_position, 1.0)
				return
	var pane_c := shop.pane.global_position if is_instance_valid(shop.pane) else shop.global_position + Vector3.UP * 1.6
	match n.sub:
		"go":
			n.look(pane_c, 0.8)
			if shop.is_open() and n.data["style"] == "stone":
				n.data["style"] = "kick"
				n.go(shop.front_point(float(n.data["side"])), true, 0.3)
			if not n.has_goal or n.sub_t > 14.0:
				n.stop_move()
				if shop.is_open():
					_enter(n, shop)
				else:
					n.face(pane_c)
					n.sub = "smash" if n.data["style"] == "kick" else "stone_pick"
					n.sub_t = -n._rng.randf_range(0.1, 0.6)
		"smash":
			if shop.is_open():
				_enter(n, shop)
				return
			n.face(pane_c)
			n.look(pane_c, 1.0)
			n.set_act(n._idle_pose, {}, 2.0)
			if n.sub_t > 0.0 and n.human.kick_t < 0.0 and absf(wrapf(n._yaw_to(pane_c) - n.yaw, -PI, PI)) < 0.4:
				n.human.start_kick()
				n.sub_t = -n._rng.randf_range(0.9, 2.2)
				if n._rng.randf() < 0.35:
					n.say_cat("allez" if n._rng.randf() < 0.5 else "ouais", true)
			if n.state_t > 50.0:
				_leave(n, shop)
		"stone_pick":
			if shop.is_open():
				n.go(shop.front_point(float(n.data["side"])), true, 0.3)
				n.sub = "go"
				return
			if n.sub_t < 0.0:
				return
			n.face(pane_c)
			n.human.crouch = lerpf(n.human.crouch, 0.8, minf(1.0, delta * 5.0))
			n.human.lean_extra = lerpf(n.human.lean_extra, 0.25, minf(1.0, delta * 5.0))
			n.set_act("pick", {"target": Vector3(0.18, 0.05, 0.45)}, 3.0)
			if n.sub_t > 0.75:
				n.stone_vis.visible = true
				n.sub = "stone_throw"
				n.sub_t = 0.0
		"stone_throw":
			n.human.crouch = lerpf(n.human.crouch, 0.0, minf(1.0, delta * 5.0))
			n.human.lean_extra = lerpf(n.human.lean_extra, 0.0, minf(1.0, delta * 5.0))
			if shop.is_open():
				n.stone_vis.visible = false
				n.go(shop.front_point(float(n.data["side"])), true, 0.3)
				n.sub = "go"
				return
			var tp := pane_c
			n.face(tp)
			n.look(tp, 1.0)
			var dir := n._wbd(tp - n.human.shoulder_world("R")).normalized()
			if n.sub_t < 0.45:
				n.set_act("stone", {}, 4.0)
			else:
				n.set_act("throw", {"dir": dir}, 8.0)
				if n.act_t > 0.48 and n.stone_vis.visible:
					n._throw_stone(tp)
					n.data["hits"] = int(n.data["hits"]) + 1
			if n.sub_t > 1.6:
				n.sub = "stone_pick"
				n.sub_t = -n._rng.randf_range(1.0, 2.2)
				if int(n.data["hits"]) >= 7 and n._rng.randf() < 0.4:
					n.data["style"] = "kick"
					n.go(shop.front_point(float(n.data["side"])), true, 0.3)
					n.sub = "go"
		"enter":
			n.look(n.goal + Vector3.UP * 1.0, 0.6)
			if not n.has_goal or n.sub_t > 8.0:
				_pick(n, shop)
		"pick":
			var it: ShopItem = n.dnode("item") as ShopItem
			if it == null or it.smashed:
				_pick(n, shop)
				return
			var ip := it.global_position + Vector3.UP * minf(it.size.y * 0.5, 0.7)
			n.look(ip, 0.8)
			if not n.has_goal or n.sub_t > 7.0:
				n.stop_move()
				n.face(ip)
				n.sub = "hit"
				n.sub_t = -n._rng.randf_range(0.1, 0.5)
		"hit":
			var it2: ShopItem = n.dnode("item") as ShopItem
			if it2 == null or it2.smashed:
				n.data["smashed"] = int(n.data["smashed"]) + 1
				# certains ressortent les bras chargés, d'autres continuent à tout casser
				if n.loot_box == null and n._rng.randf() < 0.45:
					grab_box(n, it2)
					_to_exit(n, shop, false)
				elif int(n.data["smashed"]) >= MAX_ITEMS or not shop.has_loot():
					_to_exit(n, shop, false)
				else:
					if n._rng.randf() < 0.4:
						n.say_cat("ouais", true)
					_pick(n, shop)
				return
			var ip2 := it2.global_position + Vector3.UP * minf(it2.size.y * 0.5, 0.7)
			n.face(ip2)
			n.look(ip2, 1.0)
			n.set_act(n._idle_pose, {}, 2.0)
			if n.sub_t > 0.0 and n.human.kick_t < 0.0 and absf(wrapf(n._yaw_to(ip2) - n.yaw, -PI, PI)) < 0.45:
				n.human.start_kick()
				n.sub_t = -n._rng.randf_range(0.8, 1.6)
			if n.sub_t > 6.0:
				_pick(n, shop)
		"exit":
			if n.loot_box != null:
				n.set_act("carry", {"w": 0.34}, 3.0)
			if not n.has_goal or n.sub_t > 9.0:
				n.in_shop = null
				if n.loot_box != null:
					# il s'éloigne avec son butin, à l'opposé de la police
					var away := n.global_position + Vector3(-n._rng.randf_range(8.0, 14.0), 0, 0) + _out(shop) * n._rng.randf_range(2.0, 5.0)
					n.go(crowd.clamp_area(away) if crowd else away, false, 0.6)
					n.sub = "away"
					n.sub_t = 0.0
					if n._rng.randf() < 0.5:
						n.say_cat("ouais", true)
				else:
					_leave(n, shop)
		"away":
			n.set_act("carry", {"w": 0.34}, 3.0)
			if not n.has_goal or n.sub_t > 14.0:
				drop_box(n)
				_leave(n, shop)


static func _enter(n: Npc, shop: Shop) -> void:
	n.in_shop = shop
	n.sub = "enter"
	n.sub_t = 0.0
	if n._rng.randf() < 0.5:
		n.hop(1)
	n.follow(shop.inside_point(n._rng.randf_range(0.0, 0.25), clampf(float(n.data["side"]), -0.6, 0.6)), Actor.RUN * 0.7)


## Choisit un meuble intact (au plus deux casseurs par meuble) et va se placer devant
static func _pick(n: Npc, shop: Shop) -> void:
	var best: ShopItem = null
	var bd := 1e9
	for o in shop.intact_items():
		var it := o as ShopItem
		var busy := 0
		for m in n.crowd.npcs if n.crowd else []:
			if m != n and m.state == "loot" and m.data.get("item") == it:
				busy += 1
		if busy >= 2:
			continue
		var d := it.global_position.distance_to(n.global_position) + n._rng.randf_range(0.0, 1.5)
		if d < bd:
			bd = d
			best = it
	if best == null:
		_to_exit(n, shop, false)
		return
	n.data["item"] = best
	var lx := n._rng.randf_range(-best.size.x * 0.3, best.size.x * 0.3)
	var stand := best.to_global(Vector3(lx, 0.0, best.size.z * 0.5 + 0.55))
	# toujours dans la boutique
	var sl := shop.to_local(stand)
	sl.x = clampf(sl.x, -shop.width * 0.5 + 0.4, shop.width * 0.5 - 0.4)
	sl.z = clampf(sl.z, -shop.depth + 0.4, -0.5)
	n.follow(shop.to_global(sl), Actor.WALK * 1.2)
	n.sub = "pick"
	n.sub_t = 0.0


static func _to_exit(n: Npc, shop: Shop, run: bool) -> void:
	n.follow(shop.front_point(clampf(float(n.data.get("side", 0.0)), -0.5, 0.5)) + _out(shop) * 1.2, Actor.RUN * (0.95 if run else 0.55))
	n.sub = "exit"
	n.sub_t = 0.0


static func _leave(n: Npc, shop: Shop) -> void:
	drop_box(n)
	n.go_home()
	if n.in_shop != null and shop != null:
		# encore dedans (temps écoulé) : sortir d'abord
		n.go(shop.front_point() + _out(shop) * 1.5, false, 0.5)


## Prend un carton de marchandise sur le meuble renversé
static func grab_box(n: Npc, it: ShopItem) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, n._rng.randf_range(0.18, 0.3), 0.26)
	mi.mesh = bm
	var col: Color = it.goods[n._rng.randi() % it.goods.size()] if it != null and not it.goods.is_empty() else Color(0.62, 0.48, 0.3)
	mi.material_override = Shop.col_mat(col.lerp(Color(0.62, 0.48, 0.3), 0.5), 0.8)
	mi.top_level = true
	n.add_child(mi)
	mi.global_position = n.global_position + Vector3.UP * 1.0
	n.loot_box = mi
	AudioLib.play_at(n, "cardboard_land", mi.global_position, -8.0, 4.0)


## Pose le butin par terre (il reste dans la rue)
static func drop_box(n: Npc) -> void:
	if n.loot_box == null:
		return
	var box := n.loot_box
	n.loot_box = null
	if not is_instance_valid(box):
		return
	var rb := RigidBody3D.new()
	rb.mass = 2.0
	rb.collision_layer = 4
	rb.collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (box.mesh as BoxMesh).size
	cs.shape = bs
	rb.add_child(cs)
	var scene := n.get_tree().current_scene
	scene.add_child(rb)
	rb.global_transform = box.global_transform
	box.reparent(rb, true)
	box.top_level = false
	box.transform = Transform3D.IDENTITY
	rb.linear_velocity = n.vel + Vector3.UP * 0.5
	n.get_tree().create_timer(60.0).timeout.connect(func(): if is_instance_valid(rb): rb.queue_free())
