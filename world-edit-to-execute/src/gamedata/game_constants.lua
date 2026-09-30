--[[
game_constants.lua - WC3's gameplay constants, with the map's own on top (Issues 527-529)

WC3 keeps its rules' numbers in [Misc] sections (the World Editor's
"Gameplay Constants"): how much experience a level needs, what a kill is
worth, what an attribute point gives, upkeep, revival, the damage table.
They're read in the game's order, each later one replacing what it sets:

  1. the defaults below (FROM MEMORY of The Frozen Throne 1.21: stand-ins
     until the install's own files are read)
  2. the install's Units\MiscData.txt, then Units\MiscGame.txt
  3. the map's war3mapMisc.txt (custom gameplay constants: DAoW sets its
     own food ceiling, upkeep, hero levels, experience curve, damage table)

Values are numbers, or lists of numbers for comma lists.

    local gc = require("gamedata.game_constants")
    local C = gc.load({ chain = chain, map_text = archive:extract("war3mapMisc.txt") })
    C.values.FoodCeiling               -- 100 (DAoW: 300)
    C:hero_xp_needed(3)                -- total experience to reach level 3
    C:kill_xp(level, is_hero)          -- a kill's experience before sharing
    C:damage_factor("pierce", "large") -- the damage table
]]

local profile = require("parsers.profile_txt")

local gc = {}

-- {{{ Defaults (from memory; see the header)
gc.DEFAULTS = {
    MaxHeroLevel = 10, MaxUnitLevel = 20,
    NeedHeroXP = { 200 }, NeedHeroXPFormulaA = 1, NeedHeroXPFormulaB = 100, NeedHeroXPFormulaC = 0,
    GrantHeroXP = { 100, 120, 160, 220, 300 }, GrantHeroXPFormulaA = 1, GrantHeroXPFormulaB = 100, GrantHeroXPFormulaC = 0,
    GrantNormalXP = { 25 }, GrantNormalXPFormulaA = 1, GrantNormalXPFormulaB = 5, GrantNormalXPFormulaC = 5,
    HeroFactorXP = { 100, 90, 80, 70, 60 },
    SummonedKillFactor = 0.5, HeroExpRange = 1200, BuildingKillsGiveExp = 0, MaxLevelHeroesDrainExp = 1,
    StrAttackBonus = 1, StrHitPointBonus = 25, StrRegenBonus = 0.05,
    IntManaBonus = 15, IntRegenBonus = 0.05,
    AgiDefenseBonus = 0.3, AgiDefenseBase = -2, AgiAttackSpeedBonus = 0.02,
    FoodCeiling = 100, UpkeepUsage = { 50, 80 }, UpkeepGoldTax = { 0.3, 0.6 }, UpkeepLumberTax = { 0, 0 },
    HeroMaxReviveCostGold = 700, HeroMaxReviveCostLumber = 0, HeroMaxReviveTime = 150,
    ReviveBaseFactor = 0.4, ReviveLevelFactor = 0.1, ReviveBaseLumberFactor = 0, ReviveLumberLevelFactor = 0,
    ReviveMaxFactor = 4, ReviveTimeFactor = 0.65, ReviveMaxTimeFactor = 2,
    HeroReviveManaFactor = 0, HeroReviveLifeFactor = 1,
    HeroAbilityLevelSkip = 2,
    -- the damage table: per attack type, one factor per armour type in
    -- ARMOR order
    DamageBonusNormal = { 1.00, 1.50, 1.00, 0.70, 1.00, 1.00, 0.05, 1.00 },
    DamageBonusPierce = { 2.00, 0.75, 1.00, 0.35, 1.00, 0.50, 0.05, 1.50 },
    DamageBonusSiege = { 1.00, 0.50, 1.00, 1.50, 1.00, 0.50, 0.05, 1.50 },
    DamageBonusMagic = { 1.25, 0.75, 2.00, 0.35, 1.00, 0.50, 0.05, 1.00 },
    DamageBonusChaos = { 1, 1, 1, 1, 1, 1, 1, 1 },
    DamageBonusSpells = { 1.00, 1.00, 1.00, 1.00, 1.00, 0.70, 0.05, 1.00 },
    DamageBonusHero = { 1.00, 1.00, 1.00, 0.50, 1.00, 1.00, 0.05, 1.00 },
}
-- armour types, in the damage table's order (unit field "udty"/defType)
gc.ARMOR = { "small", "medium", "large", "fort", "normal", "hero", "divine", "none" }
gc.ATTACK = { normal = "DamageBonusNormal", pierce = "DamageBonusPierce", siege = "DamageBonusSiege",
              magic = "DamageBonusMagic", chaos = "DamageBonusChaos", spells = "DamageBonusSpells",
              hero = "DamageBonusHero" }
gc.INSTALL_FILES = { "Units\\MiscData.txt", "Units\\MiscGame.txt" }
-- }}}

local C = {}
C.__index = C

