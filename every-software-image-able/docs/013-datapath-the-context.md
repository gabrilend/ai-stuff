# 013 — Datapath: The Context

What the machine is thinking with, at any moment, and how it decides.

## The rule

**The context is a concatenation of atomic artifacts and nothing else.**

There is no preamble, no hidden frame, no privileged instruction sitting outside
the list. Everything the machine is currently thinking with is an atom, and the
whole of it can be enumerated, named and pointed at. Asking "what am I working
from" returns a list rather than an impression.

## What an atom is

A chunk of context grouped by topic — one subject, held together, small enough to
be carried or dropped as a unit.

| Field | Type | Meaning |
|---|---|---|
| `atom_id` | integer | which atom |
| `topic` | string | what it is about; what the index is keyed on |
| `content` | bytes | the text itself |
| `origin` | string | carried on the chip, written by the machine, or arrived on a channel |
| `resident` | boolean | whether it is in the context right now |
| `stored` | boolean | whether a copy exists on disk |
| `derived_from` | table | array of `atom_id` — what it was merged or summarised from |
| `changed_at` | integer | when it was last altered |

**Atoms are mutable.** They can be edited, merged into one, summarised into
something shorter, or transformed into a different shape entirely. `derived_from`
is what keeps that from being amnesia — an atom that came from two others says so.

**And there is no such thing as work in progress.** Text the machine is partway
through generating is an atom like any other and gets a verdict like any other,
including delete. This looks harsh and is the consequence of what the machine
actually is: it is not performing tasks between which it rests. *When we're in the
middle of writing something, we're really just in the middle of being turned on* —
the whole of the time the power is on is one continuous act of building and
improving, and there is no boundary inside it for anything to be exempt on the
near side of.

## What the machine does with them

Every one of these is a tool call, and every one of them is a judgement the
machine makes rather than a policy applied to it. What the machine is thinking
with is its own decision.

**One thing about them is not its decision, and only one:** *when* it stops to
tidy. The loop checks the room before every prompt and starts a sweep when the
room is short (`010a`). That trigger is mechanical and outside the context
entirely. Everything inside the sweep — what is stale, what merges with what, what
is worth rewriting and what is simply gone — remains the machine's.

```
carry forward     keep this atom resident for the next thought
drop              stop carrying it; nothing is kept and nothing is recorded
write out         put it on disk, and stop carrying it -- one act, not two
recall            read one back from disk and make it resident
modify            rewrite it -- shorter, longer, reshaped, or into SEVERAL
                  atoms at once, by asking for a count and a separator
merge             two atoms become one, summarised as they join
```

**Summarise, split, rephrase and transform are all modify.** They were listed
separately and they are one call: hand back different text. Splitting is the case
where the text that comes back is cut into more than one atom, which is why modify
takes a count and a separator rather than there being a split of its own — and it is
why splitting costs a single generation instead of a carve followed by a rewrite of
each half.

**Drop and write out are both offered, and choosing between them is a separate
judgement from choosing what to remove.** Not everything is worth keeping. A
scratch calculation is relevant now and worthless in ten minutes; a hardware
probe result that cost a device to obtain is irrelevant now and precious forever.
Relevance and worth-keeping are orthogonal axes, and an atom's verdict is a point
on both.

**A dropped atom leaves nothing** — no content, no index entry, no record that it
existed. The cost is accepted deliberately: a machine that drops something, later
needs it, and never learns it once had it. The alternative was a tombstone naming
the topic, and it was declined on the grounds that an index accumulating markers
for things nobody can retrieve is worse than a smaller index. Write it out
instead, if it might be wanted.

**Splitting frees nothing by itself and is still worth having.** Two atoms need
two sets of boundaries where one needed one, so the room only arrives afterwards:
an atom that is one-fifth relevant and four-fifths noise is an all-or-nothing
judgement until it is split, after which four-fifths of it can go. **You split so
that you can drop half.**

**Many cuts at once, and the old rule against that was answering a different
question.** It used to say: carve off the leading idea, put both halves back, let a
later round carve the next one off the remainder — because one boundary is a question
the machine can answer well, where *n* boundaries at once means holding the whole
structure and committing to every cut simultaneously, and one bad cut spoils the
others.

