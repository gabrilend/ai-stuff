--[[
route_b_fields.lua - which Liquipedia infobox field is which stock table column

Reviewed data for Route B (issue 112e). Liquipedia's Warcraft III pages carry
an infobox whose fields are the game's own numbers under friendlier names;
this maps each onto the stock table and column Route A reads, so the two can
be compared number by number. Worked out from the Knight's page (`hkni`),
checked against the 1.29.2 layer's column names. Fields not listed here
(text, art, lists of requirements) aren't compared.

Change it here, with the reason, and the comparison follows.

Format: template name -> { infobox field -> "Table.column" }
]]

local M = {
    -- {{{ units and heroes (and the unit side of buildings)
    ["Infobox unit"] = {
        gold = "UnitBalance.goldcost",
        lumber = "UnitBalance.lumbercost",
        build_time = "UnitBalance.bldtm",
        food = "UnitBalance.fused",
        foodproduced = "UnitBalance.fmade",
        armor = "UnitBalance.def",
        armorup = "UnitBalance.defUp",
        hp = "UnitBalance.HP",
        hpregen = "UnitBalance.regenHP",
        level = "UnitBalance.level",
        mana = "UnitBalance.manaN",
        manastart = "UnitBalance.mana0",
        manaregen = "UnitBalance.regenMana",
        daysight = "UnitBalance.sight",
        nightsight = "UnitBalance.nsight",
        collision = "UnitBalance.collision",
        speed = "UnitBalance.spd",
        bountybase = "UnitBalance.bountyplus",
        bountydice = "UnitBalance.bountydice",
        bountysides = "UnitBalance.bountysides",
        stock = "UnitBalance.stockMax",
        stockstart = "UnitBalance.stockStart",
        stockreplenish = "UnitBalance.stockRegen",
        acq_range = "UnitWeapons.acquire",
        minrange = "UnitWeapons.minRange",
        castpoint = "UnitWeapons.castpt",
        castbackwing = "UnitWeapons.castbsw",
        backswingpoint = "UnitWeapons.backSw1",
        dmgpoint = "UnitWeapons.dmgpt1",
        cooldown = "UnitWeapons.cool1",
        dmgbase = "UnitWeapons.dmgplus1",
        dmgdice = "UnitWeapons.dice1",
        dmgsides = "UnitWeapons.sides1",
        range = "UnitWeapons.rangeN1",
        rangemotionbuffer = "UnitWeapons.RngBuff1",
        -- splash: full, medium and small damage radii, and the medium and
        -- small damage fractions (Mortar Team: 25 / 100 / 200, 0.4 / 0.1)
        area = "UnitWeapons.Farea1",
        areamed = "UnitWeapons.Harea1",
        areasm = "UnitWeapons.Qarea1",
        dmgmed = "UnitWeapons.Hfact1",
        dmgsm = "UnitWeapons.Qfact1",
        backswingpoint2 = "UnitWeapons.backSw2",
        dmgpoint2 = "UnitWeapons.dmgpt2",
        cooldown2 = "UnitWeapons.cool2",
        dmgbase2 = "UnitWeapons.dmgplus2",
        dmgdice2 = "UnitWeapons.dice2",
        dmgsides2 = "UnitWeapons.sides2",
        range2 = "UnitWeapons.rangeN2",
        rangemotionbuffer2 = "UnitWeapons.RngBuff2",
        area2 = "UnitWeapons.Farea2",
        areamed2 = "UnitWeapons.Harea2",
        areasm2 = "UnitWeapons.Qarea2",
        dmgmed2 = "UnitWeapons.Hfact2",
        dmgsm2 = "UnitWeapons.Qfact2",
        turnrate = "UnitData.turnRate",
        priority = "UnitData.prio",
        cargo_size = "UnitData.cargoSize",
    },
    -- }}}

    -- {{{ items (no id in their infobox: matched by name, see route_b.lua)
    ["Infobox item"] = {
        level = "ItemData.Level",
        gold = "ItemData.goldcost",
        lumber = "ItemData.lumbercost",
        charges = "ItemData.uses",
        stock = "ItemData.stockMax",
        stockstart = "ItemData.stockStart",
        stockreplenish = "ItemData.stockRegen",
    },
    -- }}}
}

-- Buildings carry the same fields as units (Barracks: id hbar, hp, gold,
-- ...). Their pages as they stood in 2018 used an older layout with no id
-- (paired by name instead, see route_b.lua) and two other names: buildtime
-- for build_time, foodsupply for foodproduced (Castle: buildtime=140,
-- foodsupply=12).
M["Infobox building"] = {}
for field, target in pairs(M["Infobox unit"]) do M["Infobox building"][field] = target end
M["Infobox building"].buildtime = "UnitBalance.bldtm"
M["Infobox building"].foodsupply = "UnitBalance.fmade"

return M
