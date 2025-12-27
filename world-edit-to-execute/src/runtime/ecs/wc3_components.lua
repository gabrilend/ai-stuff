--[[
WC3 Core Component Definitions

Registers all standard components used by Warcraft 3 entities.
These components form the vocabulary for WC3 entity representation,
matching WC3's concepts closely while staying pure Lua.

Component responsibilities:
- position: Where the entity is in the world
- stats: Health, mana, damage, armor
- movement: Can move, how fast, pathing rules
- owner: Which player controls this
- unit_type: Reference to type definition (SLK data)
- selectable: Can be selected, UI state
- abilities: What abilities the unit has
- buffs: Active temporary effects
- hero: Hero-specific (XP, attributes, inventory)
- building: Building-specific (construction, queue)
- item: Item-specific (charges, carrier)
- projectile: Missile tracking
- destructible: Destroyable object (tree, rock)
- doodad: Non-interactive scenery
]]

local wc3 = {}

local component = require("runtime.ecs.component")

-- {{{ Position Component
-- World position and facing direction
-- All units, buildings, items, doodads have position
component.register("position", {
    x = 0.0,              -- World X coordinate
    y = 0.0,              -- World Y coordinate
    z = 0.0,              -- World Z coordinate (height)
    facing = 0.0,         -- Facing angle in radians (0 = East, counter-clockwise)
})
-- Note: WC3 uses degrees in JASS (0-360) but radians internally
-- Conversion: radians = degrees * (math.pi / 180)
-- }}}

-- {{{ Stats Component
-- Health, mana, and combat statistics
-- Used by units, buildings, and destructibles
component.register("stats", {
    -- Health
    hp = 100,             -- Current hit points
    hp_max = 100,         -- Maximum hit points
    hp_regen = 0.0,       -- HP regeneration per second

    -- Mana
    mp = 0,               -- Current mana points
    mp_max = 0,           -- Maximum mana points
    mp_regen = 0.0,       -- MP regeneration per second

    -- Combat
    armor = 0,            -- Armor value (reduces physical damage)
    armor_type = "normal",-- Armor type: unarmored, light, medium, heavy, fortified, hero, divine
    damage_min = 0,       -- Minimum attack damage
    damage_max = 0,       -- Maximum attack damage
    damage_type = "normal",-- Attack type: normal, pierce, siege, magic, chaos, spells, hero
    attack_speed = 1.0,   -- Attacks per second base
    attack_range = 128,   -- Attack range in units

    -- State
    invulnerable = false, -- Cannot take damage
    ethereal = false,     -- Cannot be targeted by physical attacks
})
-- }}}

-- {{{ Movement Component
-- Movement capability and pathing
-- Units and some buildings (uproot) have movement
component.register("movement", {
    speed = 270,          -- Base movement speed (units per second)
    speed_current = 270,  -- Current speed (after buffs/debuffs)
    speed_min = 100,      -- Minimum speed (hard floor)
    speed_max = 522,      -- Maximum speed (hard cap, WC3 limit)

    pathing = "foot",     -- Pathing type: foot, horse, fly, float, amphibious, buildingblocked
    collision_size = 32,  -- Collision radius in units

    -- Movement state
    moving = false,       -- Currently moving
    move_target_x = 0,    -- Move destination X
    move_target_y = 0,    -- Move destination Y
    turn_rate = 0.6,      -- Radians per second for turning

    -- Flight (if pathing == "fly")
    fly_height = 0,       -- Current fly height
    fly_height_default = 0,-- Default fly height
})
-- }}}

-- {{{ Owner Component
-- Player ownership and team
-- Units, buildings, items (when held)
component.register("owner", {
    player_id = 0,        -- Owning player (0-15, or -1 for neutral)
    -- Note: Neutral hostile = player 12 (PLAYER_NEUTRAL_AGGRESSIVE)
    --       Neutral passive = player 13 (PLAYER_NEUTRAL_PASSIVE)
    --       Neutral victim = player 14

    -- Cached alliance info (updated when alliances change)
    team = 0,             -- Team number for quick alliance checks
})
-- }}}

-- {{{ Unit Type Component
-- Reference to unit type definition
-- All units and buildings
component.register("unit_type", {
    type_id = "",         -- Four-character type ID (e.g., "hfoo", "hpea", "htow")
    -- This references the unit data loaded from SLK files

    -- Cached type info (from SLK data)
    name = "",            -- Display name
    is_hero = false,      -- Is this a hero unit
    is_building = false,  -- Is this a building
    is_summoned = false,  -- Is this summoned (not trained)
    food_used = 0,        -- Food cost
    food_made = 0,        -- Food provided (farms, halls)
    level = 1,            -- Unit level
})
-- }}}

