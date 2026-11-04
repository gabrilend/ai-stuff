# 111 — Time-scaled motion and the frame cap

**Phase:** 1 — The world beneath
**Blocked by:** 110
**Related documents:** docs/architecture.md, issue 102 (the fixed tick)

## Current Behavior

Built (2026-10-10), waiting on its open questions. Every step covers all
the time since the previous step began, and every motion is scaled by it
(`src/006-the-move-box.lua`). LÖVE's frame loop is replaced
(`game.run` in `src/016-the-game.lua`): after drawing, it sleeps until about 2
ms before the frame's slot ends, then watches the clock for the rest
(`src/010-the-frame-cap.lua`); vsync is off. Escape opens the settings menu:
painted −10, −1, +1, +10 buttons, the cap on a large dial, BACK and QUIT.
Measured: cap 144 → 144 fps; cap 164 → 164; cap 240 → 239–240; cap 0 → 377
(uncapped). One second of motion at 20, 60 and 240 steps agrees to within
32-bit float rounding (spread 1.9e-5 of a tier; bound 240 × 2^-22).

## Intended Behavior

- Every motion and action is scaled by the time that passed since the last
  step, so a unit crosses a tier band in the same seconds whether the game
  runs at 20 frames per second or 240.
- The player sets the maximum framerate, as an exact whole number from 0 to
  240, in the settings menu (opened with Escape). It is set with painted
  buttons (−10, −1, +1, +10); a dial shows the value. 0 means no cap.
- The frame loop waits out the rest of each frame's time budget, so the cap
  is met exactly within the timer's accuracy. Vsync is off so caps above the
  monitor's rate are real.
- The starting cap is read from `input/game-settings.lua`.
- Dials on the dashboard show the measured framerate and frame time.

## Suggested Implementation Steps

1. Replace LÖVE's frame loop with one that measures the step time, runs the
   step, draws, then sleeps to the cap.
2. The settings menu: a panel on the dashboard, painted buttons, a dial.
3. Tests: cap arithmetic (240 → 1/240 s budget; 0 → no wait); a unit's
   displacement over one simulated second is the same at caps 20, 60, 240.

## Open questions

- Is 0 "no cap" (as built), or "stop"? 
- Issue 102 plans a fixed tick for exact replays and network play; this issue
  scales by measured time. Should the simulation step in fixed slices (many
  per frame at low framerates) while the view scales by measured time?
