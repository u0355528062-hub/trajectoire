class_name DlgDouze
extends RefCounted
## Dialogues du chapitre 1 « On était douze » (format : docs/CAMPAGNE.md § 5.3 ; histoire : BIBLE.md § 4.1).

const DLG := {
	"_id": "douze",
	# ------------------------------------------------------------ arrivée au square
	"accueil": [
		{"who": "nadia", "text": "Ponctuel. Ta mère serait fière.", "anim": "wave", "look": "sam", "if": "ch0_promesse"},
		{"who": "nadia", "text": "Ah ! T'es venu, finalement. Les livraisons attendront.", "anim": "wave", "look": "sam", "if": "!ch0_promesse"},
		{"who": "karim", "text": "Je l'ai traîné. Il voulait pas rater le match.", "anim": "laugh", "look": "nadia"},
		{"who": "sam", "text": "C'est pas vrai. Enfin, un peu."},
		{"who": "nadia", "text": "Neuf, dix, onze… Douze. Avec vous deux, on est douze.", "anim": "point"},
		{"who": "karim", "text": "Douze. Le gouvernement tremble, là.", "anim": "shrug"},
		{"who": "nadia", "text": "Rigole. En 2019, on a commencé à six, à l'hôpital. On a fini à quatre cents.", "anim": "explain", "look": "karim"},
		{"who": "nadia", "text": "Bon. Le plan. Des tracts pour les gens qui passent, des affiches pour ceux qui passeront.", "anim": "explain", "look": "sam"},
		{"who": "nadia", "text": "Les affiches, sur la colonne Morris et les panneaux d'affichage libre. Pas sur les murs.", "anim": "point", "look": "morris"},
		{"who": "karim", "text": "Pourquoi pas sur les murs ?"},
		{"who": "nadia", "text": "Parce que c'est soixante-huit euros d'amende, et que les gens détestent qu'on salisse leur immeuble.", "anim": "crossed"},
		{"choice": [
			{"id": "pret", "text": "« Je prends les tracts. »", "say": "Donne, je prends les tracts. Les gens me connaissent, je les livre.", "rel": {"nadia": 3}},
			{"id": "trac", "text": "« Je sais pas trop quoi leur dire. »", "say": "Je sais pas trop quoi leur dire, moi, aux gens.", "goto": "conseil"},
		]},
	],
	"conseil": [
		{"who": "nadia", "text": "Tu leur dis pas un discours. Tu leur demandes combien ils paient leur électricité.", "anim": "explain"},
		{"who": "nadia", "text": "Ils vont te répondre. Tout le monde a envie d'en parler, personne ne demande.", "anim": "nod"},
		{"set": {"ch1_conseil_nadia": true}},
	],
	# ------------------------------------------------------------ Karim devant la banque
	"banque": [
		{"who": "karim", "text": "Regarde-moi ça. Banque Hexa. Deux milliards de bénéfices l'an dernier.", "anim": "point", "look": "banque"},
		{"who": "karim", "text": "Et nous on colle des affiches légales. Sur les panneaux prévus. Comme des gentils.", "anim": "explain", "look": "sam"},
		{"who": "sam", "text": "Tu veux faire quoi ?"},
		{"who": "karim", "text": "Un mot. Un seul. Gros. Sur la vitrine. Qu'ils le voient en ouvrant demain.", "anim": "spray"},
		{"who": "karim", "text": "Toi qui disais que râler, ça change rien… Ben voilà, je râle plus. J'agis.", "if": "flag:ch0_reaction==resigne"},
		{"choice": [
			{"id": "dissuader", "text": "L'en dissuader", "say": "Laisse tomber. Si on se fait choper le premier jour, Nadia nous tue. Et elle aura raison.",
				"set": {"ch1_karim_retenu": true}, "rel": {"karim": -5, "nadia": 5}, "goto": "dissuade"},
			{"id": "taguer", "text": "Taguer avec lui", "say": "Vas-y. Mais vite. Je fais le guet, après je m'y mets.",
				"set": {"ch1_tag_banque": true, "ch1_tag": true}, "rel": {"karim": 10, "nadia": -8}, "stats": {"notoriete": 0.05}, "goto": "tag"},
			{"id": "laisser", "text": "Le laisser faire, sans toi", "say": "Fais ce que tu veux. Moi, j'y retourne.",
				"set": {"ch1_tag_karim": true, "ch1_tag": true}, "rel": {"karim": -2}, "goto": "seul"},
		], "prompt": "Karim a déjà la bombe dans la manche."},
	],
	"dissuade": [
		{"who": "karim", "text": "T'es sérieux ? …Ouais. Ouais, t'es sérieux.", "anim": "sigh"},
		{"who": "karim", "text": "OK. Mais le jour où ça sert à rien, les affiches, tu me le dis.", "anim": "crossed", "look": "sam"},
		{"who": "sam", "text": "Promis. Viens, on fait le carrefour. Y a du monde au métro."},
	],
	"tag": [
		{"who": "karim", "text": "Ah ! Je savais. Je savais qu'il y avait un vrai mec là-dessous.", "anim": "laugh"},
	],
	"seul": [
		{"who": "karim", "text": "Comme tu veux, Monsieur Légal.", "anim": "shrug"},
	],
	# ------------------------------------------------------------ la patrouille
	"patrouille": [
		{"who": "nadia", "text": "Une voiture. Personne ne court, personne ne crie. On fait rien de mal.", "anim": "explain", "look": "sam"},
		{"who": "karim", "text": "…Ils ralentissent. Ils regardent la banque.", "if": "ch1_tag"},
		{"choice": [
			{"id": "calme", "text": "Continuer à tracter, calmement", "say": "Bonsoir. Un tract ? Non ? Bonne soirée.",
				"rel": {"nadia": 5}, "stats": {"opinion": 0.5}},
			{"id": "filmer", "text": "Sortir ton téléphone et filmer", "say": "Je filme. Juste au cas où.",
				"set": {"ch1_filme_patrouille": true}, "rel": {"nadia": -2}},
			{"id": "vanne", "text": "Lancer une vanne aux policiers", "say": "Vous voulez un tract, messieurs ? Y a vos salaires gelés aussi, dedans !",
				"set": {"ch1_vanne": true}, "rel": {"nadia": -6, "karim": 6}, "stats": {"notoriete": 0.05}},
		], "prompt": "La voiture roule au pas.", "timer": 10.0},
		{"who": "nadia", "text": "Voilà. Ils sont passés. C'est tout ce qu'ils voulaient : qu'on les voie.", "anim": "nod", "if": "!ch1_vanne"},
		{"who": "nadia", "text": "T'es content ? Maintenant ils connaissent ta tête. Pour un tract.", "anim": "shake_head", "if": "ch1_vanne"},
		{"who": "karim", "text": "Il était bien, son tract.", "anim": "laugh", "if": "ch1_vanne"},
	],
	# ------------------------------------------------------------ Inès
	"ines": [
		{"who": "ines", "text": "Pardon, pardon. Garde de douze heures. C'est fini, j'ai tout raté ?", "anim": "wave"},
		{"who": "nadia", "text": "Inès ! Treize, alors. Sam, Inès. Elle est interne aux urgences.", "anim": "point"},
		{"who": "ines", "text": "Salut. T'as distribué combien ?", "look": "sam"},
		{"who": "sam", "text": "Assez pour savoir que les gens ont pas envie d'en parler… et puis si, en fait."},
		{"who": "ines", "text": "C'est pareil aux urgences. Les gens disent que ça va, et ils sont là depuis six heures.", "anim": "laugh"},
		{"who": "ines", "text": "Je viendrai avec ma trousse, aux prochains. On sait jamais.", "anim": "explain"},
		{"choice": [
			{"id": "aider", "text": "« Je peux t'aider, si besoin. »", "say": "Si t'as besoin de bras pour porter ton sac, je suis là.",
				"set": {"ch1_aide_ines": true}, "rel": {"ines": 8}},
			{"id": "pourquoi", "text": "« Une trousse ? Pour un rassemblement ? »", "say": "Une trousse ? Pour douze personnes dans un square ?",
				"rel": {"ines": 2}, "goto": "ines_trousse"},
		]},
		{"who": "ines", "text": "Je note. Le premier qui tombe, c'est toi qui le portes.", "anim": "laugh", "if": "ch1_aide_ines"},
	],
	"ines_trousse": [
		{"who": "ines", "text": "Aujourd'hui, douze. Mais si Nadia a raison, un jour on sera mille. Et ce jour-là, ils seront nerveux.", "anim": "explain"},
		{"who": "ines", "text": "J'ai vu des gens arriver aux urgences avec la main en morceaux. Je préfère avoir la trousse.", "anim": "sigh"},
	],
	# ------------------------------------------------------------ bilan au square
	"bilan": [
		{"who": "nadia", "text": "Bon. Le compte. Combien de tracts ?", "anim": "crossed"},
		{"who": "sam", "text": "Pas assez. Mais une dame m'a demandé où on se retrouve la prochaine fois."},
		{"who": "nadia", "text": "Ça, c'est le seul chiffre qui compte.", "anim": "nod"},
		{"who": "nadia", "text": "Et la vitrine de la banque, je veux pas savoir. Mais demain, tout le monde saura.", "anim": "shake_head", "look": "karim", "if": "ch1_tag"},
		{"who": "karim", "text": "Ils sauront qu'on existe, au moins.", "if": "ch1_tag"},
		{"who": "nadia", "text": "Samedi, y a une copine qui fait des vidéos. Lou. Elle veut filmer les prix. Vous venez ?", "anim": "explain"},
		{"choice": [
			{"id": "oui", "text": "« On sera là. »", "say": "On sera là.", "rel": {"nadia": 3}, "stats": {"mobilisation": 1}},
			{"id": "karim", "text": "« Seulement si Karim vient. »", "say": "Seulement si Karim vient. Hein, Karim ?", "rel": {"karim": 4}},
		]},
		{"who": "karim", "text": "Si y a des vidéos, je veux être dedans. De dos.", "anim": "laugh"},
	],
}
