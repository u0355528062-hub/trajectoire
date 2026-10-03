class_name Clinic
extends Node3D
## Construit le cabinet médical : bureau du médecin, salle d'attente,
## accueil, extérieur, éclairage et environnement.
##
## Repères : X vers l'est, Z vers le sud, Y vers le haut (mètres).
## Cabinet : x ∈ [0, 6], z ∈ [0, 6]. Salle d'attente : x ∈ [-7, 0], z ∈ [0, 6].

const H := 2.8
const T := 0.14

# Points de passage des patients
const OUTSIDE := Vector3(-4.0, 0, 11.0)
const ENTRY := Vector3(-4.0, 0, 5.2)
const RECEPTION := Vector3(-5.05, 0, 3.5)
const WAIT_SEATS_X := [-5.6, -4.8, -4.0, -3.2, -2.4]
const WAIT_SEAT_Z := 0.5
const WAIT_FRONT_Z := 1.4
const DOOR_W := Vector3(-0.8, 0, 4.7)
const DOOR_E := Vector3(0.8, 0, 4.7)
const OFFICE_APPROACH := Vector3(2.55, 0, 3.45)
const PATIENT_SEAT := Vector3(2.5, 0, 2.5)
const EXAM_APPROACH := Vector3(4.3, 0, 3.75)
const EXAM_SEAT := Vector3(4.98, 0, 3.75)
const PLAYER_SPAWN := Vector3(1.2, 0, 3.4)

var computer: Interactable
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var secretary: Humanoid
var screen_title: Label
var screen_body: Label
var _clock_hour: Node3D
var _clock_minute: Node3D
var _rng := RandomNumberGenerator.new()
var _font: Font


func build() -> void:
	_rng.seed = 1977
	_font = load("res://assets/fonts/Inter-SemiBold.ttf")
	_build_environment()
	_build_shell()
	_build_office()
	_build_waiting_room()
	_build_exterior()
	_build_lights()
	apply_quality(int(Game.settings["quality"]))
	Game.settings_changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	apply_quality(int(Game.settings["quality"]))


func _process(_delta: float) -> void:
	if _clock_hour:
		var m := Game.minutes
		_clock_minute.rotation.z = -fmod(m, 60.0) / 60.0 * TAU
		_clock_hour.rotation.z = -fmod(m / 60.0, 12.0) / 12.0 * TAU


func wait_seat(i: int) -> Vector3:
	return Vector3(WAIT_SEATS_X[i], 0, WAIT_SEAT_Z)


func wait_front(i: int) -> Vector3:
	return Vector3(WAIT_SEATS_X[i], 0, WAIT_FRONT_Z)


# --- Environnement -------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_mat.ground_horizon_color = Color(0.62, 0.66, 0.68)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.2)
	sky_mat.sun_angle_max = 1.5
	sky_mat.sun_curve = 0.08
	sky_mat.sky_energy_multiplier = 1.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.0
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.1
	env.sdfgi_energy = 1.0
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.95, 0.93, 0.9)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_ambient_inject = 0.0
	world_env = WorldEnvironment.new()
	world_env.environment = env
	var attrs := CameraAttributesPractical.new()
	attrs.auto_exposure_enabled = false
	world_env.camera_attributes = attrs
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.light_volumetric_fog_energy = 2.5
	sun.light_angular_distance = 0.6
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.78, -0.42, -0.46), Vector3.UP)


func apply_quality(q: int) -> void:
	if world_env == null:
		return
	var env := world_env.environment
	env.ssao_enabled = true
	env.ssil_enabled = q >= 1
	env.ssr_enabled = q >= 1
	env.sdfgi_enabled = q >= 2
	env.volumetric_fog_enabled = q >= 2
	env.glow_enabled = true
	env.ambient_light_energy = 0.35 if q >= 2 else 0.55
	sun.shadow_blur = 1.5 if q >= 1 else 0.8
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X if q >= 2 else (Viewport.MSAA_2X if q == 1 else Viewport.MSAA_DISABLED)
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED


# --- Enveloppe : sols, murs, plafonds ------------------------------------------------

func _build_shell() -> void:
	# Sols
	var office_floor := Art.add_mesh(self, Art.box_mesh(Vector3(6, 0.1, 6)), Art.mat("floor_wood"), Vector3(3, -0.05, 3))
	office_floor.name = "OfficeFloor"
	Art.add_mesh(self, Art.box_mesh(Vector3(7, 0.1, 6)), Art.mat("floor_tiles"), Vector3(-3.5, -0.05, 3))
	Art.add_collider(self, Vector3(13.4, 0.1, 6.4), Vector3(-0.5, -0.05, 3))
	# Plafond et toit
	Art.add_mesh(self, Art.box_mesh(Vector3(13.3, 0.08, 6.3)), Art.mat("ceiling"), Vector3(-0.5, H + 0.04, 3))
	Art.add_mesh(self, Art.box_mesh(Vector3(13.8, 0.3, 6.8)), Art.mat("wall_outside"), Vector3(-0.5, H + 0.23, 3))
	Art.add_mesh(self, Art.rounded_box(Vector3(14.0, 0.12, 7.0), 0.03), Art.color_mat(Color(0.32, 0.33, 0.35), 0.7), Vector3(-0.5, H + 0.42, 3))

	# Murs extérieurs et cloison (ouvertures : [début, fin, bas, haut])
	_wall(Vector3(-7, 0, 0), Vector3(6, 0, 0), [[0.8, 2.6, 1.15, 2.35], [3.4, 5.2, 1.15, 2.35]], "wall")
	_wall(Vector3(-7, 0, 6), Vector3(6, 0, 6), [[2.4, 3.6, 0.0, 2.25], [8.6, 10.8, 0.9, 2.35]], "wall")
	_wall(Vector3(-7, 0, 0), Vector3(-7, 0, 6), [], "wall")
	_wall(Vector3(6, 0, 0), Vector3(6, 0, 6), [[0.7, 2.6, 0.85, 2.35]], "wall")
	_wall(Vector3(0, 0, 0), Vector3(0, 0, 6), [[4.2, 5.2, 0.0, 2.15]], "wall")

	# Fenêtres
	_window(Vector3(-5.3, 1.75, 0), 1.8, 1.2, "z")
	_window(Vector3(-2.7, 1.75, 0), 1.8, 1.2, "z")
	_window(Vector3(2.7, 1.625, 6), 2.2, 1.45, "z")
	_window(Vector3(6, 1.6, 1.65), 1.9, 1.5, "x")

	# Murs d'accent (panneaux fins côté intérieur)
	Art.add_mesh(self, Art.box_mesh(Vector3(5.86, H, 0.01)), Art.mat("wall_accent"), Vector3(3, H * 0.5, T * 0.5 + 0.006))
	Art.add_mesh(self, Art.box_mesh(Vector3(0.01, H, 5.86)), Art.mat("wall_accent_blue"), Vector3(-7 + T * 0.5 + 0.006, H * 0.5, 3))

	# Plinthes
	for seg in [
		[Vector3(3, 0.05, T * 0.5 + 0.02), Vector3(5.86, 0.1, 0.02)],
		[Vector3(-3.5, 0.05, T * 0.5 + 0.02), Vector3(6.86, 0.1, 0.02)],
		[Vector3(5.93 - T * 0.5, 0.05, 3), Vector3(0.02, 0.1, 5.86)],
		[Vector3(-6.93 + T * 0.5, 0.05, 3), Vector3(0.02, 0.1, 5.86)],
	]:
		Art.add_mesh(self, Art.box_mesh(seg[1]), Art.mat("baseboard"), seg[0])

	# Encadrements de portes
	_door_frame(Vector3(0, 0, 4.7), 1.0, 2.15, "x")
	_door_frame(Vector3(-4.0, 0, 6), 1.2, 2.25, "z")
	# Porte du cabinet, ouverte contre le mur
	var leaf := Node3D.new()
	leaf.position = Vector3(0.07, 0, 5.2)
	add_child(leaf)
	Art.add_rbox(leaf, Vector3(0.92, 2.1, 0.045), Vector3(0.48, 1.06, 0.03), Art.mat("wood_light"), 0.008)
	Art.add_mesh(leaf, Art.cylinder(0.012, 0.012, 0.14, 12), Art.mat("brushed_metal"), Vector3(0.85, 1.02, -0.02), Vector3(90, 0, 0))
	Art.add_collider(leaf, Vector3(0.92, 2.1, 0.05), Vector3(0.48, 1.06, 0.03))
	# Plaque du cabinet
	_label_panel(self, Vector3(-0.08, 2.32, 4.7), Vector2(0.62, 0.14), "Dr — Médecine générale", Color(0.12, 0.2, 0.28), Color(0.95, 0.96, 0.97), 0.0013, Vector3(0, -90, 0))
	# Portes vitrées automatiques de l'entrée, ouvertes
	for sx in [-1.0, 1.0]:
		var p := Vector3(-4.0 + sx * 1.05, 1.12, 6.0)
		Art.add_rbox(self, Vector3(0.9, 2.2, 0.03), p, Art.mat("glass"), 0.004)
		Art.add_rbox(self, Vector3(0.9, 0.05, 0.04), p + Vector3(0, -1.08, 0), Art.mat("dark_metal"), 0.006)
		Art.add_rbox(self, Vector3(0.9, 0.05, 0.04), p + Vector3(0, 1.08, 0), Art.mat("dark_metal"), 0.006)


