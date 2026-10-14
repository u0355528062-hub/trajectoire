class_name SandboxMenu
extends VBoxContainer
## Menu « Bac à sable » de l'écran titre : quelques réglages du monde (moment, météo, taille de la foule, police,
## tension de départ), traduits en WorldSetup.sandbox. Les choix par défaut redonnent exactement le jeu d'origine.

signal launch(over: Dictionary)      ## réglages choisis (format WorldSetup ; {} = jeu d'origine)
signal back

const TODS := [["Aube", "aube"], ["Matin", "matin"], ["Midi", "midi"], ["Après-midi", "aprem"], ["Crépuscule", "crepuscule"], ["Nuit", "nuit"]]
const WEATHERS := [["Sec", "sec"], ["Bruine", "bruine"], ["Pluie", "pluie"], ["Brume", "brume"]]
const SIZES := [["Petite", 25], ["Normale", -1], ["Grande", 120], ["Énorme", 170]]
const TENSIONS := [["Calme", 0.0], ["Tendu", 0.2], ["Échauffourées", 0.4], ["Affrontement", 0.65]]
const DEFAULTS := {"tod": "crepuscule", "weather": "sec", "size": -1, "police": true, "tension": 0.0}

var pick: Dictionary = DEFAULTS.duplicate()
var first_button: Button
var _tension_row: Control


## Choix du menu -> réglages du monde (seules les différences avec le jeu d'origine)
static func to_sandbox(p: Dictionary) -> Dictionary:
	var over := {}
	if str(p["tod"]) != DEFAULTS["tod"]:
		over["tod"] = str(p["tod"])
	if str(p["weather"]) != DEFAULTS["weather"]:
		over["weather"] = str(p["weather"])
	if int(p["size"]) != DEFAULTS["size"]:
		over["crowd"] = {"size": int(p["size"])}
	if not bool(p["police"]):
		over["police"] = {"enabled": false}
	elif float(p["tension"]) > 0.0:
		over["police"] = {"start_tension": float(p["tension"])}
	return over


## Réglages du monde -> choix du menu (pour rouvrir le menu sur les derniers choix)
static func from_sandbox(over: Dictionary) -> Dictionary:
	var cfg := WorldSetup.merge(WorldSetup.DEFAULT, over)
	var pol: Dictionary = cfg["police"]
	var sz: Variant = (cfg["crowd"] as Dictionary)["size"]
	return {"tod": str(cfg["tod"]), "weather": str(cfg["weather"]), "size": int(sz) if not (sz is String) else -1,
		"police": bool(pol["enabled"]), "tension": float(pol["start_tension"])}


func _ready() -> void:
	pick = from_sandbox(WorldSetup.sandbox)
	add_theme_constant_override("separation", 6)
	custom_minimum_size.x = 640
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(UiStyle.label("BAC À SABLE", 15, UiStyle.RED.lightened(0.15), "caps"))
	add_child(_seg("Moment", "", TODS, "tod"))
	add_child(_seg("Météo", "", WEATHERS, "weather"))
	add_child(_seg("Foule", "Normale : la foule d'origine", SIZES, "size"))
	var sw := UiKit.Switch.new(bool(pick["police"]))
	sw.toggled.connect(func(on: bool):
		pick["police"] = on
		_tension_row.modulate.a = 1.0 if on else 0.35)
	add_child(UiKit.row("Police", "Sans police : ni cordon ni renforts", sw))
	_tension_row = _seg("Tension de départ", "La police y répond dès le début", TENSIONS, "tension")
	_tension_row.modulate.a = 1.0 if bool(pick["police"]) else 0.35
	add_child(_tension_row)
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	add_child(gap)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	add_child(h)
	var go := UiKit.Btn.new("DESCENDRE DANS LA RUE", true)
	go.custom_minimum_size = Vector2(360, 56)
	go.pressed.connect(func(): launch.emit(to_sandbox(pick)))
	h.add_child(go)
	first_button = go
	var ret := UiKit.Btn.new("RETOUR", false, "ghost")
	ret.pressed.connect(func(): back.emit())
	h.add_child(ret)


## Rangée de boutons exclusifs : `opts` = [[libellé, valeur]…], la valeur choisie va dans pick[key]
func _seg(title: String, hint: String, opts: Array, key: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var btns: Array[Button] = []
	for o in opts:
		var b := UiKit.Btn.new(str(o[0]), false, "seg")
		btns.append(b)
		box.add_child(b)
	var refresh := func():
		for k in btns.size():
			btns[k].button_pressed = _same(opts[k][1], pick[key])
	refresh.call()
	for i in btns.size():
		btns[i].pressed.connect(func():
			pick[key] = opts[i][1]
			refresh.call())
	return UiKit.row(title, hint, box)


static func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < 0.001
	return str(a) == str(b)
