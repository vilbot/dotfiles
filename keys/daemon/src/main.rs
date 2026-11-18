//! mackeys: a Mac keyboard on Hyprland.
//!
//!   mackeys <remap.toml>                    run (the systemd service)
//!   mackeys set <remap.toml> <changes.json> change actions' keys: {"window.close": ["cmd+q"]}
//!
//! Running: one thread per grabbed keyboard, one watching Hyprland's events, one looking for new
//! keyboards and config changes. They send `Msg`s to the main loop, which owns the engine and
//! the virtual keyboard. Desktop actions run in Hyprland as `Actions["name"]()` (hypr/actions.lua).
//!
//! After an action with `wait_for_layer` (F4 opens mission control's search box), keys are held
//! back until that layer is open, so they all land in it: hymission buffers keys while its search
//! box starts and can lose a key's release then, which makes the key repeat forever.

mod devices;
mod hyprland;

use anyhow::{Context, Result};
use devices::Press;
use evdev::KeyCode;
use evdev::uinput::VirtualDevice;
use mackeys::config::Config;
use mackeys::engine::{Engine, Out, World};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::cell::Cell;
use std::sync::mpsc::{Receiver, RecvTimeoutError, Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};

/// How long keys wait for a layer an action opens.
const LAYER_WAIT: Duration = Duration::from_millis(1000);

enum Msg {
    Keys(Vec<(KeyCode, Press, u64)>),
    KeyboardGone(PathBuf),
    Hyprland(hyprland::Event),
    ConfigChanged,
    HyprlandExited,
}

struct Desktop {
    app: String,
    layout: String,
    /// Open layer-shell surfaces by namespace (one per screen for some).
    layers: HashMap<String, usize>,
    /// False once Hyprland said mission control is closed, until an action runs (only actions
    /// open it), so typing doesn't ask Hyprland on every key.
    overview_maybe_open: Cell<bool>,
}

impl World for Desktop {
    fn app(&self) -> &str {
        &self.app
    }
    fn layer_open(&self, namespace: &str) -> bool {
        self.layers.get(namespace).is_some_and(|n| *n > 0)
    }
    fn layout(&self) -> &str {
        &self.layout
    }
    fn overview_open(&self) -> bool {
        let open = self.overview_maybe_open.get() && hyprland::overview_open();
        self.overview_maybe_open.set(open);
        open
    }
}

type Keys = Vec<(KeyCode, Press, u64)>;

struct Daemon {
    engine: Engine,
    output: VirtualDevice,
    desktop: Desktop,
    /// Keys are held back until this layer opens or the time is up.
    waiting: Option<(String, Instant)>,
    held_back: Keys,
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.iter().map(String::as_str).collect::<Vec<_>>().as_slice() {
        ["set", path, changes] => set(Path::new(path), changes),
        [path] => run(PathBuf::from(path)),
        _ => anyhow::bail!("usage: mackeys <remap.toml> | mackeys set <remap.toml> <changes.json>"),
    }
}

fn set(path: &Path, changes: &str) -> Result<()> {
    let changes: BTreeMap<String, Vec<String>> = serde_json::from_str(changes).context("changes: {\"action\": [\"keys\", ...]}")?;
    let text = std::fs::read_to_string(path)?;
    let new = mackeys::edit::set_keys(&text, &changes)?;
    std::fs::write(path, new)?;
    Ok(())
}

fn run(config_path: PathBuf) -> Result<()> {
    let config = load(&config_path)?;
    let device_names = config.devices.clone();
    write_sheet(&config);
    check_actions(&config);

    let desktop = Desktop {
        app: hyprland::active_class().unwrap_or_default(),
        layout: hyprland::layout(),
        layers: HashMap::new(),
        overview_maybe_open: Cell::new(true),
    };
    let mut d = Daemon { engine: Engine::new(config), output: devices::virtual_keyboard()?, desktop, waiting: None, held_back: Vec::new() };

    let (tx, rx) = channel();
    spawn_hyprland_watcher(tx.clone());
    spawn_scanner(tx, device_names, config_path.clone());

    while let Some(msg) = next(&rx, d.waiting.as_ref().map(|(_, until)| *until)) {
        match msg {
            None => d.stop_waiting()?,
            Some(Msg::Keys(keys)) => d.keys(keys)?,
            Some(Msg::KeyboardGone(path)) => {
                eprintln!("keyboard gone: {}", path.display());
                d.held_back.clear();
                let out = d.engine.release_all();
                d.perform(out)?;
            }
            Some(Msg::Hyprland(hyprland::Event::Focus(class))) => d.desktop.app = class,
            Some(Msg::Hyprland(hyprland::Event::Layout(layout))) => d.desktop.layout = layout,
            Some(Msg::Hyprland(hyprland::Event::LayerOpened(ns))) => {
                *d.desktop.layers.entry(ns.clone()).or_default() += 1;
                if d.waiting.as_ref().is_some_and(|(layer, _)| *layer == ns) {
                    d.stop_waiting()?;
                }
            }
            Some(Msg::Hyprland(hyprland::Event::LayerClosed(ns))) => {
                let n = d.desktop.layers.entry(ns).or_default();
                *n = n.saturating_sub(1);
            }
            Some(Msg::ConfigChanged) => match load(&config_path) {
                Ok(config) => {
                    write_sheet(&config);
                    check_actions(&config);
                    let out = d.engine.reload(config);
                    d.perform(out)?;
                    eprintln!("reloaded {}", config_path.display());
                }
                Err(e) => eprintln!("not reloading, {e:#}"),
            },
            Some(Msg::HyprlandExited) => {
                let out = d.engine.release_all();
                d.perform(out)?;
                eprintln!("Hyprland exited");
                return Ok(());
            }
        }
    }
    Ok(())
}

