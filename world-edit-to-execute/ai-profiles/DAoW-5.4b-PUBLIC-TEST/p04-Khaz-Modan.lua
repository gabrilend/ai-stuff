-- AI profile for Khaz Modan (player 4), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Khaz Modan",
    race = "custom",
    options = {
        defend_users = true,
        groups_flee = true,
        heroes_flee = true,
        target_heroes = true,
        units_flee = false,
    },
    harvest = { gold = 5, lumber = 3 },
    -- General: target priorities
    targets = { { kind = "enemy_near_home" }, { kind = "enemy_base" } },
    -- Heroes
    heroes = {
        { id = "Ntin" },   -- High Tinker of Gnomeregan
        { id = "Hmkg" },   -- King of Khaz Modan
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "unit", id = "h00L", count = 12 },   -- Dwarven Warrior
        { kind = "unit", id = "hrif", count = 12 },   -- Rifleman
        { kind = "unit", id = "h050", count = 4 },   -- Dwarven Engineer
        { kind = "unit", id = "hmtm", count = 4 },   -- Mortar Team
        { kind = "unit", id = "negz", count = 4 },   -- Gnome Bombardier
        { kind = "unit", id = "hgry", count = 2 },   -- Gryphon Rider
        { kind = "unit", id = "hdes", count = 2 },   -- Alliance Frigate
        { kind = "unit", id = "hbot", count = 2 },   -- Alliance Transport Ship
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "h00L", count = 9 },   -- Dwarven Warrior
            { id = "hrif", count = 9 },   -- Rifleman
            { id = "h050", count = 2 },   -- Dwarven Engineer
            { id = "hmtm", count = 2 },   -- Mortar Team
            { id = "negz", count = 2 },   -- Gnome Bombardier
            { id = "hgry", count = 1 },   -- Gryphon Rider
        },
    },
    -- Attack Waves
    waves = {
        delay = 120,
        initial_delay = 240,
        list = { { group = "main" }, { group = "main" }, { group = "main" } },
        max_wait = 90,
        min_fraction = 0.6,
        repeat_from = 1,
    },
    -- Conditions
    conditions = { army_up = { "army", ">=", 8 } },
}