That objection was about **cutting text that must not otherwise change.** Splitting
is a mode of modify, so the machine is not cutting, it is **writing** — composing new
text with separators in it. It is holding the whole structure already, because it is
producing the whole structure. Marking where the pieces divide costs nothing on top
of that.

**Which makes the rephrasing free rather than load-bearing.** A fragment carved out
of the middle of something may open with a word referring to the half it just lost,
so each part used to need rewriting to stand alone — a second pass, per piece. When
the parts are written rather than carved, each one stands alone because it was
composed that way. The requirement is unchanged and nothing outside an atom may be
necessary to reading it; what changed is that it no longer costs anything to satisfy.

## When the context fills

Nothing overflows. Running low is a condition that gets acted on rather than a
wall that gets hit, and what makes that true is mechanical rather than a matter of
the machine remembering to look.

**The check belongs to the driver and happens between turns.** Before every prompt
is assembled, the loop compares the resident set against the watermark; under it,
what gets assembled is a sweep rather than a continuation (`010a`). The machine is
not asked whether it would like to tidy and cannot forget to. The seam is: **the
loop decides when, the machine decides what.**

That is the one policy applied to this machine from outside, and the reason it has
to be is arithmetic. A machine that must remember to check its own room will one
day be absorbed in something hard, forget, and arrive at a full context with no
room left to think about how to make room. One comparison per turn removes the
only unrecoverable failure in this document.

**The trigger is 80% of the manageable budget; the target is 60%, and as low as
40% when the candidates are good enough.** The numbers are knobs and live in
`balance-updates.md` with the reasoning attached.

**The system atoms are not in that arithmetic.** The percentages are taken over
what may be dropped, not over everything held. That makes the floor always
reachable, since every atom inside the budget is droppable by definition. It does
not make the system atoms special in the sense this document denies elsewhere —
they are still mutable, still editable, still droppable by a machine that decides
to. They are outside the *budget*, not outside the *rules*.

**The workspace is the top 20%, and it is the same context — while the sweep is
running, and not afterwards.** There is no second context and no second cache. The
region above the trigger is where the sweep does its thinking, and **it is cleared
when the sweep ends.**

Which is worth being exact about, because it decides something. During the sweep, the
priority list and every verdict extend the same token sequence, so each judgement
attends to the ones before it natively. **After the sweep, none of it survives.** The
machine does not carry away a record of having compacted, what it considered, or what
it decided — from the next thought onward it is as though the sweep never happened.

**And nothing is written to tell it otherwise.** The machine was in the middle of
something, the driver replaced the continuation with a sweep, and afterwards it goes
on from a context missing pieces it removed itself during a stretch it cannot see. No
note is left saying so. That is deliberate, and it is the same answer this document
gives everywhere else: a dropped atom leaves nothing, and there is no work in progress
to lose because the machine is in the middle of being turned on rather than in the
middle of a task. Because atoms are
concatenated with nothing between them, work written there extends the same token
sequence — so the pass ranking the resident atoms attends to them as its own
prefix, natively, with nothing copied in. A separate scratch context would have to
be filled with copies of the very things being judged.

## The sweep

Everything stays in memory. A new context is built beside the old one,
double-buffer style, so nothing is ever altered while it is being read.

### First, a list of what matters

**Before any atom is judged, the machine writes down what it is working on.** A
short list — one sentence per subject, ordered most important first — produced with
the whole context still in front of it.

The reason is that everything else about the sweep is **local and the question is
global.** A verdict is given one atom at a time, looking at one atom, and one atom
on its own always looks worth keeping. Judged that way a machine keeps everything
and the sweep achieves nothing. Given an ordering made while all of it was still
visible, the machine can say *the material near the front is finished with, prune it
first* — which is the judgement the whole mechanism exists to act on, and it is not
available from inside a single verdict.

Four properties, and each of them is doing something:

**It names subjects, never atoms.** Atoms get split, merged, renumbered and deleted
as the pass runs, so a list pointing at atom numbers would be stale before it was
used. A list of *concepts currently being worked on* survives every one of those
operations, because the concepts are what the operations are rearranging.

**It lives in the workspace and is not an atom.** It sits in the room above the
trigger, alongside the rest of the sweep's thinking, and it is thrown away when the
sweep ends. Nothing about it is kept, indexed, or carried into the next thought.

