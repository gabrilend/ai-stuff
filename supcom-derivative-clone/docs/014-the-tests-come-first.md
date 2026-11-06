# 014 — The Tests Come First

There is no source yet. There are tests. This document is the contract between
them: how a test finds the thing it is testing, what it does when the thing is
not there, and what each test file has decided about the source before the
source exists.

## Why the tests were written first

A test written after the code tests what the code happens to do. A test written
before the code is a statement of what the code is *for*, and the code is then
designed to satisfy a statement rather than to satisfy itself. For a project
whose source will be built system by system from issue files, the tests are the
issue files' assertions made executable — the part of a blueprint that can say
no.

Every test file therefore fails today, and it fails in exactly one way: **the
module it looks for does not exist.** That is reported as a named absence — the
file it looked for, and the issue that creates it — and never as a skip. When
the issue is built, the test starts asking its real questions.

## How a test finds its subject

Source files are numbered, and their numbers are claimed when they are created.
A test cannot know the number of a file that does not exist yet, so a test never
names a number. It names the file's **stem** — the part after the index — and the
harness looks for exactly one file in `src/` whose name ends in that stem:

    local dunes = harness.load("the-dunes", "102")   -- finds src/NNN-the-dunes.lua

Zero matches is the named absence above. Two matches is an error too, because a
stem that two files share is a naming bug and not something to pick between.

The harness is `tests/018-the-harness.lua`, the first numbered file there. It
holds the loader, the assertion helper, the seed, the report format, and the
rule that a test program exits non-zero if any claim in it did not hold. A
`suite` groups the claims that share a subject, so that one absent module fails
once by name and the other suites still run. A test that needs a world asks the
harness's `fresh_world(parameters, modules)`, which puts it together through the
tick's `assemble` like a match does; the report is `finish()`, the last line of
every program.

**Source with no test is a failure.** For every stem in the table below whose
file exists under `src/` or `assets/`, the issue that owns it -- the first its
row names -- must be named by some test's covers line, or
`./validate-documentation` fails naming the stem and the issue. A stem with no
file yet is only counted. And every bug fixed gets a test that fails without
the fix, in its phase's program, under a folded function whose comment says
what went wrong.

## What every test file carries

At its head, after the licence, a line naming the issues it can be shown to
specify:

    -- covers: 102, 103, 104

The validator reads those lines. A covered issue must have a file, and the
census counts how many issues have a test naming them. **Under-claim on
purpose.** A mechanic wrongly marked covered is worse than one marked missing;
the pixels of phase 6, the handheld's screens, and a person against the bot are
looked at rather than asserted, and are not claimed.

## The stems the tests have decided on

These are the source files the tests look for, by stem, with the exports each
test calls. This table is the design of `src/` before `src/` exists, and the
issue that builds each one takes the stem and the signatures as given. An issue
that needs a new export adds it here first, in the same breath as it adds it to
the test.

