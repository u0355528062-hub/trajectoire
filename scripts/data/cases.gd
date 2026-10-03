extends Node
## Base de données médicale du mode Histoire (médecine générale).
## Chargée en autoload sous le nom « Cases ».
##
## Contenus simplifiés à visée ludique et pédagogique : ils ne remplacent pas
## les recommandations officielles (HAS, sociétés savantes).

# --- Interrogatoire -----------------------------------------------------------

const QUESTIONS := [
	{"id": "debut", "text": "Depuis quand avez-vous ces symptômes ?"},
	{"id": "description", "text": "Pouvez-vous me décrire ce que vous ressentez ?"},
	{"id": "fievre", "text": "Avez-vous eu de la fièvre ?"},
	{"id": "autres", "text": "Avez-vous remarqué d'autres symptômes ?"},
	{"id": "antecedents", "text": "Avez-vous des antécédents médicaux ou chirurgicaux ?"},
	{"id": "traitements", "text": "Prenez-vous des médicaments en ce moment ?"},
	{"id": "allergies", "text": "Avez-vous des allergies, notamment à des médicaments ?"},
	{"id": "mode_vie", "text": "Fumez-vous ? Et l'alcool, le sport ?"},
]

const DEFAULT_ANSWERS := {
	"debut": "Je ne sais plus trop… quelques jours, je dirais.",
	"description": "C'est difficile à expliquer, docteur.",
	"fievre": "Non, pas de fièvre.",
	"autres": "Non, rien d'autre de particulier.",
	"antecedents": "Non, rien de spécial.",
	"traitements": "Non, aucun traitement.",
	"allergies": "Pas que je sache.",
	"mode_vie": "Je ne fume pas. Un verre de temps en temps, c'est tout.",
}

## Répliques génériques des patients (enregistrées pour chaque voix).
const GENERIC := {
	"hello": "Bonjour docteur.",
	"ok": "D'accord, docteur.",
	"table": "D'accord, je m'installe sur la table.",
	"lie": "Je m'allonge, d'accord.",
	"chair": "Je me rassieds sur la chaise.",
	"pain": "Aïe ! Là, ça me fait mal.",
	"cold": "Ouh, c'est froid !",
	"aah": "Aaaaaah…",
	"blow": "Je souffle fort, c'est ça ?",
	"sample": "D'accord, je reviens tout de suite.",
	"prick": "Aïe, ça pique un peu.",
	"bye": "Merci beaucoup docteur. Au revoir !",
	"follow": "J'arrive, docteur.",
	"stand": "Je me lève.",
	"which": "Oui ?",
}

# --- Diagnostics ----------------------------------------------------------------

const DIAGNOSES := {
	"rhinopharyngite": "Rhinopharyngite virale",
	"angine_strepto": "Angine à streptocoque A",
	"angine_virale": "Angine virale",
	"sinusite": "Sinusite bactérienne",
	"grippe": "Grippe",
	"mononucleose": "Mononucléose infectieuse",
	"lombalgie": "Lombalgie commune aiguë",
	"sciatique": "Lombosciatique (radiculalgie)",
	"colique_nephretique": "Colique néphrétique",
	"tassement": "Tassement vertébral",
	"oma": "Otite moyenne aiguë purulente",
	"otite_externe": "Otite externe",
	"otite_congestive": "Otite congestive (virale)",
	"hta_non_controlee": "HTA non contrôlée",
	"hta_controlee": "HTA bien contrôlée",
	"blouse_blanche": "Effet blouse blanche isolé",
	"hypotension_ortho": "Hypotension orthostatique",
	"cystite": "Cystite aiguë simple",
	"pyelonephrite": "Pyélonéphrite aiguë",
	"vaginite": "Vaginite",
	"asthme": "Exacerbation d'asthme modérée",
	"asthme_grave": "Asthme aigu grave",
	"pneumopathie": "Pneumopathie aiguë communautaire",
	"bronchite": "Bronchite aiguë",
	"entorse": "Entorse bénigne de la cheville",
	"fracture_cheville": "Fracture de la malléole",
	"rupture_achille": "Rupture du tendon d'Achille",
	"fracture_5mt": "Fracture de la base du 5e métatarsien",
	"sca": "Syndrome coronarien aigu ST+ (infarctus)",
	"pericardite": "Péricardite aiguë",
	"rgo": "Reflux gastro-œsophagien",
	"attaque_panique": "Attaque de panique",
	"dt2_desequilibre": "Diabète de type 2 déséquilibré",
	"dt2_equilibre": "Diabète de type 2 équilibré",
	"hypothyroidie": "Hypothyroïdie",
	"gea": "Gastro-entérite aiguë virale",
	"appendicite": "Appendicite aiguë",
	"toxi_infection": "Toxi-infection alimentaire grave",
	"zona": "Zona thoracique",
	"herpes": "Herpès cutané",
	"eczema": "Eczéma de contact",
	"migraine": "Crise de migraine sans aura",
	"hsa": "Hémorragie sous-arachnoïdienne",
	"cephalee_tension": "Céphalée de tension",
}

# --- Prescriptions et orientations ------------------------------------------------
# Chaque entrée : libellé, ligne d'ordonnance, catégorie (rx / bio / orientation / conseil).

