//! remap.toml, read into typed rules. See keys/remap.toml for the format by example.

use crate::keys::{Chord, Mod, OutMod, Trigger, parse_key};
use anyhow::{Context, Result, bail};
use evdev::KeyCode;
use indexmap::IndexMap;
use serde::Deserialize;
use std::collections::{BTreeMap, HashMap, HashSet};

pub struct Config {
    /// Keyboards to take over: a device is used when its name contains one of these.
    pub devices: Vec<String>,
    /// How many desktops `{n}` stands for.
    pub desktops: u32,
    /// Window classes by group name, e.g. "terminal" -> ["com.mitchellh.ghostty", ...].
    pub apps: HashMap<String, Vec<String>>,
    /// What each physical modifier sends unless a layer says otherwise.
    pub modifiers: ModMap,
    /// Physical key -> key sent, everywhere (unless a layer maps the combo).
    pub keys: HashMap<KeyCode, KeyCode>,
    pub tap_hold: Option<TapHold>,
    /// Checked top to bottom; see `Layer`.
    pub layers: Vec<Layer>,
    /// Every action with its label and keys as written, by section: the keyboard shortcut sheet.
    pub sheet: Vec<Section>,
    /// Actions that open a layer (`wait_for_layer`): keys typed right after them are held back
    /// until it is open, action name -> layer namespace.
    pub waits: HashMap<String, String>,
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

