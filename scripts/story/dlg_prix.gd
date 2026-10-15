class_name DlgPrix
extends RefCounted
## Dialogues du chapitre 2 « Les prix, en vrai » (format : docs/CAMPAGNE.md § 5.3 ; histoire : BIBLE.md § 4.2).

const DLG := {
	"_id": "prix",
	# ------------------------------------------------------------ Lou au Zinc
	"lou": [
		{"who": "lou", "text": "C'est toi, Sam ? Lou. Nadia m'a dit que tu connaissais tout le monde ici.", "anim": "wave", "look": "sam"},
		{"who": "sam", "text": "Tout le monde, non. Les codes d'immeuble, oui."},
		{"who": "lou", "text": "Ça me va. Bon, l'idée : pas de slogans, pas de musique triste. Des chiffres et des gens.", "anim": "explain"},
		{"who": "lou", "text": "Les étiquettes du Panier. Le totem de la station. Et quelqu'un qui raconte. Trois minutes, pas plus.", "anim": "explain"},
		{"who": "lou", "text": "Au fait, le tag sur la banque, jeudi… Il tourne sur le groupe du quartier. Les commentaires sont pas tendres.", "look": "sam", "if": "ch1_tag"},
		{"who": "lou", "text": "Les gens retiennent la vitrine, pas la loi. C'est pour ça que je fais des vidéos.", "anim": "shrug", "if": "ch1_tag"},
		{"who": "jo", "text": "Et moi je fais quoi, dans votre film ? Le vieux râleur au comptoir ?", "anim": "crossed"},
		{"who": "lou", "text": "Vous seriez parfait.", "anim": "laugh"},
		{"who": "jo", "text": "Jamais de la vie. Avec ma tronche, vous perdez la moitié du public.", "anim": "shake_head"},
		{"who": "lou", "text": "Pour le témoignage, t'as quelqu'un ? Quelqu'un de vrai. Pas un militant.", "look": "sam"},
		{"choice": [
			{"id": "ferreira", "text": "« Mme Ferreira. »", "say": "Mme Ferreira, au-dessus de la pharmacie. Elle chauffe plus. Mais elle veut pas que ça se sache.",
				"set": {"ch2_piste_ferreira": true}, "goto": "lou_ferreira"},
			{"id": "personne", "text": "« J'sais pas. »", "say": "J'sais pas. Les gens ont honte, en vrai.", "goto": "lou_jo"},
		]},
	],
	"lou_ferreira": [
		{"who": "lou", "text": "Alors on lui demande. Et si elle dit non, c'est non.", "anim": "nod"},
	],
	"lou_jo": [
		{"who": "jo", "text": "Maria Ferreira. La dame d'en face. Elle se couvre chez elle comme dehors.", "anim": "point"},
		{"who": "jo", "text": "Mais vous lui parlez gentiment. Sinon c'est à moi que vous aurez affaire.", "anim": "crossed"},
		{"set": {"ch2_piste_ferreira": true}},
	],
	# ------------------------------------------------------------ la supérette
	"gerant": [
		{"who": "narrateur", "text": "Le gérant, depuis la caisse : « Hé ! Vous faites quoi, là ? On filme pas dans le magasin ! »"},
		{"who": "lou", "text": "On filme les prix, monsieur. Ils sont affichés, c'est public.", "anim": "explain"},
		{"who": "narrateur", "text": "« C'est pas public, c'est chez moi. Dehors. »"},
		{"who": "lou", "text": "D'accord, on sort. On a ce qu'il faut de toute façon.", "anim": "nod", "look": "sam"},
	],
	# ------------------------------------------------------------ la police appelée par le gérant
	"police": [
		{"who": "lou", "text": "Il a appelé. Une voiture. Pour deux personnes avec un téléphone sur le trottoir.", "anim": "point"},
		{"who": "narrateur", "text": "Deux policiers descendent, sans se presser. « Bonjour. On nous signale un problème avec le magasin. »"},
		{"choice": [
			{"id": "partir", "text": "Expliquer et partir calmement", "say": "Pas de problème. On filmait les prix, on s'en va. Bonne journée.",
				"set": {"ch2_parti_calme": true}, "rel": {"lou": 2}, "goto": "police_calme"},
			{"id": "rester", "text": "Rester : filmer la rue, c'est légal", "say": "Il y a pas de problème. On est sur la voie publique, on a le droit de filmer.",
				"set": {"ch2_accroche": true}, "rel": {"lou": 6}, "stats": {"notoriete": 0.08, "repression": 0.02}, "goto": "police_controle"},
		], "prompt": "Le gérant regarde depuis sa porte."},
	],
	"police_calme": [
		{"who": "narrateur", "text": "« Parfait. Bonne journée. » La voiture repart. Le gérant rentre sans un mot."},
		{"who": "lou", "text": "Bien joué. On n'est pas là pour lui. On est là pour les étiquettes.", "anim": "nod"},
	],
	"police_controle": [
		{"who": "narrateur", "text": "« Vous avez raison. Contrôle d'identité, alors. Vos papiers, s'il vous plaît. »"},
		{"who": "lou", "text": "Je filme, hein. Tranquillement.", "anim": "film"},
		{"who": "narrateur", "text": "Le policier note : Diallo, Samuel. Il lève les yeux. « Vous êtes du quartier ? »"},
		{"who": "narrateur", "text": "« Jeudi soir, devant la Banque Hexa. C'était pas vous, par hasard ? »", "if": "ch1_tag"},
		{"who": "sam", "text": "Je livre des pizzas, je suis partout. Jeudi j'étais au square.", "if": "ch1_tag"},
		{"who": "narrateur", "text": "« Bonne journée, Monsieur Diallo. » Ils repartent. Doucement."},
		{"who": "lou", "text": "T'as été bien. Calme, poli, dans ton droit. Ça, ça se montre.", "anim": "nod"},
		{"who": "sam", "text": "Mon nom est dans un carnet, maintenant."},
		{"who": "lou", "text": "Bienvenue. Le mien y est depuis 2016.", "anim": "shrug"},
	],
	# ------------------------------------------------------------ la station
	"station": [
		{"who": "lou", "text": "Deux soixante-dix-neuf. L'an dernier il était à deux vingt.", "anim": "point", "look": "station_service"},
		{"who": "lou", "text": "Je fais le totem en serré. Toi, fais-moi un plan large avec les gens qui font le plein. Leur tête quand ça tourne.", "anim": "explain"},
	],
	# ------------------------------------------------------------ Mme Ferreira
	"ferreira": [
		{"who": "mme_ferreira", "text": "Sam ! Entrez, entrez. Et votre amie aussi. Gardez vos manteaux, hein.", "anim": "beckon", "if": "ch0_aide_ferreira"},
		{"who": "mme_ferreira", "text": "Oui ? C'est pour quoi ?", "look": "lou", "if": "!ch0_aide_ferreira"},
		{"who": "lou", "text": "Bonjour Madame. On fait une petite vidéo sur les prix. Sam m'a dit que… l'hiver a été dur.", "anim": "explain"},
		{"who": "mme_ferreira", "text": "Il vous a dit ça ? Il avait promis.", "anim": "crossed", "look": "sam", "if": ["ch0_aide_ferreira", "!ch0_ferreira_doute"]},
		{"who": "mme_ferreira", "text": "Qui vous a raconté ça ? Joseph, hein. Il sait pas tenir sa langue.", "anim": "crossed", "if": "!ch0_aide_ferreira"},
		{"who": "mme_ferreira", "text": "Je me doutais bien que vous alliez revenir avec ça. Vous me l'aviez dit : je suis pas la seule.", "anim": "sigh", "if": "ch0_ferreira_doute"},
		{"goto": "ferreira_oui", "if": "rel:mme_ferreira>=10"},
		{"choice": [
			{"id": "pas_seule", "text": "« Vous parleriez pour tout l'immeuble. »", "say": "Au troisième, ils sont pareils. Si vous parlez, vous parlez pour eux aussi.",
				"rel": {"mme_ferreira": 5}, "goto": "ferreira_oui"},
			{"id": "insister", "text": "« Ça passera à la télé, peut-être. »", "say": "Ça peut aller loin, vous savez. Peut-être jusqu'à la télé.",
				"rel": {"mme_ferreira": -5}, "goto": "ferreira_peur"},
			{"id": "renoncer", "text": "« Excusez-nous. On vous laisse. »", "say": "Excusez-nous. Vous avez raison, on vous laisse tranquille.",
				"rel": {"mme_ferreira": 3}, "set": {"ch2_ferreira_refus": true}, "goto": "ferreira_non"},
		], "prompt": "Elle serre son gilet."},
	],
	"ferreira_peur": [
		{"who": "mme_ferreira", "text": "La télé ? Pour que ma fille me voie pleurer devant tout le monde ? Non.", "anim": "shake_head"},
		{"who": "lou", "text": "Pas de larmes, promis. Juste vos chiffres. Et on peut flouter votre visage.", "anim": "explain"},
		{"who": "mme_ferreira", "text": "…Flouter. Bon. Mais je dis juste les chiffres.", "anim": "sigh"},
		{"set": {"ch2_ferreira_floutee": true}},
		{"goto": "ferreira_oui"},
	],
	"ferreira_non": [
		{"who": "mme_ferreira", "text": "Vous êtes gentils. Mais c'est mes affaires, vous comprenez.", "anim": "nod"},
		{"who": "lou", "text": "On comprend. Merci, Madame.", "anim": "nod"},
	],
	"ferreira_oui": [
		{"who": "mme_ferreira", "text": "Bon. Je veux bien. Mais vous me faites pas pleurer. J'ai horreur de ça.", "anim": "nod"},
		{"who": "lou", "text": "Juré. Sam, c'est toi qui tiens le téléphone. Elle te connaît.", "anim": "give", "look": "sam"},
		{"set": {"ch2_ferreira_ok": true}},
	],
	"temoignage": [
		{"who": "mme_ferreira", "text": "Je m'appelle Maria. J'ai soixante-quatorze ans. J'ai fait des ménages pendant quarante ans.", "look": "sam"},
		{"who": "mme_ferreira", "text": "J'ai huit cent douze euros de pension. Ma dernière facture de chauffage, c'est cent quatre-vingts.", "anim": "explain"},
		{"who": "mme_ferreira", "text": "Alors j'ai coupé. Je mets mon manteau dans la cuisine. Je me couche à sept heures, c'est plus chaud.", "anim": "warm"},
		{"who": "mme_ferreira", "text": "Je demande pas qu'on me plaigne. Je demande… je sais pas ce que je demande. Qu'on le sache, voilà.", "anim": "sigh"},
		{"wait": 0.8},
		{"who": "lou", "text": "…Merci. C'est parfait. Vraiment.", "anim": "nod"},
	],
	# ------------------------------------------------------------ le montage au Zinc
	"montage": [
		{"who": "lou", "text": "Bon. C'est monté. Deux minutes cinquante. Les passants, je les floute, ça c'est non négociable.", "anim": "phone"},
		{"goto": "montage_visage", "if": "temoignage_ferreira", "else": "montage_sans"},
	],
	"montage_visage": [
		{"who": "lou", "text": "Mme Ferreira, elle a dit d'accord pour montrer son visage. Mais elle sait pas ce que c'est, internet.", "anim": "explain", "if": "!ch2_ferreira_floutee"},
		{"who": "lou", "text": "On lui a promis le flou. Mais franchement, son visage, c'est la moitié de la vidéo.", "anim": "explain", "if": "ch2_ferreira_floutee"},
		{"who": "jo", "text": "Des gens vont l'insulter. Y en a toujours.", "anim": "crossed"},
		{"choice": [
			{"id": "floutee", "text": "Flouter son visage", "say": "On floute. Elle a pas à payer pour nous.",
				"set": {"ch2_video": "floutee"}, "rel": {"mme_ferreira": 8, "lou": 2}, "stats": {"opinion": 3}},
			{"id": "nette", "text": "Montrer son visage", "say": "On la montre. Les gens doivent voir qui paie, pour de vrai.",
				"if": "!ch2_ferreira_floutee", "set": {"ch2_video": "nette"}, "rel": {"lou": 4}, "stats": {"opinion": 5, "notoriete": 0.03}},
			{"id": "nette_promesse", "text": "Montrer son visage malgré la promesse", "say": "On la montre. Tant pis pour le flou, ça touchera plus de monde.",
				"if": "ch2_ferreira_floutee", "set": {"ch2_video": "nette", "ch2_promesse_rompue": true}, "rel": {"lou": -6, "mme_ferreira": -15}, "stats": {"opinion": 5}},
		], "prompt": "Le curseur clignote sur « Publier »."},
		{"who": "lou", "text": "D'accord. Je publie.", "anim": "phone"},
	],
	"montage_sans": [
		{"who": "lou", "text": "Pas de témoignage, alors. Juste les prix et la rue. C'est moins fort, mais c'est honnête.", "anim": "shrug"},
		{"set": {"ch2_video": "floutee"}, "stats": {"opinion": 1}},
		{"who": "lou", "text": "Je publie.", "anim": "phone"},
	],
	"publie": [
		{"wait": 0.6},
		{"who": "lou", "text": "Dix minutes. Mille vues. Le compte du quartier l'a partagée. Et… un journaliste de Canal Continu m'écrit.", "anim": "phone"},
		{"who": "jo", "text": "Les mêmes qui parlent de « grogne » ? Ils veulent quoi ?", "anim": "crossed"},
		{"who": "lou", "text": "Les droits de diffusion. Gratuitement, bien sûr.", "anim": "laugh"},
		{"who": "jo", "text": "Ha ! Les « droits ». Ils manquent pas d'air.", "anim": "laugh"},
		{"who": "lou", "text": "Sam. Merci. T'as l'œil, tu sais. Tu devrais filmer, aux prochains.", "look": "sam"},
		{"choice": [
			{"id": "oui", "text": "« Je filmerai. »", "say": "Je filmerai. Mais c'est toi qui montes, hein.", "rel": {"lou": 6}, "set": {"ch2_promesse_lou": true}},
			{"id": "bof", "text": "« Moi je préfère être dedans. »", "say": "Moi je préfère être dedans que derrière.", "rel": {"lou": 1}},
		]},
		{"who": "lou", "text": "Mardi, Nadia veut faire un cortège. Jusqu'à la mairie. On verra combien on est.", "anim": "explain"},
	],
}
