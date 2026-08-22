
## 2026-08-08 — the watermarks the context compacts between

**What changed.** Three numbers, where before there was a wall and no numbers.
The machine sweeps its own resident atoms when they reach **80%** of the
manageable budget, and compacts down to **60%** — or as far as **40%** when the
candidates are good enough to be worth the rewriting. The mechanism is `docs/013`;
these are only the knobs.

**Manageable budget** means the total minus the atoms carried on the chip. The
system atoms are outside the arithmetic, which is what makes 40% always reachable:
every atom inside the budget can be dropped by definition.

**Why the trigger is below the wall, and why it must not be raised.** Deciding
what is least relevant is a judgement and writing a summary is generation — both
are forward passes, and both need somewhere to run. The region above 80% is the
workspace they run in. At 100% there is no room to think about how to make room,
so **moving this number toward 95% to keep more context resident converts a
graceful mechanism into a deadlock.** It looks like reclaimable waste and is not.

**Why there are two targets and not one.** Not sweep frequency — the replay cost
is set by the position of the earliest atom touched, so going deeper is free or
cheaper. The 60-to-40 range is a knob on **how much rewriting is worth doing**.
Reaching 40% by dropping things costs almost nothing; reaching it by summarising
and splitting costs a generation pass per atom. Lower the floor when the machine
is finding good candidates, raise it when it is paying to rewrite things it could
have discarded.

**What to watch when tuning.** How often a sweep ends still above the wall (the
trigger is too high, or the instruction has grown), and what fraction of a sweep's
reclaimed room came from rewriting rather than dropping (the floor is too low).

**Decided by** gabrilend, this conversation: *"we should do this until we're at
least down to 60%, but if there are strong enough candidates we can go as low as
40%."*

## 2026-08-03 — the matrix product gets a second specification

**What changed.** A third matrix-vector kernel, keeping four running totals
instead of one, is now the one meant to run. The exact kernel stays.

**Why.** Keeping one total forces every addition to wait for the one before
it. Measured on this processor over a 32-by-176 shape:

| | per second | against one at a time |
|---|---|---|
| one at a time | 175,215 | — |
| four at a time, one total | 202,123 | 1.15x |
| four at a time, four totals | 904,509 | **5.16x** |

So the exact ordering was costing **4.48x**. That is more than the fourfold
the vector width alone would explain, because breaking the dependency chain
lets the processor overlap work it was previously serialising.

**What it costs.** Two machines of different architectures will now produce
slightly different numbers, so a thought from one cannot be reproduced on the
other. One machine remains exactly reproducible — same image, same carried
numbers, same input, same words, every time. Determinism was never what was
traded; portability of the exact bits was.

**What is kept, and why.** The exact kernel remains and is what proves a port
to a new architecture is honest: its answers must match the first
architecture's bit for bit, which is a claim no tolerance can make. Run it
once on a new machine, then run the fast one forever after.

**Decided by** gabrilend, this conversation: *"Let them diverge. Let's focus
on speed."*
