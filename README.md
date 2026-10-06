# Blocus — Godot 4.4

Étape 1 : baseplate grise, personnage humain réaliste, mortier d'artifice (6 tirs), vue 1re/3e personne.

Ouvrir le dossier dans Godot 4.4+ et lancer (F5). Au premier lancement, laisser Godot importer les assets.

| Touche | Action |
|---|---|
| ZQSD / WASD | Marcher |
| Maj | Courir |
| Espace | Sauter |
| V | Vue 1re / 3e personne |
| 1 | Sortir / ranger le mortier |
| Clic gauche | Tirer (6 obus : prise, allumage, chargement, départ) |
| R | Recharger les 6 obus (test) |
| H | Masquer l'aide |
| Échap | Libérer la souris |

## Personnage

`assets/character/` est généré par `tools/build_character.py` à partir des données **MakeHuman (CC0)** :
maillage de base, squelette et poids de skinning, morphologie « homme jeune », yeux (texture d'iris).
Vêtements (sweat, jean, baskets, bonnet), peau (lèvres, sourcils, barbe), textures de tissus : générés par le script.
Pour régénérer : cloner `makehumancommunity/makehuman` et lancer `MH_DATA=<repo>/makehuman/data/ python3 tools/build_character.py`
(Python 3 + numpy + Pillow).
