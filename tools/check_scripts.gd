extends Node
## Vérifie que tous les scripts du projet se compilent (outil de développement).
## godot --headless --path . res://tools/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	var files := _collect("res://scripts")
	files.append_array(_collect("res://tests"))
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate():
			print("ÉCHEC : ", f)
			bad += 1
	print("SCRIPTS VÉRIFIÉS : %d, en erreur : %d" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)


func _collect(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_collect(dir.path_join(sub)))
	return out
