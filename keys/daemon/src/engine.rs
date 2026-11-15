//! The remapper itself: physical key events in, key events for apps out.
//!
//! Pure: no devices, no sockets, no clock. The caller passes the time and a `World` that says
//! which app is focused and which flags are set, so every behavior can be tested.
//!
//! Modifiers are sent lazily: before each key goes out, the modifiers apps see are made to match
//! what that key needs (press the missing ones, let go of the extra ones), and they stay like that
//! until the next key or modifier change. Nothing is re-pressed behind the user's back.

use crate::config::{Action, Config, Layer, ModMap};
use crate::keys::{Chord, Mod, OutMod, Side};
use evdev::KeyCode;
use std::collections::{BTreeSet, HashMap};

/// What the engine needs to know about the desktop.
pub trait World {
    /// Class of the focused window ("" when none).
    fn app(&self) -> &str;
    /// Whether the flag file $XDG_RUNTIME_DIR/<name> exists.
    fn flag(&self, name: &str) -> bool;
}

/// A key event for apps: the key and whether it goes down (true) or up.
pub type Out = (KeyCode, bool);

pub struct Engine {
    config: Config,
    /// Physical modifiers held right now (Caps counts once it is a modifier).
    held: BTreeSet<(Mod, Side)>,
    /// Output keys currently down (modifiers and keys).
    down: BTreeSet<KeyCode>,
    /// For each physical non-modifier key that is down: the output key it holds, if any.
    pressed: HashMap<KeyCode, Option<KeyCode>>,
    tap_hold: TapHoldState,
    sticky: Option<Sticky>,
}

enum TapHoldState {
    Up,
    /// Down, no other key yet: still a tap if let go in time.
    Undecided { since_ms: u64 },
    /// Down and acting as its modifier.
    Held,
}

/// Modifiers kept down by a `hold` action until the physical modifier that triggered it goes up.
struct Sticky {
    trigger: Mod,
    keys: Vec<KeyCode>,
}

impl Engine {
    pub fn new(config: Config) -> Engine {
        Engine {
            config,
            held: BTreeSet::new(),
            down: BTreeSet::new(),
            pressed: HashMap::new(),
            tap_hold: TapHoldState::Up,
            sticky: None,
        }
    }

    pub fn config(&self) -> &Config {
        &self.config
    }

    /// Swaps in a new config. Every key that is down for apps is let go first.
    pub fn reload(&mut self, config: Config) -> Vec<Out> {
        let out = self.release_all();
        *self = Engine::new(config);
        out
    }

    /// Lets go of every output key (e.g. when the keyboard disappears).
    pub fn release_all(&mut self) -> Vec<Out> {
        let out = self.down.iter().map(|k| (*k, false)).collect();
        self.down.clear();
        self.held.clear();
        self.pressed.clear();
        self.tap_hold = TapHoldState::Up;
        self.sticky = None;
        out
    }

    /// Handles one physical key going down or up, at `now_ms`.
    pub fn key(&mut self, key: KeyCode, is_down: bool, now_ms: u64, world: &dyn World) -> Vec<Out> {
        let mut out = Vec::new();
        let tap_hold_key = self.config.tap_hold.as_ref().map(|t| t.key);

        if Some(key) == tap_hold_key {
            self.tap_hold_key(is_down, now_ms, world, &mut out);
        } else {
            if is_down {
                self.decide_hold(world, &mut out);
            }
            match (Mod::of(key), is_down) {
                (Some(m), true) => {
                    self.held.insert(m);
                    self.sync(world, &mut out);
                }
                (Some(m), false) => {
                    self.held.remove(&m);
                    if self.sticky.as_ref().is_some_and(|s| !self.held.iter().any(|(h, _)| *h == s.trigger)) {
                        self.sticky = None;
                    }
                    self.sync(world, &mut out);
                }
                (None, true) => self.press(key, world, &mut out),
                (None, false) => {
                    if let Some(Some(sent)) = self.pressed.remove(&key) {
                        self.set(sent, false, &mut out);
                    }
                }
            }
        }
        out
    }

    fn tap_hold_key(&mut self, is_down: bool, now_ms: u64, world: &dyn World, out: &mut Vec<Out>) {
        let Some(th) = &self.config.tap_hold else { return };
        let (tap, hold, tap_ms) = (th.tap, th.hold, th.tap_ms);
        if is_down {
            self.tap_hold = TapHoldState::Undecided { since_ms: now_ms };
            return;
        }
        match std::mem::replace(&mut self.tap_hold, TapHoldState::Up) {
            TapHoldState::Undecided { since_ms } if now_ms.saturating_sub(since_ms) <= tap_ms => {
                self.sync(world, out);
                self.set(tap, true, out);
                self.set(tap, false, out);
            }
            TapHoldState::Held => {
                self.held.remove(&(hold, Side::Left));
                self.sync(world, out);
            }
            _ => {}
        }
    }

    /// Another key went down while the tap/hold key is undecided: it is a modifier now.
    fn decide_hold(&mut self, world: &dyn World, out: &mut Vec<Out>) {
        if let TapHoldState::Undecided { .. } = self.tap_hold {
            let hold = self.config.tap_hold.as_ref().map(|t| t.hold).expect("tap_hold set");
            self.tap_hold = TapHoldState::Held;
            self.held.insert((hold, Side::Left));
            self.sync(world, out);
        }
    }

