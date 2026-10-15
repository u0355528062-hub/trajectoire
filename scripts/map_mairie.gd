class_name MapMairie
extends Node3D
## Mairie d'arrondissement au bout est du boulevard (côté nord, façade vers -X) : avant-corps en pierre devant
## l'immeuble (porte cochère, inscription MAIRIE et devise, fronton à horloge, drapeaux tricolores, lanternes) ; le
## parvis pavé est dessiné par le sol (Streetscape.ground_material). Repère : celui de l'immeuble porteur (`building`) — x le long de la façade, z vers le parvis.

const W := 7.6                      # largeur de l'avant-corps
const D := 0.8                      # saillie de l'avant-corps

var building: ParisBuilding
static var _mats := {}


## Pierre (ou enduit) texturée, sans couleur de sommet (contrairement aux matériaux fusionnés des immeubles)
static func stone_mat(tint: Color, tex := "stone") -> StandardMaterial3D:
	var key := tex + str(tint)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = ParisBuilding.mip_tex("res://assets/paris/%s_a.png" % tex)
		m.albedo_color = tint
		m.normal_enabled = true
		m.normal_texture = ParisBuilding.mip_tex("res://assets/paris/%s_n.png" % tex, true)
		m.normal_scale = 0.45
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		m.roughness = 0.88
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	return _mats[key]


