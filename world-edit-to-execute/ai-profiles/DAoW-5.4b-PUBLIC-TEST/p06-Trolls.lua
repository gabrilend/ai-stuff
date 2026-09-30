-- AI profile for Trolls (player 6), in the AI Editor's shape: see src/ai/profile.lua.
-- Derived from what the faction owns when the game starts; edit freely:
-- this file is used instead of deriving while it exists.
return {
    -- General
    name = "Trolls",
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
        { id = "O01U" },   -- Chief of Sandfury tribe
        { id = "Nsjs" },   -- Warlord of Zul'Aman
        { id = "Opgh" },   -- Blood Lord
        { id = "O00I" },   -- Priestess of Jintha'alor
    },
    -- Build Priorities
    build = {
        { kind = "hero", slot = 1 },
        { kind = "hero", slot = 2 },
        { kind = "hero", slot = 3 },
        { kind = "hero", slot = 4 },
        { kind = "unit", id = "nftr", count = 12 },   -- Axe Warrior
        { kind = "unit", id = "o00Q", count = 8 },   -- Raptor Raider
        { kind = "unit", id = "nfsh", count = 7 },   -- Gurubashi Priest
        { kind = "unit", id = "nfsp", count = 5 },   -- Amani Sorceror
        { kind = "unit", id = "nftk", count = 4 },   -- Troll Warlord
        { kind = "unit", id = "n01W", count = 3 },   -- Amani'shi Berserker
        { kind = "unit", id = "o00S", count = 3 },   -- Sandfury Executioner
        { kind = "unit", id = "n01X", count = 2 },   -- Eagle
    },
    -- Attack Groups
    groups = {
        main = {
            { id = "nftr", count = 8 },   -- Axe Warrior
            { id = "nftb", count = 5 },   -- Troll Axe-Thrower
            { id = "o00Q", count = 4 },   -- Raptor Raider
            { id = "nfsh", count = 3 },   -- Gurubashi Priest
            { id = "otbk", count = 3 },   -- Troll Berserker
            { id = "nfsp", count = 2 },   -- Amani Sorceror
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
