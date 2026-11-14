# Game Menu Overlay Restyle Design

**Date:** 2026-11-14  
**Status:** Draft for review  
**Branch:** `develop`  
**Depends on:** Escape overlay (`2026-11-12-rakamod-design.md`)

## Goal

Restyle the Escape-menu **left stats overlay** to match the Toxi-style print: blue ALL-CAPS section headers with underlines, label-left / value-right rows, clearer section spacing, and Played class bars that read as tinted rows. Icons are deferred (slots may exist; textures stay hidden or unset until a later pass).

## Non-goals

- Restyling Blizzard / Ellesmere `GameMenuFrame` buttons (Options, Shop, AddOns, etc.)
- Character info block (class icon, record, spec name) — follow-up
- Changing overlay data sources or settings toggles (`enabled` / `collections` / `played` / `professions`)
- Shipping profession / collection icons in this pass (user will add later)
- Copying ToxiUI / ElvUI assets or code

## Scope

| Piece | This pass |
|-------|-----------|
| Left PROFESSIONS / COLLECTIONS / PLAYED panel | Yes — visual + layout rework in `Overlay.lua` |
| Dim under Escape menu | Keep as today (alpha ~0.45) |
| Panel anchor beside `GameMenuFrame` | Keep `Logic.AnchorSide` behavior |
| Game Menu button chrome | No |
| Character info (top-right) | No |

## Visual design

Palette (approximate from print; tune in implementation):

- Header text: accent blue (~`0.20, 0.55, 1.00` or close to Settings ACCENT)
- Header rule: same blue, 1px full content width under the header
- Row label: light gray / white, left-aligned
- Row value: light gray / white, right-aligned
- Panel: no heavy card chrome required; transparent / minimal so it sits next to Ellesmere’s menu
- Played class rows: full-width tinted bar (class color at reduced alpha) + class name left + duration right; current character class may use a stronger fill

Section headers: **PROFESSIONS**, **COLLECTIONS**, **PLAYED** (ALL CAPS).

### Row model

Replace single concatenated strings (`"Mounts 12/34"`) with structured rows:

```lua
{ label = "Mounts", value = "12/34", texture = nil }  -- texture unused this pass
```

Played summary rows:

| Label | Value |
|-------|--------|
| Session | formatted duration |
| This Character | formatted duration |
| Account | formatted duration |

Class bars: one visible row per class with stored time (same data as today).

### Section order

1. Professions  
2. Collections  
3. Played (summary rows + class bars)

Respect existing toggles: if a section is off or has no rows, hide its header and skip its gap.

### Spacing

- Clear gap between sections (larger than today’s ~12px — target ~20–28px)
- Modest gap under each header rule before first row
- Consistent row height (~18–20px)

### Icons

- Keep an icon texture on row frames for a later pass
- This pass: do **not** show profession spell icons (or hide them) so layout matches “icons later”
- Layout must not reserve a large empty icon column that breaks the print; either 0 width when hidden or a small reserved slot that stays invisible

## Behavior (unchanged)

- Show/hide with `GameMenuFrame`
- `RequestTimePlayed` / `TIME_PLAYED_MSG` / rate limit as today
- Collections / professions API fallbacks (hide missing rows) as today
- Settings page controls unchanged

## Files

| File | Change |
|------|--------|
| `Overlay.lua` | Header chrome, dual-column rows, section order, spacing, class-bar restyle |
| `Logic.lua` | Only if a pure helper helps (e.g. split label/value); prefer keep logic in Overlay |
| `Settings.lua` | Description text only if needed (“Game Menu” blurb) |
| Tests | Optional: no new Logic API required; skip unless a helper is extracted |

## Success criteria

- Escape overlay visually matches the print’s left column (headers, rules, label/value, Played bars)
- Section order is Professions → Collections → Played
- Toggles and data refresh still work
- Game Menu buttons and character block untouched
- No new icons required to look correct
