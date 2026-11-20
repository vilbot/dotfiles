//! Recording keys for the Settings app's Shortcuts page: the next keys pressed, as remap.toml
//! writes them ("opt+shift+1"), instead of doing anything. Pure: the daemon feeds it the physical
//! keys and keeps the time.
//!
//! Esc pressed twice cancels; Esc once (after a short wait, `Step::EscWait`) is recorded as Esc,
//! so Esc can be bound. The tap/hold key (Caps) is its hold modifier when another key goes down
//! while it is held, and Esc when tapped alone, as when typing.

use crate::config::TapHold;
use crate::keys::{Mod, Trigger};
use evdev::KeyCode;
use std::collections::BTreeSet;

pub struct Recorder {
    tap_hold: Option<(KeyCode, Mod, KeyCode)>,
    held: BTreeSet<Mod>,
    /// The tap/hold key is down; true once another key went down with it (it's a modifier then).
    tap_hold_down: Option<bool>,
    /// Esc was pressed once: a second press cancels, anything else records Esc.
    esc_once: bool,
}

#[derive(Debug, PartialEq)]
pub enum Step {
    /// Still waiting for keys.
    Waiting,
    /// Esc once: wait a moment for a second one, then call `esc_timeout`.
    EscWait,
    /// These keys were pressed.
    Done(String),
    /// Esc twice.
    Cancelled,
}

impl Recorder {
    pub fn new(tap_hold: Option<&TapHold>) -> Recorder {
        Recorder { tap_hold: tap_hold.map(|t| (t.key, t.hold, t.tap)), held: BTreeSet::new(), tap_hold_down: None, esc_once: false }
    }

    pub fn key(&mut self, key: KeyCode, is_down: bool) -> Step {
        if let Some((th_key, hold, tap)) = self.tap_hold {
            if key == th_key {
                if is_down {
                    self.tap_hold_down = Some(false);
                    return Step::Waiting;
                }
                return match self.tap_hold_down.take() {
                    Some(false) => self.press(tap),
                    _ => {
                        self.held.remove(&hold);
                        Step::Waiting
                    }
                };
            }
            if is_down && self.tap_hold_down == Some(false) {
                self.tap_hold_down = Some(true);
                self.held.insert(hold);
            }
        }
        match (Mod::of(key), is_down) {
            (Some((m, _)), true) => {
                self.held.insert(m);
                Step::Waiting
            }
            (Some((m, _)), false) => {
                self.held.remove(&m);
                Step::Waiting
            }
            (None, true) => self.press(key),
            (None, false) => Step::Waiting,
        }
    }

    /// No second Esc came: Esc it is.
    pub fn esc_timeout(&mut self) -> Step {
        self.esc_once = false;
        Step::Done("esc".into())
    }

    fn press(&mut self, key: KeyCode) -> Step {
        let bare_esc = key == KeyCode::KEY_ESC && self.held.is_empty();
        if self.esc_once {
            self.esc_once = false;
            return if bare_esc { Step::Cancelled } else { Step::Done("esc".into()) };
        }
        if bare_esc {
            self.esc_once = true;
            return Step::EscWait;
        }
        let trigger = Trigger { mods: self.held.iter().map(|m| (*m, None)).collect(), key };
        Step::Done(trigger.text())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::parse_key;

    fn caps() -> TapHold {
        TapHold { key: KeyCode::KEY_CAPSLOCK, tap: KeyCode::KEY_ESC, hold: Mod::Ctrl, tap_ms: 1000 }
    }

    /// "+opt +shift +1" -> the last step
    fn feed(r: &mut Recorder, events: &str) -> Step {
        let mut last = Step::Waiting;
        for ev in events.split_whitespace() {
            let (kind, name) = ev.split_at(1);
            let name = match name {
                "cmd" => "leftmeta",
                "opt" => "leftalt",
                "ctrl" => "leftctrl",
                "shift" => "leftshift",
                "caps" => "capslock",
                n => n,
            };
            last = r.key(parse_key(name).unwrap(), kind == "+");
            if last != Step::Waiting {
                return last;
            }
        }
        last
    }

    #[test]
    fn records_modifiers_in_mac_order() {
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+shift +opt +1"), Step::Done("opt+shift+1".into()));
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+cmd +ctrl +q"), Step::Done("ctrl+cmd+q".into()));
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+opt +leftbrace"), Step::Done("opt+[".into()));
    }

    #[test]
    fn a_modifier_let_go_no_longer_counts() {
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+opt -opt +f"), Step::Done("f".into()));
    }

    #[test]
    fn esc_twice_cancels_once_records_esc() {
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+esc"), Step::EscWait);
        assert_eq!(feed(&mut r, "-esc +esc"), Step::Cancelled);
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+esc"), Step::EscWait);
        assert_eq!(r.esc_timeout(), Step::Done("esc".into()));
        let mut r = Recorder::new(None);
        assert_eq!(feed(&mut r, "+opt +esc"), Step::Done("opt+esc".into()));
    }

    #[test]
    fn caps_held_is_ctrl_tapped_is_esc() {
        let mut r = Recorder::new(Some(&caps()));
        assert_eq!(feed(&mut r, "+caps +j"), Step::Done("ctrl+j".into()));
        let mut r = Recorder::new(Some(&caps()));
        assert_eq!(feed(&mut r, "+caps -caps"), Step::EscWait);
        assert_eq!(feed(&mut r, "+caps -caps"), Step::Cancelled);
        let mut r = Recorder::new(Some(&caps()));
        assert_eq!(feed(&mut r, "+caps -caps"), Step::EscWait);
        assert_eq!(feed(&mut r, "+esc"), Step::Cancelled);
    }
}
