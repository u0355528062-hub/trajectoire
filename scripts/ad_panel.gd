class_name AdPanel
extends Node3D
## Panneau publicitaire vitré (« abribus » posé seul) : on casse la vitre, l'affiche reste.

var crowd: Crowd
var glass: GlassPane


func _ready() -> void:
	add_to_group("ad_panels")
	var gra := Furniture.mat("graphite", Color(0.1, 0.1, 0.12), 0.5, 0.4)
	var alu := Furniture.mat("alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
	# cadre
	Furniture.box(self, Vector3(1.32, 0.08, 0.16), gra, Vector3(0, 0.1, 0))
	Furniture.box(self, Vector3(1.32, 0.1, 0.16), gra, Vector3(0, 2.12, 0))
	for sx in [-1.0, 1.0]:
		Furniture.box(self, Vector3(0.09, 2.1, 0.16), gra, Vector3(sx * 0.615, 1.1, 0))
	for sx in [-1.0, 1.0]:
		Furniture.box(self, Vector3(0.1, 0.06, 0.6), gra, Vector3(sx * 0.55, 0.03, 0))
	# affiche rétro-éclairée
	var pm := StandardMaterial3D.new()
	var tex: Texture2D = load("res://assets/busstop/poster.png")
	pm.albedo_texture = tex
	pm.emission_enabled = true
	pm.emission_texture = tex
	pm.emission_energy_multiplier = 1.0
	pm.roughness = 0.5
	var q := QuadMesh.new()
	q.size = Vector2(1.14, 1.9)
	var pq := Furniture.add(self, q, pm, Vector3(0, 1.13, 0.0))
	pq.rotation.y = 0.0
	var pb := pq.duplicate()
	pb.rotation.y = PI
	add_child(pb)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.85)
	l.light_energy = 0.55
	l.omni_range = 3.0
	l.position = Vector3(0, 1.3, 0.5)
	add_child(l)
	# vitres avant / arrière
	glass = GlassPane.new()
	glass.size = Vector2(1.14, 1.9)
	glass.kind = "ad"
	glass.break_at = 90.0
	glass.thick = 0.012
	glass.position = Vector3(0, 1.13, 0.085)
	add_child(glass)
	var g2 := GlassPane.new()
	g2.size = Vector2(1.14, 1.9)
	g2.kind = "ad"
	g2.break_at = 90.0
	g2.thick = 0.012
	g2.position = Vector3(0, 1.13, -0.085)
	g2.rotation.y = PI
	add_child(g2)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.32, 2.2, 0.16)
	cs.shape = bs
	cs.position = Vector3(0, 1.1, 0)
	body.add_child(cs)
	add_child(body)
	if crowd != null:
		crowd.add_obstacle(self, Vector2(0.7, 0.3), Vector2.ZERO, false, true)
