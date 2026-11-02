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
| `place_stone` | `stone`, `slot_kind`, `slot_lane` | Marks one stone to move to a slot (chest, a lane, a lane's stone, the library). It arrives a full wave later. |
| `cancel_move` | `stone` | Calls a marked move back. The stone stays where it was. |
| `contribute` | `stone` | Gives one of your own stones to the team's pool, permanently. |
| `offer` | `stone`, `to` | Gives one of your own stones to the teammate named. The only verb that moves ownership. |
| `dismiss` | `stone` | Sets a pool stone aside from your own view and nobody else's. |
| `request` | `stone` | Asks for a stone. Changes nothing by itself. |
| `ping` | `x`, `y` | Marks a point on the map for your team. |
| `move_cursor` | `x`, `y` | Where you are pointing. Never refused. |
| `reroll` | `stone` | Pays the reroll price for one stone in your own hand and turns it into the next card of the team's deck. |
| `buy_hero` | `hero`, `where`, `target` | Spends your own resource on a hero. The purchase lives in the commanders module. |
| `set_signpost` | `team`, `lane` | Turns one of your team's sign-posts. Refused only for a lane that does not exist. |
| `choose_boon` | `boon` | Takes one of the boons on offer. |

Every verb but `set_signpost` hands its fields to the module that owns the rule, and
that module decides the refusal; this file only routes. The chest, the stones and the
reroll are tested verb by verb in `tests/073-the-door-and-the-chest`.

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

**Placing into a lane does not touch the bodies already walking in it, and moving a
stone out of one does not weaken them.** They were stamped at birth and keep what they were
born with until they die. That delay is what turns every reassignment into a
decision worth arguing about instead of a switch.

**Stone is different**, and that difference is deliberate. Placing into or moving out
of stone re-stamps the towers and every guard standing under them immediately,
because a guard stands at the thing it copied from for its whole life — a guard whose
tower has changed and whose numbers have not is a visible lie.
