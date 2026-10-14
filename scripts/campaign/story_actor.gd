class_name StoryActor
extends Actor
## Personnage d'histoire (Nadia, Karim, Inès, Lou, Jo, Mme Ferreira, le commissaire…) : un Actor piloté par le
## script du chapitre (pas de cerveau autonome) — il marche vers une cible (en contournant les obstacles, sans
## rester coincé), suit quelqu'un, regarde, joue des gestes et « parle » (bouche synchronisée sur la réplique,
## hochements de tête, mains qui accompagnent la parole) pendant ses répliques, puis revient au repos.
## Look : CastLooks.

var story_id := ""
var display_name := ""
var live_amp := -1.0              # niveau de la voix enregistrée (0..1) fourni par DialogueUI ; -1 = aucun
var _talk_t := 0.0
var _talk_auto := false           # le geste « explain » a été mis automatiquement par la parole
var _talk_nod := false
var _gesture_t := 0.0
var _follow: Node3D
var _follow_moving := false
var _follow_plan_at := Vector3.INF
var _target := Vector3.INF
var _run := false
var _pending_walk := false        # assis : on se relève avant de partir
var _look_node: Node3D
var _look_until := 0.0
var _prog_t := 0.0
var _prog_d := INF
var _replans := 0


func setup_look(id: String) -> void:
	story_id = id
	var lk := CastLooks.look(id)
	display_name = str(lk.get("name", id.capitalize()))
	variant = str(lk.get("variant", "male_a"))
	outfit = (lk.get("outfit", {}) as Dictionary).duplicate(true)
	female = variant.begins_with("female")
	voice = str(lk.get("voice", "f1" if female else "m1"))


## Parle pendant `sec` secondes : bouche synchronisée sur `text` (syllabes, silences de la ponctuation),
## petits hochements, et mains qui accompagnent la parole si le personnage ne fait rien d'autre
func talk(sec: float, text := "") -> void:
	_talk_t = maxf(_talk_t, sec)
	_say_env = DialogueLip.envelope(text if text != "" else "la la la la la la", sec)
	_say_t = 0.0
	_say_loud = false
	if act == "idle" and _gesture_t <= 0.0 and not has_goal and sec > 1.3 and not seated():
		set_act("explain", {}, 2.5)
		_talk_auto = true


## Interrompt la parole (réplique passée)
func stop_talk() -> void:
	_talk_t = 0.0
	_say_t = -1.0
	live_amp = -1.0


func talking() -> bool:
	return _talk_t > 0.0


## Poses de la bibliothèque d'Actor utilisables comme gestes (docs/CAMPAGNE.md § « Gestes »)
const GESTURES := ["idle", "pocket", "crossed", "akimbo", "back", "phone", "film", "selfie", "call", "dance", "spray",
	"highfive", "shake", "link", "comfort", "drum", "finger", "fist", "cheer", "clap", "sign", "point", "cup", "whistle",
	"talk", "warm", "head", "cover", "refuse", "wave", "carry", "pick", "surrender", "reach", "megaphone", "drink", "give",
	"stretch", "rest_knee", "treat", "beckon",
	"nod", "shake_head", "shrug", "explain", "sigh", "laugh", "hug", "sit", "sit_ground"]

## Gestes qu'on garde en marchant (objets tenus, bras croisés…) ; les autres s'interrompent au départ
const KEEP_WALKING := ["phone", "film", "call", "carry", "megaphone", "pocket", "crossed", "back", "sign", "drink"]


## Geste (un nom de GESTURES) tenu `sec` secondes, puis retour au repos. `p` : paramètres de pose (ex. cible)
func gesture(name: String, sec := 2.0, p := {}) -> void:
	var g := name if GESTURES.has(name) else "idle"
	_gesture_t = sec
	_talk_auto = false
	if g == "sit" or g == "sit_ground":
		halt()
	var pp := p
	if g == "hug" and pp.is_empty():
		pp = {"target": Vector3(0, 1.28, 0.42)}
	sep_k = 0.12 if g == "hug" else 1.0
	set_act(g, pp, 3.0)
	if _talk_nod and (g == "nod" or g == "shake_head" or g == "laugh"):
		human.nod = 0.0
		_talk_nod = false


func face_target(p: Vector3) -> void:
	face(p)
	look(p + Vector3.UP * 1.5)
	_look_node = null


## Regarde (tête et yeux) un nœud qui bouge — personnage, joueur — pendant `sec` secondes (≤ 0 : jusqu'à nouvel
## ordre) ; `turn` : se tourne aussi vers lui ; null : regard libre
func look_at_node(n: Node3D, sec := 0.0, turn := false) -> void:
	_look_node = n
	_look_until = sec
	if n == null:
		look(look_p, 0.0)
		return
	look(_head_of(n), 0.85)
	if turn:
		face(n.global_position)


func follow_target(n: Node3D) -> void:
	_follow = n
	_follow_moving = false
	_follow_plan_at = Vector3.INF
	if n == null:
		stop_move()
	else:
		_target = Vector3.INF


