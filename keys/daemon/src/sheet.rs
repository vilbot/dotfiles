//! The keyboard shortcut sheet as JSON, for the desktops' shells (Shortcuts settings, sheets):
//! $XDG_STATE_HOME/mackeys/keymap.json, written on every (re)load.
//!
//!   file       the keymap it is from (where `mackeys set` writes)
//!   desktops   what {n} stands for
//!   groups     [{title, rows: [{action, label, keys (as written), keysLabel (as on a Mac),
//!              triggers (every key it expands to, written one way: same text = same keys),
//!              layer (keys clash only within one), app}]}]; notes have `fixed` instead
//!   apps       {app: {action: [{mods: ["ctrl", ...], code}]}}: for each action an app does
//!              itself (an `app` layer), the keys it gets: mods as apps see them (ctrl, alt,
//!              altgr, super, shift) and the key's Linux code (layout-independent; Qt's
//!              nativeScanCode is this + 8)

use crate::config::{Config, DIRECTIONS, Layer, expand};
use crate::engine::{Engine, Out, World};
use crate::keys::{Mod, Side, Trigger};
use evdev::KeyCode;
use serde_json::{Map, Value, json};
use std::collections::BTreeSet;

pub fn json(config: &Config, file: &str) -> String {
    let groups: Vec<Value> = config
        .sheet
        .iter()
        .map(|section| {
            let rows: Vec<Value> = section
                .rows
                .iter()
                .map(|row| {
                    let labels: Vec<String> = row.keys.iter().map(|k| mac_label(k, config.desktops)).collect();
                    match &row.action {
                        Some(action) => json!({
                            "action": action,
                            "label": row.label,
                            "keys": row.keys,
                            "keysLabel": labels,
                            "triggers": triggers(action, &row.keys, config.desktops),
                            "layer": row.layer,
                            "app": row.app,
                        }),
                        None => json!({ "label": row.label, "keysLabel": row.keys, "fixed": true }),
                    }
                })
                .collect();
            json!({ "title": section.title, "rows": rows })
        })
        .collect();
    let model = json!({ "file": file, "desktops": config.desktops, "groups": groups, "apps": apps(config) });
    serde_json::to_string_pretty(&model).expect("json") + "\n"
}

/// Every key an action's keys expand to, written the one way (Trigger::text).
fn triggers(action: &str, keys: &[String], desktops: u32) -> Vec<String> {
    let expanded = expand(action, keys, desktops).unwrap_or_default();
    expanded.iter().filter_map(|(_, k)| Trigger::parse(k).ok()).map(|t| t.text()).collect()
}

/// The keys each app action reaches its app as: what the engine sends for them where the
/// app's layer applies.
fn apps(config: &Config) -> Value {
    let mut apps = Map::new();
    for layer in config.layers.iter().filter(|l| l.app.is_some()) {
        let app = layer.app.clone().unwrap();
        let entry = apps.entry(app).or_insert_with(|| Value::Object(Map::new()));
        let world = Place::of(layer, config);
        for row in config.sheet.iter().flat_map(|s| &s.rows).filter(|r| r.layer.as_deref() == Some(layer.name.as_str())) {
            let Some(action) = &row.action else { continue };
            let got: Vec<Value> = expand(action, &row.keys, config.desktops)
                .unwrap_or_default()
                .iter()
                .filter_map(|(_, k)| Trigger::parse(k).ok())
                .filter_map(|t| received(config, &world, &t))
                .map(|(mods, code)| json!({ "mods": mods, "code": code }))
                .collect();
            entry.as_object_mut().unwrap().insert(action.clone(), Value::Array(got));
        }
    }
    Value::Object(apps)
}

/// Where a layer applies: its app focused, its layer-shell surface open, its layout on.
struct Place {
    app: String,
    layer: Option<String>,
    overview: bool,
    layout: String,
}

impl Place {
    fn of(layer: &Layer, config: &Config) -> Place {
        let w = &layer.when;
        let app = w.app.as_ref().and_then(|g| config.apps.get(g)).and_then(|c| c.first()).cloned().unwrap_or_default();
        Place { app, layer: w.layer.clone(), overview: w.overview.unwrap_or(false), layout: w.layout.clone().unwrap_or_default() }
    }
}

impl World for Place {
    fn app(&self) -> &str {
        &self.app
    }
    fn layer_open(&self, namespace: &str) -> bool {
        self.layer.as_deref() == Some(namespace)
    }
    fn overview_open(&self) -> bool {
        self.overview
    }
    fn layout(&self) -> &str {
        &self.layout
    }
}

