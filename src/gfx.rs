//! Primitives de dessin en coordonnées logiques 1100 x 800 : formes pleines avec contour, transformation
//! affine (cartes posées, tournées, écrasées par la perspective), textes alignés comme sous GDI
//! (haut du texte = haut de la cellule de la police), polices et mise à l'échelle de la fenêtre.

use macroquad::prelude::*;

pub const WW: f32 = 1100.0;
pub const WH: f32 = 800.0;

pub const fn rgb(r: u8, g: u8, b: u8) -> Color {
    Color::new(r as f32 / 255.0, g as f32 / 255.0, b as f32 / 255.0, 1.0)
}

/// Transformation affine : (x, y) -> (a x + c y + tx, b x + d y + ty).
#[derive(Clone, Copy)]
pub struct Xf {
    pub a: f32,
    pub b: f32,
    pub c: f32,
    pub d: f32,
    pub tx: f32,
    pub ty: f32,
}

impl Xf {
    pub const ID: Xf = Xf { a: 1.0, b: 0.0, c: 0.0, d: 1.0, tx: 0.0, ty: 0.0 };

    /// Objet centré en (cx, cy), agrandi de `scale`, tourné de `angle`, puis écrasé verticalement de `sq`.
    pub fn place(cx: f64, cy: f64, scale: f64, angle: f64, sq: f64) -> Xf {
        let (s, c) = angle.sin_cos();
        Xf {
            a: (scale * c) as f32,
            b: (scale * s * sq) as f32,
            c: (-scale * s) as f32,
            d: (scale * c * sq) as f32,
            tx: cx as f32,
            ty: cy as f32,
        }
    }

    pub fn apply(&self, x: f32, y: f32) -> (f32, f32) {
        (self.a * x + self.c * y + self.tx, self.b * x + self.d * y + self.ty)
    }

    fn scale(&self) -> f32 {
        (self.a * self.d - self.b * self.c).abs().sqrt()
    }
}

/// Une police à une taille donnée (taille = hauteur du cadratin, comme une hauteur négative sous GDI).
#[derive(Clone)]
pub struct Face {
    pub font: Option<Font>,
    pub size: f32,
    /// hauteur au-dessus de la ligne de base, en fraction de la taille (usWinAscent / unitsPerEm)
    pub asc: f32,
}

/// Lit usWinAscent / unitsPerEm dans les tables OS/2 et head d'une police TrueType.
fn win_ascent(b: &[u8]) -> Option<f32> {
    let u16at = |o: usize| b.get(o..o + 2).map(|s| u16::from_be_bytes([s[0], s[1]]));
    let u32at = |o: usize| b.get(o..o + 4).map(|s| u32::from_be_bytes([s[0], s[1], s[2], s[3]]));
    let n = u16at(4)? as usize;
    let (mut os2, mut head) = (None, None);
    for i in 0..n {
        let r = 12 + i * 16;
        let off = u32at(r + 8)? as usize;
        match b.get(r..r + 4)? {
            b"OS/2" => os2 = Some(off),
            b"head" => head = Some(off),
            _ => {}
        }
    }
    let upem = u16at(head? + 18)? as f32;
    let asc = u16at(os2? + 74)? as f32;
    (upem > 0.0).then(|| asc / upem)
}

pub struct FontFile {
    font: Option<Font>,
    asc: f32,
}

impl FontFile {
    pub fn load(paths: &[&str]) -> FontFile {
        for p in paths {
            if let Ok(bytes) = std::fs::read(p) {
                if let Ok(font) = load_ttf_font_from_bytes(&bytes) {
                    return FontFile { font: Some(font), asc: win_ascent(&bytes).unwrap_or(0.95) };
                }
            }
        }
        FontFile { font: None, asc: 0.8 }
    }

    pub fn face(&self, size: f32) -> Face {
        Face { font: self.font.clone(), size, asc: self.asc }
    }
}

/// Alignement horizontal du texte (le point donné est toujours le haut du texte).
#[derive(Clone, Copy)]
pub enum Align {
    Left,
    Center,
    Right,
}

/// Peintre : passage des coordonnées logiques aux pixels de la cible (fenêtre ou texture).
#[derive(Clone, Copy)]
pub struct Gfx {
    pub sc: f32,
    pub ox: f32,
    pub oy: f32,
}

impl Gfx {
    /// Fenêtre : le jeu 1100 x 800 mis à l'échelle, proportions gardées, centré.
    pub fn fit() -> Gfx {
        let (w, h) = (screen_width(), screen_height());
        let sc = (w / WW).min(h / WH);
        Gfx { sc, ox: ((w - WW * sc) / 2.0).floor(), oy: ((h - WH * sc) / 2.0).floor() }
    }

    pub fn px(&self, x: f32, y: f32) -> Vec2 {
        vec2(self.ox + x * self.sc, self.oy + y * self.sc)
    }

    /// Pixels de la fenêtre -> coordonnées logiques.
    pub fn to_logical(&self, p: Vec2) -> (f32, f32) {
        ((p.x - self.ox) / self.sc, (p.y - self.oy) / self.sc)
    }

