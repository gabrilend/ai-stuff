-- AI profile for Blood Elves (player 2), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Blood Elves",
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
        { id = "Hkal" },   -- Sun King
        { id = "Edem" },   -- The Calculator
        { id = "H012" },   -- High Astromancer
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "nbel", count = 7 },
        { kind = "unit", id = "nhea", count = 7 },   -- High Elven Archer
        { kind = "unit", id = "hspt", count = 5 },   -- Spell Breaker
        { kind = "unit", id = "ners", count = 3 },
        { kind = "unit", id = "h007", count = 2 },   -- Bloodmage
        { kind = "unit", id = "nhew", count = 4 },
        { kind = "unit", id = "h013", count = 4 },   -- Blood Sage
        { kind = "unit", id = "hdhw", count = 2, condition = "army_up" },   -- Dragonhawk Rider
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "nbel", count = 3 },
            { id = "nhea", count = 3 },   -- High Elven Archer
            { id = "hspt", count = 2 },   -- Spell Breaker
            { id = "u00K", count = 2 },   -- Tempest Wing
            { id = "h03H", count = 1 },   -- Solarium Agent
            { id = "ners", count = 1 },
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
