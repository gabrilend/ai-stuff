# 111a — Every Mechanic Has a Test

| | |
| --- | --- |
| Phase | 1 — The World and the Tick |
| Blocked by | 111 |
| Blocks | — |
| Reads | [the proving ground](../docs/024-the-proving-ground.md), [the shape of the code](../docs/018-the-shape-of-the-code.md) |
| Open questions | T1, T2, T3, T4, T6, T7, T7b |

## Current behavior

**Two kinds of test, one front door, and fifty-nine of eighty mechanics named by one.**
The shape is built and the census is being worked down. Twenty-five tests exist. Seventeen are read by a
bench and eight by a person; two of the seventeen fail a claim, and both failures are
findings rather than flakes.

What exists:

- **A test is a table that names things and contains no behavior.** The loader refuses a
  function in any field, and refuses any field it does not know by name.
- **Two grounds** — a short straight road with only the machinery named, and the real map
  with the whole cast — differing by one field, arranged by two verb tables that are the
  same shape.
- **The arena has no tick of its own.** The march loop lives in the walking module, the
  tick's stage table carries a named row for it that the game never runs, and a test names
  a selection of stages.
- **One measurement catalogue**, now forty-three readings deep: bodies and where they are,
  what they are carrying and which row of the brain they are running, the waves, the
  stone, the two economies and the phase. The window's readout, a terminal report and an
  assertion all ask the same named reading of the same world.
- **Claims hold over a whole run**, not merely at its last tick, and there are now claims
  for the other end of a run — `ever_at_least` and `ever_at_most`, judged at the highest
  and lowest a reading reached. Half of what a test wants to say is that something
  *happened*, which is true at one tick and false at the others.
- **The census reads all three directories** and is wired into the documentation
  validator, which fails on any mechanic in a built phase with no test.
- **The census and the validator are Lua**, not shell wrapping python.

### What writing the tests found

One was a live fault and is fixed; one is a trap that is staying and is now
written down beside the code; three are findings about the game that nobody had before,
because nothing had counted them.

- **The gate armed no towers.** A team's slot counts are one cache over its stones and a
  tower keeps a second — its own copy of what its lane's stone holds, so that swinging
  never reaches into a team record. The `stone` verb rebuilt only the first, so every
  scenario ever written that slotted an upgrade into stone posed a world where the slot
  said one, the interface said one, and every tower shot with nothing. Fixed: the verb
  now re-stamps every lane, which is what the real placement path does.
- **Setting the clock to nought is not the same as not setting it.** The `tick` verb
  always writes the ordinary stretch's length into the phase deadline, and a match's
  *first* stretch is longer than the ones between challenges. Two runs of the same test,
  one with the row and one without, play different matches and neither looks wrong. Left
  as it is — it means "the clock is here now" — and written down beside the verb.
- **No guard ever leashes, because the guards were standing inside the tower.** A tower
  had no size anywhere in the simulation — the only place one existed was a number inside
  a drawing routine — so a guard placed a few paces from a tower's centre was inside a
  building nobody had told the simulation was there, and the rope was never pulled tight.
  A structure now carries a radius, guards stand on a ring outside it, and nothing walks
  into masonry. See T7.
- **Claims pinned to the last tick of a match are claims about luck.** Three of the new
  tests asked for somebody to be fighting, or something to have been placed, at the
  instant the run stopped. All three passed, and all three failed the moment an unrelated
  change moved the match along a slightly different line. A thing that *happens* is asked
  about the highest a reading ever reached; a thing that *holds* is asked about the
  lowest; and a reading about how the bots happen to be playing is watched rather than
  claimed at all.
- **The surge does not empty a chest, it copies one.** The count of upgrades held does not
  move for the whole surge while the count of bodies carrying something climbs into the
  hundreds. That is consistent with the design sentence — nothing is lost — but the
  sentence reads as though the chest is spent, and it is not.
- **Removing the separation pass from a crossing changes nothing.** Two allied columns run
  through a shortened tick with no separation pass overlap exactly as much as they do with
  one: never. They also never come within the rank spacing of each other. See T6.

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

**T5. The `wave` verb silently did nothing, and now raises a wave directly. Answered.**
Setting a clock pushes the spawner's own clock forward so it does not dump every wave it
thinks it owes; asking that spawner for a wave then found none due, so the verb placed
nothing and said nothing about it. The choice was between placing bodies directly and
refusing out loud, and it turned on whether a posed wave should be a real wave with a real
wave record behind it.

It should, so the wave-raising routine is exported from the waves module and the verb
calls it. A posed wave now has a commander, a mixture, a captain, ranks and a bounty per
body, and it is the only wave raised -- the old route produced six as a side effect, one
per team per lane, of which five were not asked for.

Both match tests that carried a comment about this now pose what they wanted. The dragon
scenario has bodies in it for the first time.

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

