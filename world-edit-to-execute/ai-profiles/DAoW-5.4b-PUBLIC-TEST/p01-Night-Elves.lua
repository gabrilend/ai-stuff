-- AI profile for Night Elves (player 1), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Night Elves",
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
        { id = "Emoo" },   -- General of the Sentinels
        { id = "Etyr" },   -- High Priestess of Elune
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "unit", id = "earc", count = 12 },   -- Archer
        { kind = "unit", id = "esen", count = 10 },   -- Huntress
        { kind = "unit", id = "edry", count = 9 },   -- Dryad
        { kind = "unit", id = "emtg", count = 8 },   -- Mountain Giant
        { kind = "unit", id = "etrs", count = 6 },
        { kind = "unit", id = "nwat", count = 5 },   -- Priestess of Elune
        { kind = "unit", id = "edes", count = 4 },
        { kind = "unit", id = "edoc", count = 2 },   -- Druid of the Claw
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "earc", count = 7 },   -- Archer
            { id = "esen", count = 5 },   -- Huntress
            { id = "edry", count = 4 },   -- Dryad
            { id = "emtg", count = 4 },   -- Mountain Giant
            { id = "nfv2", count = 3 },
            { id = "etrs", count = 3 },
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
