# Settings UI (Toxi-style shell) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `Settings.lua` into a ToxiUI-inspired left-sidebar + content-page shell for existing RakaMod options only.

**Architecture:** One settings frame with a left nav column (five buttons) and a right host that shows one page frame at a time. Existing `AddCheck` / `AddSlider` / color / outline helpers are rewritten to take a page context (`parent`, local `y`) instead of one global scroll list. Soft-blue accent constants style border and selected nav. No new db keys or features.

**Tech Stack:** WoW Lua addon (`Settings.lua` only). No AceConfig. Manual in-game verification (no CreateFrame unit tests). Spec: `docs/superpowers/specs/2026-11-13-settings-ui-design.md`.

## Global Constraints

- Scope: UI shell + regroup existing controls only — Overlay, Player Frame (`reveal`), Zone Text, AFK, Gradient.
- Sidebar label **Player Frame**; db section remains `reveal`.
- Accent: soft blue (Ellesmere-ish), not Toxi gold. Suggested RGB: `(0.45, 0.70, 0.95)`.
- Title: **RakaMod**. Open via existing slash / `Settings:Show`. ESC via `UISpecialFrames`.
- Do not copy ToxiUI/KryoMOD files, strings, or art.
- Keep Ellesmere `RegisterSkin` hook on the outer frame + close button.
- Preserve `SyncFromDB`, `RefreshNotes`, apply hooks (`Core:RefreshModules`, `ZoneText:Apply`, `Gradient:Apply`).
- Commits: only if the user explicitly asks this session.

---

## File map

- Modify: `Settings.lua` — full shell rebuild (single file; helpers + pages stay here to match current addon style).
- Spec (read-only): `docs/superpowers/specs/2026-11-13-settings-ui-design.md`
- No TOC change unless icon textures are added under `Media/` (prefer stock textures / fontstring-only nav to avoid new assets).

Shared names after Task 1 (used by later tasks):

```lua
local ACCENT = { r = 0.45, g = 0.70, b = 0.95 }
local SIDEBAR_WIDTH = 140
local PAGES = {} -- key -> { button, page, scroll?, content? }
function Settings:SelectPage(key) end -- "overlay"|"reveal"|"zoneText"|"afk"|"gradient"
function Settings:Show() end
function Settings:RefreshNotes() end
```

Page builder signature (Task 2+):

```lua
-- CreatePage returns page frame + content frame + Advance/LocalY closures for helpers
local function CreatePage(key, title)
  -- page sized to content host; optional ScrollFrame inside
end
```

---

### Task 1: Outer shell + sidebar chrome

**Files:**
- Modify: `Settings.lua` (replace outer layout; keep `RakaModSettingsFrame` name, `Settings` table, `Show`/`RefreshNotes` stubs temporarily if needed)

**Interfaces:**
- Consumes: existing `RakaMod.Settings`, `UISpecialFrames`, Ellesmere skin hook pattern
- Produces: `frame`, `sidebar`, `contentHost`, `ACCENT`, `SelectPage`, five nav buttons (pages empty placeholders)

- [ ] **Step 1: Replace outer frame chrome**

Keep frame name `RakaModSettingsFrame`, size about `640 x 520`, movable/clamped/`DIALOG`. Replace dialog-box backdrop with dark panel + soft-blue edge, e.g.:

```lua
local ACCENT = { r = 0.45, g = 0.70, b = 0.95 }

if frame.SetBackdrop then
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(0.08, 0.08, 0.10, 0.95)
  frame:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.85)
end
```

Title top-left or top-center: `RakaMod`. Keep `UIPanelCloseButton` top-right and Ellesmere `RegisterSkin` in `Show`.

- [ ] **Step 2: Add sidebar + content host**

```lua
local SIDEBAR_WIDTH = 140
local sidebar = CreateFrame("Frame", nil, frame, template)
sidebar:SetPoint("TOPLEFT", 12, -40)
sidebar:SetPoint("BOTTOMLEFT", 12, 12)
sidebar:SetWidth(SIDEBAR_WIDTH)
-- dark backdrop similar to outer, slightly lighter

local contentHost = CreateFrame("Frame", nil, frame, template)
contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, 0)
contentHost:SetPoint("BOTTOMRIGHT", -12, 12)
-- dark backdrop
```

- [ ] **Step 3: Nav buttons + SelectPage**

Create five buttons in order:

| Label        | key        |
|--------------|------------|
| Overlay      | overlay    |
| Player Frame | reveal     |
| Zone Text    | zoneText   |
| AFK          | afk        |
| Gradient     | gradient   |

Each button: left-aligned text, full sidebar width minus padding, height ~28. Selected state: soft-blue highlight texture (or `SetBackdropColor` with accent alpha). Unselected: dark.

```lua
local pages = {} -- key -> { button = btn, page = frameOrNil }

function Settings:SelectPage(key)
  for k, entry in pairs(pages) do
    if entry.page then
      if k == key then entry.page:Show() else entry.page:Hide() end
    end
    -- update button highlight for selected key
  end
end
```

Default on `Show`: `SelectPage("overlay")`.

Placeholder: for each key, create an empty `page` frame parented to `contentHost`, `SetAllPoints`, hide all but overlay.

- [ ] **Step 4: Smoke-check in game**

`/reload`, `/raka` (or current slash). Expect: shell opens, five nav labels, clicking switches empty pages, ESC closes, soft-blue border.

---

### Task 2: Page helpers (scoped AddCheck / AddSlider / notes / colors)

