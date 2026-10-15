class_name NewsTexts
extends RefCounted
## Textes des actualités (tout est fictif) : titres de Canal Continu selon le chapitre et l'état de l'opinion,
## répliques de la présentatrice, sondage, publications du réseau social « Fil », écrans d'échec et de fin.
## Le ton de la chaîne suit les sondages (BIBLE § 3) : « grogne » → « mouvement » → « crise ».
## Aussi : formatage des nombres à la française.

const CHANNEL := "CANAL CONTINU"
const NETWORK := "Fil"

## Titres par chapitre : [grogne, mouvement, crise]
const HEADLINES := {
	"prologue": ["Loi de Stabilité : le gouvernement assume, « un effort partagé »",
		"Loi de Stabilité : la grogne monte dans les quartiers populaires",
		"Loi de Stabilité : la colère gronde déjà"],
	"douze": ["Vie chère : une poignée de militants tracte dans le quartier des Tanneurs",
		"Vie chère : les rassemblements se multiplient à Paris",
		"Vie chère : un mouvement parti de rien gagne la capitale"],
	"prix": ["Prix : une vidéo amateur fait le tour des réseaux",
		"« Les prix, en vrai » : la vidéo qui met le gouvernement en difficulté",
		"Vie chère : le témoignage qui bouleverse le pays"],
	"cortege": ["Tensions devant une mairie d'arrondissement à Paris",
		"Premier cortège contre la loi de Stabilité : la mobilisation s'organise",
		"Loi de Stabilité : le mouvement s'invite devant les mairies"],
	"nasse": ["Nuit agitée à Paris : des dégradations dans le quartier des Tanneurs",
		"Nasse, LBD : la gestion du maintien de l'ordre en question",
		"Lycéen blessé par un LBD : le gouvernement sous pression"],
	"blocus": ["Blocages : la France qui se lève tôt prise en otage ?",
		"Grève générale : le pays au ralenti",
		"Grève générale : le gouvernement au pied du mur"],
}
## Mot-clé de l'incrustation, par chapitre
const KEYWORD := {"prologue": "VIE CHÈRE", "douze": "MOBILISATION", "prix": "VIE CHÈRE", "cortege": "MANIFESTATION",
	"nasse": "MAINTIEN DE L'ORDRE", "blocus": "GRÈVE GÉNÉRALE"}
## Pseudos du réseau Fil (inventés)
const HANDLES := ["@marie.t75", "@kevin_bzh", "@sophie_infirmiere", "@lebaron_du_92", "@nadege.l", "@tonton_rachid",
	"@coralie_v", "@yannick.dupuis", "@la_boulangere", "@etudiant_precaire", "@mamie_rose", "@jb_routier"]
