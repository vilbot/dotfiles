//! remap.toml, read into typed rules. See keys/remap.toml for the format by example.

use crate::keys::{Chord, Mod, OutMod, Trigger, parse_key};
use anyhow::{Context, Result, bail};
use evdev::KeyCode;
use serde::Deserialize;
use std::collections::{BTreeMap, HashMap};

pub struct Config {
    /// Keyboards to take over: a device is used when its name contains one of these.
    pub devices: Vec<String>,
    /// Window classes by group name, e.g. "terminal" -> ["com.mitchellh.ghostty", ...].
    pub apps: HashMap<String, Vec<String>>,
    /// What each physical modifier sends unless a layer says otherwise.
    pub modifiers: ModMap,
    /// Physical key -> key sent, everywhere (unless a layer maps the combo).
    pub keys: HashMap<KeyCode, KeyCode>,
    pub tap_hold: Option<TapHold>,
    /// Checked top to bottom; see `Layer`.
    pub layers: Vec<Layer>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ModMap {
    pub cmd: OutMod,
    pub opt: OutMod,
    pub ctrl: OutMod,
    pub shift: OutMod,
}

impl ModMap {
    pub fn get(&self, m: Mod) -> OutMod {
        match m {
            Mod::Cmd => self.cmd,
            Mod::Opt => self.opt,
            Mod::Ctrl => self.ctrl,
            Mod::Shift => self.shift,
        }
    }
}

/// A key that is one key when tapped and a modifier when held (Caps: Esc / Ctrl).
pub struct TapHold {
    pub key: KeyCode,
    pub tap: KeyCode,
    /// Held, it is this physical modifier, so it goes through the same rules as the real key.
    pub hold: Mod,
    /// Held longer than this and let go alone, it does nothing.
    pub tap_ms: u64,
}

pub struct Layer {
    pub name: String,
    pub when: When,
    /// Changes to what physical modifiers send while this layer applies.
    pub modifiers: Vec<(Mod, OutMod)>,
    pub map: Vec<(Trigger, Action)>,
    /// When this layer applies, layers below it are not checked.
    pub stop: bool,
}

#[derive(Default)]
pub struct When {
    pub app: Option<String>,
    pub not_app: Option<String>,
    pub flag: Option<String>,
    pub not_flag: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Action {
    /// Sent while the physical key is down. With `hold`, the chord's modifiers stay down until
    /// the trigger's modifier is let go (Cmd+Tab: Alt stays held while the switcher is open).
    Send { chord: Chord, hold: bool },
    /// Tapped one after another when the key goes down.
    Sequence(Vec<Chord>),
    /// Nothing is sent.
    Nothing,
}

// --- the file as written ----------------------------------------------------------------

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct File {
    devices: Vec<String>,
    #[serde(default)]
    apps: HashMap<String, Vec<String>>,
    modifiers: BTreeMap<String, String>,
    #[serde(default)]
    keys: BTreeMap<String, String>,
    tap_hold: Option<FileTapHold>,
    #[serde(default, rename = "layer")]
    layers: Vec<FileLayer>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FileTapHold {
    key: String,
    tap: String,
    hold: String,
    tap_ms: u64,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FileLayer {
    name: String,
    #[serde(default)]
    when: FileWhen,
    #[serde(default)]
    modifiers: BTreeMap<String, String>,
    #[serde(default)]
    map: BTreeMap<String, FileAction>,
    #[serde(default)]
    stop: bool,
}

#[derive(Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct FileWhen {
    app: Option<String>,
    not_app: Option<String>,
    flag: Option<String>,
    not_flag: Option<String>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum FileAction {
    One(String),
    Many(Vec<String>),
    Held { send: String, hold: bool },
}

impl Config {
    pub fn parse(text: &str) -> Result<Config> {
        let file: File = toml::from_str(text)?;

        let modifiers = mod_map(&file.modifiers)?;
        let keys = file
            .keys
            .iter()
            .map(|(from, to)| Ok((parse_key(from)?, parse_key(to)?)))
            .collect::<Result<_>>()
            .context("in [keys]")?;
        let tap_hold = file
            .tap_hold
            .map(|t| -> Result<TapHold> {
                Ok(TapHold { key: parse_key(&t.key)?, tap: parse_key(&t.tap)?, hold: physical_mod(&t.hold)?, tap_ms: t.tap_ms })
            })
            .transpose()
            .context("in [tap_hold]")?;

        let mut layers = Vec::new();
        for l in file.layers {
            let layer = layer(l, &file.apps)?;
            layers.push(layer);
        }
        Ok(Config { devices: file.devices, apps: file.apps, modifiers, keys, tap_hold, layers })
    }
}

fn layer(l: FileLayer, apps: &HashMap<String, Vec<String>>) -> Result<Layer> {
    let ctx = || format!("in layer {:?}", l.name);
    for group in [&l.when.app, &l.when.not_app].into_iter().flatten() {
        if !apps.contains_key(group) {
            bail!("{}: no app group {group:?} in [apps]", ctx());
        }
    }
    let modifiers = l
        .modifiers
        .iter()
        .map(|(m, out)| Ok((physical_mod(m)?, OutMod::parse(out)?)))
        .collect::<Result<_>>()
        .with_context(ctx)?;
    let mut map = Vec::new();
    for (trigger, action) in &l.map {
        let parsed = (|| -> Result<(Trigger, Action)> {
            let action = match action {
                FileAction::One(chord) => Action::Send { chord: Chord::parse(chord)?, hold: false },
                FileAction::Held { send, hold } => Action::Send { chord: Chord::parse(send)?, hold: *hold },
                FileAction::Many(chords) if chords.is_empty() => Action::Nothing,
                FileAction::Many(chords) => Action::Sequence(chords.iter().map(|c| Chord::parse(c)).collect::<Result<_>>()?),
            };
            Ok((Trigger::parse(trigger)?, action))
        })()
        .with_context(|| format!("{}: {trigger:?}", ctx()))?;
        map.push(parsed);
    }
    let when = When { app: l.when.app, not_app: l.when.not_app, flag: l.when.flag, not_flag: l.when.not_flag };
    Ok(Layer { name: l.name, when, modifiers, map, stop: l.stop })
}

fn mod_map(m: &BTreeMap<String, String>) -> Result<ModMap> {
    let get = |name: &str| -> Result<OutMod> {
        OutMod::parse(m.get(name).with_context(|| format!("[modifiers] needs {name}"))?)
    };
    for name in m.keys() {
        physical_mod(name).context("in [modifiers]")?;
    }
    Ok(ModMap { cmd: get("cmd")?, opt: get("opt")?, ctrl: get("ctrl")?, shift: get("shift").unwrap_or(OutMod::Shift) })
}

fn physical_mod(name: &str) -> Result<Mod> {
    Ok(match name {
        "cmd" => Mod::Cmd,
        "opt" => Mod::Opt,
        "ctrl" => Mod::Ctrl,
        "shift" => Mod::Shift,
        _ => bail!("unknown modifier {name:?} (cmd, opt, ctrl or shift)"),
    })
}
