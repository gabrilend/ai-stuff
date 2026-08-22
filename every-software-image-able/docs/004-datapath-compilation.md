# 004 — Datapath: Compilation

The chain the seed page gives as the machine's floor: **text to source to a
runnable program**, where both arrows are allowed to improve rather than being
fixed machinery.

## Why it cannot be a fixed compiler

The first translation happens with nothing underneath it. No compiler exists yet,
the processor is one nobody surveyed in advance, and the output has to be
assembly because there is no language available that needs less. The model is the
compiler until it has written one, and what it writes is shaped by a machine it
only just finished measuring (`003`).

After that the chain keeps improving, but the reason it started improvable is
that it started with nothing to be fixed *to*.

## This is not an optimiser, and that was the mistake

**Rewritten 2026-08-21.** What was here described a machine that measures itself,
raises a demand naming which axis is short, iterates over approaches to that one
constraint until the ideas run out, and keeps every approach it ever tried so it can
select among them by situation. It was careful, it was consistent, and it was
apparatus for a kind of machine this is not.

> the system is supposed to be improving itself in whatever order it pleases. So, we
> shouldn't be strict about guiding it. It should just wander around and do whatever.
> Like we very explicitly are not trying to optimize here, we're trying to be
> organic.

So there is no metric, no demand record, no objective, and nothing that decides what
the machine should be working on. It works on whatever it is working on.

**What is wanted instead is organisation, which is a different thing.** A machine
that wanders and forgets what it has built wanders in circles. A machine that
wanders and can find what it has built goes somewhere.

## What is encouraged, and it is three habits

**Build indexes.** Of what exists, of what it does, of where it is. Not one index
imposed by this document — whatever indexes turn out to be worth having, built by
the machine, for the way that machine ended up organised.

**Look at what you already built before building something.** Most problems a
machine meets are ones it has met, and the difference between a machine that knows
that and one that does not is whether it can find the earlier answer. This is rung
one in `005`, and it is the rung that matters most because it is the one the other
three exist to avoid.

**Reuse it when you find it.** Take the thing that already works rather than writing
a second thing that does the same job. That is what keeps the machine integrated with
itself rather than becoming a pile of unrelated programs that happen to share a
drive.

## What that costs, and why it is acceptable

**It goes monolithic.** Everything using the same pieces means the pieces have many
users, and a machine that reuses aggressively ends up with a small number of things
that everything leans on. That is a real cost and it is accepted rather than
designed around.

**And things break.** Change something shared and one of the things leaning on it
stops working. The design used to require this be prevented — know every dependent
before changing anything, with an index recording what each one relies on. It is not
required any more.

> If the shared functionality changes, it'll probably break one or the other end,
> and that's fine, it'll fix it when it tries to run the program again, sees that
> it's broken, and thinks "oh huh I should fix that".

**Which is a real position and worth stating as one.** Breakage is discovered by
running rather than prevented by bookkeeping. A machine with nobody waiting on it can
afford to find out the expensive way, because the cost of a broken program is that
the machine notices and fixes it, and the cost of preventing every breakage is an
index that has to be right about everything forever.

The reverse index in `005` is still a good idea and it is now an *idea* — something a
machine may build if it finds itself breaking things it did not expect to. Not a
precondition for changing anything.

## Writing things down

**Not a rule, and not a mechanism.** An earlier draft made this a duty — every
choice explained, with a chart, showing every alternative at its measured position,
because a chart with one bar carries no clarity. That was written when this document
described an optimiser, and it went out with the optimiser.

What is left is a suggestion and it is short. **Write down your thoughts sometimes.
Explain what things do.** How much, how often, in what form, and whether anything
gets drawn at all, is the machine's business.

There is a good definition of clarity underneath it, kept because it is worth having
and not because anything requires it:

> distance from alternatives when more accurate to the truth than alternatives

Two parts, and the second is what makes it a real quantity rather than a feeling.
Distance alone is not clarity — being far from every alternative while wrong is
isolation. Clarity is margin *in the correct direction*. Which gives a picture a rule
if a machine wants one: show the field, not the winner, because the margin is the
thing worth seeing and it is invisible in a chart with one bar.

The machine has nobody to explain itself to for a long time, so anything it writes it
writes for its later self. That is a reason to bother, not an obligation to.

## When there is nothing to vary

Working out what would have had to be different searches over the values of code
that exists. If the machine did not reach the state it wanted because of a case
nobody handled — a branch that was never written — no amount of searching finds it,
because there is no parameter to move.

That is not a silent failure. **It is how the machine notices it needs to build
something.** Having nothing to vary is precisely the discovery that the software
does not exist yet, which hands the problem to rung three (`005`) and is, in the
seed page's terms, the whole point of the project.

## Open questions

- ~~How many different ways before moving on?~~ **Dissolved 2026-08-21.** It was a
  question about an optimiser, and there is no optimiser. The machine tries things
  for as long as it feels like trying them.
- ~~What draws the picture before there is a display?~~ **Answered.** The
  firmware hands over a linear framebuffer — an address, a geometry and a pixel
  format — so writing bytes changes pixels with no driver involved. The machine
  can draw from its first instant, and a chart showing what a choice was made
  against is available immediately rather than in a late phase (`202`).
- **Does a second way of doing something ever get deleted?** Rung four condenses
  duplication, and two ways of doing one job look exactly like duplication from the
  outside. Sometimes they are, and sometimes one of them is better on this hardware
  and the other is better on the hardware the machine has not met yet.
- **What makes a machine look at what it already built?** The habit is encouraged
  and nothing enforces it. A machine that forgets to look writes the same thing
  twice, notices later or never, and the only cost is room — which is exactly the
  cost rung four exists to reclaim, so the failure is self-limiting rather than
  compounding.
