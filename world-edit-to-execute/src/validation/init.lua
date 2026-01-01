-- Cross-Reference Validation Module
-- Validates references between parsed map files to detect inconsistencies.
--
-- Validates:
--   - Unit placements reference valid unit type IDs
--   - Doodad placements reference valid doodad type IDs
--   - Item drops reference valid item IDs
--   - Ability references point to valid ability IDs
--   - Waygate destinations point to existing regions
--   - Region ambient sounds reference existing sound definitions
--   - Objects are used in appropriate contexts (type classification)
--
-- Usage:
--   local validation = require("validation")
--   local map = require("data").load("path/to/map.w3x")
--   local report = validation.validate_map(map)
--   print(validation.format_report(report))

local validation = {}

-- {{{ Constants and type classification heuristics

-- Object type patterns for heuristic classification
-- These are used when we don't have the object in our database
-- and need to guess what type it should be based on ID format.
local TYPE_PATTERNS = {
    -- Custom objects always have digits (e.g., H001, u000, A003)
    custom = "^%a%d%d%d$",

    -- Hero units: Capital first letter, lowercase rest (Hpal, Edem, Ulic)
    -- Exception: Some standard units use this pattern too
    hero = "^%u%l%l%l$",

    -- Standard units: all lowercase (hfoo, ogru, ushd)
    unit_standard = "^%l%l%l%l$",

    -- Abilities: Often start with A (AHhb, ANcl, AUan)
    -- Or have capital+capital pattern
    ability = "^A%u%l%l$",

    -- Items: Various patterns, often lowercase with specific prefixes
    -- (phea, pman, ratc, bspd)
}

-- Known base game ID prefixes for different types
-- Used to distinguish base game IDs from custom IDs
local BASE_GAME_PREFIXES = {
    -- Human units
    ["h"] = "unit",
    -- Orc units
    ["o"] = "unit",
    -- Undead units
    ["u"] = "unit",
    -- Night Elf units
    ["e"] = "unit",
    -- Neutral hostile units
    ["n"] = "unit",
    -- Critters/Neutral passive
    ["c"] = "unit",
}
-- }}}

-- {{{ ValidationReport class
local ValidationReport = {}
ValidationReport.__index = ValidationReport

-- {{{ ValidationReport.new
function ValidationReport.new()
    local self = setmetatable({}, ValidationReport)

    -- Critical issues (custom ID not found, definitely wrong)
    self.errors = {}

    -- Possible issues (base game ID not in our data, may be OK)
    self.warnings = {}

    -- Statistics
    self.stats = {
        units_checked = 0,
        doodads_checked = 0,
        item_drops_checked = 0,
        abilities_checked = 0,
        waygates_checked = 0,
        sounds_checked = 0,
        valid = 0,
        invalid = 0,
    }

    return self
end
-- }}}

-- {{{ ValidationReport:add_error
function ValidationReport:add_error(category, message, details)
    self.errors[#self.errors + 1] = {
        category = category,
        message = message,
        details = details or {},
    }
    self.stats.invalid = self.stats.invalid + 1
end
-- }}}

-- {{{ ValidationReport:add_warning
function ValidationReport:add_warning(category, message, details)
    self.warnings[#self.warnings + 1] = {
        category = category,
        message = message,
        details = details or {},
    }
end
-- }}}

-- {{{ ValidationReport:mark_valid
function ValidationReport:mark_valid()
    self.stats.valid = self.stats.valid + 1
end
-- }}}

-- {{{ ValidationReport:is_valid
function ValidationReport:is_valid()
    return #self.errors == 0
end
-- }}}

-- {{{ ValidationReport:summary
function ValidationReport:summary()
    return {
        errors = #self.errors,
        warnings = #self.warnings,
        valid = self.stats.valid,
        invalid = self.stats.invalid,
        total_checked = self.stats.valid + self.stats.invalid,
    }
end
-- }}}
-- }}}

