//! What the real keys/remap.toml does, key by key.
//!
//! `run` takes physical events ("+cmd +c -c -cmd", "wait:1500") and returns what apps get
//! ("+leftctrl +c -c -leftctrl").

use mackeys::config::Config;
use mackeys::engine::{Engine, World};
use mackeys::keys::{key_name, parse_key};
use std::collections::BTreeSet;

struct Desk {
    app: &'static str,
    flags: &'static [&'static str],
}

impl World for Desk {
    fn app(&self) -> &str {
        self.app
    }
    fn flag(&self, name: &str) -> bool {
        self.flags.contains(&name)
    }
}

const CHROME: Desk = Desk { app: "google-chrome", flags: &[] };
const GHOSTTY: Desk = Desk { app: "com.mitchellh.ghostty", flags: &[] };
const ZED: Desk = Desk { app: "dev.zed.Zed", flags: &[] };

fn engine() -> Engine {
    Engine::new(Config::parse(include_str!("../../remap.toml")).expect("remap.toml parses"))
}

/// Physical key names in tests: Mac modifier names, the rest as in remap.toml.
fn physical(name: &str) -> evdev::KeyCode {
    let kernel = match name {
        "cmd" => "leftmeta",
        "opt" => "leftalt",
        "ropt" => "rightalt",
        "ctrl" => "leftctrl",
        "shift" => "leftshift",
        "caps" => "capslock",
        other => other,
    };
    parse_key(kernel).unwrap()
}

fn run(e: &mut Engine, world: &Desk, events: &str) -> String {
    let mut now = 0;
    let mut out = Vec::new();
    for ev in events.split_whitespace() {
        if let Some(ms) = ev.strip_prefix("wait:") {
            now += ms.parse::<u64>().unwrap();
            continue;
        }
        now += 10;
        let (is_down, name) = (ev.starts_with('+'), &ev[1..]);
        for (key, down) in e.key(physical(name), is_down, now, world) {
            out.push(format!("{}{}", if down { '+' } else { '-' }, key_name(key)));
        }
    }
    out.join(" ")
}

#[test]
fn cmd_c_copies() {
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +c -c -cmd"), "+leftctrl +c -c -leftctrl");
    assert_eq!(run(&mut engine(), &GHOSTTY, "+cmd +c -c -cmd"), "+leftctrl +leftshift +c -c -leftctrl -leftshift");
}

#[test]
fn physical_ctrl_is_super_in_apps_and_ctrl_in_terminals() {
    assert_eq!(run(&mut engine(), &CHROME, "+ctrl +c -c -ctrl"), "+leftmeta +c -c -leftmeta");
    assert_eq!(run(&mut engine(), &GHOSTTY, "+ctrl +c -c -ctrl"), "+leftctrl +c -c -leftctrl");
}

#[test]
fn caps_tapped_is_esc_held_is_ctrl() {
    assert_eq!(run(&mut engine(), &CHROME, "+caps -caps"), "+esc -esc");
    assert_eq!(run(&mut engine(), &CHROME, "+caps wait:1500 -caps"), "");
    assert_eq!(run(&mut engine(), &GHOSTTY, "+caps +c -c -caps"), "+leftctrl +c -c -leftctrl");
}

#[test]
fn zed_window_moves_need_one_tap_each() {
    // Caps+W then H: Zed must see Super held the whole time, never let go and pressed again.
    assert_eq!(run(&mut engine(), &ZED, "+caps +w -w +h -h -caps"), "+leftmeta +w -w +h -h -leftmeta");
}

#[test]
fn zed_gets_mac_text_keys_untouched() {
    assert_eq!(run(&mut engine(), &ZED, "+cmd +left -left -cmd"), "+leftctrl +left -left -leftctrl");
    assert_eq!(run(&mut engine(), &ZED, "+ctrl +a -a -ctrl"), "+leftmeta +a -a -leftmeta");
}

#[test]
fn cmd_tab_keeps_alt_down_until_cmd_goes_up() {
    assert_eq!(
        run(&mut engine(), &CHROME, "+cmd +tab -tab +tab -tab -cmd"),
        "+leftctrl -leftctrl +leftalt +tab -tab +tab -tab -leftalt"
    );
    assert_eq!(
        run(&mut engine(), &CHROME, "+cmd +tab -tab +shift +tab -tab -shift -cmd"),
        "+leftctrl -leftctrl +leftalt +tab -tab +leftshift +tab -tab -leftshift -leftalt"
    );
}

#[test]
fn desktop_keys() {
    assert_eq!(run(&mut engine(), &GHOSTTY, "+cmd +space -space -cmd"), "+leftctrl -leftctrl +leftmeta +f13 -f13 -leftmeta");
    assert_eq!(run(&mut engine(), &CHROME, "+opt +tab -tab -opt"), "+leftalt -leftalt +leftmeta +f14 -f14 -leftmeta");
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +q -q -cmd"), "+leftctrl -leftctrl +leftalt +f4 -f4 -leftalt");
}

