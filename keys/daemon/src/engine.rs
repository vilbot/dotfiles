//! The remapper itself: physical key events in, key events and desktop actions out.
//!
//! Pure: no devices, no sockets, no clock. The caller passes the time and a `World` that says
//! which app is focused and what is open, so every behavior can be tested.
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
    /// Whether a layer-shell surface with this namespace is open.
    fn layer_open(&self, namespace: &str) -> bool;
    /// Whether mission control is open. Asked only when a layer that depends on it has the
    /// pressed key, or drops keys it doesn't list (`let_through`).
    fn overview_open(&self) -> bool;
    /// The keyboard layout typing goes through now, as Hyprland names it ("Sweden - Swerty").
    fn layout(&self) -> &str {
        ""
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Out {
    /// A key going down (true) or up, for apps.
    Key(KeyCode, bool),
    /// A desktop action to run (hypr/actions.lua).
    Run(String),
}

pub struct Engine {
    config: Config,
    /// Physical modifiers held right now (Caps counts once it is a modifier).
    held: BTreeSet<(Mod, Side)>,
    /// Output keys currently down (modifiers and keys).
    down: BTreeSet<KeyCode>,
    /// What each physical non-modifier key that is down is doing.
    pressed: HashMap<KeyCode, Pressed>,
    tap_hold: TapHoldState,
    sticky: Option<Sticky>,
    /// Actions to run once a physical modifier is let go (`on_release`).
    on_release: Vec<(Mod, String)>,
}

enum Pressed {
    Key(KeyCode),
    Action { name: String, repeat: bool },
    Nothing,
}

enum TapHoldState {
    Up,
    /// Down, no other key yet: still a tap if let go in time.
    Undecided { since_ms: u64 },
    /// Down and acting as its modifier.
    Held,
}

/// Modifiers kept down by a `hold` mapping until the physical modifier that triggered it goes up.
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
            on_release: Vec::new(),
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
        let out = std::mem::take(&mut self.down).into_iter().map(|k| Out::Key(k, false)).collect();
        self.held.clear();
        self.pressed.clear();
        self.tap_hold = TapHoldState::Up;
        self.sticky = None;
        self.on_release.clear();
        out
    }

    /// Handles one physical key going down or up, at `now_ms`.
    pub fn key(&mut self, key: KeyCode, is_down: bool, now_ms: u64, world: &dyn World) -> Vec<Out> {
        let mut out = Vec::new();
        let tap_hold_key = self.config.tap_hold.as_ref().map(|t| t.key);

        if Some(key) == tap_hold_key {
            self.tap_hold_key(is_down, now_ms, world, &mut out);
            return out;
        }
        if is_down {
            self.decide_hold(world, &mut out);
        }
        match (Mod::of(key), is_down) {
            (Some(m), true) => {
                self.held.insert(m);
                self.sync(world, &mut out);
            }
            (Some(m), false) => self.modifier_up(m, world, &mut out),
            (None, true) => self.press(key, world, &mut out),
            (None, false) => match self.pressed.remove(&key) {
                Some(Pressed::Key(sent)) => self.set(sent, false, &mut out),
                _ => {}
            },
        }
        out
    }

    /// The keyboard repeats a held key: actions marked `repeat` run again, keys don't (the
    /// desktop repeats keys itself).
    pub fn repeat(&mut self, key: KeyCode) -> Vec<Out> {
        match self.pressed.get(&key) {
            Some(Pressed::Action { name, repeat: true }) => vec![Out::Run(name.clone())],
            _ => Vec::new(),
        }
    }

    fn modifier_up(&mut self, m: (Mod, Side), world: &dyn World, out: &mut Vec<Out>) {
        self.held.remove(&m);
        let still_held = |k: Mod, held: &BTreeSet<(Mod, Side)>| held.iter().any(|(h, _)| *h == k);
        if self.sticky.as_ref().is_some_and(|s| !still_held(s.trigger, &self.held)) {
            self.sticky = None;
        }
        let (due, waiting): (Vec<_>, Vec<_>) = std::mem::take(&mut self.on_release).into_iter().partition(|(k, _)| !still_held(*k, &self.held));
        self.on_release = waiting;
        self.sync(world, out);
        out.extend(due.into_iter().map(|(_, name)| Out::Run(name)));
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
            TapHoldState::Held => self.modifier_up((hold, Side::Left), world, out),
            _ => {}
        }
    }

    /// Another key went down while the tap/hold key is undecided: it is a modifier now.
    fn decide_hold(&mut self, world: &dyn World, out: &mut Vec<Out>) {
        if let (TapHoldState::Undecided { .. }, Some(th)) = (&self.tap_hold, &self.config.tap_hold) {
            let hold = th.hold;
            self.tap_hold = TapHoldState::Held;
            self.held.insert((hold, Side::Left));
            self.sync(world, out);
        }
    }

    fn press(&mut self, key: KeyCode, world: &dyn World, out: &mut Vec<Out>) {
        let held: Vec<(Mod, Side)> = self.held.iter().copied().collect();
        let found = lookup(&self.config, world, |trigger| trigger.matches(key, &held)).map(|(t, a)| (t.clone(), a.clone()));

        let pressed = match found {
            Some((_, Action::Nothing)) => Pressed::Nothing,
            Some((trigger, Action::Send { chord, hold })) => {
                self.send_mods(&chord, out);
                if hold {
                    let keys = chord.mods.iter().filter(|m| **m != OutMod::Shift).map(|m| m.key(Side::Left)).collect();
                    self.sticky = trigger_mod(&trigger).map(|trigger| Sticky { trigger, keys });
                }
                self.set(chord.key, true, out);
                Pressed::Key(chord.key)
            }
            Some((_, Action::Sequence(chords))) => {
                for chord in &chords {
                    self.send_mods(chord, out);
                    self.set(chord.key, true, out);
                    self.set(chord.key, false, out);
                }
                Pressed::Nothing
            }
            Some((trigger, Action::Run { name, repeat, on_release })) => {
                if let (Some(after), Some(m)) = (on_release, trigger_mod(&trigger)) {
                    if !self.on_release.iter().any(|(k, n)| *k == m && *n == after) {
                        self.on_release.push((m, after));
                    }
                }
                out.push(Out::Run(name.clone()));
                Pressed::Action { name, repeat }
            }
            None if dropped(&self.config, world, key) => Pressed::Nothing,
            None => {
                let sent = self.config.keys.get(&key).copied().unwrap_or(key);
                self.sync(world, out);
                self.set(sent, true, out);
                Pressed::Key(sent)
            }
        };
        self.pressed.insert(key, pressed);
    }

    /// Output modifiers become what the held physical modifiers send in this context.
    fn sync(&mut self, world: &dyn World, out: &mut Vec<Out>) {
        let map = modifier_map(&self.config, world);
        let sticky_trigger = self.sticky.as_ref().map(|s| s.trigger);
        let mut want: BTreeSet<KeyCode> =
            self.held.iter().filter(|(m, _)| Some(*m) != sticky_trigger).map(|(m, side)| map.get(*m).key(*side)).collect();
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
        let current: Vec<KeyCode> = self.down.iter().copied().filter(|k| Mod::of(*k).is_some()).collect();
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
            out.push(Out::Key(key, is_down));
        } else if is_down {
            // Already down (e.g. the same output key from two physical keys): tap it again.
            out.push(Out::Key(key, false));
            out.push(Out::Key(key, true));
        }
    }
}

