class_name LampPost
extends StaticBody3D
## Lampadaire à lanterne vitrée : un jet de pierre (ou de pétard) casse la vitre — la lumière claque et s'éteint.

var crowd: Crowd
var glass: GlassPane
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _bulb_mat: StandardMaterial3D
var _dead := false
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 40.0
	collision_layer = 1
	var gra := Furniture.mat("graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
	var alu := Furniture.mat("alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
	Furniture.cyl(self, 0.05, 0.075, 3.5, gra, Vector3(0, 1.75, 0))
	Furniture.cyl(self, 0.11, 0.11, 0.35, gra, Vector3(0, 0.18, 0))
	Furniture.cyl(self, 0.045, 0.045, 0.1, gra, Vector3(0, 3.55, 0))
	# lanterne : cadre + ampoule + vitre côté chaussée (+Z)
	var lan := Node3D.new()
	lan.position = Vector3(0, 3.62, 0)
	add_child(lan)
	Furniture.box(lan, Vector3(0.34, 0.03, 0.34), gra, Vector3(0, -0.02, 0))
	Furniture.box(lan, Vector3(0.36, 0.04, 0.36), gra, Vector3(0, 0.38, 0))
	Furniture.add(lan, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.4), Vector2(0.2, 0.4), Vector2(0.06, 0.52), Vector2(0.0, 0.54)]), 12), gra)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Furniture.cyl(lan, 0.012, 0.012, 0.4, alu, Vector3(sx * 0.165, 0.18, sz * 0.165))
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bulb_mat.albedo_color = Color(1.0, 0.82, 0.55) * 2.2
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	_bulb = Furniture.add(lan, sm, _bulb_mat, Vector3(0, 0.16, 0))
	_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.55)
	_light.light_energy = 2.0
	_light.omni_range = 9.5
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.position = Vector3(0, 3.78, 0)
	add_child(_light)
	# vitres : face avant (chaussée) et arrière ; seule la face avant est cassable (les cailloux viennent de la rue)
	glass = GlassPane.new()
	glass.size = Vector2(0.3, 0.34)
	glass.kind = "lamp"
	glass.break_at = 30.0
	glass.slowmo = false
	glass.thick = 0.008
	glass.glass_color = Color(0.9, 0.85, 0.7, 0.14)
	glass.position = Vector3(0, 3.78, 0.185)
	add_child(glass)
	glass.broken_event.connect(_on_broken)
	var cs := CollisionShape3D.new()
	var cc := CylinderShape3D.new()
	cc.radius = 0.1
	cc.height = 3.6
	cs.shape = cc
	cs.position = Vector3(0, 1.8, 0)
	add_child(cs)
	# chaque lampadaire est aussi un obstacle pour les PNJ
	if crowd != null:
		crowd.add_obstacle(self, Vector2(0.15, 0.15), Vector2.ZERO, true, true)


func _process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	# léger vacillement de la lampe (vieux sodium)
	var f := 1.0 + 0.03 * sin(_t * 7.0 + _seed) + (0.0 if randf() > 0.0008 else -0.35)
	_light.light_energy = 2.0 * f


func _on_broken(p: Vector3) -> void:
	if _dead:
		return
	_dead = true
	AudioLib.play_at(self, "sfx:bulb_pop", p, 0.0, 9.0)
	# claquement : quelques éclairs, puis plus rien
	var tw := create_tween()
	for i in 4:
		tw.tween_callback(func():
			_light.light_energy = 3.2
			_bulb_mat.albedo_color = Color(1.0, 0.9, 0.7) * 3.0)
		tw.tween_interval(0.05)
		tw.tween_callback(func():
			_light.light_energy = 0.0
			_bulb_mat.albedo_color = Color(0.1, 0.08, 0.06))
		tw.tween_interval(randf_range(0.06, 0.2))
	tw.tween_callback(func():
		_light.visible = false)
	var sp := Fx.embers(24, Vector3(0.05, 0.02, 0.05), Color(1.0, 0.8, 0.5), 1.0)
	sp.one_shot = true
	sp.explosiveness = 0.9
	sp.lifetime = 0.9
	get_tree().current_scene.add_child(sp)
	sp.global_position = global_position + Vector3(0, 3.7, 0.1)
	sp.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(sp): sp.queue_free())
	get_tree().call_group("crowd", "on_event", "vandal", {"pos": global_position, "amount": 0.2})
