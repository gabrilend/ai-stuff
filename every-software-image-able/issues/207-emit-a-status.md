# 207 — Emit a status

## Current behavior

Nothing the machine does leaves a trace anyone can read at a glance.

## Intended behavior

Programs and the machine itself can emit an aspect, a code and a magnitude, and
those can be shown on hardware that cannot spell.

## Suggested implementation steps

1. Provide the emission as a tool call and as something the code produced by
   `204` can reach. Both, because the machine emits during its own thinking and
   the things it builds emit during theirs.
2. Carry three numbers: the aspect, which says where this came from; the code,
   which means whatever the emitting program needs it to mean; and the magnitude,
   on an axis where fifty is ordinary and distance in either direction means a
   look is warranted, and nothing more than that.
3. Drive whatever display the board has. A handful of lamps or a seven-segment
   readout cannot spell, which is why the aspect is shown as colour **and**
   shape — the redundancy is so the reading survives a failed lamp, a dim room,
   or a person who does not distinguish the colours.
4. Keep the current reading in memory as a machine-wide value, so the picture is
   comparable across everything running rather than private to each program.
5. Where there are no lamps, draw the colourshape on the framebuffer from `202` —
   which most machines have and most will not have lamps. Fall back to the serial
   port after that, and say which is happening. A status shown nowhere is worse
   than no status, because it looks like nothing happened.
6. Leave the meanings alone. The seed provides the mechanism; the lookup that says
   what a given code means is something the grown machine builds for itself
   (`docs/006`), and baking a vocabulary in here would be deciding something that
   is not ours to decide.

## Blocks

The phase 2 demo.

## Blocked by

`201`, `202`.

## Related documents

`docs/006-datapath-status-and-tolerance.md` — the three numbers, and why fifty is
the middle.
