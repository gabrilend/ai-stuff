-- AI profile for Illidari (player 7), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Illidari",
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
        { id = "Nbbc" },   -- Warchief of the Fel Horde
        { id = "Eevi" },   -- Lord of Outland
        { id = "Hvsh" },
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "nchg", count = 12 },   -- Chaos Grunt
        { kind = "unit", id = "ohun", count = 10 },   -- Fel Orc Crossbowman
        { kind = "unit", id = "nchw", count = 9 },   -- Fel Orc Warlock
        { kind = "unit", id = "nchr", count = 6 },
        { kind = "unit", id = "u00V", count = 4 },   -- Dreadcaster
        { kind = "unit", id = "ncpn", count = 4 },
        { kind = "unit", id = "n02A", count = 2 },   -- Illidari Shadowdancer
        { kind = "unit", id = "o006", count = 2 },   -- Chaos Blade Master
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "nchg", count = 9 },   -- Chaos Grunt
            { id = "ohun", count = 5 },   -- Fel Orc Crossbowman
            { id = "nchw", count = 4 },   -- Fel Orc Warlock
            { id = "nchr", count = 3 },
            { id = "nmyr", count = 3 },   -- Naga Myrmidon
            { id = "nntg", count = 2 },
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
