# 803 — How a model is laid out on the media

Produces `src/058-weight-format-on-media.md`.

## Current behavior

**Done.** `src/058-weight-format-on-media.md` exists. The format is a pre-sorted
stream in the sequencer's own walk order, cut into six contiguous regions so six
lines read at once with none touching another's data.

Six constraints. `C-058-2` is the format's whole purpose as a number: over
ninety-nine per cent of a slice read must be one contiguous run, which is what
separates a thirty millisecond load from a several second one.

The carried rotation table is in, with a constraint requiring it to stay small
against the weights — it removes every transcendental from the forward pass, and
if it were large that trade would need arguing rather than asserting.

**The tensor walk order is a count and not an order.** Nine tensors a layer, and
which nine in what sequence is `048`'s to state and this file's to mirror, and
neither has written the list.

**Nothing describes how the file is produced.** Something outside this machine
quantises, fits the expansion tables, computes the rotations and writes this
layout. It is the only substantial piece of software the design assumes and does
not specify, and `085` needs it on day one.

## Intended behavior

**The byte-level layout of a model as it sits on the storage lines**, so that
loading it is a sequential read and not eighty million small ones.

### The property that matters

A drive delivers its rated bandwidth on long sequential reads and a small fraction
of it on scattered ones. A transformer's weights arrive from training as a few
hundred named tensors in whatever order the framework serialised them. **Reading
those in the order the sequencer wants them is a scatter**, and the difference
between a scatter and a sequential read is the difference between a thirty
millisecond load and a several second one.

So the format is not a container. It is a **pre-sorted stream**, ordered exactly
as `608`'s descriptor chain walks it: slice by slice, layer by layer, and within a
layer, tensor by tensor in walk order.

### Six slices, six independent streams

The cut in `1101` assigns a run of consecutive layers to each face. The media
layout must mirror it: **six contiguous regions, one per face**, so that a face's
whole share is one seek and one long read, and so that the six lines can be read
simultaneously without any of them touching another's data.

This is what makes the six lines worth having. Six independent streams into six
independent regions, with no coordination beyond starting them.

### What has to be in the file besides weights

- **A header** naming the model's shape — layer count, hidden width, head counts,
  vocabulary — because the machine must not infer them and `608`'s descriptor
  chains are built from them.
- **The quantisation tables.** `606`'s sixteen-entry codebook per group and its
  scale. These interleave with the weights rather than sitting in a block of their
  own, because the engine's expansion path in `605` wants them alongside.
- **The rotation table.** Positional rotations depend only on the position and the
  pair, never on what the model is thinking, so they are computed once at packing
  time and carried. This removes sine and cosine from the machine entirely, which
  is what lets `603` claim bit-exactness through the whole forward pass.
- **A hash per slice**, checked after load. `069`'s argument: a weight corrupted at
  load and then read ten million times is a different problem from one corrupted
  in flight, so checking is a load-time operation and not a per-transfer one.

### Alignment

Every tensor's start must be aligned to `703`'s transfer size and to `505`'s
interleave, so that the load path writes whole transfers into whole banks. Padding
between tensors is cheaper than a misaligned write on every one of them.

## Symbols this must publish

Header layout and size. Slice region boundaries. Tensor order within a layer.
Group and scale interleaving. Rotation table size. Alignment and padding overhead.
Hash algorithm and coverage. Total on-media size against resident size. Sequential
read fraction.

## Constraints this must assert

- Total on-media size equals resident size plus header plus rotation table plus
  padding. Nothing unaccounted.
- Every tensor start is aligned to both `703`'s transfer size and `505`'s
  interleave.
- Slice regions are contiguous and disjoint, and there are as many as there are
  faces.
- Sequential read fraction exceeds a stated floor, which is the whole point of the
  format expressed as a number.
- The declared shape in the header is consistent with the tensor sizes that
  follow. A self-check that catches a truncated or mismatched file at load rather
  than at the first wrong answer.

## Suggested implementation steps

1. Get the walk order from `608` and lay the tensors out in it.
2. Cut into six regions from `1101`'s assignment.
3. Design the header and make it self-checking against the body.
4. Interleave the quantisation tables where `605` wants them.
5. Add the rotation table and the per-slice hashes.
6. Work the alignment padding and report the overhead.

## Blocks

`804`, `806`, `1205`.

## Blocked by

`505`, `606`, `608`, `703`, `802`, `1101`.

## Related documents

`004`. `603` for why the rotation table being carried matters.