## Mur rectiligne avec ouvertures. `openings` : [début, fin, bas, haut] le long du mur.
func _wall(a: Vector3, b: Vector3, openings: Array, mat_name: String) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var along_x := absf(dir.x) > 0.5
	var mat := Art.mat(mat_name)
	var pieces: Array = []
	var cursor := 0.0
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	for o in sorted:
		if o[0] > cursor:
			pieces.append([cursor, o[0], 0.0, H])
		if o[2] > 0.0:
			pieces.append([o[0], o[1], 0.0, o[2]])
		if o[3] < H:
			pieces.append([o[0], o[1], o[3], H])
		cursor = o[1]
	if cursor < length:
		pieces.append([cursor, length, 0.0, H])
	for p in pieces:
		var l: float = p[1] - p[0]
		var hgt: float = p[3] - p[2]
		var extra := T if (p[0] == 0.0 or p[1] == length) else 0.0
		var center: Vector3 = a + dir * ((p[0] + p[1]) * 0.5)
		center.y = (p[2] + p[3]) * 0.5
		var size := Vector3(l + extra, hgt, T) if along_x else Vector3(T, hgt, l + extra)
		Art.add_mesh(self, Art.box_mesh(size), mat, center)
		Art.add_collider(self, size, center)


func _window(center: Vector3, width: float, height: float, axis: String) -> void:
	var frame := Art.color_mat(Color(0.94, 0.94, 0.95), 0.35)
	var along := Vector3.RIGHT if axis == "z" else Vector3.BACK
	var depth := Vector3.BACK if axis == "z" else Vector3.RIGHT
	var fw := 0.06
	# Cadre
	for s in [-1.0, 1.0]:
		var side_size: Vector3 = _abs3(along * fw + Vector3.UP * height + depth * (T + 0.02))
		Art.add_rbox(self, side_size, center + along * (s * (width * 0.5 - fw * 0.5)), frame, 0.008)
		var tb_size: Vector3 = _abs3(along * width + Vector3.UP * fw + depth * (T + 0.02))
		Art.add_rbox(self, tb_size, center + Vector3.UP * (s * (height * 0.5 - fw * 0.5)), frame, 0.008)
	# Meneau central
	Art.add_rbox(self, _abs3(along * 0.04 + Vector3.UP * height + depth * 0.08), center, frame, 0.006)
	# Vitre
	Art.add_mesh(self, Art.box_mesh(_abs3(along * width + Vector3.UP * height + depth * 0.012)), Art.mat("glass"), center)
	# Rebord intérieur
	var inward := 1.0
	if axis == "z" and center.z > 3.0:
		inward = -1.0
	if axis == "x" and center.x > 3.0:
		inward = -1.0
	Art.add_rbox(self, _abs3(along * (width + 0.12) + Vector3.UP * 0.035 + depth * 0.24), center + Vector3.DOWN * (height * 0.5 + 0.017) + depth * (inward * 0.06), Art.color_mat(Color(0.96, 0.96, 0.95), 0.3), 0.01)


func _abs3(v: Vector3) -> Vector3:
	return Vector3(absf(v.x), absf(v.y), absf(v.z))


func _door_frame(center: Vector3, width: float, height: float, axis: String) -> void:
	var frame := Art.color_mat(Color(0.95, 0.95, 0.95), 0.3)
	var along := Vector3.BACK if axis == "x" else Vector3.RIGHT
	var depth := Vector3.RIGHT if axis == "x" else Vector3.BACK
	for s in [-1.0, 1.0]:
		Art.add_rbox(self, _abs3(along * 0.06 + Vector3.UP * height + depth * (T + 0.04)), center + along * (s * (width * 0.5 + 0.0)) + Vector3.UP * (height * 0.5), frame, 0.01)
	Art.add_rbox(self, _abs3(along * (width + 0.12) + Vector3.UP * 0.06 + depth * (T + 0.04)), center + Vector3.UP * (height + 0.03), frame, 0.01)


# --- Cabinet du médecin --------------------------------------------------------------

