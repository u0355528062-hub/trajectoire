# Guide pas à pas — lancer le jeu (aucune connaissance de Godot nécessaire)

## 1. Installer Godot (gratuit, 2 minutes)

1. Va sur **https://godotengine.org/download** et télécharge **Godot 4.4** (version « Standard », pas « .NET »).
2. Dézippe le fichier téléchargé. Il n'y a **rien à installer** : le fichier obtenu (`Godot_v4.4…exe` sur Windows, `Godot.app` sur Mac) est le programme. Double-clique dessus.

> Il te faut une carte graphique qui gère Vulkan (tout PC/Mac récent). Pas de carte graphique récente ? Voir « Problèmes » en bas.

## 2. Récupérer le projet

- Dézippe **`trajectoire-blocus.zip`** dans un dossier (par exemple `Documents/blocus`). Tu dois voir dedans un fichier `project.godot` et des dossiers `scripts`, `assets`, `shaders`.
- *(Alternative)* Sur GitHub, ouvre le dépôt `trajectoire`, branche `claude/godot-blocus-start` → bouton vert **Code → Download ZIP**.

## 3. Ouvrir le projet dans Godot

1. Au lancement de Godot, la fenêtre « Gestionnaire de projets » s'ouvre.
2. Clique **Importer** → choisis le fichier `project.godot` → **Importer et modifier**.
3. **Patiente 1 à 3 minutes** la première fois : Godot prépare les images et le personnage (barre de progression en bas). C'est normal et ça n'arrive qu'une fois.

## 4. Lancer le jeu

- Clique le bouton **▶ (en haut à droite)** ou appuie sur **F5**.
- Si Godot demande une scène principale : choisis **`main.tscn`**.
- Clique dans la fenêtre du jeu pour capturer la souris. **Échap** libère la souris, **F8** (ou le bouton ■) arrête le jeu.

## 5. Les commandes

| Touche | Action |
|---|---|
| **Z Q S D** (ou W A S D) | Marcher |
| **Maj** | Courir |
| **Espace** | Sauter — et **se débattre** quand un policier t'a agrippé |
| **C** | S'accroupir |
| **Souris** | Regarder |
| **V** | Vue 1ʳᵉ / 3ᵉ personne |
| **1** | Sortir / ranger le mortier |
| **2** | Sortir / ranger les **pierres** (lancer) |
| **3** | Sortir le **briquet + journal** (mettre le feu à une poubelle) |
| **4** | Sortir un **fumigène** |
| **5 / 6** | Sortir un **petit / gros pétard** : clic gauche = allumer la mèche, clic gauche encore = lancer |
| **Molette** | Changer d'objet |
| **Clic droit (maintenu)** | Viser : mortier = bras tendu + réticule ; pierres / journal = **trajectoire en pointillés** ; fumigène = le **brandir** au-dessus de la tête |
| **Clic gauche** | Mortier (en visant) : tirer, 6 obus. Pierres : lancer. Journal : allumer, puis lancer. Fumigène : craquer, puis lancer |
| **E** | Poubelle : ouvrir / fermer. **Maintenir E** : la basculer sur ses roues et la pousser. Aussi : **relever une barrière** tombée, **grimper sur le capot** d'une voiture de police |
| **G** | Appeler la foule (« Venez ! ») |
| **F** | Coup de pied (vitres, poubelles, barrières, panneaux, voitures de police…) |
| **B / N / X** | Poing levé / applaudir / mains en l'air : la foule autour de toi suit |
| **R** | Recharger obus, fumigènes et pétards (pour tester) |
| **H** | Afficher / masquer l'aide |
| **Échap** | **Menu pause** (reprendre, recommencer, options Son / Image / Jeu / Accessibilité, commandes) |

L'arrêt de bus est devant toi, de l'autre côté de la route : traverse, puis soit :
- **lance des pierres** (touche **2**, clic droit pour voir la trajectoire, clic gauche pour lancer) : chaque impact ajoute des fissures et fait tomber des éclats, la vitre finit par exploser après 3 à 5 pierres ;
- **donne des coups de pied** : place-toi à 1 m d'une vitre, regarde-la et appuie sur **F**.

### Mettre le feu à une poubelle

1. Approche-toi d'une poubelle (la verte est juste devant toi au départ), appuie sur **E** : le couvercle s'ouvre.
2. Appuie sur **3** (briquet + journal), puis **clic gauche** : ton personnage allume le journal.
3. Maintiens **clic droit** : la trajectoire s'affiche. Vise l'intérieur de la poubelle et **clic gauche** pour lancer.
4. Le feu prend : des manifestants viennent regarder, filmer, et certains apportent des cartons pour l'entretenir.
   Referme le couvercle (**E**) pour l'éteindre.

