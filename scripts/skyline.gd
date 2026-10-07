class_name Skyline
extends Node3D
## Horizon urbain lointain : bâtiments aux fenêtres allumées et tours à balises rouges.

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var sh: Shader = load("res://shaders/building.gdshader")
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.albedo_color = Color(1.0, 0.15, 0.1) * 3.0
	var blink := Shader.new()
	blink.code = """shader_type spatial;
render_mode unshaded;
uniform float offset = 0.0;
void fragment() { ALBEDO = vec3(1.0, 0.12, 0.08) * (2.0 + 4.0 * step(0.5, fract(TIME * 0.7 + offset))); }"""
	for i in 150:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(330.0, 620.0)
		var w := rng.randf_range(22.0, 60.0)
		var d := rng.randf_range(22.0, 60.0)
		var h := rng.randf_range(35.0, 120.0)
		if rng.randf() < 0.09:
			h = rng.randf_range(150.0, 260.0)
			w = rng.randf_range(24.0, 36.0)
			d = w
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(w, h, d)
		mi.mesh = b
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("seed", rng.randf() * 10.0)
		var t := rng.randf_range(0.05, 0.11)
		m.set_shader_parameter("wall_color", Color(t, t * 1.05, t * 1.3))
		mi.material_override = m
		mi.position = Vector3(cos(ang) * dist, h * 0.5, sin(ang) * dist)
		mi.rotation.y = rng.randf() * PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		if h > 140.0:
			var bc := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.8
			sm.height = 3.6
			bc.mesh = sm
			var bm := ShaderMaterial.new()
			bm.shader = blink
			bm.set_shader_parameter("offset", rng.randf())
			bc.material_override = bm
			bc.position = mi.position + Vector3(0, h * 0.5 + 2.0, 0)
			bc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bc)
