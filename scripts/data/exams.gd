class_name ExamDB
extends RefCounted
## Outils du médecin, zones du corps et examens physiques.
## Un examen = un outil appliqué sur une zone du corps du patient.

## Outils, dans l'ordre de la roue (sens horaire depuis le haut).
const TOOLS := [
	{"id": "mains", "name": "Mains", "desc": "Palper, inspecter, tester la force", "icon": "hand"},
	{"id": "stethoscope", "name": "Stéthoscope", "desc": "Ausculter le cœur et les poumons", "icon": "stethoscope"},
	{"id": "tensiometre", "name": "Tensiomètre", "desc": "Tension artérielle au bras", "icon": "gauge"},
	{"id": "thermometre", "name": "Thermomètre", "desc": "Température (front ou oreille)", "icon": "thermometer"},
	{"id": "oxymetre", "name": "Oxymètre", "desc": "Saturation et pouls au doigt", "icon": "heart-pulse"},
	{"id": "otoscope", "name": "Otoscope", "desc": "Examiner les tympans", "icon": "ear"},
	{"id": "lampe", "name": "Lampe et abaisse-langue", "desc": "Gorge et pupilles", "icon": "flashlight"},
	{"id": "marteau", "name": "Marteau à réflexes", "desc": "Réflexes aux genoux", "icon": "hammer"},
	{"id": "debitmetre", "name": "Débitmètre de pointe", "desc": "Souffle (asthme)", "icon": "wind"},
	{"id": "glucometre", "name": "Lecteur de glycémie", "desc": "Glycémie au bout du doigt", "icon": "droplet"},
	{"id": "trod", "name": "TROD angine", "desc": "Prélèvement de gorge, test rapide", "icon": "test-tube"},
	{"id": "bandelette", "name": "Bandelette urinaire", "desc": "Analyse d'urine rapide", "icon": "flask"},
	{"id": "ecg", "name": "Électrocardiogramme", "desc": "Électrodes sur le thorax", "icon": "activity"},
]