const TREATMENTS := {
	"paracetamol": ["Paracétamol", "Paracétamol 1 g, jusqu'à 3 fois par jour si douleur ou fièvre", "rx"],
	"ains": ["Ibuprofène (anti-inflammatoire)", "Ibuprofène 400 mg, 3 fois par jour au cours des repas, 3 jours", "rx"],
	"amoxicilline": ["Amoxicilline", "Amoxicilline 1 g matin et soir, 6 jours", "rx"],
	"fluoroquinolone": ["Ciprofloxacine (fluoroquinolone)", "Ciprofloxacine 500 mg matin et soir, 5 jours", "rx"],
	"fosfomycine": ["Fosfomycine-trométamol", "Fosfomycine-trométamol 3 g, un sachet en prise unique", "rx"],
	"corticoides": ["Corticoïdes par voie orale", "Prednisolone 40 mg le matin, 5 jours", "rx"],
	"lavage_nez": ["Lavages de nez", "Sérum physiologique : lavages de nez plusieurs fois par jour", "rx"],
	"gouttes_oreille": ["Gouttes auriculaires antibiotiques", "Gouttes auriculaires antibiotiques, 2 fois par jour", "rx"],
	"rester_actif": ["Conseil : rester actif", "Maintien des activités habituelles, éviter le repos au lit", "conseil"],
	"repos_lit": ["Repos strict au lit", "Repos strict au lit pendant une semaine", "conseil"],
	"radio_rachis": ["Radiographie lombaire", "Radiographie du rachis lombaire face et profil", "bio"],
	"radio_cheville": ["Radiographie de cheville", "Radiographie de la cheville droite", "bio"],
	"radio_thorax": ["Radiographie thoracique", "Radiographie thoracique de face", "bio"],
	"kine": ["Kinésithérapie", "10 séances de kinésithérapie", "rx"],
	"arret_travail": ["Arrêt de travail court", "Arrêt de travail de 3 jours", "conseil"],
	"hygiene_vie": ["Règles hygiéno-diététiques", "Réduction du sel, activité physique régulière, alimentation équilibrée", "conseil"],
	"intensifier_hta": ["Ajouter un IEC ou un ARA2", "Ramipril 2,5 mg le matin (en plus de l'amlodipine)", "rx"],
	"renouveler_seul": ["Renouveler à l'identique", "Renouvellement du traitement habituel à l'identique", "rx"],
	"bilan_bio": ["Bilan biologique", "Créatinine, kaliémie, glycémie à jeun, bilan lipidique", "bio"],
	"urgences": ["Urgences par ses propres moyens", "Se rendre aux urgences par ses propres moyens", "orientation"],
	"samu": ["Appeler le SAMU (15)", "Appel du SAMU – Centre 15", "orientation"],
	"aspirine": ["Aspirine (avec le SAMU)", "Aspirine 250 mg, sur avis du médecin régulateur", "rx"],
	"ipp": ["Inhibiteur de la pompe à protons", "Oméprazole 20 mg le matin, 14 jours", "rx"],
	"anxiolytique": ["Anxiolytique", "Hydroxyzine 25 mg le soir", "rx"],
	"ecbu": ["ECBU", "Examen cytobactériologique des urines", "bio"],
	"hydratation": ["Hydratation abondante", "Boire au moins 1,5 L d'eau par jour", "conseil"],
	"salbutamol": ["Salbutamol inhalé", "Salbutamol 100 µg : 2 bouffées si gêne, jusqu'à 4 fois par jour", "rx"],
	"traitement_fond": ["Corticoïde inhalé (fond)", "Béclométasone 250 µg : 1 bouffée matin et soir (traitement de fond)", "rx"],
	"glace_repos": ["Glace, repos, compression, surélévation", "Glaçage 20 min 3 fois par jour, repos relatif, compression, jambe surélevée", "conseil"],
	"attelle": ["Chevillère de maintien", "Chevillère de contention, 3 semaines", "rx"],
	"platre": ["Plâtre 6 semaines", "Immobilisation plâtrée 6 semaines", "rx"],
	"isglt2": ["Ajouter un iSGLT2 ou un aGLP-1", "Dapagliflozine 10 mg le matin (en plus de la metformine)", "rx"],
	"insuline": ["Débuter une insuline", "Insuline glargine 10 UI le soir", "rx"],
	"arret_metformine": ["Arrêter la metformine", "Arrêt de la metformine", "rx"],
	"pieds": ["Éducation podologique", "Examen des pieds à chaque consultation, chaussures adaptées", "conseil"],
	"sro": ["Soluté de réhydratation orale", "Soluté de réhydratation orale, à volonté", "rx"],
	"antibiotique_gea": ["Antibiotique (amoxicilline)", "Amoxicilline 1 g matin et soir, 5 jours", "rx"],
	"reevaluation": ["Réévaluation à 48–72 h", "Consultation de réévaluation dans 48 à 72 heures", "conseil"],
	"hospitalisation": ["Hospitalisation", "Hospitalisation en service de médecine", "orientation"],
	"valaciclovir": ["Valaciclovir (antiviral)", "Valaciclovir 1 g 3 fois par jour, 7 jours", "rx"],
	"creme": ["Crème hydratante", "Crème émolliente sur les lésions", "rx"],
	"triptan": ["Triptan", "Sumatriptan 50 mg dès le début de la crise", "rx"],
	"opioides": ["Codéine / tramadol", "Tramadol 50 mg, jusqu'à 3 fois par jour", "rx"],
	"scanner": ["Scanner cérébral en urgence", "Scanner cérébral en urgence", "bio"],
	"surveillance": ["Consignes de surveillance", "Reconsulter en cas d'aggravation ou de fièvre persistante", "conseil"],
}

# --- Personnages hors patients ----------------------------------------------------------

const CAST := {
	"camille": {"name": "Camille", "avatar": "camille_secretaire", "gender": "f", "voice": "siwis", "pitch": 0.6},
	"smur_medecin": {"name": "Dr Lucas (SMUR)", "avatar": "smur_medecin", "gender": "m", "voice": "gilles", "pitch": -0.5},
	"smur_infirmiere": {"name": "Infirmière du SMUR", "avatar": "smur_infirmiere", "gender": "f", "voice": "siwis", "pitch": -0.8},
	"regulateur": {"name": "Médecin régulateur du SAMU", "avatar": "", "gender": "m", "voice": "mls", "pitch": -1.0},
	"marchand": {"name": "Dr Hélène Marchand", "avatar": "helene_marchand", "gender": "f", "voice": "siwis", "pitch": -2.2},
}

## Répliques des personnages hors patients.
const LINES := {
	"camille": {
		"morning": "Bonjour docteur ! L'agenda du jour est sur votre ordinateur.",
		"next": "Votre patient suivant est en salle d'attente.",
		"done": "C'est terminé pour ce matin ! Bonne pause, docteur.",
		"urgent": "Docteur ! Un monsieur se plaint d'une douleur dans la poitrine, il est très pâle !",
		"walk_in": "Docteur, un patient se présente sans rendez-vous.",
		"none": "Il n'y a personne en salle d'attente pour le moment.",
		"call": "Je fais entrer le patient suivant.",
		"busy": "Vous avez déjà un patient dans votre cabinet, docteur.",
		"hello": "Oui, docteur ?",
		"arrival_m": "Votre patient de rendez-vous est arrivé.",
		"arrival_f": "Votre patiente de rendez-vous est arrivée.",
	},
	"regulateur": {
		"answer": "SAMU, centre 15, j'écoute.",
		"ok": "Bien reçu. J'engage le SMUR immédiatement, ils seront chez vous dans une dizaine de minutes. Donnez-lui de l'aspirine s'il n'est pas allergique, et restez auprès de lui.",
	},
	"smur_medecin": {
		"hello": "Bonjour ! SMUR. Où est le patient ?",
		"take": "On s'occupe de lui. Bon réflexe, docteur : direction la salle de coronarographie.",
	},
	"marchand": {
		"hello": "Alors, mon cher confrère ? Camille m'a dit le plus grand bien de vous.",
		"proud": "Mes patients sont entre de bonnes mains. Je peux enfin profiter de ma retraite !",
	},
}

# --- Dossiers patients --------------------------------------------------------------
# treatment.good : attendu (bonus, malus si oublié)
# treatment.ok   : acceptable
# treatment.bad  : inadapté ou dangereux (malus)
# treatment.critical : oubli = erreur grave (urgence vitale)
# key_exams : examens utiles ("a|b" = l'un ou l'autre)

