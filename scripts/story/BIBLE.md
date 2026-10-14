# Blocus — « La Hausse » : bible du scénario

Référence d'écriture de la campagne. Contrat technique : `docs/CAMPAGNE.md`. Code : `scripts/story/story.gd`
(chapitres, réglages du monde, choix de la fin), `ch_<id>.gd` (mise en scène), `dlg_<id>.gd` (dialogues),
`ch_base.gd` (outils communs). Tout est **fictif**.

---

## 1. Le monde

**France, mars–avril 2027.** Deux hivers de hausses : gazole à 2,79 €/L, baguette à 1,65 €, électricité +38 % en
un an, loyers indexés qui suivent. Le gouvernement du Premier ministre **Arnaud Vérin** (fictif) fait adopter
sans vote, par procédure accélérée, la **loi de Stabilité** portée par la ministre de l'Économie **Claire Morvan** :
TVA relevée de deux points, gel des salaires publics et des minima sociaux pour trois ans, fin du bouclier
tarifaire sur l'énergie au 1er avril.

- **Canal Continu** : chaîne d'info en continu. Parle de « grogne », de « pédagogie », de « prise d'otages » les
  jours de blocage. Sa présentatrice (id `presentatrice`) n'est pas une méchante : elle lit le conducteur ; son ton
  change avec les sondages.
- **USS — Union Santé Solidaire** : petit syndicat des hôpitaux de Nadia. Pas de grande centrale dans l'histoire.
- **Le quartier des Tanneurs**, Paris : le **boulevard des Ormes** (le boulevard du jeu), la **rue des Cerisiers**
  (nord), la **rue de la Forge** (sud, station-service **Carbura**). Le **square des Tanneurs**, la supérette **Le Panier du Coin**, la **Banque Hexa**, la pharmacie, la boulangerie, la colonne
  Morris, la mairie d'arrondissement au bout du boulevard.
- **Le Zinc** : café-bar de Jo. Télé au-dessus du comptoir, toujours sur Canal Continu, son coupé sauf pour le JT.

## 2. Le ton

Réaliste, sobre, contemporain. Personne n'a tort à 100 %. On rit un peu, même les mauvais jours. Répliques
courtes, oral (« t'as », « j'sais pas », « ouais »), un mot d'argot quand il vient tout seul (« thune », « daron »,
« les keufs » chez Karim seulement, « les collègues » chez Rivière). Pas de discours : quand quelqu'un
s'emballe, un autre le coupe. Pas de slogans réels, pas de partis, pas de personnalités.

**Violence** : toujours un choix du joueur, jamais récompensé quand elle vise des personnes. La casse fait plaisir
à Karim et monte la mobilisation des plus radicaux, mais fait baisser l'opinion, monte la répression et la
notoriété de Sam. La non-violence tenue face à la police (sit-in, sortir les gens, soigner, filmer) est ce qui
fait basculer l'opinion. Les violences policières **filmées et diffusées** font monter l'opinion.

## 3. Personnages

| id | Qui | Ce qu'il veut | Ce qu'il craint | Arc |
|---|---|---|---|---|
| `sam` (joueur) | Sam Diallo, 24 ans, livreur à vélo. Vit avec sa mère Mariam (aide-soignante de nuit) et sa sœur Lina, 14 ans. N'a jamais milité. | Que le mois tienne. | Être « celui qui fout le bordel », décevoir sa mère. | De spectateur à porte-voix ; le joueur décide quel genre. |
| `nadia` | Nadia Benali, 45 ans, aide-soignante, déléguée USS. Collègue de la mère de Sam. | Le nombre. Que ça dure. | La casse qui donne raison au gouvernement ; la fatigue. | Prudente → apprend à lâcher la main (confie le mégaphone, accepte le blocage). Si Sam casse, elle prend ses distances. |
| `karim` | Karim Haddad, 23 ans, ami d'enfance de Sam, intérimaire en logistique. Drôle, sincère, à vif. | Qu'on arrête de « demander poliment ». | Rien, il dit. En vrai : finir comme son père, usé à 50 ans. | Tenté par la casse. Selon Sam : retenu, accompagné, ou lâché. Peut finir en garde à vue (ch. 3) puis en prison (ch. 4). |
| `ines` | Inès Morel, 26 ans, interne en médecine (urgences). Street medic. | Que personne ne perde un œil. | Le jour où elle ne pourra rien faire. | Neutre et soignante → témoin. Sa confiance se gagne en la protégeant (ch. 4). |
| `lou` | Lou Garnier, 31 ans, vidéaste indépendante. | Une image qui dit vrai. | Exposer des gens qui n'ont rien demandé. | Monte la vidéo des prix (ch. 2), sort les images de la nasse (ch. 4), prépare un documentaire. |
| `jo` | Jo (Joseph) Lemaire, 62 ans, patron du Zinc, ancien docker du Havre. | Que son café reste ouvert. | Revivre les défaites de 95, de 2010. | Bourru, « je fais pas de politique » → ouvre son arrière-salle, cache les gens (ch. 4), sert le café du blocage. |
| `mme_ferreira` | Maria Ferreira, 74 ans, veuve, retraitée (ménage, 40 ans). | Avoir chaud. Ne pas être une charge. | La honte. | Ne demande rien → accepte de témoigner (ch. 2) ; parle au commissaire et aux caméras (ch. 5). |
| `commissaire` | Commissaire Rivière, 52 ans, maintien de l'ordre de l'arrondissement. | Que la nuit finisse sans mort. | La préfecture. Les images. | Un rouage, pas un monstre : applique les ordres, reconnaît Sam, négocie au ch. 5 si l'opinion le lui permet. |
| `presentatrice` | Présentatrice de Canal Continu. | — | — | Ses journaux suivent les sondages : « grogne » → « mouvement » → « crise ». |

