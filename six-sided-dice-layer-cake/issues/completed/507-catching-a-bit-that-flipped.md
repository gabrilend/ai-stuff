# 507 — Catching a bit that flipped

Produces `src/040-core-ecc-and-repair.md`.

## Current behavior

**Done.** `src/040-core-ecc-and-repair.md` exists and opens with the sentence it
should: a flipped weight bit crashes nothing, changes one number in one matrix,
and the model produces slightly different text forever with no symptom at all.
Six hundred and thirty thousand million bits gives an upset about every ninety
minutes.

The line went from sixty-four bits to two hundred and fifty-six, which takes the
overhead from twelve and a half per cent to under four — and that eight and a
half per cent recovered is most of what paid for dropping eight tiers. Scrubbing
comes out close to free: an hour's period puts the mean time between
uncorrectable errors in the millions of years and costs about a millionth of the
core's bandwidth.

Seven constraints, all holding.

**Runtime repair is abandoned rather than solved**, and it is a real reduction in
what the machine survives. The map would have to outlive power loss and nothing
in this cube is non-volatile — the same gap `033` needs for its fault record.
Two dependents on one missing thing.

**The soft error rate is a sea-level figure with no altitude term**, and cosmic
ray flux roughly doubles every two thousand metres.

## Intended behavior

**Error detection, correction, scrubbing and row repair for sixty-four gibibytes of
static memory, sized against a real error rate rather than a convention.**

### Why this is not optional here

Five hundred and fifty billion bits. A soft error rate of a thousand failures in
time per billion bits — an ordinary figure for static memory at sea level — gives
roughly **one upset every two hours**. Without correction, this machine produces a
wrong answer twice a working day and never says so.

And the failure is silent in the worst way. A flipped weight bit does not crash
anything. It changes one number in one matrix and the model produces slightly
different text, forever, until the memory is reloaded. **There is no symptom.** The
blueprint should open with that sentence.

### The scheme

Single error correct, double error detect, over a line whose width comes from
`703`'s transfer size. Twelve and a half per cent overhead at a sensible line
width, which is the deduction `501` already carries.

`009` entry M1 asks whether correction should be per word or per line. Per line is
cheaper in check bits and worse for small reads. The sieve's reads are enormous and
sequential, so per line is almost certainly right — but the **sequencer** in `608`
makes small reads of its own control structures, and if those pay a line's latency
the schedule suffers. The blueprint must resolve this by measuring rather than
assuming, and the measurement is a count of small reads per token from `704`.

### Scrubbing

Correction only helps if errors do not accumulate. Two upsets in one line is a
detected uncorrectable, which is better than silence but still a stopped machine.
So the whole core must be read and rewritten on a cycle short compared to the mean
time between two upsets in the same line.

Sixty-four gibibytes at a scrub rate low enough to be invisible: the blueprint must
derive the required period from the upset rate and the line count, then derive the
bandwidth that period demands, then show it is a negligible fraction of `501`'s
aggregate. If it is not negligible, the line width is wrong.

### Repair

Soft errors are transient. **Hard failures are not**, and in a stack of thirty-two
tiers they are the yield problem in `1203` wearing a different hat. Three levels:

- **Spare rows and columns** within a tier, blown at test. Two per cent of capacity,
  already in `501`'s chain.
- **A redundant tier.** One of the thirty-two held in reserve, mapped in if another
  fails. Three per cent of capacity and it is what turns a thirty-two-way stack
  yield problem into a manageable one.
- **Runtime remap.** A line that fails repeatedly is retired and its address
  remapped. Needs somewhere to keep the map that survives power loss, which nothing
  in the design currently provides. **This is a gap** and the blueprint should say
  so rather than inventing a mechanism in passing.

## Symbols this must publish

Soft error rate per bit and for the whole core. Mean time to an upset. Code
strength, line width and check bit overhead. Scrub period and scrub bandwidth.
Spare row and column counts. Redundant tier count. Mean time to an uncorrectable
error with and without scrubbing. Small-read count per token from `704`.

## Constraints this must assert

- Mean time to an uncorrectable error exceeds the target in `1206`.
- Scrub bandwidth is under a stated fraction of aggregate, so it is invisible.
- Check bit overhead matches the deduction in `501`'s capacity chain. Two
  blueprints agreeing about the same twelve and a half per cent.
- Scrub period is shorter than the mean time to a second upset in the same line, by
  a stated factor. This is the constraint that makes scrubbing worth doing rather
  than a ritual.

## Suggested implementation steps

1. Get the raw soft error rate with a source and compute the whole-core rate. Open
   the blueprint with the two hours.
2. Choose the code and the line width, resolving `009` entry M1 with `704`'s small
   read count.
3. Derive the scrub period from the two-upset condition and the bandwidth from the
   period.
4. Size the spares and the redundant tier against `1203`'s yield model.
5. State the runtime remap gap plainly rather than filling it.

## Blocks

`501`, `1203`, `1206`.

## Blocked by

`502`, `503`, `703`, `704`.

## Related documents

`004` on why a corrupted weight is a different problem from a corrupted transfer.
`009` entry M1.
