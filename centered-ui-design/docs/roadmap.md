<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Phases are clusters of functionality, ordered by what builds on what,
     not by calendar. Each phase names the demo it ends with. -->

# Roadmap

Each phase is a group of related machinery. Lower phases are the ground the
higher ones stand on; work in a lower phase can still happen late. Progress
is not tracked here — see `issues/phase-N-progress.md`, or run
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`.

## Phase 1 — The world beneath

A headless, deterministic simulation built the soramech way — stations that
run when every input has arrived: the program's doors (reads `input/`,
writes `output/goodbye`), the soramech stations and pool, seeded randomness,
a fixed tick, the world of hub, quadrants and tier rings, stands that move in
tier-time, combat as one station per direction, couriers that carry orders
with real transit delay, and the snapshot handoff to whatever is watching.

**Ends with:** a demo that runs a seeded battle with no window and prints
the statistics that matter — ticks per second with one worker and with all,
courier transit times by tier, losses by direction, and a check that two
runs with the same seed produce identical worlds — then plays the recorded
snapshots in a plain debug window.

## Phase 2 — Glass and metal

The rendering kit, with no game in it: palette tokens from dark to bright,
brushed-metal and glass-refraction shaders, circle, ring, arc and half-circle
shapes, text along arcs, dials (paper-thin discs under seamless glass,
turned only by the game), nested dials, readouts that roll like odometers,
bright buttons, the far camera, small 3D models, and formula voxel effects.

**Ends with:** a showroom window of every element, live, with frame-time,
draw-call, voxel and depth-precision counts on dials.

## Phase 3 — The wheel at the center

The dashboard assembled over the hub: naming a stand with a map click, the
strict map-then-dashboard order rhythm, couriers drawn on the map, the
sphere projected onto the circle, merged stands showing level and count with
balance colors and triangles, and the calendar dials.

**Ends with:** a playable skirmish on phase 1's simulation through the real
dashboard: one human seat against a scripted foe, with live counts of orders
given, mean transit time, the rhythm of map-then-dashboard clicks, and
stands merged on screen.

## Phase 4 — Factories and engineers

Metal, glass and aether income; factories built by telling engineers; build
queues; waypoint paths that lock once set; engineers that dismantle and
rebuild.

**Ends with:** a demo of a quadrant's economy over time — income, spending,
units made per factory, path lengths — shown on rolling dials and a chart,
with one factory dismantled and rebuilt mid-run.

## Phase 5 — The round table

The team: quadrants per seat, hot-seat switching between stand-ins, the
distribution vote with priority weights, the next-purchase vote, and the
vote cadence paced by the calendar.

**Ends with:** a four-seat hot-seat game where each seat holds different
priorities, showing how each vote was tallied and where every resource went.

## Phase 6 — Foes in every direction

Generated non-linear terrain in each tier band of the sphere, the underworld
face, a foe per direction with outposts at each tier, foe AI, helper AI for
unplayed seats, fronts being decided and advancing outward, and flanking
forces moving side to side.

**Ends with:** a full game against four AI foes, with a live map of every
front's tier and a timeline of when each front was decided.

## Phase 7 — Growing outward

The choice catalog generated from equal value budgets, two-step roll tables,
parity-matched offers, prices and aether unlocks, enhancements that wait in
the tray and slot into powers when acquired, level-ups for both sides of a
front, and heroes told to adventure deeper.

**Ends with:** a balance demo: thousands of offers rolled across threads,
with the spread of offer values per side, how often each table entry came
up, and a played game showing the same foe at tier 1 and tier 3 having
grown differently from you.

## Phase 8 — Across the wire

Lockstep networked play over ENet: commands stamped with ticks, a lobby that
seats players, and world checksums that catch any divergence.

**Ends with:** two or more game windows (on one machine or several) playing
the same game, with live round-trip times and checksum agreement shown.

## Phase 9 — Reading the machine

A walk through this project one function or datastructure at a time: a map
of stops built from the source and its `.info.md` files, the recorded reasons
behind each choice drawn from issues, comments and transcripts, a room the
guide owns for its record of the reader, and a local AI guide that steps back
when a part is not landing and summarizes when the reader skips. Built in
parallel with delta-version issue 065. Reading is the license; nothing grades
the reader.

**Ends with:** a walk of this repository with the count of stops, the count of
decisions with no recorded reason, and a guided path drawn on the face.

## Phase 10 — The machine answers

One delivery contract for any signal — a single setting, or a stream sent in
numbered chunks rmail-attachment style — and a physical output that follows
it. First source: the pitch of spoken sentiment sentences. First output: a
fan driven by a user account with one permission. Built in parallel with
delta-version issue 066.

**Ends with:** spoken sentences turning the fan up and down, with pitch,
chunks, requested speed and measured speed shown.
