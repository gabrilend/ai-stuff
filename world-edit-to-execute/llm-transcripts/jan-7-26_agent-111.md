# Conversation Summary: agent-a3ee0f9

Generated on: Tue Dec 30 09:35:07 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Explore the WoW-related design documents and systems in this codebase. Look for:

1. Any existing WoW mode or WoW-style design documents in issues/ or docs/
2. The guild/hero system in src/guild/
3. Any profession or skill-related designs (issue 702, etc.)
4. How the project handles dual WC3/WoW mode systems

I need to understand what WoW patterns already exist so we can extend the
resource system appropriately.

--------------------------------------------------------------------------------

### Assistant Response 1

Perfect! Now I have a complete understanding. Let me compile my findings into a
comprehensive report:

## WoW-Related Design & System Patterns - Complete Analysis

Based on my exploration of the codebase, here's what I found regarding WoW
patterns and the resource system:

## 1. **Existing WoW-Mode Architecture**

The project has a sophisticated **dual WC3/WoW mode system** already designed:

**Issue 015: WoW-Style Combat System**
- Defines WoW primary attributes (Strength, Agility, Stamina, Intellect, Spirit)
- Secondary stats (Attack Power, Spell Power, Crit, Haste, etc.)
- Class-specific resource systems (Health, Mana, Rage, Energy, etc.)
- Includes WoW vanilla/classic formulas for damage calculation and stat conversions

**Issue 016: Attribute Getter/Setter System (9 sub-issues)**
- Core attribute registry (016a) - schema definitions, type system
- Dispatch table getters/setters (016b-c) - efficient attribute access
- Modifier stack system (016d) - base + equipment + buffs + auras
- Derived attribute engine (016e) - dependency graphs, lazy evaluation
- **WC3 config (016f)** - Strength/Agility/Intelligence with hero classes
- **WoW config (016g)** - Full primary/secondary stat system with ratings
- **Cross-system mapping (016h)** - Bidirectional conversion between WC3 ↔ WoW attributes

## 2. **Guild/Hero System (Existing Implementation)**

`src/guild/` contains a WC3-inspired system:

**Hero System** (`hero.lua`):
- Level progression (1-25) with XP thresholds
- WC3-style base stats (Strength, Agility, Intelligence, Endurance)
- **Contains FIXME comments** for WoW stats that should be integrated
- 6-slot inventory (WC3-like)
- Equipment system (weapon, armor, accessory)
- Quest/bounty tracking with capability unlocking

**Item System** (`items.lua`):
- Equipment with stat bonuses
- Consumables with various effects
- Rarity system (Common through Legendary)
- Quest items and soulbound equipment

**Shop System** (`shop.lua`):
- Marketplace for buying/selling items
- Discount types and pricing

## 3. **Profession System (Issue 702 - Ready to Implement)**

Comprehensive design for WoW-style professions that also maps to WC3:

**Issue 702a: Profession Core Component**
- Skill levels (configurable max: 300 for WoW, 5 for WC3)
- Primary/secondary profession slots (WoW: 2 primary + unlimited secondary)
- Skill-up chances based on recipe difficulty
- Events for skill progression

**WoW ↔ WC3 Mapping:**
| WoW | WC3 | Shared |
|-----|-----|--------|
| Mining | Gold Mine harvesting | `gather:mineral` |
| Herbalism | (none) | `gather:plant` |
| Skinning | Corpse loot | `gather:corpse` |
| Blacksmithing | Armory upgrades | `craft:metal` |
| Alchemy | Alchemist shop | `craft:potion` |
| Engineering | Workshop/Factory | `craft:mechanical` |

## 4. **Resource Management System (Issue 406 - FULLY IMPLEMENTED)**

The resource system is **already complete** with:

**Core Storage (406a)** - ✅ Implemented:
- Standard WC3 resources: gold, lumber, food_used, food_cap
- Per-player resource tracking with clamping
- Event firing on resource changes
- Custom resource registration for map-specific mechanics

**Spending Validation (406b)** - ✅ Implemented:
- `can_afford(cost_table)` with food cap checking
- `spend()` with atomic all-or-nothing semantics
- `refund()` for cancelled operations
- Cost arithmetic (add_costs, multiply_cost)

**Food & Harvesting (406c)** - ✅ Implemented:
- `add_food_supply()` / `remove_food_supply()` for building production
- `add_food_used()` / `remove_food_used()` for unit consumption
- `deposit_harvest()` with upkeep modifier application
- `deplete_gold_mine()` with low-warning events
- Upkeep system: none (0-50 food) = 100%, low (51-80) = 70%, high (80+) = 40%
- Income rate system for custom maps

**Location:** `/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/src/runtime/resources.lua` (805 lines)

## 5. **How to Extend Resource System for WoW Patterns**

Based on the existing architecture, here's how resources would integrate with
WoW systems:

**Potential WoW-specific resources:**
1. **Crafting Materials** - Mine ore, harvest herbs, skin leather
   ```lua
   resources.register_type("copper_ore", { max = 200, default = 0 })
   resources.register_type("tin_ore", { max = 200, default = 0 })
   resources.register_type("wool_cloth", { max = 200, default = 0 })
   ```

2. **Profession XP/Skill tracking** - Could be layered on top via attributes
(Issue 016g config)

3. **Reputation resources** - Different faction standing
   ```lua
   resources.register_type("faction_reputation", { max = 999999, default = 0 })
   ```

4. **Currencies** - Badges, tokens, etc.
   ```lua
   resources.register_type("conquest_points", { max = 99999, default = 0 })
   resources.register_type("valor_points", { max = 99999, default = 0 })
   ```

## 6. **Key Design Patterns Already in Place**

1. **Dispatch Tables over Conditionals** (Issue 016)
   - Used for attribute getters/setters
   - Efficient lookup with numeric indexes

2. **Config-Driven Systems**
   - WC3 config defines primary stats and formulas
   - WoW config defines ratings and conversions
   - Easy to switch between game modes

3. **Event-Driven Architecture**
   - Resource changes fire events
   - Professions fire skill-up events
   - Allows decoupling of systems

4. **Modifier Stacks** (Issue 016d)
   - Base values + equipment bonuses + buffs + auras
   - Source tracking for removal

5. **Separation of Concerns**
   - Attributes (stats) in Issue 016
   - Resources (economy) in Issue 406
   - Professions (progression) in Issue 702

## 7. **Integration Points**

To connect WoW patterns with the resource system:

1. **Profession recipes cost resources:**
   ```lua
   -- Recipe: Smelt Copper Ore -> Copper Bar
   local recipe = {
       inputs = { copper_ore = 5 },
       outputs = { copper_bar = 1 },
       skill_required = 1,
   }
   ```

2. **Resource gathering increases profession skill:**
   - Mining ore → increases Mining skill
   - Apply skill-up chance from Issue 702a

3. **Attributes affect crafting success:**
   - Intellect modifier for alchemy (Issue 016g formulas)
   - Strength modifier for blacksmithing

4. **Food/Upkeep system remains WC3-specific:**
   - WoW mode disables food mechanics
   - Uses resource system for other purposes

---

**Summary:** The project has **excellent foundations** for both systems. The attribute system (Issue 016) provides the stat infrastructure, the resource system (Issue 406) handles economy, and the profession system (Issue 702) ties them together. The dual WC3/WoW design is thoughtful and leverages shared abstractions effectively.

--------------------------------------------------------------------------------
