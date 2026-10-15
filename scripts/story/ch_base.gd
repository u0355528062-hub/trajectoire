class_name ChapterBase
extends ChapterScript
## Outils communs aux chapitres de « La Hausse » (scripts/story/ch_*.gd) : plans de caméra relatifs aux lieux,
## objectifs de conversation et d'outils (avec repli tant que le kit du joueur n'est pas livré), patrouille,
## bilan de la casse. N'utilise que l'API ChapterScript (docs/CAMPAGNE.md § 5.1).

## Fichiers du kit du joueur (§ 9) : tant qu'un outil manque, ses objectifs se valident en restant dans la zone
const KIT := "res://scripts/campaign/%s.gd"


## Durée d'attente « réelle » (until / wait_event ne sont pas accélérés en pilote automatique)
func tmo(sec: float) -> float:
	return sec * (0.1 if Campaign.autoplay else 1.0)


## L'outil du kit du joueur est-il livré ? (talk_interact, tract_tool, poster_tool, phone_tool, megaphone_tool, spray_tool)
func kit(tool: String) -> bool:
	return ResourceLoader.exists(KIT % tool)


## Point de caméra autour d'une cible : à `dist` m, `h` m de haut, `yaw` degrés (0 = côté +Z). Jamais dans un
## immeuble : un point prévu derrière une façade est pris en miroir devant elle (Quartier.camera_point).
func cam(target: Variant, dist: float, h: float, yaw: float) -> Vector3:
	var p := pos_of(target)
	var a := deg_to_rad(yaw)
	return Quartier.camera_point(p, p + Vector3(sin(a) * dist, h, cos(a) * dist))


## Point à `d` m d'une cible, décalé (pour placer quelqu'un à côté d'un lieu ou d'un personnage)
func near(target: Variant, dx: float, dz: float) -> Vector3:
	return pos_of(target) + Vector3(dx, 0.0, dz)


## Ouverture de chapitre : noir, carton de titre, début de cinématique
func open_chapter(title: String, sub: String, sec := 3.5) -> void:
	await fade_out(0.01)
	await title_card(title, sub, sec)
	cine_begin()


## Objectif « parler à quelqu'un » (E). Sans le module de conversation, rester près de la personne suffit.
func talk_obj(id: String, text: String, who: String) -> Objective:
	var o := objective(id, text, {"type": "talk", "who": who})
	if o and not kit("talk_interact"):
		_fallback(o, who, 2.6, 1.0, 1)
	return o


## Objectif d'événement d'outil (tracts, affiches, vidéo, mégaphone, bombe…). Sans l'outil, il avance en restant
## près de `zone` (une seconde et demie par unité).
func tool_obj(id: String, text: String, spec: Dictionary, tool: String, zone: Variant, radius := 6.0) -> Objective:
	var o := objective(id, text, spec)
	if o and not kit(tool):
		_fallback(o, zone, radius, 1.5, int(spec.get("count", 1)))
		hint("Outil pas encore disponible dans cette version : l'objectif avance tout seul près du repère.", 5.0)
	return o


func _fallback(o: Objective, zone: Variant, radius: float, per_unit: float, units: int) -> void:
	var acc := 0.0
	while alive() and o.is_active():
		await wait(0.25)
		if not o.is_active() or not is_instance_valid(player):
			return
		if zone is String and zone != "player" and not Quartier.SPOTS.has(zone) and actor(zone) == null:
			continue
		var c := pos_of(zone)
		if Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length() > radius:
			continue
		acc += 0.25
		if acc >= per_unit:
			acc = 0.0
			if units <= 1:
				o.complete()
			else:
				o.add_progress(1)


## Une voiture de patrouille traverse le quartier (si la police sait le faire)
func patrol() -> void:
	if is_instance_valid(police) and police.has_method("patrol_pass"):
		police.call("patrol_pass")


## Fin de chapitre : la casse du chapitre s'ajoute au total de la campagne (fins, réactions des personnages)
func bank_casse(extra := 0) -> int:
	var n := Campaign.counter("vitres") + Campaign.counter("voitures") * 3 + extra
	var total := int(flag("casse_total", 0)) + n
	set_flag("casse_total", total)
	return n


## Une réplique de la présentatrice du JT (télé du Zinc, radio…)
func tv(text: String) -> void:
	await say("presentatrice", text)


## Le joueur regarde-t-il la cible (moins de `max_dist` m, dans un cône étroit autour du centre de l'écran) ?
func looking_at(target: Variant, max_dist := 14.0, cos_min := 0.94) -> bool:
	if not is_instance_valid(player) or player.camera == null:
		return false
	var c := player.camera
	var to := pos_of(target) + Vector3.UP * 1.4 - c.global_position
	if to.length() > max_dist or to.length() < 0.5:
		return false
	return (-c.global_basis.z).dot(to.normalized()) >= cos_min


## Objectif « regarder » : atteint quand le joueur pose les yeux sur la cible
func look_obj(id: String, text: String, target: Variant, max_dist := 14.0) -> Objective:
	var o := objective(id, text, {"type": "manual", "waypoint": pos_of(target)})
	if o:
		_watch_look(o, target, max_dist)
	return o


func _watch_look(o: Objective, target: Variant, max_dist: float) -> void:
	while alive() and o.is_active():
		await wait(0.15)
		if o.is_active() and looking_at(target, max_dist):
			o.complete()


## Plan fixe par-dessus l'épaule de `a` vers `b` (le dialogue se joue ensuite sur ce cadre)
func frame(a: Variant, b: Variant, side := 0.7, fov := 42.0) -> void:
	var pa := pos_of(a)
	var pb := pos_of(b)
	var back := Vector3(pa.x - pb.x, 0.0, pa.z - pb.z)
	if back.length() < 0.1:
		back = Vector3.BACK
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	await shot({"from": pa + back * 1.5 + right * side + Vector3.UP * 1.75, "look": pb + Vector3.UP * 1.55,
		"dur": 0.05, "fov": fov, "cut": true, "dof": pa.distance_to(pb) + 1.5})


## Plan fixe large sur une cible (cam() : distance, hauteur, angle)
func wide(target: Variant, dist: float, h: float, yaw: float, fov := 50.0) -> void:
	await shot({"from": cam(target, dist, h, yaw), "look": pos_of(target) + Vector3.UP * 1.2, "dur": 0.05,
		"fov": fov, "cut": true})


## Objectif « filmer / photographier » un sujet (film_clip ou photo dont "subjects" contient `subject` :
## "prix", "temoignage", "police_lbd", "crowd"…). Sans le téléphone, rester près de `zone` suffit.
func clip_obj(id: String, text: String, subject: String, zone: Variant, radius := 6.0) -> Objective:
	var o := objective(id, text, {"type": "manual", "waypoint": pos_of(zone)})
	if o == null:
		return null
	if kit("phone_tool"):
		_watch_clip(o, subject, "film_clip")
		_watch_clip(o, subject, "photo")
	else:
		_fallback(o, zone, radius, 2.0, 1)
		hint("Téléphone pas encore disponible dans cette version : reste près du repère pour avancer.", 5.0)
	return o


func _watch_clip(o: Objective, subject: String, ev: String) -> void:
	while alive() and o.is_active():
		var d := await wait_event(ev, 1.0)
		if o.is_active() and (d.get("subjects", []) as Array).has(subject):
			o.complete()
