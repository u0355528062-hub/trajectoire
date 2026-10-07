class_name Npc
extends CharacterBody3D
## Manifestant non joueur : corps réaliste (Human), bibliothèque de poses procédurales
## (téléphone, filmer, poing levé, pancarte, banderole, fumigène, mégaphone, applaudir,
## mains sur la tête, se protéger, lancer, porter, ramasser...), voix avec synchro labiale,
## déplacement avec évitement, et un petit cerveau (activité de fond + réactions).

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
var curious := 0.5
var calm := 0.5
var role := "loner"          # march, chat, loner, bloc
var group := -1
var slot := Vector2.ZERO     # cortège : (latéral, recul)
var home_pos := Vector3.ZERO
var prop := ""               # sign, banner, flare, megaphone, mortar
var sign_idx := 1
var banner_side := 1.0       # perche à droite (+1) ou à gauche (-1)
var smoker := false

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
var _cheer_beat := 0.0

# --- état
var state := "home"
var state_t := 0.0
var sub := ""
var sub_t := 0.0
var data := {}
var react_cd := 0.0
var _idle_t := 0.0
var _idle_pose := "idle"
var _glance_cd := 0.0
var _look_cd := 0.0
var _home_sub := ""
var _home_t := 0.0
var _home_dur := 0.0
var _mortar_cd := 0.0
var _flare_cd := 0.0
var _cig_t := 0.0
var _whistle_cd := 0.0

# --- accessoires
var phone: Node3D
var sign_node: Node3D
var flare: Flare
var mega: Node3D
var mortar_m: Node3D
var lighter: Node3D
var cig: Node3D
var item: Node3D             # objet porté (Burnable)
var stone_vis: MeshInstance3D
var pole_node: Node3D
var _fuse_fx: GPUParticles3D
var _fuse_light: OmniLight3D
var _voice: AudioStreamPlayer3D
var _steps: AudioStreamPlayer3D
var _cig_smoke: GPUParticles3D
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
	_build_props()
	_idle_pose = _pick_idle()
	_mortar_cd = _rng.randf_range(25.0, 50.0)
	_flare_cd = _rng.randf_range(2.0, 12.0)
	_cig_t = _rng.randf_range(0.0, 8.0)
	_whistle_cd = _rng.randf_range(10.0, 40.0)


# =================================================================== accessoires
func _build_props() -> void:
	phone = Props.phone("feed")
	phone.visible = false
	phone.top_level = true
	add_child(phone)
	match prop:
		"sign":
			sign_node = Props.sign_board(sign_idx)
			sign_node.top_level = true
			add_child(sign_node)
		"banner":
			pole_node = Node3D.new()
			var pm := CylinderMesh.new()
			pm.top_radius = 0.016
			pm.bottom_radius = 0.018
			pm.height = 2.05
			pm.radial_segments = 8
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = Props.wood()
			mi.position.y = 0.42
			pole_node.add_child(mi)
			pole_node.top_level = true
			add_child(pole_node)
		"flare":
			_new_flare()
		"megaphone":
			mega = Props.megaphone()
			mega.top_level = true
			add_child(mega)
		"mortar":
			mortar_m = MortarModel.build()
			mortar_m.top_level = true
			add_child(mortar_m)
			_fuse_fx = Fx.embers(30, Vector3(0.005, 0.005, 0.005), Color(1, 0.75, 0.4), 1.2)
			_fuse_fx.lifetime = 0.4
			_fuse_fx.emitting = false
			_fuse_fx.top_level = true
			add_child(_fuse_fx)
			_fuse_light = OmniLight3D.new()
			_fuse_light.light_color = Color(1, 0.6, 0.25)
			_fuse_light.omni_range = 2.5
			_fuse_light.light_energy = 0.0
			_fuse_light.top_level = true
			add_child(_fuse_light)
	if prop == "mortar":
		lighter = Props.lighter(Color(0.1, 0.3, 0.8) if _rng.randf() < 0.5 else Color(0.8, 0.15, 0.1))
		lighter.top_level = true
		lighter.visible = false
		add_child(lighter)
	if smoker:
		cig = Props.cigarette()
		cig.top_level = true
		add_child(cig)
		_cig_smoke = Fx.smoke(Color(0.75, 0.75, 0.78, 0.18), 10, 3.0, 0.06, true, 0.25, 6.0)
		_cig_smoke.top_level = true
		add_child(_cig_smoke)
	stone_vis = MeshInstance3D.new()
	stone_vis.mesh = Stone.make_mesh(idx + 3)
	stone_vis.material_override = Stone.material()
	stone_vis.scale = Vector3.ONE * 0.11
	stone_vis.top_level = true
	stone_vis.visible = false
	add_child(stone_vis)


func _new_flare() -> void:
	flare = Flare.new()
	flare.burn_time = _rng.randf_range(55.0, 80.0)
	flare.held = true
	add_child(flare)
	flare.top_level = true
	flare.burnt_out.connect(_on_flare_out)


func _on_flare_out() -> void:
	# fumigène fini : on le jette par terre, un autre plus tard
	if flare == null:
		return
	var f := flare
	flare = null
	_flare_cd = _rng.randf_range(25.0, 55.0)
	_drop_flare.call_deferred(f)


