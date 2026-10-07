class_name Banner
extends MeshInstance3D
## Banderole peinte tendue entre deux perches : le tissu ondule au vent et se creuse au milieu.
## Les sommets des perches sont fournis chaque image (coordonnées monde).

const HEIGHT := 0.82
var a_top := Vector3.ZERO
var b_top := Vector3(3, 0, 0)
var _mat: ShaderMaterial


func _ready() -> void:
	top_level = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 28
	var nv := 7
	for j in nv:
		for i in nu:
			var quad := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for q: Vector2 in quad:
				var uv := Vector2(q.x / nu, q.y / nv)
				st.set_uv(uv)
				st.set_normal(Vector3(0, 0, 1))
				st.add_vertex(Vector3(uv.x, -uv.y, 0))
	mesh = st.commit()
	custom_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform vec3 a_top;
uniform vec3 b_top;
uniform float height = 0.82;
uniform sampler2D tex : source_color, filter_linear_mipmap;
varying float v_shade;
void vertex() {
	float u = UV.x;
	float v = UV.y;
	vec3 along = b_top - a_top;
	float L = max(length(along), 0.05);
	vec3 ax = along / L;
	vec3 side = normalize(cross(ax, vec3(0.0, 1.0, 0.0)));
	float slack = clamp(1.0 - L / 3.4, 0.0, 0.6);
	float bell = sin(3.14159 * u);
	float wave = sin(u * 8.0 + TIME * 2.1) * 0.045 + sin(u * 15.0 - TIME * 3.3 + v * 2.0) * 0.012;
	float billow = bell * (0.05 + 0.5 * slack) * (0.6 + 0.6 * v);
	vec3 p = mix(a_top, b_top, u);
	p.y -= v * height + bell * (0.04 + slack * 0.3) * (1.0 - 0.5 * v);
	p += side * (wave * bell * (0.6 + v) + billow);
	VERTEX = p;
	float dw = cos(u * 8.0 + TIME * 2.1) * 8.0 * 0.045 * bell;
	NORMAL = normalize(side - ax * dw * 0.35);
	v_shade = 0.82 + 0.18 * sin(u * 8.0 + TIME * 2.1);
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = c * v_shade * (FRONT_FACING ? 1.0 : 0.78);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25);
}"""
	_mat.shader = sh
	_mat.set_shader_parameter("tex", load(Props.DIR + "banner.png"))
	_mat.set_shader_parameter("height", HEIGHT)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## a = sommet de la perche gauche (vue de face), b = droite
func set_poles(a: Vector3, b: Vector3) -> void:
	a_top = a
	b_top = b
	global_position = (a + b) * 0.5
	_mat.set_shader_parameter("a_top", a)
	_mat.set_shader_parameter("b_top", b)