    fn press(&mut self, key: KeyCode, world: &dyn World, out: &mut Vec<Out>) {
        let held: Vec<(Mod, Side)> = self.held.iter().copied().collect();
        let layers = active_layers(&self.config, world);
        let action = layers.iter().find_map(|l| l.map.iter().find(|(t, _)| t.matches(key, &held)).map(|(t, a)| (t.clone(), a.clone())));

        match action {
            Some((_, Action::Nothing)) => {
                self.pressed.insert(key, None);
            }
            Some((trigger, Action::Send { chord, hold })) => {
                self.send_mods(&chord, out);
                if hold {
                    let trigger_mod = trigger.mods.iter().map(|(m, _)| *m).find(|m| *m != Mod::Shift);
                    let keys = chord.mods.iter().filter(|m| **m != OutMod::Shift).map(|m| m.key(Side::Left)).collect();
                    self.sticky = trigger_mod.map(|trigger| Sticky { trigger, keys });
                }
                self.set(chord.key, true, out);
                self.pressed.insert(key, Some(chord.key));
            }
            Some((_, Action::Sequence(chords))) => {
                for chord in &chords {
                    self.send_mods(chord, out);
                    self.set(chord.key, true, out);
                    self.set(chord.key, false, out);
                }
                self.pressed.insert(key, None);
            }
            None => {
                let sent = self.config.keys.get(&key).copied().unwrap_or(key);
                self.sync(world, out);
                self.set(sent, true, out);
                self.pressed.insert(key, Some(sent));
            }
        }
    }

    /// Output modifiers become what the held physical modifiers send in this context.
    fn sync(&mut self, world: &dyn World, out: &mut Vec<Out>) {
        let map = modifier_map(&self.config, world);
        let mut want: BTreeSet<KeyCode> = BTreeSet::new();
        let sticky_trigger = self.sticky.as_ref().map(|s| s.trigger);
        for (m, side) in &self.held {
            if Some(*m) != sticky_trigger {
                want.insert(map.get(*m).key(*side));
            }
        }
        if let Some(s) = &self.sticky {
            want.extend(s.keys.iter().copied());
        }
        self.set_mods(want, out);
    }

    /// Output modifiers become exactly the chord's (plus any sticky ones).
    fn send_mods(&mut self, chord: &Chord, out: &mut Vec<Out>) {
        let mut want: BTreeSet<KeyCode> = chord.mods.iter().map(|m| m.key(Side::Left)).collect();
        if let Some(s) = &self.sticky {
            want.extend(s.keys.iter().copied());
        }
        self.set_mods(want, out);
    }

    fn set_mods(&mut self, want: BTreeSet<KeyCode>, out: &mut Vec<Out>) {
        let current: Vec<KeyCode> = self.down.iter().copied().filter(|k| is_modifier(*k)).collect();
        for k in current.iter().filter(|k| !want.contains(k)) {
            self.set(*k, false, out);
        }
        for k in want.iter().filter(|k| !current.contains(k)) {
            self.set(*k, true, out);
        }
    }

    fn set(&mut self, key: KeyCode, is_down: bool, out: &mut Vec<Out>) {
        let changed = if is_down { self.down.insert(key) } else { self.down.remove(&key) };
        if changed {
            out.push((key, is_down));
        } else if is_down {
            // Already down (e.g. the same output key from two physical keys): tap it again.
            out.push((key, false));
            out.push((key, true));
        }
    }
}

fn is_modifier(key: KeyCode) -> bool {
    Mod::of(key).is_some()
}

/// The layers that apply right now, top to bottom, ending at the first one with `stop`.
fn active_layers<'a>(config: &'a Config, world: &dyn World) -> Vec<&'a Layer> {
    let mut layers = Vec::new();
    for layer in &config.layers {
        if applies(layer, config, world) {
            layers.push(layer);
            if layer.stop {
                break;
            }
        }
    }
    layers
}

fn applies(layer: &Layer, config: &Config, world: &dyn World) -> bool {
    let in_group = |group: &str| config.apps.get(group).is_some_and(|classes| classes.iter().any(|c| c.eq_ignore_ascii_case(world.app())));
    let w = &layer.when;
    w.app.as_deref().is_none_or(in_group)
        && !w.not_app.as_deref().is_some_and(in_group)
        && w.flag.as_deref().is_none_or(|f| world.flag(f))
        && !w.not_flag.as_deref().is_some_and(|f| world.flag(f))
}

/// What each physical modifier sends right now: the first applying layer that sets one wins.
fn modifier_map(config: &Config, world: &dyn World) -> ModMap {
    let mut map = config.modifiers;
    let mut decided: Vec<Mod> = Vec::new();
    for layer in active_layers(config, world) {
        for (m, sent) in &layer.modifiers {
            if !decided.contains(m) {
                decided.push(*m);
                match m {
                    Mod::Cmd => map.cmd = *sent,
                    Mod::Opt => map.opt = *sent,
                    Mod::Ctrl => map.ctrl = *sent,
                    Mod::Shift => map.shift = *sent,
                }
            }
        }
    }
    map
}
