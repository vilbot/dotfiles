//! The focused window's class, from Hyprland's sockets.

use anyhow::{Context, Result};
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;

fn socket(name: &str) -> Result<PathBuf> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR not set")?;
    let instance = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").context("HYPRLAND_INSTANCE_SIGNATURE not set (not in Hyprland?)")?;
    Ok(PathBuf::from(runtime).join("hypr").join(instance).join(name))
}

/// Class of the focused window right now ("" when none).
pub fn active_class() -> Result<String> {
    let mut stream = UnixStream::connect(socket(".socket.sock")?)?;
    stream.write_all(b"activewindow")?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    Ok(reply.lines().find_map(|l| l.trim().strip_prefix("class: ")).unwrap_or("").to_string())
}

/// Calls `on_focus` with the class of every newly focused window. Returns when Hyprland exits.
pub fn watch_focus(mut on_focus: impl FnMut(String)) -> Result<()> {
    let stream = UnixStream::connect(socket(".socket2.sock")?)?;
    for line in BufReader::new(stream).lines() {
        let line = line?;
        if let Some(rest) = line.strip_prefix("activewindow>>") {
            let class = rest.split_once(',').map_or(rest, |(class, _title)| class);
            on_focus(class.to_string());
        }
    }
    Ok(())
}