const CASES := {
	"rhino": {
		"patient": {"name": "Lucas Bernard", "age": 28, "sex": "M", "job": "Graphiste",
			"avatar": "lucas_bernard", "voice": "gilles", "pitch": 0.6, "cough": true},
		"motif": "Nez qui coule, gorge qui gratte",
		"history": "Aucun antécédent notable.",
		"greeting": "Bonjour docteur. Je crois que j'ai attrapé un rhume, mais je préfère vérifier.",
		"answers": {
			"debut": "Ça a commencé il y a trois jours.",
			"description": "J'ai le nez bouché, ça coule clair, et la gorge qui gratte un peu. Je suis un peu fatigué.",
			"fievre": "Un peu, trente-sept neuf hier soir. Aujourd'hui ça va mieux.",
			"autres": "Je tousse un peu le matin, c'est tout.",
		},
		"extra_questions": [
			{"text": "Avez-vous mal au visage, sous les yeux ?", "answer": "Non, pas vraiment."},
		],
		"vitals": {"temp": 37.6},
		"findings": {
			"orl": "Pharynx légèrement rouge, sans exsudat. Rhinorrhée claire. Amygdales normales.",
			"ganglions": "Petites adénopathies cervicales souples, mobiles et indolores.",
		},
		"visual": {"orl": "rouge_leger"},
		"key_exams": ["orl", "temp", "pulmo_d|pulmo_g"],
		"diagnosis": "rhinopharyngite",
		"differentials": ["angine_strepto", "sinusite", "grippe"],
		"treatment": {
			"good": ["paracetamol", "lavage_nez", "surveillance"],
			"ok": ["arret_travail"],
			"bad": ["amoxicilline", "corticoides", "ains"],
		},
		"options": ["paracetamol", "lavage_nez", "surveillance", "arret_travail", "amoxicilline", "corticoides", "ains", "radio_thorax"],
		"teaching": "La rhinopharyngite est virale : le traitement est uniquement symptomatique (paracétamol, lavages de nez). Les antibiotiques sont inutiles et favorisent les résistances ; les AINS et corticoïdes sont déconseillés dans les infections ORL.",
	},
	"lombalgie": {
		"patient": {"name": "Patrick Morel", "age": 52, "sex": "M", "job": "Magasinier",
			"avatar": "patrick_morel", "voice": "mls", "pitch": -1.0, "walk": "walk_bruised", "mood": "pain"},
		"motif": "Mal au dos",
		"history": "Appendicectomie à 20 ans. Pas d'autre antécédent.",
		"greeting": "Bonjour docteur… Aïe. Je me suis bloqué le dos hier au travail.",
		"answers": {
			"debut": "Hier après-midi, en soulevant un carton de vingt-cinq kilos.",
			"description": "Ça tire en bas du dos, des deux côtés. Ça ne descend pas dans les jambes.",
			"autres": "Non. Pas de problème pour uriner, pas de fourmillements.",
			"traitements": "J'ai pris un Doliprane hier soir, ça a un peu soulagé.",
			"mode_vie": "Je fume dix cigarettes par jour. Pas de sport, mon travail est physique.",
		},
		"extra_questions": [
			{"text": "Avez-vous perdu du poids récemment ?", "answer": "Non, pas du tout."},
			{"text": "La douleur vous réveille-t-elle la nuit ?", "answer": "Seulement quand je me retourne dans le lit."},
		],
		"vitals": {"ta": "136/84", "fc": 80},
		"findings": {
			"rachis": "Contracture des muscles paravertébraux lombaires, douleur à la palpation, raideur en flexion. Pas de douleur à la percussion des épineuses.",
			"lasegue": "Signe de Lasègue négatif des deux côtés.",
			"force": "Force et sensibilité normales aux quatre membres.",
			"reflexes": "Réflexes rotuliens présents et symétriques.",
		},
		"pain": ["lumbar"],
		"key_exams": ["rachis", "lasegue", "reflexes|force"],
		"diagnosis": "lombalgie",
		"differentials": ["sciatique", "colique_nephretique", "tassement"],
		"treatment": {
			"good": ["paracetamol", "rester_actif"],
			"ok": ["ains", "arret_travail", "kine"],
			"bad": ["radio_rachis", "repos_lit", "opioides"],
		},
		"options": ["paracetamol", "rester_actif", "ains", "arret_travail", "kine", "radio_rachis", "repos_lit", "opioides"],
		"teaching": "Lombalgie commune sans drapeau rouge : pas d'imagerie avant 6 semaines. Le maintien de l'activité accélère la guérison, le repos au lit la retarde. Antalgiques simples, AINS de courte durée possibles.",
	},
	"otite": {
		"patient": {"name": "Léo Dubois", "age": 8, "sex": "M", "job": "Élève de CE2",
			"avatar": "leo_dubois", "voice": "siwis", "pitch": 4.5, "mood": "tired", "child": true},
		"companion": {"name": "Claire Dubois", "role": "La mère", "avatar": "claire_dubois", "gender": "f", "voice": "siwis", "pitch": 0.0},
		"motif": "Fièvre et douleur d'oreille",
		"history": "Né à terme. Vaccinations à jour.",
		"greeting": "(La mère) Bonjour docteur, merci de nous prendre sans rendez-vous. Il a pleuré toute la nuit en se tenant l'oreille.",
		"answers": {
			"debut": "(La mère) Depuis hier soir. Il avait le nez qui coulait depuis trois jours.",
			"description": "(Léo) J'ai mal à l'oreille… À droite, ça tape fort.",
			"fievre": "(La mère) Trente-huit neuf cette nuit, malgré le paracétamol.",
			"autres": "(La mère) Il mange moins et il est grognon.",
			"antecedents": "(La mère) Rien de particulier. Il est né à terme et ses vaccins sont à jour.",
			"traitements": "(La mère) Juste du paracétamol depuis hier soir.",
			"allergies": "(La mère) Aucune allergie connue.",
			"mode_vie": "(La mère) Il est en CE2. Personne ne fume à la maison.",
		},
		"vitals": {"temp": 38.7, "fc": 112, "fr": 22, "ta": "100/62"},
		"findings": {
			"oto_d": "Tympan droit rouge, bombé et opaque, perte des reliefs : aspect d'otite moyenne aiguë purulente.",
			"orl": "Rhinopharynx inflammatoire, rhinorrhée purulente. Amygdales normales.",
		},
		"visual": {"oto_d": "purulente", "orl": "rouge_leger"},
		"pain": ["ear_r"],
		"key_exams": ["oto_d", "oto_g", "temp"],
		"diagnosis": "oma",
		"differentials": ["otite_externe", "otite_congestive", "angine_virale"],
		"treatment": {
			"good": ["amoxicilline", "paracetamol"],
			"ok": ["surveillance", "lavage_nez"],
			"bad": ["gouttes_oreille", "corticoides", "fluoroquinolone"],
		},
		"options": ["amoxicilline", "paracetamol", "surveillance", "lavage_nez", "gouttes_oreille", "corticoides", "fluoroquinolone"],
		"teaching": "OMA purulente (tympan rouge et bombé) chez un enfant de plus de 2 ans avec fièvre et otalgie marquées : amoxicilline 5 jours et antalgique. Les gouttes auriculaires ne traitent pas une otite moyenne : le tympan est fermé.",
	},
	"hta": {
		"patient": {"name": "Monique Lefèvre", "age": 66, "sex": "F", "job": "Retraitée (institutrice)",
			"avatar": "monique_lefevre", "voice": "siwis", "pitch": -1.8, "walk": "walk_slow"},
		"motif": "Renouvellement d'ordonnance — tension",
		"history": "Hypertension depuis 5 ans sous amlodipine 5 mg. Ménopausée. Pas de diabète connu.",
		"greeting": "Bonjour docteur. Le docteur Marchand m'a beaucoup parlé de vous ! Je viens pour mon ordonnance de tension.",
		"answers": {
			"debut": "La tension, ça fait cinq ans. Mais mon appareil affiche des chiffres hauts depuis deux mois.",
			"description": "Je me sens bien. Parfois un petit mal de tête le matin.",
			"autres": "Non, pas de douleur dans la poitrine, pas d'essoufflement.",
			"traitements": "Amlodipine cinq milligrammes le matin. Je ne l'oublie jamais.",
			"mode_vie": "Je ne fume pas. Je marche un peu. J'aime bien la charcuterie, je l'avoue.",
		},
		"extra_questions": [
			{"text": "Avez-vous noté vos automesures à la maison ?", "answer": "Oui, j'ai mon carnet : en moyenne cent cinquante-deux sur quatre-vingt-douze, matin et soir, sur la semaine."},
		],
		"vitals": {"ta": "158/94", "fc": 70},
		"findings": {
			"cardio": "Bruits du cœur réguliers, pas de souffle. Pouls périphériques présents.",
			"pied_d": "Pas d'œdème de la cheville droite.",
			"pied_g": "Pas d'œdème de la cheville gauche.",
		},
		"key_exams": ["ta", "cardio"],
		"diagnosis": "hta_non_controlee",
		"differentials": ["hta_controlee", "blouse_blanche", "hypotension_ortho"],
		"treatment": {
			"good": ["intensifier_hta", "hygiene_vie", "bilan_bio"],
			"ok": ["surveillance"],
			"bad": ["renouveler_seul", "urgences", "anxiolytique"],
		},
		"options": ["intensifier_hta", "hygiene_vie", "bilan_bio", "surveillance", "renouveler_seul", "urgences", "anxiolytique"],
		"teaching": "Les automesures (152/92) confirment une HTA non contrôlée sous monothérapie : on passe à une bithérapie (ajout d'un IEC ou d'un ARA2), on renforce les règles hygiéno-diététiques (sel) et on contrôle créatinine et kaliémie.",
	},
	"angine": {
		"patient": {"name": "Inès Garcia", "age": 19, "sex": "F", "job": "Étudiante",
			"avatar": "ines_garcia", "voice": "siwis", "pitch": 1.4, "mood": "pain"},
		"motif": "Mal de gorge, fièvre",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour… J'ai super mal à la gorge, j'ai du mal à avaler.",
		"answers": {
			"debut": "Avant-hier, d'un coup.",
			"description": "Très mal en avalant, même la salive. Mal à la tête aussi.",
			"fievre": "Oui, trente-huit huit ce matin.",
			"autres": "Non, je ne tousse pas et je n'ai pas le nez qui coule.",
			"allergies": "Aucune allergie.",
			"mode_vie": "Je ne fume pas. Je fais du handball deux fois par semaine.",
		},
		"vitals": {"temp": 38.7, "fc": 96},
		"findings": {
			"orl": "Amygdales augmentées de volume, très rouges, recouvertes d'un exsudat blanchâtre.",
			"ganglions": "Adénopathies cervicales antérieures sensibles.",
			"tdr": "TROD angine POSITIF : streptocoque du groupe A.",
		},
		"visual": {"orl": "exsudat", "tdr": "pos"},
		"pain": ["neck"],
		"key_exams": ["orl", "temp", "tdr", "ganglions"],
		"required_exam": "tdr",
		"diagnosis": "angine_strepto",
		"differentials": ["angine_virale", "mononucleose", "rhinopharyngite"],
		"treatment": {
			"good": ["amoxicilline", "paracetamol"],
			"ok": ["surveillance"],
			"bad": ["corticoides", "ains", "fluoroquinolone"],
		},
		"options": ["amoxicilline", "paracetamol", "surveillance", "corticoides", "ains", "fluoroquinolone"],
		"teaching": "Score de McIsaac ≥ 2 (fièvre, absence de toux, adénopathies, amygdales) → TROD. TROD positif : amoxicilline 6 jours. Sans TROD, l'antibiothérapie n'est pas recommandée.",
	},
	"cystite": {
		"patient": {"name": "Sophie Laurent", "age": 31, "sex": "F", "job": "Infirmière scolaire",
			"avatar": "sophie_laurent", "voice": "siwis", "pitch": 0.3},
		"motif": "Brûlures urinaires",
		"history": "Une cystite il y a deux ans. Pas de grossesse en cours.",
		"greeting": "Bonjour docteur. Je crois que c'est encore une infection urinaire…",
		"answers": {
			"debut": "Depuis hier matin.",
			"description": "Ça brûle quand j'urine et j'ai envie d'y aller tout le temps.",
			"fievre": "Non, pas de fièvre.",
			"autres": "Pas de douleur dans le dos, pas de pertes inhabituelles.",
			"traitements": "Seulement ma pilule. Mon test de grossesse de la semaine dernière était négatif.",
		},
		"vitals": {"temp": 36.9},
		"findings": {
			"bu": "Leucocytes +++, nitrites + : bandelette positive.",
			"abdomen": "Discrète sensibilité sus-pubienne. Abdomen souple.",
			"rachis": "Fosses lombaires indolores à la percussion.",
		},
		"visual": {"bu": {"leu": 3, "nit": 1, "sang": 1, "prot": 0, "glu": 0}},
		"key_exams": ["bu", "temp", "rachis|abdomen"],
		"diagnosis": "cystite",
		"differentials": ["pyelonephrite", "vaginite", "colique_nephretique"],
		"treatment": {
			"good": ["fosfomycine", "hydratation"],
			"ok": ["surveillance"],
			"bad": ["fluoroquinolone", "amoxicilline", "ecbu"],
		},
		"options": ["fosfomycine", "hydratation", "surveillance", "fluoroquinolone", "amoxicilline", "ecbu"],
		"teaching": "Cystite simple (pas de fièvre, pas de douleur lombaire, bandelette positive) : fosfomycine-trométamol en dose unique. L'ECBU n'est pas nécessaire ; les fluoroquinolones sont à éviter en première intention.",
	},
	"asthme": {
		"patient": {"name": "Thomas Petit", "age": 24, "sex": "M", "job": "Cuisinier",
			"avatar": "thomas_petit", "voice": "gilles", "pitch": 1.2, "cough": true, "mood": "worry"},
		"motif": "Gêne respiratoire, sifflements",
		"history": "Asthme depuis l'enfance. Allergie aux pollens de graminées.",
		"greeting": "Bonjour docteur. Mon asthme… ça siffle depuis deux jours.",
		"answers": {
			"debut": "Depuis deux jours, surtout la nuit. C'est la saison des pollens.",
			"description": "J'ai la poitrine qui serre et ça siffle. La Ventoline me soulage quelques heures.",
			"autres": "Je tousse la nuit. Pas de fièvre, pas de crachats.",
			"traitements": "Juste ma Ventoline quand ça ne va pas. Je l'ai prise six fois hier.",
			"mode_vie": "Je ne fume pas. Les fumées de la cuisine me gênent parfois.",
		},
		"vitals": {"fr": 20, "spo2": 96, "fc": 98, "dep": 320},
		"findings": {
			"pulmo_g": "Sibilants diffus dans tout le champ pulmonaire gauche, expiration prolongée.",
			"pulmo_d": "Sibilants diffus dans tout le champ pulmonaire droit, expiration prolongée.",
			"respiration": "FR 20/min. Pas de tirage, parle par phrases complètes.",
			"dep": "Débit de pointe : 320 L/min, soit environ 60 % de la valeur théorique.",
		},
		"sounds": {"pulmo_g": "sibilants", "pulmo_d": "sibilants", "cardio": "rapide"},
		"key_exams": ["pulmo_d|pulmo_g", "spo2", "dep", "respiration"],
		"diagnosis": "asthme",
		"differentials": ["asthme_grave", "pneumopathie", "bronchite"],
		"treatment": {
			"good": ["salbutamol", "corticoides", "traitement_fond"],
			"ok": ["surveillance", "reevaluation"],
			"bad": ["amoxicilline", "samu", "anxiolytique"],
		},
		"options": ["salbutamol", "corticoides", "traitement_fond", "surveillance", "reevaluation", "amoxicilline", "samu", "anxiolytique"],
		"teaching": "Exacerbation modérée (phrases complètes, SpO₂ 96 %, DEP 60 %) : bronchodilatateur de courte durée, corticothérapie orale courte, et mise en place d'un traitement de fond par corticoïde inhalé. Pas d'antibiotique sans signe d'infection bactérienne.",
	},
	"thoracique": {
		"patient": {"name": "Gérard Roux", "age": 61, "sex": "M", "job": "Agriculteur",
			"avatar": "gerard_roux", "voice": "mls", "pitch": -2.0, "walk": "walk_slow", "mood": "pain", "skin": "pale"},
		"motif": "SANS RDV — douleur dans la poitrine",
		"history": "Diabète de type 2. Tabac : quarante paquets-années. Cholestérol non traité.",
		"greeting": "Docteur… ça me serre dans la poitrine… Ma femme a insisté pour que je passe.",
		"answers": {
			"debut": "Depuis… quarante minutes environ. Au repos, en lisant le journal.",
			"description": "Comme un étau sur la poitrine. Ça part dans le bras gauche et dans la mâchoire.",
			"autres": "J'ai la nausée. Je transpire.",
			"traitements": "De la metformine, pour le diabète.",
			"mode_vie": "Je fume un paquet par jour depuis quarante ans.",
		},
		"vitals": {"ta": "152/90", "fc": 102, "spo2": 95, "fr": 20},
		"findings": {
			"cardio": "Bruits du cœur réguliers et rapides. Pas de souffle.",
			"pulmo_g": "Pas de crépitant à gauche.",
			"pulmo_d": "Pas de crépitant à droite.",
			"ecg": "Sus-décalage du segment ST en DII, DIII et aVF, avec miroir en V1-V3 : infarctus inférieur en cours.",
			"respiration": "FR 20/min. Patient pâle, en sueur.",
		},
		"visual": {"ecg": "st_inferieur"},
		"sounds": {"cardio": "rapide"},
		"urgent": true,
		"key_exams": ["ecg", "ta", "cardio"],
		"diagnosis": "sca",
		"differentials": ["pericardite", "rgo", "attaque_panique"],
		"treatment": {
			"good": ["samu", "aspirine"],
			"critical": ["samu"],
			"ok": [],
			"bad": ["urgences", "ipp", "anxiolytique", "paracetamol"],
		},
		"options": ["samu", "aspirine", "urgences", "ipp", "anxiolytique", "paracetamol"],
		"teaching": "Douleur thoracique constrictive irradiant au bras et à la mâchoire chez un patient à haut risque : syndrome coronarien aigu jusqu'à preuve du contraire. Appel immédiat du 15 ; ne jamais laisser le patient partir par ses propres moyens. Chaque minute compte.",
	},
	"entorse": {
		"patient": {"name": "Julie Moreau", "age": 35, "sex": "F", "job": "Comptable, coureuse amateur",
			"avatar": "julie_moreau", "voice": "siwis", "pitch": 0.5, "walk": "walk_injured"},
		"motif": "Cheville tordue",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour ! Je me suis tordu la cheville en courant ce matin, c'est malin…",
		"answers": {
			"debut": "Ce matin à sept heures, sur un trottoir.",
			"description": "Le pied est parti vers l'intérieur. Ça a gonflé sur le côté extérieur de la cheville droite.",
			"autres": "J'ai pu marcher jusqu'à chez moi en boitant.",
			"mode_vie": "Je cours trois fois par semaine. Je ne fume pas.",
		},
		"extra_questions": [
			{"text": "Avez-vous entendu un craquement ?", "answer": "Non, je ne crois pas."},
		],
		"findings": {
			"pied_d": "Œdème et douleur en avant et sous la malléole externe (ligament latéral). Pas de douleur osseuse au bord postérieur des malléoles ni à la base du 5e métatarsien. Appui possible : quatre pas. Tendon d'Achille intact.",
		},
		"pain": ["foot_r"],
		"key_exams": ["pied_d"],
		"diagnosis": "entorse",
		"differentials": ["fracture_cheville", "rupture_achille", "fracture_5mt"],
		"treatment": {
			"good": ["glace_repos", "attelle"],
			"ok": ["paracetamol", "kine"],
			"bad": ["radio_cheville", "platre"],
		},
		"options": ["glace_repos", "attelle", "paracetamol", "kine", "radio_cheville", "platre", "repos_lit"],
		"teaching": "Règles d'Ottawa négatives (appui possible, pas de douleur osseuse) : la radiographie n'est pas indiquée. Protocole glace-repos-compression-surélévation, contention souple et reprise progressive de l'appui.",
	},
	"diabete": {
		"patient": {"name": "Nadia Benali", "age": 58, "sex": "F", "job": "Aide-soignante",
			"avatar": "nadia_benali", "voice": "siwis", "pitch": -1.2},
		"motif": "Suivi du diabète — résultats de prise de sang",
		"history": "Diabète de type 2 depuis 6 ans. Surpoids (IMC 31). Pas de complication connue.",
		"greeting": "Bonjour docteur, je vous apporte ma prise de sang. L'hémoglobine glyquée n'est pas bonne, je crois.",
		"answers": {
			"debut": "Le diabète, ça fait six ans. L'hémoglobine glyquée est à huit virgule un pour cent ; elle était à sept virgule quatre il y a six mois.",
			"description": "Je me sens bien. Un peu plus soif ces temps-ci.",
			"autres": "Pas de problème de pieds, pas de troubles de la vue.",
			"traitements": "Metformine, mille milligrammes matin et soir.",
			"mode_vie": "Je ne fume pas. Avec mes horaires, je mange mal et je ne fais pas de sport.",
		},
		"vitals": {"ta": "132/80", "glyc": 1.62},
		"findings": {
			"pied_d": "Pied droit : pas de plaie, pas d'hyperkératose. Sensibilité au monofilament conservée. Pouls pédieux perçus.",
			"pied_g": "Pied gauche : pas de plaie, pas d'hyperkératose. Sensibilité au monofilament conservée. Pouls pédieux perçus.",
		},
		"key_exams": ["glycemie", "pied_d|pied_g", "ta"],
		"diagnosis": "dt2_desequilibre",
		"differentials": ["dt2_equilibre", "hypothyroidie", "pyelonephrite"],
		"treatment": {
			"good": ["isglt2", "hygiene_vie"],
			"ok": ["bilan_bio", "pieds"],
			"bad": ["insuline", "arret_metformine"],
		},
		"options": ["isglt2", "hygiene_vie", "bilan_bio", "pieds", "insuline", "arret_metformine", "renouveler_seul"],
		"teaching": "HbA1c au-dessus de l'objectif sous metformine seule : on intensifie (ajout d'un iSGLT2 ou d'un aGLP-1, avec bénéfice cardio-rénal) et on renforce les mesures hygiéno-diététiques. L'insuline n'est pas indiquée d'emblée à ce stade.",
	},
	"gastro": {
		"patient": {"name": "Emma Roussel", "age": 22, "sex": "F", "job": "Serveuse",
			"avatar": "emma_roussel", "voice": "siwis", "pitch": 1.0, "mood": "tired"},
		"motif": "Diarrhées, vomissements",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour… J'ai été malade toute la nuit. Toute ma colocation a eu la même chose.",
		"answers": {
			"debut": "Hier soir.",
			"description": "J'ai vomi trois fois et j'ai la diarrhée. Des crampes au ventre.",
			"fievre": "Trente-sept huit hier soir.",
			"autres": "Pas de sang dans les selles. J'arrive à boire un peu depuis ce matin.",
		},
		"vitals": {"temp": 37.7, "fc": 88, "ta": "112/70"},
		"findings": {
			"abdomen": "Abdomen souple, sensibilité diffuse modérée, sans défense. Bruits hydroaériques augmentés. Fosse iliaque droite indolore.",
			"respiration": "FR 16/min. Muqueuses humides, pas de pli cutané.",
		},
		"pain": ["abdomen"],
		"key_exams": ["abdomen", "temp", "ta"],
		"diagnosis": "gea",
		"differentials": ["appendicite", "toxi_infection", "colique_nephretique"],
		"treatment": {
			"good": ["sro", "surveillance"],
			"ok": ["paracetamol", "arret_travail", "hydratation"],
			"bad": ["antibiotique_gea", "hospitalisation", "ains"],
		},
		"options": ["sro", "surveillance", "paracetamol", "arret_travail", "hydratation", "antibiotique_gea", "hospitalisation", "ains"],
		"teaching": "Gastro-entérite virale sans signe de gravité ni déshydratation : réhydratation (SRO), règles d'hygiène et surveillance. Pas d'antibiotique. Les AINS sont à éviter en cas de déshydratation.",
	},
	"pneumopathie": {
		"patient": {"name": "Bernard Faure", "age": 72, "sex": "M", "job": "Retraité (boulanger)",
			"avatar": "bernard_faure", "voice": "mls", "pitch": -2.6, "walk": "walk_slow", "cough": true, "mood": "tired", "skin": "flushed"},
		"motif": "Toux et fièvre",
		"history": "BPCO légère. Ancien fumeur, arrêt il y a dix ans.",
		"greeting": "Bonjour docteur. Ça fait trois jours que je traîne cette fièvre.",
		"answers": {
			"debut": "Trois jours.",
			"description": "Je tousse et je crache jaune. Je suis essoufflé quand je monte l'escalier.",
			"fievre": "Trente-neuf hier soir, avec des frissons.",
			"autres": "Un point de côté à droite quand je respire fort. Je mange et je bois normalement.",
			"traitements": "Un inhalateur pour ma BPCO.",
			"mode_vie": "J'ai arrêté de fumer il y a dix ans. Je jardine encore un peu.",
		},
		"vitals": {"temp": 39.1, "fc": 104, "fr": 22, "spo2": 94, "ta": "128/76"},
		"findings": {
			"pulmo_d": "Foyer de crépitants à la base droite, avec un souffle tubaire.",
			"pulmo_g": "Murmure vésiculaire normal à gauche.",
			"cardio": "Tachycardie régulière, pas de souffle.",
			"respiration": "FR 22/min, légère polypnée, pas de signe de lutte.",
		},
		"sounds": {"pulmo_d": "crepitants", "cardio": "rapide"},
		"key_exams": ["pulmo_d", "temp", "spo2"],
		"diagnosis": "pneumopathie",
		"differentials": ["bronchite", "asthme", "sca"],
		"treatment": {
			"good": ["amoxicilline", "reevaluation"],
			"ok": ["radio_thorax", "paracetamol", "surveillance"],
			"bad": ["corticoides", "fluoroquinolone", "antibiotique_gea"],
		},
		"options": ["amoxicilline", "reevaluation", "radio_thorax", "paracetamol", "surveillance", "corticoides", "fluoroquinolone"],
		"teaching": "Pneumopathie (fièvre, crépitants en foyer) sans critère de gravité majeur : amoxicilline 1 g trois fois par jour et réévaluation obligatoire à 48–72 h. La radiographie confirme le diagnostic. Les fluoroquinolones ne sont pas un traitement de première intention.",
	},
	"zona": {
		"patient": {"name": "Martine Girard", "age": 62, "sex": "F", "job": "Pharmacienne à la retraite",
			"avatar": "martine_girard", "voice": "siwis", "pitch": -1.5, "mood": "pain"},
		"motif": "SANS RDV — boutons douloureux",
		"history": "Varicelle dans l'enfance. Hypothyroïdie traitée.",
		"greeting": "Bonjour docteur, pardon de venir sans rendez-vous. J'ai des boutons qui me brûlent sur le côté droit.",
		"answers": {
			"debut": "Les boutons sont sortis hier. Mais ça brûlait déjà depuis trois jours à cet endroit.",
			"description": "Une brûlure, comme des décharges électriques, sur le flanc droit.",
			"traitements": "Du Lévothyrox.",
		},
		"findings": {
			"peau_d": "Vésicules groupées en bouquet sur fond rouge, disposées en bande sur le flanc droit (dermatome T6), s'arrêtant à la ligne médiane.",
		},
		"visual": {"peau_d": "zona"},
		"pain": ["flank_r"],
		"key_exams": ["peau_d"],
		"diagnosis": "zona",
		"differentials": ["herpes", "eczema", "sca"],
		"treatment": {
			"good": ["valaciclovir", "paracetamol"],
			"ok": ["surveillance"],
			"bad": ["corticoides", "amoxicilline", "creme"],
		},
		"options": ["valaciclovir", "paracetamol", "surveillance", "corticoides", "amoxicilline", "creme"],
		"teaching": "Zona typique (éruption vésiculeuse unilatérale d'un dermatome). Après 50 ans et dans les 72 heures suivant l'éruption : valaciclovir 7 jours pour limiter les douleurs post-zostériennes, avec des antalgiques adaptés.",
	},
	"migraine": {
		"patient": {"name": "Antoine Leroy", "age": 29, "sex": "M", "job": "Développeur",
			"avatar": "antoine_leroy", "voice": "gilles", "pitch": 0.0, "mood": "pain"},
		"motif": "Mal de tête",
		"history": "Céphalées similaires depuis l'adolescence, jamais explorées.",
		"greeting": "Bonjour docteur. J'ai encore une de mes migraines… et celle-ci ne passe pas.",
		"answers": {
			"debut": "Depuis ce matin, au réveil. Ça s'est installé progressivement.",
			"description": "Ça tape d'un seul côté, à gauche. La lumière et le bruit me gênent.",
			"autres": "J'ai eu la nausée. Pas de troubles de la vision avant la crise.",
			"traitements": "Du paracétamol, mais ça ne fait rien.",
		},
		"extra_questions": [
			{"text": "La douleur a-t-elle été brutale, en coup de tonnerre ?", "answer": "Non, ça a monté doucement, comme d'habitude."},
			{"text": "Est-ce la pire douleur de votre vie ?", "answer": "Non, c'est comme mes crises habituelles."},
		],
		"vitals": {"ta": "128/80"},
		"findings": {
			"force": "Force et sensibilité normales et symétriques.",
			"reflexes": "Réflexes ostéotendineux normaux et symétriques.",
			"nuque": "Pas de raideur de nuque.",
			"pupilles": "Pupilles égales et réactives. Photophobie.",
		},
		"key_exams": ["nuque", "pupilles|force|reflexes", "ta|temp"],
		"diagnosis": "migraine",
		"differentials": ["hsa", "cephalee_tension", "sinusite"],
		"treatment": {
			"good": ["ains", "triptan"],
			"ok": ["surveillance"],
			"bad": ["opioides", "scanner", "corticoides"],
		},
		"options": ["ains", "triptan", "surveillance", "opioides", "scanner", "corticoides"],
		"teaching": "Céphalée unilatérale pulsatile avec photophobie, d'installation progressive, examen normal : migraine. Traitement de crise par AINS puis triptan si insuffisant. Les opioïdes sont à éviter. Pas d'imagerie en l'absence de signe d'alerte.",
	},
}

