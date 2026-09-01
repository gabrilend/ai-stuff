# Phase 6 — The Habitat

**All four issues complete.** The vision's fourth sentence: dinosaurs rumbling
through a habitat, hiding and playing games.

| Issue | |
| --- | --- |
| [601](completed/601-a-body-wider-than-one-cell.md) | a body wider than one cell |
| [602](completed/602-marching-a-line-through-stone.md) | marching a line through stone |
| [603](completed/603-hiding-is-stopping-somewhere-unseen.md) | hiding is stopping somewhere unseen |
| [604](completed/604-a-game-is-roles-and-an-ending.md) | a game is roles and an ending |

`./run-maze --scene habitat` is dinosaurs alone; `--scene jungle` puts little
guys in with them.

## The journey, and what it taught

### The maze had nowhere for them to stand

A three-by-three animal needs nine contiguous cells at one height, and a maze of
one-cell corridors has essentially none. Ninety dinosaurs were spawned and
fifty-seven never moved, which looks exactly like a broken locomotion row.

The fix was in the generator, three phases earlier: **plazas**, a dozen or so
courts cleared among the corridors. The reference picture has them, and they are
most of what stops it reading as uniform hatching — so they were owed anyway.

They also had to be made careful. The first version flattened any cell within a
wall's height of the clearing's level, which quietly *moves floor*: a floor cell
lowered by two is detached from whatever it was connected to outside the
rectangle. On some seeds it stranded a hundred and sixty-five cells, and the maze
validator refused the maze — correctly, and from three phases away.

### The thing nobody designed

The plazas are mostly **not connected to each other**, because the corridors
between them are one cell wide. So a maze has some number of separate enclosures
— eight, or fourteen, depending on the seed — and a dinosaur lives in one of them
for its whole life.

Nobody drew those. They are a consequence of a body being wider than a corridor,
in a maze that was generated before there were bodies at all. It is the best
thing in this phase and it is reported as a number, because otherwise nobody
would ever know it was there.

### The same footprint check, in four places, three of them missed

The step chooser was the obvious one. The other three each produced a distinct
and confusing failure:

- **The pathfinder.** A dinosaur handed a route through a corridor it cannot
  enter walks it as far as the first narrow cell and stops. What shows up is a
  search that *succeeded* and a body that did not move.
- **The errand's adjacency check**, the same thing one step later.
- **The separation rule in the meet pass** — the one place in the project that
  can put a body somewhere it does not fit. Eighteen dinosaurs of sixty ended up
  straddling walls in forty seconds, and every rule that assumes a body stands
  where a body can stand was then quietly wrong about all of them.

**What it taught:** a new property of a body is not one check. It is a check in
every place that moves one, and the way to find them is to write the invariant as
a test — "no dinosaur is standing where a dinosaur cannot stand" — rather than to
go looking.

### Blind, and then thrashing

Sight measured its eye height from the layer a body stands *on* rather than from
its feet, so every line began inside the block the creature was standing on and
**nothing could see anything**: one pair in four hundred and forty-one, and that
pair adjacent. It is one character of arithmetic and it silently disabled the
entire phase.

Then, with sight working, the cover search ran every tick for every body that
could not find any — three hundred surfaces and a sight march apiece, seventy
thousand failed searches a minute, the move pass costing nine tenths of the whole
simulation. A body in the open is not going to get a different answer in a
sixtieth of a second.

### Counting failures per caller

Fifty-eight thousand failed searches a minute, then forty-six thousand more, from
two entirely different causes. A bare total said only that something was wrong.

Adding the caller's name to the counter found both immediately: a wide body
drawing destinations from the floor at large, most of which it could never reach;
and a follower already standing on the cell it was being sent to, whose
zero-length path was being counted as a failure.

**What it taught:** a counter without a breakdown tells you a thing is happening
and gives you no way to find out where. The breakdown cost one argument.

### The four-times-slower-for-nothing measurement

Balls alone cost 1.8 seconds a minute. Walkers alone cost 1.0. **Together they
cost 12.4** — each row four times slower purely for the other one existing.

There was nothing in the simulation to find, because it was not in the
simulation. LuaJIT's default trace cache holds a thousand traces and half a
megabyte of machine code, and a run with two locomotion rows live overflows it
and flushes: forty-five flushes in three hundred ticks, twenty-two thousand
traces compiled, every one of them thrown away.

Raising the limits at world creation took the same scene from 14.3 seconds to
1.3, took the *test suite* from thirty seconds to eleven, and made "both" cost
exactly the sum of its parts again.

**What it taught:** the profile said the move pass. The move pass was innocent.
When two things are each slower for the other's presence and neither touches the
other's data, the interaction is underneath both of them.

## What is worth carrying into phase 7

- The delve adds three more creature kinds and three more locomotion rows. The
  trace cache limits are already raised; the footprint invariant already has a
  test; the failed-search breakdown already names its callers. All three of those
  were bought here and are what phase 7 gets for free.
- `braid` at zero against a chase is the demonstration this phase owes and did
  not do: a chase on a maze with no loops corners the pursued every time, and it
  would be the clearest single showing in the project that a generator knob
  decides a behaviour.
