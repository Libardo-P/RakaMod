# RakaMod design

Date: 2026-11-12

RakaMod is an original companion addon for EllesmereUI. It runs from one folder on World of Warcraft retail and WoW Forever. KryoMOD and ToxiUI are references for behavior only. None of their code, fonts, or art is copied.

## Goal

Give EllesmereUI a Kryo-style overlay, player-frame reveal, and zone text, plus a full AFK screen and a two-color health gradient.

In scope for v1:

- Escape-menu overlay: collections, played time, professions
- Player-frame reveal
- Zone-text styling
- Full-screen AFK mode
- Gradient on health bars, using two colors the player picks
- A small original media pack and a settings window

Out of scope for v1:

- Per-class gradient pairs, dark mode, a databar, an armory, or an installer
- An Ellesmere layout import
- Gradients on power bars, cast bars, or absorb bars
- The Mythic+ dungeon list, including group-finder search, Hero's Path teleports, and Raider.IO score colors. That panel is a later version.
- Publishing to CurseForge

RakaMod's own license is All Rights Reserved until the author chooses another.

## Where it lives

- Git repo: `D:\Blizzard\World of Warcraft\_forever_\Interface\AddOns\RakaMod`
- Retail loads that same folder through a junction at `D:\Blizzard\World of Warcraft\_retail_\Interface\AddOns\RakaMod`
- Addon author field: `Raka`
- Version: `0.1.0`

## Architecture

One addon. One TOC. Retail interface `120105` and Forever interface `16001` are both listed. Forever is detected at runtime from `GetBuildInfo()`: the fourth return is `16001` on Forever and a retail interface number otherwise. Feature code does not depend on `WOW_PROJECT_ID`.

EllesmereUI is required. These are optional, and the feature that needs one stays inactive when it is missing:

- `EllesmereUIUnitFrames` for reveal and for player, pet, target, focus, and boss gradients
- `EllesmereUIRaidFrames` for party and raid gradients
- `EllesmereUINameplates` for nameplate gradients
- `EllesmereUIDataBars` for profession icons
- `LibSharedMedia-3.0` for media registration

Each feature is a file registered by Core. Load order:

1. `Core.lua` — saved variables, client detection, slash commands, module registry
2. `Media.lua` — font and statusbar
3. `Settings.lua` — options window
4. `Overlay.lua`
5. `Reveal.lua`
6. `ZoneText.lua`
7. `AFK.lua`
8. `Gradient.lua`

A module exposes `OnLoad` and `OnEnable`. Core calls `OnLoad` during `ADDON_LOADED` and `OnEnable` during `PLAYER_LOGIN`. `OnEnable` returns immediately when the module is disabled or its Ellesmere dependency is missing.

```
RakaMod.toc
Core.lua
Media.lua
Settings.lua
Overlay.lua
Reveal.lua
ZoneText.lua
AFK.lua
Gradient.lua
Media/RakaMod.ttf
Media/statusbar.tga
Media/OFL.txt
```

The bundled font file is Inter, stored as `Media/RakaMod.ttf`, under the SIL Open Font License in `Media/OFL.txt`. SharedMedia registers it as `RakaMod`. The statusbar is a generated flat white texture named `RakaMod Statusbar`. Zone text uses the font file directly, so SharedMedia is not required for that feature. When LibSharedMedia is present, both assets are registered.

TOC metadata:

```
## Interface: 120105, 16001
## Title: RakaMod
## Author: Raka
## Version: 0.1.0
## SavedVariables: RakaModDB
## Dependencies: EllesmereUI
## OptionalDeps: EllesmereUIUnitFrames, EllesmereUIRaidFrames, EllesmereUINameplates, EllesmereUIDataBars, LibSharedMedia-3.0
```

Slash commands `/rakamod`, `/rmod`, and `/rm` open settings.

The settings window is skinned with `EllesmereUI.RegisterSkin` when that function exists. It has one section per module:

- Overlay: master switch, plus one switch each for collections, played, and professions
- Reveal: master switch, casting, health, health-percent slider from 1 to 100, mouseover, combat, and pet
- Zone text: master switch, size slider, color picker, outline dropdown (`NONE`, `OUTLINE`, `THICKOUTLINE`)
- AFK: master switch and camera-pan switch
- Gradient: master switch, left color, right color

## Saved data

One account-wide saved variable, `RakaModDB`. Session start is not saved. It is `GetTime()` at `PLAYER_LOGIN`.

