# Issue 005: Class and Gem System Design

**Phase:** None (Long-term Research)
**Type:** Design Research
**Priority:** High
**Parent:** 000-warlord-mode-design-compendium.md

---

## Purpose

Deep exploration of the class structure and gem-based progression system. This document focuses on build diversity, horizontal progression, and the interplay between combat and crafting roles.

---

## Class Structure

### Four Classes, Faction Paired

```
Horde:
- Grunt: Melee warrior, gathering specialist
- Shaman: Caster, production specialist

Alliance (Night Elf):
- Huntress: Melee warrior, gathering specialist
- Druid: Caster, production specialist
```

### Class Parity

```
Grunt ↔ Huntress
- Similar combat capabilities
- Different flavor/animations
- Same role in faction economy

Shaman ↔ Druid
- Similar casting capabilities
- Different elemental themes
- Same role in faction economy
```

### Elemental Themes

```
Horde (Shaman):
- Storm: Lightning damage, chain effects
- Earth: Physical damage, defense buffs
- Fire: Burst damage, damage over time

Alliance (Druid):
- Leaf: Nature damage, healing over time
- Cold: Slow effects, shatter combos
- Star: Arcane damage, mana effects
```

---

## Role Differentiation

### Warriors (Grunt/Huntress)

```
Combat strengths:
- High parry baseline
- Strong melee damage
- Tanking capability
- Front-line presence

Profession strengths:
- Gathering efficiency
- Mining/skinning/herbalism bonuses
- Can fight through hostile nodes
- Material transport (inventory space)

Weaknesses:
- Low magic resistance
- Single-target focused
- Limited utility
- Dependent on healers
```

### Casters (Shaman/Druid)

```
Combat strengths:
- Ranged damage
- Area effects
- Support auras
- Elemental versatility

Profession strengths:
- Production efficiency
- Crafting bonuses
- Enchanting/gem-cutting
- Elemental summoning

Weaknesses:
- Fragile in melee
- Cast times interruptible
- Mana dependent
- Need warrior protection
```

---

## Level System

### Compressed Levels

```
Starting level: 10
Level cap: 20
Total levels to earn: 10

Design intent:
- Quick to reach cap
- Focus on specialization, not power
- All levels "useful" (no dead levels)
```

### Level Progression

```
Each level grants:
- 1 ability point (choose new ability)
- Access to new gem sockets (staggered)
- Slight stat increase (minimal)

Level 10 (start):
- Basic attacks
- 1 ability
- 2 gem sockets

Level 15 (mid):
- 6 abilities
- 4 gem sockets
- Role defined

Level 20 (cap):
- 11 abilities
- 6 gem sockets
- Fully specialized
```

### No Power Treadmill

```
Level 20 is not "stronger" than level 10:
- Different, not better
- More options, not more power
- A group of 10s can defeat a 20
- Specialization matters more than level
```

---

## Uniform Equipment

### Faction Uniforms

```
Everyone wears same base gear:
- Horde: Grunt/Shaman uniforms
- Alliance: Huntress/Druid uniforms

No "better" gear drops:
- No item level
- No rarity tiers (for armor)
- No farming for upgrades
- Equipment is standard issue
```

### Socket System

```
Uniform pieces have sockets:

Helm: 1 socket
Chest: 2 sockets
Legs: 1 socket
Weapon: 2 sockets

Total: 6 sockets per character
Each socket holds one gem
```

---

## Gem Categories

### Combat Gems

```
Offensive:
- Flat damage increase per hit
- Proc damage on hit count
- Damage type conversion
- Critical strike effects

Defensive:
- Parry bonuses
- Damage shields
- Health regeneration
- Damage reduction

Utility:
- Movement speed
- Attack speed
- Crowd control effects
- Vision/detection
```

### Crafting Gems

```
Production:
- Craft bonus items
- Quality improvements
- Random enchantment procs
- Material efficiency

Summoning:
- Elemental cost reduction
- Summon bonuses
- Duration extensions
- Support drone additions

Gathering:
- Yield bonuses
- Speed bonuses
- Rare find chance
- Inventory expansion
```

---

## Gem Examples (Expanded)

### Offensive Gems

