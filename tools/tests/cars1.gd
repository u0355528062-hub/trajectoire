extends SceneTree
## Voitures civiles : coups de pied (bosses, alarme), vitre brisée, incendie jusqu'à la carcasse ; elles ne sont
## jamais comptées parmi les véhicules de police.
var frame := 0
var main: Node
var car: CivilCar
var ok_alarm := false
var ok_burn := false
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		var cars := root.find_children("*", "CivilCar", true, false)
		print("voitures civiles : ", cars.size())
		var best := 1e9
		for c in cars:
			var d: float = (c as Node3D).global_position.length()
			if d < best:
				best = d
				car = c
		var police: Police = main.get_node("Police")
		for v in police.vehicles:
			if v is CivilCar:
				print("ERREUR : voiture civile comptée dans la police")
		print("cible à ", car.global_position)
	if frame >= 10 and frame <= 200 and frame % 10 == 0 and car:
		var p := car.global_position + Vector3.UP * 0.8 + car.global_basis.x * (car.half.x + 0.05)
		car.kick(p, -car.global_basis.x, 1.0)
		if car.alarm_t > 0.0:
			ok_alarm = true
	if frame == 220 and car:
		print("alarme=", ok_alarm, " vitres intactes=", car.damage.panes.filter(func(p): return is_instance_valid(p) and p.alive()).size())
		car.damage.ignite()
	if frame > 220 and car and car.damage.burning:
		ok_burn = true
	if frame == 30 * 60:
		print("brûle=", ok_burn, " explosée=", car.damage.exploded if car else false)
		print("RÉSULTAT : ", "OK" if ok_alarm and ok_burn else "ÉCHEC")
		quit()
	return false