/// The modifier that "holds" a mapping or action: the trigger's first one that isn't Shift.
fn trigger_mod(trigger: &crate::keys::Trigger) -> Option<Mod> {
    trigger.mods.iter().map(|(m, _)| *m).find(|m| *m != Mod::Shift)
}

/// The first mapping, top to bottom, whose trigger fits and whose layer applies. A layer's
/// condition is only checked when it has a fitting trigger or `stop`, so mission control is only
/// asked whether it is open when one of its keys is pressed.
fn lookup<'a>(config: &'a Config, world: &dyn World, fits: impl Fn(&crate::keys::Trigger) -> bool) -> Option<&'a (crate::keys::Trigger, Action)> {
    for layer in &config.layers {
        let hit = layer.map.iter().find(|(t, _)| fits(t));
        if (hit.is_some() || layer.stop) && applies(layer, config, world) {
            if hit.is_some() {
                return hit;
            }
            if layer.stop {
                return None;
            }
        }
    }
    None
}

/// A key no layer maps: dropped when an applying layer lets only other keys through.
fn dropped(config: &Config, world: &dyn World, key: KeyCode) -> bool {
    config.layers.iter().any(|l| l.let_through.as_ref().is_some_and(|keys| !keys.contains(&key)) && applies(l, config, world))
}

fn applies(layer: &Layer, config: &Config, world: &dyn World) -> bool {
    let in_group = |group: &str| config.apps.get(group).is_some_and(|classes| classes.iter().any(|c| c.eq_ignore_ascii_case(world.app())));
    let w = &layer.when;
    w.app.as_deref().is_none_or(in_group)
        && !w.not_app.as_deref().is_some_and(in_group)
        && w.layer.as_deref().is_none_or(|l| world.layer_open(l))
        && !w.not_layer.as_deref().is_some_and(|l| world.layer_open(l))
        && w.overview.is_none_or(|want| world.overview_open() == want)
        && w.layout.as_deref().is_none_or(|l| world.layout() == l)
}

/// What each physical modifier sends right now: the first applying layer that sets one wins,
/// down to the first applying layer with `stop`.
fn modifier_map(config: &Config, world: &dyn World) -> ModMap {
    let mut map = config.modifiers;
    let mut decided: Vec<Mod> = Vec::new();
    for layer in &config.layers {
        if !(layer.stop || !layer.modifiers.is_empty()) || !applies(layer, config, world) {
            continue;
        }
        for (m, sent) in &layer.modifiers {
            if !decided.contains(m) {
                decided.push(*m);
                map.set(*m, *sent);
            }
        }
        if layer.stop {
            break;
        }
    }
    map
}
