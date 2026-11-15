# Fade Grain Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Shared grain overlay on Game Menu + AFK black fades.  
**Spec:** `docs/superpowers/specs/2026-11-15-fade-grain-design.md`

## Tasks

1. Add `Logic.GrainAlpha` / `Logic.GrainTileSize` + tests  
2. Ship `Media/grain.tga` + defaults in `Core.lua`  
3. Wire grain texture + apply in `Overlay.lua` and `AFK.lua`  
4. General page sliders + live refresh in `Settings.lua`  
5. Mark spec Implemented  

## Done when

Escape/AFK fades show tunable grain; strength 0 = plain black; tests pass.
