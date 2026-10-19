//! Déroulement d'une partie autour du moteur : tours des bots, délais et animations (cartes qui volent,
//! pli ramassé), bulles, conseils, « suite » à la fin des manches, actions en ligne. Sans graphisme :
//! le même code sert à la fenêtre et aux tests. Tout ce qui touche à la partie est déterministe
//! (graine + suite des actions), ce qui permet le jeu en ligne « lockstep ».

use crate::engine::*;
use std::collections::VecDeque;

pub const NT_HELLO: u8 = 1;
pub const NT_START: u8 = 2;
pub const NT_BID: u8 = 3;
pub const NT_PLAY: u8 = 4;
pub const NT_NEXT: u8 = 5;

pub const SUIT_NAMES: [&str; 4] = ["Pique", "Cœur", "Carreau", "Trèfle"];
pub const LEVEL_NAMES: [&str; 3] = ["facile", "normal", "difficile"];
const ANN_NAMES: [&str; 5] = ["", "Tierce", "Cinquante", "Cent", "Carré"];

/// Centre des mains (bas, gauche, haut, droite).
pub const HX: [f64; 4] = [550.0, 92.0, 550.0, 1008.0];
pub const HY: [f64; 4] = [686.0, 345.0, 96.0, 345.0];

#[derive(Clone, Copy, PartialEq, Debug)]
pub struct Frame {
    pub kind: u8,
    pub b1: u8,
    pub b: u16,
    pub c: u32,
    pub d: u32,
}

pub struct Table {
    pub e: Engine,
    /// siège du joueur de cet ordinateur
    pub me: usize,
    pub botlvl: i32,
    pub help: bool,
    /// l'ordinateur joue à la place du joueur local (démonstration, tests)
    pub auto: bool,
    /// masque des sièges humains
    pub humans: u32,
    /// sièges qui ont appuyé sur SUITE (en ligne)
    pub nextmask: u32,
    pub online: bool,
    pub now: f64,
    wake: f64,
    /// début du ramassage du pli (0 = pas en cours)
    pub collect: f64,
    /// carte conseillée (aide), -1 = aucune
    pub hint: i32,
    /// départ de la carte jouée par chaque joueur : instant et position
    pub ast0: [f64; 4],
    pub asx: [f64; 4],
    pub asy: [f64; 4],
    /// bulles : texte et fin d'affichage
    pub bub: [Option<(String, f64)>; 4],
    /// victoires / défaites (parties locales)
    pub wins: [u32; 2],
    pub save_needed: bool,
    pub outbox: Vec<Frame>,
    pub inbox: VecDeque<Frame>,
}

/// Abscisse de la carte i (sur n) de la main du joueur du bas.
pub fn hand_cx(i: usize, n: usize) -> f64 {
    550.0 - (n as f64 - 1.0) * 42.0 + i as f64 * 84.0
}

impl Table {
    pub fn new(seed: u64) -> Table {
        let mut e = Engine::new();
        e.rng = seed | 1;
        let mut t = Table {
            e,
            me: 0,
            botlvl: 1,
            help: false,
            auto: false,
            humans: 1,
            nextmask: 0,
            online: false,
            now: 10_000.0,
            wake: 0.0,
            collect: 0.0,
            hint: -1,
            ast0: [0.0; 4],
            asx: [0.0; 4],
            asy: [0.0; 4],
            bub: Default::default(),
            wins: [0, 0],
            save_needed: false,
            outbox: Vec::new(),
            inbox: VecDeque::new(),
        };
        t.new_match();
        t
    }

    pub fn np(&self) -> usize {
        self.e.np as usize
    }

    pub fn phase(&self) -> i32 {
        self.e.gs.phase
    }

    pub fn turn(&self) -> usize {
        self.e.gs.turn as usize
    }

    /// Position d'affichage du joueur p : 0 bas, 1 gauche, 2 haut, 3 droite.
    pub fn disp_pos(&self, p: usize) -> usize {
        let np = self.np();
        let rel = (p + np - self.me) % np;
        if np == 2 {
            rel * 2
        } else {
            rel
        }
    }

    /// Le joueur p est-il le joueur de cet ordinateur (et pas joué par l'ordinateur) ?
    pub fn is_human(&self, p: usize) -> bool {
        !self.auto && p == self.me && self.e.lvl[p] == -1
    }

    /// Une décision du joueur p doit-elle être prise par l'ordinateur ?
    fn is_bot(&self, p: usize) -> bool {
        self.e.lvl[p] >= 0 || (self.auto && p == self.me)
    }