**Files:**
- Modify: `Settings.lua`

**Interfaces:**
- Consumes: `contentHost`, `pages` from Task 1; `RakaMod.db`; `PickColor`; `OUTLINES`
- Produces: `CreatePage(key)`, `AddDescription(pageCtx, text)`, `AddCheck(pageCtx, ...)`, `AddSlider(...)`, `AddColorButton(...)`, `AddNote(...)`, shared `checks`/`sliders`/`swatches` arrays, `applying` flag

- [ ] **Step 1: Page context**

```lua
local function CreatePage(key)
  local page = CreateFrame("Frame", nil, contentHost)
  page:SetAllPoints()
  page:Hide()

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(400, 400)
  scroll:SetScrollChild(content)

  local y = 0
  local ctx = {
    key = key,
    page = page,
    scroll = scroll,
    content = content,
    LocalY = function() return y end,
    Advance = function() y = y - ROW end,
    Finish = function()
      content:SetHeight((-y) + 16)
    end,
  }
  pages[key].page = page
  pages[key].ctx = ctx
  return ctx
end
```

Wire mousewheel like today (`PassWheel` / `OnMouseWheel` using that page’s scroll).

- [ ] **Step 2: Port helpers to take `ctx`**

Rewrite `AddCheck`, `AddSlider`, `AddColorButton`, `AddNote` to parent widgets to `ctx.content` and use `ctx.LocalY()` / `ctx.Advance()`. Keep registering into global `checks` / `sliders` / `swatches` so one `SyncFromDB` still works.

`AddDescription(ctx, text)`: accent-colored header “Description” + white one-line body; advances ~two rows.

Keep `PickColor`, `NextOutline`, `AddSwatch`, `AddZoneSwatch` behavior identical; only parenting/y changes.

- [ ] **Step 3: SyncFromDB unchanged semantically**

`SyncFromDB` still walks `checks`, `sliders`, `swatches`, and the zone outline button reference.

---

### Task 3: Build the five pages

**Files:**
- Modify: `Settings.lua`

**Interfaces:**
- Consumes: Task 2 helpers; existing db keys
- Produces: filled pages; `revealNote`, `gradientNote`; `RefreshNotes` wired

- [ ] **Step 1: Overlay page**

```lua
local overlay = CreatePage("overlay")
AddDescription(overlay, "Escape overlay buttons (collections / played / professions).")
AddCheck(overlay, "Enabled", "overlay", "enabled")
AddCheck(overlay, "Collections", "overlay", "collections")
AddCheck(overlay, "Played", "overlay", "played")
AddCheck(overlay, "Professions", "overlay", "professions")
overlay:Finish()
```

(Use `overlay.Finish` from ctx.)

- [ ] **Step 2: Player Frame page (`reveal`)**

Description: `Show the player frame when casting, low health, mouseover, or combat.`  
Note: `EllesmereUI Unit Frames is not installed.` → `revealNote`  
Controls: Enabled, Casting, Health, Health percent (1–100), Mouseover, Combat, Pet.  
Labels: drop “Reveal enabled” → **Enabled** (section still `reveal`).

- [ ] **Step 3: Zone Text page**

Description: `Custom zone change text appearance.`  
Enabled, Size (8–64), Outline cycle button, Color swatch. Keep outline cycle + `AddZoneSwatch` logic.

- [ ] **Step 4: AFK page**

Description: `Full AFK screen behavior.`  
Enabled, Camera pan.

- [ ] **Step 5: Gradient page**

Description: `Two-color health bar gradient via Ellesmere modules.`  
Note: `No Ellesmere health-bar module is installed.` → `gradientNote`  
Enabled, Left swatch, Right swatch.

- [ ] **Step 6: RefreshNotes**

Same logic as today: hide empty overlay note; show/hide `revealNote` / `gradientNote` based on `RakaMod.Core:AddonLoaded(...)`.

- [ ] **Step 7: Show()**

Skin once, `SyncFromDB()`, `SelectPage` (keep last page or default overlay), `frame:Show()`, `RefreshNotes()`. Update scroll child width for the active page.

---

### Task 4: In-game verification

**Files:** none (manual)

- [ ] **Step 1: Checklist**

1. `/reload` — no Lua errors.  
2. Open settings — Toxi-like sidebar, soft-blue accent, title RakaMod.  
3. Each nav: Overlay / Player Frame / Zone Text / AFK / Gradient — correct controls only.  
4. Toggle Overlay Collections — still appears on Escape.  
5. Toggle Player Frame options — reveal still works with Ellesmere UF.  
6. Zone Text size/outline/color — apply on zone change.  
7. AFK enabled — AFK screen still works.  
8. Gradient colors — bars update when module present; note shows when missing.  
9. ESC closes; reopen syncs from db.  
10. Ellesmere skin still applies if RegisterSkin present.

- [ ] **Step 2: Fix any layout bugs** (clipping, scroll, nav highlight) found in Step 1.

---

## Spec coverage check

| Spec item                         | Task |
|-----------------------------------|------|
| Toxi sidebar + content            | 1    |
| Soft-blue accent, RakaMod title   | 1    |
| Five nav; Player Frame label      | 1, 3 |
| Existing controls only per page   | 3    |
| Descriptions + Enabled            | 3    |
| Missing-module notes              | 3    |
| Same db / apply behavior          | 2, 3 |
| Slash + ESC                       | 1    |
| No new features                   | all  |

## Placeholder scan

None intentional. Commit steps omitted (user must request commits).
