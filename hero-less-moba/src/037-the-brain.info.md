# 037-the-brain

What a body is doing, as a dispatch table.

## What it is for

The state field indexes an array of behaviour functions, one per state, each
returning the state the body should be in next tick. **There is no chain of
conditionals deciding what a soldier is doing** — the soldier already knows, and the
table says what knowing that means.

Having one body type is a design constraint with teeth: anything worth giving a hero
has to be expressible as a field on the common record, which keeps this table small
enough to actually be good. The alternative — a separate hero controller — is how
lane-pushers end up with soldiers visibly stupider than heroes, and in a game with no
heroes at the centre of it, visibly stupid soldiers are the whole product.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `run(world)` | | — Advances every living body by one tick of thinking. |
| `state` | *(table)* | The dispatch table, indexed by state number. |

## The seven states

| # | State | What it does |
| --- | --- | --- |
| 1 | **walking** | Advance along the lane, unless blocked by the rank ahead. Act on whatever targeting wrote down. |
| 2 | **closing** | Keep advancing until the target is inside weapon range. Recheck the target's generation every tick. |
| 3 | **fighting** | Stop. The attack pass swings; this only decides whether the body is still in a fight. |
| 4 | **leashing** | Guards only. Walk back toward the leash node, **refusing to acquire anything on the way**. |
| 5 | **dying** | One tick of bookkeeping, done by the reap pass. |
| 6 | **waiting** | A hero standing at its own library during a calm. *Not built.* |
| 7 | **recovering** | A wounded body that has pulled out of the line to mend. *Not built.* |

States 6 and 7 have rows so that the table is the whole list of states rather than the
list of implemented ones.

## Three behaviours worth knowing

**A dead target drops you back to walking on the same tick, not the next one.** An
idle tick per kill is invisible individually and adds up to a visibly limp frontline.

**A leashing guard refuses to acquire**, and the refusal is the point. A guard that
re-acquires on the way home never gets home, and the ground around the tower it was
supposed to be denying ends up empty while the guard chases somebody down the lane.

**Fighting can fall back to closing.** If the target moved out of range the body
closes again rather than swinging at nothing.

## The one body that will not use this

The Eternal Golem never enters closing and never enters fighting. It walks, and it
attacks whatever it walks into, and it does not stop for either — there is no target
acquisition, because it is not going anywhere except the library. That exception is
written down here so somebody finds it, rather than discovering it by wondering why
the Golem parks. **Not built** — it belongs to the challenge phase.

## Where the rest of the brain will go

How a ranged body keeps its distance, how a wounded one leaves the line and comes
back, and how a healer chooses are rules on this same record and this same dispatch
table — not a second controller. They are enough of them to want their own page, and
they are not built yet.