#[test]
fn f_row_sends_what_is_printed_and_right_option_gives_f_keys() {
    assert_eq!(run(&mut engine(), &CHROME, "+f1 -f1"), "+brightnessdown -brightnessdown");
    assert_eq!(run(&mut engine(), &CHROME, "+ropt +f1 -f1 -ropt"), "+rightalt -rightalt +f1 -f1");
    // left Option + F1 is not the plain F-key
    assert_eq!(run(&mut engine(), &CHROME, "+opt +f1 -f1 -opt"), "+leftalt +brightnessdown -brightnessdown -leftalt");
}

#[test]
fn mac_text_editing() {
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +left -left -cmd"), "+leftctrl -leftctrl +home -home");
    assert_eq!(run(&mut engine(), &CHROME, "+opt +backspace -backspace -opt"), "+leftalt -leftalt +leftctrl +backspace -backspace -leftctrl");
    assert_eq!(run(&mut engine(), &GHOSTTY, "+opt +backspace -backspace -opt"), "+leftalt -leftalt +leftctrl +w -w -leftctrl");
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +h -h -cmd"), "+leftctrl -leftctrl");
}

#[test]
fn emacs_keys_outside_terminals() {
    assert_eq!(run(&mut engine(), &CHROME, "+ctrl +a -a -ctrl"), "+leftmeta -leftmeta +home -home");
    assert_eq!(run(&mut engine(), &CHROME, "+ctrl +k -k -ctrl"), "+leftmeta -leftmeta +leftshift +end -end -leftshift +backspace -backspace");
    assert_eq!(run(&mut engine(), &GHOSTTY, "+ctrl +a -a -ctrl"), "+leftctrl +a -a -leftctrl");
}

#[test]
fn ctrl_tab_keeps_ctrl_down_in_browsers() {
    assert_eq!(
        run(&mut engine(), &CHROME, "+ctrl +tab -tab +tab -tab -ctrl"),
        "+leftmeta -leftmeta +leftctrl +tab -tab +tab -tab -leftctrl"
    );
}

#[test]
fn mission_control_hjkl() {
    let open = Desk { app: "google-chrome", flags: &["hymission-open"] };
    let search = Desk { app: "google-chrome", flags: &["hymission-open", "hymission-search"] };
    assert_eq!(run(&mut engine(), &open, "+h -h"), "+left -left");
    assert_eq!(run(&mut engine(), &search, "+h -h"), "+h -h");
    assert_eq!(run(&mut engine(), &search, "+opt +h -h -opt"), "+leftalt -leftalt +f24 -f24 +up -up");
}

#[test]
fn command_palette_gets_ctrl_letters_untouched() {
    let palette = Desk { app: "google-chrome", flags: &["quickshell-palette-open"] };
    assert_eq!(run(&mut engine(), &palette, "+ctrl +n -n -ctrl"), "+leftmeta +n -n -leftmeta");
}

#[test]
fn typing_after_shift_is_plain() {
    assert_eq!(run(&mut engine(), &GHOSTTY, "+shift +i -i -shift +space -space"), "+leftshift +i -i -leftshift +space -space");
}

/// Whatever is pressed, in whatever order and app: once every physical key is up, every key
/// apps saw go down has come back up, and no key went down twice without going up.
#[test]
fn every_key_comes_back_up() {
    let keys = ["cmd", "opt", "ropt", "ctrl", "shift", "caps", "tab", "c", "h", "a", "left", "f1", "space", "backspace"];
    let worlds = [&CHROME, &GHOSTTY, &ZED];
    let mut seed: u64 = 7;
    let mut random = |n: usize| {
        seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (seed >> 33) as usize % n
    };
    for _ in 0..300 {
        let mut e = engine();
        let world = worlds[random(worlds.len())];
        let mut physical_down: BTreeSet<&str> = BTreeSet::new();
        let mut events = Vec::new();
        for _ in 0..12 {
            let key = keys[random(keys.len())];
            if physical_down.remove(key) {
                events.push(format!("-{key}"));
            } else {
                physical_down.insert(key);
                events.push(format!("+{key}"));
            }
        }
        events.extend(physical_down.iter().map(|k| format!("-{k}")));
        let out = run(&mut e, world, &events.join(" "));

        let mut down: BTreeSet<&str> = BTreeSet::new();
        for ev in out.split_whitespace() {
            let (is_down, key) = (ev.starts_with('+'), &ev[1..]);
            if is_down {
                down.insert(key);
            } else {
                down.remove(key);
            }
        }
        assert!(down.is_empty(), "{} in {}: still down {down:?}\nout: {out}", events.join(" "), world.app);
    }
}

#[test]
fn config_errors_say_where() {
    let bad = include_str!("../../remap.toml").replace("\"cmd+q\" = \"alt+f4\"", "\"cmd+q\" = \"alt+f99\"");
    let err = format!("{:#}", Config::parse(&bad).err().expect("bad key is an error"));
    assert!(err.contains("desktop") && err.contains("cmd+q") && err.contains("f99"), "{err}");
}