Relations (−100..100) : départ 0. Repères : ±5 petit geste, ±10 choix net, ±15 trahison ou loyauté forte.

## 4. Chapitres

| # | id | Titre | Jour | Lieu clé | Foule | Police |
|---|---|---|---|---|---|---|
| 0 | `prologue` | La note | lun. 8 mars, 8 h 10, matin | supérette → Zinc → pharmacie → colonne Morris | aucune | absente |
| 1 | `douze` | On était douze | jeu. 11 mars, 18 h 30, fin d'après-midi | square, colonne Morris, banque | 12 | une patrouille |
| 2 | `prix` | Les prix, en vrai | sam. 13 mars, 15 h, après-midi, bruine | supérette, station Carbura, Zinc | 6 | patrouille appelée par le gérant |
| 3 | `cortege` | Premier cortège | mar. 16 mars, 19 h 40, crépuscule | square → parvis de la mairie | mobilisation (~40) | cordon devant la mairie |
| 4 | `nasse` | La nasse | jeu. 25 mars, 22 h 15, nuit, pluie | boulevard, rue des Cerisiers | mobilisation (~80) | encerclement, LBD |
| 5 | `blocus` | Blocus | mar. 6 avril, 5 h 50, aube | station Carbura, boulevard | mobilisation (~150) | cordon, négociation |

