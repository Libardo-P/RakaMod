# Game Menu Dim Opacity Design

**Date:** 2026-11-14  
**Status:** Implemented (hide-world-UI removed; fade only)  
**Branch:** `develop`  
**Depends on:** Escape overlay restyle (`2026-11-14-game-menu-overlay-restyle-design.md`)

## Goal

Add a Game Menu setting to control Escape **background dim opacity**.

## Non-goals

- Hiding world UI / HUD while the menu is open
- Hiding or restyling `GameMenuFrame` buttons
- Separate fade sliders on Game Menu / AFK (superseded by shared Features fade)

## Settings

Background fade lives on **Features** (`features.backgroundFade`, default `50`), shared with AFK.  
Game Menu page keeps: `enabled`, `collections`, `played`, `professions`.

## Dim opacity

- Keep `RakaModOverlayDim` fullscreen black texture.
- On show / setting change: `shade:SetColorTexture(0, 0, 0, alpha)` via `Logic.FadeShadeAlpha`.

## Lifecycle

```
OnMenuShow:
  ApplyDimAlpha()
  show dim + panel (existing)

OnMenuHide / Disable:
  hide dim + panel (existing)
```

## Files

| File | Change |
|------|--------|
| `Core.lua` | `features.backgroundFade` default |
| `Logic.lua` | `FadeShadeAlpha` helper |
| `Overlay.lua` / `AFK.lua` | Apply shared dim |
| `Settings.lua` | Features fade slider |
| `tests/test_logic.lua` | Shade helper asserts |

## Success criteria

- Slider changes Escape dim from transparent to fully black
- Game Menu + RakaMod overlay remain visible
- Collections / Played / Professions toggles still work
- AFK fade behavior unchanged (or identical via shared helper)
