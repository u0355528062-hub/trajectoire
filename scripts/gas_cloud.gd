class_name GasCloud
extends Node3D
## Nuage de gaz lacrymogène : grandes volutes blanches qui s'étalent autour de la grenade (il la suit si
## on la renvoie du pied). Gêne les manifestants et le joueur ; les policiers masqués n'en souffrent pas.

const R_MAX := 6.5
const LIFE := 44.0

var host: Node3D
var crowd: Crowd
var radius := 0.9
var life := 0.0
var _smoke: GPUParticles3D
var _low: GPUParticles3D
var _hiss: AudioStreamPlayer3D
var _scan := 0.0


func _ready() -> void:
	add_to_group("gas_clouds")
	_smoke = Fx.smoke(Color(0.93, 0.94, 0.9, 0.55), 40, 13.0, 3.6, false, 0.5, 2.4)
	add_child(_smoke)
	_low = Fx.smoke(Color(0.88, 0.9, 0.86, 0.42), 24, 10.0, 2.4, false, 0.12, 2.2)
	add_child(_low)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = AudioLib.stream("gas_hiss_loop", true)
	_hiss.unit_size = 14.0
	_hiss.max_distance = 140.0
	_hiss.volume_db = -3.0
	add_child(_hiss)
	_hiss.play(randf() * 2.0)
	# les plus anciens nuages s'estompent plus vite
	var all := get_tree().get_nodes_in_group("gas_clouds")
	if all.size() > 5:
		(all[0] as GasCloud).life = maxf((all[0] as GasCloud).life, LIFE - 8.0)


func _exit_tree() -> void:
	pass


func density_at(p: Vector3) -> float:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	if d >= radius or p.y > 4.5:
		return 0.0
	var k := 1.0 - d / radius
	return clampf(pow(k, 0.7) * 1.25, 0.0, 1.0) * fade()


func fade() -> float:
	return clampf((LIFE - life) / 9.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	life += delta
	if life >= LIFE:
		queue_free()
		return
	if host != null and is_instance_valid(host):
		global_position = Vector3(host.global_position.x, 0.0, host.global_position.z)
	var u := clampf(life / 8.0, 0.0, 1.0)
	radius = lerpf(0.9, R_MAX, 1.0 - (1.0 - u) * (1.0 - u))
	var f := fade()
	var pm := _smoke.process_material as ParticleProcessMaterial
	pm.emission_sphere_radius = radius * 0.62
	(_low.process_material as ParticleProcessMaterial).emission_sphere_radius = radius * 0.75
	_smoke.position.y = 1.0 + radius * 0.12
	_low.position.y = 0.45
	_smoke.amount_ratio = clampf(0.25 + 0.75 * u, 0.0, 1.0) * f
	_low.amount_ratio = clampf(0.2 + 0.8 * u, 0.0, 1.0) * f
	_hiss.volume_db = linear_to_db(maxf(f * 0.8 + 0.01, 0.01)) - 3.0
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.12
		_expose()


func _expose() -> void:
	var pl := get_tree().get_first_node_in_group("player") as Player
	if pl != null:
		var dp := density_at(pl.global_position)
		if dp > 0.0:
			pl.apply_gas(dp)
	if crowd == null:
		return
	for a in crowd.neighbors(global_position, radius):
		var d := density_at(a.global_position)
		if d <= 0.0:
			continue
		if a is Npc:
			(a as Npc).on_gas(d, global_position)
		elif a is Cop:
			(a as Cop).on_gas(d, global_position)
