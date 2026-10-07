class_name FloorFire
extends Node3D
## Feu au sol alimenté par des déchets (papier, journaux, cartons, planches) : plus on en ajoute, plus la
## flamme monte. Éclaire le sol, noircit la dalle (tache persistante) et attire les curieux.
## Sert de « foyer » comme la poubelle : burning, heat, fire_center(), add_item().

signal died

const MAX_FIRES := 6
var items: Array[Burnable] = []
var heat := 0.0
var fuel := 0.0
var burning := true
var radius := 0.4
var by_player := false
var _fx: FireFx
var _glow: MeshInstance3D
var _scorch: Decal
var _boost := 0.0
var _age := 0.0
var _out_t := 0.0
var _seed := 0.0
var _scan := 0.0
var _expo := {}
var _init_done := false
static var _glow_mat: StandardMaterial3D
static var _scorch_tex: Texture2D
static var _all_scorches: Array[Decal] = []


## Crée un feu au sol à la position de l'objet allumé (ou rejoint un feu voisin).
static func merge_or_create(b: Burnable) -> void:
	if b.fire != null or b.in_bin != null:
		return
	var scene := b.get_tree().current_scene
	var near: FloorFire = null
	var count := 0
	for f in b.get_tree().get_nodes_in_group("fires"):
		if f is FloorFire and (f as FloorFire).burning:
			count += 1
			if (f as FloorFire).dist_xz(b.global_position) < 0.9 + (f as FloorFire).heat * 0.5:
				near = f
	if near == null:
		if count >= MAX_FIRES:
			return
		near = FloorFire.new()
		scene.add_child(near)
		near.global_position = Vector3(b.global_position.x, 0.0, b.global_position.z)
		near.by_player = false
	near.add_item(b)


func dist_xz(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _ready() -> void:
	_seed = randf() * 100.0
	add_to_group("fires")
	add_to_group("fire_sources")
	_fx = FireFx.new()
	_fx.extent = Vector3(0.12, 0.03, 0.12)
	_fx.flame_size = 0.36
	_fx.smoke_size = 0.45
	_fx.smoke_rise = 1.4
	_fx.smoke_amount = 34
	_fx.light_range = 7.0
	_fx.light_energy = 2.6
	_fx.light_y = 0.4
	_fx.position.y = 0.04
	_fx.flame_rise = 0.9
	add_child(_fx)
	# lueur chaude sur la dalle
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.albedo_texture = load(Props.DIR + "ground_glow.png")
		_glow_mat.albedo_color = Color(1.0, 0.55, 0.22, 1.0)
		_glow_mat.disable_receive_shadows = true
		_glow_mat.no_depth_test = false
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	_glow.mesh = q
	_glow.material_override = _glow_mat
	_glow.rotation.x = -PI / 2.0
	_glow.position.y = 0.025
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	# tache de brûlure qui reste après l'extinction
	if _scorch_tex == null:
		_scorch_tex = load(Props.DIR + "scorch.png")
	_scorch = Decal.new()
	_scorch.texture_albedo = _scorch_tex
	_scorch.size = Vector3(1.4, 0.6, 1.4)
	_scorch.position.y = 0.1
	_scorch.rotation.y = randf() * TAU
	_scorch.modulate = Color(1, 1, 1, 0.0)
	_scorch.upper_fade = 0.5
	_scorch.lower_fade = 0.5
	var scene := get_tree().current_scene
	scene.add_child(_scorch)
	_scorch.global_position = global_position + Vector3(0, 0.1, 0)
	_all_scorches.append(_scorch)
	if _all_scorches.size() > 24:
		var old: Decal = _all_scorches.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	_fx.start()
	_fx.ignite_burst()
	_init_done = true
	get_tree().call_group("crowd", "on_event", "fire_start", {"bin": self, "pos": fire_center(), "floor": true})


func fire_center() -> Vector3:
	return global_position + Vector3(0, 0.3 + 0.45 * heat, 0)


# --- interface commune des foyers (poubelle / feu au sol) utilisée par les PNJ
func stand_pos(from: Vector3) -> Vector3:
	var d := Vector3(from.x - global_position.x, 0, from.z - global_position.z)
	d = d.normalized() if d.length() > 0.05 else Vector3(1, 0, 0)
	return global_position + d * (0.95 + radius * 0.8 + heat * 0.35)


func hand_target() -> Vector3:
	return global_position + Vector3(0, 0.12, 0)


func can_take_items() -> bool:
	return burning


func feed_item(item: Node3D, from: Vector3) -> bool:
	if not (item is Burnable):
		return false
	var b := item as Burnable
	b.global_position = global_position + Vector3((from.x - global_position.x) * 0.15, 0.1, (from.z - global_position.z) * 0.15)
	return add_item(b)


## Ajoute un objet au feu (il y est consumé). Renvoie vrai si accepté.
func add_item(b: Burnable) -> bool:
	if b == null or not is_instance_valid(b) or b.fire != null:
		return false
	items.append(b)
	b.join_fire(self)
	b.reparent(get_tree().current_scene, true)
	# l'objet se pose au sol, au milieu des flammes
	var lp := Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z)
	if lp.length() > 0.55:
		lp = lp.normalized() * 0.55
	var y := b.size.y * 0.5
	if b.kind == "plank" or b.kind == "news":
		y = 0.05 + 0.08 * items.size()
	b.global_position = global_position + Vector3(lp.x, y, lp.y)
	_boost = minf(_boost + 0.25 + b.fuel_s * 0.012, 0.8)
	fuel += b.fuel_s * (1.0 - b.burn)
	if burning:
		_fx.flare_up_burst(-3.0 + minf(b.fuel_s * 0.08, 3.0))
		get_tree().call_group("crowd", "on_event", "fire_flare", {"bin": self, "pos": fire_center()})
	b.ignite()
	_update_extent()
	return true