**T7. No guard ever enters the leashing state — and the reason turned out to be where
they were standing.**
Measured over five thousand ticks of a real match: nought, every tick. The tower pass
measures every guard against its leash node each tick and flips the state when it is
outside the radius, and that code is reached — the guards were simply always inside it.

Asked about it, the answer was that **the guards were standing inside the tower**, and
that they should be walking around outside it. Which was exactly right and was not
something a reading of the leash could have said: a tower had no size anywhere in the
simulation, so a guard placed a few paces from a tower's centre was inside a building
nobody had told the simulation was there.

That is fixed — a structure carries a radius, guards stand on a ring outside it, a base
tower's guards stand around the library they are leashed to, and nothing walks into
masonry any more. **The leash is still never pulled tight**, and now it is a question
about the rope rather than about the ground: the radius is a hundred and twenty-eight
paces and a guard's whole patrol fits inside it. Whether to tighten it until the rule
bites, let guards chase further, or leave it as a guarantee that costs nothing is still
open, and a claim asserting the count is always nought is watching it either way.

**T7b. One guard gets wedged in stone about four minutes into a match, and stays.**
With seven towers down, the count of guards standing inside a building goes from nought
to one and does not come back. It is not a blip — the same body is in the same stone for
the rest of the match — which means something walks it back in as fast as the separation
pass takes it out. The most likely shape is a guard whose patrol node *is* a building's
node, walking at the centre of it every tick, but that has not been confirmed. The whole
match reproduces it, which makes it a bug report anybody can run.

**T8. A third of the census was things a test of this kind cannot cover. Answered: ask a
person.**
The roadmap is the list of mechanics and the census counts every row of it in a phase that
has code. Several of those rows are not mechanics a world can be measured for: the
headless runner and the terminal viewer are tools, the proving ground is the ground the
tests stand on, this issue is the census itself, and the whole drawing phase is a window
somebody has to look at. Eighteen rows that were never coming off the list, in a check that
fails the build — and a check that always fails is a check people learn to read past.

The answer given was the one nobody had written down as an option: **just ask me to test
them.**

So there is a third ground, `person`, and a fourth directory of tests. A hand test names a
command and **one question per mechanic it covers**, raises no world, runs no stages and
makes no claims. Running one prints what to look for, **runs the command**, waits for it
to finish, and only then asks — a question asked before the thing has been seen is a
question answered from memory of the last time.

**Four answers and a replay**, and two of the four are the ones that earn their place.

*Could not reproduce* means the run never got into the state the question is about, which
is not a person failing to look properly — it means whatever was supposed to produce that
state does not, and that is a fault in the simulation sitting exactly where a test failure
would be if a bench could reach it.

*Yes, but* is a yes with something attached. Most of what a person notices while looking
at a working thing is not a fault: it works and the colour is wrong, it works and it took
a moment to find. With nowhere to put that it goes in as a no, which sends somebody to fix
a thing that is not broken — or it goes nowhere, which is worse, because the person had to
decide to throw it away and will decide faster next time. It does not join the list of
things to pick up; it is printed after it, under its own heading, because it is not a
queue.

Everything except a plain yes asks for a note, worded for which kind it was. A plain yes
asks nothing, because a prompt on every answer is a prompt people learn to hit return
through.

Every question names the mechanic it is evidence for, and the loader refuses a question
about a mechanic the test does not claim, or a claimed mechanic nothing asks about. That
is what makes an answer usable months later: it lands beside an issue number rather than
as "it looked a bit odd" against a file covering three things.

Answers append to a record in the repository — what somebody saw on a particular day is
the only evidence there will ever be that a window was looked at — and running everything
reads it back and prints whatever was not a yes, before listing the tests nobody has
looked at. So the next person to open the project starts from what the last one saw. `all`
does not run them, since a build cannot look at anything.

They are still tables of nouns. What a person is asked is written in advance, for the same
reason a claim is a row rather than a predicate: a question invented while looking at the
screen is a question that agrees with whatever is on it. A hand test carrying a field that
needs a world is refused by name at load, because a half-automated test looks like it
measures something and does not.

Eight of them exist and the census counts them like anything else, which is what makes the
number honest — the question was never "has this been automated", it was "is anybody
checking this at all".

**What is left is a real list.** Twenty-one rows, and five of them belong to mechanics
nobody has started building. The rest — the commander catalogue, abilities, the three ways
a hero can be spawned, rerolling, staking, the zones a lane is cut into — are ordinary
gaps that an ordinary test would close.

## Related documents and tools

- [The proving ground](111-the-proving-ground.md) — the arena this generalises
- [The invariants](../tests/051-the-invariants.info.md)
- [The formation sandbox](../tests/060-the-formation-sandbox.info.md)
