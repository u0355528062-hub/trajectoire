# Blocus — Godot 4.4

**Débutant ? Lis [GUIDE.md](GUIDE.md) (pas à pas).**

Une manifestation urbaine au crépuscule, sur une grande baseplate grise (la ville reste au loin) :
un cortège qui marche et scande derrière sa banderole, des groupes qui discutent, des cagoulés près
de l'abribus, des pancartes, des fumigènes, des feux de poubelle… et toi au milieu. Plus ça chauffe,
plus la police se rapproche : CRS au bout de la rue, camionnettes, gaz lacrymogène, charges, LBD,
interpellations. Si on te menotte, c'est **fini** : écran « ARRÊTÉ », on recommence.

Ouvrir le dossier dans Godot 4.4+ et lancer (F5). Au premier lancement, laisser Godot importer les assets.

## Commandes

| Touche | Action |
|---|---|
| ZQSD / WASD | Marcher |
| Maj | Courir |
| Espace | Sauter — et **se débattre** quand un policier t'a agrippé |
| C | S'accroupir |
| V | Vue 1re / 3e personne |
| 1 | Mortier d'artifice : clic droit = viser, clic gauche = tirer (6 obus) |
| 2 | Pierres : clic droit = trajectoire, clic gauche = lancer |
| 3 | Briquet + journal : clic gauche = allumer, clic droit = viser, clic gauche = lancer la torche |
| 4 | Fumigène : clic gauche = craquer, clic droit (maintenu) = brandir, clic gauche = lancer |
| 5 / 6 | Petit / gros **pétard** : allumer la mèche (clic gauche), puis lancer — ils font reculer, tinter les oreilles… |
| Molette | Changer d'objet |
| E | Poubelle : ouvrir / fermer (**maintenir** : la basculer et la déplacer) · relever une barrière · **grimper sur le capot** d'une voiture de police |
| F | Coup de pied : vitres, abribus, poubelles, barrières, panneaux, lampadaires, voitures de police, grenades |
| G | Appeler la foule : « Venez ! » — certains te suivent pour casser l'abribus ou s'en prendre à une voiture |
| B / N / X | Poing levé / applaudir / mains en l'air (la foule suit) |
| R | Recharger obus, fumigènes et pétards (test) |
| H | Masquer l'aide |
| Échap | **Menu pause** : reprendre, recommencer, options (son, image, jeu, accessibilité), commandes |

## La tension et la police

En haut de l'écran, la **barre de tension** monte avec ce que tu fais (vitres cassées, feux, mortier,
voiture attaquée ou incendiée, projectiles sur les policiers…) et avec ce que fait la police elle‑même
(gaz, charges, coups). Elle redescend lentement quand tout est calme. Cinq stades :

| Stade | Ce qui change |
|---|---|
| **CALME** | La manifestation vit sa vie. Au bout de la rue, rien. |
| **TENDU** | Un cordon de CRS se met en place à l'autre bout de la rue ; une voiture de patrouille arrive. |
| **ÉCHAUFFOURÉES** | Un fourgon arrive, la ligne avance par bonds, premiers tirs de lacrymo, interpellations de ceux qui jettent des projectiles. |
| **AFFRONTEMENT** | La ligne pousse, charges à la matraque, tirs de LBD, bombe lacrymogène à bout portant, équipes d'interpellation. |
| **ÉMEUTE** | Renforts, gaz en continu, corps à corps. |

- **Lacrymogène** : le gaz brouille et déforme l'image, fait tousser et ralentit ; les CRS enfilent leur masque.
- **Interpellation** : un policier t'agrippe → **martèle Espace** pour te dégager. Des manifestants peuvent
  accourir pour te libérer (la jauge de lutte bondit). Menotté = partie terminée.
- Les policiers ripostent à ce qu'on leur jette (pierres, canettes, sacs, crayons, pétards, mortier…).
- Quand tout se calme pour de bon, la ligne se replie vers son cordon d'origine sous les cris de joie.

## Ce qui se passe autour de toi

- **Le cortège** (13 personnes) fait le tour de la place : banderole « TOUS DEBOUT ! » tenue par deux
  manifestants, pancartes, fumigènes, meneur au mégaphone. Il s'arrête, le meneur lance un slogan,
  la foule le reprend en rythme (poings levés, pancartes brandies, applaudissements, bouches synchronisées).
  Face à la police, on change de répertoire.
