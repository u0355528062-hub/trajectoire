class_name Lighting
extends RefCounted
## Lumière et atmosphère du quartier selon le moment de la journée et la météo : ciel, environnement
## (tonemapping, SSAO/SSIL/SSR, glow, brouillard volumétrique, étalonnage), soleil/lune et lumière de remplissage.
## `build` ajoute WorldEnvironment, lumières et le nœud Weather (pluie, sol mouillé, éclairage urbain selon l'heure)
## comme enfants directs de `parent` (Settings.apply les y retrouve).

const TODS := ["aube", "matin", "midi", "aprem", "crepuscule", "nuit"]
const WEATHERS := ["sec", "bruine", "pluie", "brume"]

## Ciel par défaut (= crépuscule) ; chaque moment n'indique que ce qui change
const SKY_BASE := {
	"zenith_color": Color(0.012, 0.025, 0.11), "mid_color": Color(0.12, 0.17, 0.42), "horizon_color": Color(1.0, 0.52, 0.28),
	"ground_color": Color(0.16, 0.14, 0.17), "star_amount": 0.8, "cloud_cover": 0.52, "cloud_lit": Color(1.0, 0.62, 0.36),
	"cloud_shade": Color(0.2, 0.17, 0.3), "cloud_scale": 1.0, "overcast": 0.0, "halo_color": Color(1.0, 0.45, 0.2), "halo_k": 0.35,
	"glare_color": Color(1.0, 0.7, 0.4), "glare_k": 0.8, "disc_color": Color(1.0, 0.9, 0.7), "disc_k": 3.0, "city_glow": Color(0, 0, 0),
}

