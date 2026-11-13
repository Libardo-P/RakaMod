# Per-Class Gradient Mode Design

**Date:** 2026-11-13  
**Status:** Draft for review  
**Depends on:** Settings UI shell (`2026-11-13-settings-ui-design.md`)

## Goal

Replace the single global left/right health gradient with a ToxiUI-inspired Gradient page: per-class pairs, NPC reaction pairs, and state pairs. Paint hooked Ellesmere health bars using those tables. Widen the settings window to 800×560 (fixed size for now).

## Non-goals

- Resizable settings window (deferred)
- Extra state rows beyond Dead / Offline / Tapped / Disconnected (add after testing)
- Dark mode, threat/classification extras, power-bar gradients
- Copying ToxiUI assets, strings, or code

## Settings window

- Default size: **800×560**
- Not resizable in this pass
- Still movable, clamped, ESC-close, Ellesmere skin hook

## Data model

`RakaMod.db.gradient`:

```lua
gradient = {
  enabled = false,
  classes = {
    -- [classFile] = { left = {r,g,b}, right = {r,g,b} }
    WARRIOR = ..., PALADIN = ..., HUNTER = ..., ROGUE = ...,
    PRIEST = ..., DEATHKNIGHT = ..., SHAMAN = ..., MAGE = ...,
    WARLOCK = ..., MONK = ..., DRUID = ..., DEMONHUNTER = ...,
    EVOKER = ..., -- include; harmless if unused on Forever
  },
  npc = {
    friendly = { left = ..., right = ... },
    enemy = { left = ..., right = ... },
    neutral = { left = ..., right = ... },
  },
  states = {
    dead = { left = ..., right = ... },
    offline = { left = ..., right = ... },
    tapped = { left = ..., right = ... },
    disconnected = { left = ..., right = ... },
  },
}
```

### Defaults

- **Classes:** from WoW class color (`RAID_CLASS_COLORS` / `C_ClassColor`), darker → brighter horizontal shift (deterministic darken/lighten helpers in `Logic.lua`).
- **NPC / State:** fixed sensible pairs (green / red / gold for NPC; muted grays/reds for states) defined once in defaults.
- Legacy `gradient.left` / `gradient.right` are not shown in UI. `MergeDefaults` seeds the new tables; leftover legacy keys may remain in SavedVariables but are unused.

## Gradient settings page

1. Description (one line) + **Enabled**
2. Existing missing-module note
3. **Class Colors** — two-column grid; each row: class-tinted label · left swatch · `>` · right swatch · gradient preview bar
4. **NPC Colors** — Friendly / Enemy / Neutral (same row chrome)
5. **State Colors** — Dead / Offline / Tapped / Disconnected

Swatch change → update db → refresh that row’s preview → `Gradient:Apply()`.

Other sidebar pages keep their controls; they simply gain horizontal room from the wider frame.

## Paint behavior

Priority when choosing a pair for a hooked health bar:

1. dead  
2. offline  
3. disconnected  
4. tapped  
5. player unit → `classes[classFile]`  
6. NPC → `npc.friendly` / `npc.enemy` / `npc.neutral` from reaction  
7. fallback → `npc.neutral`

Health bars only (power unchanged). Use `SetGradient` HORIZONTAL with the pair’s left/right `CreateColor`s (same API path as today).

### Unit resolution

- On hook / paint, resolve a unit token from the bar’s Ellesmere/owner frame when possible.
- If unit cannot be resolved: use **npc.neutral** (do not error).

State checks use standard unit APIs (`UnitIsDeadOrGhost`, `UnitIsConnected`, tap APIs as available on Forever/retail). Prefer pcall; missing API → skip that state.

## Files likely touched

- `Logic.lua` — default pair builders, merge shape, optional color darken/lighten + tests
- `Core.lua` — defaults table for `gradient`
- `Gradient.lua` — resolve pair + Paint
- `Settings.lua` — frame size; Gradient page rebuild; gradient row helper

## Success criteria

- Settings open at 800×560; Gradient page shows Class / NPC / State editors with previews
- Enabling gradient paints bars by class/NPC/state per priority above
- Disabling restores prior non-gradient behavior (existing flatten/restore path)
- No new state rows beyond the four; no window resizing
- Logic unit tests cover darken/lighten and pair-pick helpers where pure

## Out of scope / later

- Resize + saved window size
- More state colors after user testing
- Per-unit-type toggles (units / bars / nameplates tabs)
