# Settings window: ConfUI-style restyle (v2)

Status: Implemented, pending in-game visual review.

## Scope

Rebuild the Settings window to follow the ConfUI mockup. Custom code only (no Ace3 / AceGUI / ElvUI).

Excluded on purpose: ElvUI branding or text, social network icons, yellow/gold accent (blue is the accent everywhere).

## Layout

- Neutral charcoal palette, blue accent.
- Sidebar: brand, search box, grouped nav with icons. Search filters nav entries by page name, tab name, and every control label.
- Content: page title and description, a top tab row, then the page body.
- Footer: version, `Reset Page` (two-click confirm), `Apply & Reload` (`ReloadUI`).

## Pages and tabs

| Nav | Tabs |
| --- | --- |
| General | General, About |
| Features | Background |
| Game Menu | Panels |
| AFK | Behavior |
| Player Frame | Triggers |
| Zone Text | Style |
| Gradient Mode | Health, Bars, Resources, Nameplates |

Each tab is a scrolling page made of titled, bordered cards in one or two columns (`ctx.Card(title, col)`; `col` nil means full width).

## Controls

- Checkbox (box + label) for options.
- ON/OFF toggle button for master switches.
- Slider with a value box on the right.
- Dropdown select (Zone Text outline, nameplate fade direction).
- Color swatch and gradient pair rows.

## Master switches

Game Menu, AFK, Player Frame, Zone Text, and Gradient Mode each have an `Enabled` ON/OFF switch in the page header (same line as the title), above all of that page's tabs. While it is off, the page's tabs are dimmed (still editable). The sidebar shows a status dot for these pages (blue = on, grey = off). "Addon not installed" notes appear next to the switch. Nameplates keeps its own switch inside its tab.

## Behavior

- All controls keep their existing `RakaModDB` bindings and refresh hooks.
- `Reset Page` resets every control on the current nav page to `Core.DEFAULTS` (exposed on `RakaMod.Core.DEFAULTS`).
- Later: split `Settings.lua` by page (see personal reminder).