func _drop_flare(f: Flare) -> void:
	if not is_instance_valid(f):
		return
	var fwd := _bd(Vector3(0.3, 0.2, 1.0)).normalized()
	f.reparent(get_tree().current_scene, true)
	f.release(fwd * 2.5, Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)))


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
			var dir: Vector3 = p.get("dir", Vector3(0, 0.05, 1))
			var pos := eye + dir.normalized() * 0.4 * k + Vector3(0.05, -0.07, 0) + Vector3(sin(t * 1.3) * 0.006, sin(t * 1.7) * 0.006, 0)
			return [_h(pos, Vector3(0, 1, 0), (eye - pos), 0.62, 0.0, Vector3(1, -1, -0.2)), null]
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
		"reach":
			var tg2: Vector3 = p.get("target", Vector3(0.1, 1.0, 0.6))
			return [_h(tg2, Vector3(0, -0.2, 1), Vector3(0, 1, 0), 0.6, 0.0, Vector3(1, -1, -0.2)), null]
		"megaphone":
			return [_h(mouth + Vector3(0.0, -0.07, 0.12), Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.95, 0.0, Vector3(1, -0.6, 0.1)),
				_h(mouth + Vector3(-0.04, -0.06, 0.28), Vector3(0.3, 0.2, 1), Vector3(1, 0, 0), 0.5, 0.0, Vector3(-1, -1, 0))]
		"mega_low":
			return [_h(sr + Vector3(0.03, -0.45, 0.12) * k, Vector3(0, 0, 1), Vector3(-1, 0, 0), 0.95), null]
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
		"beckon":
			var bk := sin(t * 5.0) * 0.5 + 0.5
			return [_h(sr + Vector3(0.05, 0.25 + bk * 0.1, 0.35 - bk * 0.15) * k, Vector3(0, 0.6 + bk * 0.3, 0.8 - bk * 0.5), Vector3(0, -0.3, -1), 0.2, 0.0, Vector3(1, -0.5, -0.3)), null]
	return [null, null]


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _blend_h(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r := {
		"pos": (a["pos"] as Vector3).lerp(b["pos"], u),
		"f": (a["f"] as Vector3).slerp(b["f"], u).normalized(),
		"p": (a["p"] as Vector3).slerp(b["p"], u).normalized(),
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
	react_cd = maxf(react_cd - delta, 0.0)
	_glance_cd = maxf(_glance_cd - delta, 0.0)
	_look_cd = maxf(_look_cd - delta, 0.0)
	state_t += delta
	act_t += delta
	_prev_t += delta
	_blend = minf(_blend + delta * _blend_speed, 1.0)
	_think(delta)
	_move(delta)
	_express(delta)
	_anim_acc += delta
	if _frame % anim_every == 0 or human.kick_t >= 0.0:
		var hv := Vector3(vel.x, 0, vel.z).length()
		human.animate(_anim_acc, hv, clampf((hv - 1.6) / 2.0, 0.0, 1.0), true, 0.0, 0.0)
		_anim_acc = 0.0
		_place_props()


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


# =================================================================== accessoires (placement)
func _place_props() -> void:
	var phone_on := act in ["phone", "film", "call", "selfie"] and _blend > 0.4
	if _prev_act in ["phone", "film", "call", "selfie"] and act in ["phone", "film", "call", "selfie"]:
		phone_on = true
	phone.visible = phone_on
	var pr := human.palm("R")
	var pl := human.palm("L")
	if phone_on:
		var f: Vector3 = pr["f"]
		var p: Vector3 = pr["p"]
		phone.global_transform = Transform3D(Props.basis_up(f, p), (pr["pos"] as Vector3) + p * 0.018 + f * 0.012)
	var thumb: Vector3 = pr["thumb"]
	var grip: Vector3 = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.03
	var fwd := forward()
	if sign_node:
		var face_dir := _bd(Vector3(-1, 0, 0)) if act == "sign_rest" else fwd
		sign_node.global_transform = Transform3D(Props.basis_up(thumb, face_dir), grip)
	if pole_node:
		var gh: Dictionary = pr if banner_side > 0.0 else pl
		var g2: Vector3 = (gh["pos"] as Vector3) + (gh["p"] as Vector3) * 0.03
		pole_node.global_transform = Transform3D(Props.basis_up(gh["thumb"], fwd), g2)
	if flare and flare.held:
		flare.hold(Transform3D(Props.basis_up(thumb, fwd), grip + thumb * 0.06))
	if mega:
		var mb := Props.basis_up(thumb, pr["f"])
		mega.global_transform = Transform3D(mb, grip)
	if mortar_m:
		var axis: Vector3 = data.get("axis_w", _bd(Vector3(0, 0.71, 0.70)))
		var origin: Vector3 = (pr["pos"] as Vector3) - axis * 0.075 + (pr["p"] as Vector3) * (MortarModel.TUBE_R + 0.008)
		mortar_m.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis.normalized())), origin)
		_fuse_fx.global_position = origin + axis * (MortarModel.TUBE_LEN + 0.04)
		_fuse_light.global_position = _fuse_fx.global_position
	if lighter:
		lighter.visible = act == "mortar_light" and _blend > 0.5
		if lighter.visible:
			var lp: Vector3 = pl["pos"]
			lighter.global_position = lp + (pl["p"] as Vector3) * 0.04
			lighter.global_basis = Basis(Quaternion(Vector3.UP, (pl["thumb"] as Vector3)))
	if cig:
		var cp: Vector3 = (pr["pos"] as Vector3) + (pr["f"] as Vector3) * 0.075 + thumb * 0.012
		var ax2: Vector3 = (-(pr["p"] as Vector3) + (pr["f"] as Vector3) * 0.3).normalized()
		cig.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, ax2)), cp)
		var cyc := fmod(_cig_t, 9.0)
		if cyc > 1.8 and cyc < 3.4:   # on recrache la fumée
			_cig_smoke.global_position = human.head_world() + forward() * 0.13 + Vector3.DOWN * 0.03
		else:
			_cig_smoke.global_position = cp + ax2 * 0.075
	if stone_vis.visible:
		stone_vis.global_position = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.035 + (pr["f"] as Vector3) * 0.02
	if item and is_instance_valid(item) and item.get_parent() == self:
		if act == "carry" or act == "toss2":
			item.global_position = ((pr["pos"] as Vector3) + (pl["pos"] as Vector3)) * 0.5 + Vector3.UP * 0.02
			item.global_basis = global_basis
		else:
			item.global_position = (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.06


# =================================================================== cerveau
func _pick_idle() -> String:
	var opts := ["pocket", "crossed", "akimbo", "back", "idle", "idle"]
	if role == "bloc":
		opts = ["akimbo", "crossed", "pocket", "idle"]
	return opts[_rng.randi() % opts.size()]


## Pose « libre » compatible avec l'accessoire tenu
func _prop_rest_pose() -> String:
	if smoker and prop == "" and role != "march":
		return "smoke_drag" if fmod(_cig_t, 9.0) < 1.4 else "smoke_hold"
	match prop:
		"sign":
			return "sign_rest"
		"banner":
			return "banner"
		"flare":
			return "flare_low" if flare else _idle_pose
		"megaphone":
			return "mega_low"
		"mortar":
			return "mortar_carry"
	return _idle_pose


func _prop_cheer_pose() -> Array:
	match prop:
		"sign":
			return ["sign", {"raise": 1.0}]
		"banner":
			return ["banner", {}]
		"flare":
			return ["flare_up", {}] if flare else ["fist", {"k": 1.0}]
		"megaphone":
			return ["mega_low", {}]
		"mortar":
			return ["mortar_carry", {}]
	return ["cheer", {"open": _rng.randf() < 0.5}]


func busy() -> bool:
	return state in ["rally", "feed", "mortar", "panic", "dodge"]


## Réaction courte : pose, durée, point regardé, options {voice, loud, hop, face, run_to}
func react(pose: String, dur: float, look_at_p: Vector3, opt := {}) -> bool:
	opt = opt.duplicate()
	if busy() and not opt.get("force", false):
		return false
	if prop != "" and pose in ["cheer", "fist", "clap", "head", "wave", "refuse", "film", "phone", "point", "cup"]:
		if prop in ["banner", "megaphone", "mortar"] or (prop == "sign") or (prop == "flare" and flare != null):
			var pc := _prop_cheer_pose()
			if pose in ["cheer", "fist", "clap", "wave", "point", "cup"]:
				pose = pc[0]
				opt["prm"] = pc[1]
			else:
				pose = _prop_rest_pose()
				opt["prm"] = {}
	state = "react"
	state_t = 0.0
	data = {"dur": dur, "look": look_at_p}
	set_act(pose, opt.get("prm", {}), 4.0)
	look(look_at_p, 1.0)
	jaw_extra = 0.0
	if opt.get("face", true) and not has_goal and prop != "banner":
		face(look_at_p)
	if opt.has("voice") and _rng.randf() < float(opt.get("voice_p", 1.0)):
		var delay: float = opt.get("delay", _rng.randf_range(0.05, 0.5))
		var cat: String = opt["voice"]
		var loud: bool = opt.get("loud", true)
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(self):
				say_cat(cat, loud))
	if opt.get("hop", false):
		hop(int(opt.get("hops", 2)))
	react_cd = dur + _rng.randf_range(1.0, 3.0)
	return true