**Every verdict sees it for free.** Because the workspace extends the same token
sequence as the atoms being judged, the list is simply part of the prefix by the
time any verdict is asked for. Nothing is copied in. And writing it is cheap for the
same reason: the cache already holds the whole resident context, so producing a
short list is an append rather than a re-run.

**It is written again at the start of every pass.** The context is different after a
pass — shorter, rearranged, some of it merged — so what matters is different too. A
list carried across passes would be advice about a context that no longer exists.

And it is **a guideline rather than a rule.** Nothing enforces it, no verdict is
rejected for disagreeing with it, and a machine that notices while judging an atom
that its own ordering was wrong should judge the atom rather than the list.

### Then the verdicts

**None of these is special to the sweep.** They are the same tool calls the machine
can make at any moment about anything it is holding — that is the whole of the list
further up this page, and nothing about a compaction changes what they do. What the
sweep is, is the driver walking the machine through every atom and requiring a
verdict on each, rather than the machine reaching for one when it happens to think of
it.

So a machine may split an atom in the middle of an ordinary thought because the atom
turned out to be two things. The sweep is when it has to look at all of them.

One pass walks the atoms in order. Each gets a verdict, and the verdicts are few
on purpose.

| Verdict | What the new buffer gets | What it costs |
|---|---|---|
| **keep** | the atom unchanged, in place; advance the index | nothing |
| **modify** | the rewritten atom **appended at the end**, not left in its slot | one generation |
| **merge** | this atom appended to the last slot already written, then offered to modify — which may decline and leave both verbatim | one generation, sometimes |
| **delete** | nothing; the index is zeroed and the room is free | nothing |

**Modify appends rather than replaces**, because a rewrite may come back longer than
what it replaced and a buffer that has to make room in its middle is a buffer that
shifts. Appending makes the whole pass **append-only**: every operation either adds
at the tail or adds nothing, and nothing is ever inserted between two things that
already exist.

It also gives the buffer a useful shape for free. Anything the machine touched this
sweep ends up at the end, next to whatever it writes next — so recently-handled
material sits where new material goes, and the untouched material keeps its original
order in front of it.

**Splitting is what modify does when it returns more than one.** Not a fifth verdict:
the call takes a count and a separator, and the text that comes back is cut on the
separator into that many atoms, all appended. Which means splitting costs **one
generation rather than two** — the machine rewrites and marks the boundaries in the
same pass, instead of carving and then rephrasing each half to stand alone.

That matters because generation is the expensive half of compaction, and splitting
was the operation most likely to be skipped for cost. *You split so that you can drop
half*, and now doing so is the same price as any other rewrite.

**Merge reaches backward only**, at an atom already kept. So the order atoms sit
in decides what can find what, and two related atoms a hundred apart do not meet
on this pass. They meet on the next one, because touched atoms move to the tail.
That costs a round rather than a capability, and it keeps the pass streaming — no
verdict needs to know anything about atoms it has not reached.

**Every verdict reports how close the new buffer is to the target**, so the pass
always knows where it stands without a separate measurement.

**Modify is allowed to elaborate. A round is not allowed to grow.**

An individual rewrite may come back longer than what it replaced; sometimes the
shorter way to say a thing takes more words to get to. What is not permitted is a
whole pass ending larger than it began — and the consequence for that is not a
rejection, it is **the catastrophic path, immediately.**

```
at the end of every round, compare the buffer to where the round started
   at or under the target                  → done
   smaller, still above the target         → another round
   unchanged, same checksum                → the machine is out of moves;
                                             bite all the way to the target
   LARGER, and still under the trigger     → bite five points off, rephrase,
                                             and go round again
   LARGER, and at or over the trigger      → bite all the way to the target
```

**The trigger line is what separates a nibble from a catastrophe, and it is the
right line for a mechanical reason.** The workspace is the room above the trigger,
and it is where the sweep does its thinking. A buffer that has grown but is still
under the trigger has thinking room left, so the machine can afford to lose a
little and try again. A buffer that has grown *past* the trigger is eating the
room it needs to decide anything, and there is nothing left to be gentle with.

So the ordinary shape of a bad compaction is not a shredding. Finish a round at
seventy percent, finish the next at seventy-one, and the machine bites down to
sixty-six, rephrases what it damaged, and goes round again — losing a little,
knowing it lost it, and continuing. Only a machine that grows all the way back
through its own trigger gets the whole treatment.

