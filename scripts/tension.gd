class_name Tension
extends Node
## Barre de chaos : la pression monte avec les actions du joueur (vitres, feu, mortier, jets sur la police...)
## et celles des forces de l'ordre (gaz, charges). Au début rien ne se passe ; aux seuils, la police se
## renforce (voir police.gd). Elle redescend doucement quand tout est calme.

signal changed(value: float, stage: int)
signal stage_up(stage: int)
signal stage_down(stage: int)

const STAGES := [0.0, 0.16, 0.36, 0.60, 0.84]
const STAGE_NAMES := ["CALME", "TENDU", "ÉCHAUFFOURÉES", "AFFRONTEMENT", "ÉMEUTE"]

var value := 0.0
var stage := 0
var police_active := false     # des policiers sont engagés (la tension redescend plus lentement)
var frozen := false
var _since := 99.0
var _log: Array = []
var _decay_hold := 0.0
var _peak := 0.0


func _ready() -> void:
	add_to_group("tension")
	add_to_group("crowd")        # reçoit les mêmes événements que la foule


## Hausse (ou baisse) de la tension ; `why` sert à la mise au point
func add(amount: float, why := "") -> void:
	if frozen:
		return
	var old := stage
	if amount > 0.0:
		amount *= float(Settings.d["tension_gain"])
	value = clampf(value + amount, 0.0, 1.0)
	_peak = maxf(_peak, value)
	if amount > 0.0:
		_since = 0.0
		_decay_hold = maxf(_decay_hold, 4.0 + amount * 120.0)
	_log.append([Time.get_ticks_msec() / 1000.0, amount, why])
	if _log.size() > 40:
		_log.pop_front()
	_refresh_stage(old)


func set_value(v: float) -> void:
	var old := stage
	value = clampf(v, 0.0, 1.0)
	_refresh_stage(old)


func _refresh_stage(old: int) -> void:
	var s := 0
	for i in STAGES.size():
		if value >= STAGES[i]:
			s = i
	# petite hystérésis à la baisse
	if s < stage and value > STAGES[stage] - 0.04:
		s = stage
	stage = s
	changed.emit(value, stage)
	if stage > old:
		stage_up.emit(stage)
	elif stage < old:
		stage_down.emit(stage)


func stage_name() -> String:
	return STAGE_NAMES[stage]


func max_value() -> float:
	return _peak


func _process(delta: float) -> void:
	_since += delta
	_decay_hold = maxf(_decay_hold - delta, 0.0)
	if frozen or value <= 0.0 or _decay_hold > 0.0:
		return
	# redescente lente : plus lente quand la police est sur place
	var rate := 0.0045 if not police_active else 0.0013
	if stage >= 3:
		rate *= 0.6
	var old := stage
	value = maxf(value - rate * delta, 0.0)
	_refresh_stage(old)


## Correspondance événement -> pression
func on_event(type: String, d: Dictionary) -> void:
	match type:
		"glass_hit":
			add(0.003, "vitre frappée")
		"glass_break":
			add(0.03, "vitre brisée")
		"bus_destroyed":
			add(0.07, "abribus détruit")
		"mortar_fire":
			var dir: Vector3 = d.get("dir", Vector3.UP)
			add(0.02 if dir.y > 0.5 else 0.045, "tir de mortier")
		"burst":
			add(0.006, "explosion")
		"fire_start":
			add(0.03 if not d.get("floor", false) else 0.022, "feu allumé")
		"player_fire":
			add(0.012, "feu du joueur")
		"vandal":
			add(0.008 * float(d.get("amount", 1.0)), "dégradation")
		"flare_lit":
			if d.get("player", false):
				add(0.008, "fumigène")
		"call":
			add(0.015, "appel à la foule")
		"petard":
			add(0.006 * float(d.get("size", 1.0)), "pétard")
		"cop_hit":
			add(0.045, "projectile sur la police")
		"car_vandal":
			add(clampf(float(d.get("amount", 0.02)), 0.0, 0.05), "véhicule de police attaqué")
		"car_burn":
			add(0.14, "véhicule de police en feu")
		"arrest":
			add(0.03, "interpellation")
		"police_gas":
			add(0.018, "tir lacrymo")
		"police_lbd":
			add(0.02, "tir de LBD")
		"police_baton":
			add(0.012, "coup de matraque")
		"cop_down":
			add(0.05, "policier à terre")
