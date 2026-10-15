class_name OpinionModel
extends Node
## Opinion publique : traduit ce qui se passe dans la rue en variations des jauges de campagne (opinion,
## mobilisation, répression, notoriété) et note les faits marquants dans le journal (repris par le JT du bilan).
## Barème (docs/CAMPAGNE.md § 1 « Ton », § 6 ; BIBLE § 2) :
## - le terrain (tracts, affiches légales, discussions, slogans repris, témoignages) fait monter un peu l'opinion
##   et la mobilisation, avec des plafonds par chapitre ;
## - la casse fait baisser l'opinion (davantage devant des témoins et des caméras), monte la mobilisation des plus
##   radicaux, la répression, et la notoriété de Sam quand c'est lui et que la police le voit ;
## - la violence contre des personnes ne rapporte jamais rien ;
## - les violences policières devant témoins font monter un peu l'opinion ; FILMÉES ET PUBLIÉES, beaucoup ;
## - la non-violence tenue face à la police (rester, ne pas répondre) est ce qui convainc le plus ;
## - une vidéo publiée vaut selon ses sujets et sa qualité (score du téléphone), avec des rendements décroissants ;
##   floutée, elle protège Sam (moins de notoriété) mais touche un peu moins.
## Le téléphone émet film_clip à l'enregistrement (published false) puis à la publication (published true, même
## `clip`) : on dédoublonne par `clip` et seule la publication compte.
## Les choix scénarisés des chapitres (Campaign.add_stat) ne passent pas par ici et ne sont pas plafonnés.

## Plafonds par chapitre de l'opinion venue du jeu : x = gain max, y = perte max (points)
const CHAPTER_CAP := {"prologue": Vector2(2, 6), "douze": Vector2(5, 10), "prix": Vector2(7, 12),
	"cortege": Vector2(9, 16), "nasse": Vector2(11, 20), "blocus": Vector2(11, 22)}
const CAP_DEFAULT := Vector2(8, 16)
## Plafonds par source (points d'opinion gagnés dans un chapitre)
const SOURCE_CAP := {"tracts": 2.5, "affiches": 1.5, "discussions": 1.5, "megaphone": 1.5, "temoignages": 1.2,
	"videos": 8.0, "temoins": 1.5, "tenue": 4.0}
## Mobilisation gagnée sur le terrain (gens convaincus) et chez les radicaux (casse), par chapitre
const MOB_CAP := {"terrain": 12.0, "videos": 14.0, "radicaux": 15.0}
## Poids des sujets de violence policière dans une vidéo publiée (le plus fort l'emporte)
const POLICE_SUBJECTS := {"police_lbd": 1.0, "police_baton": 0.85, "arrest": 0.6, "police_charge": 0.6, "police_gas": 0.45}
## Libellés des sujets (journal, réseaux sociaux)
const SUBJECT_TXT := {"police_lbd": "un tir de LBD", "police_baton": "des coups de matraque", "arrest": "une interpellation",
	"police_charge": "une charge policière", "police_gas": "les gaz lacrymogènes", "temoignage": "un témoignage",
	"prix": "les prix", "crowd": "la foule", "casse": "de la casse", "cop_hit": "des projectiles sur la police",
	"police": "la police"}
## Casse : [perte d'opinion, mobilisation radicale, répression, notoriété si c'est Sam, compteur]
const CASSE := {"glass_break": [0.4, 0.3, 0.004, 0.02, "vitres"], "car_burn": [2.0, 1.0, 0.02, 0.06, "voitures"],
	"bus_destroyed": [1.2, 0.6, 0.01, 0.05, "mobilier"], "fire_start": [0.25, 0.2, 0.002, 0.02, "feux"],
	"player_fire": [0.4, 0.2, 0.004, 0.03, "feux"], "kick_bus": [0.03, 0.0, 0.0, 0.0, ""],
	"mortar_fire": [0.6, 0.3, 0.01, 0.04, "mortiers"]}
## Violences contre des personnes : [perte d'opinion, répression, notoriété si c'est Sam]
const VIOLENCE := {"cop_hit": [0.45, 0.01, 0.03], "cop_down": [1.6, 0.03, 0.08], "civil_hit": [1.2, 0.0, 0.05]}
const CALM_NEEDED := 20.0         # secondes sans violence du cortège pour parler de non-violence
const TENUE_STEP := 15.0          # gain toutes les 15 s de non-violence tenue face à la police

