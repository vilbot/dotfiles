//! The keyboard shortcut sheet as JSON, for Quickshell (Opt+? sheet, Shortcuts settings page).

use crate::config::{Config, DIRECTIONS};
use serde_json::{Value, json};

pub fn json(config: &Config) -> String {
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
                        Some(action) => json!({ "action": action, "label": row.label, "keys": row.keys, "keysLabel": labels }),
                        None => json!({ "label": row.label, "keysLabel": row.keys, "fixed": true }),
                    }
                })
                .collect();
            json!({ "title": section.title, "rows": rows })
        })
        .collect();
    let model = json!({ "desktops": config.desktops, "groups": groups });
    serde_json::to_string_pretty(&model).expect("json") + "\n"
}

/// How macOS menus write keys: "opt+shift+{n}" -> "⌥ ⇧ 1–5", "opt+shift+/" -> "⌥ ?".
pub fn mac_label(keys: &str, desktops: u32) -> String {
    let parts: Vec<&str> = keys.split('+').map(str::trim).collect();
    let (mods, key) = parts.split_at(parts.len().saturating_sub(1));
    let key = key.first().copied().unwrap_or("");
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
