# Architecture

How the program is put together, and why it is put together that way.

## Two halves that never touch backwards

The program is two halves joined by one narrow seam.

- **The simulation** (src/001 through src/020) generates everything that
  happens: bodies, swings, hits, rounds, the campaign. It is plain LuaJIT and
  never calls the game engine. It runs identically under a bare `luajit`
  with no window, which is how the tests and the headless runner use it, and
  inside the game engine, which is how a person plays it.
- **The view** (src/021 through src/030) reads the simulation's state and draws
  it, and turns a person's keys and mouse into *intents* handed to the
  simulation. The view may read anything in the simulation; the simulation may
  read nothing in the view.

The seam is two records:

| Record | Direction | Fields |
| --- | --- | --- |
| intent | view → simulation, once per tick, for the player's soldier | `forward` (number −1..1, W minus S), `side` (number −1..1, D minus A), `guard` (boolean, guard held), `swing` (string: "swing", "overhead" or false), `u_delta` (number, how far the mouse moved the weapon along its U this tick), `dodge` (boolean) |
| command | view → simulation, in third person | `volley` (table {x, y} target point in cells, or false), `shields` (boolean), and in the command phase `push` (compass string) and `perk` (perk name) and `be_affected` (boolean) |

Everything the view draws comes from the battle record and the soldier records
(see docs/datapath-battle-tick.md), never from a copy the view keeps of its
own. A bug in drawing therefore cannot change a battle, and a bug in a battle
shows up identically in every viewer and in the test suite.

## Reading order

Every source file starts with a number, and the numbers are the order the
program is meant to be read in: configuration first, then the field, the
bodies, the sword, the battle, the round, the campaign, the receipt; then
the matrix arithmetic, the clay, the two eyes, the command table, and the
front desk that connects them. `.file-index-counter` holds the highest number
in use, so a new file takes the next one.

## One clock

The simulation advances in fixed ticks of 1/60 second. The view's frame rate
does not change what happens: the front desk accumulates real time and runs as
many ticks as are due. A scripted run (`--key 2.5 space`) fires on the tick
whose time first reaches the scripted moment, so the same seed and the same
script always produce the same battle, frame rate or not.

## One source of chance

Every random choice draws from a named stream derived from the run's seed
(src/003-random-streams.lua). Movement, hits, minds and the campaign each have
their own stream, so changing how often the minds roll does not reshuffle
which swings land.

## Configuration in the suckless manner

Following st and dwm: every knob has its default in src/001-config.def.lua,
laid out as an aligned table with a short comment per line. A person who wants
different values copies the lines they want into config.lua at the project
root; the program reads the defaults and then the overrides. An override that
names a knob the defaults do not have is an error, not a silent no-op, so a
typo cannot quietly do nothing. Key bindings are a table of
{ key, action, argument } rows, as in dwm's keys[], dispatched by lookup.

## Dispatch, not chains

Decisions with more than two branches are tables of functions indexed by name:
the swing kinds, the modes of the front desk, the input events, the perk
effects, the soldier mind's states. Adding a kind means adding a row.

## Errors, not fallbacks

A missing catalogue entry, an unknown perk, a mod file that returns the wrong
shape, a config typo, an unknown key name: each stops the program with a
message naming the file and the field (src/002-util.lua, the `die` helper).
Nothing guesses.

## Data the world is made of

Unit types, weapons, perks and region kinds live as plain data files in
assets/catalogue/. A folder under mods/ with the same layout overlays them:
a mod file with the same name replaces the entry; a new name adds one. The
catalogue loader (src/004-catalogue.lua) validates every entry against its
schema when it loads, so a broken mod fails at start-up and not in the middle
of a round.

## Start and end

The first thing the program does is read input/ (src/018-input-and-goodbye.lua):
any `.lua` file there is a table of run options (seed, script, mode), so a run
can be set up by dropping a file into a folder. The last thing it does is write
output/goodbye: the receipt, with the time, the seed, and the counts of ticks,
frames, swings, hits, parries, trips, rounds and the result. A run that crashed
writes no receipt, so a stale receipt is the error report.

## Threads

The simulation runs on the main thread inside the game today; one battle is
small enough. Batches of headless battles (balance runs, the test suite's
determinism checks) are spread across processes, one per core, by
`./run-many-battles`. Moving the in-game simulation onto its own engine
thread, talking to the view through channels, is planned with the multiplayer
work (phase 7), because the same message format serves both.
