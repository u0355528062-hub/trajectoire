class_name Crowd
extends Node3D
## Chef d'orchestre de la foule : crée les manifestants (cortège avec banderole, pancartes,
## mégaphone et fumigènes ; groupes qui discutent ; « black bloc » cagoulé près de l'abribus ;
## promeneurs), fait marcher et chanter le cortège, gère les conversations, le budget de voix,
## les obstacles, et distribue les réactions aux événements (tirs, bouquets, vitres, feu, appel).

const MAX_VOICES := 7
const AREA_MIN := Vector2(-38.0, -25.2)      # jusqu'au pied des façades (boulevard bordé d'immeubles)
const AREA_MAX := Vector2(38.0, 18.2)
const VARIANTS := ["male_a", "male_b", "male_c", "male_d", "male_e", "female_a", "female_b", "female_c", "female_d"]
const CHANTS := ["chant_lacherien", "chant_ensemble", "chant_rue", "chant_onestla"]
const POLICE_CHANTS := ["chant_police", "chant_justice", "chant_partout", "chant_libere", "chant_resiste"]

var npcs: Array[Npc] = []
var actors: Array[Actor] = []          # civils + policiers
var nav := NavGrid.new()
var obstacles: Array[Dictionary] = []
var _obs: Array[Dictionary] = []
var _obs_c := PackedVector3Array()
var _obs_r2 := PackedFloat32Array()
var _obs_tick := 0
var _hash := {}
var _nav_dirty := true
var player: Player
var bus: BusStop
var excitement := 0.3
var rally_active := false
var surge := false                 # grand mouvement de foule : on secoue l'abribus jusqu'à l'effondrer
var _rally_t := 0.0
var _rally_far_t := 0.0
var _slots := {}
var voices := 0

# --- cortège
var _route := PackedVector3Array()
var _route_cum := PackedFloat32Array()
var _route_total := 1.0
var cortege_s := 0.0
var cortege_speed := 0.0
var _cortege_moving := true
var _cortege_timer := 0.0
var _cortege_phase_len := 35.0
var chanting := false
var leader_speaking := false
var _chant := ""
var _chant_t := 0.0
var _chant_env: Array = []
var _chant_beats: Array = []
var _beat_i := 0
var _next_chant := 5.0
var _chant_seq := -1.0
var _later_chant_delay := 1.6
var _chant_idx := 0
var _chant_police := false
var _chant_player: AudioStreamPlayer3D
var _murmur: AudioStreamPlayer3D
var _bed: AudioStreamPlayer
var _claps: AudioStreamPlayer3D
var _banner: Banner
var leader: Npc
var _banner_l: Npc
var _banner_r: Npc

# --- discussions
var _chats: Array = []
var _rings := {}
var fire_srcs: Array = []          # poubelles et feux au sol (cache par image)
var police: Police
var standoff: Standoff
const MAX_LOOTERS := 7
var _loot_cd := 20.0
var aid_pairs := {}                # blessé -> secouriste en route
var _aid_t := 0.0
var _initial_count := 0
var _newcomer_cd := 40.0
var _newcomer_n := 0
var _gas_aware_t := 0.0
var _clouds: Array = []              # nuages de gaz (mis à jour à chaque image)
var _brawl_cd := 20.0
var _throw_cd := 6.0
var _vandal_cd := 25.0
# barricade : barrières posées en travers de la chaussée entre la foule et la police
const BARRICADE_Z := [-9.4, -7.4, -5.4]
var barricade_x := NAN
var _barricade: Array = [null, null, null]     # Barrier posée à chaque place
var _barricade_by: Array = [null, null, null]  # Npc qui y porte une barrière
var _barricade_cd := 25.0
var _carat_cd := 30.0
var _taunt_cd := 6.0
var _comfort_cd := 3.0
var _tag_cd := 20.0
var _tags: Array[Label3D] = []
var _rescuers := 0
var _arson_cd := 140.0
var _later: Array = []
var _sound_cd := {}
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _bump_cd := 0.0
var _cheer_cd := 0.0
var _static_circles: Array = []


func setup(p: Player, b: BusStop) -> void:
	player = p
	bus = b


func _ready() -> void:
	add_to_group("crowd")
	_rng.seed = 4242
	_build_route()
	var circles := [
		[Vector3(-4.8, 0, -11.3), 0.35], [Vector3(3.4, 0, -11.6), 0.25], [Vector3(-3.4, 0, -11.6), 0.25],
		[Vector3(3.55, 0, -13.3), 0.55], [Vector3(2.55, 0, -12.45), 0.35], [Vector3(-2.75, 0, -12.0), 0.22],
	]
	for c in circles:
		var m := Marker3D.new()
		add_child(m)
		m.global_position = c[0]
		add_obstacle(m, Vector2(c[1], 0.0), Vector2.ZERO, true)
	if bus:
		add_obstacle(bus, Vector2(2.15, 1.05))
	_spawn_all()
	standoff = Standoff.new(self)
	_initial_count = npcs.size()
	_build_audio()
	_banner = Banner.new()
	add_child(_banner)


# =================================================================== cortège : parcours
func _build_route() -> void:
	var ctrl := [Vector3(-30, 0, -7.2), Vector3(-10, 0, -7.4), Vector3(10, 0, -7.4), Vector3(30, 0, -7.2),
		Vector3(36, 0, -0.5), Vector3(30, 0, 5.5), Vector3(10, 0, 6.0), Vector3(-10, 0, 6.0), Vector3(-30, 0, 5.5), Vector3(-36, 0, -0.5)]
	var n := ctrl.size()
	_route.clear()
	for i in n:
		var p0: Vector3 = ctrl[(i - 1 + n) % n]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[(i + 1) % n]
		var p3: Vector3 = ctrl[(i + 2) % n]
		var steps := int(p1.distance_to(p2) / 0.5) + 1
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			_route.append(p)
	_route_cum.clear()
	var acc := 0.0
	_route_cum.append(0.0)
	for i in range(1, _route.size() + 1):
		acc += _route[i - 1].distance_to(_route[i % _route.size()])
		_route_cum.append(acc)
	_route_total = acc
	cortege_s = _route_s_near(Vector3(-13, 0, -7.3))


