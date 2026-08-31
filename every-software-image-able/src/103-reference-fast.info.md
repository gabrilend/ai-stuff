# 103-reference-fast — info

The readable twin of the fast matrix product. A second specification, not a faster version of the first.

The exact kernel adds each product into one running total, in order, so its answer is the same on every machine that has ever run it. Keeping that order is what costs the speed -- each addition waits for the one before it, and the processor's adder idles in between. This one keeps four totals and lets four additions be in flight at once.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `103-reference-fast.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/103-reference-fast.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.LANES` | how many totals are kept at once |
| `M.matrix_vector_fast(out, matrix, input, rows, columns)` | One row at a time, four totals at a time. |
| `M.differs_from_exact(fast, exact, count)` | How far apart the two specifications land, so the price of the speed is a measured number rather than an assurance. |

### In more detail

**`M.LANES`**

Four, because that is how many single-precision numbers fit in one vector
register on the architectures this project targets. It is a property of
the silicon rather than a tuning choice, which is why it is named here
rather than being a number somebody could raise.

**`M.matrix_vector_fast(out, matrix, input, rows, columns)`**

One row at a time, four totals at a time.

The combining order is part of the specification. It follows what the
vector instructions naturally do rather than what reads most tidily:

  lane0 += lane2 and lane1 += lane3, together
  then lane0 += lane1
  then anything that did not fit in a group of four, one at a time

Written the other way round -- remainder first, or a left-to-right sum of
the four -- gives a different answer, and a reader who assumes the tidy
order will be looking at a disagreement that is really a misreading.

**`M.differs_from_exact(fast, exact, count)`**

How far apart the two specifications land, so the price of the speed is a
measured number rather than an assurance.

Reported as the largest relative difference rather than the largest
absolute one: the values in a forward pass span several orders of
magnitude, and an absolute difference says more about the size of the
numbers than about the arithmetic.

## The answer differs, and that is the trade

Floating-point addition is not associative: adding the same numbers in a different order gives a different result in the last bits. Neither is wrong. They are answers to slightly different questions, and this file writes down which question this one answers so that an assembly version can be held to it exactly.

## What is given up

said plainly. Two machines of different architectures running this will produce slightly different numbers, so a thought that came out of one cannot be reproduced on the other. That was a deliberate decision: the same machine remains perfectly reproducible, and the exact kernel remains available for proving that a port is honest.

## What is kept

On one machine, this is as deterministic as the exact one -- same image, same carried numbers, same input, same output, every time. Determinism was never the thing being given up; portability of the exact bits was.

## Where it sits

**Checked by** `104-test-fast-kernel`.

