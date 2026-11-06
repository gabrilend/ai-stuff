# 403 — Figures Are Posed From The Record

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 402, 203, 302 |
| Blocks | 405, 406 |
| Files | `src/024-figures.lua` |
| Reads | `docs/art-direction.md` |

## Current behavior

Built in `src/024-figures.lua`: legs swung by distance walked, a body
squashed by lost health and leaning with fatigue, a two-dot face, arms to a
two-handed grip, a brick sword (or spear), armor bricks by rating, a
cat-faced shield for the shield trait, a pennant for the player in third
person. Drawing is the renderer's part-list call; no separate draw function
was needed.

## Intended behavior

A figure is drawn from one soldier record and nothing else. The parts: clay
legs, body, head with a two-dot face, arms reaching to the sword's grip; brick
armor plates (more and bigger with higher armor rating; shoulder bricks when
thick); the sword (brick blade, crossguard, pommel stud) in the team colour;
a shield disc for soldiers with the shield trait.

The pose comes from the record:

- the sword sits at its U position (301) and, during a swing, travels along
  the kind's path (stab thrusts forward from the bend; slashes sweep across
  from their side; the overhead rises and falls), following the swing's
  windup and strike timing;
- guarding lifts the sword across the body;
- walking swings the legs by distance travelled;
- fatigue sags the body; damage dents it (the body blob is squashed by lost
  health);
- tripped lies on its back; fallen lies still and greys.

## Suggested implementation steps

1. Write one function that returns the list of (shape, matrix, colour, look)
   for a soldier, and another that draws that list.
2. Check with screenshots of each pose.
