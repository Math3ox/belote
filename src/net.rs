//! Parties en ligne : 2 à 4 humains, connexion TCP directe par IP, en étoile (l'hôte relaie).
//!
//! Principe « lockstep » : toutes les machines exécutent la même partie (mêmes règles, mêmes bots, même
//! générateur aléatoire dont la graine est envoyée par l'hôte au démarrage). Seules les actions des humains
//! circulent : enchère, carte jouée (position dans la main), « suite ». 12 octets par action.
//! L'hôte est le siège 0. Les invités prennent les sièges 2, 1, 3 (4 joueurs : le 1er invité est le
//! partenaire) ou le siège 1 (belote à deux). Les sièges libres sont tenus par des bots.

use crate::table::{Frame, Table, NT_BID, NT_HELLO, NT_NEXT, NT_START};
use std::io::{ErrorKind, Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream, UdpSocket};
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::time::Duration;

pub const PORT: u16 = 4210;
const SEAT4: [usize; 3] = [2, 1, 3];

pub fn encode(f: &Frame) -> [u8; 12] {
    let mut b = [0u8; 12];
    b[0] = f.kind;
    b[1] = f.b1;
    b[2..4].copy_from_slice(&f.b.to_le_bytes());
    b[4..8].copy_from_slice(&f.c.to_le_bytes());
    b[8..12].copy_from_slice(&f.d.to_le_bytes());
    b
}

pub fn decode(b: &[u8]) -> Frame {
    Frame {
        kind: b[0],
        b1: b[1],
        b: u16::from_le_bytes([b[2], b[3]]),
        c: u32::from_le_bytes([b[4], b[5], b[6], b[7]]),
        d: u32::from_le_bytes([b[8], b[9], b[10], b[11]]),
    }
}

/// « ip » ou « ip:port » -> adresse (port 4210 par défaut).
pub fn parse_addr(s: &str) -> Option<SocketAddr> {
    let (ip, port) = match s.split_once(':') {
        Some((ip, p)) => (ip, p.parse::<u16>().ok().filter(|&p| p != 0)?),
        None => (s, PORT),
    };
    let ip: std::net::Ipv4Addr = ip.parse().ok()?;
    if ip.is_unspecified() {
        return None;
    }
    Some(SocketAddr::from((ip, port)))
}

/// Adresse IP locale principale (celle que les amis du réseau local doivent taper).
fn local_ip() -> String {
    UdpSocket::bind("0.0.0.0:0")
        .and_then(|s| {
            s.connect("192.0.2.1:9")?;
            s.local_addr()
        })
        .map(|a| a.ip().to_string())
        .unwrap_or_else(|_| "?".into())
}

struct Peer {
    s: TcpStream,
    rx: Vec<u8>,
}

impl Peer {
    fn new(s: TcpStream) -> Peer {
        let _ = s.set_nodelay(true);
        let _ = s.set_nonblocking(true);
        Peer { s, rx: Vec::new() }
    }

    fn send(&mut self, f: &Frame) -> bool {
        let buf = encode(f);
        let mut done = 0;
        for _ in 0..1000 {
            match self.s.write(&buf[done..]) {
                Ok(n) => {
                    done += n;
                    if done == buf.len() {
                        return true;
                    }
                }
                Err(e) if e.kind() == ErrorKind::WouldBlock || e.kind() == ErrorKind::Interrupted => {
                    std::thread::sleep(Duration::from_millis(1))
                }
                Err(_) => return false,
            }
        }
        false
    }

    /// Lit ce qui est arrivé ; renvoie les trames complètes, ou None si la connexion est fermée.
    fn recv(&mut self) -> Option<Vec<Frame>> {
        let mut buf = [0u8; 256];
        loop {
            match self.s.read(&mut buf) {
                Ok(0) => return None,
                Ok(n) => self.rx.extend_from_slice(&buf[..n]),
                Err(e) if e.kind() == ErrorKind::WouldBlock => break,
                Err(e) if e.kind() == ErrorKind::Interrupted => {}
                Err(_) => return None,
            }
        }
        let mut out = Vec::new();
        while self.rx.len() >= 12 {
            out.push(decode(&self.rx[..12]));
            self.rx.drain(..12);
        }
        Some(out)
    }
}

enum State {
    Off,
    /// hôte : attente des invités
    Hosting { l: TcpListener, guests: Vec<Peer> },
    Connecting(Receiver<std::io::Result<TcpStream>>),
    /// invité connecté : attente du départ (siège reçu dans HELLO)
    Waiting { host: Peer, seat: usize },
    /// partie en ligne : l'hôte a les invités, l'invité a l'hôte
    Game { peers: Vec<Peer>, host: bool },
}

