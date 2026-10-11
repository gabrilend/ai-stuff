<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Phases are clusters of functionality, ordered by what builds on what,
     not by calendar. Each phase names the demo it ends with. -->

# Roadmap

Each phase is a group of related machinery. Lower phases are the ground the
higher ones stand on; work in a lower phase can still happen late. Progress
is not tracked here — see `issues/phase-N-progress.md`, or run
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua <project> -m`.

## Phase 1 — The world beneath

A headless, deterministic simulation: the program's doors (reads `input/`,
writes `output/goodbye`), seeded randomness, a fixed tick, the polar world of
hub, quadrants and tier rings, stands that move in tier-time, combat split
across worker threads, couriers that carry orders with real transit delay,
and the snapshot handoff to whatever is watching.

**Ends with:** a demo that runs a seeded battle with no window and prints
the statistics that matter — ticks per second, courier transit times by
tier, losses by direction, and a check that two runs with the same seed
produce identical worlds — then plays the recorded snapshots in a plain
debug window.

## Phase 2 — Glass and metal

The rendering kit, with no game in it: palette tokens from dark to bright,
brushed-metal and glass-refraction shaders, circle, ring, arc and half-circle
shapes, text along arcs, rotating parts with weight and detents, readouts
that roll like odometers, bright buttons, and complication windows.

**Ends with:** a showroom window of every element, live, with frame-time
and draw-call counts, and sliders for tone and rotation speed.

## Phase 3 — The wheel at the center

The command wheel assembled over the hub: the lazy-susan rim that chooses the
stand, the face of order buttons and readouts, the strict button-then-map
order grammar, couriers drawn on the map, the accordion with its reach and
squeeze dials, and the calendar complication.

**Ends with:** a playable skirmish on phase 1's simulation through the
real console: one human seat against a scripted foe, with live counts of
orders given, mean transit time, and accordion settings in use.

## Phase 4 — Factories and engineers

Metal, glass and aether income; factories and their build queues; waypoint
paths that lock once set; engineers that dismantle and rebuild.

**Ends with:** a demo of a quadrant's economy over time — income, spending,
units made per factory, path lengths — shown as rotating readouts and a
chart, with one factory dismantled and rebuilt mid-run.

## Phase 5 — The round table

The team: quadrants per seat, hot-seat switching between stand-ins, the
distribution vote with priority weights, the next-purchase vote, and the
vote cadence set from the calendar complication.

**Ends with:** a four-seat hot-seat game where each seat holds different
priorities, showing how each vote was tallied and where every resource went.

## Phase 6 — Foes in every direction

Generated non-linear terrain in each tier band, a foe per direction with
outposts at each tier, foe AI, helper AI for unplayed seats, fronts being
decided and advancing outward, and flanking forces moving side to side.

**Ends with:** a full game against four AI foes, with a live map of every
front's tier and a timeline of when each front was decided.

## Phase 7 — Growing outward

The choice catalog generated from equal value budgets, two-step roll tables,
parity-matched offers, prices and aether unlocks, held choices that
strengthen their unlock, level-ups for both sides of a front, and heroes sent
adventuring with the depth dial.

**Ends with:** a balance demo: thousands of offers rolled across threads,
with the spread of offer values per side, how often each table entry came
up, and a played game showing the same foe at tier 1 and tier 3 having
grown differently from you.

## Phase 8 — Across the wire

Lockstep networked play over ENet: commands stamped with ticks, a lobby that
seats players, and world checksums that catch any divergence.

**Ends with:** two or more game windows (on one machine or several) playing
the same game, with live round-trip times and checksum agreement shown.
