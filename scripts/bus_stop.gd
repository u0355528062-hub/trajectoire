class_name BusStop
extends Node3D
## Abribus détaillé et cassable. Les vitres encaissent coups de pied et jets de pierres :
## chaque impact ajoute des fissures, des éclats se détachent, puis la vitre explose en
## éclats physiques (RigidBody) qui tombent et rebondissent.

const DIR := "res://assets/busstop/"
const KICK_DAMAGE := 36.0
const BREAK_AT := 100.0

var _glass: StandardMaterial3D
var _graphite: StandardMaterial3D
var _alu: StandardMaterial3D
var _panes: Array[GlassPane] = []
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
	_build_street()


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


func _quad(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	m.mesh = q
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _static_box(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	sb.rotation = rot
	add_child(sb)
	return sb


# ------------------------------------------------------------------ construction
func _build_ground() -> void:
	var paving := StandardMaterial3D.new()
	paving.albedo_texture = _tex("paving_a.png")
	paving.normal_enabled = true
	paving.normal_texture = _tex("paving_n.png")
	paving.normal_scale = 0.9
	paving.roughness = 0.88
	paving.uv1_triplanar = true
	paving.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_box(self, Vector3(5.2, 0.08, 3.1), Vector3(0, 0.04, 0.1), paving)
	_static_box(Vector3(5.2, 0.08, 3.1), Vector3(0, 0.04, 0.1))
	# rampe douce : le joueur monte sans buter sur le rebord
	_static_box(Vector3(5.2, 0.02, 0.5), Vector3(0, 0.03, 1.85), Vector3(0.0, 0.0, 0.0))
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.92, 0.72, 0.1)
	yellow.roughness = 0.62
	_box(self, Vector3(5.2, 0.008, 0.36), Vector3(0, 0.084, 1.42), yellow)
	for i in 26:  # plots podotactiles
		var dome := _cyl(self, 0.017, 0.012, Vector3(-2.5 + i * 0.2, 0.09, 1.42), yellow)
		dome.scale = Vector3(1, 1, 1)
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.5, 0.5, 0.5)
	curb.roughness = 0.82
	_box(self, Vector3(60.0, 0.15, 0.22), Vector3(0, 0.075, 1.86), curb)
	_box(self, Vector3(60.0, 0.05, 0.12), Vector3(0, 0.025, 2.0), curb)


func _build_frame() -> void:
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.87, 0.9)
	chrome.metallic = 1.0
	chrome.roughness = 0.14
	for x in [-1.85, 1.85]:
		for z in [-0.75, 0.75]:
			_box(self, Vector3(0.09, 2.55, 0.09), Vector3(x, 1.355, z), _graphite)
			_cyl(self, 0.062, 0.1, Vector3(x, 0.13, z), chrome)       # manchon chromé au pied
			for a in 4:                                                # boulons
				var ang := a * PI * 0.5 + PI * 0.25
				_cyl(self, 0.008, 0.012, Vector3(x + cos(ang) * 0.075, 0.09, z + sin(ang) * 0.075), chrome)
	for x in [-0.62, 0.62]:
		_box(self, Vector3(0.05, 2.3, 0.05), Vector3(x, 1.23, -0.75), _graphite)
	for z in [-0.75, 0.75]:
		_box(self, Vector3(3.8, 0.07, 0.07), Vector3(0, 2.52, z), _graphite)
	_box(self, Vector3(3.8, 0.08, 0.07), Vector3(0, 0.16, -0.75), _graphite)
	_box(self, Vector3(0.07, 0.08, 1.5), Vector3(-1.85, 0.16, 0), _graphite)
	_box(self, Vector3(0.07, 0.08, 1.5), Vector3(1.85, 0.16, 0), _graphite)
	_box(self, Vector3(0.07, 0.07, 1.5), Vector3(-1.85, 2.52, 0), _graphite)
	_box(self, Vector3(0.07, 0.07, 1.5), Vector3(1.85, 2.52, 0), _graphite)
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(-1.85, 1.35, 0.75))
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(1.85, 1.35, 0.75))
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(-1.85, 1.35, -0.75))
	_static_box(Vector3(0.1, 2.5, 0.1), Vector3(1.85, 1.35, -0.75))


