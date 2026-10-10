# Scénarios de test (sans interface)

Chaque script instancie `main.tscn` puis simule la partie : ils servent à repérer les erreurs de script
et les comportements aberrants sans avoir à jouer.

```
godot --headless --path . --fixed-fps 30 -s tools/tests/<script>.gd
```

| Script | Ce qu'il vérifie |
|---|---|
| `police2.gd` | Paliers de tension, gaz, charges, LBD, interpellations ; arrestation du joueur (écran « ARRÊTÉ ») |
| `standoff1.gd` | Face-à-face : formation de la foule selon le stade, craintifs à l'arrière, repli de la ligne au retour au calme |
| `roles1.gd` | Médic (blessé, joueur aspergé), reporter, secouristes de fortune |
| `rescue1.gd` | Des manifestants viennent libérer le joueur agrippé |
| `brawl1.gd` | Corps à corps entre manifestants enragés et policiers |
| `soak1.gd` | Endurance : 9 minutes simulées, tension en dents de scie, événements aléatoires ; signale PNJ bloqués ou hors zone |
| `fuzz_pnj.gd` | Appels aléatoires des réactions des PNJ (panique, gaz, coups, arrestation, soins, corps à corps…) pendant 7 minutes simulées |
| `fuzz_joueur.gd` | Touches et clics aléatoires du joueur (outils, coups de pied, appels, gestes), téléportations vers les lieux d'action |
| `perf3.gd` | Coût moyen des scripts par image (calme / tendu / émeute) |
| `barricade1.gd` | Barricade : barrières portées en travers de la rue, abandonnées si le porteur est gazé, ligne de police arrêtée puis barricade renversée |
| `behave1.gd` | Initiatives de la foule (jets, provocations, voitures, barricades…), réponses des CRS, prudence de la police sous les obus |
| `melee1.gd` | Joueur collé à la ligne : réponse graduée du CRS selon son attitude (neutre, mains en l'air, doigt d'honneur) |
| `sound1.gd` | Sons des véhicules : sirène deux-tons puis rapide (stade 3+), radio de bord, grondement d'une voiture en feu jusqu'à l'extinction, « Libérez-le ! » |
| `capture_police.gd` | Captures d'écran aux stades 3-4 (gaz, charge, LBD, escorte d'un interpellé). Demande un rendu, voir ci-dessous |

Les scripts affichent leurs résultats sur la sortie standard ; toute ligne `SCRIPT ERROR` est un bug.

`capture_police.gd` a besoin d'un affichage (pas de `--headless`) ; sur un serveur sans écran :

```
xvfb-run -s "-screen 0 1280x720x24" godot --path . --fixed-fps 30 --resolution 1280x720 -s tools/tests/capture_police.gd -- /chemin/des/captures
```
