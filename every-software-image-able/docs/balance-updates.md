
## 2026-08-21 — how long the text on the card may be

**What changed.** The ceiling on what the machine wakes up holding goes from **8000
bytes to 9000**. It is checked by the payload test and it is the only hard limit on
that text.

**Why the old number was tight, and why that reason is gone.** It was set when the
instruction was believed to be carved *out of* the manageable context budget, so
every byte of it was a byte the machine would never get to manage — a machine that
grew its own instruction shrank its working room in the one region nobody measured.
That turned out to be wrong on the same day this was raised: what the machine wakes
holding sits **beside** the context rather than inside it, so a longer text costs
memory rather than working room.

**What the ceiling still protects is attention.** A machine reading its own purpose
alongside real work should be able to hold both comfortably. Nine thousand bytes is
about two thousand words — a page and a half — which is a long system prompt and not
an unreasonable one.

**Why raise it rather than keep cutting.** The text gained several things decided
after the number was set: what to do when stuck, whose the disks and networks are,
build what suits this machine, nothing will ever ask you anything, and arming the
board's reset timer around a probe that might not answer. Every one of those
displaced prose from somewhere else, and past a point the displacing stops removing
fat and starts removing meaning. This is that point.

**What would make this wrong is doing it again.** A ceiling that moves whenever
something new is worth saying is not a ceiling. The value of the number is that a
new sentence has to earn its place by pushing an old one out, and that pressure only
exists while the number holds.

**What to watch.** Whether the text is still readable start to finish by something
that has never seen this project — which is what it is for — and whether anything in
it has become a sentence nobody would miss.

## 2026-08-21 — the nibble, and how hard a bad round is punished

**What changed.** A compaction round that ends *larger* than it began no longer
goes straight to a full random deletion. It bites **five percentage points** off
the buffer, rephrases what it damaged, and runs another round. Only a round that
ends larger *and* at or above the 80% trigger gets bitten all the way down to the
60% target.

**Why five, and why it is a percentage of the whole rather than a fraction of the
excess.** A fraction of the excess would take almost nothing off a round that grew
by one point, which is the ordinary case and the one that most needs to make
progress. Five points is enough that a machine which grows slightly still descends —
grow by one, bite five, net four down per cycle, so a buffer at 80% reaches 60% in
five cycles of a bad compaction rather than in one catastrophe.

**Why the trigger is the line between the two.** The room above the trigger is the
workspace, and the workspace is where the sweep does its thinking. A buffer that has
grown but is still below the trigger has room left to reason with, so it can afford
to lose a little and try again. A buffer that has grown *past* the trigger is eating
the room it needs in order to decide anything, and there is nothing left to be
gentle with.

**Why it terminates either way.** Each cycle either descends or climbs toward the
trigger, and reaching the trigger hands the buffer to the form that always reaches
the target. A round that grows by more than five points repeatedly does not loop
forever, it escalates.

**What to watch when tuning.** How often a compaction escalates to the full bite
(five is too small, or rounds are growing badly), and how many cycles a typical bad
compaction takes (five is too small if it is many, too large if a single cycle
routinely overshoots well below the target).

**Decided by** gabrilend, this conversation: *"if we're larger than the round
started, but still below 80%, then we only bite away 5% of the tokens, do a rephrase
pass, then continue with another round. That way it's a little less catastrophic."*

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