func walk(p: Vector3, run := false) -> void:
	_target = p
	_run = run
	_prog_t = 0.0
	_prog_d = INF
	_replans = 0
	_follow = null
	if act != "idle" and (_talk_auto or EXPR_ACTS.has(act) or not KEEP_WALKING.has(act)):
		set_act("idle")
		_gesture_t = 0.0
		_talk_auto = false
	sep_k = 1.0
	if seated():
		_pending_walk = true
		stop_move()
		return
	go(p, run)


func arrived(r := 0.6) -> bool:
	return _target == Vector3.INF or Vector2(global_position.x - _target.x, global_position.z - _target.z).length() < r


## Arrêt net (et oubli de la destination)
func halt() -> void:
	_target = Vector3.INF
	_pending_walk = false
	stop_move()


func _head_of(n: Node3D) -> Vector3:
	if n is Actor and (n as Actor).human:
		return (n as Actor).head_pos()
	if n is Player and (n as Player).human:
		return (n as Player).human.head_world()
	return n.global_position + Vector3.UP * 1.6


func _think(delta: float) -> void:
	# parole
	if _talk_t > 0.0:
		_talk_t = maxf(_talk_t - delta, 0.0)
		if act != "nod" and act != "shake_head" and act != "laugh":
			human.nod = lerpf(human.nod, 0.22 * clampf(_talk_amp * 1.6, 0.0, 1.0), minf(1.0, delta * 4.0))
			_talk_nod = true
		if _talk_t <= 0.0 and _talk_auto:
			_talk_auto = false
			if act == "explain":
				set_act("idle", {}, 2.0)
	elif _talk_nod:
		human.nod = lerpf(human.nod, 0.0, minf(1.0, delta * 5.0))
		if human.nod < 0.01:
			human.nod = 0.0
			_talk_nod = false
	# geste tenu
	if _gesture_t > 0.0:
		_gesture_t -= delta
		if _gesture_t <= 0.0:
			sep_k = 1.0
			set_act("idle", {}, 2.0)
	# regard suivi
	if _look_node != null:
		if not is_instance_valid(_look_node):
			_look_node = null
			look(look_p, 0.0)
		else:
			look(_head_of(_look_node), 0.85)
			if _look_until > 0.0:
				_look_until -= delta
				if _look_until <= 0.0:
					_look_node = null
					look(look_p, 0.0)
	# se relever avant de marcher
	if _pending_walk:
		if not seated():
			_pending_walk = false
			go(_target, _run)
		return
	# suivre quelqu'un (hystérésis : on repart au-delà de 2,6 m, on s'arrête à 1,6 m)
	if _follow != null:
		if not is_instance_valid(_follow):
			_follow = null
			stop_move()
		else:
			var fp := _follow.global_position
			var d := Vector2(fp.x - global_position.x, fp.z - global_position.z).length()
			if d > 2.6 or (_follow_moving and d > 1.6):
				if not _follow_moving or not has_goal or _follow_plan_at.distance_to(fp) > 1.2:
					go(fp, d > 6.0, 1.5)
					_follow_plan_at = fp
				_follow_moving = true
			elif _follow_moving:
				_follow_moving = false
				stop_move()
				face(fp)
		return
	_walk_watch(delta)


## Marche fiable : relance si l'Actor s'est arrêté trop tôt, recalcule le chemin s'il ne progresse plus,
## et en dernier recours fait un petit pas vers le point suivant du chemin
func _walk_watch(delta: float) -> void:
	if _target == Vector3.INF:
		return
	var d := Vector2(global_position.x - _target.x, global_position.z - _target.z).length()
	if d < 0.6:
		_target = Vector3.INF
		stop_move()
		return
	if not has_goal:
		if d < 1.4:
			_target = Vector3.INF       # assez près : quelqu'un ou un obstacle occupe la place exacte
			return
		go(_target, _run)
	_prog_t += delta
	if d < _prog_d - 0.3:
		_prog_d = d
		_prog_t = 0.0
	elif _prog_t > 3.0:
		_prog_t = 0.0
		_replans += 1
		if _replans >= 3 and not path.is_empty():
			var wp: Vector3 = path[0]
			var step := Vector3(wp.x - global_position.x, 0, wp.z - global_position.z)
			if step.length() > 0.01:
				var np := global_position + step.limit_length(1.0)
				if crowd:
					np = crowd.resolve(self, np)
					np.y = crowd.ground_y(np)
				global_position = np
			_replans = 0
		go(_target, _run)


func _move(delta: float) -> void:
	if seated() or _pending_walk:
		vel = Vector3.ZERO           # assis (ou en train de se relever) : on ne glisse pas
		return
	super._move(delta)


func _express(delta: float) -> void:
	super._express(delta)
	if live_amp >= 0.0:
		_talk_amp = lerpf(_talk_amp, live_amp, minf(1.0, delta * 10.0))
		human.jaw = lerpf(human.jaw, clampf(live_amp * 0.75, 0.0, 0.7), minf(1.0, delta * 18.0))
