# Roadmap

Seven phases. They are **clusters of functionality**, not a schedule and not a
progress bar. A phase is finished when its issues are, and it is entirely normal
for the last issue completed in this project to belong to phase one.

Each phase ends with a demo in `issues/completed/demos/`, runnable from
`./run-phase-demo`. The demos are not development artifacts — they are part of
the deliverable, they show the features of the real program rather than
describing them, and they are updated as the program is.

## Phase 1 — The Stone

The world exists and can be inspected. Nothing moves and nothing is drawn in a
window.

| Issue | |
| --- | --- |
| [101](../issues/completed/101-a-column-is-one-integer.md) | a column is one integer |
| [102](../issues/completed/102-surfaces-are-a-bit-trick.md) | surfaces are a bit trick |
| [103](../issues/completed/103-randomness-comes-from-named-streams.md) | randomness comes from named streams |
| [104](../issues/completed/104-the-terraces-are-piled-rectangles.md) | the terraces are piled rectangles |
| [105](../issues/completed/105-the-maze-is-a-spanning-tree-over-rooms.md) | the maze is a spanning tree over rooms |
| [106](../issues/completed/106-staircases-are-cut-not-built.md) | staircases are cut, not built |
| [107](../issues/completed/107-four-answers-to-may-i-move.md) | four answers to "may I move" |
| [108](../issues/completed/108-the-validator-refuses-a-broken-maze.md) | the validator refuses a broken maze |

Done when a seed produces a maze, the validator says it is one connected piece,
and the same seed produces the same maze twice.

## Phase 2 — The Eye

The maze becomes visible, three different ways.

| Issue | |
| --- | --- |
| [201](../issues/completed/201-world-to-screen-and-back.md) | world to screen, and back |
| [202](../issues/completed/202-the-renderer-is-one-linear-sweep.md) | the renderer is one linear sweep |
| [203](../issues/completed/203-three-tones-and-a-mottle.md) | three tones and a mottle |
| [204](../issues/completed/204-pan-zoom-and-the-pointer.md) | pan, zoom, and the pointer |
| [205](../issues/completed/205-a-terminal-viewer-so-we-are-not-blind.md) | a terminal viewer so we are not blind |
| [206](../issues/completed/206-headless-and-the-report.md) | headless, and the report |

Done when the same maze can be looked at in a window, read in a terminal, and
measured with no window at all.

## Phase 3 — The Rolling

The first thing that moves. This is the vision's first sentence.

| Issue | |
| --- | --- |
| [301](../issues/completed/301-a-body-is-an-index-into-flat-arrays.md) | a body is an index into flat arrays |
| [302](../issues/completed/302-the-tick-is-a-table-of-passes.md) | the tick is a table of passes |
| [303](../issues/completed/303-locomotion-is-a-dispatch-table.md) | locomotion is a dispatch table |
| [304](../issues/completed/304-the-floor-is-an-interpolated-height-field.md) | the floor is an interpolated height field |
| [305](../issues/completed/305-a-ball-collides-with-faces-and-corners.md) | a ball collides with faces and corners |
| [306](../issues/completed/306-falling-is-shared-by-everybody.md) | falling is shared by everybody |
| [307](../issues/completed/307-the-aquarium-tops-itself-up.md) | the aquarium tops itself up |
| [308](../issues/completed/308-bodies-are-bucketed-by-cell.md) | bodies are bucketed by cell |

Done when balls roll down the maze, none of them get inside a wall, and the
headless report can prove both.

## Phase 4 — The Wandering

The vision's second sentence: little guys with idle animations and interactions.

| Issue | |
| --- | --- |
| [401](../issues/completed/401-a-step-from-surface-to-surface.md) | a step from surface to surface |
| [402](../issues/completed/402-smoothing-belongs-to-the-renderer.md) | smoothing belongs to the renderer |
| [403](../issues/completed/403-a-path-is-found-once-and-kept.md) | a path is found once and kept |
| [404](../issues/completed/404-an-idle-is-a-row-with-a-clock.md) | an idle is a row with a clock |
| [405](../issues/completed/405-the-meet-pass-pairs-bodies.md) | the meet pass pairs bodies |
| [406](../issues/completed/406-two-bodies-idling-together.md) | two bodies idling together |
| [407](../issues/completed/407-the-director-decides-what-is-worth-watching.md) | the director decides what is worth watching |
| [408](../issues/completed/408-the-panel-and-its-sliders.md) | the panel and its sliders |

Done when a crowd of little guys wanders, sets itself errands and finishes them,
stands about, notices each other, and the camera can be told to go and find
somebody more interesting. `./run-maze --scene crowd` runs it.

## Phase 5 — The Fencing

The vision's third sentence.

