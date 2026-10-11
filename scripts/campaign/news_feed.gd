class_name NewsFeed
extends CanvasLayer
## Actualités et écrans de fin : notifications d'actualité pendant le jeu (push), bilan de fin de chapitre
## (JT, sondage, mobilisation, réseaux sociaux), écran d'échec (garde à vue…), fins de la campagne.
## VERSION SQUELETTE : écrans minimaux ; le module Opinion & actualités les remplace en gardant l'interface publique.

signal closed

var director: ChapterDirector
var _label: Label
var _panel: VBoxContainer
var _answer := -1


func bind(d: ChapterDirector) -> void:
	director = d


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(24, 24)
	add_child(_label)
	_panel = VBoxContainer.new()
	_panel.anchor_left = 0.3
	_panel.anchor_right = 0.7
	_panel.anchor_top = 0.3
	_panel.anchor_bottom = 0.7
	add_child(_panel)


func push(text: String) -> void:
	_label.text = text


## Bilan de fin de chapitre (await)
func show_bilan(outcome: String) -> void:
	var s := "FIN DU CHAPITRE (%s)\nOpinion : %d %%   Mobilisation : %d" % [outcome, int(Campaign.stat("opinion")), int(Campaign.stat("mobilisation"))]
	await _ask(s, ["Continuer"])


## Écran d'échec ; true = recommencer le chapitre, false = retour au menu
func show_failure(reason: String) -> bool:
	var s := "ÉCHEC : " + ("interpellé, garde à vue" if reason == "arrested" else reason)
	return await _ask(s, ["Recommencer le chapitre", "Menu principal"]) == 0


## Fin de la campagne (await)
func show_ending(id: String) -> void:
	await _ask("FIN : " + id, ["Retour au menu"])


## Fin atteinte selon l'état de la campagne (le module Opinion & actualités affine les règles)
static func pick_ending() -> String:
	var op := Campaign.stat("opinion")
	if op >= 60.0:
		return "recul"
	if op >= 40.0:
		return "amere"
	return "essoufflement"


func _ask(text: String, options: Array) -> int:
	if Campaign.autoplay:
		await director.sleep(0.02)
		return 0
	for c in _panel.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = text
	_panel.add_child(l)
	_answer = -1
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		var k := i
		b.pressed.connect(func() -> void: _answer = k)
		_panel.add_child(b)
	var prev := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	while _answer < 0:
		await director.sleep(0.05)
	Input.mouse_mode = prev
	for c in _panel.get_children():
		c.queue_free()
	closed.emit()
	return _answer