-- {{{ Selectable Component
-- Selection and UI state
-- Most interactable entities
component.register("selectable", {
    selected = false,     -- Currently selected by local player
    selection_scale = 1.0,-- Selection circle scale factor
    selection_priority = 0,-- Priority for group selection (higher = more likely to be primary)

    -- UI hints
    show_healthbar = true,-- Show health bar when selected/hovered
    show_manabar = true,  -- Show mana bar if unit has mana
    can_select = true,    -- Can be selected at all (some units cannot)
})
-- }}}

-- {{{ Abilities Component
-- Container for unit abilities
-- Units with spells or passive abilities
component.register("abilities", {
    ability_ids = {},     -- Array of ability type IDs
    cooldowns = {},       -- ability_id -> remaining cooldown time
    levels = {},          -- ability_id -> current level (for hero abilities)
    disabled = {},        -- ability_id -> true if disabled
})
-- Note: Ability definitions are separate; this just tracks which
-- abilities the unit has and their current state.
-- }}}

-- {{{ Buffs Component
-- Active buffs and debuffs on the unit
-- Units that can receive buffs
component.register("buffs", {
    active = {},          -- Array of active buff instances
    -- Each buff: { buff_id, source_entity, remaining_duration, stacks }

    -- Cached modifiers (recalculated when buffs change)
    speed_modifier = 1.0, -- Multiplicative speed modifier
    damage_modifier = 1.0,-- Multiplicative damage modifier
    armor_modifier = 0,   -- Additive armor modifier
})
-- }}}

-- {{{ Hero Component
-- Hero-specific stats (experience, attributes)
-- Hero units only
component.register("hero", {
    experience = 0,       -- Current experience points
    level = 1,            -- Hero level (1-10 typically)

    -- Primary attributes
    strength = 0,         -- Strength (HP, HP regen)
    agility = 0,          -- Agility (armor, attack speed)
    intelligence = 0,     -- Intelligence (mana, mana regen)
    primary_attribute = "strength", -- Which attribute provides damage bonus

    -- Attribute gains per level (from hero data)
    str_per_level = 0,
    agi_per_level = 0,
    int_per_level = 0,

    -- Inventory
    inventory = {},       -- Array of 6 item entity IDs (nil for empty slots)
})
-- }}}

-- {{{ Building Component
-- Building-specific state
-- Buildings only
component.register("building", {
    construction_progress = 1.0, -- 0.0 = just started, 1.0 = complete
    under_construction = false,

    -- Rally point
    rally_x = 0,
    rally_y = 0,
    rally_target = nil,   -- Entity ID to rally to (unit/building)

    -- Production queue
    queue = {},           -- Array of unit type IDs being trained
    queue_progress = 0.0, -- Progress on current item (0.0-1.0)
})
-- }}}

-- {{{ Item Component
-- Item-specific data
-- Items (on ground or in inventory)
component.register("item", {
    item_id = "",         -- Item type ID (four-char)
    charges = 0,          -- Remaining charges (0 = no charges/infinite)
    charges_max = 0,      -- Maximum charges

    -- State
    on_ground = true,     -- Is the item on the ground
    carrier = nil,        -- Entity ID of carrying unit (if not on ground)
    slot = 0,             -- Inventory slot (1-6) if carried

    -- Loot
    can_be_picked_up = true,
    drop_on_death = true,
    sellable = true,
    pawnable = true,
})
-- }}}

-- {{{ Projectile Component
-- Projectile data for missiles
-- Projectile entities
component.register("projectile", {
    source = nil,         -- Entity ID that fired this projectile
    target = nil,         -- Entity ID target (nil for point target)
    target_x = 0,         -- Target X (for point target or if target dies)
    target_y = 0,         -- Target Y

    speed = 900,          -- Projectile speed (units per second)
    arc = 0.0,            -- Arc height (0 = straight line)
    homing = true,        -- Does it follow the target

    -- Payload
    damage = 0,           -- Damage on impact
    damage_type = "normal",
    impact_ability = nil, -- Ability to trigger on impact

    -- State
    distance_traveled = 0,
})
-- }}}

-- {{{ Destructible Component
-- Destructible object data (trees, rocks, gates)
component.register("destructible", {
    type_id = "",         -- Destructible type ID

    -- State
    alive = true,         -- Not destroyed
    current_animation = "stand", -- Current animation state

    -- Resources
    lumber_amount = 0,    -- Lumber when harvested (trees)
    gold_amount = 0,      -- Gold when harvested (gold mines)
})
-- }}}

