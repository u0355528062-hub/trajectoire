class_name StoryCast
extends Node3D
## Distribution : crée, anime et retire les personnages d'histoire (StoryActor) d'un chapitre. Ils sont inscrits
## dans `crowd.actors` pour l'évitement mutuel, mais ne sont ni manifestants (pas dans crowd.npcs) ni ciblés par
## la police. VERSION SQUELETTE : le module Cinématiques & jeu d'acteur l'enrichit en gardant l'interface publique.

var director: ChapterDirector
var actors := {}          # id -> StoryActor


func bind(d: ChapterDirector) -> void:
	director = d


func get_actor(id: String) -> StoryActor:
	var a: StoryActor = actors.get(id)
	return a if a != null and is_instance_valid(a) else null


func spawn(id: String, at: Vector3) -> StoryActor:
	var a := get_actor(id)
	if a:
		a.global_position = at
		return a
	a = StoryActor.new()
	a.setup_look(id)
	a.idx = 900 + actors.size()
	a.crowd = director.crowd
	a.name = "Story_" + id
	add_child(a)
	a.global_position = at
	actors[id] = a
	if director.crowd:
		director.crowd.actors.append(a)
	return a


func despawn(id: String) -> void:
	var a := get_actor(id)
	actors.erase(id)
	if a:
		if director.crowd:
			director.crowd.actors.erase(a)
		a.queue_free()


## Marche jusqu'à `to` ; false si pas arrivé avant `timeout` secondes
func walk_to(a: StoryActor, to: Vector3, run := false, timeout := 40.0) -> bool:
	if Campaign.autoplay:
		a.global_position = to
		return true
	a.walk(to, run)
	var t := 0.0
	while t < timeout:
		if not is_instance_valid(a):
			return false
		if a.arrived():
			a.stop_move()
			return true
		await director.sleep(0.1)
		t += 0.1
	return false


func _physics_process(delta: float) -> void:
	for id in actors:
		var a: StoryActor = actors[id]
		if is_instance_valid(a):
			a.tick(delta, true)
