extends Node
## Test d'interface : clique réellement (événements souris simulés) sur les
## boutons du menu et de la journée, comme le ferait un joueur.

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	main = load("res://scripts/main.gd").new()
	add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _find_button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree():
			continue
		if b.text.begins_with(text):
			return b
		for l in b.find_children("*", "Label", true, false):
			if (l as Label).text == text:
				return b
	return null


func _click(root: Node, text: String) -> bool:
	var b := _find_button(root, text)
	if b == null:
		failures.append("bouton introuvable : " + text)
		return false
	var vp := b.get_viewport()
	var pos := b.get_global_transform_with_canvas() * (b.size * 0.5)
	pos = vp.get_screen_transform() * pos
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	await _frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(4)
	return true


func _run() -> void:
	await _frames(20)
	await _click(main, "Paramètres")
	if _find_button(main, "Retour") == null:
		failures.append("le bouton Paramètres n'ouvre pas les réglages")
	await _click(main, "Retour")
	await _click(main, "Nouvelle partie")
	await _frames(10)
	if not (main._current is GameSession):
		failures.append("Nouvelle partie ne lance pas la journée")
	else:
		var s: GameSession = main._current
		await _click(s, "Commencer la journée")
		if s.state != GameSession.State.PLAY:
			failures.append("Commencer la journée ne démarre pas (état %d)" % s.state)
		s._open_pause()
		await _frames(3)
		await _click(s, "Reprendre")
		if s.state != GameSession.State.PLAY:
			failures.append("Reprendre ne ferme pas la pause")
		s._open_pause()
		await _frames(3)
		await _click(s, "Quitter vers le menu principal")
		await _frames(10)
		if not (main._current is MainMenu):
			failures.append("Quitter ne revient pas au menu")
	if failures.is_empty():
		print("CLICK TEST OK")
		get_tree().quit(0)
	else:
		print("CLICK TEST FAILED")
		for f in failures:
			print("  - " + f)
		get_tree().quit(1)
