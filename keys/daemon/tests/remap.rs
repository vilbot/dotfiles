//! What the real keys/remap.toml does, key by key.
//!
//! `run` takes physical events ("+cmd +c -c -cmd", "*f12" = auto-repeat, "wait:1500") and
//! returns what apps get and which actions run ("+leftctrl +c -c -leftctrl", "run:window.close").

use mackeys::config::Config;
use mackeys::engine::{Engine, Out, World};
use mackeys::keys::{key_name, parse_key};
use std::collections::{BTreeMap, BTreeSet};

struct Desk {
    app: &'static str,
    layout: &'static str,
    layers: &'static [&'static str],
    overview: bool,
}

impl World for Desk {
    fn app(&self) -> &str {
        self.app
    }
    fn layer_open(&self, namespace: &str) -> bool {
        self.layers.contains(&namespace)
    }
    fn overview_open(&self) -> bool {
        self.overview
    }
    fn layout(&self) -> &str {
        self.layout
    }
}

const fn app(app: &'static str) -> Desk {
    Desk { app, layout: "English (US)", layers: &[], overview: false }
}
const CHROME: Desk = app("google-chrome");
const GHOSTTY: Desk = app("com.mitchellh.ghostty");
const ZED: Desk = app("dev.zed.Zed");

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
        let (kind, name) = ev.split_at(1);
        let result = match kind {
            "*" => e.repeat(physical(name)),
            _ => e.key(physical(name), kind == "+", now, world),
        };
        for o in result {
            out.push(match o {
                Out::Key(key, down) => format!("{}{}", if down { '+' } else { '-' }, key_name(key)),
                Out::Run(action) => format!("run:{action}"),
            });
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
fn cmd_tab_switches_apps_and_commits_when_cmd_goes_up() {
    assert_eq!(
        run(&mut engine(), &CHROME, "+cmd +tab -tab +tab -tab -cmd"),
        "+leftctrl run:app.switch.next run:app.switch.next -leftctrl run:app.switch.commit"
    );
    assert_eq!(
        run(&mut engine(), &CHROME, "+cmd +tab -tab +shift +tab -tab -shift -cmd"),
        "+leftctrl run:app.switch.next +leftshift run:app.switch.prev -leftshift -leftctrl run:app.switch.commit"
    );
}

#[test]
fn desktop_actions() {
    assert_eq!(run(&mut engine(), &GHOSTTY, "+cmd +space -space -cmd"), "+leftctrl run:launcher -leftctrl");
    assert_eq!(run(&mut engine(), &CHROME, "+opt +tab -tab -opt"), "+leftalt run:desktop.next -leftalt");
    assert_eq!(run(&mut engine(), &CHROME, "+opt +3 -3 -opt"), "+leftalt run:desktop.goto.3 -leftalt");
    assert_eq!(run(&mut engine(), &CHROME, "+opt +h -h -opt"), "+leftalt run:window.focus.left -leftalt");
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +q -q -cmd"), "+leftctrl run:window.close -leftctrl");
}

#[test]
fn held_keys_repeat_only_repeating_actions() {
    assert_eq!(run(&mut engine(), &CHROME, "+f12 *f12 *f12 -f12"), "run:volume.up run:volume.up run:volume.up");
    assert_eq!(run(&mut engine(), &CHROME, "+f3 *f3 -f3"), "run:overview.desktop");
    assert_eq!(run(&mut engine(), &CHROME, "+a *a -a"), "+a -a");
}

#[test]
fn f_row_runs_what_is_printed_and_right_option_gives_f_keys() {
    assert_eq!(run(&mut engine(), &CHROME, "+f1 -f1"), "run:brightness.down");
    assert_eq!(run(&mut engine(), &CHROME, "+ropt +f1 -f1 -ropt"), "+rightalt -rightalt +f1 -f1");
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
    let open = Desk { overview: true, ..CHROME };
    let search = Desk { overview: true, layers: &["hymission-search"], ..CHROME };
    assert_eq!(run(&mut engine(), &open, "+h -h"), "+left -left");
    assert_eq!(run(&mut engine(), &open, "+opt +tab -tab -opt"), "+leftalt run:overview.desktop.next -leftalt");
    assert_eq!(run(&mut engine(), &search, "+h -h"), "+h -h");
    assert_eq!(run(&mut engine(), &search, "+opt +h -h -opt"), "+leftalt -leftalt +f24 -f24 +up -up");
}

/// Typing doesn't reach the window behind mission control; its own keys and actions still work.
#[test]
fn mission_control_drops_typing() {
    let open = Desk { overview: true, ..CHROME };
    let search = Desk { overview: true, layers: &["hymission-search"], ..CHROME };
    assert_eq!(run(&mut engine(), &open, "+c -c +cmd +c -c -cmd"), "+leftctrl -leftctrl");
    assert_eq!(run(&mut engine(), &open, "+esc -esc +3 -3 +slash -slash"), "+esc -esc +3 -3 +slash -slash");
    assert_eq!(run(&mut engine(), &open, "+f4 -f4 +opt +1 -1 -opt"), "run:overview.all +leftalt run:desktop.goto.1 -leftalt");
    assert_eq!(run(&mut engine(), &search, "+c -c"), "+c -c");
    assert_eq!(run(&mut engine(), &CHROME, "+c -c"), "+c -c");
    assert_eq!(run(&mut engine(), &open, "+cmd +space -space -cmd"), "+leftctrl -leftctrl");
    assert_eq!(run(&mut engine(), &search, "+cmd +space -space -cmd"), "+leftctrl -leftctrl");
    assert_eq!(run(&mut engine(), &CHROME, "+cmd +space -space -cmd"), "+leftctrl run:launcher -leftctrl");
}

#[test]
fn f4_waits_for_the_search_box() {
    let config = Config::parse(include_str!("../../remap.toml")).unwrap();
    assert_eq!(config.waits.get("overview.all").map(String::as_str), Some("hymission-search"));
}

#[test]
fn command_palette_gets_ctrl_letters_untouched() {
    let palette = Desk { layers: &["quickshell-palette"], ..CHROME };
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
        for ev in out.split_whitespace().filter(|ev| !ev.starts_with("run:")) {
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
    let bad = include_str!("../../remap.toml").replace("\"ropt+f1\" = \"f1\"", "\"ropt+f1\" = \"f99\"");
    let err = format!("{:#}", Config::parse(&bad).err().expect("bad key is an error"));
    assert!(err.contains("desktop") && err.contains("ropt+f1") && err.contains("f99"), "{err}");
}

#[test]
fn sheet_lists_actions_with_mac_keys() {
    let config = Config::parse(include_str!("../../remap.toml")).unwrap();
    let sheet: serde_json::Value = serde_json::from_str(&mackeys::sheet::json(&config)).unwrap();
    let rows: Vec<&serde_json::Value> = sheet["groups"].as_array().unwrap().iter().flat_map(|g| g["rows"].as_array().unwrap()).collect();
    let label = |action: &str| rows.iter().find(|r| r["action"] == action).map(|r| r["keysLabel"].clone()).unwrap();
    assert_eq!(label("window.focus.{dir}"), serde_json::json!(["⌥ H J K L"]));
    assert_eq!(label("desktop.move.{n}"), serde_json::json!(["⌥ ⇧ 1–5"]));
    assert_eq!(label("help.keys"), serde_json::json!(["⌥ ?"]));
    assert_eq!(label("desktop.last"), serde_json::json!([]));
    let titles: Vec<&str> = sheet["groups"].as_array().unwrap().iter().map(|g| g["title"].as_str().unwrap()).collect();
    assert_eq!(titles.first(), Some(&"Desktops"));
    assert!(titles.contains(&"Mission control"));
}

#[test]
fn shortcuts_page_edits_keep_the_file_and_refuse_clashes() {
    let text = include_str!("../../remap.toml");
    let set = |action: &str, keys: &[&str]| {
        let changes = BTreeMap::from([(action.to_string(), keys.iter().map(|k| k.to_string()).collect())]);
        mackeys::edit::set_keys(text, &changes)
    };
    let new = set("window.close", &["opt+w"]).unwrap();
    assert!(new.contains(r#""window.close" = { keys = "opt+w", label = "Close window" }"#), "{new}");
    assert_eq!(new.lines().count(), text.lines().count());
    assert!(new.contains("# the keyboard's screenshot key"));
    assert!(set("window.pin", &[]).unwrap().contains(r#""window.pin" = { keys = [], label"#));

    let err = format!("{:#}", set("window.float", &["opt+f"]).unwrap_err());
    assert!(err.contains("twice") && err.contains("opt+f"), "{err}");
    assert!(set("no.such.action", &["opt+w"]).is_err());
}

#[test]
fn swerty_opt_types_the_symbols_on_the_swedish_letters() {
    let swerty = Desk { layout: "Sweden - Swerty", ..GHOSTTY };
    // ö -> ; (AltGr is the right Alt key; the left one is let go first)
    assert_eq!(run(&mut engine(), &swerty, "+opt +semicolon -semicolon -opt"), "+leftalt -leftalt +rightalt +semicolon -semicolon -rightalt");
    // Shift+Opt+ä -> "
    assert_eq!(
        run(&mut engine(), &swerty, "+opt +shift +apostrophe -apostrophe -shift -opt"),
        // Shift let go while Opt is still held: plain Alt again until Opt goes up
        "+leftalt +leftshift -leftalt +rightalt +apostrophe -apostrophe -leftshift -rightalt +leftalt -leftalt"
    );
    // å and the key after it -> [ ]
    assert_eq!(run(&mut engine(), &swerty, "+opt +leftbrace -leftbrace +rightbrace -rightbrace -opt"),
        "+leftalt -leftalt +rightalt +leftbrace -leftbrace +rightbrace -rightbrace -rightalt");
    // Opt stays Alt elsewhere, and desktop keys still work
    assert_eq!(run(&mut engine(), &swerty, "+opt +b -b -opt"), "+leftalt +b -b -leftalt");
    assert_eq!(run(&mut engine(), &swerty, "+opt +h -h -opt"), "+leftalt run:window.focus.left -leftalt");
    // on the US layout Opt+; is Alt+;
    assert_eq!(run(&mut engine(), &GHOSTTY, "+opt +semicolon -semicolon -opt"), "+leftalt +semicolon -semicolon -leftalt");
}
