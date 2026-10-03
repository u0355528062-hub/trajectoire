extends Node
## Point d'entrée : alterne entre le menu principal et les journées de jeu.

var _current: Node


func _ready() -> void:
	show_menu()


func _swap(n: Node) -> void:
	if _current and is_instance_valid(_current):
		remove_child(_current)
		_current.queue_free()
	_current = n
	add_child(n)


func show_menu() -> void:
	Game.clock_running = false
	var m := MainMenu.new()
	m.new_game.connect(_on_new_game, CONNECT_DEFERRED)
	m.continue_game.connect(_on_continue, CONNECT_DEFERRED)
	m.quit_game.connect(get_tree().quit, CONNECT_DEFERRED)
	_swap(m)


func _on_new_game() -> void:
	Game.delete_save()
	Game.start_new_story()
	start_day()


func _on_continue() -> void:
	if not Game.load_game():
		Game.start_new_story()
	start_day()


func start_day() -> void:
	Game.reset_day()
	var s := GameSession.new()
	s.quit_to_menu.connect(show_menu, CONNECT_DEFERRED)
	s.next_day_requested.connect(start_day, CONNECT_DEFERRED)
	_swap(s)
