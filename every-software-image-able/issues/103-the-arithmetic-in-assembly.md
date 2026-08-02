# 103 — The arithmetic, in assembly

## Current behavior

**The fixture exists, and it is the half that makes the other half possible.**
A forward pass written plainly on the host (`src/035`) — embedding lookup,
normalisation, the projections, rotary position encoding, attention over the
cached keys and values with fewer key heads than query heads, the gated
feedforward, and the projection to a score per token. It runs, and what it
produces is recorded in `assets/036-fixture.lua`.

`src/037` checks that record and five things that must be true regardless of
whether the record is right — because a fixture only catches change, and one
generated from a broken implementation would preserve the breakage forever.
The sharpest of them: adding a token to the prompt must not change any earlier
answer. Seven of seven on 2026-08-02.

Which tensors a model contains is in `src/034`, so nothing works out names for
itself.

**The first two kernels exist in assembly and match exactly.** `src/043`
generates them, `src/044` compares them against the reference bit for bit —
26 of 26 on x86-64, including a four-at-a-time version that keeps one running
accumulator so its answer is identical rather than merely close.

This forced a decision the fixture had left implicit. The reference summed in
double because that language's numbers are doubles; assembly sums in single;
they can never agree. **Precision is now part of the specification** — every
accumulation single precision, ascending index order — and the reference
implements it literally. That is what makes an exact comparison possible, and
an exact comparison is worth far more than a tolerance, which turns every
future disagreement into a judgement call.

The line where exactness stops is drawn explicitly: multiplication, addition
and square root agree everywhere, so kernels built from them are compared by
bits. Exponential, sine and cosine do not, so anything downstream of them is
checked by the whole-pass fixture with a stated tolerance.

Kernels touch only the memory handed to them, so they need no symbol
references and the same instructions run hosted — where a test takes a fraction
of a second — and on bare metal, where it would take minutes.

**The working memory question is answered too** — the part of this ticket that
would have been `103c`. `src/045` itemises what a machine needs to think:
weights at a chosen storage format, the cache that grows with the length of a
thought, the vectors one step needs while it happens, and the engine. `src/046`
prints that across several model shapes and board sizes and checks the
arithmetic against itself, 6 of 6.

It reports **which term runs out first**, because the remedy differs. Weights
dominating means only a smaller model will do. Cache dominating means a shorter
thought is also an answer — and a machine that cannot hold its full context can
still think in shorter breaths, which beats refusing to start. The arrangement
of a model decides which wall it meets: at the same context length, one
reference shape is weight-bound and another is cache-bound.

This is the whitepaper's top risk turned from an argument into arithmetic. It
does not say whether a model that fits is also good enough to write assembly
unaided. Nothing arithmetic can.

**Every function in a forward pass now agrees exactly.** There is no tolerance
anywhere, and getting there took removing two obstacles rather than accepting
them.

Sine and cosine left the engine entirely: the turns that carry position depend
only on the position and the pair, never on what the model is thinking, so they
are computed once and carried with the weights (`034`). Nothing to approximate
and nothing to disagree about.

The exponential was specified rather than borrowed (`047`) — the range
reduction, the polynomial, the order of operations, the clamps. Two candidate
polynomials were kept and measured across the ranges a model actually produces;
the longer wins tenfold where softmax spends nearly all its arguments (`048`).

So the assembly now covers the matrix-vector product, normalisation, the
exponential, softmax and the gate, all bit-exact — 37 of 37 (`044`).

**A whole forward pass now runs on the assembly arithmetic and matches the
recorded answer bit for bit** (`src/049`, `src/050`, 4 of 4). Nine kernels
cover everything a step does; the order of operations is still decided in a
readable language, which is deliberate — what remains has no floating point in
it, and is the easy half.

Composing them found a defect the kernel tests could not: a disagreement of
four parts in a thousand million, at the second token only. It was in the
**reference**. Accumulating a weighted value the obvious way rounds once where
a machine rounds twice, and where a rounding happens is part of the answer.
Two earlier fixes were plausible and wrong; the whole episode is in
`notes/023`.

The lesson is about fixtures generally: a recorded answer catches a change in
arithmetic, and cannot catch a specification too imprecise to implement twice.
Only a second implementation catches that.

**Still to write:** the conducting in assembly, and both other architectures.

## Intended behavior

The operations a transformer needs, written in assembly for the first target
architecture, running with no library beneath them: matrix by vector, attention
over a cache of past keys and values, the normalisations, the activation, and
the final projection to a score per token in the vocabulary.

No compiler exists to build these with and no runtime exists to call into. There
is the instruction set, the registers, and the memory found in `102`.

## Suggested implementation steps

1. Write the plain version first, without vector instructions, and get it
   correct. Correctness here means: given the same input as a reference
   implementation on a development machine, the numbers agree within the tolerance
   the precision allows. A fast wrong answer is worthless and hard to notice.
2. Build the reference comparison as a fixture, not as a one-off. Every later
   optimisation is checked against it, and every architecture in phase 4 is
   checked against it too.
3. Then use the vector instructions. This is where nearly all the speed is, and it
   is worth being exact about why: the operation is multiply-and-accumulate over
   long runs of contiguous numbers, which is what those instructions exist for.
   Expect the difference to be large enough to change which models are viable.
4. Lay out the working memory deliberately. The cache of past keys and values
   grows with the conversation and is the largest thing after the weights; where
   it sits and how it is indexed decides both speed and how long a thought can
   get.
5. Keep the shapes as data rather than as constants baked into the code. The
   header from `101` describes them, and reading them means a different model can
   be packed without rewriting the arithmetic.
6. Measure as you go, in tokens per second, on real hardware. It is the number
   the whole project's feasibility rests on.

## Notes on effort

This ticket is a candidate for sub-issues — `103a` for the plain version and the
reference fixture, `103b` for the vectorised version, `103c` for the working
memory layout — and should be split if it stops fitting in one head.

## Blocks

`104`, `105`, `106`, and all of phase 4.

## Blocked by

`101`, `102`.

## Related documents

`docs/010-datapath-the-mind.md` — why this is written by people rather than by
the machine, and why it is written more than once.
