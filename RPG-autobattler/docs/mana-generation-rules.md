# Mana Generation Rules

How a unit's mana bars fill. The code is `src/systems/mana_system.lua`;
the numbers below are its constants, so change them there.

## The vision's rule

Each unit has one to four abilities, each with its own mana bar. When a bar
is full the ability is used. The **primary** ability (the first) always
gains mana. The others gain mana only when a condition holds:

- **ranged** units: while standing still, whether fighting or waiting
  behind the front;
- **melee** units: while a foe is in range, moving or not.

A full bar stays full until the ability finds a target. Nothing is wasted.

## Which units are which

| Unit type | Follows the rule for | Reach / shooting range |
|-----------|----------------------|------------------------|
| melee     | melee                | 12                     |
| tank      | melee                | 15                     |
| special   | melee                | 20                     |
| ranged    | ranged               | 30                     |
| support   | ranged               | 25                     |

The distances are the engagement ranges in `combat_detection_system.lua`.

## Rates

Each ability sets its own `mana_rate` (default 10 a second) and `max_mana`
(default 100). Unit templates will choose them.

| Situation | Primary | Secondary |
|-----------|---------|-----------|
| Always | x1 | - |
| Ranged-style, still for at least 0.25 s | x1 | x1 |
| ...with an enemy within shooting range | x1 | x1.2 |
| Melee-style, one enemy within reach | x1 | x1 |
| ...two or more enemies within reach | x1 | x1.15 |
| Otherwise | x1 | 0 |

- "Still" means moving slower than 0.1 pixels a second. Only time after
  the first quarter second counts, so a unit that pauses mid-walk gains
  nothing.
- Only living enemies count.
- A dead unit's bars empty.