- **Les groupes** discutent pour de vrai (répliques, réponses, hochements de tête), fument, regardent
  leur téléphone, téléphonent, filment, **boivent** à la bouteille, **s'étirent**, **s'assoient** quand ils sont
  fatigués, grelottent quand il fait frais.
- **Les cagoulés** (black bloc) traînent près de l'abribus ; l'un d'eux tire des feux d'artifice dans le ciel.
- **Face-à-face** : dès les échauffourées, le cortège s'arrête et **fait front** à distance de la ligne :
  les plus déterminés au premier rang (poing levé, cris en porte‑voix, doigt pointé, téléphones qui filment),
  les plus calmes qui s'assoient ou tentent d'apaiser (« Du calme ! »), les craintifs qui reculent à l'arrière.
  Quand la ligne avance, la foule recule avec elle ; quand elle se replie, on l'acclame.
- **Humeurs** : chaque manifestant a de la peur, de la colère, de la fatigue, de la soif… qui montent avec
  les événements (gaz, charges, coups, arrestations) et redescendent avec le temps. Elles changent ses gestes,
  sa voix, l'endroit où il se tient. Les plus enragés finissent par se jeter sur un policier (**corps à corps**).
- **Mémoire du gaz** : on ne vient pas se poster dans un nuage, on recule avant qu'il arrive, et on ne fuit
  jamais vers la ligne de police.
- **Secours** : un **médic** (gilet jaune à croix rouge, sac rouge) accourt vers les blessés, rince les yeux
  des aspergés — et les tiens ; à défaut, un voisin courageux vient donner un coup de main.
- **Presse** : un **reporter** (brassard PRESSE, appareil à longue focale) cherche le bon angle sur les
  interpellations, les charges, les incendies, les nuages de gaz.
- **Renforts** : les manifestants interpellés sont remplacés peu à peu par de nouveaux arrivants qui
  rejoignent le cortège (un peu plus quand ça chauffe).
- **Réactions** : quand tu vises bas avec le mortier, ceux qui sont dans l'axe s'écartent en criant
  « Attention ! » ; vise le ciel et on t'encourage. Une vitre qui explose déclenche une clameur ;
  un pétard fait sursauter (certains reculent, d'autres applaudissent).
- **Feu de poubelle** : ouvre une poubelle (E), allume le journal (3) et lance-le dedans. Les curieux
  forment un cercle, filment, se réchauffent les mains, et certains vont chercher cartons et planches
  pour nourrir le feu. Refermer le couvercle étouffe les flammes.
- **Appel (G)** près de l'abribus : les plus téméraires accourent, donnent des coups de pied dans les
  vitres ou lancent des pierres en criant « Ouais ! Allez ! ».

## Voitures de police

La voiture de patrouille et les fourgons sont **vandalisables** : coups de pied et projectiles laissent des
**bosses**, les vitres se fissurent puis explosent, tu peux **monter sur le capot** (E) — d'autres viennent
t'aider à frapper les portières. Un fumigène ou un journal enflammé posé près du moteur met le feu :
flammes, fumée, pneus qui éclatent, carcasse calcinée, et, un peu plus tard, explosion du réservoir.
La police réagit (et la tension monte vite).

## Mobilier de rue

Barrières métalliques (renversées d'un coup de pied, à relever avec E), cônes, panneaux, boîtes à journaux,
pots de fleurs, corbeilles, lampadaires à globe de verre, panneau publicitaire vitré : tout se frappe,
s'abîme, se renverse ou se brise ; la foule s'en mêle.

## Pour tester sans jouer

Des scénarios sans interface (`--headless`) servent à vérifier le comportement de la foule et de la police :
`godot --headless --path . --fixed-fps 30 -s tools/tests/<script>.gd` (voir `tools/tests/README.md`), avec des scripts qui instancient `main.tscn`
(montée de tension, arrestations, gaz, secours…). Un script d'endurance de neuf minutes simulées a tourné
sans erreur ni anomalie (PNJ bloqués, positions aberrantes).

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
