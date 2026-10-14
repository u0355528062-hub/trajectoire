class_name MegaphoneTool
extends KitTool
## Mégaphone : clic gauche = lancer un slogan (porte-voix à la bouche). La foule reprend si elle est assez
## nombreuse autour et assez motivée ; sinon, quelques voix… ou personne. Événement : megaphone {"slogan", "joined"}.

## Slogans (texte, index du cri enregistré « megaphone_i » = index du chant de la foule Crowd.CHANTS)
const SLOGANS := [["On lâche rien !", 0], ["Tous ensemble !", 1], ["La rue est à nous !", 2], ["On est là !", 3]]
const COOLDOWN := 3.5
const HEAR_R := 22.0
const CROWD_MIN := 6              # en dessous, ce n'est pas une foule : au mieux deux ou trois voix
const CHANT_MIN := 8              # assez de monde reprend : toute la foule enchaîne le chant

var _model: Node3D
var _voice: AudioStreamPlayer3D
var _t := -1.0
var _dur := 2.0
var _cd := 0.0
var _idx := -1
var _env: Array = []
var _raise := 0.0
var _rng2 := RandomNumberGenerator.new()


func _build() -> void:
	if _model == null:
		_model = Props.megaphone()
		_model.top_level = true
		add_child(_model)
		_voice = AudioStreamPlayer3D.new()
		_voice.bus = &"Voix"
		_voice.unit_size = 14.0
		_voice.max_distance = 120.0
		add_child(_voice)
		_rng2.randomize()


func _show(on: bool) -> void:
	if _model:
		_model.visible = on


func _cancel() -> void:
	_t = -1.0
	if _voice:
		_voice.stop()
	if human:
		human.jaw = 0.0


func use() -> void:
	if not equipped or equip_t < 0.5 or _t >= 0.0 or _cd > 0.0:
		return
	_idx = (_idx + 1) % SLOGANS.size()
	var snd := "megaphone_%d" % int(SLOGANS[_idx][1])
	_env = AudioLib.env(snd)
	_dur = maxf(float(_env.size()) / AudioLib.ENV_HZ, 1.2)
	_voice.stream = AudioLib.stream(snd)
	_voice.volume_db = 4.0
	_voice.play()
	_t = 0.0
	_cd = COOLDOWN


func prompt() -> Array:
	if _t >= 0.0:
		return [["…"], "« %s »" % SLOGANS[_idx][0]]
	if _cd > 0.0:
		return []
	return [["CLIC GAUCHE"], "Lancer « %s »" % SLOGANS[(_idx + 1) % SLOGANS.size()][0]]


func step(delta: float) -> void:
	super.step(delta)
	_cd = maxf(_cd - delta, 0.0)
	_raise = move_toward(_raise, 1.0 if _t >= 0.0 else 0.0, delta * 5.0)
	if _t < 0.0:
		return
	_t += delta
	human.jaw = AudioLib.env_at(_env, _t) * 0.9 if _t < _dur else 0.0
	if _t >= _dur + 0.25:
		_t = -1.0
		human.jaw = 0.0
		_crowd_answer()


## La foule reprend-elle ? Nombre de manifestants à portée de voix, et leur envie de crier
func _crowd_answer() -> void:
	var text: String = SLOGANS[_idx][0]
	var c := crowd()
	var joined := 0
	if c:
		var me := player.global_position
		var near: Array = []
		var keen: Array = []
		for n in c.npcs:
			if not is_instance_valid(n) or n.busy() or n.state == "arrested":
				continue
			if n.global_position.distance_to(me) > HEAR_R:
				continue
			near.append(n)
			var drive := c.excitement * 0.5 + n.anger * 0.3 + n.bold * 0.45 - n.fear * 0.6
			if drive > 0.38:
				keen.append(n)
		if near.size() >= CROWD_MIN:
			joined = keen.size()
		else:
			joined = mini(keen.size(), 2)
		var shown := 0
		for n in keen:
			if shown >= joined:
				break
			shown += 1
			n.react("fist" if _rng2.randf() < 0.6 else "cheer", 2.2, me + Vector3.UP * 1.6,
				{"voice": "slogan" if joined >= CHANT_MIN else "ouais", "voice_p": 0.25, "face": false, "delay": _rng2.randf_range(0.05, 0.6)})
		# assez de monde : toute la foule enchaîne sur le chant correspondant
		if joined >= CHANT_MIN and not c.chanting and c.has_method("_start_chant_track") and "_chant_idx" in c:
			c.set("_chant_police", false)
			c.set("_chant_idx", int(SLOGANS[_idx][1]))
			c.call("_start_chant_track")
	emit_event("megaphone", {"slogan": text, "joined": joined})
	if joined >= CHANT_MIN:
		say("La foule reprend : « %s »" % text)
	elif joined > 0:
		say("Quelques voix reprennent…")
	else:
		say("Personne ne reprend.")


func _mouth() -> Transform3D:
	var hs := human.hscale()
	var head_pose := human.skeleton.get_bone_global_pose(human.bone["head"])
	return human.skeleton.global_transform * head_pose * Transform3D(Basis(Vector3.RIGHT, -0.07), Vector3(0, -0.037 * hs, 0.108 * hs))


func _hand_targets() -> Array:
	if equip_t <= 0.0 or human == null:
		return [null, null]
	var w := ease01(equip_t)
	var k := human.arm_length() / 0.58
	var shr := human.shoulder_world("R")
	var grip: Vector3 = _model.get_meta("grip", Vector3(0, -0.092, 0.092)) if _model else Vector3.ZERO
	var e := ease01(_raise)
	# repos : tenu par la poignée, le long du corps, pavillon vers l'avant et le bas
	var yb := Basis(Vector3.UP, human.global_rotation.y + PI)
	var low_b := yb * Basis(Vector3.RIGHT, 0.75)
	var low_pos := shr + bdir(Vector3(0.04, -0.42, 0.22) * k)
	# levé : embout contre la bouche, pavillon dans l'axe du regard (à peine relevé)
	var cf := cam_fwd()
	cf = Vector3(cf.x, clampf(cf.y, -0.25, 0.35), cf.z).normalized()
	var bx := Vector3.UP.cross(cf).normalized()
	var up_b := Basis(bx, cf.cross(bx).normalized(), cf)
	var mouth := _mouth().origin + cf * 0.01
	var up_pos := mouth + up_b * grip
	var f := bdir(Vector3(0, 0.83, 0.55)).slerp(bdir(Vector3(0, 0.3, 1.0)), 1.0 - e)
	var r := hand(low_pos.lerp(up_pos, e), f, bdir(Vector3(-1, 0, 0)), 0.95, w)
	if _model and _model.visible:
		if e > 0.6:
			_model.global_transform = Transform3D(up_b, mouth)
		else:
			var pr := human.palm("R")
			var b := low_b.slerp(up_b, clampf(e / 0.6, 0.0, 1.0) * 0.5).orthonormalized()
			_model.global_transform = Transform3D(b, (pr["pos"] as Vector3) + (pr["p"] as Vector3) * 0.02 - b * grip)
	return [r, null]