### 0. La note
La carte de Sam est refusée à la caisse (3 courses, 23,40 €). Au Zinc, Jo lui offre le café ; la télé annonce la
loi. Karim débarque, furieux (son agence d'intérim gèle les missions). Mme Ferreira, chargée, avoue à demi-mot
qu'elle ne chauffe plus. Nadia colle une affiche : rassemblement jeudi au square.
Choix : réaction à la télé (`ch0_reaction` = colere|resigne|ironie) ; porter les courses de Mme Ferreira
(`ch0_aide_ferreira`) ; promesse à Nadia (`ch0_promesse`).

### 1. On était douze
Douze au square. Nadia distribue les rôles : tracts, affiches (légal : colonne Morris, panneaux libres). Karim veut
taguer la Banque Hexa (« Ils ont fait 2 milliards l'an dernier »). Choix : l'en dissuader (`ch1_karim_retenu`),
taguer avec lui (`ch1_tag_banque`), le laisser faire seul (`ch1_tag_karim`). Une patrouille passe au ralenti. Inès
arrive à la fin, en blouse sous le manteau. Lien : le nombre de tracts → mobilisation ; le tag → notoriété.

### 2. Les prix, en vrai
Lou propose une vidéo : les étiquettes de la supérette, le totem de la station, une voix. Mme Ferreira accepte de
parler si on ne la « fait pas pleurer ». Choix : visage flouté ou non (`ch2_video` = floutee|nette) ; avec ou sans
son nom. Le gérant de la supérette appelle la police : partir calmement (`ch2_parti_calme`) ou s'accrocher
(`ch2_accroche`, contrôle d'identité : notoriété +). Lou publie le soir (`ch2_publiee`) ; témoignage :
`temoignage_ferreira`.

### 3. Premier cortège
Nadia confie le mégaphone à Sam (s'il a tenu parole, sinon elle hésite). Cortège jusqu'au parvis de la mairie,
cordon de Rivière. Choix : sit-in (`ch3_choix` = sitin) ou forcer le cordon (= forcer). Karim est interpellé (il a
répondu à une bousculade). Choix : intervenir (`ch3_karim` = libere, ou gav si raté), filmer (= filme), laisser
faire (= gav). Rivière note le visage de Sam (`riviere_connait_sam`).

### 4. La nasse
Nuit de pluie, la police encercle le cortège au carrefour. Un tir de LBD blesse un lycéen (Théo, 17 ans) ; Inès le
soigne à genoux. Sam : protéger Inès, filmer, sortir les images du quartier par la rue des Cerisiers
(`images_sorties`), faire sortir les gens (`ch4_sortie`). Karim et une vingtaine partent vers la banque : les
suivre (`ch4_emeute`), le retenir (si la relation le permet : `ch4_karim_retenu`) ou le laisser partir. Karim
interpellé pendant l'émeute → `karim_prison` (comparution immédiate). Jo ouvre l'arrière-salle (`jo_cache`).
Si les images sortent et que Lou a confiance : `docu_lou`.

### 5. Blocus
Grève générale. À l'aube, blocage de la station Carbura puis du boulevard. Tenir jusqu'à 8 h, puis Rivière vient
négocier. Arguments selon l'histoire : la vidéo des prix, les images de la nasse, Mme Ferreira, le nombre. Choix
final : lever le blocage contre une audience en préfecture (`ch5_issue` = accord), tenir (= tenir), ou
l'affrontement (= affrontement). Épilogue au Zinc devant le JT.

## 5. Drapeaux et jauges (référence)

| Drapeau | Valeurs | Posé | Repris |
|---|---|---|---|
| `ch0_reaction` | colere / resigne / ironie | 0 | 1 (Karim), 5 (épilogue) |
| `ch0_aide_ferreira` | bool | 0 | 2 (elle accepte plus vite) |
| `ch0_promesse` | bool | 0 | 1 (Nadia), 3 (mégaphone) |
| `ch1_tag_banque`, `ch1_tag_karim`, `ch1_karim_retenu` | bool | 1 | 2 (Lou a vu le tag), 3, 4 |
| `ch2_video` | floutee / nette | 2 | 3, 5 |
| `ch2_publiee`, `temoignage_ferreira`, `ch2_accroche`, `ch2_parti_calme` | bool | 2 | 3, 5, fins |
| `ch3_choix` | sitin / forcer | 3 | 4, 5 |
| `ch3_karim` | libere / filme / gav | 3 | 4, 5 |
| `riviere_connait_sam` | bool | 3 | 4, 5 |
| `ch4_emeute`, `ch4_karim_retenu`, `ch4_sortie`, `images_sorties`, `jo_cache`, `ch4_protege_ines` | bool | 4 | 5, fins |
| `karim_prison`, `sam_fiche` | bool | 4, 5 | fins |
| `docu_lou` | bool | 4 | fin cachée |
| `ch5_issue` | accord / tenir / affrontement | 5 | fins |
| `ch5_ferreira_la`, `ch5_arg_*`, `ch5_laisse_passer` | bool | 5 | négociation, épilogue |
| `fin_suggeree` | greve / recul / amere / essoufflement | 5 (épilogue) | JT de l'épilogue ; `NewsFeed.pick_ending()` peut le reprendre |
| `casse_total` | int (vitres + 3 × voitures + choix violents) | tous | fins |

Jauges (`Campaign`) : opinion (départ 18), mobilisation (12), répression (0,15), notoriété (0). Chaque chapitre
ajoute des effets de choix modestes (±1 à ±6 d'opinion) ; l'OpinionModel ajoute ceux du jeu (tracts, vidéos, casse).

## 6. Fins

`Story.ending_for_state()` calcule la fin suggérée (le module Opinion & actualités l'utilise dans
`NewsFeed.pick_ending()`, ou affine) :

1. **`greve` — « La grève »** (cachée) : `docu_lou` et `temoignage_ferreira`, opinion ≥ 55, `casse_total` ≤ 6,
   `ch5_issue` ≠ affrontement. Le documentaire de Lou et la voix de Mme Ferreira passent partout ; la grève
   devient nationale ; la loi tombe et le gouvernement avec.
2. **`recul` — « Le recul »** : opinion ≥ 60, `casse_total` ≤ 10, ni `karim_prison` ni `sam_fiche`. La loi est
   retirée ; le quartier fête ça au Zinc.
3. **`amere` — « Victoire amère »** : opinion ≥ 45 (ou ≥ 60 avec dégâts). Loi retirée, mais Karim en prison
   ou Sam fiché, vitrines en contreplaqué, procès à venir.
4. **`essoufflement` — « L'essoufflement »** : sinon. Le mouvement s'éteint, les procès commencent ; Nadia
   repart en tournée de nuit.

## 7. Habillage sonore (ids pour le module Audio)

Musiques : `theme` (titre), `matin` (prologue), `espoir` (ch. 1–2), `marche` (cortège), `tension`, `nasse`,
`aube`, `fin`. Ambiances : `rue_matin`, `cafe`, `square`, `supermarche`, `cortege`, `pluie_nuit`, `blocage`.
Voix : `assets/voice/<id du chapitre>/<nœud>_<i>.ogg` (§ 5.3).
