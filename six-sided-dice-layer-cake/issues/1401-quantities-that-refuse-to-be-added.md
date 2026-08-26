# 1401 — Quantities that refuse to be added

Produces `src/091-units.lua`.

## Current behavior

**Done.** `src/091-units.lua` exists. Ten dimension slots, thirty-eight units,
fourteen prefixes, a recursive-descent parser for compound unit strings, and
arithmetic through metamethods so that a derivation reads as arithmetic.

Addition, subtraction and comparison refuse across dimensions and say which two
they were given. When one side is dimensionless the message is a longer one that
teaches the rule, because a bare number where a quantity belongs is the mistake
every author makes on their first day.

**One thing turned out to matter that the ticket did not anticipate.** A
quantity is recognised by a marker field rather than by the identity of its
metatable, because two modules each reaching for this file with `dofile` load it
twice, and a quantity built by one copy was being rejected by the other with a
message about not being a quantity. Correct, baffling, and fixed by not asking
the question that way.

Temperature is still unchecked in the way the ticket predicted: kelvin and a
kelvin difference have the same dimension and the engine cannot tell them apart.
The convention of naming differences `dT_` is a convention and the blueprint
says so rather than implying a check.

## Intended behavior

**A quantity type that carries a dimension, and arithmetic that refuses when the
dimensions disagree.**

### The dimension vector

Ten slots. The seven from the international system — length, mass, time, current,
temperature, amount, luminous intensity — and three more this project needs:

**bit**, so that a bandwidth in bits per second and a clock frequency in hertz are
different types even though both are one over seconds. Adding them is a real
mistake somebody will make in a bandwidth blueprint, and without this slot nothing
catches it.

**tok**, so that tokens per second is not a frequency either.

**flop**, so that operations per second is not one either.

Three pseudo-dimensions to separate three quantities that are all reciprocal
seconds and none of which is interchangeable with another. **That is the whole
justification and it should be in the file's comments**, because a reader will
otherwise assume the seven were enough.

### What the module offers

Parsing a unit string into a dimension and a scale — `mm`, `W/(m*K)`, `kg/m^3`,
`1`, and the prefixes from pico to tera. Constructing a quantity from a number and
a unit. Adding and subtracting, which refuse across dimensions. Multiplying and
dividing, which combine them. Raising to an integer power. Comparing, which
refuses across dimensions. Formatting for a human, which chooses a sensible prefix.

Everything is stored internally in base units and converted only at the edges, so
that no derivation ever depends on what unit a symbol was declared in.

### The two things that must be got right

**Temperature.** Kelvin is a dimension and a temperature difference is the same
dimension, but adding two absolute temperatures is meaningless while adding a
difference to an absolute is not. The engine cannot tell them apart from the
dimension alone. `002` sidesteps this by using kelvin throughout and naming
differences with a `dT_` prefix — a convention rather than a check. **The blueprint
should say plainly that this is unchecked**, because an unchecked convention
presented as a checked one is worse than nothing.

**Refusal, not coercion.** An operation on mismatched dimensions raises, with a
message naming both. It must never quietly produce a number. `002`'s whole claim
rests on this.

## What the file must offer

Unit parsing, quantity construction, the six arithmetic operations, comparison,
formatting, and a dimension-equality predicate. Nothing else; this is the bottom
of the stack and everything above it will be tempted to add to it.

## Tests

Its own, run by `run-checks`, and they should be plentiful because everything
depends on this:

- Every prefix parses to the right scale.
- Compound units parse to the right dimension.
- Adding a length to a temperature raises.
- Multiplying a force by a length gives energy, dimensionally.
- A round trip through formatting and parsing preserves the value.
- The three pseudo-dimensions are mutually distinct and distinct from one over
  seconds.

## Blocks

`1402`, `1403`, `1404`, `1405`.

## Blocked by

Nothing. This is first.

## Related documents

`002`. `009` entry X2, which would extend this module with intervals.