Defaults:

```lua
{
  overlay = {
    enabled = true,
    collections = true,
    played = true,
    professions = true,
  },
  reveal = {
    enabled = true,
    casting = true,
    health = true,
    healthPercent = 90,
    mouseover = true,
    combat = true,
    pet = false,
  },
  zoneText = {
    enabled = true,
    size = 32,
    r = 1, g = 1, b = 1,
    outline = "OUTLINE",
  },
  afk = {
    enabled = true,
    cameraPan = true,
  },
  gradient = {
    enabled = false,
    left = { r = 0.91, g = 0.84, b = 0.64 },
    right = { r = 0.15, g = 0.14, b = 0.13 },
  },
  played = {
    -- [guid] = { name, realm, classFile, totalSeconds, lastUpdated }
  },
}
```

If a top-level section is missing or is not a table, Core replaces that section with its default and leaves the other sections in place. Missing keys inside a valid section are filled from the defaults.

Played records are keyed by player GUID. `TIME_PLAYED_MSG` writes `totalSeconds` for the current character. The account total is the sum of stored character totals. A class bar is that class's sum divided by the account total.

`RequestTimePlayed` runs once at login, and again when the overlay opens if this character has no record yet for the current session. It is never called more than once per 60 seconds. Until the message arrives, the overlay shows session time and shows an em dash for a total it does not yet have.

## Escape overlay

When `GameMenuFrame` is shown and the overlay is enabled, RakaMod shows the overlay panel and a fullscreen dim at alpha `0.45` under the menu. The panel anchors to the left edge of `GameMenuFrame`, vertically centered on it. If that position would leave the screen, it anchors to the right edge instead. Hiding the menu hides both.

Panels, each with its own switch:

- Collections. Mounts, toys, pets, and achievement points, using `C_MountJournal`, `C_ToyBox`, `C_PetJournal`, and `GetTotalAchievementPoints`. A row whose API is missing is hidden. The whole panel hides if every row is hidden.
- Played. This session, this character, and the account total, plus one bar per class that has stored time.
- Professions. Primary and secondary professions from `GetProfessions` and `GetProfessionInfo`. The row icon is the profession spell icon from `GetProfessionInfo`. When `EllesmereUIDataBars` is loaded and reading a global profession-icon table succeeds, that icon is used instead. The panel hides when `GetProfessions` is missing.

## Player frame reveal

Requires EllesmereUI Unit Frames. The module only forces the player frame shown. It never writes Ellesmere visibility settings, and it never forces the frame hidden.

Triggers, evaluated only when their switch is on:

- Casting: `UnitCastingInfo("player")` or `UnitChannelInfo("player")`
- Health: current health is below `healthPercent` (default 90)
- Mouseover: the cursor is over the player frame
- Combat: the player is in combat

The pet frame uses the same trigger set only when `reveal.pet` is on. That switch defaults off.

The alpha target is `frame._visWrap or frame`. Ellesmere fades the player through that wrapper. At the first force-show of a cycle, Reveal stores `IsShown()` and `GetAlpha()` from that target. While any active trigger is true, Reveal sets that target's alpha to `1`. When unlocked, it also calls `Show()` on the unit frame.

When every active trigger is false, Reveal removes its own secure driver, if it installed one, and does not call `Hide` itself. If `EllesmereUI._ModuleNS.EllesmereUIUnitFrames.UpdateFrameVisibility` exists, Reveal calls that and does not apply the stored alpha. Otherwise it restores the stored shown flag on the unit frame when unlocked, and restores the stored alpha on the alpha target.

When combat reveal is on and any trigger is active while unlocked, Reveal arms `RegisterStateDriver(frame, "visibility", "[combat] show")` before lockdown so the frame can show in combat. Alpha still updates while locked. `Show` waits until unlock. On release, Reveal clears `frame._euiVisDriver` only after it successfully removes a driver it installed, then calls Ellesmere's `UpdateFrameVisibility`. While a reveal cycle is active, Reveal re-applies alpha `1` after that visibility pass. If showing the frame errors, that update is skipped.

If health numbers cannot be read because they are secret values, the health trigger does not fire for that update.

## Zone text

When enabled, these font strings use the bundled RakaMod font, `zoneText.size`, the RGB color, and `zoneText.outline`:

- `ZoneTextString`
- `SubZoneTextString`
- `PVPInfoTextString`
- `PvPObjectiveTextString`, when it exists