var director: ChapterDirector
var hud: OpinionHud
var up := 0.0                     # opinion gagnée dans ce chapitre (venue du jeu)
var down := 0.0                   # opinion perdue
var src: Dictionary = {}          # gain par source
var mob: Dictionary = {}          # mobilisation par source
var clips: Dictionary = {}        # clip -> {"published": bool}
var published := 0                # vidéos publiées par le joueur dans ce chapitre
var tenue_t := 0.0                # non-violence tenue face à la police (s)
var _clock := 0.0
var _last_violence := -999.0      # dernier acte violent du cortège ou du joueur
var _last_police := -999.0        # dernière action de la police
var _stage := 0
var _anon := 0
var _cars_logged := 0
var _logged: Dictionary = {}
var _news_t := -999.0
var _civ: Civilians
var _res: Residents
var _searched := false


func bind(d: ChapterDirector) -> void:
	director = d
	d.event.connect(on_event)
	d.chapter_finished.connect(_on_chapter_finished)
	hud = OpinionHud.new()
	hud.name = "OpinionHud"
	hud.director = d
	add_child(hud)


func on_event(type: String, d: Dictionary) -> void:
	match type:
		"tract_given":
			Campaign.count("tracts")
			_gain("tracts", 0.12, "tract distribué")
			_mob("terrain", 0.25, "tract distribué")
		"tract_refused":
			Campaign.count("tracts_refuses")
		"talk":
			if str(d.get("who", "")) == "passant":
				Campaign.count("discussions")
				_gain("discussions", 0.1, "discussion avec un passant")
				_mob("terrain", 0.3, "discussion avec un passant")
		"poster_stuck":
			if bool(d.get("legal", true)):
				Campaign.count("affiches")
				_gain("affiches", 0.1, "affiche collée")
				_mob("terrain", 0.2, "affiche collée")
			else:
				Campaign.count("affiches_sauvages")
				_gain("affiches", 0.04, "affichage sauvage")
				if _police_sees(_pos(d)):
					Campaign.add_stat("notoriete", 0.02, "affichage sauvage sous les yeux de la police")
		"spray_tag":
			Campaign.count("tags")
			_loss(0.35 * _seen_factor(_pos(d)), "tag sur un mur")
			_mob("radicaux", 0.4, "tag")
			Campaign.add_stat("notoriete", 0.02 + (0.04 if _police_sees(_pos(d)) else 0.0), "tag")
			_log_once("tag", "casse", "Tag « %s » sur un mur du quartier" % str(d.get("text", "…")).left(40), -0.35)
		"megaphone":
			Campaign.count("slogans")
			var joined := int(d.get("joined", 0))
			if joined > 0:
				_gain("megaphone", 0.05 + 0.01 * minf(joined, 20.0), "slogan repris par la foule")
				_mob("terrain", 0.1 * minf(joined, 20.0), "slogan repris")
				if joined >= 10:
					_log_once("slogan", "mobilisation", "« %s » repris par %d personnes" % [str(d.get("slogan", "")).left(48), joined], 0.5)
		"film_clip":
			_on_clip(d)
		"photo":
			Campaign.count("photos")
		"testimony":
			Campaign.count("temoignages")
			var who := str(d.get("who", ""))
			_gain("temoignages", 0.3, "témoignage recueilli")
			_log_once("temoignage_" + who, "temoignage", "Témoignage recueilli : %s" % _who_txt(who), 0.3)
		"police_stage":
			_stage = int(d.get("stage", 0))
			if _stage >= 2:
				_last_police = _clock
		"police_lbd", "police_baton", "police_gas", "police_charge", "police_bang", "gas_land":
			_last_police = _clock
			_police_violence(type, d)
		"arrest", "grab":
			_last_police = _clock
			if type == "arrest":
				Campaign.count("interpellations")
		"police_retreat":
			if _calm() and _clock - _last_police < 60.0:
				_gain("tenue", 1.0, "la police recule devant un cortège pacifique")
				_log_once("retreat", "non_violence", "La police recule devant un cortège qui ne répond pas", 1.0)
		"car_vandal":
			if bool(d.get("player", false)):
				_last_violence = _clock
				Campaign.count("carrosseries")
				_loss(0.06 * _seen_factor(_pos(d)), "voiture dégradée")
		"vandal":
			_last_violence = _clock
			Campaign.count("mobilier")
			_loss(0.5 * clampf(float(d.get("amount", 0.2)), 0.0, 1.0) * _seen_factor(_pos(d)), "mobilier urbain dégradé")
		"petard_boom":
			if bool(d.get("player", false)):
				_loss(0.05, "pétard")
		_:
			if CASSE.has(type):
				_casse(type, d)
			elif VIOLENCE.has(type):
				_violence(type, d)


