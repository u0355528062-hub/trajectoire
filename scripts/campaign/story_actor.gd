class_name StoryActor
extends Actor
## Personnage d'histoire (Nadia, Karim, Inès, Lou, Jo, Mme Ferreira, le commissaire…) : un Actor piloté par le
## script du chapitre (pas de cerveau autonome) — il marche vers une cible, suit quelqu'un, regarde, joue des gestes
## et « parle » (mouvements de bouche, de tête et de mains) pendant ses répliques. Look : CastLooks.
## VERSION SQUELETTE : le module Cinématiques & jeu d'acteur l'enrichit en gardant l'interface publique.

var story_id := ""
var display_name := ""
var _talk_t := 0.0
var _gesture_t := 0.0
var _follow: Node3D
var _target := Vector3.INF


func setup_look(id: String) -> void:
	story_id = id
	var lk := CastLooks.look(id)
	display_name = str(lk.get("name", id.capitalize()))
	variant = str(lk.get("variant", "male_a"))
	outfit = (lk.get("outfit", {}) as Dictionary).duplicate(true)
	female = variant.begins_with("female")
	voice = str(lk.get("voice", "f1" if female else "m1"))


## Parle pendant `sec` secondes
func talk(sec: float) -> void:
	_talk_t = maxf(_talk_t, sec)


## Poses de la bibliothèque d'Actor utilisables comme gestes
const GESTURES := ["idle", "pocket", "crossed", "akimbo", "back", "phone", "film", "selfie", "call", "dance", "spray",
	"highfive", "shake", "link", "comfort", "drum", "finger", "fist", "cheer", "clap", "sign", "point", "cup", "whistle",
	"talk", "warm", "head", "cover", "refuse", "wave", "carry", "pick", "surrender", "reach", "megaphone", "drink", "give",
	"stretch", "rest_knee", "treat", "beckon"]


## Geste (un nom de GESTURES) tenu `sec` secondes, puis retour au repos
func gesture(name: String, sec := 2.0) -> void:
	_gesture_t = sec
	set_act(name if GESTURES.has(name) else "idle")


func face_target(p: Vector3) -> void:
	face(p)
	look(p + Vector3.UP * 1.5)


func follow_target(n: Node3D) -> void:
	_follow = n


func walk(p: Vector3, run := false) -> void:
	_target = p
	go(p, run)


func arrived(r := 0.6) -> bool:
	return _target == Vector3.INF or Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < r


func _think(delta: float) -> void:
	_talk_t = maxf(_talk_t - delta, 0.0)
	if _gesture_t > 0.0:
		_gesture_t -= delta
		if _gesture_t <= 0.0:
			set_act("idle")
	if _follow and is_instance_valid(_follow):
		var p := _follow.global_position
		if global_position.distance_to(p) > 2.2:
			go(p, global_position.distance_to(p) > 6.0)
		else:
			stop_move()
