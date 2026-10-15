class_name StoryAudio
extends Node
## Son de l'histoire : ambiances par lieu et moment (rue du matin, nuit, pluie, Zinc, supérette, JT, foule),
## musiques sobres des cinématiques, du bilan JT, de l'échec et des fins. Fondus enchaînés gérés ici (aussi pendant
## la pause). Sons générés par tools/build_audio_story.py (assets/audio/story), bus « Ambiance ».
## Une ambiance de l'histoire remplace la ville générique (Ambient) ; un intérieur étouffe la pluie de Weather.
## Tous les lecteurs sont des enfants : ils disparaissent avec la scène (rechargement de chapitre).

const DIR := "res://assets/audio/story/"
const BUS := &"Ambiance"
const MUSIC_DB := -12.0          # niveau des musiques (fichiers à ~-20 dBFS RMS), bien sous les voix
const AMB_DB := -9.0             # niveau des ambiances
const RAIN_DB := -11.0           # pluie de Weather (averse)
const MUSIC_FADE := 2.5          # s
const AMB_FADE := 1.8            # s
const INSIDE_RAIN := 0.25        # gain de la pluie du dehors entendue d'un intérieur
const RAIN_FILE := "amb_pluie"

## Musiques : id -> [boucle, ouverture jouée une fois avant la boucle ("" = aucune)]
const MUSIC := {
	"theme": ["mus_theme", ""], "matin": ["mus_matin", ""], "espoir": ["mus_espoir", ""],
	"marche": ["mus_marche", ""], "tension": ["mus_tension", ""], "nasse": ["mus_nasse", ""],
	"aube": ["mus_aube", ""], "fin": ["mus_fin", ""], "fin_sombre": ["mus_fin_sombre", ""],
	"jt": ["mus_jt", "mus_jt_intro"], "bilan": ["mus_jt", "mus_jt_intro"],
	"echec": ["mus_echec", "mus_echec_intro"],
}

## Ambiances : id -> {"layers": [[fichier, dB relatifs]…], "inside": intérieur, "mute": coupe aussi le dehors}
const AMBIENCE := {
	"rue_matin": {"layers": [["amb_rue_matin", 0.0]]},
	"rue_nuit": {"layers": [["amb_rue_nuit", 0.0]]},
	"pluie": {"layers": [["amb_pluie", 0.0]]},
	"pluie_nuit": {"layers": [["amb_rue_nuit", -3.0], ["amb_pluie", 0.0]]},
	"cafe": {"layers": [["amb_cafe", 0.0]], "inside": true},
	"zinc": {"layers": [["amb_cafe", 0.0]], "inside": true},
	"supermarche": {"layers": [["amb_superette", 0.0]], "inside": true},
	"superette": {"layers": [["amb_superette", 0.0]], "inside": true},
	"tv": {"layers": [["amb_tv", -2.0]], "inside": true},
	"jt": {"layers": [["amb_tv", -2.0]], "inside": true},
	"square": {"layers": [["amb_square", 0.0]]},
	"cortege": {"layers": [["amb_cortege", 0.0]]},
	"blocage": {"layers": [["amb_blocage", 0.0]]},
	"foule": {"layers": [["amb_foule_gronde", 0.0]]},
	"gronde": {"layers": [["amb_foule_gronde", 0.0]]},
	"silence": {"layers": []},
	"ecran": {"layers": [], "mute": true},
}

## Musique de l'écran de fin selon la fin atteinte (NewsTexts.ENDINGS)
const ENDING_MUSIC := {"greve": "fin", "recul": "fin", "amere": "fin_sombre", "essoufflement": "fin_sombre"}

static var _streams := {}

var director: ChapterDirector
var music_id := ""
var ambience_id := ""
var _mix: Array[Dictionary] = []          # lecteurs suivis : {p, base, g, to, rate, own, kind, file}
var _pending_loop := ""                   # boucle à lancer quand l'ouverture se termine
var _pending_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(d: ChapterDirector) -> void:
	director = d
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.ensure_buses()
	if d and d.news and not d.news.child_entered_tree.is_connected(_on_news_child):
		d.news.child_entered_tree.connect(_on_news_child)


