class_name AudioLib
extends RefCounted
## Sons enregistrés (assets/audio, générés par tools/build_audio.py) : voix des PNJ,
## chants de foule, bruitages. Enveloppes (synchro labiale, 20 Hz) et temps forts des chants.

const DIR := "res://assets/audio/"
const ENV_HZ := 20.0

static var _data := {}
static var _streams := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DIR + "audio.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		if _data.is_empty():
			_data = {"env": {}, "voices": {}, "beats": {}}
	return _data


static func stream(sound: String, loop := false) -> AudioStream:
	var key := sound + ("#loop" if loop else "")
	if not _streams.has(key):
		var s: AudioStream = load(DIR + sound + ".ogg")
		if loop and s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			(s as AudioStreamOggVorbis).loop = true
		_streams[key] = s
	return _streams[key]


## Nom d'une réplique au hasard : voix ("m1", "m2", "f1") + catégorie ("ouais", "talk"...)
static func pick(voice: String, cat: String) -> String:
	var v: Dictionary = data().get("voices", {})
	var lst: Array = v.get(voice + "_" + cat, [])
	if lst.is_empty():
		return ""
	return lst[randi() % lst.size()]


static func count(voice: String, cat: String) -> int:
	var v: Dictionary = data().get("voices", {})
	return (v.get(voice + "_" + cat, []) as Array).size()


static func env(sound: String) -> Array:
	return (data().get("env", {}) as Dictionary).get(sound, [])


## Valeur de l'enveloppe (0..1) à l'instant t (s)
static func env_at(e: Array, t: float) -> float:
	if e.is_empty() or t < 0.0:
		return 0.0
	var x := t * ENV_HZ
	var i := int(x)
	if i >= e.size() - 1:
		return 0.0 if i >= e.size() else float(e[i])
	return lerpf(float(e[i]), float(e[i + 1]), x - i)


static func beats(chant: String) -> Array:
	return (data().get("beats", {}) as Dictionary).get(chant, [])


## Lecteur 3D jetable
static func play_at(parent: Node, sound: String, pos: Vector3, vol := 0.0, unit := 8.0, pitch := 1.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var a := AudioStreamPlayer3D.new()
	a.stream = Sfx.get_stream(StringName(sound.substr(4))) if sound.begins_with("sfx:") else stream(sound)
	a.bus = Settings.bus_for(sound)
	a.volume_db = vol
	a.unit_size = unit
	a.pitch_scale = pitch
	a.max_distance = 120.0
	var host: Node = parent.get_tree().current_scene
	if host == null:
		host = parent
	host.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)
	return a
