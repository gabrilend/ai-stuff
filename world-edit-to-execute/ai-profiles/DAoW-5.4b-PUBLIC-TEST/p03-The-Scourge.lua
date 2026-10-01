-- AI profile for The Scourge (player 3), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "The Scourge",
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
        { id = "Uvng" },   -- Death Knight
        { id = "Uktl" },   -- Arch-Lich
        { id = "Uanb" },   -- King of Azjol'nerub
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "ugho", count = 12 },   -- Ghoul
        { kind = "unit", id = "uabo", count = 12 },   -- Abomination
        { kind = "unit", id = "unec", count = 12 },   -- Necromancer
        { kind = "unit", id = "ucry", count = 12 },   -- Crypt Fiend
        { kind = "unit", id = "uktn", count = 10 },   -- Thuzadin Cultist
        { kind = "unit", id = "ugar", count = 4 },   -- Gargoyle
        { kind = "unit", id = "u004", count = 4 },   -- Death Knight
        { kind = "unit", id = "uobs", count = 3 },   -- Obsidian Statue
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "ugho", count = 12 },   -- Ghoul
            { id = "uabo", count = 10 },   -- Abomination
            { id = "unec", count = 6 },   -- Necromancer
            { id = "ucry", count = 6 },   -- Crypt Fiend
            { id = "uktn", count = 5 },   -- Thuzadin Cultist
            { id = "ugar", count = 2 },   -- Gargoyle
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
