class_name Weather
extends Node3D
## Météo et éclairage urbain selon l'heure (créé par Lighting.build) :
## - pluie / bruine : gouttes en particules GPU autour de la caméra (cachées sous les auvents et les toits par un
##   champ de hauteur aux qualités moyenne et plus), éclaboussures au sol ; quantité selon la qualité d'image ;
## - sol mouillé : baseplate et marquages assombris et lustrés, flaques étendues, chaussée du boulevard mouillée ;
## - lampadaires éteints le jour, fenêtres plus ou moins allumées selon l'heure.
## Les matériaux partagés (caches statiques d'autres modules) sont réglés de façon idempotente : un chapitre sec
## après un chapitre pluvieux retrouve le sol sec.

const QUALITY_K := [0.3, 0.6, 1.0, 1.3]     # quantité de pluie par qualité d'image (Bas, Moyen, Élevé, Ultra)

var tod := "crepuscule"
var weather := "sec"
var wet := 0.0                 # 0 sec .. 1 détrempé
var rain := 0.0                # 0 aucune .. 1 averse
var lamps_on := true
var win := Vector2(1.2, 0.16)
var rain_col := Color(0.75, 0.7, 0.72)
var _drops: GPUParticles3D
var _splash: GPUParticles3D
var _field: GPUParticlesCollisionHeightField3D
var _drops_base := 0
var _splash_base := 0

static var _wet_touched: Array[StandardMaterial3D] = []


func setup(t_id: String, w_id: String, t: Dictionary, w: Dictionary) -> void:
	tod = t_id
	weather = w_id
	wet = float(w.get("wet", 0.0))
	rain = float(w.get("rain", 0.0))
	lamps_on = bool(t["lamps"])
	win = t["win"]
	rain_col = t["rain_col"]


func _ready() -> void:
	if rain > 0.0:
		_build_rain()
		add_child(StoryAudio.rain_player(rain))     # son de la pluie (assets/audio/story/amb_pluie)
	apply_settings()
	set_process(rain > 0.0)
	# le reste du monde est construit après l'éclairage : on l'habille une fois la scène prête
	_dress.call_deferred()


## Réglages image : la pluie suit la qualité (basse = pluie allégée, sans champ de hauteur)
func apply_settings() -> void:
	if _drops == null:
		return
	var q := clampi(int(Settings.d.get("quality", 2)), 0, QUALITY_K.size() - 1)
	var k: float = QUALITY_K[q]
	_drops.amount = maxi(200, int(_drops_base * k))
	if _splash != null:
		_splash.amount = maxi(60, int(_splash_base * k))
	var want_field := q >= 1
	if want_field and _field == null:
		_field = GPUParticlesCollisionHeightField3D.new()
		_field.size = Vector3(48.0, 40.0, 48.0)
		_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
		_field.follow_camera_enabled = true
		_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
		add_child(_field)
	elif not want_field and _field != null:
		_field.queue_free()
		_field = null
	var pm := _drops.process_material as ParticleProcessMaterial
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT if want_field else ParticleProcessMaterial.COLLISION_DISABLED


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.ZERO
	# le volume de pluie est décalé vers l'avant : c'est là qu'on la voit
	_drops.global_position = Vector3(at.x, at.y + 5.5, at.z) + fwd * 5.0
	if _splash != null:
		_splash.global_position = Vector3(at.x, 0.03, at.z) + fwd * 4.0


# ------------------------------------------------------------------ pluie
func _build_rain() -> void:
	var heavy := rain >= 0.6
	_drops = GPUParticles3D.new()
	_drops.name = "Gouttes"
	_drops_base = 6500 if heavy else 4500
	_drops.amount = _drops_base
	var fall := 9.5 if heavy else 2.4
	_drops.lifetime = 11.5 / fall
	_drops.preprocess = _drops.lifetime
	_drops.local_coords = false
	_drops.fixed_fps = 0
	_drops.visibility_aabb = AABB(Vector3(-22, -16, -22), Vector3(44, 24, 44))
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16.0, 3.5, 16.0)
	pm.direction = Vector3(0.06, -1.0, 0.03)
	pm.spread = 2.0 if heavy else 6.0
	pm.initial_velocity_min = fall * 0.9
	pm.initial_velocity_max = fall * 1.1
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	pm.collision_use_scale = false
	_drops.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.011, 0.5) if heavy else Vector2(0.007, 0.07)
	q.material = _streak_mat(0.28 if heavy else 0.32, heavy)
	_drops.draw_pass_1 = q
	add_child(_drops)
	if heavy:
		_build_splashes()


