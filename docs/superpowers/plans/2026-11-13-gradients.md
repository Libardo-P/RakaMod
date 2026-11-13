# Per-Class Gradients Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single left/right health gradient with Class / NPC / State pairs (Toxi-style editors + priority paint) and widen settings to 800×560 fixed.

**Architecture:** Pure helpers in `Logic.lua` (class pair from RGB, build defaults, pick pair). `Core` seeds `db.gradient` via `BuildGradientDefaults`. `Gradient.lua` resolves unit → info → pair → `SetGradient`. `Settings.lua` rebuilds the Gradient page with two-column class rows and preview bars.

**Tech Stack:** WoW Lua addon, Lua 5.4 out-of-game tests for Logic only.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-11-13-gradient-by-class-design.md`
- Window 800×560, not resizable
- States: dead, offline, tapped, disconnected only
- Paint priority: dead → offline → disconnected → tapped → player class → NPC reaction → npc.neutral
- No ToxiUI copy; health bars only
- Branch: `gradients`

---

### Task 1: Logic helpers + tests

**Files:** `Logic.lua`, `tests/test_logic.lua`

- [ ] Add `CLASS_FILES`, `CLASS_FALLBACK_COLORS`, `ClassPairFromRgb`, `BuildGradientDefaults`, `PickGradientPair`
- [ ] Update merge test defaults to new gradient shape
- [ ] Run `tests/run.lua` → ok

### Task 2: Core defaults + Gradient paint

**Files:** `Core.lua`, `Gradient.lua`

- [ ] `DEFAULTS.gradient = Logic.BuildGradientDefaults(wowColors)`
- [ ] Resolve unit; build info; `PickGradientPair`; paint
- [ ] Offline = player not connected; disconnected flag reserved/same skip if offline already matched

### Task 3: Settings UI

**Files:** `Settings.lua`

- [ ] Frame 800×560
- [ ] Gradient page: description, enabled, note, Class (2-col), NPC, State with swatches + preview
- [ ] Remove global Left/Right swatches

### Task 4: Verify

- [ ] `tests/run.lua` ok; `loadfile Settings/Gradient/Core/Logic`
