//! none-caret: shows the keyboard layout at the text cursor when it changes, as macOS does.
//!
//! The shell can't see where the text cursor is: apps tell only an input method (text-input-v3,
//! the cursor rectangle). So this is an input method that types nothing (it never grabs the
//! keyboard); its one popup surface, which Hyprland places at the text cursor, shows the layout's
//! name for about a second (fading in and out) after mackeys' keyboard switches layout (Hyprland's socket2 "activelayout").
//!
//! While a text field is focused (the input method is "active") it writes 1 to
//! $XDG_RUNTIME_DIR/none-caret, else 0, and removes it when it quits: the shell's corner shows the
//! layout only when there's no text cursor to show it at (tty/shell/Status.qml).
//! Colours: None's theme (~/.local/state/none/theme.json); the box is drawn like tty/shell/Line.qml.

use anyhow::{Context, Result, bail};
use pangocairo::{cairo, pango};
use std::{
    ffi::CString,
    io::{BufRead, BufReader, Read, Write},
    os::{
        fd::{AsFd, AsRawFd, FromRawFd, OwnedFd},
        unix::net::UnixStream,
    },
    path::PathBuf,
    sync::{OnceLock, mpsc},
    time::{Duration, Instant},
};
use wayland_client::{
    Connection, Dispatch, QueueHandle, delegate_noop,
    globals::{GlobalListContents, registry_queue_init},
    protocol::{wl_buffer, wl_compositor, wl_registry, wl_seat, wl_shm, wl_shm_pool, wl_surface},
};
use wayland_protocols_misc::zwp_input_method_v2::client::{
    zwp_input_method_manager_v2::ZwpInputMethodManagerV2,
    zwp_input_method_v2::{self, ZwpInputMethodV2},
    zwp_input_popup_surface_v2::ZwpInputPopupSurfaceV2,
};

const KEYBOARD: &str = "mackeys-virtual-keyboard"; // all typing goes through it (as in Status.qml)
// About a second in all: in (a fade, rising 6px, as tty/shell/Line.qml), held, out
const FADE_IN: f64 = 0.10; // seconds
const HOLD: f64 = 0.76;
const FADE_OUT: f64 = 0.14;
const RISE: f64 = 6.0; // px
const FRAME: Duration = Duration::from_millis(16);
const FONT: &str = "Hack"; // tty/shell/Ui.qml: Hack 14px, a box with 12/6 padding and a 1px border
const FONT_PX: f64 = 14.0;
const PAD_X: i32 = 12;
const PAD_Y: i32 = 6;

static FLAG: OnceLock<CString> = OnceLock::new();

struct State {
    active: bool,
    pending: bool,
    scale: i32,
    unavailable: bool,
    flag: PathBuf,
}

