# Issue 702c: Crafting Professions

**Phase:** 7 - Gameplay: Core Mechanics
**Type:** Feature
**Priority:** High
**Dependencies:** 702a (Core), 702d (Recipes), 406 (Resources)

---

## Current Behavior

No crafting profession system. Items cannot be created from materials.

---

## Intended Behavior

Crafting professions that transform resources into items:

| Profession | Input | Output | WC3 Equivalent |
|------------|-------|--------|----------------|
| Blacksmithing | Ore, Bars | Weapons, Armor | Armory upgrades |
| Leatherworking | Leather | Leather Armor | (new) |
| Tailoring | Cloth | Cloth Armor, Bags | (new) |
| Alchemy | Herbs | Potions, Elixirs | Alchemist shop |
| Engineering | Metal, Parts | Gadgets, Bombs | Workshop, Factory |
| Enchanting | Dust, Shards | Enchantments | Arcane Sanctum |
| Jewelcrafting | Gems, Metal | Jewelry, Gems | (new) |
| Inscription | Herbs, Ink | Glyphs, Cards | (new) |
| Cooking | Meat, Fish | Food | (new) |
| First Aid | Cloth | Bandages | (new) |

---

## Crafting Station System

Many crafting actions require a station:

```lua
ecs.register_component("crafting_station", {
    station_type = "forge",  -- forge, anvil, alchemy_lab, etc.
    professions_supported = {"blacksmithing", "engineering"},

    -- Bonus effects
    skill_bonus = 0,         -- +X to effective skill
    speed_bonus = 0,         -- % faster crafting

    -- Fuel (optional)
    requires_fuel = false,
    fuel_type = nil,
    fuel_remaining = 0,

    -- Usage
    in_use_by = nil,         -- Entity currently using
    queue = {},              -- Entities waiting
})
```

---

## Crafting Flow

```
[Entity] ──selects recipe──▶ [Recipe]
    │
    ▼
┌──────────────────────────────────────────┐
│ 1. Check profession requirement          │
│ 2. Check skill requirement               │
│ 3. Check station requirement (if any)    │
│ 4. Check reagents in inventory           │
│ 5. Check tool requirement (if any)       │
└──────────────────────────────────────────┘
    │
    ▼ (all pass)
┌──────────────────────────────────────────┐
│ 6. Consume reagents                      │
│ 7. Begin craft (instant or channeled)    │
│ 8. Calculate output quantity/quality     │
│ 9. Create item(s) in inventory           │
│ 10. Try skill-up                         │
│ 11. Fire EVENT_CRAFT_SUCCESS             │
└──────────────────────────────────────────┘
```

---

## Profession Definitions

### Blacksmithing
```lua
PROFESSION_BLACKSMITHING = {
    id = "blacksmithing",
    type = "crafting",
    category = "primary",

    stations = {"forge", "anvil"},
    tool = "blacksmith_hammer",

    material_types = {"bar", "stone", "gem"},
    output_types = {"weapon", "armor", "shield", "mail", "plate"},

    specializations = {
        {id = "armorsmith", skill = 200, focus = "armor"},
        {id = "weaponsmith", skill = 200, focus = "weapons"},
    },
}
```

### Alchemy
```lua
PROFESSION_ALCHEMY = {
    id = "alchemy",
    type = "crafting",
    category = "primary",

    stations = {"alchemy_lab"},  -- Or none for basic
    tool = nil,

    material_types = {"herb", "reagent", "vial"},
    output_types = {"potion", "elixir", "flask", "transmute"},

    -- Alchemy special: discovery system
    discovery_enabled = true,
    discovery_chance = 0.05,

    specializations = {
        {id = "elixir_master", skill = 300, bonus = "elixirs"},
        {id = "potion_master", skill = 300, bonus = "potions"},
        {id = "transmutation_master", skill = 300, bonus = "transmutes"},
    },
}
```

### Engineering
```lua
PROFESSION_ENGINEERING = {
    id = "engineering",
    type = "crafting",
    category = "primary",

    stations = {"workshop"},
    tool = "arclight_spanner",

    material_types = {"bar", "part", "cloth", "gem"},
    output_types = {"device", "explosive", "pet", "mount", "gadget"},

    -- Engineering special: malfunction chance
    malfunction_base = 0.05,
    malfunction_formula = function(skill, device_skill)
        return math.max(0, 0.05 - (skill - device_skill) * 0.001)
    end,

    specializations = {
        {id = "gnomish", skill = 200, theme = "utility"},
        {id = "goblin", skill = 200, theme = "explosives"},
    },
}
```

