class_name DlgPrologue
extends RefCounted
## Dialogues du prologue « La note » (format : docs/CAMPAGNE.md § « Format des dialogues » ; histoire : BIBLE.md).

const DLG := {
	"_id": "prologue",
	# ------------------------------------------------------------ la caisse de la supérette
	"caisse": [
		{"who": "narrateur", "text": "Le Panier du Coin. Pâtes, lait, lessive. Vingt-trois euros quarante."},
		{"who": "narrateur", "text": "« Paiement refusé. »", "wait": 0.4},
		{"who": "sam", "text": "Attendez. Je la remets."},
		{"who": "narrateur", "text": "« Paiement refusé. Solde insuffisant. »", "wait": 0.5},
		{"who": "sam", "text": "…Le virement de la plateforme tombe jeudi. Jeudi."},
		{"choice": [
			{"id": "lessive", "text": "Reposer la lessive", "say": "Je reprends juste le lait et les pâtes. Désolé.", "set": {"ch0_courses": "lait"}},
			{"id": "rien", "text": "Tout reposer", "say": "Laissez. Je repasserai.", "set": {"ch0_courses": "rien"}},
		], "prompt": "La file attend derrière toi."},
		{"who": "narrateur", "text": "Message de Maman : « Pense au lait pour Lina stp. Je rentre à 9 h. Bisous. »", "wait": 0.3},
	],
	# ------------------------------------------------------------ prix de la boulangerie (regard)
	"ardoise": [
		{"who": "sam", "text": "Un euro soixante-cinq, la baguette. Elle était à un euro dix quand j'ai commencé à livrer."},
	],
	# ------------------------------------------------------------ le Zinc
	"zinc": [
		{"who": "jo", "text": "Tiens, le coursier. T'as une tête de lundi.", "anim": "akimbo", "look": "sam"},
		{"who": "sam", "text": "Ma carte vient de se faire refuser au Panier. Pour vingt-trois balles."},
		{"who": "jo", "text": "Bienvenue au club. Assieds-toi, celui-là il est pour moi.", "anim": "give"},
		{"who": "sam", "text": "Jo, t'es pas obligé."},
		{"who": "jo", "text": "Je sais. C'est pour ça que c'est gentil.", "anim": "shrug"},
		{"who": "jo", "text": "Chut. Ça, je veux l'entendre.", "anim": "point", "look": "bar_qg", "wait": 0.3},
		{"who": "presentatrice", "text": "Le Premier ministre Arnaud Vérin a donc engagé ce matin la procédure accélérée sur la loi de Stabilité."},
		{"who": "presentatrice", "text": "Au programme : deux points de TVA en plus, le gel des salaires publics et des minima sociaux pendant trois ans…"},
		{"who": "presentatrice", "text": "…et la fin du bouclier tarifaire sur l'énergie au premier avril. Le gouvernement parle d'un effort « juste et temporaire »."},
		{"who": "jo", "text": "Temporaire. En 95 aussi, c'était temporaire.", "anim": "sigh"},
		{"choice": [
			{"id": "colere", "text": "« C'est du vol. »", "say": "C'est du vol, en fait. Ils nous font les poches et ils appellent ça un effort.",
				"set": {"ch0_reaction": "colere"}, "rel": {"jo": 3}},
			{"id": "resigne", "text": "« Ça changera rien. »", "say": "De toute façon, râler, ça a jamais rien changé.",
				"set": {"ch0_reaction": "resigne"}, "rel": {"jo": -2}},
			{"id": "ironie", "text": "« Juste et temporaire… »", "say": "« Juste et temporaire. » Comme mon contrat, quoi.",
				"set": {"ch0_reaction": "ironie"}, "rel": {"jo": 4}},
		], "prompt": "La télé continue sans le son."},
		{"who": "jo", "text": "T'as raison. Mais dis-le pas trop fort, y a des gens qui t'écoutent.", "anim": "laugh", "if": "flag:ch0_reaction==colere"},
		{"who": "jo", "text": "C'est ce qu'ils veulent que tu penses, gamin. Et ça marche, hein.", "anim": "shake_head", "if": "flag:ch0_reaction==resigne"},
		{"who": "jo", "text": "Ha. Celle-là je la ressortirai.", "anim": "laugh", "if": "flag:ch0_reaction==ironie"},
		{"call": "karim_arrive"},
		{"who": "karim", "text": "Wesh. Vous avez vu ? Vous avez vu le bouffon à la télé ?", "anim": "point", "look": "sam"},
		{"who": "jo", "text": "On a vu. Bonjour, d'abord.", "anim": "crossed"},
		{"who": "karim", "text": "Bonjour Jo. L'agence vient d'appeler. Plus de missions « jusqu'à nouvel ordre ». Le dépôt gèle tout.", "anim": "explain"},
		{"who": "sam", "text": "Sérieux ? Depuis quand ?"},
		{"who": "karim", "text": "Depuis ce matin, frère. Gel des salaires, gel des missions. Ils gèlent tout sauf les prix.", "anim": "explain"},
		{"who": "karim", "text": "Et toi, ta tête ? Ça va pas non plus ?", "if": "flag:ch0_courses==rien"},
		{"who": "sam", "text": "Carte refusée. J'ai même pas pu prendre le lait de Lina.", "if": "flag:ch0_courses==rien"},
		{"who": "karim", "text": "Tu vois. C'est ça que je dis. On peut même plus acheter du lait.", "anim": "fist", "if": "flag:ch0_courses==rien"},
		{"who": "karim", "text": "Faut faire un truc. Pas une pétition, hein. Un vrai truc.", "anim": "fist"},
		{"who": "jo", "text": "Commence par finir ton café. Les vrais trucs, ça se prépare.", "anim": "give"},
	],
	# ------------------------------------------------------------ Mme Ferreira
	"ferreira": [
		{"who": "mme_ferreira", "text": "Oh, mon Dieu… Non, non, c'est rien. C'est le sac.", "anim": "pick"},
		{"who": "karim", "text": "Bonjour Madame Ferreira.", "anim": "wave"},
		{"who": "mme_ferreira", "text": "Bonjour mon grand. Je vous dérange pas, je rentre.", "look": "karim"},
		{"choice": [
			{"id": "aider", "text": "Porter ses sacs jusque chez elle", "say": "Donnez, je vous les monte. J'habite à côté.",
				"set": {"ch0_aide_ferreira": true}, "rel": {"mme_ferreira": 10, "jo": 3}, "goto": "ferreira_aide"},
			{"id": "laisser", "text": "La laisser faire", "say": "Bonne journée, Madame Ferreira.",
				"rel": {"mme_ferreira": -2}, "goto": "ferreira_seule"},
		], "prompt": "Les sacs ont l'air lourds."},
	],
	"ferreira_aide": [
		{"who": "mme_ferreira", "text": "Vous êtes gentil. Le fils Diallo, c'est ça ? Celui du vélo ?", "anim": "nod", "look": "sam"},
		{"who": "sam", "text": "Sam. Oui, c'est moi, le vélo."},
		{"who": "mme_ferreira", "text": "C'est au-dessus de la pharmacie. Doucement, hein, j'ai des œufs."},
	],
	"ferreira_seule": [
		{"who": "jo", "text": "Bouge pas, Maria. Je te les porte, moi.", "anim": "carry"},
		{"who": "mme_ferreira", "text": "Tu vas laisser ton café, Joseph ?"},
		{"who": "jo", "text": "Il sera froid. Comme chez toi, d'ailleurs. Allez, viens.", "anim": "beckon"},
		{"who": "karim", "text": "…Comment ça, comme chez elle ?", "look": "sam"},
		{"who": "sam", "text": "J'sais pas. Je crois qu'elle chauffe plus."},
	],
	# ------------------------------------------------------------ en bas de chez Mme Ferreira
	"porte": [
		{"who": "mme_ferreira", "text": "Voilà. Vous pouvez poser là, dans l'entrée.", "anim": "point"},
		{"who": "sam", "text": "Il fait froid, chez vous. Le radiateur est en panne ?"},
		{"who": "mme_ferreira", "text": "Non. Il marche très bien. C'est moi qui marche pas avec.", "anim": "sigh"},
		{"who": "mme_ferreira", "text": "Cent quatre-vingts euros, la dernière facture. J'ai huit cent douze de pension. Alors je mets mon manteau.", "anim": "warm"},
		{"who": "sam", "text": "Votre fille sait ?"},
		{"who": "mme_ferreira", "text": "Surtout pas. Elle a ses enfants, ses soucis. Et vous non plus, vous dites rien, hein ?", "look": "sam"},
		{"choice": [
			{"id": "promis", "text": "« Promis. »", "say": "Promis. Mais si vous avez besoin, je suis juste en face.", "rel": {"mme_ferreira": 5}},
			{"id": "doute", "text": "« Vous devriez pas rester seule avec ça. »", "say": "Vous devriez pas garder ça pour vous. Vous êtes sûrement pas la seule.",
				"rel": {"mme_ferreira": 2}, "set": {"ch0_ferreira_doute": true}},
		]},
		{"who": "mme_ferreira", "text": "Pas la seule… Ça, je sais bien. Au troisième, ils sont pareils.", "if": "ch0_ferreira_doute"},
		{"who": "mme_ferreira", "text": "Allez, filez. Et merci, Sam.", "anim": "wave"},
	],
	# ------------------------------------------------------------ Nadia à la colonne Morris
	"nadia": [
		{"who": "nadia", "text": "Sam ? Le fils de Mariam ? T'as grandi, toi.", "anim": "wave", "look": "sam"},
		{"who": "sam", "text": "Bonjour. Vous travaillez avec ma mère, c'est ça ? À l'hôpital ?"},
		{"who": "nadia", "text": "Même service, même nuits. Tiens, regarde.", "anim": "point", "look": "morris"},
		{"who": "narrateur", "text": "« LOI DE STABILITÉ : ILS GÈLENT NOS VIES. Rassemblement jeudi, 18 h 30, square des Tanneurs. »"},
		{"who": "sam", "text": "Vous allez être combien ?"},
		{"who": "nadia", "text": "Honnêtement ? Pas beaucoup. Dix. Quinze si y a du soleil.", "anim": "shrug"},
		{"who": "nadia", "text": "Mais faut bien que quelqu'un commence. Sinon on attend que ça passe, et ça passe jamais.", "anim": "explain"},
		{"goto": "nadia_karim", "if": "!flag:ch0_reaction==resigne", "else": "nadia_doute"},
	],
	"nadia_doute": [
		{"who": "sam", "text": "Dix personnes dans un square. Vous croyez que ça va les faire reculer ?"},
		{"who": "nadia", "text": "Non. Dix, non. Mais dix qui en ramènent deux chacun, ça fait trente. Je sais compter, tu vois.", "anim": "explain"},
		{"goto": "nadia_karim"},
	],
	"nadia_karim": [
		{"who": "nadia", "text": "Et ton copain, là, Karim. Il est remonté, hein ? Ramène-le. Mais calme.", "look": "sam"},
		{"choice": [
			{"id": "viendrai", "text": "« Je viendrai. »", "say": "Je viendrai. Jeudi, 18 h 30.",
				"set": {"ch0_promesse": true}, "rel": {"nadia": 10}, "stats": {"mobilisation": 1}},
			{"id": "verrai", "text": "« Je verrai. J'ai des livraisons. »", "say": "Je verrai. Le jeudi soir, c'est le rush des livraisons.",
				"rel": {"nadia": 2}},
			{"id": "pourquoi", "text": "« Pourquoi moi ? »", "say": "Pourquoi vous me demandez à moi ? J'ai jamais fait ça.",
				"goto": "nadia_pourquoi"},
		], "prompt": "Nadia te tend une affiche."},
		{"who": "nadia", "text": "Je compte sur toi, alors. Et dis bonjour à ta mère.", "anim": "nod", "if": "ch0_promesse"},
		{"who": "nadia", "text": "Je comprends. Si t'as cinq minutes, passe quand même.", "anim": "nod", "if": "!ch0_promesse"},
	],
	"nadia_pourquoi": [
		{"who": "nadia", "text": "Justement. Ceux qui l'ont jamais fait, c'est eux qui manquent.", "anim": "explain"},
		{"who": "nadia", "text": "Et puis toi, tu connais tout le quartier. Tu livres la moitié des immeubles.", "anim": "laugh"},
		{"choice": [
			{"id": "ok", "text": "« Bon. Jeudi. »", "say": "Bon. D'accord. Jeudi.",
				"set": {"ch0_promesse": true}, "rel": {"nadia": 8}, "stats": {"mobilisation": 1}},
			{"id": "non", "text": "« Je promets rien. »", "say": "Je promets rien.", "rel": {"nadia": 0}},
		]},
		{"who": "nadia", "text": "Ça me va.", "anim": "nod"},
	],
	# ------------------------------------------------------------ fin
	"fin": [
		{"who": "narrateur", "text": "Le soir même, la vidéo du Premier ministre a fait trois millions de vues. Les commentaires étaient fermés."},
		{"who": "narrateur", "text": "Le jeudi, au square des Tanneurs, ils étaient douze.", "wait": 0.5},
	],
}