impl State {
    fn set_active(&mut self, on: bool) {
        self.active = on;
        let _ = std::fs::write(&self.flag, if on { "1" } else { "0" });
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for State {
    fn event(_: &mut Self, _: &wl_registry::WlRegistry, _: wl_registry::Event, _: &GlobalListContents, _: &Connection, _: &QueueHandle<Self>) {}
}
delegate_noop!(State: ignore wl_compositor::WlCompositor);
delegate_noop!(State: ignore wayland_client::protocol::wl_region::WlRegion);
delegate_noop!(State: ignore wl_shm::WlShm);
delegate_noop!(State: ignore wl_shm_pool::WlShmPool);
delegate_noop!(State: ignore wl_seat::WlSeat);
delegate_noop!(State: ignore ZwpInputMethodManagerV2);
delegate_noop!(State: ignore ZwpInputPopupSurfaceV2);

impl Dispatch<wl_buffer::WlBuffer, ()> for State {
    fn event(_: &mut Self, buffer: &wl_buffer::WlBuffer, event: wl_buffer::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_buffer::Event::Release = event {
            buffer.destroy();
        }
    }
}

impl Dispatch<wl_surface::WlSurface, ()> for State {
    fn event(state: &mut Self, _: &wl_surface::WlSurface, event: wl_surface::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        if let wl_surface::Event::PreferredBufferScale { factor } = event {
            state.scale = factor.max(1);
        }
    }
}

impl Dispatch<ZwpInputMethodV2, ()> for State {
    fn event(state: &mut Self, _: &ZwpInputMethodV2, event: zwp_input_method_v2::Event, _: &(), _: &Connection, _: &QueueHandle<Self>) {
        match event {
            zwp_input_method_v2::Event::Activate => state.pending = true,
            zwp_input_method_v2::Event::Deactivate => state.pending = false,
            zwp_input_method_v2::Event::Done => {
                let on = state.pending;
                state.set_active(on)
            }
            zwp_input_method_v2::Event::Unavailable => state.unavailable = true,
            _ => {}
        }
    }
}

/// #rrggbb -> (r, g, b) in 0..1
fn rgb(hex: &str) -> (f64, f64, f64) {
    let v = u32::from_str_radix(hex.trim_start_matches('#'), 16).unwrap_or(0);
    (((v >> 16) & 255) as f64 / 255.0, ((v >> 8) & 255) as f64 / 255.0, (v & 255) as f64 / 255.0)
}

/// None's current colours for the box: background, border, text (gruver16 until one is picked)
fn colours() -> [(f64, f64, f64); 3] {
    let state = std::env::var("XDG_STATE_HOME").unwrap_or_else(|_| format!("{}/.local/state", std::env::var("HOME").unwrap_or_default()));
    let theme: serde_json::Value = std::fs::read_to_string(format!("{state}/none/theme.json"))
        .ok()
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_default();
    let get = |slot: &str, default: &str| rgb(theme.get(slot).and_then(|v| v.as_str()).unwrap_or(default));
    [get("base00", "#282828"), get("base03", "#4a4f59"), get("base06", "#c3c4ca")]
}

/// draws TEXT in a box, ARGB8888 (cairo's ARGB32 is the same in memory): (width, height, pixels)
fn draw(text: &str, scale: i32, opacity: f64) -> Result<(i32, i32, Vec<u8>)> {
    let mut font = pango::FontDescription::from_string(FONT);
    font.set_absolute_size(FONT_PX * pango::SCALE as f64);
    let measure = cairo::Context::new(&cairo::ImageSurface::create(cairo::Format::ARgb32, 1, 1)?)?;
    let layout = pangocairo::functions::create_layout(&measure);
    layout.set_font_description(Some(&font));
    layout.set_text(text);
    let (tw, th) = layout.pixel_size();
    let (w, h) = (tw + 2 * PAD_X, th + 2 * PAD_Y);
    let full_h = h + RISE as i32; // room below for the box's way up

    let mut surface = cairo::ImageSurface::create(cairo::Format::ARgb32, w * scale, full_h * scale)?;
    {
        let cr = cairo::Context::new(&surface)?;
        cr.scale(scale as f64, scale as f64);
        cr.translate(0.0, (RISE * (1.0 - opacity)).round());
        cr.push_group();
        let [bg, border, ink] = colours();
        cr.set_source_rgb(bg.0, bg.1, bg.2);
        cr.paint()?;
        cr.set_source_rgb(border.0, border.1, border.2);
        cr.set_line_width(1.0);
        cr.rectangle(0.5, 0.5, w as f64 - 1.0, h as f64 - 1.0);
        cr.stroke()?;
        cr.set_source_rgb(ink.0, ink.1, ink.2);
        cr.move_to(PAD_X as f64, PAD_Y as f64);
        let layout = pangocairo::functions::create_layout(&cr);
        layout.set_font_description(Some(&font));
        layout.set_text(text);
        pangocairo::functions::show_layout(&cr, &layout);
        cr.pop_group_to_source()?;
        cr.paint_with_alpha(opacity)?;
    }
    surface.flush();
    let (pw, ph) = (w * scale, full_h * scale);
    let stride = surface.stride() as usize;
    let data = surface.data()?;
    // wl_shm gets rows of exactly pw * 4 bytes; cairo may pad them
    let px = data.chunks(stride).take(ph as usize).flat_map(|row| &row[..pw as usize * 4]).copied().collect();
    Ok((pw, ph, px))
}

/// the pixels in shared memory, as a buffer the compositor reads
fn buffer(shm: &wl_shm::WlShm, qh: &QueueHandle<State>, w: i32, h: i32, px: &[u8]) -> Result<wl_buffer::WlBuffer> {
    let fd = unsafe { libc::memfd_create(c"none-caret".as_ptr(), libc::MFD_CLOEXEC) };
    if fd < 0 {
        bail!("memfd_create: {}", std::io::Error::last_os_error());
    }
    let fd = unsafe { OwnedFd::from_raw_fd(fd) };
    let mut file = std::fs::File::from(fd);
    file.write_all(px)?;
    let pool = shm.create_pool(file.as_fd(), px.len() as i32, qh, ());
    let buffer = pool.create_buffer(0, w, h, w * 4, wl_shm::Format::Argb8888, qh, ());
    pool.destroy();
    Ok(buffer)
}

/// Hyprland's sockets: $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/NAME
fn hypr_socket(name: &str) -> Result<PathBuf> {
    let run = std::env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR")?;
    let sig = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").context("not in Hyprland")?;
    Ok(PathBuf::from(run).join("hypr").join(sig).join(name))
}

/// the layout mackeys' keyboard has now (hyprctl devices)
fn current_layout() -> Option<String> {
    let mut s = UnixStream::connect(hypr_socket(".socket.sock").ok()?).ok()?;
    s.write_all(b"j/devices").ok()?;
    let mut out = String::new();
    s.read_to_string(&mut out).ok()?;
    let v: serde_json::Value = serde_json::from_str(&out).ok()?;
    v["keyboards"].as_array()?.iter().find(|k| k["name"] == KEYBOARD)?["active_keymap"].as_str().map(String::from)
}

/// every layout mackeys' keyboard switches to, sent to TX (and a byte to WAKE for the main loop's poll)
fn watch_layouts(tx: mpsc::Sender<String>, mut wake: UnixStream) -> Result<()> {
    let socket = UnixStream::connect(hypr_socket(".socket2.sock")?)?;
    for line in BufReader::new(socket).lines() {
        let line = line?;
        let Some(rest) = line.strip_prefix("activelayout>>") else { continue };
        let Some((keyboard, name)) = rest.rsplit_once(',') else { continue };
        if keyboard == KEYBOARD {
            tx.send(name.to_string())?;
            wake.write_all(b"x")?;
        }
    }
    bail!("Hyprland's event socket closed")
}

fn would_block(e: &wayland_client::backend::WaylandError) -> bool {
    matches!(e, wayland_client::backend::WaylandError::Io(io) if io.kind() == std::io::ErrorKind::WouldBlock)
}

/// quitting: no flag left behind saying a text cursor is there
extern "C" fn on_signal(_: libc::c_int) {
    if let Some(p) = FLAG.get() {
        unsafe { libc::unlink(p.as_ptr()) };
    }
    unsafe { libc::_exit(0) };
}

fn main() -> Result<()> {
    let flag = PathBuf::from(std::env::var("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR")?).join("none-caret");
    FLAG.set(CString::new(flag.to_string_lossy().as_bytes())?).ok();
    unsafe {
        libc::signal(libc::SIGTERM, on_signal as *const () as libc::sighandler_t);
        libc::signal(libc::SIGINT, on_signal as *const () as libc::sighandler_t);
        libc::signal(libc::SIGHUP, on_signal as *const () as libc::sighandler_t);
    }
    let hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        if let Some(p) = FLAG.get() {
            unsafe { libc::unlink(p.as_ptr()) };
        }
        hook(info)
    }));
    let result = run(flag.clone());
    let _ = std::fs::remove_file(&flag);
    result
}