| Stem | Issue | What the tests call |
| --- | --- | --- |
| `the-dunes` | 102 | `raise(parameters, seed)` returns a field with `size`, `height`, `water_line`; `validate(field)` raises naming the cell; `dump(field)` returns text; also `index(field, x, y)`, the one place a cell's index is computed, and `cell_of(field, x, y)` |
| `sightlines` | 103 | `can_see(field, x1, y1, eye, x2, y2, profile)` returns a boolean; `questions_asked()` returns a count; `reset_questions()` clears it |
| `the-world` | 104 | `allocate(parameters)` returns flat arrays with the integer zero everywhere; `validate(world)`; `claim(world, group)` and `release(world, group, id)` for a pool's rows; `load(stem)` and `load_asset(stem)`, the loader every module uses; `LAYOUT` and `COUNTERS` |
| `the-tick` | 105, 801 | `SYSTEMS`, an ordered table of rows `{name, run, sliceable, run_slice}`, with `waiting_for` naming the issue on a row not yet built; `advance(world)`; `assemble(modules, parameters)`; `ticks_of(seconds)` |
| `timers` | 106 | `counter(period)` returns `{period, increment, ...}`; `advance(counter, tick)`; `read(value, written_at, counter, cap)`; `write(value, written_at, counter, cap, change)` returns the new pair; `ticks_of(seconds, rate)` |
| `random-streams` | 107 | `open(seed, name)`; `next_integer(stream, below)` in `[0, below)`; `next_double(stream)` in `[0, 1)`; `STREAMS`, the names; `draw(world, name, below)` and `draw_double(world, name)` for the world's own streams |
| `the-rules` | 105, 112 | a table in `assets/`: `ticks_per_second`, the claim's `claim_seconds` and `claim_increments`, the sizes of the command queue, the refusal ring, the shot queue (`shots_per_unit`) and the bone queue (`bones_per_unit`), and `fingerprint_every`; copied into the world as `world.rule` |
| `commands` | 108 | `VERBS`, a dispatch table, and `ARGUMENTS`, each verb's argument names; `queue(world, command)` returns nothing or a refusal string naming the reason; `apply_due(world)` returns how many applied; `refusals(world)` returns the ring's refusals, oldest first; `unpack(world, row)` |
| `snapshot` | 109 | `hash(world)`; `copy(world)`; `record(world, path, commands)`; `replay(path)`; `stamp(world)`; `snapshot_pass(world)`, the tick's last row; `note_command(world, command)`, the door's hook |
| `headless-runner` | 110 | `run(root, options)` — options carry `seed`, `ticks`, `field`, `bots`, and `units` and `replay` — returns a report with `ticks`, `hash`, `seed`, `factories`, `shortest_pattern`, and `ended`, `replay`, `replay_checked`, `mismatch_tick`, `world`; `lines(report)` |
| `terminal-viewer` | 111 | `draw(snapshot, options)` returns a string with a row per field row, tinted when `options.colour` is set; `GRADES`, `WATER`, `LETTERS`, `UNKNOWN`, `SEEN`, `BONE`, `COLOURS` |
| `territory` | 112 | `claim(world, team, x, y, radius)`; `claim_pass(world)`; `owner(world, cell)`; `percent(world, team)` |
| `units` | 201, 202 | `spawn(world, kind, team, x, y)` returns an id, refusing an unknown kind by name; `alive(world)` returns a count; `catalogue()`, the unit catalogue loaded, validated and converted to ticks; `validate_catalogue(raw, rate)`; `kind(name or index)`, `index_of(name)`, `name_of(index)`; `counters()`, the heal and recharge counters the catalogue asks for; `validate(world)`; `dump(world, id)`; `report()` |
| `unit-catalogue` | 202 | a table in `assets/`, one row per kind, every field an integer, a double, or a name: `health`, `damage`, `shell_speed`, `heal_period`, `eye`, `profile`, `shield`, and the rest the issue lists |
| `domains` | 203 | `can_stand(field, domain, x, y)`, the domain a name or an integer; `altitude_at(field, kind, x, y)`; `is_shore(field, x, y)`; `ground_at(field, x, y)`; `validate(world)`; `LAND`, `AIR`, `SEA`, `REACH`, `STAND` |
| `movement` | 204 | `move_pass(world)` and `move_pass_slice(world, first, last)`; `occupancy_pass(world)`; `step_length(field, kind, from_x, from_y, to_x, to_y)`; `held(world, id)` |
| `targeting` | 205, 405, 502 | `aim_pass(world)` and `aim_pass_slice(world, first, last)`; `falloff(kind, distance)` returns a fraction; `flight_ticks(kind, distance)`; `candidates(world, shooter)`; `visible(world, shooter)`; `sees(world, a, b)`; `ready(world, id)`; `distance(world, a, b)` |
| `combat` | 206, 207 | `fire_pass(world)` and `fire_pass_slice(world, first, last)`; `land_pass(world)`; `die_pass(world)` returns how many died; `die_row(world)`, the tick's die row: the die pass, then the enforcers' eat pass; `hurt(world, id, amount)`; `health(world, id)`; `damage_at(world, id, distance)`; `describe(world, index)` returns one shot as a line |
| `bones` | 208 | `leave(world, unit)` returns the bone row, or zero for a kind whose bones carry nothing; `leave_at(world, x, y, mass)`; `eat(world, unit, bone)` returns the mass; `near(world, x, y, radius)` returns bone rows in queue order; `mass_of(kind)`; `total(world)` |
| `thread-pool` | 209 | `slice(count, workers)` returns contiguous ranges, each `{first, last}`; `run_sliced(system, world)` over a tick row, returning the ranges; `trace_writes(body, world)` returns every write the body made, as `{array, field, index}`; `outside(world, run_slice, first, last)` names the first unit row written outside the range; `configure(workers, backend)`, `workers()`, `read_workers(root)`, `cores()`, `BACKENDS` |
| `command-truck` | 210 | `move(world, id, x, y)` and `launch(world, id, heading)` return nothing or a refusal (heading in compass degrees, nought north); `trucks_alive(world, team)`; `owned_by(world, id, team)`; `next_launch_tick(world, team)`; `KIND`, `PLANE`, `MISSIONS`, `MISSION` |
| `enforcer` | 211 | `eat_pass(world)`; `absorb(world, target, amount)` returns what the sphere leaves, and `combat.hurt` calls it (it replaces the `shield_pass` first named here: a shield on a pair needs no pass); `upgrade(world, id)` returns the step; `step`, `cap`, `sphere`, `shield`, each `(world, id)` |
| `economy` | 301, 303, 305, 311 | `income_pass(world)`; `held_cells(world, team)`; `construction_pass(world)`; `build_power(world, team)`; `place_energy(world, team, cell)`; `find_hydrocarbon(world, team, cell)`; `consequences_pass(world)`; `cell_pays(world, cell)`; `improve(world, team, cell)` |
| `energy-menu` | 302 | `LEVELS`, four rows; `set_level(world, team, level)` raises on a fifth |
| `roster` | 304, 309 | `add(world, team, kind, count)`; `count(world, team, kind)`; `on_energy(world, team)`; `hurt(world, team, fraction)`; `hurt_count(world, team, kind)`; `hurt_ids(world, team)` |
| `cost-table` | 306 | a table in `assets/`; `for_kind(kind)` returns `mass`, `energy`, `build_ticks`; `RATIO` by alignment |
| `factories` | 307, 308 | `LINES`, the catalogue of lines; `place(world, team, cell, domain, line, pattern)` returns an id; `emit_pass(world)`; `stop(world, id)`; **no** `redraw` |
| `thorns` | 310 | `build(world, team, amount)`; `spend_pass(world)` |
| `the-cloud` | 401 to 406 | `MISSIONS`, a dispatch table; `fly_pass(world)`; `round_pass(world)`; `report(world, team, x, y)` |
| `plane-upgrades` | 407 | as source: `buy(world, team, name)` raising on an unknown name; `strength(world, team)`. As an asset: one row per upgrade with `energy` and `strength` |
| `experimentals` | 501 to 505 | as an asset: one row per experimental, none carrying a team. As source: `place_carrier(world, team, kind, pattern, line, attack_pattern, keep_hold)` returns an id; `carrier_pass(world)` |
| `the-viewer` | 601, 605, 607 | `take(snapshot)`; `layout(width, height)`; `current()`; `begin_pattern(spec)`, `add_point(cell)`, `finish_pattern(issue)` returns the one command; `begin_wheel(spec)`, `point_wheel(dx, dy)`, `finish_wheel(issue)` returns the one command |
| `lenses` | 603 | `new(spec)` refusing an unknown layer; `push(lens, sx, sy, factor)`; `to_screen(lens, x, y)`; `to_field(lens, sx, sy)` |
| `lockstep` | 701, 702, 705, 706 | `join(world, spec)` returns a peer; `issue(peer, command)`; `step(peer)`; `schedule(command, tick, delay)`; `waiting_for(peer)`; `halted(peer)` returns the tick or nothing; `evidence(peer)` returns a path in the RAM tier; `rejoin(peer, from)` |
| `transport-loopback` | 703 | `open()` returns a wire with `endpoint(name)`, `cut(name)`, `mend(name)`; an endpoint has `send(peer, datagram)` and `receive()` returning the sender and the datagram, or nothing |
| `discovery` | 704 | `new(spec)`; `announce_pass(d, tick)`; `listen_pass(d, tick)`; `heard(d, name)`; `lobby(d)` returns the agreed `seed` |
| `box-map` | 805 | `describe(SYSTEMS)` returns a map with one station per system; `write(map)` returns the map file's text |
| `the-bot` | 901, 903 | `think(snapshot, team)` returns a list of commands; `DIFFICULTIES`, rows each with `sees` |
| `overnight` | 902 | `run(root, options)` returns the path it wrote, in the RAM tier |

