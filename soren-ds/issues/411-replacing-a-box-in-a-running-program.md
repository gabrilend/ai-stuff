# 411 — Replacing a box in a running program

## Current behavior

**A box can be compiled on the device and there is no way to put it to
work.**

The catalogue has a row for it. Nothing places it, so nothing runs it.

## Intended behavior

**A new station, the arrows moved, the old station left unwired.**

The old plan was a hot swap: find the box's entry, store a new function
pointer over the old one, and every station running that box picks up
the new code on its next run. That plan does not survive the design
underneath it, and the reason is not an implementation difficulty:

> **A station's box cannot be changed.** Its input ports were sized from
> that box's parameter widths when it was placed, and they may be
> holding values right now. Storing a different function over the top
> means the next run hands those bytes to something that expects a
> different shape.

So the replacement uses only operations that already exist:

```
   before                          after

   ─→ [ old ] ─→                   ─→ [ new ] ─→

                                   the old station is gone, and its
                                   place is available to the next
                                   station anybody adds
```

| step | operation |
|---|---|
| 1 | place a station running the new box |
| 2 | draw the arrows into it, as one batch |
| 3 | draw the arrows out of it, as one batch |
| 4 | remove the old station |

**Step 4 used to be *give the old station's inputs no source*,** because
a station could not be removed. It can (207), so it is, and three things
follow. The table stops growing by one station per edit, which on a device
whose purpose is being edited while it runs was the whole worry. The page
of code the old box lived in becomes reclaimable, where before it stayed
reachable forever (410). And the removal itself cuts every arrow that
named the old station, so the walk in step 4 is doing work the unwiring
had to do anyway.

The *no source* state is still what parks a program (213) and what a
failing box uses to take itself out of service (214) — those two want a
station that stops running and **stays**, which is a different thing from
one that goes away.

**Step 4 is a separate step, and a caller may defer it.** The programming
environment does (804): a person who has just saved a box is still looking
at the result, and putting the arrows back is how they undo a save — which
needs something to put them back to. So the editor stops after step 3 and
removes the old station when the person has decided. Removal being an act a
caller performs, rather than something that happens to them as a
consequence of rewiring, is what makes that possible without a second
mechanism.

**Arrows move in batches**, which matters more here than anywhere else.
Attach one arrow into the new station and values start arriving; attach
the next a moment later and it has already missed everything the first
one got. A batch means every arrow starts from the same instant.

**Values already in the old station's ports are discarded with it.** They
are not drained and not delivered. Whether that is acceptable depends on
what the box was doing, and it is the honest answer rather than a tidy
one: the engine will not invent a policy for values a person's edit
stranded, and it will not keep a station alive forever so that the values
inside it can go on existing unreachably.

**A value already in flight toward the old station is also discarded**,
because a worker reads a port's destination list once and then visits the
entries, so a removal can land in between. That is what this engine does
with any value that has nowhere to go.

Somebody who wants those values to survive an edit has a way to say so
that does not need a new mechanism: wire the old station's output
somewhere that keeps them, and remove it after they have drained.

**What the old plan bought that this does not.** A hot swap kept the
station, so it kept the station's identity, its buffered values, and its
place in every arrow anybody had drawn. This changes the station, so a
program written back out afterwards has a different shape from the one
somebody wrote. That is a real loss and it is the price of the ports
being sized to a box.

**What this buys that the old plan did not.** It cannot go wrong in the
way the old one could — there is no window in which a station's ports
and its box disagree about what a value is. And it needs no new
mechanism at all: four calls that already exist, in a sequence.

**And the loss is smaller than it was.** While a replaced station had to
stay in the table, a program written back out carried one dead station per
edit, so the shape drifted further from what somebody wrote with every
save. Now the only difference is which place in the table the live station
sits in, and a place is not something a map file mentions.

### Rolling back is the same act, backwards

The old station is still there, still placed on the old box, with its
arrows removed. Putting the arrows back is the rollback, and it needs
nothing new. A device that has just been handed a bad box by somebody
learning is a device that wants that to be one operation.

**Automatic rollback is not in scope.** Deciding that a box is
misbehaving means deciding what misbehaving is, and the only signal
available in this phase is that the box removed itself (214). Phase 9's
protection work adds the other one — a box that reaches outside its
region — and that is where an automatic version belongs.

## Suggested implementation steps

1. The replacement as one call: given a station and a new box, place,
   rewire, and unwire. It calls nothing that did not already exist.
2. The rollback as its inverse, given the two stations.
3. A record of the pairing — which station replaced which — so the
   rollback has something to name and so the transcript can say what
   happened.
4. A test that a running program's output changes at the first run after
   a replacement, and never mid-value.
5. A test that values stranded in the old station's ports stay exactly
   where they were.
6. A test that a rollback restores the previous behaviour and that the
   two stations can be swapped back and forth repeatedly.

## Open questions

- *Does the old station get cleaned up eventually?* It cannot be
  removed, so it accumulates: an afternoon of editing leaves a trail of
  unwired stations in the table. Each is small — a record and its ports'
  cells — but the trail is unbounded, and the answer is either "that is
  what a session costs" or a mechanism the design currently refuses.
  This is the strongest argument anybody has for making stations
  removable, and it should be weighed there rather than here.
- *Should replacing carry the old station's buffered values across?*
  The new box may take the same widths, in which case the bytes are
  meaningful; it may not, in which case they are not. Deciding by width
  is exactly the reasoning 303 accepted everywhere else, so it would be
  consistent — and consistently able to move a value into something that
  reads it wrong.
- *Who names the new station?* Somebody editing wants the same name
  back, and two stations cannot share one. Suffixing is the obvious
  answer and it makes the written-out program read like a history of
  the session rather than a description of a program.

## Blocked by

409, 410, and phase 2's construction operations.

## Blocks

412.

## Related

- [409 — Compiling a box on the device](409-compile-pipeline.md)
- [212 — Maps built by hand](212-maps-built-by-hand.md), whose four
  operations are the whole of this
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  which uses step 4 for its own reason