## Réglages par moment : soleil (élévation, cap en degrés), remplissage, ambiance, exposition, brouillards, étalonnage,
## ciel, éclairage urbain (lamps : lampadaires allumés ; win : émission des fenêtres allumées / tamisées), couleur de pluie
const TOD := {
	"crepuscule": {
		"sun": Vector2(13.0, 28.0), "sun_col": Color(1.0, 0.68, 0.47), "sun_e": 2.8, "sun_ang": 0.8,
		"fill": Vector2(35.0, 145.0), "fill_col": Color(0.35, 0.5, 1.0), "fill_e": 0.35,
		"amb": Color(0.5, 0.53, 0.62), "amb_e": 0.85, "exp": 1.05,
		"fog": Color(0.56, 0.52, 0.52), "fog_d": 0.0007, "fog_sun": 0.1, "aerial": 0.35,
		"vfog_d": 0.0022, "vfog_alb": Color(0.8, 0.8, 0.82), "vfog_em": Color(0.02, 0.025, 0.05), "vfog_em_e": 0.5, "vfog_aniso": 0.3,
		"contrast": 1.07, "sat": 1.0, "sky": {},
		"lamps": true, "win": Vector2(1.2, 0.16), "rain_col": Color(0.75, 0.7, 0.72),
	},
	"aube": {
		"sun": Vector2(5.0, -92.0), "sun_col": Color(1.0, 0.68, 0.5), "sun_e": 1.8, "sun_ang": 1.0,
		"fill": Vector2(40.0, 88.0), "fill_col": Color(0.62, 0.68, 1.0), "fill_e": 0.28,
		"amb": Color(0.54, 0.55, 0.64), "amb_e": 0.72, "exp": 1.12,
		"fog": Color(0.66, 0.62, 0.66), "fog_d": 0.0016, "fog_sun": 0.3, "aerial": 0.5,
		"vfog_d": 0.006, "vfog_alb": Color(0.86, 0.86, 0.9), "vfog_em": Color(0.03, 0.035, 0.06), "vfog_em_e": 0.5, "vfog_aniso": 0.55,
		"contrast": 1.04, "sat": 0.98,
		"sky": {"zenith_color": Color(0.24, 0.27, 0.42), "mid_color": Color(0.55, 0.54, 0.64), "horizon_color": Color(1.0, 0.7, 0.54),
			"ground_color": Color(0.18, 0.17, 0.2), "star_amount": 0.12, "cloud_cover": 0.4, "cloud_lit": Color(1.0, 0.72, 0.58),
			"cloud_shade": Color(0.38, 0.35, 0.48), "halo_color": Color(1.0, 0.58, 0.38)},
		"lamps": true, "win": Vector2(0.75, 0.12), "rain_col": Color(0.72, 0.72, 0.78),
	},
	"matin": {
		"sun": Vector2(30.0, -142.0), "sun_col": Color(1.0, 0.92, 0.82), "sun_e": 2.5, "sun_ang": 0.6,
		"fill": Vector2(50.0, 38.0), "fill_col": Color(0.72, 0.8, 1.0), "fill_e": 0.3,
		"amb": Color(0.6, 0.63, 0.7), "amb_e": 0.8, "exp": 0.95,
		"fog": Color(0.68, 0.74, 0.84), "fog_d": 0.0006, "fog_sun": 0.15, "aerial": 0.5,
		"vfog_d": 0.0015, "vfog_alb": Color(0.9, 0.92, 0.95), "vfog_em": Color(0, 0, 0), "vfog_em_e": 0.0, "vfog_aniso": 0.5,
		"contrast": 1.05, "sat": 1.02,
		"sky": {"zenith_color": Color(0.2, 0.36, 0.68), "mid_color": Color(0.45, 0.6, 0.82), "horizon_color": Color(0.74, 0.82, 0.9),
			"ground_color": Color(0.22, 0.22, 0.23), "star_amount": 0.0, "cloud_cover": 0.38, "cloud_lit": Color(1.0, 0.98, 0.95),
			"cloud_shade": Color(0.56, 0.6, 0.7), "halo_color": Color(1.0, 0.95, 0.85), "halo_k": 0.25, "glare_color": Color(1.0, 0.95, 0.85),
			"glare_k": 0.5, "disc_color": Color(1.0, 0.98, 0.92), "disc_k": 4.0},
		"lamps": false, "win": Vector2(0.1, 0.02), "rain_col": Color(0.78, 0.8, 0.84),
	},
	"midi": {
		"sun": Vector2(57.0, 148.0), "sun_col": Color(1.0, 0.97, 0.93), "sun_e": 2.6, "sun_ang": 0.5,
		"fill": Vector2(60.0, -32.0), "fill_col": Color(0.72, 0.8, 1.0), "fill_e": 0.32,
		"amb": Color(0.62, 0.65, 0.72), "amb_e": 0.85, "exp": 0.84,
		"fog": Color(0.7, 0.76, 0.86), "fog_d": 0.0005, "fog_sun": 0.1, "aerial": 0.5,
		"vfog_d": 0.0012, "vfog_alb": Color(0.92, 0.94, 0.96), "vfog_em": Color(0, 0, 0), "vfog_em_e": 0.0, "vfog_aniso": 0.5,
		"contrast": 1.06, "sat": 1.03,
		"sky": {"zenith_color": Color(0.18, 0.34, 0.68), "mid_color": Color(0.42, 0.58, 0.82), "horizon_color": Color(0.7, 0.8, 0.9),
			"ground_color": Color(0.22, 0.22, 0.23), "star_amount": 0.0, "cloud_cover": 0.32, "cloud_lit": Color(1.0, 1.0, 0.98),
			"cloud_shade": Color(0.58, 0.62, 0.72), "halo_color": Color(1.0, 0.97, 0.9), "halo_k": 0.2, "glare_color": Color(1.0, 0.97, 0.9),
			"glare_k": 0.5, "disc_color": Color(1.0, 1.0, 0.95), "disc_k": 4.0},
		"lamps": false, "win": Vector2(0.08, 0.02), "rain_col": Color(0.8, 0.82, 0.86),
	},
	"aprem": {
		"sun": Vector2(27.0, 78.0), "sun_col": Color(1.0, 0.88, 0.72), "sun_e": 2.5, "sun_ang": 0.6,
		"fill": Vector2(45.0, -102.0), "fill_col": Color(0.72, 0.78, 1.0), "fill_e": 0.3,
		"amb": Color(0.62, 0.63, 0.68), "amb_e": 0.8, "exp": 0.95,
		"fog": Color(0.74, 0.72, 0.72), "fog_d": 0.0007, "fog_sun": 0.2, "aerial": 0.45,
		"vfog_d": 0.0018, "vfog_alb": Color(0.92, 0.9, 0.88), "vfog_em": Color(0, 0, 0), "vfog_em_e": 0.0, "vfog_aniso": 0.5,
		"contrast": 1.06, "sat": 1.04,
		"sky": {"zenith_color": Color(0.2, 0.34, 0.64), "mid_color": Color(0.46, 0.57, 0.78), "horizon_color": Color(0.86, 0.82, 0.76),
			"ground_color": Color(0.22, 0.21, 0.21), "star_amount": 0.0, "cloud_cover": 0.42, "cloud_lit": Color(1.0, 0.94, 0.86),
			"cloud_shade": Color(0.5, 0.52, 0.62), "halo_color": Color(1.0, 0.85, 0.6), "halo_k": 0.3, "glare_color": Color(1.0, 0.85, 0.6),
			"glare_k": 0.6, "disc_color": Color(1.0, 0.95, 0.85), "disc_k": 4.0},
		"lamps": false, "win": Vector2(0.12, 0.02), "rain_col": Color(0.8, 0.8, 0.82),
	},
	"nuit": {
		"sun": Vector2(38.0, -60.0), "sun_col": Color(0.62, 0.72, 1.0), "sun_e": 0.1, "sun_ang": 0.5,
		"fill": Vector2(50.0, 120.0), "fill_col": Color(0.3, 0.4, 0.8), "fill_e": 0.06,
		"amb": Color(0.25, 0.27, 0.34), "amb_e": 1.15, "exp": 1.5,
		"fog": Color(0.25, 0.22, 0.22), "fog_d": 0.0012, "fog_sun": 0.0, "aerial": 0.3,
		"vfog_d": 0.004, "vfog_alb": Color(0.7, 0.7, 0.72), "vfog_em": Color(0.035, 0.025, 0.02), "vfog_em_e": 0.6, "vfog_aniso": 0.4,
		"contrast": 1.08, "sat": 1.0,
		"sky": {"zenith_color": Color(0.006, 0.01, 0.03), "mid_color": Color(0.02, 0.03, 0.07), "horizon_color": Color(0.13, 0.09, 0.07),
			"ground_color": Color(0.04, 0.035, 0.035), "star_amount": 0.3, "cloud_cover": 0.45, "cloud_lit": Color(0.2, 0.19, 0.2),
			"cloud_shade": Color(0.07, 0.06, 0.07), "halo_color": Color(0.6, 0.7, 1.0), "halo_k": 0.04, "glare_color": Color(0.7, 0.8, 1.0),
			"glare_k": 0.15, "disc_color": Color(0.9, 0.92, 1.0), "disc_k": 1.6, "city_glow": Color(0.14, 0.1, 0.075)},
		"lamps": true, "win": Vector2(1.4, 0.34), "rain_col": Color(0.7, 0.66, 0.62),
	},
}

