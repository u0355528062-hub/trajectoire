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
| **Espace** | Sauter |
| **Souris** | Regarder |
| **V** | Vue 1ʳᵉ / 3ᵉ personne |
| **1** | Sortir / ranger le mortier |
| **2** | Sortir / ranger les **pierres** (lancer) |
| **Molette** | Changer d'objet |
| **Clic droit (maintenu)** | Viser : mortier = bras tendu + réticule ; pierres = **trajectoire en pointillés** et cercle d'impact |
| **Clic gauche** | Mortier (en visant) : tirer, 6 obus. Pierres : lancer (illimité) |
| **F** | Coup de pied (3 coups cassent une vitre) |
| **R** | Recharger les 6 obus (pour tester) |
| **H** | Afficher / masquer l'aide |

L'arrêt de bus est devant toi, de l'autre côté de la route : traverse, puis soit :
- **lance des pierres** (touche **2**, clic droit pour voir la trajectoire, clic gauche pour lancer) : chaque impact ajoute des fissures et fait tomber des éclats, la vitre finit par exploser après 3 à 5 pierres ;
- **donne des coups de pied** : place-toi à 1 m d'une vitre, regarde-la et appuie sur **F**.

## 6. Problèmes fréquents

- **Le jeu est lent / saccadé** : ferme les autres programmes. Dans le jeu, regarder un coin du ciel plutôt que les feux d'artifice proches aide. Pour alléger : menu **Projet → Paramètres du projet → Rendu → Anti-aliasing** → mets *MSAA 3D* sur « Désactivé ».
- **Message « Vulkan non supporté » / écran noir** : ton ordinateur est trop ancien pour le mode normal. Menu **Projet → Paramètres du projet → Rendu → Moteur de rendu** (« Rendering Method ») → choisis **gl_compatibility**, puis relance. (L'apparence sera un peu plus simple : moins de reflets et d'ombres douces.)
- **La souris ne bouge pas la caméra** : clique une fois dans la fenêtre du jeu.
- **Rien ne s'est importé / images manquantes** : ferme Godot, rouvre le projet et attends la fin de la barre de progression en bas à droite.
- **Un son ne marche pas** : tous les sons sont fabriqués par le code, aucun fichier audio. Vérifie le volume du PC.

## 7. Où est quoi (si tu veux modifier plus tard)

- `main.tscn` : la scène lancée (ciel, lumière, sol, arrêt de bus, joueur).
- `scripts/` : le comportement. `player.gd` (déplacements, caméra), `human.gd` (corps, marche, course, coup de pied), `mortar.gd` (visée, tir), `bus_stop.gd` (arrêt de bus cassable), `hud.gd` (interface).
- `assets/` : le personnage (généré depuis des données libres MakeHuman, CC0) et les textures.
- `tools/` : les programmes Python qui génèrent le personnage et les textures (inutiles pour jouer).

Pour changer un réglage simple : dans Godot, double-clique le script dans le panneau « Système de fichiers » (en bas à gauche), modifie la valeur d'une constante en haut du fichier (par exemple `WALK_SPEED` dans `player.gd`), enregistre (**Ctrl+S**) et relance avec **F5**.
