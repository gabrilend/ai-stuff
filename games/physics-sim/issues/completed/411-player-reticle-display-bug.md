# 411 - Player Reticle Display Bug

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

In `src/001-main.c` (lines 790-803):

**Before:**
- Used `spawn_cooldown` (legacy timer) for visual
- Switched between cyan (charging) and green (ready)
- Showed static "full" ring when ready to spawn

**After:**
- Uses `spawn_credits` fractional part (like adversary)
- Consistent cyan color throughout
- Always shows progress toward next spawn - never static
- Ring continuously animates regardless of spawn state

```c
float credits_frac = ball_manager->spawn_credits - (int)ball_manager->spawn_credits;
// Always shows fractional progress, never a static "full" ring
```

## Files Modified

- `src/001-main.c` - Player reticle rendering (cooldown indicator section)