A stem not in this table is a stem no test asked for, and an issue that wants
one adds a row here first.

## The world fields the tests touch

The tests reach into the world record directly where a claim is about the data
rather than about a function. Those fields are part of the contract too, and
the world's layout must carry them under these names. Issue 104 laid down the
unit, cell, team and stream groups and the claim counter, and issue 108 the
command queue and the refusal ring, and issue 112 the claim's presence fields
and the marked queue, issue 206 the shot queue, and issue 208 the bone queue;
every other group and
field below is added to the layout, under the name given here, by the issue that
builds the system that writes it:

- `world.tick`
- `world.field.{size, height, water_line}`
- `world.unit.{count, alive, kind, team, x, y, target, pattern, leg, health, health_at,
  shield, shield_at, eaten, eat_share, mission, strength, in_round, goal_x, goal_y,
  claim_radius, waited}`
- `world.pattern.{count, points}`
- `world.shot.{count, shooter, target, damage, arrives}` — the shells in flight (issue 206)
- `world.bone.{count, x, y, mass}`
- `world.heal.<kind>`, `world.reload.<kind>`, `world.recharge.enforcer`, `world.launch`, `world.cloud_round`,
  `world.claim.{period, increments_to_claim}` — every one a counter from issue 106
- `world.team.{mass, mass_income_last_tick, energy, thorns, energy_level, launch_at}`
- `world.cell.{owner, hydrocarbon, improvement, claim_by, claim_began, claim_seen, mark, occupant}`
- `world.marked.{count, cell}` — the claim pass's scratch, empty between passes (issue 112)
- `world.building.alive`
- `world.factory.{line, running, pattern}`
- `world.flip.{count, cell, from, to, by}`
- `world.carrier.{held, moving}`
- `world.cloud.{x, y}`
- `world.rule.mass_per_cell`
- `world.applied_at`
- `world.command.count`, `world.refusal`, `world.fingerprint`, `world.fingerprint_tick`, `world.record_path`

