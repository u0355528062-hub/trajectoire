# Campagne « La Hausse » — cahier des charges

Ce document est le **contrat commun** de la grosse mise à jour « campagne » de Blocus. Chaque module (agent) le lit
en entier avant de coder, respecte les interfaces décrites ici et ne modifie que les fichiers qui lui sont attribués
(§ 9). Le squelette de code existe déjà et tourne de bout en bout (`tools/tests/campaign_smoke.gd`) : on le
remplit, on ne le réinvente pas.

---

## 1. Vision

Le joueur veut :

- un **monde qui part en vrille sur les prix** (inflation, carburant, loyers, énergie, courses) ;
- un **but** : faire basculer l'**opinion publique** pour que le pays se soulève, en partant de **presque rien**
  (quelques personnes, un tractage) jusqu'à un **blocage** massif ;
- des **missions** pour gagner l'opinion, avec la liberté de **casser un peu, beaucoup ou pas du tout** —
  et des **conséquences** ;
- des **cinématiques et dialogues soignés**, des **choix qui changent l'histoire** ;
- des **graphismes et une immersion au maximum** de ce que permet le moteur, des **personnages crédibles** ;
- une **vraie carte** : quelques rues, assez grande, pas gigantesque ;
- **aucun bug** ;
- du **réalisme** : rien de « gadget ». Pas de parapluie qui annule le gaz, pas de super-pouvoirs, pas d'objets
  magiques. Ce qui existe dans une vraie manifestation française existe ; le reste non.

Le **bac à sable** d'origine reste jouable tel quel (menu « Bac à sable »), avec quelques réglages en plus.

### Ton

Réaliste, sobre, contemporain, français. Pas de caricature (ni des manifestants, ni des policiers, ni des
passants). Les personnages ont des raisons, des doutes, de l'humour. Les dialogues sonnent comme de vraies
conversations (registre oral, phrases courtes, quelques mots d'argot quand c'est naturel, jamais de pavés).
Tout est **fictif** : gouvernement, ministres, chaîne de télé, syndicats et marques sont inventés ; aucune
personnalité, aucun parti, aucune organisation réels.

La violence est un **choix du joueur** avec un **coût** : la casse fait monter la colère et la mobilisation des plus
radicaux mais **fait baisser l'opinion** ; les violences policières **filmées et diffusées** font monter l'opinion ;
la non-violence tenue face à la police est ce qui convainc le plus. Le jeu ne récompense jamais la violence contre
des personnes.

---

## 2. L'histoire (résumé — le module Scénario l'écrit en détail)

**Monde.** France, printemps 2027 (fictif). Les prix flambent : gazole 2,79 €/L, baguette 1,65 €, électricité
+38 % en un an, loyers qui suivent. Le gouvernement du Premier ministre (fictif) fait passer en force la
**« loi de Stabilité »** : TVA relevée, gel des salaires et des minima sociaux, fin du bouclier tarifaire. La chaîne
d'info en continu (fictive) parle de « grogne » et de « pédagogie ».

**Le quartier.** Un quartier populaire de Paris (le boulevard du jeu et ses rues). Le café-bar **Le Zinc** de Jo sert
de QG. La supérette affiche les nouveaux prix ; la station-service de la rue de la Forge aussi.

**Sam** (le joueur), 24 ans, livreur à vélo, vit avec sa mère (aide-soignante) et sa petite sœur. Il n'a jamais
milité. Personnages (ids stables) :

| id | Qui | Rôle |
|---|---|---|
| `nadia` | Nadia, 45 ans, aide-soignante syndiquée | organise, prudente, croit au nombre et à la non-violence |
| `karim` | Karim, 23 ans, ami d'enfance de Sam | en colère, tenté par la casse ; sincère |
| `ines` | Inès, 26 ans, interne en médecine | street medic ; voit les blessés |
| `lou` | Lou, 31 ans, vidéaste indépendante | filme, diffuse ; sait ce qui fait basculer l'opinion |
| `jo` | Jo, 62 ans, patron du Zinc | ancien docker, bourru, cache les gens quand ça tourne mal |
| `mme_ferreira` | Mme Ferreira, 74 ans, voisine | ne peut plus payer son chauffage ; son témoignage compte |
| `commissaire` | Commissaire Rivière, 52 ans | responsable du maintien de l'ordre ; pas un monstre, un rouage |
| `presentatrice` | Présentatrice du JT de la chaîne d'info | journaux télévisés entre les chapitres |

