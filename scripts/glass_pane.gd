class_name GlassPane
extends Node3D
## Vitre cassable réutilisable (abribus, voitures, panneaux publicitaires, boîtes à journaux) :
## chaque impact ajoute des fissures et détache des éclats, puis la vitre explose en éclats physiques.
## Les événements « glass_hit » / « glass_break » sont diffusés à la foule et au système de tension.

signal hit_event(point: Vector3, amount: float)
signal broken_event(point: Vector3)

const DIR := "res://assets/busstop/"
const KICK_DAMAGE := 36.0

var size := Vector2(1.0, 1.0)
var kind := "bus"          # bus | car | ad | news : pour les réactions
var break_at := 100.0
var glass_color := Color(0.62, 0.8, 0.86, 0.09)
var slowmo := true
var thick := 0.012
var damage := 0.0
var hits := 0
var is_broken := false
var overlays: Array = []   # décors (givre, saleté) supprimés à l'éclatement
var _mesh: MeshInstance3D
var _body: StaticBody3D
var _cracks: Array = []
var _web := 0
var _rng := RandomNumberGenerator.new()

static var _crack_shader: Shader
static var _tex_cache := {}
static var _slowmo_on := false


static func tex(f: String) -> Texture2D:
	if not _tex_cache.has(f):
		_tex_cache[f] = load(DIR + f)
	return _tex_cache[f]


func _ready() -> void:
	_rng.randomize()
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(size.x, size.y, thick)
	_mesh.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = glass_color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.3
	_mesh.material_override = m
	add_child(_mesh)
	_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.05)
	cs.shape = bs
	_body.add_child(cs)
	_body.set_meta("glass", self)
	add_child(_body)
	if _crack_shader == null:
		_crack_shader = Shader.new()
		_crack_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec2 half_size = vec2(0.5, 1.0);