func _build_office() -> void:
	# Bureau
	var desk := Node3D.new()
	desk.name = "Desk"
	desk.position = Vector3(3.0, 0, 1.5)
	add_child(desk)
	Art.add_rbox(desk, Vector3(1.7, 0.045, 0.82), Vector3(0, 0.75, 0), Art.mat("wood"), 0.012)
	for sx in [-1.0, 1.0]:
		Art.add_rbox(desk, Vector3(0.05, 0.72, 0.74), Vector3(sx * 0.8, 0.36, 0), Art.mat("dark_metal"), 0.01)
	Art.add_rbox(desk, Vector3(1.55, 0.45, 0.025), Vector3(0, 0.48, 0.3), Art.mat("dark_metal"), 0.006)
	# Caisson
	Art.add_rbox(desk, Vector3(0.42, 0.6, 0.6), Vector3(-0.5, 0.31, -0.05), Art.mat("wood_light"), 0.01)
	for i in range(3):
		Art.add_rbox(desk, Vector3(0.12, 0.012, 0.02), Vector3(-0.5, 0.5 - i * 0.19, -0.36), Art.mat("brushed_metal"), 0.004)
	Art.add_collider(desk, Vector3(1.7, 0.8, 0.82), Vector3(0, 0.4, 0))

	# Écran (face au médecin, côté nord)
	var monitor := Node3D.new()
	monitor.position = Vector3(0.2, 0.772, 0.05)
	monitor.rotation_degrees = Vector3(0, 180, 0)
	desk.add_child(monitor)
	Art.add_rbox(monitor, Vector3(0.24, 0.012, 0.18), Vector3(0, 0.006, 0), Art.mat("dark_metal"), 0.005)
	Art.add_rbox(monitor, Vector3(0.05, 0.3, 0.025), Vector3(0, 0.16, -0.035), Art.mat("dark_metal"), 0.008)
	Art.add_rbox(monitor, Vector3(0.62, 0.38, 0.025), Vector3(0, 0.39, 0.0), Art.mat("black_plastic"), 0.01)
	var screen := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.595, 0.355)
	screen.mesh = quad
	screen.position = Vector3(0, 0.39, 0.0135)
	monitor.add_child(screen)
	_setup_screen(screen)
	computer = Interactable.create(monitor, Vector3(0.7, 0.5, 0.3), Vector3(0, 0.35, 0), "Ouvrir l'agenda")
	# Clavier, souris
	Art.add_rbox(desk, Vector3(0.44, 0.018, 0.14), Vector3(0.2, 0.782, -0.22), Art.color_mat(Color(0.85, 0.85, 0.86), 0.4), 0.006)
	Art.add_rbox(desk, Vector3(0.06, 0.022, 0.1), Vector3(0.55, 0.784, -0.22), Art.color_mat(Color(0.85, 0.85, 0.86), 0.4), 0.01)
	# Ordonnancier, stylo, téléphone
	Art.add_rbox(desk, Vector3(0.21, 0.012, 0.297), Vector3(-0.35, 0.778, -0.12), Art.mat("paper"), 0.002, Vector3(0, 12, 0))
	Art.add_mesh(desk, Art.cylinder(0.005, 0.005, 0.14, 8), Art.color_mat(Color(0.1, 0.2, 0.5), 0.3), Vector3(-0.2, 0.778, -0.12), Vector3(0, 30, 90))
	Art.add_rbox(desk, Vector3(0.18, 0.06, 0.2), Vector3(-0.65, 0.8, 0.2), Art.mat("black_plastic"), 0.015, Vector3(-10, 20, 0))
	# Stéthoscope posé
	var steth := Node3D.new()
	steth.position = Vector3(-0.15, 0.78, 0.22)
	desk.add_child(steth)
	Art.add_mesh(steth, Art.torus(0.09, 0.105), Art.color_mat(Color(0.1, 0.1, 0.12), 0.4), Vector3.ZERO, Vector3(0, 0, 0), Vector3(1, 0.2, 0.8))
	Art.add_mesh(steth, Art.cylinder(0.022, 0.022, 0.012, 24), Art.mat("chrome"), Vector3(0.14, 0.004, 0.05))
	# Lampe de bureau
	var lamp := Node3D.new()
	lamp.position = Vector3(0.72, 0.772, 0.25)
	desk.add_child(lamp)
	Art.add_mesh(lamp, Art.cylinder(0.07, 0.08, 0.02, 24), Art.mat("dark_metal"), Vector3(0, 0.01, 0))
	Art.add_mesh(lamp, Art.cylinder(0.008, 0.008, 0.42, 8), Art.mat("dark_metal"), Vector3(0, 0.22, 0), Vector3(10, 0, 0))
	Art.add_mesh(lamp, Art.cylinder(0.03, 0.08, 0.12, 24), Art.mat("dark_metal"), Vector3(0, 0.42, -0.08), Vector3(-35, 0, 0))
	var lamp_light := SpotLight3D.new()
	lamp_light.position = Vector3(0, 0.38, -0.12)
	lamp_light.rotation_degrees = Vector3(-60, 0, 0)
	lamp_light.light_color = Color(1.0, 0.85, 0.65)
	lamp_light.light_energy = 1.5
	lamp_light.spot_range = 1.6
	lamp_light.spot_angle = 38
	lamp.add_child(lamp_light)
	# Petite plante
	_plant(desk, Vector3(-0.72, 0.77, 0.28), 0.35)

	# Fauteuil du médecin et chaises patients
	_office_chair(Vector3(3.0, 0, 0.72), 0.0)
	_guest_chair(Vector3(2.5, 0, 2.55), 0.0)
	_guest_chair(Vector3(3.45, 0, 2.55), 0.0)
	# Tapis
	Art.add_rbox(self, Vector3(2.2, 0.01, 1.5), Vector3(3.0, 0.005, 2.6), Art.fabric_mat(Color(0.55, 0.5, 0.45)), 0.004)

	_exam_table(Vector3(5.2, 0, 3.75))
	_sink(Vector3(4.9, 0, 0.32))
	_bookshelf(Vector3(1.1, 0, 0.28))
	_medicine_cabinet(Vector3(4.3, 0, 5.68))
	_coat_rack(Vector3(0.45, 0, 5.6))
	_plant(self, Vector3(5.55, 0, 5.5), 1.4)
	_bin(Vector3(3.95, 0, 1.05))

	# Diplômes au mur, derrière le bureau
	for i in range(3):
		var pos := Vector3(2.35 + i * 0.65, 1.75 + (0.08 if i == 1 else 0.0), T * 0.5 + 0.03)
		_frame(pos, Vector2(0.42, 0.32), ["Diplôme d'État de\nDocteur en Médecine", "Faculté de Médecine\nde Tours", "Ordre des Médecins\nInscription n° 37/2026"][i])
	# Échelle de lecture (Monoyer) sur le mur ouest du cabinet
	_label_panel(self, Vector3(T * 0.5 + 0.02, 1.55, 1.4), Vector2(0.42, 0.8), "10/10   F  Z  U  E\n8/10   D  E  N  T\n6/10   V  O  L  K\n4/10   M  P\n2/10   R\n1/10   N", Color(0.98, 0.98, 0.97), Color(0.08, 0.08, 0.1), 0.0016, Vector3(0, 90, 0))
	# Horloge murale
	_wall_clock(Vector3(T * 0.5 + 0.03, 2.2, 3.2))
	# Tensiomètre mural
	var bp := Node3D.new()
	bp.position = Vector3(6 - T * 0.5 - 0.04, 1.45, 3.1)
	bp.rotation_degrees = Vector3(0, -90, 0)
	add_child(bp)
	Art.add_rbox(bp, Vector3(0.18, 0.26, 0.06), Vector3.ZERO, Art.mat("white_plastic"), 0.015)
	Art.add_rbox(bp, Vector3(0.12, 0.08, 0.01), Vector3(0, 0.05, 0.031), Art.color_mat(Color(0.15, 0.3, 0.32), 0.2), 0.004)
	Art.add_mesh(bp, Art.torus(0.05, 0.065), Art.color_mat(Color(0.15, 0.2, 0.35), 0.7), Vector3(0, -0.2, 0.04), Vector3(90, 0, 0))


