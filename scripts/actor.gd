class_name Actor
extends CharacterBody3D
## Personnage animé non joueur : corps réaliste (Human), bibliothèque de poses procédurales
## (téléphone, filmer, poing levé, pancarte, banderole, fumigène, mégaphone, applaudir, matraque,
## bouclier, menottes...), voix avec synchro labiale, déplacement avec évitement.
## Les civils (Npc) et les policiers (Cop) en héritent et ajoutent leur « cerveau ».

const WALK := 1.25
const RUN := 3.7

var crowd: Crowd
var human: Human
var idx := 0
var variant := "male_a"
var outfit := {}
var female := false
var voice := "m1"
var vpitch := 1.0
var bold := 0.5
var calm := 0.5

# --- déplacement
var has_goal := false
var goal := Vector3.ZERO
var path: Array[Vector3] = []
var speed_want := WALK
var arrive_r := 0.35
var vel := Vector3.ZERO
var yaw := 0.0
var face_point := Vector3.ZERO
var has_face := false
var fire_ok := false         # autorisé à s'approcher d'un feu (pour l'alimenter)
var banner_side := 1.0       # perche à droite (+1) ou à gauche (-1) pour la banderole
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO
var _walk_k := 1.0

# --- haut du corps / expression
var act := "idle"
var act_t := 0.0
var prm := {}
var _prev_act := "idle"
var _prev_t := 0.0
var _prev_prm := {}
var _blend := 1.0
var _blend_speed := 3.0
var look_p := Vector3.ZERO
var look_w := 0.0
var _look_want := 0.0
var _say_env: Array = []
var _say_t := -1.0
var _say_loud := false
var _talk_amp := 0.0
var jaw_extra := 0.0
var _hop_t := -1.0
var _hop_n := 1
var _anim_acc := 0.0
var _frame := 0

var mega: Node3D             # mégaphone tenu (civil meneur ou chef de police)
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _pocket_style := "jeans"
var _rng := RandomNumberGenerator.new()
var _k := 1.0                # échelle des bras


func _ready() -> void:
	_rng.seed = idx * 7919 + 13
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	human = Human.new()
	human.variant = variant
	human.outfit = outfit
	human.sway_seed = _rng.randf() * 10.0
	add_child(human)
	human.hand_provider = Callable(self, "_hands")
	human.kick_impact.connect(_on_kick_impact)
	human.footstep.connect(_on_footstep)
	_k = human.arm_length() / 0.54
	_pocket_style = "hoodie" if outfit.get("top", "hoodie") == "hoodie" else "jeans"
	_walk_k = _rng.randf_range(0.88, 1.12)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"Voix"
	_voice.position.y = 1.6
	_voice.unit_size = 3.0
	_voice.max_distance = 70.0
	_voice.pitch_scale = vpitch
	_voice.finished.connect(_on_voice_done)
	add_child(_voice)
	_steps = AudioStreamPlayer3D.new()
	_steps.unit_size = 2.5
	_steps.max_distance = 18.0
	add_child(_steps)
	yaw = rotation.y


# =================================================================== repères
## corps (x droite, y haut, z avant) -> monde
func _bw(v: Vector3) -> Vector3:
	return global_transform * Vector3(v.x, v.y, -v.z)


func _bd(v: Vector3) -> Vector3:
	return global_basis * Vector3(v.x, v.y, -v.z)


func _wb(p: Vector3) -> Vector3:
	var l := global_transform.affine_inverse() * p
	return Vector3(l.x, l.y, -l.z)


func _wbd(d: Vector3) -> Vector3:
	var l := global_basis.inverse() * d
	return Vector3(l.x, l.y, -l.z)


func forward() -> Vector3:
	return -global_basis.z


## Repère de la bouche (monde) : origine au contact des lèvres, +Z = devant le personnage, suit la tête.
func mouth_xf() -> Transform3D:
	var hs := human.hscale()
	var head_pose := human.skeleton.get_bone_global_pose(human.bone["head"])
	var local := Transform3D(Basis(Vector3.RIGHT, -0.07), Vector3(0, -0.037 * hs, 0.108 * hs))
	return human.skeleton.global_transform * head_pose * local


func head_pos() -> Vector3:
	return human.head_world() + Vector3.UP * 0.05


# =================================================================== poses
func set_act(name: String, p := {}, speed := 3.0) -> void:
	if name == act and p.hash() == prm.hash():
		return
	if name == act:
		prm = p
		return
	_prev_act = act
	_prev_t = act_t
	_prev_prm = prm
	act = name
	act_t = 0.0
	prm = p
	_blend = 0.0
	_blend_speed = speed


func _h(pos: Vector3, f: Vector3, p: Vector3, curl := 0.6, index := 0.0, pole := Vector3.ZERO) -> Dictionary:
	var d := {"pos": pos, "f": f.normalized(), "p": p.normalized(), "curl": curl, "index": index}
	if pole != Vector3.ZERO:
		d["pole"] = pole.normalized()
	return d


## Main gauche symétrique d'une main droite (décalages relatifs aux épaules)
func _sym(off: Vector3, f: Vector3, p: Vector3, curl: float, pole := Vector3.ZERO, sr := Vector3.ZERO, sl := Vector3.ZERO) -> Array:
	var m := Vector3(-1, 1, 1)
	return [_h(sr + off, f, p, curl, 0.0, pole), _h(sl + off * m, f * m, p * m, curl, 0.0, pole * m)]