#[derive(PartialEq, Clone, Copy)]
pub enum Menu {
    None,
    Choice,
    Ip,
    /// message d'information : une touche le ferme
    Info,
}

pub struct Net {
    state: State,
    pub menu: Menu,
    pub ip: String,
    pub lines: [String; 3],
}

impl Net {
    pub fn new(ip: String) -> Net {
        Net { state: State::Off, menu: Menu::None, ip, lines: Default::default() }
    }

    /// Attente en ligne (hôte, connexion, invité en attente) : le panneau est affiché, Échap annule.
    pub fn waiting(&self) -> bool {
        matches!(self.state, State::Hosting { .. } | State::Connecting(_) | State::Waiting { .. })
    }

    pub fn hosting(&self) -> bool {
        matches!(self.state, State::Hosting { .. })
    }

    /// Panneau à afficher : (titre, lignes, mode menu « H / R »).
    pub fn panel(&self) -> Option<(&str, [&str; 3], bool)> {
        if self.menu == Menu::Choice {
            return Some((
                "MULTIJOUEUR EN LIGNE",
                [
                    "H : héberger une partie      R : rejoindre une partie      Echap : annuler",
                    "Tous les joueurs doivent avoir la même version du jeu.",
                    "",
                ],
                true,
            ));
        }
        if self.menu != Menu::None || self.waiting() {
            return Some(("MULTIJOUEUR EN LIGNE", [&self.lines[0], &self.lines[1], &self.lines[2]], false));
        }
        None
    }

    fn say(&mut self, a: &str, b: &str, c: &str) {
        self.lines = [a.into(), b.into(), c.into()];
    }

    /// Touche N : ouvre le menu, ou coupe la connexion en cours.
    pub fn open(&mut self, t: &mut Table) {
        if !matches!(self.state, State::Off) {
            self.close(t, "Connexion perdue : retour à la partie locale.");
            return;
        }
        if self.menu == Menu::None {
            self.menu = Menu::Choice;
            self.say("", "", "");
        }
    }

    /// Touche pendant le menu « H / R » (toute autre touche annule).
    pub fn menu_key(&mut self, t: &mut Table, c: char) {
        match c.to_ascii_uppercase() {
            'H' => {
                self.menu = Menu::None;
                self.host(t);
            }
            'R' => {
                self.menu = Menu::Ip;
                self.prompt();
            }
            _ => self.menu = Menu::None,
        }
    }

    fn prompt(&mut self) {
        let l1 = format!("Adresse IP de l'hôte (Entrée = valider) : {}_", self.ip);
        self.say(&l1, "Exemple : 192.168.1.20   (autre port : 192.168.1.20:4210). Echap : annuler.", "");
    }

    /// Saisie de l'adresse. Renvoie vrai quand l'adresse est validée (à mémoriser).
    pub fn ip_char(&mut self, c: char) -> bool {
        match c {
            '\u{1b}' => self.menu = Menu::None,
            '\r' | '\n' => return self.join(),
            '\u{8}' => {
                self.ip.pop();
                self.prompt();
            }
            '0'..='9' | '.' | ':' if self.ip.len() < 21 => {
                self.ip.push(c);
                self.prompt();
            }
            _ => {}
        }
        false
    }

    fn max_guests(t: &Table) -> usize {
        if t.np() == 4 {
            3
        } else {
            1
        }
    }

    fn host_msg(&mut self, t: &Table, n: usize) {
        self.lines[2] = if t.np() == 2 {
            "Mode à deux : la partie démarre dès qu'un joueur se connecte.".into()
        } else {
            format!("{} joueur(s) connecté(s). Entrée : commencer maintenant (les places libres sont tenues par des bots).", n + 1)
        };
    }

    fn host(&mut self, t: &Table) {
        let l = TcpListener::bind(("0.0.0.0", PORT)).and_then(|l| {
            l.set_nonblocking(true)?;
            Ok(l)
        });
        match l {
            Ok(l) => {
                self.state = State::Hosting { l, guests: Vec::new() };
                let l1 = format!("En attente de joueurs...  Ton adresse IP : {}", local_ip());
                self.say(&l1, "Port 4210 (réseau local, VPN type Tailscale, ou redirection de port). Echap : annuler.", "");
                self.host_msg(t, 0);
            }
            Err(_) => {
                self.say("Impossible d'écouter sur le port 4210 (déjà utilisé ?).", "", "");
                self.menu = Menu::Info;
            }
        }
    }