## Publications selon le genre du fait marquant (journal) : [texte, pour ou contre le mouvement]
const POSTS := {
	"video": ["Regardez jusqu'au bout. Et après dites-moi qu'on exagère.", "Partagez avant que ça disparaisse."],
	"police": ["Un gamin de 17 ans. Un LBD. Et on nous parle d'ordre républicain ?", "Je suis infirmière. Ce que j'ai vu hier soir, je l'oublierai pas."],
	"casse": ["Casser les vitrines du quartier, c'est ça la lutte ? Les commerçants vont payer.", "Moi je soutenais. Mais là, les voitures brûlées, non."],
	"non_violence": ["Assis sous les gaz sans répondre. Respect à eux.", "Personne n'a rien cassé. Et c'est la police qui a reculé."],
	"temoignage": ["Cette dame, c'est ma grand-mère. C'est toutes nos grands-mères.", "812 € de pension et le chauffage coupé. En 2027."],
	"terrain": ["Un gars m'a tendu un tract devant la boulangerie. On a parlé dix minutes. J'y serai jeudi.", "Des affiches partout sur la colonne Morris du quartier. Ça bouge."],
	"blocage": ["Coincé au blocage ce matin. Ils m'ont offert un café et expliqué. Je comprends.", "Bloquer les gens qui bossent, super idée…"],
	"sitin": ["Quarante personnes assises devant la mairie. Calmes. Dignes.", "Le sit-in devant la mairie, c'était beau."],
	"pro": ["2,79 € le gazole. Et on devrait se taire ?", "Gel des salaires, TVA en hausse. Faut pas s'étonner.", "Ma fille est aide-soignante, elle fait des ménages le week-end. Voilà."],
	"contre": ["Encore des blocages… Certains travaillent.", "Toujours les mêmes qui râlent.", "Le gouvernement a raison de tenir bon."],
}
## Fins (BIBLE § 6)
const ENDINGS := {
	"greve": {"title": "La grève", "tag": "Fin cachée",
		"lines": ["Le documentaire de Lou passe partout. La voix de Mme Ferreira aussi : « Je demande pas la charité. Je demande à avoir chaud. »",
			"Les dépôts, les hôpitaux, les raffineries suivent. En dix jours, la grève devient nationale.",
			"La loi de Stabilité est abandonnée. Le gouvernement Vérin tombe dans la foulée."],
		"tv": "Démission du gouvernement : la grève a eu raison de la loi de Stabilité"},
	"recul": {"title": "Le recul", "tag": "Fin",
		"lines": ["Vingt-trois jours après le premier tract, la ministre Morvan annonce le « report sine die » de la loi de Stabilité.",
			"Au Zinc, Jo offre la tournée. Nadia pleure un peu, puis fait semblant que non.",
			"Rien n'est réglé : les prix restent hauts. Mais le quartier sait maintenant qu'il peut faire reculer quelqu'un."],
		"tv": "Le gouvernement retire la loi de Stabilité"},
	"amere": {"title": "Victoire amère", "tag": "Fin",
		"lines": ["La loi est retirée. Sur le boulevard des Ormes, les vitrines sont encore en contreplaqué.",
			"Il y a les procès qui arrivent, les noms dans les fichiers, les absents à la table du Zinc.",
			"On a gagné. Ça n'a pas le goût qu'on imaginait."],
		"tv": "Loi de Stabilité retirée : le gouvernement cède, les procès commencent"},
	"essoufflement": {"title": "L'essoufflement", "tag": "Fin",
		"lines": ["Les cortèges rétrécissent. Canal Continu passe à autre chose.",
			"La loi s'applique au 1er avril. Les convocations au tribunal arrivent par la poste.",
			"Nadia repart en tournée de nuit. « On recommencera. Mieux. » Personne ne sait si elle y croit."],
		"tv": "Loi de Stabilité : le mouvement s'essouffle, la réforme s'applique"},
}
## Écrans d'échec : raison -> [tampon, texte]
const FAILURES := {
	"arrested": ["GARDE À VUE", "Interpellé. Vingt-quatre heures au commissariat, le téléphone sous scellés, une convocation au tribunal. Ta mère est venue te chercher au petit matin, sans un mot."],
	"timer": ["TROP TARD", "Le moment est passé. Le quartier ne t'a pas attendu."],
	"tension": ["ÇA A DÉGÉNÉRÉ", "La situation a échappé à tout le monde. Ce soir, Canal Continu ne parlera que de ça."],
}


# ------------------------------------------------------------------ nombres
## « +0,4 », « −2 » (virgule décimale, vrai signe moins)
static func signed(v: float, decimals := 1) -> String:
	var s := ("%." + str(decimals) + "f") % absf(v)
	s = s.replace(".", ",")
	if absf(v) < pow(10.0, -decimals) * 0.5:
		return "0"
	return ("+" if v > 0.0 else "−") + s


## « 12 400 », « 1,2 million »
static func big_number(n: int) -> String:
	if n >= 1000000:
		return ("%.1f" % (n / 1000000.0)).replace(".", ",") + " million" + ("s" if n >= 2000000 else "")
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


