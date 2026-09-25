--[[
field_rules.lua - which stock tables each object kind reads, and how each column is labelled

Reviewed data, not code (issue 112c). Change it here, with the reason, and
the merge in stock_rows.lua follows.

Every column is copied (owner's decision, 2026-09-24: "copy everything, and we
will work slowly to replace all the artwork and such"). Nothing is dropped;
instead each column carries a label saying whose it is, so the replacement
work can find what is still borrowed:

  fact      numbers, flags, ids, lists of ids, order strings: the functional
            facts maps need to behave the same (not protected; Feist v. Rural)
  borrowed  Blizzard's text and art: names, tooltips, icon/model/sound paths.
            Read from the player's own install, used on their machine, never
            committed or shipped, and each on a replacement track
            (docs/licensing-and-boundaries.md, W client doc 012)
  editor    columns no metadata row describes and the game doesn't read
            (comments, sort keys, beta flags); copied, labelled so nothing
            downstream mistakes them for game data
  map       set by the map itself: the map author's value, whatever its type

A metadata "type" decides between fact and borrowed.
]]

return {
    -- {{{ borrowed_types
    -- Metadata types whose values are Blizzard's text or art. Each names what
    -- the value is, and what takes its place once replaced.
    borrowed_types = {
        string = "names, tooltips and other text; names come from the map or our own gathered name lists, tooltips are rebuilt by the UI from the facts",
        stringList = "lists of text; same as string",
        icon = "icon image paths; replaced by the asset forge",
        model = "model paths; replaced by the asset forge",
        modelList = "lists of model paths; replaced by the asset forge",
        soundLabel = "sound names; replaced by the asset forge",
        combatSound = "sound names; replaced by the asset forge",
        unitSound = "sound set names; replaced by the asset forge",
        effectList = "lists of effect model paths; replaced by the asset forge",
        lightningList = "lightning effect names; replaced by the asset forge",
        shadowImage = "shadow image names; replaced by the asset forge",
        shadowTexture = "shadow texture paths; replaced by the asset forge",
        uberSplat = "ground decal names; replaced by the asset forge",
        teamColor = "team colour choice (appearance)",
        tilesetList = "which tilesets show the object in the editor",
    },
    -- }}}

    -- {{{ id_columns
    -- Columns no metadata row describes that are still facts the game needs.
    -- Any other column without a metadata row is labelled "editor".
    id_columns = {
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
                "Units\\HumanAbilityStrings.txt", "Units\\OrcAbilityStrings.txt", "Units\\UndeadAbilityStrings.txt",
                "Units\\NightElfAbilityStrings.txt", "Units\\NeutralAbilityStrings.txt",
                "Units\\CampaignAbilityStrings.txt", "Units\\CommonAbilityStrings.txt", "Units\\ItemAbilityStrings.txt",
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
                "Units\\HumanUnitStrings.txt", "Units\\OrcUnitStrings.txt", "Units\\UndeadUnitStrings.txt",
                "Units\\NightElfUnitStrings.txt", "Units\\NeutralUnitStrings.txt", "Units\\CampaignUnitStrings.txt",
            },
        },
        items = {
            map_file = "war3map.w3t", has_levels = false,
            metadata = "Units\\UnitMetaData.slk",
            tables = { ItemData = "Units\\ItemData.slk" },
            profiles = { "Units\\ItemFunc.txt", "Units\\ItemStrings.txt" },
        },
    },
    -- }}}
}
