class_name Interactable
extends Area3D
## Zone avec laquelle le joueur peut interagir (touche E / clic).

signal used

const LAYER := 2

@export var prompt: String = "Interagir"
@export var enabled: bool = true


static func create(parent: Node3D, size: Vector3, pos: Vector3, prompt_text: String) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt_text
	it.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	it.add_child(cs)
	parent.add_child(it)
	return it


func _init() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = 0
	monitoring = false
	monitorable = true


func interact() -> void:
	if enabled:
		used.emit()
