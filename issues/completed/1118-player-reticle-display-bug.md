# 1118 - Player Reticle Display Bug

## Status: COMPLETE

## Problem

The player's spawn reticle flashed between blue and green states:
- Blue state: shows spawn progress while charging
- Green state: shown when ready to spawn

With fast spawn rates, this caused jarring flickering as the reticle rapidly
alternated between colors.

## Solution

Changed player reticle to use consistent cyan color scheme throughout,
matching how the adversary reticle uses consistent red tones. Now the
reticle shows progress as fill amount, not color change.

## Changes Made

In `src/001-main.c` (lines 790-808):

**Before:**
- Background ring: (60, 60, 80) dim blue-gray
- Charging arc: (100, 200, 255) cyan
- Ready ring: (100, 255, 150) **green** ← color switch caused flickering

**After:**
- Background ring: (60, 80, 100) dim cyan
- Charging arc: (100, 200, 255) cyan
- Ready ring: (100, 200, 255) **cyan** ← consistent color, no flickering

## Files Modified

- `src/001-main.c` - Player reticle rendering (cooldown indicator section)
