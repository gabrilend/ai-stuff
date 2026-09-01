# 065-the-delve

Fire that spreads, riding, and three monsters that undo each other.

Read this page rather than the source, and read [the delve](../docs/021-the-delve.md),
[riding](../docs/022-riding-and-being-ridden.md) and
[the monsters](../docs/023-the-monsters-of-the-delve.md) before either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(...)` | | at world creation |
| `ignite(world, id, why)` | | sets a body alight; the only way anything catches fire |
| `burn(world, dt)` | | one tick of everything that is |
| `mount(world, bodies, rider, mount)` / `dismount(...)` | | |
| `rider_position(world, bodies, rider)` | | derived, never stored |
| `pass_riding(world, dt)` | | keeps a pair a pair, and separates it when it must |
| `pass_monsters(world, dt)` | | holds, breaks, ignites |
| `break_a_wall(world, bodies, id, kind)` | | a golem goes through |
| `meets(world, bodies, a, b)` | | the delve's whole meet rule |

## The damage is not in this file

Two bodies of opposing sides that can hurt each other start a **duel**, and
`060-duels.lua` does the exchanging. What is left here is the three things that
are *not* an exchange of blows: climbing onto a dinosaur, being held by a vine,
and being set alight.

That split is what the loose reading of "solve" turned out to mean. The monsters
are enemies with health, the cycle between them is a table of multipliers in the
creature table, and what would have been nine pairings of rules is three
abilities.

## The automaton does not check whose side you are on

It is a machine; it sets alight whatever flammable thing is beside it, on its own
cooldown.

Restricting it to the other side was the tidy thing to write, and it silently
deleted the best behaviour in the mode — the automatons and the vines are both
monsters, so nothing ever lit a vine, and a wooden machine standing in a thicket
it had ignited stopped being possible. The counter read zero and nothing raised.

Not itself, though. It catches from the fire it started rather than from its own
hand, which is both funnier and what actually happens.

## Ignite is a state, not an event

The distinction was made explicitly when this mode was asked for — *"fire powers
like 'ignite' and not like 'fireball'"* — and it decides the construction. A
fireball happens at a place, at a moment, and is over: it would be a function
call. Something ignited stays ignited, loses fuel, and sets fire to what is
beside it: it is a tick pass.

Three things fall out that nobody wrote, and the third is the test of whether the
model was built at the right level:

1. **The automaton solves itself.** A machine made of wood whose power is to set
   things alight, standing in the vines it has just ignited, catches. There is a
   test for it and no code path called "self" — if there had to be one, the fire
   model was wrong.
2. A burning corridor is a corridor nobody wants to use, which is terrain.
3. A party can carry fire: something flammable carried past a burning thing
   catches, and can be carried elsewhere. That is an ability nobody wrote.

## The delve's passes always run

They were gated on a flag derived from the scene's population, which is the
obvious reading of "a mode is which tables are loaded" and is wrong in a way that
is entirely silent. A body placed by any route other than the scene's population
— a test, a scenario, anything later — got a world where fire does not burn and
riders do not ride, with no error and no clue. Four assertions failed on it and
every one looked like a bug in the thing being asserted.

The gate was not worth having either: three sweeps of the body store is a few
tens of microseconds a tick. **The mode is which creature kinds spawn and which
meet-table entries exist. It is not which passes run.**

## A rider's position is derived

The mount's, one layer up, offset along its facing. Deriving rather than storing
means the two cannot drift apart, which is the failure mode of every version of
this that keeps two positions in step by updating both.

The `carried` locomotion row does nothing at all, which is the correct amount of
work for a body not moving under its own power — and being a row rather than a
flag means the move pass never learns riding exists.

## Two things about the golem that took finding

**Its own clock.** It counted its work on the shared `timer`, which is also the
idle clock and which the riding pass writes. The idle reset it before it ever
reached the threshold, so no golem ever broke a wall — with no error and nothing
in any counter.

**It reaches past its own footprint.** A three-by-three golem can never be
*adjacent* to a wall: its footprint needs three by three of level floor, so its
four neighbours are floor by construction and the nearest wall is always two
cells away. Reaching one cell further is also what lets it make its own space —
the wall comes down, its footprint then fits a cell on, and it advances into the
notch it just made.

It takes one layer off the top rather than boring through, so the columns stay
height-shaped and the validator's check for that still passes. A golem that bored
a tunnel through the middle of a wall would be the first thing in the project to
make a column with a hole in it, and that check has been waiting since phase one.

## The version counter finally moves

`store.version` was written in phase one and nothing bumped it until this file.
That was the point: the renderer's baked mesh is the first thing in the project
to cache something derived from the stone, and this is the first thing that
changes it. The viewer compares the counter and rebuilds.
