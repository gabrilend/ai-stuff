-- AI profile for The Horde (player 11), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "The Horde",
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
        { id = "Odrt" },   -- Elder Shaman of the Frost Wolves
        { id = "Othr" },   -- Warchief of the Horde
        { id = "Orex" },
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "ogru", count = 12 },   -- Grunt
        { kind = "unit", id = "oshm", count = 12 },   -- Shaman
        { kind = "unit", id = "o009", count = 12 },   -- Orc Spear Thrower
        { kind = "unit", id = "orai", count = 7 },   -- Raider
        { kind = "unit", id = "nw2w", count = 6 },   -- Frost Wolf Rider
        { kind = "unit", id = "obot", count = 4 },   -- Horde Transport Ship
        { kind = "unit", id = "odes", count = 4 },   -- Horde Frigate
        { kind = "unit", id = "ojgn", count = 2 },   -- Horde Battleship
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "ogru", count = 14 },   -- Grunt
            { id = "oshm", count = 7 },   -- Shaman
            { id = "o009", count = 6 },   -- Orc Spear Thrower
            { id = "orai", count = 3 },   -- Raider
            { id = "o007", count = 3 },   -- Blademaster
            { id = "nw2w", count = 3 },   -- Frost Wolf Rider
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
