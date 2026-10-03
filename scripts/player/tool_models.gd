class_name ToolModels
extends RefCounted
## Modèles 3D des instruments médicaux tenus en main.
## Repère : l'instrument pointe vers -Z (vers l'avant).

static var _mats: Dictionary = {}
static var _shader: Shader


static func vm(color: Color, rough: float = 0.5, metal: float = 0.0, spec: float = 0.5, extra: Dictionary = {}) -> ShaderMaterial:
	var key := "%s_%.2f_%.2f_%.2f_%s" % [color.to_html(), rough, metal, spec, str(extra)]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load("res://shaders/viewmodel.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("specular_amount", spec)
	m.set_shader_parameter("noise_tex", Art.noise())
	for k in extra.keys():
		m.set_shader_parameter(k, extra[k])
	_mats[key] = m
	return m


static func glove() -> ShaderMaterial:
	return vm(Color(0.33, 0.4, 0.86), 0.36, 0.0, 0.55, {"clearcoat_amount": 0.25, "noise_bump": 0.12, "rim_amount": 0.12})


static func sleeve() -> ShaderMaterial:
	return vm(Color(0.94, 0.95, 0.96), 0.88, 0.0, 0.35, {"noise_bump": 0.25})


static func chrome() -> ShaderMaterial:
	return vm(Color(0.92, 0.93, 0.95), 0.12, 1.0, 0.5)


static func black_rubber() -> ShaderMaterial:
	return vm(Color(0.04, 0.04, 0.045), 0.55, 0.0, 0.4, {"noise_bump": 0.2})


static func plastic(c: Color) -> ShaderMaterial:
	return vm(c, 0.38, 0.0, 0.5, {"clearcoat_amount": 0.3})


static func lcd(c: Color = Color(0.62, 0.72, 0.62)) -> ShaderMaterial:
	return vm(c, 0.25, 0.0, 0.6, {"emission": Vector3(c.r, c.g, c.b) * 0.35, "emission_energy": 0.6})


static func _m(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _screen(parent: Node3D, pos: Vector3, rot: Vector3, size: Vector2, text: String, fsize: int = 48, col: Color = Color(0.08, 0.12, 0.1)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = UITheme.font("bold")
	l.font_size = fsize
	l.pixel_size = size.y / 160.0
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = rot
	l.no_depth_test = true
	l.render_priority = 10
	l.shaded = false
	l.name = "Display"
	parent.add_child(l)
	return l


static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	match id:
		"stethoscope":
			_stethoscope(root)
		"tensiometre":
			_bp_monitor(root)
		"thermometre":
			_thermometer(root)
		"oxymetre":
			_oximeter(root)
		"otoscope":
			_otoscope(root)
		"lampe":
			_penlight(root)
		"marteau":
			_hammer(root)
		"debitmetre":
			_peak_flow(root)
		"glucometre":
			_glucometer(root)
		"trod":
			_swab(root)
		"bandelette":
			_strip(root)
		"ecg":
			_electrodes(root)
	return root


static func _stethoscope(r: Node3D) -> void:
	var ch := chrome()
	# Pavillon : membrane noire tournée vers l'avant, bague chromée.
	_m(r, Art.cylinder(0.022, 0.022, 0.009, 40), ch, Vector3(0, 0, -0.012), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.0205, 0.0205, 0.002, 40), vm(Color(0.08, 0.08, 0.09), 0.35, 0.0, 0.6), Vector3(0, 0, -0.0175), Vector3(90, 0, 0))
	_m(r, Art.torus(0.019, 0.0235), black_rubber(), Vector3(0, 0, -0.016), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.012, 0.016, 0.012, 32), ch, Vector3(0, 0, -0.0015), Vector3(90, 0, 0))
	# Tige et tubulure
	_m(r, Art.cylinder(0.0035, 0.0035, 0.04, 12), ch, Vector3(0, 0.012, 0.012), Vector3(60, 0, 0))
	var tube := black_rubber()
	var p := Vector3(0, 0.03, 0.03)
	var dir := Vector3(0.15, 0.5, 1.0).normalized()
	for i in 10:
		var seg_len := 0.035
		var nxt := p + dir * seg_len
		var mid := (p + nxt) * 0.5
		var mi := _m(r, Art.cylinder(0.0045, 0.0045, seg_len + 0.004, 10), tube, mid)
		mi.look_at_from_position(mid, nxt, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		p = nxt
		dir = (dir + Vector3(0.05, -0.18, 0.12)).normalized()


static func _bp_monitor(r: Node3D) -> void:
	var white := plastic(Color(0.93, 0.94, 0.95))
	_m(r, Art.rounded_box(Vector3(0.1, 0.03, 0.13), 0.012), white, Vector3(0, 0, -0.04), Vector3(-60, 0, 0))
	var face := Node3D.new()
	face.position = Vector3(0, 0.0, -0.04)
	face.rotation_degrees = Vector3(-60, 0, 0)
	r.add_child(face)
	_m(face, Art.rounded_box(Vector3(0.07, 0.004, 0.05), 0.003), lcd(), Vector3(0, 0.016, -0.02))
	_m(face, Art.cylinder(0.009, 0.009, 0.004, 20), plastic(Color(0.15, 0.45, 0.85)), Vector3(0, 0.016, 0.035))
	_screen(face, Vector3(0, 0.0185, -0.02), Vector3(-90, 0, 0), Vector2(0.06, 0.04), "--- / ---", 40)
	# Tuyau vers le brassard
	_m(r, Art.cylinder(0.003, 0.003, 0.14, 8), vm(Color(0.85, 0.85, 0.86), 0.5), Vector3(0.03, -0.02, 0.05), Vector3(70, 0, 20))


static func _thermometer(r: Node3D) -> void:
	var white := plastic(Color(0.95, 0.96, 0.97))
	var blue := plastic(Color(0.12, 0.38, 0.78))
	_m(r, Art.rounded_box(Vector3(0.034, 0.04, 0.12), 0.014), white, Vector3(0, 0.03, -0.035))
	_m(r, Art.rounded_box(Vector3(0.03, 0.09, 0.036), 0.012), white, Vector3(0, -0.012, 0.008), Vector3(-14, 0, 0))
	_m(r, Art.cylinder(0.009, 0.014, 0.025, 24), blue, Vector3(0, 0.03, -0.105), Vector3(90, 0, 0))
	_m(r, Art.rounded_box(Vector3(0.026, 0.004, 0.034), 0.003), lcd(Color(0.55, 0.8, 0.95)), Vector3(0, 0.051, 0.0), Vector3(-15, 0, 0))
	_m(r, Art.rounded_box(Vector3(0.012, 0.018, 0.01), 0.004), blue, Vector3(0, 0.005, -0.012))
	_screen(r, Vector3(0, 0.0535, 0.0), Vector3(-105, 0, 0), Vector2(0.024, 0.016), "--,-", 40)


static func _oximeter(r: Node3D) -> void:
	var body := plastic(Color(0.92, 0.93, 0.95))
	var acc := plastic(Color(0.15, 0.55, 0.85))
	_m(r, Art.rounded_box(Vector3(0.034, 0.016, 0.058), 0.007), body, Vector3(0, 0.006, -0.03))
	_m(r, Art.rounded_box(Vector3(0.034, 0.014, 0.052), 0.007), acc, Vector3(0, -0.01, -0.03))
	_m(r, Art.rounded_box(Vector3(0.022, 0.002, 0.026), 0.002), vm(Color(0.02, 0.03, 0.05), 0.2, 0, 0.6), Vector3(0, 0.0145, -0.032))
	_screen(r, Vector3(0, 0.016, -0.032), Vector3(-90, 0, 0), Vector2(0.02, 0.012), "--", 36, Color(0.3, 0.9, 1.0))


static func _otoscope(r: Node3D) -> void:
	var blk := vm(Color(0.06, 0.06, 0.07), 0.45, 0.0, 0.45, {"noise_bump": 0.3})
	var ch := chrome()
	_m(r, Art.cylinder(0.0135, 0.0135, 0.1, 24), blk, Vector3(0, -0.035, 0.0))
	_m(r, Art.cylinder(0.015, 0.015, 0.01, 24), ch, Vector3(0, 0.017, 0.0))
	_m(r, Art.rounded_box(Vector3(0.03, 0.034, 0.036), 0.01), blk, Vector3(0, 0.038, -0.004))
	_m(r, Art.cylinder(0.004, 0.013, 0.034, 24), vm(Color(0.05, 0.05, 0.06), 0.3, 0, 0.6), Vector3(0, 0.04, -0.038), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.008, 0.008, 0.004, 20), vm(Color(0.6, 0.7, 0.8, 1.0), 0.05, 0.0, 0.9), Vector3(0, 0.04, 0.015), Vector3(90, 0, 0))


static func _penlight(r: Node3D) -> void:
	var ch := chrome()
	_m(r, Art.cylinder(0.0065, 0.0065, 0.13, 20), vm(Color(0.12, 0.35, 0.65), 0.25, 0.6, 0.5), Vector3(0, 0, -0.01), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.0068, 0.0068, 0.02, 20), ch, Vector3(0, 0, -0.08), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.0048, 0.0048, 0.002, 16), vm(Color(1, 0.97, 0.85), 0.1, 0, 0.5, {"emission": Vector3(1, 0.95, 0.8), "emission_energy": 3.0}), Vector3(0, 0, -0.0905), Vector3(90, 0, 0))
	_m(r, Art.rounded_box(Vector3(0.003, 0.008, 0.05), 0.0015), ch, Vector3(0, 0.0085, 0.02))
	# Abaisse-langue en bois
	_m(r, Art.rounded_box(Vector3(0.018, 0.002, 0.15), 0.0009), vm(Color(0.86, 0.74, 0.55), 0.8, 0, 0.3, {"noise_bump": 0.2}), Vector3(-0.03, -0.012, -0.04), Vector3(0, 8, 0))


