extends Node
## Base de données médicale du mode Histoire (médecine générale).
## Chargée en autoload sous le nom « Cases ».
##
## Les contenus sont simplifiés à visée ludique et pédagogique : ils ne
## remplacent pas les recommandations officielles (HAS, sociétés savantes).

# --- Interrogatoire -----------------------------------------------------------

const QUESTIONS := [
	{"id": "debut", "text": "Depuis quand avez-vous ces symptômes ?"},
	{"id": "description", "text": "Pouvez-vous me décrire ce que vous ressentez ?"},
	{"id": "fievre", "text": "Avez-vous eu de la fièvre ?"},
	{"id": "autres", "text": "Avez-vous remarqué d'autres symptômes ?"},
	{"id": "antecedents", "text": "Avez-vous des antécédents médicaux ou chirurgicaux ?"},
	{"id": "traitements", "text": "Prenez-vous des médicaments en ce moment ?"},
	{"id": "allergies", "text": "Avez-vous des allergies, notamment médicamenteuses ?"},
	{"id": "mode_vie", "text": "Tabac, alcool, activité physique ?"},
]

const DEFAULT_ANSWERS := {
	"debut": "Je ne sais plus trop… quelques jours, je dirais.",
	"description": "C'est difficile à expliquer, docteur.",
	"fievre": "Non, pas de fièvre.",
	"autres": "Non, rien d'autre de particulier.",
	"antecedents": "Non, rien de spécial.",
	"traitements": "Non, aucun traitement.",
	"allergies": "Pas que je sache.",
	"mode_vie": "Je ne fume pas, un verre de temps en temps.",
}

# --- Examens ------------------------------------------------------------------
# `table` : l'examen se fait sur la table d'examen (le patient s'y installe).

const EXAMS := [
	{"id": "constantes", "name": "Constantes vitales", "detail": "TA · FC · T° · SpO₂ · FR", "time": 2, "kind": "clinique", "table": false},
	{"id": "cardio", "name": "Auscultation cardiaque", "detail": "Stéthoscope", "time": 1, "kind": "clinique", "table": true},
	{"id": "pulmo", "name": "Auscultation pulmonaire", "detail": "Stéthoscope", "time": 1, "kind": "clinique", "table": true},
	{"id": "orl", "name": "Examen de la gorge", "detail": "Abaisse-langue · lampe", "time": 1, "kind": "clinique", "table": false},
	{"id": "otoscopie", "name": "Otoscopie", "detail": "Tympans", "time": 1, "kind": "clinique", "table": false},
	{"id": "peau", "name": "Peau et ganglions", "detail": "Inspection · palpation", "time": 1, "kind": "clinique", "table": false},
	{"id": "abdomen", "name": "Palpation abdominale", "detail": "Allongé", "time": 2, "kind": "clinique", "table": true},
	{"id": "neuro", "name": "Examen neurologique", "detail": "Force · sensibilité · réflexes", "time": 2, "kind": "clinique", "table": true},
	{"id": "locomoteur", "name": "Examen ostéo-articulaire", "detail": "Rachis · membres", "time": 2, "kind": "clinique", "table": true},
	{"id": "tdr", "name": "TROD angine", "detail": "Streptocoque A · 5 min", "time": 3, "kind": "test", "table": false},
	{"id": "bu", "name": "Bandelette urinaire", "detail": "Leucocytes · nitrites", "time": 2, "kind": "test", "table": false},
	{"id": "glycemie", "name": "Glycémie capillaire", "detail": "Dextro", "time": 1, "kind": "test", "table": false},
	{"id": "dep", "name": "Débit expiratoire de pointe", "detail": "Peak-flow", "time": 2, "kind": "test", "table": false},
	{"id": "ecg", "name": "ECG 12 dérivations", "detail": "Électrocardiogramme", "time": 5, "kind": "test", "table": true},
]

