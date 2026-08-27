# The roadmap

Eleven phases. They are not a schedule and they are not progress tracking. Each one
is a cluster of functionality that hangs together, and they are ordered so that
every phase can be built on top of things that already work.

It is entirely normal for the last issue completed in this project to belong to
phase one.

Every phase ends with a **demo** in `issues/completed/demos/`, run from the
project root with `./run-phase-demo`. The demos are not development scrap. They
are part of what this project delivers, they are kept working, and each one
recombines the tools of earlier phases into something none of them could do
alone.

---

## Phase 1 — The world holds still

*What it turned out to teach:* [phase 1 progress](../issues/phase-1-progress.md)

The data model, and nothing that moves. Fixed-point arithmetic. The flat arrays.
The thing record, the wall record, the region record. The string pool. The
validator that runs once and refuses to substitute a default. Snapshot out,
snapshot in.

No network, no sight, no rules, no clock.

**Ends with:** a demo that loads a world, reports statistics about it -- how many
things, how many segments, how deep the region nesting goes -- writes it out,
reads it back, and shows the two are byte-identical.

**Proves:** that a world can be described, held, checked, and round-tripped.

## Phase 2 — The world can be seen

*What it turned out to teach:* [phase 2 progress](../issues/phase-2-progress.md)

The angular sweep. Visibility polygons from an eye with a facing and an arc. The
fog bitmaps. The thread pool that the sweep runs on.

Still no network and no tick -- sight is computed on demand, from a world that is
not moving.

**Ends with:** a demo that draws, in the terminal, what one body can see in a
generated dungeon; walks it down a corridor a step at a time; and shows the fog
accumulating behind it while the sight ahead changes.

**Proves:** the geometry works, and that it is fast enough to run per viewer per
tick. The demo reports its own timings rather than this document guessing at them.

## Phase 3 — The world ticks, and turns can be taken back

*What it turned out to teach:* [phase 3 progress](../issues/phase-3-progress.md)

The dispatch table of passes. Motion, and collision against walls.
Buffer-then-resolve. Named random streams. The command log, and replay from a
snapshot plus a log.

Then the turn, which is a transaction: a stretch of beats over which actions land,
a simultaneous resolution when it closes, a snapshot at its head, and an undo.
Both re-declaring and retconning -- restoring the head and carrying on from it,
and restoring the head and replaying a corrected log forward.

Still single-process, driven by a scripted command file rather than by people.

**Ends with:** a demo that runs a scripted session twice on different thread counts
and compares the world hash at every tick, then takes a turn back, runs it
differently, and shows the world following the correction.

**Proves:** determinism, which every later claim about replays depends on -- and
then spends it, because rollback is determinism being cashed in for something a
table actually wants.

## Phase 4 — People connect

*What it turned out to teach:* [phase 4 progress](../issues/phase-4-progress.md)

The door and the private ports. The session sockets. The wire protocol. The
outbound filter -- the one function that may write a thing to a socket. The intake
gauntlet. Leak tests.

No browser yet; the participants in this phase are test programs.

**Ends with:** a demo where several fake participants connect at once, one of
them deliberately asks for something it must not have, the refusal is shown in
words, and the leak test sweeps every outbound stream for records that should not
be in it.

**Proves:** the security model, which is the claim this project would be most
embarrassed to have wrong.

## Phase 5 — The bridge and the browser

*What it turned out to teach:* [phase 5 progress](../issues/phase-5-progress.md)

The client program: one socket out, one HTTP server in, on `localhost`. The first
real renderer. Interpolation between ticks, prediction for your own body, light
and shadow drawn from the visibility polygons.

Appearance in this phase comes from a table compiled into the renderer. Phase 7
replaces that table with the ruleset's answers, and the interface is built now so
that replacement is a substitution rather than a rewrite.

**Ends with:** a demo you can actually play. Walk a character around a generated
dungeon in a browser, with real fog, at a real frame rate.

**Proves:** the whole spine, end to end, for the first time.

## Phase 6 — Control is a dial

*What it turned out to teach:* [phase 6 progress](../issues/phase-6-progress.md)

Scopes in full. List membership and region membership. Driven and ordered styles.
Several scopes held by one connection. Multiple GMs. The commander who owns the
tavern and moves the crockery. Handing a scope over mid-session.

**Ends with:** a demo with one server and four connections sitting at four
different points on the dial -- one body driven with keys, a party of four given
orders, the tavern, and a GM -- all in the same room at the same time.

**Proves:** that the dial is one mechanism and not four special cases.

## Phase 7 — The rules layer

*What it turned out to teach:* [phase 7 progress](../issues/phase-7-progress.md)

LuaJIT embedded in the server. The hooks. Sheet storage owned by the ruleset.
`may_know`. Dice from named streams. A sample ruleset, and then a second one that
is deliberately unlike the first.

**Ends with:** a demo that runs the same world under two different rulesets and
shows them disagreeing about what is legal, what a thing is, and who may know
what -- with the server unchanged between them.

**Proves:** system-agnosticism, which is otherwise only an intention.

## Phase 8 — Content generation

*What it turned out to teach:* [phase 8 progress](../issues/phase-8-progress.md)

The description language. Validate, lay out, realise, furnish, write -- five
stages, five programs. Generator tests that check the output against the
description that asked for it.

**Ends with:** a demo that takes a written description and a seed, produces a
dungeon, regenerates it from the same seed and shows it is identical, changes one
line of the description and shows what changed, and then drops a participant into
it.

**Proves:** that nothing needs to be hand-placed.