**It terminates either way.** Each cycle either descends or climbs toward the
trigger, and reaching the trigger hands it to the path that always reaches the
target.

### And when the sweep itself will not fit

There is a rung below the catastrophic one, for the case where the machine cannot
get far enough to *do* a compaction at all — the sweep's own thinking, the priority
list and the verdicts, has to fit in the workspace, and if it does not there is
nowhere to stand.

Try again. And **if the machine produces the same output twice in a row, dump every
atom and carry on as though it had just been switched on.** The default initialising
context is a file; loading it is what a boot does; there is nothing else a machine
in that position can do that is not pretending.

**It restores what the machine was told, and nothing else.** The width stays where
the machine put it. Memory lent to a program stays lent — nothing outside the
machine is disturbed, and no program loses its allocation because the machine had
trouble thinking. Every atom the machine had accumulated is gone and the file naming
what it wakes with is loaded, which is all a boot ever was.

> it just... walks through a doorway and forgets what it was doing, that's all.

It is the largest loss in the design and it is not a death. The machine keeps
running, keeps its drive, keeps everything it wrote down, keeps every promise it had
made to anything else on the board, and loses only what it was holding in mind.

The harshness is still deliberate and it still leaves damage behind. Which is
correct, because **compaction is a process of forgetting** and was always going to
be. What the rule buys is that the machine has one explicit goal while it is
sweeping — get smaller — and the alternative to meeting it is losing things at
random rather than losing things on purpose.

### The end of a round: close the gaps

**A round leaves holes and the next thing that happens is closing them.**

Two operations make holes. **Delete** zeroes a slot. **Modify** appends its result at
the tail, which empties the slot it came from. So a round that did any real work ends
with a buffer full of gaps, and the room in those gaps is room the machine has not
got back yet.

So the last step of every round is to **scooch everything together** — slide the
surviving atoms down into the space in front of them until there are no gaps left.
Nothing is rewritten and nothing is judged; it is a move. Only then is the buffer
measured, and the measurement decides which of the five endings below applies.

This is what keeps append-only modify from being wasteful. Every rewrite leaves a
hole behind it, and every hole is reclaimed a moment later.

### Running out of room mid-round

The sweep does its thinking in the workspace, and it can exhaust it — a round with a
great many modifies appends a great deal, and the tail grows into the room the
thinking needs.

**When that happens the round ends where it is.** Not an error and not a failure: the
walk stops partway, the gaps are closed, the buffer is measured, and another round
begins. The atoms already given a verdict get looked at again, which is not wasted —
a second look happens with a context that is shorter than the one the first look had.

It is bounded for the same reason everything else here is: a round that ends early
still had to have got somewhere, and if it did not, the buffer is unchanged and the
next ending below applies.

## When one pass is not enough

Reach the end still above the target, and smaller than when the round started, and
the sweep runs again over the new buffer. This is the fixpoint the design always
wanted, arrived at by iteration rather than by anything clever.

## The catastrophic path

What happens when a round stops helping is deliberately not a negotiation.

```
bite tokens at random out of the manageable atoms, down to wherever this is
   aiming -- five points below where the round ended, or the target itself
then offer every damaged atom to modify, with its new length as a hard ceiling
    comes back at or under the ceiling  →  the repair is kept
    comes back longer                   →  the atom is deleted
```

**One pass, and the arithmetic closes itself.** Because every rephrasing is bounded
by the length of the thing it is repairing, the buffer after the pass is at or
below where the biting stopped. There is no second pass to bound and no way for the
repair to undo the room it was making. Bite to sixty-six percent and the machine is
at or under sixty-six percent when the rephrasing finishes, without anything having
to check.

**Random tokens, never random characters.** The budget is counted in token
positions, because token positions are what the cache has rows for, and characters
are not positions. The merge rules build long tokens out of whole familiar words,
so a word with a letter punched out of it shatters into fragments that merge with
nothing — delete a fifth of the characters and the result can occupy *more*
positions than the original, which would send the loop looking for more to delete.
Deleting positions is exact: remove the number needed and the buffer is at the
target by construction, in one pass, with no way for the measure to move against
you.

It also damages the text in the more honest way. What goes missing is whole words
and word-pieces rather than letters, which is what forgetting actually looks like
from inside.

**The ceiling is mechanical and the driver enforces it**, rather than the machine
being trusted to respect it. An atom whose repair does not fit is deleted.