| Issue | |
| --- | --- |
| [501](../issues/completed/501-a-duel-is-a-record-not-two-flags.md) | a duel is a record, not two flags |
| [502](../issues/completed/502-damage-is-buffered-then-applied.md) | damage is buffered, then applied |
| [503](../issues/completed/503-a-duel-has-to-end.md) | a duel has to end |
| [504](../issues/completed/504-teams-and-what-the-camera-does-with-them.md) | teams, and what the camera does with them |

Done when two sides meet in the corridors, fight, and the fights end four
different ways. `./run-maze --scene war` runs it.



## Phase 6 — The Habitat

The vision's fourth sentence.

| Issue | |
| --- | --- |
| [601](../issues/completed/601-a-body-wider-than-one-cell.md) | a body wider than one cell |
| [602](../issues/completed/602-marching-a-line-through-stone.md) | marching a line through stone |
| [603](../issues/completed/603-hiding-is-stopping-somewhere-unseen.md) | hiding is stopping somewhere unseen |
| [604](../issues/completed/604-a-game-is-roles-and-an-ending.md) | a game is roles and an ending |

Done when dinosaurs move through the maze, cannot go everywhere the little guys
can, hide from each other, and play games that end. `./run-maze --scene jungle`
runs it.

**Phases 1 to 6 are complete — the whole of the original vision.**

## Phase 7 — The Delve

The mode that was added after the vision was written.

| Issue | |
| --- | --- |
| [701](../issues/completed/701-a-mode-is-which-tables-are-loaded.md) | a mode is which tables are loaded |
| [702](../issues/completed/702-riding-is-a-derived-position.md) | riding is a derived position |
| [703](../issues/completed/703-fire-is-a-state-that-spreads.md) | fire is a state that spreads |
| [704](../issues/completed/704-a-golem-changes-the-stone.md) | a golem changes the stone |
| [705](../issues/completed/705-vines-creep-along-walls.md) | vines creep along walls |
| [706](../issues/completed/706-the-automaton-solves-itself.md) | the automaton solves itself |
| [707](../issues/completed/707-a-monster-is-a-lock.md) | **in progress** — a monster is a lock |

Six of seven done. The cycle runs — automatons burn vines, vines hold golems,
golems smash automatons and walk through walls — and the party has no goal, which
is the half that rests on [open question 3](026-open-questions.md). See
[the phase 7 progress](../issues/phase-7-progress.md).

## Phase 8 — The Mountain

The world stops being generated. The reference picture turns out to contain no
walls at all, only flat plates at many elevations and the staircases between
them, laid over the face of a mountain that falls toward the viewer — and a
surface that never rises toward the camera is visible everywhere without any pass
to make it so.

| Issue | |
| --- | --- |
| [801](../issues/completed/801-a-map-is-plates-and-stairs.md) | a map is plates and stairs |
| [802](../issues/completed/802-the-mountainside-is-hard-coded.md) | the mountainside is hard-coded |
| [803](../issues/completed/803-the-height-field-becomes-a-model.md) | the height field becomes a model |
| [804](../issues/completed/804-a-ball-is-a-sphere-against-faces.md) | a ball is a sphere against faces |
| [805](../issues/805-a-ball-is-a-sprite-in-a-solid-world.md) | **not started** — a ball is a sprite in a solid world |
| [806](../issues/completed/806-balls-collide-with-each-other.md) | balls collide with each other |

Done when balls dropped at the summit find their own way to the bottom, bouncing
down real staircases against real faces. See
[the phase 8 progress](../issues/phase-8-progress.md).

The generator of phases 1 and 2 still runs and still passes its tests. It is not
deleted and it is not defended; whether a generator is written again, and whether
it produces mountainsides rather than pyramids, is a question for after the
hand-authored map has proved what a map should look like.

## What is not in any phase

**The jungle, and this is settled rather than pending.** The volcanoes, the sky,
the foliage and the dinosaurs standing outside the maze in the reference picture
are never going to be here. All scenery, no simulation behind any of it, and it
would be the largest art commitment in a project with no art at all. Was open
question 6.

Sound. Networking. Anything a person can control other than the camera. None of
these have been asked for and none are assumed.

**The thread pool.** The passes declare whether they are safe to split and
nothing reads it. Fourteen hundred bodies cost about three and a half
milliseconds a tick, which is a fifth of a frame — and the largest speed-up in
the project by far was not parallelism but raising LuaJIT's trace cache limits,
which was worth eleven times. The flags being *stated* is what makes adding a
pool later a change to the tick rather than an audit of every pass.

## Related documents and tools

- [Open questions](026-open-questions.md) — what is unsettled, and blocking what
- [Ways this could go wrong](027-ways-this-could-go-wrong.md)
- `./run-phase-demo` — the demos, as they arrive
