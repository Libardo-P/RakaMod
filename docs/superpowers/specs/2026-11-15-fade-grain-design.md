# Fade Grain Design

**Date:** 2026-11-15  
**Status:** Implemented  
**Branch:** `develop`

## Goal

One shared **background fade** for Escape and AFK, with an optional **grain** toggle. Same fade opacity and grain tiling on both screens.

## Settings (Features page)

| Control | DB key | Default | Notes |
|---------|--------|---------|-------|
| Background fade | `features.backgroundFade` | `50` | Integer 0–100 → black shade alpha |
| Grain Background | `features.fadeGrain` | `true` | On = grained; off = clean |

Fixed grain look when enabled: strength `40`, scale `1`.

## Apply

- Overlay + AFK both read `features.backgroundFade` via `Logic.FadeShadeAlpha`
- Grain uses `UIParent` size for texcoords so Escape and AFK match
- Features slider/toggle live-refresh both surfaces

## Non-goals

- Separate fade sliders on Game Menu / AFK pages
- Soft shadows on HUD frames
