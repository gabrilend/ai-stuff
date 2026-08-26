# Open questions

Questions that surfaced while the rest of these documents were being written, and
which are mostly **not answered**. They are listed here so they can be worked
through one at a time rather than being quietly decided by whoever writes the code
first.

A phase with an unanswered blocking question against it is not ready to start.
Where a document states an answer to one of these, it states it as a proposal and
says so.

A question that gets settled is marked ANSWERED and **stays here**, with the
reasoning that settled it. It is not deleted. A list that only holds live
questions loses the record of why the dead ones died, and that record is what
stops the same question being reopened in six months by somebody who was not in
the room.

Each question carries the phase it blocks, so the order to work through them is
roughly the order of [the roadmap](015-roadmap.md).

---

## Blocking phase 1 — the world holds still

### 1.1 What is one world unit? — ANSWERED

**The simulation counts metres. The picture speaks feet, rounded to the nearest
foot.**

A position is an `int32_t` in units of 1/1024 of a metre: range about ±2,100
kilometres, precision about a millimetre. Nothing in the server has ever heard of
a foot. The renderer converts on its way to the screen, and a person at the table
reads whole feet.

The rounding lives in the view and only in the view. See
[a thing in the world](005-a-thing-in-the-world.md) for the consequence that
matters: **commands carry metres**, never rounded feet, because two clients that
round differently would otherwise disagree about where a body went.

### 1.2 Does anything persist between sessions? — ANSWERED

**Both. Statistics as an engraving, and the world itself written back out.**

The engraving is a text file drawn as an ornate metal carving -- a fish, a bird, a
dragon, a mammoth -- whose lines are the cell walls of the table it contains.
Bespoke per run, read by one script and written by another, shown in the action
bar during play, and intentionally fragile. See
[the record log is an engraving](018-the-record-log-is-an-engraving.md).

**And the world persists.** A session ends by writing the world out; the next one
loads it. The tavern the players burned down is still burned next week.

That has a price, and it is recurring rather than one-off. The snapshot format in
[108](../issues/108-a-world-writes-itself-down.md) stops being a debugging
convenience and becomes a **long-lived format**: it needs a version number that is
checked and refused on mismatch, and it needs a migration path every single time a
record changes shape. Adding one field to the thing record in phase 6 means
writing a converter for every world file anybody already has.

The cost is accepted. What it buys is the only thing that makes a campaign a
campaign -- a place that remembers.

The consequence for phase 1: **108 cannot be finished as a debugging convenience
and then upgraded later.** The version story has to be in it from the start,
because the first world file that gets saved without one is the first world file
that cannot be migrated.

### 1.3 What goes in the engraving's cells?

Constrained in an unusual and useful way: **a creature has only so many places to
put a number.** The engraving cannot grow a column without being redrawn, so the
set of statistics is small, fixed, and chosen rather than accumulated.

The candidate list is whatever [the goodbye](../output/goodbye) writes at the end
of a run. Which of those earn a place on the carving is undecided.

### 1.4 What picks the creature?

Each record log gets its own. Is the animal chosen by the person, drawn from the
session's seed, or derived from the statistics themselves -- a long session
becoming a mammoth, a short violent one becoming a hawk?

The third is the most appealing and the most likely to produce something nobody
wanted. It is also the only one of the three where the shape of your campaign
picks its own animal.
---

## Blocking phase 2 — the world can be seen

### 2.1 How coarse is the fog memory grid?

[Sight and what it remembers](007-sight-and-what-it-remembers.md) proposes one
world metre per cell, which now that the scale is settled means a map a hundred
and twenty metres on a side costs under two kilobytes per viewer. That is cheap
enough that the argument for coarser has mostly evaporated.

What is left of the question is the other direction: whether a metre is too coarse
for a corridor you only glanced into. A metre cell that is set because one corner
of it fell inside your vision claims you remember a square metre of floor you
barely saw.

### 2.2 Does a viewer with many bodies see the union, or switch between them?

A commander with six goblins: is their screen everything all six can see at once,
or the view from whichever one is selected? The union is the honest answer for
sight-as-security and it is what the documents assume. But it may play badly --
six overlapping cones is a strange thing to look at.

---

## Blocking phase 3 — the world ticks