func _route_s_near(p: Vector3) -> float:
	var best := 0
	var bd := INF
	for i in _route.size():
		var d := _route[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return _route_cum[best]


func route_at(s: float) -> Array:
	s = fposmod(s, _route_total)
	var lo := 0
	var hi := _route.size()
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if _route_cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var a := _route[lo]
	var b := _route[(lo + 1) % _route.size()]
	var seg := maxf(_route_cum[lo + 1] - _route_cum[lo], 0.001)
	var u := (s - _route_cum[lo]) / seg
	var tan := (b - a).normalized()
	return [a.lerp(b, u), tan]


func march_target(n: Npc) -> Array:
	if standoff.active:
		var sp: Variant = standoff.slot_of(n)
		if sp != null:
			return [safe_from_gas(sp), Vector3(1, 0, 0)]
		if standoff.is_rear(n):
			return [standoff.rear_spot(n), Vector3(1, 0, 0)]
	var wob := Vector2(sin(_time * 0.31 + n.idx) * 0.14, sin(_time * 0.23 + n.idx * 1.7) * 0.22)
	if n.prop == "banner" or n == leader:
		wob = Vector2(0, sin(_time * 0.4 + n.idx) * 0.05)
	var r := route_at(cortege_s - n.slot.y - wob.y)
	var p: Vector3 = r[0]
	var tan: Vector3 = r[1]
	var right := tan.cross(Vector3.UP).normalized()
	p += right * (n.slot.x + wob.x)
	return [safe_from_gas(p), tan]


func cortege_center() -> Vector3:
	if standoff.active:
		return standoff.center + Vector3.UP * 1.5
	var r := route_at(cortege_s - 2.6)
	return (r[0] as Vector3) + Vector3.UP * 1.5


# =================================================================== création des PNJ
func _outfit(rng: RandomNumberGenerator, female: bool, masked: String, vest: bool) -> Dictionary:
	var cols := [Color(0.05, 0.05, 0.06), Color(0.12, 0.14, 0.2), Color(0.32, 0.33, 0.32), Color(0.5, 0.11, 0.12),
		Color(0.14, 0.27, 0.17), Color(0.58, 0.48, 0.32), Color(0.17, 0.24, 0.45), Color(0.4, 0.28, 0.19),
		Color(0.7, 0.68, 0.64), Color(0.45, 0.17, 0.3), Color(0.8, 0.52, 0.1), Color(0.08, 0.2, 0.3)]
	var tops := ["hoodie", "hoodie", "jacket", "jacket", "tshirt"]
	var top: String = tops[rng.randi() % tops.size()]
	var heads := ["", "", "beanie", "cap", "beanie"]
	var o := {
		"top": top, "top_color": cols[rng.randi() % cols.size()], "hood": false, "vest": vest,
		"pants_tex": rng.randf() < 0.65, "pants_color": [Color(1, 1, 1), Color(0.07, 0.07, 0.08), Color(0.25, 0.23, 0.2), Color(0.18, 0.2, 0.24)][rng.randi() % 4],
		"shoe_color": [Color(0.2, 0.21, 0.25), Color(0.85, 0.85, 0.83), Color(0.06, 0.06, 0.06), Color(0.45, 0.3, 0.2)][rng.randi() % 4],
		"head": heads[rng.randi() % heads.size()], "head_color": cols[rng.randi() % cols.size()],
		"face": "", "face_color": Color(0.05, 0.05, 0.06), "backpack": rng.randf() < 0.3,
		"bag_color": [Color(0.04, 0.04, 0.05), Color(0.1, 0.12, 0.2), Color(0.12, 0.18, 0.12), Color(0.3, 0.08, 0.1), Color(0.25, 0.18, 0.12)][rng.randi() % 5],
		"hair_color": [Color(0.05, 0.035, 0.025), Color(0.12, 0.08, 0.05), Color(0.3, 0.2, 0.1), Color(0.02, 0.02, 0.02)][rng.randi() % 4],
	}
	if not o["pants_tex"]:
		o["pants_color"] = [Color(0.07, 0.07, 0.08), Color(0.2, 0.2, 0.22), Color(0.25, 0.22, 0.17)][rng.randi() % 3]
	if masked == "bloc":
		o["top"] = "hoodie" if rng.randf() < 0.7 else "jacket"
		o["top_color"] = Color(0.04, 0.04, 0.045)
		o["hood"] = rng.randf() < 0.6
		o["face"] = "balaclava"
		o["face_color"] = Color(0.03, 0.03, 0.035)
		o["pants_tex"] = false
		o["pants_color"] = Color(0.05, 0.05, 0.06)
		o["shoe_color"] = Color(0.06, 0.06, 0.06)
		o["vest"] = false
	elif masked == "balaclava":
		o["face"] = "balaclava"
		o["face_color"] = [Color(0.04, 0.04, 0.05), Color(0.25, 0.25, 0.27)][rng.randi() % 2]
	elif masked == "bandana":
		o["face"] = "bandana"
		o["face_color"] = [Color(0.7, 0.1, 0.1), Color(0.08, 0.08, 0.1), Color(0.15, 0.2, 0.45)][rng.randi() % 3]
	if top == "hoodie" and masked == "" and rng.randf() < 0.15:
		o["hood"] = true
	return o


func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	# [rôle, accessoire, n° pancarte, masque, gilet, emplacement/zone, groupe, fumeur]
	var cfg := [
		["march", "banner", 0, "", false, Vector2(-1.5, 0.0), -1, false],
		["march", "banner", 0, "bandana", false, Vector2(1.5, 0.0), -1, false],
		["march", "megaphone", 0, "", true, Vector2(-2.7, -1.6), -1, false],
		["march", "sign", 1, "", false, Vector2(-1.2, 1.5), -1, false],
		["march", "sign", 3, "", true, Vector2(1.2, 1.6), -1, false],
		["march", "", 0, "", false, Vector2(0.0, 1.4), -1, false],
		["march", "flare", 0, "balaclava", false, Vector2(-1.4, 2.9), -1, false],
		["march", "sign", 2, "", false, Vector2(0.1, 2.9), -1, false],
		["march", "", 0, "bandana", false, Vector2(1.3, 3.0), -1, false],
		["march", "sign", 4, "", false, Vector2(-0.6, 4.3), -1, false],
		["march", "flare", 0, "", false, Vector2(0.8, 4.4), -1, false],
		["march", "", 0, "", true, Vector2(-1.7, 4.5), -1, false],
		["march", "", 0, "", false, Vector2(1.9, 4.6), -1, false],
		["chat", "", 0, "", false, Vector2.ZERO, 0, true],
		["chat", "", 0, "", true, Vector2.ZERO, 0, false],
		["chat", "", 0, "", false, Vector2.ZERO, 0, false],
		["chat", "", 0, "", false, Vector2.ZERO, 1, false],
		["chat", "", 0, "balaclava", false, Vector2.ZERO, 1, true],
		["chat", "", 0, "", false, Vector2.ZERO, 2, false],
		["chat", "", 0, "", true, Vector2.ZERO, 2, false],
		["chat", "", 0, "", false, Vector2.ZERO, 2, true],
		["bloc", "mortar", 0, "bloc", false, Vector2.ZERO, -1, false],
		["bloc", "flare", 0, "bloc", false, Vector2.ZERO, -1, false],
		["bloc", "", 0, "bloc", false, Vector2.ZERO, -1, true],
		["bloc", "", 0, "bloc", false, Vector2.ZERO, -1, false],
		["loner", "sign", 2, "", false, Vector2.ZERO, -1, false],
		["loner", "", 0, "", false, Vector2.ZERO, -1, false],
		["medic", "", 0, "", true, Vector2.ZERO, -1, false],
		["press", "", 0, "", false, Vector2.ZERO, -1, false],
	]
	var chat_centers := [Vector3(-4.6, 0, -1.4), Vector3(7.6, 0, 2.6), Vector3(-9.0, 0, 4.0)]
	for g in chat_centers.size():
		_chats.append({"center": chat_centers[g], "home": chat_centers[g], "members": [], "speaker": null, "next": 2.0 + g * 1.7, "last": null, "reply": -1.0, "listener": null})
	var bloc_home := [Vector3(6.0, 0, -13.2), Vector3(7.3, 0, -12.4), Vector3(5.2, 0, -14.3), Vector3(7.0, 0, -14.5)]
	var loner_home := [Vector3(1.0, 0, 6.5), Vector3(12.0, 0, -2.5)]
	var bloc_i := 0
	var loner_i := 0
	for i in cfg.size():
		var c: Array = cfg[i]
		var n := Npc.new()
		n.idx = i
		n.crowd = self
		n.role = c[0]
		n.prop = c[1]
		n.sign_idx = c[2]
		var vi := (i * 4 + 1) % VARIANTS.size()
		n.variant = VARIANTS[vi]
		n.female = n.variant.begins_with("female")
		n.voice = "f1" if n.female else ("m1" if i % 2 == 0 else "m2")
		n.vpitch = rng.randf_range(0.96, 1.1) if n.female else rng.randf_range(0.92, 1.07)
		n.outfit = _outfit(rng, n.female, c[3], c[4])
		n.slot = c[5]
		n.group = c[6]
		n.smoker = c[7]
		n.bold = rng.randf_range(0.2, 0.8)
		n.curious = rng.randf_range(0.3, 0.95)
		n.calm = rng.randf_range(0.2, 0.9)
		var pos := Vector3.ZERO
		match n.role:
			"march":
				var r := route_at(cortege_s - n.slot.y)
				pos = (r[0] as Vector3) + (r[1] as Vector3).cross(Vector3.UP).normalized() * n.slot.x
				n.rotation.y = atan2(-(r[1] as Vector3).x, -(r[1] as Vector3).z)
				if n.prop == "megaphone":
					leader = n
				if n.prop == "banner":
					n.banner_side = 1.0 if n.slot.x < 0.0 else -1.0
					if n.slot.x < 0.0:
						_banner_l = n
					else:
						_banner_r = n
			"chat":
				var ch: Dictionary = _chats[n.group]
				(ch["members"] as Array).append(n)
				pos = (ch["center"] as Vector3) + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
				n.curious = rng.randf_range(0.4, 0.95)
			"bloc":
				pos = bloc_home[bloc_i % bloc_home.size()]
				bloc_i += 1
				n.bold = rng.randf_range(0.65, 1.0)
				n.calm = rng.randf_range(0.5, 0.95)
			"medic":
				pos = Vector3(-2.5, 0, 3.5)
				n.bold = 0.5
				n.calm = 0.9
				n.outfit["vest"] = true
				n.outfit["top"] = "tshirt"
				n.outfit["backpack"] = true
				n.outfit["bag_color"] = Color(0.72, 0.1, 0.1)
			"press":
				pos = Vector3(11.0, 0, 7.0)
				n.bold = 0.55
				n.calm = 0.8
				n.outfit["top"] = "jacket"
				n.outfit["top_color"] = Color(0.12, 0.2, 0.17)
				n.outfit["backpack"] = true
				n.outfit["bag_color"] = Color(0.05, 0.05, 0.06)
			_:
				pos = loner_home[loner_i % loner_home.size()]
				loner_i += 1
		n.home_pos = pos
		n.position = Vector3(pos.x, ground_y(pos), pos.z)
		add_child(n)
		npcs.append(n)
		actors.append(n)


func _build_audio() -> void:
	Settings.ensure_buses()
	_chant_player = AudioStreamPlayer3D.new()
	_chant_player.bus = &"Ambiance"
	_chant_player.unit_size = 16.0
	_chant_player.max_distance = 160.0
	_chant_player.volume_db = 1.0
	add_child(_chant_player)
	_chant_player.finished.connect(_on_chant_done)
	_murmur = AudioStreamPlayer3D.new()
	_murmur.bus = &"Ambiance"
	_murmur.stream = AudioLib.stream("crowd_murmur", true)
	_murmur.unit_size = 9.0
	_murmur.max_distance = 120.0
	_murmur.volume_db = -5.0
	add_child(_murmur)
	_murmur.play()
	_claps = AudioStreamPlayer3D.new()
	_claps.bus = &"Ambiance"
	_claps.stream = AudioLib.stream("claps_group", true)
	_claps.unit_size = 9.0
	_claps.volume_db = -60.0
	add_child(_claps)
	_claps.play()
	_bed = AudioStreamPlayer.new()
	_bed.bus = &"Ambiance"
	_bed.stream = AudioLib.stream("crowd_murmur", true)
	_bed.volume_db = -27.0
	add_child(_bed)
	_bed.play(12.0)


# =================================================================== boucle
func _physics_process(delta: float) -> void:
	_time += delta
	_bump_cd = maxf(_bump_cd - delta, 0.0)
	_cheer_cd = maxf(_cheer_cd - delta, 0.0)
	excitement = move_toward(excitement, 0.3, delta * 0.006)
	_run_later()
	fire_srcs = get_tree().get_nodes_in_group("fire_sources")
	_clouds = get_tree().get_nodes_in_group("gas_clouds")
	_cache_obstacles()
	_rebuild_hash()
	if _nav_dirty:
		rebuild_nav()
	_update_arson(delta)
	_update_hostility(delta)
	_update_brawls(delta)
	_update_vandalism(delta)
	_update_barricade(delta)
	_update_car_attacks(delta)
	_update_taunts(delta)
	_update_comfort(delta)
	_update_tags(delta)
	_update_looting(delta)
	standoff.update(delta)
	_update_gas_awareness(delta)
	_update_aid(delta)
	_update_newcomers(delta)
	_update_cortege(delta)
	_update_chats(delta)
	_update_rally(delta)
	_update_bumps()
	var cam := get_viewport().get_camera_3d()
	var cp := cam.global_position if cam else Vector3.ZERO
	for n in actors:
		var d := n.global_position.distance_to(cp)
		var every := 1 if d < 22.0 else (2 if d < 45.0 else 3)
		var has_prop: bool = (n is Npc and (n as Npc).prop != "") or (n is Cop)
		var lod := 0 if d < 40.0 else (1 if (d < 70.0 or has_prop) else 2)
		# hors champ : on ne voit que son ombre, on l'anime moins souvent et sans les détails du visage
		if cam != null and d > 5.0 and not cam.is_position_in_frustum(n.global_position + Vector3.UP):
			every = maxi(every * 2, 4)
			lod = maxi(lod, 1)
		n.human.lod = lod
		n.tick(delta, every)
	if _banner_l != null and _banner_r != null and _banner_l.pole_node and _banner_r.pole_node:
		var a := _banner_r.pole_node.global_transform * Vector3(0, 1.4, 0)
		var b := _banner_l.pole_node.global_transform * Vector3(0, 1.4, 0)
		_banner.set_poles(a, b)
		_banner.visible = a.distance_to(b) < 6.5      # perches trop écartées : la banderole tombe


func _run_later() -> void:
	var i := 0
	while i < _later.size():
		var e: Array = _later[i]
		if _time >= float(e[0]):
			_later.remove_at(i)
			var cb: Callable = e[1]
			if cb.is_valid():
				cb.call()
		else:
			i += 1


func later(dt: float, cb: Callable) -> void:
	_later.append([_time + dt, cb])


# ------------------------------------------------------------------- cortège
func _update_cortege(delta: float) -> void:
	_cortege_timer += delta
	if _cortege_timer > _cortege_phase_len:
		_cortege_timer = 0.0
		_cortege_moving = not _cortege_moving
		_cortege_phase_len = _rng.randf_range(30.0, 55.0) if _cortege_moving else _rng.randf_range(14.0, 22.0)
		if not _cortege_moving and not chanting and _chant_seq < 0.0:
			_next_chant = 1.5
	# l'arrière ne doit pas être largué
	var lag := 0.0
	for n in npcs:
		if n.role == "march" and n.state == "home":
			var t: Vector3 = march_target(n)[0]
			lag = maxf(lag, Vector2(t.x - n.global_position.x, t.z - n.global_position.z).length())
	var want := 0.55 if _cortege_moving and not standoff.active else 0.0
	if lag > 2.5:
		want *= clampf(1.0 - (lag - 2.5) / 3.0, 0.0, 1.0)
	cortege_speed = move_toward(cortege_speed, want, delta * 0.25)
	cortege_s = fposmod(cortege_s + cortege_speed * delta, _route_total)
	var cc := cortege_center()
	_chant_player.global_position = cc
	_murmur.global_position = cc
	_claps.global_position = cc
	# chants : le meneur lance au mégaphone, la foule reprend
	if _chant_seq >= 0.0:
		_chant_seq += delta
		if _chant_seq > float(_later_chant_delay) and not chanting:
			_start_chant_track()
	elif not chanting:
		_next_chant -= delta
		if _next_chant <= 0.0:
			_start_chant_seq()
	if chanting:
		_chant_t += delta
		while _beat_i < _chant_beats.size() and float(_chant_beats[_beat_i]) <= _chant_t:
			_beat_i += 1
	leader_speaking = leader != null and leader.speaking()
	var clap_target := -6.0 if chanting else -60.0
	_claps.volume_db = move_toward(_claps.volume_db, clap_target, delta * (30.0 if chanting else 20.0))



func _start_chant_seq() -> void:
	# face à la police, on change de répertoire
	var pol_stage: int = police.stage if police != null else 0
	_chant_police = pol_stage >= 1 and _rng.randf() < 0.45 + 0.12 * float(pol_stage)
	if _chant_police:
		_chant_idx = (_chant_idx + 1 + _rng.randi() % 3) % POLICE_CHANTS.size()
	else:
		_chant_idx = (_chant_idx + 1 + _rng.randi() % 2) % CHANTS.size()
	_chant_seq = 0.0
	_later_chant_delay = 1.6
	if _chant_police:
		_later_chant_delay = 0.9
	elif leader:
		var d := leader.say("megaphone_%d" % _chant_idx, true, 4.0)
		leader._voice.unit_size = 14.0
		_later_chant_delay = d + 0.35


func _start_chant_track() -> void:
	_chant = POLICE_CHANTS[_chant_idx] if _chant_police else CHANTS[_chant_idx]
	_chant_player.stream = AudioLib.stream(_chant)
	_chant_player.play()
	_chant_env = AudioLib.env(_chant)
	_chant_beats = AudioLib.beats(_chant)
	_beat_i = 0
	_chant_t = 0.0
	chanting = true
	_chant_seq = -1.0


func _on_chant_done() -> void:
	chanting = false
	_chant_t = 0.0
	_next_chant = _rng.randf_range(9.0, 20.0)


func beat_pulse(i: int) -> float:
	if not chanting or _beat_i == 0:
		return 0.0
	var lagt := (i % 5) * 0.015
	var b := float(_chant_beats[_beat_i - 1])
	var dt := _chant_t - b - lagt
	if dt < 0.0:
		return 0.0 if _beat_i < 2 else exp(-(_chant_t - float(_chant_beats[_beat_i - 2])) * 5.0)
	return exp(-dt * 5.0)


func chant_jaw(i: int) -> float:
	if not chanting:
		return 0.0
	return AudioLib.env_at(_chant_env, _chant_t - (i % 4) * 0.02) * (0.75 + 0.2 * ((i * 37) % 10) / 10.0)


# ------------------------------------------------------------------- discussions
func _update_chats(delta: float) -> void:
	for ch in _chats:
		var members: Array = ch["members"]
		var avail: Array = []
		for m in members:
			if not is_instance_valid(m):
				continue
			var n := m as Npc
			if n.state == "home":
				avail.append(n)
		var spk: Npc = ch["speaker"]
		if spk and (not is_instance_valid(spk) or not spk.speaking()):
			ch["speaker"] = null
			spk = null
		if float(ch["reply"]) >= 0.0:
			ch["reply"] = float(ch["reply"]) - delta
			if float(ch["reply"]) < 0.0 and avail.size() >= 2:
				var last: Npc = ch["last"]
				var cand: Array = avail.filter(func(x): return x != last)
				if not cand.is_empty():
					var r: Npc = cand[_rng.randi() % cand.size()]
					var d := r.say(AudioLib.pick(r.voice, "reply"), false)
					ch["speaker"] = r
					ch["listener"] = last
					ch["next"] = d + _rng.randf_range(0.6, 2.0)
					ch["last"] = r
				ch["reply"] = -1.0
			continue
		if spk != null:
			continue
		ch["next"] = float(ch["next"]) - delta
		if float(ch["next"]) > 0.0 or avail.size() < 2:
			continue
		var last2: Npc = ch["last"]
		var cand2: Array = avail.filter(func(x): return x != last2)
		var s: Npc = cand2[_rng.randi() % cand2.size()]
		var d2 := s.say(AudioLib.pick(s.voice, "talk"), false)
		ch["speaker"] = s
		ch["listener"] = last2 if last2 and avail.has(last2) else avail.filter(func(x): return x != s)[0]
		ch["last"] = s
		if _rng.randf() < 0.6:
			ch["reply"] = d2 + _rng.randf_range(0.25, 0.7)
		else:
			ch["next"] = d2 + _rng.randf_range(1.5, 4.0)


func chat_spot(n: Npc) -> Array:
	var ch: Dictionary = _chats[n.group]
	var members: Array = ch["members"]
	var i := members.find(n)
	var cnt := members.size()
	var center: Vector3 = ch["center"]
	var ang := TAU * i / cnt + n.group * 0.9
	var rad := 0.62 + 0.12 * cnt
	return [safe_from_gas(center + Vector3(cos(ang), 0, sin(ang)) * rad), center + Vector3.UP * 1.55]


func chat_speaker(g: int) -> Npc:
	if g < 0 or g >= _chats.size():
		return null
	return _chats[g]["speaker"]


func chat_listener_target(n: Npc) -> Npc:
	var ch: Dictionary = _chats[n.group]
	var l: Npc = ch["listener"]
	if l and l != n:
		return l
	for m in ch["members"]:
		if m != n:
			return m
	return null


# ------------------------------------------------------------------- voix
func voice_ok(n: Actor, loud: bool) -> bool:
	return voices < MAX_VOICES and near_listener(n.global_position, 70.0 if (loud and n is Cop) else (40.0 if loud else 17.0))


func voice_started() -> void:
	voices += 1


func voice_done() -> void:
	voices = maxi(voices - 1, 0)


func near_listener(p: Vector3, r: float) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	return cam.global_position.distance_to(p) < r


func _crowd_sound(name: String, pos: Vector3, vol := 0.0, cd := 4.0) -> void:
	if _time < float(_sound_cd.get(name, -99.0)):
		return
	_sound_cd[name] = _time + cd
	AudioLib.play_at(self, name, pos, vol, 14.0)


# =================================================================== espace
func player_pos() -> Vector3:
	return player.global_position if player else Vector3.ZERO


func ground_y(p: Vector3) -> float:
	if bus:
		var l := bus.to_local(p)
		if absf(l.x) <= 2.6 and l.z >= -1.45 and l.z <= 1.65:
			return 0.08
	if p.z >= -10.9 and p.z <= -3.9:
		return 0.02
	return 0.0


## Limite est de la zone des civils : s'étend vers le cordon (jamais au-delà de la ligne de police)
func area_max_x() -> float:
	if police != null:
		return clampf(police.line_c.x - 1.2, AREA_MIN.x + 14.0, 53.0)
	return AREA_MAX.x


func chats() -> Array:
	return _chats


func clamp_area(p: Vector3) -> Vector3:
	p.x = clampf(p.x, AREA_MIN.x, area_max_x())
	p.z = clampf(p.z, AREA_MIN.y, AREA_MAX.y)
	if bus:
		var l := bus.to_local(p)
		var hx := 2.3
		var hz := 1.2
		if absf(l.x) < hx and absf(l.z) < hz:
			if hx - absf(l.x) < hz - absf(l.z):
				l.x = signf(l.x if l.x != 0.0 else 1.0) * (hx + 0.1)
			else:
				l.z = signf(l.z if l.z != 0.0 else 1.0) * (hz + 0.1)
			p = bus.to_global(l)
	return p


## Enregistre un obstacle qui suit son nœud : boîte (demi-dimensions locales x/z) ou cercle.
func add_obstacle(node: Node3D, half: Vector2, offset := Vector2.ZERO, circle := false, in_nav := true) -> void:
	obstacles.append({"node": node, "half": half, "off": offset, "circle": circle, "nav": in_nav})
	_nav_dirty = true


func remove_obstacle(node: Node3D) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i]["node"] == node:
			obstacles.remove_at(i)
	_nav_dirty = true


