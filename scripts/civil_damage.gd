class_name CivilDamage
extends VehicleDamage
## Dégradations d'une voiture civile garée : même système que les véhicules de police (bosses, vitres qui se
## fissurent puis éclatent, incendie, carcasse, explosion), avec deux différences :
## - les vitres cassables (`GlassPane`) ne sont créées qu'à l'approche du joueur ou d'une pierre (« armement ») ;
##   au repos, la voiture n'a qu'un vitrage statique partagé, bien moins coûteux ;
## - les événements « voiture » ne concernent que les manifestants : ni les CRS ni la jauge de tension.

var armed := false
var pane_specs: Array = []          # [rôle, taille, position, rotation, seuil de casse, ralenti]


func setup(c: PoliceVehicle) -> void:
	car = c
	crowd = c.crowd
	for m in car._body.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers |= DENT_LAYER


## Crée les vitres cassables (et masque le vitrage statique qu'elles remplacent)
func arm() -> void:
	if armed or car == null or exploded:
		return
	armed = true
	var cc := car as CivilCar
	for s in pane_specs:
		var p := GlassPane.new()
		p.size = s[1]
		p.kind = "car"
		p.break_at = s[4]
		p.slowmo = s[5]
		p.thick = 0.008
		p.glass_color = CivilCar.PANE_COLOR
		p.spec = 0.45
		p.use_rim = false
		p.position = s[2]
		p.rotation = s[3]
		p.set_meta("role", s[0])
		car._body.add_child(p)
		p.add_to_group("breakable")
		p.hit_event.connect(_on_pane_hit)
		p.hit_event.connect(func(_pt: Vector3, _a: float): cc.trigger_alarm())
		p.broken_event.connect(func(pt: Vector3): _on_pane_broken(p, pt))
		panes.append(p)
	if cc.glass_rect != null:
		cc.glass_rect.visible = false


## Aucune vitre touchée : on peut revenir au vitrage statique
func intact() -> bool:
	for p in panes:
		if not is_instance_valid(p) or not p.alive() or p.hits > 0:
			return false
	return not burning and charred <= 0.0


func disarm() -> void:
	if not armed or not intact():
		return
	armed = false
	for p in panes:
		p.remove_from_group("breakable")
		p.queue_free()
	panes.clear()
	var cc := car as CivilCar
	if cc.glass_rect != null:
		cc.glass_rect.visible = true


## Le feu prend : les vraies vitres sont posées (elles éclateront dans la chaleur et l'explosion)
func ignite() -> void:
	arm()
	super.ignite()


func near_body(p: Vector3, margin := 0.35) -> bool:
	var l := car.to_local(p)
	var cc := car as CivilCar
	return absf(l.x) < car.half.x + margin and absf(l.z) < car.half.y + margin and l.y > -0.1 and l.y < cc.top_h + margin


func in_cabin(p: Vector3) -> bool:
	return (car as CivilCar).cabin.grow(0.05).has_point(car.to_local(p))


func _fire_specs() -> Array:
	return (car as CivilCar).fire_specs()


func _charrable(mo: Material) -> bool:
	return mo == (car as CivilCar).paint_mat or mo == CivilCar.cmat("glass")


## Les manifestants réagissent (encouragements, renforts pour cogner) ; la police ne se sent pas visée
func _notify(type: String, d: Dictionary) -> void:
	if type in ["car_vandal", "car_glass", "car_burn"]:
		if crowd != null and is_instance_valid(crowd):
			crowd.on_event(type, d)
		return
	super._notify(type, d)
