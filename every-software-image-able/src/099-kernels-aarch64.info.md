# 099-kernels-aarch64 — info

The arithmetic in the second tongue. Issue 401, the half that ports almost mechanically -- and "almost" is where the work is.

The same innermost loops the machine already has, written again in a different processor's instructions. The test of a port is not that it looks right; it is that it produces the same numbers, bit for bit, as the first one did -- and the fixture that made that testable was built in 103 for exactly this moment.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `099-kernels-aarch64.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/099-kernels-aarch64.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.matrix_vector_plain` | described below |
| `M.matrix_vector_wide` | four at a time |
| `M.matrix_vector_fast` | four independent totals |
| `M.matrix_vector_quantised` | weights at four bits, unpacked as it goes |
| `M.rms_normalise` | described below |
| `M.add_into` | void add_into(float *destination, const float *addend, int count) |
| `M.rotate` | void rotate(float *vec, const float *turns, int heads, int head_width) |
| `M.attention_scores` | described below |
| `M.attention_mix` | described below |
| `M.build_exp(specification)` | float exp_one(float x) |
| `M.softmax` | void softmax(float *values, int count) |
| `M.swiglu` | void swiglu(float *gate, const float *up, int count) |
| `M.source(names)` | Everything written so far, in one assembler file. |
| `M.written` | what exists here, so a test can ask rather than be told |
| `M.missing_from(first_tongue_names)` | What the first architecture has that this one does not, WORKED OUT rather than remembered. |

### In more detail

**`M.matrix_vector_plain`**

void matrix_vector_plain(float *out, const float *matrix,
                         const float *input, int rows, int columns)

out x0, matrix x1, input x2, rows w3, columns w4.

**`M.matrix_vector_wide`**

The same answer, reading four numbers per step. The four products are
folded into ONE running total in the same order the plain version would,
rather than summed with the instruction that adds a whole vector together
-- which would be faster and would give a different answer.

The lane extraction is by index here rather than by rotating the register,
which is what the first tongue had to do. Same order, fewer instructions,
identical result.

**`M.matrix_vector_fast`**

The same operation as the two above and DELIBERATELY NOT THE SAME ANSWER.

The exact kernel folds each group of four products into ONE running total,
in order, so its answer is identical on every machine that has ever run
it. That ordering is what costs the speed: every addition waits for the
one before it, and the adder sits idle in between. This keeps FOUR totals,
one per lane, and never makes them wait for each other -- which is what
the vector hardware was built to do.

SO THIS IS A SECOND SPECIFICATION, not a faster implementation of the
first. It is never compared against the exact one. It is compared against
the first architecture's fast kernel, bit for bit, exactly as everything
else here is -- and that comparison is the whole reason `103` wrote the
second specification down rather than leaving it as "whatever is quick".

WHY IT WAS MISSING UNTIL NOW, which is worth more than the kernel. The
first tongue has eleven routines and this file had ten. Nothing said so:
the list of what is absent was a hand-kept table that had been emptied,
and the test that was meant to notice compared against a literal ten
rather than against what the first tongue actually has. Both agreed, and
both were wrong. The port that resulted had the routine that proves
correctness and not the one that provides the speed.

THE FINAL COMBINING IS SPECIFIED RATHER THAN INCIDENTAL, because a
different reduction order is a different answer again:
    lane0 += lane2, lane1 += lane3, then lane0 += lane1
and any remaining columns are folded in one at a time AFTERWARDS. All four
lanes are read out before any of them is written back, because the
accumulator's low lane and the register the total ends up in are the same
thirty-two bits.

**`M.matrix_vector_quantised`**

void matrix_vector_quantised(float *out, const unsigned char *matrix,
                             const float *input, int rows, int columns)

out x0, matrix x1, input x2, rows w3, columns w4.

A FOURTH SPECIFICATION, not a smaller version of the three above. The
weights it reads have already lost information and its answer is different
on purpose, so it is never compared against the exact product. It is held
to `123`, the readable specification, and to the other two architectures.

THE SCALE IS UNPACKED IN WHOLE-NUMBER ARITHMETIC, and this architecture is
the one that makes that look like a waste -- it has a half-to-single
conversion instruction sitting right there. It is not used. The first
architecture's equivalent is an optional extension a given chip may not
have, and the third's base instruction set has no half-precision at all,
so borrowing the instruction here would mean this architecture's answer
came from hardware the others must imitate. Three implementations agreeing
is the point; one of them taking a shortcut the others cannot is how they
stop.

The unpacking is the same three steps everywhere: shift the pattern up
thirteen places so its mantissa lands where a single precision mantissa
goes, add the difference between the two exponent biases, and -- only when
the exponent field was zero -- take one step into the normal range and
subtract it off again, which resolves a subnormal without counting leading
zeroes. A scale is never negative and never infinite, because the
quantiser takes a magnitude and saturates, so neither case is written.

TWO WEIGHTS PER PASS, and not for speed: choosing a half of a byte by
testing an index would put a branch in the innermost loop of the machine,
and taking the low half then the high half needs no test at all.

**`M.rms_normalise`**

