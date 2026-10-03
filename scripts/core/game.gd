extends Node
## État global : horloge de la journée, progression du mode Histoire,
## réglages et sauvegarde. Chargé en autoload sous le nom « Game ».

signal time_changed(minutes: float)
signal notify(text: String, kind: String)
signal stats_changed
signal settings_changed

const SAVE_PATH := "user://trajectoire_save.json"
const SETTINGS_PATH := "user://trajectoire_settings.json"
const FEE := 30.0 ## Tarif d'une consultation de médecine générale (en euros).
const REAL_SECONDS_PER_GAME_MINUTE := 1.5

var day: int = 1
var minutes: float = 8 * 60 + 20
var clock_running: bool = false

var reputation: float = 50.0
var money: float = 0.0
var total_seen: int = 0
var total_correct: int = 0

## Résultats des consultations de la journée en cours.
var day_results: Array[Dictionary] = []

var settings := {
	"sensitivity": 0.25,
	"fov": 75.0,
	"quality": 2, # 0 = Performance, 1 = Équilibré, 2 = Ultra
	"fullscreen": false,
	"head_bob": true,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()


func _process(delta: float) -> void:
	if clock_running and not get_tree().paused:
		advance(delta / REAL_SECONDS_PER_GAME_MINUTE)


## Fait avancer l'horloge de `mins` minutes de jeu.
func advance(mins: float) -> void:
	if mins <= 0.0:
		return
	minutes += mins
	time_changed.emit(minutes)


func clock_text(m: float = -1.0) -> String:
	if m < 0.0:
		m = minutes
	var total := int(floor(m))
	return "%02d:%02d" % [(total / 60) % 24, total % 60]


func say(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)


func start_new_story() -> void:
	day = 1
	reputation = 50.0
	money = 0.0
	total_seen = 0
	total_correct = 0
	reset_day()


func reset_day() -> void:
	minutes = Cases.day_start_minutes(day)
	day_results.clear()
	clock_running = false
	stats_changed.emit()


func record_result(result: Dictionary) -> void:
	day_results.append(result)
	total_seen += 1
	if result.get("diagnosis_ok", false):
		total_correct += 1
	money += float(result.get("fee", FEE))
	reputation = clampf(reputation + float(result.get("reputation_delta", 0.0)), 0.0, 100.0)
	stats_changed.emit()


func next_day() -> void:
	day += 1
	save_game()
	reset_day()


func is_story_finished() -> bool:
	return day > Cases.day_count()


# --- Sauvegarde -------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"day": day,
		"reputation": reputation,
		"money": money,
		"total_seen": total_seen,
		"total_correct": total_correct,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	day = int(parsed.get("day", 1))
	reputation = float(parsed.get("reputation", 50.0))
	money = float(parsed.get("money", 0.0))
	total_seen = int(parsed.get("total_seen", 0))
	total_correct = int(parsed.get("total_correct", 0))
	if is_story_finished():
		day = Cases.day_count()
	reset_day()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# --- Réglages ---------------------------------------------------------------

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				for k in settings.keys():
					if parsed.has(k) and typeof(parsed[k]) == typeof(settings[k]):
						settings[k] = parsed[k]
					elif parsed.has(k) and typeof(settings[k]) == TYPE_INT and typeof(parsed[k]) == TYPE_FLOAT:
						settings[k] = int(parsed[k])
	apply_settings()


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var want_fs: bool = settings["fullscreen"]
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_fs and not is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not want_fs and is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()


# --- Contrôles --------------------------------------------------------------
# Les touches sont déclarées par position physique : ZQSD sur AZERTY
# correspond automatiquement à WASD sur QWERTY.

func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("interact", [KEY_E])
	_bind("agenda", [KEY_TAB])
	_bind("pause", [KEY_ESCAPE])
	if not InputMap.has_action("interact_mouse"):
		InputMap.add_action("interact_mouse")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_mouse", mb)


func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