    pub fn player_name(&self, p: usize) -> String {
        let np = self.np();
        let rel = (p + np - self.me) % np;
        if rel == 0 {
            "TOI".into()
        } else if self.e.lvl[p] == -1 {
            format!("JOUEUR {}", p + 1)
        } else if np == 2 {
            "BOT".into()
        } else {
            ["", "ADVERSAIRE 1", "PARTENAIRE", "ADVERSAIRE 2"][rel].into()
        }
    }

    fn set_bubble(&mut self, p: usize, text: String, ms: f64) {
        self.bub[p] = Some((text, self.now + ms));
    }

    // ---------- déroulement ----------
    pub fn set_levels(&mut self) {
        for p in 0..4 {
            self.e.lvl[p] = if self.humans >> p & 1 == 1 { -1 } else { self.botlvl };
        }
    }

    pub fn new_match(&mut self) {
        self.set_levels();
        self.nextmask = 0;
        self.e.new_match();
        self.e.dealer = self.e.rng_mod(self.e.np as u32) as i32;
        self.new_round();
    }

    fn new_round(&mut self) {
        self.e.new_round();
        self.bub = Default::default();
        self.hint = -1;
        self.after_new_round();
    }

    fn after_new_round(&mut self) {
        self.ast0 = [self.now - 2000.0; 4];
        self.collect = 0.0;
        self.wake = self.now + 600.0;
    }

    /// Enchère du joueur dont c'est le tour (-1 = passer, sinon couleur d'atout).
    fn apply_bid(&mut self, choice: i32) {
        let p = self.turn();
        if choice == -1 {
            self.set_bubble(p, "Je passe".into(), 1500.0);
        } else {
            self.set_bubble(p, format!("Je prends : {}", SUIT_NAMES[choice as usize]), 2200.0);
        }
        self.e.do_bid(choice);
        self.wake = self.now + 850.0;
        self.hint = -1;
    }

    /// Carte jouée (position dans la main du joueur dont c'est le tour).
    fn apply_play(&mut self, pos: usize) {
        let p = self.turn();
        let dp = self.disp_pos(p);
        let n = self.e.gs.hn[p] as usize;
        let (x, y) = if dp == 0 { (hand_cx(pos, n), 686.0) } else { (HX[dp], HY[dp]) };
        self.asx[p] = x;
        self.asy[p] = y;
        self.ast0[p] = self.now;
        self.e.do_play(pos);
        if self.e.gs.ev != 0 {
            let txt = if self.e.gs.ev == 1 { "Belote !" } else { "Rebelote !" };
            self.set_bubble(self.e.gs.evp as usize, txt.into(), 1800.0);
            self.e.gs.ev = 0;
        }
        self.wake = self.now + if self.phase() == PH_TRICKEND { 1250.0 } else { 700.0 };
        self.hint = -1;
    }

    /// Après le 1er pli : bulles des annonces de l'équipe qui les marque.
    fn annonce_bubbles(&mut self) {
        let team = self.e.gs.annteam;
        if team < 0 {
            return;
        }
        for p in 0..4 {
            if (p & 1) as i32 == team && self.e.gs.ann_n[p] > 0 {
                let k = self.e.gs.anl[p][0] as usize;
                self.set_bubble(p, ANN_NAMES[k].into(), 2600.0);
            }
        }
    }

    /// Le pli a fini de glisser vers son gagnant : on le range.
    fn collect_done(&mut self) {
        self.collect = 0.0;
        self.e.trick_collect();
        if self.phase() == PH_MATCHEND && !self.online {
            let lost = ((self.e.rs_winner as usize) ^ self.me) & 1;
            self.wins[lost] += 1;
            self.save_needed = true;
        }
        if self.e.gs.trickno == 1 && self.phase() == PH_PLAY {
            self.annonce_bubbles();
        }
        self.wake = self.now + 500.0;
    }

    /// Avance le temps de dt millisecondes : bots, ramassage des plis, actions reçues.
    pub fn tick(&mut self, dt: f64) {
        self.now += dt;
        if self.online {
            self.pump();
        }
        if self.help && self.hint == -1 && self.phase() == PH_PLAY {
            self.update_hint();
        }
        if self.now < self.wake {
            return;
        }
        let ph = self.phase();
        let p = self.turn();
        match ph {
            PH_BID1 | PH_BID2 if self.is_bot(p) => {
                let c = self.e.bot_bid(p);
                if self.e.lvl[p] == -1 {
                    self.human_bid(c); // siège humain joué par l'ordinateur (U) : action diffusée
                } else {
                    self.apply_bid(c);
                }
            }
            PH_PLAY if self.is_bot(p) => {
                let pos = self.e.bot_card(p);
                if self.e.lvl[p] == -1 {
                    self.human_play(pos);
                } else {
                    self.apply_play(pos);
                }
            }
            PH_TRICKEND => {
                if self.collect == 0.0 {
                    // le pli reste visible, puis glisse vers le gagnant
                    self.collect = self.now;
                    self.wake = self.now + 320.0;
                } else {
                    self.collect_done();
                }
            }
            PH_ROUNDEND | PH_MATCHEND if self.auto && self.nextmask >> self.me & 1 == 0 => self.human_next(),
            _ => {}
        }
    }

