//! mackeys: a Mac keyboard on Hyprland. Usage: mackeys <remap.toml>
//!
//! Threads: one per grabbed keyboard, one watching Hyprland's focus, one looking for new
//! keyboards and config changes. They all send `Msg`s to the main loop, which owns the engine
//! and the virtual keyboard.

mod devices;
mod hyprland;

use anyhow::{Context, Result};
use evdev::KeyCode;
use mackeys::config::Config;
use mackeys::engine::{Engine, World};
use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{Sender, channel};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

enum Msg {
    Keys(Vec<(KeyCode, bool, u64)>),
    KeyboardGone(PathBuf),
    Focus(String),
    ConfigChanged,
    HyprlandExited,
}

struct Desktop {
    app: String,
    runtime_dir: PathBuf,
}

impl World for Desktop {
    fn app(&self) -> &str {
        &self.app
    }
    fn flag(&self, name: &str) -> bool {
        self.runtime_dir.join(name).exists()
    }
}

fn main() -> Result<()> {
    let config_path = PathBuf::from(std::env::args().nth(1).context("usage: mackeys <remap.toml>")?);
    let config = load(&config_path)?;
    let device_names = config.devices.clone();

    let mut engine = Engine::new(config);
    let mut output = devices::virtual_keyboard()?;
    let mut desktop = Desktop {
        app: hyprland::active_class().unwrap_or_default(),
        runtime_dir: PathBuf::from(std::env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR not set")?),
    };

    let (tx, rx) = channel();
    spawn_focus_watcher(tx.clone());
    spawn_scanner(tx, device_names, config_path.clone());

    for msg in rx {
        match msg {
            Msg::Keys(keys) => {
                for (key, is_down, ms) in keys {
                    let out = engine.key(key, is_down, ms, &desktop);
                    devices::send(&mut output, &out)?;
                }
            }
            Msg::KeyboardGone(path) => {
                eprintln!("keyboard gone: {}", path.display());
                devices::send(&mut output, &engine.release_all())?;
            }
            Msg::Focus(class) => desktop.app = class,
            Msg::ConfigChanged => match load(&config_path) {
                Ok(config) => {
                    devices::send(&mut output, &engine.reload(config))?;
                    eprintln!("reloaded {}", config_path.display());
                }
                Err(e) => eprintln!("not reloading, {e:#}"),
            },
            Msg::HyprlandExited => {
                devices::send(&mut output, &engine.release_all())?;
                eprintln!("Hyprland exited");
                return Ok(());
            }
        }
    }
    Ok(())
}

fn load(path: &Path) -> Result<Config> {
    let text = std::fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;
    Config::parse(&text).with_context(|| format!("in {}", path.display()))
}

fn spawn_focus_watcher(tx: Sender<Msg>) {
    std::thread::spawn(move || {
        let result = hyprland::watch_focus(|class| {
            let _ = tx.send(Msg::Focus(class));
        });
        if let Err(e) = result {
            eprintln!("focus watcher: {e:#}");
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
