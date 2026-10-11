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
| 2026-10-10 | starting view (`view_depth`, input) | slant | arch | the owner asked that the world's scale match the dashboard's curve; the arch view does that, so the game starts in it (flat, hub and slant stay in the menu) |
| 2026-10-10 | the arch view's reach (`arch_reach`, input, new) | — | 112 | the map's edge at the top row above the apex: the whole distance in view |
| 2026-10-10 | console metal (014) | tone 0.52-0.57 with two fixed glints (0.22, 0.12) | tone 0.50-0.55 lit by the metal dial x1.25, sheen 0.16 at the far edge, hour highlight 0.07 | the camera now looks across the console like a desk; the circular glints read as a spinning spotlight (issue 302) |
| 2026-10-10 | console panel lamp (`PANEL_LAMP`, 014, new) | none | 0.46, 0.48, 0.55 | at midnight the metal went so dark its engraved labels could not be read (picture 022) |
| 2026-10-10 | the arch's span (`arch_span_degrees`, input, new) | one quadrant (90) | 450 | the owner asked for "magic circles" of more than 360 degrees to fit more on screen; 450 shows three seats' quadrants whole (pictures 025-027 compare 360, 450, 720) |
| 2026-10-10 | console height (`arch_height_share`, input) | 0.5 | 0.2 | the owner asked for 40% of the console's area; its width is pinned to the window, so its height went to 40% (issue 302) |
| 2026-10-10 | click reach (`PICK_REACH_SHARE`, 003) | 5% of the console's height (25 px, then 10 px after the shrink) | 3% of the window's height (30 px) | after the console shrank nobody could be clicked; the reach no longer follows the console |
| 2026-10-10 | personal space (`SPACE_AT_TIER_ONE`, `KEEP_APART_SHARE`, 020, new) | none | 3.0 ground units across at tier 1, growing with the ring's radius; a quarter of an overlap undone a step | the owner asked for units near the console to crowd closer and far ones to spread out (issue 104) |
| 2026-10-10 | view dial steps and limits (003, 016, new) | — | a tenth per wheel notch; reach 30-400 world units, span 60-1080 degrees | the owner's A (view distance) and S (field of view) dials (issue 214) |
| 2026-10-10 | painted terrain (`terrain_splotch_count`, input, new; `SPLOTCH_SIZE`, 007) | — | 1500 splotches, all 4.5 ground units across, as many to every stretch of ring | the owner's test terrain, "to test the rendering at different distances"; first sizes varied 2.5-7 and spread evenly by tier, then the owner asked for one size and an even count per length of ring |
| 2026-10-10 | the focus blur (`view_blur`, input) | on | off | the owner: "I think it's clearer without it" (it stays in the settings menu) |
| 2026-10-10 | the land as lit dots (026, 013, new) | painted splotches (1500, 4.5 across) | points every 3 ground units along each ring and between rings, sprites 5.2 across, relief bend 0.8, 9 mesas 4-9 high | the owner's terrain of "invisible points" drawn as round sprites lit by the sun; the splotch knobs are retired |
| 2026-10-10 | the ground (`view_ground`, input, new) | the painted map | dots | the owner: "we don't draw a texture onto the ground"; the painted map stays as a menu choice |
| 2026-10-10 | terrain point spacing (`POINT_SPACING`, 026) | 3.0 | 3.0 / sqrt(2) (about 2.1) | the owner: "they should be mostly overlapping, so maybe twice as many as there are now" |
| 2026-10-10 | terrain circle style (`view_circle`, input, new) | — | bars | the owner asked for a bar-chart circle to watch the turn; "shade" is the drawing, "bars-open" the same bars with a clear background |
| 2026-10-10 | a drag's carry (`DRAG_CARRY_SHARE`, 016, new) | settle on the nearest seat (half an arch) | a sixth of an arch carries on to the next seat | with arches as wide as the screen, ordinary drags slid back and dragging seemed not to work |
| 2026-10-10 | starting circle style (`view_circle`, input) | bars | shade | the turn is confirmed; the shaded circle now follows the owner's drawing |
| 2026-10-10 | the lake and its waves (026, 020, new) | — | a lake 11 across, a fifth of the way out; three waves tipping the water 0.50, 0.38, 0.26 | the owner's moving surface turned by the engine; first tips of 0.16, 0.12, 0.08 were too gentle to see (pictures 070-071) |