**Chapitres** (chacun est une journée jouable sur la carte, avec son heure, sa météo, sa foule, sa police) :

0. **Prologue — « La note »** (matin) : la caisse de la supérette refuse la carte de Sam ; la loi est annoncée à la
   télé du Zinc. Apprendre à marcher, parler, regarder. Rencontre de Jo, Karim, Nadia, Mme Ferreira.
1. **« On était douze »** (fin d'après-midi) : rassemblement de 12 personnes au square. Tractage aux passants (beaucoup
   refusent), affiches sur la colonne Morris et les panneaux d'affichage libre. Karim veut taguer la banque.
   Une patrouille passe ; rien de plus.
2. **« Les prix, en vrai »** (après-midi) : filmer les étiquettes de la supérette et le totem de la station-service,
   recueillir des témoignages (Mme Ferreira…), Lou monte une vidéo. Choix : visages floutés ou non. Le gérant
   appelle la police : partir calmement ou s'accrocher.
3. **« Premier cortège »** (crépuscule) : ~40 personnes ; Sam au mégaphone mène le cortège jusqu'au parvis de la
   mairie ; cordon de police devant la mairie. Choix : sit-in pacifique ou forcer le cordon. Karim interpellé :
   intervenir, filmer, ou laisser faire.
4. **« La nasse »** (nuit, pluie) : ~80 personnes ; la police encercle ; un tir de LBD blesse un lycéen. Protéger Inès
   qui soigne, filmer, sortir les images du quartier, faire sortir les gens par une rue. Karim et d'autres partent
   à l'émeute : les suivre ou non.
5. **« Blocus »** (aube puis matin) : grève générale ; blocage du boulevard et de la station-service avec ~150
   personnes ; tenir, négocier avec le commissaire Rivière. La fin dépend des jauges et des choix.

**Fins** : « Le recul » (la loi est retirée, opinion haute, peu de casse) ; « Victoire amère » (retirée, mais le
quartier est meurtri, Karim en prison ou Sam fiché) ; « L'essoufflement » (opinion basse : le mouvement s'éteint,
procès) ; une fin cachée possible (documentaire de Lou + témoignage de Mme Ferreira : grève nationale).

Le module Scénario écrit la bible complète (`scripts/story/BIBLE.md`), tous les chapitres et tous les dialogues.

---

## 3. Jauges, relations, drapeaux

`Campaign` (statique, `scripts/campaign/campaign.gd`) :

| Jauge | Plage | Départ | Sens |
|---|---|---|---|
| `opinion` | 0–100 | 18 | % de la population qui soutient le mouvement (sondages du JT) |
| `mobilisation` | 0–400 | 12 | gens prêts à descendre dans la rue → taille de la foule des chapitres suivants |
| `repression` | 0–1 | 0,15 | dureté de la réponse de l'État → police des chapitres suivants |
| `notoriete` | 0–1 | 0 | à quel point la police connaît Sam (monte avec l'interpellation, les actes filmés par la police…) |

- Relations `rel` avec `nadia`, `karim`, `ines`, `lou`, `jo`, `mme_ferreira` (−100..100).
- Drapeaux `flags` (choix : `ch1_tag_banque`, `ch2_visages_floutes`…), compteurs du chapitre `counters`
  (tracts, affiches, vitres, vidéos…), journal `journal` des faits marquants (repris par le JT).
- La taille de la foule d'un chapitre se calcule depuis `mobilisation` (le module Scénario fixe la formule dans
  `Story.CHAPTERS`, ex. `"crowd": {"size": "mobilisation"}` interprété par WorldSetup, ou un nombre fixe).
- Sauvegarde `user://campagne.json` à chaque début de chapitre ; « Continuer » au menu ; « Recommencer le chapitre »
  restaure l'état du début du chapitre.

---

## 4. Architecture