    fn join(&mut self) -> bool {
        let Some(addr) = parse_addr(&self.ip) else {
            self.prompt();
            self.lines[1] = "Adresse IP invalide. Exemple : 192.168.1.20".into();
            return false;
        };
        self.menu = Menu::None;
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            let _ = tx.send(TcpStream::connect_timeout(&addr, Duration::from_secs(8)));
        });
        self.state = State::Connecting(rx);
        self.say("Connexion en cours... (Echap : annuler)", "", "");
        true
    }

    /// Hôte : lance la partie avec les invités présents (Entrée, ou table complète).
    pub fn host_start(&mut self, t: &mut Table) {
        let State::Hosting { guests, .. } = &mut self.state else { return };
        if guests.is_empty() {
            return;
        }
        let mut humans = 1u32;
        for k in 0..guests.len() {
            humans |= 1 << if t.np() == 4 { SEAT4[k] } else { 1 };
        }
        let cfg = t.net_config(humans);
        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_nanos();
        let seed = (t.e.rng ^ now as u64) | 1;
        let start = Frame { kind: NT_START, b1: cfg, b: t.e.target as u16, c: seed as u32, d: (seed >> 32) as u32 };
        let mut peers = std::mem::take(guests);
        let ok = peers.iter_mut().all(|p| p.send(&start));
        self.state = State::Game { peers, host: true };
        t.net_begin(0, cfg, t.e.target, seed);
        if !ok {
            self.close(t, "Connexion perdue : retour à la partie locale.");
        }
    }

    /// Ferme tout ; une partie en ligne laisse place à une partie locale et à un message.
    pub fn close(&mut self, t: &mut Table, msg: &str) {
        let was_game = matches!(self.state, State::Game { .. });
        self.state = State::Off;
        self.menu = Menu::None;
        if was_game {
            t.leave_online();
            self.say(msg, "", "");
            self.menu = Menu::Info;
        }
    }

    /// Échap pendant une attente.
    pub fn cancel(&mut self, t: &mut Table) {
        self.close(t, "");
        self.menu = Menu::None;
    }

    /// À appeler à chaque image.
    pub fn poll(&mut self, t: &mut Table) {
        const LOST: &str = "Connexion perdue : retour à la partie locale.";
        match &mut self.state {
            State::Off => t.outbox.clear(),
            State::Hosting { l, guests } => {
                if let Ok((s, _)) = l.accept() {
                    if guests.len() >= Self::max_guests(t) {
                        drop(s);
                    } else {
                        let k = guests.len();
                        let seat = if t.np() == 4 { SEAT4[k] } else { 1 };
                        let mut p = Peer::new(s);
                        if p.send(&Frame { kind: NT_HELLO, b1: seat as u8, b: t.np() as u16, c: 0, d: 0 }) {
                            guests.push(p);
                        }
                    }
                    let n = guests.len();
                    let full = n >= Self::max_guests(t);
                    self.host_msg(t, n);
                    if full {
                        self.host_start(t);
                        return;
                    }
                }
                // un invité parti avant le départ : on le retire
                if let State::Hosting { guests, .. } = &mut self.state {
                    let before = guests.len();
                    guests.retain_mut(|p| p.recv().is_some());
                    if guests.len() != before {
                        let n = guests.len();
                        self.host_msg(t, n);
                    }
                }
            }
            State::Connecting(rx) => match rx.try_recv() {
                Ok(Ok(s)) => {
                    self.state = State::Waiting { host: Peer::new(s), seat: 1 };
                    self.say("Connecté ! En attente du départ de la partie par l'hôte...", "", "");
                }
                Ok(Err(_)) | Err(TryRecvError::Disconnected) => {
                    self.state = State::Off;
                    self.say("Connexion impossible (hôte absent ou port fermé).", "", "");
                    self.menu = Menu::Info;
                }
                Err(TryRecvError::Empty) => {}
            },
            State::Waiting { host, seat } => match host.recv() {
                None => {
                    self.state = State::Off;
                    self.say(LOST, "", "");
                    self.menu = Menu::Info;
                }
                Some(frames) => {
                    for f in frames {
                        if f.kind == NT_HELLO {
                            *seat = f.b1 as usize;
                        } else if f.kind == NT_START {
                            let seed = f.c as u64 | (f.d as u64) << 32;
                            let me = *seat;
                            let State::Waiting { host, .. } = std::mem::replace(&mut self.state, State::Off) else {
                                unreachable!()
                            };
                            self.state = State::Game { peers: vec![host], host: false };
                            t.net_begin(me, f.b1, f.b as i32, seed);
                            return;
                        }
                    }
                }
            },
            State::Game { peers, host } => {
                let mut lost = false;
                // réception (l'hôte relaie aux autres invités)
                for i in 0..peers.len() {
                    let Some(frames) = peers[i].recv() else {
                        lost = true;
                        break;
                    };
                    for f in frames {
                        if (NT_BID..=NT_NEXT).contains(&f.kind) && t.inbox.len() < 256 {
                            t.inbox.push_back(f);
                            if *host {
                                for (j, p) in peers.iter_mut().enumerate() {
                                    if j != i && !p.send(&f) {
                                        lost = true;
                                    }
                                }
                            }
                        }
                    }
                }
                // envoi des actions locales à tous
                let out: Vec<Frame> = t.outbox.drain(..).collect();
                for f in &out {
                    for p in peers.iter_mut() {
                        if !p.send(f) {
                            lost = true;
                        }
                    }
                }
                if lost {
                    self.close(t, LOST);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::engine::{PH_MATCHEND, PH_ROUNDEND};

    #[test]
    fn trames() {
        let f = Frame { kind: NT_START, b1: 0x9F, b: 1000, c: 0xDEADBEEF, d: 0x01234567 };
        assert_eq!(decode(&encode(&f)), f);
        assert_eq!(parse_addr("192.168.1.20"), Some("192.168.1.20:4210".parse().unwrap()));
        assert_eq!(parse_addr("10.0.0.1:5000"), Some("10.0.0.1:5000".parse().unwrap()));
        assert_eq!(parse_addr("10.0.0"), None);
    }

    /// Un hôte et trois invités sur 127.0.0.1 (vraies connexions TCP, l'hôte relaie) :
    /// les quatre machines jouent en mode automatique et restent identiques.
    #[test]
    fn quatre_joueurs_tcp() {
        let n = 4;
        let mut ts: Vec<Table> = (0..n).map(|k| Table::new(100 + k as u64)).collect();
        let mut nets: Vec<Net> = (0..n).map(|_| Net::new("127.0.0.1".into())).collect();
        nets[0].open(&mut ts[0]);
        nets[0].menu_key(&mut ts[0], 'h');
        assert!(nets[0].hosting(), "{:?}", nets[0].lines);
        for k in 1..n {
            nets[k].open(&mut ts[k]);
            nets[k].menu_key(&mut ts[k], 'r');
            nets[k].ip_char('\r');
            // attendre que l'hôte ait accepté cet invité avant le suivant (sièges dans l'ordre)
            for _ in 0..500 {
                nets[k].poll(&mut ts[k]);
                nets[0].poll(&mut ts[0]);
                if let State::Hosting { guests, .. } = &nets[0].state {
                    if guests.len() == k {
                        break;
                    }
                }
                if matches!(nets[0].state, State::Game { .. }) {
                    break;
                }
                std::thread::sleep(Duration::from_millis(2));
            }
        }
        for t in ts.iter_mut() {
            t.auto = true;
        }
        let speeds = [50.0, 37.0, 71.0, 44.0];
        // scores à chaque fin de manche, pour chaque machine
        let mut hist: Vec<Vec<[i32; 2]>> = vec![Vec::new(); n];
        let mut was_end = [false; 4];
        for _ in 0..40_000 {
            for k in 0..n {
                nets[k].poll(&mut ts[k]);
                ts[k].tick(speeds[k]);
                let end = ts[k].phase() == PH_ROUNDEND || ts[k].phase() == PH_MATCHEND;
                if end && !was_end[k] {
                    hist[k].push(ts[k].e.score);
                }
                was_end[k] = end;
            }
            if hist.iter().all(|h| h.len() >= 3) {
                break;
            }
            std::thread::sleep(Duration::from_micros(300));
        }
        assert!(ts.iter().all(|t| t.online), "pas tous en ligne : {:?}", nets.iter().map(|n| n.lines[0].clone()).collect::<Vec<_>>());
        assert_eq!(ts[0].humans, 0b1111);
        assert!(hist.iter().all(|h| h.len() >= 3), "manches jouées : {:?}", hist.iter().map(|h| h.len()).collect::<Vec<_>>());
        for h in &hist {
            assert_eq!(h[..3], hist[0][..3], "machines désynchronisées");
        }
        // un invité part : tout le monde revient en partie locale
        nets[2].close(&mut ts[2], "fin");
        for _ in 0..500 {
            for k in 0..n {
                nets[k].poll(&mut ts[k]);
            }
            if !ts[0].online {
                break;
            }
            std::thread::sleep(Duration::from_millis(2));
        }
        assert!(!ts[0].online);
    }
}
