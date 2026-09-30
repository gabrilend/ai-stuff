--[[
Default Melee AI (Issue 521d)

What a computer player gets on a melee map (Blizzard.j's
MeleeStartingAI, or StartMeleeAI with the game's own scripts\human.ai
and the rest): one profile per race, ours, in the AI Editor's shape
(ai/profile.lua). Blizzard's melee scripts are the game's and aren't used
or copied; these play the same broad game (workers, an army from the
barracks, a hero, attack waves that grow) with stock ids from memory.

With harvesting (issue 527) and construction (issues 531, 540) a melee
AI gathers, builds its farms, barracks and altar with its workers, trains
its army and hero there, and its waves form. Research ("upgrade"
entries) is still kept, not played.

    local melee = require("ai.melee")
    local p = melee.profile("human")      -- or by a script path: melee.race_of("scripts\\orc.ai")
]]

local melee = {}

-- {{{ Races
-- worker, hall, food building, barracks, altar, army units in order of
-- tier, heroes with skill orders
local RACES = {
    human = {
        worker = "hpea", hall = "htow", farm = "hhou", barracks = "hbar", altar = "halt",
        army = { "hfoo", "hrif", "hkni", "hmpr", "hsor", "hmtm" },
        heroes = {
            { id = "Hamg", skills = { "AHwe", "AHab", "AHwe", "AHbz", "AHwe", "AHmt" } },
            { id = "Hmkg", skills = { "AHtb", "AHtc", "AHbh", "AHtb", "AHtc", "AHav" } },
            { id = "Hpal", skills = { "AHhb", "AHad", "AHhb", "AHds", "AHhb", "AHre" } },
        },
    },
    orc = {
        worker = "opeo", hall = "ogre", farm = "otrb", barracks = "obar", altar = "oalt",
        army = { "ogru", "ohun", "orai", "oshm", "okod", "otau" },
        heroes = {
            { id = "Obla", skills = { "AOwk", "AOcr", "AOwk", "AOmi", "AOcr", "AOww" } },
            { id = "Ofar", skills = { "AOsf", "AOcl", "AOsf", "AOfs", "AOcl", "AOeq" } },
            { id = "Otch", skills = { "AOsh", "AOae", "AOsh", "AOws", "AOae", "AOre" } },
        },
    },
    undead = {
        worker = "uaco", hall = "unpl", farm = "uzig", barracks = "usep", altar = "uaod",
        army = { "ugho", "ucry", "unec", "uban", "uabo", "ufro" },
        heroes = {
            { id = "Udea", skills = { "AUdc", "AUau", "AUdc", "AUdp", "AUdc", "AUan" } },
            { id = "Ulic", skills = { "AUfn", "AUfu", "AUfn", "AUdr", "AUfn", "AUdd" } },
            { id = "Udre", skills = { "AUcs", "AUav", "AUsl", "AUcs", "AUav", "AUin" } },
        },
    },
    nightelf = {
        worker = "ewsp", hall = "etol", farm = "emow", barracks = "eaom", altar = "eate",
        army = { "earc", "esen", "edry", "edoc", "emtg", "ehip" },
        heroes = {
            { id = "Edem", skills = { "AEmb", "AEim", "AEmb", "AEev", "AEim", "AEme" } },
            { id = "Ekee", skills = { "AEer", "AEah", "AEer", "AEfn", "AEah", "AEtq" } },
            { id = "Emoo", skills = { "AHfa", "AEst", "AHfa", "AEar", "AEst", "AEsf" } },
        },
    },
}
melee.RACES = RACES
-- }}}

-- {{{ melee.race_of
-- The race of a script path ("scripts\\human.ai") or a player's race
-- constant ("RACE_ORC"), else nil
function melee.race_of(text)
    text = tostring(text or ""):lower()
    for _, r in ipairs({ "human", "orc", "undead", "nightelf" }) do
        if text:find(r, 1, true) then return r end
    end
    if text:find("night", 1, true) or text:find("elf", 1, true) then return "nightelf" end
    return nil
end
-- }}}

-- {{{ melee.profile
function melee.profile(race)
    local r = RACES[race] or RACES.human
    local a = r.army
    return {
        name = "Melee (" .. (RACES[race] and race or "human") .. ")",
        race = RACES[race] and race or "human",
        options = { melee = true, defend_users = true, target_heroes = true, repair = true,
                    heroes_flee = true, units_flee = true, groups_flee = true, take_items = true,
                    buy_items = true, smart_artillery = true },
        harvest = { gold = 5, lumber = 3 },
        heroes = r.heroes,
        conditions = {
            early = { "game_time", "<", 360 },
            mid = { "and", { "game_time", ">=", 360 }, { "game_time", "<", 900 } },
            late = { "game_time", ">=", 900 },
            has_army = { "army", ">=", 6 },
        },
        build = {
            { kind = "unit", id = r.worker, count = 5 },
            { kind = "building", id = r.farm, count = 1 },
            { kind = "building", id = r.barracks, count = 1 },
            { kind = "building", id = r.altar, count = 1 },
            { kind = "hero", slot = 1 },
            { kind = "unit", id = r.worker, count = 12 },
            { kind = "unit", id = a[1], count = 4 },
            { kind = "building", id = r.farm, count = 4 },
            { kind = "unit", id = a[2], count = 3, condition = { "not", "early" } },
            { kind = "hero", slot = 2, condition = { "not", "early" } },
            { kind = "unit", id = a[1], count = 8, condition = "late" },
            { kind = "unit", id = a[3], count = 4, condition = "late" },
            { kind = "hero", slot = 3, condition = "late" },
            { kind = "expansion", condition = { "and", "mid", "has_army" } },
        },
        groups = {
            early = { { id = a[1], count = 4 } },
            mid = { { id = a[1], count = 4 }, { id = a[2], count = 3 } },
            late = { { id = a[1], count = 6 }, { id = a[2], count = 3 }, { id = a[3], count = 3 } },
        },
        waves = {
            initial_delay = 300, delay = 90, repeat_from = 3, max_wait = 120,
            list = {
                { group = "early" },
                { group = "mid" },
                { group = "late" },
            },
        },
        targets = {
            { kind = "enemy_near_home" },
            { kind = "creeps", condition = "early" },
            { kind = "enemy_base" },
        },
    }
end
-- }}}

return melee
