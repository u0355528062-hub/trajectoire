# Blocus — Godot 4.4

**Débutant ? Lis [GUIDE.md](GUIDE.md) (pas à pas).**

Une manifestation urbaine au crépuscule, sur une grande baseplate grise (la ville reste au loin) :
un cortège qui marche et scande derrière sa banderole, des groupes qui discutent, des cagoulés près
de l'abribus, des pancartes, des fumigènes, des feux de poubelle… et toi au milieu.

Ouvrir le dossier dans Godot 4.4+ et lancer (F5). Au premier lancement, laisser Godot importer les assets.

## Commandes

| Touche | Action |
|---|---|
| ZQSD / WASD | Marcher |
| Maj | Courir |
| Espace | Sauter |
| V | Vue 1re / 3e personne |
| 1 | Mortier d'artifice : clic droit = viser, clic gauche = tirer (6 obus) |
| 2 | Pierres : clic droit = trajectoire, clic gauche = lancer |
| 3 | Briquet + journal : clic gauche = allumer, clic droit = viser, clic gauche = lancer la torche |
| 4 | Fumigène : clic gauche = craquer, clic droit (maintenu) = brandir, clic gauche = lancer |
| Molette | Changer d'objet |
| E | Poubelle : ouvrir / fermer le couvercle — **maintenir E** pour la basculer sur ses roues et la déplacer |
| G | Appeler la foule : « Venez ! » — certains te suivent pour casser l'abribus, d'autres refusent |
| F | Coup de pied (abribus, poubelles, cartons) |
| R | Recharger obus et fumigènes (test) |
| H | Masquer l'aide |
| Échap | Libérer la souris |

## Ce qui se passe autour de toi

- **Le cortège** (13 personnes) fait le tour de la place : banderole « TOUS DEBOUT ! » tenue par deux
  manifestants, pancartes, fumigènes, meneur au mégaphone. Il s'arrête, le meneur lance un slogan,
  la foule le reprend en rythme (poings levés, pancartes brandies, applaudissements, bouches synchronisées).
- **Les groupes** discutent pour de vrai (répliques, réponses, hochements de tête), fument, regardent
  leur téléphone, téléphonent, filment.
- **Les cagoulés** traînent près de l'abribus ; l'un d'eux tire des feux d'artifice dans le ciel.
- **Réactions** : quand tu vises bas avec le mortier, ceux qui sont dans l'axe s'écartent en criant
  « Attention ! » ; vise le ciel et on t'encourage. Chaque bouquet fait lever les têtes (« Waouh ! »,
  téléphones brandis, applaudissements). Un tir à hauteur d'homme provoque un mouvement de panique.
  Une vitre qui explose déclenche une clameur ; les curieux viennent voir.
- **Feu de poubelle** : ouvre une poubelle (E), allume le journal (3) et lance-le dedans. Les curieux
  forment un cercle, filment, se réchauffent les mains, et certains vont chercher cartons et planches
  pour nourrir le feu (qui repart à chaque ajout). Refermer le couvercle étouffe les flammes.
- **Appel (G)** près de l'abribus : les plus téméraires accourent, donnent des coups de pied dans les
  vitres ou lancent des pierres en criant « Ouais ! Allez ! ».

## Assets et crédits

- Personnages : générés par `tools/build_character.py` à partir des données **MakeHuman (CC0)** :
  9 morphologies (hommes/femmes, origines et âges variés), vêtements (sweat, capuche, doudoune, t-shirt,
  gilet jaune, jean, baskets, bonnet, casquette, cagoule, bandana, sac à dos), peau, cheveux.
- Voix et foules : `tools/build_audio.py`, synthèse vocale neuronale **Piper** (MIT) avec les voix
  `fr-gilles-low` (CC0) et `fr-siwis-medium` (CC BY 4.0, SIWIS database), mixées (cris, chœurs, réverbération).
- Pancartes : `tools/build_props.py`, polices **Permanent Marker** et **Rock Salt** (Apache 2.0, Google Fonts,
  licence dans `tools/fonts/`).
- Abribus, mortier, textures, flammes, fumées : générés par les scripts de `tools/`.

Régénérer (Python 3 + numpy + Pillow) :
`MH_DATA=<makehuman>/makehuman/data/ python3 tools/build_character.py`,
`PIPER_DIR=<piper> VOICES_DIR=<voix> python3 tools/build_audio.py`, `python3 tools/build_props.py`.
