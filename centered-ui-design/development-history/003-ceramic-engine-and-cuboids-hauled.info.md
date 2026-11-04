<!-- made by scripts/capture-history on 2026-10-10 20:16, from the
     game run as: run /tmp/claude-1000/-mnt-mtwo-programming-ai-stuff-centered-ui-design/151ddaeb-59f4-466e-abd5-8862afcb9075/scratchpad/history/81facb00f/game-at-81facb00f --click 12 300 300 --screenshot 14 -->

# 003 — ceramic-engine-and-cuboids-hauled

- **Picture:** 003-ceramic-engine-and-cuboids-hauled.png
- **Commit:** 81facb00f 2026-10-10 centered-ui-design: the world runs on the ceramic engine; units haul cuboids home
- **Run:** `run --click 12 300 300 --screenshot 14` (from /tmp/claude-1000/-mnt-mtwo-programming-ai-stuff-centered-ui-design/151ddaeb-59f4-466e-abd5-8862afcb9075/scratchpad/history/81facb00f/game-at-81facb00f)

## What it shows

The view has turned so seat 1's amber quadrant faces up (the player's
chair). Four colour-coded sections ring the hub as bright ovals; cuboids —
small glazed rounded cubes in the four colours — lie about, are carried in
front of figures' chests, and stack in their sections (a green stack at
left). The arch's band now carries the map painted onto it from above: the
amber quadrant unrolled along it. Only a sliver of the allies' arches shows
at the feet. Four small dials under the calendar count the cuboids resting
in each section, inked in its colour (1, 0, 4, 4). The named slot reads
SEAT 4 - LEVEL 3. 144 frames a second, with the world worked out on the
ceramic engine's worker threads.


## The story so far

The world's work moved to soramech's C engine ("ceramics"): C boxes
compiled by serac, handed in by the batch, never waited on, LÖVE's main
thread rendering only. Units haul cuboids to the sections of their colour,
claims going to the lowest-numbered unit so the result never depends on
which worker finishes first. Two bugs met on the way — cuboids dropped the
moment they were lifted, and a band that never painted — were found by
probes and screenshots and fixed. Next, the owner brought reference
pictures of a tilt-shift look (a valley receding to mountains) and asked for
that depth wrapped all the way round the dashboard, lighting as spinning
dial textures instead of a skybox, both versions of everything to compare,
and this history of pictures.