static func _hammer(r: Node3D) -> void:
	var ch := chrome()
	_m(r, Art.rounded_box(Vector3(0.012, 0.004, 0.17), 0.0018), ch, Vector3(0, 0, -0.03))
	var head := Node3D.new()
	head.position = Vector3(0, 0.0, -0.115)
	r.add_child(head)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.05, 0.045, 0.014)
	_m(head, prism, vm(Color(0.85, 0.2, 0.12), 0.55, 0, 0.4), Vector3(0, 0.005, 0), Vector3(0, 0, 0))
	_m(head, Art.cylinder(0.004, 0.004, 0.016, 10), ch, Vector3(0, -0.012, 0), Vector3(90, 0, 0))


static func _peak_flow(r: Node3D) -> void:
	var clear := vm(Color(0.92, 0.94, 0.96), 0.15, 0, 0.7, {"clearcoat_amount": 0.6})
	_m(r, Art.cylinder(0.02, 0.02, 0.14, 32), clear, Vector3(0, 0, -0.03), Vector3(90, 0, 0))
	_m(r, Art.cylinder(0.012, 0.014, 0.04, 24), plastic(Color(0.85, 0.85, 0.88)), Vector3(0, 0, -0.115), Vector3(90, 0, 0))
	_m(r, Art.rounded_box(Vector3(0.004, 0.006, 0.1), 0.002), plastic(Color(0.85, 0.18, 0.15)), Vector3(0.0, 0.021, -0.03))
	for i in 9:
		_m(r, Art.box_mesh(Vector3(0.008, 0.001, 0.001)), vm(Color(0.1, 0.1, 0.1), 0.6), Vector3(0.0, 0.0205, -0.07 + i * 0.011))


