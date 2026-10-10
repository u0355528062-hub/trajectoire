extends SceneTree
## Boutiques : on fait monter la tension, des casseurs attaquent une vitrine (la banque d'abord), puis les
## pilleurs entrent et renversent les meubles. On vérifie qu'ils ressortent et que personne ne reste coincé.
var frame := 0
var main: Node
var crowd: Crowd
var shop: Shop
var opened_at := -1
var max_in := 0
var max_loot := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		for c in main.get_children():
			if c is Crowd: crowd = c
		print("boutiques=", get_nodes_in_group("shops").size())
	if crowd == null:
		return false
	if frame > 60:
		crowd.excitement = maxf(crowd.excitement, 0.9)
	if frame > 60 and shop == null:
		for n in crowd.npcs:
			if n.state == "loot":
				shop = n.data["shop"]
				print("[%ds] cible : %s x=%.1f z=%.1f" % [frame / 30, shop.kind, shop.global_position.x, shop.global_position.z])
				break
	var inside := 0
	var loot := 0
	for n in crowd.npcs:
		if n.state == "loot":
			loot += 1
		if n.in_shop != null:
			inside += 1
	max_in = maxi(max_in, inside)
	max_loot = maxi(max_loot, loot)
	if shop and shop.is_open() and opened_at < 0:
		opened_at = frame
		print("[%ds] VITRINE BRISÉE" % (frame / 30))
	if frame % 300 == 0 and shop:
		var smashed := shop.items.size() - shop.intact_items().size()
		print("[%ds] pilleurs=%d dedans=%d meubles cassés=%d/%d vitre=%.0f" % [frame / 30, loot, inside, smashed, shop.items.size(), shop.pane.damage if is_instance_valid(shop.pane) else -1.0])
	if frame == 30 * 150:
		var stuck := 0
		for n in crowd.npcs:
			if n.state != "loot" and n.in_shop != null:
				stuck += 1
			# personne dans un mur de façade
			var z := n.global_position.z
			if n.in_shop == null and (z > ParisStreet.NORTH_Z - 0.3 or z < ParisStreet.SOUTH_Z + 0.3):
				stuck += 1
		print("FIN max_pilleurs=%d max_dedans=%d ouverte=%s coincés=%d" % [max_loot, max_in, opened_at > 0, stuck])
		quit()
	return false
