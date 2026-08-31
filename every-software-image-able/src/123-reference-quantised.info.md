# 123-reference-quantised — info

The readable specification of the small stored form: turning plain numbers into blocks, turning blocks back into numbers, and the matrix product that reads them without ever unpacking a whole tensor. Issue 108.

Weights stored at four bits each instead of thirty-two, so a model that needed four gigabytes needs about six hundred megabytes. The cost is that every use of a weight has to undo the packing first, inside the innermost loop of the machine.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `123-reference-quantised.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/123-reference-quantised.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.to_f16_bits(value) / M.from_f16_bits(bits)` | A 16-bit float, written out rather than borrowed, for the same reason the exponential is: a conversion that differs between machines makes every we... |
| `M.round_to_even(value)` | To the nearest whole number, with a value exactly halfway going to the even one. |
| `M.quantise_block(values, at, block)` | One block of plain numbers into a scale and a run of four-bit weights. |
| `M.pack_block(scale_bits, weights, layout)` | A scale and its weights into the exact bytes the format describes: the scale low byte first, then two weights per byte with the earlier weight in t... |
| `M.quantise(values, count, format)` | A whole run of plain numbers into the bytes the format stores, as a string. |
| `M.read_weight(bytes, at, index, format)` | One weight out of a packed run, as the number it stands for. |
| `M.matrix_vector_quantised(out, matrix_bytes, input, rows, columns, format)` | The same shape of operation as the plain product, reading a packed matrix. |

### In more detail

**`M.to_f16_bits(value) / M.from_f16_bits(bits)`**

A 16-bit float, written out rather than borrowed, for the same reason the
exponential is: a conversion that differs between machines makes every
weight downstream of it incomparable. One sign bit, five exponent bits,
ten mantissa bits, and a bias of fifteen.

Rounding is to nearest with ties going to even, which is what every
machine here does by default and what the assembly will have to match.

**`M.round_to_even(value)`**

To the nearest whole number, with a value exactly halfway going to the
even one. Named and separate because it is the rule the hardware uses and
the obvious alternatives -- always up, or away from zero -- differ from it
on exactly the values that occur most often when quantising, which are the
halves.

**`M.quantise_block(values, at, block)`**

One block of plain numbers into a scale and a run of four-bit weights.

Returns the scale's 16-bit pattern and an array of `block` numbers, each 0
to 15. Nothing here is packed into bytes yet -- that is layout, and it
happens in `pack_block` below, so that the arithmetic and the byte order
are separately checkable.

**`M.pack_block(scale_bits, weights, layout)`**

A scale and its weights into the exact bytes the format describes: the
scale low byte first, then two weights per byte with the earlier weight in
the low four bits.

**`M.read_weight(bytes, at, index, format)`**

One weight out of a packed run, as the number it stands for.

`at` is where the run begins in the byte string, counted from zero;
`index` is which weight, also from zero. Written as a lookup rather than
as part of a loop so that the assembly has something exact to reproduce
for a single weight before it has to reproduce a whole product.

**`M.matrix_vector_quantised(out, matrix_bytes, input, rows, columns, format)`**

The same shape of operation as the plain product, reading a packed matrix.

THE ORDER OF ADDITION IS THE SPECIFICATION, exactly as everywhere else:
one running total per row, single precision, ascending index order.

WHAT IS DIFFERENT, and it is the whole of the difference: each weight
arrives as a small whole number and a scale shared with thirty-one others.
The value multiplied into the total is `(weight - 8) * scale`, computed in
single precision, and THEN multiplied by the input. Folding the scale into
the running total once per block instead would be fewer multiplications
and a different answer -- the products would each be rounded before the
scale rather than after it.

That is not a small difference and it is not an optimisation left on the
table. It is a different specification, and if a faster arrangement is
ever wanted it gets its own name and its own recorded answers.

## This is a separate specification, not a smaller version of the plain one

Quantising loses information: the answer is different, and it is meant to be. So this is never compared against the exact product. It is written down here, its answers are recorded, and the assembly versions are held to THESE -- exactly as the four-totals product is held to its own rather than to the exact one it is faster than.

## Where the arithmetic is the specification

and there are three places:

## Worth knowing

  ONE. The scale is the largest magnitude in the block divided by SEVEN,   and the reason is the whole difference between a bound and a hope.

  Four bits with a zero point of eight run from minus eight to plus seven   -- sixteen levels, but not symmetric. Dividing by eight puts the most   extreme weight at index sixteen if it happens to be positive, which does   not exist, so it clips. Clipping is not a rounding error: it is   unbounded by the step size, and it happens to exactly the largest weight   in the block, which is the one that matters most.

  Dividing by seven leaves index zero unused and guarantees that nothing   ever clips: every weight lands between one and fifteen, and the error is   never worse than half a step. The cost is one level of sixteen, which   makes the step one seventh of the largest magnitude instead of one   eighth -- and one seventh of a half beats one eighth of one and a half.

  The usual arrangement elsewhere divides by minus eight, which puts the   extreme at index zero and clips only in the opposite direction. That is   a real choice and it is not this one: it trades a guarantee for slightly   finer steps, and a guarantee is worth more here, because this project   holds three implementations to identical answers and an unbounded case   is where three implementations stop agreeing.

  TWO. The scale is rounded to a 16-bit float BEFORE any weight is   quantised against it. The stored scale is what the machine will read, so   quantising against the unrounded one produces weights chosen for a scale   that no longer exists.

  THREE. Every accumulation in the product is single precision, in   ascending index order, exactly as in the plain product. The dequantising   changes what is multiplied, not how the sum is built.

## Where it sits

**Belongs to** `108`.

**Checked by** `124-test-quantised`, `125-test-quantised-kernels`.

