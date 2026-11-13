# RakaMod Settings UI Redesign

**Date:** 2026-11-13  
**Status:** Draft for review  
**Scope:** Settings shell layout only — no new features

## Goal

Replace the single scrolling settings list with a ToxiUI-inspired options shell: left sidebar navigation + right content pages. Keep every existing RakaMod setting and behavior; only regroup and restyle.

## Non-goals

- No new Misc features (nameplate fonts, profession slash commands, etc.)
- No AceConfig / external options libraries
- No KryoMOD-style top tab strip (superseded by Toxi-style sidebar)
- No copy of ToxiUI assets, strings, or proprietary chrome — original layout inspired by that shape

## Layout

```
+------------------------------------------+
| RakaMod                              [X] |
+----------+-------------------------------+
| Overlay  | Description                   |
| Player   | Enabled …                     |
| Frame    | (page controls)               |
| Zone Text|                               |
| AFK      |                               |
| Gradient |                               |
+----------+-------------------------------+
```

- Frame: movable, clamped, `DIALOG` strata, ESC-close via `UISpecialFrames` (existing pattern).
- Open/close: existing slash (`/raka` / current command) unchanged.
- Left sidebar: five nav buttons; one selected at a time (soft-blue highlight).
- Right pane: one page visible; hide/show pages on nav click; scrollable when content overflows.
- Title: **RakaMod**.
- Accent: soft blue (Ellesmere-ish), not Toxi gold. Dark panels, thin accent border/highlights.

## Sidebar labels

| Label (UI)     | Internal section | Notes                          |
|----------------|------------------|--------------------------------|
| Overlay        | `overlay`        |                                |
| Player Frame   | `reveal`         | db key stays `reveal`          |
| Zone Text      | `zoneText`       |                                |
| AFK            | `afk`            |                                |
| Gradient       | `gradient`       |                                |

Simple icons beside each label (stock/atlas or lightweight textures — not Toxi assets).

## Pages (existing controls only)

Each page structure:

1. Short **Description** (one line)
2. **Enabled** checkbox where the feature already has one
3. Remaining controls for that feature
4. Existing missing-module notes where applicable

### Overlay

- Description: Escape overlay buttons (collections / played / professions).
- Controls: Enabled, Collections, Played, Professions.

### Player Frame

- Description: Show the player frame when casting, low health, mouseover, or combat.
- Controls: Enabled, Casting, Health, Health percent, Mouseover, Combat, Pet.
- Note when EllesmereUI Unit Frames is not installed (existing).

### Zone Text

- Description: Custom zone change text appearance.
- Controls: Enabled, Size, Outline, Color.

### AFK

- Description: Full AFK screen behavior.
- Controls: Enabled, Camera pan.

### Gradient

- Description: Two-color health bar gradient via Ellesmere modules.
- Controls: Enabled, existing color swatches (start/end as today).
- Note when no Ellesmere health-bar module is installed (existing).

## Behavior

- All getters/setters continue to read/write `RakaMod.db` the same way.
- Apply hooks unchanged (`ZoneText:Apply`, `Gradient:Apply`, reveal/overlay/afk existing apply paths).
- `Settings:Refresh` / open path still syncs widget state from db and shows/hides dependency notes.
- Default selected page on open: Overlay (first sidebar item).

## Implementation sketch

- Rebuild `Settings.lua` shell: outer frame → sidebar column + content host.
- Per-page child frames; nav switches `Show`/`Hide`.
- Reuse current helper pattern (`AddCheck`, `AddSlider`, color swatches, outline cycle) scoped per page instead of one long `y` list.
- Soft-blue accent constants at top of file (r, g, b) for border/selected nav.
- No TOC changes expected unless new media files are added for icons.

## Success criteria

- Settings open with Toxi-like sidebar + content pages.
- All current options remain reachable and functional.
- Soft-blue accent; RakaMod title; Player Frame label for reveal.
- No new gameplay features introduced.

## Out of scope for later

- Mythic+ overlay buttons
- Media font/statusbar pickers (not in current settings UI)
- KryoMOD chrome parity