func go_home() -> void:
	state = "home"
	state_t = 0.0
	sub = ""
	data = {}
	fire_ok = false
	_home_sub = ""
	_home_t = 0.0
	stone_vis.visible = false
	set_act(_prop_rest_pose(), {}, 2.5)
	_look_want = 0.0


func _think(delta: float) -> void:
	match state:
		"home":
			_think_home(delta)
		"react":
			if state_t > float(data.get("dur", 2.0)):
				go_home()
			else:
				look(data.get("look", look_p), 1.0)
		"dodge":
			_think_dodge(delta)
		"panic":
			_think_panic(delta)
		"watch":
			_think_watch(delta)
		"feed":
			_think_feed(delta)
		"rally":
			_think_rally(delta)
		"mortar":
			_think_mortar(delta)
		"goto_look":
			if not has_goal or state_t > 12.0:
				react("film" if _rng.randf() < 0.5 else _idle_pose, _rng.randf_range(4.0, 8.0), data.get("look", global_position))


# ------------------------------------------------------------------- activité de fond
func _think_home(delta: float) -> void:
	_home_t += delta
	# coup d'œil au joueur quand il passe tout près
	if crowd and _glance_cd <= 0.0:
		var pp := crowd.player_pos()
		var d := pp.distance_to(global_position)
		if d < 4.5 and forward().dot((pp - global_position).normalized()) > -0.2:
			look(pp + Vector3.UP * 1.6, 1.0)
			_look_cd = _rng.randf_range(1.5, 3.0)
			_glance_cd = _rng.randf_range(6.0, 12.0)
	match role:
		"march":
			_home_march(delta)
		"chat":
			_home_chat(delta)
		_:
			_home_loner(delta)
	_home_props(delta)


func _home_props(delta: float) -> void:
	# fumigène : l'allumer, puis le brandir
	if prop == "flare":
		if flare == null:
			_flare_cd -= delta
			if _flare_cd <= 0.0 and crowd and crowd.flare_budget_ok():
				_new_flare()
				_home_sub = "flare_light"
				_home_t = 0.0
				set_act("flare_light", {}, 4.0)
		elif not flare.lit and not flare.spent:
			if _home_sub != "flare_light":
				_flare_cd -= delta
				if _flare_cd <= 0.0 and crowd and crowd.flare_budget_ok():
					_home_sub = "flare_light"
					_home_t = 0.0
					set_act("flare_light", {}, 4.0)
			elif _home_t > 0.95:
				flare.ignite()
				_home_sub = ""
				if _rng.randf() < 0.6:
					say_cat("ouais", true)
	# mortier : un tir vers le ciel de temps en temps
	if prop == "mortar":
		_mortar_cd -= delta
		if _mortar_cd <= 0.0 and crowd and crowd.mortar_ok(self):
			_start_mortar()
	# cigarette : bouffée toutes les ~9 s (la braise rougit), fumée recrachée
	if smoker and cig:
		_cig_t += delta
		var cyc := fmod(_cig_t, 9.0)
		var drag := act == "smoke_drag" and cyc < 1.4
		(cig.get_node("Ember") as MeshInstance3D).scale = Vector3.ONE * (1.7 if drag else 1.0)
		_cig_smoke.emitting = true
		_cig_smoke.amount_ratio = 1.0 if cyc > 1.8 and cyc < 3.4 else 0.2