## Zones du corps : os de rattachement, décalage dans le repère de l'avatar
## (avatar tourné vers +Z, sa gauche vers +X) et rayon de la zone.
const SPOTS := {
	"forehead": {"name": "Front", "bone": "Bip01 Head", "offset": Vector3(0, 0.115, 0.075), "r": 0.045},
	"eyes": {"name": "Yeux", "bone": "Bip01 Head", "offset": Vector3(0, 0.07, 0.085), "r": 0.04},
	"mouth": {"name": "Bouche", "bone": "Bip01 Head", "offset": Vector3(0, 0.005, 0.1), "r": 0.04},
	"ear_l": {"name": "Oreille gauche", "bone": "Bip01 Head", "offset": Vector3(0.075, 0.06, -0.005), "r": 0.04},
	"ear_r": {"name": "Oreille droite", "bone": "Bip01 Head", "offset": Vector3(-0.075, 0.06, -0.005), "r": 0.04},
	"neck": {"name": "Cou", "bone": "Bip01 Neck", "offset": Vector3(0, 0.035, 0.065), "r": 0.05},
	"chest": {"name": "Thorax", "bone": "Bip01 Spine2", "offset": Vector3(0, 0.07, 0.14), "r": 0.055},
	"heart": {"name": "Cœur", "bone": "Bip01 Spine2", "offset": Vector3(0.065, 0.0, 0.135), "r": 0.05},
	"lung_l": {"name": "Poumon gauche", "bone": "Bip01 Spine2", "offset": Vector3(0.1, 0.1, 0.11), "r": 0.05},
	"lung_r": {"name": "Poumon droit", "bone": "Bip01 Spine2", "offset": Vector3(-0.1, 0.1, 0.11), "r": 0.05},
	"back_l": {"name": "Dos (poumon gauche)", "bone": "Bip01 Spine2", "offset": Vector3(0.085, 0.02, -0.12), "r": 0.065},
	"back_r": {"name": "Dos (poumon droit)", "bone": "Bip01 Spine2", "offset": Vector3(-0.085, 0.02, -0.12), "r": 0.065},
	"flank_l": {"name": "Flanc gauche", "bone": "Bip01 Spine1", "offset": Vector3(0.155, 0.0, 0.0), "r": 0.06},
	"flank_r": {"name": "Flanc droit", "bone": "Bip01 Spine1", "offset": Vector3(-0.155, 0.0, 0.0), "r": 0.06},
	"abdomen": {"name": "Abdomen", "bone": "Bip01 Spine", "offset": Vector3(0, 0.05, 0.14), "r": 0.075},
	"lumbar": {"name": "Bas du dos", "bone": "Bip01 Spine", "offset": Vector3(0, 0.02, -0.12), "r": 0.07},
	"arm_l": {"name": "Bras gauche", "bone": "Bip01 L UpperArm", "offset": "mid", "r": 0.05},
	"arm_r": {"name": "Bras droit", "bone": "Bip01 R UpperArm", "offset": "mid", "r": 0.05},
	"hand_l": {"name": "Main gauche", "bone": "Bip01 L Hand", "offset": "tip", "r": 0.05},
	"hand_r": {"name": "Main droite", "bone": "Bip01 R Hand", "offset": "tip", "r": 0.05},
	"leg_l": {"name": "Jambe gauche", "bone": "Bip01 L Thigh", "offset": "mid", "r": 0.07},
	"leg_r": {"name": "Jambe droite", "bone": "Bip01 R Thigh", "offset": "mid", "r": 0.07},
	"knee_l": {"name": "Genou gauche", "bone": "Bip01 L Calf", "offset": Vector3(0, 0, 0.05), "r": 0.05},
	"knee_r": {"name": "Genou droit", "bone": "Bip01 R Calf", "offset": Vector3(0, 0, 0.05), "r": 0.05},
	"foot_l": {"name": "Cheville gauche", "bone": "Bip01 L Foot", "offset": Vector3(0, 0, 0.02), "r": 0.06},
	"foot_r": {"name": "Cheville droite", "bone": "Bip01 R Foot", "offset": Vector3(0, 0, 0.02), "r": 0.06},
}