# --- Journées du mode Histoire -------------------------------------------------------

const DAYS := [
	{
		"title": "Lundi — Premier jour",
		"intro": "Vous reprenez le cabinet du Dr Hélène Marchand, partie à la retraite après 35 ans au service de Saint-Aubin-sur-Loire.\n\nCamille, la secrétaire, vous accueille avec un café. Les patients du Dr Marchand vous attendent… et ils vont vous juger.",
		"start": 500,
		"patients": [
			{"case": "rhino", "time": 510},
			{"case": "lombalgie", "time": 530},
			{"case": "otite", "time": 540, "walk_in": true},
			{"case": "hta", "time": 560},
			{"case": "angine", "time": 585},
		],
	},
	{
		"title": "Mardi — Le bouche-à-oreille",
		"intro": "La nouvelle s'est répandue : le nouveau médecin est arrivé. La salle d'attente se remplit.\n\nRestez vigilant. En médecine générale, l'urgence vitale peut franchir la porte sans rendez-vous.",
		"start": 500,
		"patients": [
			{"case": "cystite", "time": 510},
			{"case": "asthme", "time": 530},
			{"case": "thoracique", "time": 538, "walk_in": true},
			{"case": "entorse", "time": 555},
			{"case": "diabete", "time": 580},
		],
	},
	{
		"title": "Mercredi — La visite du Dr Marchand",
		"intro": "Le Dr Marchand a promis de passer en fin de matinée pour voir comment vous vous en sortez.\n\nUne dernière matinée chargée vous attend. Montrez-lui que son cabinet est entre de bonnes mains.",
		"start": 500,
		"marchand_visit": true,
		"patients": [
			{"case": "gastro", "time": 510},
			{"case": "pneumopathie", "time": 530},
			{"case": "zona", "time": 545, "walk_in": true},
			{"case": "migraine", "time": 565},
		],
	},
]