## Phase 9 — The sprite studio

*What it turned out to teach:* [phase 9 progress](../issues/phase-9-progress.md)

A description-in, sprite-out generator whose artifact is one self-contained
animated SVG. The wall that refuses a bad description by name. The pool that keeps
every sprite ever made, with its category, its tier, and who set that tier. The
per-category quality floor, which reports what raising it costs in variety before
it is raised.

Both rating algorithms, because both are wanted and they are different machines:
**rate on arrival** — the machine tiers everything as it is generated, a person
tiers a little whenever they like, and the person's rating wins and is marked as
theirs. And **judge then curate** — a person tiers the whole library once, and
from then on re-tiers individual sprites during live play, at the moment they look
at one and think it is wrong.

Neither counts as built until both are tested and shown working.

**Ends with:** a demo that generates a batch of sprites, shows the pool with its
tiers and their provenance, raises one category's floor and reports the variety it
just cost, and then runs a live session in which a sprite is re-tiered from the
table without stopping play.

**Proves:** that the appearance layer is a studio rather than a folder, and that
judging a thing in a session is a different act from judging a picture in a
gallery.

**Built.** Nine issues rather than eight -- the ninth, that a thing in the world
has to say which picture it is wearing, was foundational and was found last, while
wiring the re-tier command. The demo also writes a page gathering the whole
library, every sprite moving, sorted by tier.

**What it left for later:** the browser still draws coloured circles. The pictures
exist, animate, and are openable on disk, and nothing yet sends one down the wire
to a table. The paintbrush being a closed set of numeric moves makes that
tractable -- a sprite can be sent as its layers rather than as text or as a second
generator ported into JavaScript -- and it belongs with the second view. See open
question 15.5.

## Phase 10 — The engraving

*What it turned out to teach:* [phase 10 progress](../issues/phase-10-progress.md)

The record log: a text file drawn as an ornate metal carving whose lines are the
cell walls of the table it contains. A reader that turns a carving into variables,
a writer that turns variables into a carving, a third script that hands one to a
friend, and the action bar that shows its cells during play.

Intentionally fragile, which is a design decision with an argument behind it: the
art is a checksum you can see. A value of the wrong width bends the creature's
wing, and a person notices from across the room without running anything.

**Ends with:** a demo that finishes a session, engraves its statistics as a
creature nobody chose in advance, reads that engraving back into variables and
shows they match, re-engraves from those variables and compares byte for byte,
and then deliberately mangles one cell so the carving visibly deforms.

**Proves:** that a file can be a picture and a database at once without being
worse at either.

**Built.** Four creatures, generated from tiling rules rather than drawn, with
their ornament anchored to chamber walls so that a hand-edit visibly bends the
animal. The writer and the reader share no code and describe the alphabet in two
different ways on purpose. The bridge hangs the last session's carving in the
action bar, and the server carves itself as the last thing it does.

## Phase 11 — The second view, and the documentation

*What it turned out to teach:* [phase 11 progress](../issues/phase-11-progress.md)

A terminal renderer speaking the same protocol as the browser, with no server
changes. The documentation rendered to linked HTML in `docs/HTML/`, with the
companion files reachable from everything that mentions them.

**Ends with:** a demo showing one session watched simultaneously from a browser
and a terminal, and the documentation site built from the Markdown by a tool.

**Proves:** the generate-then-view split at the last boundary -- and it is the
capstone precisely because it can only be attempted once everything else is real.

**Built.** A terminal view speaking the same protocol, which found a defect that
had been in the server since phase four: the hello had never once arrived, and
the browser had degraded silently and correctly for six phases. A documentation
site of 287 pages built from the Markdown by a tool, whose first report found a
hundred and sixty-five dead links -- nearly all of them created by the act of
finishing an issue and moving it into `completed/`.

And the sprites reach the table, as numbers on the wire, because the paintbrush
was closed.
## Phase 12 — The table, as it is actually played

Four decisions made after the first eleven phases were built, each of which turned
out to be a design the documents did not have.

**Commanding is not affecting.** A forest commander owns their goblin patrol and
moves it. When it walks into somebody else's tavern, the tavern's owner cannot
move it — and can absolutely poison its drink, spring a trapdoor under it, refuse
it mead, or kill it. *But they had better explain how.* Owning a piece is the
right to move it on the board. It is not a fence around what anybody else may do
to it.

**Nothing checks who you are, and that is the answer.** The door admits whoever
knocks. The remedy for somebody behaving badly is the remedy a real table has: the
host removes them, and takes back what they did. Both of those have to exist for
the answer to be honest, and neither did.

**The controls are a state machine you can see.** Three dials — which units, which
direction, how far — and a handful of verbs applied to whatever they are pointing
at. The state is drawn back to you as a small diagram, because a modal control
scheme whose mode is invisible is a control scheme nobody can hold in their head.

**Ends with:** a demo in which one person moves a squad of four with key
combinations while another person poisons one of them; a host removing somebody
and unwinding what they did; and the dial's own diagram changing as the keys are
pressed.

**Proves:** that the permission model separates *who moves this* from *who may act
on this*, and that a party of four is playable with one keyboard.

---

## What is deliberately not in any phase

**Audio, video, and voice chat.** Real, and out of scope. People have those
already.

**Accounts, lobbies, matchmaking, persistence across sessions.** This is a program
a host runs for a table they already have.

**Combat, character advancement, inventory, initiative.** These belong to a
ruleset, and the sample rulesets in phase 7 will implement enough of them to prove
the interface. The server will never grow an opinion about any of them.
