//! Belote en 3D isométrique : contre des bots, belote à deux, ou en ligne de 2 à 4 humains.
//! Fenêtre portable (macroquad : Windows, Linux, macOS) ; `belote -sim ...` = banc d'essai sans fenêtre.

#![windows_subsystem = "windows"]

mod cards;
mod cfg;
mod draw;
mod engine;
mod gfx;
mod net;
mod table;

use draw::{BtnId, Fonts, Overlay};
use engine::*;
use gfx::{Gfx, WH, WW};
use macroquad::prelude::*;
use net::{Menu, Net};
use table::Table;

#[cfg(windows)]
mod win {
    use std::ffi::c_void;
    #[repr(C)]
    #[derive(Default)]
    pub struct Rect {
        pub l: i32,
        pub t: i32,
        pub r: i32,
        pub b: i32,
    }
    #[link(name = "user32")]
    extern "system" {
        pub fn SetProcessDPIAware() -> i32;
        pub fn SystemParametersInfoW(action: u32, p1: u32, p2: *mut c_void, p3: u32) -> i32;
    }

    /// Zone de travail de l'écran (sans la barre des tâches), en pixels réels.
    pub fn work_area() -> (i32, i32) {
        let mut r = Rect::default();
        unsafe {
            SetProcessDPIAware();
            if SystemParametersInfoW(0x30, 0, &mut r as *mut Rect as *mut c_void, 0) == 0 {
                return (1920, 1040);
            }
        }
        (r.r - r.l, r.b - r.t)
    }
}

fn seed() -> u64 {
    let t = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default();
    (t.as_nanos() as u64) ^ 0x2545F4914F6CDD1D ^ (std::process::id() as u64) << 32
}

fn window_conf() -> Conf {
    // 1100 x 800 si l'écran le permet, sinon réduite pour tenir dans la zone de travail
    #[cfg(windows)]
    let (aw, ah) = win::work_area();
    #[cfg(not(windows))]
    let (aw, ah) = (1100 + 16, 800 + 40);
    let k = 1f32.min((aw - 16) as f32 / WW).min((ah - 40) as f32 / WH);
    Conf {
        window_title: "Belote - jeu du bistro en 3D isométrique".into(),
        window_width: (WW * k) as i32,
        window_height: (WH * k) as i32,
        window_resizable: true,
        sample_count: 4,
        ..Default::default()
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if let Some(i) = args.iter().position(|a| a == "-sim") {
        engine::sim_main(&args[i + 1..]);
        return;
    }
    macroquad::Window::from_config(window_conf(), run());
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

async fn run() {
    let fonts = Fonts::load();
    let deck = cards::Deck::new(&fonts.cards);
    let mut t = Table::new(seed());
    let mut c = cfg::load(&mut t);
    t.new_match();
    let mut net = Net::new(c.ip.clone());
    let mut fullscreen = c.fullscreen;
    if fullscreen {
        set_fullscreen(true);
    }
    let mut gallery = false;
    let mut last = get_time();
    loop {
        let g = Gfx::fit();
        let mouse = g.to_logical(mouse_position().into());
        let mut save = false;

        // ---------- clavier ----------
        let mut chars: Vec<char> = Vec::new();
        while let Some(ch) = get_char_pressed() {
            chars.push(ch);
        }
        let any_key = !chars.is_empty() || get_last_key_pressed().is_some();
        match net.menu {
            Menu::Info => {
                if any_key {
                    net.menu = Menu::None;
                }
            }
            Menu::Ip => {
                if is_key_pressed(KeyCode::Escape) {
                    chars = vec!['\u{1b}'];
                } else if is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::KpEnter) {
                    chars = vec!['\r'];
                } else if is_key_pressed(KeyCode::Backspace) {
                    chars = vec!['\u{8}'];
                }
                for ch in chars {
                    if net.ip_char(ch) {
                        c.ip = net.ip.clone();
                        save = true;
                    }
                }
            }
            Menu::Choice => {
                if let Some(&ch) = chars.first() {
                    net.menu_key(&mut t, ch);
                } else if is_key_pressed(KeyCode::Escape) {
                    net.menu_key(&mut t, '\u{1b}');
                }
            }
            Menu::None => {
                if is_key_pressed(KeyCode::Escape) {
                    if net.waiting() {
                        net.cancel(&mut t);
                    } else if gallery {
                        gallery = false;
                    } else if fullscreen {
                        fullscreen = false;
                        set_fullscreen(false);
                        c.fullscreen = false;
                        save = true;
                    } else {
                        break;
                    }
                }
                if is_key_pressed(KeyCode::F11) {
                    fullscreen = !fullscreen;
                    set_fullscreen(fullscreen);
                    c.fullscreen = fullscreen;
                    save = true;
                }
                if is_key_pressed(KeyCode::Space) || is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::KpEnter) {
                    if net.hosting() {
                        net.host_start(&mut t);
                    } else {
                        btn_action(&mut t, BtnId::Next);
                    }
                }
                if !net.waiting() {
                    for ch in chars {
                        match ch.to_ascii_uppercase() {
                            'J' => t.toggle_np(),
                            'L' => t.cycle_level(),
                            'A' => t.toggle_annonces(),
                            'H' => t.toggle_help(),
                            'P' => t.cycle_target(),
                            'U' => t.auto = !t.auto,
                            'G' => gallery = !gallery,
                            'N' => net.open(&mut t),
                            _ => {}
                        }
                    }
                }
            }
        }

        // ---------- souris ----------
        let mut hover = draw::hand_hit(&t, mouse.0, mouse.1);
        if is_mouse_button_pressed(MouseButton::Left) && net.menu == Menu::None && !net.waiting() && !gallery {
            let btn = draw::buttons(&t).into_iter().find(|b| b.hit(mouse.0, mouse.1));
            if let Some(b) = btn {
                btn_action(&mut t, b.id);
            } else if t.phase() == PH_PLAY && t.is_human(t.turn()) {
                if let Some(i) = hover {
                    if t.e.legal_mask(t.me) >> i & 1 == 1 {
                        t.human_play(i);
                        hover = None;
                    }
                }
            }
        }

        // ---------- temps, réseau, image ----------
        let now = get_time();
        t.tick(((now - last) * 1000.0).min(100.0));
        last = now;
        net.poll(&mut t);
        if save || t.save_needed {
            t.save_needed = false;
            cfg::save(&t, &c);
        }
        let ov = Overlay { gallery, hover, mouse, net: net.panel(), optline: draw::optline(&t) };
        draw::draw(&t, g, &fonts, &deck, &ov);
        if is_key_pressed(KeyCode::F12) {
            // capture : image opaque (les éléments translucides laissent un alpha < 1 dans le tampon)
            let mut img = get_screen_data();
            img.bytes.chunks_mut(4).for_each(|p| p[3] = 255);
            img.export_png("belote_shot.png");
        }
        next_frame().await;
    }
}
