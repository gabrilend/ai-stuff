# Issue 015: WoW-Style Combat & Stat System

## Current Behavior

The guild hero system uses simplified WC3-style stats (strength, agility, intelligence, endurance). These are sufficient for quest tracking but don't model combat mechanics.

## Intended Behavior

Implement a WoW-style combat system with:
- Primary attributes (Strength, Agility, Stamina, Intellect, Spirit)
- Secondary stats (Attack Power, Spell Power, Crit, Haste, etc.)
- Resource systems (Health, Mana, Rage, Energy, etc.)
- Armor and damage reduction formulas
- Combat calculations (physical damage, spell damage, healing)

## Suggested Implementation Steps

### Phase 1: Primary Stats
- [ ] Define WOW_PRIMARY_STATS constant
- [ ] Implement stat->derived stat conversions
- [ ] Add class/spec modifiers for stat weights

### Phase 2: Secondary Stats
- [ ] Define WOW_SECONDARY_STATS constant
- [ ] Implement rating->percentage conversions
- [ ] Add diminishing returns formulas

### Phase 3: Resource Systems
- [ ] Implement Health (Stamina * 10)
- [ ] Implement Mana (Intellect * 15)
- [ ] Implement class-specific resources (Rage, Energy, Runic Power, Focus)
- [ ] Add resource regeneration mechanics

### Phase 4: Combat Calculations
- [ ] Implement armor reduction formula
- [ ] Implement physical damage calculation
- [ ] Implement spell damage calculation
- [ ] Implement healing calculation
- [ ] Add crit/hit/miss mechanics

### Phase 5: Combat Simulation
- [ ] Create CombatLog class for tracking events
- [ ] Implement basic attack sequence
- [ ] Implement spell cast sequence
- [ ] Add buff/debuff system
- [ ] Create combat test arena

## Related Documents

- `src/guild/hero.lua` - Contains FIXME placeholders for WoW stats
- `src/runtime/ecs/wc3_components.lua` - ECS components (may need WoW variants)
- WoWWiki/Wowpedia documentation on stat formulas

## Acceptance Criteria

- [ ] Primary stats affect derived combat stats correctly
- [ ] Armor reduces physical damage per WoW formula
- [ ] Spell power affects spell damage with proper coefficients
- [ ] Resource generation and consumption works
- [ ] Combat log tracks all damage/healing events
- [ ] Test coverage for all formulas

## Notes

### WoW Stat Formulas (Vanilla/Classic Reference)

**Armor Reduction:**
```
reduction = armor / (armor + 400 + 85 * attacker_level)
```

**Attack Power to DPS:**
```
dps_bonus = attack_power / 14
```

**Spell Power Coefficient:**
```
coefficient = min(cast_time / 3.5, 1.0)  -- For damage spells
coefficient = min(cast_time / 3.5, 1.0) * 0.5  -- For DoTs (per tick)
```

**Crit Chance from Agility (Rogue):**
```
crit_percent = agility / 29
```

**Mana from Intellect:**
```
mana = 15 * intellect  -- After first 20 intellect
```

**Health from Stamina:**
```
health = 10 * stamina  -- After first 20 stamina
```

### Resource Generation

| Class | Resource | Generation |
|-------|----------|------------|
| Warrior | Rage | Damage dealt/taken |
| Rogue | Energy | 20/sec |
| Druid (Cat) | Energy | 20/sec |
| Mage | Mana | Spirit regen |
| Hunter | Focus | 5/sec + Steady Shot |
| Death Knight | Runic Power | Rune abilities |

---

**Status:** Pending
**Priority:** Low (enhancement for combat-focused gameplay)
**Dependencies:** Issue 014 (Guild Hero System)
