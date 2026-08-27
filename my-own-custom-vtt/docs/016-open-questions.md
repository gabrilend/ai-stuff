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
[108](../issues/completed/108-a-world-writes-itself-down.md) stops being a debugging
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

### 1.3 What goes in the engraving's cells? — ANSWERED

Constrained in an unusual and useful way: **a creature has only so many places to
put a number.** The engraving cannot grow a column without being redrawn, so the
set of statistics is small, fixed, and chosen rather than accumulated.

**Eight, and they came from [the goodbye](../output/goodbye)** — which named them
before any of this existed, which makes it the honest source rather than a guess
made afterwards. Beats, turns, seats, commands, refused, rollbacks, things, and
the checksum.

The ratio of commands to refusals is the most direct evidence there is about
where an interface confuses people, which is why both are there rather than
either. Names are deliberately absent: a seat is a count, and a record that
outlives the evening must not be keyed on something somebody can change between
one evening and the next.

See [090-record](../src/090-record.info.md).

### 1.4 What picks the creature? — ANSWERED

Each record log gets its own. The three candidates were: chosen by a person,
drawn from the session's seed, or derived from the statistics themselves — a long
session becoming a mammoth, a short violent one becoming a hawk.

**The seed picks it**, folded with the beat the session stopped on. So two runs
from the same starting number that lasted different lengths get different
animals, because they were different evenings, and the carving belongs to the
run.

The third option was the most appealing and it was not taken. Deriving the animal
from the statistics means the shape of a campaign picks its own creature, which
is lovely — and it means the animal changes when the numbers do, so a session
that ran two beats longer is a different species. The carving is a picture of one
evening, and an evening does not change after it ends.

The seed is stirred before the animal is chosen, which was not obvious: taking
the high bits of an unstirred seed made every small number pick the fish,
including 1, 2 and 3. See [094-creature](../src/094-creature.info.md).
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

### 3.2a How long is a turn's window, in ticks? — ANSWERED, AND THE QUESTION WAS WRONG

