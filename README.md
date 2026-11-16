# RakaMod

Companion addon for [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui). One folder runs on Retail 12.x and WoW Forever (Interface `120105, 16001`).

## Features

- Escape menu overlay: collections, played time, professions, with shared background fade and grain
- Player frame reveal (casting, health below 100%, mouseover, combat)
- Full-screen AFK mode with the latest EllesmereUI changelog, class-coloured character info, model animation and a whisper log
- Per-class, NPC and unit-state health bar gradients on Ellesmere unit, raid and nameplate frames, plus optional power, castbar, class resource and nameplate threat / classification gradients
- ElvUI-style settings window (`/rakamod`, `/rmod` or `/rm`), minimap icon and an entry under Esc > Options > AddOns

## Settings window

The settings window (v0.6.0) follows an ElvUI-config layout: a sidebar with the RakaMod crest, a search box and icon navigation; a header with the title, version and close button; a tab row above a bordered body with titled option groups in two columns; and a footer with **Apply & Reload UI**.

- **Search** (top of the sidebar) filters the page list and the options on the open page by label, group title, page and tab name. It jumps to the first page or tab that matches; clear it to see everything again.
- **Accent color**: General > Colors. Pick a preset (gold, blue, green, red, purple, cyan, white), a custom color through the color picker, or your class color (follows the current character and spec). The whole window recolors immediately, no reload. The default is blue.
- Pages with a master switch show **Enabled** (ON/OFF) on the right of the tab row. Pages without a nav icon show text only.
- Text uses `Rk Roboto Condensed` by default; the **Fonts** page changes it (and the AFK mode font) live; nav icons are `Media/ui/nav-*.tga` (regenerate with `python3 tools/make_nav_icons.py`).

Layout lives in `UI/` (`Theme.lua` palette, fonts and accent, `Widgets.lua` controls, `Shell.lua` window chrome, `ColorPicker.lua`); `Settings.lua` holds the pages and option bindings. Setting keys are unchanged; the new keys are `general.accent` and the `fonts` table documented below.

## Install

1. Install EllesmereUI. RakaMod declares it as a required dependency and will not load without it.
2. Copy this folder to `World of Warcraft/_retail_/Interface/AddOns/RakaMod` (or `_classic_era_`/Forever's AddOns folder). The folder name must be `RakaMod`.
3. `/reload`, then `/rakamod`.

Fonts saved variables (`RakaModDB.fonts`):

| Key | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Master switch of the Fonts page. When `false` RakaMod overrides no font: the settings window and AFK mode use the game's standard font (`STANDARD_TEXT_FONT`, so Ellesmere or Blizzard font edits prevail), the Game Menu overlay panels keep their original font, and `uiSize` is ignored. |
| `ui` | `Rk Roboto Condensed` | General Font: text of the settings window. |
| `uiSize` | `15` | General font size: point size (6 to 24) of the settings window's option text. Headings and small text keep their ratio to it. Applied live. |
| `afk` | `Rk RakaMod` | AFK Font: AFK mode text. Applies the next time AFK mode starts. |
| `overlay` | `Game Default` | Game Menu Overlay Font: RakaMod's Played / Professions / Collections panels beside the Escape menu. `Game Default` keeps the game's own font. |

Gradient Mode (`RakaModDB.gradient`): the toolbar **Enabled** switch is the master for the whole feature (health + bars + resources + nameplates). While it is off, nothing paints. While it is on, Health always paints; Bars / Resources / Nameplates each have their own switch (all off by default) so you can paint only health, only nameplates, and so on.

| Key | Default | Paints |
| --- | --- | --- |
| `powerEnabled` | `false` | Power bars, colored by power type from `power` (mana, rage, focus, energy, runic power, alt power). Other power types keep Ellesmere's color. |
| `castbarEnabled` | `false` | Cast bars, `castbar.regular` or `castbar.nonInterruptible`. |
| `resourcesEnabled` | `false` | Pips of your class resource bar from `classResources` (combo points 1-5, holy power, chi, soul shards, shadow orbs, runes by spec). |
| `nameplatesEnabled` | `false` | Nameplate health: dead / offline / tapped states first, then `nameplateThreat`, then `nameplateClassification`, then the Health tab colors. `nameplateFadeDirection` (`LEFT` / `RIGHT`) sets which way those bars fade. |

Bars are found on Ellesmere frames by field name (health, power, cast, class power and so on), so a bar only paints when Ellesmere exposes it under such a name. Every `SetGradient` call is protected, so an unknown bar layout never raises an error.

Optional Ellesmere modules unlock features: UnitFrames (Reveal, unit gradients), RaidFrames (party and raid gradients) and Nameplates (nameplate gradients). RakaMod does not write to any Ellesmere saved variables.

## Libraries

Everything RakaMod needs is bundled in `Libs/`, so it does not rely on EllesmereUI or any other addon exporting them: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 and LibSharedMedia-3.0.

## Media

All fonts, status bars, backgrounds and shapes live in `Media/` and are registered by RakaMod itself into its bundled LibSharedMedia. Every registered name starts with `Rk ` followed by the original name, for example `Rk Doris PP` or `Rk ToxiUI Clean`, so they show up in any LibSharedMedia picker (ElvUI, Ellesmere, Plater and others) without clashing with other packs. No separate shared-media addon is required.

Saved settings from older versions that stored an unprefixed media name are migrated once on first load.

Authors and licences for every asset are listed in [`Media/CREDITS.md`](Media/CREDITS.md). Several assets are marked **Unknown** or restricted; resolve those before redistributing the addon.

## Development

```
lua tests/run.lua        # logic, gradient, load smoke and settings UI tests (Lua 5.1 and 5.4)
luacheck .               # lint, WoW globals declared in .luacheckrc
```

`tests/smoke_load.lua` loads every file in TOC order against a stubbed WoW API, checks for load errors and stray globals, verifies that every registered media file exists with an `Rk ` name, and checks that the Esc > Options category registers. CI (`.github/workflows/ci.yml`) runs the tests on Lua 5.1 and 5.4 and luacheck on every push and pull request.

`tests/test_ui.lua` drives the settings window through a stateful WoW stub (`tests/wowstub.lua`): accent switching and live repaint, search filtering, Apply & Reload UI, close and the ways of opening the window.

Design notes and plans are in `docs/superpowers/`. The original v1 design carries a status banner listing where it has been superseded.

## Licence

All rights reserved by the author for RakaMod's own code and art (`LICENSE.txt`). Bundled third-party assets keep their own licences, see `Media/CREDITS.md`.
