# Phase 5 — The Yolk: progress

**The block of shared memory at the centre. Complete, and it resized itself.**

| ticket | blueprint | state |
|---|---|---|
| `501` | `034-core-organisation` | done |
| `502` | `035-core-bitcell-and-macro` | done |
| `503` | `036-core-tier-and-stack` | done |
| `504` | `037-core-six-port-arbitration` | done |
| `505` | `038-core-address-map` | done |
| `506` | `039-core-ordering-model` | done |
| `507` | `040-core-ecc-and-repair` | done |

A hundred and thirty-two constraints hold across thirty-one blueprints.
Seventy-seven more wait on phases 6 through 12.

## The tier count came out of the chain rather than going into it

Thirty-two tiers was the first sketch, chosen because it made the stack pitch a
round number. Then `035` derived an areal density from the bitcell upward —
cell area, array efficiency, tier overhead — rather than quoting one, and at that
density thirty-two tiers hold half again what the reference model needs. Silicon
nobody uses, paying leakage forever.

**Twenty-four**, and each tier gets a lamina a third thicker, which the core's
own cooling wanted anyway. This is the phase's best argument for deriving rather
than choosing: the density and the tier count could each have been picked to look
sensible, and only building one from the other exposed the mismatch.

Widening the correction line from sixty-four bits to two hundred and fifty-six
recovered another eight and a half per cent, which is most of what paid for
dropping the eight tiers.

## Three silent unit conversions

Written by hand into derivations, in a notation that already does conversions.
Each was a dimensionless literal and therefore invisible:

- a division by a thousand to turn megabytes into gigabytes, which made the core
  a thousand times too small
- two more to turn millimetres into metres, which between them made a tier's
  temperature rise a thousand times too large

**This is the failure mode the whole notation exists to prevent and it still took
the checker to find them.** Worth remembering: the rule that every literal is
dimensionless stops an unlabelled quantity entering the project, and does nothing
about a labelled one being converted twice.

## The via that is not a via

A through-stack column running the full forty millimetres of the core is a
resistance and a capacitance in series, and its time constant goes as the
reciprocal of its area. Three microns was hopeless. Five settled in two hundred
and eleven picoseconds against a two hundred picosecond budget — eleven
picoseconds short, which no hand calculation would have flagged. Seven gives a
hundred and eight, in copper rather than tungsten.

That matters because the two end faces reach deep tiers this way, and if they
cannot, `034`'s single-face-takes-all requirement fails for two of the six.

## The corrections that flowed backwards

`037` derived a per-bit figure for the switch fabric and **corrected `020`'s heat
budget**, which had been carrying an estimate of thirty-nine watts made before
there was one. `035` did the same for retention leakage. Both were caught by
constraints asserting that two blueprints must agree about the same watts.

## What is still open

**The interleaving is a stride and not an analysis** (`038`). Six streams walking
six contiguous regions in step is about as correlated as access patterns get, and
whether that makes bank collisions rarer or more frequent depends on where the
regions begin. **The piece of this phase most likely to cost real bandwidth
silently.**

**Runtime repair is abandoned** (`040`). The map would have to outlive power loss
and nothing in this cube is non-volatile — the same missing thing `033` needs for
its fault record. **Two dependents on one gap.**

**Training will break `C-039-5` when it is implemented**, because the reverse
staging buffers are a fourth sharing site and the ordering model still says
three. That is the constraint behaving correctly.

**Nothing says what happens on an out-of-range address** (`038`). No protection,
no fault, so a face computing a wrong address reads somebody else's region and
produces plausible nonsense.

**The memory model is prose.** Five definitions and a table that no program
reads. A machine-checkable memory model would be worth more than everything else
in `039`.