const DEFAULT_FINDINGS := {
	"cardio": "Bruits du cœur réguliers, pas de souffle audible.",
	"pulmo": "Murmure vésiculaire symétrique, pas de bruit surajouté.",
	"orl": "Pharynx et amygdales d'aspect normal.",
	"otoscopie": "Tympans gris nacrés, bien visibles des deux côtés.",
	"peau": "Pas de lésion cutanée. Pas d'adénopathie palpable.",
	"abdomen": "Abdomen souple, indolore, pas de masse palpable.",
	"neuro": "Force, sensibilité et réflexes normaux et symétriques.",
	"locomoteur": "Mobilité articulaire normale, pas de douleur provoquée.",
	"tdr": "Négatif.",
	"bu": "Négative (leucocytes −, nitrites −, sang −, glucose −).",
	"glycemie": "0,98 g/L.",
	"dep": "Dans les normes pour l'âge et la taille.",
	"ecg": "Rythme sinusal régulier, pas de trouble de la repolarisation.",
}

const DEFAULT_VITALS := {"ta": "124/78", "fc": 74, "temp": 36.8, "spo2": 98, "fr": 15}

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

const TREATMENTS := {
	"paracetamol": "Paracétamol",
	"ains": "Anti-inflammatoire (ibuprofène)",
	"amoxicilline": "Amoxicilline",
	"fluoroquinolone": "Ciprofloxacine (fluoroquinolone)",
	"fosfomycine": "Fosfomycine — dose unique",
	"corticoides": "Corticoïdes par voie orale",
	"lavage_nez": "Lavages de nez au sérum physiologique",
	"gouttes_oreille": "Gouttes auriculaires antibiotiques",
	"rester_actif": "Conseil : rester actif, éviter le repos au lit",
	"repos_lit": "Repos strict au lit 1 semaine",
	"radio_rachis": "Radiographie du rachis lombaire",
	"radio_cheville": "Radiographie de la cheville",
	"radio_thorax": "Radiographie du thorax",
	"kine": "Séances de kinésithérapie",
	"arret_travail": "Arrêt de travail court",
	"hygiene_vie": "Règles hygiéno-diététiques",
	"intensifier_hta": "Ajouter un IEC ou un ARA2 (bithérapie)",
	"renouveler_seul": "Renouveler l'ordonnance à l'identique",
	"bilan_bio": "Bilan biologique de suivi",
	"urgences": "Adresser aux urgences par ses propres moyens",
	"samu": "Appeler le SAMU (15) immédiatement",
	"aspirine": "Aspirine (en lien avec le SAMU)",
	"ipp": "Inhibiteur de la pompe à protons",
	"anxiolytique": "Anxiolytique",
	"ecbu": "ECBU (examen cytobactériologique des urines)",
	"hydratation": "Hydratation abondante",
	"salbutamol": "Salbutamol inhalé (bronchodilatateur)",
	"traitement_fond": "Corticoïde inhalé (traitement de fond)",
	"glace_repos": "Glace, repos relatif, compression, surélévation",
	"attelle": "Attelle / chevillère de maintien",
	"platre": "Plâtre 6 semaines",
	"isglt2": "Ajouter un iSGLT2 ou un aGLP-1",
	"insuline": "Débuter une insuline",
	"arret_metformine": "Arrêter la metformine",
	"pieds": "Examen des pieds et éducation podologique",
	"sro": "Soluté de réhydratation orale",
	"antibiotique_gea": "Antibiotique (amoxicilline)",
	"reevaluation": "Réévaluation à 48–72 h",
	"hospitalisation": "Hospitalisation",
	"valaciclovir": "Valaciclovir (antiviral) 7 jours",
	"creme": "Crème hydratante",
	"triptan": "Triptan",
	"opioides": "Codéine / tramadol (opioïdes)",
	"scanner": "Scanner cérébral en urgence",
	"surveillance": "Consignes de surveillance (reconsulter si aggravation)",
}

# --- Dossiers patients --------------------------------------------------------------
# treatment.good : attendu (bonus, malus si oublié)
# treatment.ok   : acceptable (neutre ou petit bonus)
# treatment.bad  : inadapté / dangereux (malus)
# treatment.critical : oubli = erreur grave (urgence vitale)

