# 105 — The thinking loop, and its limits

## Current behavior

One token can be produced. Nothing produces a second one, and nothing decides
when to stop.

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
