//! Changing an action's keys in remap.toml, keeping its comments and layout (Shortcuts page).

use crate::config::Config;
use anyhow::{Context, Result, bail};
use std::collections::BTreeMap;
use toml_edit::{Array, DocumentMut, Item, Value};

/// `changes`: action as written ("window.focus.{dir}") -> its new keys (empty = unbound).
/// Returns the new file text, which parses as a config.
pub fn set_keys(text: &str, changes: &BTreeMap<String, Vec<String>>) -> Result<String> {
    let mut doc: DocumentMut = text.parse().context("remap.toml isn't valid TOML")?;
    for (action, keys) in changes {
        let entry = find(&mut doc, action).with_context(|| format!("no action {action:?} in remap.toml"))?;
        let value: Value = match keys.as_slice() {
            [one] => one.as_str().into(),
            many => Value::Array(many.iter().map(String::as_str).collect::<Array>()),
        };
        match entry {
            Item::Value(Value::InlineTable(t)) => {
                t.insert("keys", value);
            }
            Item::Table(t) => {
                t.insert("keys", Item::Value(value));
            }
            _ => bail!("{action:?} isn't a table with keys"),
        }
    }
    let new = doc.to_string();
    Config::parse(&new)?;
    Ok(new)
}

fn find<'a>(doc: &'a mut DocumentMut, action: &str) -> Option<&'a mut Item> {
    let layers = doc.get_mut("layer")?.as_array_of_tables_mut()?;
    for layer in layers.iter_mut() {
        let Some(sections) = layer.get_mut("actions").and_then(Item::as_table_like_mut) else { continue };
        for (_, section) in sections.iter_mut() {
            if let Some(entry) = section.as_table_like_mut().and_then(|s| s.get_mut(action)) {
                return Some(entry);
            }
        }
    }
    None
}