func _setup_screen(screen: MeshInstance3D) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 384)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.1, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	var bar := ColorRect.new()
	bar.color = Color(0.1, 0.6, 0.6)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(640, 6)
	vp.add_child(bar)
	screen_title = Label.new()
	screen_title.position = Vector2(28, 22)
	screen_title.size = Vector2(590, 50)
	screen_title.add_theme_font_override("font", load("res://assets/fonts/InterDisplay-Bold.ttf"))
	screen_title.add_theme_font_size_override("font_size", 34)
	screen_title.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
	screen_title.text = "Agenda"
	vp.add_child(screen_title)
	screen_body = Label.new()
	screen_body.position = Vector2(28, 84)
	screen_body.size = Vector2(590, 290)
	screen_body.add_theme_font_override("font", load("res://assets/fonts/Inter-Medium.ttf"))
	screen_body.add_theme_font_size_override("font_size", 22)
	screen_body.add_theme_color_override("font_color", Color(0.7, 0.82, 0.9))
	screen_body.add_theme_constant_override("line_spacing", 6)
	vp.add_child(screen_body)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = vp.get_texture()
	m.albedo_color = Color(1.25, 1.25, 1.25)
	screen.material_override = m


func set_screen(title: String, body: String) -> void:
	if screen_title:
		screen_title.text = title
		screen_body.text = body


func _office_chair(pos: Vector3, yaw: float) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation_degrees.y = yaw
	add_child(c)
	for i in range(5):
		var a := TAU * i / 5.0
		var arm := Node3D.new()
		arm.rotation.y = a
		c.add_child(arm)
		Art.add_rbox(arm, Vector3(0.04, 0.03, 0.3), Vector3(0, 0.08, -0.15), Art.mat("dark_metal"), 0.012)
		Art.add_mesh(arm, Art.sphere(0.03, 10), Art.mat("black_plastic"), Vector3(0, 0.03, -0.29))
	Art.add_mesh(c, Art.cylinder(0.025, 0.03, 0.36, 16), Art.mat("chrome"), Vector3(0, 0.27, 0))
	Art.add_rbox(c, Vector3(0.5, 0.08, 0.48), Vector3(0, 0.48, 0), Art.fabric_mat(Color(0.12, 0.13, 0.15)), 0.035)
	Art.add_rbox(c, Vector3(0.46, 0.6, 0.06), Vector3(0, 0.88, -0.25), Art.fabric_mat(Color(0.12, 0.13, 0.15)), 0.03, Vector3(8, 0, 0))
	for sx in [-1.0, 1.0]:
		Art.add_rbox(c, Vector3(0.04, 0.03, 0.26), Vector3(sx * 0.27, 0.68, -0.02), Art.mat("black_plastic"), 0.012)
		Art.add_rbox(c, Vector3(0.025, 0.18, 0.025), Vector3(sx * 0.27, 0.58, -0.02), Art.mat("dark_metal"), 0.008)
	Art.add_collider(c, Vector3(0.55, 1.1, 0.55), Vector3(0, 0.55, 0))