func _home_march(delta: float) -> void:
	if crowd == null:
		return
	var tgt: Array = crowd.march_target(self)
	var p: Vector3 = tgt[0]
	var fdir: Vector3 = tgt[1]
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	var cs: float = crowd.cortege_speed
	if d > 3.5:
		go(p, true, 0.4)
	elif d > 0.2 or cs > 0.05:
		follow(p, clampf(cs + d * 0.9, 0.0, RUN * 0.8))
	face(global_position + fdir * 5.0)
	if prop == "megaphone" and crowd.cortege_speed < 0.05:
		face(crowd.cortege_center())
	# haut du corps selon le chant
	var chanting: bool = crowd.chanting
	var beat: float = crowd.beat_pulse(idx)
	if _home_sub == "flare_light":
		return
	match prop:
		"sign":
			set_act("sign", {"raise": clampf(0.35 + beat * 0.65, 0.0, 1.0) if chanting else 0.0}, 3.0)
		"banner":
			set_act("banner", {}, 2.0)
		"flare":
			if flare and flare.lit:
				set_act("flare_up" if chanting or fmod(_home_t, 14.0) < 8.0 else "flare_low", {}, 2.0)
			else:
				set_act("flare_low" if flare else _idle_pose, {}, 2.0)
		"megaphone":
			if crowd.leader_speaking:
				set_act("megaphone", {}, 4.0)
			else:
				set_act("mega_low", {}, 2.0)
		_:
			if chanting:
				if idx % 3 == 0:
					set_act("clap", {"gap": 0.02 + 0.2 * (1.0 - beat)}, 4.0)
				elif idx % 3 == 1:
					set_act("fist", {"k": beat}, 4.0)
				else:
					set_act("fist", {"k": beat * 0.8, "left": "akimbo"}, 4.0)
			else:
				_home_idle_cycle(delta, true)
	if chanting and prop != "megaphone":
		jaw_extra = crowd.chant_jaw(idx)
		look(crowd.cortege_center() + Vector3.UP * 2.0 + fdir * 6.0, 0.4)
	else:
		jaw_extra = 0.0
	# coup de sifflet de temps en temps
	_whistle_cd -= delta
	if _whistle_cd <= 0.0 and prop == "" and not chanting:
		_whistle_cd = _rng.randf_range(25.0, 60.0)
		if crowd.near_listener(global_position, 40.0):
			set_act("whistle", {}, 5.0)
			get_tree().create_timer(0.35).timeout.connect(func():
				if is_instance_valid(self):
					AudioLib.play_at(self, "whistle_%d" % (_rng.randi() % 3), head_pos(), 0.0, 9.0))
			_home_sub = "whistle"
			_home_t = 0.0


## Petites occupations quand on n'a rien de particulier à faire
func _home_idle_cycle(delta: float, marching := false) -> void:
	if _home_sub == "whistle":
		if _home_t > 1.4:
			_home_sub = ""
		return
	if prop != "":
		# la main droite tient déjà quelque chose : pas de téléphone
		set_act(_prop_rest_pose(), {}, 2.0)
		if _look_cd <= 0.0:
			_look_cd = _rng.randf_range(2.5, 6.0)
			if crowd:
				look(crowd.interest_point(self), _rng.randf_range(0.5, 1.0))
		return
	if _home_sub == "" or _home_t > _home_dur:
		_home_t = 0.0
		var r := _rng.randf()
		if r < 0.28:
			_home_sub = "phone"
			_home_dur = _rng.randf_range(6.0, 16.0)
			Props.set_phone_screen(phone, "feed")
		elif r < 0.36 and not marching:
			_home_sub = "call"
			_home_dur = _rng.randf_range(8.0, 14.0)
		elif r < 0.44 and not marching and smoker:
			_home_sub = "smoke"
			_home_dur = _rng.randf_range(10.0, 20.0)
		elif r < 0.5 and not marching:
			_home_sub = "film"
			_home_dur = _rng.randf_range(5.0, 10.0)
			Props.set_phone_screen(phone, "cam")
		else:
			_home_sub = "stand"
			_idle_pose = _pick_idle()
			_home_dur = _rng.randf_range(6.0, 15.0)
	match _home_sub:
		"phone":
			set_act("phone", {"two": idx % 2 == 0}, 2.5)
			look(phone.global_position if phone.visible else _bw(Vector3(0.05, 1.2, 0.4)), 0.9)
		"call":
			set_act("call", {}, 2.5)
			if not speaking() and _rng.randf() < delta * 0.5:
				say(AudioLib.pick(voice, "talk" if _rng.randf() < 0.6 else "reply"), false, -3.0)
			look(_bw(Vector3(-1.5, 1.3, 4.0)), 0.5)
		"smoke":
			pass
		"film":
			var tgt := crowd.interest_point(self) if crowd else _bw(Vector3(0, 1.5, 8))
			set_act("film", {"dir": _wbd(tgt - head_pos()).normalized()}, 2.5)
			face(tgt)
			look(tgt, 0.7)
		_:
			set_act(_prop_rest_pose(), {}, 2.0)
			if _look_cd <= 0.0:
				_look_cd = _rng.randf_range(2.5, 6.0)
				if crowd and _rng.randf() < 0.7:
					look(crowd.interest_point(self), _rng.randf_range(0.5, 1.0))
				else:
					_look_want = 0.0


