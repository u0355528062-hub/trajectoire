class_name DlgCortege
extends RefCounted
## Dialogues du chapitre 3 « Premier cortège » (format : docs/CAMPAGNE.md § 5.3 ; histoire : BIBLE.md § 4.3).

const DLG := {
	"_id": "cortege",
	# ------------------------------------------------------------ le départ du square
	"depart": [
		{"who": "nadia", "text": "J'ai compté deux fois. On est plus de quarante. Quarante, Sam !", "anim": "cheer", "look": "sam", "if": "stat:mobilisation>=40"},
		{"who": "nadia", "text": "J'ai compté deux fois. Une trentaine. Le double de jeudi.", "anim": "nod", "look": "sam", "if": "stat:mobilisation<40"},
		{"who": "karim", "text": "Y a même la boulangère. Elle a fermé plus tôt.", "anim": "point"},
		{"who": "lou", "text": "La vidéo a ramené du monde. Y a des gens que j'ai jamais vus.", "anim": "film", "if": "ch2_publiee"},
		{"who": "lou", "text": "Mme Ferreira a eu des messages horribles, hier. Elle a quand même descendu son balcon pour nous voir partir.", "anim": "point", "if": "flag:ch2_video==nette"},
		{"who": "ines", "text": "J'ai la trousse. Sérum, compresses, couverture de survie. Espérons qu'elle reste fermée.", "anim": "carry"},
		{"who": "nadia", "text": "Le parcours est déclaré jusqu'au parvis de la mairie. On marche, on chante, on s'arrête au parvis. Point.", "anim": "explain"},
		{"goto": "megaphone_oui", "if": "ch0_promesse", "else": "megaphone_doute"},
	],
	"megaphone_oui": [
		{"who": "nadia", "text": "Et c'est toi qui mènes. T'as tenu parole depuis le début. Tiens.", "anim": "give", "look": "sam"},
		{"who": "sam", "text": "Moi ? Au mégaphone ? Nadia, j'ai jamais…"},
		{"who": "nadia", "text": "Personne n'a jamais, la première fois. Phrases courtes. Et tu respires entre.", "anim": "laugh"},
		{"set": {"ch3_megaphone": true}},
	],
	"megaphone_doute": [
		{"who": "nadia", "text": "Il faudrait quelqu'un au mégaphone. Quelqu'un que le quartier connaît.", "anim": "explain", "look": "sam"},
		{"choice": [
			{"id": "prendre", "text": "« Donne. Je le fais. »", "say": "Donne. Je le fais.",
				"set": {"ch3_megaphone": true}, "rel": {"nadia": 8}},
			{"id": "refuser", "text": "« Fais-le, toi. Je porte la banderole. »", "say": "Fais-le, toi. Moi je porte la banderole avec Karim.",
				"rel": {"nadia": -2, "karim": 3}},
		]},
		{"who": "nadia", "text": "Phrases courtes. Et tu respires entre.", "anim": "give", "if": "ch3_megaphone"},
		{"who": "nadia", "text": "D'accord. Mais reste devant, hein.", "anim": "nod", "if": "!ch3_megaphone"},
	],
	# ------------------------------------------------------------ le cordon
	"cordon": [
		{"who": "commissaire", "text": "Mesdames, messieurs, ici la police. Le parvis de la mairie est interdit ce soir. Restez sur le boulevard.", "anim": "megaphone"},
		{"who": "nadia", "text": "Le parcours est déclaré ! Jusqu'au parvis ! J'ai le récépissé de la préfecture !", "anim": "sign"},
		{"who": "commissaire", "text": "La préfecture a modifié le parcours à seize heures, madame. Vous avez reçu le courriel.", "anim": "megaphone"},
		{"who": "nadia", "text": "À seize heures. Pour une manif à dix-neuf. Évidemment.", "anim": "sigh", "look": "sam"},
		{"who": "karim", "text": "Ils sont vingt. On est quarante. On passe.", "anim": "fist", "look": "sam"},
		{"who": "ines", "text": "Karim. Regarde leurs mains. Ils attendent que ça.", "anim": "point", "look": "karim"},
		{"who": "nadia", "text": "On s'assoit. Tous. Ici. Ils veulent nous arrêter au boulevard ? On reste au boulevard. Toute la nuit s'il faut.", "anim": "explain"},
		{"choice": [
			{"id": "sitin", "text": "Sit-in : tout le monde s'assoit", "say": "Tout le monde s'assoit ! On bouge plus ! On est chez nous !",
				"set": {"ch3_choix": "sitin"}, "rel": {"nadia": 10, "ines": 5, "karim": -5}},
			{"id": "forcer", "text": "Forcer le cordon avec Karim", "say": "On passe ! Le parvis est à nous ! Avancez !",
				"set": {"ch3_choix": "forcer"}, "rel": {"karim": 10, "nadia": -15, "ines": -8}, "stats": {"notoriete": 0.1}},
		], "prompt": "Quarante personnes te regardent.", "timer": 12.0},
	],
	"sitin": [
		{"who": "narrateur", "text": "Une personne s'assoit. Puis dix. Puis tout le monde. Le bitume est froid."},
		{"who": "lou", "text": "Ça, c'est une image. Des gens assis, des boucliers debout. Je la tiens.", "anim": "film"},
	],
	"forcer": [
		{"who": "narrateur", "text": "Le premier rang pousse. Le cordon ne recule pas d'un centimètre. Les boucliers se lèvent."},
		{"who": "commissaire", "text": "Première sommation : on va faire usage de la force. Dispersez-vous.", "anim": "megaphone"},
		{"who": "ines", "text": "Reculez ! Ils vont gazer ! Couvrez-vous le visage !", "anim": "cover"},
	],
	# ------------------------------------------------------------ Karim interpellé
	"arrestation": [
		{"who": "narrateur", "text": "Un policier repousse une femme du premier rang. Karim l'attrape par la manche. Trois policiers sortent du cordon."},
		{"who": "karim", "text": "Lâchez-moi ! J'ai rien fait ! Sam !", "anim": "surrender"},
		{"choice": [
			{"id": "intervenir", "text": "Intervenir", "say": "Lâchez-le ! Il a rien fait ! Il voulait juste la protéger !",
				"set": {"ch3_intervenu": true}, "rel": {"karim": 12}, "stats": {"notoriete": 0.1}, "goto": "intervenir"},
			{"id": "filmer", "text": "Filmer l'interpellation", "say": "Lou ! Lou, filme ! Je filme aussi !",
				"set": {"ch3_karim": "filme"}, "rel": {"lou": 8, "karim": -3}, "goto": "filmer"},
			{"id": "laisser", "text": "Ne pas bouger", "say": "…",
				"set": {"ch3_karim": "gav"}, "rel": {"karim": -15}, "goto": "laisser"},
		], "prompt": "Karim est plaqué au sol.", "timer": 8.0},
	],
	"intervenir": [
		{"goto": "intervenir_ok", "if": "flag:ch3_choix==sitin", "else": "intervenir_rate"},
	],
	"intervenir_ok": [
		{"who": "commissaire", "text": "Stop. Lâchez-le. …J'ai dit lâchez-le. Ce soir, on n'interpelle pas pour une manche.", "anim": "point"},
		{"who": "commissaire", "text": "Vous. Oui, vous, au mégaphone. Vous les tenez, vos gens ? Alors tenez-les.", "look": "sam", "if": "ch3_megaphone"},
		{"who": "commissaire", "text": "Vous. Ramenez votre ami derrière. Et qu'il reste assis.", "look": "sam", "if": "!ch3_megaphone"},
		{"set": {"ch3_karim": "libere", "riviere_connait_sam": true}},
	],
	"intervenir_rate": [
		{"who": "narrateur", "text": "Un bouclier te repousse. Tu tombes. Quand tu te relèves, Karim est déjà dans le fourgon."},
		{"who": "commissaire", "text": "Vous, reculez. Je vous ai vu pousser tout à l'heure. Je ne vous le dirai pas deux fois.", "look": "sam"},
		{"set": {"ch3_karim": "gav", "riviere_connait_sam": true}},
	],
	"filmer": [
		{"who": "narrateur", "text": "Deux téléphones filment. On voit le policier pousser la femme. On voit Karim tendre la main. On voit les trois autres."},
		{"who": "lou", "text": "J'ai tout. Le début aussi. Ça va le sortir de là, ça. Ça va le sortir.", "anim": "film"},
	],
	"laisser": [
		{"who": "narrateur", "text": "Tu ne bouges pas. Personne ne bouge. Le fourgon démarre."},
		{"who": "ines", "text": "Ils l'emmènent au commissariat de l'arrondissement. Je connais un avocat. J'appelle.", "anim": "call"},
	],
	# ------------------------------------------------------------ après
	"apres": [
		{"who": "commissaire", "text": "Diallo, c'est ça ? Le livreur. On s'est déjà croisés sur un carnet de mes collègues.", "look": "sam", "if": "ch2_accroche"},
		{"who": "commissaire", "text": "Je fais mon travail, monsieur. Ce soir il n'y a pas eu de blessé. Je compte bien que ça dure.", "anim": "explain", "look": "sam", "if": "riviere_connait_sam"},
		{"who": "karim", "text": "Merci, frère. J'te dois une. Une grosse.", "anim": "hug", "look": "sam", "if": "flag:ch3_karim==libere"},
		{"who": "lou", "text": "Je publie l'interpellation cette nuit. Avec le début, le policier qui pousse. Karim sera dehors demain.", "anim": "phone", "if": "flag:ch3_karim==filme"},
		{"who": "ines", "text": "Garde à vue. Quarante-huit heures, peut-être. Il a un avocat, au moins.", "anim": "sigh", "if": "flag:ch3_karim==gav"},
		{"who": "nadia", "text": "Ce soir on a été plus forts qu'eux. Assis. Sans rien casser. Les gens l'ont vu.", "anim": "nod", "look": "sam", "if": "flag:ch3_choix==sitin"},
		{"who": "nadia", "text": "Ce soir on leur a donné ce qu'ils voulaient. Demain, à la télé, ce sera « heurts à la mairie ».", "anim": "shake_head", "look": "sam", "if": "flag:ch3_choix==forcer"},
		{"choice": [
			{"id": "assumer", "text": "« On a eu raison. »", "say": "On a eu raison. Ils ont changé le parcours en douce, on allait pas dire merci.", "if": "flag:ch3_choix==forcer",
				"rel": {"karim": 4, "nadia": -4}},
			{"id": "regret", "text": "« J'ai merdé. »", "say": "T'as raison. J'ai merdé. Je me suis laissé emporter.", "if": "flag:ch3_choix==forcer",
				"rel": {"nadia": 6}, "set": {"ch3_regret": true}},
			{"id": "suite", "text": "« Et maintenant ? »", "say": "Et maintenant ? On fait quoi, la prochaine fois ?"},
		]},
		{"who": "nadia", "text": "Maintenant on dort. Et jeudi prochain, on sera deux fois plus. Tu verras.", "anim": "explain"},
	],
}
