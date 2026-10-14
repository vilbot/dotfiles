#!/usr/bin/env python3
"""Generate the gruver16 JetBrains theme (editor scheme + UI theme plugin) from nvim/lua/palettes/gruver16.lua."""
import re, zipfile, pathlib

here = pathlib.Path(__file__).parent
lua = (here.parent / "nvim/lua/palettes/gruver16.lua").read_text()
c = {k: v.lstrip("#") for k, v in re.findall(r'(base0[0-9A-F])\s*=\s*"(#[0-9a-fA-F]{6})"', lua)}
b = lambda n: c[f"base{n}"]

def opt(name, fg=None, bg=None, style=None, effect=None, etype=None):
    o = ""
    if fg: o += f'<option name="FOREGROUND" value="{fg}" />'
    if bg: o += f'<option name="BACKGROUND" value="{bg}" />'
    if style: o += f'<option name="FONT_TYPE" value="{style}" />'
    if effect: o += f'<option name="EFFECT_COLOR" value="{effect}" /><option name="EFFECT_TYPE" value="{etype}" />'
    return f'    <option name="{name}"><value>{o}</value></option>\n'

attrs = [
    ("DEFAULT_KEYWORD", b("0E")), ("DEFAULT_STRING", b("0B")), ("DEFAULT_NUMBER", b("09")),
    ("DEFAULT_COMMENT", b("04")), ("DEFAULT_BLOCK_COMMENT", b("04")), ("DEFAULT_LINE_COMMENT", b("04")),
    ("DEFAULT_DOC_COMMENT", b("04")), ("DEFAULT_DOC_COMMENT_TAG", b("0C")),
    ("DEFAULT_FUNCTION_DECLARATION", b("0D")), ("DEFAULT_FUNCTION_CALL", b("0D")),
    ("DEFAULT_CLASS_NAME", b("0A")), ("DEFAULT_INTERFACE_NAME", b("0A")),
    ("DEFAULT_CONSTANT", b("0C")), ("DEFAULT_PREDEFINED_SYMBOL", b("0C")),
    ("DEFAULT_METADATA", b("0A")), ("DEFAULT_OPERATION_SIGN", b("07")),
    ("DEFAULT_PARENTHS", b("07")), ("DEFAULT_BRACKETS", b("07")), ("DEFAULT_BRACES", b("07")),
    ("DEFAULT_COMMA", b("07")), ("DEFAULT_DOT", b("07")), ("DEFAULT_SEMICOLON", b("07")),
    ("DEFAULT_IDENTIFIER", b("07")), ("DEFAULT_LOCAL_VARIABLE", b("07")),
    ("DEFAULT_PARAMETER", b("07")), ("DEFAULT_INSTANCE_FIELD", b("07")),
    ("DEFAULT_STATIC_FIELD", b("0C")), ("DEFAULT_INSTANCE_METHOD", b("0D")),
    ("DEFAULT_STATIC_METHOD", b("0D")), ("DEFAULT_LABEL", b("0A")),
    ("DEFAULT_TAG", b("0E")), ("DEFAULT_ATTRIBUTE", b("0A")), ("DEFAULT_ENTITY", b("09")),
    ("DEFAULT_VALID_STRING_ESCAPE", b("0C")), ("DEFAULT_INVALID_STRING_ESCAPE", b("08")),
    # web languages set their own keys in Darcula, so the DEFAULT_* fallbacks above never reach them
    ("HTML_TAG", b("04")), ("HTML_TAG_NAME", b("0E")), ("HTML_CUSTOM_TAG_NAME", b("0D")),
    ("HTML_ATTRIBUTE_NAME", b("0A")), ("HTML_ATTRIBUTE_VALUE", b("0B")),
    ("HTML_ENTITY_REFERENCE", b("09")), ("HTML_COMMENT", b("04")),
    ("XML_TAG", b("04")), ("XML_TAG_NAME", b("0E")), ("XML_CUSTOM_TAG_NAME", b("0D")),
    ("XML_NS_PREFIX", b("0C")), ("XML_ATTRIBUTE_NAME", b("0A")), ("XML_ATTRIBUTE_VALUE", b("0B")),
    ("XML_ENTITY_REFERENCE", b("09")), ("XML_PROLOGUE", b("04")), ("XML_TAG_DATA", b("07")),
    ("JSP_ACTION_AND_DIRECTIVE_NAME", b("0D")), ("JSP_ACTION_AND_DIRECTIVE_ATTRIBUTE_NAME", b("0A")),
    ("JSP_ACTION_AND_DIRECTIVE_ATTRIBUTE_VALUE", b("0B")), ("JSP_COMMENT", b("04")),
    ("EL_BOUNDS", b("0C")), ("EL_IDENTIFIER", b("07")), ("EL_KEYWORD", b("0E")),
    ("EL_NUMBER", b("09")), ("EL_STRING", b("0B")), ("EL_OPERATION_SIGN", b("07")),
    ("EL_DOT", b("07")), ("EL_PARENTHS", b("07")), ("EL_BRACKETS", b("07")), ("EL_COMMA", b("07")),
    ("CSS.TAG_NAME", b("0E")), ("CSS.CLASS_NAME", b("0A")), ("CSS.ID_SELECTOR", b("0D")),
    ("CSS.PSEUDO", b("0C")), ("CSS.PROPERTY_NAME", b("0D")), ("CSS.PROPERTY_VALUE", b("07")),
    ("CSS.IDENT", b("07")), ("CSS.KEYWORD", b("0E")), ("CSS.FUNCTION", b("0D")),
    ("CSS.NUMBER", b("09")), ("CSS.COLOR", b("09")), ("CSS.STRING", b("0B")),
    ("CSS.URL", b("0B")), ("CSS.IMPORTANT", b("08")), ("CSS.COMMENT", b("04")),
    ("JS.GLOBAL_VARIABLE", b("0C")), ("JS.GLOBAL_FUNCTION", b("0D")), ("JS.LOCAL_VARIABLE", b("07")),
    ("JS.PARAMETER", b("07")), ("JS.INSTANCE_MEMBER_FUNCTION", b("0D")), ("JS.REGEXP", b("0C")),
]
extra = [
    ("BAD_CHARACTER", dict(fg=b("08"), effect=b("08"), etype="2")),
    ("ERRORS_ATTRIBUTES", dict(effect=b("08"), etype="2")),
    ("WARNING_ATTRIBUTES", dict(effect=b("0E"), etype="2")),
    ("HYPERLINK_ATTRIBUTES", dict(fg=b("0D"), effect=b("0D"), etype="1")),
    ("MATCHED_BRACE_ATTRIBUTES", dict(bg=b("03"), style="1")),
    ("UNMATCHED_BRACE_ATTRIBUTES", dict(bg=b("08"), fg=b("00"))),
    ("TODO_DEFAULT_ATTRIBUTES", dict(fg="d85757", style="2")),
    ("SEARCH_RESULT_ATTRIBUTES", dict(fg=b("00"), bg=b("0A"))),
    ("TEXT_SEARCH_RESULT_ATTRIBUTES", dict(fg=b("00"), bg=b("0A"))),
    ("WRITE_SEARCH_RESULT_ATTRIBUTES", dict(fg=b("00"), bg=b("0E"))),
    ("IDENTIFIER_UNDER_CARET_ATTRIBUTES", dict(bg=b("02"))),
    ("WRITE_IDENTIFIER_UNDER_CARET_ATTRIBUTES", dict(bg=b("03"))),
    ("FOLDED_TEXT_ATTRIBUTES", dict(fg=b("07"), bg=b("01"))),
    ("INJECTED_LANGUAGE_FRAGMENT", dict(bg=b("01"))),
    # Darcula tints JSP regions; keep scriptlets subtly marked, drop the tint on tags/directives
    ("JSP_SCRIPTING_BACKGROUND", dict(bg=b("01"))),
    ("JSP_ACTION_AND_DIRECTIVE_BACKGROUND", dict(bg=b("00"))),
    ("TEXT_SEARCH_RESULT_ATTRIBUTES", dict(fg=b("00"), bg=b("0A"))),
    ("DIFF_INSERTED", dict(bg="2f3b2c")), ("DIFF_DELETED", dict(bg="3d2a2b")),
    ("DIFF_MODIFIED", dict(bg="3a3a2c")), ("DIFF_CONFLICT", dict(bg="3d2a2b")),
]

