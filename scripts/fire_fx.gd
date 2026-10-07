class_name FireFx
extends Node3D
## Effets d'un foyer : deux couches de flammes (atlas animé), braises, fumée noire, fumée blanche
## d'étouffement, lueur vacillante avec ombres et crépitement. Utilisé par les poubelles, les feux au sol
## et les voitures qui brûlent. L'intensité `h` va de 0 à ~1,6.

var extent := Vector3(0.17, 0.03, 0.22)
var flame_size := 0.42
var smoke_size := 0.55
var smoke_rise := 1.5
var smoke_amount := 46
var light_range := 6.0
var light_energy := 4.2
var light_y := 0.55
var shadows := true
var sound_unit := 5.0
var sound_gain := 0.0
var flame_rise := 1.1

var _a: GPUParticles3D
var _b: GPUParticles3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _smoulder: GPUParticles3D
var _light: OmniLight3D
var _snd: AudioStreamPlayer3D
var _seed := 0.0
var _on := false
var _last_hv := -1.0
static var _shadow_lights := 0


func _ready() -> void:
	_seed = randf() * 100.0
	_a = Fx.fire(flame_size, 36, extent, flame_rise)
	add_child(_a)
	_b = Fx.fire(flame_size * 0.66, 30, extent * Vector3(1.15, 1.6, 1.15), flame_rise * 1.45)
	_b.lifetime = 1.1
	add_child(_b)
	_embers = Fx.embers(40, extent)
	add_child(_embers)
	_smoke = Fx.smoke(Color(0.1, 0.1, 0.105, 0.5), smoke_amount, 7.0, smoke_size, true, smoke_rise, 6.0)
	_smoke.position.y = light_y
	add_child(_smoke)
	_smoulder = Fx.smoke(Color(0.55, 0.55, 0.56, 0.35), 20, 5.0, smoke_size * 0.65, true, 0.6, 5.0)
	_smoulder.position.y = light_y * 0.5
	add_child(_smoulder)
	for p in [_a, _b, _embers, _smoke, _smoulder]:
		(p as GPUParticles3D).emitting = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.2)
	_light.light_energy = 0.0
	_light.omni_range = light_range
	_light.omni_attenuation = 1.15
	if shadows and _shadow_lights < 3:
		_light.shadow_enabled = true
		_light.shadow_bias = 0.08
		_shadow_lights += 1
	_light.position = Vector3(0, light_y, 0)
	add_child(_light)
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = AudioLib.stream("fire_loop", true)
	_snd.unit_size = sound_unit
	_snd.volume_db = -60.0
	add_child(_snd)


func _exit_tree() -> void:
	if _light and _light.shadow_enabled:
		_shadow_lights = maxi(_shadow_lights - 1, 0)


func set_extent(e: Vector3) -> void:
	extent = e
	for p in [_a, _b, _embers]:
		((p as GPUParticles3D).process_material as ParticleProcessMaterial).emission_box_extents = e


func start() -> void:
	if _on:
		return
	_on = true
	for p in [_a, _b, _embers, _smoke]:
		(p as GPUParticles3D).emitting = true
	_snd.play(randf() * 6.0)


func stop(keep_smoke := true) -> void:
	_on = false
	for p in [_a, _b, _embers]:
		(p as GPUParticles3D).emitting = false
	if not keep_smoke:
		_smoke.emitting = false


func is_on() -> bool:
	return _on


## h : intensité totale (chaleur + à-coup) ; flames : visibilité des flammes (0 = couvercle fermé)
func update(h: float, flames := 1.0, smoke_on := true, smoulder := 0.0) -> void:
	var hv := clampf(h / 1.6, 0.0, 1.0)
	_a.amount_ratio = clampf(h * 1.1, 0.0, 1.0) * flames
	_b.amount_ratio = clampf((h - 0.35) * 1.2, 0.0, 1.0) * flames
	var q := roundf(hv * 8.0) / 8.0
	if absf(q - _last_hv) > 0.01:
		_last_hv = q
		var pa := _a.process_material as ParticleProcessMaterial
		pa.scale_min = 0.55 + 0.6 * q
		pa.scale_max = 1.0 + 0.9 * q
		var kh := 0.35 + 0.95 * q       # petit feu : flammes basses
		pa.initial_velocity_min = 0.35 * flame_rise * kh
		pa.initial_velocity_max = 0.9 * flame_rise * kh
		pa.gravity = Vector3(0, 1.8 * flame_rise * kh, 0)
		var pb := _b.process_material as ParticleProcessMaterial
		pb.initial_velocity_max = (0.5 + 1.8 * q) * flame_rise
	_embers.amount_ratio = clampf(h, 0.0, 1.0) * flames
	_smoke.amount_ratio = clampf(0.25 + h * 0.8, 0.0, 1.0) if smoke_on else 0.0
	_smoke.emitting = smoke_on and (_on or h > 0.02)
	var t := Time.get_ticks_msec() / 1000.0
	_light.light_energy = light_energy * h * Fx.flicker(t, _seed)
	_light.omni_range = light_range * (0.65 + 0.5 * hv)
	if _on:
		_snd.volume_db = linear_to_db(clampf(h * 0.9, 0.001, 1.0)) - 2.0 + sound_gain
	elif _snd.playing and h <= 0.01:
		_snd.stop()
	_smoulder.emitting = smoulder > 0.01
	_smoulder.amount_ratio = clampf(smoulder, 0.1, 1.0)


func ignite_burst(boost_sound := true) -> void:
	if boost_sound:
		AudioLib.play_at(self, "fire_ignite", global_position, 2.0, 8.0)
	_embers.restart()


func flare_up_burst(vol := 0.0) -> void:
	AudioLib.play_at(self, "fire_flare_up", global_position, vol, 7.0, randf_range(0.9, 1.1))
	_embers.restart()
