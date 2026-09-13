# Roadmap

Ten phases. They are clusters of functionality, not a schedule. A phase's
number says how much of the rest stands on top of it, so the last issue finished
may well belong to phase one.

Four decisions shape all of it, recorded here because every phase below assumes
them:

- **Open sources only.** Nothing in this project requires an account, a
  registered client, or a secret. Anything that would is out of scope.
- **Both simulators get built**, wired together, and their disagreement is the
  output rather than a discrepancy to be explained away.
- **The destination is a game, not a report.** A floating invisible player
  directing many bot characters, whose combat is resolved by prediction rather
  than simulation because simulating all of it costs too much. See the purpose
  document. This is why the cheap model exists and why its error has to be
  measured rather than estimated.
- **Everything from 2011 onward, all game lines.** Retail, the test realms, and
  every Classic line, back to the earliest patch any open source still describes.

---

## Phase 1 - The patch spine

Nothing in this project is allowed to float free of a version, so the version
table is built before anything that would be stamped with one.

The game's own build history is published as one document: for each product
line, every version string ever shipped with the date it went up. A version
string is four numbers, `12.1.5.69594`. The first three are what a player calls
the patch. The fourth is the build number, and it is the only part that is both
unique and reliably ordered - patches get re-released, re-numbered, and shipped
out of sequence across regions, but build numbers only ever go up.

What this phase produces:

- A harvested, archived copy of that build history.
- A **build record**: one entry per shipped build, carrying its product line,
  its four version numbers, its release date, and the identifiers the publisher
  uses to address that build's data.
- An **expansion table**: the mapping from a patch's leading number to the name
  a person would use. This is the only hand-written table in the project, and it
  is small, stable, and hand-written because no open source states it.
- An ordering function over builds, and the ability to ask "which build was live
  on this date, on this product line".
- The rule for what happens to an artefact whose patch is not known. Decided in
  advance rather than discovered later: it is stored with the patch recorded as
  unknown and it is shown as unknown, never placed on the timeline at a guessed
  position.

Everything downstream keys off the build record.

## Phase 2 - The harvester

The thing that goes out and comes back, and the archive it fills.

- A **fetch layer**. There is no TLS library for the Lua runtime on this
  machine, so requests are made by driving the system's own transfer tool as a
  child process. That is not a workaround to be apologised for - it means
  timeouts, certificate failures, redirects and rate-limit responses are
  reported by a program built to report them, instead of being half-implemented
  here.
- A **source registry**. One entry per place worth asking, each stating how to
  address it, what shape it answers in, how fast it may politely be asked, and
  which extractor understands its answers.
- A **turn-taking scheduler**. The request to alternate between sources rather
  than drain one. How turns are apportioned is an open question - equal turns
  and proportional-to-richness produce very different archives.
- The **append-only raw archive**. Every response is kept exactly as received,
  forever, beside a provenance record stating what was asked, of whom, when, and
  what came back. Nothing downstream ever edits an archived byte; interpretation
  happens on copies. This mirrors the standing principle that memory is written
  once and never rewritten, and it is also just good practice: when an extractor
  turns out to have been wrong, the fix is to re-extract, not to re-fetch.
- A **reachability probe** that re-establishes which sources still answer and in
  what shape, so that the survey document never has to be trusted on the point.

Source adapters in this phase, all open, none requiring an account:

| Source | What it yields |
|---|---|
| The build index | the patch spine of phase 1 |
| The client's own database tables | spells, items, statistics, per build |
| The open-source simulator's repository | fifteen years of spell behaviour and priority lists, versioned |
| The competitive-season service | independent dating of what content was current |
| Shared spreadsheets | the literal theorycrafting artefacts |

## Phase 3 - Extraction

Raw archived bytes become typed records stamped with a build number. One
extractor per shape, each of which may only read the archive and may never write
to it.

The hard one is the open-source simulator's repository, and it is also the
richest. Two hundred and one frozen tags run from 2011 to 2020; after that the
history is organised as one long-lived branch per expansion. Inside are the
per-specialisation source files stating what every ability does, and the written
priority lists stating what a player should press next. Extracting those gives,
for any patch, both the ruleset and the intended path through it - which is
exactly what phases 5 and 6 need as input.

Also in this phase: deciding what a **fact** is in this project. The record that
says "this ability, in this build, had this coefficient, according to this
source" is the atom everything else is made of, and its shape is fixed here.

## Phase 4 - The viewer

