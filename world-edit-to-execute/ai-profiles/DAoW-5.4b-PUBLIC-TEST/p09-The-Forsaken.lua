-- AI profile for The Forsaken (player 9), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "The Forsaken",
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
        { id = "Ulic" },   -- Master of the Apothecary
        { id = "Usyl" },   -- Queen of the Forsaken
        { id = "Uvar" },   -- Arch Lord of The Undercity
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "o01M", count = 12 },   -- Forsaken Ghoul
        { kind = "unit", id = "uswb", count = 12 },   -- Forsaken Abomination
        { kind = "unit", id = "uban", count = 10 },   -- Banshee
        { kind = "unit", id = "e007", count = 4 },   -- Forsaken Archer
        { kind = "unit", id = "udes", count = 4 },
        { kind = "unit", id = "ubot", count = 3 },
        { kind = "unit", id = "uubs", count = 2 },
        { kind = "unit", id = "u00U", count = 2 },   -- Deathguard
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "o01M", count = 8 },   -- Forsaken Ghoul
            { id = "uswb", count = 7 },   -- Forsaken Abomination
            { id = "uban", count = 5 },   -- Banshee
            { id = "e007", count = 2 },   -- Forsaken Archer
            { id = "udes", count = 2 },
            { id = "ubot", count = 1 },
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