static func upper_first(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


# ------------------------------------------------------------------ journal télévisé
## 0 : « grogne », 1 : « mouvement », 2 : « crise »
static func tone(opinion: float) -> int:
	return 0 if opinion < 30.0 else (1 if opinion < 50.0 else 2)


static func headline(ch_id: String, opinion: float) -> String:
	var h: Array = HEADLINES.get(ch_id, ["Vie chère : la grogne continue", "Vie chère : le mouvement continue", "Vie chère : la crise s'installe"])
	return str(h[tone(opinion)])


static func keyword(ch_id: String) -> String:
	return str(KEYWORD.get(ch_id, "VIE CHÈRE"))


## Faits marquants du chapitre pour le JT : les plus forts d'abord (|d|), hors entrées techniques
static func highlights(entries: Array, n := 4) -> Array:
	var out := entries.filter(func(e): return str(e.get("kind", "")) not in ["chapitre", "echec"] and str(e.get("text", "")) != "")
	out.sort_custom(func(a, b): return absf(float(a.get("d", 0.0))) > absf(float(b.get("d", 0.0))))
	return out.slice(0, n)


## Répliques de la présentatrice (2 ou 3)
static func anchor_lines(ch_id: String, opinion: float, op_delta: float, mob: float, entries: Array) -> Array:
	var t := tone(opinion)
	var out: Array = []
	out.append(["Bonsoir. La loi de Stabilité continue de faire réagir, avec ce que certains appellent déjà une « grogne ».",
		"Bonsoir. Le mouvement contre la loi de Stabilité ne faiblit pas.",
		"Bonsoir. Le pays traverse ce soir une crise sociale d'une ampleur rare."][t])
	var pts := int(round(absf(op_delta)))
	var trend := "stable" if pts == 0 else ("%s de %d point%s" % ["en hausse" if op_delta > 0.0 else "en baisse", pts, "s" if pts > 1 else ""])
	out.append("Selon notre sondage, %d %% des Français soutiennent le mouvement, %s. Les organisateurs revendiquent %s personnes prêtes à descendre dans la rue." % [int(round(opinion)), trend, big_number(int(round(mob)))])
	var top := highlights(entries, 1)
	if not top.is_empty():
		out.append("Dans le quartier des Tanneurs, à Paris : %s." % _lower_first(str(top[0].get("text", "")).trim_suffix(".")))
	if ch_id == "blocus":
		out.append("Le gouvernement doit s'exprimer dans la soirée.")
	return out


static func _lower_first(s: String) -> String:
	if s.length() > 1 and s.substr(1, 1) == s.substr(1, 1).to_lower():
		return s.left(1).to_lower() + s.substr(1)
	return s


## Sondage : [oui, non, ne se prononcent pas] (somme 100)
static func poll(opinion: float) -> Array:
	var nsp := clampf(14.0 - absf(opinion - 50.0) * 0.12, 5.0, 14.0)
	var oui := clampf(opinion, 0.0, 100.0 - nsp)
	return [int(round(oui)), int(round(100.0 - nsp - oui)), int(round(nsp))]


## Publications « Fil » : [{handle, text, likes, pro}] d'après les faits du chapitre et l'opinion
static func social_posts(entries: Array, opinion: float, seed_v: int, n := 2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var kinds: Array = []
	for e in highlights(entries, 6):
		var k := str(e.get("kind", ""))
		if k in ["lbd", "interpellation", "heurts"] and float(e.get("d", 0.0)) >= 0.0:
			k = "police"
		elif k in ["heurts", "violence"]:
			k = "casse"
		elif k == "sortie":
			k = "non_violence"
		if POSTS.has(k) and not kinds.has(k):
			kinds.append(k)
	kinds.append("pro" if opinion >= 35.0 or rng.randf() < 0.5 else "contre")
	var out: Array = []
	var used: Array = []
	for k in kinds:
		if out.size() >= n:
			break
		var pool: Array = POSTS[k]
		var h := str(HANDLES[rng.randi_range(0, HANDLES.size() - 1)])
		while used.has(h):
			h = str(HANDLES[rng.randi_range(0, HANDLES.size() - 1)])
		used.append(h)
		var likes := int((200.0 + rng.randf() * 900.0) * (1.0 + opinion / 12.0))
		out.append({"handle": h, "text": str(pool[rng.randi_range(0, pool.size() - 1)]), "likes": likes, "pro": k != "casse" and k != "contre"})
	return out


## Fin : {title, tag, lines, tv} (+ destins des personnages selon les drapeaux)
static func ending(id: String) -> Dictionary:
	var e: Dictionary = (ENDINGS.get(id, ENDINGS["essoufflement"]) as Dictionary).duplicate(true)
	var fates: Array = []
	if bool(Campaign.flag("karim_prison", false)):
		fates.append(["Karim", "Six mois ferme. Sam lui écrit tous les dimanches."])
	elif bool(Campaign.flag("ch4_karim_retenu", false)) or bool(Campaign.flag("ch1_karim_retenu", false)):
		fates.append(["Karim", "Il a repris l'intérim. Il colle encore des affiches, la nuit, « pour le plaisir »."])
	else:
		fates.append(["Karim", "Il dit qu'il a rien regretté. Il a quand même arrêté de courir devant."])
	fates.append(["Nadia", "Élue déléguée régionale de l'USS. Toujours de nuit, toujours fatiguée."] if id in ["greve", "recul", "amere"] else ["Nadia", "De retour à l'hôpital. Elle garde les tracts dans un carton, « pour la prochaine »."])
	if bool(Campaign.flag("docu_lou", false)):
		fates.append(["Lou", "Son documentaire est sélectionné en festival. Elle refuse les plateaux de Canal Continu."])
	else:
		fates.append(["Lou", "Elle continue de filmer. Les images de la nasse sont dans un disque dur, quelque part."])
	if bool(Campaign.flag("temoignage_ferreira", false)):
		fates.append(["Mme Ferreira", "Les voisins ont payé son fioul. Elle dit que c'est « trop », et elle a chaud."])
	if bool(Campaign.flag("sam_fiche", false)) or Campaign.stat("notoriete") >= 0.6:
		fates.append(["Sam", "Fiché. Chaque contrôle d'identité dure un peu plus longtemps qu'avant."])
	else:
		fates.append(["Sam", "Il livre toujours à vélo. Les gens du quartier le saluent, maintenant."])
	e["fates"] = fates
	return e


static func failure(reason: String) -> Array:
	if FAILURES.has(reason):
		return FAILURES[reason]
	return ["CHAPITRE RATÉ", upper_first(reason) if reason != "" else "Ça ne s'est pas passé comme prévu."]
