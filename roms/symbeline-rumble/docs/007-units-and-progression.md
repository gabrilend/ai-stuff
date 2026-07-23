# Units & Progression

In-match unit behavior lives in `002-game-mechanics.md`. This doc covers the
*between-match* layer: who these units are, how they grow, and what the
player is asked to decide outside of combat.

## Units are adventurers

Each unit in the deck is a persistent character with a name, a class, a
level, an equipment loadout, and a behavior pattern. The reference for the
feel of this layer is Fire Emblem (not Warcraft Rumble, which is more
disposable). Losing a beloved unit should feel like a loss, not a refresh.

## Unit stats

All stats are stored fixed-point integers (per `008-fixed-point-math.md`).

| Stat             | Notes                                                              |
|------------------|--------------------------------------------------------------------|
| `hp_max`         | Hit points at full health.                                         |
| `atk`            | Outgoing damage before defender's `def`.                           |
| `def`            | Damage reduction (subtractive, not multiplicative; keeps fixed-point clean). |
| `range`          | Engagement distance in fix-tiles (see fixed-point doc).            |
| `speed`          | Tiles per tick.                                                    |
| `cooldown_post_death` | Ticks after death before re-enters deck (may be ∞ for permadeath modes). |

## Classes

A class is a tag plus a stat curve plus a behavior-pattern allow-list. The
roster is not yet locked, but the shape:

- **Footman** — line infantry. Cheap. Holds paths.
- **Archer** — ranged. Fragile.
- **Knight** — armored. Slow.
- **Mage** — long-range, spell-affinity, fragile.
- **Scout** — fast. Treasure carrier specialist.
- **Priest** — heals adjacent friendly units; cannot engage.

(Initial playable set in phase 4 will be 2–3 classes; the rest grow in phase
7/8 content work.)

## Equipment

Equipment slots and the per-class allow-list:

| Slot       | Effect                                          | Worn by                       |
|------------|-------------------------------------------------|-------------------------------|
| Weapon     | `atk` and `range` modifiers                     | all                           |
| Armor      | `def` and `speed` modifiers (heavier = slower)  | all                           |
| Trinket    | One of: hp regen, retreat threshold, spell affinity, treasure carry rate | all       |
| Banner     | Aura: small `atk` or `def` buff to nearby allies | leader-class only             |

Equipment is acquired via match rewards, treasure chests opened post-match,
and class-specific quest events.

## Levels

Levels are coarse — 1 through 10. Each level bumps stats by a class-curve
amount. Leveling happens at the post-match screen; the player allocates
unspent experience (earned per surviving unit per match) into specific
units. This makes level-up a deliberate act, not a passive accrual.

## Behavior patterns

A behavior pattern is a small, named program executed by the unit during a
match at decision nodes on the path graph. The vocabulary is small and
combinatorial; the player selects one or two per unit from an unlocked
list. Initial vocabulary draft (subject to phase-7 revision):

| Pattern   | Effect at decision node                                                    |
|-----------|----------------------------------------------------------------------------|
| Advance   | Take the path that progresses toward the enemy structure.                  |
| Hold      | If a friendly structure is in range, return to it and stand watch.         |
| Raid      | Prefer paths toward unclaimed treasure chests or mines.                    |
| Escort    | Stay within engagement radius of a chosen friendly unit.                   |
| Skirmish  | Engage enemies but retreat below 25% hp.                                   |
| Cautious  | Prefer paths with friendly support nearby; avoid lone advances.            |

Patterns are evaluated as a small fixed-point priority sum at each decision
node — not a chain of `if`s. The dispatch is a table per pattern producing
a score for each branch, summed across active patterns.

## The deck, between matches

- Add/remove unit (subject to deck size cap).
- Reorder cycling priority (which unit comes up first when slots free).
- Edit per-unit loadout (class within unlocked, equipment, patterns).
- View per-unit history (match count, kills, deaths, treasure carried).

## What "permadeath" means here

Permadeath is a per-campaign option, not a global toggle. In a permadeath
campaign, `cooldown_post_death = ∞` and the unit is gone. The player feels
the loss of leveling and equipment investment. In non-permadeath
campaigns, the unit returns after a long cooldown but with no penalty
beyond match-time absence.

## Why FE-inspired

Warcraft Rumble's units are cards. Fire Emblem's units are people. The
match layer in Symbeline Rumble is built like Warcraft Rumble's (path-
based, deck-cycling, no micro), but the meta-layer is built like Fire
Emblem's so that the player has someone to root for inside the match. The
two layers cohere because the units they describe are the same units.
