class_name PatientRecord
extends RefCounted
## Suivi d'un patient pendant la journée : statut, position, dossier
## (réponses, examens), prescription et résultat.

enum Status { EXPECTED, ARRIVING, WAITING, CALLED, IN_OFFICE, LEAVING, DONE }

var case_id: String
var data: Dictionary
var appointment: float
var arrival_time: float
var walk_in := false
var status: Status = Status.EXPECTED
## "outside", "reception", "waiting", "walking", "chair", "table", "lying", "leaving"
var position := "outside"
var arrived_at := -1.0
var consult_started_at := -1.0
var seat_index := -1
var body: Character
var companion: Character
var hotspots: Array[Hotspot] = []
var talk: Interactable

var questions: Array[String] = []
var exams: Dictionary = {} # id -> {"text", "abnormal", "minute"}
var notes: Array[Dictionary] = [] # {"kind", "title", "text", "abnormal", "minute"}
var diagnosis := ""
var treatments: Array = []
var result: Dictionary = {}
var said_cold := false


func display_name() -> String:
	return data.get("patient", {}).get("name", "?")


func first_name() -> String:
	return display_name().split(" ")[0]


func short_name() -> String:
	var parts := display_name().split(" ")
	if parts.size() >= 2:
		return "%s. %s" % [parts[0].substr(0, 1), " ".join(parts.slice(1))]
	return display_name()


func is_female() -> bool:
	return data.get("patient", {}).get("sex", "M") == "F"


func is_child() -> bool:
	return data.get("patient", {}).get("child", false)


func title_name() -> String:
	if is_child():
		return first_name()
	var parts: PackedStringArray = display_name().split(" ")
	return "%s %s" % ["Mme" if is_female() else "M.", parts[parts.size() - 1]]


func age() -> int:
	return int(data.get("patient", {}).get("age", 0))


func gender_code() -> String:
	return "f" if is_female() else "m"


func status_text() -> String:
	match status:
		Status.EXPECTED: return "Attendu"
		Status.ARRIVING: return "Arrive"
		Status.WAITING: return "En salle d'attente"
		Status.CALLED: return "Appelé" if not is_female() else "Appelée"
		Status.IN_OFFICE: return "En consultation"
		Status.LEAVING, Status.DONE: return "Vu" if not is_female() else "Vue"
	return ""


func is_urgent() -> bool:
	return data.get("urgent", false)


func position_text() -> String:
	match position:
		"chair": return "Assis" + ("e" if is_female() else "") + " face au bureau"
		"table": return "Assis" + ("e" if is_female() else "") + " sur la table d'examen"
		"lying": return "Allongé" + ("e" if is_female() else "") + " sur la table d'examen"
		"walking": return "Se déplace"
	return ""


func add_note(kind: String, title: String, text: String, abnormal: bool, minute: float) -> void:
	notes.append({"kind": kind, "title": title, "text": text, "abnormal": abnormal, "minute": minute})


func set_hotspots_active(v: bool) -> void:
	for h in hotspots:
		if is_instance_valid(h):
			h.active = v
