# 105 — The thinking loop, and its limits

## Current behavior

**Reopened on 2026-08-04. The loop exists and does not run on the machine
it was built for.**

Everything below this paragraph is true and was true when this closed. What
was missing from it is the distinction between the two kinds of code in this
project, and this ticket is where that distinction first mattered.

**Assembly** is real processor instructions, which can be extracted as raw
bytes and put on a card. That is what runs on the chip. **A readable
program** runs on the development machine and reaches the assembly by loading
it as a library and calling in. That is scaffolding: it proves the assembly
is right, and it cannot go on a card, because a bare machine has nothing to
run it with.

The loop is the readable kind. So are the assembler, the hands, and the
context. That is the project's usual method applied faithfully at the bottom
and not yet above it -- the arithmetic got its readable version, then its
recorded answers, then its assembly. Everything above the arithmetic has the
first two and not the third.

The consequence is precise: **on a flashed machine, the waking code detects
the processor, says "handing over," and halts.** There is nothing to hand
over to.

Carrying this loop onto the chip is `107`, which is a separate ticket
because what it must do is more than this loop does -- it also has to find
its own pieces, find the model's tensors, and lay out memory, none of which
this loop does because a foreign-function interface did all three for it.

**This ticket stays open until the readable loop has an assembly twin held
to it**, the same way the readable forward pass has one. The readable half
below is not superseded by that; it becomes the reference the assembly half
is measured against, and it should stay exactly as it is.

---

**The context mechanism exists and is tested** — `src/052`, checked by
`src/053`, 17 of 17.

The context is a concatenation of atoms and nothing else, and that is tested
directly rather than asserted: the whole context is rebuilt from its
enumerated atoms and must come out identical, so nothing unnamed can be hiding
in it.

Carrying, dropping, recalling, merging and editing are all operations the
machine asks for. Two properties matter more than the operations: a dropped
atom stays findable, because one that cannot be found again was lost rather
than dropped; and a merged-away atom's number is never reused, because anything
that referred to it would otherwise point at a different subject, which is worse
than pointing at nothing.

Running low is a condition the machine can see. Dropping for want of room is
treated as a fallback — announced, counted, and never allowed to take the atoms
carried on the chip, since those include the instruction and the explanation of
this mechanism itself. When everything left is undroppable, nothing is dropped
and the room left says so, rather than a machine believing it made room and
overrunning.

**And the uncomfortable property is tested rather than left implicit:** a
machine can edit its own prohibitions, because they are atoms in a mutable
list. Nothing prevents it, deliberately, and `docs/013` says why.

**The loop is closed** — `src/061`, checked by `src/062`, 13 of 13. Text
becomes tokens through the assembly tokenizer, tokens run through the
assembly conductor reusing the cache, a token is drawn by the assembly
sampler and joins the input. Four stoppers, each named in the answer: a
finish token (swallowed), a length limit, an interruption asked between
tokens — because a machine that cannot be interrupted mid-thought cannot be
told to stop doing something — and the room running out, which is reported
honestly rather than thought past. What to let go of then is the machine's
own decision through the context operations, never the loop's policy.

The cache reuse is proven both ways: a second thought costs only its new
tokens, and the reused cache's scores equal a fresh replay of the whole
conversation, bit for bit. Two seam refusals are tested: a byte the
vocabulary cannot say, and a tokenizer table that can say more than the
weights know — a broken image named plainly rather than an embedding read
past its edge.

**Closing the loop found a defect in the context mechanism.** Atoms joined
with a newline — exactly the "separator nobody named" that `docs/013`'s rule
forbids. The separator belonged to no atom, drifted the token accounting
from the real encoding, and broke the cache's prefix reuse at every atom
boundary. Atoms now join with nothing between; an atom that wants a boundary
owns the boundary in its content.

The disk half of the atom operations remains `304`'s: writing an atom out
and recalling it needs storage, and loading the boot set from the image
needs the builder (`502`). Hosted callers hand boot atoms in directly.

## Intended behavior

Text in, text out, continuously — with an honest answer to what happens when the
machine has thought for longer than it can hold.

## Suggested implementation steps

1. Close the loop: text becomes tokens, tokens run through the arithmetic, a
   token is drawn, it joins the input, repeat. Each pass reuses the cache of past
   keys and values rather than recomputing them, which is the difference between
   a usable machine and an unusable one.
2. Decide what stops it. A token that means "finished", a length limit, or an
   outside interruption — and the third matters most here, because a machine that
   cannot be interrupted mid-thought cannot be told to stop doing something.
3. **Build the context out of atoms rather than as one growing string.** The
   context is a concatenation of atomic artifacts and nothing else — each one a
   chunk grouped by topic, each one carried or dropped as a unit, each one
   nameable. Nothing is implicit and nothing sits outside the list, including the
   instruction the machine woke up with. `docs/013` is the whole mechanism.
4. Provide the operations as tool calls rather than as an automatic policy: carry
   forward, drop, write out, recall, merge, summarise, transform. What the machine
   is thinking with is a decision it makes, continuously, rather than a rule
   applied to it — which means running low is a condition it can see and act on
   instead of a wall it hits.
5. Index them, because an atom that is not resident is useless unless it can be
   found. Keyed on topic, searched by task.
6. Load the resident set at boot from a mutable file naming which atoms start
   present. In phase 1 there is no storage, so writing out and recalling cannot
   work yet — implement the residency and the index in memory, leave the disk half
   as a marked seam, and complete it in `304`.
7. Say out loud when something is dropped for want of room rather than by
   decision. That case is a fallback, and a fallback nobody was told about is a
   warning nobody received.

## Blocks

`106`, and all of phase 2 — the hands are useless without a loop to hold them.

## Blocked by

`103`, `104`, `105a`.

## Related documents

`docs/013-datapath-the-context.md` — atoms, the operations on them, and the
mutable file that says which are present at boot.
`docs/005-datapath-the-four-rungs.md` — cognition space as retrieval rather than
as a limit.
