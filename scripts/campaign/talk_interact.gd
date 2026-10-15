class_name TalkInteract
extends Node
## Interaction « Parler » du joueur (E) : repère la personne la plus proche devant lui — personnage d'histoire,
## passant ou manifestant — et engage la conversation. Avec les tracts en main, E sur un passant lui tend un tract.
## Événement : talk {"who": id du personnage d'histoire ou "passant", "node": la personne}.
## Les manifestants répondent (geste, voix) sans événement : ce ne sont pas des passants.

const REACH := 2.2
const SCAN := 0.12

## Répliques des passants à qui l'on parle (vie chère, loi de Stabilité, manif) — registre oral, sans pavé
const PASSANT_LINES := [
	"Vous avez vu le gazole ? Deux soixante-dix-neuf… Je fais plus le plein, je mets vingt balles.",
	"Moi je fais mes courses au discount maintenant. Et encore.",
	"Encore une manif ? Bon… courage, hein.",
	"Je suis d'accord avec vous, mais j'ai pas envie que ça dégénère.",
	"Ma mère peut plus se chauffer. Alors oui, la loi, elle passe pas.",
	"Désolé, je suis pressé. Mais je vous soutiens.",
	"La « pédagogie », qu'ils disent à la télé… On a très bien compris, merci.",
	"Ça sert à rien, vos trucs. Ils écoutent jamais.",
	"Mon loyer a pris soixante euros. Soixante ! Pour le même deux-pièces.",
	"Je bosse à l'hôpital. Le gel des salaires, on le sent passer, croyez-moi.",
]
## Répliques des manifestants (déjà dans le mouvement)
const DEMO_LINES := [
	"On lâche rien, hein !",
	"T'as vu les prix à la station ? C'est du vol.",
	"Paraît qu'on sera plus nombreux samedi.",
	"Fais gaffe à toi, les flics sont nerveux.",
	"Moi c'est ma facture d'élec qui m'a fait venir.",
	"Si on reste calmes, ils pourront rien dire.",
]
const TRACT_TALK_LINES := [
	"La loi de Stabilité ? Ma facture d'électricité a pris quarante balles… Donnez.",
	"C'est quand, le rassemblement ? Samedi ? Je verrai si je peux.",
	"Vous croyez que ça va changer quelque chose ? … Bon, allez, je prends.",
	"Mon fils est livreur aussi. Je lui montrerai.",
	"Le plein à cent euros, franchement… Oui, je prends.",
	"Vous avez raison. Il faut bien que quelqu'un dise quelque chose.",
]
const TRACT_REFUSE_LINES := ["Non merci.", "Pas le temps, désolé.", "Ça m'intéresse pas.", "Laissez-moi tranquille.",
	"La politique, très peu pour moi.", "Non, non, ça ira."]
const TRACT_TAKE_LINES := ["Merci.", "Ouais, d'accord.", "Je lirai.", "Mm."]

var player: Player
var target: Actor               # personne à portée (null si personne)
var target_dist := INF
var _scan_t := 0.0
var _cd := 0.0
var _rng := RandomNumberGenerator.new()
var _line_i := 0


func _ready() -> void:
	_rng.randomize()
	_line_i = _rng.randi() % PASSANT_LINES.size()


func update(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_scan_t -= delta
	if target != null and not is_instance_valid(target):
		target = null
		target_dist = INF
	if _scan_t > 0.0:
		return
	_scan_t = SCAN
	target = null
	target_dist = INF
	if player == null or player.arrest_phase != "" or player.down_t > 0.0:
		return
	var c := _crowd()
	if c == null:
		return
	var me := player.global_position
	var fwd := -player.cam_yaw.global_basis.z
	for a in c.actors:
		_consider(a, me, fwd)
	for n in c.npcs:
		_consider(n, me, fwd)


func _consider(a: Actor, me: Vector3, fwd: Vector3) -> void:
	if not is_instance_valid(a) or not talkable(a):
		return
	var d := a.global_position - me
	d.y = 0.0
	var l := d.length()
	if l > minf(REACH, target_dist) or absf(a.global_position.y - me.y) > 1.2:
		return
	if l > 0.9 and fwd.dot(d / maxf(l, 0.01)) < 0.35:
		return
	target = a
	target_dist = l


static func talkable(a: Actor) -> bool:
	if a is StoryActor:
		return true
	if a is Passerby:
		var w := a as Passerby
		return not w.done and not w.leaving and w.state not in ["flee", "gassed"]
	if a is Npc:
		return not (a as Npc).busy()
	return false


func _crowd() -> Crowd:
	if player and player.is_inside_tree():
		for n in player.get_tree().get_nodes_in_group("crowd"):
			if n is Crowd:
				return n
	return null


## Libellé de l'invite E (vide si personne)
func prompt(tracts_in_hand: bool) -> String:
	if target == null:
		return ""
	if target is StoryActor:
		return "Parler à " + (target as StoryActor).display_name
	if tracts_in_hand and (target is Passerby or target is Npc):
		return "Tendre un tract"
	if target is Passerby:
		return "Parler à la passante" if target.female else "Parler au passant"
	return "Parler"


## E : engage la conversation (ou tend un tract si les tracts sont en main)
func activate(a: Actor, tracts: TractTool = null) -> void:
	if a == null or not is_instance_valid(a) or _cd > 0.0:
		return
	_cd = 0.6
	if a is StoryActor:
		_emit("talk", {"who": (a as StoryActor).story_id, "node": a})
		return
	if tracts != null and tracts.equipped and (a is Passerby or a is Npc):
		tracts.offer(a)
		return
	var from := player.global_position
	if a is Passerby:
		if (a as Passerby).talk_to(from, _rng.randf_range(3.0, 4.5)):
			_line_i = (_line_i + 1 + _rng.randi() % 3) % PASSANT_LINES.size()
			player.message.emit("%s : « %s »" % ["Passante" if a.female else "Passant", PASSANT_LINES[_line_i]])
			_emit("talk", {"who": "passant", "node": a})
	elif a is Npc:
		if (a as Npc).talk_to(from):
			player.message.emit("%s : « %s »" % ["Manifestante" if a.female else "Manifestant", DEMO_LINES[_rng.randi() % DEMO_LINES.size()]])


func _emit(type: String, d: Dictionary) -> void:
	if player and player.is_inside_tree():
		player.get_tree().call_group("crowd", "on_event", type, d)