func _build_roof() -> void:
	var roof := Node3D.new()
	roof.position = Vector3(0, 2.62, 0.05)
	roof.rotation.x = -0.03
	add_child(roof)
	_box(roof, Vector3(4.1, 0.1, 1.94), Vector3.ZERO, _graphite)
	_box(roof, Vector3(4.18, 0.025, 2.02), Vector3(0, 0.066, 0), _alu)
	# bords arrondis (tubes) à l'avant et à l'arrière
	_cyl(roof, 0.07, 4.18, Vector3(0, 0.0, 1.0), _alu, Vector3(0, 0, PI / 2.0))
	_cyl(roof, 0.06, 4.18, Vector3(0, 0.0, -1.0), _graphite, Vector3(0, 0, PI / 2.0))
	_cyl(roof, 0.06, 2.0, Vector3(2.09, 0.0, 0.0), _graphite, Vector3(PI / 2.0, 0, 0))
	_cyl(roof, 0.06, 2.0, Vector3(-2.09, 0.0, 0.0), _graphite, Vector3(PI / 2.0, 0, 0))
	# gouttière + descente d'eau
	_box(roof, Vector3(4.0, 0.045, 0.06), Vector3(0, -0.075, -1.0), _graphite)
	_cyl(self, 0.025, 2.5, Vector3(-1.93, 1.3, -0.82), _graphite)
	var led := StandardMaterial3D.new()
	led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.albedo_color = Color(1.0, 0.86, 0.62) * 2.2
	for z in [-0.5, 0.45]:
		_box(roof, Vector3(3.5, 0.012, 0.045), Vector3(0, -0.056, z), led)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.58)
	l.light_energy = 1.4
	l.omni_range = 5.0
	l.position = Vector3(0, -0.4, 0.1)
	roof.add_child(l)
	# écran d'information voyageurs suspendu
	var scr := Node3D.new()
	scr.position = Vector3(0.95, 2.34, 0.62)
	add_child(scr)
	_box(scr, Vector3(1.0, 0.27, 0.06), Vector3.ZERO, _graphite)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _tex("ledscreen.png")
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.5, 1.5, 1.5)
	_quad(scr, Vector2(0.94, 0.235), Vector3(0, 0, 0.032), sm)
	_box(scr, Vector3(0.03, 0.14, 0.03), Vector3(-0.4, 0.2, 0), _graphite)
	_box(scr, Vector3(0.03, 0.14, 0.03), Vector3(0.4, 0.2, 0), _graphite)
	var sl := OmniLight3D.new()
	sl.light_color = Color(1.0, 0.65, 0.2)
	sl.light_energy = 0.35
	sl.omni_range = 1.8
	sl.position = Vector3(0, 0, 0.4)
	scr.add_child(sl)


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
	_box(ad, Vector3(0.05, 2.02, 1.42), Vector3(-0.015, 1.2, 0), _alu)
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = _tex("poster.png")
	pm.emission_enabled = true
	pm.emission_texture = _tex("poster.png")
	pm.emission_energy_multiplier = 1.15
	pm.roughness = 0.5
	_quad(ad, Vector2(1.38, 1.98), Vector3(-0.042, 1.2, 0), pm, Vector3(0, -PI / 2.0, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.8)
	l.light_energy = 0.7
	l.omni_range = 3.2
	l.position = Vector3(-0.5, 1.3, 0)
	ad.add_child(l)
	_static_box(Vector3(0.2, 2.1, 1.5), Vector3(1.85, 1.2, 0))


func _build_street_furniture() -> void:
	var pole := Node3D.new()
	pole.position = Vector3(-2.75, 0.08, 1.0)
	add_child(pole)
	_cyl(pole, 0.036, 3.0, Vector3(0, 1.5, 0), _alu)
	_cyl(pole, 0.06, 0.05, Vector3(0, 0.03, 0), _graphite)
	_sign_pivot = Node3D.new()
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
	var plm := StandardMaterial3D.new()
	plm.albedo_texture = _tex("plate.png")
	plm.roughness = 0.45
	_quad(_sign_pivot, Vector2(0.56, 0.28), Vector3(0, 2.32, 0.05), plm)
	_box(_sign_pivot, Vector3(0.6, 0.32, 0.02), Vector3(0, 2.32, 0.036), _alu)
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _tex("timetable.png")
	tm.roughness = 0.4
	_quad(_sign_pivot, Vector2(0.36, 0.5), Vector3(0, 1.68, 0.05), tm)
	_box(_sign_pivot, Vector3(0.4, 0.54, 0.02), Vector3(0, 1.68, 0.036), _graphite)
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = _tex("map.png")
	mm.roughness = 0.4
	_quad(_sign_pivot, Vector2(0.3, 0.45), Vector3(0, 1.1, 0.05), mm)
	_box(_sign_pivot, Vector3(0.34, 0.49, 0.02), Vector3(0, 1.1, 0.036), _graphite)
	# poubelle
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.1, 0.24, 0.17)
	green.metallic = 0.5
	green.roughness = 0.4
	_cyl(self, 0.23, 0.82, Vector3(2.55, 0.49, 0.55), green)
	_cyl(self, 0.25, 0.05, Vector3(2.55, 0.92, 0.55), _graphite)
	_box(self, Vector3(0.18, 0.04, 0.02), Vector3(2.55, 0.76, 0.785), _graphite)
	# bornes anti-stationnement
	for x in [-3.4, 3.4]:
		_cyl(self, 0.05, 0.7, Vector3(x, 0.4, 1.4), _graphite)
		_cyl(self, 0.052, 0.06, Vector3(x, 0.62, 1.4), _alu)
	# arceau à vélos
	for i in 3:
		_cyl(self, 0.016, 0.7, Vector3(3.2 + i * 0.35, 0.38, -0.3), _alu)
	_cyl(self, 0.016, 0.7, Vector3(3.2 + 0.35, 0.73, -0.3), _alu, Vector3(0, 0, PI / 2.0))
	# lampadaire (éclaire l'arrêt et la chaussée)
	var lamp := Node3D.new()
	lamp.position = Vector3(-4.8, 0.08, 1.7)
	add_child(lamp)
	_cyl(lamp, 0.07, 6.2, Vector3(0, 3.1, 0), _graphite)
	_cyl(lamp, 0.12, 0.3, Vector3(0, 0.15, 0), _graphite)
	_cyl(lamp, 0.045, 1.9, Vector3(0.0, 6.0, 0.8), _graphite, Vector3(PI / 2.0 - 0.1, 0, 0))
	var lh := _box(lamp, Vector3(0.32, 0.1, 0.7), Vector3(0, 5.78, 1.7), _graphite)
	var lem := StandardMaterial3D.new()
	lem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lem.albedo_color = Color(1.0, 0.82, 0.55) * 2.5
	_box(lamp, Vector3(0.26, 0.012, 0.6), Vector3(0, 5.725, 1.7), lem)
	var sp := SpotLight3D.new()
	sp.light_color = Color(1.0, 0.8, 0.55)
	sp.light_energy = 8.5
	sp.spot_range = 13.0
	sp.spot_angle = 62.0
	sp.spot_attenuation = 0.8
	sp.shadow_enabled = true
	sp.position = Vector3(0, 5.7, 1.7)
	sp.rotation_degrees = Vector3(-90, 0, 0)
	lamp.add_child(sp)
	lh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_static_box(Vector3(0.2, 3.0, 0.2), Vector3(-4.8, 1.5, 1.7))