## Météo : couvert, atténuation du soleil, brouillards ajoutés, sol mouillé (wet) et pluie (rain : 0 = aucune)
const WEATHER := {
	"sec": {},
	"bruine": {"cover": 0.85, "overcast": 0.6, "cloud_scale": 0.75, "desat": 0.5, "sky_k": 0.85, "sun_k": 0.35, "shadow": 0.5,
		"amb_k": 1.1, "fog_d": 0.0025, "vfog_d": 0.008, "sat_k": 0.9, "wet": 0.55, "rain": 0.35},
	"pluie": {"cover": 1.0, "overcast": 0.95, "cloud_scale": 0.6, "desat": 0.75, "sky_k": 0.6, "sun_k": 0.15, "shadow": 0.2,
		"amb_k": 1.05, "fog_d": 0.004, "vfog_d": 0.012, "sat_k": 0.85, "wet": 1.0, "rain": 1.0},
	"brume": {"cover": 0.9, "overcast": 0.75, "cloud_scale": 0.7, "desat": 0.6, "sky_k": 0.9, "sun_k": 0.4, "shadow": 0.4,
		"amb_k": 1.1, "fog_d": 0.008, "vfog_d": 0.02, "sat_k": 0.88, "wet": 0.25, "rain": 0.0, "mist": true},
}

## Moment et météo de la scène en cours (lus par Weather et les autres modules)
static var tod_now := "crepuscule"
static var weather_now := "sec"


