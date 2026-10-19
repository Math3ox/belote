# Belote en 3D isométrique (assembleur x86-64, Windows)

Belote contre des bots (ou en ligne avec des amis), dans une fenêtre Windows : table ronde en perspective isométrique,
cartes posées sur le tapis avec rotation et animation. Même esprit que le jeu du 421 : assembleur GNU `as` (syntaxe
Intel), sans bibliothèque C, uniquement `user32`, `gdi32`, `kernel32` et `ws2_32` (réseau).

## Lancer
Double-clic sur `belote.exe` (aucune installation). Les réglages sont mémorisés dans `belote.cfg`
(supprimer ce fichier remet les valeurs par défaut).

## Modes de jeu
| Mode | Joueurs | Principe |
|---|---|---|
| **Belote à 4** (par défaut) | toi + 3 bots | toi et le bot d'en face (« partenaire ») contre les deux autres bots |
| **Belote à deux** (touche `J`) | toi + 1 bot | belote « de comptoir » : variante à deux joueurs (voir plus bas) |
| **En ligne** (touche `N`) | 2 à 4 humains | les places libres sont tenues par des bots ; 2 humains seulement en mode « à deux » |

## Règles (belote classique à 4)
- 32 cartes. On donne 3 puis 2 cartes à chacun, on retourne une carte : c'est la proposition d'atout.
  Au **1er tour**, chacun à son tour peut **prendre** (la couleur de la retourne devient l'atout) ou passer.
  Si tout le monde passe, **2e tour** : on peut prendre dans une autre couleur. Si tout le monde repasse, on redonne.
  Le preneur ramasse la retourne, puis on complète : tout le monde a 8 cartes.
- Valeur des cartes : à l'**atout** V 20, 9 14, A 11, 10 10, R 4, D 3 ; hors atout A 11, 10 10, R 4, D 3, V 2.
  Total 152 + 10 de der = **162** points par donne.
- Il faut **fournir** la couleur demandée ; sinon **couper** (jouer atout) sauf si le partenaire est maître du pli ;
  il faut **monter** à l'atout quand on le peut.
- **Belote-rebelote** : roi et dame d'atout dans la même main, +20 (annoncés automatiquement quand tu les joues).
- **Annonces** (touche `A` pour les activer/couper) : tierce 20, cinquante 50, cent 100 (suite de 5 ou plus),
  carrés (valets 200, 9 150, as/10/rois/dames 100). Elles sont comptées automatiquement après le 1er pli :
  seule l'équipe qui a la meilleure annonce marque les siennes.
- **Contrat** : l'équipe qui a pris doit faire plus de points que l'autre (annonces et belote comprises).
  Sinon elle est **dedans** : les adversaires marquent les 162 points (la belote reste à celui qui l'a).
  À égalité : **litige**, les points du preneur sont mis de côté pour la prochaine donne.
- **Capot** (un camp fait tous les plis) : 252 points.
- La partie se joue en 1000 points par défaut (touche `P` : 501 / 1000 / 1500).

## Belote à deux (variante implémentée)
6 cartes chacun, un talon de 20 cartes avec la retourne dessus. Le joueur qui n'a pas donné parle en premier (prendre ou
passer, 2 tours comme à 4). Le preneur ramasse la retourne et l'adversaire pioche une carte (7 chacun). **Tant que le talon
n'est pas vide, aucune obligation** de fournir, couper ou monter ; après chaque pli le gagnant pioche en premier. Quand le talon est
vide, les obligations de la belote classique s'appliquent. Même décompte (162 points par donne, contrat à battre, belote 20).

## Jouer
- **Enchères** : boutons PRENDRE / PASSER (1er tour), couleur / PASSER (2e tour).
- **Jeu** : clique sur une carte (les cartes grisées sont injouables). Espace ou Entrée : SUITE à la fin d'une manche.
- Raccourcis : `J` 4 joueurs / à deux · `L` niveau des bots · `A` annonces · `H` aide · `P` objectif · `Q` qualité
  (2x anticrénelé / 1x rapide) · `F11` plein écran · `F12` capture `belote_shot.bmp` · `N` en ligne · `Échap` quitter.
- `H` (aide) : conseil pour prendre ou passer, et la carte conseillée est surlignée en or pendant le jeu.
- `U` : l'ordinateur joue à ta place (démonstration / tests).

## Niveaux des bots (touche `L`)
- **facile** : heuristiques normales mais 35 % de coups au hasard et enchères bruitées.
- **normal** : évaluation de la main pour prendre ; comptage des cartes sorties, cartes maîtresses, couleurs manquantes,
  on charge le partenaire quand il est maître, on gagne le pli avec la plus petite carte possible.
- **difficile** : simulations de Monte-Carlo : le bot tire au hasard les cartes qu'il ne voit pas (en respectant les couleurs
  que chaque joueur a montré ne plus avoir), joue la fin de la donne pour chaque carte possible et choisit celle qui rapporte
  le plus en moyenne ; même méthode pour décider de prendre. En simulation il bat « normal » dans environ 80 % des parties.

## En ligne (touche `N`)
Un joueur choisit **H** (héberger) : le jeu affiche ses adresses IP (réseau local, ou VPN type Tailscale / ZeroTier, ou
redirection du port TCP **4210** sur la box). Les autres choisissent **R**, tapent l'IP de l'hôte (`ip` ou `ip:port`) puis Entrée.
- À **4 joueurs** : jusqu'à 3 invités (le 1er prend la place de ton partenaire). La partie démarre quand ils sont tous là, ou
  quand l'hôte appuie sur **Entrée** : les places libres sont tenues par des bots.
- En mode **à deux** : un seul invité, la partie démarre dès qu'il est connecté.
- Principe « lockstep » : toutes les machines exécutent la même partie avec la même graine aléatoire (envoyée par l'hôte) ;
  seules les actions (enchère, carte jouée, « suite ») circulent, 12 octets chacune. Les joueurs doivent avoir la même version.
  Si quelqu'un se déconnecte, tout le monde revient à une partie locale.

## Fichiers
- `belote.s` : point d'entrée, `-sim` (banc d'essai sans fenêtre). Inclut tout le reste.
- `game.s` : règles, état de la donne, enchères, annonces, plis, décompte. `ai.s` : bots facile/normal. `mc.s` : bots difficiles.
- `gfx.s` : primitives GDI, polices, transformation isométrique, dessin des cartes, réduction 2x2 (SSE).
- `ui.s` / `ui2.s` : déroulement, animations, boutons, bulles, tapis, mains, panneaux. `gui.s` : fenêtre, tampons, plein écran,
  mise à l'échelle, réglages. `net.s` : jeu en ligne. `sim.s` : journal et simulations.
- Outils de test : `check.py` (rejoue `sim.log` avec une réimplémentation indépendante des règles : légalité de chaque coup,
  mains, scores, annonces, litiges), `uitest.py` (pilote l'interface par clics + captures), `nettest.py` (2 à 4 instances en ligne
  qui doivent rester identiques), `shot.py`, `tune.py` / `tune2.py` (réglage des bots).

## Compiler / tester
`build.bat` (gcc/as/ld de MSYS2 ucrt64). Banc d'essai : `belote.exe -sim <parties> <graine> <joueurs 2|4> <niveau équipe 0> <niveau équipe 1> <journal 0|1>`
puis `python check.py`.
