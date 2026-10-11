<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Append-only. Every small tweak of a number gets a line here: what,
     from, to, and why. Never edit an earlier entry; add a new one. -->

# Balance updates

| Date | What | From | To | Why |
|---|---|---|---|---|
| 2026-10-10 | unit drawn height per unit of record size (`UNIT_WORLD_SCALE`, 013) | 1.7 (spheroid length) | 3.4 | units became figures with bodies, arms and legs; a figure is thinner than a spheroid, so it was drawn taller to stay visible at the default zoom |
| 2026-10-10 | `UNIT_WORLD_SCALE` (013) | 3.4 | 5.0 | at 3.4 the figures were specks at the default zoom (screenshot); 5.0 shows limbs while units stay apart |
| 2026-10-10 | cuboid edge at tier 1 (`CUBOID_SIZE`, 007) | 1.2 | 2.4 | at 1.2 cuboids were specks beside the figures in the default view (screenshot) |
| 2026-10-10 | hauler's pickup reach (`REACH_WORLD_UNITS`, 020) | 1.6 | 2.6 | follows the larger cuboid: a hauler stops about where its hands meet the cuboid's near face |
