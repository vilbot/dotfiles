//! Names of keys and combos as written in remap.toml.
//!
//! Physical side (what is pressed): Mac names, `cmd+shift+left`, `ropt+f1`.
//! Output side (what apps get): Linux names, `ctrl+shift+c`, `super+f13`.

use anyhow::{Context, Result, bail};
use evdev::KeyCode;
use std::str::FromStr;

/// A modifier key on the physical (Mac) keyboard.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum Mod {
    Cmd,
    Opt,
    Ctrl,
    Shift,
}

/// A modifier as apps see it.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum OutMod {
    Ctrl,
    Alt,
    Super,
    Shift,
    /// The right Alt key, whichever side triggered it: the layout's third level (swerty's ;:'"[]{}).
    AltGr,
}

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub enum Side {
    Left,
    Right,
}

impl Mod {
    /// The physical modifier a key code is, if it is one.
    pub fn of(key: KeyCode) -> Option<(Mod, Side)> {
        Some(match key {
            KeyCode::KEY_LEFTMETA => (Mod::Cmd, Side::Left),
            KeyCode::KEY_RIGHTMETA => (Mod::Cmd, Side::Right),
            KeyCode::KEY_LEFTALT => (Mod::Opt, Side::Left),
            KeyCode::KEY_RIGHTALT => (Mod::Opt, Side::Right),
            KeyCode::KEY_LEFTCTRL => (Mod::Ctrl, Side::Left),
            KeyCode::KEY_RIGHTCTRL => (Mod::Ctrl, Side::Right),
            KeyCode::KEY_LEFTSHIFT => (Mod::Shift, Side::Left),
            KeyCode::KEY_RIGHTSHIFT => (Mod::Shift, Side::Right),
            _ => return None,
        })
    }

    fn parse(name: &str) -> Option<(Mod, Option<Side>)> {
        let (side, base) = match name.as_bytes().first() {
            Some(b'l') if name.len() > 1 && Mod::parse(&name[1..]).is_some() => (Some(Side::Left), &name[1..]),
            Some(b'r') if name.len() > 1 && Mod::parse(&name[1..]).is_some() => (Some(Side::Right), &name[1..]),
            _ => (None, name),
        };
        let m = match base {
            "cmd" => Mod::Cmd,
            "opt" => Mod::Opt,
            "ctrl" => Mod::Ctrl,
            "shift" => Mod::Shift,
            _ => return None,
        };
        Some((m, side))
    }
}

impl OutMod {
    pub fn key(self, side: Side) -> KeyCode {
        match (self, side) {
            (OutMod::Ctrl, Side::Left) => KeyCode::KEY_LEFTCTRL,
            (OutMod::Ctrl, Side::Right) => KeyCode::KEY_RIGHTCTRL,
            (OutMod::Alt, Side::Left) => KeyCode::KEY_LEFTALT,
            (OutMod::Alt, Side::Right) => KeyCode::KEY_RIGHTALT,
            (OutMod::Super, Side::Left) => KeyCode::KEY_LEFTMETA,
            (OutMod::Super, Side::Right) => KeyCode::KEY_RIGHTMETA,
            (OutMod::Shift, Side::Left) => KeyCode::KEY_LEFTSHIFT,
            (OutMod::Shift, Side::Right) => KeyCode::KEY_RIGHTSHIFT,
            (OutMod::AltGr, _) => KeyCode::KEY_RIGHTALT,
        }
    }

    pub fn parse(name: &str) -> Result<OutMod> {
        Ok(match name {
            "ctrl" => OutMod::Ctrl,
            "alt" => OutMod::Alt,
            "super" => OutMod::Super,
            "shift" => OutMod::Shift,
            "altgr" => OutMod::AltGr,
            _ => bail!("unknown modifier {name:?} (ctrl, alt, super, shift or altgr)"),
        })
    }
}

/// Physical keys pressed together, e.g. `cmd+shift+left`.
/// A modifier without a side (`opt`) matches either side; `ropt` only the right one.
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct Trigger {
    pub mods: Vec<(Mod, Option<Side>)>,
    pub key: KeyCode,
}

impl Trigger {
    pub fn parse(text: &str) -> Result<Trigger> {
        let (mods, key) = split(text)?;
        let mods = mods
            .iter()
            .map(|m| Mod::parse(m).with_context(|| format!("unknown modifier {m:?} in {text:?} (cmd, opt, ctrl, shift; l/r prefix for a side)")))
            .collect::<Result<Vec<_>>>()?;
        Ok(Trigger { mods, key: parse_key(key)? })
    }