void rms_normalise(float *out, const float *input, const float *weight,
                   int size, float epsilon)

out x0, input x1, weight x2, size w3, epsilon s0.

The value one is built in a register rather than loaded from anywhere: a
constant in memory needs a symbol reference, and a symbol reference in
this project is a note for a linker that nothing reads.

**`M.add_into`**

void add_into(float *destination, const float *addend, int count)

destination x0, addend x1, count w2.

What carries a token's meaning past a layer rather than through it.

**`M.rotate`**

void rotate(float *vec, const float *turns, int heads, int head_width)

vec x0, turns x1, heads w2, head_width w3.

Turns each pair of numbers in each head by the angle for this position,
reading the cosine and sine from the carried table rather than computing
them -- which is why this kernel is built from multiplication and addition
alone, and can therefore be required to match exactly.

**`M.attention_scores`**

void attention_scores(float *scores, const float *query, const float *keys,
                      int count, int width, int stride, float scale)

scores x0, query x1, keys x2, count w3, width w4, stride w5, scale s0.

How well this token's question matches each earlier token's answer. The
keys sit one position apart by the stride, because every layer and every
key head shares one array.

**`M.attention_mix`**

void attention_mix(float *out, const float *weights, const float *values,
                   int count, int width, int stride)

out x0, weights x1, values x2, count w3, width w4, stride w5.

What to carry forward: each earlier token's value, weighted by how well it
matched, accumulated in ascending order because that is the order the
specification names.

**`M.build_exp(specification)`**

float exp_one(float x)

The power arrives in s0 and the answer comes back in s0.

Built by a function rather than held as text, because its constants are
COMPUTED from the specification rather than transcribed. Writing the bit
pattern of a polynomial coefficient by hand is how the first architecture
once got one digit wrong in a way nothing downstream could have noticed.

The method, and it is the specification's rather than a choice made here:
turn raising e to a power into raising two to a power, split that into a
whole part and a fraction, adjust the number's exponent field by the whole
part -- which is exact and free -- and approximate the fraction with a
short polynomial.

Everything in it is multiplication and addition, which is what lets an
exponential be required to match another machine's exactly. Borrowing the
host language's exponential instead would have made every softmax in the
engine incomparable between architectures.

**`M.softmax`**

void softmax(float *values, int count)

values x0, count w1. Turns scores into weights adding to one, in place.

The largest is taken off first. That changes nothing about the answer and
stops the exponentials running away -- and because it is done, every
argument handed to the exponential is zero or negative, which is the range
it is most accurate over.

THIS ONE CALLS SOMETHING, which is what makes it different from every
kernel above. Anything that must survive a call goes in the registers the
convention obliges a callee to give back -- including the floating ones,
which are easy to forget because the integer ones are the famous half.

**`M.swiglu`**

void swiglu(float *gate, const float *up, int count)

gate x0, up x1, count w2.

The gate decides how much of each position passes, on a curve smooth
everywhere rather than a hard cutoff, and what passes is multiplied by the
other half.

The negation is written as a subtraction from zero rather than as a negate
instruction, to match the first architecture exactly: the two differ in
the sign of zero, and a specification that is exact everywhere else should
not be approximate there.

**`M.written`**

The exponential comes before the two that call it, because the assembler
resolves a call to something it has already seen and this file is emitted
in order.

**`M.missing_from(first_tongue_names)`**

What the first architecture has that this one does not, WORKED OUT rather
than remembered.

There was a hand-kept table here called `not_written_yet`, holding the
names still to be done. It was emptied when the port felt finished and
then said nothing ever again -- while the first tongue quietly had one
more routine than this file did. The test that was supposed to catch that
compared the count against a literal ten, so the stale table and the stale
test agreed with each other and the missing routine was the fast matrix
product: the one that provides all of the speed.

A port that quietly covers less than the first tongue is a port that looks
finished, which is what the emptied table said in its own comment while
being the reason it happened. So nothing is remembered now. The caller
hands over the first tongue's list and this returns the difference.

## Why it is a separate file from 043

That file holds the first tongue and is already long. A second architecture in the same file would mean every reader of either wading through both, and the emitter dispatches on architecture anyway. Adding a third is adding a third file.

## What ports mechanically and what does not

The plain arithmetic is a translation: multiply, add, compare, branch, all present on both. The registers are more numerous here, which makes some of the shuffling the first tongue needed unnecessary -- and removing it would change the answer, so it is kept. Every accumulation is single precision in ascending index order, because that is the specification and not merely what fell out.

## The order of addition is the specification

This architecture has instructions that would sum four numbers in one step, and they are not used, for the same reason the first tongue's wide kernel keeps one running accumulator: floating-point addition is not associative, and a faster answer that differs in the last bit is a different specification rather than a better implementation of this one.

## Worth knowing

The calling convention here puts the first arguments in x0, x1, x2, then w3, w4, and floating arguments in s0 -- which is what the bundled patterns say (083), so everything the machine writes later agrees with this.

## Where it sits

**Belongs to** `401`.

**Checked by** `100-test-kernels-aarch64`, `110-test-forward-aarch64`, `119-test-sampler-aarch64`, `125-test-quantised-kernels`.