func _pose(name: String, t: float, p: Dictionary) -> Array:
	if name == "idle" or human == null:
		return [null, null]
	var k := _k
	var sr := _wb(human.shoulder_world("R"))
	var sl := _wb(human.shoulder_world("L"))
	var hd := _wb(human.head_world())
	var mouth := hd + Vector3(0, -0.035, 0.105)
	var eye := hd + Vector3(0, 0.04, 0.09)
	var mid := (sr + sl) * 0.5
	match name:
		"pocket":
			if _pocket_style == "hoodie":
				return _sym(Vector3(-0.11, -0.5, 0.17) * k, Vector3(-0.8, -0.2, 0.2), Vector3(0, 0.1, -1), 0.35, Vector3(1, -0.6, -0.5), sr, sl)
			return _sym(Vector3(0.0, -0.53, 0.06) * k, Vector3(0.1, -1, 0.25), Vector3(-1, 0, 0), 0.3, Vector3(1, -0.4, -0.6), sr, sl)
		"crossed":
			return [_h(sr + Vector3(-0.27, -0.27, 0.2) * k, Vector3(-1, 0.15, 0.1), Vector3(0, 0.15, -1), 0.45, 0.0, Vector3(1, -1, 0.2)),
				_h(sl + Vector3(0.25, -0.31, 0.135) * k, Vector3(1, 0.1, 0.1), Vector3(0, 0.15, -1), 0.45, 0.0, Vector3(-1, -1, 0.2))]
		"akimbo":
			return _sym(Vector3(0.06, -0.42, -0.02) * k, Vector3(-0.3, -0.75, 0.55), Vector3(-1, 0, 0), 0.2, Vector3(1, 0, -0.5), sr, sl)
		"back":
			return _sym(Vector3(-0.13, -0.5, -0.17) * k, Vector3(-0.6, -0.5, -0.3), Vector3(-0.5, 0, -0.8), 0.4, Vector3(1, -1, 0.3), sr, sl)
		"phone":
			var r := _h(sr + Vector3(-0.12, -0.30, 0.30) * k + Vector3(0, sin(t * 0.7) * 0.01, 0), Vector3(0, 0.6, 0.8), Vector3(0, 0.8, -0.6), 0.55)
			var l: Variant = null
			if p.get("two", false):
				l = _h(sl + Vector3(0.1, -0.32, 0.28) * k, Vector3(0, 0.6, 0.8), Vector3(0, 0.8, -0.6), 0.5)
			return [r, l]
		"film":
			var dir := _film_dir(p.get("dir", Vector3(0, 0.05, 1)))
			var pos := eye + dir * 0.4 * k + Vector3(0.05, -0.07, 0) + Vector3(sin(t * 1.3) * 0.006, sin(t * 1.7) * 0.006, 0)
			var back := (eye - pos).normalized()
			return [_h(pos, Vector3(0, 1, 0), back, 0.62, 0.0, Vector3(1, -1, -0.2)), null]
		"selfie":
			var pos2 := eye + Vector3(0.12, 0.18, 0.42) * k
			return [_h(pos2, Vector3(0, 1, 0), (eye - pos2), 0.62, 0.0, Vector3(1, -0.8, 0)), null]
		"call":
			return [_h(hd + Vector3(0.09, -0.03, 0.05), Vector3(0, 0.55, -0.8), Vector3(-1, 0, 0), 0.55, 0.0, Vector3(0.3, -1, 0.6)), null]
		"fist":
			var pk: float = p.get("k", 0.0)
			var off := Vector3(0.03, 0.08, 0.13).lerp(Vector3(0.06, 0.5, 0.08), pk) * k
			var l2: Variant = null
			if p.get("left", "") == "akimbo":
				l2 = _h(sl + Vector3(-0.06, -0.42, -0.02) * k, Vector3(0.3, -0.75, 0.55), Vector3(1, 0, 0), 0.2, 0.0, Vector3(-1, 0, -0.5))
			return [_h(sr + off, Vector3(0, 1, 0.15), Vector3(-0.6, 0, 0.8), 1.0, 0.0, Vector3(1, -0.4, -0.2)), l2]
		"cheer":
			var open: bool = p.get("open", true)
			var wob := Vector3(sin(t * 7.0) * 0.03, sin(t * 3.5) * 0.04, 0)
			return _sym(Vector3(0.13, 0.48, 0.06) * k + wob, Vector3(0.25, 1, 0.1), Vector3(-0.3, 0, 1), 0.2 if open else 0.95, Vector3(1, -0.2, -0.3), sr, sl)
		"clap":
			var gap: float = p.get("gap", 0.1)
			var c := mid + Vector3(0, -0.2, 0.33) * k
			return [_h(c + Vector3(gap * 0.5 + 0.03, 0, 0), Vector3(0, 0.45, 0.9), Vector3(-1, 0, 0), 0.15, 0.0, Vector3(1, -1, -0.3)),
				_h(c + Vector3(-gap * 0.5 - 0.03, 0, 0), Vector3(0, 0.45, 0.9), Vector3(1, 0, 0), 0.15, 0.0, Vector3(-1, -1, -0.3))]
		"sign":
			var raise: float = p.get("raise", 0.0)
			var b := Vector3(0.0, sr.y - 0.2 * k + raise * 0.32 * k, 0.29 * k + raise * 0.04)
			return [_h(b + Vector3(0.035, 0.15, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -1, -0.3)),
				_h(b + Vector3(-0.035, -0.12, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), 0.95, 0.0, Vector3(-1, -1, -0.3))]
		"sign_rest":
			return [_h(sr + Vector3(-0.07, -0.22, 0.2) * k, Vector3(-1, 0, 0), Vector3(0, -0.51, -0.86), 0.95, 0.0, Vector3(1, -1, -0.2)), null]
		"banner":
			var s: float = banner_side
			var pp := Vector3(s * 0.2, sr.y - 0.12 * k, 0.24 * k)
			var bob := sin(t * 1.9) * 0.012
			var upper := _h(pp + Vector3(0, 0.2 + bob, 0), Vector3(0, 0, 1), Vector3(-s, 0, 0), 0.95, 0.0, Vector3(s, -1, -0.3))
			var lower := _h(pp + Vector3(-s * 0.01, -0.14 + bob, 0.02), Vector3(0, 0, 1), Vector3(-s, 0, 0), 0.95, 0.0, Vector3(-s, -1, -0.2))
			return [upper, lower] if s > 0.0 else [lower, upper]
		"flare_up":
			var sway := Vector3(sin(t * 2.2) * 0.08, sin(t * 4.4) * 0.03, 0)
			return [_h(sr + Vector3(0.02, 0.48, 0.14) * k + sway, Vector3(0, 0.3, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -0.3, -0.2)), null]
		"flare_low":
			return [_h(sr + Vector3(0.03, -0.25, 0.27) * k, Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -1, -0.3)), null]
		"flare_light":
			var rp := sr + Vector3(-0.1, -0.15, 0.3) * k
			var cap := rp + Vector3(0, 0.17, 0)
			var u: float = clampf(t / 1.1, 0.0, 1.0)
			var lp := sl + Vector3(0.05, -0.3, 0.2) * k
			if u > 0.2:
				lp = cap + Vector3(-0.02, 0.03 + (0.12 if u > 0.75 else 0.0), 0) + Vector3(sin(t * 18.0) * 0.01, 0, 0) * float(u < 0.75)
			return [_h(rp, Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.95), _h(lp, Vector3(0.3, 0.2, 1), Vector3(0, -1, 0), 0.7)]
		"point":
			var d: Vector3 = (p.get("dir", Vector3(0, 0.2, 1)) as Vector3).normalized()
			return [_h(sr + d * 0.55 * k, d, Vector3(0, -1, 0), 1.0, 1.0, Vector3(1, -0.6, -0.4)), null]
		"cup":
			return [_h(mouth + Vector3(0.065, -0.01, 0.045), Vector3(-0.3, 0.3, 0.9), Vector3(-0.85, 0, 0.5), 0.35, 0.0, Vector3(1, -0.8, 0.2)),
				_h(mouth + Vector3(-0.065, -0.01, 0.045), Vector3(0.3, 0.3, 0.9), Vector3(0.85, 0, 0.5), 0.35, 0.0, Vector3(-1, -0.8, 0.2))]
		"whistle":
			return [_h(mouth + Vector3(0.02, -0.06, 0.07), Vector3(-0.2, 0.5, -0.8), Vector3(-0.9, 0, -0.2), 0.8, 1.0, Vector3(1, -1, 0.4)), null]
		"talk":
			var amp: float = clampf(_talk_amp, 0.0, 1.0)
			var g := Vector3(sin(t * 2.3) * 0.04, sin(t * 3.1 + 1.0) * 0.07, sin(t * 1.7) * 0.03) * (0.3 + amp)
			var r2 := _h(sr + Vector3(-0.07, -0.35, 0.27) * k + g, Vector3(0.05, 0.2, 1), Vector3(-0.55, 0.83, 0), 0.3)
			var l3: Variant = null
			if p.get("two", false):
				var g2 := Vector3(sin(t * 2.0 + 2.0) * 0.04, sin(t * 2.7 + 3.0) * 0.06, 0) * (0.3 + amp)
				l3 = _h(sl + Vector3(0.07, -0.37, 0.25) * k + g2, Vector3(-0.05, 0.2, 1), Vector3(0.55, 0.83, 0), 0.3)
			return [r2, l3]
		"warm":
			var rub: float = p.get("rub", 0.0)
			var off2 := Vector3(-0.1 - rub * 0.07, -0.24, 0.42) * k
			return _sym(off2 + Vector3(0, sin(t * 6.0) * 0.015 * rub, 0), Vector3(0, 1, 0.3), Vector3(0, -0.3, 1), 0.15, Vector3(1, -1, -0.2), sr, sl)
		"head":
			return [_h(hd + Vector3(0.08, 0.16, -0.01), Vector3(-1, 0.1, 0), Vector3(0, -1, 0), 0.25, 0.0, Vector3(1, 0.3, 0)),
				_h(hd + Vector3(-0.08, 0.16, -0.01), Vector3(1, 0.1, 0), Vector3(0, -1, 0), 0.25, 0.0, Vector3(-1, 0.3, 0))]
		"cover":
			return [_h(hd + Vector3(0.06, 0.12, 0.04), Vector3(-0.7, 0.2, 0.6), Vector3(0, -1, 0), 0.3, 0.0, Vector3(0.6, -0.2, 0.8)),
				_h(hd + Vector3(-0.06, 0.12, 0.04), Vector3(0.7, 0.2, 0.6), Vector3(0, -1, 0), 0.3, 0.0, Vector3(-0.6, -0.2, 0.8))]
		"refuse":
			var sh := Vector3(sin(t * 9.0) * 0.03, 0, 0)
			return _sym(Vector3(-0.1, -0.12, 0.33) * k + sh, Vector3(0, 1, 0.1), Vector3(0, 0, 1), 0.1, Vector3(1, -1, -0.3), sr, sl)
		"wave":
			var w := sin(t * 8.0)
			return [_h(sr + Vector3(0.12 + w * 0.06, 0.42, 0.07) * k, Vector3(w * 0.3, 1, 0), Vector3(0, 0, 1), 0.1, 0.0, Vector3(1, -0.3, -0.2)), null]
		"throw":
			var dir2: Vector3 = (p.get("dir", Vector3(0, 0.3, 1)) as Vector3).normalized()
			var cocked := _h(sr + Vector3(0.06, 0.17, -0.11) * k, Vector3(0, 0.9, -0.2), Vector3(0, 0, 1), 0.6, 0.0, Vector3(1, -0.3, -0.5))
			var rel := _h(sr + dir2 * 0.5 * k + Vector3(0, 0.04, 0), dir2, Vector3(0, -1, 0), 0.15, 0.0, Vector3(1, -0.8, 0))
			var carry := _h(sr + Vector3(0.04, -0.4, 0.15) * k, Vector3(0, 0, 1), Vector3(0, 1, 0), 0.6)
			var bal := _h(sl + Vector3(0.05, 0.0, 0.38) * k, Vector3(0, 0.2, 1), Vector3(0, -1, 0), 0.3)
			var rr: Dictionary
			var lw := 0.0
			if t < 0.34:
				rr = _blend_h(carry, cocked, _ease(t / 0.34))
				lw = _ease(t / 0.34)
			elif t < 0.48:
				rr = _blend_h(cocked, rel, _ease((t - 0.34) / 0.14))
				lw = 1.0
			else:
				rr = _blend_h(rel, carry, _ease((t - 0.48) / 0.5))
				lw = 1.0 - _ease((t - 0.48) / 0.4)
			bal["w"] = lw
			return [rr, bal]
		"toss2":
			var c2 := mid + Vector3(0, -0.42, 0.28) * k
			var hi := mid + Vector3(0, 0.05, 0.5) * k
			var u2 := 0.0
			if t < 0.35:
				c2 = c2.lerp(mid + Vector3(0, -0.5, 0.22) * k, _ease(t / 0.35))
			elif t < 0.55:
				u2 = _ease((t - 0.35) / 0.2)
				c2 = (mid + Vector3(0, -0.5, 0.22) * k).lerp(hi, u2)
			else:
				c2 = hi.lerp(mid + Vector3(0, -0.35, 0.3) * k, _ease((t - 0.55) / 0.5))
			var hw: float = p.get("w", 0.36) * 0.5 + 0.03
			return [_h(c2 + Vector3(hw, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.5, 0.0, Vector3(1, -1, -0.3)),
				_h(c2 + Vector3(-hw, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), 0.5, 0.0, Vector3(-1, -1, -0.3))]
		"carry":
			var w2: float = p.get("w", 0.36)
			var c3 := mid + Vector3(0, -0.4, 0.3) * k
			return [_h(c3 + Vector3(w2 * 0.5 + 0.03, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.5, 0.0, Vector3(1, -1, -0.3)),
				_h(c3 + Vector3(-w2 * 0.5 - 0.03, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), 0.5, 0.0, Vector3(-1, -1, -0.3))]
		"pick":
			var tg: Vector3 = p.get("target", Vector3(0.15, 0.05, 0.45))
			return [_h(tg + Vector3(0, 0.06, 0), Vector3(0, -0.5, 0.86), Vector3(0, -1, 0), 0.6, 0.0, Vector3(1, 0, -0.4)),
				_h(sl + Vector3(0.02, -0.62, 0.32) * k, Vector3(0, -0.2, 1), Vector3(0, -1, 0), 0.4)]
		"dep1":
			# une main (droite) tient le déchet et le descend vers le foyer, puis s'ouvre
			var tg3: Vector3 = p.get("target", Vector3(0.1, 0.8, 0.6))
			var u3: float = clampf(p.get("u", 0.0), 0.0, 1.0)
			var op3: float = clampf(p.get("open", 0.0), 0.0, 1.0)
			var from3 := sr + Vector3(-0.08, -0.3, 0.28) * k
			var over3 := tg3 + Vector3(0, 0.14, 0)
			var pos3 := from3.lerp(over3, _ease(u3))
			var fd3 := (Vector3(0, -0.5, 1.0)).lerp((tg3 - pos3).normalized(), 0.45)
			var left3: Variant = null
			if p.get("brace", false):
				left3 = _h(sl + Vector3(0.12, -0.38, 0.12) * k, Vector3(0.4, -0.7, 0.6), Vector3(-1, 0, 0), 0.4, 0.0, Vector3(-1, -1, 0))
			return [_h(pos3, fd3, Vector3(-1, 0, 0), lerpf(0.78, 0.12, op3), 0.0, Vector3(1, -0.7, -0.3)), left3]
		"dep2":
			# deux mains portent un carton / une planche jusqu'au foyer
			var tg4: Vector3 = p.get("target", Vector3(0, 0.8, 0.7))
			var u4: float = clampf(p.get("u", 0.0), 0.0, 1.0)
			var op4: float = clampf(p.get("open", 0.0), 0.0, 1.0)
			var hw4: float = float(p.get("w", 0.36)) * 0.5 + 0.03
			var c0 := mid + Vector3(0, -0.4, 0.3) * k
			var c1 := tg4 + Vector3(0, 0.16, -0.04)
			var cc := c0.lerp(c1, _ease(u4))
			var cv := lerpf(0.5, 0.12, op4)
			return [_h(cc + Vector3(hw4, 0, 0), Vector3(0, -0.2, 1), Vector3(-1, 0, 0), cv, 0.0, Vector3(1, -1, -0.3)),
				_h(cc + Vector3(-hw4, 0, 0), Vector3(0, -0.2, 1), Vector3(1, 0, 0), cv, 0.0, Vector3(-1, -1, -0.3))]
		"ignite":
			# main droite avec le briquet, vers le papier à allumer
			var tg5: Vector3 = p.get("target", Vector3(0.1, 0.3, 0.6))
			var u5: float = clampf(p.get("u", 0.0), 0.0, 1.0)
			var from5 := sr + Vector3(-0.08, -0.32, 0.28) * k
			var pos5 := from5.lerp(tg5 + Vector3(-0.02, -0.07, -0.02), _ease(u5))
			var left5: Variant = null
			if p.get("brace", false):
				left5 = _h(sl + Vector3(0.12, -0.38, 0.12) * k, Vector3(0.4, -0.7, 0.6), Vector3(-1, 0, 0), 0.4, 0.0, Vector3(-1, -1, 0))
			return [_h(pos5, Vector3(0, -0.15, 1).lerp((tg5 - pos5).normalized(), 0.35), Vector3(-1, 0, 0), 0.85, 0.0, Vector3(1, -0.7, -0.3)), left5]
		"cuffed":
			# mains menottées dans le dos
			var cb := Vector3(0.0, sr.y - 0.62 * k, -0.18 * k)
			return [_h(cb + Vector3(0.045, 0, 0), Vector3(0, -0.8, -0.2), Vector3(-1, 0, 0), 0.6, 0.0, Vector3(1, -1, 0.5)),
				_h(cb + Vector3(-0.045, 0, 0), Vector3(0, -0.8, -0.2), Vector3(1, 0, 0), 0.6, 0.0, Vector3(-1, -1, 0.5))]
		"resist":
			# se débat : bras qui tirent dans tous les sens
			var w1 := sin(t * 11.0)
			var w2 := sin(t * 9.0 + 1.3)
			return [_h(sr + Vector3(0.1 + w1 * 0.08, -0.28 + w2 * 0.12, 0.26 + w2 * 0.06) * k, Vector3(0.2, -0.3, 1), Vector3(-1, 0.2, 0), 0.7, 0.0, Vector3(1, -1, -0.2)),
				_h(sl + Vector3(-0.1 + w2 * 0.08, -0.3 + w1 * 0.1, 0.22 + w1 * 0.06) * k, Vector3(-0.2, -0.3, 1), Vector3(1, 0.2, 0), 0.7, 0.0, Vector3(-1, -1, -0.2))]
		"surrender":
			return _sym(Vector3(0.14, 0.38, 0.08) * k + Vector3(0, sin(t * 3.0) * 0.012, 0), Vector3(0.1, 1, 0.2), Vector3(-0.2, 0, 1), 0.05, Vector3(1, -0.3, -0.3), sr, sl)
		"reach":
			var tg2: Vector3 = p.get("target", Vector3(0.1, 1.0, 0.6))
			return [_h(tg2, Vector3(0, -0.2, 1), Vector3(0, 1, 0), 0.6, 0.0, Vector3(1, -1, -0.2)), null]
		"megaphone":
			if mega == null:
				return [null, null]
			var mx := mouth_xf() * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.012))
			var gp: Vector3 = mx * (mega.get_meta("grip") as Vector3)
			var rh := _h(_wb(gp), _wbd(mx.basis.z), _wbd(mx.basis.x), 0.95, 0.0, Vector3(1, -0.7, -0.15))
			var lh: Variant = null
			if p.get("left", "hip") == "fist":
				var pump: float = p.get("pump", 0.0)
				lh = _h(sl + Vector3(-0.05, 0.3 + 0.12 * pump, 0.12) * k, Vector3(0, 1, 0.1), Vector3(1, 0, 0.3), 1.0, 0.0, Vector3(-1, -0.4, -0.2))
			else:
				lh = _h(sl + Vector3(-0.06, -0.42, -0.02) * k, Vector3(0.3, -0.75, 0.55), Vector3(1, 0, 0), 0.2, 0.0, Vector3(-1, 0, -0.5))
			return [rh, lh]
		"mega_low":
			return [_h(sr + Vector3(0.03, -0.47, 0.13) * k, Vector3(0, -0.15, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -1, -0.3)), null]
		"mortar_carry":
			return [_h(sr + Vector3(0.03, -0.46, 0.21) * k, Vector3(0, -0.3, 0.95), Vector3(-1, 0, 0), 1.1), null]
		"mortar_light":
			var mp := sr + Vector3(-0.08, -0.33, 0.24) * k
			var ax := Vector3(0, 0.84, 0.54)
			var mouth_t := mp - ax * MortarModel.TUBE_LEN * 0.25 + ax * MortarModel.TUBE_LEN
			var u3: float = clampf(t, 0.0, 2.0)
			var lpos := sl + Vector3(0.05, -0.3, 0.2) * k
			if u3 > 0.35:
				lpos = mouth_t + Vector3(-0.07, -0.02, 0.02)
			return [_h(mp, Vector3(0, 0, 1), Vector3(-1, 0, 0), 1.1), _h(lpos, Vector3(0, 0.3, 1), Vector3(1, 0, 0), 0.85)]
		"mortar_aim":
			var ax2: Vector3 = (p.get("axis", Vector3(0, 0.95, 0.3)) as Vector3).normalized()
			return [_h(sr + ax2 * 0.36 * k + Vector3(0, -0.035, 0), (ax2 + Vector3.UP).normalized(), Vector3(-1, 0, 0), 1.1, 0.0, Vector3(1, -1, -0.2)), null]
		"smoke_hold":
			return [_h(sr + Vector3(0.0, -0.42, 0.16) * k, Vector3(0, 0.25, 1), Vector3(-1, 0, 0), 0.45), null]
		"smoke_drag":
			return [_h(mouth + Vector3(0.035, -0.005, 0.055), Vector3(-0.3, 1, 0), Vector3(0, 0, -1), 0.3, 0.0, Vector3(1, -1, 0.3)), null]
		"stone":
			return [_h(sr + Vector3(0.04, -0.4, 0.15) * k, Vector3(0, 0, 1), Vector3(0, 1, 0), 0.6), null]
		"drink":
			# la bouteille monte à la bouche, bascule, puis redescend
			var du: float = clampf(t / 0.9, 0.0, 1.0) if t < 3.6 else clampf(1.0 - (t - 3.6) / 0.8, 0.0, 1.0)
			var due := _ease(du)
			var rest_p := sr + Vector3(0.0, -0.36, 0.26) * k
			var up_p := mouth + Vector3(0.0, -0.06, 0.09)
			var fing := Vector3(0, 0, 1).lerp(Vector3(0, 0.83, 0.55), due).normalized()
			return [_h(rest_p.lerp(up_p, due), fing, Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -0.8, 0.0)), null]
		"give":
			# bras tendu pour offrir la bouteille
			var gd: Vector3 = (p.get("dir", Vector3(0, 0, 1)) as Vector3).normalized()
			return [_h(sr + Vector3(gd.x, 0.0, gd.z).normalized() * 0.42 * k + Vector3(0, -0.2, 0), Vector3(gd.x, 0.5, gd.z), Vector3(-1, 0, 0), 0.9, 0.0, Vector3(1, -0.8, -0.2)), null]
		"stretch":
			var su := _ease(clampf(t / 1.2, 0.0, 1.0))
			var wob2 := Vector3(sin(t * 5.0) * 0.012, 0.0, 0.0)
			return _sym(Vector3(0.1, 0.1, 0.0).lerp(Vector3(0.12, 0.62, -0.1), su) * k + wob2, Vector3(0.1, 1, -0.1), Vector3(-0.3, 0, 1), 0.7, Vector3(1, -0.2, -0.5), sr, sl)
		"rest_knee":
			# assis, mains posées sur les genoux
			return _sym(Vector3(0.05, -0.34, 0.4) * k, Vector3(0, -0.45, 1), Vector3(0, 1, 0), 0.35, Vector3(1, -0.4, -0.3), sr, sl)
		"treat":
			# soigner quelqu'un : les deux mains près de la personne secourue
			var tt: Vector3 = p.get("target", Vector3(0, 0.5, 0.6))
			var sway := Vector3(0, sin(t * 3.0) * 0.012, 0)
			return [_h(tt + Vector3(0.09, 0, 0) + sway, Vector3(0, -0.8, 0.6), Vector3(-1, 0, 0.2), 0.4, 0.0, Vector3(1, -0.5, 0.0)),
				_h(tt + Vector3(-0.09, 0, 0) - sway, Vector3(0, -0.8, 0.6), Vector3(1, 0, 0.2), 0.4, 0.0, Vector3(-1, -0.5, 0.0))]
		"shoot":
			# reporter : appareil à longue focale tenu à deux mains, collé à l'œil droit (dans ce repère +X = droite)
			var sd := _film_dir(p.get("dir", Vector3(0, 0.05, 1)))
			var rgt := Vector3.UP.cross(sd).normalized()
			var cpos := eye + sd * 0.25 * k + Vector3(rgt.x * 0.035, -0.045, rgt.z * 0.035)
			var rh := cpos + rgt * 0.075 + Vector3(0, -0.02, 0)
			var lh := cpos - rgt * 0.02 + sd * 0.1 + Vector3(0, -0.065, 0)
			return [_h(rh, (sd + Vector3.UP * 0.3).normalized(), -rgt, 0.85, 0.0, Vector3(1, -0.8, 0.2)),
				_h(lh, sd, Vector3.UP, 0.5, 0.0, Vector3(-1, -0.8, 0.2))]
		"beckon":
			var bk := sin(t * 5.0) * 0.5 + 0.5
			return [_h(sr + Vector3(0.05, 0.25 + bk * 0.1, 0.35 - bk * 0.15) * k, Vector3(0, 0.6 + bk * 0.3, 0.8 - bk * 0.5), Vector3(0, -0.3, -1), 0.2, 0.0, Vector3(1, -0.5, -0.3)), null]
	return [null, null]


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


