extends Node
## Gestion du son : bus audio (Musique, Ambiance, Effets, Voix, Interface),
## sons d'interface, sons ponctuels positionnés, ambiances en boucle.
## Chargé en autoload sous le nom « Sfx ».

const BUSES := ["Music", "Ambience", "SFX", "Voice", "UI", "Phone"]
const DIR := "res://assets/audio/"

var _cache: Dictionary = {}
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _music: AudioStreamPlayer
var _music_tween: Tween
var _steth: AudioStreamPlayer
var _steth_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_ui_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_steth = AudioStreamPlayer.new()
	_steth.bus = "SFX"
	add_child(_steth)
	Game.settings_changed.connect(apply_volumes)
	apply_volumes()


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	# Légère réverbération de pièce sur les voix et les effets.
	var voice := AudioServer.get_bus_index("Voice")
	if AudioServer.get_bus_effect_count(voice) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.25
		rv.damping = 0.6
		rv.wet = 0.08
		rv.dry = 1.0
		AudioServer.add_bus_effect(voice, rv)
	var phone := AudioServer.get_bus_index("Phone")
	AudioServer.set_bus_send(phone, "Voice")
	if AudioServer.get_bus_effect_count(phone) == 0:
		var bp := AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1600.0
		bp.resonance = 0.6
		AudioServer.add_bus_effect(phone, bp)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = 0.15
		dist.post_gain = -3.0
		AudioServer.add_bus_effect(phone, dist)
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv2 := AudioEffectReverb.new()
		rv2.room_size = 0.3
		rv2.damping = 0.5
		rv2.wet = 0.1
		AudioServer.add_bus_effect(sfx, rv2)


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_vol("Master", float(s.get("vol_master", 0.9)))
	_set_vol("Music", float(s.get("vol_music", 0.6)))
	_set_vol("Ambience", float(s.get("vol_ambience", 0.7)))
	_set_vol("SFX", float(s.get("vol_sfx", 0.85)))
	_set_vol("Voice", float(s.get("vol_voice", 1.0)))
	_set_vol("UI", float(s.get("vol_ui", 0.7)))


func _set_vol(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Charge un son (ogg ou wav) depuis assets/audio, avec cache.
func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var p: String = DIR + name + ext
		if ResourceLoader.exists(p):
			s = load(p)
			break
	_cache[name] = s
	return s


## Son d'interface (non positionné).
func ui(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream("ui/" + name)
	if s == null:
		return
	var p := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Son ponctuel non positionné sur un bus donné.
func play(name: String, bus: String = "SFX", volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var s := stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Son ponctuel positionné dans le monde.
func play_at(name: String, pos: Vector3, parent: Node, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> AudioStreamPlayer3D:
	var s := stream(name)
	if s == null or parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = 30.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Boucle d'ambiance attachée à un nœud (le lecteur est renvoyé).
func loop_at(name: String, parent: Node3D, pos: Vector3, volume_db: float = 0.0, unit_size: float = 6.0, bus: String = "Ambience") -> AudioStreamPlayer3D:
	var s := stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = 60.0
	p.autoplay = true
	parent.add_child(p)
	p.global_position = pos
	if not p.playing:
		p.play()
	return p


func music(name: String, fade: float = 2.0) -> void:
	var s := stream("music/" + name) if name != "" else null
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	if _music.playing:
		_music_tween.tween_property(_music, "volume_db", -40.0, fade * 0.5)
	_music_tween.tween_callback(func():
		_music.stop()
		if s:
			_music.stream = s
			_music.volume_db = -40.0
			_music.play())
	if s:
		_music_tween.tween_property(_music, "volume_db", 0.0, fade)


## Joue un flux audio directement (ex. voix au téléphone).
func play_stream(s: AudioStream, bus: String = "Voice", volume_db: float = 0.0, phone: bool = false) -> AudioStreamPlayer:
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "Phone" if phone else bus
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Sons entendus dans le stéthoscope (boucle tant qu'on écoute).
func stethoscope(state: String, heart: bool, hr: int) -> void:
	var name := ""
	if heart:
		name = "steth/heart_rapide" if (state == "rapide" or hr > 95) else "steth/heart_normal"
	else:
		name = "steth/lung_" + (state if state in ["sibilants", "crepitants"] else "normal")
	if name == _steth_name and _steth.playing:
		return
	var s := stream(name)
	if s == null:
		return
	_steth_name = name
	_steth.stream = s
	_steth.volume_db = -2.0
	_steth.play()
	# Les autres sons sont atténués pendant l'auscultation.
	_set_vol("Ambience", float(Game.settings.get("vol_ambience", 0.7)) * 0.25)


func stethoscope_stop() -> void:
	if _steth.playing:
		_steth.stop()
	_steth_name = ""
	_set_vol("Ambience", float(Game.settings.get("vol_ambience", 0.7)))