func _build_street() -> void:
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_texture = _tex("asphalt_a.png")
	asphalt.normal_enabled = true
	asphalt.normal_texture = _tex("asphalt_n.png")
	asphalt.albedo_color = Color(0.82, 0.84, 0.9)
	asphalt.normal_scale = 0.3
	asphalt.roughness = 0.72
	asphalt.metallic_specular = 0.6
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3(1.6, 1.6, 1.6)
	var road := _box(self, Vector3(120.0, 0.02, 7.0), Vector3(0, 0.01, 5.6), asphalt)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_static_box(Vector3(120.0, 0.04, 7.0), Vector3(0, 0.0, 5.6))
	var dash := StandardMaterial3D.new()
	dash.albedo_texture = _tex("road_dash.png")
	dash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dash.roughness = 0.6
	for i in range(-18, 19):
		_quad(self, Vector2(2.6, 0.14), Vector3(i * 3.2, 0.024, 5.6), dash, Vector3(-PI / 2.0, 0, 0))
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.9, 0.9, 0.85)
	edge.roughness = 0.6
	_box(self, Vector3(120.0, 0.004, 0.12), Vector3(0, 0.022, 2.25), edge)
	_box(self, Vector3(120.0, 0.004, 0.12), Vector3(0, 0.022, 8.95), edge)
	var bus := StandardMaterial3D.new()
	bus.albedo_texture = _tex("road_bus.png")
	bus.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bus.roughness = 0.6
	_quad(self, Vector2(4.0, 2.0), Vector3(0.8, 0.024, 3.55), bus, Vector3(-PI / 2.0, 0, 0))
	# plaque d'égout
	var sew := StandardMaterial3D.new()
	sew.albedo_color = Color(0.12, 0.12, 0.13)
	sew.metallic = 0.7
	sew.roughness = 0.5
	_cyl(self, 0.32, 0.012, Vector3(-6.0, 0.024, 6.4), sew)
	var bars := _cyl(self, 0.32, 0.014, Vector3(-6.0, 0.026, 6.4), sew)
	bars.scale = Vector3(0.7, 1, 0.7)


