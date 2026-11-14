# Game Menu Overlay Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Escape left overlay to Toxi-like headers, label/value rows, and Played class bars without touching GameMenu chrome.

**Architecture:** In-place rewrite of row/header chrome and layout order in `Overlay.lua`. Data APIs and Escape hooks stay. Icons remain hidden.

**Tech Stack:** WoW Lua addon (`Overlay.lua`).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-11-14-game-menu-overlay-restyle-design.md`
- Section order: Professions → Collections → Played
- No GameMenuFrame button restyle; no character block
- No icons shown this pass
- Branch: `develop`

---

### Task 1: Restyle Overlay chrome + layout

**Files:** Modify `Overlay.lua`

- [ ] Header: ALL CAPS blue + underline rule
- [ ] Rows: `label` left / `value` right; icon always hidden
- [ ] Collections/Professions/Played fill use structured label/value
- [ ] Class bars: full-width class tint + name left + duration right; highlight player class
- [ ] Layout order Professions → Collections → Played; larger section gaps
- [ ] Smoke: `lua tests/run.lua` still ok
- [ ] Commit

```bash
git add Overlay.lua docs/superpowers/plans/2026-11-14-game-menu-overlay-restyle.md
git commit -m "feat: restyle Escape overlay to Toxi-like stats panel"
```