```
main.gd ── WorldSetup.config()  ← Campaign.chapter_def() | WorldSetup.sandbox | DEFAULT
        ── Lighting.build(tod, weather)
        ── foule / police / passants / habitants / joueur paramétrés par la config
        └─ ChapterDirector (si Campaign.active)
              ├─ StoryCast (StoryActor…)      personnages d'histoire
              ├─ Cinematics                    caméra, bandes noires, fondus, cartons
              ├─ ObjectiveTracker (Objective)  objectifs, repères, aides
              ├─ OpinionModel                  événements → jauges
              ├─ NewsFeed                      notifications, bilan/JT, échec, fins
              ├─ DialogueUI                    répliques, voix, choix (+ interprète des dialogues)
              ├─ StoryAudio                    ambiances et musiques
              └─ script du chapitre (ChapterScript)  ← scripts/story/ch_*.gd
```

- **Bus d'événements** : `get_tree().call_group("crowd", "on_event", type, data)` (existant). Le directeur est dans
  le groupe « crowd » et relaie tout sur son signal `event(type, d)` ; les services s'y branchent.
- **Notifications de campagne** : `Campaign` appelle le groupe « campaign » : `on_campaign_stat(k, v, delta, why)`,
  `on_campaign_flag(k, v)`, `on_campaign_rel(who, v, d)`. Une interface (jauge d'opinion du HUD…) se met dans ce
  groupe pour réagir.
- **Rechargement** : chaque chapitre = un rechargement de `main.tscn` (`reload_current_scene`) ; l'état de campagne,
  statique, survit. Aucun nœud ne doit être gardé d'une scène à l'autre.
- **Arrêt propre** : toute attente d'un service ou d'un chapitre porte sur un nœud du directeur
  (`director.sleep(s)`, signaux d'enfants du directeur). Si la scène disparaît, l'attente ne reprend jamais.
  **Interdit** dans les services et chapitres : `get_tree().create_timer()` (survit au rechargement).
- **Pilote automatique** (`Campaign.autoplay`, tests) : attentes ÷10 ; répliques, plans, fondus quasi instantanés ;
  choix par `Campaign.auto_pick(n)` ; objectifs terminés automatiquement après `spec.autoplay_after` (0,3 s par
  défaut) ; écrans de bilan/échec/fin validés seuls. **Chaque service doit garder ce comportement.**

---

## 5. Interfaces (à respecter à la lettre)

Les signatures ci-dessous existent déjà dans le squelette. Un module peut **ajouter** des méthodes, jamais
changer ni retirer celles-ci (les autres modules et les chapitres en dépendent).

### 5.1 API des chapitres — `ChapterScript` (`scripts/campaign/chapter_script.gd`)

Accès : `director`, `main`, `player`, `crowd`, `police`, `tension`. Toutes les méthodes marquées *await* s'appellent
avec `await`.

| Méthode | Rôle |
|---|---|
| `run()` *await* | à surcharger : le scénario |
| `alive() -> bool` | chapitre toujours en cours |
| `wait(s)` *await*, `until(cond: Callable, timeout=-1) -> bool` *await*, `wait_event(type, timeout=-1) -> Dictionary` *await* | temps |
| `spot(id) -> Vector3`, `pos_of(cible) -> Vector3` | lieux (cible : id de lieu, id de personnage, "player", Vector3, Node3D) |
| `actor(id) -> StoryActor`, `spawn(id, at, facing=null) -> StoryActor`, `despawn(id)` | personnages |
| `walk_to(qui, vers, run=false, timeout=40) -> bool` *await*, `face(qui, cible)`, `gesture(qui, nom, s=2)`, `follow(qui, cible\|null)` | jeu d'acteur |
| `say(qui, texte, opts={})` *await*, `bark(qui, texte)` | répliques |
| `dialogue(dlg, noeud="start") -> String` *await* | arbre de dialogue ; renvoie l'id du dernier choix |
| `choose(question, options, timer=0) -> int` *await* | choix simple |
| `cine_begin()`, `cine_end()`, `shot(spec)` *await*, `fade_out(s)` *await*, `fade_in(s)` *await*, `title_card(titre, sous_titre, s)` *await* | cinéma |
| `objective(id, texte, spec) -> Objective`, `complete(o) -> bool` *await*, `objectives_all(liste) -> bool` *await*, `objective_any(liste) -> Objective` *await*, `clear_objectives()` | objectifs |
| `stat(k)`, `add_stat(k, d, why)`, `flag(k, def)`, `set_flag(k, v)`, `rel(qui)`, `rel_add(qui, d)` | campagne |
| `news(texte)`, `hint(texte, s=5)`, `music(id)`, `ambience(id)` | habillage |
| `set_tension(v)`, `freeze_tension(on)`, `end_chapter(issue="ok")`, `fail_chapter(raison)` | monde, issue |

### 5.2 Services (enfants du directeur)

- `DialogueUI` : `play_line(qui, texte, opts)` *await*, `bark(qui, texte)`, `choose(question, options, timer)` *await*
  `-> int`, `run(dlg, noeud)` *await* `-> String`, statiques `display_name(qui)`, `line_id(noeud, i, choix=-1)`,
  `voice_path(dlg_id, line_id)`, `cond(expr)`.
- `Cinematics` : `active`, `cam`, `begin()`, `end()`, `shot(spec)` *await*, `fade_out(s)` *await*, `fade_in(s)` *await*,
  `title_card(t, st, s)` *await*, `letterbox(on)`.
- `StoryCast` : `get_actor(id)`, `spawn(id, pos) -> StoryActor`, `despawn(id)`, `walk_to(a, pos, run, timeout)` *await*.
- `StoryActor` (hérite d'`Actor`) : `story_id`, `display_name`, `setup_look(id)`, `talk(s)`, `gesture(nom, s)`,
  `face_target(pos)`, `follow_target(node|null)`, `walk(pos, run)`, `arrived(r)`.
- `ObjectiveTracker` : signal `objective_finished(o, ok)` ; `add(id, texte, spec) -> Objective`, `get_objective(id)`,
  `clear()`, `hint(texte, s)`, `wait_for(o)` *await* `-> bool`, `wait_any(liste)` *await* `-> Objective`.
- `Objective` : signaux `done`, `failed(raison)`, `progressed(v, cible)` ; `id`, `text`, `spec`, `state`, `progress`,
  `target`, `waypoint`, `optional` ; `complete()`, `fail(raison)`, `add_progress(n)`, `set_waypoint(p)`.
- `OpinionModel` : `on_event(type, d)`.
- `NewsFeed` : `push(texte)`, `show_bilan(issue)` *await*, `show_failure(raison)` *await* `-> bool` (true = recommencer),
  `show_ending(id)` *await*, statique `pick_ending() -> String`.
- `StoryAudio` : `music(id)`, `ambience(id)`, `stop_music(fondu)`.

### 5.3 Format des dialogues

Un fichier par chapitre : `scripts/story/dlg_<chapitre>.gd` avec `class_name Dlg<Chapitre>` et `const DLG := {...}`
(constante GDScript : vérifiée à l'analyse, exportée sans réglage particulier). Clé obligatoire `"_id"` (= id du
chapitre, sert au dossier des voix). Chaque autre clé est un **nœud** : une liste d'étapes jouées dans l'ordre.

| Étape | Effet |
|---|---|
| `{"who": "nadia", "text": "…", "anim": "nod", "look": "sam", "wait": 0.3, "if": cond}` | réplique (geste, regard, pause après) ; ignorée si `if` est faux |
| `{"choice": [option…], "prompt": "…", "timer": 8.0}` | choix (minuteur → option 0) |
| option : `{"id": "aider", "text": "Texte du bouton", "say": "Réplique de Sam", "if": cond, "set": {…}, "stats": {…}, "rel": {…}, "goto": "noeud"}` | |
| `{"goto": "noeud", "if": cond, "else": "autre"}` | saut (conditionnel) |
| `{"set": {"drapeau": valeur}}`, `{"stats": {"opinion": 2}}`, `{"rel": {"karim": -5}}`, `{"news": "…"}` | effets |
| `{"call": "nom_de_methode"}` | appelle (et attend) une méthode du script du chapitre (mise en scène pendant le dialogue) |
| `{"wait": 1.0}`, `{"end": true}` | pause, fin |

Conditions : `"drapeau"`, `"!drapeau"`, `"stat:opinion>=40"`, `"rel:karim<0"`, `"flag:ch2_video==floutee"`, ou une
liste (toutes vraies). Locuteurs : ids du § 2, plus `"sam"` (le joueur) et `"narrateur"`.

**Voix** : la réplique d'index `i` du nœud `n` a l'id `n_i` ; la réplique `say` de l'option `k` du choix d'index `i`
a l'id `n_i_ck`. Fichier : `res://assets/voice/<_id>/<id>.ogg`. S'il existe, il est joué et la réplique dure
le temps de la voix. Les ids changent si on insère une étape : le module Audio régénère les voix à la fin.

### 5.4 Plans (`shot(spec)`)

`{"from": Vector3, "to": Vector3 (travelling), "look": cible, "look_to": cible, "dur": 3.0, "fov": 50, "fov_to": 40,
"ease": "inout"|"linear"|"in"|"out", "dof": distance de mise au point (0 = sans), "shake": 0..1 (caméra à l'épaule),
"cut": true}` — cible = Vector3, id de personnage, `"player"` ou id de lieu. Bandes noires pendant `cine_begin…cine_end`.

### 5.5 Objectifs (`objective(id, texte, spec)`)

| `type` | Clés | Atteint quand |
|---|---|---|
| `manual` (défaut) | — | le script appelle `o.complete()` |
| `reach` | `spot` ou `waypoint`, `radius` (4) | le joueur est dans le cercle |
| `talk` | `who` | événement `talk` avec `who` |
| `event` | `event`, `count`, `filter` (égalités sur les données) | `count` événements reçus |
| `hold` | `spot`, `radius`, `sec` | le joueur reste `sec` secondes dans la zone |
| `survive` | `timer` | le temps s'écoule |

Communs : `count`, `timer` (échec à l'expiration, sauf `survive`), `fail_if: {"tension_above": 0.6}`, `optional`,
`waypoint`, `autoplay_after`. L'interpellation du joueur fait échouer le chapitre (directeur).

### 5.6 Réglages du monde (`Story.CHAPTERS[i]`, `WorldSetup`)

```
"id", "title", "date", "script",
"tod": "aube"|"matin"|"midi"|"aprem"|"crepuscule"|"nuit",   "weather": "sec"|"bruine"|"pluie"|"brume",
"crowd": {"size": int (-1 = foule d'origine) | "mobilisation", "cortege": bool, "bloc": int, "medic": bool,
          "press": bool, "theme": "prix" (pancartes/slogans sur la vie chère) | "origine"},
"police": {"enabled": bool, "cordon": bool, "line_x": float, "max_stage": 0..4, "start_tension": 0..1,
           "tension_frozen": bool, "patrol": bool},
"civilians": {"density": 0..1.5},   "residents": bool,
"tools": ["phone", "tracts", "posters", "megaphone", "spray", "stones", "igniter", "flare", "petards_small",
          "petards_medium", "mortar"],
"spawn": id de lieu | ""
```

### 5.7 Lieux (`Quartier.SPOTS`)

Ids stables (le module Carte ajuste les positions aux bâtiments, peut en **ajouter**, n'en **retire** aucun) :
`depart, square, metro, kiosque, morris, wallace, abribus, parking, velib, bar_qg, boulangerie, supermarche, banque,
pharmacie, carrefour_ouest, rue_nord, rue_nord_fond, rue_sud, rue_sud_fond, station_service, cordon, parvis_mairie,
mairie`.

### 5.8 Gestes (`gesture(qui, nom)`)

Poses existantes d'`Actor` : `idle, pocket, crossed, akimbo, back, phone, film, selfie, call, dance, spray, highfive,
shake, link, comfort, drum, finger, fist, cheer, clap, sign, point, cup, whistle, talk, warm, head, cover, refuse,
wave, carry, pick, surrender, reach, megaphone, drink, give, stretch, rest_knee, treat, beckon`. Le module
Cinématiques & jeu d'acteur ajoute au minimum : `nod` (acquiescer), `shake_head` (non), `shrug` (hausser les épaules),
`explain` (mains qui accompagnent la parole), `sigh`, `laugh`, `hug`, `sit` (s'asseoir sur un banc/une marche).

### 5.9 Événements (bus « crowd »)

Existants : `glass_hit, glass_break, bus_destroyed, bus_collapse, mortar_fire, mortar_aim, burst, fire_start, fire_out,
player_fire, vandal, flare_lit, flare_raise, fire_flare, call, petard, petard_lit, petard_boom, cop_hit, cop_down,
car_vandal, car_burn, arrest, grab, police_gas, police_lbd, police_baton, police_bang, police_charge, police_stage,
police_retreat, gas_land, gas_back, lid, kick_bus, barrier_fall, boarded, civil_hit, player_gesture, player_mantle`.

Nouveaux (émis par le module Kit du joueur, consommés par Objectifs et Opinion) :

| Événement | Données |
|---|---|
| `talk` | `{"who": id de personnage d'histoire ou "passant", "node": Node3D}` (le joueur engage la conversation, E) |
| `tract_given` / `tract_refused` | `{"pos": Vector3, "by": "player"}` |
| `poster_stuck` | `{"pos": Vector3, "surface": "morris"\|"panneau"\|"mur"\|"abribus", "legal": bool}` |
| `spray_tag` | `{"pos": Vector3, "text": String, "surface": String}` |
| `megaphone` | `{"slogan": String, "joined": int}` |
| `film_start` / `film_stop` | `{}` / `{"sec": float}` |
| `film_clip` | `{"sec": float, "subjects": ["police_lbd", "police_baton", "crowd", "prix", "temoignage", "casse"…], "score": float, "published": bool}` |
| `photo` | `{"subjects": [...]}` |
| `testimony` | `{"who": String}` (témoignage recueilli au téléphone) |

---

## 6. Mécaniques réalistes (rien de magique)

- **Téléphone** (outil) : filmer / photographier. Le cadre compte : ce qui est **dans le champ et assez près**
  (violences policières, taille de la foule, étiquettes de prix, témoignage) fait la valeur d'une vidéo. Batterie,
  stockage limité, **la police peut confisquer** le téléphone d'un interpellé. Publier = choix (floutage…).
- **Tracts** : on les tend aux passants (E) ; beaucoup refusent, certains discutent, d'autres jettent. Une pile
  limitée (on en reprend au QG).
- **Affiches + colle** : sur la colonne Morris, les panneaux d'affichage libre (légal) ou n'importe quel mur
  (illégal, la police peut verbaliser).
- **Mégaphone** : lancer un slogan ; la foule reprend si elle est assez nombreuse et motivée.
- **Bombe de peinture** : taguer (vandalisme, opinion −, notoriété +).
- Outils d'origine (pierres, briquet, fumigène, pétards, mortier) : seulement quand le chapitre les autorise.
- **Gaz lacrymogène** : rien ne l'annule ; on recule, on se couvre le visage (masque/foulard **atténuent un peu**),
  on se rince au sérum avec un médic. **Pas de parapluie magique, pas de super-pouvoir.**
- **Sommations** : avant une dispersion, la police fait les sommations réglementaires au haut-parleur
  (« Première sommation : on va faire usage de la force. Dispersez-vous. »). Rester après = risque d'interpellation.
- **Interpellation** : garde à vue = chapitre raté (recommencer le chapitre) ; notoriété en hausse.

---

## 7. Qualité — « aucun bug toléré »

- Godot **4.4.1** : `tools/dev/gd` (sémaphore 3 instances) — `tools/dev/gd --headless --path . --import` après ajout
  de classes, puis les tests : `tools/tests/run_all.sh quick` (campagne + échantillon) et `tools/tests/run_all.sh`
  (tout). Une ligne `SCRIPT ERROR`, `Parse Error`, `ÉCHEC`, un délai dépassé = échec.
- Chaque module livre **au moins un test** `tools/tests/campaign_<module>.gd` (sans affichage, `--fixed-fps 30`) qui
  affiche `RÉSULTAT : OK`, et garde `campaign_smoke.gd` vert (toutes politiques : `first`, `last`, `random:1..3`).
- **Captures** pour tout ce qui se voit : `tools/dev/gd --render --path . --resolution 1280x720 -s tools/tests/shot1.gd -- /tmp/x.png 60`
  (rendu logiciel lent : ~5 min ; écrire un script de capture dédié qui place la caméra et prend plusieurs vues en
  une seule exécution). Regarder les images (outil Read) et corriger ce qui cloche.
- **Performances** : `tools/tests/perf3.gd` ne doit pas se dégrader de plus de 10 % ; 150 manifestants doivent
  rester fluides (LOD d'animation existant).
- Les tests d'origine (`tools/tests/*.gd`) restent verts.
- Style : celui du dépôt (GDScript typé, tabulations, commentaires `##` en français, noms anglais courts).
  Pas de `print` de débogage laissé dans le jeu.
- Pas de nouvelles dépendances de projet (pas d'addons). Pas d'autoload sauf nécessité absolue (justifier dans le
  commit). Les ressources non-ressources (JSON, txt) ne sont pas exportées : données en constantes GDScript.

---

## 8. Git

- Branche d'intégration : `claude/friendly-shannon-mkzhif` (dépôt `/home/user/trajectoire`).
- Chaque module travaille dans **son worktree** : `tools/dev/new_worktree.sh <module>` crée
  `/home/user/wt/<module>` sur la branche locale `wip/<module>`. On y code, on y teste, on y **commite**
  (messages en français, clairs). On ne pousse pas ; l'intégration fusionne.
- Ne pas modifier les fichiers d'un autre module (§ 9). Si un changement ailleurs est indispensable, le faire
  **minimal** et l'expliquer dans le message de commit (l'intégrateur arbitre).

---

## 9. Modules et fichiers attribués

| Module | Fichiers (création ✚ / modification ✎) |
|---|---|
| **Fondation A — noyau** | ✎ `scripts/campaign/campaign.gd`, `chapter_director.gd`, `chapter_script.gd`, `world_setup.gd` ; ✚ tests `campaign_smoke*.gd`, `campaign_core.gd` |
| **Fondation B — monde paramétrable & menus** | ✎ `main.gd`, `crowd.gd` (taille/compo), `police.gd` (+ `cop.gd` si besoin) (config), `civilians.gd`, `residents.gd`, `player.gd` (outils autorisés, point de départ), `hud.gd` (outils masqués), `title_screen.gd`, `pause_menu.gd` ; ✚ `scripts/campaign/sandbox_menu.gd` |
| **Dialogues** | ✎ `scripts/campaign/dialogue_ui.gd` ; ✚ `scripts/campaign/dialogue_*.gd`, `tools/tests/campaign_dialogue.gd`, `tools/check_dialogues.gd` (validateur de tous les `dlg_*.gd`) |
| **Cinématiques & jeu d'acteur** | ✎ `cinematics.gd`, `story_cast.gd`, `story_actor.gd` ; ✎ `actor.gd` (nouveaux gestes, parole) ; ✚ `tools/tests/campaign_cine.gd` |
| **Objectifs & interface** | ✎ `objective.gd`, `objective_tracker.gd` ; ✚ `scripts/campaign/objective_*.gd`, `opinion_hud.gd` (jauge d'opinion en jeu), `tools/tests/campaign_objectives.gd` |
| **Kit du joueur** | ✚ `scripts/campaign/phone_tool.gd`, `tract_tool.gd`, `poster_tool.gd`, `megaphone_tool.gd`, `spray_tool.gd`, `talk_interact.gd` ; ✎ `player.gd` (nouveaux outils), `hud.gd` (barre d'outils), `passerby.gd`/`npc.gd` (réactions aux tracts, conversation) |
| **Opinion & actualités** | ✎ `opinion_model.gd`, `news_feed.gd` ; ✚ `scripts/campaign/news_*.gd` (JT, réseaux sociaux, bilan, fins) |
| **Carte** | ✎ `quartier.gd`, `paris_street.gd`, `paris_building.gd`, `streetscape.gd`, `landmarks.gd`, `parking.gd`, `shop*.gd`, `nav_grid.gd`, `crowd.gd` (zone seulement : `AREA_MIN/MAX`), `civilians.gd` (itinéraires) ; ✚ `scripts/map_*.gd` |
| **Visuels** | ✎ `scripts/lighting.gd`, `shaders/*`, `settings.gd` (réglages image) ; ✚ `scripts/weather.gd`, `tools/build_*textures*.py` (nouvelles textures) |
| **Personnages** | ✎ `scripts/story/cast_looks.gd`, `human.gd` (matériaux : peau, yeux, cheveux, tissus), `tools/build_character.py`, `assets/character/*` |
| **Scénario** | ✎ `scripts/story/story.gd` ; ✚ `scripts/story/BIBLE.md`, `ch_*.gd`, `dlg_*.gd` (retire `ch_demo*.gd`/`dlg_demo.gd`) |
| **Audio** | ✎ `story_audio.gd`, `tools/build_audio*.py` ; ✚ `assets/voice/**`, `assets/audio/*` (nouvelles ambiances), `tools/build_voices.py` |