    /// Polygone convexe plein et/ou contour.
    pub fn poly(&self, xf: &Xf, pts: &[(f32, f32)], fill: Option<Color>, line: Option<Color>) {
        let p: Vec<Vec2> = pts
            .iter()
            .map(|&(x, y)| {
                let (x, y) = xf.apply(x, y);
                self.px(x, y)
            })
            .collect();
        if let Some(c) = fill {
            for i in 1..p.len().saturating_sub(1) {
                draw_triangle(p[0], p[i], p[i + 1], c);
            }
        }
        if let Some(c) = line {
            let w = (0.6 * self.sc * xf.scale()).max(0.8);
            for i in 0..p.len() {
                let (a, b) = (p[i], p[(i + 1) % p.len()]);
                draw_line(a.x, a.y, b.x, b.y, w, c);
            }
        }
    }

    /// Polygone quelconque (non convexe) plein, triangulé par « oreilles », avec contour.
    pub fn poly_any(&self, xf: &Xf, pts: &[(f32, f32)], fill: Color, line: Option<Color>) {
        let p: Vec<Vec2> = pts
            .iter()
            .map(|&(x, y)| {
                let (x, y) = xf.apply(x, y);
                self.px(x, y)
            })
            .collect();
        let area: f32 = (0..p.len()).map(|i| p[i].perp_dot(p[(i + 1) % p.len()])).sum();
        let mut idx: Vec<usize> = (0..p.len()).collect();
        if area < 0.0 {
            idx.reverse();
        }
        let inside = |q: Vec2, a: Vec2, b: Vec2, c: Vec2| {
            (b - a).perp_dot(q - a) > 0.0 && (c - b).perp_dot(q - b) > 0.0 && (a - c).perp_dot(q - c) > 0.0
        };
        let mut guard = 0;
        while idx.len() > 3 && guard < 200 {
            guard += 1;
            let n = idx.len();
            for i in 0..n {
                let (a, b, c) = (p[idx[(i + n - 1) % n]], p[idx[i]], p[idx[(i + 1) % n]]);
                if (b - a).perp_dot(c - b) <= 0.0 {
                    continue; // sommet rentrant
                }
                if idx.iter().any(|&k| inside(p[k], a, b, c)) {
                    continue;
                }
                draw_triangle(a, b, c, fill);
                idx.remove(i);
                break;
            }
        }
        if idx.len() == 3 {
            draw_triangle(p[idx[0]], p[idx[1]], p[idx[2]], fill);
        }
        if line.is_some() {
            self.poly(xf, pts, None, line);
        }
    }

    pub fn rrect(&self, xf: &Xf, x: f32, y: f32, w: f32, h: f32, r: f32, fill: Option<Color>, line: Option<Color>) {
        let r = r.min(w / 2.0).min(h / 2.0);
        let mut pts = Vec::with_capacity(40);
        let corners = [(x + w - r, y + r, -90.0f32), (x + w - r, y + h - r, 0.0), (x + r, y + h - r, 90.0), (x + r, y + r, 180.0)];
        for (cx, cy, a0) in corners {
            for k in 0..=8 {
                let a = (a0 + k as f32 * 11.25).to_radians();
                pts.push((cx + r * a.cos(), cy + r * a.sin()));
            }
        }
        self.poly(xf, &pts, fill, line);
    }

    pub fn ellipse(&self, xf: &Xf, cx: f32, cy: f32, rx: f32, ry: f32, fill: Option<Color>, line: Option<Color>) {
        let pts: Vec<(f32, f32)> = (0..64)
            .map(|i| {
                let t = i as f32 * std::f32::consts::TAU / 64.0;
                (cx + rx * t.cos(), cy + ry * t.sin())
            })
            .collect();
        self.poly(xf, &pts, fill, line);
    }

    pub fn line(&self, xf: &Xf, x0: f32, y0: f32, x1: f32, y1: f32, w: f32, c: Color) {
        let (a, b) = (xf.apply(x0, y0), xf.apply(x1, y1));
        let (a, b) = (self.px(a.0, a.1), self.px(b.0, b.1));
        draw_line(a.x, a.y, b.x, b.y, w * self.sc * xf.scale(), c);
    }

    /// Texte dont le haut est en y (comme TA_TOP sous GDI).
    pub fn text(&self, s: &str, x: f32, y: f32, f: &Face, c: Color, al: Align) {
        if s.is_empty() {
            return;
        }
        let px = (f.size * self.sc).round().max(1.0) as u16;
        let w = measure_text(s, f.font.as_ref(), px, 1.0).width;
        let p = self.px(x, y);
        let x0 = match al {
            Align::Left => p.x,
            Align::Center => p.x - w / 2.0,
            Align::Right => p.x - w,
        };
        draw_text_ex(
            s,
            x0.round(),
            (p.y + f.asc * px as f32).round(),
            TextParams { font: f.font.as_ref(), font_size: px, color: c, ..Default::default() },
        );
    }

    /// Texture plaquée sur un quadrilatère : rectangle (x0, y0)-(x1, y1) de l'espace local transformé par xf.
    pub fn quad(&self, xf: &Xf, tex: &Texture2D, x0: f32, y0: f32, x1: f32, y1: f32, tint: Color, flip_v: bool) {
        let corners = [(x0, y0, 0.0, 0.0), (x1, y0, 1.0, 0.0), (x1, y1, 1.0, 1.0), (x0, y1, 0.0, 1.0)];
        let vertices = corners
            .iter()
            .map(|&(x, y, u, v)| {
                let (x, y) = xf.apply(x, y);
                let p = self.px(x, y);
                Vertex::new(p.x, p.y, 0.0, u, if flip_v { 1.0 - v } else { v }, tint)
            })
            .collect();
        draw_mesh(&Mesh { vertices, indices: vec![0, 1, 2, 0, 2, 3], texture: Some(tex.clone()) });
    }
}
