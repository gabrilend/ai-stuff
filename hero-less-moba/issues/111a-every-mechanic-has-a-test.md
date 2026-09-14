# 111a — Every Mechanic Has a Test

| | |
| --- | --- |
| Phase | 1 — The World and the Tick |
| Blocked by | 111 |
| Blocks | — |
| Reads | [the proving ground](../docs/024-the-proving-ground.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | T1, T2, T3, T4, T5, T6 |

## Current behavior

**One kind of test, one front door, and twenty-eight of seventy-four mechanics named by
one.** Built; the census is not yet worked down, and four of the four declared tests fail
a claim.

What exists:

- **A test is a table that names things and contains no behavior.** The loader refuses a
  function in any field, and refuses any field it does not know by name.
- **Two grounds** — a short straight road with only the machinery named, and the real map
  with the whole cast — differing by one field, arranged by two verb tables that are the
  same shape.
- **The arena has no tick of its own.** The march loop moved into the walking module, the
  tick's stage table carries a named row for it that the game never runs, and a test names
  a selection of stages.
- **One measurement catalogue.** The window's readout, a terminal report and an assertion
  all ask the same named reading of the same world.
- **Claims hold over a whole run**, not merely at its last tick.
- **The census reads all three directories** and is wired into the documentation
  validator, which now fails on any mechanic in a built phase with no test.
- **The census and the validator are Lua**, not shell wrapping python.

What the four tests report, all of it new information nobody had before:

- Two allied columns **pass through each other** and arrive at opposite ends of the road.
  A body steps off the road on the way past. The overlapping this also showed has since
  been fixed — see [214](214-going-round-what-is-in-the-way.md).
- A formation **does** get past a lone ally standing in its way, which contradicts the
  scene's own written account of it. It now does so by *filtering round him*, which is
  what the scene was written to check for in the first place.
- A `wave` row places nothing in any test that also sets a clock, on the whole map, in
  silence — long known and now failing a claim rather than sitting in a comment.
- Two pairs of bodies stood inside each other in an ordinary match with no formations on
  the field at all. **Nothing overlaps anywhere any more**: across a whole eight-thousand
  tick match, at every tick, no two bodies are inside each other. That took a separation
  pass, and finding it took the claims being asked about every tick rather than the last
  one.

## Intended behavior

**A test says only nouns. Everything a test does is a row in a table the engine owns.**

This is the rule the rest of the design follows from, and it is worth stating on its
own before any field names:

> A test is an arrangement of functionality we want to measure. The engine runs
> everything. A test pulls functionality from the engine and never defines any of
> its own.

A test that defines its own tick is testing its own tick. A test that defines its own
measurement can be wrong about the world in a way the world cannot contradict. Both
have already happened here, which is why this is a rule rather than a preference.

### What a test file holds

No functions. Seven fields, and every value in them is either a plain number, a string,
or a row whose first word is something the engine can look up.

| Field | What it is |
| --- | --- |
| `covers` | which mechanics this demonstrates, by issue number. **The field that makes the census possible.** |
| `name` | what it is called on screen |
| `caption` | what a person is looking at, and what would be wrong |
| `ground` | `arena` or `match` — which world, and therefore which vocabulary |
| `want` | the modules it needs, by their name in the tick's cast. Arena only; a match has the whole cast by definition |
| `arrange` | the rows that put the world in the state being tested |
| `stages` | which part of the simulation runs, **by the engine's name for it** |
| `measure` | which readings to take, by name |
| `expect` | the claims, as rows — for when it is run rather than watched |

### The four vocabularies, all of them the engine's

**Arrangement.** A row is a verb and its arguments. Match tests use the gate's existing
verb table, unchanged. Arena tests use the same kind of table on
[the arena](../src/068-the-arena.info.md) — putting a formation somewhere, putting a
single body somewhere. Adding something a test can arrange is adding a row, in the
engine, where the thing being arranged already lives.

**Stages.** The tick is already an ordered array of named systems. A test names which
of them run, and gets those rows out of the real array rather than a hand-written
imitation. **This is what removes the arena's second definition of marching**, which
[the proving ground document](../docs/024-the-proving-ground.md) currently states as
the arena's plainly-admitted cost. The march loop moves into the walking module beside
the step it repeats, the tick gains a named row for it, and the arena stops having a
tick of its own.

Common selections are **presets in the engine** — `marching`, `fighting`, `whole_match`
— so a scene names a preset rather than reciting a list, and a preset that turns out to
be wrong is wrong in one place.

**Measurement.** A named reading over a world: how far the leading body has come, how
deep the group is, how many are going round something, how many are alive. The scene
viewer's readout, the headless report and an assertion all ask for the same named
reading, so a number seen in the window and a number seen in a terminal are the same
number rather than two measurements that ought to agree.

**Expectation.** A claim is a row too — a measurement, a comparison, a value. A test
that could write an arbitrary predicate could write one that passes for the wrong
reason.

### The viewer is a wrapper, and now genuinely is one

It reads a test, asks the engine for the ground the test named, hangs the cast the test
named, performs the arrangement, runs the stages, and either draws it or reports it. It
contains no knowledge of any particular mechanic, which is what stops it accumulating
special cases — and it now contains no knowledge of any particular *behavior* either.

### The census, and why it is a tool rather than a list

A hand-kept list of which mechanics have tests is a list that is wrong within a week.
So the coverage is **derived**: the mechanics come from the roadmap, which is already
the authoritative list of them and is already checked against the issue files; the
tests come from every directory tests live in, each declaring what it covers.

Read textually rather than by loading, so that a test which is an executable and a test
which is a table can both be counted, and so that a broken test still appears as a
covered mechanic rather than vanishing from the census by crashing it.

**And it fails the build.** A mechanic in a phase that has code, with no test naming it,
is a failure of the written half exactly as a dangling issue reference is. That is what
turns "every mechanic should have one" from an intention into a fact — the same way the
roadmap check turned "every issue should be listed" into one.

### The demos run them one after another

A phase demo is the tests for that phase, played in order, each announcing what it is
about to show. The demos stop being a separate thing somebody has to write and become a
way of reading the tests that already exist — which is also why there are no demos
today after nine phases: a demo that has to be authored from nothing is a demo that
never gets authored.

## Suggested implementation steps

1. Move the march loop out of the arena and into the walking module, and give the
   tick's ordered array a named row for it. The arena stops having a tick.
2. Give the tick module a way to select stages by name, and name the two or three
   selections that tests actually make.
3. Give the arena an arrangement vocabulary shaped like the gate's, so both grounds are
   arranged the same way.
4. Write the measurement catalogue, and move the headless report's arithmetic into it
   out of the shell script.
5. Write the bench: read a test, refuse anything it says that the engine does not know,
   assemble, arrange, run, measure, report.
6. Convert the two scenes and the two scenarios to the one shape, with `covers`.
7. One front door over all of them: list, pick, run, watched or reported.
8. Build the census, in Lua, reading every directory that holds tests.
9. Wire the census into the documentation validator, failing on any mechanic in a built
   phase with no test.
10. Then work the census down. It is a long list and the point is that it is a list.

## Open questions

**T1. Do the two big suites become arrangements too, or stay as programs?**
The invariants and the formation sandbox are seventy-five thousand and thirty-five
thousand characters of assertions apiece, and they are the bulk of the coverage. Under
the rule above they are all defining behavior of their own. Converting them is a much
larger job than everything else here put together, and it may be that a suite of
hundreds of assertions is a different kind of thing from a scene and should keep its
own shape. Unanswered.

**T2. Should a scene carry claims at all?**
[The proving ground document](../docs/024-the-proving-ground.md) says the arena shows and
the suites assert, and that the whole value of a scene is in the case where nobody yet
knows what the right behaviour is — where writing an assertion first means guessing the
answer before seeing the question.

The reconciliation built is that claims are **optional**, and a test with none is reported
as *watched* rather than as *passed*. That is now written into the document too. What is
still not settled is whether a scene that has grown a full set of claims should stay a
scene or move into a suite — and if it stays, what the suites are still for.

**T3. What runs a match test that is not the whole match?**
An arena test names a few stages and gets a small world. A match test today runs
everything. Whether a match test should also be allowed to name stages — a whole map
and a whole cast, but only the movement systems running — is not answered, and it is
the difference between two instruments and a dial between them.

**T4. A claim can be about a value, and cannot be about a duration or an order.**
`always` folds the lowest and highest each reading reached; `finally` asks the world where
it stopped. Between them they cannot say "they were touching for at least fifty ticks", or
"the front rank stopped before the rear rank did", or "it never recovered once it fell".
Every one of those is a sentence somebody has already wanted to write about the crossing
scene. What the shape of such a claim should be — a reading over a window of ticks, a
sequence of claims, something else — is not decided.

**T5. The `wave` verb silently does nothing, and has for as long as it has existed.**
Setting a clock pushes the spawner's own clock forward so it does not dump every wave it
thinks it owes; asking that spawner for a wave then finds none due, and it places nothing
and says nothing. Both match tests carry a comment about it and both now fail a claim on
account of it. The fix is either to make the verb place bodies directly rather than ask
the spawner, or to make it refuse out loud — and which of those is right depends on
whether a posed wave should be a real wave with a real wave record behind it.

**T6. Two allied columns pass through each other. Is that the answer to H18, or a
regression?**
[The work queue](work-queue.md) records H16 as answered — a body may not stand where a
body already is, and head-on the rule stops a formation rather than moving it aside — and
records the consequence as H18: one stationary ally halts a formation. The crossing scene
now shows the opposite. The columns meet, squeeze past, and arrive at opposite ends.
Somebody's uncommitted work changed it, and the change is not written down anywhere.

Under either reading, two things in that run are defects rather than decisions: bodies
stand **inside** each other by up to seventeen thousandths of a pace, and bodies step
**off the road** — sixty-seven and a half paces from the centre line of a road whose
half-width is sixty-six.

## Related documents and tools

- [The proving ground](111-the-proving-ground.md) — the arena this generalises
- [The invariants](../tests/051-the-invariants.info.md)
- [The formation sandbox](../tests/060-the-formation-sandbox.info.md)
