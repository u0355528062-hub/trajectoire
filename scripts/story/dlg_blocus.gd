class_name DlgBlocus
extends RefCounted
## Dialogues du chapitre 5 « Blocus » (format : docs/CAMPAGNE.md § 5.3 ; histoire : BIBLE.md § 4.5).

const DLG := {
	"_id": "blocus",
	# ------------------------------------------------------------ l'aube au Zinc
	"aube": [
		{"who": "jo", "text": "Cinq heures cinquante. Premier café de grève. Celui-là, personne le paie.", "anim": "give", "look": "sam"},
		{"who": "nadia", "text": "Les cheminots ont voté cette nuit. Les hôpitaux aussi, en service minimum. On n'est pas seuls.", "anim": "explain", "if": "stat:opinion>=35"},
		{"who": "nadia", "text": "Les autres quartiers ont lâché. Ce matin, c'est nous. Juste nous.", "anim": "sigh", "if": "stat:opinion<35"},
		{"who": "nadia", "text": "J'ai une lettre de Karim. Il dit… il dit de bloquer pour lui aussi. Et qu'il mange mal.", "anim": "sigh", "look": "sam", "if": "karim_prison"},
		{"who": "karim", "text": "Six heures du mat', sobre, et je vais bloquer une station-service. Ma mère est fière, pour une fois.", "anim": "laugh", "if": "!karim_prison"},
		{"who": "sam", "text": "J'ai reçu une convocation au commissariat. Pour la nuit de la nasse. Les caméras.", "if": "sam_fiche"},
		{"who": "ines", "text": "On y va avec un avocat. Pas tout seul. Jamais tout seul.", "anim": "nod", "look": "sam", "if": "sam_fiche"},
		{"who": "lou", "text": "J'ai monté quarante minutes. Le square, les étiquettes, la nasse. Ce matin, je filme la fin.", "anim": "film", "if": "docu_lou"},
		{"who": "lou", "text": "Je filme. Avec le téléphone de ma sœur. Ils ont gardé le mien.", "anim": "film", "if": "ch4_images_confisquees"},
		{"who": "mme_ferreira", "text": "Bonjour tout le monde. J'ai mis deux pulls. On m'a dit que ça pouvait être long.", "anim": "wave", "if": "ch5_ferreira_la"},
		{"who": "jo", "text": "Maria ! À ton âge, sur un blocage ?", "anim": "laugh", "if": "ch5_ferreira_la"},
		{"who": "mme_ferreira", "text": "À mon âge, Joseph, c'est chez moi qu'il fait froid. Dehors, au moins, on est nombreux.", "anim": "shrug", "if": "ch5_ferreira_la"},
		{"who": "nadia", "text": "D'abord la station de la rue de la Forge. Ensuite le boulevard. Personne ne casse rien. Personne.", "anim": "explain"},
	],
	# ------------------------------------------------------------ à la station
	"station": [
		{"who": "narrateur", "text": "Les palettes, les banderoles. Le gérant de la station regarde, les bras croisés. Puis il éteint les pompes lui-même."},
		{"who": "nadia", "text": "Il a coupé les pompes. Lui-même. T'as vu ça ?", "anim": "point"},
	],
	# ------------------------------------------------------------ sur le boulevard
	"automobiliste": [
		{"who": "narrateur", "text": "Une voiture s'arrête devant le blocage. La conductrice baisse la vitre. Blouse bleue sous le manteau."},
		{"who": "narrateur", "text": "« Je suis aide-soignante, je commence à sept heures. Je fais comment, moi ? »"},
		{"choice": [
			{"id": "passer", "text": "La laisser passer", "say": "Écartez les barrières ! Elle va bosser à l'hôpital, on la laisse passer !",
				"set": {"ch5_laisse_passer": true}, "rel": {"nadia": 6, "ines": 4}, "stats": {"opinion": 2}},
			{"id": "bloquer", "text": "Refuser : personne ne passe", "say": "Désolé, madame. Personne passe. C'est aussi pour vous qu'on fait ça.",
				"rel": {"nadia": -4, "karim": 3}, "stats": {"opinion": -2}},
		], "prompt": "Elle attend, le moteur tourne.", "timer": 10.0},
		{"who": "narrateur", "text": "« Merci. Tenez bon. Ma mère aussi, elle a plus de chauffage. »", "if": "ch5_laisse_passer"},
		{"who": "narrateur", "text": "Elle recule, fait demi-tour. Une passante filme la scène.", "if": "!ch5_laisse_passer"},
	],
	# ------------------------------------------------------------ la négociation
	"nego": [
		{"who": "commissaire", "text": "Monsieur Diallo. On se retrouve.", "look": "sam", "if": "riviere_connait_sam"},
		{"who": "commissaire", "text": "Qui parle pour vous, ici ? …Vous ? Bien.", "look": "sam", "if": "!riviere_connait_sam"},
		{"who": "commissaire", "text": "La préfecture veut le boulevard libre à dix heures. Je peux faire ça de deux façons. Je préfère la première.", "anim": "explain"},
		{"who": "sam", "text": "Et la première, c'est quoi ?"},
		{"who": "commissaire", "text": "Vous libérez la station et une voie du boulevard. Une délégation est reçue en préfecture à midi.", "anim": "explain"},
		{"who": "nadia", "text": "Reçue pour entendre qu'on « a été entendus ». On connaît.", "anim": "crossed"},
		{"goto": "arguments"},
	],
	"arguments": [
		{"choice": [
			{"id": "prix", "text": "Parler de la vidéo des prix", "say": "Vous avez vu la vidéo des prix ? Tout le monde l'a vue. Même vos collègues l'ont partagée.",
				"if": ["ch2_publiee", "!ch5_arg_prix"], "set": {"ch5_arg_prix": true}, "goto": "rep_prix"},
			{"id": "theo", "text": "Parler de Théo", "say": "Théo a dix-sept ans. Vos gars lui ont tiré dans la tête. C'est filmé.",
				"if": ["images_sorties", "!ch5_arg_theo"], "set": {"ch5_arg_theo": true}, "goto": "rep_theo"},
			{"id": "ferreira", "text": "Laisser parler Mme Ferreira", "say": "Madame Ferreira, vous voulez lui dire, vous ?",
				"if": ["ch5_ferreira_la", "!ch5_arg_ferreira"], "set": {"ch5_arg_ferreira": true}, "goto": "rep_ferreira"},
			{"id": "nombre", "text": "Montrer la foule", "say": "Regardez derrière moi. Ils sont tous du quartier. Vous allez tous les gazer ?",
				"if": "!ch5_arg_nombre", "set": {"ch5_arg_nombre": true}, "goto": "rep_nombre"},
			{"id": "conclure", "text": "Passer à la décision", "say": "Bon. On a assez parlé.", "goto": "decision"},
		], "prompt": "Rivière attend. Derrière lui, les fourgons."},
	],
	"rep_prix": [
		{"who": "commissaire", "text": "Je l'ai vue. Ma femme me l'a envoyée. …Ça ne change rien à mes ordres.", "anim": "sigh"},
		{"who": "commissaire", "text": "Mais ça change ce que les gens penseront de ces ordres. Je sais.", "look": "sam"},
		{"goto": "arguments"},
	],
	"rep_theo": [
		{"who": "commissaire", "text": "L'inspection générale est saisie. Ce tir n'aurait pas dû avoir lieu.", "anim": "explain"},
		{"who": "commissaire", "text": "Je vous le dis à vous, pas à une caméra. Ce tir n'aurait pas dû avoir lieu.", "look": "sam"},
		{"goto": "arguments"},
	],
	"rep_ferreira": [
		{"who": "mme_ferreira", "text": "Monsieur. J'ai soixante-quatorze ans. J'ai jamais manifesté de ma vie. Ma mère non plus.", "look": "commissaire"},
		{"who": "mme_ferreira", "text": "Ce matin je suis là parce que j'ai plus de chauffage. C'est tout. Vous allez me gazer, moi ?", "anim": "explain"},
		{"who": "commissaire", "text": "…Non, madame. Personne ne va vous gazer.", "anim": "shake_head"},
		{"goto": "arguments"},
	],
	"rep_nombre": [
		{"who": "commissaire", "text": "Je les vois. J'ai cent vingt hommes. Vous êtes plus nombreux. Ça ne m'a jamais arrêté.", "anim": "crossed", "if": "stat:mobilisation<150"},
		{"who": "commissaire", "text": "Je les vois. Et je vois les caméras. Je ne chargerai pas une foule pareille sans ordre écrit.", "anim": "crossed", "if": "stat:mobilisation>=150"},
		{"goto": "arguments"},
	],
	"decision": [
		{"who": "karim", "text": "On recule pas. Pas après tout ça. Pas après Théo.", "anim": "fist", "if": "!karim_prison"},
		{"who": "nadia", "text": "C'est toi qui décides, Sam. Ils t'écoutent. Moi je te suis.", "anim": "nod", "look": "sam"},
		{"choice": [
			{"id": "accord", "text": "Accepter : libérer la station, délégation à midi", "say": "D'accord. On libère la station. Le boulevard reste à nous jusqu'à midi. Et Nadia vient avec moi en préfecture.",
				"set": {"ch5_issue": "accord"}, "rel": {"nadia": 8, "karim": -6}},
			{"id": "tenir", "text": "Refuser : on tient le blocage", "say": "Non. On reste. Assis, sans rien casser. Si vous voulez le boulevard, venez le prendre devant les caméras.",
				"set": {"ch5_issue": "tenir"}, "rel": {"karim": 6, "lou": 4}},
			{"id": "affrontement", "text": "Rompre : pousser le cordon", "say": "On a assez négocié. Tout le monde, on avance !",
				"set": {"ch5_issue": "affrontement"}, "rel": {"nadia": -20, "ines": -12, "karim": 8, "mme_ferreira": -10}},
		], "prompt": "Mille regards dans ton dos.", "timer": 15.0},
	],
	"accord": [
		{"who": "commissaire", "text": "Merci. Vraiment. Midi, à la préfecture. Je vous fais escorter. Sans menottes.", "anim": "nod"},
		{"who": "narrateur", "text": "La station rouvre. Le boulevard, lui, reste plein jusqu'à midi. Les gens dansent sur les passages piétons."},
	],
	"tenir_ok": [
		{"who": "commissaire", "text": "…Je vais appeler la préfecture. Ne bougez pas. Et ne cassez rien, je vous en prie.", "anim": "call"},
		{"who": "narrateur", "text": "Les fourgons ne bougent pas. À neuf heures, ils repartent. Personne n'ose charger une foule pareille."},
	],
	"tenir_dur": [
		{"who": "commissaire", "text": "Je suis désolé, monsieur Diallo.", "anim": "megaphone"},
		{"who": "commissaire", "text": "Ici la police. Première sommation : on va faire usage de la force. Dispersez-vous.", "anim": "megaphone"},
		{"who": "ines", "text": "Restez assis ! Couvrez-vous le visage ! Les médics, avec moi !", "anim": "cover"},
	],
	"affrontement": [
		{"who": "narrateur", "text": "Le premier rang pousse. Les grenades partent avant les sommations finies. Une vitrine éclate derrière."},
		{"who": "nadia", "text": "Non, non, non… Pas comme ça. Pas aujourd'hui.", "anim": "cover"},
	],
	# ------------------------------------------------------------ épilogue : le JT au Zinc
	"jt": [
		{"who": "presentatrice", "text": "Coup de théâtre ce soir : le Premier ministre retire la loi de Stabilité. La grève générale a été suivie dans tout le pays.", "if": "flag:fin_suggeree==greve"},
		{"who": "presentatrice", "text": "Un documentaire tourné dans un quartier de Paris, et le témoignage d'une retraitée, ont été vus douze millions de fois.", "if": "flag:fin_suggeree==greve"},
		{"who": "presentatrice", "text": "Le gouvernement recule : la loi de Stabilité est retirée. Arnaud Vérin parle de « dialogue retrouvé ».", "if": "flag:fin_suggeree==recul"},
		{"who": "presentatrice", "text": "La loi de Stabilité est retirée. Mais la nuit de la nasse laisse des traces : plusieurs procès s'ouvrent la semaine prochaine.", "if": "flag:fin_suggeree==amere"},
		{"who": "presentatrice", "text": "Les blocages se sont levés un à un. Le gouvernement maintient sa loi. Le mouvement, lui, semble s'essouffler.", "if": "flag:fin_suggeree==essoufflement"},
		{"wait": 0.6},
		{"who": "jo", "text": "Éteins pas. Je veux la revoir, celle-là.", "anim": "laugh", "if": "!flag:fin_suggeree==essoufflement"},
		{"who": "nadia", "text": "On était douze, Sam. Douze, dans un square.", "anim": "hug", "look": "sam", "if": "!flag:fin_suggeree==essoufflement"},
		{"who": "jo", "text": "Éteins. J'ai assez entendu cette voix pour l'année.", "anim": "sigh", "if": "flag:fin_suggeree==essoufflement"},
		{"who": "nadia", "text": "On a perdu cette fois. On a appris à se compter, au moins. La prochaine fois, on commencera à cent.", "anim": "explain", "look": "sam", "if": "flag:fin_suggeree==essoufflement"},
		{"who": "nadia", "text": "Et maintenant on s'occupe de Karim. On le laisse pas là-bas.", "anim": "nod", "if": "karim_prison"},
		{"who": "mme_ferreira", "text": "Le premier avril est passé. J'ai rallumé le radiateur. Une heure par jour. C'est déjà ça.", "anim": "laugh", "if": "ch5_ferreira_la"},
		{"choice": [
			{"id": "fin_nous", "text": "« C'était pas moi. C'était nous. »", "say": "C'était pas moi. C'était nous. Tout le quartier."},
			{"id": "fin_suite", "text": "« Et maintenant ? »", "say": "Et maintenant ? On rentre chez nous ?"},
		]},
		{"who": "jo", "text": "Maintenant ? Maintenant tu paies ton café. Je rigole. …Pas aujourd'hui.", "anim": "laugh"},
	],
}
