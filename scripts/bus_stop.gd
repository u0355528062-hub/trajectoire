class_name BusStop
extends Node3D
## Abribus détaillé et cassable. Chaque vitre encaisse des coups de pied (fissures de plus en
## plus étendues) puis éclate en éclats physiques (RigidBody) qui tombent et rebondissent.

const DIR := "res://assets/busstop/"
const HITS_TO_BREAK := 3

var _glass: StandardMaterial3D
var _graphite: StandardMaterial3D
var _alu: StandardMaterial3D
var _panes: Array[Dictionary] = []
var _sign_pivot: Node3D
var _rng := RandomNumberGenerator.new()
var _crack_shader: Shader
var _tex_cache := {}


func _tex(f: String) -> Texture2D:
	if not _tex_cache.has(f):
		_tex_cache[f] = load(DIR + f)
	return _tex_cache[f]


func _ready() -> void:
	_rng.randomize()
	add_to_group("breakable")
	_make_materials()
	_build_ground()
	_build_frame()
	_build_roof()
	_build_bench()
	_build_adbox()
	_build_panes()
	_build_street_furniture()


# ------------------------------------------------------------------ matériaux
func _make_materials() -> void:
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.62, 0.8, 0.86, 0.09)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.03
	_glass.metallic_specular = 0.7
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.rim_enabled = true
	_glass.rim = 0.12
	_glass.rim_tint = 0.3
	_graphite = StandardMaterial3D.new()
	_graphite.albedo_color = Color(0.085, 0.095, 0.105)
	_graphite.metallic = 0.85
	_graphite.roughness = 0.34
	_alu = StandardMaterial3D.new()
	_alu.albedo_color = Color(0.74, 0.76, 0.79)
	_alu.metallic = 1.0
	_alu.roughness = 0.26
	_crack_shader = Shader.new()
	_crack_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec2 half_size = vec2(0.5, 1.0);
