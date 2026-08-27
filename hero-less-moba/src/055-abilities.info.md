# 055-abilities

What a hero does that a wave unit cannot.

## What it is for

**There is no cast key and no targeting cursor.** An ability fires by itself when
its cooldown is ready and its condition is met.

A hero is a soldier you paid for and pointed, not a puppet you drive. That rule
keeps the soldier brain the only brain in the game — every piece of manual control
added is a behaviour the brain no longer has to be good at, and the end of that road
is a game where the soldiers are visibly stupider than the things you drive. It also
protects the chest: a player's hands are busy placing and arguing, and a hero
demanding attention would compete with the system that replaced heroes in the first
place.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `run(world)` | | — Every hero whose cooldown is ready and condition met. Also ticks fear. |
| `condition` | *(table)* | Predicates. Each returns the target to apply to, or 0. |
| `effect` | *(table)* | What happens. |
| `FEAR_MULTIPLIER` | | What a frightened body's blows are multiplied by. |

## Which concentrates everything into the condition

With nobody able to intervene, a hero's entire personality is the predicate that
decides when its ability fires. Two heroes with identical stats and different
conditions are two genuinely different purchases, and there is nowhere else for the
design effort to go.

A condition **returns the target** rather than a yes/no, which keeps the search in
one place: having found the right body, it should not make the effect find it again.

| Condition | Fires when |
| --- | --- |
| `enemies_crowded` | three or more enemies close together |
| `structure_in_reach` | an enemy structure inside weapon range |
| `ally_soonest_to_die` | an ally will die soonest — health **and** incoming damage per second, not health alone |
| `allies_hurt_nearby` | two or more wounded allies close by |

| Effect | Does |
| --- | --- |
| `splash` | damage to every enemy in the radius |
| `breach` | heavy damage to one structure |
| `heal` | one ally, clamped at full |
| `shield` | mends everything close by, a little |
| `wither` | **fear** |

## Not a parallel damage system

Everything here writes into the same pending-damage buffer an ordinary swing does,
resolves on the same tick boundary, and passes through the same armour arithmetic.
There is no second way to hurt somebody.

## Fear is not damage

A frightened body **hits softer** for a while. That is the enemy's actual weapon,
and it is deliberately not a second way of doing what swords already do. It lands on
a crowd, because that is what fear is worst in.

**Fear is evil. It is inflicted.** It is not an environmental hazard and not a
resource — it is something one thing does to another on purpose, and it has an
author.

## Why `ally_soonest_to_die` is not "lowest health"

A body at four hundred health with nothing attacking it is fine; a body at four
hundred with three enemies on it is next. Percentage is the wrong measure and
absolute health alone is only half of one. What a healer is answering is *how long
has this one got.*