func _home_chat(delta: float) -> void:
	if crowd == null:
		return
	var spot: Array = crowd.chat_spot(self)
	var p: Vector3 = spot[0]
	var center: Vector3 = spot[1]
	if Vector2(p.x - global_position.x, p.z - global_position.z).length() > 0.5 and not has_goal:
		go(p, false, 0.3)
	if not has_goal:
		face(center)
	var spk: Npc = crowd.chat_speaker(group)
	if speaking():
		set_act("talk", {"two": idx % 2 == 1}, 2.5)
		var other: Npc = crowd.chat_listener_target(self)
		if other:
			look(other.head_pos(), 1.0)
	else:
		if spk and spk != self:
			look(spk.head_pos(), 1.0)
			if _rng.randf() < delta * 0.25:
				human.nod = 1.0
				get_tree().create_timer(0.9).timeout.connect(func():
					if is_instance_valid(self):
						human.nod = 0.0)
		if smoker:
			set_act(_prop_rest_pose(), {}, 2.5)
		else:
			if _home_sub == "" or _home_t > _home_dur:
				_home_t = 0.0
				_home_dur = _rng.randf_range(8.0, 18.0)
				_home_sub = "phone" if _rng.randf() < 0.2 else "stand"
				_idle_pose = _pick_idle()
			if _home_sub == "phone" and (spk == null or spk == self):
				set_act("phone", {}, 2.5)
				look(phone.global_position if phone.visible else _bw(Vector3(0.05, 1.2, 0.4)), 0.9)
			else:
				set_act(_idle_pose, {}, 2.0)


func _home_loner(delta: float) -> void:
	if crowd == null:
		return
	# se balade dans sa zone de temps en temps
	if not has_goal and _rng.randf() < delta * (0.03 if role == "bloc" else 0.05):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(1.0, 7.0 if role == "loner" else 4.0)
		go(crowd.clamp_area(home_pos + Vector3(cos(a), 0, sin(a)) * r), false, 0.4)
		_home_sub = "stand"
		_home_t = 0.0
		_home_dur = _rng.randf_range(4.0, 8.0)
	if prop == "mortar":
		set_act("mortar_carry", {}, 2.0)
		if _look_cd <= 0.0:
			_look_cd = _rng.randf_range(2.5, 6.0)
			look(crowd.interest_point(self), 0.8)
		return
	if prop == "flare" and flare and flare.lit:
		set_act("flare_up" if fmod(_home_t, 10.0) < 5.0 else "flare_low", {}, 2.0)
		return
	if _home_sub == "flare_light":
		return
	_home_idle_cycle(delta)


# ------------------------------------------------------------------- esquive / panique
func dodge(from: Vector3, dir: Vector3) -> void:
	if busy():
		return
	var to := global_position - from
	var side := dir.cross(Vector3.UP).normalized()
	if to.dot(side) < 0.0:
		side = -side
	var target := global_position + side * _rng.randf_range(2.5, 4.0) + dir.normalized() * _rng.randf_range(-0.5, 0.5)
	state = "dodge"
	state_t = 0.0
	data = {"from": from}
	stop_move()
	go(crowd.clamp_area(target) if crowd else target, true, 0.5)
	set_act("cover" if calm < 0.4 else "refuse", {}, 5.0)
	look(from + Vector3.UP * 1.5, 1.0)
	if _rng.randf() < 0.5:
		say_cat("warn", true)


func _think_dodge(_delta: float) -> void:
	var from: Vector3 = data.get("from", global_position)
	look(from + Vector3.UP * 1.5, 1.0)
	if not has_goal or state_t > 4.0:
		state = "react"
		state_t = 0.0
		data = {"dur": _rng.randf_range(2.0, 4.0), "look": from + Vector3.UP * 1.5}
		face(from)
		set_act("refuse" if bold < 0.6 else "crossed", {}, 3.0)


func panic(from: Vector3, strength := 1.0) -> void:
	if state == "panic" or state == "mortar":
		return
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
	var target := global_position + away.normalized() * _rng.randf_range(5.0, 9.0) * strength
	_drop_item()
	state = "panic"
	state_t = 0.0
	data = {"from": from}
	go(crowd.clamp_area(target) if crowd else target, true, 0.6)
	set_act("cover", {}, 6.0)
	if _rng.randf() < 0.35:
		say_cat("warn", true)


func _think_panic(_delta: float) -> void:
	var from: Vector3 = data.get("from", global_position)
	human.crouch = lerpf(human.crouch, 0.0, 0.1)
	if not has_goal or state_t > 5.0:
		state = "react"
		state_t = 0.0
		data = {"dur": _rng.randf_range(2.5, 4.5), "look": from + Vector3.UP * 1.0}
		face(from)
		set_act("head" if _rng.randf() < 0.5 else _idle_pose, {}, 3.0)


func startle(from: Vector3) -> void:
	# sursaut : petit recul + regard
	if busy():
		return
	look(from, 1.0)
	human.kick_back(0.6)
	react(_idle_pose if prop == "" else _prop_rest_pose(), 1.5, from, {"face": true})


# ------------------------------------------------------------------- feu : regarder / alimenter
func watch_fire(bin: TrashBin, ring: Vector3) -> void:
	if busy() and state != "watch":
		return
	state = "watch"
	state_t = 0.0
	data = {"bin": bin, "ring": ring, "next": 0.0}
	go(ring, false, 0.35)
	if _rng.randf() < 0.35:
		say_cat("fire", true)