func day_count() -> int:
	return DAYS.size()


func day_data(day: int) -> Dictionary:
	return DAYS[clampi(day - 1, 0, DAYS.size() - 1)]


func day_start_minutes(day: int) -> float:
	return float(day_data(day).get("start", 500))


func get_case(id: String) -> Dictionary:
	return CASES.get(id, {})


func treatment_label(id: String) -> String:
	return TREATMENTS.get(id, [id])[0]


func treatment_line(id: String) -> String:
	var t: Array = TREATMENTS.get(id, [id, id, "rx"])
	return t[1]


func treatment_kind(id: String) -> String:
	var t: Array = TREATMENTS.get(id, [id, id, "rx"])
	return t[2]


func vitals(case_data: Dictionary) -> Dictionary:
	var v: Dictionary = ExamDB.DEFAULT_VITALS.duplicate()
	v.merge(case_data.get("vitals", {}), true)
	return v


func _fmt_num(x: float, decimals: int = 1) -> String:
	return (("%." + str(decimals) + "f") % x).replace(".", ",")


## Résultat textuel d'un examen pour un cas.
func exam_result(case_data: Dictionary, exam_id: String) -> String:
	var v := vitals(case_data)
	match exam_id:
		"ta":
			return "TA %s mmHg · FC %d/min" % [str(v["ta"]), int(v["fc"])]
		"temp":
			return "Température %s °C" % _fmt_num(float(v["temp"]))
		"spo2":
			return "SpO₂ %d %% · FC %d/min" % [int(v["spo2"]), int(v["fc"])]
		"glycemie":
			return "Glycémie capillaire : %s g/L" % _fmt_num(float(v["glyc"]), 2)
		"dep":
			var f: Dictionary = case_data.get("findings", {})
			if f.has("dep"):
				return f["dep"]
			return "Débit de pointe : %d L/min, normal pour l'âge et la taille." % int(v["dep"])
	var findings: Dictionary = case_data.get("findings", {})
	var txt: String = findings.get(exam_id, ExamDB.DEFAULT_FINDINGS.get(exam_id, "Normal."))
	return txt.format({"fr": int(v["fr"]), "fc": int(v["fc"])})