var _film_d := Vector3(0, 0.05, 1)


## Direction de visée du téléphone, ramenée dans un cône devant le visage et lissée :
## le téléphone ne passe jamais derrière la tête, même quand le corps n'a pas fini de se tourner.
func _film_dir(want: Vector3) -> Vector3:
	var w := want.normalized() if want.length() > 0.01 else Vector3(0, 0.05, 1)
	var yaw := clampf(atan2(w.x, w.z), -0.75, 0.75)
	var pitch := clampf(asin(clampf(w.y, -1.0, 1.0)), -0.45, 0.55)
	var tgt := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	_film_d = Fx.vslerp(_film_d, tgt, 0.12).normalized()
	return _film_d


func _blend_h(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r := {
		"pos": (a["pos"] as Vector3).lerp(b["pos"], u),
		"f": Fx.vslerp(a["f"], b["f"], u).normalized(),
		"p": Fx.vslerp(a["p"], b["p"], u).normalized(),
		"curl": lerpf(a.get("curl", 0.6), b.get("curl", 0.6), u),
		"index": lerpf(a.get("index", 0.0), b.get("index", 0.0), u),
		"w": lerpf(a.get("w", 1.0), b.get("w", 1.0), u),
	}
	if a.has("pole") or b.has("pole"):
		var pa: Vector3 = a.get("pole", Vector3(1, -1, -0.45))
		var pb: Vector3 = b.get("pole", Vector3(1, -1, -0.45))
		r["pole"] = pa.lerp(pb, u).normalized()
	return r


## Fournisseur de cibles des mains (appelé par Human pendant l'animation)
func _hands() -> Array:
	var cur := _pose(act, act_t, prm)
	if _blend < 1.0:
		var old := _pose(_prev_act, _prev_t, _prev_prm)
		var u := _ease(_blend)
		for i in 2:
			var a: Variant = old[i]
			var b: Variant = cur[i]
			if a != null and b != null:
				cur[i] = _blend_h(a, b, u)
			elif b != null:
				var bb: Dictionary = (b as Dictionary).duplicate()
				bb["w"] = float(bb.get("w", 1.0)) * u
				cur[i] = bb
			elif a != null:
				var aa: Dictionary = (a as Dictionary).duplicate()
				aa["w"] = float(aa.get("w", 1.0)) * (1.0 - u)
				cur[i] = aa
	var out := [null, null]
	for i in 2:
		if cur[i] == null:
			continue
		var d: Dictionary = cur[i]
		var o := {"pos": _bw(d["pos"]), "f": _bd(d["f"]), "p": _bd(d["p"]), "curl": d.get("curl", 0.6), "index": d.get("index", 0.0), "w": d.get("w", 1.0)}
		if d.has("pole"):
			var pl: Vector3 = d["pole"]
			# le pôle est donné pour la main concernée en repère corps ; Human l'attend en monde
			o["pole"] = _bd(pl)
		out[i] = o
	return out


# =================================================================== voix
## Joue une réplique (synchro labiale toujours ; son si la foule l'autorise). Renvoie la durée.
func say(sound: String, loud := false, vol := 0.0) -> float:
	if sound == "":
		return 0.0
	_say_env = AudioLib.env(sound)
	_say_t = 0.0
	_say_loud = loud
	var dur := maxf(_say_env.size() / AudioLib.ENV_HZ, 0.6)
	if crowd and crowd.voice_ok(self, loud):
		if _voice.playing:
			_voice.stop()
			crowd.voice_done()
		_voice.stream = AudioLib.stream(sound)
		_voice.unit_size = 7.0 if loud else 3.0
		_voice.volume_db = vol + (2.0 if loud else -2.0)
		_voice.pitch_scale = vpitch
		_voice.play()
		crowd.voice_started()
	return dur / vpitch


func say_cat(cat: String, loud := true, vol := 0.0) -> float:
	return say(AudioLib.pick(voice, cat), loud, vol)


func speaking() -> bool:
	return _say_t >= 0.0


func _on_voice_done() -> void:
	if crowd:
		crowd.voice_done()


func _on_footstep(spd: float) -> void:
	if crowd == null or not crowd.near_listener(global_position, 14.0):
		return
	_steps.stream = Sfx.get_stream(&"footstep_a" if _rng.randf() < 0.5 else &"footstep_b")
	_steps.volume_db = lerpf(-24.0, -12.0, clampf(spd / RUN, 0.0, 1.0))
	_steps.pitch_scale = _rng.randf_range(0.85, 1.15)
	_steps.play()


# =================================================================== déplacement
func go(p: Vector3, run := false, r := 0.35) -> void:
	goal = p
	has_goal = true
	arrive_r = r
	speed_want = (RUN if run else WALK) * _walk_k
	path = crowd.plan(global_position, p) if crowd else [p]
	_stuck_t = 0.0
	_stuck_ref = global_position


func follow(p: Vector3, spd: float) -> void:
	# poursuite continue d'une cible mobile (place dans le cortège)
	goal = p
	has_goal = true
	arrive_r = 0.2
	speed_want = spd
	path = [p]


func stop_move() -> void:
	has_goal = false
	path.clear()


func face(p: Vector3) -> void:
	face_point = p
	has_face = true


func _move(delta: float) -> void:
	var pos := global_position
	var desired := Vector3.ZERO
	if has_goal:
		if path.is_empty():
			path = [goal]
		var wp: Vector3 = path[0]
		var to := Vector3(wp.x - pos.x, 0, wp.z - pos.z)
		var d := to.length()
		var final_ := path.size() <= 1
		if not final_ and d < 0.7:
			path.pop_front()
		elif final_ and d < arrive_r:
			has_goal = false
			path.clear()
		else:
			var sp := speed_want
			if final_:
				sp = minf(sp, maxf(0.5, d * 1.7))
			desired = to / maxf(d, 0.001) * sp
		# coincé ?
		_stuck_t += delta
		if _stuck_t > 2.0:
			if pos.distance_to(_stuck_ref) < 0.25:
				if d < 1.5:
					has_goal = false
					path.clear()
				else:
					path = crowd.plan(pos, goal) if crowd else [goal]
			_stuck_t = 0.0
			_stuck_ref = pos
	var sep := crowd.separation(self) if crowd else Vector3.ZERO
	desired += sep * (2.4 if has_goal else 1.6)
	var acc := 9.0 if speed_want > 2.0 else 5.5
	vel = vel.move_toward(desired, acc * delta)
	if not has_goal and vel.length() < 0.12 and sep.length() < 0.05:
		vel = vel.move_toward(Vector3.ZERO, acc * delta)
	pos += vel * delta
	if crowd:
		pos = crowd.resolve(self, pos)
		pos.y = crowd.ground_y(pos)
	global_position = pos
	# orientation
	var hv := Vector2(vel.x, vel.z).length()
	var want := yaw
	if hv > 0.35:
		want = atan2(-vel.x, -vel.z)
	elif has_face:
		var fd := face_point - pos
		if Vector2(fd.x, fd.z).length() > 0.05:
			want = atan2(-fd.x, -fd.z)
	var err := wrapf(want - yaw, -PI, PI)
	var rate := 5.0 if hv > 0.35 else 2.8
	yaw += clampf(err, -rate * delta, rate * delta)
	rotation = Vector3(0, yaw, 0)
	human.step_in_place = 1.0 if (hv < 0.3 and absf(err) > 0.35 and human.kick_t < 0.0 and human.crouch < 0.3) else 0.0


# =================================================================== boucle
func tick(delta: float, anim_every: int) -> void:
	_frame += 1
	act_t += delta
	_prev_t += delta
	_blend = minf(_blend + delta * _blend_speed, 1.0)
	_pre_tick(delta)
	_think(delta)
	_move(delta)
	_express(delta)
	_anim_acc += delta
	if _frame % anim_every == 0 or human.kick_t >= 0.0:
		var hv := Vector3(vel.x, 0, vel.z).length()
		human.animate(_anim_acc, hv, clampf((hv - 1.6) / 2.0, 0.0, 1.0), true, 0.0, 0.0)
		_anim_acc = 0.0
		_place_props()


## Crochets pour les classes dérivées
func _pre_tick(_delta: float) -> void:
	pass


func _think(_delta: float) -> void:
	pass


func _place_props() -> void:
	pass


func _on_kick_impact(_point: Vector3) -> void:
	pass


func _express(delta: float) -> void:
	# synchro labiale
	var jaw := 0.0
	if _say_t >= 0.0:
		_say_t += delta * vpitch
		var e := AudioLib.env_at(_say_env, _say_t)
		jaw = e * (0.95 if _say_loud else 0.6)
		_talk_amp = lerpf(_talk_amp, e, minf(1.0, delta * 8.0))
		if _say_t > _say_env.size() / AudioLib.ENV_HZ + 0.1:
			_say_t = -1.0
	else:
		_talk_amp = lerpf(_talk_amp, 0.0, minf(1.0, delta * 3.0))
	jaw = maxf(jaw, jaw_extra)
	human.jaw = lerpf(human.jaw, jaw, minf(1.0, delta * 18.0))
	# saut de joie
	if _hop_t >= 0.0:
		_hop_t += delta
		var ph := _hop_t * 2.6
		human.hop = maxf(0.0, sin(ph * PI)) * 0.11 if ph < _hop_n else 0.0
		if ph >= _hop_n:
			_hop_t = -1.0
			human.hop = 0.0
	# regard
	look_w = lerpf(look_w, _look_want, minf(1.0, delta * 3.0))
	human.look_w = look_w
	human.look_target = look_p


func look(p: Vector3, w := 1.0) -> void:
	look_p = p
	_look_want = w


func hop(n := 2) -> void:
	_hop_t = 0.0
	_hop_n = n


