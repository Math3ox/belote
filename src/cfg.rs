//! Réglages mémorisés dans `belote.cfg` à côté de l'exécutable (texte « clé = valeur »).
//! Supprimer le fichier remet les valeurs par défaut ; un champ invalide est ignoré.

use crate::table::Table;
use std::path::PathBuf;

#[derive(Default)]
pub struct Cfg {
    pub fullscreen: bool,
    pub ip: String,
}

fn path() -> Option<PathBuf> {
    std::env::current_exe().ok().map(|p| p.with_file_name("belote.cfg"))
}

/// Lit les réglages (avant la première partie).
pub fn load(t: &mut Table) -> Cfg {
    let mut c = Cfg::default();
    let Some(text) = path().and_then(|p| std::fs::read_to_string(p).ok()) else { return c };
    for line in text.lines() {
        let Some((k, v)) = line.split_once('=') else { continue };
        let v = v.trim();
        let n = v.parse::<i32>().ok();
        match (k.trim(), n) {
            ("joueurs", Some(np @ (2 | 4))) => t.e.np = np,
            ("objectif", Some(o @ 100..=10000)) => t.e.target = o,
            ("annonces", Some(a @ 0..=1)) => t.e.optann = a,
            ("niveau", Some(l @ 0..=2)) => t.botlvl = l,
            ("plein_ecran", Some(f @ 0..=1)) => c.fullscreen = f == 1,
            ("aide", Some(h @ 0..=1)) => t.help = h == 1,
            ("victoires", Some(w @ 0..=999999)) => t.wins[0] = w as u32,
            ("defaites", Some(l @ 0..=999999)) => t.wins[1] = l as u32,
            ("ip", _) if v.len() <= 21 && v.chars().all(|c| c.is_ascii_digit() || c == '.' || c == ':') => {
                c.ip = v.into()
            }
            _ => {}
        }
    }
    c
}

/// Écrit les réglages (silencieux si le dossier n'est pas inscriptible). Une partie en ligne impose les
/// réglages de l'hôte : ils ne sont pas mémorisés.
pub fn save(t: &Table, c: &Cfg) {
    if t.online {
        return;
    }
    let text = format!(
        "# réglages de la belote (supprimer ce fichier remet les valeurs par défaut)\n\
         joueurs = {}\nobjectif = {}\nannonces = {}\nniveau = {}\nplein_ecran = {}\naide = {}\n\
         victoires = {}\ndefaites = {}\nip = {}\n",
        t.e.np, t.e.target, t.e.optann, t.botlvl, c.fullscreen as u8, t.help as u8, t.wins[0], t.wins[1], c.ip
    );
    if let Some(p) = path() {
        let _ = std::fs::write(p, text);
    }
}
