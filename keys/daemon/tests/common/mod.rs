//! The test harness both keymaps' tests use: `run` takes physical events ("+cmd +c -c -cmd",
//! "*f12" = auto-repeat, "wait:1500") and returns what apps get and which actions run
//! ("+leftctrl +c -c -leftctrl", "run:window.close").
#![allow(dead_code)]

use mackeys::engine::{Engine, Out, World};
use mackeys::keys::{key_name, parse_key};

pub struct Desk {
    pub app: &'static str,
    pub layout: &'static str,
    pub layers: &'static [&'static str],
    pub overview: bool,
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

/// Physical key names in tests: Mac modifier names, the rest as in remap.toml.
pub fn physical(name: &str) -> evdev::KeyCode {
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

pub fn run(e: &mut Engine, world: &Desk, events: &str) -> String {
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

