-- AI profile for Kul'Tiras & Theramore (player 5), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Kul'Tiras & Theramore",
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
        { id = "H03C" },   -- Admiral of Kul Tiras
        { id = "H04R" },   -- The Apprentice
        { id = "Hjai" },   -- Archmage of Theramore
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "hhes", count = 9 },   -- Pirate
        { kind = "unit", id = "n03K", count = 9 },   -- Whale Harpooner
        { kind = "unit", id = "h02W", count = 8 },   -- Kul'Tiras Vanguard
        { kind = "unit", id = "nmed", count = 4 },   -- Pyromancer
        { kind = "unit", id = "hdes", count = 4 },   -- Alliance Frigate
        { kind = "unit", id = "hbot", count = 3 },   -- Alliance Transport Ship
        { kind = "unit", id = "nhym", count = 3 },
        { kind = "unit", id = "nemi", count = 3 },   -- Geomancer
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "hhes", count = 4 },   -- Pirate
            { id = "n03K", count = 4 },   -- Whale Harpooner
            { id = "h02W", count = 4 },   -- Kul'Tiras Vanguard
            { id = "nmed", count = 2 },   -- Pyromancer
            { id = "hdes", count = 2 },   -- Alliance Frigate
            { id = "hbot", count = 1 },   -- Alliance Transport Ship
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
