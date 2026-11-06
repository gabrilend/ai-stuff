# Game rules

The rules of the game as the simulation enforces them, gathered from
notes/vision and made precise enough to build. Numbers are not written here:
every knob lives in the configuration defaults (src/001-config.def.lua), and
the rules simulator (`./run-tests` and `./run-headless --report`) prints the
values actually in force. Changes to numbers are logged in
docs/balance-updates.md with the reason.

## 1. The shape of a match

1. A match is played on a campaign map of regions. Each side has a home region.
2. Before each round is a **command phase** (third person): the player picks a
   compass direction to push and one perk. The enemy commander picks too.
3. The round is fought in the region the push leads into. Its **battle phase**
   opens in third person: the contingents approach, the player throws volleys
   and raises shields for the whole contingent.
4. When the lines touch, the view drops into first person: the player becomes
   one frontline soldier while the rest of the contingent fights on its own,
   following the order given.
5. If the player's soldier falls, the view returns to third person and the
   player commands until the round ends.
6. A round ends when a contingent **breaks**. The winner's front advances into
   that region. Taking the enemy's home region wins the match.
7. Every soldier is **replenished** at the start of every round.

Third person and first person are equal halves of the game; neither is a menu
for the other.

## 2. Bodies and space

- The battlefield is a grid of cells; a cell holds at most one soldier.
- W A S D move the soldier relative to where it faces: forward, sidestep left,
  backstep, sidestep right.
- A soldier **cannot enter a cell held by an enemy**. Nobody can push anyone
  around.
- A soldier **may enter a cell held by an ally**, at half speed. The ally then
  steps the other way on its own, driven by its own dodge movement rather than
  by the player's input. (The more physical version, where the player pushes
  the ally, is refused on purpose: it lets players grief their own side.)
- A **dodge** (a quick step) can never end in an occupied cell.
- Thick armor slows walking.

## 3. Stamina, guarding and tripping

- Stamina runs from 1 to 0; fatigue is 1 minus stamina.
- Swinging, being parried, parrying, and dodging spend stamina. Standing,
  walking slowly and recovering restore it.
- Guarding (holding the parry stance) lets a soldier parry. At high stamina a
  parry almost always succeeds; the chance falls as fatigue rises.
- **Backstepping while fatigued trips** (fatigue above the trip threshold).
- **Sidestepping while guarding trips one time in four.** Only while guarding.
- A tripped soldier lies down for a moment: it cannot move, swing or guard.

## 4. The sword (first person)

- The weapon sits on a **U** drawn around the locked target. Moving the mouse
  moves the weapon along the U.
- The **lock** is always the nearest enemy. When the nearest changes, the lock
  takes half a second to move. The lock is what the player is looking at, and
  it changes before the next attack, so the enemy cannot tell which way the
  player is about to look.
- **Left click** swings from wherever the weapon is: from the left arm, a slash
  from the left; from the bottom, a stab; from the right arm, a slash from the
  right. The bend is wide, because most attacks are stabs: a battalion has no
  room for wide slashes.
- **Space** is the overhead: slower windup, longer recovery, extra damage if it
  lands, and it can still be parried.
- **Right click (held)** is the guard.
- Mouse look is free while the look key is held; otherwise the eyes follow the
  lock.
- There is no interface on screen at all: the player sees their arms and
  sword, the field, and the bodies. Awareness beyond the 90 degree view (out to
  160, less in heavy armor) is shown as warmth or chill at the screen edges:
  allies warm, enemies cold.

## 5. Hits, momentum and criticals

A swing that reaches its strike moment with its target in reach and in front
of the attacker connects, unless the target parries.

- **Momentum** is the sum of two things: how fast the attacker was moving
  toward the target (body inertia), and the swing pattern — a swing from the
  side opposite the last one flows and adds momentum; the same side again
  stalls and adds none; a stab after a slash adds a little.
- **Critical hits** deal extra damage. A swing is critical when its momentum
  passes the critical threshold, or when it is a **flanked** solid connect
  (the attacker stands more than 90 degrees off the target's facing), or when
  a unit trait says it always is. Crit chance (from perks) is a further roll.
- **Armor** takes a percentage off the damage after criticals are applied.
- Health at zero: the soldier falls and leaves the field (its cell is freed).

## 6. Third-person command

- **Left click** throws a volley from the whole contingent. The arc is always
  the same, because everyone trained the same way and nobody can see how far
  the enemy is: it lands three battalion lengths ahead of the front rank. The
  late perk "trained arc" lets the player pick range 1, 2 or 3.
- **Right click (held)** raises shields. Shields add a bonus to parry, larger
  against volleys, but the contingent walks slower behind them.
- The push direction picked in the command phase steers the contingent's
  advance. A battalion that meets enemies engages; otherwise it walks.

## 7. Perks and unit types

Perks are picked one per round. Some apply to everyone, some to "a certain
number of guys". For those, the player is asked whether to be one of them; if
no such unit is ready, the player is a normal soldier.

Starter catalogue (all data, in the catalogue folder, moddable):

| Name | What it does |
| --- | --- |
| mega spearman | maximum armor rating +1 (the +1 is its shield); stabs only |
| beastwarrior | huge and tall; every hit is critical; may guard while walking forward |
| skirmisher | throws from the front rank if the enemy is not too close, then falls back through loose formation |
| halberds | longer reach, slashes stronger |
| riposte | a successful parry is followed at once by a counter-stab |
| harry | the battalion attacks then steps back as a group, in and out |
| trained arc | volleys may be thrown at range 1, 2 or 3 |
| thick armor | +2 armor points, slower walk |
| bushido | for armies without good armor: parry chance falls more slowly with fatigue |

The first release is two-handed swords only; spears, hammers, glaives,
halberds, pikes, horses and archers are catalogue entries for an expansion.
