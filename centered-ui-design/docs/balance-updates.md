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
| 2026-10-10 | seconds per calendar day (`calendar_seconds_per_day`, input) | 3 | 24 | the light dials turn once a day; at 3 seconds the whole world flickered from noon to night and back every 3 seconds |
| 2026-10-10 | unit metal and band brightness under dial light (013) | 1.25, 1.15 | 1.9, 1.6 | dial light is softer than the old fixed glint; figures read as dark lumps (screenshot) |
| 2026-10-10 | ground under dial light (013) | the flat map alone, x1.5 | an earth base (0.26, 0.25, 0.18) plus the map x1.3, x1.35 | the flat map is near-black; seen from the hub camera the ground was a muddy slab |
| 2026-10-10 | starting view (`view_depth`, input) | hub | slant | the owner asked for the near ground by the dashboard and the far ground at the top, everything the same size; the slant view is that, so the game now starts in it (the hub and flat views stay in the menu) |
| 2026-10-10 | the slant view's reach (`slant_reach`, input, new) | — | 120 | a little past the map's edge (112), so the whole quadrant to the edge shows with a margin of table above it |
| 2026-10-10 | hauler pace (020) | 3.0 ground units per second at tier 1, shrinking far out | 0.12 tiers per second on the sphere (`WALK_TIERS_PER_SECOND`) | the walk is now measured on the sphere (issue 214, step 8); 0.12 is the old pace at tier 1 converted (3.0 / about 24.5 ground units per tier there) |
| 2026-10-10 | hauler reach (020) | 2.6 ground units at tier 1 | 0.106 tiers on the sphere (`REACH_TIERS`) | the same reach at tier 1, converted |
| 2026-10-10 | the foes' pole (`far_pole_tier`, input, new) | — | 7 | one tier past the 6 shown: far walkers cross sideways about twice as fast on screen as near ones, and the lap never shrinks to nothing inside the map |