### 3.1 Is the world turn-shaped, and can a turn be undone? — ANSWERED

**Turns are simultaneous and can be rolled back.** Everyone declares inside a
window; when it closes everything resolves at once; and the whole turn can be
taken back and run again.

The server understands a turn as a **transaction** -- a window with a snapshot at
its head and an undo -- and understands nothing else about it. No initiative, no
rounds, no opinion on whether acting twice is legal. A ruleset wanting continuous
play sets the window to one tick and never rolls back.

Neither half needed new machinery. Simultaneous resolution is buffer-then-resolve,
already the rule for every pass. Rollback is a head snapshot plus a deterministic
replay, and both of those already existed for other reasons. See
[the turn is a transaction](019-the-turn-is-a-transaction.md).

### 3.2 What is the tick rate? — MOSTLY ANSWERED

**Not constrained by sight, which is what everyone expected to constrain it.**

Phase 2's demo measures the sweep rather than guessing at it: about 90
microseconds per body against seventeen walls. A table of six is roughly 550
microseconds of sight per tick, which at twenty ticks a second is about one per
cent of one core.

Sight was the expensive pass and the reason this question existed. It is not
expensive enough to matter at tabletop scale, so phase 3 may pick a heartbeat for
other reasons -- how tight the controls feel, how much interpolation the view has
to do, how much bandwidth a faster tick costs in phase 4.

Twenty per second remains the working assumption. What is now known is that
nothing in the simulation is pushing back on it.

The measurement scales with wall count, not with map size, so a much more
detailed dungeon is the case that would reopen this. The demo reports the current
figure, so the answer stays live rather than becoming a number in a document that
nobody re-measures.

### 3.2a How long is a turn's window, in ticks?