func mark_nav_dirty() -> void:
	_nav_dirty = true


func nav_dirty() -> void:
	_nav_dirty = true


## Un policier rejoint la simulation : il est animé et fait partie des obstacles mouvants
func register_cop(c: Cop) -> void:
	if not actors.has(c):
		actors.append(c)


func unregister_actor(a: Actor) -> void:
	actors.erase(a)
	if a is Npc:
		npcs.erase(a)
		_forget_npc(a as Npc)


## Un manifestant quitte la scène (interpellé et embarqué) : on efface toute référence vers lui
func _forget_npc(n: Npc) -> void:
	for ch in _chats:
		(ch["members"] as Array).erase(n)
		for k in ["speaker", "last", "listener"]:
			if ch[k] == n:
				ch[k] = null
	_slots.erase(n)
	aid_pairs.erase(n)
	for pt in aid_pairs.keys():
		if aid_pairs[pt] == n:
			aid_pairs.erase(pt)
	if standoff != null:
		standoff.forget(n)
	for bin in _rings:
		(_rings[bin] as Array).erase(n)
	if leader == n:
		leader = null
		leader_speaking = false
	if _banner_l == n:
		_banner_l = null
	if _banner_r == n:
		_banner_r = null
	_banner.visible = _banner_l != null and _banner_r != null


func rebuild_nav() -> void:
	nav.clear()
	for o in obstacles:
		var node: Node3D = o["node"]
		if not o["nav"] or not is_instance_valid(node):
			continue
		var xf := node.global_transform
		var off: Vector2 = o["off"]
		var c := xf * Vector3(off.x, 0, off.y)
		if o["circle"]:
			nav.block_circle(c, (o["half"] as Vector2).x)
		else:
			nav.block_box(c, o["half"], node.global_rotation.y)
	_nav_dirty = false


func _cache_obstacles() -> void:
	# les obstacles bougent peu : on ne les relève qu'une image physique sur deux
	_obs_tick += 1
	if _obs_tick % 2 == 0 and not _obs.is_empty():
		return
	_obs.clear()
	_obs_c.clear()
	_obs_r2.clear()
	for o in obstacles:
		var node: Node3D = o["node"]
		if not is_instance_valid(node):
			continue
		var xf := node.global_transform
		var off: Vector2 = o["off"]
		var c := xf * Vector3(off.x, 0, off.y)
		var h: Vector2 = o["half"]
		var r := (h.x + 0.5) if o["circle"] else (h.length() + 0.5)
		_obs.append({"c": c, "inv": Basis(Vector3.UP, node.global_rotation.y).inverse(), "h": h, "circle": o["circle"]})
		_obs_c.append(c)
		_obs_r2.append(r * r)
	for n in get_tree().get_nodes_in_group("dyn_obstacles"):
		var info: Array = n.obstacle_box()
		if info.size() == 3:
			var hb: Vector2 = info[1]
			var r2 := hb.length() + 0.5
			_obs.append({"c": info[0], "inv": Basis(Vector3.UP, float(info[2])).inverse(), "h": hb, "circle": false})
			_obs_c.append(info[0])
			_obs_r2.append(r2 * r2)


func _rebuild_hash() -> void:
	_hash.clear()
	for a in actors:
		var key := Vector2i(floori(a.global_position.x / 1.5), floori(a.global_position.z / 1.5))
		if _hash.has(key):
			(_hash[key] as Array).append(a)
		else:
			_hash[key] = [a]


## Acteurs (civils et policiers) à moins de `r` de `p` (plan horizontal)
func neighbors(p: Vector3, r: float) -> Array[Actor]:
	var out: Array[Actor] = []
	var k0 := Vector2i(floori((p.x - r) / 1.5), floori((p.z - r) / 1.5))
	var k1 := Vector2i(floori((p.x + r) / 1.5), floori((p.z + r) / 1.5))
	var r2 := r * r
	for x in range(k0.x, k1.x + 1):
		for y in range(k0.y, k1.y + 1):
			var lst: Variant = _hash.get(Vector2i(x, y))
			if lst == null:
				continue
			for a: Actor in lst:
				var d := a.global_position - p
				if d.x * d.x + d.z * d.z <= r2:
					out.append(a)
	return out


## Chemin lissé (A*) évitant les obstacles fixes.
func plan(from: Vector3, to: Vector3) -> Array[Vector3]:
	if _nav_dirty:
		rebuild_nav()
	return nav.path(from, to)


func separation(n: Actor) -> Vector3:
	var p := n.global_position
	var acc := Vector3.ZERO
	for o in neighbors(p, 0.9):
		if o == n:
			continue
		var d := Vector3(p.x - o.global_position.x, 0, p.z - o.global_position.z)
		var l := d.length()
		if l < 0.85:
			if l < 0.01:
				d = Vector3(cos(n.idx), 0, sin(n.idx))
				l = 0.01
			acc += d / l * (0.85 - l) / 0.85
	if player:
		var pp := player.global_position
		var d2 := Vector3(p.x - pp.x, 0, p.z - pp.z)
		var l2 := d2.length()
		if l2 < 1.1 and l2 > 0.01:
			acc += d2 / l2 * (1.1 - l2) / 1.1 * 1.6
	return acc


func resolve(n: Actor, p: Vector3) -> Vector3:
	var rad := 0.3
	for i in _obs.size():
		var oc: Vector3 = _obs_c[i]
		var ddx := p.x - oc.x
		var ddz := p.z - oc.z
		if ddx * ddx + ddz * ddz > _obs_r2[i]:
			continue
		var o: Dictionary = _obs[i]
		var c: Vector3 = o["c"]
		var h: Vector2 = o["h"]
		if o["circle"]:
			p = _push_circle(p, c, h.x + rad)
			continue
		var l: Vector3 = (o["inv"] as Basis) * (p - c)
		var hx := h.x + rad
		var hz := h.y + rad
		if absf(l.x) < hx and absf(l.z) < hz:
			if hx - absf(l.x) < hz - absf(l.z):
				l.x = (signf(l.x) if l.x != 0.0 else 1.0) * hx
			else:
				l.z = (signf(l.z) if l.z != 0.0 else 1.0) * hz
			var w: Vector3 = ((o["inv"] as Basis).inverse() * l) + c
			p.x = w.x
			p.z = w.z
	for c in _static_circles:
		p = _push_circle(p, c[0], c[1] + 0.25)
	for fs in fire_srcs:
		var src := fs as Node3D
		if src is PoliceVehicle:
			continue
		var r := 0.55
		if src is TrashBin:
			var bin := src as TrashBin
			if bin.tipped:
				r = 0.8
			elif bin.burning and not n.fire_ok:
				r = 0.85 + bin.heat * 0.7
		else:
			var ff := src as FloorFire
			r = (0.55 + ff.radius + ff.heat * 0.5) if ff.burning else (0.5 + ff.radius * 0.5)
			if n.fire_ok and ff.burning:
				r = 0.5 + ff.radius * 0.5
		p = _push_circle(p, src.global_position, r)
	if player:
		p = _push_circle(p, player.global_position, 0.48)
	# les façades : personne ne traverse les murs (sauf les pilleurs dans une boutique ouverte)
	var zlo := ParisStreet.SOUTH_Z + 0.35
	var zhi := ParisStreet.NORTH_Z - 0.35
	if n is Npc and (n as Npc).in_shop != null:
		var sh := (n as Npc).in_shop
		if sh.global_position.z > 0.0:
			zhi += sh.depth
		else:
			zlo -= sh.depth
	p.z = clampf(p.z, zlo, zhi)
	if n is Cop:
		p.x = clampf(p.x, -125.0, 125.0)
		return p
	var xm := area_max_x() + (4.0 if police == null else 1.0)
	if n is Npc and (n as Npc).state == "arrested":
		xm = 125.0                 # l'interpellé est emmené derrière la ligne, jusqu'au fourgon
	elif p.x > xm + 1.0:
		xm = p.x - 0.1             # escorte interrompue de l'autre côté : il revient sans téléportation
	p.x = clampf(p.x, AREA_MIN.x - 4.0, xm)
	return p


func _push_circle(p: Vector3, c: Vector3, r: float) -> Vector3:
	var d := Vector2(p.x - c.x, p.z - c.z)
	var l := d.length()
	if l < r:
		if l < 0.001:
			d = Vector2(1, 0)
			l = 1.0
		var q := Vector2(c.x, c.z) + d / l * r
		p.x = q.x
		p.z = q.y
	return p


## Point intéressant à regarder pour un PNJ désœuvré
func interest_point(n: Npc) -> Vector3:
	var r := _rng.randf()
	var p := n.global_position
	if r < 0.25:
		return cortege_center()
	if r < 0.45:
		var best_fs: Node3D = null
		var bd := 30.0
		for fs in fire_srcs:
			if fs.burning and fs.global_position.distance_to(p) < bd:
				bd = fs.global_position.distance_to(p)
				best_fs = fs
		if best_fs:
			return best_fs.fire_center()
	if r < 0.6 and player and player.global_position.distance_to(p) < 16.0:
		return player.global_position + Vector3.UP * 1.6
	if r < 0.75 and bus:
		return bus.global_position + Vector3.UP * 1.3
	if r < 0.9:
		var o: Npc = npcs[_rng.randi() % npcs.size()]
		if o != n and o.global_position.distance_to(p) < 15.0:
			return o.head_pos()
	return p + Vector3(_rng.randf_range(-8, 8), _rng.randf_range(0.5, 3.0), _rng.randf_range(-8, 8))


func flare_budget_ok() -> bool:
	var lit := 0
	for n in npcs:
		if n.flare and n.flare.lit:
			lit += 1
	return lit < 3


func mortar_ok(n: Npc) -> bool:
	if rally_active:
		return false
	if player and player.global_position.distance_to(n.global_position) < 3.5:
		return false
	for o in npcs:
		if o != n and o.state == "mortar":
			return false
	return true


func safe_sky_dir(n: Npc) -> Vector3:
	var c := Vector3.ZERO
	var cnt := 0
	for o in npcs:
		if o.global_position.distance_to(n.global_position) < 15.0:
			c += o.global_position
			cnt += 1
	var away := n.global_position - (c / maxf(cnt, 1))
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(0, 0, -1)
	return (away.normalized() * 0.35).rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))


