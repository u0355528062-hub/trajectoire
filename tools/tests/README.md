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
| `perf3.gd` | Coût moyen des scripts par image (calme / tendu / émeute) |

Les scripts affichent leurs résultats sur la sortie standard ; toute ligne `SCRIPT ERROR` est un bug.