Underneath the tick rate and not answered by it. Fixed, or dependent on people
being finished? See [3.5](#35-what-closes-a-turns-window).

### 3.3 When a turn is rolled back, does the fog roll back with it? — ANSWERED

**Fog rolls back with the world.**

A rollback is a full state restore. Whatever the world was at the head of the
turn, every viewer's memory was too, and both go back together. Mechanically this
is the easy answer -- a fog record is a flat block of bits, so it restores the same
way everything else does, and nothing anywhere has to reason about a memory that
disagrees with its world.

**What it costs, stated plainly so nobody is surprised by it later:** the person
still remembers the corridor. They looked at it. The screen now knows less than
they do, and their own map will close over a room they can describe out loud.

That is accepted, and the reason it is the right trade is that the alternative is
worse in a way that never goes away. A fog that is not rolled back holds a place
reached in a turn that never happened, and it will contradict the world every time
anybody walks there again -- a permanent inconsistency, spreading, in exchange for
a moment of honesty about one person's memory.

The underlying fact stays true and stays worth writing down: **you cannot restore
ignorance.** A rollback at a tabletop has always been a social agreement, and the
program's job is to make the state consistent so the people can make the rest of
it work. It is not pretending to wipe a memory. It is putting the board back.

The implementation consequence, which is small only because it was anticipated:
[205](../issues/205-the-fog-is-a-bitmap.md) builds snapshot and restore for a fog
record from the start, and [309](../issues/309-taking-a-turn-back.md) includes fog
in the ring alongside the world blocks and the random stream positions. The
decision gets a comment at the point where fog is restored, because the other
answer will look like a bug to the next reader.

### 3.4 Who may roll back a turn?

A GM, presumably. But there are several GMs, and a retcon changes what somebody
else did without asking them -- see the re-declare versus retcon table in
[019](019-the-turn-is-a-transaction.md). Does it need agreement? Does the person
whose command is being rewritten get told?

### 3.5 What closes a turn's window?

Three candidates and they are not exclusive: everybody has sent `DECLARED`; a
timer expired; a GM said so. A timer is the one that keeps a session moving and
also the one that will cut somebody off mid-thought.

### 3.6 Does a rolled-back turn appear in the engraving?

The command log keeps it, because a record that omits the parts somebody regretted
is not a record. Whether it reaches the carving is separate -- and **the number of
rollbacks might be the best statistic on it.** A session with eleven of them was a
session about something.

---

## Blocking phase 4 — people connect

### 4.1 Why one port per participant? — ANSWERED

**Kept.** One listening port per participant, and the host forwards a range.

What it buys: the kernel resolves identity before any of our code runs, so there
is no session lookup in the receive path and no bug possible in one. And the
per-person outbound filter binds to the socket once, at bind time, rather than
being passed as a parameter on every outbound message -- which removes the single
most plausible way a secret could leak, a misthreaded "who is this for".

What it costs, unchanged and accepted: a host behind a home router forwards a
contiguous range rather than one port, which is a longer conversation with a
router's web interface. [Desire](../desire/what-would-be-better) records the wish
that this not be what stops somebody joining, and
[faith](../faith/boons-expected) records the expectation that it will be, on the
first evening a real table tries this.

Both of those stay written down. If the expectation turns out right, this is the
decision to revisit, and the argument above is what would have to be given up.

### 4.2 What is in the `secret` field of a join request?

A shared password for the table? One password per participant? A public key?
Something the host reads out over voice chat when the session starts? The field is
thirty-two bytes and its contents are entirely undecided.

### 4.3 How large can a table get?

Sets the port range, the thread pool size, and how hard the sight pass has to
work. Six is a normal tabletop. Thirty is a convention hall. The difference
changes whether `SEES_REGION` is an optimisation or a necessity.

### 4.4 What happens when somebody's connection drops?

Their port is released and their scopes are unheld -- so does their character stand
there? Get driven by a GM? Vanish? And when they reconnect, do they get their old
port back, and does their fog memory survive, or do they re-explore what they
already saw?

Fog memory surviving a reconnect is the difference between a dropped connection
being an annoyance and being a disaster.

---

## Blocking phase 5 — the bridge and the browser

### 5.1 How is a thing actually drawn? — ANSWERED

**Animated SVG**, one self-contained file per sprite, composed and driven by the
renderer. Decided in [the sprite studio](017-the-sprite-studio.md).

It is left in this list rather than deleted because it was open for a while and
the reasoning is worth keeping where somebody looking for it will find it: vector
survives being scaled, tinted, and recomposed where a raster sprite does not; SVG
is text, so the encoder is string-writing and nothing is borrowed to produce it;
and an animated SVG can be *watched* in a browser as it stands, which is what makes
it rateable by a person who is judging a walk cycle rather than a still frame.

What remains open is downstream of it, and is [11.1](#111-does-the-terminal-renderer-draw-sprites-at-all)
-- a terminal cannot draw one.

### 5.2 May the bridge keep a local copy of the fog memory?

It would cut the bandwidth considerably: the server would send only newly-revealed
terrain rather than everything remembered. But it puts a piece of per-viewer state
outside the server, and the whole security argument rests on the server being the
only place that decides what a viewer has. Probably safe, because the fog is that
viewer's own memory and reveals nothing new. "Probably safe" is exactly the phrase
that should stop a decision from being made quietly.

---

## Blocking phase 6 — control is a dial

### 6.1 When a goblin patrol walks out of the forest and into the tavern, whose is it?

The question from [the vision](../notes/vision). Region membership is evaluated
from the thing's current region, so mechanically the answer is "the tavern's, the
moment it crosses". Whether that is wanted is another matter: the forest's
commander may have been walking that patrol for ten minutes with an intention, and
having it taken away at a doorway is a strange experience.

Alternatives that have not been argued: the patrol keeps its origin scope until
somebody hands it over; a thing can be in a list scope *and* a region scope, with
the list winning; the boundary crossing is a request the receiving commander
accepts.

### 6.2 Is "usually weaker but not always" a rule or a convention?

Whether the program enforces anything about the strength of a commander's bodies,
or whether that is entirely the GM's business when handing out scopes. If it is a
rule, it is a *ruleset's* rule, since the server has no idea what strength is.

### 6.3 Can a scope be handed over mid-session, and what happens to orders in flight?

A GM handing the tavern to a player who just arrived. Standing orders belong to
the bodies, not to the scope, so mechanically they would continue -- which means
the new commander inherits six goblins already walking somewhere for reasons they
were not told.

### 6.4 Does a player with a party of four drive all four, or one at a time?

The vision says a player controls "up to an entire party at once, but generally
not more". Four bodies driven simultaneously with one keyboard is not really
possible; four bodies given orders is the strategy-game interface; one driven and
three following is a third thing that is common in games and is not in the
documents at all.

### 6.5 Does `HIDDEN` hide a thing from other GMs? — ANSWERED BY THE MECHANISM

**It falls out of gate ordering rather than needing a rule of its own.**

Gate 1 asks whether a thing is inside a scope you hold, and passing it passes
everything below -- including the hidden gate. So:

- A GM whose scope is the whole map sees hidden things, because they command
  them. **Your own ambush is not hidden from you.**
- Two GMs with whole-map scopes therefore both see everything, including each
  other's.
- A co-GM holding only a **region** sees hidden things inside it and not
  elsewhere -- so a GM who wants an ambush their colleague does not know about
  puts it outside the colleague's region.

`MAY_SEE_HIDDEN` is left meaningful for the case that remains: seeing somebody
else's hidden things without commanding them.

This was not designed. It was noticed when a phase 4 leak test started failing
in phase 6 -- a test whose own comment had said it would change deliberately when
scopes arrived. The mechanism produced a coherent answer and the answer was
adopted rather than overridden.

**What is still open:** whether two GMs should be able to keep secrets from each
other at all, which is a question about tables rather than about code. The
mechanism above says "only by carving up regions", and nobody has said whether
that is enough.

### 6.6 Can a GM see what the players have seen?

Not the world -- a GM sees that anyway -- but the *fog*. "Which rooms have they
explored" is a question a GM asks constantly, and the data is right there. It is
also, faintly, a surveillance question about the other people at the table.

---

## Blocking phase 7 — the rules layer

### 7.1 What happens when a ruleset raises an error mid-tick?

The whole argument for embedding Lua rather than compiling rules in is that
somebody's homebrew should not take down the table. So: the offending hook is
abandoned, the tick continues, and a sentence goes somewhere a person will read
it. But *which* person -- the GM, everyone, a log file? And what happens to the
half-applied changes the hook had already requested before it failed?

### 7.2 Are stale ghosts shown?

When a viewer sees a goblin and walks away, is a faded goblin drawn at the last
place they saw it? [Sight and what it remembers](007-sight-and-what-it-remembers.md)
proposes this is the ruleset's decision, because it is a statement about how the
game handles uncertainty. That may be over-thinking it.

---

## Blocking phase 8 — content generation

### 8.1 What does the description language look like?

The five-stage pipeline in [content is generated](013-content-is-generated.md)
says what the stages do and says nothing about the syntax of the thing feeding
them. It is the part of the project most likely to become a language, and the part
where deciding by accident would be worst.

---

## No phase — questions about the whole thing

### 9.1 Is sound modelled at all?

Light is blocked by walls and this is the entire foundation of the fog. Sound is
the same shape of problem -- it travels, it is blocked, it goes around corners
differently -- and hearing something you cannot see is one of the best things a
tabletop can do. It is not in any document and not in any phase.

### 9.2 Can two people drive one body?

A scope is held by exactly one viewer, so currently no. Whether that should hold
for the case of a player who has stepped away, or two people sharing a character.

---

## Blocking phase 9 — the sprite studio

### 10.1 Which rating algorithm does a given table actually run?

Both are built. [The sprite studio](017-the-sprite-studio.md) says the choice is a
setting and that switching costs nothing because both write the same field. What
it does not say is what the **default** is, and the default is what nearly
everyone will use.

Rate-on-arrival suits a large generated library and gives a free, continuous
measurement of how far the machine's taste has drifted from yours.
Judge-then-curate gives a library every item of which a person has looked at, and
bounds it at one person's patience. They fail in opposite directions.

### 10.2 Who may re-tier a sprite during play?

Algorithm B has somebody changing a sprite's tier mid-session. Only the GM? Anyone
who can see the thing? The table by some agreement?

There is no leak in letting a player re-tier a sprite they can already see -- the
tier is about the `kind`, and they are looking at one. But a shared library that
any of six people can re-tier, mid-session, without discussion, is a different
social object from one the GM curates.

### 10.3 Is the pool per-table or per-project?

If a table's sessions each curate the same pool, the library becomes that group's
over a campaign, which is the appealing version. If the pool ships with the
project, in-play re-tiering is one person editing a shared asset for everybody who
ever uses it, which is a different thing entirely and probably wants to be a
local overlay on top of a shipped pool rather than an edit to it.

### 10.4 What are the categories, exactly?

Quality is discussed per-category and never globally -- nobody says the sprites are
bad, they say *the goblins* are bad. [The sprite studio](017-the-sprite-studio.md)
proposes that the categories are the `kind` families a ruleset declares. That
makes them the ruleset's to name, which means two rulesets have two different sets
of categories, which means a pool is not straightforwardly portable between them.

### 10.5 Does a machine grader that watches motion actually exist here?

Algorithm A requires something that rates every sprite on arrival, and a rater
shown one still frame of a walk cycle is rating an illustration. Whether the thing
doing the rating can watch an animated SVG at all is a practical question that has
not been checked, and if it cannot, algorithm A does not work as described and
algorithm B is the only one that does.

### 10.6 Does the studio ever regenerate a sprite that is in use?

A sprite is referenced by things in a live world. If the studio produces a better
goblin, does the running session pick it up, at the next session, or never? Never
is the safest and is also how a library stops improving.

---

## Blocking phase 10 — the second view

### 11.1 Does the terminal renderer draw sprites at all?

Phase 10 proves the split by building a second renderer against the same protocol.
But the protocol now carries vector sprites, and a terminal cannot draw one. Either
the terminal view ignores appearance entirely and draws glyphs by `kind` -- which
is honest and slightly weakens the proof -- or the appearance layer has a
representation the terminal can use, which is a constraint on
[the sprite studio](017-the-sprite-studio.md) that nothing currently states.

---

## Blocking phase 4 — the command machine

These arrived with the bytecode decision and are downstream of it.

### 12.1 Does an out-of-range value round, or refuse? — ANSWERED

**Round within range; refuse outside it.**

A slot's bit width *is* its range, so an out-of-range value is not rejected -- it
is unsayable. Every one of the 65,536 patterns in a sixteen-bit angle slot is a
legal angle, because a full turn is 65,536. The format makes the invalid
unrepresentable, which beats checking for it, because a check can be forgotten and
a bit width cannot.

A value landing between two representable steps **rounds to the nearest**, and
that is not a fallback and is not reported. It is what a fixed-width field means,
the same way storing a position rounds it to the nearest thousandth of a metre.
Quantisation is the representation, not an error being swallowed.

**References are the exception and they are refused.** A 32-bit index is a
perfectly legal number that points past the end of the array. Clamping one would
silently aim a command at whichever body happened to be last, which is the class
of bug this entire design exists to prevent.

So the standing rule about fallbacks is intact: nothing here quietly substitutes a
default. The only thing that "rounds" is a value being written into the width it
was always going to be written into.

### 12.2 What exactly is "bitflag-sorted"? — ANSWERED

**A self-terminating chain of positional flag words, bounded by configuration.**

The first bit of every flag word is a continuation bit: 1 means another word
follows, 0 means this is the last. Every other bit is an independent flag at a
fixed position -- three bits are three separate questions, not one question with
eight answers. There is no length field, because the words say when they stop.

How many words the server will accept is read from its config, and that number is
a hard limit rather than a hint. It is what keeps a self-terminating format from
being a way to make the server read forever, and it is what lets the flag buffer
be one of the pre-sized containers the decoder writes into.

Written up in [commands](010-commands-enter-through-one-door.md).

What is still undecided is the **word width** -- four bits, a byte, something else
-- and therefore how many flags one word carries and how often the chain extends.
A byte gives seven flags per word, which is probably more than one command needs
and therefore probably right.

### 12.3 Where does the recorded value go, and how big does it get?

Every operand is written to the command log as it is decoded, before anything acts
on it -- including operands belonging to commands that are then refused. A busy
table generates a lot of this. Whether the log is capped, rotated, or simply
allowed to grow for the length of a session has not been decided, and a session is
hours long.

---

## Raised by building phase 3

### 13.1 Should the motion passes go to the thread pool at all?

They currently do, and it makes them **slower**.

Phase 3's demo measures the same session at one, two, four, and eight threads.
Results are identical at every beat, which is the claim that mattered. But the
wall time climbs with the thread count: twenty-four bodies is a few microseconds
of arithmetic, and waking a pool and waiting on a barrier costs more than the
work it is coordinating.

Sight was worth parallelising and motion is not, which is the same measurement
pointing in two directions. The pool is not the wrong tool; motion at tabletop
scale is the wrong size of job for it.

The obvious shape: a pass declares a **threshold**, and below it runs on the
calling thread. That keeps one code path -- the pool of one is already exactly
this -- and makes the threshold a number somebody measured rather than a
judgement somebody made.

What is not obvious is where the threshold goes. Per pass, per world, or read
from `input/`? And whether it should be measured once at startup on the host's
actual machine rather than compiled in, since the crossover depends entirely on
how fast a barrier is there.

### 13.2 Does a replayed turn re-snapshot?

Currently no, deliberately: a retcon replays turn boundaries forward without
capturing new heads, because the ring already holds those heads and overwriting
them would destroy the history a second rollback would need.

The consequence is that after a deep retcon, the ring holds heads captured
before the correction. Rolling back again lands on a head that is still correct
-- the state at that turn's start did not change -- but the reasoning is subtle
enough to be worth a test that nobody has written.

### 13.3 What happens to commands declared after the point a retcon replays to?

A retcon replays to where the session was. Anything in the log past that point is
applied afterward without being ticked through, which is right for standing
orders and wrong for anything order-dependent.

It has not come up because phase 3 has no way to declare a command in the future.
Phase 4 does, and this is where it will surface.

---

## Raised by building phase 7

### 14.1 A rolled-back turn does not roll back the sheets

A world snapshot copies flat blocks of bytes, which is what makes it a memcpy. A
ruleset's sheet storage is a Lua table, which is not that.

So taking a turn back restores every position, every wall, every fog bitmap and
every dice position -- and leaves the hit points where they were. **A rollback
that looks like it worked.**

Three ways out, none taken:

| Way | What it costs |
| --- | --- |
| The ruleset provides `snapshot` and `restore` hooks | Every ruleset author must get it right, and one who does not produces a rollback that silently half-works -- which is worse than one that visibly does not. |
| The server serialises the sheet table generically | Works only for plain data. Breaks quietly on a closure or an upvalue, which is exactly what a ruleset with interesting rules will contain. |
| Accept it | Honest and cheap and wrong in a way people will notice the first time somebody undoes a fight. |

`rules_sheets_survive_rollback` exists and returns 0, so a caller can **say** so
rather than pretend. The phase 7 demo shows it happening.

This is the largest known hole in the project.

### 14.2 Can a ruleset make a replay diverge?

Lua's only number type is a double, so every value crossing the rules boundary is
floating point, and `073-rules` is exempt from the build's floating-point check
for that reason.

That is a relocation of the determinism argument rather than a hole in it: what
was banned in C was the compiler's freedom to reassociate and to fuse, and a VM
executing bytecode one operation at a time has neither. The four arithmetic
operations are deterministic given the same inputs.

**What is left open is transcendentals.** `math.sin` in one C library may not
agree with `math.sin` in another to the last bit, so a ruleset using them may
replay differently on a different machine.

Three possible answers, none chosen: remove them from the sandbox and make
rulesets poorer; provide our own integer versions and make them slower and
stranger; or leave them and rely on the determinism harness to catch a divergence
after the fact.

The harness does catch it -- the world hash compared at every beat is exactly
this test -- so the current position is "leave them, and find out". That is a
position, not an oversight.

### 14.3 Who reads a ruleset's error?

A failing hook is abandoned after eight failures and its error is recorded, and
the refusal that comes back says the ruleset failed rather than that it declined.

But the error is currently only visible to whoever issued the command. A GM
probably wants to see it; a player probably does not want a stack trace; a log
file cannot be read during a session. Undecided.

---

## Raised by building phase 9

### 15.1 The tier cut lines are frozen and the distribution is not

`sprite_machine_tier` files a sprite under one of five tiers by comparing its
score against four numbers. Those four numbers are the tenth, thirtieth,
seventieth and ninetieth percentiles of a real distribution, measured by
`084-calibrate` over thirty-two thousand generated sprites.

The first set of numbers was not measured. It was four round values that looked
reasonable, and against the generator's actual output it put ninety per cent of
every sprite into two tiers and left tier one entirely empty. A five-point scale
that is really a three-point scale is worse than a three-point scale, because the
two dead numbers look like information.

**What stays open is that the measurement has a date on it.** Add a shape to the
paintbrush, change how large a body is drawn, weight a grading component
differently — and the distribution slides underneath the four lines. Tier five
comes to mean "the best third" instead of "the best tenth" with nothing raising an
error, and every rating anybody recorded against a tier is quietly describing a
different pool than it did.

`084-calibrate` exists and exits non-zero when the tiers have gone adrift, so the
question is not "how would we find out" — it is **who runs it, and when**. Three
possibilities, none chosen:

| Answer | Cost |
| --- | --- |
| The build runs it every time | Adds seconds to every build for a check that only matters when the generator changed. |
| A person runs it after touching the generator | Free, and depends entirely on somebody remembering. |
| The pool refuses to accept ratings while the calibration is stale | Correct and severe. Turns a quiet drift into a stopped studio. |

### 15.2 A tier is a ranking, and the dial reads it as a verdict

Because the cut lines are percentiles, tier five means *in the best tenth of what
this paintbrush produces*. It does not mean *good*.

That is the right meaning for the quality dial, whose job is to hand back the
better ones. But it has a consequence nobody would expect from the word "tier":
**improving the generator does not raise anybody's tiers.** Make every sprite
better and the distribution shifts, the percentiles shift with it, and the same
ten per cent are still tier five. The scale measures spread, not quality, and it
will report a paintbrush that has genuinely improved as exactly as good as before.

The alternative is absolute cut lines, which have the opposite failure: they drift
without anybody touching them, because "sixty points" means whatever the current
components happen to add up to.

Not resolved. Worth resolving before anybody uses a tier to decide that the
generator has got better.

### 15.3 An empty word was offered a suggestion

Not open — fixed — but recorded because the shape of the mistake recurs.

`sprite_nearest_word` offered `bob` for an empty word, because the threshold was
"at most three edits" and three edits is the whole of a three-letter word. The fix
is a second condition: the distance must also be **shorter than the word being
corrected**, so that most of what was typed survives into the suggestion.

`076-describe` had the identical bug in its own suggester and was fixed the same
way. The lesson is that an edit-distance threshold is only meaningful relative to
the length of the input, and a bare constant is a bug waiting for a short word.

### 15.4 A world file's checksum cannot survive a format change

A world file carries a hash of its own contents in its header. That hash is
computed by walking every field of every record — and the walk is whatever the
current build's walk is.

Adding two sprite fields to a thing broke it. A version 2 file's hash covered
nine fields per thing; this build's walk covers eleven. Recomputing it on load
compares two different questions and always disagrees, so **every version 2 file
would be refused as corrupt**, and the converter ladder — which exists precisely
so old files keep working — could never actually be used for a change of shape.

The ladder had one rung before this and that rung changed no record's shape, so
nothing had ever tested the thing the ladder was built for.

**What is done now:** the hash is checked only for a file that needed no
migration. A migrated world records the version it came from in
`migrated_from`, so a caller can say out loud that its integrity was not
verified. That is a loss, stated rather than hidden.

**The real fix, not yet done:** a checksum over the file's BYTES instead of over
the world's FIELDS. Version-independent by construction, because bytes do not
have a schema.

It is not free. The field walk is currently shared with the determinism
instrument — the same function produces the number two running servers compare at
every beat — and those are two different jobs wearing one name:

| Job | Wants |
| --- | --- |
| determinism | a walk over fields, so that two worlds built differently but identically compare equal |
| file integrity | a walk over bytes, so that any version verifies and disk rot is caught |

Splitting them means a second hash and a second place to keep in step. Written
last rather than in the header, so that a streaming writer can accumulate it and
never seek — which also keeps the writer usable on a pipe.

| Answer | Cost |
| --- | --- |
| Split the two hashes | The right shape; two things to maintain instead of one. |
| Keep a hash function per version | The once-per-pair growth the ladder exists to avoid. Nobody writes the sixteenth. |
| Leave it, and accept unverified old files | Free, and quietly weakens the check every time the format moves. |
