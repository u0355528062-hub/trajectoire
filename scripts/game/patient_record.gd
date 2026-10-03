class_name PatientRecord
extends RefCounted
## Suivi d'un patient au cours de la journée.

enum Status { EXPECTED, ARRIVING, WAITING, CALLED, IN_OFFICE, CONSULTING, LEAVING, DONE }

var case_id: String
var data: Dictionary
var appointment: float
var arrival_time: float
var walk_in := false
var status: Status = Status.EXPECTED
var arrived_at := -1.0
var consult_started_at := -1.0
var seat_index := -1
var on_table := false
var body: Humanoid
var interact: Interactable
var result: Dictionary = {}


func display_name() -> String:
	return data.get("patient", {}).get("name", "?")


func short_name() -> String:
	var n := display_name()
	var parts := n.split(" ")
	if parts.size() >= 2:
		return "%s. %s" % [parts[0].substr(0, 1), " ".join(parts.slice(1))]
	return n


func title_name() -> String:
	var p: Dictionary = data.get("patient", {})
	var prefix: String = "Mme" if p.get("sex", "M") == "F" else "M."
	if int(p.get("age", 30)) < 15:
		return p.get("name", "?").split(" ")[0]
	var parts: PackedStringArray = p.get("name", "?").split(" ")
	return "%s %s" % [prefix, parts[parts.size() - 1]]


func age() -> int:
	return int(data.get("patient", {}).get("age", 0))


func status_text() -> String:
	match status:
		Status.EXPECTED: return "Attendu"
		Status.ARRIVING: return "Arrive"
		Status.WAITING: return "En salle d'attente"
		Status.CALLED: return "Appelé"
		Status.IN_OFFICE, Status.CONSULTING: return "En consultation"
		Status.LEAVING, Status.DONE: return "Vu"
	return ""


func is_urgent() -> bool:
	return data.get("urgent", false)