-- {{{ Helper functions

-- {{{ is_custom_id
-- Check if an ID looks like a custom (map-created) object.
-- Custom objects have the pattern X### (letter + 3 digits)
local function is_custom_id(id)
    if not id or #id ~= 4 then
        return false
    end
    -- Pattern: one letter followed by 3 digits
    return id:match("^%a%d%d%d$") ~= nil
end
-- }}}

-- {{{ classify_id
-- Attempt to classify an object ID by its pattern.
-- Returns a table with suspected type info.
local function classify_id(id)
    if not id or #id ~= 4 then
        return { type = "unknown", is_custom = false }
    end

    local result = {
        type = "unknown",
        is_custom = is_custom_id(id),
    }

    if result.is_custom then
        -- Custom ID - try to determine type from first letter
        local first = id:sub(1, 1):upper()
        if first == "H" or first == "O" or first == "U" or first == "E" or first == "N" then
            result.type = "unit"
        elseif first == "A" then
            result.type = "ability"
        elseif first == "I" then
            result.type = "item"
        elseif first == "B" then
            result.type = "destructible"
        elseif first == "D" then
            result.type = "doodad"
        elseif first == "R" then
            result.type = "upgrade"
        end
    else
        -- Base game ID - use first character heuristic
        local first = id:byte(1)
        if first >= 65 and first <= 90 then
            -- Capital letter first = usually hero or ability
            if id:sub(1, 1) == "A" then
                result.type = "ability"
            elseif id:sub(1, 1) == "B" then
                result.type = "buff"
            else
                result.type = "unit"  -- Hero
            end
        else
            -- Lowercase = standard unit, item, or doodad
            result.type = "unit"
        end
    end

    return result
end
-- }}}

-- {{{ format_position
-- Format a position for error messages.
local function format_position(pos)
    if not pos then return "unknown position" end
    return string.format("(%.0f, %.0f)", pos.x or 0, pos.y or 0)
end
-- }}}
-- }}}