### Casser l'abribus avec la foule

Va près de l'abribus et appuie sur **G** : ton personnage crie « Venez ! ». Selon leur caractère et
l'ambiance, certains manifestants accourent pour donner des coups de pied dans les vitres ou lancer des
pierres, d'autres refusent. Plus la soirée est chaude (feux d'artifice, vitres cassées, feux), plus ils te suivent.

### La barre de tension et la police

La **barre en haut de l'écran** mesure la tension. Elle monte quand tu casses des vitres, mets le feu,
tires au mortier, lances des projectiles sur les policiers, t'attaques à une voiture de police… et quand la
police elle‑même gaze ou charge. Elle redescend doucement quand tout est calme.

- **Tendu** : des CRS arrivent au bout de la rue et forment un cordon.
- **Échauffourées** : un fourgon, la ligne avance, premiers gaz lacrymogènes. La foule s'arrête de défiler
  et **fait front** face à la police.
- **Affrontement / Émeute** : charges, LBD, bombe lacrymogène, interpellations, renforts.

Si un policier t'**agrippe**, **martèle Espace** pour te dégager (des manifestants peuvent venir t'aider).
**Menotté = c'est fini** : l'écran « ARRÊTÉ » apparaît, appuie sur Entrée ou Espace pour recommencer.
Le gaz brouille l'image : sors du nuage, un **médic** (gilet jaune à croix rouge) viendra te rincer les yeux.

### Autres choses à essayer

- **Grimpe sur le capot** de la voiture de police (E) : des manifestants viennent t'aider à la défoncer.
  Une vitre cassée + un fumigène ou une torche posée près du moteur, et elle prend feu.
- **Pétards** (5 et 6) : le petit fait peur, le gros fait mal aux oreilles.
- **Barrières, cônes, panneaux, boîtes à journaux, lampadaires** : tout se frappe et se renverse.
- **Barricade** : quand ça chauffe, des manifestants portent les barrières en travers de la rue ; la police doit les renverser pour avancer.
- Observe la foule : certains boivent, s'étirent, s'assoient, d'autres filment, un reporter cherche le bon
  angle, les plus calmes tentent d'apaiser les plus énervés.

## 6. Problèmes fréquents

- **Le jeu est lent / saccadé** : ferme les autres programmes. Dans le jeu, regarder un coin du ciel plutôt que les feux d'artifice proches aide. Pour alléger : menu **Projet → Paramètres du projet → Rendu → Anti-aliasing** → mets *MSAA 3D* sur « Désactivé ».
- **Message « Vulkan non supporté » / écran noir** : ton ordinateur est trop ancien pour le mode normal. Menu **Projet → Paramètres du projet → Rendu → Moteur de rendu** (« Rendering Method ») → choisis **gl_compatibility**, puis relance. (L'apparence sera un peu plus simple : moins de reflets et d'ombres douces.)
- **La souris ne bouge pas la caméra** : clique une fois dans la fenêtre du jeu.
- **Rien ne s'est importé / images manquantes** : ferme Godot, rouvre le projet et attends la fin de la barre de progression en bas à droite.
- **Un son ne marche pas** : vérifie le volume du PC. Les voix et la foule sont dans `assets/audio/` (fichiers .ogg) ; si Godot les signale manquants, laisse-le terminer l'import (barre en bas à droite).
- **Le jeu rame avec la foule** : la foule compte une trentaine de personnages animés, plus jusqu'à 32 policiers. Ferme les autres programmes, ou dans `scripts/crowd.gd` supprime quelques lignes de la liste `cfg` (une ligne = un manifestant).

## 7. Où est quoi (si tu veux modifier plus tard)

- `main.tscn` : la scène lancée (ciel, lumière, sol, arrêt de bus, poubelles, foule, joueur).
- `scripts/` : le comportement. `player.gd` (déplacements, caméra, objets), `human.gd` (corps, marche, course, coup de pied), `mortar.gd` (visée, tir), `bus_stop.gd` (arrêt de bus cassable), `hud.gd` (interface), `crowd.gd` (la foule : cortège, chants, réactions), `npc.gd` (un manifestant : poses, voix, comportements), `trash_bin.gd` (poubelle et feu), `igniter.gd` (briquet), `flare_tool.gd` / `flare.gd` (fumigène).
- `assets/` : le personnage (généré depuis des données libres MakeHuman, CC0) et les textures.
- `tools/` : les programmes Python qui génèrent le personnage et les textures (inutiles pour jouer).

Pour changer un réglage simple : dans Godot, double-clique le script dans le panneau « Système de fichiers » (en bas à gauche), modifie la valeur d'une constante en haut du fichier (par exemple `WALK_SPEED` dans `player.gd`), enregistre (**Ctrl+S**) et relance avec **F5**.
