--[[
field_rules.lua - which stock tables each object kind reads, and which fields count as functional

Reviewed data, not code (issue 112c). Change it here, with the reason, and
the merge in stock_rows.lua follows.

Why these drops: the project keeps only the facts maps need to behave the
same (numbers, flags, ids, lists of ids), never Blizzard's art, sound or text
(docs/licensing-and-boundaries.md, issue 112). A field's metadata "type"
decides: text and asset types are dropped; everything else is kept.
]]

return {
    -- {{{ dropped_types
    -- Metadata types whose values are text or asset paths.
    dropped_types = {
        string = "names, tooltips and other text",
        stringList = "lists of text",
        icon = "icon image paths",
        model = "model paths",
        modelList = "lists of model paths",
        soundLabel = "sound names",
        combatSound = "sound names",
        unitSound = "sound set names",
        effectList = "lists of effect model paths",
        lightningList = "lightning effect names (appearance only)",
        shadowImage = "shadow image names",
        shadowTexture = "shadow texture paths",
        uberSplat = "ground decal names",
        teamColor = "team colour (appearance only)",
        tilesetList = "which tilesets show the object in the editor",
    },
    -- }}}

    -- {{{ always_kept
    -- Columns no metadata row describes, but which the game needs.
    always_kept = {
        AbilityData = { alias = "the ability's id", code = "the base ability whose behaviour it uses" },
        AbilityBuffData = { alias = "the buff's id" },
        UnitData = { unitID = "the unit's id" },
        UnitBalance = { unitBalanceID = "the unit's id" },
        UnitWeapons = { unitWeapID = "the unit's id" },
        UnitAbilities = { unitAbilID = "the unit's id" },
        UnitUI = { unitUIID = "the unit's id" },
        ItemData = { itemID = "the item's id" },
        UpgradeData = { upgradeid = "the upgrade's id" },
        DestructableData = { DestructableID = "the destructible's id" },
        Doodads = { doodID = "the doodad's id" },
    },
    -- }}}

    -- {{{ kinds
    -- Per object kind: the map file, its metadata table, its stock tables
    -- (the "slk" names metadata rows use, each with its path), and the
    -- profile text files that hold its "Profile" fields.
    kinds = {
        abilities = {
            map_file = "war3map.w3a", has_levels = true,
            metadata = "Units\\AbilityMetaData.slk",
            tables = { AbilityData = "Units\\AbilityData.slk" },
            profiles = {
                "Units\\HumanAbilityFunc.txt", "Units\\OrcAbilityFunc.txt", "Units\\UndeadAbilityFunc.txt",
                "Units\\NightElfAbilityFunc.txt", "Units\\NeutralAbilityFunc.txt",
                "Units\\CampaignAbilityFunc.txt", "Units\\CommonAbilityFunc.txt", "Units\\ItemAbilityFunc.txt",
            },
        },
        units = {
            map_file = "war3map.w3u", has_levels = false,
            metadata = "Units\\UnitMetaData.slk",
            tables = {
                UnitData = "Units\\UnitData.slk", UnitBalance = "Units\\UnitBalance.slk",
                UnitWeapons = "Units\\UnitWeapons.slk", UnitAbilities = "Units\\UnitAbilities.slk",
                UnitUI = "Units\\UnitUI.slk",
            },
            profiles = {
                "Units\\HumanUnitFunc.txt", "Units\\OrcUnitFunc.txt", "Units\\UndeadUnitFunc.txt",
                "Units\\NightElfUnitFunc.txt", "Units\\NeutralUnitFunc.txt", "Units\\CampaignUnitFunc.txt",
            },
        },
        items = {
            map_file = "war3map.w3t", has_levels = false,
            metadata = "Units\\UnitMetaData.slk",
            tables = { ItemData = "Units\\ItemData.slk" },
            profiles = { "Units\\ItemFunc.txt" },
        },
    },
    -- }}}
}
