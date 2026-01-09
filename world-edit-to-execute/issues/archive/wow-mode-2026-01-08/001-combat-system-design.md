# Issue 001: Combat System Design

**Phase:** None (Long-term Research)
**Type:** Design Research
**Priority:** High
**Parent:** 000-warlord-mode-design-compendium.md

---

## Purpose

Deep exploration of the rhythmic parry-based combat system. This document focuses on the mechanical interactions, feel, and emergent gameplay created by the parry/tempo design.

---

## Core Mechanic: The Parry Dance

### Base State

```
All characters:
- 95% base parry chance
- 2.00 second attack speed (standardized)
- Parry: -5% parry chance
- Hit taken: parry recovers halfway to 95%
```

### Mathematical Flow

```
Example combat sequence:

Turn 1: Defender at 95% parry
        Attacker swings → 95% chance to parry
        Result: PARRY
        Defender now at 90%

Turn 2: Defender at 90% parry
        Attacker swings → 90% chance to parry
        Result: PARRY
        Defender now at 85%

Turn 3: Defender at 85% parry
        Attacker swings → 85% chance to parry
        Result: HIT
        Defender recovers: 85% + (95%-85%)/2 = 90%

Turn 4: Defender at 90% parry
        ...cycle continues...
```

### Expected Hits Per Cycle

```
Starting at 95%, expected parries before first hit:
- 95% × 90% × 85% × 80% × ...

Average: ~4-6 parries before hit lands
At 2.0s per attack: 8-12 seconds per hit

This is SLOW. Intentionally so.
Combat is readable, strategic, not twitch.
```

---

## The Learning Model

### Philosophical Basis

Each parry/hit represents learning:

```
PARRY (defender succeeds):
- Defender "used up" defensive attention
- Parry chance drops 5%
- Attacker observes the defense pattern

HIT (attacker succeeds):
- Defender "learned" from the blow
- Parry recovers halfway to max
- Maximum attention renewed

Combat as conversation:
- Each exchange teaches both fighters
- Parry spam depletes defender's edge
- Successful hits reset the dynamic
```

### The Parry Floor

Current parry drops by 5% per parry, but what's the floor?

```
Option A: No floor
- Parry can reach 0%
- Defender eventually helpless
- Death spiral once low

Option B: Floor at 50%
- Minimum parry chance
- Defender always has some chance
- Stalemates possible

Option C: Floor based on current HP
- Low HP = low parry floor
- Wounded fighters more vulnerable
- Heals restore defensive ceiling

Recommendation: Option C
- Creates meaningful HP interaction
- Heals become defensive as well as health
- Wounded state is tactically distinct
```

---

## Tempo Items and Abilities

### Berserker's Tempo (Legendary Weapon)

```
Effect:
- On hit: +10% attack speed (stacks 5x, max +50%)
- On parry: attack speed halved

Interaction with parry system:
- Hit → you speed up, they recover parry
- Parry → you slow down, their parry drops
- Self-balancing: faster attacks face recovered defense
```

### Guaranteed-Hit Abilities

```
"Your next strike has 100% chance to hit"

Strategic value:
- Extends tempo streaks
- Burns through parry recovery
- Costly (usually ability slot)

Counter-cost:
- Gives enemy full parry recovery
- Doesn't benefit from low-parry windows
- Sometimes worse than normal attack
```

### Parry-Reduction Abilities

```
"Your next strike reduces target parry by 10%"

Strategic value:
- Opens window for follow-up
- Synergizes with team attacks
- Enables berserker to start fresh

Team combo:
1. Support uses parry-reduction
2. Berserker attacks low-parry target
3. Hits land, tempo builds
4. Defender can't recover fast enough
```

---

## Next-Swing Ability Design

### Principles

```
All melee abilities:
- Queue on next weapon swing
- Don't interrupt attack rhythm
- Visible "wind-up" for counterplay
- One ability per swing (no stacking)
```

### Example Ability Set

```
Offensive:
- Power Strike: Next hit deals 130% damage
- Cleave: Next hit splashes 2 targets for 20%
- Rend: Next hit applies bleed (damage over time)

Defensive:
- Riposte: If next attack is parried, counter for 50%
- Guard: Next parry restores 5% more parry chance
- Deflect: Next parry reflects 30% damage

Utility:
- Hamstring: Next hit slows target 20% for 5s
- Disarm: Next hit has 20% chance to disarm
- Expose: Next hit reduces target parry by 10%
```

### Ability Timing

```
Abilities queued before swing:
- Visual indicator (glow, stance change)
- Enemy can read and respond
- Creates prediction game

Example mind-game:
- Attacker queues Power Strike
- Defender sees it, queues Riposte
- If parry: Riposte triggers, attacker hurt
- If hit: Power Strike triggers, extra damage
- Both players chose before outcome known
```

---

## Caster Combat Integration

### Ground-Target Cone Spells

```
Targeting:
- Click location on ground
- Thin cone fires toward that point
- Hits first enemy in cone path

Why this design:
- Skillshot element (aim matters)
- Readable for RTS observation
- Can miss, creating counterplay
```

### Spell Tempo

```
Casters have different rhythm:
- Cast time replaces attack speed
- Spells don't interact with parry (magic)
- But cast can be interrupted (silence, stun)

Hybrid balance:
- "Next melee strike doubles cast speed"
- Melee creates windows for casting
- Casters need melee support to function
```

---

## Group Combat Dynamics

### Focus Fire

```
Multiple attackers vs one defender:
- Each attacker has independent parry check
- Defender's parry drops with each parry
- More attackers = faster parry drain
- Defender can't parry all at once

Result: Focus fire is effective
But: Requires coordination (all attack same target)
```

### Healer Role

```
Healer functions:
1. Restore HP (obvious)
2. Restore parry ceiling (less obvious)

When ally is low parry:
- Even if parry succeeds, ceiling is low
- Recovery only goes halfway to current max
- Max based on HP (if using Option C)
- Heal → restore HP → restore ceiling
```

### Tank Role

```
Tank functions:
1. Absorb attacks (parry spam)
2. Draw aggro from AI enemies
3. Buy time for parry recovery

Tanks can be built for:
- High base parry (gem: +5% baseline)
- Parry recovery (gem: parry restores +2%)
- Damage reflection (gem: thorns damage)
```

---

## Audio Feedback

### Combat Soundscape

```
Each 2-second beat:
- SWING: Whoosh sound
- PARRY: Metal clang, high pitch
- HIT: Thud/impact, lower pitch
- CRIT: Emphasized hit sound

Tempo changes:
- Speed increase: Rising pitch, faster rhythm
- Speed decrease: Lower pitch, slower rhythm
- Berserker at max stacks: Intense, rapid audio
```

### Ability Cues

```
Ability queue:
- Distinct sound when queued
- Visual + audio for enemy awareness
- Different sounds per ability type

Example:
- Power Strike queue: Low rumble
- Riposte queue: High chime
- Cleave queue: Sweeping wind
```

---

## Open Questions

1. Should parry chance be visible to opponent?
2. How do ranged attacks interact with parry?
3. Can abilities cancel queued abilities?
4. What happens to tempo stacks on target switch?
5. How do crowd control effects (stun, root) interact?

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document |

---

## Sub-Issue Analysis

*Generated by Claude Code on 2026-01-02 15:45*


