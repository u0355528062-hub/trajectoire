class_name DlgNasse
extends RefCounted
## Dialogues du chapitre 4 « La nasse » (format : docs/CAMPAGNE.md § 5.3 ; histoire : BIBLE.md § 4.4).

const DLG := {
	"_id": "nasse",
	# ------------------------------------------------------------ avant le départ
	"depart": [
		{"who": "jo", "text": "Ça tombe comme à Brest, ce soir. Vous êtes combien, là ? Quatre-vingts ? Cent ?", "anim": "point", "look": "sam"},
		{"who": "jo", "text": "Écoute-moi bien. Si ça tourne mal, la porte de derrière, rue des Cerisiers. Tu frappes trois fois.", "anim": "explain", "look": "sam"},
		{"who": "sam", "text": "Jo… Tu fais pas de politique, toi."},
		{"who": "jo", "text": "Je fais pas de politique. Je fais un café. Avec une porte de derrière.", "anim": "shrug"},
		{"who": "karim", "text": "Quarante-huit heures, frère. Pour une manche. Rappel à la loi, et mon téléphone, ils l'ont gardé.", "anim": "crossed", "look": "sam", "if": "flag:ch3_karim==gav"},
		{"who": "karim", "text": "T'étais où, toi, pendant qu'ils m'écrasaient la tête ?", "look": "sam", "if": "flag:ch3_karim==gav"},
		{"who": "karim", "text": "La vidéo de Lou m'a sorti en dix heures. Dix heures. Sans elle, j'y serais encore.", "anim": "nod", "if": "flag:ch3_karim==filme"},
		{"who": "karim", "text": "Ce soir je reste à côté de toi. Comme à la mairie. Tu me portes chance.", "anim": "laugh", "if": "flag:ch3_karim==libere"},
		{"who": "nadia", "text": "Le parcours est déclaré, cette fois jusqu'au carrefour. Ils ont accepté. Trop vite, si tu veux mon avis.", "anim": "explain"},
		{"who": "ines", "text": "J'ai deux internes avec moi. Et des lunettes de piscine pour tout le monde. On sait jamais.", "anim": "carry"},
		{"who": "lou", "text": "Sam, si ça part en vrille, on filme tout. Les visages des gens, non. Les gestes, oui.", "anim": "film", "look": "sam"},
	],
	# ------------------------------------------------------------ la nasse
	"nasse": [
		{"who": "lou", "text": "Sam. Derrière. Regarde derrière.", "anim": "point"},
		{"who": "narrateur", "text": "Des fourgons au fond du boulevard. Des casques dans la rue de la Forge. Le cortège est fermé des deux côtés."},
		{"who": "nadia", "text": "Ils nous nassent. Le parcours accepté trop vite… voilà pourquoi.", "anim": "sigh"},
		{"who": "commissaire", "text": "Ici la police. Première sommation : on va faire usage de la force. Dispersez-vous.", "anim": "megaphone"},
		{"who": "karim", "text": "Se disperser où ? Vous avez fermé partout !", "anim": "fist"},
		{"who": "commissaire", "text": "Deuxième sommation : on va faire usage de la force. Dispersez-vous.", "anim": "megaphone"},
	],
	# ------------------------------------------------------------ le tir
	"tir": [
		{"who": "narrateur", "text": "Un claquement sec. Puis un deuxième. Un garçon en K-way rouge tombe sur le trottoir, les mains sur le visage."},
		{"who": "ines", "text": "Laissez-moi passer ! Médic ! Laissez-moi passer !", "anim": "cover"},
		{"who": "ines", "text": "C'est un gamin. Il a dix-sept ans. Théo. Il saigne de l'arcade… l'œil, je sais pas encore.", "anim": "treat"},
		{"who": "ines", "text": "Sam ! J'ai besoin qu'on me fasse de la place. Personne ne me marche dessus pendant que je travaille.", "anim": "treat", "look": "sam"},
		{"who": "lou", "text": "Faut filmer. Le tireur est encore là, on le voit. Sam, si personne filme, ça n'existe pas.", "anim": "film", "look": "sam"},
		{"choice": [
			{"id": "proteger", "text": "Protéger Inès pendant qu'elle soigne", "say": "Reculez ! Faites de la place ! Elle soigne, reculez !",
				"set": {"ch4_protege_ines": true}, "rel": {"ines": 12, "lou": -2}},
			{"id": "filmer", "text": "Filmer le tireur et le blessé", "say": "Je filme. Lou, prends le gamin, je prends le tireur.",
				"set": {"ch4_filme_lbd": true}, "rel": {"lou": 8, "ines": -4}},
		], "prompt": "Inès est à genoux sous la pluie.", "timer": 10.0},
	],
	# ------------------------------------------------------------ Karim part à l'émeute
	"emeute": [
		{"who": "karim", "text": "Ils ont tiré sur un gosse. Un gosse, Sam ! Nous on va à la banque. Ils vont payer quelque chose ce soir.", "anim": "fist", "look": "sam"},
		{"who": "narrateur", "text": "Une vingtaine de silhouettes cagoulées remontent le boulevard. Quelqu'un ramasse des pavés."},
		{"choice": [
			{"id": "retenir", "text": "Retenir Karim", "say": "Karim. Regarde-moi. Si tu y vas, demain on parle de vitrines, pas de Théo. Reste.",
				"if": "rel:karim>=10", "set": {"ch4_karim_retenu": true}, "rel": {"karim": 5, "nadia": 5}, "goto": "retenu"},
			{"id": "retenir_echec", "text": "Essayer de retenir Karim", "say": "Karim, attends ! Reste avec nous, ça sert à rien !",
				"if": "rel:karim<10", "rel": {"karim": -3}, "goto": "parti"},
			{"id": "laisser", "text": "Le laisser partir", "say": "…Fais attention à toi.", "goto": "parti"},
			{"id": "suivre", "text": "Le suivre à la banque", "say": "Attends. Je viens.",
				"set": {"ch4_emeute": true}, "rel": {"karim": 12, "nadia": -15, "ines": -10, "lou": -6}, "goto": "suivre"},
		], "prompt": "Karim recule déjà vers la banque.", "timer": 10.0},
	],
	"retenu": [
		{"who": "karim", "text": "…Putain. T'as raison. T'as raison et je déteste ça.", "anim": "sigh"},
		{"who": "karim", "text": "Je reste. Mais je porte le gamin s'il faut le porter.", "anim": "nod", "look": "ines"},
	],
	"parti": [
		{"who": "karim", "text": "Désolé, frère.", "anim": "shrug"},
		{"who": "narrateur", "text": "Karim disparaît dans la pluie, vers les vitrines du boulevard."},
		{"set": {"ch4_karim_parti": true}},
	],
	"suivre": [
		{"who": "nadia", "text": "Sam ! Sam, non ! Pas toi !", "anim": "reach"},
	],
	"banque": [
		{"who": "narrateur", "text": "Une vitrine éclate. Puis l'alarme. Les phares d'un fourgon tournent au coin. Trois policiers courent vers Karim."},
		{"choice": [
			{"id": "tirer", "text": "Tirer Karim hors de là", "say": "Karim ! Viens ! Lâche ça, viens !",
				"set": {"sam_fiche": true}, "rel": {"karim": 15}, "stats": {"notoriete": 0.15}, "goto": "tire"},
			{"id": "fuir", "text": "Fuir seul", "say": "…",
				"set": {"karim_prison": true}, "rel": {"karim": -25}, "goto": "fui"},
		], "prompt": "Les policiers arrivent.", "timer": 6.0},
	],
	"tire": [
		{"who": "narrateur", "text": "Tu l'attrapes par la capuche. Vous courez. Une caméra sur un lampadaire vous suit tout le long de la rue."},
		{"who": "karim", "text": "T'es revenu me chercher… T'es revenu.", "anim": "rest_knee"},
	],
	"fui": [
		{"who": "narrateur", "text": "Tu cours. Derrière toi, Karim crie ton nom une fois. Puis plus rien."},
	],
	# ------------------------------------------------------------ sortir les images, sortir les gens
	"sortie": [
		{"who": "lou", "text": "Ils commencent à prendre les téléphones à l'entrée du boulevard. Faut sortir les images. Maintenant.", "anim": "phone", "look": "sam"},
		{"who": "nadia", "text": "La rue des Cerisiers. Elle est pas fermée, j'ai vérifié. On fait sortir les gens par là.", "anim": "point", "look": "rue_nord"},
		{"who": "lou", "text": "Prends ma carte mémoire. Toi, ils te fouilleront pas. Enfin, moins que moi.", "anim": "give", "look": "sam"},
		{"choice": [
			{"id": "prendre", "text": "Prendre la carte et guider les gens", "say": "Donne. Tout le monde, par la rue des Cerisiers ! Calmement ! On marche !",
				"rel": {"lou": 6, "nadia": 4}},
			{"id": "lou", "text": "« Garde-la. Je fais sortir les gens. »", "say": "Garde-la, c'est ton travail. Moi je fais sortir les gens.",
				"rel": {"nadia": 6}, "set": {"ch4_lou_garde": true}},
		]},
	],
	"lou_seule": [
		{"who": "narrateur", "text": "Pendant ce temps, au carrefour, des policiers fouillent les sacs. Le téléphone de Lou part dans un sachet."},
		{"set": {"ch4_images_confisquees": true}},
	],
	# ------------------------------------------------------------ au Zinc, la nuit
	"zinc": [
		{"who": "jo", "text": "Trois coups, c'est trois coups. Pas douze. Entrez, entrez. Serviettes sur le comptoir.", "anim": "beckon"},
		{"who": "ines", "text": "Théo est aux urgences. Il gardera son œil. Il a eu de la chance qu'on soit là tout de suite.", "anim": "sigh", "if": "ch4_protege_ines"},
		{"who": "ines", "text": "Théo est aux urgences. Pour l'œil… on saura demain. On m'a bousculée deux fois pendant que je le tenais.", "anim": "sigh", "if": "!ch4_protege_ines"},
		{"who": "lou", "text": "Les images sont sorties. Le tir, le gamin, les sommations dans la nasse. Tout est en ligne.", "anim": "phone", "if": "images_sorties"},
		{"who": "lou", "text": "Ils ont pris mon téléphone. Tout est dedans. Tout.", "anim": "sigh", "if": "ch4_images_confisquees"},
		{"who": "nadia", "text": "Karim passe en comparution immédiate demain matin. L'avocat parle de six mois ferme. Pour une vitrine.", "anim": "sigh", "look": "sam", "if": "karim_prison"},
		{"who": "karim", "text": "Ils vont me retrouver. Les caméras. Toi aussi, ils vont te retrouver, Sam.", "anim": "sit", "if": "sam_fiche"},
		{"who": "jo", "text": "Personne ne retrouve personne ici. Ici, c'est un café. Buvez.", "anim": "give"},
		{"goto": "docu", "if": "images_sorties", "else": "fin"},
	],
	"docu": [
		{"who": "lou", "text": "Sam… Je vais en faire un film. Pas une vidéo. Un film. Du square jusqu'à ce soir.", "anim": "explain", "look": "sam"},
		{"choice": [
			{"id": "oui", "text": "« Fais-le. Je t'aiderai. »", "say": "Fais-le. Et je t'aide. Tout ce que t'as besoin.", "rel": {"lou": 10}, "set": {"ch4_aide_docu": true}},
			{"id": "prudent", "text": "« Attends que ça se calme. »", "say": "Attends un peu. Si on balance tout maintenant, ils vont nous tomber dessus.", "rel": {"lou": -4}},
		]},
		{"goto": "fin"},
	],
	"fin": [
		{"who": "nadia", "text": "Ils voulaient qu'on ait peur. Regarde-nous. On a froid, on est trempés. Mais on a pas peur.", "anim": "explain"},
		{"who": "nadia", "text": "On parle d'une grève générale, le 6 avril. Les cheminots, les hôpitaux, les livreurs. Tout le monde.", "anim": "explain", "if": "stat:opinion>=35"},
		{"who": "nadia", "text": "Les autres quartiers hésitent. Mais nous on bloquera le 6 avril. Même si on est seuls.", "anim": "crossed", "if": "stat:opinion<35"},
	],
}