### Enchanting
```lua
PROFESSION_ENCHANTING = {
    id = "enchanting",
    type = "crafting",
    category = "primary",

    stations = {},  -- Runed rods are the "tools"
    tool = "runed_rod",

    material_types = {"dust", "essence", "shard", "crystal"},
    output_types = {"enchant"},  -- Applied to items, not created

    -- Enchanting special: disenchant ability
    disenchant_enabled = true,

    -- Rod progression (acts as skill gates)
    rods = {
        {id = "runed_copper_rod", skill = 1},
        {id = "runed_silver_rod", skill = 100},
        {id = "runed_golden_rod", skill = 150},
        {id = "runed_truesilver_rod", skill = 200},
        {id = "runed_arcanite_rod", skill = 290},
    },
}
```

### Cooking (Secondary)
```lua
PROFESSION_COOKING = {
    id = "cooking",
    type = "crafting",
    category = "secondary",

    stations = {"campfire", "cooking_fire", "stove"},
    tool = nil,

    material_types = {"meat", "fish", "spice", "produce"},
    output_types = {"food"},

    -- Food provides buffs
    buff_system = true,
}
```

---

## Quality System (Optional)

Crafted items can have quality variations:

```lua
CRAFT_QUALITY = {
    POOR = 0,      -- Gray, fails
    COMMON = 1,    -- White, normal
    UNCOMMON = 2,  -- Green, bonus stats
    RARE = 3,      -- Blue, significant bonus
    EPIC = 4,      -- Purple, max stats
}

function calculate_quality(skill, recipe_skill, luck)
    local excess_skill = skill - recipe_skill
    local roll = math.random() + luck

    if roll > 0.95 and excess_skill > 50 then
        return CRAFT_QUALITY.EPIC
    elseif roll > 0.80 and excess_skill > 25 then
        return CRAFT_QUALITY.RARE
    elseif roll > 0.50 then
        return CRAFT_QUALITY.UNCOMMON
    else
        return CRAFT_QUALITY.COMMON
    end
end
```

---

## API Design

```lua
local crafting = require("runtime.systems.crafting")

-- Check if entity can craft recipe
crafting.can_craft(entity, recipe_id)
crafting.get_missing_reagents(entity, recipe_id)

-- Perform crafting
crafting.start_craft(entity, recipe_id, quantity)
crafting.cancel_craft(entity)
crafting.complete_craft(entity)

-- Station interaction
crafting.use_station(entity, station)
crafting.leave_station(entity)

-- Queries
crafting.get_craftable_recipes(entity, profession_id)
crafting.find_nearest_station(entity, station_type, max_range)
```

---

## Events

```lua
events.register("EVENT_CRAFT_START")      -- Begin crafting
events.register("EVENT_CRAFT_SUCCESS")    -- Item created
events.register("EVENT_CRAFT_FAILED")     -- Interrupted or failed
events.register("EVENT_CRAFT_DISCOVERY")  -- New recipe discovered
events.register("EVENT_DISENCHANT")       -- Item broken down
```

---

## WC3 Mode Mapping

In WC3, crafting maps to building upgrades and shop purchases:

```lua
-- WC3 Armory upgrade = mass "crafting" for army
WC3_UPGRADE_CRAFT = {
    -- Research Iron Forged Swords
    id = "iron_forged_swords",
    profession = "blacksmithing",
    station = "armory",
    cost = {gold = 100, lumber = 50},
    time = 60,
    effect = "all_melee +1 damage",
}

-- WC3 Shop = instant crafting
WC3_SHOP_CRAFT = {
    id = "buy_health_potion",
    profession = "alchemy",
    station = "shop",
    cost = {gold = 100},
    time = 0,  -- Instant
    product = "potion_of_healing",
}
```

---

## Acceptance Criteria

- [ ] Crafting stations can be interacted with
- [ ] Recipes consume reagents from inventory
- [ ] Crafted items appear in inventory
- [ ] Skill requirements enforced
- [ ] Skill-ups occur on successful craft
- [ ] Station requirements enforced
- [ ] All major professions defined
- [ ] Quality variations (optional mode)
- [ ] Events fire correctly
- [ ] WC3 upgrade mapping works
- [ ] Unit tests for crafting logic

---

## Notes

Crafting is where economy meets gameplay. A good crafting system creates:
- Material sinks (resources get consumed)
- Progression goals (want that epic recipe)
- Player interaction (trade crafted goods)
- Strategic depth (which recipes to learn?)

The WC3 mapping is clever: army upgrades are just "group crafting" where
the Armory "crafts" an improvement that affects all units.