    // ---------- actions du joueur local ----------
    fn send(&mut self, kind: u8, b: u16) {
        if self.online {
            self.outbox.push(Frame { kind, b1: self.me as u8, b, c: 0, d: 0 });
        }
    }

    /// Enchère du joueur local (-1 = passer).
    pub fn human_bid(&mut self, choice: i32) {
        self.send(NT_BID, (choice + 1) as u16);
        self.apply_bid(choice);
    }

    pub fn human_play(&mut self, pos: usize) {
        self.send(NT_PLAY, pos as u16);
        self.apply_play(pos);
    }

    /// SUITE (fin de manche / de partie).
    pub fn human_next(&mut self) {
        if self.online {
            self.send(NT_NEXT, 0);
            self.mark_next(self.me);
        } else {
            self.do_next_step();
        }
    }

    fn mark_next(&mut self, seat: usize) {
        self.nextmask |= 1 << seat;
        if self.nextmask & self.humans == self.humans {
            self.nextmask = 0;
            self.do_next_step();
        }
    }

    fn do_next_step(&mut self) {
        match self.phase() {
            PH_MATCHEND => self.new_match(),
            PH_ROUNDEND => {
                self.e.next_round();
                self.after_new_round();
            }
            _ => {}
        }
    }

    /// Applique dans l'ordre les actions reçues, chacune quand c'est bien le tour de son auteur.
    fn pump(&mut self) {
        while let Some(f) = self.inbox.front().copied() {
            let seat = f.b1 as usize;
            let ph = self.phase();
            match f.kind {
                NT_BID => {
                    if !(ph == PH_BID1 || ph == PH_BID2) || seat != self.turn() {
                        return;
                    }
                    self.inbox.pop_front();
                    self.apply_bid(f.b as i16 as i32 - 1);
                }
                NT_PLAY => {
                    if ph != PH_PLAY || seat != self.turn() {
                        return;
                    }
                    self.inbox.pop_front();
                    if (f.b as i32) < self.e.gs.hn[seat] && self.e.legal_mask(seat) >> f.b & 1 == 1 {
                        self.apply_play(f.b as usize);
                    }
                }
                NT_NEXT => {
                    if !(ph == PH_ROUNDEND || ph == PH_MATCHEND) {
                        return;
                    }
                    self.inbox.pop_front();
                    self.mark_next(seat);
                }
                _ => {
                    self.inbox.pop_front();
                }
            }
        }
    }

    /// Démarre une partie en ligne. `config` : sièges humains (bits 0-3), annonces (bit 4),
    /// niveau des bots (bits 5-6), 4 joueurs (bit 7).
    pub fn net_begin(&mut self, me: usize, config: u8, target: i32, seed: u64) {
        self.me = me;
        self.e.target = target;
        self.e.rng = seed;
        self.humans = (config & 15) as u32;
        self.e.optann = (config >> 4 & 1) as i32;
        let lvl = (config >> 5 & 3) as i32;
        self.botlvl = if lvl > 2 { 1 } else { lvl };
        self.e.np = if config & 0x80 != 0 { 4 } else { 2 };
        self.online = true;
        self.inbox.clear();
        self.outbox.clear();
        self.nextmask = 0;
        self.new_match();
    }

    pub fn net_config(&self, humans: u32) -> u8 {
        (humans as u8) | (self.e.optann as u8) << 4 | (self.botlvl as u8) << 5 | if self.np() == 4 { 0x80 } else { 0 }
    }

    /// Fin du jeu en ligne : retour à une partie locale.
    pub fn leave_online(&mut self) {
        self.online = false;
        self.humans = 1;
        self.me = 0;
        self.inbox.clear();
        self.outbox.clear();
        self.new_match();
    }

    // ---------- aide ----------
    /// Carte conseillée au joueur local (calculée sur une copie : la partie n'est pas touchée).
    fn update_hint(&mut self) {
        self.hint = -1;
        let p = self.turn();
        if self.help && self.phase() == PH_PLAY && self.is_human(p) {
            let mut c = self.e.clone();
            self.hint = c.bot_card(p) as i32;
        }
    }

    pub fn toggle_help(&mut self) {
        self.help = !self.help;
        self.update_hint();
        self.save_needed = true;
    }

    /// Conseil d'enchère pour le joueur local.
    pub fn advice_bid(&self) -> String {
        let mut c = self.e.clone();
        match c.bot_bid(self.turn()) {
            -1 => "Conseil : passer".into(),
            s => format!("Conseil : prendre, atout {}", SUIT_NAMES[s as usize]),
        }
    }