/// Presses the trigger's keys in a fresh engine: the modifiers apps see when its key goes
/// down, and that key's code.
fn received(config: &Config, world: &Place, t: &Trigger) -> Option<(Vec<&'static str>, u16)> {
    let mut engine = Engine::new(config.clone());
    let mut down: BTreeSet<KeyCode> = BTreeSet::new();
    let apply = |outs: Vec<Out>, down: &mut BTreeSet<KeyCode>| -> Option<KeyCode> {
        let mut pressed = None;
        for o in outs {
            if let Out::Key(k, is_down) = o {
                if is_down {
                    down.insert(k);
                    if Mod::of(k).is_none() {
                        pressed = Some(k);
                        break;
                    }
                } else {
                    down.remove(&k);
                }
            }
        }
        pressed
    };
    for (i, (m, side)) in t.mods.iter().enumerate() {
        let out = engine.key(physical(*m, side.unwrap_or(Side::Left)), true, i as u64, world);
        apply(out, &mut down);
    }
    let key = apply(engine.key(t.key, true, 100, world), &mut down)?;
    let mut mods: Vec<&'static str> = down
        .iter()
        .filter_map(|k| match *k {
            KeyCode::KEY_LEFTCTRL | KeyCode::KEY_RIGHTCTRL => Some("ctrl"),
            KeyCode::KEY_LEFTALT => Some("alt"),
            KeyCode::KEY_RIGHTALT => Some("altgr"),
            KeyCode::KEY_LEFTMETA | KeyCode::KEY_RIGHTMETA => Some("super"),
            KeyCode::KEY_LEFTSHIFT | KeyCode::KEY_RIGHTSHIFT => Some("shift"),
            _ => None,
        })
        .collect();
    mods.sort();
    mods.dedup();
    Some((mods, key.code()))
}

fn physical(m: Mod, side: Side) -> KeyCode {
    match (m, side) {
        (Mod::Cmd, Side::Left) => KeyCode::KEY_LEFTMETA,
        (Mod::Cmd, Side::Right) => KeyCode::KEY_RIGHTMETA,
        (Mod::Opt, Side::Left) => KeyCode::KEY_LEFTALT,
        (Mod::Opt, Side::Right) => KeyCode::KEY_RIGHTALT,
        (Mod::Ctrl, Side::Left) => KeyCode::KEY_LEFTCTRL,
        (Mod::Ctrl, Side::Right) => KeyCode::KEY_RIGHTCTRL,
        (Mod::Shift, Side::Left) => KeyCode::KEY_LEFTSHIFT,
        (Mod::Shift, Side::Right) => KeyCode::KEY_RIGHTSHIFT,
    }
}

/// How macOS menus write keys: "opt+shift+{n}" -> "⌥ ⇧ 1–5", "opt+shift+/" -> "⌥ ?".
pub fn mac_label(keys: &str, desktops: u32) -> String {
    let parts: Vec<&str> = keys.split('+').map(str::trim).collect();
    let (mods, key) = parts.split_at(parts.len().saturating_sub(1));
    let key = key.first().copied().unwrap_or("");
    // one side of a modifier ("ropt") shows as the modifier
    let mods: Vec<&str> = mods.iter().map(|m| m.strip_prefix(['l', 'r']).filter(|b| ["cmd", "opt", "ctrl", "shift"].contains(b)).unwrap_or(m)).collect();
    let mut shift = mods.contains(&"shift");

    let shifted = match key {
        "/" | "slash" if shift => Some("?"),
        "`" | "grave" if shift => Some("~"),
        _ => None,
    };
    if shifted.is_some() {
        shift = false;
    }
    let key = match shifted {
        Some(s) => s.to_string(),
        None => match key {
            "{n}" => format!("1–{desktops}"),
            "{dir}" => DIRECTIONS.iter().map(|(_, k)| k.to_uppercase()).collect::<Vec<_>>().join(" "),
            "{arrow}" => "← ↓ ↑ →".into(),
            "[" | "leftbrace" => "[".into(),
            "]" | "rightbrace" => "]".into(),
            "pageup" => "PgUp".into(),
            "pagedown" => "PgDn".into(),
            "home" => "Home".into(),
            "end" => "End".into(),
            "space" => "Space".into(),
            "enter" | "return" => "↩".into(),
            "esc" | "escape" => "Esc".into(),
            "tab" => "⇥".into(),
            "backspace" => "⌫".into(),
            "delete" => "⌦".into(),
            "left" => "←".into(),
            "right" => "→".into(),
            "up" => "↑".into(),
            "down" => "↓".into(),
            "grave" => "`".into(),
            "slash" => "/".into(),
            other => other.to_uppercase(),
        },
    };
    let mut out: Vec<String> = Vec::new();
    for (name, glyph) in [("ctrl", "⌃"), ("opt", "⌥"), ("shift", "⇧"), ("cmd", "⌘")] {
        if mods.contains(&name) && (name != "shift" || shift) {
            out.push(glyph.into());
        }
    }
    out.push(key);
    out.join(" ")
}
