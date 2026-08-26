# 033-commands

The one door player intent comes through, and the refusals it hands back.

## What it is for

The tick is a pure function of (state, commands), and that is only true if there is
no second path by which a click can reach a world array. The viewer holds a mouse
and the simulation holds the world; this file is the whole of the border between
them.

A viewer that could write into the world directly would make every desync and every
"it worked on my machine" unfindable, because the search space would be the entire
program instead of one queue.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `queue(world, command)` | | The command, stamped with an arrival index. |
| `apply_all(world)` | | — Drains the queue. The tick's first system after clearing. |
| `verb` | *(table)* | The verb dispatch table. |

## The verbs

| Verb | Fields it wants | What it does |
| --- | --- | --- |
| `place_in_lane` | `team`, `kind`, `lane` | Chest → that lane's body slot. |
| `place_in_stone` | `team`, `kind`, `lane` | Chest → that lane's tower slot, and re-stamps the stone. |
| `place_in_library` | `team`, `kind` | Chest → the library slot, which reaches all three base towers. |
| `recall` | `team`, `kind`, `from` (`"lane"`/`"stone"`/`"library"`), `lane` | Slot → chest. |

Every command also carries `player`, which decides the order it is applied in.

## Ordering, and why it is not arrival order

Commands are applied **by player number, then by arrival index** — not in the order
they showed up. Two players clicking in the same tick must resolve the same way on
every machine, and "who got there first" is exactly the thing two machines disagree
about.

## Refusals are loud

Every refusal is returned, named, and raised as a `refused` event carrying the
player, the verb, and a sentence saying why. A command that silently does nothing is
the worst outcome available here: the player believes the game has their instruction
and it does not.

An **unknown verb**, by contrast, stops the program. That is a programming error and
not a player error — a player can only send verbs the interface offers.

## The rule that surprises people

**Placing into a lane does not touch the bodies already walking in it, and recalling
from one does not weaken them.** They were stamped at birth and keep what they were
born with until they die. That delay is what turns every reassignment into a
decision worth arguing about instead of a switch.

**Stone is different**, and that difference is deliberate. Placing into or recalling
from stone re-stamps the towers and every guard standing under them immediately,
because a guard stands at the thing it copied from for its whole life — a guard whose
tower has changed and whose numbers have not is a visible lie.
