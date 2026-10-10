class_name Settings
extends RefCounted
## Réglages du joueur (son, image, jeu) : enregistrés dans user://settings.cfg, appliqués au moteur,
## à l'environnement 3D et aux bus audio. Tout est lu via Settings.d["clé"].

const PATH := "user://settings.cfg"

const DEFAULTS := {
	# son
	"master": 0.85, "effects": 1.0, "voices": 1.0, "ambience": 0.9,
	# jeu
	"sensitivity": 1.0, "invert_y": false, "fov": 72.0, "head_bob": true, "screen_shake": 1.0,
	"gas_fx": 1.0, "show_help": true, "tension_gain": 1.0, "subtitles": true,
	# image
	"quality": 2, "shadows": true, "ssao": true, "ssil": false, "ssr": true, "glow": true, "volfog": true,
	"msaa": 1, "render_scale": 1.0, "vsync": true, "fullscreen": false, "brightness": 1.0, "fps_cap": 0,
	"smoke_q": 1,
}


## Densité des fumées selon le réglage (Basse / Moyenne / Haute) : moins de particules, chacune un peu plus opaque
static func smoke_k() -> float:
	return [0.35, 0.55, 1.0][clampi(int(d.get("smoke_q", 1)), 0, 2)]

const QUALITY_NAMES := ["Bas", "Moyen", "Élevé", "Ultra"]
const PRESETS := [
	{"shadows": false, "ssao": false, "ssil": false, "ssr": false, "glow": true, "volfog": false, "msaa": 0, "render_scale": 0.75},
	{"shadows": true, "ssao": false, "ssil": false, "ssr": false, "glow": true, "volfog": false, "msaa": 0, "render_scale": 0.9},
	{"shadows": true, "ssao": true, "ssil": false, "ssr": true, "glow": true, "volfog": true, "msaa": 1, "render_scale": 1.0},
	{"shadows": true, "ssao": true, "ssil": true, "ssr": true, "glow": true, "volfog": true, "msaa": 2, "render_scale": 1.0},
]

static var d: Dictionary = DEFAULTS.duplicate()
static var _loaded := false
static var _buses_ready := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("settings", k):
				var v: Variant = cf.get_value("settings", k)
				if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
					d[k] = v


static func save_all() -> void:
	var cf := ConfigFile.new()
	for k in d:
		cf.set_value("settings", k, d[k])
	cf.save(PATH)


static func reset() -> void:
	d = DEFAULTS.duplicate()


static func set_quality(q: int) -> void:
	q = clampi(q, 0, PRESETS.size() - 1)
	d["quality"] = q
	for k in PRESETS[q]:
		d[k] = PRESETS[q][k]


# ------------------------------------------------------------------ bus audio
static func ensure_buses() -> void:
	if _buses_ready:
		return
	_buses_ready = true
	for nm in ["Effets", "Voix", "Ambiance"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")


static func bus_for(sound: String) -> StringName:
	ensure_buses()
	if sound.begins_with("v_") or sound.begins_with("player_call") or sound.begins_with("cough") or sound.begins_with("megaphone") or sound.begins_with("pol_mega"):
		return &"Voix"
	for p in ["chant_", "crowd_", "applause", "cheer", "claps", "clap_", "awe", "panic"]:
		if sound.begins_with(p):
			return &"Ambiance"
	return &"Effets"


## Acouphène : filtre passe-bas progressif sur les bus d'effets, d'ambiance et de voix (k de 0 à 1)
static var _ring_fx: AudioEffectLowPassFilter
static var _ring_on := false


static func set_ring(k: float) -> void:
	ensure_buses()
	if k <= 0.001:
		if _ring_on and _ring_fx != null:
			for nm in ["Effets", "Ambiance", "Voix"]:
				var bi := AudioServer.get_bus_index(nm)
				for i in range(AudioServer.get_bus_effect_count(bi) - 1, -1, -1):
					if AudioServer.get_bus_effect(bi, i) == _ring_fx:
						AudioServer.remove_bus_effect(bi, i)
			_ring_on = false
		return
	if _ring_fx == null:
		_ring_fx = AudioEffectLowPassFilter.new()
	if not _ring_on:
		for nm in ["Effets", "Ambiance", "Voix"]:
			AudioServer.add_bus_effect(AudioServer.get_bus_index(nm), _ring_fx)
		_ring_on = true
	_ring_fx.cutoff_hz = lerpf(20000.0, 650.0, clampf(k, 0.0, 1.0))


static func _vol(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001)) if v > 0.001 else -80.0


# ------------------------------------------------------------------ application
static func apply(tree: SceneTree) -> void:
	load_all()
	ensure_buses()
	AudioServer.set_bus_volume_db(0, _vol(float(d["master"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effets"), _vol(float(d["effects"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voix"), _vol(float(d["voices"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambiance"), _vol(float(d["ambience"])))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if d["vsync"] else DisplayServer.VSYNC_DISABLED)
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if d["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	Engine.max_fps = int(d["fps_cap"])
	var root := tree.root
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(d["msaa"]), 0, 2)]
	var rs := float(d["render_scale"])
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if rs < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = rs
	var scene := tree.current_scene
	if scene == null:
		return
	for n in scene.get_children():
		if n is WorldEnvironment and (n as WorldEnvironment).environment != null:
			var env := (n as WorldEnvironment).environment
			env.ssao_enabled = d["ssao"]
			env.ssil_enabled = d["ssil"]
			env.ssr_enabled = d["ssr"]
			env.glow_enabled = d["glow"]
			env.volumetric_fog_enabled = d["volfog"]
			env.adjustment_enabled = true
			env.adjustment_brightness = float(d["brightness"])
		elif n is DirectionalLight3D and (n as DirectionalLight3D).light_energy > 1.0:
			(n as DirectionalLight3D).shadow_enabled = d["shadows"]


## Les nouveaux lecteurs audio sans bus explicite vont sur « Effets »
static func route_player(n: Node) -> void:
	if n is AudioStreamPlayer3D or n is AudioStreamPlayer:
		if n.bus == &"Master":
			n.bus = &"Effets"
