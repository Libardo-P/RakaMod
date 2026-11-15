# RakaMod

Companion addon for [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui). One folder runs on Retail 12.x and WoW Forever (Interface `120105, 16001`).

## Features

- Escape menu overlay: collections, played time, professions, with shared background fade and grain
- Player frame reveal (casting, health above 100% including absorbs, mouseover, combat)
- Zone text styling
- Full-screen AFK mode with the latest EllesmereUI changelog, class-coloured character info, model animation and a whisper log
- Per-class, NPC and unit-state health bar gradients on Ellesmere unit, raid and nameplate frames
- Settings window (`/rakamod`, `/rmod` or `/rm`), minimap icon and an entry under Esc > Options > AddOns

## Install

1. Install EllesmereUI. RakaMod declares it as a required dependency and will not load without it.
2. Copy this folder to `World of Warcraft/_retail_/Interface/AddOns/RakaMod` (or `_classic_era_`/Forever's AddOns folder). The folder name must be `RakaMod`.
3. `/reload`, then `/rakamod`.

Optional Ellesmere modules unlock features: UnitFrames (Reveal, unit gradients), RaidFrames (party and raid gradients) and Nameplates (nameplate gradients). RakaMod does not write to any Ellesmere saved variables.

## Libraries

Everything RakaMod needs is bundled in `Libs/`, so it does not rely on EllesmereUI or any other addon exporting them: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 and LibSharedMedia-3.0.

## Media

All fonts, status bars, backgrounds and shapes live in `Media/` and are registered by RakaMod itself into its bundled LibSharedMedia. Every registered name starts with `Rk ` followed by the original name, for example `Rk Doris PP` or `Rk ToxiUI Clean`, so they show up in any LibSharedMedia picker (ElvUI, Ellesmere, Plater and others) without clashing with other packs. No separate shared-media addon is required.

Saved settings from older versions that stored an unprefixed media name are migrated once on first load.

Authors and licences for every asset are listed in [`Media/CREDITS.md`](Media/CREDITS.md). Several assets are marked **Unknown** or restricted; resolve those before redistributing the addon.

## Development

```
lua tests/run.lua        # logic, gradient and load smoke tests (Lua 5.1 and 5.4)
luacheck .               # lint, WoW globals declared in .luacheckrc
```

`tests/smoke_load.lua` loads every file in TOC order against a stubbed WoW API, checks for load errors and stray globals, verifies that every registered media file exists with an `Rk ` name, and checks that the Esc > Options category registers. CI (`.github/workflows/ci.yml`) runs the tests on Lua 5.1 and 5.4 and luacheck on every push and pull request.

Design notes and plans are in `docs/superpowers/`. The original v1 design carries a status banner listing where it has been superseded.

## Licence

All rights reserved by the author for RakaMod's own code and art (`LICENSE.txt`). Bundled third-party assets keep their own licences, see `Media/CREDITS.md`.
