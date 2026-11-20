//! What the None desktop's tty/keys.toml does (harness: common/mod.rs).

mod common;
use common::*;
use mackeys::config::Config;
use mackeys::engine::Engine;
use serde_json::{Value, json};
use std::collections::BTreeMap;

const TEXT: &str = include_str!("../../../tty/keys.toml");

fn engine() -> Engine {
    Engine::new(Config::parse(TEXT).expect("tty/keys.toml parses"))
}

const FOOT: Desk = Desk { app: "foot", layout: "English (US)", layers: &[], overview: false };
const CHROME: Desk = Desk { app: "google-chrome", ..FOOT };
const SETTINGS: Desk = Desk { app: "none-settings", ..FOOT };
const LAUNCHER: Desk = Desk { layers: &["tty-launcher"], ..FOOT };

fn sheet() -> Value {
    let config = Config::parse(TEXT).unwrap();
    serde_json::from_str(&mackeys::sheet::json(&config, "/x/tty/keys.toml")).unwrap()
}

fn rows(sheet: &Value) -> Vec<Value> {
    sheet["groups"].as_array().unwrap().iter().flat_map(|g| g["rows"].as_array().unwrap().clone()).collect()
}

#[test]
fn desktop_keys() {
    assert_eq!(run(&mut engine(), &FOOT, "+opt +1 -1 -opt"), "+leftalt run:desktop.goto.1 -leftalt");
    assert_eq!(run(&mut engine(), &FOOT, "+cmd +q -q -cmd"), "+leftctrl run:window.close -leftctrl");
    assert_eq!(run(&mut engine(), &FOOT, "+f5 -f5"), "run:panel.control");
    assert_eq!(run(&mut engine(), &FOOT, "+cmd +c -c -cmd"), "+leftctrl +leftshift +c -c -leftctrl -leftshift");
}

#[test]
fn caps_tapped_is_esc_also_where_esc_is_bound() {
    assert_eq!(run(&mut engine(), &FOOT, "+caps -caps"), "+esc -esc");
    // Opt+Shift+Esc logs out; Caps tapped is Esc for bindings too
    let mut text = TEXT.replace(r#""session.exit" = { keys = "opt+shift+esc""#, r#""session.exit" = { keys = "esc""#);
    text = text.replace(r#""launcher.close" = { keys = "esc","#, r#""launcher.close" = { keys = [],"#);
    let mut e = Engine::new(Config::parse(&text).unwrap());
    assert_eq!(run(&mut e, &FOOT, "+caps -caps"), "run:session.exit");
}

#[test]
fn launcher_keys_reach_it_untouched() {
    // the app does them: nothing runs, the keys go through as typed (Cmd is Ctrl, Ctrl is Super)
    assert_eq!(run(&mut engine(), &LAUNCHER, "+ctrl +j -j -ctrl"), "+leftmeta +j -j -leftmeta");
    assert_eq!(run(&mut engine(), &LAUNCHER, "+cmd +j -j -cmd"), "+leftctrl +j -j -leftctrl");
    // and Ctrl+N isn't the emacs Down there
    assert_eq!(run(&mut engine(), &LAUNCHER, "+ctrl +n -n -ctrl"), "+leftmeta +n -n -leftmeta");
    // desktop keys still work while it's open
    assert_eq!(run(&mut engine(), &LAUNCHER, "+opt +2 -2 -opt"), "+leftalt run:desktop.goto.2 -leftalt");
}

#[test]
fn keymap_json_says_which_keys_each_app_gets() {
    let s = sheet();
    assert_eq!(s["file"], "/x/tty/keys.toml");
    let next = &s["apps"]["launcher"]["launcher.next"];
    // down, physical Ctrl+J (Super), Ctrl+N (Super), Cmd+J (Ctrl)
    assert_eq!(*next, json!([
        { "mods": [], "code": 108 },
        { "mods": ["super"], "code": 36 },
        { "mods": ["super"], "code": 49 },
        { "mods": ["ctrl"], "code": 36 },
    ]));
    assert_eq!(s["apps"]["launcher"]["launcher.prev"][1], json!({ "mods": ["shift"], "code": 15 }));
    assert_eq!(s["apps"]["settings"]["settings.undo"], json!([{ "mods": ["ctrl"], "code": 44 }]));
    // a row knows its layer and app, and every key it stands for, written one way
    let goto = rows(&s).into_iter().find(|r| r["action"] == "desktop.goto.{n}").unwrap();
    assert_eq!(goto["layer"], "desktop");
    assert_eq!(goto["app"], Value::Null);
    assert_eq!(goto["triggers"], json!(["opt+1", "opt+2", "opt+3", "opt+4", "opt+5"]));
    assert_eq!(goto["keysLabel"], json!(["⌥ 1–5"]));
    let lock = rows(&s).into_iter().find(|r| r["action"] == "session.lock").unwrap();
    assert_eq!(lock["triggers"], json!(["ctrl+cmd+q"]));
}

#[test]
fn settings_app_keys_pass_and_text_editing_still_works_there() {
    assert_eq!(run(&mut engine(), &SETTINGS, "+j -j"), "+j -j");
    assert_eq!(run(&mut engine(), &SETTINGS, "+cmd +left -left -cmd"), "+leftctrl -leftctrl +home -home");
}

#[test]
fn arrow_templates() {
    let text = TEXT.replace(r#""window.focus.{dir}" = { keys = "opt+{dir}""#, r#""window.focus.{dir}" = { keys = ["opt+{dir}", "opt+{arrow}"]"#);
    let mut e = Engine::new(Config::parse(&text).unwrap());
    assert_eq!(run(&mut e, &CHROME, "+opt +up -up -opt"), "+leftalt run:window.focus.up -leftalt");
    // a template in the keys but not the name (or the other way) is a mistake
    let bad = TEXT.replace(r#""window.close" = { keys = "cmd+q""#, r#""window.close" = { keys = "cmd+{n}""#);
    assert!(Config::parse(&bad).is_err());
}

#[test]
fn shortcuts_page_saves_into_this_file() {
    let changes = BTreeMap::from([("launcher.favorite".to_string(), vec!["cmd+d".to_string()])]);
    let new = mackeys::edit::set_keys(TEXT, &changes).unwrap();
    assert!(new.contains(r#""launcher.favorite" = { keys = "cmd+d", label"#));
    assert_eq!(new.lines().count(), TEXT.lines().count());
}