    /// Message du bas de l'écran.
    pub fn message(&self) -> String {
        let human = self.is_human(self.turn());
        match self.phase() {
            PH_BID1 | PH_BID2 if human && self.help => self.advice_bid(),
            PH_BID1 if human => "Prendre la carte retournée comme atout, ou passer ?".into(),
            PH_BID2 if human => "Choisis une autre couleur d'atout, ou passe.".into(),
            PH_PLAY if human && self.e.gs.tn == 0 => "Tu ouvres : joue la carte de ton choix.".into(),
            PH_PLAY if human => "À toi de jouer : clique sur une carte.".into(),
            PH_ROUNDEND | PH_MATCHEND if self.nextmask >> self.me & 1 == 1 => "En attente des autres joueurs...".into(),
            PH_ROUNDEND | PH_MATCHEND => "Espace : suite".into(),
            _ => "Les autres réfléchissent...".into(),
        }
    }

    /// Cartes jouables du joueur local (toutes si ce n'est pas à lui de jouer).
    pub fn my_legal(&self) -> u32 {
        if self.phase() == PH_PLAY && self.turn() == self.me {
            self.e.legal_mask(self.me)
        } else {
            u32::MAX
        }
    }

    // ---------- réglages ----------
    pub fn toggle_np(&mut self) {
        if self.online {
            return;
        }
        self.e.np = 6 - self.e.np;
        self.new_match();
        self.save_needed = true;
    }

    pub fn cycle_level(&mut self) {
        if self.online {
            return;
        }
        self.botlvl = (self.botlvl + 1) % 3;
        self.set_levels();
        self.save_needed = true;
    }

    pub fn toggle_annonces(&mut self) {
        if self.online {
            return;
        }
        self.e.optann ^= 1;
        self.save_needed = true;
    }

    pub fn cycle_target(&mut self) {
        if self.online {
            return;
        }
        self.e.target = match self.e.target {
            501 => 1000,
            1000 => 1500,
            _ => 501,
        };
        self.save_needed = true;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Joue tout seul (mode U) jusqu'à la fin de plusieurs parties.
    #[test]
    fn parties_automatiques() {
        for np in [4, 2] {
            let mut t = Table::new(12345 + np);
            t.e.np = np as i32;
            t.e.target = 501;
            t.new_match();
            t.auto = true;
            let mut matches = 0;
            for _ in 0..200_000 {
                let before = t.phase();
                t.tick(50.0);
                if before == PH_MATCHEND && t.phase() != PH_MATCHEND {
                    matches += 1;
                    if matches == 3 {
                        break;
                    }
                }
            }
            assert_eq!(matches, 3, "np={np} : parties non terminées");
        }
    }

    /// Plusieurs machines en lockstep, à des vitesses différentes : les parties restent identiques.
    #[test]
    fn lockstep_quatre_machines() {
        for np in [4usize, 2] {
            let seed = 0x1234_5678_9ABC_DEF1;
            let n = np; // 4 humains (4 joueurs) ou 2 humains (belote à deux)
            let humans = (1u32 << n) - 1;
            let mut ts: Vec<Table> = (0..n).map(|k| Table::new(k as u64 + 7)).collect();
            for (k, t) in ts.iter_mut().enumerate() {
                t.e.np = np as i32;
                let cfg = t.net_config(humans);
                t.net_begin(k, cfg, 501, seed);
                t.auto = true;
            }
            let speeds = [50.0, 31.0, 77.0, 43.0];
            // scores et graine à chaque fin de manche, pour chaque machine
            let mut hist: Vec<Vec<([i32; 2], u64)>> = vec![Vec::new(); n];
            let mut was_end = [false; 4];
            for _ in 0..200_000 {
                for k in 0..n {
                    ts[k].tick(speeds[k]);
                    let end = ts[k].phase() == PH_ROUNDEND || ts[k].phase() == PH_MATCHEND;
                    if end && !was_end[k] {
                        hist[k].push((ts[k].e.score, ts[k].e.rng));
                    }
                    was_end[k] = end;
                    let out: Vec<Frame> = ts[k].outbox.drain(..).collect();
                    for f in out {
                        for j in 0..n {
                            if j != k {
                                ts[j].inbox.push_back(f);
                            }
                        }
                    }
                }
                if hist.iter().all(|h| h.len() >= 8) {
                    break;
                }
            }
            assert!(hist.iter().all(|h| h.len() >= 8), "np={np} : manches jouées {:?}", hist.iter().map(|h| h.len()).collect::<Vec<_>>());
            for h in &hist {
                assert_eq!(h[..8], hist[0][..8], "np={np} : machines désynchronisées");
            }
        }
    }
}