func _think_watch(delta: float) -> void:
	var bin: TrashBin = data.get("bin")
	if bin == null or not is_instance_valid(bin):
		go_home()
		return
	var fc := bin.fire_center()
	if not bin.burning:
		data["out_t"] = float(data.get("out_t", 0.0)) + delta
		if float(data["out_t"]) > 3.5:
			go_home()
			return
	if state_t > float(data.get("max", 60.0 + curious * 90.0)):
		go_home()
		return
	var ring: Vector3 = crowd.ring_point(self, bin)
	if not has_goal and Vector2(ring.x - global_position.x, ring.z - global_position.z).length() > 0.8:
		go(ring, false, 0.35)
	if not has_goal:
		face(fc)
	look(fc, 1.0)
	data["next"] = float(data.get("next", 0.0)) - delta
	if float(data["next"]) <= 0.0:
		data["next"] = _rng.randf_range(4.0, 9.0)
		var r := _rng.randf()
		var close := global_position.distance_to(bin.global_position) < 2.6
		if prop != "":
			set_act(_prop_cheer_pose()[0] if _rng.randf() < 0.4 else _prop_rest_pose(), _prop_cheer_pose()[1] if _rng.randf() < 0.4 else {}, 2.5)
		elif r < 0.32:
			Props.set_phone_screen(phone, "cam")
			set_act("film", {"dir": _wbd(fc - head_pos()).normalized()}, 2.5)
			if _rng.randf() < 0.3 and crowd.near_listener(global_position, 12.0):
				AudioLib.play_at(self, "phone_shutter", phone.global_position, -16.0, 2.0)
		elif r < 0.45:
			set_act("head", {}, 2.5)
			if _rng.randf() < 0.4:
				say_cat("wow", true)
		elif r < 0.6 and close and bin.heat < 1.0:
			set_act("warm", {"rub": float(_rng.randf() < 0.5)}, 2.0)
		elif r < 0.75:
			set_act(_pick_idle(), {}, 2.0)
		elif r < 0.85:
			set_act("phone", {}, 2.0)
		else:
			set_act("point", {"dir": _wbd(fc - human.shoulder_world("R")).normalized()}, 3.0)
			if _rng.randf() < 0.5:
				say_cat("fire", true)
	if act == "film":
		prm = {"dir": _wbd(fc - head_pos()).normalized()}


func feed_fire(bin: TrashBin) -> void:
	if busy():
		return
	state = "feed"
	state_t = 0.0
	sub = "find"
	sub_t = 0.0
	data = {"bin": bin}
	fire_ok = true


func _think_feed(delta: float) -> void:
	sub_t += delta
	var bin: TrashBin = data.get("bin")
	if bin == null or not is_instance_valid(bin) or state_t > 45.0:
		_drop_item()
		go_home()
		return
	match sub:
		"find":
			var it: Burnable = crowd.reserve_burnable(self, bin.global_position, 18.0)
			if it:
				data["item"] = it
				var ip := it.global_position
				var away := (global_position - ip)
				away.y = 0
				go(ip + away.normalized() * 0.45, false, 0.25)
				sub = "goto_item"
			else:
				# pas de déchet à portée : un journal sorti de la poche
				var b := Burnable.make("paper")
				b.held = true
				add_child(b)
				b.top_level = true
				item = b
				sub = "goto_bin"
				go(_bin_spot(bin), false, 0.3)
			sub_t = 0.0
		"goto_item":
			var it2: Burnable = data.get("item")
			if it2 == null or not is_instance_valid(it2) or it2.in_bin != null or it2.held:
				sub = "find"
				return
			face(it2.global_position)
			if not has_goal or sub_t > 12.0:
				sub = "pick"
				sub_t = 0.0
				stop_move()
		"pick":
			var it3: Burnable = data.get("item")
			if it3 == null or not is_instance_valid(it3):
				sub = "find"
				human.crouch = 0.0
				return
			face(it3.global_position)
			human.crouch = lerpf(human.crouch, 0.85, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.25, minf(1.0, delta * 5.0))
			set_act("pick", {"target": _wb(it3.global_position)}, 3.0)
			look(it3.global_position, 1.0)
			if sub_t > 0.9:
				it3.set_held(true)
				it3.reparent(self, true)
				item = it3
				sub = "goto_bin"
				sub_t = 0.0
				go(_bin_spot(bin), false, 0.3)
		"goto_bin":
			human.crouch = lerpf(human.crouch, 0.0, minf(1.0, delta * 4.0))
			human.lean_extra = lerpf(human.lean_extra, 0.0, minf(1.0, delta * 4.0))
			var it4 := item as Burnable
			if it4 and it4.kind != "paper":
				set_act("carry", {"w": maxf(it4.size.x, 0.3) if it4.kind == "box" else 0.25}, 3.0)
			else:
				set_act("stone", {}, 3.0)
			if bin.burning:
				look(bin.fire_center(), 0.8)
			if not has_goal:
				if Vector2(bin.global_position.x - global_position.x, bin.global_position.z - global_position.z).length() > 1.8:
					go(_bin_spot(bin), false, 0.3)
				else:
					face(bin.global_position)
					if not bin.is_open() and bin.burning:
						# quelqu'un a étouffé le feu : on n'insiste pas, on pose le carton
						_drop_item()
						watch_fire(bin, crowd.ring_point(self, bin))
						fire_ok = false
						return
					sub = "open" if not bin.is_open() else "throw"
					sub_t = 0.0
		"open":
			face(bin.global_position)
			set_act("reach", {"target": _wb(bin.top_center() + forward() * -0.3 + Vector3.UP * 0.05)}, 4.0)
			if sub_t > 0.6:
				bin.set_lid(true)
				sub = "throw"
				sub_t = 0.0
		"throw":
			face(bin.global_position)
			var two := item != null and (item as Burnable) != null and (item as Burnable).kind != "paper"
			var dir := _wbd(bin.top_center() - human.shoulder_world("R")).normalized()
			set_act("toss2" if two else "throw", {"dir": dir, "w": 0.36}, 6.0)
			if sub_t > (0.55 if two else 0.48) and item != null:
				_release_item_into(bin)
			if sub_t > 1.2:
				sub = "after"
				sub_t = 0.0
				if _rng.randf() < 0.6:
					say_cat("fire" if _rng.randf() < 0.6 else "ouais", true)
		"after":
			look(bin.fire_center(), 1.0)
			var pc := _prop_cheer_pose()
			set_act(pc[0], pc[1], 3.0)
			if sub_t > 1.5:
				if _rng.randf() < 0.4 + bold * 0.3 and bin.burning:
					sub = "find"
				else:
					watch_fire(bin, crowd.ring_point(self, bin))
					fire_ok = false