func _process(delta: float) -> void:
	_clock += delta
	# non-violence tenue : la police agit, le cortège reste sans répondre
	var police_on := _clock - _last_police < 20.0 or _stage >= 2
	var crowd_here := director != null and is_instance_valid(director.crowd) and director.crowd.npcs.size() >= 5
	if police_on and crowd_here and _calm():
		var before := int(tenue_t / TENUE_STEP)
		tenue_t += delta
		if int(tenue_t / TENUE_STEP) > before:
			_gain("tenue", 0.6, "non-violence face à la police")
			if tenue_t >= 30.0:
				_log_once("tenue", "non_violence", "Face à la police, le cortège tient sans répondre", 1.5)


## Le cortège est resté sans violence depuis CALM_NEEDED secondes
func _calm() -> bool:
	return _clock - _last_violence >= CALM_NEEDED


# ------------------------------------------------------------------ casse et violences
func _casse(type: String, d: Dictionary) -> void:
	var c: Array = CASSE[type]
	var p := _pos(d)
	_last_violence = _clock
	if str(c[4]) != "":
		Campaign.count(str(c[4]))
	_loss(float(c[0]) * _seen_factor(p), {"glass_break": "vitrine brisée", "car_burn": "véhicule incendié",
		"bus_destroyed": "abribus détruit", "fire_start": "feu de poubelle", "player_fire": "feu allumé",
		"kick_bus": "abribus dégradé", "mortar_fire": "tir de mortier d'artifice"}.get(type, "casse"))
	_mob("radicaux", float(c[1]), "les plus radicaux")
	if float(c[2]) > 0.0:
		Campaign.add_stat("repression", float(c[2]), "casse")
	if _by_player(d, p) and float(c[3]) > 0.0:
		Campaign.add_stat("notoriete", float(c[3]) * (2.0 if _police_sees(p) else 1.0), "casse")
	match type:
		"glass_break":
			var n := Campaign.counter("vitres")
			if n in [1, 5, 10, 20, 40]:
				Campaign.log_action("casse", "Première vitrine brisée" if n == 1 else "%d vitrines brisées" % n, -0.4 * n)
				if n == 5:
					_auto_news("Vitrines brisées dans le quartier des Tanneurs : le ministre de l'Intérieur dénonce des « casseurs ».")
		"car_burn":
			_cars_logged += 1
			Campaign.log_action("casse", "Une voiture incendiée" if _cars_logged == 1 else "%d voitures incendiées" % _cars_logged, -2.0)
			_auto_news("Voiture incendiée dans le quartier des Tanneurs : les images tournent en boucle.")
		"bus_destroyed":
			_log_once("abribus", "casse", "Un abribus détruit sur le boulevard", -1.2)


func _violence(type: String, d: Dictionary) -> void:
	var v: Array = VIOLENCE[type]
	var p := _pos(d)
	_last_violence = _clock
	var why := str({"cop_hit": "projectile sur la police", "cop_down": "policier blessé", "civil_hit": "passant frappé"}.get(type, "violence"))
	_loss(float(v[0]) * _seen_factor(p), why)
	if float(v[1]) > 0.0:
		Campaign.add_stat("repression", float(v[1]), why)
	if _by_player(d, p) and float(v[2]) > 0.0:
		Campaign.add_stat("notoriete", float(v[2]), why)
	if type == "cop_down":
		_log_once("cop_down", "violence", "Un policier blessé sur le boulevard", -1.6)
	elif type == "civil_hit":
		_log_once("civil_hit", "violence", "Un passant frappé dans la confusion", -1.2)


## Violence policière vue par des témoins : un peu d'opinion, seulement si le cortège était calme
func _police_violence(type: String, d: Dictionary) -> void:
	if type == "police_lbd":
		Campaign.count("lbd")
		_log_once("lbd", "police", "Tirs de LBD sur le cortège", 0.0)
	if not _calm():
		return
	var w := _witnesses(_pos(d))
	if int(w["people"]) + int(w["press"]) <= 0:
		return
	var g := {"police_lbd": 0.25, "police_baton": 0.15, "police_charge": 0.08, "police_gas": 0.05}.get(type, 0.0) as float
	if g > 0.0:
		_gain("temoins", g * (1.5 if int(w["press"]) > 0 else 1.0), "violences policières devant témoins")


