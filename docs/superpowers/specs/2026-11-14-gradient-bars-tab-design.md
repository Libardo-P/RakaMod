# Gradient Bars Tab Design

**Date:** 2026-11-14  
**Status:** Draft for review  
**Depends on:** Per-class gradient mode (`2026-11-13-gradient-by-class-design.md`)

## Goal

Add a **Bars** sub-tab on the existing Gradient settings page for Power and Castbar gradient pairs (ToxiUI-inspired). Persist defaults and allow editing via the same swatch UI. Do **not** paint power or cast bars in this pass.

## Non-goals

- Painting Ellesmere power bars or cast bars (follow-up)
- Painting class resource bars (follow-up; settings only in this pass)
- Separate sidebar nav item for Bars
- Separate Enabled flag for Bars (shares `gradient.enabled`)
- Copying ToxiUI assets, strings, or code

## Settings UX

Keep one sidebar item: **Gradient Mode** (rename from `Gradient`).

At the top of the Gradient Mode content area (below the page header, above the scroll body):

| Sub-tab | Content |
|---------|---------|
| **Health** | Current page: Enabled, module note, Class / NPC / State colors |
| **Bars** | Power Colors + Castbar Colors |
| **Resources** | Class Resources (combo points, holy power, chi, shards, orbs, runes) |
| **Nameplates** | Enabled, fade direction, Threat Colors, Classification Colors |

Sub-tab chrome: compact buttons; selected state uses existing accent. Switching tabs shows/hides content frames (no second sidebar page). Enabled + module note stay on **Health** only.

## Data model

Extend `RakaMod.db.gradient` (via `Logic.BuildGradientDefaults` + `MergeDefaults`):

```lua
gradient = {
  enabled = false,
  classes = { ... },      -- existing
  npc = { ... },          -- existing
  states = { ... },       -- existing
  power = {
    altPower = { left = {r,g,b}, right = {r,g,b} },
    focus = { left = ..., right = ... },
    rage = { left = ..., right = ... },
    energy = { left = ..., right = ... },
    mana = { left = ..., right = ... },
    runicPower = { left = ..., right = ... },
  },
  castbar = {
    regular = { left = ..., right = ... },
    nonInterruptible = { left = ..., right = ... },
  },
  classResources = {
    comboPoint1 = ..., comboPoint2 = ..., comboPoint3 = ...,
    comboPoint4 = ..., comboPoint5 = ...,
    holyPower = ..., chi = ..., soulShards = ..., shadowOrbs = ...,
    bloodRunes = ..., frostRunes = ..., unholyRunes = ..., deathRunes = ...,
  },
}
```

### Defaults

Sample left/right hex from the ToxiUI Bars print during implementation and store as fixed `hexPair` entries (same pattern as class/NPC defaults). Approximate targets from the print:

| Key | Role |
|-----|------|
| `power.altPower` | Dark blue → lighter blue |
| `power.focus` | Dark orange → lighter orange |
| `power.rage` | Dark red → bright red |
| `power.energy` | Dark orange → pale yellow |
| `power.mana` | Dark blue → sky blue |
| `power.runicPower` | Deep cyan → bright cyan |
| `castbar.regular` | Orange → lighter orange |
| `castbar.nonInterruptible` | Dark grey → lighter grey |

Default button on each row resets from `BuildGradientDefaults`.

## Bars page layout

1. Section **Power Colors** + one-line description  
2. Pair rows (single column): Alt Power, Focus, Rage, Energy, Mana, Runic Power  
3. Section **Castbar Colors** + one-line description  
4. Pair rows: Regular, Non-interruptible  

Reuse `AddPairRow` / color picker. On change: write db → refresh row preview. Do **not** call `Gradient:Apply()` for these rows until painting exists (optional no-op Apply is fine if cheaper than branching).

## Paint behavior

**Unchanged.** `Gradient.lua` continues to hook health bars only. Power/cast keys remain excluded by `Logic.IsHealthBarKey`. Stored `power` / `castbar` tables are unused by paint until a later spec.

## Files

| File | Change |
|------|--------|
| `Logic.lua` | Add `power` / `castbar` defaults in `BuildGradientDefaults` |
| `Settings.lua` | Health/Bars sub-tabs; Bars page with Power + Castbar rows |
| `tests/test_logic.lua` | Assert a few power/castbar default hex samples |
| `Gradient.lua` | No paint changes |

## Success criteria

- Sidebar label is **Gradient Mode**; Health and Bars sub-tabs switch content cleanly  
- Bars shows editable Power + Castbar pairs with Toxi-sampled defaults  
- SavedVariables merge fills missing `power` / `castbar` without wiping health tables  
- Health gradients and paint path behave as today  
- Bars Class Colors absent until a follow-up screenshot/spec  
