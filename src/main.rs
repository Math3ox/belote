//! Belote en 3D isométrique : contre des bots, belote à deux, ou en ligne de 2 à 4 humains.
//! Dessin 100 % processeur (aucune carte graphique), Windows / Linux / macOS ;
//! `belote -sim ...` = banc d'essai sans fenêtre.

#![windows_subsystem = "windows"]

mod cards;
mod cfg;
mod draw;
mod engine;
mod gfx;
mod net;
mod shell;
mod table;

use draw::{BtnId, Fonts, Overlay};
use engine::*;
use gfx::Gfx;
use net::{Menu, Net};
use shell::Key;
use std::hash::{Hash, Hasher};
use table::Table;

fn seed() -> u64 {
    let t = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    (t.as_nanos() as u64) ^ 0x2545F4914F6CDD1D ^ (std::process::id() as u64) << 32
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if let Some(i) = args.iter().position(|a| a == "-sim") {
        engine::sim_main(&args[i + 1..]);
        return;
    }
    let mut t = Table::new(seed());
    let c = cfg::load(&mut t);
    t.new_match();
    let net = Net::new(c.ip.clone());
    let fullscreen = c.fullscreen;
    shell::run(Belote {
        fonts: Fonts::load(),
        deck: None,
        t,
        c,
        net,
        fullscreen,
        quit: false,
        gallery: false,
        strength: false,
        hover: None,
        mouse: (0.0, 0.0),
        sig: 0,
        under: None,
    });
}

struct Belote {
    fonts: Fonts,
    /// cartes dessinées à l'échelle de la fenêtre (refaites quand la taille change)
    deck: Option<cards::Deck>,
    t: Table,
    c: cfg::Cfg,
    net: Net,
    fullscreen: bool,
    quit: bool,
    gallery: bool,
    strength: bool,
    hover: Option<usize>,
    mouse: (f32, f32),
    /// empreinte de ce qui est affiché : on ne redessine que si elle change
    sig: u64,
    /// couche fixe (décor + talon, étiquettes, mains adverses) et son empreinte
    under: Option<(u64, tiny_skia::Pixmap)>,
}

fn btn_action(t: &mut Table, id: BtnId) {
    match id {
        BtnId::Next => {
            if matches!(t.phase(), PH_ROUNDEND | PH_MATCHEND) {
                t.human_next();
            }
        }
        BtnId::Pass => t.human_bid(-1),
        BtnId::Take => t.human_bid(t.e.gs.turned >> 3),
        BtnId::Suit(k) => t.human_bid(k as i32),
    }
}

impl Belote {
    fn save(&mut self) {
        self.t.save_needed = false;
        cfg::save(&self.t, &self.c);
    }

    /// Empreinte de l'état affiché.
    fn signature(&self) -> u64 {
        let t = &self.t;
        let gs = &t.e.gs;
        let mut h = std::collections::hash_map::DefaultHasher::new();
        (gs.phase, gs.turn, gs.tn, gs.trickno, gs.hn, gs.tcard, gs.trump, gs.taker, gs.dpos, gs.passes, gs.bidrnd).hash(&mut h);
        (t.e.score, t.e.dealer, t.e.np, t.e.target, t.e.optann, t.hint, t.nextmask, t.wins, t.help, t.botlvl).hash(&mut h);
        for p in 0..4 {
            t.bub[p].as_ref().map(|(s, end)| (s.clone(), *end > t.now)).hash(&mut h);
        }
        (t.message(), self.net.panel().map(|(a, l, m)| (a.to_string(), l.map(|x| x.to_string()), m))).hash(&mut h);
        (self.gallery, self.strength, self.hover, draw::buttons(t).iter().position(|b| b.hit(self.mouse.0, self.mouse.1))).hash(&mut h);
        h.finish()
    }
}

impl shell::Game for Belote {
    fn title(&self) -> String {
        "Belote - jeu du bistro en 3D isométrique".into()
    }

    fn shot_name(&self) -> &str {
        "belote_shot.png"
    }

    fn background(&mut self, g: &Gfx) {
        self.under = None; // décor refait : la couche fixe aussi
        let ppu = (g.sc * 1.04).max(0.5);
        if self.deck.as_ref().map(|d| d.ppu()) != Some(ppu) {
            self.deck = Some(cards::Deck::new(&self.fonts.cards, g.glyphs(), ppu));
        }
        draw::background(g, &self.fonts, self.deck.as_ref().unwrap());
    }

    fn draw(&mut self, g: &Gfx) {
        let Some(deck) = &self.deck else { return };
        if self.gallery {
            draw::gallery(g, &self.fonts, deck);
            return;
        }
        // couche fixe : refaite seulement si son état (ou la taille de la fenêtre) change
        let sig = draw::under_signature(&self.t);
        let size_ok = self.under.as_ref().map(|(_, p)| g.snapshot_size() == (p.width(), p.height())).unwrap_or(false);
        if !size_ok || self.under.as_ref().map(|u| u.0) != Some(sig) {
            let mut layer = g.snapshot();
            draw::draw_under(&self.t, &g.on(&mut layer), &self.fonts, deck);
            self.under = Some((sig, layer));
        }
        if let Some((_, layer)) = &self.under {
            g.restore(layer);
        }
        let ov = Overlay {
            strength: self.strength,
            hover: self.hover,
            mouse: self.mouse,
            net: self.net.panel(),
            optline: draw::optline(&self.t),
        };
        draw::draw_over(&self.t, g, &self.fonts, deck, &ov);
    }

    fn tick(&mut self, dt: f64) -> bool {
        self.t.tick(dt);
        self.net.poll(&mut self.t);
        if self.t.save_needed {
            self.save();
        }
        let sig = self.signature();
        let changed = sig != self.sig || self.animating();
        self.sig = sig;
        changed
    }

