# 905 — The bonded grade

Produces `src/066-spout-bonded-grade.md`.

## Current behavior

**Done.** `src/066-spout-bonded-grade.md` exists, opening with *it is a bond, not
a connector* because every consequence follows from that sentence.

Six constraints, and two are asserted in the alarming direction deliberately.
`C-066-1`: with no spares an array this size **fails more often than it works**,
which is the entire justification for `063`'s spare conductors and which a reader
who has not multiplied it out will not believe. `C-066-3`: this bond needs a
flatness **two orders of magnitude tighter** than the face flatness `013`
specifies — which locates the difficulty precisely. It is not the number of
wires. It is that two fifty millimetre surfaces must be flat to a fifth of a
micron while being pressed together hot.

The shipping form is argued: a cube bonded to its own small translation die, with
the detachable interface on the far side of that.

**The spare coverage bound is crude** — expected failures over spares, which is
not a probability, and is marked as such. **And nothing says how a failed bond is
found**, since the only opportunity is after the bond, when the object cannot be
taken apart.

## Intended behavior

**The permanent grade: sixteen point eight million conductors at ten micron pitch,
copper bonded directly to copper, one wire per bit of the pane.**

### What it is

Not a connector. A **bond**. The face and whatever receives it are pressed
together at temperature and become one object; there is no socket, no compliance,
no mating cycle, and no way back. The blueprint must open with that, because every
consequence follows from it.

### What it buys

Two mebibytes on one edge. Sixty-four gibibytes in thirty-three microseconds. A
factor of forty-two thousand against a four hundred gigabit network link, and a
factor of about two hundred and fifty against the cabled grade in `906`.

### What it costs

**Serviceability, completely.** `207` says a cube has no field-replaceable parts
and service means replacing the whole cube. A bonded spout means service replaces
*two* whole objects, because they are one object. If the far side is another cube,
a single die failure anywhere in either scraps both.

**Yield, multiplicatively.** Sixteen point eight million bonds, all of which must
work, made in one operation at the very end of assembly when both objects are
already at their most valuable. `1203` must carry this as its own term and `902`'s
spares are what make it survivable.

**Alignment.** Ten micron pads want sub-micron placement across fifty-two
millimetres, with both surfaces flat to a fraction of that, at temperature. This is
the hardest mechanical tolerance in the project and it should be compared
explicitly against `201`'s stack, which is two orders of magnitude looser.

### When it is right

The blueprint should be specific rather than leaving it as an option nobody
chooses. It is right when the two objects were always going to live and die
together: two cubes sold as a pair, or a cube bonded to a translation unit from
`909` that is itself cheap and never separately serviced.

**The second of those is the useful case** and it is probably how this grade
actually ships: the cube is bonded to its own small translation die at assembly,
and the detachable interface is on the far side of *that*. The cube's spout is
permanent; the machine's output is not. This resolves most of the serviceability
objection and the blueprint should say so.

## Symbols this must publish

Conductor count and pitch. Bond temperature, force and dwell. Alignment tolerance
in plane and in flatness. Bond yield per conductor and for the array. Assembly
step position in `1202`'s order. Rework possibility, which is none. Transfer rate
and burst energy, inherited from `901`.

## Constraints this must assert

- Alignment tolerance is achievable by the process named in `1202`, stated as a
  comparison rather than an assertion.
- Array yield with `902`'s spares exceeds `1203`'s target.
- Bond temperature is below the point at which anything already assembled is
  damaged — which is a real constraint because this is the last step and
  everything else is already inside.
- Flatness required is tighter than `201`'s stack allowance, asserted in the
  failing direction so the conflict is visible rather than discovered.

## Suggested implementation steps

1. Open with "it is a bond, not a connector" and take the consequences in order.
2. Derive array yield from per-bond yield and `902`'s spares.
3. Compare the alignment requirement against `201` and let the conflict show.
4. Argue the bonded-to-a-translation-die case as the shipping form.

## Blocks

`1202`, `1203`, `909`.

## Blocked by

`901`, `902`, `903`, `904`.

## Related documents

`007`. `207` for the serviceability this destroys and `909` for what mostly
rescues it.
