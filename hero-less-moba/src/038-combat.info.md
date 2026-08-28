# 038-combat

Everything between "this soldier swings" and "that soldier is dead."

## What it is for

Three passes of the tick live here: the swings, the resolution, and the reaping.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `clear_buffers(world)` | | — Zeroes both damage buffers and the event list. |
| `strike(world, target_id, raw)` | | — One blow landing on a body. |
| `strike_structure(world, structure_id, raw)` | | — One blow landing on stone. |
| `attack_pass(world)` | | — Every body whose cooldown came up and whose target is in reach. |
| `resolve_pass(world)` | | — Adds the buffer into health; marks the dead. |
| `reap_pass(world)` | | — Starts a decay for the fallen, and finishes one for the certain. |

## A death is a two-second process

The reap pass is two sweeps, not one.

**The fallen.** A body at zero health has `alive` set to zero and a decay counter
started. That single flag is what everything in the simulation already tests, so the
body stops fighting, stops being a target, stops holding a place in the frontline
queue, stops counting toward push depth and leaves the spatial grid — with no change
to any of those passes. It keeps its slot and every one of its numbers.

**The certain.** Decay counters come down, and a body whose counter reaches zero has
everything happen at once: the kill announced, the team paid, the wave counter
decremented, the guard replaced, the challenge ended if it was a monster, the slot
released.

**Why.** Machines correct each other about once a second, and a body that died here
and did not die on the authority's machine cannot be repaired once its slot is gone —
there is nothing left to write onto. Deaths are the hinge everything hangs from:
health makes deaths, deaths make wipes, wipes make draws, draws make the chest. Two
seconds is two correction cycles, so every machine has had its say before anything is
committed, and undoing a death is clearing one number.

**The cost.** Every consequence of a death lands two seconds late, uniformly, so it
is a delay and not a distortion. Paying immediately and undoing it later does not
work: a payment can be unmade only if it has not been spent, and a chest draw that
has already been placed cannot be unmade at all. A consequence that has been acted on
is not revertible, so the boundary sits before the consequence.

This is the same shape as the buffered damage below, one step later — a two-stage
split so that an outcome is decided in one place and committed in another. See
issue 210.

## Damage is buffered, then applied

Nothing writes to a health value during the attack pass. Attacks write into
`pending_damage`, cleared at the top of every tick; a separate pass adds it into
health.

**The reason is simultaneity.** Two soldiers on their last sliver of health, both off
cooldown on the same tick, should both die. If damage were applied immediately,
whichever one the loop reached first would win — and which one that is depends on slot
ordering, which depends on which soldier died four minutes ago and freed its slot.
That is a real, reproducible, completely unexplainable unfairness.

It also makes the attack pass safe to slice across a pool of workers: every worker
writes into distinct slots of a preallocated array and reads nothing another worker
is writing.

## One swing, start to finish

1. Cooldown comes down — **whatever the body is doing.** A body that only ticked its
   cooldown while in contact would swing late every time it re-engaged, and the delay
   would be invisible and would always favour whoever stood still.
2. Range is checked against the target's actual position. This is the only place in
   the game that uses as-the-crow-flies distance; everything about progress uses
   milestones.
3. The attacker's `damage` is used **as it stands** — the upgrades were folded in at
   birth by [the chest](041-the-chest.info.md), not walked here.
4. The defender's armour is subtracted and floored at a small positive minimum, so a
   blow never heals and a heavily upgraded defender is very hard to kill but never
   literally immune. **Immunity in a lane-pusher means a permanent stalemate**, which
   is the exact failure this whole game exists to avoid.
5. The result goes into the buffer. **Nothing records who dealt it.**

Structures have no armour and take full damage, which keeps siege arithmetic simple
enough that a player can hold "how many swings is that tower" in their head.

## Kill attribution: there isn't any

When a body dies, the opposing team is paid. That is the whole rule. The reap pass
reads the **dead body's own team** and pays the other one; it never asks what killed
it, because it does not need to.

It pays two seconds after the blow rather than at it, for the reason below.

So there is no last-hit accounting in this game at all — nothing to steal, and no
reason to position a body for a finishing blow. Three consequences:

1. **Nobody can be locked out.** A player who spends everything on a hero and loses it
   badly keeps earning at exactly the same rate as their teammates.
2. **Teammates have identical incomes.** The only difference between two players on a
   team is timing and choice.
3. **A team's income tracks its map position** — a snowball, by design, running in
   parallel with the upgrade economy's.

## Ordering inside the three passes

`resolve_pass` marks the dead but frees nothing, because freeing a slot mid-pass would
let a later body in the same pass be handed a slot the pass still refers to.

A structure at zero health is marked `falling` rather than processed immediately.
**Both libraries can reach zero in the same pass, and that is a draw** — picking a
winner by team number would mean team 1 wins ties forever, the kind of invisible
asymmetry only ever discovered by the player it kept losing to.
