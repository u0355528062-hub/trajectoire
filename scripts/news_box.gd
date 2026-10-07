class_name NewsBox
extends StreetProp
## Boîte à journaux : vitre cassable (les journaux tombent, on peut les ramasser et les brûler),
## carrosserie qui s'enfonce sous les coups de pied, puis bascule.

var stock := 6
var glass: GlassPane


func _build() -> void:
	mass = 42.0
	damage_limit = 4.0
	top_y = 0.9
	reach = Vector3(0.42, 1.2, 0.4)
	nav_half = Vector2(0.28, 0.25)
	vandal_amount = 0.3
	var blue := Furniture.mat("news_blue", Color(0.07, 0.2, 0.55), 0.38, 0.55)
	var dark := Furniture.mat("news_dark", Color(0.05, 0.05, 0.06), 0.6, 0.2)
	var alu := Furniture.mat("alu", Color(0.72, 0.74, 0.77), 0.35, 0.85)
	# pieds + caisson + chapeau
	for sx in [-1.0, 1.0]:
		Furniture.cyl(_model, 0.03, 0.03, 0.12, dark, Vector3(sx * 0.19, 0.06, 0.0))
	Furniture.add(_model, MeshKit.rbox(Vector3(0.5, 0.58, 0.42), 0.02, 2), blue, Vector3(0, 0.41, 0))
	# partie haute : encadrement de la vitrine
	Furniture.add(_model, MeshKit.rbox(Vector3(0.5, 0.5, 0.42), 0.02, 2), blue, Vector3(0, 0.95, 0))
	Furniture.add(_model, MeshKit.rbox(Vector3(0.54, 0.04, 0.46), 0.015, 2), blue, Vector3(0, 1.22, 0))
	# cavité sombre derrière la vitre
	Furniture.box(_model, Vector3(0.38, 0.34, 0.01), dark, Vector3(0, 0.95, 0.212))
	# journaux empilés visibles derrière la vitre
	var paper := Props.paper_material()
	for i in 4:
		var pb := Furniture.box(_model, Vector3(0.32, 0.012, 0.015), paper, Vector3(0, 0.82 + i * 0.07, 0.205), Vector3(-0.35 + i * 0.05, 0, 0))
		pb.scale.y = 7.0
	# fente à pièces, poignée
	Furniture.box(_model, Vector3(0.14, 0.17, 0.012), alu, Vector3(0, 0.55, 0.215))
	Furniture.box(_model, Vector3(0.035, 0.03, 0.01), dark, Vector3(0.0, 0.58, 0.222))
	Furniture.box(_model, Vector3(0.12, 0.03, 0.04), alu, Vector3(0, 0.46, 0.235))
	Furniture.col_box(self, Vector3(0.5, 1.2, 0.42), Vector3(0, 0.6, 0))
	# vitre
	glass = GlassPane.new()
	glass.size = Vector2(0.38, 0.34)
	glass.kind = "news"
	glass.break_at = 70.0
	glass.slowmo = false
	glass.thick = 0.01
	glass.position = Vector3(0, 0.95, 0.222)
	add_child(glass)
	glass.broken_event.connect(_on_glass_broken)


func _on_glass_broken(_p: Vector3) -> void:
	_spill(Vector3(0, 0, 1))


func _on_toppled(d: Vector3) -> void:
	if glass != null and is_instance_valid(glass) and not glass.is_broken:
		glass.hit(glass.global_position, 100.0, d)
	_spill(d)


## Les journaux sortent de la boîte et tombent par terre
func _spill(dir: Vector3) -> void:
	if stock <= 0:
		return
	var n := stock
	stock = 0
	var out := global_basis * Vector3(0, 0, 1)
	for i in n:
		var b := Burnable.make("news")
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + global_basis * Vector3(randf_range(-0.12, 0.12), 0.86 + randf_range(-0.06, 0.1), 0.26)
		b.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		b.linear_velocity = out * randf_range(0.6, 1.5) + dir * randf_range(0.0, 0.6) + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 1.1), randf_range(-0.4, 0.4))
		b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