uniform vec2 offset = vec2(0.0);
varying vec2 pl;
void vertex() { pl = VERTEX.xy + offset; }
void fragment() {
	if (abs(pl.x) > half_size.x || abs(pl.y) > half_size.y) discard;
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * 1.15;
	ALPHA = c.a * 0.92;
}"""


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 28
	m.mesh = c
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	parent.add_child(m)
	return m


func _static_box(size: Vector3, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	add_child(sb)


# ------------------------------------------------------------------ construction
func _build_ground() -> void:
	var conc := StandardMaterial3D.new()
	conc.albedo_texture = _tex("concrete_a.png")
	conc.normal_enabled = true
	conc.normal_texture = _tex("concrete_n.png")
	conc.normal_scale = 0.4
	conc.roughness = 0.92
	conc.uv1_triplanar = true
	conc.uv1_scale = Vector3(1.6, 1.6, 1.6)
	_box(self, Vector3(5.2, 0.1, 3.1), Vector3(0, 0.05, 0.1), conc)
	_static_box(Vector3(5.2, 0.1, 3.1), Vector3(0, 0.05, 0.1))
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.95, 0.74, 0.1)
	yellow.roughness = 0.6
	_box(self, Vector3(5.2, 0.012, 0.36), Vector3(0, 0.106, 1.42), yellow)
	for i in 26: # plots podotactiles
		_cyl(self, 0.016, 0.01, Vector3(-2.5 + i * 0.2, 0.113, 1.42), yellow)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.42, 0.42, 0.43)
	curb.roughness = 0.85
	_box(self, Vector3(5.6, 0.16, 0.2), Vector3(0, 0.08, 1.75), curb)


func _build_frame() -> void:
	# poteaux
	for x in [-1.85, 1.85]:
		for z in [-0.75, 0.75]:
			_box(self, Vector3(0.09, 2.55, 0.09), Vector3(x, 1.375, z), _graphite)
	for x in [-0.62, 0.62]:
		_box(self, Vector3(0.05, 2.3, 0.05), Vector3(x, 1.25, -0.75), _graphite)
	# lisses haute/basse
	for z in [-0.75, 0.75]:
		_box(self, Vector3(3.8, 0.07, 0.07), Vector3(0, 2.52, z), _graphite)
	_box(self, Vector3(3.8, 0.08, 0.07), Vector3(0, 0.16, -0.75), _graphite)
	_box(self, Vector3(0.07, 0.08, 1.5), Vector3(-1.85, 0.16, 0), _graphite)
	_box(self, Vector3(0.07, 0.08, 1.5), Vector3(1.85, 0.16, 0), _graphite)
	_box(self, Vector3(0.07, 0.07, 1.5), Vector3(-1.85, 2.52, 0), _graphite)
	_box(self, Vector3(0.07, 0.07, 1.5), Vector3(1.85, 2.52, 0), _graphite)
	# patins d'ancrage
	for x in [-1.85, 1.85]:
		for z in [-0.75, 0.75]:
			_box(self, Vector3(0.16, 0.02, 0.16), Vector3(x, 0.11, z), _alu)
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(-1.85, 1.35, 0.75))
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(1.85, 1.35, 0.75))


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.position = Vector3(0, 2.62, 0.05)
	roof.rotation.x = -0.03
	add_child(roof)
	_box(roof, Vector3(4.15, 0.1, 2.0), Vector3.ZERO, _graphite)
	_box(roof, Vector3(4.2, 0.03, 2.05), Vector3(0, 0.065, 0), _alu)
	_box(roof, Vector3(4.2, 0.2, 0.06), Vector3(0, -0.02, 1.0), _alu)    # bandeau avant
	_box(roof, Vector3(4.2, 0.16, 0.05), Vector3(0, 0.0, -1.0), _graphite)
	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.albedo_color = Color(1.0, 0.86, 0.62) * 2.2
	for z in [-0.45, 0.55]:
		_box(roof, Vector3(3.5, 0.012, 0.045), Vector3(0, -0.056, z), led)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.58)
	l.light_energy = 1.3
	l.omni_range = 5.0
	l.position = Vector3(0, -0.4, 0.1)
	roof.add_child(l)


func _build_bench() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _tex("wood_a.png")
	wood.normal_enabled = true
	wood.normal_texture = _tex("wood_n.png")
	wood.albedo_color = Color(0.5, 0.42, 0.36)
	wood.roughness = 0.62
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3(5.0, 5.0, 5.0)
	var bench := Node3D.new()
	bench.position = Vector3(0, 0, -0.42)
	add_child(bench)
	for i in 6:
		_box(bench, Vector3(2.3, 0.035, 0.062), Vector3(0, 0.46, -0.16 + i * 0.075), wood)
	for i in 3:
		_box(bench, Vector3(2.3, 0.075, 0.03), Vector3(0, 0.74 + i * 0.1, -0.2 - i * 0.025), wood, Vector3(-0.15, 0, 0))
	for x in [-1.1, 0.0, 1.1]:
		_box(bench, Vector3(0.035, 0.44, 0.035), Vector3(x, 0.22, 0.16), _graphite)
		_box(bench, Vector3(0.035, 0.44, 0.035), Vector3(x, 0.22, -0.17), _graphite)
		_box(bench, Vector3(0.03, 0.03, 0.4), Vector3(x, 0.44, 0.0), _graphite)
		_box(bench, Vector3(0.03, 0.36, 0.03), Vector3(x, 0.62, -0.22), _graphite, Vector3(-0.15, 0, 0))
	for x in [-0.55, 0.55]:
		_box(bench, Vector3(0.03, 0.14, 0.33), Vector3(x, 0.54, 0.0), _graphite)
	_static_box(Vector3(2.3, 0.5, 0.45), Vector3(0, 0.3, -0.42))


func _build_adbox() -> void:
	var ad := Node3D.new()
	ad.position = Vector3(1.78, 0, 0)
	add_child(ad)
	_box(ad, Vector3(0.18, 2.12, 1.52), Vector3(0.07, 1.2, 0), _graphite)
	var poster := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.38, 1.98)
	poster.mesh = q
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _tex("poster.png")
	pm.emission_enabled = true
	pm.emission_texture = _tex("poster.png")
	pm.emission_energy_multiplier = 1.15
	pm.roughness = 0.5
	poster.material_override = pm
	poster.position = Vector3(-0.02, 1.2, 0)
	poster.rotation.y = -PI / 2.0
	ad.add_child(poster)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.8)
	l.light_energy = 0.7
	l.omni_range = 3.2
	l.position = Vector3(-0.5, 1.3, 0)
	ad.add_child(l)
	_static_box(Vector3(0.2, 2.1, 1.5), Vector3(1.85, 1.2, 0))


func _build_street_furniture() -> void:
	# poteau + panneau + horaires
	var pole := Node3D.new()
	pole.position = Vector3(-2.75, 0.1, 1.0)
	add_child(pole)
	_cyl(pole, 0.036, 3.0, Vector3(0, 1.5, 0), _alu)
	_cyl(pole, 0.06, 0.05, Vector3(0, 0.03, 0), _graphite)
	_sign_pivot = Node3D.new()
	_sign_pivot.position = Vector3(0, 0, 0)
	pole.add_child(_sign_pivot)
	var disc := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.25
	dc.bottom_radius = 0.25
	dc.height = 0.014
	dc.radial_segments = 48
	disc.mesh = dc
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = _tex("sign.png")
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	dm.roughness = 0.4
	dm.metallic = 0.2
	disc.material_override = dm
	disc.position = Vector3(0, 2.7, 0.04)
	disc.rotation.x = PI / 2.0
	_sign_pivot.add_child(disc)
	_cyl(_sign_pivot, 0.255, 0.012, Vector3(0, 2.7, 0.032), _alu, Vector3(PI / 2.0, 0, 0))
	var plate := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(0.56, 0.28)
	plate.mesh = pq
	var plm := StandardMaterial3D.new()
	plm.albedo_texture = _tex("plate.png")
	plm.roughness = 0.45
	plate.material_override = plm
	plate.position = Vector3(0, 2.32, 0.05)
	_sign_pivot.add_child(plate)
	_box(_sign_pivot, Vector3(0.6, 0.32, 0.02), Vector3(0, 2.32, 0.036), _alu)
	var tt := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = Vector2(0.36, 0.5)
	tt.mesh = tq
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _tex("timetable.png")
	tm.roughness = 0.4
	tt.material_override = tm
	tt.position = Vector3(0, 1.68, 0.05)
	_sign_pivot.add_child(tt)
	_box(_sign_pivot, Vector3(0.4, 0.54, 0.02), Vector3(0, 1.68, 0.036), _graphite)
	# poubelle
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.1, 0.24, 0.17)
	green.metallic = 0.5
	green.roughness = 0.4
	_cyl(self, 0.23, 0.82, Vector3(2.55, 0.51, 0.55), green)
	_cyl(self, 0.25, 0.05, Vector3(2.55, 0.94, 0.55), _graphite)
	_box(self, Vector3(0.18, 0.04, 0.02), Vector3(2.55, 0.78, 0.785), _graphite)


func _build_panes() -> void:
	# fond : 3 vitres ; côté gauche : 1 vitre ; côté droit : devant le caisson lumineux
	var y0 := 1.33
	_add_pane(Vector2(1.14, 2.2), Vector3(-1.23, y0, -0.75), 0.0)
	_add_pane(Vector2(1.14, 2.2), Vector3(0.0, y0, -0.75), 0.0)
	_add_pane(Vector2(1.14, 2.2), Vector3(1.23, y0, -0.75), 0.0)
	_add_pane(Vector2(1.42, 2.2), Vector3(-1.85, y0, 0.0), PI / 2.0)
	_add_pane(Vector2(1.34, 1.94), Vector3(1.69, 1.2, 0.0), -PI / 2.0)


func _add_pane(size: Vector2, pos: Vector3, rot_y: float) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot_y
	add_child(node)
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(size.x, size.y, 0.012)
	m.mesh = b
	m.material_override = _glass
	node.add_child(m)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.05)
	cs.shape = bs
	sb.add_child(cs)
	node.add_child(sb)
	_panes.append({"node": node, "size": size, "hits": 0, "mesh": m, "body": sb, "cracks": null, "broken": false})


# ------------------------------------------------------------------ interaction
## Appelé quand un coup de pied atteint le point `point` (monde), poussée selon `dir`.
func kick(point: Vector3, dir: Vector3) -> bool:
	var best := -1
	var best_d := 9.0
	for i in _panes.size():
		var p: Dictionary = _panes[i]
		if p["broken"]:
			continue
		var node: Node3D = p["node"]
		var sz: Vector2 = p["size"]
		var l := node.to_local(point)
		if absf(l.x) <= sz.x * 0.5 + 0.25 and absf(l.y) <= sz.y * 0.5 + 0.3 and absf(l.z) <= 0.75:
			if absf(l.z) < best_d:
				best_d = absf(l.z)
				best = i
	if best < 0:
		# le poteau du panneau ?
		var pp := _sign_pivot.global_position
		if Vector2(point.x - pp.x, point.z - pp.z).length() < 0.6 and point.y < 2.4:
			_wobble_sign()
			_sound(&"glass_hit", point, -4.0)
			return true
		return false
	var p2: Dictionary = _panes[best]
	var node2: Node3D = p2["node"]
	var sz2: Vector2 = p2["size"]
	var l2 := node2.to_local(point)
	var imp := Vector2(clampf(l2.x, -sz2.x * 0.5 + 0.12, sz2.x * 0.5 - 0.12), clampf(l2.y, -sz2.y * 0.5 + 0.12, sz2.y * 0.5 - 0.12))
	p2["hits"] += 1
	var hits: int = p2["hits"]
	var impact_w := node2.to_global(Vector3(imp.x, imp.y, 0))
	if hits >= HITS_TO_BREAK:
		_shatter(p2, imp, dir)
	else:
		_add_cracks(p2, imp, hits)
		_vibrate(node2)
		_sound(&"glass_hit", impact_w, 2.0)
		if hits >= 2:
			_sound(&"glass_crack", impact_w, 0.0)
	return true


func _sound(name: StringName, pos: Vector3, vol: float) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = Sfx.get_stream(name)
	a.volume_db = vol
	a.unit_size = 10.0
	add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


func _vibrate(node: Node3D) -> void:
	var base := node.rotation
	var tw := create_tween()
	for k in 6:
		var a := 0.012 * (1.0 - float(k) / 6.0) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(node, "rotation", base + Vector3(a, a * 0.4, 0), 0.035)
	tw.tween_property(node, "rotation", base, 0.04)


func _wobble_sign() -> void:
	var tw := create_tween()
	for k in 8:
		var a := 0.06 * (1.0 - float(k) / 8.0) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(_sign_pivot, "rotation", Vector3(a * 0.4, 0, a), 0.06)
	tw.tween_property(_sign_pivot, "rotation", Vector3.ZERO, 0.06)


func _add_cracks(p: Dictionary, imp: Vector2, level: int) -> void:
	var node: Node3D = p["node"]
	var sz: Vector2 = p["size"]
	var old = p["cracks"]
	if old != null:
		(old as Node).queue_free()
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := 0.95 if level == 1 else 1.9
	q.size = Vector2(s, s)
	m.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = _crack_shader
	sm.set_shader_parameter("tex", _tex("crack1.png" if level == 1 else "crack2.png"))
	sm.set_shader_parameter("half_size", sz * 0.5)
	sm.set_shader_parameter("offset", imp)
	m.material_override = sm
	m.position = Vector3(imp.x, imp.y, 0.0075)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(m)
	p["cracks"] = m


# ------------------------------------------------------------------ éclatement
func _axis_points(a: float, b: float, c: float) -> Array[float]:
	var pts: Array[float] = [c]
	var x := c
	while x < b - 0.04:
		var d := absf(x - c)
		x += (0.085 + 0.27 * smoothstep(0.0, 1.0, d / 1.0)) * _rng.randf_range(0.75, 1.3)
		pts.append(minf(x, b))
	x = c
	while x > a + 0.04:
		var d2 := absf(x - c)
		x -= (0.085 + 0.27 * smoothstep(0.0, 1.0, d2 / 1.0)) * _rng.randf_range(0.75, 1.3)
		pts.append(maxf(x, a))
	pts.sort()
	# fusionne les points trop proches
	var out: Array[float] = []
	for v in pts:
		if out.is_empty() or v - out[out.size() - 1] > 0.03:
			out.append(v)
	out[0] = a
	out[out.size() - 1] = b
	return out


func _shard_mesh(poly: Array[Vector2], thick: float) -> ArrayMesh:
	var n := poly.size()
	var c2 := Vector2.ZERO
	for v in poly:
		c2 += v
	c2 /= n
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for v in poly:
		front.append(Vector3(v.x - c2.x, v.y - c2.y, thick * 0.5))
		back.append(Vector3(v.x - c2.x, v.y - c2.y, -thick * 0.5))
	var tris: Array = []
	for i in range(1, n - 1):
		tris.append([front[0], front[i], front[i + 1]])
		tris.append([back[0], back[i + 1], back[i]])
	for i in n:
		var j := (i + 1) % n
		tris.append([front[i], back[i], back[j]])
		tris.append([front[i], back[j], front[j]])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var nn := (b - a).cross(c - a)
		var centre := (a + b + c) / 3.0
		if nn.length() < 1e-12:
			continue
		nn = nn.normalized()
		if nn.dot(centre) > 0.0: # normale vers l'extérieur => ordre anti-horaire : on inverse (Godot = horaire)
			var tmp := b
			b = c
			c = tmp
		else:
			nn = -nn
		verts.append_array([a, b, c])
		norms.append_array([nn, nn, nn])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _shatter(p: Dictionary, imp: Vector2, kick_dir: Vector3) -> void:
	p["broken"] = true
	var node: Node3D = p["node"]
	var sz: Vector2 = p["size"]
	(p["mesh"] as Node).queue_free()
	(p["body"] as Node).queue_free()
	if p["cracks"] != null:
		(p["cracks"] as Node).queue_free()
	var impact_w := node.to_global(Vector3(imp.x, imp.y, 0))
	_sound(&"glass_break", impact_w, 5.0)

	var xs := _axis_points(-sz.x * 0.5, sz.x * 0.5, imp.x)
	var ys := _axis_points(-sz.y * 0.5, sz.y * 0.5, imp.y)
	var grid: Array = []
	for i in xs.size():
		var row: Array[Vector2] = []
		for j in ys.size():
			var v := Vector2(xs[i], ys[j])
			var edge_x := i == 0 or i == xs.size() - 1
			var edge_y := j == 0 or j == ys.size() - 1
			if not edge_x:
				var sx := minf(xs[i] - xs[i - 1], xs[i + 1] - xs[i])
				v.x += _rng.randf_range(-0.32, 0.32) * sx
			if not edge_y:
				var sy := minf(ys[j] - ys[j - 1], ys[j + 1] - ys[j])
				v.y += _rng.randf_range(-0.32, 0.32) * sy
			row.append(v)
		grid.append(row)

	var scene := get_tree().current_scene
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.72, 0.88, 0.92, 0.22)
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mat.roughness = 0.03
	shard_mat.metallic_specular = 1.0
	shard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shard_mat.rim_enabled = true
	shard_mat.rim = 0.5
	var phys := PhysicsMaterial.new()
	phys.friction = 0.45
	phys.bounce = 0.18
	var count := 0
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var a: Vector2 = grid[i][j]
			var b: Vector2 = grid[i + 1][j]
			var c: Vector2 = grid[i + 1][j + 1]
			var d: Vector2 = grid[i][j + 1]
			var polys: Array = []
			if _rng.randf() < 0.55:
				polys.append([a, b, c, d] as Array[Vector2])
			elif _rng.randf() < 0.5:
				polys.append([a, b, c] as Array[Vector2])
				polys.append([a, c, d] as Array[Vector2])
			else:
				polys.append([a, b, d] as Array[Vector2])
				polys.append([b, c, d] as Array[Vector2])
			var touches_edge := i == 0 or j == 0 or i == xs.size() - 2 or j == ys.size() - 2
			for poly in polys:
				var pl: Array[Vector2] = poly
				var cen := Vector2.ZERO
				for v in pl:
					cen += v
				cen /= pl.size()
				var rb := RigidBody3D.new()
				rb.collision_layer = 4
				rb.collision_mask = 1
				rb.mass = 0.35
				rb.physics_material_override = phys
				rb.linear_damp = 0.05
				rb.angular_damp = 0.2
				var mi := MeshInstance3D.new()
				mi.mesh = _shard_mesh(pl, 0.008)
				mi.material_override = shard_mat
				rb.add_child(mi)
				var pts := PackedVector3Array()
				for v in pl:
					pts.append(Vector3(v.x - cen.x, v.y - cen.y, 0.004))
					pts.append(Vector3(v.x - cen.x, v.y - cen.y, -0.004))
				var shape := ConvexPolygonShape3D.new()
				shape.points = pts
				var cs := CollisionShape3D.new()
				cs.shape = shape
				rb.add_child(cs)
				scene.add_child(rb)
				rb.global_transform = node.global_transform * Transform3D(Basis(), Vector3(cen.x, cen.y, 0))
				var cw := rb.global_position
				var away := cw - impact_w
				var dist := away.length()
				var k := clampf(dist / 1.5, 0.0, 1.0)
				var vel := away.normalized() * lerpf(3.4, 0.4, k) + kick_dir * lerpf(3.2, 0.8, k)
				vel += Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0.1, 1.3) * (1.0 - k * 0.6), _rng.randf_range(-0.4, 0.4))
				if touches_edge and _rng.randf() < 0.6:
					rb.freeze = true
					var delay := _rng.randf_range(0.3, 3.0)
					get_tree().create_timer(delay).timeout.connect(func():
						if is_instance_valid(rb):
							rb.freeze = false
							rb.linear_velocity = Vector3(_rng.randf_range(-0.3, 0.3), -0.2, _rng.randf_range(-0.3, 0.3)) + kick_dir * 0.4
							rb.angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3)))
				else:
					rb.linear_velocity = vel
					rb.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
				var life := _rng.randf_range(14.0, 22.0)
				get_tree().create_timer(life).timeout.connect(func():
					if is_instance_valid(rb):
						var tw := rb.create_tween()
						tw.tween_property(rb, "scale", Vector3.ONE * 0.01, 1.0)
						tw.tween_callback(rb.queue_free))
				count += 1
	_glass_dust(impact_w, kick_dir)


func _glass_dust(pos: Vector3, dir: Vector3) -> void:
	var scene := get_tree().current_scene
	var ps := GPUParticles3D.new()
	ps.amount = 90
	ps.lifetime = 1.8
	ps.one_shot = true
	ps.explosiveness = 0.95
	ps.local_coords = false
	ps.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized() + Vector3.UP * 0.3
	pm.spread = 70.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.3
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.8, 0.92, 1, 0.8), Color(0.8, 0.92, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	ps.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	q.material = FireworkShell.spark_material(Color(0.85, 0.95, 1.0), 1.4)
	ps.draw_pass_1 = q
	scene.add_child(ps)
	ps.global_position = pos
	ps.emitting = true
	get_tree().create_timer(3.5).timeout.connect(ps.queue_free)