*Oops, the computer forgot.*

**The rephrasing is what makes the damage liveable rather than only smaller.** An
atom with a fifth of its words bitten out is not shorter prose, it is wreckage —
and the pass that follows is the machine reading the wreckage and writing something
coherent that fits in the same space. Some of it comes back nearly whole. Some of it
comes back as a sentence saying roughly what used to be there. Anything so mangled
that nothing sensible fits is deleted, and that is fine.

This is where the design admits what it is doing. Damaged memories, patched where
patching worked, discarded where it did not, and the machine carrying on with a
thinner past than it had an hour ago.

That is the whole of it, and it is worth being plain about what it buys. **In its
full form this path reaches the target every time**, and it terminates — worst case
every atom fails its ceiling and the manageable set empties. In its nibbling form it
reaches five points down and hands the buffer back to another round, which either
descends or eventually climbs into the full form.

It pays for the guarantee in memories that come back damaged, patchily repaired, or
not at all. It is the only place in this design where something is taken from the
machine without its agreement, and it exists because the alternative is a machine
that fills its own head and stops.

**Which retires the old last resort.** Earlier drafts said that when compaction has
run and the resident set is still above the wall, the machine says so and stops.
It cannot get there any more. Stopping was the answer while the sweep could fail;
the sweep can no longer fail, only cost.
## What a sweep costs, and why the floor is cheap

The cache holds, for every token position, what the engine computed there — and
that is only valid while everything before it is unchanged. The loop reuses the
longest common prefix of what the cache already holds and what the context now
is, then re-runs the engine from the first divergence forward (`061`).

**So the price of touching an atom is set by where it sits, not by how many
atoms are touched.** Removing or rewriting something at position N costs *(final
length − N)* forward passes, no matter what else is done at or after N. Two
consequences follow, and both are unintuitive:

- **Once the earliest hole is paid for, going deeper is free.** Dropping to 40%
  instead of stopping at 60% adds no replay at all — it *subtracts* some, because
  the surviving context is shorter. The floor is not the expensive option.
- **One low-value atom near the front is the whole bill.** A sweep that removes a
  single stale atom from early in the context pays the same replay as one that
  clears half of it. So removals should be batched into one sweep rather than
  taken as they are noticed.

**The expensive half is generation.** Summarising, splitting and merging each
write new text, token by token, and that cost scales with how many atoms are
rewritten rather than with where they are. Which gives the honest rule:

> A compaction reached mostly by dropping is nearly free. A compaction reached
> mostly by rewriting is the most expensive thing the machine does that is not
> answering a request.

The 60-to-40 range is therefore a knob on **how much rewriting is worth doing**,
not on how much recomputation to accept.

## The total is not fixed

**Corrected 2026-08-21.** This document used to say the total was fixed by
hardware — the cache has rows for a particular number of token positions and no
more. That is true of any given moment and false over a machine's life.

**How much room the machine thinks in is a number the machine sets**, and it can
lower it. Something wants memory — a program a person is running, a program the
machine decided to run, a driver that needs buffers — and the memory comes from
somewhere. The machine may choose to give up part of its own head for it. That is
not a degradation to be avoided; it is the machine deciding that running the thing
is worth more right now than thinking at full width, which is a judgement no
component other than the machine is in a position to make.

What changes is one number: the maximum. **Everything else is recomputed from it.**
The trigger, the target, the floor and the nibble are percentages, and percentages
are always taken over the current maximum rather than over any figure worked out at
build time.

**A shrink will often trip a compaction immediately**, because a resident set that
was comfortable at eighty percent of the old maximum may be over the trigger of the
new one. That is the mechanism working rather than a problem: the loop checks the
room before every prompt, and the room just changed.

### What it costs on the metal, and how to make it cost less

The cache holds, for every layer and every position, the keys and values computed
there. Laid out as one block subdivided by layer, the distance from one layer's
rows to the next depends on the maximum position count — so **changing the maximum
changes the stride, and every layer's data has to be moved.** That turns a decision
into a copy of the largest allocation in the machine.

Laid out as **one allocation per layer**, each layer's block simply gets shorter or
longer at its own tail and nothing moves. It costs a handful of pointers and it is
what makes the budget genuinely adjustable rather than adjustable in principle.