-- {{{ Individual validators

-- {{{ validate_unit_placements
-- Validate that unit type IDs exist in object database.
-- @param map Map object with registry and object_data
-- @param report ValidationReport to append results
function validation.validate_unit_placements(map, report)
    if not map.registry or not map.registry.units then
        return
    end

    local objectdb = map.object_data

    for _, unit in ipairs(map.registry.units) do
        report.stats.units_checked = report.stats.units_checked + 1

        local id = unit.id
        if not id then
            report:add_error("unit_placement", "Unit has no type ID", {
                creation_id = unit.creation_number,
                position = format_position(unit.position),
            })
            goto continue
        end

        -- Check if ID exists in objectdb
        local found_in_db = objectdb and objectdb:has(id)

        if found_in_db then
            -- Verify it's actually a unit type
            local obj_type = objectdb:get_type(id)
            if obj_type ~= "unit" then
                report:add_error("type_mismatch",
                    string.format("Unit placement uses %s ID '%s'", obj_type, id), {
                    creation_id = unit.creation_number,
                    position = format_position(unit.position),
                    expected_type = "unit",
                    actual_type = obj_type,
                })
            else
                report:mark_valid()
            end
        else
            -- Not in our database
            local classification = classify_id(id)

            if classification.is_custom then
                -- Custom ID not found = definite error
                report:add_error("unit_placement",
                    string.format("Custom unit ID '%s' not found in object data", id), {
                    creation_id = unit.creation_number,
                    position = format_position(unit.position),
                    player = unit.player,
                })
            else
                -- Base game ID - warning only (we don't have SLK data)
                report:add_warning("unit_placement",
                    string.format("Base game unit ID '%s' not in custom object data", id), {
                    creation_id = unit.creation_number,
                    position = format_position(unit.position),
                })
                report:mark_valid()  -- Assume valid for base game
            end
        end

        ::continue::
    end
end
-- }}}

-- {{{ validate_doodad_placements
-- Validate that doodad type IDs exist in object database.
-- @param map Map object with registry and object_data
-- @param report ValidationReport to append results
function validation.validate_doodad_placements(map, report)
    if not map.registry or not map.registry.doodads then
        return
    end

    local objectdb = map.object_data

    for _, doodad in ipairs(map.registry.doodads) do
        report.stats.doodads_checked = report.stats.doodads_checked + 1

        local id = doodad.id
        if not id then
            report:add_error("doodad_placement", "Doodad has no type ID", {
                creation_id = doodad.creation_number,
                position = format_position(doodad.position),
            })
            goto continue
        end

        -- Check if ID exists in objectdb
        local found_in_db = objectdb and objectdb:has(id)

        if found_in_db then
            -- Verify it's a doodad or destructible type
            local obj_type = objectdb:get_type(id)
            if obj_type ~= "doodad" and obj_type ~= "destructible" then
                report:add_error("type_mismatch",
                    string.format("Doodad placement uses %s ID '%s'", obj_type, id), {
                    creation_id = doodad.creation_number,
                    position = format_position(doodad.position),
                    expected_type = "doodad/destructible",
                    actual_type = obj_type,
                })
            else
                report:mark_valid()
            end
        else
            -- Not in our database
            local classification = classify_id(id)

            if classification.is_custom then
                -- Custom ID not found = definite error
                report:add_error("doodad_placement",
                    string.format("Custom doodad ID '%s' not found in object data", id), {
                    creation_id = doodad.creation_number,
                    position = format_position(doodad.position),
                })
            else
                -- Base game ID - warning only
                report:add_warning("doodad_placement",
                    string.format("Base game doodad ID '%s' not in custom object data", id), {
                    creation_id = doodad.creation_number,
                    position = format_position(doodad.position),
                })
                report:mark_valid()
            end
        end

        ::continue::
    end
end
-- }}}

-- {{{ validate_item_drops
-- Validate that item drop IDs reference valid items.
-- @param map Map object with registry and object_data
-- @param report ValidationReport to append results
function validation.validate_item_drops(map, report)
    if not map.registry or not map.registry.units then
        return
    end

    local objectdb = map.object_data

    for _, unit in ipairs(map.registry.units) do
        -- Skip units without item drops
        if not unit.item_drops or not unit.item_drops.sets then
            goto continue
        end

        for set_idx, item_set in ipairs(unit.item_drops.sets) do
            if not item_set.items then goto next_set end

            for item_idx, item in ipairs(item_set.items) do
                report.stats.item_drops_checked = report.stats.item_drops_checked + 1

                local id = item.id
                if not id or id == "\0\0\0\0" then
                    goto next_item
                end

                -- Check if ID exists in objectdb
                local found_in_db = objectdb and objectdb:has(id)

                if found_in_db then
                    -- Verify it's an item type
                    local obj_type = objectdb:get_type(id)
                    if obj_type ~= "item" then
                        report:add_error("type_mismatch",
                            string.format("Item drop uses %s ID '%s'", obj_type, id), {
                            unit_id = unit.id,
                            unit_creation_id = unit.creation_number,
                            drop_set = set_idx,
                            drop_index = item_idx,
                            expected_type = "item",
                            actual_type = obj_type,
                        })
                    else
                        report:mark_valid()
                    end
                else
                    -- Not in our database
                    local classification = classify_id(id)

                    if classification.is_custom then
                        report:add_error("item_drop",
                            string.format("Custom item ID '%s' not found in object data", id), {
                            unit_id = unit.id,
                            unit_creation_id = unit.creation_number,
                            drop_set = set_idx,
                            drop_index = item_idx,
                        })
                    else
                        report:add_warning("item_drop",
                            string.format("Base game item ID '%s' not in custom object data", id), {
                            unit_id = unit.id,
                            unit_creation_id = unit.creation_number,
                        })
                        report:mark_valid()
                    end
                end

                ::next_item::
            end
            ::next_set::
        end
        ::continue::
    end
end
-- }}}

-- {{{ validate_ability_references
-- Validate that ability IDs reference valid abilities.
-- @param map Map object with registry and object_data
-- @param report ValidationReport to append results
function validation.validate_ability_references(map, report)
    if not map.registry or not map.registry.units then
        return
    end

    local objectdb = map.object_data

    for _, unit in ipairs(map.registry.units) do
        -- Skip units without abilities
        if not unit.abilities or #unit.abilities == 0 then
            goto continue
        end

        for ability_idx, ability in ipairs(unit.abilities) do
            report.stats.abilities_checked = report.stats.abilities_checked + 1

            local id = ability.id
            if not id or id == "\0\0\0\0" then
                goto next_ability
            end

            -- Check if ID exists in objectdb
            local found_in_db = objectdb and objectdb:has(id)

            if found_in_db then
                -- Verify it's an ability type
                local obj_type = objectdb:get_type(id)
                if obj_type ~= "ability" then
                    report:add_error("type_mismatch",
                        string.format("Ability reference uses %s ID '%s'", obj_type, id), {
                        unit_id = unit.id,
                        unit_creation_id = unit.creation_number,
                        ability_index = ability_idx,
                        expected_type = "ability",
                        actual_type = obj_type,
                    })
                else
                    report:mark_valid()
                end
            else
                -- Not in our database
                local classification = classify_id(id)

                if classification.is_custom then
                    report:add_error("ability_reference",
                        string.format("Custom ability ID '%s' not found in object data", id), {
                        unit_id = unit.id,
                        unit_creation_id = unit.creation_number,
                        ability_index = ability_idx,
                        ability_level = ability.level,
                    })
                else
                    report:add_warning("ability_reference",
                        string.format("Base game ability ID '%s' not in custom object data", id), {
                        unit_id = unit.id,
                        unit_creation_id = unit.creation_number,
                    })
                    report:mark_valid()
                end
            end

            ::next_ability::
        end
        ::continue::
    end
end
-- }}}

-- {{{ validate_waygates
-- Validate that waygate destinations point to existing regions.
-- @param map Map object with registry
-- @param report ValidationReport to append results
function validation.validate_waygates(map, report)
    if not map.registry or not map.registry.units then
        return
    end

    -- Build a set of valid region creation numbers
    local valid_regions = {}
    if map.registry.regions then
        for _, region in ipairs(map.registry.regions) do
            if region.creation_number then
                valid_regions[region.creation_number] = region
            end
        end
    end

    for _, unit in ipairs(map.registry.units) do
        -- Skip units without waygate destination
        if not unit.waygate_dest or unit.waygate_dest < 0 then
            goto continue
        end

        report.stats.waygates_checked = report.stats.waygates_checked + 1

        local target = valid_regions[unit.waygate_dest]
        if target then
            report:mark_valid()
        else
            report:add_error("waygate",
                string.format("Waygate destination region %d does not exist", unit.waygate_dest), {
                unit_id = unit.id,
                unit_creation_id = unit.creation_number,
                position = format_position(unit.position),
                target_region_id = unit.waygate_dest,
            })
        end

        ::continue::
    end
end
-- }}}

-- {{{ validate_region_sounds
-- Validate that region ambient sounds reference existing sound definitions.
-- @param map Map object with registry
-- @param report ValidationReport to append results
function validation.validate_region_sounds(map, report)
    if not map.registry or not map.registry.regions then
        return
    end

    -- Build a set of valid sound names
    local valid_sounds = {}
    if map.registry.sounds then
        for _, sound in ipairs(map.registry.sounds) do
            if sound.name then
                valid_sounds[sound.name] = sound
            end
        end
    end

    for _, region in ipairs(map.registry.regions) do
        -- Skip regions without ambient sound
        if not region.ambient_sound or region.ambient_sound == "" then
            goto continue
        end

        report.stats.sounds_checked = report.stats.sounds_checked + 1

        local sound = valid_sounds[region.ambient_sound]
        if sound then
            report:mark_valid()
        else
            report:add_warning("region_sound",
                string.format("Region ambient sound '%s' not found in sound definitions",
                    region.ambient_sound), {
                region_name = region.name,
                region_creation_id = region.creation_number,
                sound_name = region.ambient_sound,
            })
        end

        ::continue::
    end
end
-- }}}
-- }}}

-- {{{ Main validation function

-- {{{ validate_map
-- Run all validators on a map and return a comprehensive report.
-- @param map Loaded Map object (from data.load)
-- @return ValidationReport with all errors and warnings
function validation.validate_map(map)
    local report = ValidationReport.new()

    if not map then
        report:add_error("validation", "No map provided")
        return report
    end

    if not map.registry then
        report:add_warning("validation", "Map has no object registry - no placements to validate")
    end

    if not map.object_data then
        report:add_warning("validation",
            "Map has no object data - cannot validate custom IDs (only base game)")
    end

    -- Run all validators
    validation.validate_unit_placements(map, report)
    validation.validate_doodad_placements(map, report)
    validation.validate_item_drops(map, report)
    validation.validate_ability_references(map, report)
    validation.validate_waygates(map, report)
    validation.validate_region_sounds(map, report)

    return report
end
-- }}}
-- }}}

-- {{{ Report formatting

-- {{{ format_report
-- Format a validation report as a human-readable string.
-- @param report ValidationReport object
-- @return Formatted string
function validation.format_report(report)
    local lines = {}

    lines[#lines + 1] = "=== Validation Report ==="
    lines[#lines + 1] = ""

    -- Summary
    local summary = report:summary()
    lines[#lines + 1] = string.format("Total references checked: %d", summary.total_checked)
    lines[#lines + 1] = string.format("Valid: %d", summary.valid)
    lines[#lines + 1] = string.format("Errors: %d", summary.errors)
    lines[#lines + 1] = string.format("Warnings: %d", summary.warnings)
    lines[#lines + 1] = ""

    -- Detailed stats
    lines[#lines + 1] = "Checked:"
    lines[#lines + 1] = string.format("  Unit placements: %d", report.stats.units_checked)
    lines[#lines + 1] = string.format("  Doodad placements: %d", report.stats.doodads_checked)
    lines[#lines + 1] = string.format("  Item drops: %d", report.stats.item_drops_checked)
    lines[#lines + 1] = string.format("  Ability references: %d", report.stats.abilities_checked)
    lines[#lines + 1] = string.format("  Waygates: %d", report.stats.waygates_checked)
    lines[#lines + 1] = string.format("  Region sounds: %d", report.stats.sounds_checked)
    lines[#lines + 1] = ""

    -- Errors
    if #report.errors > 0 then
        lines[#lines + 1] = "ERRORS:"
        for i, err in ipairs(report.errors) do
            lines[#lines + 1] = string.format("  [%d] %s: %s", i, err.category, err.message)
            -- Show key details
            if err.details then
                for k, v in pairs(err.details) do
                    if k ~= "position" then
                        lines[#lines + 1] = string.format("       %s: %s", k, tostring(v))
                    end
                end
            end
        end
        lines[#lines + 1] = ""
    end

    -- Warnings (show first 10)
    if #report.warnings > 0 then
        lines[#lines + 1] = "WARNINGS:"
        local show_count = math.min(10, #report.warnings)
        for i = 1, show_count do
            local warn = report.warnings[i]
            lines[#lines + 1] = string.format("  [%d] %s: %s", i, warn.category, warn.message)
        end
        if #report.warnings > show_count then
            lines[#lines + 1] = string.format("  ... and %d more warnings",
                #report.warnings - show_count)
        end
        lines[#lines + 1] = ""
    end

    -- Overall result
    if report:is_valid() then
        lines[#lines + 1] = "RESULT: PASSED (no errors)"
    else
        lines[#lines + 1] = "RESULT: FAILED (" .. #report.errors .. " errors)"
    end

    return table.concat(lines, "\n")
end
-- }}}
-- }}}

-- {{{ Module exports
validation.ValidationReport = ValidationReport
validation.is_custom_id = is_custom_id
validation.classify_id = classify_id
-- }}}

return validation
