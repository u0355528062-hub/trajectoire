class_name Viewmodel
extends Node3D
## Mains et instrument vus à la première personne : équipement, balancement,
## geste d'examen (la main avance vers la zone examinée).

## Placement par outil : pose de la main droite, transformation de la main
## (position, rotation en degrés) dans le repère de la caméra, et de
## l'instrument dans le repère de la main.
const CONFIG := {
	"mains": {"pose": "relaxed", "hand": [Vector3(0.2, -0.24, -0.4), Vector3(4, 12, -12)], "left": true},
	"stethoscope": {"pose": "pinch", "hand": [Vector3(0.17, -0.2, -0.36), Vector3(10, 18, -22)], "tool": [Vector3(-0.028, -0.024, -0.118), Vector3(0, -6, 0)]},
	"tensiometre": {"pose": "cup", "hand": [Vector3(0.15, -0.24, -0.34), Vector3(32, 10, 168)], "tool": [Vector3(0.0, 0.03, -0.08), Vector3(0, 180, 180)]},
	"thermometre": {"pose": "grip", "hand": [Vector3(0.18, -0.2, -0.34), Vector3(8, 14, -78)], "tool": [Vector3(0.0, -0.035, -0.066), Vector3(0, 0, 90)]},
	"oxymetre": {"pose": "pinch", "hand": [Vector3(0.17, -0.21, -0.35), Vector3(14, 16, -24)], "tool": [Vector3(-0.03, -0.03, -0.12), Vector3(0, 0, 0)]},
	"otoscope": {"pose": "grip", "hand": [Vector3(0.18, -0.22, -0.34), Vector3(6, 14, -80)], "tool": [Vector3(0.0, -0.035, -0.064), Vector3(0, 0, 90)]},
	"lampe": {"pose": "pinch", "hand": [Vector3(0.17, -0.2, -0.36), Vector3(10, 14, -30)], "tool": [Vector3(-0.03, -0.022, -0.1), Vector3(0, -4, 0)]},
	"marteau": {"pose": "pinch", "hand": [Vector3(0.18, -0.21, -0.36), Vector3(6, 14, -60)], "tool": [Vector3(-0.03, -0.022, -0.09), Vector3(0, -4, 0)]},
	"debitmetre": {"pose": "grip", "hand": [Vector3(0.16, -0.22, -0.36), Vector3(8, 40, -84)], "tool": [Vector3(0.0, -0.035, -0.064), Vector3(0, -90, 90)]},
	"glucometre": {"pose": "cup", "hand": [Vector3(0.15, -0.24, -0.34), Vector3(34, 10, 170)], "tool": [Vector3(0.0, 0.026, -0.075), Vector3(0, 180, 180)]},
	"trod": {"pose": "pinch", "hand": [Vector3(0.17, -0.2, -0.36), Vector3(10, 14, -30)], "tool": [Vector3(-0.03, -0.022, -0.08), Vector3(0, -4, 0)]},
	"bandelette": {"pose": "pinch", "hand": [Vector3(0.17, -0.2, -0.36), Vector3(10, 14, -30)], "tool": [Vector3(-0.03, -0.022, -0.08), Vector3(0, -4, 0)]},
	"ecg": {"pose": "cup", "hand": [Vector3(0.15, -0.24, -0.34), Vector3(30, 10, 168)], "tool": [Vector3(0.0, 0.022, -0.06), Vector3(0, 180, 180)]},
}

var tool := "mains"
var right: GloveHand
var left: GloveHand
var _tool_node: Node3D
var _base_r := Transform3D()
var _base_l := Transform3D()
var _equip := 1.0
var _switch_to := ""
var _use := 0.0
var _use_target := 0.0
var _t := 0.0
var _sway := Vector2.ZERO
var _bob := 0.0
var _visible_hands := true