func visual_state(case_data: Dictionary, exam_id: String):
	var vis: Dictionary = case_data.get("visual", {})
	if vis.has(exam_id):
		return vis[exam_id]
	return ExamDB.DEFAULT_VISUAL.get(exam_id, "normal")


func sound_state(case_data: Dictionary, exam_id: String) -> String:
	var s: Dictionary = case_data.get("sounds", {})
	return s.get(exam_id, ExamDB.DEFAULT_SOUNDS.get(exam_id, "normal"))


## Un examen est-il « anormal » pour ce cas (utile pour la mise en évidence) ?
func exam_is_abnormal(case_data: Dictionary, exam_id: String) -> bool:
	if exam_id in ["ta", "temp", "spo2", "glycemie", "respiration"]:
		var v := vitals(case_data)
		match exam_id:
			"temp":
				return float(v["temp"]) >= 38.0
			"spo2":
				return int(v["spo2"]) < 95 or int(v["fc"]) > 100
			"glycemie":
				return float(v["glyc"]) > 1.4
			"respiration":
				return int(v["fr"]) > 20
			"ta":
				var parts := str(v["ta"]).split("/")
				return parts.size() == 2 and (int(parts[0]) >= 140 or int(parts[1]) >= 90)
	var f: Dictionary = case_data.get("findings", {})
	if not f.has(exam_id):
		return false
	var low := String(f[exam_id]).to_lower()
	for ok in ["normal", "négatif", "pas de crépitant", "indolore", "pas d'œdème", "conservée"]:
		if low.begins_with(ok) or (ok in low and not ("positif" in low or "rouge" in low or "douleur" in low)):
			return false
	return true