    pub fn set(&mut self, m: Mod, sent: OutMod) {
        match m {
            Mod::Cmd => self.cmd = sent,
            Mod::Opt => self.opt = sent,
            Mod::Ctrl => self.ctrl = sent,
            Mod::Shift => self.shift = sent,
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
    /// When this layer applies, a key no layer maps goes through only if it is listed here;
    /// the rest are dropped (None: everything goes through).
    pub let_through: Option<Vec<KeyCode>>,
}

#[derive(Default)]
pub struct When {
    pub app: Option<String>,
    pub not_app: Option<String>,
    /// A layer (Hyprland layer-shell namespace, e.g. "quickshell-palette") is open.
    pub layer: Option<String>,
    pub not_layer: Option<String>,
    /// Mission control (hymission) is open.
    pub overview: Option<bool>,
    /// This keyboard layout is on (Hyprland's name for it, e.g. "Sweden - Swerty").
    pub layout: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum Action {
    /// Sent while the physical key is down. With `hold`, the chord's modifiers stay down until
    /// the trigger's modifier is let go (Ctrl+Tab in browsers).
    Send { chord: Chord, hold: bool },
    /// Tapped one after another when the key goes down.
    Sequence(Vec<Chord>),
    /// Runs a desktop action (hypr/actions.lua). `repeat`: again while the key is held.
    /// `on_release`: another action, run when the trigger's modifier is let go.
    Run { name: String, repeat: bool, on_release: Option<String> },
    /// Nothing is sent.
    Nothing,
}

pub struct Section {
    pub title: String,
    pub rows: Vec<Row>,
}

pub struct Row {
    /// The action as written ("window.focus.{dir}"); None for a note (a mouse bind).
    pub action: Option<String>,
    pub label: String,
    /// Keys as written ("opt+{dir}").
    pub keys: Vec<String>,
}

// --- the file as written ----------------------------------------------------------------

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct File {
    devices: Vec<String>,
    desktops: u32,
    #[serde(default)]
    apps: HashMap<String, Vec<String>>,
    modifiers: BTreeMap<String, String>,
    #[serde(default)]
    keys: BTreeMap<String, String>,
    tap_hold: Option<FileTapHold>,
    #[serde(default, rename = "layer")]
    layers: Vec<FileLayer>,
    /// Shown on the sheet, not keys of ours: section -> [[label, keys], ...]
    #[serde(default)]
    notes: IndexMap<String, Vec<[String; 2]>>,
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
    map: BTreeMap<String, FileSend>,
    /// section -> action -> how it's bound
    #[serde(default)]
    actions: IndexMap<String, IndexMap<String, FileAction>>,
    #[serde(default)]
    stop: bool,
    let_through: Option<Vec<String>>,
}

#[derive(Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct FileWhen {
    app: Option<String>,
    not_app: Option<String>,
    layer: Option<String>,
    not_layer: Option<String>,
    overview: Option<bool>,
    layout: Option<String>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum FileSend {
    One(String),
    Many(Vec<String>),
    Held { send: String, hold: bool },
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct FileAction {
    keys: OneOrMany,
    label: String,
    #[serde(default)]
    repeat: bool,
    on_release: Option<String>,
    wait_for_layer: Option<String>,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum OneOrMany {
    One(String),
    Many(Vec<String>),
}

impl OneOrMany {
    fn list(&self) -> Vec<String> {
        match self {
            OneOrMany::One(k) => vec![k.clone()],
            OneOrMany::Many(ks) => ks.clone(),
        }
    }
}

/// `{dir}` in an action name and its keys: the direction and its vim key.
pub const DIRECTIONS: [(&str, &str); 4] = [("left", "h"), ("down", "j"), ("up", "k"), ("right", "l")];

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
        // the sheet: keys that always work first, then those of a mode (mission control, ...)
        let (mut sheet, mut modes): (Vec<Section>, Vec<Section>) = (Vec::new(), Vec::new());
        let mut action_names = HashSet::new();
        let mut waits = HashMap::new();
        for l in &file.layers {
            layers.push(layer(l, &file.apps, file.desktops)?);
            let w = &l.when;
            let in_mode = w.app.is_some() || w.not_app.is_some() || w.layer.is_some() || w.not_layer.is_some() || w.overview.is_some() || w.layout.is_some();
            for (title, actions) in &l.actions {
                let rows = actions.iter().map(|(name, a)| Row { action: Some(name.clone()), label: a.label.clone(), keys: a.keys.list() });
                section(if in_mode { &mut modes } else { &mut sheet }, title).rows.extend(rows);
                for (name, a) in actions {
                    if !action_names.insert(name.clone()) {
                        bail!("action {name:?} is listed twice");
                    }
                    if let Some(layer) = &a.wait_for_layer {
                        for (name, _) in expand(name, &a.keys.list(), file.desktops)? {
                            waits.insert(name, layer.clone());
                        }
                    }
                }
            }
        }
        sheet.extend(modes);
        for (title, notes) in &file.notes {
            let rows = notes.iter().map(|[label, keys]| Row { action: None, label: label.clone(), keys: vec![keys.clone()] });
            section(&mut sheet, title).rows.extend(rows);
        }

        Ok(Config { devices: file.devices, desktops: file.desktops, apps: file.apps, modifiers, keys, tap_hold, layers, sheet, waits })
    }
}

impl Config {
    /// Every action the keys can run, expanded ("desktop.goto.1", ...), sorted.
    pub fn action_names(&self) -> Vec<String> {
        let mut names: Vec<String> = self
            .layers
            .iter()
            .flat_map(|l| &l.map)
            .filter_map(|(_, a)| match a {
                Action::Run { name, on_release, .. } => Some([Some(name.clone()), on_release.clone()]),
                _ => None,
            })
            .flatten()
            .flatten()
            .collect();
        names.sort();
        names.dedup();
        names
    }
}

fn section<'a>(sheet: &'a mut Vec<Section>, title: &str) -> &'a mut Section {
    match sheet.iter().position(|s| s.title == title) {
        Some(i) => &mut sheet[i],
        None => {
            sheet.push(Section { title: title.to_string(), rows: Vec::new() });
            sheet.last_mut().unwrap()
        }
    }
}

fn layer(l: &FileLayer, apps: &HashMap<String, Vec<String>>, desktops: u32) -> Result<Layer> {
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

    let mut map: Vec<(Trigger, Action)> = Vec::new();
    for (trigger, send) in &l.map {
        let parsed = (|| -> Result<(Trigger, Action)> {
            let action = match send {
                FileSend::One(chord) => Action::Send { chord: Chord::parse(chord)?, hold: false },
                FileSend::Held { send, hold } => Action::Send { chord: Chord::parse(send)?, hold: *hold },
                FileSend::Many(chords) if chords.is_empty() => Action::Nothing,
                FileSend::Many(chords) => Action::Sequence(chords.iter().map(|c| Chord::parse(c)).collect::<Result<_>>()?),
            };
            Ok((Trigger::parse(trigger)?, action))
        })()
        .with_context(|| format!("{}: {trigger:?}", ctx()))?;
        map.push(parsed);
    }
    for (name, a) in l.actions.values().flatten() {
        if let Some(r) = &a.on_release {
            check_name(r).with_context(ctx)?;
        }
        for (name, key) in expand(name, &a.keys.list(), desktops).with_context(ctx)? {
            let trigger = Trigger::parse(&key).with_context(|| format!("{}: {name}", ctx()))?;
            map.push((trigger, Action::Run { name, repeat: a.repeat, on_release: a.on_release.clone() }));
        }
    }
    for (i, (t, _)) in map.iter().enumerate() {
        if map[..i].iter().any(|(earlier, _)| earlier == t) {
            bail!("{}: the same keys are used twice ({})", ctx(), describe(t));
        }
    }

    let let_through = l
        .let_through
        .as_ref()
        .map(|keys| keys.iter().map(|k| parse_key(k)).collect::<Result<Vec<_>>>())
        .transpose()
        .with_context(|| format!("{}: let_through", ctx()))?;

    let w = &l.when;
    let when = When { app: w.app.clone(), not_app: w.not_app.clone(), layer: w.layer.clone(), not_layer: w.not_layer.clone(), overview: w.overview, layout: w.layout.clone() };
    Ok(Layer { name: l.name.clone(), when, modifiers, map, stop: l.stop, let_through })
}

/// "desktop.goto.{n}" + "opt+{n}" -> desktop.goto.1 = opt+1, ...; {dir} -> left/h, down/j, ...
pub fn expand(name: &str, keys: &[String], desktops: u32) -> Result<Vec<(String, String)>> {
    check_name(name)?;
    let fills: Vec<(String, String)> = if name.contains("{n}") {
        (1..=desktops).map(|n| (n.to_string(), n.to_string())).collect()
    } else if name.contains("{dir}") {
        DIRECTIONS.iter().map(|(d, k)| (d.to_string(), k.to_string())).collect()
    } else {
        vec![(String::new(), String::new())]
    };
    let mut out = Vec::new();
    for (in_name, in_key) in &fills {
        let name = name.replace("{n}", in_name).replace("{dir}", in_name);
        for key in keys {
            out.push((name.clone(), key.replace("{n}", in_key).replace("{dir}", in_key)));
        }
    }
    Ok(out)
}

/// Action names go into Lua (`Actions["name"]()`), so only plain characters.
fn check_name(name: &str) -> Result<()> {
    if name.is_empty() || !name.chars().all(|c| c.is_ascii_alphanumeric() || "._-{}".contains(c)) {
        bail!("action name {name:?}: use letters, digits and . _ -");
    }
    Ok(())
}

fn describe(t: &Trigger) -> String {
    let mut parts: Vec<String> = t.mods.iter().map(|(m, side)| {
        let side = match side {
            Some(crate::keys::Side::Left) => "l",
            Some(crate::keys::Side::Right) => "r",
            None => "",
        };
        format!("{side}{}", format!("{m:?}").to_lowercase())
    }).collect();
    parts.push(crate::keys::key_name(t.key));
    parts.join("+")
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
