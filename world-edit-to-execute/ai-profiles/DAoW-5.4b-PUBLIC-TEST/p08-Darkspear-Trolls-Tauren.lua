-- AI profile for Darkspear Trolls & Tauren (player 8), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Darkspear Trolls & Tauren",
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
        { id = "Orkn" },   -- Chief of the Darkspear Tribe
        { id = "Ocb2" },   -- Chieftain of the Bloodhoof
        { id = "H03L" },   -- Arch Druid of the Tauren
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "otau", count = 9 },   -- Tauren
        { kind = "unit", id = "otbk", count = 8 },   -- Troll Berserker
        { kind = "unit", id = "nftr", count = 7 },   -- Axe Warrior
        { kind = "unit", id = "odoc", count = 4 },   -- Witch Doctor
        { kind = "unit", id = "odes", count = 2 },   -- Horde Frigate
        { kind = "unit", id = "otbr", count = 2 },   -- Troll Batrider
        { kind = "unit", id = "obot", count = 2 },   -- Horde Transport Ship
        { kind = "unit", id = "ojgn", count = 1 },   -- Horde Battleship
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "otau", count = 4 },   -- Tauren
            { id = "otbk", count = 4 },   -- Troll Berserker
            { id = "nftr", count = 3 },   -- Axe Warrior
            { id = "ospw", count = 2 },   -- Spirit Walker
            { id = "odoc", count = 2 },   -- Witch Doctor
            { id = "odes", count = 1 },   -- Horde Frigate
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
