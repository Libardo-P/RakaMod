# Game Menu Dim Opacity + Hide World UI Design

**Date:** 2026-11-14  
**Status:** Draft for review  
**Branch:** `develop`  
**Depends on:** Escape overlay restyle (`2026-11-14-game-menu-overlay-restyle-design.md`)

## Goal

Add Game Menu settings to control Escape **background dim opacity** and a single **Hide world UI** toggle that clears map/chat/buffs/bars (etc.) while the menu is open, then restores them on close.

## Non-goals

- Per-element hide toggles (minimap vs chat vs buffs separately)
- Hiding or restyling `GameMenuFrame` buttons
- Changing AFK fade (separate `afk.backgroundFade`)
- Permanently hiding UI outside Escape

## Settings (Game Menu page)

| Control | DB key | Default | Notes |
|---------|--------|---------|-------|
| Background fade | `overlay.backgroundFade` | `45` | Integer 0–100 → dim alpha (same mapping idea as AFK) |
| Hide world UI | `overlay.hideWorldUI` | `false` | While Escape menu shown |
| Existing | `enabled`, `collections`, `played`, `professions` | unchanged | |

Reuse `AddSlider` / `AddCheck`. Slider live-updates dim if the menu is open (or on next open).

## Dim opacity

- Keep `RakaModOverlayDim` fullscreen black texture.
- On show / setting change: `shade:SetColorTexture(0, 0, 0, alpha)` where `alpha = clamp(backgroundFade, 0, 100) / 100`.
- Prefer a shared helper in `Logic` (e.g. generalize `AfkShadeAlpha` or add `Logic.ShadeAlpha(fade, default)` used by AFK + overlay) to avoid two slightly different clamp paths.

## Hide world UI

**Approach:** known-frame list + restore (not “hide all UIParent children”).

On `GameMenuFrame` show (overlay enabled and `hideWorldUI`):

1. For each frame name in the hide list, if `_G[name]` exists, is a region/frame, and `:IsShown()`, record it and `:Hide()`.
2. Store the list of frames we hid for this session (do not hide frames that were already hidden).

On menu hide / overlay disable:

1. `:Show()` each recorded frame (best-effort `pcall`).
2. Clear the restore list.

### Suggested hide list (Forever + retail best-effort)

Include when present:

- Minimap cluster: `Minimap`, `MinimapCluster`, `Cluster`
- Chat: `ChatFrame1`…`ChatFrameN` (or dock manager frames if safer), `GeneralDockManager`
- Buffs: `BuffFrame`, `DebuffFrame`, `TemporaryEnchantFrame`
- Bags / micro: `MainMenuBarBackpackButton`, bag bar frames if named
- Action / stance: `MainMenuBar`, `MultiBarBottomLeft`, `MultiBarBottomRight`, `MultiBarLeft`, `MultiBarRight`, `StanceBar`, `PetActionBar`, `PossessBar`
- Quest / tracker: `ObjectiveTrackerFrame`, `WatchFrame`
- Player/target (Blizzard): `PlayerFrame`, `TargetFrame`, `FocusFrame`
- Ellesmere-ish roots if found by global name patterns already used elsewhere (unit frames / raid / nameplates parents) — only well-known `_G` names; skip unknown

### Never hide

- `GameMenuFrame` and its children
- `RakaModOverlayDim`, `RakaModOverlayPanel`, `RakaModSettingsFrame`
- `StaticPopup1`…`4`, `UIErrorsFrame`
- `DropDownList1` / `2`, tooltips (`GameTooltip`) — optional keep visible for menu usability
- Cursor / mouse look frames

If a frame is protected and hide fails, skip silently.

## Lifecycle

```
OnMenuShow:
  ApplyDimAlpha()
  if hideWorldUI then HideWorldUI() end
  show dim + panel (existing)

OnMenuHide / Disable:
  RestoreWorldUI()
  hide dim + panel (existing)
```

## Files

| File | Change |
|------|--------|
| `Core.lua` | Defaults: `backgroundFade = 45`, `hideWorldUI = false` |
| `Logic.lua` | Shared shade-alpha helper (optional refactor of AFK) |
| `Overlay.lua` | Apply dim alpha; hide/restore world UI |
| `Settings.lua` | Slider + checkbox on Game Menu page |
| `tests/test_logic.lua` | Assert shade helper / defaults if Logic changes |
| `AFK.lua` | Only if switching to shared `ShadeAlpha` |

## Success criteria

- Slider changes Escape dim from transparent to fully black
- Hide world UI clears common HUD while menu is open and restores on close
- Game Menu + RakaMod overlay remain visible
- Collections / Played / Professions toggles still work
- AFK fade behavior unchanged (or identical via shared helper)