## Examens : outil, zones valides, minutes de jeu consommées, durée de geste
## (secondes réelles, bouton maintenu), position requise du patient.
## pos : "any" | "lying" | "not_lying" | "sitting"
const EXAMS := {
	"ta": {"name": "Tension artérielle", "tool": "tensiometre", "spots": ["arm_l", "arm_r"], "min": 2, "hold": 3.0, "pos": "not_lying", "verb": "Prendre la tension"},
	"temp": {"name": "Température", "tool": "thermometre", "spots": ["forehead", "ear_l", "ear_r"], "min": 1, "hold": 1.2, "pos": "any", "verb": "Prendre la température"},
	"spo2": {"name": "Saturation (SpO₂)", "tool": "oxymetre", "spots": ["hand_l", "hand_r"], "min": 1, "hold": 2.0, "pos": "any", "verb": "Mesurer la saturation"},
	"respiration": {"name": "Respiration", "tool": "mains", "spots": ["chest"], "min": 1, "hold": 2.5, "pos": "any", "verb": "Observer la respiration"},
	"cardio": {"name": "Auscultation cardiaque", "tool": "stethoscope", "spots": ["heart"], "min": 1, "hold": 3.0, "pos": "any", "verb": "Ausculter le cœur"},
	"pulmo_g": {"name": "Auscultation pulmonaire gauche", "tool": "stethoscope", "spots": ["lung_l", "back_l"], "min": 1, "hold": 3.0, "pos": "any", "verb": "Ausculter le poumon gauche"},
	"pulmo_d": {"name": "Auscultation pulmonaire droite", "tool": "stethoscope", "spots": ["lung_r", "back_r"], "min": 1, "hold": 3.0, "pos": "any", "verb": "Ausculter le poumon droit"},
	"oto_g": {"name": "Otoscopie gauche", "tool": "otoscope", "spots": ["ear_l"], "min": 1, "hold": 1.5, "pos": "any", "verb": "Examiner le tympan gauche"},
	"oto_d": {"name": "Otoscopie droite", "tool": "otoscope", "spots": ["ear_r"], "min": 1, "hold": 1.5, "pos": "any", "verb": "Examiner le tympan droit"},
	"orl": {"name": "Examen de la gorge", "tool": "lampe", "spots": ["mouth"], "min": 1, "hold": 1.5, "pos": "any", "verb": "Examiner la gorge"},
	"pupilles": {"name": "Réflexes pupillaires", "tool": "lampe", "spots": ["eyes", "forehead"], "min": 1, "hold": 1.2, "pos": "any", "verb": "Éclairer les pupilles"},
	"ganglions": {"name": "Ganglions du cou", "tool": "mains", "spots": ["neck"], "min": 1, "hold": 2.0, "pos": "not_lying", "verb": "Palper les ganglions"},
	"nuque": {"name": "Raideur de nuque", "tool": "mains", "spots": ["neck", "forehead"], "min": 1, "hold": 2.0, "pos": "lying", "verb": "Rechercher une raideur de nuque"},
	"abdomen": {"name": "Palpation abdominale", "tool": "mains", "spots": ["abdomen"], "min": 2, "hold": 2.5, "pos": "lying", "verb": "Palper l'abdomen"},
	"rachis": {"name": "Palpation lombaire", "tool": "mains", "spots": ["lumbar"], "min": 1, "hold": 2.0, "pos": "not_lying", "verb": "Palper le bas du dos"},
	"lasegue": {"name": "Manœuvre de Lasègue", "tool": "mains", "spots": ["leg_l", "leg_r"], "min": 1, "hold": 2.2, "pos": "lying", "verb": "Lever la jambe tendue"},
	"force": {"name": "Force et sensibilité", "tool": "mains", "spots": ["hand_l", "hand_r"], "min": 1, "hold": 1.8, "pos": "any", "verb": "Tester la force et la sensibilité"},
	"reflexes": {"name": "Réflexes ostéotendineux", "tool": "marteau", "spots": ["knee_l", "knee_r"], "min": 1, "hold": 1.0, "pos": "sitting", "verb": "Tester le réflexe rotulien"},
	"pied_d": {"name": "Cheville et pied droits", "tool": "mains", "spots": ["foot_r"], "min": 1, "hold": 2.0, "pos": "any", "verb": "Examiner la cheville droite"},
	"pied_g": {"name": "Cheville et pied gauches", "tool": "mains", "spots": ["foot_l"], "min": 1, "hold": 2.0, "pos": "any", "verb": "Examiner la cheville gauche"},
	"peau_d": {"name": "Peau du flanc droit", "tool": "mains", "spots": ["flank_r"], "min": 1, "hold": 1.5, "pos": "any", "verb": "Inspecter la peau"},
	"peau_g": {"name": "Peau du flanc gauche", "tool": "mains", "spots": ["flank_l"], "min": 1, "hold": 1.5, "pos": "any", "verb": "Inspecter la peau"},
	"dep": {"name": "Débit expiratoire de pointe", "tool": "debitmetre", "spots": ["mouth"], "min": 2, "hold": 2.5, "pos": "not_lying", "verb": "Faire souffler dans le débitmètre"},
	"glycemie": {"name": "Glycémie capillaire", "tool": "glucometre", "spots": ["hand_l", "hand_r"], "min": 1, "hold": 2.0, "pos": "any", "verb": "Mesurer la glycémie"},
	"tdr": {"name": "TROD angine", "tool": "trod", "spots": ["mouth"], "min": 5, "hold": 2.0, "pos": "any", "verb": "Faire un prélèvement de gorge"},
	"bu": {"name": "Bandelette urinaire", "tool": "bandelette", "spots": ["*"], "min": 4, "hold": 1.0, "pos": "not_lying", "verb": "Demander un échantillon d'urine"},
	"ecg": {"name": "ECG 12 dérivations", "tool": "ecg", "spots": ["chest", "heart"], "min": 5, "hold": 3.0, "pos": "lying", "verb": "Poser les électrodes"},
}