# ------------------------------------------------------------------ vidéos
func _on_clip(d: Dictionary) -> void:
	var key: Variant = d.get("clip", null)
	if key == null:
		_anon += 1
		key = "x%d" % _anon
	if not clips.has(key):
		Campaign.count("rushes")
		clips[key] = {"published": false}
	var rec: Dictionary = clips[key]
	if not bool(d.get("published", false)) or bool(rec.get("published", false)):
		return
	rec["published"] = true
	_publish(d)


## Effet d'une vidéo publiée : selon les sujets, la qualité (score), le floutage et le rang dans le chapitre
func _publish(d: Dictionary) -> void:
	published += 1
	Campaign.count("videos")
	var subjects: Array = d.get("subjects", [])
	var blur := bool(d.get("blur", false))
	var score := float(d.get("score", 0.0))
	var k := clampf(score / 8.0, 0.15, 2.0) * (0.85 if blur else 1.0) / (1.0 + 0.35 * float(published - 1))
	var op := 0.0
	var mobv := 0.0
	var pw := 0.0
	for s in subjects:
		pw = maxf(pw, float(POLICE_SUBJECTS.get(s, 0.0)))
	var casse := subjects.has("casse") or subjects.has("cop_hit")
	if pw > 0.0:
		op += 2.4 * k * pw * (0.5 if casse else 1.0)     # images ambiguës si le cortège casse aussi
	if subjects.has("temoignage"):
		op += 1.3 * k
	if subjects.has("prix"):
		op += 0.8 * k
	if subjects.has("crowd"):
		op += 0.2 * k
		mobv += 4.0 * k
	if casse:
		op -= 1.5 * k                                     # la casse tourne en boucle sur Canal Continu
		Campaign.add_stat("repression", 0.01, "images de casse")
	if op == 0.0 and subjects.is_empty():
		op = 0.05                                         # une vidéo sans rien de fort : presque rien
	var what := _subjects_txt(subjects)
	if op >= 0.0:
		_gain("videos", op, "vidéo publiée")
	else:
		_loss(-op, "vidéo de casse publiée")
	if mobv > 0.0:
		_mob("videos", mobv, "vidéo de la foule")
	var noto := 0.005 if blur else 0.02
	if not blur and (pw > 0.0 or casse):
		noto += 0.03                                      # visages nets : la police remonte jusqu'à l'auteur
	Campaign.add_stat("notoriete", noto, "vidéo publiée" + (" (floutée)" if blur else ""))
	Campaign.log_action("video", "Vidéo publiée : %s (%d s)%s" % [what, int(float(d.get("sec", 0.0))), ", visages floutés" if blur else ""], op)
	if director and director.news:
		var views := int(900.0 * (1.0 + score) * (1.0 + Campaign.stat("opinion") / 25.0) * (2.5 if pw > 0.0 else 1.0))
		director.news.push_social("Ta vidéo", "%s — %s vues en une heure" % [NewsTexts.upper_first(what) if what != "" else "Vidéo", NewsTexts.big_number(views)])
		if pw >= 0.85 and not casse:
			_auto_news("Violences policières : une vidéo tournée dans le quartier des Tanneurs fait réagir. La préfecture « examine les images ».")


# ------------------------------------------------------------------ témoins, caméras
## Monde : gestionnaires des passants et des habitants (cherchés une fois)
func _find() -> void:
	if _searched or director == null or not is_instance_valid(director.main):
		return
	_searched = true
	for c in director.main.get_children():
		if c is Civilians:
			_civ = c
		elif c is Residents:
			_res = c


## Témoins autour d'un point : {people, press, police}
func _witnesses(p: Vector3) -> Dictionary:
	_find()
	var people := 0
	var press := 0
	var cops := 0
	if p != Vector3.INF:
		if _civ and is_instance_valid(_civ):
			for w in _civ.walkers:
				if is_instance_valid(w) and w.global_position.distance_squared_to(p) < 400.0:
					people += 1
		if _res and is_instance_valid(_res):
			for r in _res.residents:
				if is_instance_valid(r) and r.state in ["idle", "out"] and r.global_position.distance_squared_to(p) < 625.0:
					people += 1
		if director and is_instance_valid(director.crowd):
			for n in director.crowd.npcs:
				if is_instance_valid(n) and n.role == "press" and n.global_position.distance_squared_to(p) < 625.0:
					press += 1
		if director and director.cast:
			var lou := director.cast.get_actor("lou")
			if lou != null and is_instance_valid(lou) and lou.is_inside_tree() and lou.global_position.distance_squared_to(p) < 625.0:
				press += 1
		if director and is_instance_valid(director.police):
			for c in director.police.cops:
				if is_instance_valid(c) and c.global_position.distance_squared_to(p) < 900.0:
					cops += 1
	return {"people": people, "press": press, "police": cops}