-- {{{ Doodad Component
-- Non-interactive scenery
component.register("doodad", {
    type_id = "",         -- Doodad type ID
    variation = 0,        -- Visual variation (0-n)
    scale = 1.0,          -- Size scale
    animation = "stand",  -- Current animation
})
-- }}}

-- {{{ Helper Functions

-- {{{ wc3.create_unit
-- Helper to create a unit with standard components
-- Note: Does NOT load type data from SLK - just sets up structure
function wc3.create_unit(type_id, player_id, x, y, facing)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
        facing = facing or 0,
    })

    ecs.add_component(entity, "unit_type", {
        type_id = type_id,
    })

    ecs.add_component(entity, "owner", {
        player_id = player_id or 0,
    })

    ecs.add_component(entity, "stats")
    ecs.add_component(entity, "movement")
    ecs.add_component(entity, "selectable")
    ecs.add_component(entity, "abilities")
    ecs.add_component(entity, "buffs")

    return entity
end
-- }}}

-- {{{ wc3.create_hero
-- Helper to create a hero unit with hero component
function wc3.create_hero(type_id, player_id, x, y, facing)
    local ecs = require("runtime.ecs")

    local entity = wc3.create_unit(type_id, player_id, x, y, facing)

    -- Mark as hero in unit_type
    local ut = ecs.get_component(entity, "unit_type")
    ut.is_hero = true

    -- Add hero component
    ecs.add_component(entity, "hero")

    return entity
end
-- }}}

-- {{{ wc3.create_building
-- Helper to create a building with standard components
function wc3.create_building(type_id, player_id, x, y, facing)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
        facing = facing or 0,
    })

    ecs.add_component(entity, "unit_type", {
        type_id = type_id,
        is_building = true,
    })

    ecs.add_component(entity, "owner", {
        player_id = player_id or 0,
    })

    ecs.add_component(entity, "stats")
    ecs.add_component(entity, "selectable")
    ecs.add_component(entity, "building")

    return entity
end
-- }}}

-- {{{ wc3.create_item
-- Helper to create an item on the ground
function wc3.create_item(item_id, x, y)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
    })

    ecs.add_component(entity, "item", {
        item_id = item_id,
        on_ground = true,
    })

    ecs.add_component(entity, "selectable")

    return entity
end
-- }}}

-- {{{ wc3.create_destructible
-- Helper to create a destructible object (tree, rock, gate)
function wc3.create_destructible(type_id, x, y, facing, hp)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
        facing = facing or 0,
    })

    ecs.add_component(entity, "stats", {
        hp = hp or 100,
        hp_max = hp or 100,
    })

    ecs.add_component(entity, "destructible", {
        type_id = type_id,
    })

    ecs.add_component(entity, "selectable")

    return entity
end
-- }}}

-- {{{ wc3.create_doodad
-- Helper to create a non-interactive doodad
function wc3.create_doodad(type_id, x, y, facing, scale, variation)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    ecs.add_component(entity, "position", {
        x = x or 0,
        y = y or 0,
        facing = facing or 0,
    })

    ecs.add_component(entity, "doodad", {
        type_id = type_id,
        scale = scale or 1.0,
        variation = variation or 0,
    })

    return entity
end
-- }}}

-- {{{ wc3.create_projectile
-- Helper to create a projectile
function wc3.create_projectile(source, target, target_x, target_y, speed, damage)
    local ecs = require("runtime.ecs")

    local entity = ecs.create_entity()

    -- Start at source position
    local source_pos = ecs.get_component(source, "position")
    local start_x = source_pos and source_pos.x or 0
    local start_y = source_pos and source_pos.y or 0

    ecs.add_component(entity, "position", {
        x = start_x,
        y = start_y,
    })

    ecs.add_component(entity, "projectile", {
        source = source,
        target = target,
        target_x = target_x or 0,
        target_y = target_y or 0,
        speed = speed or 900,
        damage = damage or 0,
    })

    ecs.add_component(entity, "movement", {
        speed = speed or 900,
        moving = true,
    })

    return entity
end
-- }}}

-- }}}

--[[
WC3 Entity Type to Component Mapping:

| WC3 Type     | Components                                              |
|--------------|---------------------------------------------------------|
| Unit         | position, unit_type, owner, stats, movement,            |
|              | selectable, abilities, buffs                            |
| Hero         | All Unit components + hero                              |
| Building     | position, unit_type, owner, stats, selectable, building |
| Item         | position, item, selectable                              |
| Destructible | position, stats, destructible, selectable               |
| Doodad       | position, doodad                                        |
| Projectile   | position, movement, projectile                          |
]]

return wc3