# =================================================================== feu
## Foyer allumé le plus proche de `p` (à moins de `r` m)
func nearest_fire(p: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for fs in fire_srcs:
		if fs.burning and fs.global_position.distance_to(p) < bd:
			bd = fs.global_position.distance_to(p)
			best = fs
	return best


## Départ de feu spontané, rare : un manifestant décidé fait un feu au sol ou brûle une poubelle
func _update_arson(delta: float) -> void:
	_arson_cd -= delta
	if _arson_cd > 0.0 or player == null:
		return
	_arson_cd = 20.0
	var st := police.stage if police else 0
	var active := 0
	for fs in fire_srcs:
		if fs.burning:
			active += 1
	if active >= (2 if st < 3 else 3) or rally_active:
		return
	if _rng.randf() > 0.25 + excitement * 0.5 + 0.08 * float(st):
		return
	# les manifestants allument leurs feux d'eux-mêmes, de préférence (pas forcément) là où est le joueur
	var cands: Array[Npc] = []
	var near_player := _rng.randf() < 0.5
	for n in npcs:
		if n.state == "home" and n.role != "march" and n.prop == "" and n.bold > 0.6 and not n.busy() \
				and (not near_player or n.global_position.distance_to(player.global_position) < 40.0):
			cands.append(n)
	if cands.is_empty():
		return
	var who: Npc = cands[_rng.randi() % cands.size()]
	_arson_cd = _rng.randf_range(170.0, 340.0) / (1.0 + 0.4 * float(st))
	# une poubelle fermée, pas encore brûlée, à proximité ?
	if _rng.randf() < 0.3:
		for b in get_tree().get_nodes_in_group("bins"):
			var bin := b as TrashBin
			if not bin.burning and not bin.tipped and bin.contents > 0.5 and bin.global_position.distance_to(who.global_position) < 22.0 and bin.grabbed_by == null:
				who.make_fire(bin.global_position, bin)
				return
	# sinon un feu au sol, dans un coin dégagé
	for i in 12:
		var a := _rng.randf() * TAU
		var spot := clamp_area(who.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 8.0))
		if not nav.is_free(spot):
			continue
		if bus and spot.distance_to(bus.global_position) < 5.0:
			continue
		if spot.distance_to(player.global_position) < 3.0:
			continue
		var clear := true
		for fs in fire_srcs:
			if fs.global_position.distance_to(spot) < 4.5:
				clear = false
		if clear:
			who.make_fire(spot)
			return


func ring_point(n: Npc, bin: Node3D) -> Vector3:
	var lst: Array = _rings.get(bin, [])
	lst = lst.filter(func(x): return is_instance_valid(x) and (x as Npc).state in ["watch", "feed", "react"] and (x as Npc).data.get("bin") == bin)
	if not lst.has(n):
		lst.append(n)
	_rings[bin] = lst
	var i := lst.find(n)
	var cnt := maxi(lst.size(), 5)
	var base := float(bin.get_instance_id() % 100) * 0.1
	var ang := base + TAU * i / cnt
	var base_r := 2.0
	if bin.has_method("ring_radius"):
		base_r = float(bin.call("ring_radius"))
	var rad: float = base_r + float(bin.heat) * 0.8 + (0.6 if i >= 9 else 0.0) + (n.idx % 3) * 0.12
	var p: Vector3 = bin.global_position + Vector3(cos(ang), 0, sin(ang)) * rad
	return clamp_area(p)


func watchers(bin: Node3D) -> int:
	var c := 0
	for n in npcs:
		if n.state in ["watch", "feed"] and n.data.get("bin") == bin:
			c += 1
	return c


func reserve_burnable(n: Npc, near: Vector3, r: float) -> Burnable:
	var best: Burnable = null
	var bd := r
	for o in get_tree().get_nodes_in_group("burnables"):
		var b := o as Burnable
		if b.held or b.in_bin != null or b.lit or b._dying or b.fire != null:
			continue
		if b.reserved_by != null and is_instance_valid(b.reserved_by) and b.reserved_by != n:
			continue
		var d := b.global_position.distance_to(near)
		if d < bd and b.global_position.y < 1.0:
			bd = d
			best = b
	if best:
		best.reserved_by = n
	return best


# =================================================================== abribus
func attack_slot(n: Npc) -> Dictionary:
	if bus == null:
		return {}
	var cands: Array = []
	for i in bus.pane_count():
		if not bus.pane_alive(i):
			continue
		var c := bus.pane_center(i)
		# coups de pied : de derrière l'abribus ET de l'intérieur (côté rue)
		for off in [-0.28, 0.28]:
			for side in [0, 1]:
				var lp: Vector3
				var lf: Vector3
				if i <= 2:
					lp = Vector3(bus.pane_local_x(i) + off, 0, -1.55 if side == 0 else 0.1)
					lf = Vector3(bus.pane_local_x(i) + off, 1.0, -0.75)
				elif i == 3:
					lp = Vector3(-2.65 if side == 0 else -1.15, 0, off)
					lf = Vector3(-1.85, 1.0, off)
				else:
					lp = Vector3(2.5 if side == 0 else 1.05, 0, off)
					lf = Vector3(1.69, 1.0, off)
				cands.append({"kind": "kick", "pane": i, "pos": bus.to_global(lp), "face": bus.to_global(lf), "target": bus.to_global(lf), "key": "k%d%s%d" % [i, off, side]})
		for xo in [-3.2, -1.4, 0.4, 2.2]:
			var lp2 := Vector3(xo + float(i) * 0.15, 0, 6.2 + float(i % 2) * 0.9)
			var tgt := c + Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.35, 0.25), 0)
			cands.append({"kind": "throw", "pane": i, "pos": bus.to_global(lp2), "face": tgt, "target": tgt, "key": "t%d%s" % [i, xo]})
	# vague : on s'agrippe aux montants pour secouer (deux places par montant)
	if surge and not bus.collapsed:
		cands.clear()
		for px in [-1.85, 1.85]:
			for pz in [-0.75, 0.75]:
				for ang in [0.0, 1.0]:
					var outv := Vector3(signf(px) * (0.6 if ang == 0.0 else 0.2), 0, signf(pz) * (0.2 if ang == 0.0 else 0.6))
					var post := Vector3(px, 0, pz)
					cands.append({"kind": "shake", "pane": -1, "pos": bus.to_global(post + outv), "face": bus.to_global(post + Vector3.UP * 1.25),
						"target": bus.to_global(post + Vector3.UP * 1.25), "key": "s%s%s%s" % [px, pz, ang]})
	var taken := {}
	for k in _slots:
		if is_instance_valid(k) and k != n:
			taken[(_slots[k] as Dictionary)["key"]] = true
	var best: Dictionary = {}
	var bs := INF
	for c2 in cands:
		var cd: Dictionary = c2
		if taken.has(cd["key"]):
			continue
		var score: float = (cd["pos"] as Vector3).distance_to(n.global_position)
		var kicker: bool = (n.idx * 7 + 3) % 10 < 6      # 6 manifestants sur 10 préfèrent les coups de pied
		if cd["kind"] == "kick":
			score -= (11.0 if kicker else 1.0) + 5.0 * n.bold
		else:
			score -= (1.0 if kicker else 8.0) + 2.0 * (1.0 - n.bold)
		score += _rng.randf_range(0.0, 3.0)
		if score < bs:
			bs = score
			best = cd
	if not best.is_empty():
		_slots[n] = best
	return best


func free_slot(n: Npc) -> void:
	_slots.erase(n)


func _update_rally(delta: float) -> void:
	if not rally_active:
		return
	_rally_t += delta
	var near_bus := player != null and bus != null and player.global_position.distance_to(bus.global_position) < 18.0
	_rally_far_t = 0.0 if near_bus else _rally_far_t + delta
	if _rally_t > 75.0 or _rally_far_t > 12.0 or (bus and bus.all_broken() and not surge) or (bus and bus.collapsed):
		rally_active = false
		_slots.clear()
		return
	# les spectateurs encouragent
	if _cheer_cd <= 0.0:
		_cheer_cd = _rng.randf_range(2.5, 5.0)
		var cands: Array = npcs.filter(func(x): return (x as Npc).state == "home" and (x as Npc).global_position.distance_to(bus.global_position) < 26.0)
		if not cands.is_empty():
			var c: Npc = cands[_rng.randi() % cands.size()]
			c.react(c._prop_cheer_pose()[0], 2.0, bus.global_position + Vector3.UP * 1.2, {"voice": "allez" if _rng.randf() < 0.5 else "ouais", "prm": c._prop_cheer_pose()[1]})


func _update_bumps() -> void:
	if player == null or _bump_cd > 0.0:
		return
	var pv := Vector3(player.velocity.x, 0, player.velocity.z)
	if pv.length() < 3.0:
		return
	for n in npcs:
		if n.global_position.distance_to(player.global_position) < 0.75 and not n.busy():
			_bump_cd = 3.0
			n.human.kick_back(0.7)
			n.react("refuse", 1.8, player.global_position + Vector3.UP * 1.6, {"voice": "warn", "voice_p": 0.7})
			return


# =================================================================== événements
func on_event(type: String, d: Dictionary) -> void:
	match type:
		"mortar_aim":
			_ev_mortar_aim(d)
		"mortar_fire":
			_ev_mortar_fire(d)
		"burst":
			_ev_burst(d)
		"glass_hit":
			_ev_glass_hit(d)
		"glass_break":
			_ev_glass_break(d)
		"bus_destroyed":
			excitement = minf(excitement + 0.2, 1.0)
			_crowd_sound("applause", bus.global_position + Vector3(0, 1, 5), 0.0, 6.0)
		"fire_start":
			_ev_fire_start(d)
		"fire_flare":
			_ev_fire_flare(d)
		"lid":
			for n in _near(d["pos"], 8.0):
				if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.5:
					n.look(d["pos"], 1.0)
		"flare_lit":
			if d.get("player", false):
				_ev_player_flare(d["pos"], 0.45)
		"flare_raise":
			_ev_player_flare(d["pos"], 0.5)
			_gather(d["pos"], 3, 22.0)
		"car_vandal":
			_ev_car_vandal(d)
		"car_glass":
			excitement = minf(excitement + 0.05, 1.0)
			celebrate(d["pos"], 1)
			_crowd_sound("cheer_small", d["pos"], -4.0, 5.0)
			for n in _near(d["pos"], 20.0):
				if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.35:
					var pc := n._prop_cheer_pose()
					n.react(pc[0], 2.2, d["pos"] + Vector3.UP, {"voice": "ouais", "voice_p": 0.5, "prm": pc[1]})
		"car_burn":
			excitement = minf(excitement + 0.25, 1.0)
			later(0.5, func(): _crowd_sound("cheer_big", d["pos"], 0.0, 6.0))
			later(1.6, func(): _crowd_sound("applause", d["pos"], -4.0, 6.0))
		"petard_lit":
			for n in _near(d["pos"], 7.0):
				if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.4:
					n.look(d["pos"], 1.0)
		"petard_boom":
			_ev_petard_boom(d)
		"call":
			_ev_call(d)
		"player_gesture":
			_ev_player_gesture(d)
		"shop_open":
			_ev_shop_open(d)
		"shop_smash":
			excitement = minf(excitement + 0.02, 1.0)
			if _rng.randf() < 0.4:
				_crowd_sound("cheer_small", d["pos"], -6.0, 4.0)
			if police and police.tension:
				police.tension.add(0.01, "boutique saccagée")
		"bus_collapse":
			surge = false
			excitement = minf(excitement + 0.3, 1.0)
			celebrate(d["pos"], 4)
			later(0.4, func(): _crowd_sound("cheer_big", d["pos"] + Vector3.UP * 2.0, 2.0, 6.0))
			later(1.4, func(): _crowd_sound("applause", d["pos"] + Vector3.UP * 2.0, -2.0, 6.0))
			if police and police.tension:
				police.tension.add(0.05, "abribus effondré")
			if player:
				player.message.emit("L'abribus s'effondre !")
		"police_bang":
			# les boucliers claquent : les timides reculent d'un pas, les hardis répondent
			for n in _near(d["pos"], 30.0):
				n.look(d["pos"] + Vector3.UP * 1.4, 1.0)
				if n.bold < 0.45:
					n.scare(0.06)
				else:
					n.enrage(0.08)
					if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.3:
						var pc := n._prop_cheer_pose()
						n.react(pc[0], 2.0, d["pos"] + Vector3.UP * 1.5, {"voice": "defy", "voice_p": 0.4, "prm": pc[1]})
		"police_gas":
			mood_blast(d["pos"], 30.0, 0.1, 0.12)
			_ev_police_gas(d)
		"gas_land":
			mood_blast(d["pos"], 14.0, 0.4, 0.1)
			_ev_gas_land(d)
		"police_charge":
			_ev_charge(d)
		"police_stage":
			_ev_police_stage(d)
		"police_retreat":
			_ev_police_retreat(d)
		"police_lbd", "police_baton", "civil_hit":
			_ev_violence(type, d)
		"grab":
			_ev_grab(d)
		"boarded":
			_crowd_sound("crowd_boo", d["pos"], -2.0, 5.0)
		"kick_bus":
			for n in _near(d["pos"], 22.0):
				if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.35:
					var pc := n._prop_cheer_pose()
					n.react(pc[0] if n.bold > 0.55 else n._prop_rest_pose(), 1.6, d["pos"] + Vector3.UP, {"voice": "allez", "voice_p": 0.3 * n.bold, "prm": pc[1] if n.bold > 0.55 else {}})