func _guest_chair(pos: Vector3, yaw: float, fabric: Color = Color(0.18, 0.36, 0.38)) -> Node3D:
	var c := Node3D.new()
	c.position = pos
	c.rotation_degrees.y = yaw
	add_child(c)
	var wood := Art.mat("wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Art.add_rbox(c, Vector3(0.035, 0.44, 0.035), Vector3(sx * 0.2, 0.22, sz * 0.2), wood, 0.012)
	Art.add_rbox(c, Vector3(0.48, 0.07, 0.46), Vector3(0, 0.46, 0), fabric_mat_cached(fabric), 0.03)
	for sx in [-1.0, 1.0]:
		Art.add_rbox(c, Vector3(0.035, 0.45, 0.035), Vector3(sx * 0.2, 0.68, 0.21), wood, 0.012, Vector3(-6, 0, 0))
	Art.add_rbox(c, Vector3(0.46, 0.24, 0.05), Vector3(0, 0.78, 0.23), fabric_mat_cached(fabric), 0.022, Vector3(-6, 0, 0))
	Art.add_collider(c, Vector3(0.5, 0.95, 0.5), Vector3(0, 0.47, 0))
	return c


func fabric_mat_cached(c: Color) -> Material:
	return Art.fabric_mat(c)


func _exam_table(pos: Vector3) -> void:
	var t := Node3D.new()
	t.name = "ExamTable"
	t.position = pos
	add_child(t)
	Art.add_rbox(t, Vector3(0.6, 0.55, 1.7), Vector3(0, 0.3, 0), Art.mat("white_plastic"), 0.03)
	Art.add_rbox(t, Vector3(0.56, 0.04, 1.66), Vector3(0, 0.02, 0), Art.mat("dark_metal"), 0.01)
	for i in range(3):
		Art.add_rbox(t, Vector3(0.012, 0.14, 0.4), Vector3(-0.305, 0.4 - i * 0.16, 0.35), Art.color_mat(Color(0.85, 0.86, 0.87), 0.4), 0.004)
	Art.add_rbox(t, Vector3(0.7, 0.1, 1.4), Vector3(0, 0.63, 0.25), Art.mat("vinyl_teal"), 0.045)
	Art.add_rbox(t, Vector3(0.7, 0.1, 0.6), Vector3(0, 0.74, -0.68), Art.mat("vinyl_teal"), 0.045, Vector3(-22, 0, 0))
	# Drap d'examen papier
	Art.add_rbox(t, Vector3(0.5, 0.006, 1.38), Vector3(0, 0.684, 0.25), Art.mat("paper"), 0.002)
	Art.add_mesh(t, Art.cylinder(0.06, 0.06, 0.52, 24), Art.mat("paper"), Vector3(0, 0.66, 0.98), Vector3(0, 0, 90))
	Art.add_mesh(t, Art.cylinder(0.012, 0.012, 0.62, 8), Art.mat("chrome"), Vector3(0, 0.66, 0.98), Vector3(0, 0, 90))
	# Marchepied
	Art.add_rbox(t, Vector3(0.45, 0.2, 0.32), Vector3(-0.62, 0.1, 0.55), Art.mat("white_plastic"), 0.02)
	Art.add_rbox(t, Vector3(0.43, 0.012, 0.3), Vector3(-0.62, 0.205, 0.55), Art.color_mat(Color(0.2, 0.2, 0.22), 0.8), 0.004)
	Art.add_collider(t, Vector3(0.7, 0.75, 1.95), Vector3(0, 0.375, 0))
	# Lampe d'examen sur pied
	var l := Node3D.new()
	l.position = Vector3(0.1, 0, 1.25)
	t.add_child(l)
	Art.add_mesh(l, Art.cylinder(0.16, 0.18, 0.03, 24), Art.mat("white_plastic"), Vector3(0, 0.015, 0))
	Art.add_mesh(l, Art.cylinder(0.012, 0.012, 1.5, 10), Art.mat("chrome"), Vector3(0, 0.77, 0))
	Art.add_mesh(l, Art.cylinder(0.009, 0.009, 0.5, 10), Art.mat("chrome"), Vector3(-0.2, 1.55, -0.12), Vector3(0, 30, 60))
	Art.add_mesh(l, Art.cylinder(0.05, 0.1, 0.1, 24), Art.mat("white_plastic"), Vector3(-0.42, 1.45, -0.25), Vector3(0, 0, 30))


func _sink(pos: Vector3) -> void:
	var s := Node3D.new()
	s.position = pos
	add_child(s)
	Art.add_rbox(s, Vector3(0.9, 0.82, 0.5), Vector3(0, 0.41, 0.0), Art.mat("white_plastic"), 0.015)
	Art.add_rbox(s, Vector3(0.92, 0.04, 0.52), Vector3(0, 0.84, 0), Art.color_mat(Color(0.2, 0.22, 0.24), 0.25), 0.01)
	Art.add_mesh(s, Art.cylinder(0.19, 0.15, 0.1, 32), Art.mat("ceramic"), Vector3(0, 0.82, 0.04))
	Art.add_mesh(s, Art.cylinder(0.17, 0.12, 0.09, 32), Art.color_mat(Color(0.82, 0.82, 0.8), 0.2), Vector3(0, 0.83, 0.04))
	Art.add_mesh(s, Art.cylinder(0.014, 0.018, 0.25, 12), Art.mat("chrome"), Vector3(0, 0.97, -0.17))
	Art.add_mesh(s, Art.cylinder(0.011, 0.011, 0.16, 12), Art.mat("chrome"), Vector3(0, 1.08, -0.1), Vector3(80, 0, 0))
	Art.add_rbox(s, Vector3(0.09, 0.2, 0.07), Vector3(0.35, 1.25, -0.2), Art.mat("white_plastic"), 0.02)
	Art.add_rbox(s, Vector3(0.3, 0.38, 0.12), Vector3(-0.32, 1.45, -0.18), Art.mat("white_plastic"), 0.03)
	# Miroir
	var mirror := StandardMaterial3D.new()
	mirror.metallic = 1.0
	mirror.roughness = 0.02
	mirror.albedo_color = Color(0.9, 0.92, 0.94)
	Art.add_rbox(s, Vector3(0.5, 0.65, 0.015), Vector3(0.05, 1.55, -0.22), mirror, 0.006)
	for d in [0.0, 1.0]:
		Art.add_rbox(s, Vector3(0.012, 0.12, 0.012), Vector3(-0.22 + d * 0.44, 0.7, 0.252), Art.mat("brushed_metal"), 0.004)
	Art.add_collider(s, Vector3(0.9, 0.9, 0.5), Vector3(0, 0.45, 0))


func _bookshelf(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	add_child(b)
	var wood := Art.mat("wood_light")
	var w := 1.4
	var hgt := 2.0
	for sx in [-1.0, 1.0]:
		Art.add_rbox(b, Vector3(0.03, hgt, 0.34), Vector3(sx * w * 0.5, hgt * 0.5, 0), wood, 0.006)
	Art.add_rbox(b, Vector3(w, hgt, 0.015), Vector3(0, hgt * 0.5, -0.165), Art.color_mat(Color(0.75, 0.7, 0.62), 0.8), 0.003)
	for i in range(6):
		var y := 0.04 + i * 0.39
		Art.add_rbox(b, Vector3(w, 0.028, 0.34), Vector3(0, y, 0), wood, 0.006)
		if i == 5:
			continue
		var x := -w * 0.5 + 0.05
		while x < w * 0.5 - 0.12:
			if _rng.randf() < 0.12:
				x += _rng.randf_range(0.08, 0.2)
				continue
			var bw := _rng.randf_range(0.025, 0.06)
			var bh := _rng.randf_range(0.2, 0.32)
			var col := Color.from_hsv(_rng.randf(), _rng.randf_range(0.25, 0.6), _rng.randf_range(0.25, 0.7))
			var lean := 0.0
			if _rng.randf() < 0.06:
				lean = _rng.randf_range(-12.0, -6.0)
			Art.add_rbox(b, Vector3(bw, bh, _rng.randf_range(0.18, 0.25)), Vector3(x + bw * 0.5, y + 0.014 + bh * 0.5, 0.02), Art.color_mat(col.lerp(Color(0.5, 0.45, 0.4), 0.25), 0.7), 0.004, Vector3(0, 0, lean))
			x += bw + 0.004
	Art.add_collider(b, Vector3(w, hgt, 0.36), Vector3(0, hgt * 0.5, 0))


func _medicine_cabinet(pos: Vector3) -> void:
	var c := Node3D.new()
	c.position = pos
	add_child(c)
	Art.add_rbox(c, Vector3(1.0, 1.9, 0.4), Vector3(0, 0.95, 0), Art.mat("white_plastic"), 0.015)
	Art.add_rbox(c, Vector3(0.94, 1.0, 0.01), Vector3(0, 1.35, -0.2), Art.mat("glass"), 0.003)
	for i in range(3):
		Art.add_rbox(c, Vector3(0.9, 0.015, 0.34), Vector3(0, 0.95 + i * 0.3, 0), Art.mat("glass"), 0.003)
		for j in range(7):
			var col: Color = [Color(0.95, 0.95, 0.95), Color(0.6, 0.8, 0.9), Color(0.95, 0.85, 0.5), Color(0.9, 0.55, 0.5)][(i + j) % 4]
			Art.add_rbox(c, Vector3(0.09, 0.14, 0.06), Vector3(-0.36 + j * 0.12, 1.03 + i * 0.3, -0.05), Art.color_mat(col, 0.5), 0.008)
	Art.add_collider(c, Vector3(1.0, 1.9, 0.4), Vector3(0, 0.95, 0))


func _coat_rack(pos: Vector3) -> void:
	var r := Node3D.new()
	r.position = pos
	add_child(r)
	Art.add_mesh(r, Art.cylinder(0.18, 0.2, 0.03, 24), Art.mat("dark_metal"), Vector3(0, 0.015, 0))
	Art.add_mesh(r, Art.cylinder(0.015, 0.015, 1.75, 10), Art.mat("dark_metal"), Vector3(0, 0.88, 0))
	# Blouse blanche suspendue
	var coat := Art.fabric_mat(Color(0.96, 0.96, 0.97))
	Art.add_mesh(r, Art.capsule(0.17, 0.95), coat, Vector3(0.06, 1.2, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.45))
	Art.add_mesh(r, Art.capsule(0.05, 0.6), coat, Vector3(-0.1, 1.25, 0.02), Vector3(0, 0, 8))
	Art.add_mesh(r, Art.capsule(0.05, 0.6), coat, Vector3(0.22, 1.25, 0.02), Vector3(0, 0, -8))
	Art.add_collider(r, Vector3(0.4, 1.8, 0.4), Vector3(0, 0.9, 0))


func _bin(pos: Vector3) -> void:
	Art.add_mesh(self, Art.cylinder(0.14, 0.12, 0.34, 24), Art.mat("brushed_metal"), pos + Vector3(0, 0.17, 0))


func _plant(parent: Node3D, pos: Vector3, size: float) -> void:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	var pot_h := 0.18 * size + 0.05
	Art.add_mesh(p, Art.cylinder(0.12 * size + 0.04, 0.09 * size + 0.03, pot_h, 32), Art.mat("ceramic"), Vector3(0, pot_h * 0.5, 0))
	Art.add_mesh(p, Art.cylinder(0.115 * size + 0.035, 0.115 * size + 0.035, 0.01, 24), Art.mat("soil"), Vector3(0, pot_h - 0.01, 0))
	var leaves := int(10 + size * 10)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 0.07 * size + 0.02
	leaf_mesh.height = (0.07 * size + 0.02) * 2.0
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 6
	for i in range(leaves):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.02, 0.18) * size
		var y := pot_h + _rng.randf_range(0.1, 0.7) * size
		Art.add_mesh(p, leaf_mesh, Art.mat("leaf"), Vector3(cos(a) * r, y, sin(a) * r),
			Vector3(_rng.randf_range(-40, 40), rad_to_deg(a), _rng.randf_range(-30, 30)), Vector3(0.45, 0.12, 1.4))
	if size > 1.0:
		Art.add_mesh(p, Art.cylinder(0.015, 0.025, 0.7 * size, 8), Art.mat("bark"), Vector3(0, pot_h + 0.35 * size, 0))
		Art.add_collider(p, Vector3(0.4, 1.2, 0.4), Vector3(0, 0.6, 0))


func _frame(pos: Vector3, size: Vector2, text: String) -> void:
	var f := Node3D.new()
	f.position = pos
	add_child(f)
	Art.add_rbox(f, Vector3(size.x, size.y, 0.025), Vector3.ZERO, Art.color_mat(Color(0.12, 0.1, 0.09), 0.4), 0.006)
	Art.add_rbox(f, Vector3(size.x - 0.05, size.y - 0.05, 0.01), Vector3(0, 0, 0.012), Art.color_mat(Color(0.96, 0.94, 0.88), 0.85), 0.002)
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 48
	l.pixel_size = 0.0007
	l.modulate = Color(0.2, 0.18, 0.15)
	l.outline_size = 0
	l.position = Vector3(0, 0.0, 0.019)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.shaded = true
	f.add_child(l)
	Art.add_mesh(f, Art.cylinder(0.025, 0.025, 0.004, 20), Art.color_mat(Color(0.75, 0.6, 0.2), 0.3, 0.8), Vector3(0, -size.y * 0.3, 0.018), Vector3(90, 0, 0))


func _label_panel(parent: Node3D, pos: Vector3, size: Vector2, text: String, bg: Color, fg: Color, pixel: float, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	parent.add_child(n)
	Art.add_rbox(n, Vector3(size.x, size.y, 0.012), Vector3.ZERO, Art.color_mat(bg, 0.6), 0.004)
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = 64
	l.pixel_size = pixel
	l.modulate = fg
	l.outline_size = 0
	l.position = Vector3(0, 0, 0.008)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.shaded = true
	n.add_child(l)
	return n


func _wall_clock(pos: Vector3) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation_degrees = Vector3(0, 90, 0)
	add_child(c)
	Art.add_mesh(c, Art.cylinder(0.17, 0.17, 0.04, 48), Art.mat("dark_metal"), Vector3(0, 0, 0.0), Vector3(90, 0, 0))
	Art.add_mesh(c, Art.cylinder(0.155, 0.155, 0.01, 48), Art.color_mat(Color(0.97, 0.97, 0.96), 0.5), Vector3(0, 0, 0.018), Vector3(90, 0, 0))
	for i in range(12):
		var a := TAU * i / 12.0
		var long := i % 3 == 0
		Art.add_rbox(c, Vector3(0.008, 0.03 if long else 0.016, 0.004), Vector3(sin(a) * 0.13, cos(a) * 0.13, 0.024), Art.mat("black_plastic"), 0.001, Vector3(0, 0, -rad_to_deg(a)))
	_clock_hour = Node3D.new()
	_clock_hour.position = Vector3(0, 0, 0.026)
	c.add_child(_clock_hour)
	Art.add_rbox(_clock_hour, Vector3(0.012, 0.08, 0.004), Vector3(0, 0.035, 0), Art.mat("black_plastic"), 0.002)
	_clock_minute = Node3D.new()
	_clock_minute.position = Vector3(0, 0, 0.03)
	c.add_child(_clock_minute)
	Art.add_rbox(_clock_minute, Vector3(0.008, 0.12, 0.004), Vector3(0, 0.05, 0), Art.mat("black_plastic"), 0.002)
	Art.add_mesh(c, Art.cylinder(0.008, 0.008, 0.012, 12), Art.color_mat(Color(0.8, 0.15, 0.1), 0.4), Vector3(0, 0, 0.033), Vector3(90, 0, 0))


# --- Salle d'attente et accueil ------------------------------------------------------

func _build_waiting_room() -> void:
	for x in WAIT_SEATS_X:
		_guest_chair(Vector3(x, 0, WAIT_SEAT_Z - 0.05), 180.0, Color(0.72, 0.42, 0.25))
	# Table basse avec magazines
	var t := Node3D.new()
	t.position = Vector3(-1.05, 0, 0.55)
	add_child(t)
	Art.add_rbox(t, Vector3(0.6, 0.03, 0.6), Vector3(0, 0.45, 0), Art.mat("wood"), 0.01)
	Art.add_mesh(t, Art.cylinder(0.03, 0.03, 0.44, 12), Art.mat("dark_metal"), Vector3(0, 0.22, 0))
	Art.add_mesh(t, Art.cylinder(0.2, 0.22, 0.02, 24), Art.mat("dark_metal"), Vector3(0, 0.01, 0))
	for i in range(4):
		var col: Color = [Color(0.85, 0.25, 0.2), Color(0.2, 0.45, 0.75), Color(0.95, 0.8, 0.3), Color(0.3, 0.6, 0.4)][i]
		Art.add_rbox(t, Vector3(0.21, 0.006, 0.28), Vector3(_rng.randf_range(-0.12, 0.12), 0.47 + i * 0.007, _rng.randf_range(-0.1, 0.1)), Art.color_mat(col, 0.5), 0.002, Vector3(0, _rng.randf_range(-40, 40), 0))
	Art.add_collider(t, Vector3(0.6, 0.5, 0.6), Vector3(0, 0.25, 0))

	# Fontaine à eau
	var w := Node3D.new()
	w.position = Vector3(-0.42, 0, 2.3)
	add_child(w)
	Art.add_rbox(w, Vector3(0.32, 1.0, 0.32), Vector3(0, 0.5, 0), Art.mat("white_plastic"), 0.03)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.55, 0.75, 0.95, 0.45)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	Art.add_mesh(w, Art.cylinder(0.13, 0.13, 0.4, 32), water, Vector3(0, 1.22, 0))
	Art.add_rbox(w, Vector3(0.12, 0.06, 0.05), Vector3(-0.17, 0.75, 0), Art.mat("dark_metal"), 0.01)
	Art.add_collider(w, Vector3(0.34, 1.4, 0.34), Vector3(0, 0.7, 0))

	# Plantes
	_plant(self, Vector3(-6.5, 0, 0.55), 1.5)
	_plant(self, Vector3(-0.5, 0, 5.5), 1.3)

	# Comptoir d'accueil
	var r := Node3D.new()
	r.name = "Reception"
	r.position = Vector3(-5.9, 0, 3.5)
	add_child(r)
	Art.add_rbox(r, Vector3(0.12, 1.08, 2.0), Vector3(0.05, 0.54, 0), Art.mat("wood_light"), 0.02)
	Art.add_rbox(r, Vector3(0.38, 0.04, 2.1), Vector3(0.06, 1.1, 0), Art.color_mat(Color(0.92, 0.92, 0.9), 0.2), 0.012)
	Art.add_rbox(r, Vector3(0.6, 0.035, 2.0), Vector3(-0.3, 0.74, 0), Art.mat("wood"), 0.01)
	Art.add_rbox(r, Vector3(0.016, 0.6, 1.9), Vector3(0.118, 0.5, 0), Art.color_mat(Color(0.12, 0.45, 0.48), 0.4), 0.004)
	Art.add_collider(r, Vector3(0.5, 1.12, 2.1), Vector3(0, 0.56, 0))
	var mon := Node3D.new()
	mon.position = Vector3(-0.32, 0.76, -0.3)
	mon.rotation_degrees = Vector3(0, -90, 0)
	r.add_child(mon)
	Art.add_rbox(mon, Vector3(0.05, 0.28, 0.025), Vector3(0, 0.14, -0.03), Art.mat("dark_metal"), 0.008)
	Art.add_rbox(mon, Vector3(0.52, 0.32, 0.025), Vector3(0, 0.34, 0.0), Art.mat("black_plastic"), 0.01)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 0.5, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.6, 0.7)
	glow.emission_energy_multiplier = 0.6
	Art.add_rbox(mon, Vector3(0.49, 0.29, 0.004), Vector3(0, 0.34, 0.0135), glow, 0.002)
	_label_panel(self, Vector3(-6.9 + T * 0.5, 2.25, 3.5), Vector2(1.2, 0.22), "ACCUEIL", Color(0.1, 0.45, 0.48), Color(1, 1, 1), 0.0022, Vector3(0, 90, 0))
	# Chaise et secrétaire
	_office_chair(Vector3(-6.45, 0, 3.5), 90.0)
	secretary = Humanoid.new()
	secretary.name = "Camille"
	add_child(secretary)
	secretary.setup({"skin": 1, "hair": "bun", "hair_color": Color(0.42, 0.24, 0.12), "top": Color(0.86, 0.84, 0.8), "bottom": Color(0.18, 0.2, 0.26), "height": 0.97}, 4242)
	secretary.place_seated(Vector3(-6.4, 0, 3.5), Vector3(1, 0, 0), 0.5, true)

	# Affiches de prévention
	_poster(Vector3(-3.0, 1.55, 6 - T * 0.5 - 0.01), Vector2(0.6, 0.85), "VACCINATION\nGRIPPE", "Protégez-vous,\nprotégez les autres", Color(0.12, 0.42, 0.55), Vector3(0, 180, 0))
	_poster(Vector3(-1.9, 1.55, 6 - T * 0.5 - 0.01), Vector2(0.6, 0.85), "MANGER\nBOUGER", "5 fruits et légumes\npar jour", Color(0.88, 0.45, 0.18), Vector3(0, 180, 0))
	_poster(Vector3(-T * 0.5 - 0.01, 1.6, 1.4), Vector2(0.7, 0.95), "URGENCE ?", "SAMU : 15\nPompiers : 18\nEuropéen : 112", Color(0.75, 0.15, 0.18), Vector3(0, -90, 0))
	# Écran d'information
	var tv := Node3D.new()
	tv.position = Vector3(-5.6, 2.0, 6 - T * 0.5 - 0.04)
	tv.rotation_degrees = Vector3(0, 180, 0)
	add_child(tv)
	Art.add_rbox(tv, Vector3(1.1, 0.64, 0.05), Vector3.ZERO, Art.mat("black_plastic"), 0.01)
	var tv_mat := StandardMaterial3D.new()
	tv_mat.albedo_color = Color(0.1, 0.35, 0.45)
	tv_mat.emission_enabled = true
	tv_mat.emission = Color(0.12, 0.45, 0.55)
	tv_mat.emission_energy_multiplier = 0.8
	Art.add_rbox(tv, Vector3(1.06, 0.6, 0.004), Vector3(0, 0, 0.026), tv_mat, 0.002)
	var tvl := Label3D.new()
	tvl.text = "Cabinet médical de Saint-Aubin\nMerci de patienter, le médecin\nva vous recevoir."
	tvl.font = _font
	tvl.font_size = 48
	tvl.pixel_size = 0.0011
	tvl.position = Vector3(0, 0, 0.03)
	tvl.modulate = Color(1, 1, 1)
	tvl.outline_size = 0
	tv.add_child(tvl)