func _ready() -> void:
	right = GloveHand.new()
	right.side = 1.0
	add_child(right)
	right.build(ToolModels.glove(), ToolModels.sleeve(), null)
	left = GloveHand.new()
	left.side = -1.0
	add_child(left)
	left.build(ToolModels.glove(), ToolModels.sleeve(), null)
	_apply_tool("mains")


func equip(id: String) -> void:
	if id == tool and _switch_to == "":
		return
	_switch_to = id


func set_use(amount: float) -> void:
	_use_target = clampf(amount, 0.0, 1.0)


## Entrée souris pour le balancement retardé.
func add_sway(rel: Vector2) -> void:
	_sway += rel * 0.00018
	_sway = _sway.limit_length(0.04)


func set_moving(speed: float, delta: float) -> void:
	if speed > 0.2:
		_bob += delta * speed * 2.6
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, 1.0 - exp(-4.0 * delta))


func set_hands_visible(v: bool) -> void:
	_visible_hands = v


func _apply_tool(id: String) -> void:
	tool = id
	if _tool_node:
		_tool_node.queue_free()
		_tool_node = null
	var cfg: Dictionary = CONFIG.get(id, CONFIG["mains"])
	right.set_pose(cfg["pose"])
	var h: Array = cfg["hand"]
	_base_r = Transform3D(Basis.from_euler(_deg(h[1])), h[0])
	var lh: Vector3 = h[0]
	var lr: Vector3 = h[1]
	_base_l = Transform3D(Basis.from_euler(_deg(Vector3(lr.x, -lr.y, -lr.z))), Vector3(-lh.x - 0.02, lh.y, lh.z))
	left.visible = cfg.get("left", false)
	left.set_pose("relaxed")
	if cfg.has("tool"):
		_tool_node = ToolModels.build(id)
		var t: Array = cfg["tool"]
		_tool_node.transform = Transform3D(Basis.from_euler(_deg(t[1])), t[0])
		right.add_child(_tool_node)


func _deg(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


## Écrit une valeur sur l'écran de l'instrument (thermomètre, oxymètre…).
func set_display(text: String) -> void:
	if _tool_node == null:
		return
	var d := _tool_node.find_child("Display", true, false)
	if d is Label3D:
		(d as Label3D).text = text


func _process(delta: float) -> void:
	_t += delta
	# Changement d'outil : la main descend, change, remonte.
	if _switch_to != "":
		_equip = move_toward(_equip, 0.0, delta * 6.0)
		if _equip <= 0.0:
			_apply_tool(_switch_to)
			_switch_to = ""
	else:
		_equip = move_toward(_equip, 1.0, delta * 4.5)
	_use = lerpf(_use, _use_target, 1.0 - exp(-10.0 * delta))
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))

	var e := 1.0 - pow(1.0 - _equip, 3.0)
	var lower := Vector3(0, -0.28 * (1.0 - e), 0.06 * (1.0 - e))
	var breathe := Vector3(0, sin(_t * 1.4) * 0.0025, 0)
	var bob := Vector3(cos(_bob * 0.5) * 0.007, -absf(sin(_bob)) * 0.009, 0)
	var sway := Vector3(-_sway.x, _sway.y, 0)
	# Geste : avance vers le centre de l'écran (la zone visée).
	var reach := Vector3(-0.07, 0.07, -0.13) * _use
	var jitter := Vector3(sin(_t * 23.0), cos(_t * 19.0), 0) * 0.0015 * _use
	var off := lower + breathe + bob + sway + jitter
	right.transform = Transform3D(_base_r.basis, _base_r.origin + off + reach)
	var reach_l := Vector3(0.07, 0.07, -0.13) * _use
	left.transform = Transform3D(_base_l.basis, _base_l.origin + off * Vector3(-1, 1, 1) + reach_l)
	if tool == "mains":
		right.set_pose("flat" if _use > 0.3 else "relaxed")
		left.set_pose("flat" if _use > 0.3 else "relaxed")
	visible = _visible_hands
