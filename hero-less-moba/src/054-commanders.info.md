# 054-commanders

Personal resource, hero purchase, and the three places a hero may be put down.

## What it is for

The one thing in this game that belongs to a single player and cannot be touched by
their teammates.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Builds the player records and deals commanders. |
| `commander_for_wave(world, team, turn)` | | Whose mixture walks out this time. |
| `stamp_bounty(world, id, commander, index)` | | — Gives a body the colour it pays. |
| `credit(world, player, colour, amount)` | | — Adds points, capped, counting the overflow. |
| `pay_for_kill(world, dead_team, flavour, archetype, colour)` | | — Pays every player on the other team. |
| `climb_ladder(world)` | | — The wallets grow, on the clock, for everybody. |
| `can_afford(world, player, hero_row)` | | Whether they hold every colour the bill names. |
| `clear_ground(world, structure)` | | Whether a tower's command radius holds no enemy. |
| `buy(world, player, hero_row, where, target)` | | A verdict, in the same shape a command refusal uses. |
| `hero_died(world, owner)` | | — |

## Every kill pays everybody

Not a pot to be divided — the catalogue figure is **per player** — and nothing asks
what did the killing. The reap pass reads the dead body's own team and credits the
other one.

Two consequences shape the whole second economy. **Teammates have identical
incomes**, so the only thing distinguishing two players is what they do with the
same money: when to bank, when to spend, which hero, which destination. And **there
is no death spiral** — a player who buys a hero, puts it somewhere stupid and loses
it has lost the purchase and nothing else. "Personal" means a private wallet, not a
private income.

## The commanders take turns

A third of what leaves your base is somebody else's captain and somebody else's
mixture. That is what makes commander selection a team conversation in the lobby
rather than three private preferences — and why a player learns the enemy's roster
by watching rather than by being told.

## The three destinations

| | Arrives | Costs |
| --- | --- | --- |
| **onto a wave** | at the frontline, immediately, in formation | fragile — the frontline is where the enemy's damage already is |
| **onto a tower** | at that tower, unless enemies are inside its command radius | a walk from wherever you were allowed to put it |
| **onto the library** | in the lane where the enemy has pushed **deepest** | slow — a long walk |

That trade — arrive now and fragile, arrive late and intact — is the entire spend
decision.

The library's lane choice is measured in **milestones, not distance**. A lane where
they sit one pace past your first tower is in less trouble than one where they are
inside your base, even though the base is physically nearer, and a straight-line
check picks the wrong lane in exactly the case where picking wrong matters most.

## Refused, never redirected

A tower whose ground is not clear refuses the purchase and **names the nearest tower
behind it that would accept one**. The player has to ask again.

Nothing puts a body somewhere the player did not ask for it to go: a silent redirect
is a fallback, and a fallback in a game where a hero costs a minute of income is a
purchase you did not make.

That rule is the whole texture of hero spawning — you cannot reinforce the tower
that is actually under attack, you reinforce the one behind it and walk the hero up.
A tower under pressure is one whose reinforcements arrive late, by design, which is
what makes the outer towers worth defending *before* they are in trouble.

## Two details easy to miss

**The bounty sequence is sorted.** A ratio is expanded into a repeating list so
every wave gets exactly the advertised proportions rather than approximately them —
and the list is sorted, because `pairs()` has no defined order and an unsorted one
would produce a different sequence between runs, failing the reproducibility test
for a reason nobody would guess.

**Overflow is counted per colour.** A player wasting income needs to be told *which*
colour. "You are wasting spirit" is an instruction; "you are wasting resource" is a
shrug.