## Les manifestants lancent des objets sur la police quand la situation s'envenime
func _update_hostility(delta: float) -> void:
	if police == null or police.stage < 2:
		return
	_throw_cd -= delta
	if _throw_cd > 0.0:
		return
	_throw_cd = _rng.randf_range(2.2, 4.5) / (1.0 + 0.5 * float(police.stage - 2))
	var cop_near: Cop = null
	var cands: Array[Npc] = []
	for n in npcs:
		if n.busy() or n.state != "home" or n.bold < 0.5 or n.prop in ["banner", "megaphone", "mortar"] or n.role in ["medic", "press"]:
			continue
		var c := police.nearest_cop(n.global_position, 30.0)
		if c == null:
			continue
		var d := c.global_position.distance_to(n.global_position)
		if d > 9.0 and d < 28.0:
			cands.append(n)
	if cands.is_empty():
		return
	# les plus en colère lancent le plus souvent
	var tot := 0.0
	for c2 in cands:
		tot += 0.15 + c2.anger + c2.hostile
	var pick := _rng.randf() * tot
	var n2: Npc = cands[0]
	for c2 in cands:
		pick -= 0.15 + c2.anger + c2.hostile
		if pick <= 0.0:
			n2 = c2
			break
	var tcop := police.nearest_cop(n2.global_position, 30.0)
	if tcop:
		n2.throw_at(tcop)


## Corps à corps : à partir du stade « AFFRONTEMENT », les plus enragés foncent sur un policier
func _update_brawls(delta: float) -> void:
	if police == null or police.stage < 3:
		return
	_brawl_cd -= delta
	if _brawl_cd > 0.0:
		return
	_brawl_cd = _rng.randf_range(10.0, 20.0) / (1.0 + 0.7 * float(police.stage - 3))
	var active := 0
	for n in npcs:
		if n.state == "brawl":
			active += 1
	if active >= 2:
		return
	var cands: Array[Npc] = []
	for n in npcs:
		if n.state == "home" and not n.busy() and n.anger > 0.5 and n.bold > 0.6 and n.fear < 0.4 and n.prop not in ["banner", "megaphone", "mortar"] and n.role not in ["medic", "press"]:
			cands.append(n)
	cands.shuffle()
	for n in cands:
		var c := police.nearest_cop(n.global_position, 16.0)
		if c == null or c.state in ["down", "arrest", "escort"]:
			continue
		var d := c.global_position.distance_to(n.global_position)
		if d > 3.0 and d < 15.0:
			n.start_brawl(c)
			return