func _build_panes() -> void:
	var y0 := 1.33
	_add_pane(Vector2(1.14, 2.2), Vector3(-1.23, y0, -0.75), 0.0, true)
	_add_pane(Vector2(1.14, 2.2), Vector3(0.0, y0, -0.75), 0.0, true)
	_add_pane(Vector2(1.14, 2.2), Vector3(1.23, y0, -0.75), 0.0, true)
	_add_pane(Vector2(1.42, 2.2), Vector3(-1.85, y0, 0.0), PI / 2.0, true)
	_add_pane(Vector2(1.34, 1.94), Vector3(1.69, 1.2, 0.0), -PI / 2.0, false)


func _add_pane(size: Vector2, pos: Vector3, rot_y: float, frosted: bool) -> void:
	var pane := GlassPane.new()
	pane.size = size
	pane.kind = "bus"
	pane.position = pos
	pane.rotation.y = rot_y
	add_child(pane)
	if frosted:
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = _tex("frost.png")
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.roughness = 0.7
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		pane.overlays.append(_quad(pane, Vector2(size.x - 0.02, 0.34), Vector3(0, -0.1, 0.0068), fm))
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = _tex("dirt.png")
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.roughness = 1.0
	pane.overlays.append(_quad(pane, Vector2(size.x - 0.02, 0.6), Vector3(0, -size.y * 0.5 + 0.31, 0.0066), dm))
	# fixations « araignée » aux quatre coins
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.85, 0.87, 0.9)
	chrome.metallic = 1.0
	chrome.roughness = 0.15
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var f := _cyl(pane, 0.018, 0.03, Vector3(sx * (size.x * 0.5 - 0.06), sy * (size.y * 0.5 - 0.07), 0.0), chrome, Vector3(PI / 2.0, 0, 0))
			f.reparent(self, true)
	_panes.append(pane)


# ------------------------------------------------------------------ informations (PNJ)
func pane_count() -> int:
	return _panes.size()


func pane_alive(i: int) -> bool:
	return i >= 0 and i < _panes.size() and not _panes[i].is_broken


func pane_center(i: int) -> Vector3:
	return _panes[i].global_position


func pane_local_x(i: int) -> float:
	return _panes[i].position.x


func all_broken() -> bool:
	for p in _panes:
		if not p.is_broken:
			return false
	return true


func broken_count() -> int:
	var c := 0
	for p in _panes:
		if p.is_broken:
			c += 1
	return c


# ------------------------------------------------------------------ interaction
## Coup de pied : point (monde) et direction de poussée.
func kick(point: Vector3, dir: Vector3, power := 1.0) -> bool:
	var best := -1
	var best_d := 9.0
	for i in _panes.size():
		var d := _panes[i].contains(point)
		if d >= 0.0 and d < best_d:
			best_d = d
			best = i
	if best < 0:
		var pp := _sign_pivot.global_position
		if Vector2(point.x - pp.x, point.z - pp.z).length() < 0.6 and point.y < 2.4:
			_wobble_sign()
			_sound(&"glass_hit", point, -4.0)
			get_tree().call_group("crowd", "on_event", "vandal", {"pos": point, "kind": "sign_bus", "amount": 0.5})
			return true
		return false
	_panes[best].hit(point, GlassPane.KICK_DAMAGE * power, dir)
	return true


func _sound(sname: StringName, pos: Vector3, vol: float) -> void:
	var a := AudioStreamPlayer3D.new()
	a.stream = Sfx.get_stream(sname)
	a.volume_db = vol
	a.unit_size = 10.0
	a.pitch_scale = _rng.randf_range(0.93, 1.07)
	add_child(a)
	a.global_position = pos
	a.play()
	a.finished.connect(a.queue_free)


func _wobble_sign() -> void:
	var tw := create_tween()
	for k in 8:
		var a := 0.06 * (1.0 - float(k) / 8.0) * (1.0 if k % 2 == 0 else -1.0)
		tw.tween_property(_sign_pivot, "rotation", Vector3(a * 0.4, 0, a), 0.06)
	tw.tween_property(_sign_pivot, "rotation", Vector3.ZERO, 0.06)