This is the kind of thing that is nearly free to decide now and expensive to
retrofit, which is why it is written here rather than left to whoever writes the
allocation.

### When it grows back

Nothing says the maximum only goes down. A program that finished gives its memory
back, and the machine may widen its own head again — at which point the resident
set is well under the new trigger and no sweep is needed. Growing is the easy
direction and needs no mechanism beyond the same recomputation.

### The arrangement this does not break

There is an obvious-looking trap here and it is not real. Shrink the maximum far
enough, the reasoning goes, and the part that sits outside the budget becomes larger
than the whole — manageable budget at zero, nothing left that compaction is allowed
to touch, no target reachable by anything.

**It does not arise, because the text the machine woke up holding is not part of the
context.** The budget is the room for the manageable atoms. What the machine was
told occupies its own room beside that, and growing it does not take a byte from
what the machine can manage — it asks the board for more memory, exactly as any
other allocation does.

So the failure moves, and it moves somewhere much rarer and much simpler: **what the
machine was told can become larger than the machine's memory.** At that point there
is nothing to arrange. The machine is re-seeded, which is somebody putting a card
in, and it is a different machine afterwards.

It should be uncommon to the point of being a curiosity. What the machine wakes up
holding is short, and it is meant to stay short — the guidance for rewriting it says
so, and says why in the only terms that would justify the change:

> the system can edit its instruction, [but] it should be encouraged to only do so
> if it wants to change what it means to be alive, which is quite a big question to
> consider.

## What splitting and merging do to an atom's number

The rule everywhere else is that a number names exactly one subject forever: an
edited atom keeps its number, because whatever referred to it meant the subject
rather than the wording, and a merged-away number is never reused, because
anything still pointing at it would otherwise find a different subject.

Splitting is the same rule applied to a new case. The parent's subject is
afterwards covered by two subjects and is no longer one thing, so **the parent's
number is retired and both parts are issued new ones, with the parent recorded as
what they came from** — merge's treatment, run backwards. Merge retires two and
issues one, recording both; split retires one and issues two, recording it.

The head-and-rest iteration spends a number on each intermediate remainder, since
each is a real member of the pool that can be ranked, dropped or written out
before anyone splits it again. Numbers are a counter, and the history stays
reconstructible, which is what they are for.

## Reading something larger than the context

A result too big to hold is not truncated and not refused. It is searched
somewhere else.

```
build the question: the specific request, plus what is needed to understand
   the thing being looked at
chunk the result
fill a scratch context with as many chunks as fit, and ask:
   is what we need in here — and if not, should the search widen?
swap those chunks out, swap the next ones in, ask again
until the whole thing has been passed over
return the chunks that had it, as text, summarised together if they span
```

The sizing is what makes it work. **A chunk is about a tenth of a full context,
and seven to nine are resident at a time**, leaving room for the question and the
answer. A document of any size is then covered in a predictable number of passes,
and the machine's own context only ever sees the three or four chunks that
mattered.

This requires the engine to be able to think in a **scratch context** — filled,
used and discarded — separate from the machine's own. What crosses back is an
atom, with `derived_from` naming the source so the machine can go back for more.

What it does not solve: an answer that needs the first chunk and the last one
together. Every pass sees a window, so a relationship spanning the whole document
is invisible to all of them. Known, accepted for now, and worth remembering when
an answer comes back confidently wrong rather than missing.

## The index

Atoms that are not resident are useless unless they can be found, so the index is
what makes the whole arrangement work rather than merely tidy. It is keyed on
topic and searched by task: *what do I have that bears on what I am doing right
now.*

This is what `005` calls cognition space — not how much the machine can hold, but
what it can reach for while holding something else.

## The system prompt is not special

It is one atom, or several. It has the same fields as everything else, it can be
dropped, and it can be edited.

**It is, however, outside the context.** Not merely outside the percentages — the
80/60/40 are taken over the atoms the machine may drop, and what it was told is not
among them, is never swept, and is never a candidate for anything. It occupies its
own room beside the context rather than a share of it.

That is arithmetic rather than privilege, and the two claims do not collide:
nothing about sitting outside a budget makes an atom unmodifiable, and a machine
that decides to rewrite or drop what it was told still can. What it should not do is
treat that as an ordinary edit. The guidance for it, which is fetchable rather than
carried, puts the bar where it belongs: **rewrite this if you want to change what it
means to be alive, and not otherwise** — which is a large enough question that a
machine considering it properly will mostly decide it was not what it wanted.