## Le joueur lève le poing / applaudit : les voisins suivent
func _ev_player_gesture(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var kind: String = d["kind"]
	if kind == "hands":
		return
	var joined := 0
	for n in _near(p, 15.0):
		if joined >= 4 or n.busy() or n.state != "home" or n.react_cd > 0.0 or _rng.randf() > 0.45 + 0.3 * n.bold:
			continue
		joined += 1
		if kind == "dance":
			# ça danse autour de toi
			if n.prop == "" and n.fear < 0.4 and _rng.randf() < 0.7:
				n.react("dance", _rng.randf_range(4.0, 7.0), p + Vector3.UP * 1.6, {"voice": "ouais", "voice_p": 0.3, "prm": {"style": n.idx % 3}})
				n.stomp = true
			continue
		if kind == "wave":
			n.react("wave", 2.0, p + Vector3.UP * 1.6, {"voice": "ouais", "voice_p": 0.2})
			continue
		if kind == "finger":
			# les plus hardis l'imitent face à la police, les autres rigolent et encouragent
			var cops_at := police.line_c + Vector3.UP * 1.5 if police else p + Vector3.UP * 1.7
			if n.prop == "" and n.bold > 0.55 and _rng.randf() < 0.6:
				n.react("finger", 2.5, cops_at, {"voice": "defy", "voice_p": 0.5})
			else:
				n.react("clap" if n.prop == "" else n._prop_cheer_pose()[0], 2.5, p + Vector3.UP * 1.7, {"voice": "ouais", "voice_p": 0.4, "prm": {"gap": 0.1} if n.prop == "" else n._prop_cheer_pose()[1]})
		elif kind == "fist":
			n.react("fist" if n.prop == "" else n._prop_cheer_pose()[0], 3.0, p + Vector3.UP * 1.7, {"voice": "allez" if _rng.randf() < 0.5 else "ouais", "voice_p": 0.6, "prm": {"k": 1.0} if n.prop == "" else n._prop_cheer_pose()[1]})
		else:
			n.react("clap" if n.prop == "" else n._prop_cheer_pose()[0], 3.0, p + Vector3.UP * 1.7, {"voice": "bravo", "voice_p": 0.4, "prm": {"gap": 0.1} if n.prop == "" else n._prop_cheer_pose()[1]})
	if joined >= 2:
		excitement = minf(excitement + 0.04, 1.0)


func _ev_police_gas(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var voiced := 0
	for n in _near(p, 34.0):
		if n.busy() or n.state not in ["home", "react", "watch", "goto_look"] or n.react_cd > 0.0 and n.state == "react":
			continue
		if _rng.randf() < 0.6:
			n.react("cover", 1.6, p + Vector3.UP * 4.0, {"voice": "fear" if voiced < 2 else "", "voice_p": 0.6})
			voiced += 1
			n.go(clamp_area(n.global_position + n.flee_dir(p) * _rng.randf_range(3.0, 6.0)), true, 0.6)


func _ev_gas_land(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	excitement = minf(excitement + 0.1, 1.0)
	# un téméraire va ramasser la grenade et la renvoie aux CRS
	var g: GasGrenade = null
	for o in get_tree().get_nodes_in_group("gas_grenades"):
		if (o as Node3D).global_position.distance_to(p) < 1.5 and not (o as RigidBody3D).freeze:
			g = o as GasGrenade
			break
	if g != null:
		var best: Npc = null
		var bd := 10.0
		for n in npcs:
			if n.busy() or n.state not in ["home", "react"] or n.bold < 0.7 or n.anger < 0.3 or n.prop != "" or n.role in ["medic", "press"]:
				continue
			var dd := n.global_position.distance_to(p)
			if dd < bd:
				bd = dd
				best = n
		if best != null and _rng.randf() < 0.3 + 0.4 * best.anger:
			best.throw_back(g)
	_crowd_sound("crowd_gasp", p + Vector3.UP * 1.5, -2.0, 6.0)
	later(0.8, func(): _crowd_sound("crowd_gas", p + Vector3.UP * 1.5, -4.0, 8.0))


func _ev_violence(type: String, d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	mood_blast(p, 20.0, 0.25, 0.3, d.get("who"))
	var voiced := 0
	for n in _near(p, 22.0):
		if n == d.get("who") or n.busy() or n.state not in ["home", "react", "watch", "goto_look"]:
			continue
		var close := n.global_position.distance_to(p) < 9.0
		if n.bold > 0.65 and _rng.randf() < 0.55:
			n.hostile = minf(n.hostile + 0.25, 1.0)
			n.react("fist", 2.5, p + Vector3.UP, {"voice": "anger", "voice_p": 0.7 if voiced < 3 else 0.2, "prm": {"k": 1.0}})
			voiced += 1
		elif close and _rng.randf() < 0.5:
			n.react("cover", 1.8, p + Vector3.UP, {"voice": "fear", "voice_p": 0.5})
			n.go(clamp_area(n.global_position + n.flee_dir(p) * _rng.randf_range(3.0, 5.0)), true, 0.6)
		elif _rng.randf() < 0.4:
			n.react("head", 2.0, p + Vector3.UP, {})
	_crowd_sound("crowd_gasp", p + Vector3.UP * 1.5, -6.0, 6.0)


func _ev_grab(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	mood_blast(p, 24.0, 0.12, 0.4, d.get("who"))
	var cop: Node3D = d.get("cop")
	var voiced := 0
	for n in _near(p, 24.0):
		if n == d.get("who") or n.busy():
			continue
		if n.bold > 0.55 and _rescuers < 2 and cop != null and _rng.randf() < (0.55 if d.get("who") is Player else 0.3) and n.global_position.distance_to(p) < 16.0:
			_rescuers += 1
			if d.get("who") is Player:
				(d["who"] as Player).rescue_hold = 6.0
			n.rescue(cop)
			later(14.0, func(): _rescuers = maxi(_rescuers - 1, 0))
		elif n.state == "home" and _rng.randf() < 0.45:
			n.react("fist" if n.bold > 0.5 else "head", 2.5, p + Vector3.UP * 1.3, {"voice": "free", "voice_p": 0.7 if voiced < 3 else 0.15, "prm": {"k": 1.0}})
			voiced += 1
	_crowd_sound("crowd_anger", p + Vector3.UP * 1.5, -3.0, 6.0)
	# assez de monde autour : le « Libérez-le ! » est repris en chœur
	if voiced >= 2:
		later(1.4, func(): _crowd_sound("crowd_free", p + Vector3.UP * 1.5, -4.0, 12.0))


## Un événement marque les esprits : peur et colère montent autour de `p` (plus fort près du centre)
func mood_blast(p: Vector3, r: float, fear: float, anger: float, who: Variant = null) -> void:
	for n in npcs:
		if n == who or n.state in ["arrested", "boarded"]:
			continue
		var d := Vector2(n.global_position.x - p.x, n.global_position.z - p.z).length()
		if d > r:
			continue
		var k := 1.0 - d / r
		if fear > 0.0:
			n.scare(fear * k)
		if anger > 0.0:
			n.enrage(anger * k)


## La ligne se replie : soulagement, cris de joie, applaudissements
func _ev_police_retreat(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var voiced := 0
	for n in npcs:
		n.fear = maxf(n.fear - 0.25, 0.0)
		if n.state != "home" or n.busy() or n.human.sit > 0.3 or _rng.randf() > 0.55:
			continue
		var delay := _rng.randf_range(0.2, 2.5)
		var speak := voiced < 4 and _rng.randf() < 0.6
		if speak:
			voiced += 1
		later(delay, func():
			if not is_instance_valid(n) or n.busy():
				return
			var pc := n._prop_cheer_pose()
			n.react(pc[0], 2.8, p + Vector3.UP * 1.5, {"voice": ("bravo" if _rng.randf() < 0.5 else "ouais") if speak else "", "voice_p": 1.0, "hop": n.prop == "", "prm": pc[1]}))
	excitement = minf(excitement + 0.1, 1.0)
	celebrate(p, 3)
	_crowd_sound("cheer_big", p + Vector3.UP * 2.0, -3.0, 8.0)
	later(1.2, func(): _crowd_sound("applause", p + Vector3.UP * 2.0, -5.0, 8.0))


## La police se renforce : on la montre du doigt, on prévient les autres, la tension se lit sur les visages
func _ev_police_stage(d: Dictionary) -> void:
	var st: int = d["stage"]
	var p: Vector3 = d["pos"]
	var voiced := 0
	for n in npcs:
		if st >= 2:
			n.enrage(0.05 * float(st))
		if n.state != "home" or n.busy() or n.human.sit > 0.3:
			continue
		if _rng.randf() > 0.35 + 0.12 * float(st):
			continue
		var delay := _rng.randf_range(0.3, 3.0)
		var speak := voiced < 3 and _rng.randf() < 0.6
		if speak:
			voiced += 1
		later(delay, func():
			if not is_instance_valid(n) or n.busy():
				return
			var dir := n._wbd((p + Vector3.UP * 1.5 - n.head_pos()).normalized())
			if n.prop == "":
				n.react("point" if n.bold > 0.35 else "head", 2.6, p + Vector3.UP * 1.5, {"voice": "police" if speak else "", "voice_p": 1.0, "prm": {"dir": dir}})
			else:
				var pc := n._prop_cheer_pose()
				n.react(pc[0], 2.4, p + Vector3.UP * 1.5, {"voice": "police" if speak else "", "voice_p": 1.0, "prm": pc[1]}))


## Charge de la police : ceux qui sont devant détalent, les plus déterminés tiennent bon
func _ev_charge(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var voiced := 0
	mood_blast(p, 20.0, 0.5, 0.15)
	for n in _near(p, 15.0):
		if n.busy() or n.state not in ["home", "react", "watch", "goto_look"]:
			continue
		if n.fear > 0.55 or n.bold < 0.35:
			n.react("cover", 1.2, p + Vector3.UP * 1.5, {"voice": "retreat" if voiced < 2 else "", "voice_p": 0.7})
			n.go(clamp_area(n.global_position + n.flee_dir(p) * _rng.randf_range(5.0, 9.0)), true, 0.6)
			voiced += 1
		elif n.bold > 0.7 and _rng.randf() < 0.4:
			n.react("fist", 2.0, p + Vector3.UP * 1.5, {"voice": "defy", "voice_p": 0.7, "prm": {"k": 1.0}})


## Un nuage de gaz proche ? (pour éviter d'y aller ou y laisser son poste)
func gas_near(p: Vector3, margin := 0.0) -> Node3D:
	for c in _clouds:
		var g := c as GasCloud
		if g.fade() < 0.15:
			continue
		var d := Vector2(p.x - g.global_position.x, p.z - g.global_position.z).length()
		if d < g.radius + margin:
			return g
	return null


## Ramène un point d'attente hors des nuages de gaz (marge de 2 m) : on ne vient pas se poster dans le gaz
func safe_from_gas(p: Vector3) -> Vector3:
	for c in _clouds:
		var g := c as GasCloud
		if g.fade() < 0.15:
			continue
		var d := Vector2(p.x - g.global_position.x, p.z - g.global_position.z)
		var need := g.radius + 2.0
		if d.length() < need:
			var dir := d.normalized() if d.length() > 0.05 else Vector2.LEFT
			p.x = g.global_position.x + dir.x * need
			p.z = g.global_position.z + dir.y * need
	return p


## Les PNJ qui voient un nuage s'étendre vers eux reculent avant d'être pris dedans
func _update_gas_awareness(delta: float) -> void:
	_gas_aware_t -= delta
	if _gas_aware_t > 0.0:
		return
	_gas_aware_t = 0.45
	if _clouds.is_empty():
		return
	for n in npcs:
		if n.state not in ["home", "watch", "goto_look"] or n.react_cd > 0.0 or n.gas_level > 0.1:
			continue
		var g := gas_near(n.global_position, 2.8 + 1.4 * (1.0 - n.bold))
		if g != null:
			n.avoid_gas(g.global_position)


## Des manifestants arrivent par l'ouest pour remplacer les interpellés (et grossir le rang quand ça chauffe)
func _update_newcomers(delta: float) -> void:
	_newcomer_cd -= delta
	if _newcomer_cd > 0.0:
		return
	var st: int = police.stage if police != null else 0
	_newcomer_cd = _rng.randf_range(14.0, 24.0) if st >= 2 else _rng.randf_range(24.0, 38.0)
	var want := _initial_count + mini(st, 3)
	if npcs.size() >= want:
		return
	var n := Npc.new()
	var i := 100 + _newcomer_n
	_newcomer_n += 1
	var r := _rng.randf()
	n.idx = i
	n.crowd = self
	n.role = "march"
	n.slot = Vector2(_rng.randf_range(-2.2, 2.2), _rng.randf_range(5.2, 9.0))
	n.prop = "sign" if r < 0.3 else ("flare" if r < 0.37 else "")
	n.sign_idx = _rng.randi_range(1, 4)
	n.variant = VARIANTS[_rng.randi() % VARIANTS.size()]
	n.female = n.variant.begins_with("female")
	n.voice = "f1" if n.female else ("m1" if i % 2 == 0 else "m2")
	n.vpitch = _rng.randf_range(0.96, 1.1) if n.female else _rng.randf_range(0.92, 1.07)
	var mask := ""
	if n.prop == "flare":
		mask = "balaclava"
	elif _rng.randf() < 0.18:
		mask = "bandana"
	n.outfit = _outfit(_rng, n.female, mask, _rng.randf() < 0.15)
	n.smoker = n.prop == "" and _rng.randf() < 0.15
	n.bold = _rng.randf_range(0.25, 0.85)
	n.curious = _rng.randf_range(0.3, 0.95)
	n.calm = _rng.randf_range(0.2, 0.9)
	var start := Vector3(AREA_MIN.x + 1.0, 0.0, _rng.randf_range(-12.0, 6.0))
	n.home_pos = start
	n.position = Vector3(start.x, ground_y(start), start.z)
	add_child(n)
	npcs.append(n)
	actors.append(n)
	if _rng.randf() < 0.6:
		n.say_cat("join", true)


## Secours : un médic, ou à défaut un voisin courageux, vient en aide à chaque blessé
func _update_aid(delta: float) -> void:
	_aid_t -= delta
	if _aid_t > 0.0:
		return
	_aid_t = 1.0
	for pt in aid_pairs.keys():
		var h: Variant = aid_pairs[pt]
		if not is_instance_valid(pt) or not is_instance_valid(h) or (h as Npc).state != "aid":
			aid_pairs.erase(pt)
	var patients: Array = []
	for n in npcs:
		if NpcCare.needs_aid(n) and not aid_pairs.has(n):
			patients.append(n)
	if player != null and NpcCare.needs_aid(player) and not aid_pairs.has(player):
		patients.append(player)
	var helpers := 0
	for h2 in aid_pairs.values():
		if is_instance_valid(h2) and (h2 as Npc).role != "medic":
			helpers += 1
	for pt in patients:
		var best: Npc = null
		var bd := 55.0
		for m in npcs:
			if m.role == "medic" and m.state == "home" and m.fear < 0.7:
				var d := m.global_position.distance_to(pt.global_position)
				if d < bd:
					bd = d
					best = m
		var kind := "medic"
		if best == null and helpers < 2:
			bd = 10.0
			kind = "help"
			for m2 in npcs:
				if m2.role == "medic" or m2 == pt or m2.state != "home" or m2.busy() or m2.prop in ["mortar", "banner", "megaphone"]:
					continue
				if m2.calm < 0.45 or m2.bold < 0.25 or m2.fear > 0.5 or m2.human.sit > 0.3:
					continue
				var d2 := m2.global_position.distance_to(pt.global_position)
				if d2 < bd:
					bd = d2
					best = m2
		if best != null:
			aid_pairs[pt] = best
			if kind == "help":
				helpers += 1
			NpcCare.start(best, pt, kind)


func _near(p: Vector3, r: float) -> Array[Npc]:
	var out: Array[Npc] = []
	for n in npcs:
		if n.global_position.distance_to(p) < r:
			out.append(n)
	return out


func _ev_mortar_aim(d: Dictionary) -> void:
	var o: Vector3 = d["pos"]
	var dir: Vector3 = (d["dir"] as Vector3).normalized()
	var elev := asin(clampf(dir.y, -1.0, 1.0))
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var cheered := 0
	for n in npcs:
		if n.prop == "banner":
			continue
		var v := n.global_position + Vector3.UP * 1.2 - o
		var dist := v.length()
		if dist > 34.0:
			continue
		var along := v.dot(dir)
		var lateral := (v - dir * along).length()
		if elev < 0.5 and along > 0.3 and lateral < 1.3 + along * 0.1:
			if not n.busy() and n.state != "dodge":
				n.dodge(o, flat)
		elif elev > 0.55 and dist < 20.0 and n.react_cd <= 0.0 and n.state == "home" and _rng.randf() < 0.3 and cheered < 4:
			cheered += 1
			var sky := o + dir * 30.0
			if _rng.randf() < 0.35 and n.prop == "":
				n.react("film", _rng.randf_range(3.0, 5.0), sky, {"prm": {"dir": n._wbd((sky - n.head_pos()).normalized())}, "face": false})
			else:
				var pc := n._prop_cheer_pose()
				n.react(pc[0], 2.5, player.global_position + Vector3.UP * 1.6, {"voice": "allez" if _rng.randf() < 0.6 else "ouais", "voice_p": 0.45, "prm": pc[1]})
		elif dist < 9.0 and n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.25:
			n.look(player.global_position + Vector3.UP * 1.6, 1.0)


func _ev_mortar_fire(d: Dictionary) -> void:
	var o: Vector3 = d["pos"]
	var dir: Vector3 = (d["dir"] as Vector3).normalized()
	var elev := asin(clampf(dir.y, -1.0, 1.0))
	var panicked := 0
	for n in npcs:
		if n == d.get("npc"):
			continue
		var v := n.global_position + Vector3.UP * 1.2 - o
		var dist := v.length()
		if dist > 40.0:
			continue
		var along := v.dot(dir)
		var lateral := (v - dir * along).length()
		if elev < 0.45 and along > 0.0 and lateral < 2.0 + along * 0.12 and dist < 28.0 and n.prop != "banner":
			n.panic(o + dir * along, 1.0)
			panicked += 1
		elif elev >= 0.45 and dist < 24.0 and n.state == "home" and n.react_cd <= 0.0:
			_react_sky_shot(n, o, dir, dist)
		elif dist < 9.0 and n.react_cd <= 0.0:
			n.startle(o)
	if panicked >= 2:
		_crowd_sound("panic", o + dir * 8.0, 0.0, 5.0)
		excitement = minf(excitement + 0.1, 1.0)


## Tir vers le ciel : tout le monde ne fuit pas — certains s'écartent, d'autres applaudissent, filment,
## lèvent le poing, sursautent ou ne bougent pas (selon l'audace, le calme et la distance).
func _react_sky_shot(n: Npc, o: Vector3, dir: Vector3, dist: float) -> void:
	var sky := o + dir * 40.0
	var r := _rng.randf()
	var shy := (1.0 - n.calm) * 0.5 + (1.0 - n.bold) * 0.25
	var delay := _rng.randf_range(0.05, 0.5)
	if dist < 5.0 and r < 0.35 + shy * 0.3:
		later(delay, func():
			if is_instance_valid(n) and not n.busy():
				n.human.kick_back(0.9)
				var side := dir.cross(Vector3.UP).normalized()
				if (n.global_position - o).dot(side) < 0.0:
					side = -side
				n.dodge(o, dir if absf(dir.y) < 0.9 else side))
		return
	if r < 0.2 + shy * 0.2:
		later(delay, func(): if is_instance_valid(n): n.startle(o))
	elif r < 0.45:
		var pc := n._prop_cheer_pose()
		later(delay, func():
			if is_instance_valid(n):
				n.react(pc[0], _rng.randf_range(2.2, 3.4), sky, {"voice": "allez" if _rng.randf() < 0.5 else "ouais", "voice_p": 0.55, "prm": pc[1], "face": false}))
	elif r < 0.62:
		later(delay, func():
			if is_instance_valid(n):
				n.react("clap" if n.prop == "" else n._prop_rest_pose(), _rng.randf_range(2.4, 3.8), sky, {"voice": "ouais", "voice_p": 0.35, "face": false}))
	elif r < 0.74 and n.prop == "":
		later(delay, func():
			if is_instance_valid(n):
				n.react("film", _rng.randf_range(3.0, 5.0), sky, {"prm": {"dir": n._wbd((sky - n.head_pos()).normalized())}, "face": false}))
	elif r < 0.84:
		later(delay, func(): if is_instance_valid(n): n.look(sky, 1.0))
	# sinon : il ne bouge pas


func _ev_burst(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var count := 0
	var voiced := 0
	var low := p.y < 7.0
	for n in npcs:
		var dist := n.global_position.distance_to(p)
		if dist > 110.0:
			continue
		if low and dist < 8.0 and n.prop != "banner":
			later(_rng.randf_range(0.05, 0.25), func(): if is_instance_valid(n): n.panic(p, 1.2))
			continue
		count += 1
		var delay := _rng.randf_range(0.1, 0.6)
		var r := _rng.randf()
		var want_voice := voiced < 3 and _rng.randf() < 0.3
		if want_voice:
			voiced += 1
		if n.busy():
			later(delay, func(): if is_instance_valid(n): n.look(p, 1.0))
			continue
		later(delay, func():
			if not is_instance_valid(n):
				return
			var dur := _rng.randf_range(2.5, 4.5)
			var opt := {"face": false, "voice": "wow" if _rng.randf() < 0.6 else "ouais", "voice_p": 1.0 if want_voice else 0.0}
			if r < 0.3:
				var pc := n._prop_cheer_pose()
				opt["prm"] = pc[1]
				opt["hop"] = _rng.randf() < 0.35
				n.react(pc[0], dur, p, opt)
			elif r < 0.5 and n.prop == "":
				opt["prm"] = {"dir": n._wbd((p - n.head_pos()).normalized())}
				n.react("film", dur + 1.5, p, opt)
			elif r < 0.62:
				n.react("head", dur, p, opt)
			elif r < 0.75:
				opt["prm"] = {"dir": n._wbd((p - n.human.shoulder_world("R")).normalized())}
				n.react("point", dur * 0.7, p, opt)
			elif r < 0.85:
				n.react("clap", dur, p, opt)
			else:
				n.react(n._prop_rest_pose(), dur, p, opt))
	if count >= 5:
		var c := _centroid_near(p, 60.0)
		if low:
			_crowd_sound("panic", c, -2.0, 4.0)
		else:
			_crowd_sound("awe" if _rng.randf() < 0.55 else "cheer_small", c, -3.0, 3.5)
			if _rng.randf() < 0.3:
				later(1.2, func(): _crowd_sound("applause", c, -6.0, 6.0))
	excitement = minf(excitement + 0.04, 1.0)


func _centroid_near(p: Vector3, r: float) -> Vector3:
	var c := Vector3.ZERO
	var k := 0
	for n in npcs:
		if n.global_position.distance_to(p) < r:
			c += n.global_position
			k += 1
	return (c / k + Vector3.UP * 1.5) if k > 0 else p


func _ev_glass_hit(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	for n in _near(p, 26.0):
		if n.state == "home" and n.react_cd <= 0.0 and _rng.randf() < 0.45:
			if n.bold > 0.6 and _rng.randf() < 0.3:
				var pc := n._prop_cheer_pose()
				n.react(pc[0], 1.8, p, {"voice": "allez", "voice_p": 0.5, "prm": pc[1]})
			else:
				n.look(p, 1.0)


func _ev_glass_break(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	excitement = minf(excitement + 0.15, 1.0)
	var count := 0
	var voiced := 0
	for n in npcs:
		var dist := n.global_position.distance_to(p)
		if dist > 38.0:
			continue
		count += 1
		if n.state == "rally":
			if voiced < 3:
				voiced += 1
				later(_rng.randf_range(0.2, 0.6), func(): if is_instance_valid(n): n.say_cat("broke", true))
			n.hop(2)
			continue
		if n.busy():
			n.look(p, 1.0)
			continue
		var delay := _rng.randf_range(0.05, 0.4)
		if dist < 4.5:
			later(delay, func(): if is_instance_valid(n): n.startle(p))
			continue
		var want_voice := voiced < 3 and _rng.randf() < 0.35
		if want_voice:
			voiced += 1
		later(delay, func():
			if not is_instance_valid(n):
				return
			var opt := {"voice": "broke" if _rng.randf() < 0.6 else "ouais", "voice_p": 1.0 if want_voice else 0.0}
			if n.bold > 0.45 or _rng.randf() < 0.3:
				var pc := n._prop_cheer_pose()
				opt["prm"] = pc[1]
				opt["hop"] = _rng.randf() < 0.5
				n.react(pc[0], 2.8, p, opt)
			elif n.curious > 0.6 and _rng.randf() < 0.5 and n.role != "march":
				n.state = "goto_look"
				n.state_t = 0.0
				n.data = {"look": p}
				var away := (n.global_position - p)
				away.y = 0.0
				n.go(clamp_area(p + away.normalized() * 6.0), false, 0.5)
				n.set_act("film", {"dir": Vector3(0, 0, 1)}, 2.0)
			else:
				n.react("head", 2.5, p, opt))
	if count >= 3:
		_crowd_sound("cheer_big", _centroid_near(p, 30.0), 0.0, 3.0)
	if bus and bus.all_broken():
		later(1.0, func(): on_event("bus_destroyed", {}))


func _ev_fire_start(d: Dictionary) -> void:
	var bin: Node3D = d.get("bin") if d.has("bin") else d.get("car_node")
	if bin == null:
		return
	var p: Vector3 = d["pos"]
	excitement = minf(excitement + 0.1, 1.0)
	var watchers_n := watchers(bin)
	var feeders := 0
	var voiced := 0
	var cands := _near(p, 32.0)
	cands.shuffle()
	for n in cands:
		if n.busy() or n.prop in ["banner", "megaphone"] or n.role == "march" and _rng.randf() < 0.75:
			if n.state == "home" and n.react_cd <= 0.0:
				n.look(p, 1.0)
			continue
		if n.curious < 0.3 or _rng.randf() > 0.75 or watchers_n >= 11:
			if n.react_cd <= 0.0 and n.state == "home":
				n.react(n._prop_rest_pose(), 2.0, p, {})
			continue
		watchers_n += 1
		if n.bold > 0.5 and feeders < 3 and n.prop == "" and _rng.randf() < 0.55 and bin.has_method("can_take_items") and bin.can_take_items():
			feeders += 1
			n.feed_fire(bin)
		else:
			n.watch_fire(bin, ring_point(n, bin))
		if voiced < 2 and _rng.randf() < 0.5:
			voiced += 1
			later(_rng.randf_range(0.3, 1.2), func(): if is_instance_valid(n): n.say_cat("fire", true))
	if _rng.randf() < 0.7:
		later(0.6, func(): _crowd_sound("awe", p + Vector3.UP, -6.0, 6.0))


func _ev_fire_flare(d: Dictionary) -> void:
	var bin: Node3D = d["bin"]
	var voiced := 0
	for n in npcs:
		if n.state == "watch" and n.data.get("bin") == bin:
			n.data["next"] = _rng.randf_range(2.5, 4.5)
			var pc := n._prop_cheer_pose()
			n.set_act(pc[0] if _rng.randf() < 0.6 else "head", pc[1], 4.0)
			if voiced < 2 and _rng.randf() < 0.4:
				voiced += 1
				n.say_cat("fire" if _rng.randf() < 0.5 else "ouais", true)
	# de nouveaux curieux arrivent quand ça flambe
	if watchers(bin) < 8:
		for n in _near(d["pos"], 25.0):
			if n.state == "home" and n.role != "march" and n.curious > 0.5 and _rng.randf() < 0.3:
				n.watch_fire(bin, ring_point(n, bin))


## Un pétard explose : sursaut des plus proches (certains reculent, d'autres s'écartent ou rient), les autres
## tournent la tête, applaudissent, filment ou font semblant de rien. Le son met un peu de temps à arriver.
func _ev_petard_boom(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var big: bool = int(d.get("size", 1)) >= 2
	var reach := 32.0 if big else 15.0
	var near_r := 6.5 if big else 3.2
	var voiced := 0
	var scared := 0
	for n in npcs:
		var dist := n.global_position.distance_to(p)
		if dist > reach or n.state in ["arrested", "boarded", "gassed", "hit", "sprayed", "mortar", "throwcop", "rescue"]:
			continue
		var near := dist < near_r
		var delay := dist / 340.0 * 0.4 + _rng.randf_range(0.0, 0.25)
		var r := _rng.randf()
		var speak := voiced < 3 and _rng.randf() < 0.35
		if speak:
			voiced += 1
		later(delay, func():
			if not is_instance_valid(n):
				return
			if n.busy() and not (near and n.state in ["react", "home"]):
				n.look(p, 1.0)
				return
			if near:
				var away := n.global_position - p
				away.y = 0.0
				if speak:
					n.say_cat("petard", true)
				if r < 0.45 or (n.calm < 0.35 and r < 0.7):
					n.panic(p, 0.45 if not big else 0.8)
					scared += 1
				elif r < 0.75:
					n.dodge(p, away.normalized().cross(Vector3.UP))
				elif n.bold > 0.6:
					var pc := n._prop_cheer_pose()
					n.react(pc[0], 2.2, p, {"voice": "ouais", "voice_p": 0.7, "hop": true, "prm": pc[1]})
				else:
					n.startle(p)
				return
			var pose_r := r * 1.0 + (0.25 - n.calm * 0.25)
			if pose_r < 0.30:
				n.human.kick_back(0.5)
				n.react("head" if n.prop == "" else n._prop_rest_pose(), _rng.randf_range(1.6, 2.6), p, {"voice": ("petard" if _rng.randf() < 0.4 else "wow") if speak else "", "voice_p": 1.0 if speak else 0.0})
			elif pose_r < 0.5 and n.bold > 0.45:
				var pc2 := n._prop_cheer_pose()
				n.react(pc2[0], _rng.randf_range(1.6, 2.8), p, {"voice": "ouais" if speak else "", "voice_p": 1.0 if speak else 0.0, "prm": pc2[1]})
			elif pose_r < 0.65 and n.prop == "":
				n.react("film", _rng.randf_range(2.5, 4.5), p, {"prm": {"dir": n._wbd((p + Vector3.UP * 0.5 - n.head_pos()).normalized())}, "face": false})
			elif pose_r < 0.8:
				n.startle(p)
			else:
				n.look(p, 1.0))
	if scared >= 3 or (big and reach > 0.0 and _rng.randf() < 0.5):
		_crowd_sound("panic" if big else "awe", p, -4.0, 6.0)
	excitement = minf(excitement + (0.05 if big else 0.02), 1.0)


## Quelqu'un s'en prend à une voiture de police : les audacieux viennent donner des coups de pied dans les
## portières ou jeter des pierres sur les vitres ; les autres encouragent, filment, reculent.
func _ev_car_vandal(d: Dictionary) -> void:
	var car: PoliceVehicle = d.get("car")
	if car == null or not is_instance_valid(car):
		return
	var p: Vector3 = d["pos"]
	var attackers := 0
	for n in npcs:
		if n.state == "carattack" and n.data.get("car") == car:
			attackers += 1
	var cap := 2 + int(excitement * 4.0) + (2 if d.get("player", false) else 0)
	var cands := _near(p, 32.0)
	cands.sort_custom(func(a, b): return (a as Npc).global_position.distance_to(p) < (b as Npc).global_position.distance_to(p))
	var joined := 0
	for n in cands:
		if attackers >= cap or joined >= 3:
			break
		if n.state != "home" or n.busy() or n.prop in ["banner", "megaphone", "mortar"] or (n.role == "march" and _rng.randf() < 0.7):
			continue
		var dist := n.global_position.distance_to(p)
		var pj := 0.1 + n.bold * 0.55 + excitement * 0.25 + (0.2 if n.role == "bloc" else 0.0) - dist * 0.012
		if d.get("player", false):
			pj += 0.2     # « suis-moi » : on aide celui qui est monté sur le capot
		if _rng.randf() < pj:
			attackers += 1
			joined += 1
			later(_rng.randf_range(0.3, 1.4), func():
				if is_instance_valid(n) and is_instance_valid(car):
					n.say_cat("join", true)
					n.attack_car(car))
		elif dist < 20.0 and n.react_cd <= 0.0 and _rng.randf() < 0.45:
			if n.prop == "" and _rng.randf() < 0.4:
				n.react("film", _rng.randf_range(3.0, 5.0), p, {"prm": {"dir": n._wbd((p + Vector3.UP - n.head_pos()).normalized())}, "face": false})
			else:
				var pc := n._prop_cheer_pose()
				n.react(pc[0], 2.4, p, {"voice": "vandal" if _rng.randf() < 0.5 else ("allez" if _rng.randf() < 0.5 else "ouais"), "voice_p": 0.45, "prm": pc[1]})


## Initiative rare : un manifestant décidé donne un coup de pied dans un cône, une barrière, un panneau...
func _update_vandalism(delta: float) -> void:
	_vandal_cd -= delta
	if _vandal_cd > 0.0 or player == null:
		return
	_vandal_cd = _rng.randf_range(16.0, 38.0) / (0.5 + excitement)
	var active := 0
	for n in npcs:
		if n.state == "vandal":
			active += 1
	if active >= 2:
		return
	var cands: Array[Npc] = []
	for n in npcs:
		if n.state == "home" and not n.busy() and n.bold > 0.55 and n.prop == "" and n.role != "march" and _rng.randf() < 0.5:
			cands.append(n)
	cands.shuffle()
	for n in cands.slice(0, 6):
		var t := _vandal_target(n)
		if t != null:
			n.start_vandal(t)
			return


## Une voiture de police mal gardée près de la foule : des enragés s'en prennent à elle d'eux-mêmes
func _update_car_attacks(delta: float) -> void:
	if police == null or police.stage < 2:
		return
	_carat_cd -= delta
	if _carat_cd > 0.0:
		return
	_carat_cd = _rng.randf_range(14.0, 30.0) / (0.6 + excitement + 0.2 * float(police.stage - 2))
	var active := 0
	for n in npcs:
		if n.state == "carattack":
			active += 1
	if active >= 2:
		return
	for v in police.vehicles:
		# seulement une voiture du côté de la foule (celles garées derrière la ligne sont hors d'atteinte)
		if not is_instance_valid(v) or not v.is_parked() or v.burning or v.global_position.x > area_max_x() + 1.5:
			continue
		var guard := police.nearest_cop(v.global_position, 8.0)
		if guard != null:
			continue
		var best: Npc = null
		var bd := 26.0
		for n in npcs:
			if n.state != "home" or n.busy() or n.bold < 0.6 or n.anger < 0.4 or n.fear > 0.4 or n.prop != "" or n.role in ["march", "medic", "press"]:
				continue
			var d := n.global_position.distance_to(v.global_position)
			if d < bd:
				bd = d
				best = n
		if best != null:
			best.attack_car(v)
			return


## Boutiques : quand la tension monte, des casseurs s'attaquent aux vitrines (la banque d'abord) ; une
## vitrine ouverte attire les pilleurs, qui entrent et saccagent tout.
func _update_looting(delta: float) -> void:
	_loot_cd -= delta
	if _loot_cd > 0.0:
		return
	_loot_cd = _rng.randf_range(6.0, 12.0)
	var shops := get_tree().get_nodes_in_group("shops")
	if shops.is_empty():
		return
	var looters := 0
	for n in npcs:
		if n.state == "loot":
			looters += 1
	if looters >= MAX_LOOTERS:
		return
	var hot := (police != null and police.stage >= 2) or excitement > 0.7
	var c := cortege_center()
	var best: Shop = null
	var bs := -1e9
	for o in shops:
		var s := o as Shop
		if not s.is_inside_tree() or s.global_position.x > area_max_x() - 2.0:
			continue
		var d := s.global_position.distance_to(c)
		if d > 34.0:
			continue
		var score := -d
		if s.is_open():
			if not s.has_loot():
				continue
			score += 25.0                        # vitrine déjà ouverte : ça attire
		elif not hot:
			continue                             # on ne s'attaque aux vitrines que quand ça chauffe
		elif s.kind == "banque":
			score += 12.0
		if score > bs:
			bs = score
			best = s
	if best == null:
		return
	var want := 2 if best.is_open() else (1 if _rng.randf() < 0.6 else 2)
	_recruit_looters(best, mini(want, MAX_LOOTERS - looters))


func _recruit_looters(s: Shop, count: int) -> void:
	var cands: Array[Npc] = []
	for n in npcs:
		if n.state != "home" or n.busy() or n.prop != "" or n.role in ["march", "medic", "press"] or n.fear > 0.45:
			continue
		if n.bold < (0.45 if s.is_open() else 0.6):
			continue
		if n.global_position.distance_to(s.global_position) > 30.0:
			continue
		cands.append(n)
	cands.sort_custom(func(a, b): return a.global_position.distance_squared_to(s.global_position) < b.global_position.distance_squared_to(s.global_position))
	for n in cands.slice(0, count):
		NpcLoot.start(n, s)


func _ev_shop_open(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	excitement = minf(excitement + 0.2, 1.0)
	later(0.3, func(): _crowd_sound("cheer_big", p + Vector3.UP * 1.5, 0.0, 5.0))
	if police and police.tension:
		police.tension.add(0.06, "vitrine brisée")
	if police:
		police.feel(0.08)
	if player and player.global_position.distance_to(p) < 30.0:
		player.message.emit("La vitrine a cédé : la boutique est ouverte !")
	# la brèche attire du monde : quelques-uns s'engouffrent tout de suite
	var looters := 0
	for n in npcs:
		if n.state == "loot":
			looters += 1
	var s: Shop = d.get("shop")
	if s != null and is_instance_valid(s):
		_recruit_looters(s, mini(_rng.randi_range(2, 4), MAX_LOOTERS - looters))


## Tags : de temps en temps, un manifestant sort une bombe de peinture
func _update_tags(delta: float) -> void:
	_tag_cd -= delta
	if _tag_cd > 0.0:
		return
	_tag_cd = _rng.randf_range(18.0, 40.0) / (0.6 + excitement)
	var st := police.stage if police else 0
	if st >= 4:
		return
	for n in npcs:
		if n.state == "tag":
			return
	var cands: Array[Npc] = []
	for n in npcs:
		if n.state == "home" and not n.busy() and n.bold > 0.5 and n.fear < 0.4 and n.prop == "" and n.role not in ["march", "medic", "press"]:
			cands.append(n)
	if cands.is_empty():
		return
	var who: Npc = cands[_rng.randi() % cands.size()]
	NpcTag.start(who, NpcTag.pick_spot(who))


## Petite victoire : des voisins se tapent dans la main (jusqu'à `pairs` paires autour de `p`)
func celebrate(p: Vector3, pairs: int) -> void:
	var done := 0
	var used := {}
	for n in _near(p, 25.0):
		if done >= pairs:
			return
		if used.has(n) or n.busy() or n.state != "home" or n.prop != "" or n.human.sit > 0.3:
			continue
		for o in neighbors(n.global_position, 1.6):
			if o == n or not (o is Npc) or used.has(o):
				continue
			var m := o as Npc
			if m.busy() or m.state != "home" or m.prop != "" or m.human.sit > 0.3:
				continue
			var meet := (n.head_pos() + m.head_pos()) * 0.5 + Vector3.UP * 0.25
			var dl := _rng.randf_range(0.1, 1.2)
			later(dl, func():
				if is_instance_valid(n) and is_instance_valid(m) and not n.busy() and not m.busy():
					n.react("highfive", 1.4, m.head_pos(), {"prm": {"target": n._wb(meet)}, "voice": "ouais", "voice_p": 0.4})
					m.react("highfive", 1.4, n.head_pos(), {"prm": {"target": m._wb(meet)}})
					AudioLib.play_at(n, "clap_%d" % _rng.randi_range(0, 2), meet, -4.0, 6.0))
			used[n] = true
			used[m] = true
			done += 1
			break


func add_tag(lab: Label3D) -> void:
	_tags.append(lab)
	while _tags.size() > NpcTag.MAX_TAGS:
		var old: Label3D = _tags.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## Quelqu'un est terrorisé : un voisin calme vient lui poser la main sur l'épaule, ça l'apaise un peu
func _update_comfort(delta: float) -> void:
	_comfort_cd -= delta
	if _comfort_cd > 0.0:
		return
	_comfort_cd = _rng.randf_range(2.0, 4.0)
	for n in npcs:
		if n.fear < 0.65 or n.state not in ["home", "react"]:
			continue
		for o in neighbors(n.global_position, 1.3):
			if not (o is Npc) or o == n:
				continue
			var m := o as Npc
			if m.busy() or m.state != "home" or m.fear > 0.35 or m.react_cd > 0.0 or m.prop != "":
				continue
			var sh := n.human.shoulder_world("L" if (n.global_position - m.global_position).dot(m.global_basis.x) > 0.0 else "R")
			m.react("comfort", 3.0, n.head_pos(), {"prm": {"target": m._wb(sh)}, "voice": "calm", "voice_p": 0.5})
			n.fear = maxf(n.fear - 0.25, 0.0)
			n.look(m.head_pos(), 1.0)
			return


## Face-à-face : on provoque la ligne (doigt d'honneur, poing levé, insultes)
func _update_taunts(delta: float) -> void:
	if police == null or police.stage < 1 or not standoff.active:
		return
	_taunt_cd -= delta
	if _taunt_cd > 0.0:
		return
	_taunt_cd = _rng.randf_range(2.5, 6.0) / (0.6 + excitement)
	var at := police.line_c + Vector3.UP * 1.5
	var cands: Array[Npc] = []
	for n in _near(standoff.center, 16.0):
		if n.state == "home" and not n.busy() and n.react_cd <= 0.5 and n.anger >= 0.3 and n.fear <= 0.55 \
				and n.prop not in ["banner", "megaphone", "mortar"]:
			cands.append(n)
	if cands.is_empty():
		return
	var n2: Npc = cands[_rng.randi() % cands.size()]
	# doigt d'honneur (mains libres) ou poing / pancarte brandie
	var pose := "finger" if n2.prop == "" and _rng.randf() < 0.45 * n2.bold + 0.25 else "fist"
	n2.react(pose, _rng.randf_range(1.8, 3.0), at, {"voice": "defy", "voice_p": 0.5, "prm": {"k": 1.0}})
	if pose == "finger":
		n2.hostile = minf(n2.hostile + 0.06, 0.3)      # les CRS repèrent les provocateurs


## Quand la police avance pour de bon, des manifestants montent une barricade avec les barrières qui traînent
func _update_barricade(delta: float) -> void:
	# places libérées : barrière renversée, déplacée, ou porteur qui a renoncé
	var any := false
	for i in BARRICADE_Z.size():
		var b: Variant = _barricade[i]
		if b != null and (not is_instance_valid(b) or (b as Barrier).is_down() or not (b as Barrier).barricade):
			_barricade[i] = null
		var h: Variant = _barricade_by[i]
		if h != null and (not is_instance_valid(h) or (h as Npc).state != "barricade" or int((h as Npc).data.get("i", -1)) != i):
			_barricade_by[i] = null
		any = any or _barricade[i] != null or _barricade_by[i] != null
	if police == null:
		return
	# la ligne est passée (ou tout est à terre) : la prochaine barricade se montera ailleurs
	if not is_nan(barricade_x) and (not any or police.line_c.x < barricade_x + 1.0):
		barricade_x = NAN
	_barricade_cd -= delta
	if _barricade_cd > 0.0 or police.stage < 2:
		return
	_barricade_cd = _rng.randf_range(8.0, 20.0) / (0.5 + excitement)
	var builders := 0
	for h in _barricade_by:
		if h != null:
			builders += 1
	if builders >= 2:
		return
	var slot_i := -1
	for i in BARRICADE_Z.size():
		if _barricade[i] == null and _barricade_by[i] == null:
			slot_i = i
			break
	if slot_i < 0:
		return
	var bx := barricade_x
	if is_nan(bx):
		bx = clampf(police.line_c.x - 8.5, AREA_MIN.x + 14.0, 50.0)
	if bx > area_max_x() - 2.0:
		return
	# barrière disponible (pas celles du barrage de police, derrière la ligne)
	var free: Array[Barrier] = []
	for o in get_tree().get_nodes_in_group("barriers"):
		var bb := o as Barrier
		if bb == null or bb.is_busy() or bb.barricade or bb.global_position.x > area_max_x() - 1.5:
			continue
		free.append(bb)
	if free.is_empty():
		return
	# bâtisseur : un manifestant hardi, mains libres, pas en plein cortège
	var best: Npc = null
	var best_b: Barrier = null
	var bd := 32.0
	for n in npcs:
		if n.state != "home" or n.busy() or n.bold < 0.6 or n.fear > 0.5 or n.prop != "" or n.role in ["march", "medic", "press"]:
			continue
		for bb in free:
			var d := n.global_position.distance_to(bb.global_position)
			if d < bd:
				bd = d
				best = n
				best_b = bb
	if best == null:
		return
	barricade_x = bx
	_barricade_by[slot_i] = best
	NpcBarricade.start(best, best_b, Vector3(bx, 0.0, BARRICADE_Z[slot_i]), PI * 0.5 + _rng.randf_range(-0.07, 0.07), slot_i)


func on_barricade_set(b: Barrier, i: int, by: Npc) -> void:
	if i >= 0 and i < _barricade.size():
		_barricade[i] = b
		if _barricade_by[i] == by:
			_barricade_by[i] = null
	_crowd_sound("cheer_small", b.global_position + Vector3.UP * 1.5, -6.0, 6.0)
	if police and police.tension:
		police.tension.add(0.01, "barricade")


## Éléments de barricade encore debout juste devant la ligne de police (à moins de `ahead` mètres)
func barricade_ahead(line_x: float, ahead: float) -> Array[Barrier]:
	var out: Array[Barrier] = []
	for b in _barricade:
		if b == null or not is_instance_valid(b):
			continue
		var bb := b as Barrier
		var dx := line_x - bb.global_position.x
		if bb.barricade and not bb.is_down() and dx > -0.5 and dx < ahead:
			out.append(bb)
	return out


func _vandal_target(n: Npc) -> Node3D:
	var best: Node3D = null
	var bd := 14.0
	for o in get_tree().get_nodes_in_group("kickable"):
		if o is TrashBin or o is Burnable or o is PoliceVehicle or o is ShopItem or not (o is Node3D):
			continue
		if o is StreetProp and (o as StreetProp).toppled:
			continue
		if o is Barrier and ((o as Barrier).is_down() or (o as Barrier).barricade or (o as Barrier).is_busy()):
			continue
		var dd := (o as Node3D).global_position.distance_to(n.global_position)
		if dd < bd:
			bd = dd
			best = o
	return best


func _ev_player_flare(p: Vector3, chance: float) -> void:
	var voiced := 0
	for n in _near(p, 16.0):
		if n.state != "home" or n.react_cd > 0.0 or _rng.randf() > chance:
			continue
		var opt := {"voice": "ouais" if _rng.randf() < 0.5 else "allez", "voice_p": 1.0 if voiced < 2 else 0.0}
		voiced += 1
		if _rng.randf() < 0.3 and n.prop == "":
			opt["prm"] = {"dir": n._wbd((p + Vector3.UP - n.head_pos()).normalized())}
			n.react("film", 4.0, p + Vector3.UP, opt)
		else:
			var pc := n._prop_cheer_pose()
			opt["prm"] = pc[1]
			n.react(pc[0], 2.5, p + Vector3.UP * 1.2, opt)


## Mouvement de foule : quelques curieux s'approchent pour voir (et filmer)
func _gather(p: Vector3, count: int, r: float) -> void:
	var n_ok := 0
	var cands := _near(p, r)
	cands.shuffle()
	for n in cands:
		if n_ok >= count:
			break
		if n.state != "home" or n.role == "march" or n.prop in ["banner", "megaphone", "mortar"]:
			continue
		if n.global_position.distance_to(p) < 4.0 or _rng.randf() > n.curious:
			continue
		n_ok += 1
		var away := n.global_position - p
		away.y = 0.0
		var dest := p + away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)) * _rng.randf_range(2.8, 4.0)
		n.state = "goto_look"
		n.state_t = 0.0
		n.data = {"look": p + Vector3.UP * 1.5}
		n.go(clamp_area(dest), false, 0.5)


func _ev_call(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	if bus == null:
		return
	if bus.all_broken():
		player.message.emit("L'abribus est déjà en morceaux !")
		for n in _near(p, 15.0):
			if n.state == "home" and _rng.randf() < 0.4:
				var pc := n._prop_cheer_pose()
				n.react(pc[0], 2.0, p + Vector3.UP * 1.6, {"voice": "ouais", "voice_p": 0.3, "prm": pc[1]})
		return
	var near_bus := p.distance_to(bus.global_position) < 22.0
	var cap := 3 + int(excitement * 5.0) + (1 if near_bus else 0)
	# de temps en temps l'appel prend : grand mouvement de foule, on va secouer l'abribus jusqu'à le faire tomber
	surge = false
	if not bus.collapsed and near_bus and _near(p, 45.0).size() >= 10 and _rng.randf() < 0.25 + 0.45 * excitement:
		surge = true
		cap = 10 + int(excitement * 6.0)
	var joiners := 0
	var already := 0
	for n in npcs:
		if n.state == "rally":
			already += 1
	var cands := _near(p, 45.0 if surge else 28.0)
	cands.sort_custom(func(a, b): return (a as Npc).global_position.distance_to(p) < (b as Npc).global_position.distance_to(p))
	var refusers := 0
	for n in cands:
		if n.state == "rally":
			continue
		if n.prop in ["banner", "megaphone"] or n.state in ["mortar", "panic", "feed"]:
			if n.react_cd <= 0.0:
				n.look(p + Vector3.UP * 1.6, 1.0)
			continue
		var dist := n.global_position.distance_to(p)
		var pj := 0.12 + n.bold * 0.6 + excitement * 0.3 + (0.25 if n.role == "bloc" else 0.0) - dist * 0.012 + (0.35 if surge else 0.0)
		if n.role == "march":
			pj -= 0.15
		if joiners + already < cap and _rng.randf() < pj:
			joiners += 1
			var delay := _rng.randf_range(0.2, 0.9)
			later(delay, func():
				if is_instance_valid(n):
					n.say_cat("join", true)
					n.rally(bus))
		elif dist < 14.0 and refusers < 3 and _rng.randf() < 0.55:
			refusers += 1
			later(_rng.randf_range(0.3, 1.0), func():
				if is_instance_valid(n):
					n.react("refuse", 2.4, p + Vector3.UP * 1.6, {"voice": "refuse", "voice_p": 0.7})
					n.human.shake = 1.0
					get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(n): n.human.shake = 0.0))
		elif n.state == "home" and n.react_cd <= 0.0:
			n.look(p + Vector3.UP * 1.6, 1.0)
	if joiners > 0:
		rally_active = true
		_rally_t = 0.0
		_rally_far_t = 0.0
		excitement = minf(excitement + 0.1, 1.0)
		later(0.8, func(): _crowd_sound("cheer_small", p + Vector3.UP * 1.5, -2.0, 3.0))
		if surge:
			player.message.emit("La foule déferle sur l'abribus ! (%d manifestants)" % joiners)
			_crowd_sound("crowd_anger", p + Vector3.UP * 1.5, 0.0, 3.0)
		else:
			player.message.emit(("%d manifestants te suivent !" % joiners) if joiners > 1 else "Un manifestant te suit !")
	elif already > 0:
		player.message.emit("Ils sont déjà avec toi !")
	else:
		player.message.emit("Personne ne te suit… pour l'instant")
