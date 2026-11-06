# Glossary

The core terms of the project. Every other document, issue and source comment
uses these words with exactly these meanings; when a word here changes, the
change is made here first.

## People and groups

- **soldier** — one body on the field. Every soldier, the player's included,
  is the same kind of record: a position, a facing, a weapon held somewhere on
  its U, a stamina value, a health value, an armor rating, a team and a
  battalion. The player is a soldier with a hand on it.
- **battalion** — a block of soldiers who move and fight as one formation
  (the default is 4 wide by 3 deep). Formation spacing is one cell per
  soldier.
- **contingent** — everything one side brings to a round: all of its
  battalions. The player commands the whole contingent in third person and
  fights as one soldier of it in first person.
- **commander** — the player, in third person. Same person as the frontline
  soldier; two seats, one mind.

## The field

- **cell** — one square of the battlefield grid, about one soldier wide
  (1.2 m). A cell holds at most one soldier. Occupancy is what the rules about
  "moving into an occupied space" are written against.
- **battlefield** — the grid of cells a round is fought on, with its edges.
- **battalion length** — the distance unit for ranged weapons: the depth of a
  battalion plus the gap behind it. Ranged weapons are thrown "at range 3",
  meaning three battalion lengths away.
- **compass direction** — one of the eight directions N, NE, E, SE, S, SW, W,
  NW. Each round the contingent is ordered to push one of them.
- **region** — one square of the campaign map. Each round is fought in the
  region the attacker pushed into.

## The sword

- **U** — the track the weapon rests on. Picture a letter U drawn around the
  locked target: the left arm, the bottom bend, the right arm. Where the
  weapon sits on the U decides what a swing does: the arms make slashes from
  that side, the bend makes a stab. The position along it is one number from
  -1 (top of left arm) through 0 (bottom of the bend) to +1 (top of right arm).
- **lock** — the enemy the U is drawn around. Always the nearest enemy; when a
  nearer one appears the lock takes half a second to move to it.
- **swing** — one attack: a stab, a slash or an overhead. Each has a windup
  (committed, interruptible only by being hit), a strike moment, and a
  recovery.
- **overhead** — the special swing from above (space bar). Slower, leaves the
  attacker open, deals extra damage, can still be parried.
- **guard** — holding the parry stance. While guarding a soldier may parry an
  incoming swing; the chance falls as fatigue rises.
- **parry** — a guarded soldier turning a swing aside. A parried swing deals no
  damage and costs both soldiers stamina.

## The body

- **stamina** — how much the body has left, from 1 (fresh) to 0 (spent).
  Actions spend it, rest restores it.
- **fatigue** — 1 minus stamina. The vision speaks in both words; the code
  stores stamina and derives fatigue.
- **trip** — falling down. Happens when backstepping while fatigued, and one
  time in four when sidestepping while guarding. A tripped soldier lies for a
  moment and cannot guard.
- **momentum** — how much the body and the blade are carrying into a swing:
  the speed toward the target, plus the flow of the swing pattern (alternating
  sides flows, repeating a side stalls).
- **critical hit** — a hit dealing extra damage. Earned by momentum, by
  flanking, or by unit traits.
- **flank** — striking a soldier from beyond its sides (more than 90 degrees
  off where it faces). A flanked solid connect is always a critical hit.
- **armor** — a percentage taken off every hit. Two tracks: armor rating
  (how much is taken off) and thickness (thin, or thick for two more points at
  a slower walk). Armor also narrows awareness.
- **awareness** — the 160 degree arc a soldier knows about without turning;
  the screen shows only 90 degrees, and the rest is felt at the screen edges.
  Armor narrows it.

## The round

- **match** — a sequence of rounds that ends when one side takes the other's
  home region.
- **round** — one battle. A round has a command phase and a battle phase, and
  ends when one contingent breaks.
- **command phase** — between rounds: pick the compass direction to push and
  one perk. Third person.
- **battle phase** — the fight. It opens in third person (approach, volleys,
  shield wall) and switches to first person when the lines touch.
- **volley** — a thrown ranged attack by the whole contingent (left mouse in
  third person). Always lands at range 3 unless the late perk is owned.
- **shield wall** — the contingent raising shields (right mouse in third
  person). Shields help parry, especially against volleys.
- **break** — a contingent breaks when a quarter or less of it is still
  standing. The other side wins the round.
- **replenish** — every soldier is restored at the start of each round.

## Growth

- **perk** — one upgrade picked in a command phase. Some apply to all
  soldiers, some to a stated number of them; for those, the player always
  chooses whether to be one of the affected.
- **unit type** — a kind of soldier: two-handed swordsman (the base), mega
  spearman, beastwarrior, skirmisher. Unit types and perks are data files, so
  they can be modded.
- **catalogue** — the data files that define unit types, weapons and perks.

## The program

- **tick** — one fixed step of the simulation (1/60 s). Everything that
  happens, happens on a tick.
- **receipt** — the goodbye note written to output/goodbye as the program's
  last act, carrying the run's seed and counts.
- **script** — a timeline of input given on the command line (--key, --click,
  --screenshot, --quit), sent through the same handlers a person's input uses.
- **seed** — the one number every random stream is derived from. Same seed and
  same script give the same battle.