fn run(flag: PathBuf) -> Result<()> {
    let conn = Connection::connect_to_env().context("no Wayland display")?;
    let (globals, mut queue) = registry_queue_init::<State>(&conn)?;
    let qh = queue.handle();
    let compositor: wl_compositor::WlCompositor = globals.bind(&qh, 4..=6, ())?;
    let shm: wl_shm::WlShm = globals.bind(&qh, 1..=1, ())?;
    let seat: wl_seat::WlSeat = globals.bind(&qh, 1..=9, ())?;
    let manager: ZwpInputMethodManagerV2 = globals.bind(&qh, 1..=1, ()).context("the compositor has no input-method-v2")?;
    let im = manager.get_input_method(&seat, &qh, ());
    let surface = compositor.create_surface(&qh, ());
    let _popup = im.get_input_popup_surface(&surface, &qh, ());
    let nothing = compositor.create_region(&qh, ());
    surface.set_input_region(Some(&nothing)); // clicks go through it
    nothing.destroy();

    let mut state = State { active: false, pending: false, scale: 1, unavailable: false, flag };
    state.set_active(false);
    queue.roundtrip(&mut state)?;
    if state.unavailable {
        bail!("another input method is running");
    }

    let (tx, rx) = mpsc::channel();
    let (wake_rx, wake_tx) = UnixStream::pair()?;
    wake_rx.set_nonblocking(true)?;
    std::thread::spawn(move || {
        if let Err(e) = watch_layouts(tx, wake_tx) {
            eprintln!("none-caret: {e:#}");
            std::process::exit(1); // the main loop can't tell; Hyprland restarting starts us again
        }
    });

    let mut last = current_layout().unwrap_or_default();
    let mut shown_at: Option<Instant> = None; // the popup's animation, while it runs
    loop {
        queue.dispatch_pending(&mut state)?;
        if state.unavailable {
            bail!("another input method took over");
        }
        // a full socket or a partial message only means "later": WouldBlock isn't an error here
        if let Err(e) = conn.flush() {
            if !would_block(&e) { return Err(e.into()) }
        }
        let timeout = if shown_at.is_some() { FRAME.as_millis() as i32 } else { -1 };
        if let Some(guard) = queue.prepare_read() {
            let mut fds = [
                libc::pollfd { fd: guard.connection_fd().as_raw_fd(), events: libc::POLLIN, revents: 0 },
                libc::pollfd { fd: wake_rx.as_raw_fd(), events: libc::POLLIN, revents: 0 },
            ];
            let n = unsafe { libc::poll(fds.as_mut_ptr(), 2, timeout) };
            if n > 0 && fds[0].revents & libc::POLLIN != 0 {
                if let Err(e) = guard.read() {
                    if !would_block(&e) { return Err(e.into()) }
                }
            } else {
                drop(guard);
            }
        }
        queue.dispatch_pending(&mut state)?;

        let mut drain = [0u8; 64];
        while (&wake_rx).read(&mut drain).is_ok_and(|n| n > 0) {}
        for name in rx.try_iter() {
            if name == last {
                continue; // every keyboard reports; only a change counts
            }
            last = name;
            if state.active {
                shown_at = Some(Instant::now()); // (again, if it's still up)
            }
        }
        if let Some(start) = shown_at {
            let t = start.elapsed().as_secs_f64();
            let ease = |x: f64| 1.0 - (1.0 - x.clamp(0.0, 1.0)).powi(3); // out-cubic, as the shell's
            let opacity = if t < FADE_IN {
                ease(t / FADE_IN)
            } else if t < FADE_IN + HOLD {
                1.0
            } else {
                1.0 - ease((t - FADE_IN - HOLD) / FADE_OUT)
            };
            if t >= FADE_IN + HOLD + FADE_OUT || !state.active {
                surface.attach(None, 0, 0);
                surface.commit();
                shown_at = None;
            } else {
                let (w, h, px) = draw(&last, state.scale, opacity)?;
                let buf = buffer(&shm, &qh, w, h, &px)?;
                surface.set_buffer_scale(state.scale);
                surface.attach(Some(&buf), 0, 0);
                surface.damage_buffer(0, 0, w, h);
                surface.commit();
            }
        }
    }
}
