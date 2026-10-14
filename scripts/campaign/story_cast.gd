class_name StoryCast
extends Node3D
## Distribution : crée, anime et retire les personnages d'histoire (StoryActor) d'un chapitre. Ils sont inscrits
## dans `crowd.actors` pour l'évitement mutuel, mais ne sont ni manifestants (pas dans crowd.npcs) ni ciblés par
## la police. Toujours animés à pleine cadence (ce sont eux qu'on regarde de près).

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
		a.halt()
		a.global_position = _ground(at)
		return a
	a = StoryActor.new()
	a.setup_look(id)
	a.idx = 900 + actors.size()
	a.crowd = director.crowd if director else null
	a.name = "Story_" + id
	add_child(a)
	a.global_position = _ground(at)
	actors[id] = a
	if a.crowd:
		a.crowd.actors.append(a)
	return a


func despawn(id: String) -> void:
	var a := get_actor(id)
	actors.erase(id)
	if a:
		if a.crowd:
			a.crowd.actors.erase(a)
		a.queue_free()


## Marche jusqu'à `to` ; false si pas arrivé avant `timeout` secondes. Le personnage contourne les obstacles,
## recalcule son chemin s'il ne progresse plus, et se tourne ensuite dans le sens de la marche.
func walk_to(a: StoryActor, to: Vector3, run := false, timeout := 40.0) -> bool:
	if a == null or not is_instance_valid(a):
		return false
	if Campaign.autoplay:
		a.halt()
		a.global_position = _ground(to)
		await director.sleep(0.01)
		return true
	var from := a.global_position
	a.walk(to, run)
	var t := 0.0
	while t < timeout:
		if not is_instance_valid(a):
			return false
		if a.arrived():
			a.halt()
			var dir := Vector3(to.x - from.x, 0, to.z - from.z)
			if dir.length() > 0.5:
				a.face(a.global_position + dir.normalized() * 3.0)
			return true
		await director.sleep(0.1)
		t += 0.1
	if is_instance_valid(a):
		a.halt()
	return false


## Tous les personnages présents regardent `target` (nœud) ; null : regard libre
func all_look_at(target: Node3D, except: StoryActor = null) -> void:
	for id in actors:
		var a := get_actor(id)
		if a and a != except:
			a.look_at_node(target)


func _ground(p: Vector3) -> Vector3:
	if director and director.crowd:
		return Vector3(p.x, director.crowd.ground_y(p), p.z)
	return p


func _physics_process(delta: float) -> void:
	for id in actors:
		var a: StoryActor = actors[id]
		if is_instance_valid(a):
			a.tick(delta, true)