The style is applied on load, on `ZONE_CHANGED_NEW_AREA`, and when the player changes the setting.

## AFK mode

When `afk.enabled` is on and `UnitIsAFK("player")` becomes true, the screen appears unless any of these are true: combat lockdown, a cinematic, a movie, or a current cast. A cast defers one retry for 30 seconds.

On enter:

- Close all windows and hide `UIParent`
- Show a fullscreen RakaMod frame
- Show the player model, play one wave, then leave the model idle
- Show name, realm, and guild name plus rank, or the text `No Guild`
- Show a timer as `mm:ss` from the moment the screen appeared
- Show a chat log of up to 500 lines for `CHAT_MSG_WHISPER`, `CHAT_MSG_BN_WHISPER`, and `CHAT_MSG_GUILD`
- If `cameraPan` is on, start a slow left camera pan at speed `0.03`. If that call errors, the screen still stays up

On exit, stop the camera, clear the chat registration, hide the AFK frame, and show `UIParent`.

Exit causes:

- Any key except Print Screen. Print Screen takes a screenshot and leaves the screen up. A manual key exit suppresses AFK for 60 seconds.
- Entering combat, a group-finder proposal, or a battlefield ready check. These exits do not start the 60 second timer. The screen stays down until the AFK flag goes off and then on again.

If the model fails to load, the name, guild, timer, and chat still show.

## Gradient

Off by default. One pair of colors for every covered health bar, left to right. The left default is soft gold `(0.91, 0.84, 0.64)`. The right default is deep charcoal `(0.15, 0.14, 0.13)`. Players and NPCs use the same pair.

Covered bars, when that Ellesmere module is installed:

- Player, pet, target, focus, and boss health bars
- Party and raid health bars
- Nameplate health bars

A bar is covered only when it is a StatusBar health bar. Unit frames use keys that contain `Health` or `health` and none of `Power`, `Cast`, or `Absorb`. Party and raid bars come from `EllesmereUI._ModuleNS.EllesmereUIRaidFrames` button data (`GetFFD(button).health`). Nameplate bars come from `EllesmereUI._ModuleNS.EllesmereUINameplates.plates[*].health`. Any other bar is skipped. There is no per-frame retry loop.

While enabled, Gradient reapplies the two colors after Ellesmere colors the bar. While disabled, Gradient removes its hook and calls Ellesmere's own color update for each bar it hooked. It does not write Ellesmere saved variables.

## Failures

- Missing EllesmereUI: the TOC dependency blocks load. If Core still runs, it prints `RakaMod requires EllesmereUI.` once and enables nothing.
- Missing optional addon: that module stays inactive. Its settings section says the Ellesmere module is not installed.
- Missing API: the row or panel hides. No error is raised.
- Secret values: the comparison is skipped for that update.
- Bad saved data: only the broken section is reset to defaults.
- Played time not yet received: session time shows, and unknown totals show an em dash.
- A single frame or model failure does not disable the rest of the module.

## Testing

These features need the WoW client. v1 is verified by this manual checklist on Forever and on retail. The retail pass uses the junction, so both clients load the same files.

Retail:

- With EllesmereUI enabled, `/reload` loads RakaMod with no errors
- `/rakamod`, `/rmod`, and `/rm` open settings, and a reload keeps the changed values
- Escape shows the dim and the collections, played, and professions panels with live data
- Each reveal trigger shows the player frame, and clearing every trigger returns control to Ellesmere
- The pet switch does not affect the player frame
- Zone text uses the bundled font and the chosen size, color, and outline after a zone change
- `/afk` hides the UI, shows the model, name, guild, timer, and a test whisper. Print Screen takes a shot. Another key restores the UI, and the screen stays down for 60 seconds
- A queue pop or entering combat restores the UI
- Turning camera pan off leaves the camera still
- Gradient is off after install. Turning it on paints the two colors left to right on unit, party, raid, and nameplate health bars, and leaves power bars unchanged. Turning it off restores Ellesmere's colors
- Logging a second character updates that class's played bar

Forever:

- The same checklist
- Any panel whose API is missing is absent
- No Lua errors from APIs the Forever client does not provide
- Reveal, zone text, AFK, and gradient still work

## Success criteria

A player with EllesmereUI can install this one folder, open `/rakamod`, and use the overlay, reveal, zone text, AFK screen, and two-color health gradient on Forever and on retail. Panels whose APIs are missing stay hidden. The Mythic+ list is not part of this version.
