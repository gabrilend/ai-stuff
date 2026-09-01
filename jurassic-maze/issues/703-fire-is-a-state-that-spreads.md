# 703 — Fire Is A State That Spreads

| | |
| --- | --- |
| Phase | 7 — The Delve |
| Blocked by | 302, 701 |
| Blocks | 705, 706, 707 |
| Reads | [the monsters of the delve](../docs/023-the-monsters-of-the-delve.md), [the delve](../docs/021-the-delve.md) |
| Open questions | none |

## Current behavior

Nothing burns.

## Intended behavior

The distinction was made explicitly — *"fire powers like 'ignite' and not like
'fireball'"* — and it decides the whole construction.

A **fireball** is an event: it happens at a place, at a moment, and it is over. It
would be a function call.

**Ignite** is a state that persists and spreads. A burning body or cell stays
burning, loses fuel every tick, and sets fire to flammable neighbours.

So: a `burn` pass, one row inserted into
[the tick](../docs/010-the-tick.md) before `resolve`, sweeping a list of burning
things, decrementing fuel, applying damage into the same buffer issue 502 uses,
and rolling to spread.

Flammability is a field on the creature kind and on the equipment row. Stone does
not burn. The maze does not burn. Vines, wooden automatons, and wooden weapons
do.

Building it as a spreading state rather than as an attack gives three things for
free, and the third is the test of whether it was built at the right level:

1. **The automaton burns.** A machine made of wood, whose power is to set things
   alight, standing in the vines it just ignited, has solved itself. Nothing
   arranges this.
2. Fire in a corridor is a corridor nobody wants to use, which is terrain.
3. **A party can carry fire.** Something flammable carried past a burning thing
   catches and can be carried elsewhere. That is a party ability nobody wrote,
   and it is the whole spread mechanic reused.

## Suggested implementation steps

1. Add `burning` and `fuel` to the body store, and a sparse list of burning
   cells so the pass sweeps what is alight rather than the whole maze.
2. Write the pass: decrement, damage into the buffer, roll to spread from the
   `burn` stream to flammable neighbours.
3. Write `ignite(target)` as the only entry point, called by the automaton and by
   spreading and by nothing else.
4. Extinguish at zero fuel; count things burnt out, and total ignitions, into the
   report.
5. Test: a line of flammable bodies ignited at one end burns to the other, in a
   time that scales with the length. An automaton beside burning vines catches.
   Fire never crosses a gap of non-flammable cells.

## Related documents and tools

- [The monsters of the delve](../docs/023-the-monsters-of-the-delve.md)
- [The tick](../docs/010-the-tick.md)
