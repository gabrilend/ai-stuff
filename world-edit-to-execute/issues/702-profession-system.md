# Issue 702: Profession System

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** High
**Dependencies:** 402 (ECS), 406 (Resources), 701 (Death - for skinning)

---

## Current Behavior

No profession or crafting system exists. Units cannot gather resources beyond
basic WC3 harvesting, cannot craft items, and have no skill progression for
production activities.

---

## Intended Behavior

A unified profession system that serves both:
- **WoW-Chat Playerbots**: Full MMO-style professions with skill levels, recipes, specializations
- **WC3 Units**: Simplified gathering/production mapped to existing unit abilities

The abstraction layer allows the same profession engine to power both contexts,
with different configurations and UI presentations.

---

## Design Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROFESSION ENGINE                            │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   Gatherer   │    │   Crafter    │    │   Service    │      │
│  │              │    │              │    │              │      │
│  │ - Mining     │    │ - Smithing   │    │ - Repair     │      │
│  │ - Herbalism  │    │ - Alchemy    │    │ - Enchant    │      │
│  │ - Skinning   │    │ - Tailoring  │    │ - Transport  │      │
│  │ - Lumber     │    │ - Engineering│    │ - Healing    │      │
│  │ - Fishing    │    │ - Cooking    │    │              │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌─────────────────────────────────────────────────────┐       │
│  │              SKILL & RECIPE SYSTEM                  │       │
│  │  - Skill levels (1-300, 1-450, or 1-5 simplified)   │       │
│  │  - Recipe unlocks at thresholds                     │       │
│  │  - Success/failure chances                          │       │
│  │  - Skill-up on successful actions                   │       │
│  └─────────────────────────────────────────────────────┘       │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         ▼                  ▼                  ▼                │
│  ┌────────────┐    ┌────────────┐    ┌────────────┐           │
│  │ WoW Config │    │ WC3 Config │    │ Custom     │           │
│  │            │    │            │    │            │           │
│  │ 300 skill  │    │ 5 levels   │    │ User-def   │           │
│  │ Full UI    │    │ Ability UI │    │ Modular    │           │
│  │ Trainers   │    │ Research   │    │            │           │
│  └────────────┘    └────────────┘    └────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Mapping: WoW ↔ WC3

| WoW Profession | WC3 Equivalent | Shared Abstraction |
|----------------|----------------|-------------------|
| Mining | Gold Mine harvesting | `gather:mineral` |
| Herbalism | (none - could add) | `gather:plant` |
| Skinning | (corpse loot) | `gather:corpse` |
| Lumber (not WoW) | Lumber harvesting | `gather:wood` |
| Fishing | (none - could add) | `gather:water` |
| Blacksmithing | Armory upgrades | `craft:metal` |
| Leatherworking | (none) | `craft:leather` |
| Tailoring | (none) | `craft:cloth` |
| Alchemy | Alchemist shop | `craft:potion` |
| Engineering | Workshop/Factory | `craft:mechanical` |
| Enchanting | Arcane upgrades | `service:enchant` |
| Cooking | (none - could add) | `craft:food` |
| First Aid | Priest healing | `service:heal` |
| Repair | Peasant repair | `service:repair` |

---

## Suggested Implementation Steps

See sub-issues:
- **702a**: Core profession component and skill system
- **702b**: Gathering professions (mining, herbalism, skinning, lumber, fishing)
- **702c**: Crafting professions (smithing, alchemy, engineering, etc.)
- **702d**: Recipe and schematic system
- **702e**: WoW-mode configuration (full skill levels, trainers)
- **702f**: WC3-mode configuration (ability-based, research unlocks)
- **702g**: Profession UI abstraction layer

---

## Related Documents

- issues/406-build-resource-management-system.md (resource storage)
- issues/701-death-and-resurrection-system.md (corpses for skinning)
- issues/015-wow-style-combat-system.md (stat interactions)
- WoW profession guides for formula reference

---

## Acceptance Criteria

- [ ] Profession component can be added to any entity
- [ ] Skill levels track progress (configurable max)
- [ ] Gathering actions produce resources
- [ ] Crafting consumes resources and produces items
- [ ] Recipes unlock at skill thresholds
- [ ] WoW mode: full 1-300+ skill progression
- [ ] WC3 mode: simplified 1-5 or ability-based
- [ ] Events fire for skill-ups and crafting
- [ ] Unit tests for skill calculations

---

## Notes

The key insight is that WoW professions and WC3 unit abilities are the same
thing at different granularities:

- WC3 Peasant "Repair" = WoW Engineering (very simplified)
- WC3 Peasant "Gather" = WoW Mining + Lumberjacking combined
- WC3 Acolyte "Sacrifice" = A dark profession indeed

By building the engine to be configurable, the same code powers:
1. A WoW-chat bot grinding mining skill 1→300
2. A WC3 peasant chopping trees efficiently
3. A custom game with unique profession mechanics

The profession system also enables interesting cross-pollination:
- WC3 maps with WoW-style crafting progression
- WoW bots that operate like RTS workers
