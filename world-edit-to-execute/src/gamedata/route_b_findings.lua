--[[
route_b_findings.lua - disagreements between the routes, investigated by hand

Reviewed data for Route B (issue 112e). Each entry is one number where
Liquipedia's page (as it stood under 1.29.2) and the game's own 1.29.2 table
disagree, which was looked into and explained. The game's number is never
changed: Route A reads the player's install, and the finding says why the
published number differs. The report lists these apart from the unexplained
disagreements, which stay to be investigated.

Two kinds of explanation need no entry here, because route_b.lua proves or
detects them itself: a building's cost that is the sum of an upgrade chain
(upgrade_step), and a page first written after 1.30 (later_page).

Kinds:
  researched   the wiki shows the value after every research the object has
               (the game's table holds the value before research)
  wiki_error   the page was wrong at the time; the evidence says how we know
  other_form   the page's numbers belong to another form of the same unit

Format: "id.Table.column" -> { kind = string, why = string }
]]

local RESEARCH_CLAW = "Druid of the Claw Training (Redc, two levels): +100 mana, +0.325 mana regeneration, +75 hit points, +1 damage die each"
local SPIRIT_WALKER = "the page's id is ospm (the ethereal form, whose attack is switched off); its attack (16 + 1d6, range 400, cooldown 1.75) is the corporeal form ospw's, exactly"
local RESEARCH_TALON = "Druid of the Talon Training (Redt): +100 mana, +0.325 mana regeneration, +40 hit points per level; the page shows one level's mana and hit points"

return {
    -- {{{ Druids in their animal forms: fully researched values
    ["edcm.UnitBalance.HP"] = { kind = "researched", why = RESEARCH_CLAW .. ": 810 + 2 x 75 = 960" },
    ["edcm.UnitBalance.manaN"] = { kind = "researched", why = RESEARCH_CLAW .. ": 200 + 2 x 100 = 400" },
    ["edcm.UnitBalance.mana0"] = { kind = "researched", why = RESEARCH_CLAW .. ": starting mana scales with the maximum, 100 -> 200" },
    ["edcm.UnitBalance.regenMana"] = { kind = "researched", why = RESEARCH_CLAW .. ": 0.333 + 0.64 = 0.973 (the page's 0.32 per level is the game's 0.325 as shown)" },
    ["edcm.UnitWeapons.dice1"] = { kind = "researched", why = RESEARCH_CLAW .. ": 1 + 2 = 3" },
    ["edtm.UnitBalance.HP"] = { kind = "researched", why = RESEARCH_TALON .. ": 300 + 40 = 340" },
    ["edtm.UnitBalance.manaN"] = { kind = "researched", why = RESEARCH_TALON .. ": 200 + 100 = 300" },
    ["edtm.UnitBalance.mana0"] = { kind = "researched", why = RESEARCH_TALON .. ": starting mana scales with the maximum, 75 x 1.5 = 112.5" },
    ["edtm.UnitBalance.regenMana"] = { kind = "researched", why = RESEARCH_TALON .. ": 0.667 + 0.32 = 0.987" },
    -- }}}

    -- {{{ errors on the page at the time
    ["ubsp.UnitBalance.regenMana"] = { kind = "wiki_error",
        why = "the page writes manaregen=03: the minus sign is lost; the Destroyer's mana drains at 3 per second (the game: -3)" },
    ["tret.ItemData.stockMax"] = { kind = "wiki_error",
        why = "the 2017 page says a stock of 2; the 1.36.1 patch notes say the Tome of Retraining 'now has a stock of 2', so it was 1 before (the game: 1)" },
    ["hctw.UnitWeapons.Farea1"] = { kind = "wiki_error",
        why = "the 2018 page gives the splash radii a tenth of their size (5 / 10 / 12.5 against the game's 50 / 100 / 125): a scale slip on the page" },
    ["hctw.UnitWeapons.Harea1"] = { kind = "wiki_error", why = "see Farea1: a tenth of the game's 100" },
    ["hctw.UnitWeapons.Qarea1"] = { kind = "wiki_error", why = "see Farea1: a tenth of the game's 125" },
    -- }}}

    -- {{{ the page names one form, its numbers are another's
    ["ospm.UnitWeapons.backSw1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.cool1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.dmgplus1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.dice1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.dmgpt1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.sides1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.rangeN1"] = { kind = "other_form", why = SPIRIT_WALKER },
    ["ospm.UnitWeapons.RngBuff1"] = { kind = "other_form", why = SPIRIT_WALKER },
    -- }}}
}