static func _glucometer(r: Node3D) -> void:
	_m(r, Art.rounded_box(Vector3(0.05, 0.016, 0.085), 0.01), plastic(Color(0.2, 0.22, 0.26)), Vector3(0, 0, -0.02))
	_m(r, Art.rounded_box(Vector3(0.036, 0.003, 0.03), 0.002), lcd(), Vector3(0, 0.008, -0.005))
	_m(r, Art.box_mesh(Vector3(0.006, 0.001, 0.035)), plastic(Color(0.95, 0.95, 0.9)), Vector3(0, 0.0, -0.075))
	_screen(r, Vector3(0, 0.0102, -0.005), Vector3(-90, 0, 0), Vector2(0.03, 0.02), "--", 40)


static func _swab(r: Node3D) -> void:
	_m(r, Art.cylinder(0.002, 0.002, 0.16, 8), plastic(Color(0.95, 0.95, 0.96)), Vector3(0, 0, -0.04), Vector3(90, 0, 0))
	_m(r, Art.capsule(0.0045, 0.02), vm(Color(0.98, 0.98, 0.96), 0.95, 0, 0.2, {"noise_bump": 0.4}), Vector3(0, 0, -0.122), Vector3(90, 0, 0))
	# Cassette de test dans la main
	_m(r, Art.rounded_box(Vector3(0.02, 0.005, 0.07), 0.002), plastic(Color(0.96, 0.96, 0.97)), Vector3(0.025, -0.01, 0.0))


static func _strip(r: Node3D) -> void:
	_m(r, Art.box_mesh(Vector3(0.006, 0.0008, 0.12)), plastic(Color(0.97, 0.97, 0.97)), Vector3(0, 0, -0.04))
	var cols := [Color(0.95, 0.85, 0.55), Color(0.85, 0.9, 0.55), Color(0.95, 0.75, 0.6), Color(0.65, 0.8, 0.55), Color(0.9, 0.8, 0.7)]
	for i in cols.size():
		_m(r, Art.box_mesh(Vector3(0.0055, 0.0012, 0.005)), plastic(cols[i]), Vector3(0, 0.0003, -0.09 + i * 0.008))
	# Pot à échantillon
	_m(r, Art.cylinder(0.022, 0.02, 0.05, 28), vm(Color(0.9, 0.92, 0.95), 0.1, 0, 0.7, {"clearcoat_amount": 0.8}), Vector3(-0.035, -0.02, 0.005))
	_m(r, Art.cylinder(0.023, 0.023, 0.008, 28), plastic(Color(0.85, 0.2, 0.2)), Vector3(-0.035, 0.009, 0.005))


static func _electrodes(r: Node3D) -> void:
	_m(r, Art.rounded_box(Vector3(0.07, 0.002, 0.09), 0.002), plastic(Color(0.96, 0.96, 0.97)), Vector3(0, 0, -0.03))
	var cols := [Color(0.85, 0.15, 0.15), Color(0.95, 0.8, 0.15), Color(0.15, 0.65, 0.3), Color(0.12, 0.12, 0.12)]
	for i in 4:
		var x := -0.018 + (i % 2) * 0.036
		var z := -0.05 + int(i / 2) * 0.04
		_m(r, Art.cylinder(0.013, 0.013, 0.003, 24), plastic(Color(0.92, 0.92, 0.9)), Vector3(x, 0.002, z))
		_m(r, Art.cylinder(0.005, 0.005, 0.006, 16), plastic(cols[i]), Vector3(x, 0.005, z))