const DEFAULT_VITALS := {"ta": "124/78", "fc": 74, "temp": 36.8, "spo2": 98, "fr": 15, "glyc": 0.98, "dep": 520}

const DEFAULT_FINDINGS := {
	"respiration": "FR {fr}/min. Respiration régulière, ample, sans tirage.",
	"cardio": "Bruits du cœur réguliers, bien frappés. Pas de souffle audible.",
	"pulmo_g": "Murmure vésiculaire normal à gauche, pas de bruit surajouté.",
	"pulmo_d": "Murmure vésiculaire normal à droite, pas de bruit surajouté.",
	"oto_g": "Tympan gauche gris nacré, translucide, triangle lumineux présent.",
	"oto_d": "Tympan droit gris nacré, translucide, triangle lumineux présent.",
	"orl": "Pharynx rose, amygdales de taille normale, sans exsudat.",
	"pupilles": "Pupilles rondes, égales et réactives à la lumière.",
	"ganglions": "Pas d'adénopathie cervicale palpable.",
	"nuque": "Nuque souple : pas de raideur méningée.",
	"abdomen": "Abdomen souple, dépressible et indolore. Pas de masse.",
	"rachis": "Rachis lombaire souple, indolore. Fosses lombaires indolores.",
	"lasegue": "Signe de Lasègue négatif.",
	"force": "Force musculaire et sensibilité normales et symétriques.",
	"reflexes": "Réflexes rotuliens présents et symétriques.",
	"pied_d": "Cheville et pied droits sans anomalie.",
	"pied_g": "Cheville et pied gauches sans anomalie.",
	"peau_d": "Peau du flanc droit normale.",
	"peau_g": "Peau du flanc gauche normale.",
	"tdr": "TROD angine NÉGATIF.",
	"bu": "Bandelette urinaire négative (leucocytes −, nitrites −, sang −, protéines −, glucose −).",
	"ecg": "Rythme sinusal régulier à {fc}/min. Pas de trouble de la repolarisation.",
}

## États visuels et sonores par défaut.
const DEFAULT_VISUAL := {
	"oto_g": "normal", "oto_d": "normal", "orl": "normal", "ecg": "normal", "tdr": "neg",
	"peau_g": "normal", "peau_d": "normal",
}
const DEFAULT_SOUNDS := {"cardio": "normal", "pulmo_g": "normal", "pulmo_d": "normal"}


static func tool_def(id: String) -> Dictionary:
	for t in TOOLS:
		if t["id"] == id:
			return t
	return {}


static func tool_index(id: String) -> int:
	for i in TOOLS.size():
		if TOOLS[i]["id"] == id:
			return i
	return 0


## Examen correspondant à un outil sur une zone, compte tenu de la position.
## Renvoie "" si rien ne correspond.
static func exam_for(tool: String, spot: String, position: String) -> String:
	var fallback := ""
	for id in EXAMS.keys():
		var e: Dictionary = EXAMS[id]
		if e["tool"] != tool:
			continue
		var spots: Array = e["spots"]
		if not (spot in spots or "*" in spots):
			continue
		if pos_ok(e["pos"], position):
			return id
		if fallback == "":
			fallback = id
	return fallback


static func pos_ok(req: String, position: String) -> bool:
	match req:
		"lying":
			return position == "lying"
		"not_lying":
			return position != "lying"
		"sitting":
			return position in ["chair", "table"]
	return true


static func pos_hint(req: String) -> String:
	match req:
		"lying":
			return "Le patient doit être allongé sur la table d'examen"
		"not_lying":
			return "Le patient doit être assis"
		"sitting":
			return "Le patient doit être assis, jambes pendantes"
	return ""
