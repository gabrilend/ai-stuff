-- AI profile for Stormwind (player 10), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Stormwind",
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
        { id = "Hmgd" },   -- Lord of Stromgarde
        { id = "Hhkl" },   -- Regent of Stormwind
        { id = "Hblm" },   -- Royal Councilor
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "unit", id = "hfoo", count = 12 },   -- Footman
        { kind = "unit", id = "hkni", count = 12 },   -- Knight
        { kind = "unit", id = "nbrg", count = 12 },   -- Spearman
        { kind = "unit", id = "hmpr", count = 7 },   -- Priest
        { kind = "unit", id = "hcth", count = 6 },
        { kind = "unit", id = "hdes", count = 2 },   -- Alliance Frigate
        { kind = "unit", id = "hbsh", count = 2 },   -- Alliance Battleship
        { kind = "unit", id = "h03I", count = 2 },   -- SI7 Assassin
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "hfoo", count = 14 },   -- Footman
            { id = "hkni", count = 6 },   -- Knight
            { id = "nbrg", count = 6 },   -- Spearman
            { id = "hmpr", count = 3 },   -- Priest
            { id = "hcth", count = 3 },
            { id = "hdes", count = 1 },   -- Alliance Frigate
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