    /// True when exactly these modifiers are held: none missing, none extra.
    pub fn matches(&self, key: KeyCode, held: &[(Mod, Side)]) -> bool {
        if key != self.key {
            return false;
        }
        let wanted = |m: Mod| self.mods.iter().find(|(want, _)| *want == m);
        for m in [Mod::Cmd, Mod::Opt, Mod::Ctrl, Mod::Shift] {
            let held_sides: Vec<Side> = held.iter().filter(|(h, _)| *h == m).map(|(_, s)| *s).collect();
            match wanted(m) {
                None if !held_sides.is_empty() => return false,
                None => {}
                Some(_) if held_sides.is_empty() => return false,
                Some((_, Some(side))) if !held_sides.contains(side) => return false,
                Some(_) => {}
            }
        }
        true
    }
}

/// Keys an app should get, e.g. `ctrl+shift+c` (modifiers are sent as their left key).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Chord {
    pub mods: Vec<OutMod>,
    pub key: KeyCode,
}

impl Chord {
    pub fn parse(text: &str) -> Result<Chord> {
        let (mods, key) = split(text)?;
        let mods = mods.iter().map(|m| OutMod::parse(m)).collect::<Result<Vec<_>>>().with_context(|| format!("in {text:?}"))?;
        Ok(Chord { mods, key: parse_key(key)? })
    }
}

fn split(text: &str) -> Result<(Vec<&str>, &str)> {
    let mut parts: Vec<&str> = text.split('+').map(str::trim).collect();
    // "cmd++" is cmd and the + key; "cmd+=" is cmd and =
    if text.ends_with("++") {
        parts.pop();
        parts.pop();
        parts.push("+");
    }
    let key = parts.pop().filter(|k| !k.is_empty()).with_context(|| format!("no key in {text:?}"))?;
    Ok((parts, key))
}

/// A key by its name: letters and digits as themselves, `left`, `esc`, `f13`, `[`, `brightnessdown`, ...
/// Anything else is looked up as the kernel's KEY_<NAME>.
pub fn parse_key(name: &str) -> Result<KeyCode> {
    let lower = name.to_ascii_lowercase();
    let kernel_name = match lower.as_str() {
        "return" => "enter",
        "escape" => "esc",
        "del" => "delete",
        "[" => "leftbrace",
        "]" => "rightbrace",
        "`" => "grave",
        "." => "dot",
        "," => "comma",
        "-" => "minus",
        "=" => "equal",
        "/" => "slash",
        ";" => "semicolon",
        "'" => "apostrophe",
        "\\" => "backslash",
        other => other,
    };
    KeyCode::from_str(&format!("KEY_{}", kernel_name.to_ascii_uppercase())).map_err(|_| anyhow::anyhow!("unknown key {name:?}"))
}

/// The name parse_key accepts for a key (for test output and errors).
pub fn key_name(key: KeyCode) -> String {
    let debug = format!("{key:?}");
    debug.strip_prefix("KEY_").unwrap_or(&debug).to_ascii_lowercase()
}

/// How remap.toml writes a key: the short form parse_key takes ("[" for leftbrace, "1", "esc").
pub fn key_text(key: KeyCode) -> String {
    let name = key_name(key);
    let short = match name.as_str() {
        "leftbrace" => "[",
        "rightbrace" => "]",
        "grave" => "`",
        "dot" => ".",
        "comma" => ",",
        "minus" => "-",
        "equal" => "=",
        "slash" => "/",
        "semicolon" => ";",
        "apostrophe" => "'",
        "backslash" => "\\",
        other => other,
    };
    short.to_string()
}

impl Trigger {
    /// The one way of writing these keys: modifiers in the Mac's order (ctrl, opt, shift, cmd;
    /// "ropt" for one side), then the key. Two triggers are the same keys when this is the same.
    pub fn text(&self) -> String {
        let mut mods = self.mods.clone();
        mods.sort_by_key(|(m, _)| match m {
            Mod::Ctrl => 0,
            Mod::Opt => 1,
            Mod::Shift => 2,
            Mod::Cmd => 3,
        });
        let mut parts: Vec<String> = mods
            .iter()
            .map(|(m, side)| {
                let side = match side {
                    Some(Side::Left) => "l",
                    Some(Side::Right) => "r",
                    None => "",
                };
                format!("{side}{}", format!("{m:?}").to_lowercase())
            })
            .collect();
        parts.push(key_text(self.key));
        parts.join("+")
    }
}