func _ready() -> void:
	name = "Mairie"
	if building == null:
		return
	transform = building.transform
	var cx := building.width * 0.5
	var top := ParisBuilding.facade_h({"floors": building.floors, "fh": building.fh, "h0": building.h0})
	var stone := stone_mat(Color(0.9, 0.86, 0.78))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	# avant-corps (pleine hauteur) et soubassement en bossage
	MapStory.box(self, Vector3(W, top, D), stone, Vector3(cx, top * 0.5, D * 0.5))
	MapStory.box(self, Vector3(W + 0.3, 0.5, D + 0.15), stone_mat(Color(0.8, 0.77, 0.72)), Vector3(cx, top + 0.25, D * 0.5))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, top, D)
	cs.shape = sh
	cs.position = Vector3(cx, top * 0.5, D * 0.5)
	body.add_child(cs)
	# porte cochère et encadrement, devise au-dessus
	var z := D + 0.01
	MapStory.box(self, Vector3(3.3, 3.9, 0.12), stone_mat(Color(0.82, 0.78, 0.7)), Vector3(cx, 1.95, z))
	MapStory.box(self, Vector3(2.7, 3.5, 0.1), MapStory.mat(Color(0.12, 0.16, 0.13), 0.5), Vector3(cx, 1.75, z + 0.04))
	for s in [-1.0, 1.0]:
		MapStory.box(self, Vector3(1.24, 3.3, 0.04), MapStory.mat(Color(0.16, 0.21, 0.17), 0.45), Vector3(cx + s * 0.66, 1.7, z + 0.1))
		MapStory.box(self, Vector3(0.05, 0.4, 0.06), MapStory.mat(Color(0.75, 0.6, 0.25), 0.3), Vector3(cx + s * 0.1, 1.1, z + 0.14))
	var ink := Color(0.2, 0.17, 0.12)
	MapStory.label(self, "LIBERTÉ · ÉGALITÉ · FRATERNITÉ", 0.0045, ink, Vector3(cx, 4.25, z + 0.02), 64, true).visibility_range_end = 90.0
	MapStory.label(self, "MAIRIE", 0.0075, ink, Vector3(cx, top - 0.7, z + 0.02), 96, true).visibility_range_end = 220.0
	# fenêtres des étages de l'avant-corps
	var glass := MapStory.mat(Color(0.14, 0.16, 0.19), 0.08)
	var hh := building.fh - 1.4
	for f in building.floors:
		var y := building.h0 + 0.8 + float(f) * building.fh
		for k in 3:
			var wx := cx + (float(k) - 1.0) * 2.2
			MapStory.box(self, Vector3(1.3, hh, 0.06), glass, Vector3(wx, y + hh * 0.5, D + 0.01))
			MapStory.box(self, Vector3(1.6, 0.16, 0.2), stone, Vector3(wx, y - 0.05, D + 0.08))
			MapStory.box(self, Vector3(1.6, 0.22, 0.16), stone, Vector3(wx, y + hh + 0.12, D + 0.06))
	# balcon et drapeaux tricolores
	var by := building.h0 + 0.05
	MapStory.box(self, Vector3(W - 0.6, 0.15, 0.9), stone, Vector3(cx, by, D + 0.45))
	MapStory.box(self, Vector3(W - 0.6, 0.8, 0.05), MapStory.mat(Color(0.08, 0.08, 0.09), 0.5), Vector3(cx, by + 0.48, D + 0.88))
	for s in [-1.0, 1.0]:
		_flag(Vector3(cx + s * 2.6, by + 0.9, D + 0.85), s)
	# fronton triangulaire et horloge
	var pr := PrismMesh.new()
	pr.size = Vector3(W + 0.4, 2.2, D + 0.2)
	MapStory._mesh(self, pr, stone, Vector3(cx, top + 0.5 + 1.1, D * 0.5))
	var dial := CylinderMesh.new()
	dial.top_radius = 0.62
	dial.bottom_radius = 0.62
	dial.height = 0.08
	MapStory._mesh(self, dial, MapStory.mat(Color(0.95, 0.94, 0.88), 0.4, 0.25), Vector3(cx, top + 1.35, D + 0.13), Vector3(PI * 0.5, 0, 0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.7
	MapStory._mesh(self, ring, MapStory.mat(Color(0.7, 0.55, 0.22), 0.35), Vector3(cx, top + 1.35, D + 0.15), Vector3(PI * 0.5, 0, 0))
	var hand := MapStory.mat(Color(0.05, 0.05, 0.05), 0.5)
	MapStory.box(self, Vector3(0.05, 0.45, 0.02), hand, Vector3(cx + 0.11, top + 1.5, D + 0.19), Vector3(0, 0, -0.75))
	MapStory.box(self, Vector3(0.05, 0.3, 0.02), hand, Vector3(cx - 0.08, top + 1.3, D + 0.19), Vector3(0, 0, -2.1))
	# lanternes de part et d'autre de la porte, et une vraie lumière (nuit) sur le parvis
	for s in [-1.0, 1.0]:
		var ln := Node3D.new()
		ln.position = Vector3(cx + s * 2.3, 3.6, D + 0.3)
		add_child(ln)
		MapStory.box(ln, Vector3(0.08, 0.08, 0.4), hand, Vector3(0, 0, -0.15))
		MapStory.box(ln, Vector3(0.3, 0.45, 0.3), MapStory.mat(Color(1.0, 0.84, 0.55), 0.3, 2.5), Vector3(0, -0.1, 0.1))
	var om := OmniLight3D.new()
	om.position = Vector3(cx, 3.4, D + 1.6)
	om.light_color = Color(1.0, 0.82, 0.58)
	om.light_energy = 1.4
	om.omni_range = 9.0
	om.shadow_enabled = false
	add_child(om)
	var crowd: Crowd = building.crowd
	if crowd:
		crowd.add_obstacle(self, Vector2(W * 0.5, D * 0.5), Vector2(cx, D * 0.5))


## Drapeau tricolore sur une hampe inclinée vers le parvis
func _flag(p: Vector3, side: float) -> void:
	var f := Node3D.new()
	f.position = p
	f.rotation = Vector3(0.75, 0, side * 0.25)
	add_child(f)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.025
	pole.height = 2.6
	MapStory._mesh(f, pole, MapStory.mat(Color(0.75, 0.6, 0.25), 0.35), Vector3(0, 1.3, 0))
	var cols := [Color(0.0, 0.14, 0.58), Color(0.95, 0.95, 0.95), Color(0.8, 0.06, 0.1)]
	for i in 3:
		var qm := QuadMesh.new()
		qm.size = Vector2(0.42, 0.84)
		var m := MapStory.mat(cols[i], 0.8).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		MapStory._mesh(f, qm, m, Vector3(0.21 + 0.42 * float(i), 2.15, 0.0))
