class_name RoadSign
extends StreetProp
## Panneau routier parisien sur poteau (passage piéton, sens unique, zone 30) : se tord sous les coups puis tombe.
## Les faces viennent de l'atlas `panneaux_a.png`.

var kind := "crossing"        # crossing | one_way | zone30
static var _faces := {}


func _build() -> void:
	mass = 15.0
	damage_limit = 3.0
	top_y = 2.1
	reach = Vector3(0.35, 1.7, 0.35)
	nav_half = Vector2(0.1, 0.1)
	vandal_amount = 0.3
	hit_sound = "sign_bend"
	fall_sound = "sign_fall"
	var alu := Furniture.mat("alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
	var gra := Furniture.mat("graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
	Furniture.cyl(_model, 0.031, 0.031, 2.65, alu, Vector3(0, 1.325, 0))
	Furniture.cyl(_model, 0.058, 0.058, 0.05, gra, Vector3(0, 0.025, 0))
	Furniture.cyl(_model, 0.036, 0.036, 0.05, gra, Vector3(0, 2.66, 0))
	var size := Vector2(0.6, 0.6)
	var uv := Rect2(0, 0, 0.5, 0.5)
	var y := 2.25
	match kind:
		"one_way":
			size = Vector2(0.7, 0.3)
			uv = Rect2(0.5, 70.0 / 512.0, 0.5, 116.0 / 512.0)
			y = 2.4
		"zone30":
			uv = Rect2(0.0, 0.5, 0.5, 0.5)
	if not _faces.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/quartier/panneaux_a.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.uv1_scale = Vector3(uv.size.x, uv.size.y, 1)
		m.uv1_offset = Vector3(uv.position.x, uv.position.y, 0)
		m.roughness = 0.35
		m.metallic_specular = 0.7
		_faces[kind] = m
	var q := QuadMesh.new()
	q.size = size
	var face := Furniture.add(_model, q, _faces[kind], Vector3(0, y, 0.045))
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# dos du panneau (tôle) et colliers de fixation
	var back_size := Vector3(size.x * (0.98 if kind != "zone30" else 0.0), size.y * 0.98, 0.012)
	if kind == "zone30":
		Furniture.cyl(_model, 0.29, 0.29, 0.012, alu, Vector3(0, y, 0.036), Vector3(PI * 0.5, 0, 0), 28)
	else:
		Furniture.box(_model, back_size, alu, Vector3(0, y, 0.036))
	for dy in [-0.1, 0.1]:
		Furniture.box(_model, Vector3(0.08, 0.03, 0.05), gra, Vector3(0, y + dy, 0.015))
	Furniture.col_cyl(self, 0.05, 2.6, Vector3(0, 1.3, 0))


func _on_wobble(k: float) -> void:
	_perm = -_wob_axis * (0.1 * k)
