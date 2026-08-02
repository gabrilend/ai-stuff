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
3. **Decide what happens when the context fills.** This is the ticket's real
   subject. A machine that runs for months will exceed what it can hold within
   the first day. The options are genuinely different machines: drop the oldest
   and lose the beginning; summarise the older part and lose fidelity while
   keeping shape; or write the older part out and retrieve pieces of it when
   relevant.
4. The third option is the one the design already leans toward. `docs/005` calls
   this cognition space — what the machine can think of that is relevant to what
   it is doing right now — and names it a retrieval problem rather than a memory
   limit. But retrieval needs storage, and storage does not exist during phase 1,
   so this ticket should implement the simple answer and leave a marked seam for
   the better one.
5. Whatever is chosen, say so out loud when it happens. Silently dropping the
   start of a thought is a fallback, and a fallback that is not announced is a
   warning nobody received.

## Blocks

`106`, and all of phase 2 — the hands are useless without a loop to hold them.

## Blocked by

`103`, `104`.

## Related documents

`docs/005-datapath-the-four-rungs.md` — cognition space as retrieval rather than
as a limit.