See [3.5](#q-3-5). There is no window; there is an interval between rollback
checkpoints, and the question of how long it should be is a question about
rollback granularity rather than about how a table plays.

Ten beats is the default, which at twenty beats a second is a checkpoint every
half second. One is legal and expensive rather than special.
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
[205](../issues/completed/205-the-fog-is-a-bitmap.md) builds snapshot and restore for a fog
record from the start, and [309](../issues/completed/309-taking-a-turn-back.md) includes fog
in the ring alongside the world blocks and the random stream positions. The
decision gets a comment at the point where fog is restored, because the other
answer will look like a bug to the next reader.

### 3.4 Who may roll back a turn?

A GM, presumably. But there are several GMs, and a retcon changes what somebody
else did without asking them -- see the re-declare versus retcon table in
[019](019-the-turn-is-a-transaction.md). Does it need agreement? Does the person
whose command is being rewritten get told?

### 3.5 What closes a turn's window? — ANSWERED, AND THE QUESTION WAS WRONG

**There is no window.** Play runs continuously.

The question was asked and the answer came back as another question: *what do you
mean by a window?* Which was the right response, because nothing in the program
ever waited. Commands are accepted on every beat and applied on the beat they
arrive. A turn boundary copies the world aside and the next turn opens on the
same beat.

So the thing that was called a window is **the interval between rollback
checkpoints**, and the field is named `beats_between_checkpoints` now. A turn is
a place you can go back to. That is the whole of what it is.

The number is a trade between how finely you can aim a rollback and how often the
world is copied — ten beats at twenty a second is a checkpoint every half second.
It is not a rule about how a table plays, and calling it a window made an ordinary
interval sound like one, which is why the question could not be answered as asked.

**The general shape, worth keeping: a name that implies a behaviour the code does
not have will generate questions nobody can answer.** Three plausible answers had
been written down for this one — everybody has declared, a timer, the GM says so
— and all three were answers to a question about a thing that does not exist.
### 3.6 Does a rolled-back turn appear in the engraving? — ANSWERED

Yes. `rollbacks` is one of the eight cells.

The guess in the original wording turned out right: **it is one of the more
telling numbers on the carving.** A session with eleven of them was a session
about something, and it sits next to the ratio of commands to refusals, which is
the other statistic that is about the table rather than about the world.

It needed a counter on the session rather than a walk of the log, because the log
records what was DECLARED and a rollback is not a declaration — there is nothing
in it to count afterwards. It is incremented after the restore succeeds, so a
rollback that could not restore is not counted as one that did.

See [090-record](../src/090-record.info.md).

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

### 6.1 When a goblin patrol walks out of the forest and into the tavern, whose is it? — ANSWERED

**It stays the forest's, and the tavern's owner can still do things to it.**

> Player ownership refers to the ability to move the pieces on the board and
> wield them to do things. It does not determine who is able to affect other
> things — you can absolutely kill the goblins, tavern-owner. But you better
> explain how.

The question had been unanswerable because the model had one gate where it needed
two. Every verb asked *is this yours*, so a tavern owner could do nothing at all
to a patrol standing in their common room.

| Question | Gate |
| --- | --- |
| May I **move** this? | membership — only what is in a scope you hold |
| May I **act on** this? | sight, then the ruleset |

"But you better explain how" is the whole design of the second one. The server
knows the person could see the thing and knows an intent number; it has no
opinion about what any of them mean, and the `on_interact` hook — in the hook
table since phase 7 and never called by anything — is where the explaining
happens.

The gate is **what the outbound filter told you about**, remembered rather than
recomputed, because two answers to "can this person see that" is how a permission
model develops a hole nobody can find.

See [who controls what](008-who-controls-what.md) and issue
[1201](../issues/completed/1201-commanding-is-not-affecting.md).
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

### 7.1 What happens when a ruleset raises an error mid-tick? — HALF ANSWERED

The whole argument for embedding Lua rather than compiling rules in is that
somebody's homebrew should not take down the table. So: the offending hook is
abandoned, the tick continues, and a sentence goes somewhere a person will read
it.

**The half-applied changes are discarded, whole.** A hook does not touch the
world directly; it queues requests that are drained after it returns, so a hook
that fails part-way through has its queue cleared and nothing it asked for
happens. That was one of the reasons for making it a queue in the first place,
and it makes the answer free rather than careful.

A hook that keeps failing is abandoned after eight failures and stops being
called at all, which is failing open — the commands it would have refused are
simply allowed. That is a choice and the phase 7 demo names it: failing shut
would freeze an evening over one bad line in somebody's homebrew, and carrying on
with no rules at all is worse than right and much better than stopped. It is only
defensible because the breakage is announced loudly first.

**What is still open is which person reads the sentence**, and that is
[14.3](#q-14-3) rather than this.

### 7.2 Are stale ghosts shown?

When a viewer sees a goblin and walks away, is a faded goblin drawn at the last
place they saw it? [Sight and what it remembers](007-sight-and-what-it-remembers.md)
proposes this is the ruleset's decision, because it is a statement about how the
game handles uncertainty. That may be over-thinking it.

---

## Blocking phase 8 — content generation

### 8.1 What does the description language look like? — ANSWERED

The five-stage pipeline in [content is generated](013-content-is-generated.md)
said what the stages do and nothing about the syntax of the thing feeding them.
It was the part of the project most likely to become a language, and the part
where deciding by accident would be worst.

**It is `key = value`, one per line, over a closed vocabulary of eight words.**
Not a language. Deliberately, and the deliberateness is the answer: a closed
allowlist has nowhere for an analogy to go, and anything generating descriptions
— a person working fast, and much more so a language model — will invent
plausible neighbouring words when handed a complete reference.

Every fault is reported at once rather than one per run, each naming the line,
the word, what was found and the nearest legal word. It refuses rather than
filling in.

See [076-describe](../src/076-describe.info.md) and
issue [801](../issues/completed/801-a-description-is-validated-first.md).

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

### 10.5 Does a machine grader that watches motion actually exist here? — ANSWERED

Yes, and it was easier than the question expected.

The worry assumed the grader would have to *watch* a rendered animation. It does
not: the motion is a field of the sprite and a declaration in the file, so reading
it is reading the animation rather than one still frame. That is achievable
because the format is SVG with the motion declared in it, and would not be
achievable for a raster format — which is one of the four reasons the format was
chosen.

Motion is worth twenty of the grader's hundred points, and a still sprite scores
four. That is an opinion, and it is the project's: the vision asked for art that
behaves more like a video game than like a picture.

So algorithm A works as described. See
[082-sprite](../src/082-sprite.info.md).

### 10.6 Does the studio ever regenerate a sprite that is in use?

A sprite is referenced by things in a live world. If the studio produces a better
goblin, does the running session pick it up, at the next session, or never? Never
is the safest and is also how a library stops improving.

---

## Blocking phase 10 — the second view

### 11.1 Does the terminal renderer draw sprites at all? — ANSWERED

The worry was that the protocol would carry vector sprites a terminal cannot
draw, leaving the second view either ignoring appearance entirely — which weakens
the proof — or forcing a constraint back onto the sprite studio.

**Neither happened, because the wire carries the paintbrush rather than the
picture.** A sprite arrives as at most six layers of small integers, so the
terminal takes the body layer's shape as a glyph and its colour as the colour,
and drops the rest.

| Shape | Glyph |
| --- | --- |
| circle | `o` |
| rect | `#` |
| triangle | `A` |
| ring | `0` |
| wearing nothing | `*` |

**The drawing is reduced; the data is not.** The same instructions arrive at the
terminal as arrive at the browser, and the terminal says at startup that it is
throwing five sixths of them away rather than pretending otherwise.

No constraint was pushed back onto the studio. The one that made this possible —
the paintbrush being a closed set of numeric moves — was decided in phase 9 for a
completely different reason.

See [102-watch](../src/102-watch.info.md).

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

### 12.3 Where does the recorded value go, and how big does it get? — MEASURED, NOT DECIDED

Every operand is written to the command log as it is decoded, before anything acts
on it -- including operands belonging to commands that are then refused.

**It is not capped.** The log doubles its array when it fills and keeps every
entry for the length of the session, and so does the index of where each turn
begins.

Now the arithmetic, which was the missing half of the question. A log entry is 32
bytes. Six people issuing a command every beat at twenty beats a second is 120
entries a second, which is under four kilobytes a second and about thirteen
megabytes for a four-hour evening. A doubling array wastes at most half of that
again.

So the honest position is that **the log is small enough not to need a decision**,
and the reason to write that down rather than leaving the question open is that
"it grows without bound" and "it grows to thirteen megabytes" are very different
facts and only one of them is worth acting on.

What is still genuinely undecided is what happens across sessions -- a campaign is
not one evening, and nothing yet writes a log to disk at all. That is downstream
of 1.2, which is answered for the world and not for the record.

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

### 13.2 Does a replayed turn re-snapshot? — ANSWERED

No, deliberately: a retcon replays turn boundaries forward without capturing new
heads, because the ring already holds those heads and overwriting them would
destroy the history a second rollback would need.

The consequence is that after a deep retcon the ring holds heads captured before
the correction, and rolling back again must still land somewhere correct — the
state at a turn's *start* did not change.

**The reasoning was called subtle enough to be worth a test that nobody had
written. It is written.** It plays five turns, retcons deep into the middle of
them, then rolls back again to a head captured before the correction and compares
the world hash against the one recorded at that head. If the reasoning were
wrong, that second rollback would land on a world nobody was ever in, and every
other check in the test would still pass.

**And writing it found a small asymmetry nobody had stated.** A session starts on
turn zero without `begin_turn` ever being called for it, so **turn zero has no
head in the ring and cannot be rolled back to**. That is not a defect — there is
nothing before the start of a session to return to — but the test assumed
otherwise and failed, which is how it surfaced. It is now written down in the
test, where somebody will meet it.

### 13.3 What happens to commands declared after the point a retcon replays to?

A retcon replays to where the session was. Anything in the log past that point is
applied afterward without being ticked through, which is right for standing
orders and wrong for anything order-dependent.

It has not come up because phase 3 has no way to declare a command in the future.
Phase 4 does, and this is where it will surface.

---

## Raised by building phase 7

### 14.1 A rolled-back turn does not roll back the sheets — ANSWERED

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

`rules_sheets_survive_rollback` existed and returned 0, so a caller could **say**
so rather than pretend. The phase 7 demo showed it happening. It was the largest
known hole in the project for four phases.

---

**There was a fourth way, and the second one's cost had been misread.**

The second option was rejected for breaking *quietly* on a closure. That is a
property of one implementation of it, not of the idea. **A copier can know
perfectly well what it cannot copy**, and the whole difference between a good
answer and a bad one is whether it says so, and where.

So sheets are deep-copied at the head of every turn and copied back on a
rollback, and anything that cannot be copied stops the snapshot with a sentence
naming the path:

    the sheets could not be copied: sheet.2.attack holds a function

Three things make that safe rather than clever:

**The copier is Lua, not C**, and it lives in the registry where a ruleset cannot
reach it. C says "copy" and "put it back" and never looks inside a sheet, so the
rule from issue 703 — the server never reads a sheet — stays literally true. The
refinement worth stating: *the server may copy a sheet; it may not interpret
one.* That is the same distinction the world file writer already relies on when
it copies a `kind` it has no opinion about.

**A turn that could not be snapshotted is not rollbackable, and says why.** Not
half-rollbackable. `session_can_roll_back_to` already answered this question for
turns that had fallen out of the ring; this is the same answer for a different
reason, and `session_why_not_rollbackable` gives the sentence. The refusal happens
*before* anything is restored, so the world is left exactly where it was.

**A failure to snapshot does not stop play.** That one turn cannot be taken back
and everything else carries on — the same argument that made an abandoned rule
hook fail open rather than freezing an evening over a line in somebody's homebrew.

**A write of something uncopyable is refused where it happens.** A sheet's
metatable rejects a function at the moment it is stored, naming the field, so the
ruleset author learns at the line that did it. A ruleset can call `setmetatable`
and take the guard off, which is why the copier validates as well: *the guard is
for the message, the copier is the authority*, and there is a test that removes
the guard and checks the copier still refuses.

Cycles are refused too, rather than flattened. Flattening a cycle silently turns
what the ruleset stored into a different shape that looks similar, and the
ruleset would go on using it as though nothing had happened.

Issue [703](../issues/completed/703-the-ruleset-owns-the-sheets.md) was reopened
to close this rather than a new issue being written beside it, because the fix
belongs in the issue that built the storage. See
[073-sheet-copier.lua](../src/073-sheet-copier.lua).

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

### 15.3 An empty word was offered a suggestion — ANSWERED

Fixed, and recorded because the shape of the mistake recurs.

`sprite_nearest_word` offered `bob` for an empty word, because the threshold was
"at most three edits" and three edits is the whole of a three-letter word. The fix
is a second condition: the distance must also be **shorter than the word being
corrected**, so that most of what was typed survives into the suggestion.

`076-describe` had the identical bug in its own suggester and was fixed the same
way. The lesson is that an edit-distance threshold is only meaningful relative to
the length of the input, and a bare constant is a bug waiting for a short word.

### 15.4 A world file's checksum cannot survive a format change — ANSWERED

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

---

**The first was taken. The file format is version 4 and carries both.**

| Checksum | Where | Answers |
| --- | --- | --- |
| the field hash | the header | *does this build's reader reconstruct the same world the writer had* — a question about **code** |
| the byte checksum | the very end | *did this file change on disk* — a question about a **disk** |

The byte checksum is accumulated as the file is written and again as it is read,
through a small `struct tally` that carries a file and a running total. **Passed
rather than kept in a static**, because two threads writing two worlds is a thing
this project does and a hidden accumulator would silently mix them.

It sits at the end rather than in the header so a streaming writer never has to
seek — which keeps the writer usable on a pipe, and a world you can pipe is a
world you can hand to somebody without a file existing at either end.

**The test flips every byte in the file, one at a time, and checks each one is
caught** — including the eight bytes of the checksum itself. Not one byte in the
middle: a checksum that catches a change in the header and not in the string pool
is a checksum with a blind spot, and the only way to know is to try all of them.

The field hash stays, and after the byte check has passed on a current-version
file it cannot fail by construction — which makes it a **bug detector** rather
than an integrity check. A writer and a reader that disagree about a field would
show up there and nowhere else.

A version 3 file or older still cannot be verified, and `migrated_from` still
records that so a caller can say so. That is unavoidable: those files carry only
a walk over a field set this build no longer has. **From version 4 onward it
stops being true forever**, because bytes do not have a schema.


### 15.5 The pictures exist and the table cannot see them — ANSWERED

**Done in phase 11**, and the answer is the one this entry predicted: the layers
go on the existing wire as numbers, and each view assembles them. A view renders
the paintbrush; it does not own it.

Measured rather than assumed: about six instructions per visible thing per beat,
twelve bytes each, which came to between one and eight per cent of an update in
a generated inn. The visibility fan is far larger. Both the phase eleven demo and
the terminal view report the figure rather than anybody estimating it here.

The original entry follows, because the reasoning is why it was built this way.

---

Phase nine built a generated appearance layer and the browser still draws
coloured circles. Sprites are written to disk, they animate when opened, and
nothing sends one to a viewer.

That is the gap between "the art is generated" and the thing actually asked for,
which was art that behaves more like a video game than like a picture somebody
moves tokens around on.

**The shape of the answer is already decided by the paintbrush being closed.**
A sprite is at most six layers, each of which is a shape, a palette slot, two
offsets and a radius, plus one motion for the whole thing. Every one of those is
a small integer. So a sprite can be sent as **numbers on the existing wire** --
one instruction per layer and one for the motion -- and the browser assembles the
SVG from them.

That matters because the two obvious alternatives are both bad:

| Alternative | Why not |
| --- | --- |
| Port the generator to JavaScript | A second implementation that has to agree byte for byte, over 64-bit arithmetic that JavaScript does not have without BigInt. Two generators that disagree produce two different pictures and no error. |
| Send the SVG text | The protocol has fixed-width numeric slots and no byte strings, and adding one is a much larger change to the one place that decides what a viewer may know. |

Sending the layers makes the browser a **renderer of the paintbrush** rather than
a re-implementation of the generator, which is the same division the project uses
everywhere else: generate here, view there.

What is genuinely undecided is when. A thing's sprite never changes, so it need
only be sent once per thing per viewer -- but the outbound path deliberately
sends the whole picture every update rather than a difference, because that is
what makes a dropped update harmless. Sending six layer instructions per thing
per update is a few kilobytes for a busy map, which is probably fine and has not
been measured.

---

## Raised by building phase 11

### 16.1 The server reads one line of `input/` and there are seven

[`input/what-to-start-with`](../input/what-to-start-with) lists what a session's
opening decisions are: a seed, a world, a ruleset, a door, participants, a tick
rate, and a fog cell size. It says they belong in files rather than in a wall of
command-line flags, because a session is a small number of decisions and the
header of a replay is nearly the same set of fields.

**Only the world is honoured.** The server takes `--place` and `--seed` as
arguments, which is the thing that file exists to replace.

The rest are still command-line defaults or compiled-in constants:

| Decision | Where it lives now |
| --- | --- |
| seed | `--seed`, defaulting to a constant in the source |
| world | `--place`, or the hand-built fixture |
| ruleset | nowhere — the server loads none, and only the phase 7 demo ever does |
| door | `--` the first argument, and two constants for the private range |
| participants | nowhere. **Anybody who knocks is admitted.** See 4.2. |
| tick | a constant. See 3.2. |
| fog | a constant. See 2.1. |

The participants line is the one that matters. Permission is meant to be looked
up rather than claimed by a client, and there is nothing to look it up in — so
the door admits whoever knocks and hands them a body. That is fine for a table
of friends on one machine and is not fine for anything else, and it is the same
hole as 4.2 seen from a different side.

Not resolved. What is genuinely undecided is whether the file format should be
one file per decision — greppable, diffable, obvious — or one file with seven
lines. The directory reads better; the single file is what somebody actually
pastes to a friend, which is the same argument the engraving settled the other
way.
