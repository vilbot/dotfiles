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

pub enum Event {
    Focus(String),
    LayerOpened(String),
    LayerClosed(String),
}

/// Calls `on_event` for every focus change and layer opening/closing. Returns when Hyprland exits.
pub fn watch(mut on_event: impl FnMut(Event)) -> Result<()> {
    let stream = UnixStream::connect(socket(".socket2.sock")?)?;
    for line in BufReader::new(stream).lines() {
        let line = line?;
        let Some((name, data)) = line.split_once(">>") else { continue };
        match name {
            "activewindow" => on_event(Event::Focus(data.split_once(',').map_or(data, |(class, _title)| class).to_string())),
            "openlayer" => on_event(Event::LayerOpened(data.to_string())),
            "closelayer" => on_event(Event::LayerClosed(data.to_string())),
            _ => {}
        }
    }
    Ok(())
}