uniform vec2 offset = vec2(0.0);
uniform float rot = 0.0;
varying vec2 pl;
void vertex() { pl = VERTEX.xy + offset; }
void fragment() {
	if (abs(pl.x) > half_size.x || abs(pl.y) > half_size.y) discard;
	vec2 uv = UV - 0.5;
	float c = cos(rot); float s = sin(rot);
	uv = vec2(c * uv.x - s * uv.y, s * uv.x + c * uv.y) + 0.5;
	vec4 t = texture(tex, uv);
	ALBEDO = t.rgb * 1.15;
	ALPHA = t.a * 0.92;
}"""


func alive() -> bool:
	return not is_broken


## Distance au plan de la vitre si `p` (monde) est dans ses limites élargies, sinon -1.
func contains(p: Vector3, depth := 0.75, margin := Vector2(0.25, 0.3)) -> float:
	if is_broken:
		return -1.0
	var l := to_local(p)
	if absf(l.x) <= size.x * 0.5 + margin.x and absf(l.y) <= size.y * 0.5 + margin.y and absf(l.z) <= depth:
		return absf(l.z)
	return -1.0


func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	if contains(point) < 0.0:
		return false
	hit(point, KICK_DAMAGE * power, dir)
	return true


func stone_hit(point: Vector3, speed: float, dir: Vector3) -> void:
	if is_broken:
		return
	if speed < 3.0:
		_sound(&"glass_hit", point, -10.0)
		return
	hit(point, clampf(speed * 1.9, 6.0, 44.0), dir)


func _event(type: String, pos: Vector3) -> void:
	if is_inside_tree():
		get_tree().call_group("crowd", "on_event", type, {"pos": pos, "kind": kind, "pane": self})


func hit(point: Vector3, amount: float, dir: Vector3) -> void:
	if is_broken:
		return
	var l := to_local(point)
	var imp := Vector2(clampf(l.x, -size.x * 0.5 + 0.1, size.x * 0.5 - 0.1), clampf(l.y, -size.y * 0.5 + 0.1, size.y * 0.5 - 0.1))
	damage += amount
	hits += 1
	var impact_w := to_global(Vector3(imp.x, imp.y, 0))
	hit_event.emit(impact_w, amount)
	if damage >= break_at:
		_shatter(imp, dir)
		_event("glass_break", impact_w)
		broken_event.emit(impact_w)
		return
	_event("glass_hit", impact_w)
	_add_crack(imp, "crack_s%d.png" % _rng.randi_range(0, 3), _rng.randf_range(0.5, 0.85) + amount * 0.004)
	if damage >= 42.0 and _web < 1:
		_web = 1
		_add_crack(imp, "crack1.png", 1.25)
	if damage >= 74.0 and _web < 2:
		_web = 2
		_add_crack(imp, "crack2.png", 2.1)
	_vibrate()
	_chips(imp, impact_w, dir, int(3 + amount * 0.2))
	_sound(&"glass_hit", impact_w, 2.0 + amount * 0.03)
	if damage >= 42.0:
		_sound(&"glass_crack", impact_w, 0.0)


func _sound(sname: StringName, pos: Vector3, vol: float) -> void:
	if not is_inside_tree():
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = Sfx.get_stream(sname)
	a.volume_db = vol
	a.unit_size = 10.0
	a.pitch_scale = _rng.randf_range(0.93, 1.07)
	get_tree().current_scene.add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


func _vibrate() -> void:
	var base := rotation
	var tw := create_tween()
	for k in 6:
		var a := 0.012 * (1.0 - float(k) / 6.0) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(self, "rotation", base + Vector3(a, a * 0.4, 0), 0.035)
	tw.tween_property(self, "rotation", base, 0.04)


func _add_crack(imp: Vector2, tname: String, csize: float) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(csize, csize)
	m.mesh = q
	var sm := ShaderMaterial.new()
	sm.shader = _crack_shader
	sm.set_shader_parameter("tex", tex(tname))
	sm.set_shader_parameter("half_size", size * 0.5)
	sm.set_shader_parameter("offset", imp)
	sm.set_shader_parameter("rot", _rng.randf_range(0.0, TAU))
	m.material_override = sm
	m.position = Vector3(imp.x, imp.y, 0.0075 + _cracks.size() * 0.0003)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_cracks.append(m)
	overlays.append(m)


## Petits éclats qui se détachent à chaque impact (la vitre se dégrade progressivement).
func _chips(imp: Vector2, impact_w: Vector3, dir: Vector3, n: int) -> void:
	var scene := get_tree().current_scene
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.9, 0.95, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.03
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var phys := PhysicsMaterial.new()
	phys.friction = 0.45
	phys.bounce = 0.2
	var normal := global_basis * Vector3(0, 0, 1)
	var side := signf(normal.dot(dir))
	for k in n:
		var a := Vector2(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.05, 0.05))
		var s := _rng.randf_range(0.012, 0.04)
		var poly: Array[Vector2] = [Vector2(-s, -s * 0.6) + a, Vector2(s, -s * 0.4) + a, Vector2(s * 0.3, s) + a]
		var rb := RigidBody3D.new()
		rb.collision_layer = 4
		rb.collision_mask = 1
		rb.mass = 0.02
		rb.physics_material_override = phys
		var mi := MeshInstance3D.new()
		mi.mesh = _shard_mesh(poly, 0.006)
		mi.material_override = mat
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for v in poly:
			pts.append(Vector3(v.x, v.y, 0.003))
			pts.append(Vector3(v.x, v.y, -0.003))
		sh.points = pts
		cs.shape = sh
		rb.add_child(cs)
		scene.add_child(rb)
		rb.global_position = impact_w + normal * side * 0.02
		rb.linear_velocity = dir * _rng.randf_range(0.4, 1.8) + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, 0.8), _rng.randf_range(-0.5, 0.5))
		rb.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		get_tree().create_timer(_rng.randf_range(6.0, 11.0)).timeout.connect(func():
			if is_instance_valid(rb):
				rb.queue_free())


## Ralenti bref au moment où une vitre explose.
func _slowmo_fx() -> void:
	if _slowmo_on:
		return
	_slowmo_on = true
	Engine.time_scale = 0.3
	var t := get_tree().create_timer(0.16, true, false, true)
	t.timeout.connect(func():
		var tw := get_tree().create_tween().set_ignore_time_scale(true)
		tw.tween_property(Engine, "time_scale", 1.0, 0.3)
		tw.tween_callback(func(): _slowmo_on = false))


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
	var out: Array[float] = []
	for v in pts:
		if out.is_empty() or v - out[out.size() - 1] > 0.03:
			out.append(v)
	out[0] = a
	out[out.size() - 1] = b
	return out


static func _shard_mesh(poly: Array[Vector2], thick_: float) -> ArrayMesh:
	var n := poly.size()
	var c2 := Vector2.ZERO
	for v in poly:
		c2 += v
	c2 /= n
	var front: Array[Vector3] = []
	var back: Array[Vector3] = []
	for v in poly:
		front.append(Vector3(v.x - c2.x, v.y - c2.y, thick_ * 0.5))
		back.append(Vector3(v.x - c2.x, v.y - c2.y, -thick_ * 0.5))
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
		if nn.dot(centre) > 0.0:
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


func _shatter(imp: Vector2, kick_dir: Vector3) -> void:
	is_broken = true
	if slowmo:
		_slowmo_fx()
	_mesh.queue_free()
	_body.queue_free()
	for o in overlays:
		if is_instance_valid(o):
			(o as Node).queue_free()
	overlays.clear()
	var impact_w := to_global(Vector3(imp.x, imp.y, 0))
	_sound(&"glass_break", impact_w, 5.0)
	var xs := _axis_points(-size.x * 0.5, size.x * 0.5, imp.x)
	var ys := _axis_points(-size.y * 0.5, size.y * 0.5, imp.y)
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
	var max_shards := 500
	var made := 0
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
				if made >= max_shards:
					break
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
				rb.global_transform = global_transform * Transform3D(Basis(), Vector3(cen.x, cen.y, 0))
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
						Fx.shrink_and_free(rb, 1.0))
				made += 1
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