colors = {
    "BACKGROUND": b("00"), "CARET_ROW_COLOR": b("01"),
    "CARET_COLOR": b("07"), "CARET_ROW_COLOR": b("01"), "GUTTER_BACKGROUND": b("00"),
    "LINE_NUMBERS_COLOR": b("04"), "LINE_NUMBER_ON_CARET_ROW_COLOR": b("07"),
    "SELECTION_BACKGROUND": b("02"), "SELECTION_FOREGROUND": b("07"),
    "INDENT_GUIDE": b("02"), "SELECTED_INDENT_GUIDE": b("03"), "WHITESPACES": b("03"),
    "RIGHT_MARGIN_COLOR": b("02"), "TEARLINE_COLOR": b("02"), "METHOD_SEPARATORS_COLOR": b("02"),
    "READONLY_BACKGROUND": b("01"), "READONLY_FRAGMENT_BACKGROUND": b("01"),
    "ADDED_LINES_COLOR": b("0B"), "MODIFIED_LINES_COLOR": b("0E"), "DELETED_LINES_COLOR": b("08"),
    "WHITESPACES_MODIFIED_LINES_COLOR": b("0E"), "BORDER_LINES_COLOR": b("02"),
    "IGNORED_ADDED_LINES_BORDER_COLOR": b("03"), "IGNORED_MODIFIED_LINES_BORDER_COLOR": b("03"),
    "IGNORED_DELETED_LINES_BORDER_COLOR": b("03"),
}