    fn animating(&self) -> bool {
        let t = &self.t;
        let last = t.ast0.iter().cloned().fold(f64::MIN, f64::max);
        t.collect > 0.0 || t.now - last < 450.0
    }

    fn key(&mut self, k: Key) {
        let t = &mut self.t;
        let net = &mut self.net;
        match net.menu {
            Menu::Info => net.menu = Menu::None,
            Menu::Ip => {
                let ch = match k {
                    Key::Esc => '\u{1b}',
                    Key::Enter => '\r',
                    Key::Back => '\u{8}',
                    Key::Char(c) => c,
                    _ => return,
                };
                if net.ip_char(ch) {
                    self.c.ip = net.ip.clone();
                    self.save();
                }
            }
            Menu::Choice => match k {
                Key::Char(c) => net.menu_key(t, c),
                Key::Esc => net.menu_key(t, '\u{1b}'),
                _ => {}
            },
            Menu::None => match k {
                Key::Esc => {
                    if net.waiting() {
                        net.cancel(t);
                    } else if self.strength {
                        self.strength = false;
                    } else if self.gallery {
                        self.gallery = false;
                    } else if self.fullscreen {
                        self.fullscreen = false;
                        self.c.fullscreen = false;
                        self.save();
                    } else {
                        self.quit = true;
                    }
                }
                Key::F11 => {
                    self.fullscreen = !self.fullscreen;
                    self.c.fullscreen = self.fullscreen;
                    self.save();
                }
                Key::Space | Key::Enter => {
                    if net.hosting() {
                        net.host_start(t);
                    } else {
                        btn_action(t, BtnId::Next);
                    }
                }
                Key::Char(c) if !net.waiting() => match c.to_ascii_uppercase() {
                    'J' => t.toggle_np(),
                    'L' => t.cycle_level(),
                    'A' => t.toggle_annonces(),
                    'H' => t.toggle_help(),
                    'P' => t.cycle_target(),
                    'U' => t.auto = !t.auto,
                    'G' => self.gallery = !self.gallery,
                    'F' => self.strength = !self.strength,
                    'N' => net.open(t),
                    _ => {}
                },
                _ => {}
            },
        }
        if self.t.save_needed {
            self.save();
        }
    }

    fn click(&mut self, x: f32, y: f32) {
        self.mouse = (x, y);
        let t = &mut self.t;
        if self.strength {
            self.strength = false; // un clic ferme le panneau (sans jouer)
            return;
        }
        if self.net.menu != Menu::None || self.net.waiting() || self.gallery {
            return;
        }
        if let Some(b) = draw::buttons(t).into_iter().find(|b| b.hit(x, y)) {
            btn_action(t, b.id);
        } else if t.phase() == PH_PLAY && t.is_human(t.turn()) {
            if let Some(i) = draw::hand_hit(t, x, y) {
                if t.e.legal_mask(t.me) >> i & 1 == 1 {
                    t.human_play(i);
                }
            }
        }
        self.hover = draw::hand_hit(&self.t, x, y);
    }

    fn hover(&mut self, x: f32, y: f32) -> bool {
        self.mouse = (x, y);
        self.hover = draw::hand_hit(&self.t, x, y);
        let sig = self.signature();
        let changed = sig != self.sig;
        self.sig = sig;
        changed
    }

    fn fullscreen(&self) -> bool {
        self.fullscreen
    }

    fn quit(&self) -> bool {
        self.quit
    }
}

#[cfg(test)]
mod bench {
    use super::*;
    use std::cell::RefCell;
    use std::time::Instant;

    /// Temps de dessin d'une image en pleine partie (cargo test --release -- --ignored mesure_dessin --nocapture).
    #[test]
    #[ignore]
    fn mesure_dessin() {
        let fonts = Fonts::load();
        let glyphs = RefCell::new(gfx::Glyphs::default());
        let mut t = Table::new(5);
        t.auto = true;
        for _ in 0..400 {
            t.tick(50.0);
            if t.e.gs.tn == 3 {
                break;
            }
        }
        let mut bg = tiny_skia::Pixmap::new(1100, 800).unwrap();
        let deck = {
            let g = Gfx::fit(&mut bg, &glyphs);
            let d = cards::Deck::new(&fonts.cards, g.glyphs(), g.sc * 1.04);
            draw::background(&g, &fonts, &d);
            d
        };
        let mut frame = bg.clone();
        let ov = Overlay { strength: false, hover: None, mouse: (0.0, 0.0), net: None, optline: draw::optline(&t) };
        let n = 100;
        let mut tm = [0f64; 5];
        for _ in 0..n {
            let t0 = Instant::now();
            frame.data_mut().copy_from_slice(bg.data());
            let t1 = Instant::now();
            let g = Gfx::fit(&mut frame, &glyphs);
            draw::draw_under(&t, &g, &fonts, &deck);
            let t2 = Instant::now();
            draw::draw_over(&t, &g, &fonts, &deck, &ov);
            let t3 = Instant::now();
            let _ = t.message();
            let mut sum = 0u32;
            for s in frame.pixels() {
                sum = sum.wrapping_add((s.red() as u32) << 16 | (s.green() as u32) << 8 | s.blue() as u32);
            }
            let t4 = Instant::now();
            std::hint::black_box(sum);
            for (k, d) in [t1 - t0, t2 - t1, t3 - t2, t4 - t3].iter().enumerate() {
                tm[k] += d.as_secs_f64() * 1000.0;
            }
        }
        println!("copie decor {:.2} ms | couche fixe {:.2} ms | reste {:.2} ms | conversion {:.2} ms (par image)",
            tm[0] / n as f64, tm[1] / n as f64, tm[2] / n as f64, tm[3] / n as f64);
    }
}
