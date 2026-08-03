
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
