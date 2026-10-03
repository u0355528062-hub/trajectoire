# Trajectoire

Simulation médicale en 3D à la première personne, faite avec **Godot 4.4**.

> **Prototype 0.1** : mode Histoire « Médecin généraliste » (3 journées, 14 patients).
> Modes prévus : Urgentiste, SAMU / SMUR, Chirurgie, Sandbox.

## Lancer le jeu

1. Installer [Godot 4.4](https://godotengine.org/download) (version standard, pas .NET).
2. Ouvrir Godot → **Importer** → choisir `project.godot`.
3. Appuyer sur **F5**.

Rendu : Forward+ (Vulkan). Il faut une carte graphique compatible Vulkan.
La qualité se règle dans **Paramètres** :

| Préréglage  | Effets |
|-------------|--------|
| Performance | SSAO |
| Équilibrée  | + SSIL, réflexions SSR, FXAA, MSAA 2× |
| Ultra       | + illumination globale SDFGI, brouillard volumétrique (rayons de soleil), MSAA 4× |

## Contrôles

| Touche | Action |
|--------|--------|
| ZQSD / WASD (position physique, donc AZERTY et QWERTY) | Se déplacer |
| Souris | Regarder |
| Maj | Courir |
| E / clic gauche | Interagir |
| TAB | Agenda |
| 1 – 4 | Onglets de consultation |
| Échap | Pause |

## Déroulement d'une journée

1. Les patients arrivent à l'heure de leur rendez-vous (parfois un peu en avance),
   passent à l'accueil (Camille, la secrétaire) puis s'assoient en salle d'attente.
2. Des **patients sans rendez-vous** se présentent, dont de vraies urgences.
3. Sur l'ordinateur du bureau (ou TAB), vous **appelez** un patient : il traverse
   la salle d'attente et s'installe face à votre bureau.
4. **Consultation** :
   - *Interrogatoire* : questions générales et spécifiques au cas.
   - *Examen* : constantes, auscultation, otoscopie, TROD angine, bandelette urinaire,
     ECG, etc. Certains examens se font sur la table d'examen (le patient s'y installe).
   - *Diagnostic* : une hypothèse principale parmi quatre.
   - *Prescription* : traitements, examens complémentaires, orientation (dont l'appel du 15).
5. **Compte rendu** : note de A à F, score, satisfaction, rappel médical.
6. Chaque action coûte du temps de jeu : l'attente des patients pèse sur leur satisfaction.
7. Bilan de fin de journée, puis journée suivante (sauvegarde automatique).

## Structure du projet

```
project.godot
scenes/main.tscn            Scène d'entrée
scripts/
  main.gd                   Bascule menu ↔ journée
  core/game.gd              Autoload « Game » : horloge, réputation, sauvegarde, réglages, touches
  data/cases.gd             Autoload « Cases » : cas cliniques, examens, diagnostics, journées, évaluation
  game/session.gd           Déroulement d'une journée (patients, file d'attente, consultation)
  game/patient_record.gd    État d'un patient dans la journée
  world/clinic.gd           Construction du cabinet, de l'extérieur, de l'éclairage
  world/humanoid.gd         Personnages articulés animés (marche, assis, regard, parole)
  world/art.gd              Matériaux PBR et maillages procéduraux
  world/interactable.gd     Zones interactives
  player/player.gd          Contrôleur première personne
  ui/*.gd                   Thème, HUD, agenda, consultation, menus
shaders/                    Parquet, carrelage, bois (procéduraux)
assets/fonts/               Police Inter (licence SIL OFL)
tests/                      Test automatisé du mode Histoire + outil de captures
```

Tout le contenu 3D est généré par code : il n'y a aucun modèle importé à ce stade.
Les personnages et meubles pourront être remplacés par des modèles `.glb`
(par ex. réalisés sous Blender) sans changer la logique de jeu.

## Ajouter un patient

Dans `scripts/data/cases.gd`, ajouter une entrée à `CASES` (identité, apparence,
réponses, constantes, résultats d'examens, diagnostic attendu, diagnostics
différentiels, traitements `good` / `ok` / `bad` / `critical`, rappel médical),
puis la référencer dans une journée de `DAYS`.

## Tests

```sh
# Joue automatiquement les 3 journées et vérifie chaque étape
godot --headless --path . res://tests/story_test.tscn

# Clique réellement sur les boutons (menu, journée, pause)
godot --headless --path . res://tests/click_test.tscn

# Captures d'écran (nécessite un affichage)
godot --path . res://tests/screenshots.tscn -- /chemin/sortie
```

## Avertissement

Les contenus médicaux sont simplifiés à visée ludique et pédagogique.
Ils ne remplacent ni un avis médical ni les recommandations officielles (HAS).