x = '<scheme name="gruver16" version="142" parent_scheme="Darcula">\n'
x += '  <metaInfo><property name="ide">idea</property><property name="originalScheme">gruver16</property></metaInfo>\n'
x += '  <option name="FONT_SCALE" value="1.0" />\n  <colors>\n'
x += "".join(f'    <option name="{k}" value="{v}" />\n' for k, v in colors.items())
x += "  </colors>\n  <attributes>\n"
x += opt("TEXT", fg=b("07"), bg=b("00"))
for n, fg in attrs: x += opt(n, fg=fg)
x += opt("DEFAULT_KEYWORD", fg=b("0E")) if False else ""
for n, kw in extra: x += opt(n, **kw)
x += "  </attributes>\n</scheme>\n"
(here / "gruver16/gruver16.icls").write_text(x)

# UI theme (works in every JetBrains IDE incl. Rider)
import json
ui = {
    "name": "gruver16", "dark": True, "author": "vilgot", "editorScheme": "/gruver16.icls",
    "colors": {
        "bg": "#" + b("00"), "bg2": "#" + b("01"), "sel": "#" + b("02"), "border": "#" + b("02"),
        "fg": "#" + b("07"), "dim": "#" + b("04"), "accent": "#" + b("0D"), "hi": "#" + b("03"),
    },
    "ui": {
        "*": {
            "background": "bg", "foreground": "fg", "infoForeground": "dim",
            "selectionBackground": "sel", "selectionForeground": "fg",
            "selectionInactiveBackground": "bg2", "borderColor": "border",
            "disabledForeground": "dim", "hoverBackground": "bg2", "pressedBackground": "sel",
            "separatorColor": "border", "focusColor": "accent",
            "Button": {"startBackground": "bg2", "endBackground": "bg2", "startBorderColor": "border",
                       "endBorderColor": "border", "focusedBorderColor": "accent",
                       "default": {"startBackground": "accent", "endBackground": "accent",
                                   "foreground": "bg", "startBorderColor": "accent", "endBorderColor": "accent"}},
            "Component": {"focusColor": "accent", "borderColor": "border", "hoverIconColor": "fg"},
            "TextField": {"background": "bg2", "borderColor": "border"},
            "EditorPane": {"background": "bg"}, "EditorTabs": {"underlineColor": "accent", "background": "bg",
                                                               "hoverBackground": "bg2", "selectedBackground": "bg"},
            "ToolWindow": {"Header": {"background": "bg2"}}, "StatusBar": {"background": "bg2"},
            "Tree": {"background": "bg", "hash": "border"}, "List": {"background": "bg"},
            "Popup": {"borderColor": "border"}, "ScrollBar": {"thumbColor": "hi"},
        },
        "Panel": {"background": "bg"}, "Menu": {"background": "bg2"}, "MenuBar": {"background": "bg2"},
    },
}
(here / "gruver16/gruver16.theme.json").write_text(json.dumps(ui, indent=2) + "\n")

plugin_xml = """<idea-plugin>
  <id>dev.vilgot.gruver16</id>
  <name>gruver16</name>
  <vendor>vilgot</vendor>
  <description>gruver16 dark theme, ported from the nvim/wezterm config.</description>
  <depends>com.intellij.modules.platform</depends>
  <extensions defaultExtensionNs="com.intellij">
    <themeProvider id="dev.vilgot.gruver16" path="/gruver16.theme.json"/>
  </extensions>
</idea-plugin>
"""
jar = here / "gruver16/gruver16.jar"
with zipfile.ZipFile(jar, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("META-INF/plugin.xml", plugin_xml)
    z.write(here / "gruver16/gruver16.theme.json", "gruver16.theme.json")
    z.write(here / "gruver16/gruver16.icls", "gruver16.icls")
with zipfile.ZipFile(here / "gruver16/gruver16-plugin.zip", "w", zipfile.ZIP_DEFLATED) as z:
    z.write(jar, "gruver16/lib/gruver16.jar")
jar.unlink()
print("ok")
