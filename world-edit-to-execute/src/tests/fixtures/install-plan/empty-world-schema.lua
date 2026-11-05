--[[
A stand-in for the world database W02h asks for: AzerothCore's tables,
no rows (issue W02f step 2's tests: src/tests/test_wow_install_plan.lua).

NOT AzerothCore's schema. Nothing in this repository reads a real world
database, so these are the tables and columns the converter itself
writes, copied here by hand (2026-11-05) from src/wowbuild/creatures.lua
(its column lists) and src/wowbuild/dbc.lua (each table's column count,
for the <table>_dbc copies the server fills by position). Those are from
memory of AzerothCore's schema and are marked unchecked there and in
W02f. What checking a plan against this stand-in shows: the plan and the
SQL the converter wrote agree with each other and with one declared
schema, every row has as many values as its table wants, and nothing
goes into a table the stand-in lacks. Against the owner's real server,
W02f step 3 runs the same check on the schema read from it.

Data only: read in an empty environment.
]]
return {
    world = {
        creature = { columns = {
            "guid", "id", "map", "spawnMask", "phaseMask", "position_x", "position_y", "position_z",
            "orientation", "spawntimesecs", "Comment",
        } },
        creature_template = { columns = {
            "entry", "difficulty_entry_1", "difficulty_entry_2", "difficulty_entry_3", "KillCredit1",
            "KillCredit2", "name", "subname", "IconName", "gossip_menu_id", "minlevel", "maxlevel",
            "exp", "faction", "npcflag", "speed_walk", "speed_run", "speed_swim", "speed_flight",
            "detection_range", "rank", "dmgschool", "DamageModifier", "BaseAttackTime",
            "RangeAttackTime", "BaseVariance", "RangeVariance", "unit_class", "unit_flags",
            "unit_flags2", "dynamicflags", "family", "type", "type_flags", "lootid",
            "pickpocketloot", "skinloot", "PetSpellDataId", "VehicleId", "mingold", "maxgold",
            "AIName", "MovementType", "HoverHeight", "HealthModifier", "ManaModifier",
            "ArmorModifier", "ExperienceModifier", "RacialLeader", "movementId", "RegenHealth",
            "CreatureImmunitiesId", "flags_extra", "ScriptName", "VerifiedBuild",
        } },
        creature_template_model = { columns = {
            "CreatureID", "Idx", "CreatureDisplayID", "DisplayScale", "Probability",
        } },
        creature_model_info = { columns = {
            "DisplayID", "BoundingRadius", "CombatReach", "Gender", "DisplayID_Other_Gender",
        } },
        -- filled by position: the DBC file's columns, a localised text as 17
        map_dbc = { count = 66 },
        areatable_dbc = { count = 36 },
        creaturedisplayinfo_dbc = { count = 16 },
        creaturemodeldata_dbc = { count = 28 },
        factiontemplate_dbc = { count = 14 },
        faction_dbc = { count = 57 },
    },
}
