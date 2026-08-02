# 009 — Ask, Do Not Schedule

State what is wanted and what it costs to get it wrong. Do not state the method,
the order, or the hours.

> Let's delegate it to the computer — dear computer, try and solve this problem,
> do so as you please. That sounds better to me than "you must show up at 9 and
> leave by 5."

## The shape

Whoever holds the live information should choose the method. A procedure written
in advance is written by somebody who cannot see the conditions at the moment it
runs, so every step of it is a guess about a situation that has not happened yet.
The further ahead it is written, the worse the guess.

So the specification carries two things and no third:

- **what is wanted**, in terms of the result rather than the route
- **what a wrong answer costs**, so the executor can size its own caution

Everything else is the executor's business.

## Where it turned up in this project

Three questions that looked like they needed a designed answer, and did not:

- How many different approaches to try before moving on to a different problem.
  A number written here would have read as authoritative because it was in a
  document, while being invented by somebody who had never watched the machine
  grind.
- What mediates between altering a piece of software and merging it into another.
  These pull against each other permanently, and the balance depends on how dense
  the machine has already become — which is not knowable from outside it.
- Whether the machine uses the backward walk at all when something saturates. It
  is one way to find out what should have happened instead. A better one may
  exist on hardware nobody here has seen.

And one that was never in question: the instruction set the machine builds for
itself is chosen against the processor it woke up on, because the operations
worth having depend on what that particular silicon does cheaply.

## Where it turned up before

The pattern is old and keeps winning.

- A compiler is told what a program should compute, not which registers to use.
  Register allocation used to be done by hand; handing it over produced better
  code than hand-doing it, because the compiler can see the whole function at
  once and a person cannot hold it.
- A query is a statement of which rows are wanted, not a plan for finding them.
  The planner beats the hand-written loop because it reads the current statistics
  and the loop was written last year.
- A build tool is given dependencies, not an order. It derives an order, and a
  better one than the person would have typed, and a different one on a machine
  with more cores.
- A network protocol is told to deliver bytes in order. It is not given a
  retransmission schedule, because the right moment to retransmit depends on
  conditions that change by the second.

In every case the same thing is given up — the comfort of knowing exactly what
will happen — and the same thing is bought: the decision is made by whoever can
see.

## Where it fails, and this boundary is the important part

**Delegate the method wherever mistakes are recoverable. Specify the procedure
where they are not.**

This project has exactly one place where the answer is a procedure rather than a
delegation, and it is the exploration of hardware without a description
(`docs/003a`). Reads before writes. One change at a time. A predicted outcome
stated beforehand. Never into the registers that control voltage, clocking,
thermal limits, or anything stored in non-volatile memory. The intent written
down before the attempt.

None of that is delegated, because a destroyed chip cannot be re-decided. Every
other mistake in this design is answered by writing more software; that one is
answered by buying more hardware.

So the test is not "is this important" — it is **"can the executor find out it
was wrong, and still be there to act on that?"** Where the answer is yes, ask and
step back. Where it is no, write the procedure and mean it.