## What the tests assert, in one line each

- **The dunes and the clock** (`tests/019`). The same seed raises the same field;
  a raised field passes its own validator; a sightline over a crest is false and
  along a flat is true; the world has no absent values; the tick's systems are in
  the documented order; the timer pair derives the right value after any number
  of increments; named streams are independent and reproducible; a command for
  a past tick is refused; the hash of two identical runs is identical; a claim
  completes after enough increments and not before.
- **Things that roll, fly, and sail** (`tests/020`). A spawned unit is one row;
  the catalogue's hits-to-kill relations hold; damage falls off and never below
  its floor; a shot lands at the tick its distance says; one increment heals
  every tank without a walk; bones carry mass; the truck moves and the
  enforcer's sphere absorbs.
- **Inflows and outflows** (`tests/021`). Mass income is cells times pay; the
  four levels split engineers as documented; a lost cell removes its building's
  energy; the cost ratios hold for every kind; a build stalls with no mass; a
  pattern with a point in the water is refused by name; losing a fraction of
  ground hurts the same fraction of the roster.
- **The cloud** (`tests/022`). A plane with no orders is in the cloud; a weaker
  side goes defensive; an interceptor over enemy ground is shot by a gun that
  sees it; a report sends exactly the unbothered, equipped planes.
- **The big things** (`tests/023`). Artillery loses nothing to distance; a moving
  carrier builds without drawing resources and unleashes when it stops unless
  held.
- **Watching it happen** (`tests/024`). A lens push keeps the point under the
  cursor fixed; the viewer reads a copy; a drawing leaves as one command.
- **Other players** (`tests/025`). Two lockstep worlds fed the same batches agree
  on every hash; a missing batch stalls; a disagreeing hash names its tick; the
  loopback transport delivers in order; a dropped peer rejoins from the log.
- **The handheld** (`tests/026`). Every system in the tick is a pure function
  that writes only its declared slice, and the map file wires them in order.
- **An opponent** (`tests/027`). The bot sees only the snapshot and answers with
  commands the door knows.

Related: [the shape of the code](013-the-shape-of-the-code.md) ·
[the roadmap](015-roadmap.md)