## Éclaboussures : petits jets qui naissent au sol et retombent aussitôt
func _build_splashes() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "Eclaboussures"
	_splash_base = 700
	_splash.amount = _splash_base
	_splash.lifetime = 0.22
	_splash.local_coords = false
	_splash.visibility_aabb = AABB(Vector3(-14, -1, -14), Vector3(28, 3, 28))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10.0, 0.0, 10.0)
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(1.0, 1.0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_splash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_tex()
	m.albedo_color = Color(rain_col.r, rain_col.g, rain_col.b, 0.32)
	m.disable_receive_shadows = true
	q.material = m
	_splash.draw_pass_1 = q
	add_child(_splash)


## Trait de pluie : quad toujours tourné vers la caméra autour de l'axe vertical, bords et extrémités adoucis
func _streak_mat(alpha: float, heavy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	m.albedo_texture = _streak_tex() if heavy else _dot_tex()
	m.albedo_color = Color(rain_col.r, rain_col.g, rain_col.b, alpha)
	m.disable_receive_shadows = true
	return m


static var _streak: ImageTexture
static var _dot: ImageTexture


static func _streak_tex() -> ImageTexture:
	if _streak == null:
		var img := Image.create(8, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var v := float(y) / 63.0
			var a := sin(v * PI) * (0.35 + 0.65 * v)          # plus dense vers le bas (tête de la goutte)
			for x in 8:
				var u := (float(x) + 0.5) / 8.0
				img.set_pixel(x, y, Color(1, 1, 1, a * clampf(1.0 - absf(u - 0.5) * 2.2, 0.0, 1.0)))
		_streak = ImageTexture.create_from_image(img)
	return _streak


static func _dot_tex() -> ImageTexture:
	if _dot == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot


# ------------------------------------------------------------------ habillage du monde construit
func _dress() -> void:
	var root := get_parent()
	if root == null:
		return
	# fenêtres des immeubles : matériaux partagés, valeurs absolues (idempotent d'une scène à l'autre)
	var lit := ParisBuilding.mat("glass_lit") as StandardMaterial3D
	var dim := ParisBuilding.mat("glass_dim") as StandardMaterial3D
	if lit != null:
		lit.emission_energy_multiplier = win.x
	if dim != null:
		dim.emission_energy_multiplier = win.y
	_wet_shared()
	var road_mat: ShaderMaterial = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is LampPost:
			if not lamps_on:
				_lamp_off(n)
		elif n is SpotLight3D and _in_bus_stop(n):
			if not lamps_on:
				_bus_lamp_off(n as SpotLight3D)
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var m := mi.material_override
			if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
				var path := (m as ShaderMaterial).shader.resource_path
				if path.ends_with("baseplate.gdshader") or path.ends_with("marquage.gdshader"):
					(m as ShaderMaterial).set_shader_parameter("wetness", wet)
					if path.ends_with("baseplate.gdshader"):
						(m as ShaderMaterial).set_shader_parameter("rain", rain)
			elif m is StandardMaterial3D and wet > 0.0 and _in_bus_stop(mi):
				var sm := m as StandardMaterial3D
				if sm.albedo_texture != null and sm.albedo_texture.resource_path.ends_with("asphalt_a.png"):
					if road_mat == null:
						road_mat = _wet_road(sm)
					mi.material_override = road_mat
			else:
				for i in mi.get_surface_override_material_count():
					var sm2 := mi.get_surface_override_material(i)
					if sm2 == null and mi.mesh != null:
						sm2 = mi.mesh.surface_get_material(i)
					if sm2 is ShaderMaterial and (sm2 as ShaderMaterial).shader != null \
							and (sm2 as ShaderMaterial).shader.resource_path.ends_with("marquage.gdshader"):
						(sm2 as ShaderMaterial).set_shader_parameter("wetness", wet)


func _in_bus_stop(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is BusStop:
			return true
		p = p.get_parent()
	return false


## Lampadaire éteint (jour) : plus de lumière ni de vacillement, ampoule grise
func _lamp_off(lamp: Node) -> void:
	lamp.set_process(false)
	var l: Variant = lamp.get("_light")
	if l is Light3D:
		(l as Light3D).visible = false
	var bm: Variant = lamp.get("_bulb_mat")
	if bm is StandardMaterial3D:
		(bm as StandardMaterial3D).albedo_color = Color(0.32, 0.31, 0.29)


## Lampadaire de l'arrêt de bus éteint : projecteur coupé, verre de la tête grisé
func _bus_lamp_off(sp: SpotLight3D) -> void:
	sp.visible = false
	for c in sp.get_parent().get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			if m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				var mm := m.duplicate() as StandardMaterial3D
				mm.albedo_color = Color(0.36, 0.35, 0.33)
				(c as MeshInstance3D).material_override = mm


## Chaussée mouillée : mêmes textures que le matériau sec, shader dédié
func _wet_road(dry: StandardMaterial3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/route_mouillee.gdshader")
	m.set_shader_parameter("asphalt_a", dry.albedo_texture)
	m.set_shader_parameter("asphalt_n", dry.normal_texture)
	m.set_shader_parameter("tint", Vector3(dry.albedo_color.r, dry.albedo_color.g, dry.albedo_color.b))
	m.set_shader_parameter("uv_scale", dry.uv1_scale.x)
	m.set_shader_parameter("wetness", wet)
	m.set_shader_parameter("rain", rain)
	return m


## Bordures, caniveaux, pierres et pavés partagés (cache de Streetscape) : assombris et lustrés quand c'est mouillé.
## Valeurs sèches gardées en méta pour revenir au sec au chapitre suivant.
func _wet_shared() -> void:
	var mats: Array[StandardMaterial3D] = []
	for key in ["bordure", "caniveau", "podo", "fonte", "pierre_q", "marche", "carrelage", "beton_q", "pelouse"]:
		var m: Variant = Streetscape._mats.get(key)
		if m is StandardMaterial3D:
			mats.append(m)
	for m in _wet_touched:
		if not mats.has(m):
			mats.append(m)
	for m in mats:
		if not m.has_meta("dry_rough"):
			m.set_meta("dry_rough", m.roughness)
			m.set_meta("dry_col", m.albedo_color)
		var r := float(m.get_meta("dry_rough"))
		var col: Color = m.get_meta("dry_col")
		m.roughness = lerpf(r, r * 0.35 + 0.06, wet)
		m.albedo_color = Color(col.r * (1.0 - 0.28 * wet), col.g * (1.0 - 0.28 * wet), col.b * (1.0 - 0.28 * wet), col.a)
		if not _wet_touched.has(m):
			_wet_touched.append(m)
