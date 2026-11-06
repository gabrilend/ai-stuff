# 405 — The Front Rank Has No Interface

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 401, 403, 404, 301, 305 |
| Blocks | 407, 502 |
| Files | `src/026-first-person-view.lua` |
| Reads | `docs/game-rules.md` §4, `docs/datapath-rendering.md` |

## Current behavior

Built in `src/026-first-person-view.lua`: the eye 0.32 m behind the
shoulders (so the arms enter from the lower corners), eyes on the lock's
chest, the own arms and sword drawn last, edge glows for awareness, fatigue
and wounds, the lock drawn brighter. In progress until the open questions
about the controls are answered.

## Intended behavior

The camera sits at the player soldier's eye height, looking along its facing
(or along the free-look direction while the look key is held), with a 90
degree horizontal field of view. The player's own body is not drawn except
the arms and sword, which are drawn at the U position relative to the
camera, so the sword visibly travels around the U as the mouse moves and
along the swing's path when swinging.

Everything else is drawn from the records: every other figure, the scenery.

**No interface.** Nothing on screen is text or a bar. What the player needs
to know is in the picture:

- fatigue: the view bobs and sways more as fatigue rises, and the edges dim;
- damage: a red tint pulses in from the edges on being hit;
- awareness beyond the view: soldiers within the awareness arc (160 degrees
  minus the armor narrowing) but outside the 90 degree view glow at the
  screen edge on their side — warm for allies, cold for enemies — brighter
  for nearer;
- the lock: the locked enemy's figure is drawn very slightly brighter.

The mouse is captured (relative mode) in first person.

## Suggested implementation steps

1. Build the camera matrices from the record each frame.
2. Draw the edge glows in 2D after the 3D pass, as gradients.
3. Check by scripted screenshots: idle, swinging from each side, guarding,
   fatigued, an enemy at the side.

## Open questions

- Which button guards in first person: the right button held (built), or an
  automatic parry judged from where the sword sits on the U?
- Does the mouse move the sword (built; left alt frees the eyes) or the eyes?
- Is the edge glow for the 160 degree awareness too much interface?