## Flux (en boucle ou non) d'un fichier d'assets/audio/story ; null s'il manque
static func get_stream(file: String, loop := true) -> AudioStream:
	var key := file + ("#loop" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	var path := DIR + file + ".ogg"
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
		if s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			(s as AudioStreamOggVorbis).loop = loop
	_streams[key] = s
	return s


static func has_music(id: String) -> bool:
	if not MUSIC.has(id) or get_stream(str(MUSIC[id][0])) == null:
		return false
	return str(MUSIC[id][1]) == "" or get_stream(str(MUSIC[id][1]), false) != null


static func has_ambience(id: String) -> bool:
	if not AMBIENCE.has(id):
		return false
	for l in (AMBIENCE[id] as Dictionary)["layers"]:
		if get_stream(str(l[0])) == null:
			return false
	return true


## Lecteur de pluie pour Weather : averse en boucle, plus discrète pour une bruine (k = intensité 0..1)
static func rain_player(k: float) -> AudioStreamPlayer:
	Settings.ensure_buses()
	var p := AudioStreamPlayer.new()
	p.name = "RainSound"
	p.bus = BUS
	p.stream = get_stream(RAIN_FILE)
	p.volume_db = RAIN_DB + linear_to_db(clampf(k, 0.2, 1.0)) * 0.8
	p.autoplay = p.stream != null
	p.add_to_group("rain_sound")
	return p


# ------------------------------------------------------------------ interface (§ 5.2)
func music(id: String) -> void:
	if id == "":
		stop_music()
		return
	if not MUSIC.has(id):
		push_warning("StoryAudio : musique inconnue « %s »" % id)
		return
	if id == music_id and _has_kind("music"):
		return
	_fade_kind("music", MUSIC_FADE)
	music_id = id
	_pending_loop = ""
	var loop_file := str(MUSIC[id][0])
	var intro := str(MUSIC[id][1])
	var st := get_stream(intro, false) if intro != "" else null
	if st:
		_start("music", st, MUSIC_DB, 0.3)
		_pending_loop = loop_file
		_pending_t = maxf(st.get_length() - 0.15, 0.1)
	else:
		_start("music", get_stream(loop_file), MUSIC_DB, MUSIC_FADE)


func ambience(id: String) -> void:
	if id == "":
		id = "silence"
	if not AMBIENCE.has(id):
		push_warning("StoryAudio : ambiance inconnue « %s »" % id)
		return
	if id == ambience_id:
		return
	var def: Dictionary = AMBIENCE[id]
	var keep := {}
	for l in def["layers"]:
		keep[str(l[0])] = float(l[1])
	# les couches communes avec l'ambiance précédente continuent (pluie_nuit -> pluie : pas de coupure)
	for e in _mix:
		if e["kind"] != "amb" or not is_instance_valid(e["p"]):
			continue
		var f := str(e["file"])
		if keep.has(f) and float(e["to"]) > 0.0:
			_set_target(e, db_to_linear(keep[f]), AMB_FADE)
			keep.erase(f)
		else:
			_set_target(e, 0.0, AMB_FADE)
	var weather_rain := is_inside_tree() and get_tree().get_first_node_in_group("rain_sound") != null
	for f in keep:
		if f == RAIN_FILE and weather_rain:
			continue                      # Weather fait déjà tomber la pluie
		var e := _start("amb", get_stream(f), AMB_DB, AMB_FADE, db_to_linear(keep[f]))
		if not e.is_empty():
			e["file"] = f
	ambience_id = id
	var mute := bool(def.get("mute", false))
	var rain_g := 0.0 if mute else (INSIDE_RAIN if bool(def.get("inside", false)) else 1.0)
	_outdoor(1.0 if id == "silence" else 0.0, rain_g)


func stop_music(fade := 1.0) -> void:
	_pending_loop = ""
	_fade_kind("music", maxf(fade, 0.01))
	music_id = ""


# ------------------------------------------------------------------ écrans du JT (NewsFeed)
func _on_news_child(n: Node) -> void:
	if n is NewsBilan:
		music("jt")
	elif n is NewsFailure:
		music("echec")
	elif n is NewsEnding:
		music(str(ENDING_MUSIC.get((n as NewsEnding).ending_id, "fin_sombre")))
	else:
		return
	ambience("ecran")


# ------------------------------------------------------------------ mixage
func _start(kind: String, st: AudioStream, base: float, fade: float, to := 1.0) -> Dictionary:
	if st == null or not is_inside_tree():
		return {}
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	p.stream = st
	p.volume_db = -80.0
	add_child(p)
	p.play()
	var e := {"p": p, "base": base, "g": 0.0, "to": to, "rate": to / maxf(fade, 0.01), "own": true, "kind": kind,
		"file": ""}
	_mix.append(e)
	return e


func _set_target(e: Dictionary, to: float, fade: float) -> void:
	e["to"] = to
	e["rate"] = maxf(absf(to - float(e["g"])), 0.05) / maxf(fade, 0.01)


## Éteint en fondu tous les lecteurs d'une sorte (« music », « amb »)
func _fade_kind(kind: String, fade: float) -> void:
	for e in _mix:
		if e["kind"] == kind:
			_set_target(e, 0.0, fade)


func _has_kind(kind: String) -> bool:
	for e in _mix:
		if e["kind"] == kind and float(e["to"]) > 0.0 and is_instance_valid(e["p"]):
			return true
	return false


## Sons du dehors qui ne sont pas à nous : ville générique (Ambient de la scène) et pluie de Weather
func _outdoor(city_g: float, rain_g: float) -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("rain_sound"):
		_track_external(n, "rain", rain_g)
	var host: Node = director.main if director and is_instance_valid(director.main) else null
	if host == null:
		return
	for c in host.get_children():
		if c is Ambient:
			for p in c.get_children():
				_track_external(p, "city", city_g)


func _track_external(n: Node, kind: String, to: float) -> void:
	if not n is AudioStreamPlayer:
		return
	for e in _mix:
		if e["p"] == n:
			_set_target(e, to, AMB_FADE)
			return
	if is_equal_approx(to, 1.0):
		return
	var p := n as AudioStreamPlayer
	_mix.append({"p": p, "base": p.volume_db, "g": 1.0, "to": to, "rate": 1.0 / AMB_FADE, "own": false,
		"kind": kind, "file": ""})


func _process(delta: float) -> void:
	if _pending_loop != "":
		_pending_t -= delta
		if _pending_t <= 0.0:
			var f := _pending_loop
			_pending_loop = ""
			_start("music", get_stream(f), MUSIC_DB, 0.3)
	for i in range(_mix.size() - 1, -1, -1):
		var e: Dictionary = _mix[i]
		if not is_instance_valid(e["p"]):
			_mix.remove_at(i)
			continue
		var ap := e["p"] as AudioStreamPlayer
		var g := move_toward(float(e["g"]), float(e["to"]), float(e["rate"]) * delta)
		e["g"] = g
		ap.volume_db = float(e["base"]) + linear_to_db(maxf(g, 0.0001))
		if not bool(e["own"]):
			if is_equal_approx(g, 1.0) and is_equal_approx(float(e["to"]), 1.0):
				ap.volume_db = float(e["base"])
				_mix.remove_at(i)               # lecteur extérieur rendu à son niveau d'origine
		elif g <= 0.0001 and float(e["to"]) <= 0.0:
			ap.queue_free()
			_mix.remove_at(i)
		elif not ap.playing and not (ap.stream is AudioStreamOggVorbis and (ap.stream as AudioStreamOggVorbis).loop):
			ap.queue_free()                     # ouverture terminée
			_mix.remove_at(i)
