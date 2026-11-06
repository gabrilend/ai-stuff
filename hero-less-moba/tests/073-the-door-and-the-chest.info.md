# 073-the-door-and-the-chest

The rules a player's hands are held to: the one door commands come through, and the chest they reach into.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## Running it

```
luajit tests/073-the-door-and-the-chest.lua
```

Exits non-zero if anything failed. `./run-tests code` runs it after the invariants
and the formation sandbox.

## What it is for

Every check here is a rule about a verb, and a verb's answer does not need a match to
have been played. Asked through a whole match, a refusal that stopped being raised or
a stamp that started compounding would turn up as a wobble in some number thousands of
ticks in, and the change that caused it could be anywhere. Asked here, against a world
that has been assembled and never ticked, a failure names the verb.

**Nothing here advances the clock.** The one thing driven the way the tick drives it
is the door itself: queue, then apply.

It claims issues 106, 401, 402 and 411 for the census. It does **not** claim 413:
what is built under that number is `offer`, which the invariants already test, and
the staked die that gives 413 its name is not built.

## What it checks

### The door (106)

| Check | Fails the day somebody… |
| --- | --- |
| A queued command changes nothing until it is applied | …lets a click write into the world before the tick reaches it, which makes the tick no longer a function of state and commands. |
| Commands are applied by player, then by arrival | …applies them as they came. The check is built so the two orders disagree: an owner offers a stone, then a lower-numbered teammate tries to place it. |
| The same two commands, turning up in the other order, land the same way | …lets arrival break a tie. This is the test issue 106 asked for in its own words. |
| A refusal raises one event naming the player, the verb and a reason | …lets a refusal go quiet, so the player believes the game has their instruction. |
| An unknown verb stops the program | …turns a programming error into a silent no-op. |

### The catalogue (401)

| Check | Fails the day somebody… |
| --- | --- |
| Every kind changes at least one number, says which half of a wave it reaches, and says what it gives stone | …adds a row with a typo in its effect. This is the validator 401 asked for, standing where it is run. |
| Only Boots gives stone nothing | …empties another row's tower effect by accident, or gives stone something to walk with. |

### The stamp (401)

| Check | Fails the day somebody… |
| --- | --- |
| Two Whetstones and a Banner come to (16 + 5·2) × 1.16 | …multiplies before adding, or adds a multiplier. |
| The same holding, listed in another order and stamped on a fresh body, gives the same body | …makes the result depend on the order stones were drawn in, so two teams holding the same upgrades arrive at different numbers. |
| A melee-only kind does nothing for a ranged body, and three of it on a melee body is three of it | …ignores `reaches`, or caps a stack nobody asked to cap. |

### The instances (402)

| Check | Fails the day somebody… |
| --- | --- |
| Draws go round the team, and every stone drawn is that team's | …hands one player the whole draw, or lets a stone cross teams. |
| The per-slot counts are exactly a hand count of the stones | …lets the cache drift from the instances it is meant to summarise. |
| A stone on its way counts where it is, not where it is going | …makes a move land the moment it is marked. |

### The reroll (411)

| Check | Fails the day somebody… |
| --- | --- |
| A reroll nobody can afford is refused and says what is missing; one that can be afforded costs exactly its price | …changes the price without the refusal or the charge following. |
| A reroll turns the stone into the next card of its own team's deck, and adds nothing | …makes the reroll a draw, or advances the other team's deck. |
| A placed stone, or somebody else's, cannot be rerolled | …lets a reroll reach into a lane or another player's hand. |

## Exports

None. It is a program, not a module.
