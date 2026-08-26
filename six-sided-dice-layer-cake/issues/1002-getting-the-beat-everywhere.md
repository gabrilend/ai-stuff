# 1002 — Getting the beat everywhere

Produces `src/071-clock-distribution.md`.

## Current behavior

Nothing. Distribution has been assumed to work in a shape where the longest path
is not in a plane.

## Intended behavior

**How a clock reaches every flip-flop in a three-dimensional object**, and the
skew that results.

### What is different about a cube

In a flat package, clock distribution is a tree across a die and a shorter tree
across a board, and both are planar problems with a century of practice behind
them. Here there are three levels and the middle one is unusual:

- **Within a die.** Ordinary. A balanced tree across twenty-four millimetres.
- **Across a face.** Four dies on an interposer, a millimetre apart. Also
  ordinary, and short.
- **Between faces, through the cage.** Six faces, each seven millimetres from the
  middle, but a hundred and twenty millimetres from the face opposite. **There is
  no path between two faces that does not go through the centre.**

That last point is what makes the problem tractable rather than harder. The cage
is equidistant from all six faces by construction — it is the property `000`
claims as a reason for the shape — so the inter-face distribution is a **star with
six equal arms**, which is the easiest topology there is.

### Where the skew actually comes from

Not the arm lengths, which are equal. It comes from:

- Process variation between six separately manufactured faces.
- Temperature difference between faces, which under the sieve is real: during
  single-stream generation one face is hot and five are not, and a warmer buffer
  is a slower one.
- Supply difference, since each face has its own regulator.

**The temperature term is the one this project creates for itself.** `010` chose
the antipodal face ordering to spread the walking hot spot; this blueprint is
where that choice pays a second dividend, because a smaller temperature spread
between faces is a smaller clock skew between them.

### The honest answer to the hard case

Trying to hold six faces to a common edge across a hundred and twenty millimetres
at one point four gigahertz is a poor use of effort, because **nothing in this
machine needs it.** `1003` establishes that faces need to agree about *cycles*,
not about edges, and the handoff between them goes through memory with barriers
rather than through a timing path.

So the blueprint should specify a mesochronous arrangement — same frequency,
unknown phase — and let `1003` handle the rest. Insisting on synchrony would cost
a great deal of power for a guarantee nothing consumes.

## Symbols this must publish

Tree topology and depth at each level. Arm length and its equality. Insertion
delay per level. Skew contributions: process, temperature, supply. Total
intra-die, intra-face and inter-face skew. Distribution power. The mesochronous
declaration.

## Constraints this must assert

- Arm lengths from the cage to all six faces are equal, which is the property the
  cube's geometry provides and which a later change to `013` could silently break.
- Intra-die skew is within `1005`'s allocation.
- Inter-face skew is within what `1003`'s crossing tolerates — a much looser
  number, and the constraint should show how much looser.
- Distribution power is within `301`.

## Suggested implementation steps

1. Draw the three levels and note that the middle one is a star with equal arms.
2. Attribute skew to its three sources and show the temperature term's link to
   `010`'s ordering.
3. Declare mesochronous between faces and cite `1003` for why that suffices.
4. Budget the intra-die tree properly, since that is where the tight number is.

## Blocks

`1003`, `1005`.

## Blocked by

`013`, `1001`.

## Related documents

`000` for the equidistance this uses. `010` for the ordering that reduces the
temperature term.
