# 043, 044 — the arithmetic in assembly, and its exact comparison — info

The innermost loops of the model's arithmetic, written in the processor's own
instructions and compared against the reference **bit for bit**. Issue `103` is
the blueprint.

## Running it

```
luajit src/044-test-kernels.lua
```

Only the architecture the host is standing on can be tested here. The other two
are checked by running them on emulated machines, which is slower and is the
reason this exists.

## Why these two kernels and no others

`matrix_vector` and `rms_normalise` are built from multiplication, addition and
square root alone. All three are exactly specified by the floating-point
standard, so an assembly version can be **required** to match rather than
approximately match.

Everything else in a forward pass passes through an exponential, a sine or a
cosine at some point. Those differ between implementations, so anything
downstream of them is checked by the whole-pass fixture (`037`) with a stated
tolerance instead. That line is drawn deliberately and is stated in both tests.

## Why it can be tested without booting anything

A kernel that touches only the memory handed to it needs no operating system.
The same bytes that will run on a bare machine load into a running process and
are called directly, turning a several-minute boot into a fraction of a second.
It is the only part of the engine that gets this, and the part that most needs
it, since it will be written three times.

## The thing not to change

**The wide version keeps one running accumulator.** It reads four numbers at a
time and multiplies four at a time, then folds each product into a single total
in the same order the plain version would.

Four independent partial totals summed at the end would be faster and would
give a *different answer* — floating-point addition is not associative. That
version is legitimate and would need its own fixture from a reference doing the
same thing. It would not be comparable to this one.

## Precision is part of the specification

Every accumulation is single precision, in ascending index order. The reference
implements that literally by rounding through a float after each step, which is
slower and is the point. Without that statement the two implementations could
only be compared within a tolerance, and a tolerance turns every disagreement
into a judgement call.

## No symbol references, again

The value one is built in a register rather than loaded from memory, because a
constant in memory needs a symbol reference and a symbol reference here is a
note for a linker that nothing reads (`notes/023`). The same rule that shaped
the bare-metal payloads shapes these.

## Two host properties that bit

A built library must live on the executable RAM tier, not the artifact tier —
the latter is mounted so nothing on it may run, which is correct and which
caught a build placed there.

And hand-written assembly needs an explicit note saying it does not require an
executable stack. Without it a linker assumes the worst and current loaders
refuse the result. The note is meaningless on bare metal and required here.

## Result on 2026-08-02

26 of 26, bit-exact, on x86-64. Nine matrix shapes including ones whose column
counts are not multiples of four, so the wide version's remainder path is
exercised rather than assumed; five normalisation sizes; and three edge cases —
a row of no columns totalling zero, no rows writing nothing at all, and a
vector of zeros normalising to something finite.