Generation and viewing are kept apart, so this phase reads what phase 3 wrote
and may not reach the network.

- A **timeline scrubber**: a control that drags the entire page through fifteen
  years of builds. Dragging it does not reload anything; it re-selects which
  build's facts are on screen.
- **Meta views**: patches grouped into expansions, because that is how a person
  remembers them. The open-source simulator's own branch layout is already this
  grouping, so it is read rather than invented.
- Pages under the documentation's HTML directory, in the project's shared style,
  every page reachable from every other, with the undated pile from phase 1
  visible rather than hidden.

## Phase 5 - The arithmetic model

The uptime-average simulator. No clock. Given a character, a set of abilities,
and a fraction for each buff, it produces a damage rate by multiplying averages
together.

It is deliberately built before the event simulator, because it is small enough
to be obviously correct, and because the whole point of phase 7 is to catch it
being wrong in a specific and measurable way. Its blindness is a feature under
test, not a defect to be patched.

## Phase 6 - The event simulator

The machine with a clock. A queue of things that will happen, a game state that
changes when they do, and an interpreter for the priority lists extracted in
phase 3 that decides what the character presses next.

It produces two things: the timeline of a fight, and - by watching its own auras
switch on and off - the measured uptime of every buff. That second output is
what makes the whole project self-contained, because with the outside archive of
real fights declined, this is the only instrument in the project that measures
uptime at all.

## Phase 7 - The correlation measurement

The wiring, and the reason for the other six.

Run the event simulator on a real priority list. Take the uptimes it measured.
Feed exactly those uptimes to the arithmetic model. Subtract. Both halves ran on
the same rules, the same gear, the same character, so nothing differs between
them except that one respected the order of actions and one averaged it away.

The remainder is the payout the ruleset offers for sequencing well. Computed for
every specialisation across every patch the archive reaches, it is a chart of
design intent drawn from evidence, and it is the thing this project exists to
produce.

---

## Phase 8 - Emission to the server

The archive becomes executable. Extracted facts are turned into patch scripts in
the form the server project already applies: an apply function and an unapply
function in a matched pair, idempotent so that running twice changes nothing,
and reverting cleanly so the tree it touched round-trips back to untouched.

That project's patch system has three application times, and emission targets
them differently:

| Tier | Fires | What we would emit into it |
|---|---|---|
| pre-compile | before the build, on upstream source | changes to combat behaviour that live in code rather than data |
| post-install | after install, before validation | the bulk of it - statements that write our numbers into the world database |
| post-promote | after promotion, on live configuration | tuning knobs that are configuration rather than data |

Before anything is applied, it is **viewed**. Emission produces the change set
and a readable description of it - what value this becomes, what it was, which
build it came from, which source claimed it - and applying is a second,
deliberate act. A generated patch nobody read is a patch nobody can defend.

The boundary rule from the purpose document holds here: numbers transplant,
content does not. Emission refuses to emit an entity that did not exist in the
target's era, rather than emitting something the client cannot render.

## Phase 9 - Combat substitution

The arithmetic model leaves the laboratory and becomes the thing that resolves
fights at game speed.

- A **resolution interval**: how long a chunk of fight the model answers for in
  one go. Short enough that the world feels responsive, long enough that the
  saving is real.
- The **squad form** of the model: many characters against many targets, as
  sums of rates against health pools, rather than one character against a
  dummy.
- The **fidelity gate**: the per-specialisation gap from phase 7, consulted to
  decide which characters may be resolved cheaply and which may not.
- The **presentation contract**: resolution states what happened over an
  interval; presentation invents visible actions that add up to it and is
  forbidden from feeding anything back.

## Phase 10 - The commander

The floating invisible player who directs rather than fights. This phase is
mostly not in this repository - it is the other project's business - and it
appears here so that the earlier phases can be checked against what they are
ultimately for.

What this project owes it: a combat resolver cheap enough to run for many bots
at once, with a known and measured error, and a balance library to draw numbers
from when the custom game needs a value that retail never had to supply.

---

## Phase demos

Each phase ends with a demonstration program that runs from a single shell
script, kept in the completed-issues demos directory, and a chooser in the
project root that asks which phase to show. They are part of the deliverable,
not a development artefact: each one shows real harvested numbers and real
produced outputs, re-uses the tools of every earlier phase in a way that phase
could not have managed alone, and shows what the newest phase added. Where a
phase produces something that can be looked at, the demo opens it rather than
describing it.