/// The next message; Some(None) when `until` passes first, None when every sender is gone.
fn next(rx: &Receiver<Msg>, until: Option<Instant>) -> Option<Option<Msg>> {
    match until {
        None => rx.recv().ok().map(Some),
        Some(until) => match rx.recv_timeout(until.saturating_duration_since(Instant::now())) {
            Ok(msg) => Some(Some(msg)),
            Err(RecvTimeoutError::Timeout) => Some(None),
            Err(RecvTimeoutError::Disconnected) => None,
        },
    }
}

impl Daemon {
    fn keys(&mut self, keys: Keys) -> Result<()> {
        for (key, press, ms) in keys {
            if self.waiting.is_some() {
                self.held_back.push((key, press, ms));
                continue;
            }
            let out = match press {
                Press::Down => self.engine.key(key, true, ms, &self.desktop),
                Press::Up => self.engine.key(key, false, ms, &self.desktop),
                Press::Repeat => self.engine.repeat(key),
            };
            self.perform(out)?;
        }
        Ok(())
    }

    fn stop_waiting(&mut self) -> Result<()> {
        self.waiting = None;
        let keys = std::mem::take(&mut self.held_back);
        self.keys(keys)
    }

    fn perform(&mut self, outs: Vec<Out>) -> Result<()> {
        for out in outs {
            match out {
                Out::Key(key, is_down) => devices::send(&mut self.output, key, is_down)?,
                Out::Run(action) => {
                    self.desktop.overview_maybe_open.set(true);
                    if let Err(e) = hyprland::eval(&format!("Actions[\"{action}\"]()")) {
                        eprintln!("action {action}: {e:#}");
                    }
                    if let Some(layer) = self.engine.config().waits.get(&action) {
                        if !self.desktop.layer_open(layer) {
                            self.waiting = Some((layer.clone(), Instant::now() + LAYER_WAIT));
                        }
                    }
                }
            }
        }
        Ok(())
    }
}

/// Logs the actions remap.toml names that hypr/actions.lua doesn't have.
fn check_actions(config: &Config) {
    let list: Vec<String> = config.action_names().iter().map(|n| format!("{n:?}")).collect();
    let lua = format!(
        "(function() local missing = {{}} for _, n in ipairs({{{}}}) do if not Actions[n] then missing[#missing + 1] = n end end \
         assert(#missing == 0, 'not in hypr/actions.lua: ' .. table.concat(missing, ', ')) end)()",
        list.join(",")
    );
    if let Err(e) = hyprland::eval(&lua) {
        eprintln!("{e:#}");
    }
}

fn load(path: &Path) -> Result<Config> {
    let text = std::fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;
    Config::parse(&text).with_context(|| format!("in {}", path.display()))
}

/// The sheet for Quickshell: $XDG_STATE_HOME/mackeys/keymap.json (~/.local/state/...).
fn write_sheet(config: &Config) {
    let state = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".local/state")));
    let Some(dir) = state.map(|s| s.join("mackeys")) else { return };
    let result = std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(dir.join("keymap.json"), mackeys::sheet::json(config)));
    if let Err(e) = result {
        eprintln!("writing {}: {e}", dir.join("keymap.json").display());
    }
}

fn spawn_hyprland_watcher(tx: Sender<Msg>) {
    std::thread::spawn(move || {
        let result = hyprland::watch(|event| {
            let _ = tx.send(Msg::Hyprland(event));
        });
        if let Err(e) = result {
            eprintln!("Hyprland events: {e:#}");
        }
        let _ = tx.send(Msg::HyprlandExited);
    });
}

/// Every second: grab keyboards that appeared, and report config file changes.
fn spawn_scanner(tx: Sender<Msg>, names: Vec<String>, config_path: PathBuf) {
    let grabbed: Arc<Mutex<HashSet<PathBuf>>> = Arc::default();
    std::thread::spawn(move || {
        let modified = |p: &Path| std::fs::metadata(p).and_then(|m| m.modified()).ok();
        let mut config_time: Option<SystemTime> = modified(&config_path);
        let mut failed: HashSet<PathBuf> = HashSet::new();
        loop {
            for path in devices::find(&names) {
                if grabbed.lock().unwrap().contains(&path) {
                    continue;
                }
                match devices::grab(&path) {
                    Ok(device) => {
                        eprintln!("grabbed {} ({})", path.display(), device.name().unwrap_or("?"));
                        failed.remove(&path);
                        grabbed.lock().unwrap().insert(path.clone());
                        spawn_reader(device, path, tx.clone(), grabbed.clone());
                    }
                    Err(e) if failed.insert(path.clone()) => eprintln!("{e:#}"),
                    Err(_) => {}
                }
            }
            let now = modified(&config_path);
            if now != config_time {
                config_time = now;
                let _ = tx.send(Msg::ConfigChanged);
            }
            std::thread::sleep(Duration::from_secs(1));
        }
    });
}

fn spawn_reader(mut device: evdev::Device, path: PathBuf, tx: Sender<Msg>, grabbed: Arc<Mutex<HashSet<PathBuf>>>) {
    std::thread::spawn(move || {
        while let Ok(keys) = devices::next_keys(&mut device) {
            if !keys.is_empty() && tx.send(Msg::Keys(keys)).is_err() {
                return;
            }
        }
        grabbed.lock().unwrap().remove(&path);
        let _ = tx.send(Msg::KeyboardGone(path));
    });
}