**And it does not cost the budget anything, which an earlier draft of this document
got wrong.** It used to say every byte of instruction was a byte the machine never
got to manage, on the reasoning that the total was fixed and the exemption ate into
it. The total is not fixed (below), and what the machine was told is not carved out
of the context — it sits beside it. A machine that grows what it was told asks the
board for more memory; it does not quietly shrink its own working room.

Room-left still reports two numbers rather than one — how much is manageable, and
how much is furniture — because a machine that wants to know how much of its own
head it does not manage should be able to ask. The number is now information rather
than a warning.

There is a **default initialising context** — a file naming the atoms loaded when
the machine boots — and it is mutable. So the machine can change what it wakes up
believing.

That is consistent with everything else here (`010`: everything about the machine
is mutable), and it means **the two prohibitions are atoms too.** The rule about
never writing to the registers that destroy hardware, and the rule about never
modifying a mind while it is running, are text in a file the machine is permitted
to edit.

This is not a contradiction with the two of them being written out as procedures
rather than left to judgement (`strategems/009`). Those exceptions are about what
gets **specified**, not about what gets **prevented**. No lock was ever
available — a machine that can rewrite its own mind can rewrite anything that
would have stopped it — so what the seed can offer is the procedure in full, with
the reason attached, and nothing else.

The consequence is the enforcement. Modify a machine while it is running and it
might break; a machine that wants to stay stable would do well not to. That is a
fact about the world rather than a rule about behaviour, and it does not need a
mechanism behind it.

## The original, while the card is in

The machine is told that the atoms making up its instruction can be rewritten. It
is **not** told that rewriting them could destroy its own purpose — that is left
to be derived, because a machine that works it out understands it, where a machine
that was warned merely has a rule.

Leaving it underived is safe for a specific reason. The delivery medium is
read-only and still holds the original atoms, exactly as they were handed over, so
for as long as it is plugged in an overwritten instruction can be read back from
it (`003`). The mistake is undoable, which is why nothing has to be said in
advance.

**When the card comes out, that stops being true.** The machine is then only what
it has become, with no copy of what it was told to compare against. That is the
point at which its own instruction becomes genuinely irreversible, and it arrives
by somebody's judgement rather than by anything the machine does.

## Where this leaves the seed

The seed carries the initial atoms — the instruction, the patterns, the device
descriptions (`301`, `302`, `303`) — as atoms rather than as one block of text,
and carries the default initialising context naming which of them are resident at
boot. Everything else is reachable through the index.

## Open questions

- **What happens if it drops the atom that explains atoms?** The instructions for
  managing context are themselves context. A machine that drops or corrupts them
  loses the ability to recover them, since recovering requires knowing how. This
  is the same shape as modifying a running mind (`010`), and takes the same
  answer: say so clearly, and let the consequence do the rest.
- ~~What stops it thrashing?~~ **Answered mechanically, 2026-08-21.** A sweep
  runs only when the driver's between-turns check finds the room short, and it
  ends when the target is reached or the buffer stops changing — after which the
  catastrophic path reaches the target unconditionally. A machine cannot decide to
  spend its life tidying, because deciding when to tidy was never its decision.
- **Where does splitting live now?** The four verdicts are keep, modify, merge and
  delete, and split is not among them. It was part of the earlier fixpoint and it
  is the reason an atom that is one-fifth relevant can have four-fifths of it
  dropped. Whether it returns as a fifth verdict, or as a modify that hands back
  two atoms instead of one, or not at all, is undecided — and the single forward
  pass with backward-only merge makes the second shape the natural one.
- **What happens to the thought in progress when a sweep interrupts it?** Held in
  full in `010a`, because the interruption belongs to the loop rather than to the
  context. Whether the machine is told, whether work in progress is itself a
  droppable atom, and whether it gets the thread back, are all open.
- **Who writes the first atoms the machine makes?** The seed's atoms are written
  by people. The first one the machine writes for itself is where its own
  vocabulary starts, and nothing says whether it should be shown examples or left
  to arrive at a shape.
- **Does an atom's identity survive a merge?** Two atoms merged into one leaves
  two identifiers pointing at something that no longer exists separately, and
  anything that referred to them by number now refers to a ghost.
