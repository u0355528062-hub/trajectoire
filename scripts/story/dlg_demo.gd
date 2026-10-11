class_name DlgDemo
extends RefCounted
## Dialogues du chapitre de démonstration (format : docs/CAMPAGNE.md § « Format des dialogues »).

const DLG := {
	"_id": "demo",
	"start": [
		{"who": "nadia", "text": "T'es venu, finalement.", "anim": "wave"},
		{"who": "sam", "text": "J'ai vu l'affiche à la boulangerie."},
		{"choice": [
			{"id": "aide", "text": "Je peux aider ?", "set": {"demo_aide": true}, "rel": {"nadia": 5}, "goto": "aide"},
			{"id": "passe", "text": "Je fais que passer.", "rel": {"nadia": -2}, "goto": "passe"},
		]},
	],
	"aide": [
		{"who": "nadia", "text": "Prends ces tracts. Parle aux gens, pas besoin de crier."},
		{"stats": {"mobilisation": 1}},
	],
	"passe": [
		{"who": "nadia", "text": "Comme tout le monde. Prends quand même un tract."},
	],
}
