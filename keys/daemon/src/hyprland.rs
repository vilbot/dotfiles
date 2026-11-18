//! Talking to Hyprland over its sockets: requests (.socket.sock) and events (.socket2.sock).

use anyhow::{Context, Result};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;

fn socket(name: &str) -> Result<PathBuf> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR not set")?;
    let instance = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").context("HYPRLAND_INSTANCE_SIGNATURE not set (not in Hyprland?)")?;
    Ok(PathBuf::from(runtime).join("hypr").join(instance).join(name))
}

/// What `hyprctl <request>` would print.
pub fn request(request: &str) -> Result<String> {
    let mut stream = UnixStream::connect(socket(".socket.sock")?)?;
    stream.write_all(request.as_bytes())?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    Ok(reply)
}

/// Runs Lua in Hyprland. Ok(()) when it ran; Err with Hyprland's message when it didn't.
pub fn eval(lua: &str) -> Result<()> {
    let reply = request(&format!("eval {lua}"))?;
    if reply.trim() == "ok" { Ok(()) } else { anyhow::bail!("{}", reply.trim()) }
}

/// Class of the focused window right now ("" when none).
pub fn active_class() -> Result<String> {
    let reply = request("activewindow")?;
    Ok(reply.lines().find_map(|l| l.trim().strip_prefix("class: ")).unwrap_or("").to_string())
}

/// Whether mission control (the hymission plugin) is open.
pub fn overview_open() -> bool {
    request("hymission-overview-state").is_ok_and(|r| r.contains("\"active\":true"))
}

/// Our virtual keyboard as Hyprland names it ("mackeys-virtual-keyboard"): all typing goes
/// through it, so its layout is the one that counts.
fn keyboard() -> String {
    crate::devices::VIRTUAL_NAME.to_lowercase().replace(' ', "-")
}

/// The layout our keyboard has now ("" when Hyprland doesn't say).
pub fn layout() -> String {
    let devices: serde_json::Value = request("j/devices").ok().and_then(|r| serde_json::from_str(&r).ok()).unwrap_or_default();
    let ours = devices["keyboards"].as_array().and_then(|ks| ks.iter().find(|k| k["name"] == keyboard().as_str()).cloned());
    ours.and_then(|k| k["active_keymap"].as_str().map(String::from)).unwrap_or_default()
}

pub enum Event {
    Focus(String),
    /// Our keyboard switched layout.
    Layout(String),
    LayerOpened(String),
    LayerClosed(String),
}

/// Calls `on_event` for every focus change, layer opening/closing and layout switch. Returns when Hyprland exits.
pub fn watch(mut on_event: impl FnMut(Event)) -> Result<()> {
    let stream = UnixStream::connect(socket(".socket2.sock")?)?;
    for line in BufReader::new(stream).lines() {
        let line = line?;
        let Some((name, data)) = line.split_once(">>") else { continue };
        match name {
            "activewindow" => on_event(Event::Focus(data.split_once(',').map_or(data, |(class, _title)| class).to_string())),
            "openlayer" => on_event(Event::LayerOpened(data.to_string())),
            "closelayer" => on_event(Event::LayerClosed(data.to_string())),
            // "activelayout>>KEYBOARD,LAYOUT" (every keyboard reports; only ours counts)
            "activelayout" => {
                if let Some((kb, layout)) = data.rsplit_once(',') {
                    if kb == keyboard() {
                        on_event(Event::Layout(layout.to_string()))
                    }
                }
            }
            _ => {}
        }
    }
    Ok(())
}