```
Tier 1 (Common):
- Ember: +3 fire damage per hit
- Spark: +3 lightning damage per hit
- Frost: +3 cold damage per hit

Tier 2 (Uncommon):
- Inferno: Every 3rd hit deals +15 fire damage
- Thunder: Every 3rd hit chains to nearby enemy
- Glacier: Every 3rd hit slows target 20%

Tier 3 (Rare):
- Volcanic: Hits below 30% HP deal double fire damage
- Tempest: On killing blow, chain lightning to 3 enemies
- Permafrost: Slowed enemies take 25% more damage

Tier 4 (Epic):
- Phoenix: On death, resurrect with 30% HP (10 min CD)
- Storm Lord: Lightning hits increase attack speed 5%
- Absolute Zero: Frozen enemies shatter for massive damage
```

### Defensive Gems

```
Tier 1 (Common):
- Stone: +5 armor
- Bark: +3 HP per 5 seconds
- Shell: +2% parry

Tier 2 (Uncommon):
- Fortress: Damage shield absorbs 15 damage every 10s
- Regrowth: +5 HP per 5 seconds
- Deflector: +4% parry, reflects 5 damage on parry

Tier 3 (Rare):
- Bulwark: When below 30% HP, +20% parry
- Lifebloom: Healing received increased 15%
- Retaliation: Parry reflects 30% of attack damage

Tier 4 (Epic):
- Immortal Shell: First death per day prevented (1 HP)
- Nature's Embrace: Low HP triggers heal over time
- Perfect Defense: Every 5th parry stuns attacker
```

### Synergy Examples

```
Berserker Build:
- Spark (attack speed bonus with Berserker's Tempo)
- Thunder (chain on hit maintains momentum)
- Tempest (kill rewards more chains)

Tank Build:
- Fortress (absorb damage)
- Deflector (parry value)
- Retaliation (punish attackers)

Support Build:
- Bark (self-sustain)
- Regrowth (extended fights)
- Lifebloom (receive heals effectively)
```

---

## Crafting Integration

### Gem Sources

```
Gems come from:
- Prospecting ores (chance to find gems)
- Crushing gems (lower tier → dust → new gems)
- Quest rewards (specific gems)
- Raid loot (rare/epic gems)
- Elemental summoning (gem-producing elementals)
```

### Gem Crafting

```
Casters can:
- Cut raw gems into usable gems
- Combine gems (3 Tier 1 → 1 Tier 2, random)
- Crush gems into arcane dust
- Use dust for enchantments

Quality bonuses:
- Crafting gems improve quality
- Higher quality = stronger effect
- Caster reputation matters
```

### Equipment Crafting

```
Warriors bring materials
Casters craft equipment
Everyone wears same base stats
BUT: Crafted by better caster = better quality

Quality affects:
- Socket count (base 6, quality can add 7th)
- Durability
- Aesthetic appearance
- Nothing else (no stat bonuses)
```

---

## Prestige System

### Becoming a Guard

```
At level 20, option to prestige:
- Character becomes NPC guard
- Guards faction capital
- Retains gem configuration
- Personality quirks from play history

Guard behavior:
- Defends hub
- Uses player's ability choices
- Visible to all players
- Can die (permanent)
```

### Guard Legacy

```
When your guard dies:
- Notification sent to you
- Memorial entry in hall
- Gem drops (returned to you)
- Slot opens for new guard

Incentive:
- Guards with good builds survive longer
- Prestige for long-lived guards
- Faction benefits from strong guards
```

### Prestige Rewards

```
For prestiging:
- Cosmetic unlock for new characters
- Title/achievement
- Increased reputation with faction
- Priority for raid assignments

For guard survival:
- Ongoing reputation trickle
- Guard "promotes" after X days
- Elite guards have special abilities
```

---

## Build Philosophy

### Horizontal Progression

```
Goal: Many viable builds, none "best"

Achieved through:
- Gem synergies (combinations matter)
- Role diversity (tank/dps/support all needed)
- Situational value (frost good vs fire weak enemies)
- Team composition (builds complement each other)
```

### Anti-Meta Design

```
Prevent "one true build":
- Rock-paper-scissors counters
- Encounter variety
- Nerf nothing, buff alternatives
- Community showcases of unusual builds
```

### Respec Cost

```
Changing gems:
- Gems can be removed (not destroyed)
- Reinserting costs arcane dust
- Encourages commitment but allows change
- Alt characters are cheap (same gear)
```

---

## Open Questions

1. Should gems have durability?
2. Can gems be traded between players?
3. How rare should epic gems be?
4. Should some gems be faction-specific?
5. Can guards use gems that players can't normally get?

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-30 | Initial document |