func _bin_spot(bin: TrashBin) -> Vector3:
	var d := global_position - bin.global_position
	d.y = 0
	if d.length() < 0.1:
		d = Vector3(1, 0, 0)
	return bin.global_position + d.normalized() * 1.15


func _release_item_into(bin: TrashBin) -> void:
	if item == null or not is_instance_valid(item):
		item = null
		return
	var it := item as Burnable
	item = null
	var target := bin.top_center() + Vector3.UP * 0.05
	var origin := it.global_position
	it.reparent(get_tree().current_scene, true)
	it.reserved_by = null
	it.set_held(false)
	it.linear_velocity = _ballistic(origin, target, 4.2)
	it.angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
	AudioLib.play_at(self, "toss", origin, -12.0, 4.0)


func _drop_item() -> void:
	human.crouch = 0.0
	human.lean_extra = 0.0
	if item and is_instance_valid(item):
		var it := item as Burnable
		item = null
		if it:
			it.reparent(get_tree().current_scene, true)
			it.reserved_by = null
			it.set_held(false)
			it.linear_velocity = vel + Vector3.UP
	item = null
	if data.has("item"):
		var r: Variant = data["item"]
		if r is Burnable and is_instance_valid(r) and (r as Burnable).reserved_by == self:
			(r as Burnable).reserved_by = null


## Vitesse initiale pour atteindre `target` (tir tendu, vitesse ~v, sinon arc)
func _ballistic(origin: Vector3, target: Vector3, v: float) -> Vector3:
	var d := Vector3(target.x - origin.x, 0, target.z - origin.z)
	var dist := maxf(d.length(), 0.3)
	var h := target.y - origin.y
	var g := 9.8
	var disc := v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	while disc < 0.0 and v < 30.0:
		v += 1.0
		disc = v * v * v * v - g * (g * dist * dist + 2.0 * h * v * v)
	var tan_t := (v * v - sqrt(maxf(disc, 0.0))) / (g * dist)
	# pour jeter DANS la poubelle on préfère une cloche (arc haut)
	if dist < 3.0:
		tan_t = (v * v + sqrt(maxf(disc, 0.0))) / (g * dist)
	var ang := atan(tan_t)
	return (d.normalized() * cos(ang) + Vector3.UP * sin(ang)) * v


# ------------------------------------------------------------------- casser l'abribus
func rally(bus: BusStop) -> void:
	_drop_item()
	state = "rally"
	state_t = 0.0
	sub = "pick_slot"
	sub_t = 0.0
	data = {"bus": bus, "hits": 0}


func _think_rally(delta: float) -> void:
	sub_t += delta
	var bus: BusStop = data.get("bus")
	if bus == null or not crowd.rally_active:
		_end_rally()
		return
	match sub:
		"pick_slot":
			var s: Dictionary = crowd.attack_slot(self)
			if s.is_empty():
				_end_rally(true)
				return
			data["slot"] = s
			go(s["pos"], true, 0.3)
			sub = "go"
			sub_t = 0.0
		"go":
			var s2: Dictionary = data["slot"]
			look(s2["target"], 0.8)
			if not bus.pane_alive(s2["pane"]):
				crowd.free_slot(self)
				sub = "pick_slot"
				return
			if not has_goal or sub_t > 14.0:
				stop_move()
				face(s2["face"])
				sub = "kick" if s2["kind"] == "kick" else "stone_pick"
				sub_t = -_rng.randf_range(0.2, 0.8)
		"kick":
			var s3: Dictionary = data["slot"]
			face(s3["face"])
			look(s3["target"], 1.0)
			set_act(_idle_pose if prop == "" else _prop_rest_pose(), {}, 2.0)
			if not bus.pane_alive(s3["pane"]):
				_on_pane_broken()
				return
			if sub_t > 0.0 and human.kick_t < 0.0 and absf(wrapf(_yaw_to(s3["face"]) - yaw, -PI, PI)) < 0.25:
				human.start_kick()
				sub_t = -_rng.randf_range(2.4, 4.4)
				if _rng.randf() < 0.45:
					say_cat("ouais" if _rng.randf() < 0.5 else "allez", true)
		"stone_pick":
			var s4: Dictionary = data["slot"]
			if not bus.pane_alive(s4["pane"]):
				_on_pane_broken()
				return
			if sub_t < 0.0:
				return
			face(s4["face"])
			human.crouch = lerpf(human.crouch, 0.8, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.25, minf(1.0, delta * 5.0))
			set_act("pick", {"target": Vector3(0.18, 0.05, 0.45)}, 3.0)
			if sub_t > 0.75:
				stone_vis.visible = true
				sub = "stone_throw"
				sub_t = 0.0
		"stone_throw":
			human.crouch = lerpf(human.crouch, 0.0, minf(1.0, delta * 5.0))
			human.lean_extra = lerpf(human.lean_extra, 0.0, minf(1.0, delta * 5.0))
			var s5: Dictionary = data["slot"]
			face(s5["face"])
			look(s5["target"], 1.0)
			var dir := _wbd(s5["target"] - human.shoulder_world("R")).normalized()
			if sub_t < 0.45:
				set_act("stone", {}, 4.0)
			else:
				set_act("throw", {"dir": dir}, 8.0)
				if act_t > 0.48 and stone_vis.visible:
					_throw_stone(s5["target"])
			if sub_t > 1.6:
				sub = "stone_pick"
				sub_t = -_rng.randf_range(1.6, 3.4)
				if _rng.randf() < 0.4:
					say_cat("allez" if _rng.randf() < 0.5 else "ouais", true)
		"celebrate":
			if sub_t > 3.5:
				_end_rally()