func _poster(pos: Vector3, size: Vector2, title: String, body: String, col: Color, rot: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	add_child(n)
	Art.add_rbox(n, Vector3(size.x + 0.03, size.y + 0.03, 0.012), Vector3.ZERO, Art.color_mat(Color(0.95, 0.95, 0.95), 0.5), 0.003)
	Art.add_rbox(n, Vector3(size.x, size.y * 0.55, 0.004), Vector3(0, size.y * 0.22, 0.007), Art.color_mat(col, 0.6), 0.002)
	var l := Label3D.new()
	l.text = title
	l.font = load("res://assets/fonts/InterDisplay-Bold.ttf")
	l.font_size = 64
	l.pixel_size = 0.0012
	l.modulate = Color(1, 1, 1)
	l.outline_size = 0
	l.position = Vector3(0, size.y * 0.22, 0.011)
	l.shaded = true
	n.add_child(l)
	var b := Label3D.new()
	b.text = body
	b.font = _font
	b.font_size = 40
	b.pixel_size = 0.0011
	b.modulate = Color(0.15, 0.15, 0.18)
	b.outline_size = 0
	b.position = Vector3(0, -size.y * 0.27, 0.008)
	b.shaded = true
	n.add_child(b)


# --- Extérieur --------------------------------------------------------------------------

func _build_exterior() -> void:
	var ground := Art.add_mesh(self, Art.box_mesh(Vector3(90, 0.2, 90)), Art.mat("grass"), Vector3(0, -0.16, 0))
	ground.name = "Ground"
	Art.add_collider(self, Vector3(90, 0.2, 90), Vector3(0, -0.16, 0))
	# Trottoir et route au sud
	Art.add_mesh(self, Art.box_mesh(Vector3(40, 0.12, 4.0)), Art.mat("floor_outside"), Vector3(0, -0.06, 8.2))
	Art.add_mesh(self, Art.box_mesh(Vector3(60, 0.1, 8.0)), Art.mat("asphalt"), Vector3(0, -0.1, 14.2))
	for i in range(-6, 7):
		Art.add_mesh(self, Art.box_mesh(Vector3(2.0, 0.01, 0.14)), Art.color_mat(Color(0.9, 0.9, 0.85), 0.6), Vector3(i * 4.5, -0.045, 14.2))
	Art.add_rbox(self, Vector3(40, 0.14, 0.2), Vector3(0, -0.03, 10.25), Art.color_mat(Color(0.6, 0.6, 0.58), 0.8), 0.02)
	# Socle du bâtiment
	Art.add_mesh(self, Art.box_mesh(Vector3(13.6, 0.12, 6.6)), Art.color_mat(Color(0.5, 0.5, 0.48), 0.9), Vector3(-0.5, -0.07, 3))

	# Arbres
	for p in [Vector3(-10, 0, -4), Vector3(-3, 0, -5.5), Vector3(4, 0, -4.5), Vector3(10, 0, -2), Vector3(9.5, 0, 4.5),
			Vector3(-12, 0, 6), Vector3(5, 0, 19.5), Vector3(-8, 0, 20), Vector3(14, 0, 20), Vector3(-17, 0, 0)]:
		_tree(p)
	# Haie
	for i in range(8):
		Art.add_mesh(self, Art.sphere(0.6, 16), Art.mat("foliage"), Vector3(1.0 + i * 0.75, 0.45, 7.0), Vector3.ZERO, Vector3(1.0, 0.8, 0.9))
	# Maisons en face
	for i in range(4):
		_house(Vector3(-15 + i * 10, 0, 23), i)
	# Maisons derrière
	for i in range(3):
		_house(Vector3(-12 + i * 11, 0, -14), i + 4, true)
	# Panneau du cabinet
	var sign := Node3D.new()
	sign.position = Vector3(-6.2, 0, 7.6)
	add_child(sign)
	Art.add_mesh(sign, Art.cylinder(0.03, 0.03, 1.4, 10), Art.mat("dark_metal"), Vector3(-0.4, 0.7, 0))
	Art.add_mesh(sign, Art.cylinder(0.03, 0.03, 1.4, 10), Art.mat("dark_metal"), Vector3(0.4, 0.7, 0))
	_label_panel(sign, Vector3(0, 1.25, 0.02), Vector2(1.1, 0.5), "CABINET MÉDICAL\nMédecine générale", Color(0.1, 0.42, 0.45), Color(1, 1, 1), 0.0016)
	# Limites invisibles
	for b in [[Vector3(60, 4, 1), Vector3(0, 2, 17.5)], [Vector3(60, 4, 1), Vector3(0, 2, -7)], [Vector3(1, 4, 30), Vector3(-14, 2, 5)], [Vector3(1, 4, 30), Vector3(13, 2, 5)]]:
		Art.add_collider(self, b[0], b[1])


func _tree(pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	add_child(t)
	var h := _rng.randf_range(3.5, 5.5)
	Art.add_mesh(t, Art.cylinder(0.12, 0.2, h, 12), Art.mat("bark"), Vector3(0, h * 0.5, 0))
	for i in range(6):
		var r := _rng.randf_range(1.0, 1.7)
		Art.add_mesh(t, Art.sphere(r, 16), Art.mat("foliage"), Vector3(_rng.randf_range(-0.9, 0.9), h + _rng.randf_range(-0.6, 0.9), _rng.randf_range(-0.9, 0.9)))
	Art.add_collider(t, Vector3(0.4, 3, 0.4), Vector3(0, 1.5, 0))


func _house(pos: Vector3, idx: int, back: bool = false) -> void:
	var colors := [Color(0.92, 0.88, 0.8), Color(0.85, 0.8, 0.72), Color(0.95, 0.93, 0.88), Color(0.82, 0.76, 0.66), Color(0.9, 0.85, 0.78), Color(0.88, 0.84, 0.8), Color(0.93, 0.9, 0.84)]
	var h := Node3D.new()
	h.position = pos
	if back:
		h.rotation_degrees.y = 180
	add_child(h)
	var w := 7.0
	var hh := 5.5 if idx % 2 == 0 else 4.2
	Art.add_mesh(h, Art.box_mesh(Vector3(w, hh, 7)), Art.color_mat(colors[idx % colors.size()], 0.9), Vector3(0, hh * 0.5, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 0.6, 2.4, 7.6)
	Art.add_mesh(h, roof, Art.color_mat(Color(0.35, 0.36, 0.4), 0.7), Vector3(0, hh + 1.2, 0))
	var win := Art.color_mat(Color(0.15, 0.2, 0.25), 0.05, 0.5)
	for x in [-2.2, 0.0, 2.2]:
		for y in ([1.4, 3.8] if hh > 5.0 else [1.4]):
			Art.add_mesh(h, Art.box_mesh(Vector3(1.0, 1.2, 0.1)), win, Vector3(x, y, -3.52))
			Art.add_mesh(h, Art.box_mesh(Vector3(1.15, 0.08, 0.16)), Art.color_mat(Color(0.95, 0.95, 0.95), 0.5), Vector3(x, y - 0.64, -3.55))


# --- Éclairage intérieur -----------------------------------------------------------------

func _build_lights() -> void:
	var panels := [
		[Vector3(2.0, H - 0.02, 2.0), true], [Vector3(4.2, H - 0.02, 3.8), false],
		[Vector3(-1.8, H - 0.02, 3.0), true], [Vector3(-4.0, H - 0.02, 2.0), false], [Vector3(-5.6, H - 0.02, 4.2), false],
	]
	for p in panels:
		var pos: Vector3 = p[0]
		Art.add_rbox(self, Vector3(1.2, 0.03, 0.6), pos, Art.color_mat(Color(0.9, 0.9, 0.9), 0.4), 0.01)
		Art.add_mesh(self, Art.box_mesh(Vector3(1.12, 0.01, 0.52)), Art.mat("light_panel"), pos + Vector3(0, -0.016, 0))
		var l := OmniLight3D.new()
		l.position = pos + Vector3(0, -0.25, 0)
		l.light_color = Color(1.0, 0.95, 0.88)
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = p[1]
		l.light_size = 0.4
		l.light_specular = 0.2
		add_child(l)
	for probe_data in [[Vector3(3, 1.4, 3), Vector3(6, 2.8, 6)], [Vector3(-3.5, 1.4, 3), Vector3(7, 2.8, 6)]]:
		var probe := ReflectionProbe.new()
		probe.position = probe_data[0]
		probe.size = probe_data[1]
		probe.box_projection = true
		probe.interior = true
		probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(probe)
