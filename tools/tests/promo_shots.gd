extends SceneTree
## Photos promotionnelles (sans interface) : cortège, fumigène, feu, ligne de CRS, gaz, vue large.
## Rendu en paysage, puis recadrage au centre si un format est demandé (ex. 9:16 pour TikTok) :
##   xvfb-run -a -s "-screen 0 3414x1920x24" godot --path . --fixed-fps 30 --resolution 3414x1920 -s tools/tests/promo_shots.gd -- <dossier> [9:16]
## Le rendu est coupé entre deux photos pour aller vite.
var frame := 0
var main: Node
var crowd: Crowd
var pol: Police
var ten: Tension
var cam: Camera3D
var out_dir := "user://promo"
var ratio := 0.0       # largeur / hauteur du recadrage (0 = image entière)
var _pending := []     # [frame, nom]
var _fire_at := Vector3(5.6, 0, -0.6)
var _gas_at := Vector3.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1 and args[1].contains(":"):
		var p := args[1].split(":")
		ratio = float(p[0]) / float(p[1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	RenderingServer.render_loop_enabled = false


func _hide_ui() -> void:
	for n in main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false


## Place la caméra : position, cible, champ vertical, mise au point (0 = sans flou)
func _cam(pos: Vector3, look: Vector3, fov := 40.0, focus := 0.0) -> void:
	cam.global_position = pos
	cam.look_at(look)
	cam.fov = fov
	var at := CameraAttributesPractical.new()
	if focus > 0.0:
		at.dof_blur_far_enabled = true
		at.dof_blur_far_distance = focus + 2.5
		at.dof_blur_far_transition = 14.0
		at.dof_blur_near_enabled = true
		at.dof_blur_near_distance = maxf(focus - 2.0, 0.3)
		at.dof_blur_near_transition = 1.0
		at.dof_blur_amount = 0.1
	cam.attributes = at
	cam.current = true


func _shoot(name: String) -> void:
	_hide_ui()
	RenderingServer.render_loop_enabled = true
	_pending.append([frame + 4, name])


## Écarte les personnages qui bouchent le premier plan (entre la caméra et la cible, trop près de l'objectif)
func _clear_view(from: Vector3, to: Vector3, keep: Node3D = null) -> void:
	var ax := Vector2(to.x - from.x, to.z - from.z)
	var len := ax.length()
	if len < 0.1:
		return
	ax /= len
	for a in crowd.actors:
		if not is_instance_valid(a) or a == keep:
			continue
		var v := Vector2(a.global_position.x - from.x, a.global_position.z - from.z)
		var along := v.dot(ax)
		var side := absf(v.x * ax.y - v.y * ax.x)
		if along > -0.5 and along < len - 1.5 and side < 0.6 + along * 0.25:
			var push := Vector2(-ax.y, ax.x) * (signf(v.x * ax.y - v.y * ax.x) if side > 0.01 else 1.0) * -(1.6 + along * 0.3)
			a.global_position += Vector3(push.x, 0, push.y)


func _flare_npc() -> Npc:
	for n in crowd.npcs:
		if is_instance_valid(n) and n.flare != null and is_instance_valid(n.flare):
			return n
	return null


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	if ratio > 0.0:
		var w := int(round(float(img.get_height()) * ratio))
		if w < img.get_width():
			img = img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, img.get_height()))
	img.save_png(out_dir.path_join(name + ".png"))
	print("PHOTO ", name)


func _process(_d: float) -> bool:
	frame += 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
			if c is Police: pol = c
			if c is Tension: ten = c
		var p: Player = main.player
		p.global_position = Vector3(-60, 0.05, 15)       # le joueur hors champ
		cam = Camera3D.new()
		cam.far = 3000.0
		root.add_child(cam)
	# 1. le cortège de face, banderole en tête, contre-plongée
	if frame == 300:
		var r := crowd.route_at(crowd.cortege_s + 9.0)
		var ahead: Vector3 = r[0]
		var dir: Vector3 = (r[1] as Vector3).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		var bl: Vector3 = crowd._banner_l.global_position if crowd._banner_l else crowd.cortege_center()
		var br: Vector3 = crowd._banner_r.global_position if crowd._banner_r else bl
		var mid := (bl + br) * 0.5
		var from := ahead + side * 1.8 + Vector3(0, 0.8, 0)
		_clear_view(from, mid)
		if crowd.leader:
			crowd.leader.global_position += side * 3.0
		_cam(from, mid + Vector3(0, 1.9, 0) - dir * 3.0, 44.0, from.distance_to(mid))
		_shoot("1_cortege")
	# le feu : un tas de déchets allumé, la tension monte
	if frame == 320:
		for n in main.get_children():
			if n is Burnable and (n as Node3D).global_position.distance_to(_fire_at) < 2.5:
				(n as Burnable).ignite()
				FloorFire.merge_or_create(n as Burnable)
		ten.set_value(0.42)
	# 2. portrait : manifestant au fumigène
	if frame == 900:
		var f := _flare_npc()
		if f:
			var fp := f.global_position
			var fl: Vector3 = f.flare.global_position
			var fwd := -f.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var from2 := fp + fwd * 2.3 + Vector3(-fwd.z, 0, fwd.x) * 0.7 + Vector3(0, 1.5, 0)
			_clear_view(from2, fp, f)
			_cam(from2, fl.lerp(fp + Vector3(0, 1.6, 0), 0.55), 34.0, 2.4)
		_shoot("2_fumigene")
	# 3. feu au sol, des silhouettes autour
	if frame == 1000:
		for fr in main.get_tree().get_nodes_in_group("fires"):
			if is_instance_valid(fr) and fr is FloorFire:
				_fire_at = (fr as Node3D).global_position
				break
		var from3 := _fire_at + Vector3(-2.6, 0.7, 2.4)
		_clear_view(from3, _fire_at)
		_cam(from3, _fire_at + Vector3(0, 0.7, 0), 40.0, 3.5)
		_shoot("3_feu")
	if frame == 1020:
		ten.set_value(0.7)
	# 4. la ligne de CRS, boucliers, fourgons, vue des manifestants
	if frame == 1500:
		var lc := pol.line_c
		var from4 := lc + Vector3(-9.0, 1.4, 1.2)
		_clear_view(from4, lc)
		_cam(from4, lc + Vector3(0, 1.3, 0), 34.0, 9.0)
		_shoot("4_crs")
	# 5. gaz lacrymogène : grenades tombées entre la foule et la ligne
	if frame == 1700:
		_gas_at = pol.line_c + Vector3(-13.0, 0, 0)
		for k in 3:
			var g := GasGrenade.new()
			g.crowd = crowd
			main.add_child(g)
			g.global_position = _gas_at + Vector3(k * 2.2 - 2.2, 0.3, k * 1.6 - 1.6)
			g._activate()
	if frame == 1900:
		var from5 := _gas_at + Vector3(-11.0, 1.5, -0.8)
		_clear_view(from5, _gas_at)
		_cam(from5, _gas_at + Vector3(4.0, 1.5, 0), 38.0, 10.0)
		_shoot("5_gaz")
	# 6. vue large du boulevard en hauteur
	if frame == 2000:
		var c2 := crowd.cortege_center()
		_cam(Vector3(c2.x - 34.0, 21.0, -7.4), Vector3(c2.x + 14.0, 0.0, -5.5), 42.0)
		_shoot("6_boulevard")
	for pnd in _pending.duplicate():
		if frame == pnd[0]:
			_save(str(pnd[1]))
			_pending.erase(pnd)
			RenderingServer.render_loop_enabled = false
	if frame > 2010 and _pending.is_empty():
		return true
	return false