func _yaw_to(p: Vector3) -> float:
	var d := p - global_position
	return atan2(-d.x, -d.z)


func _on_pane_broken() -> void:
	crowd.free_slot(self)
	human.crouch = 0.0
	human.lean_extra = 0.0
	stone_vis.visible = false
	sub = "pick_slot"
	sub_t = 0.0


func _end_rally(celebrate := false) -> void:
	crowd.free_slot(self)
	human.crouch = 0.0
	human.lean_extra = 0.0
	stone_vis.visible = false
	if celebrate and sub != "celebrate":
		sub = "celebrate"
		sub_t = 0.0
		var pc := _prop_cheer_pose()
		set_act(pc[0], pc[1], 4.0)
		hop(3)
		say_cat("broke", true)
		return
	go_home()


func _throw_stone(target: Vector3) -> void:
	stone_vis.visible = false
	var origin := stone_vis.global_position
	var err := Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.35, 0.4), _rng.randf_range(-0.45, 0.45))
	var s := Stone.new()
	get_tree().current_scene.add_child(s)
	s.setup(_rng.randi(), _rng.randf_range(0.04, 0.055))
	s.collision_mask = 1
	s.global_position = origin
	s.linear_velocity = _ballistic(origin, target + err, 13.0)
	s.angular_velocity = Vector3(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10), _rng.randf_range(-10, 10))
	AudioLib.play_at(self, "sfx:throw", origin, -8.0, 5.0)
	get_tree().create_timer(40.0).timeout.connect(func():
		if is_instance_valid(s):
			s.queue_free())


func _on_kick_impact(point: Vector3) -> void:
	var fwd := forward()
	var bus: BusStop = data.get("bus") if state == "rally" else null
	if bus:
		bus.kick(point + fwd * 0.12, fwd, 0.55)


## Touché par une pierre du joueur
func on_stone_hit(from_dir: Vector3) -> void:
	human.kick_back(0.8)
	if state in ["mortar"]:
		return
	var src := global_position - from_dir.normalized() * 6.0
	if crowd:
		src = crowd.player_pos()
	react("refuse", 2.5, src + Vector3.UP * 1.6, {"voice": "warn", "force": true})


# ------------------------------------------------------------------- tir de mortier (PNJ)
func _start_mortar() -> void:
	state = "mortar"
	state_t = 0.0
	sub = "light"
	sub_t = 0.0
	stop_move()
	var away: Vector3 = crowd.safe_sky_dir(self)
	face(global_position + Vector3(away.x, 0, away.z) * 4.0)
	data = {"dir": away}
	set_act("mortar_light", {}, 3.0)


func _think_mortar(delta: float) -> void:
	sub_t += delta
	var dir: Vector3 = data.get("dir", Vector3.UP)
	var hdir := Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else -global_basis.z
	var axis_b := _wbd((hdir * 0.55 + Vector3.UP).normalized())   # ~60° au-dessus de l'horizon, loin de la foule
	match sub:
		"light":
			data["axis_w"] = _bd(Vector3(0, 0.84, 0.54))
			if lighter:
				Props.set_lighter_lit(lighter, sub_t > 0.6 and sub_t < 1.6, state_t)
			look(mortar_m.global_position + data["axis_w"] * 0.3, 1.0)
			if sub_t > 1.25:
				_fuse_fx.emitting = true
			if sub_t > 1.7:
				sub = "aim"
				sub_t = 0.0
				set_act("mortar_aim", {"axis": axis_b}, 3.5)
				AudioLib.play_at(self, "sfx:hiss", mortar_m.global_position, -12.0, 5.0)
		"aim":
			data["axis_w"] = (data["axis_w"] as Vector3).slerp(_bd(axis_b), minf(1.0, delta * 4.0))
			_fuse_light.light_energy = 0.8 + randf() * 0.6
			look(mortar_m.global_position + (data["axis_w"] as Vector3) * 3.0, 0.8)
			if sub_t > 1.1:
				_mortar_launch(data["axis_w"])
				sub = "recoil"
				sub_t = 0.0
		"recoil":
			_fuse_light.light_energy = 0.0
			look(global_position + Vector3.UP * 30.0 + forward() * 10.0, 1.0)
			if sub_t > 0.9:
				set_act("mortar_carry", {}, 2.0)
				data["axis_w"] = (data["axis_w"] as Vector3).slerp(_bd(Vector3(0, 0.71, 0.70)), minf(1.0, delta * 3.0))
			if sub_t > 3.5:
				data.erase("axis_w")
				_mortar_cd = _rng.randf_range(40.0, 80.0)
				go_home()


func _mortar_launch(axis: Vector3) -> void:
	_fuse_fx.emitting = false
	var scene := get_tree().current_scene
	var mouth := mortar_m.global_position + axis * MortarModel.TUBE_LEN
	var s := FireworkShell.new()
	scene.add_child(s)
	s.global_position = mouth
	s.velocity = (axis + Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))).normalized() * 34.0
	Fx.muzzle(scene, mouth, axis)
	AudioLib.play_at(self, "sfx:thump", mouth, 4.0, 30.0)
	human.kick_back(1.0)
	if _rng.randf() < 0.5:
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(self):
				say_cat("ouais", true))
	if crowd:
		crowd.on_event("mortar_fire", {"pos": mouth, "dir": axis, "npc": self})