-- {{{ Parsing
local function value_of(text)
    text = text:gsub('^"(.*)"$', "%1")
    if text:find(",") then
        local list = {}
        for part in text:gmatch("[^,]+") do list[#list + 1] = tonumber(part) or part end
        return list
    end
    return tonumber(text) or text
end

-- the [Misc] section of a text file into values (later keys win)
function gc.apply(values, text, origin, origins)
    local sections = profile.parse(text)
    local misc = sections.Misc or sections.misc
    if not misc then return 0 end
    local n = 0
    for k, v in pairs(misc) do
        values[k] = value_of(v)
        if origins then origins[k] = origin end
        n = n + 1
    end
    return n
end
-- }}}

-- {{{ gc.load
-- opts: chain (gamedata/chain.lua or anything with read(path)), map_text
-- (war3mapMisc.txt's text) or map_archive (an mpq archive to read it from)
function gc.load(opts)
    opts = opts or {}
    local self = setmetatable({ values = {}, origins = {}, sources = {} }, C)
    for k, v in pairs(gc.DEFAULTS) do self.values[k] = v; self.origins[k] = "default" end
    if opts.chain then
        for _, path in ipairs(gc.INSTALL_FILES) do
            local ok, text = pcall(opts.chain.read, opts.chain, path)
            if ok and text then
                gc.apply(self.values, text, "install", self.origins)
                self.sources[#self.sources + 1] = path
            end
        end
    end
    local text = opts.map_text
    if not text and opts.map_archive and opts.map_archive:has("war3mapMisc.txt") then
        text = opts.map_archive:extract("war3mapMisc.txt")
    end
    if text then
        self.map_count = gc.apply(self.values, text, "map", self.origins)
        self.sources[#self.sources + 1] = "war3mapMisc.txt"
    end
    return self
end
-- }}}

-- {{{ Reading
function C:get(key) return self.values[key] end

local function list(v) if type(v) == "table" then return v end return { v } end

-- A table value extended by its formula: entries as given, then
-- prev * A + level * B + C (the Gameplay Constants' "previous value,
-- level, constant" factors)
function C:series(key, level)
    local t = list(self.values[key] or {})
    local a = self.values[key .. "FormulaA"] or 1
    local b = self.values[key .. "FormulaB"] or 0
    local c = self.values[key .. "FormulaC"] or 0
    if level <= #t then return tonumber(t[level]) or 0 end
    local prev = tonumber(t[#t]) or 0
    for l = #t + 1, level do prev = prev * a + l * b + c end
    return prev
end

-- Total experience to reach a level (level 1: 0)
function C:hero_xp_needed(level)
    if level <= 1 then return 0 end
    -- the table's first entry is for level 2
    local t = list(self.values.NeedHeroXP or { 200 })
    local a = self.values.NeedHeroXPFormulaA or 1
    local b = self.values.NeedHeroXPFormulaB or 100
    local c = self.values.NeedHeroXPFormulaC or 0
    local need = tonumber(t[1]) or 200
    for l = 3, level do
        need = t[l - 1] and tonumber(t[l - 1]) or (need * a + l * b + c)
    end
    return need
end

-- The level a hero is at with xp experience
function C:level_for_xp(xp)
    local max = self.values.MaxHeroLevel or 10
    local level = 1
    while level < max and xp >= self:hero_xp_needed(level + 1) do level = level + 1 end
    return level
end

-- A kill's experience (before sharing and the heroes' level factor)
function C:kill_xp(level, is_hero)
    level = math.max(1, level or 1)
    return self:series(is_hero and "GrantHeroXP" or "GrantNormalXP", level)
end

-- Percent of experience a hero of this level takes
function C:hero_factor(level)
    local t = list(self.values.HeroFactorXP or { 100 })
    return (tonumber(t[math.min(math.max(1, level), #t)]) or 100) / 100
end

-- Upkeep: (level 0 none, 1 low, 2 high ...), gold tax, lumber tax, for food used
function C:upkeep(food)
    local usage = list(self.values.UpkeepUsage or {})
    local gold = list(self.values.UpkeepGoldTax or {})
    local lumber = list(self.values.UpkeepLumberTax or {})
    local tier = 0
    for i, limit in ipairs(usage) do
        local l = tonumber(limit) or 0
        -- a tier whose limit is 0 and whose tax is 0 isn't a tier (DAoW
        -- switches upkeep off with zeros)
        if l > 0 and food > l then tier = i end
    end
    return tier, tonumber(gold[tier]) or 0, tonumber(lumber[tier]) or 0
end

-- The damage table's factor
function C:damage_factor(attack, armor)
    local key = gc.ATTACK[tostring(attack or "normal"):lower()] or "DamageBonusNormal"
    local row = list(self.values[key] or {})
    local idx = 5
    for i, name in ipairs(gc.ARMOR) do
        if name == tostring(armor or "normal"):lower() then idx = i end
    end
    return tonumber(row[idx]) or 1
end

-- What reviving a hero costs, and how long it takes: its gold and lumber
-- cost and build time (the unit's), and its level
function C:revive(gold, lumber, time, level)
    local v = self.values
    local lv = math.max(0, (level or 1) - 1)
    local g = math.min((gold or 0) * math.min(v.ReviveBaseFactor + v.ReviveLevelFactor * lv, v.ReviveMaxFactor),
                       v.HeroMaxReviveCostGold)
    local l = math.min((lumber or 0) * math.min(v.ReviveBaseLumberFactor + v.ReviveLumberLevelFactor * lv, v.ReviveMaxFactor),
                       v.HeroMaxReviveCostLumber)
    local t = math.min((time or 0) * math.min(level * v.ReviveTimeFactor, v.ReviveMaxTimeFactor), v.HeroMaxReviveTime)
    return math.floor(g), math.floor(l), t
end
-- }}}

return gc
