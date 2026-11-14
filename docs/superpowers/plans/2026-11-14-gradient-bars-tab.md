# Gradient Mode Bars Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename sidebar **Gradient** → **Gradient Mode**, add Health/Bars sub-tabs, and persist Power + Castbar gradient pair defaults (settings only; no paint).

**Architecture:** Extend `Logic.BuildGradientDefaults` with `power` and `castbar` tables. Keep page key `gradient` for Health; add sibling page `gradientBars` (not in sidebar NAV). Sub-tab buttons switch between them while the Gradient Mode nav item stays selected. `Gradient.lua` unchanged.

**Tech Stack:** WoW Lua addon; `tests/run.lua` for Logic defaults.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-11-14-gradient-bars-tab-design.md`
- Sidebar label: **Gradient Mode**
- Sub-tabs: **Health** | **Bars**
- Settings + defaults only; no power/cast paint
- Bars Class Colors out of scope
- Share `gradient.enabled` (on Health tab only)
- Branch: `gradients`

### Sampled defaults (Toxi Bars print)

| Key | Left | Right |
|-----|------|-------|
| `power.altPower` | `1E4BB8` | `3D7AE8` |
| `power.focus` | `B84A18` | `D97134` |
| `power.rage` | `A81816` | `E82F2D` |
| `power.energy` | `C45E12` | `FFDF6E` |
| `power.mana` | `1A3F9E` | `4A90E8` |
| `power.runicPower` | `0E7DB8` | `37A3FB` |
| `castbar.regular` | `E8A000` | `FFB200` |
| `castbar.nonInterruptible` | `72716F` | `8E8D8B` |

---

### Task 1: Logic defaults + tests

**Files:**
- Modify: `Logic.lua` (`BuildGradientDefaults` return)
- Modify: `tests/test_logic.lua`

**Interfaces:**
- Produces: `BuildGradientDefaults().power.{altPower,focus,rage,energy,mana,runicPower}` and `.castbar.{regular,nonInterruptible}` as `{ left = {r,g,b}, right = {r,g,b} }`

- [ ] **Step 1: Write failing assertions**

```lua
eq(math.floor(g.power.mana.left.r * 255 + 0.5), 26, "mana left r")
eq(math.floor(g.castbar.nonInterruptible.right.r * 255 + 0.5), 142, "cast nonint right r")
```

- [ ] **Step 2: Run tests — expect FAIL** (`g.power` nil)

Run: `lua tests/run.lua`

- [ ] **Step 3: Add defaults in `BuildGradientDefaults`**

```lua
power = {
  altPower = hexPair("1E4BB8", "3D7AE8"),
  focus = hexPair("B84A18", "D97134"),
  rage = hexPair("A81816", "E82F2D"),
  energy = hexPair("C45E12", "FFDF6E"),
  mana = hexPair("1A3F9E", "4A90E8"),
  runicPower = hexPair("0E7DB8", "37A3FB"),
},
castbar = {
  regular = hexPair("E8A000", "FFB200"),
  nonInterruptible = hexPair("72716F", "8E8D8B"),
},
```

- [ ] **Step 4: Run tests — expect `ok`**

- [ ] **Step 5: Commit**

```bash
git add Logic.lua tests/test_logic.lua
git commit -m "feat: add power and castbar gradient defaults"
```

---

### Task 2: Rename + Health/Bars sub-tabs + Bars UI

**Files:**
- Modify: `Settings.lua` (PAGE_META, NAV label, SelectPage, gradient page build)

**Interfaces:**
- Consumes: `db.gradient.power` / `db.gradient.castbar` from Task 1
- Produces: pages `gradient` (Health) and `gradientBars` (Bars); nav key remains `gradient`

- [ ] **Step 1: Rename**

```lua
gradient = { title = "Gradient Mode", description = "..." },
-- NAV:
{ key = "gradient", label = "Gradient Mode" },
```

- [ ] **Step 2: Sub-tab helper**

Add `MakeGradientSubTabs(parentPage, active)` that creates Health/Bars buttons. Health → `SelectPage("gradient")`; Bars → `SelectPage("gradientBars")`. Update `SelectPage` so when key is `gradient` or `gradientBars`, the Gradient Mode nav button stays selected.

- [ ] **Step 3: Build `gradientBars` page**

`CreatePage("gradientBars")` with sub-tabs (Bars active), Power Colors section (6 rows), Castbar Colors section (2 rows), same `AddPairRow` pattern as NPC rows. No `Gradient:Apply` required. Call `Finish()`.

- [ ] **Step 4: Prepend Health sub-tabs on existing gradient page**

Insert sub-tab bar before description (or immediately after page open). Health tab active.

- [ ] **Step 5: Smoke**

`lua tests/run.lua` → ok; `loadfile("Settings.lua")` syntax-check if feasible.

- [ ] **Step 6: Commit**

```bash
git add Settings.lua docs/superpowers/specs/2026-11-14-gradient-bars-tab-design.md
git commit -m "feat: Gradient Mode Health/Bars sub-tabs for power and castbar colors"
```

---

### Task 3: Verify

- [ ] Confirm `Gradient.lua` untouched for paint
- [ ] Confirm merge fills new keys without wiping classes/npc/states
- [ ] Checklist: sidebar says Gradient Mode; Health/Bars switch; defaults visible; Default resets a row
