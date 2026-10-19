//! Dessin des cartes, design « bistrot classique » : face ivoire, double filet, indices en serif aux coins,
//! points disposés comme sur un vrai jeu, figures dans un cadre avec couronnes ; dos bordeaux à losanges
//! dorés et médaillon. Chaque carte est dessinée une fois dans une texture (anticrénelée), puis posée
//! avec n'importe quelle rotation ou perspective. Repère canonique : 100 x 140 centré sur l'origine.

use crate::gfx::{rgb, Align, Face, FontFile, Gfx, Xf};
use macroquad::prelude::*;

const C_IVORY: Color = rgb(250, 247, 238);
const C_SHADOW: Color = rgb(8, 52, 36);
const C_CRED: Color = rgb(194, 38, 46);
const C_CBLK: Color = rgb(27, 27, 34);
const C_TRED: Color = rgb(236, 195, 190);
const C_TBLK: Color = rgb(194, 192, 187);
const C_PANELF: Color = rgb(244, 236, 214);
const C_GOLDF: Color = rgb(217, 178, 106);
const C_GOLDLN: Color = rgb(140, 106, 36);
const C_BORD: Color = rgb(122, 31, 43);
const C_CLN2: Color = rgb(140, 134, 111);

pub const SUIT_GLYPHS: [&str; 4] = ["♠", "♥", "♦", "♣"];
const RANKS: [&str; 8] = ["7", "8", "9", "10", "V", "D", "R", "A"];
const ROI: [(f32, f32); 7] = [(-16., 10.), (-16., -6.), (-8., 2.), (0., -10.), (8., 2.), (16., -6.), (16., 10.)];
const DAME: [(f32, f32); 7] = [(-13., 10.), (-13., -3.), (-6., 3.), (0., -7.), (6., 3.), (13., -3.), (13., 10.)];
const VALET: [(f32, f32); 6] = [(-13., 10.), (-13., 0.), (-6., -6.), (6., -6.), (13., 0.), (13., 10.)];
const PIPS: [&[(f32, f32)]; 4] = [
    &[(-17., -44.), (17., -44.), (-17., 0.), (17., 0.), (-17., 44.), (17., 44.), (0., -22.)],
    &[(-17., -44.), (17., -44.), (-17., 0.), (17., 0.), (-17., 44.), (17., 44.), (0., -22.), (0., 22.)],
    &[(-17., -44.), (17., -44.), (-17., -15.), (17., -15.), (-17., 15.), (17., 15.), (-17., 44.), (17., 44.), (0., 0.)],
    &[
        (-17., -44.),
        (17., -44.),
        (-17., -15.),
        (17., -15.),
        (-17., 15.),
        (17., 15.),
        (-17., 44.),
        (17., 44.),
        (0., -30.),
        (0., 30.),
    ],
];

pub fn is_red(suit: usize) -> bool {
    suit == 1 || suit == 2
}

/// Zone de la texture dans le repère de la carte (avec l'ombre portée).
pub const X0: f32 = -54.0;
pub const Y0: f32 = -74.0;
pub const X1: f32 = 58.0;
pub const Y1: f32 = 78.0;
const TS: f32 = 2.5; // pixels de texture par unité

pub struct CardFonts {
    pub serif: Face,
    pub serif_big: Face,
    pub pip: Face,
    pub big_suit: Face,
    pub suit: Face,
}

impl CardFonts {
    pub fn load(sym: &FontFile, serif: &FontFile) -> CardFonts {
        CardFonts {
            serif: serif.face(25.0),
            serif_big: serif.face(50.0),
            pip: sym.face(22.0),
            big_suit: sym.face(84.0),
            suit: sym.face(34.0),
        }
    }
}