## Construit l'éclairage ; renvoie {"world_env", "env", "sun", "fill", "weather"}
static func build(parent: Node3D, tod := "crepuscule", weather := "sec") -> Dictionary:
	if not TODS.has(tod):
		push_warning("Lighting : moment inconnu « %s », crépuscule utilisé" % tod)
		tod = "crepuscule"
	if not WEATHERS.has(weather):
		push_warning("Lighting : météo inconnue « %s », temps sec utilisé" % weather)
		weather = "sec"
	tod_now = tod
	weather_now = weather
	var t: Dictionary = TOD[tod]
	var w: Dictionary = WEATHER[weather]

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sp := SKY_BASE.duplicate()
	sp.merge(t["sky"], true)
	if not w.is_empty():
		_weather_sky(sp, w, t["fog"])
	for k in sp:
		sky_mat.set_shader_parameter(k, sp[k])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var desat := float(w.get("desat", 0.0))
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _desat(t["amb"], desat * 0.4)
	env.ambient_light_energy = float(t["amb_e"]) * float(w.get("amb_k", 1.0))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(t["exp"])
	env.tonemap_white = 6.0

	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.8
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0

	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.1
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.25
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.6)

	env.fog_enabled = true
	env.fog_light_color = _desat(t["fog"], desat)
	env.fog_light_energy = 1.0
	env.fog_density = float(t["fog_d"]) + float(w.get("fog_d", 0.0))
	env.fog_sun_scatter = float(t["fog_sun"]) * (1.0 - desat)
	env.fog_aerial_perspective = float(t["aerial"])
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = float(t["vfog_d"]) + float(w.get("vfog_d", 0.0))
	env.volumetric_fog_albedo = t["vfog_alb"]
	env.volumetric_fog_emission = t["vfog_em"]
	env.volumetric_fog_emission_energy = float(t["vfog_em_e"])
	env.volumetric_fog_anisotropy = float(t["vfog_aniso"]) * (1.0 - desat * 0.6)
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_gi_inject = 1.0
	if w.get("mist", false):
		# brume : brouillard épais au ras du sol, le ciel s'y perd
		env.fog_sky_affect = 0.6
		env.fog_aerial_perspective = 0.7
		env.volumetric_fog_length = 64.0
	# brouillard de profondeur à ajouter quand le volumétrique est coupé (réglage image), pour garder l'ambiance
	env.set_meta("fog_d", env.fog_density)
	env.set_meta("fog_novol", float(w.get("vfog_d", 0.0)) * 0.35)

	env.adjustment_enabled = true
	env.adjustment_contrast = float(t["contrast"]) * (1.0 - desat * 0.04)
	env.adjustment_saturation = float(t["sat"]) * float(w.get("sat_k", 1.0))

	var we := WorldEnvironment.new()
	we.environment = env
	we.camera_attributes = CameraAttributesPractical.new()
	parent.add_child(we)

	# soleil (ou lune) : ombres longues et douces
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.set_meta("main_light", true)
	var sr: Vector2 = t["sun"]
	sun.rotation_degrees = Vector3(-sr.x, sr.y, 0.0)
	sun.light_color = t["sun_col"]
	sun.light_energy = float(t["sun_e"]) * float(w.get("sun_k", 1.0))
	sun.light_angular_distance = float(t["sun_ang"]) * (1.0 + 3.0 * desat)
	sun.shadow_enabled = true
	sun.shadow_opacity = float(w.get("shadow", 1.0))
	sun.shadow_blur = 1.4 * (1.0 + 2.0 * desat)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	parent.add_child(sun)

	# lumière du ciel opposée (remplissage, sans ombre) ; plus forte sous un ciel couvert (lumière diffuse)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	var fr: Vector2 = t["fill"]
	fill.rotation_degrees = Vector3(-fr.x, fr.y, 0.0)
	fill.light_color = _desat(t["fill_col"], desat * 0.7)
	fill.light_energy = float(t["fill_e"]) * (1.0 + desat * 0.8)
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	parent.add_child(fill)

	var wx := Weather.new()
	wx.name = "Weather"
	wx.setup(tod, weather, t, w)
	parent.add_child(wx)
	return {"world_env": we, "env": env, "sun": sun, "fill": fill, "weather": wx}


## Ciel couvert : nuages plus bas et continus, couleurs grisées et assombries
static func _weather_sky(sp: Dictionary, w: Dictionary, fog: Color) -> void:
	var desat := float(w["desat"])
	var k := float(w["sky_k"])
	sp["cloud_cover"] = maxf(float(sp["cloud_cover"]), float(w["cover"]))
	sp["overcast"] = float(w["overcast"])
	sp["cloud_scale"] = float(w["cloud_scale"])
	sp["star_amount"] = float(sp["star_amount"]) * (1.0 - float(w["overcast"]))
	for key in ["zenith_color", "mid_color", "horizon_color"]:
		sp[key] = _desat(sp[key], desat) * k
	sp["horizon_color"] = (sp["horizon_color"] as Color).lerp(fog * k, desat * 0.5)
	sp["cloud_lit"] = _desat(sp["cloud_lit"], desat) * k * 0.92
	sp["cloud_shade"] = _desat(sp["cloud_shade"], desat) * k
	for key in ["halo_k", "glare_k", "disc_k"]:
		sp[key] = float(sp[key]) * (1.0 - float(w["overcast"]) * 0.8)


static func _desat(c: Color, k: float) -> Color:
	var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	return Color(lerpf(c.r, l, k), lerpf(c.g, l, k), lerpf(c.b, l, k))