func _update_extent() -> void:
	var n := items.size()
	var e := 0.1 + 0.035 * minf(n, 8.0)
	_fx.set_extent(Vector3(e, 0.03, e))
	radius = 0.35 + 0.05 * minf(n, 8.0)


func extinguish() -> void:
	if not burning:
		return
	burning = false
	_fx.stop()
	get_tree().call_group("crowd", "on_event", "fire_out", {"bin": self, "pos": fire_center()})


func _physics_process(delta: float) -> void:
	if not _init_done:
		return
	_age += delta
	var t := Time.get_ticks_msec() / 1000.0
	if burning:
		# combustion des objets
		fuel = 0.0
		for b in items.duplicate():
			if not is_instance_valid(b):
				items.erase(b)
				continue
			b.set_burn(b.burn + delta / b.burn_time * (0.65 + 0.7 * heat))
			if b.burn >= 1.0:
				items.erase(b)
				b.queue_free()
				continue
			fuel += b.fuel_s * (1.0 - b.burn)
		var want := clampf(0.15 + 0.62 * sqrt(fuel / 45.0), 0.0, 1.3) if fuel > 0.1 else 0.0
		heat = move_toward(heat, want, (0.35 if want > heat else 0.5) * delta)
		_boost = move_toward(_boost, 0.0, 0.4 * delta)
		# propagation aux objets voisins
		_scan -= delta
		if _scan <= 0.0:
			_scan = 0.25
			var reach := 0.55 + 0.45 * heat
			for o in get_tree().get_nodes_in_group("burnables"):
				var b: Burnable = o
				if b.fire != null or b.in_bin != null or b.held or b._dying:
					continue
				if dist_xz(b.global_position) < reach and b.global_position.y < 0.7:
					_expo[b] = float(_expo.get(b, 0.0)) + 0.25
					if float(_expo[b]) > 1.4:
						_expo.erase(b)
						add_item(b)
				elif _expo.has(b):
					_expo.erase(b)
		if fuel <= 0.1 and heat < 0.03:
			burning = false
			_fx.stop()
			get_tree().call_group("crowd", "on_event", "fire_out", {"bin": self, "pos": fire_center()})
	else:
		heat = move_toward(heat, 0.0, 0.4 * delta)
		_out_t += delta
	var h := clampf(heat + _boost, 0.0, 1.6)
	_fx.update(h, 1.0, burning or _out_t < 5.0, 0.0 if burning else clampf(1.0 - _out_t / 9.0, 0.0, 1.0))
	var gk := h * (0.8 + 0.2 * Fx.flicker(t * 1.3, _seed))
	_glow.scale = Vector3.ONE * (0.7 + 0.9 * clampf(h / 1.3, 0.0, 1.0)) * (1.0 + 0.25 * minf(items.size(), 6.0) * 0.3)
	_glow.transparency = clampf(1.0 - gk * 0.85, 0.0, 1.0)
	if is_instance_valid(_scorch):
		var a: float = _scorch.modulate.a
		var target := clampf(_age / 20.0, 0.0, 0.92) if burning else 0.92
		_scorch.modulate.a = move_toward(a, target, delta * 0.08)
		var sc := 1.1 + 0.3 * minf(items.size(), 8.0) * 0.35 + 0.35 * clampf(_age / 40.0, 0.0, 1.0)
		_scorch.size = Vector3(sc * 1.3, 0.6, sc * 1.3)
	if not burning and _out_t > 10.0:
		died.emit()
		queue_free()