fn draw_face(g: &Gfx, f: &CardFonts, card: usize) {
    let id = Xf::ID;
    let (suit, rank) = (card >> 3, card & 7);
    let (ink, tint) = if is_red(suit) { (C_CRED, C_TRED) } else { (C_CBLK, C_TBLK) };
    g.rrect(&id, -46., -66., 100., 140., 12., Some(C_SHADOW), Some(C_SHADOW));
    g.rrect(&id, -50., -70., 100., 140., 12., Some(C_IVORY), Some(C_CLN2));
    g.rrect(&id, -47., -67., 94., 134., 8., None, Some(tint));
    let glyph = SUIT_GLYPHS[suit];
    g.text(RANKS[rank], -36., -69., &f.serif, ink, Align::Center);
    g.text(glyph, -36., -43., &f.pip, ink, Align::Center);
    g.text(RANKS[rank], 36., 41., &f.serif, ink, Align::Center);
    g.text(glyph, 36., 14., &f.pip, ink, Align::Center);
    match rank {
        7 => g.text(glyph, 0., -64., &f.big_suit, ink, Align::Center),
        4..=6 => {
            g.rrect(&id, -26., -54., 52., 108., 6., Some(C_PANELF), Some(tint));
            let crown: &[(f32, f32)] = match rank {
                6 => &ROI,
                5 => &DAME,
                _ => &VALET,
            };
            let top: Vec<(f32, f32)> = crown.iter().map(|&(x, y)| (x, y - 40.)).collect();
            let bottom: Vec<(f32, f32)> = crown.iter().map(|&(x, y)| (x, 40. - y)).collect();
            g.poly_any(&id, &top, C_GOLDF, Some(C_GOLDLN));
            g.poly_any(&id, &bottom, C_GOLDF, Some(C_GOLDLN));
            if rank == 5 {
                g.ellipse(&id, 0., -50., 3., 3., Some(C_GOLDF), Some(C_GOLDLN));
                g.ellipse(&id, 0., 50., 3., 3., Some(C_GOLDF), Some(C_GOLDLN));
            }
            g.text(RANKS[rank], 0., -38., &f.serif_big, ink, Align::Center);
            g.text(glyph, 0., 2., &f.pip, ink, Align::Center);
        }
        _ => {
            for &(x, y) in PIPS[rank] {
                g.text(glyph, x, y - 17., &f.pip, ink, Align::Center);
            }
        }
    }
}

fn draw_back(g: &Gfx, f: &CardFonts) {
    let id = Xf::ID;
    g.rrect(&id, -46., -66., 100., 140., 12., Some(C_SHADOW), Some(C_SHADOW));
    g.rrect(&id, -50., -70., 100., 140., 12., Some(C_IVORY), Some(C_CLN2));
    g.rrect(&id, -44., -64., 88., 128., 7., Some(C_BORD), Some(C_BORD));
    // losanges dorés : droites à 45 degrés recoupées au cadre
    let mut c = -190;
    while c <= 190 {
        let x0 = (-39).max(c - 59) as f32;
        let x1 = 39.min(c + 59) as f32;
        if x0 < x1 {
            let cf = c as f32;
            g.line(&id, x0, x0 - cf, x1, x1 - cf, 0.7, C_GOLDF);
            g.line(&id, -x0, x0 - cf, -x1, x1 - cf, 0.7, C_GOLDF);
        }
        c += 16;
    }
    g.rrect(&id, -44., -64., 88., 128., 7., None, Some(C_IVORY));
    g.rrect(&id, -39., -59., 78., 118., 4., None, Some(C_GOLDF));
    g.ellipse(&id, 0., 0., 22., 31., Some(C_BORD), Some(C_GOLDF));
    g.ellipse(&id, 0., 0., 15., 23., None, Some(C_GOLDF));
    g.text(SUIT_GLYPHS[1], 0., -17., &f.suit, C_GOLDF, Align::Center);
}

/// Les 32 faces et le dos, dessinés dans des textures.
pub struct Deck {
    faces: Vec<Texture2D>,
    back: Texture2D,
    /// les cibles de rendu doivent vivre tant que le dessin n'est pas exécuté (fin de l'image)
    _targets: Vec<RenderTarget>,
    /// les textures rendues sont à l'envers selon la plateforme graphique
    flip: bool,
}

fn render(f: &CardFonts, card: Option<usize>) -> RenderTarget {
    let (w, h) = (((X1 - X0) * TS) as u32, ((Y1 - Y0) * TS) as u32);
    let rt = render_target_msaa(w, h);
    rt.texture.set_filter(FilterMode::Linear);
    let mut cam = Camera2D::from_display_rect(Rect::new(0., 0., w as f32, h as f32));
    cam.render_target = Some(rt.clone());
    set_camera(&cam);
    clear_background(Color::new(C_SHADOW.r, C_SHADOW.g, C_SHADOW.b, 0.0));
    let g = Gfx { sc: TS, ox: -X0 * TS, oy: -Y0 * TS };
    match card {
        Some(c) => draw_face(&g, f, c),
        None => draw_back(&g, f),
    }
    set_default_camera();
    rt
}

impl Deck {
    pub fn new(f: &CardFonts) -> Deck {
        let mut targets: Vec<RenderTarget> = (0..32).map(|c| render(f, Some(c))).collect();
        targets.push(render(f, None));
        let faces = targets[..32].iter().map(|rt| rt.texture.clone()).collect();
        let back = targets[32].texture.clone();
        Deck { faces, back, _targets: targets, flip: true }
    }

    /// Pose une carte (None = dos) avec la transformation xf ; dim = carte grisée (injouable).
    pub fn draw(&self, g: &Gfx, xf: &Xf, card: Option<usize>, dim: bool) {
        let tex = match card {
            Some(c) => &self.faces[c],
            None => &self.back,
        };
        let tint = if dim { Color::new(0.72, 0.72, 0.70, 1.0) } else { WHITE };
        g.quad(xf, tex, X0, Y0, X1, Y1, tint, self.flip);
    }
}
