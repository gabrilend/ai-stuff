# 703 — What a transfer looks like

Produces `src/052-link-protocol.md`.

## Current behavior

**Done.** `src/052-link-protocol.md` exists. The transfer size is derived from
four constraints owned by four different phases — a whole number of correction
lines, no larger than the bank interleave, header overhead under a twentieth, and
inside the arbitration quantum — which is precisely the situation the checker
exists for.

Seven constraints. The credit count is derived from the bandwidth-delay product
rather than chosen, because falling short does not fail: it silently costs
bandwidth.

**Writes are treated as reads with a payload.** The writes that exist are small
and latency-sensitive in a way this does not distinguish, and `037` noticed the
same gap from the arbiter's side. Neither has acted.

**Errors are corrected and not counted.** How often a line needed correcting per
link is the one signal that would show a conductor failing slowly rather than all
at once, and `051` has no other way to know which conductors to remap.

## Intended behavior

**The protocol on a radial link: transaction types, transfer size, header format,
latency, and the credit scheme.**

### The traffic, which is unusually simple

Almost all of it is one face reading a long sequential run of weights out of the
core. Not scattered, not small, not read-modify-write, and not shared with anybody
— each face reads its own layers. The rest is a sixteen kibibyte staging write once
per stage per token, a handful of small sequencer reads, and the spout.

**A protocol designed for that traffic can be very simple**, and the blueprint
should resist generality. There is no coherence (`506` says so explicitly), no
snooping, no ownership, and no need for a transaction to fail and be retried
except on a correctable error.

### The transfer size

The single most-cited number in this phase. It has to satisfy four things at once:

- Large enough that header overhead is negligible against the weight stream.
- A multiple of `507`'s correction line, so a transfer is a whole number of
  protected units.
- No larger than `505`'s bank interleave, so one transfer is not split across
  banks.
- Small enough that `504`'s round-robin quantum does not starve a face for longer
  than `704` tolerates.

Four constraints from four different blueprints on one number. It is exactly the
kind of thing the checker exists for, and it should be derived here rather than
picked.

### Latency, which the sequencer needs

Round-trip from a face issuing a read to the first data arriving. Four
contributions: the link's flight time, the cage's arbitration, the tier's access
from `502`, and the return. `608`'s prefetch trigger and `604`'s outstanding
request count are both sized from this number, so it must be a worst case rather
than a typical one.

### Credits

A reader must not issue more than the cage can absorb. Credit-based flow control,
one credit per outstanding transfer, returned when the transfer completes. Simple,
and `705` needs the credit count to prove that nothing deadlocks.

The number of credits per port has to cover the round-trip latency times the line
rate, or the link idles waiting for returns. That is the bandwidth-delay product
and it should be derived, because getting it wrong wastes bandwidth silently.

## Symbols this must publish

Transaction types. Transfer size. Header size and fields. Overhead fraction.
Round-trip latency, worst case, with its four contributions. Credits per port.
Bandwidth-delay product. Maximum outstanding transfers.

## Constraints this must assert

- Transfer size is a multiple of `507`'s correction line and no larger than
  `505`'s interleave. Two constraints from two phases on one symbol.
- Header overhead is under a stated fraction of payload.
- Credits per port times transfer size is at least the bandwidth-delay product.
- Worst-case latency is inside `608`'s prefetch lead time.

## Suggested implementation steps

1. Enumerate the traffic and show how little of it there is beyond weight reads.
2. Derive the transfer size from all four constraints and show which binds.
3. Build the latency from its four contributions, worst case.
4. Derive the credit count from the bandwidth-delay product.

## Blocks

`704`, `705`, `706`, `604`, `608`, `505`, `507`.

## Blocked by

`502`, `504`, `505`, `506`, `702`.

## Related documents

`004` for the traffic this carries.