func answer(case_data: Dictionary, question_id: String) -> String:
	var answers: Dictionary = case_data.get("answers", {})
	if answers.has(question_id):
		return answers[question_id]
	if question_id == "antecedents":
		return case_data.get("history", DEFAULT_ANSWERS["antecedents"])
	return DEFAULT_ANSWERS.get(question_id, "Je ne sais pas.")


## Sépare « (La mère) Texte » en [locuteur, texte].
func split_speaker(text: String) -> Array:
	if text.begins_with("(") and ") " in text:
		var close := text.find(") ")
		return [text.substr(1, close - 1), text.substr(close + 2)]
	return ["", text]


## Texte prononcé (identique pour la génération des voix et la lecture).
func speech_text(text: String) -> String:
	var t := String(split_speaker(text)[1])
	t = t.replace("…", "...").replace("°C", " degrés").replace(" %", " pour cent")
	return t.strip_edges()


## Évalue une consultation et renvoie un résultat complet.
func evaluate(case_id: String, diagnosis: String, chosen: Array, exams_done: Array, questions: Array, minutes_spent: float, waited: float) -> Dictionary:
	var c := get_case(case_id)
	var t: Dictionary = c.get("treatment", {})
	var good: Array = t.get("good", [])
	var ok: Array = t.get("ok", [])
	var bad: Array = t.get("bad", [])
	var critical: Array = t.get("critical", [])
	var notes: Array[String] = []
	var praise: Array[String] = []

	var diagnosis_ok: bool = diagnosis == c.get("diagnosis", "")
	var score := 35.0 if diagnosis_ok else 0.0
	if not diagnosis_ok:
		notes.append("Diagnostic attendu : %s." % DIAGNOSES.get(c.get("diagnosis", ""), "?"))

	var per_good := 35.0 / maxf(1.0, good.size())
	for g in good:
		if g in chosen:
			score += per_good
		else:
			notes.append("Oubli : %s." % treatment_label(g))
	for o in chosen:
		if o in bad:
			score -= 15.0
			notes.append("Inadapté : %s." % treatment_label(o))
		elif o in ok:
			score += 1.5

	# Examens clés
	var keys: Array = c.get("key_exams", [])
	var key_done := 0
	for k in keys:
		var alts := String(k).split("|")
		var hit := false
		for a in alts:
			if a in exams_done:
				hit = true
		if hit:
			key_done += 1
		else:
			notes.append("Examen utile non réalisé : %s." % ExamDB.EXAMS.get(alts[0], {}).get("name", alts[0]).to_lower())
	if not keys.is_empty():
		score += 20.0 * float(key_done) / keys.size()
		if key_done == keys.size():
			praise.append("Examen clinique ciblé et complet.")
	else:
		score += 20.0

	var required: String = c.get("required_exam", "")
	if required != "" and not (required in exams_done):
		score -= 10.0
		notes.append("Examen indispensable non réalisé : %s." % ExamDB.EXAMS.get(required, {}).get("name", required))

	var asked: int = questions.size()
	if asked >= 4:
		score += 5.0
		praise.append("Interrogatoire soigneux.")
	elif asked < 2:
		notes.append("Interrogatoire trop succinct.")

	var critical_miss := false
	for cr in critical:
		if not (cr in chosen):
			critical_miss = true
	if critical_miss:
		score = minf(score, 5.0)
		notes.push_front("ERREUR GRAVE : urgence vitale non prise en charge.")

	if c.get("urgent", false) and minutes_spent > 15.0:
		score -= 10.0
		notes.append("Prise en charge trop lente pour une urgence (%d min)." % int(minutes_spent))
	score = clampf(score, 0.0, 100.0)

	var satisfaction := 100.0 - maxf(0.0, waited - 10.0) * 1.6 - maxf(0.0, minutes_spent - 25.0) * 1.2
	if diagnosis_ok:
		satisfaction += 8.0
	satisfaction = clampf(satisfaction, 0.0, 100.0)

	var grade := "A"
	if score < 85.0: grade = "B"
	if score < 65.0: grade = "C"
	if score < 45.0: grade = "D"
	if critical_miss: grade = "F"

	var rep := (score - 55.0) / 6.0 + (satisfaction - 60.0) / 20.0
	if critical_miss:
		rep -= 12.0

	return {
		"case_id": case_id,
		"name": c.get("patient", {}).get("name", "?"),
		"diagnosis_ok": diagnosis_ok,
		"diagnosis_expected": DIAGNOSES.get(c.get("diagnosis", ""), "?"),
		"diagnosis_given": DIAGNOSES.get(diagnosis, "—"),
		"score": score,
		"grade": grade,
		"satisfaction": satisfaction,
		"notes": notes,
		"praise": praise,
		"teaching": c.get("teaching", ""),
		"critical_miss": critical_miss,
		"samu": "samu" in chosen,
		"reputation_delta": rep,
		"fee": 30.0,
		"minutes": minutes_spent,
		"exams": exams_done.size(),
		"questions": asked,
	}