const CASES := {
	"rhino": {
		"patient": {"name": "Lucas Bernard", "age": 28, "sex": "M", "job": "Graphiste",
			"look": {"skin": 1, "hair": "short", "hair_color": Color(0.22, 0.14, 0.08), "top": Color(0.18, 0.32, 0.55), "bottom": Color(0.16, 0.17, 0.2)}},
		"motif": "Nez qui coule, gorge qui gratte",
		"history": "Aucun antécédent notable.",
		"greeting": "Bonjour docteur. Je crois que j'ai attrapé un rhume, mais je préfère vérifier.",
		"answers": {
			"debut": "Ça a commencé il y a trois jours.",
			"description": "J'ai le nez bouché, ça coule clair, la gorge qui gratte un peu. Je suis un peu fatigué.",
			"fievre": "Un peu, 37,9 °C hier soir. Aujourd'hui ça va mieux.",
			"autres": "Je tousse un peu le matin, c'est tout.",
		},
		"extra_questions": [
			{"text": "Avez-vous mal au visage, sous les yeux ?", "answer": "Non, pas vraiment."},
		],
		"vitals": {"temp": 37.6},
		"findings": {
			"orl": "Pharynx légèrement érythémateux, sans exsudat. Rhinorrhée claire. Amygdales normales.",
			"peau": "Petites adénopathies cervicales souples, indolores.",
		},
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
			"look": {"skin": 0, "hair": "short", "hair_color": Color(0.45, 0.42, 0.4), "top": Color(0.42, 0.45, 0.32), "bottom": Color(0.2, 0.24, 0.32), "build": 1.15, "beard": true}},
		"motif": "Mal au dos",
		"history": "Appendicectomie à 20 ans. Pas d'autre antécédent.",
		"greeting": "Bonjour docteur… Aïe. Je me suis bloqué le dos hier au travail.",
		"answers": {
			"debut": "Hier après-midi, en soulevant un carton de 25 kilos.",
			"description": "Ça tire en bas du dos, des deux côtés. Ça ne descend pas dans les jambes.",
			"autres": "Non. Pas de problème pour uriner, pas de fourmillements, j'ai bien dormi malgré tout.",
			"traitements": "J'ai pris un doliprane hier soir, ça a un peu soulagé.",
			"mode_vie": "Je fume dix cigarettes par jour. Pas de sport, mon travail est physique.",
		},
		"extra_questions": [
			{"text": "Avez-vous perdu du poids récemment ?", "answer": "Non, pas du tout."},
			{"text": "La douleur vous réveille-t-elle la nuit ?", "answer": "Seulement quand je me retourne dans le lit."},
		],
		"vitals": {"ta": "136/84", "fc": 80},
		"findings": {
			"locomoteur": "Contracture des muscles paravertébraux lombaires. Raideur à la flexion. Signe de Lasègue négatif des deux côtés.",
			"neuro": "Force, sensibilité et réflexes ostéotendineux normaux et symétriques aux membres inférieurs.",
		},
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
		"patient": {"name": "Léo Dubois", "age": 4, "sex": "M", "job": "Accompagné de sa mère",
			"look": {"skin": 0, "hair": "short", "hair_color": Color(0.62, 0.45, 0.22), "top": Color(0.85, 0.42, 0.18), "bottom": Color(0.22, 0.3, 0.5), "height": 0.62}},
		"motif": "Fièvre et douleur d'oreille",
		"history": "Né à terme. Vaccinations à jour.",
		"greeting": "(La mère) Bonjour docteur, merci de nous prendre sans rendez-vous. Il a pleuré toute la nuit en se tenant l'oreille.",
		"answers": {
			"debut": "(La mère) Depuis hier soir. Il avait le nez qui coulait depuis trois jours.",
			"description": "(Léo) J'ai mal à l'oreille… (il montre l'oreille droite)",
			"fievre": "(La mère) 38,9 °C cette nuit, malgré le paracétamol.",
			"autres": "(La mère) Il mange moins, il est grognon.",
			"allergies": "(La mère) Aucune allergie connue.",
			"mode_vie": "(La mère) Il est en moyenne section de maternelle.",
		},
		"vitals": {"temp": 38.7, "fc": 118, "ta": "—", "fr": 24},
		"findings": {
			"otoscopie": "Tympan droit rouge, bombé, avec perte des reliefs : aspect purulent. Tympan gauche normal.",
			"orl": "Rhinorrhée purulente, pharynx discrètement inflammatoire.",
		},
		"diagnosis": "oma",
		"differentials": ["otite_externe", "otite_congestive", "angine_virale"],
		"treatment": {
			"good": ["amoxicilline", "paracetamol"],
			"ok": ["surveillance", "lavage_nez"],
			"bad": ["gouttes_oreille", "corticoides", "fluoroquinolone"],
		},
		"options": ["amoxicilline", "paracetamol", "surveillance", "lavage_nez", "gouttes_oreille", "corticoides", "fluoroquinolone"],
		"teaching": "OMA purulente (tympan bombé) chez un enfant de plus de 2 ans avec fièvre et otalgie marquées : amoxicilline 5 jours + antalgique. Les gouttes auriculaires ne traitent pas une otite moyenne (le tympan est fermé).",
	},
	"hta": {
		"patient": {"name": "Monique Lefèvre", "age": 67, "sex": "F", "job": "Retraitée (institutrice)",
			"look": {"skin": 0, "hair": "bun", "hair_color": Color(0.78, 0.76, 0.74), "top": Color(0.55, 0.22, 0.3), "bottom": Color(0.2, 0.2, 0.24), "height": 0.93}},
		"motif": "Renouvellement d'ordonnance — tension",
		"history": "HTA depuis 5 ans sous amlodipine 5 mg. Ménopausée. Pas de diabète connu.",
		"greeting": "Bonjour docteur. Le Dr Marchand m'a beaucoup parlé de vous ! Je viens pour mon ordonnance de tension.",
		"answers": {
			"debut": "La tension, ça fait cinq ans. Mais mon appareil affiche des chiffres hauts depuis deux mois.",
			"description": "Je me sens bien. Parfois un petit mal de tête le matin.",
			"autres": "Non, pas de douleur dans la poitrine, pas d'essoufflement.",
			"traitements": "Amlodipine 5 mg le matin. Je ne l'oublie jamais.",
			"mode_vie": "Je ne fume pas. Je marche un peu. J'aime bien la charcuterie, je l'avoue.",
		},
		"extra_questions": [
			{"text": "Avez-vous noté vos automesures à la maison ?", "answer": "Oui, j'ai mon carnet : en moyenne 152/92 sur la semaine, matin et soir."},
		],
		"vitals": {"ta": "158/94", "fc": 70},
		"findings": {
			"cardio": "Bruits du cœur réguliers, pas de souffle. Pouls périphériques présents.",
		},
		"diagnosis": "hta_non_controlee",
		"differentials": ["hta_controlee", "blouse_blanche", "hypotension_ortho"],
		"treatment": {
			"good": ["intensifier_hta", "hygiene_vie", "bilan_bio"],
			"ok": ["surveillance"],
			"bad": ["renouveler_seul", "urgences", "anxiolytique"],
		},
		"options": ["intensifier_hta", "hygiene_vie", "bilan_bio", "surveillance", "renouveler_seul", "urgences", "anxiolytique"],
		"teaching": "Les automesures (152/92) confirment une HTA non contrôlée sous monothérapie : on passe à une bithérapie (ajout IEC ou ARA2), on renforce les règles hygiéno-diététiques (sel) et on contrôle créatinine et kaliémie.",
	},
	"angine": {
		"patient": {"name": "Inès Garcia", "age": 19, "sex": "F", "job": "Étudiante",
			"look": {"skin": 2, "hair": "long", "hair_color": Color(0.1, 0.07, 0.05), "top": Color(0.9, 0.88, 0.84), "bottom": Color(0.18, 0.22, 0.36), "height": 0.96}},
		"motif": "Mal de gorge, fièvre",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour… (voix étouffée) J'ai super mal à la gorge, j'ai du mal à avaler.",
		"answers": {
			"debut": "Avant-hier, d'un coup.",
			"description": "Très mal en avalant, même la salive. Mal à la tête aussi.",
			"fievre": "Oui, 38,8 °C ce matin.",
			"autres": "Non, je ne tousse pas et je n'ai pas le nez qui coule.",
			"allergies": "Aucune allergie.",
		},
		"vitals": {"temp": 38.7, "fc": 96},
		"findings": {
			"orl": "Amygdales augmentées de volume, très érythémateuses, recouvertes d'un exsudat blanchâtre.",
			"peau": "Adénopathies cervicales antérieures sensibles. Pas de rash.",
			"tdr": "POSITIF — streptocoque du groupe A.",
		},
		"diagnosis": "angine_strepto",
		"differentials": ["angine_virale", "mononucleose", "rhinopharyngite"],
		"required_exam": "tdr",
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
			"look": {"skin": 0, "hair": "long", "hair_color": Color(0.72, 0.55, 0.3), "top": Color(0.3, 0.5, 0.45), "bottom": Color(0.15, 0.15, 0.18), "height": 0.97}},
		"motif": "Brûlures urinaires",
		"history": "Une cystite il y a 2 ans. Pas de grossesse en cours.",
		"greeting": "Bonjour docteur. Je crois que c'est encore une infection urinaire…",
		"answers": {
			"debut": "Depuis hier matin.",
			"description": "Ça brûle quand j'urine et j'ai envie d'y aller tout le temps.",
			"fievre": "Non, pas de fièvre.",
			"autres": "Pas de douleur dans le dos, pas de pertes inhabituelles.",
			"traitements": "Pilule contraceptive. Test de grossesse négatif la semaine dernière.",
		},
		"vitals": {"temp": 36.9},
		"findings": {
			"bu": "Leucocytes +++, nitrites + : BU positive.",
			"abdomen": "Discrète sensibilité sus-pubienne. Fosses lombaires indolores.",
		},
		"diagnosis": "cystite",
		"differentials": ["pyelonephrite", "vaginite", "colique_nephretique"],
		"treatment": {
			"good": ["fosfomycine", "hydratation"],
			"ok": ["surveillance"],
			"bad": ["fluoroquinolone", "amoxicilline", "ecbu"],
		},
		"options": ["fosfomycine", "hydratation", "surveillance", "fluoroquinolone", "amoxicilline", "ecbu"],
		"teaching": "Cystite simple (pas de fièvre, pas de douleur lombaire, BU positive) : fosfomycine-trométamol en dose unique. L'ECBU n'est pas nécessaire, les fluoroquinolones sont à éviter en première intention.",
	},
	"asthme": {
		"patient": {"name": "Thomas Petit", "age": 24, "sex": "M", "job": "Cuisinier",
			"look": {"skin": 3, "hair": "short", "hair_color": Color(0.05, 0.04, 0.03), "top": Color(0.15, 0.15, 0.17), "bottom": Color(0.3, 0.3, 0.33)}},
		"motif": "Gêne respiratoire, sifflements",
		"history": "Asthme depuis l'enfance. Allergie aux pollens de graminées.",
		"greeting": "Bonjour docteur. Mon asthme… ça siffle depuis deux jours. (il parle par phrases complètes)",
		"answers": {
			"debut": "Depuis deux jours, surtout la nuit. C'est la saison des pollens.",
			"description": "J'ai la poitrine qui serre et ça siffle. La Ventoline me soulage quelques heures.",
			"autres": "Je tousse la nuit. Pas de fièvre, pas de crachats.",
			"traitements": "Juste ma Ventoline quand ça ne va pas. Je l'ai prise 6 fois hier.",
			"mode_vie": "Je ne fume pas. Les fumées de la cuisine me gênent parfois.",
		},
		"vitals": {"fr": 20, "spo2": 96, "fc": 98},
		"findings": {
			"pulmo": "Sibilants diffus dans les deux champs pulmonaires, expiration prolongée. Pas de tirage.",
			"dep": "320 L/min, soit environ 60 % de la valeur théorique.",
		},
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
	"entorse": {
		"patient": {"name": "Julie Moreau", "age": 35, "sex": "F", "job": "Comptable, coureuse amateur",
			"look": {"skin": 1, "hair": "ponytail", "hair_color": Color(0.35, 0.2, 0.1), "top": Color(0.25, 0.65, 0.75), "bottom": Color(0.12, 0.12, 0.14)}},
		"motif": "Cheville tordue",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour ! Je me suis tordu la cheville en courant ce matin, c'est malin…",
		"answers": {
			"debut": "Ce matin à 7 h, sur un trottoir.",
			"description": "Le pied est parti vers l'intérieur. Ça a gonflé sur le côté extérieur.",
			"autres": "J'ai pu marcher jusqu'à chez moi en boitant.",
		},
		"extra_questions": [
			{"text": "Avez-vous entendu un craquement ?", "answer": "Non, je ne crois pas."},
		],
		"findings": {
			"locomoteur": "Œdème et douleur en avant et sous la malléole externe (ligament latéral). Pas de douleur osseuse à la palpation du bord postérieur des malléoles ni de la base du 5e métatarsien. Appui possible (4 pas). Tendon d'Achille intact.",
		},
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
	"thoracique": {
		"patient": {"name": "Gérard Roux", "age": 61, "sex": "M", "job": "Agriculteur",
			"look": {"skin": 0, "hair": "bald", "hair_color": Color(0.6, 0.58, 0.55), "top": Color(0.35, 0.28, 0.22), "bottom": Color(0.24, 0.3, 0.4), "build": 1.2, "beard": true}},
		"motif": "SANS RDV — douleur dans la poitrine",
		"history": "Diabète de type 2. Tabac 40 paquets-années. Hypercholestérolémie non traitée.",
		"greeting": "Docteur… ça me serre dans la poitrine… Ma femme a insisté pour que je passe. (il est pâle et en sueur)",
		"answers": {
			"debut": "Depuis… quarante minutes environ. Au repos, en lisant le journal.",
			"description": "Comme un étau sur la poitrine. Ça part dans le bras gauche et la mâchoire.",
			"autres": "J'ai la nausée. Je transpire.",
			"traitements": "Metformine pour le diabète.",
			"mode_vie": "Je fume un paquet par jour depuis 40 ans.",
		},
		"vitals": {"ta": "152/90", "fc": 102, "spo2": 95, "fr": 20},
		"findings": {
			"cardio": "Bruits du cœur réguliers, rapides. Pas de souffle.",
			"pulmo": "Pas de crépitant.",
			"ecg": "Sus-décalage du segment ST en DII, DIII et aVF, avec miroir en V1-V3 : infarctus inférieur en cours.",
			"peau": "Pâleur, sueurs profuses.",
		},
		"diagnosis": "sca",
		"differentials": ["pericardite", "rgo", "attaque_panique"],
		"urgent": true,
		"treatment": {
			"good": ["samu", "aspirine"],
			"critical": ["samu"],
			"ok": [],
			"bad": ["urgences", "ipp", "anxiolytique", "paracetamol"],
		},
		"options": ["samu", "aspirine", "urgences", "ipp", "anxiolytique", "paracetamol"],
		"teaching": "Douleur thoracique constrictive irradiant au bras et à la mâchoire chez un patient à haut risque : syndrome coronarien aigu jusqu'à preuve du contraire. Appel immédiat du 15 ; ne jamais laisser le patient partir par ses propres moyens. Chaque minute compte.",
	},
	"diabete": {
		"patient": {"name": "Nadia Benali", "age": 58, "sex": "F", "job": "Aide-soignante",
			"look": {"skin": 2, "hair": "bun", "hair_color": Color(0.15, 0.1, 0.08), "top": Color(0.48, 0.38, 0.6), "bottom": Color(0.22, 0.2, 0.25), "build": 1.15, "height": 0.95}},
		"motif": "Suivi diabète — résultats de prise de sang",
		"history": "Diabète de type 2 depuis 6 ans. Surpoids (IMC 31). Pas de complication connue.",
		"greeting": "Bonjour docteur, je vous apporte ma prise de sang. L'hémoglobine glyquée n'est pas bonne, je crois.",
		"answers": {
			"debut": "Le diabète, ça fait six ans. L'HbA1c est à 8,1 %, elle était à 7,4 % il y a six mois.",
			"description": "Je me sens bien. Un peu plus soif ces temps-ci.",
			"autres": "Pas de problème de pieds, pas de troubles de la vue.",
			"traitements": "Metformine 1000 mg matin et soir.",
			"mode_vie": "Je ne fume pas. Avec mes horaires, je mange mal et je ne fais pas de sport.",
		},
		"vitals": {"ta": "132/80"},
		"findings": {
			"glycemie": "1,62 g/L (2 h après le repas).",
			"peau": "Pieds : pas de plaie, pas d'hyperkératose. Sensibilité au monofilament conservée.",
		},
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
			"look": {"skin": 1, "hair": "long", "hair_color": Color(0.8, 0.65, 0.38), "top": Color(0.72, 0.6, 0.4), "bottom": Color(0.25, 0.3, 0.45), "height": 0.95}},
		"motif": "Diarrhées, vomissements",
		"history": "Aucun antécédent.",
		"greeting": "Bonjour… j'ai été malade toute la nuit. Toute ma coloc a eu la même chose.",
		"answers": {
			"debut": "Hier soir.",
			"description": "J'ai vomi trois fois et j'ai la diarrhée. Des crampes au ventre.",
			"fievre": "37,8 °C hier.",
			"autres": "Pas de sang dans les selles. J'arrive à boire un peu depuis ce matin.",
		},
		"vitals": {"temp": 37.7, "fc": 88, "ta": "112/70"},
		"findings": {
			"abdomen": "Abdomen souple, sensibilité diffuse modérée, pas de défense. Bruits hydroaériques augmentés. Fosse iliaque droite indolore.",
			"peau": "Pas de pli cutané, muqueuses humides.",
		},
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
			"look": {"skin": 0, "hair": "short", "hair_color": Color(0.82, 0.8, 0.78), "top": Color(0.45, 0.35, 0.28), "bottom": Color(0.28, 0.28, 0.3), "height": 0.96}},
		"motif": "Toux et fièvre",
		"history": "BPCO légère. Ancien fumeur (arrêt il y a 10 ans).",
		"greeting": "Bonjour docteur. (il tousse) Ça fait trois jours que je traîne cette fièvre.",
		"answers": {
			"debut": "Trois jours.",
			"description": "Je tousse et je crache jaune. Je suis essoufflé quand je monte l'escalier.",
			"fievre": "39 °C hier soir, avec des frissons.",
			"autres": "Un point de côté à droite quand je respire fort. Je mange et je bois normalement.",
			"traitements": "Un inhalateur pour la BPCO.",
		},
		"vitals": {"temp": 39.1, "fc": 104, "fr": 22, "spo2": 94, "ta": "128/76"},
		"findings": {
			"pulmo": "Foyer de crépitants à la base droite, souffle tubaire.",
			"cardio": "Tachycardie régulière, pas de souffle.",
		},
		"diagnosis": "pneumopathie",
		"differentials": ["bronchite", "asthme", "sca"],
		"treatment": {
			"good": ["amoxicilline", "reevaluation"],
			"ok": ["radio_thorax", "paracetamol", "surveillance"],
			"bad": ["corticoides", "fluoroquinolone", "antibiotique_gea"],
		},
		"options": ["amoxicilline", "reevaluation", "radio_thorax", "paracetamol", "surveillance", "corticoides", "fluoroquinolone"],
		"teaching": "Pneumopathie (fièvre, crépitants en foyer) sans critère de gravité majeur : amoxicilline 1 g × 3/j et réévaluation obligatoire à 48–72 h. La radiographie confirme le diagnostic. Les fluoroquinolones ne sont pas un traitement de première intention.",
	},
	"zona": {
		"patient": {"name": "Martine Girard", "age": 70, "sex": "F", "job": "Retraitée (pharmacienne)",
			"look": {"skin": 0, "hair": "short", "hair_color": Color(0.85, 0.83, 0.8), "top": Color(0.25, 0.42, 0.55), "bottom": Color(0.3, 0.27, 0.25), "height": 0.92}},
		"motif": "SANS RDV — boutons douloureux",
		"history": "Varicelle dans l'enfance. Hypothyroïdie traitée.",
		"greeting": "Bonjour docteur, pardon de venir sans rendez-vous. J'ai des boutons qui me brûlent sur le côté.",
		"answers": {
			"debut": "Les boutons sont sortis hier. Mais ça brûlait déjà depuis trois jours à cet endroit.",
			"description": "Une brûlure, comme des décharges électriques, sur le flanc droit.",
			"traitements": "Lévothyrox.",
		},
		"findings": {
			"peau": "Vésicules groupées en bouquet sur fond érythémateux, disposées en bande sur le flanc droit (dermatome T6), s'arrêtant à la ligne médiane.",
		},
		"diagnosis": "zona",
		"differentials": ["herpes", "eczema", "sca"],
		"treatment": {
			"good": ["valaciclovir", "paracetamol"],
			"ok": ["surveillance"],
			"bad": ["corticoides", "amoxicilline", "creme"],
		},
		"options": ["valaciclovir", "paracetamol", "surveillance", "corticoides", "amoxicilline", "creme"],
		"teaching": "Zona typique (éruption vésiculeuse unilatérale d'un dermatome). Après 50 ans et dans les 72 h suivant l'éruption : valaciclovir 7 jours pour limiter les douleurs post-zostériennes, avec antalgiques adaptés.",
	},
	"migraine": {
		"patient": {"name": "Antoine Leroy", "age": 29, "sex": "M", "job": "Développeur",
			"look": {"skin": 1, "hair": "short", "hair_color": Color(0.3, 0.2, 0.12), "top": Color(0.2, 0.22, 0.26), "bottom": Color(0.35, 0.33, 0.3), "glasses": true}},
		"motif": "Mal de tête",
		"history": "Céphalées similaires depuis l'adolescence, jamais explorées.",
		"greeting": "Bonjour docteur. J'ai encore une de mes migraines… celle-ci ne passe pas.",
		"answers": {
			"debut": "Depuis ce matin au réveil. Ça s'est installé progressivement.",
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
			"neuro": "Examen neurologique normal. Pas de raideur de nuque.",
		},
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
		"intro": "Le Dr Marchand a promis de passer en fin de matinée pour savoir comment vous vous en sortez.\n\nUne dernière matinée chargée vous attend. Montrez-lui que son cabinet est entre de bonnes mains.",
		"start": 500,
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


func exam_def(id: String) -> Dictionary:
	for e in EXAMS:
		if e["id"] == id:
			return e
	return {}


## Résultat textuel d'un examen pour un cas donné.
func exam_result(case_data: Dictionary, exam_id: String) -> String:
	if exam_id == "constantes":
		var v: Dictionary = DEFAULT_VITALS.duplicate()
		v.merge(case_data.get("vitals", {}), true)
		return "TA %s mmHg · FC %d/min · T° %.1f °C · SpO₂ %d %% · FR %d/min" % [
			str(v["ta"]), int(v["fc"]), float(v["temp"]), int(v["spo2"]), int(v["fr"])]
	var findings: Dictionary = case_data.get("findings", {})
	if findings.has(exam_id):
		return findings[exam_id]
	return DEFAULT_FINDINGS.get(exam_id, "Normal.")


func answer(case_data: Dictionary, question_id: String) -> String:
	var answers: Dictionary = case_data.get("answers", {})
	if answers.has(question_id):
		return answers[question_id]
	if question_id == "antecedents":
		return case_data.get("history", DEFAULT_ANSWERS["antecedents"])
	return DEFAULT_ANSWERS.get(question_id, "Je ne sais pas.")


## Évalue une consultation. Renvoie un dictionnaire de résultat complet.
func evaluate(case_id: String, diagnosis: String, chosen: Array, exams_done: Array, minutes_spent: float, waited: float) -> Dictionary:
	var c := get_case(case_id)
	var t: Dictionary = c.get("treatment", {})
	var good: Array = t.get("good", [])
	var ok: Array = t.get("ok", [])
	var bad: Array = t.get("bad", [])
	var critical: Array = t.get("critical", [])
	var notes: Array[String] = []

	var diagnosis_ok: bool = diagnosis == c.get("diagnosis", "")
	var score := 40.0 if diagnosis_ok else 0.0
	if not diagnosis_ok:
		notes.append("Diagnostic attendu : %s." % DIAGNOSES.get(c.get("diagnosis", ""), "?"))

	var per_good := 40.0 / maxf(1.0, good.size())
	for g in good:
		if g in chosen:
			score += per_good
		else:
			notes.append("Oubli : %s." % TREATMENTS.get(g, g))
	for o in chosen:
		if o in bad:
			score -= 15.0
			notes.append("Inadapté : %s." % TREATMENTS.get(o, o))
		elif o in ok:
			score += 2.0

	var required: String = c.get("required_exam", "")
	if required != "" and not (required in exams_done):
		score -= 10.0
		notes.append("Examen clé non réalisé : %s." % exam_def(required).get("name", required))

	var critical_miss := false
	for cr in critical:
		if not (cr in chosen):
			critical_miss = true
	if critical_miss:
		score = minf(score, 5.0)
		notes.push_front("ERREUR GRAVE : urgence vitale non prise en charge.")

	var thorough := clampf(float(exams_done.size()) * 2.0, 0.0, 10.0)
	score += thorough
	if c.get("urgent", false) and minutes_spent > 15.0:
		score -= 10.0
		notes.append("Prise en charge trop lente pour une urgence (%d min)." % int(minutes_spent))
	score = clampf(score, 0.0, 100.0)

	var satisfaction := 100.0 - maxf(0.0, waited - 10.0) * 2.0 - maxf(0.0, minutes_spent - 20.0) * 1.5
	if diagnosis_ok:
		satisfaction += 10.0
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
		"teaching": c.get("teaching", ""),
		"critical_miss": critical_miss,
		"samu": "samu" in chosen,
		"reputation_delta": rep,
		"fee": Game.FEE,
		"minutes": minutes_spent,
	}