## Multiplicateur d'image : 0,6 sans personne pour voir, jusqu'à ~1,7 devant du monde et des caméras
func _seen_factor(p: Vector3) -> float:
	if p == Vector3.INF:
		return 1.0
	var w := _witnesses(p)
	return 0.6 + 0.08 * minf(float(w["people"]), 5.0) + 0.35 * minf(float(w["press"]), 2.0)


func _police_sees(p: Vector3) -> bool:
	if p == Vector3.INF:
		return false
	return int(_witnesses(p)["police"]) > 0


func _by_player(d: Dictionary, p: Vector3) -> bool:
	if bool(d.get("player", false)) or str(d.get("by", "")) == "player":
		return true
	var pl: Player = director.player if director else null
	return p != Vector3.INF and pl != null and is_instance_valid(pl) and pl.global_position.distance_to(p) < 3.5


func _pos(d: Dictionary) -> Vector3:
	var v: Variant = d.get("pos", null)
	return v if v is Vector3 else Vector3.INF


# ------------------------------------------------------------------ jauges plafonnées
func _cap() -> Vector2:
	var id := str(director.def.get("id", "")) if director else ""
	return CHAPTER_CAP.get(id, CAP_DEFAULT)


## Gain d'opinion plafonné (par source et par chapitre) ; renvoie le gain appliqué
func gain(source: String, amount: float, why: String) -> float:
	return _gain(source, amount, why)


func _gain(source: String, amount: float, why: String) -> float:
	if amount <= 0.0:
		return 0.0
	var room := minf(float(SOURCE_CAP.get(source, 2.0)) - float(src.get(source, 0.0)), _cap().x - up)
	var g := minf(amount, room)
	if g <= 0.001:
		return 0.0
	src[source] = float(src.get(source, 0.0)) + g
	up += g
	Campaign.add_stat("opinion", g, why)
	return g


func _loss(amount: float, why: String) -> float:
	var l := minf(amount, _cap().y - down)
	if l <= 0.001:
		return 0.0
	down += l
	Campaign.add_stat("opinion", -l, why)
	return l


func _mob(source: String, amount: float, why: String) -> void:
	var room := float(MOB_CAP.get(source, 10.0)) - float(mob.get(source, 0.0))
	var g := minf(amount, room)
	if g <= 0.001:
		return
	mob[source] = float(mob.get(source, 0.0)) + g
	Campaign.add_stat("mobilisation", g, why)


func _log_once(key: String, kind: String, text: String, d := 0.0) -> void:
	if _logged.has(key):
		return
	_logged[key] = true
	Campaign.log_action(kind, text, d)


## Actualité automatique, au plus une toutes les 45 s
func _auto_news(text: String) -> void:
	if _clock - _news_t < 45.0 or director == null or director.news == null:
		return
	_news_t = _clock
	director.news.push(text)


## Fin du chapitre : le terrain du chapitre entre au journal (repris par le JT)
func _on_chapter_finished(_outcome: String) -> void:
	var parts: Array = []
	var t := Campaign.counter("tracts")
	if t > 0:
		parts.append("%d tract%s distribué%s" % [t, "s" if t > 1 else "", "s" if t > 1 else ""])
	var a := Campaign.counter("affiches")
	if a > 0:
		parts.append("%d affiche%s collée%s" % [a, "s" if a > 1 else "", "s" if a > 1 else ""])
	var dsc := Campaign.counter("discussions")
	if dsc > 1:
		parts.append("%d discussions avec des passants" % dsc)
	if not parts.is_empty():
		Campaign.log_action("terrain", NewsTexts.upper_first(", ".join(parts)), float(src.get("tracts", 0.0)) + float(src.get("affiches", 0.0)))


func _subjects_txt(subjects: Array) -> String:
	var out: Array = []
	for s in subjects:
		if SUBJECT_TXT.has(s) and out.size() < 2:
			out.append(SUBJECT_TXT[s])
	return " et ".join(out)


func _who_txt(who: String) -> String:
	match who:
		"mme_ferreira":
			return "Mme Ferreira, 74 ans"
		"", "passant":
			return "un passant"
	return DialogueUI.display_name(who) if who != "" else "un passant"
