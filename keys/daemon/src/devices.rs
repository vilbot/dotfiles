//! Physical keyboards (taken over exclusively) and the virtual keyboard apps get keys from.

use anyhow::{Context, Result};
use evdev::uinput::VirtualDevice;
use evdev::{AttributeSet, Device, EventSummary, EventType, InputEvent, KeyCode};
use std::path::{Path, PathBuf};
use std::time::{Duration, UNIX_EPOCH};

pub const VIRTUAL_NAME: &str = "mackeys virtual keyboard";

/// Input device paths whose name contains one of `names` and that have letter keys.
pub fn find(names: &[String]) -> Vec<PathBuf> {
    let mut found = Vec::new();
    for (path, device) in evdev::enumerate() {
        let name = device.name().unwrap_or("");
        let has_letters = device.supported_keys().is_some_and(|k| k.contains(KeyCode::KEY_A));
        if has_letters && name != VIRTUAL_NAME && names.iter().any(|n| name.contains(n.as_str())) {
            found.push(path);
        }
    }
    found.sort();
    found
}

/// Opens a keyboard and grabs it once no key on it is down (a key let go after the grab would
/// otherwise stay down for the desktop).
pub fn grab(path: &Path) -> Result<Device> {
    let mut device = Device::open(path).with_context(|| format!("opening {}", path.display()))?;
    for _ in 0..200 {
        if device.get_key_state()?.iter().next().is_none() {
            break;
        }
        std::thread::sleep(Duration::from_millis(10));
    }
    device.grab().with_context(|| format!("grabbing {} (is Toshy still running?)", path.display()))?;
    Ok(device)
}

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum Press {
    Down,
    Up,
    /// The keyboard's auto-repeat while a key is held.
    Repeat,
}

/// Blocks for the next keys: (key, what happened, time in ms).
pub fn next_keys(device: &mut Device) -> Result<Vec<(KeyCode, Press, u64)>> {
    let mut keys = Vec::new();
    for event in device.fetch_events()? {
        if let EventSummary::Key(_, key, value) = event.destructure() {
            let press = match value {
                0 => Press::Up,
                1 => Press::Down,
                _ => Press::Repeat,
            };
            let ms = event.timestamp().duration_since(UNIX_EPOCH).map_or(0, |d| d.as_millis() as u64);
            keys.push((key, press, ms));
        }
    }
    Ok(keys)
}

/// The keyboard apps see. Only keys, no mouse buttons, so it is a plain keyboard to libinput.
pub fn virtual_keyboard() -> Result<VirtualDevice> {
    let mut keys = AttributeSet::<KeyCode>::new();
    for code in (1..0x100).chain(0x160..0x2c0) {
        keys.insert(KeyCode::new(code));
    }
    Ok(VirtualDevice::builder()?.name(VIRTUAL_NAME).with_keys(&keys)?.build()?)
}

/// Sends key events, each in its own report so they arrive in order.
pub fn send(device: &mut VirtualDevice, key: KeyCode, is_down: bool) -> Result<()> {
    device.emit(&[InputEvent::new(EventType::KEY.0, key.code(), is_down as i32)])?;
    Ok(())
}
