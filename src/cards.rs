//! Dessin des cartes, design « bistrot classique » : face ivoire, double filet, indices en serif aux coins,
//! points disposés comme sur un vrai jeu, figures dans un cadre avec couronnes ; dos bordeaux à losanges
//! dorés et médaillon. Chaque carte est dessinée une fois dans une petite image (à la taille de l'écran),
//! puis posée avec n'importe quelle rotation ou perspective. Repère canonique : 100 x 140 centré sur l'origine.

use crate::gfx::{rgb, Align, Color, Face, FontFile, Gfx, Glyphs, Xf};
use std::cell::RefCell;
use tiny_skia::Pixmap;

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

/// Zone de l'image dans le repère de la carte (avec l'ombre portée).
pub const X0: f32 = -54.0;
pub const Y0: f32 = -74.0;
pub const X1: f32 = 58.0;
pub const Y1: f32 = 78.0;

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

/// Les 32 faces et le dos, dessinés dans des images à la taille de l'écran.
pub struct Deck {
    faces: Vec<Pixmap>,
    back: Pixmap,
    /// pixels d'image par unité de la carte
    ppu: f32,
}

fn render(f: &CardFonts, glyphs: &RefCell<Glyphs>, card: Option<usize>, ppu: f32) -> Pixmap {
    let (w, h) = (((X1 - X0) * ppu).ceil() as u32, ((Y1 - Y0) * ppu).ceil() as u32);
    let mut pm = Pixmap::new(w.max(1), h.max(1)).unwrap();
    let g = Gfx::new(&mut pm, glyphs, ppu, -X0 * ppu, -Y0 * ppu);
    match card {
        Some(c) => draw_face(&g, f, c),
        None => draw_back(&g, f),
    }
    drop(g);
    pm
}

impl Deck {
    /// `ppu` : pixels par unité (échelle de la fenêtre) ; les cartes de la main sont posées environ 1:1.
    pub fn new(f: &CardFonts, glyphs: &RefCell<Glyphs>, ppu: f32) -> Deck {
        let faces = (0..32).map(|c| render(f, glyphs, Some(c), ppu)).collect();
        let back = render(f, glyphs, None, ppu);
        Deck { faces, back, ppu }
    }

    pub fn ppu(&self) -> f32 {
        self.ppu
    }

    /// Pose une carte (None = dos) avec la transformation xf ; dim = carte grisée (injouable).
    pub fn draw(&self, g: &Gfx, xf: &Xf, card: Option<usize>, dim: bool) {
        let img = match card {
            Some(c) => &self.faces[c],
            None => &self.back,
        };
        g.image(xf, img, X0, Y0, self.ppu);
        if dim {
            g.rrect(xf, -50., -70., 100., 140., 12., Some(Color::new(0.0, 0.0, 0.0, 0.26)), None);
        }
    }
}
