#!/usr/bin/env lua
-- test_validation.lua
-- Tests for the cross-reference validation module (Issue 111).
--
-- Tests all validators:
--   - Unit placement validation
--   - Doodad placement validation
--   - Item drop validation
--   - Ability reference validation
--   - Waygate destination validation
--   - Region sound validation
--   - Type classification checks

package.path = package.path .. ";src/?.lua;src/?/init.lua"

local validation = require("validation")

-- {{{ Test utilities
local passed = 0
local failed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print(string.format("[PASS] %s", name))
    else
        failed = failed + 1
        print(string.format("[FAIL] %s: %s", name, err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "expected true, got false")
    end
end

local function assert_false(value, msg)
    if value then
        error(msg or "expected false, got true")
    end
end
-- }}}

-- {{{ Mock objects for testing

-- {{{ create_mock_objectdb
-- Create a mock ObjectDatabase with specified objects.
local function create_mock_objectdb(objects)
    local db = {
        _objects = {},
        counts = {
            units = 0,
            abilities = 0,
            items = 0,
            destructibles = 0,
            doodads = 0,
            buffs = 0,
            upgrades = 0,
        },
    }

    for _, obj in ipairs(objects or {}) do
        db._objects[obj.id] = obj
        local key = obj.type .. "s"
        if db.counts[key] then
            db.counts[key] = db.counts[key] + 1
        end
    end

    function db:has(id)
        return self._objects[id] ~= nil
    end

    function db:get_type(id)
        local obj = self._objects[id]
        return obj and obj.type or nil
    end

    function db:get(id)
        return self._objects[id]
    end

    function db:count()
        local total = 0
        for _, c in pairs(self.counts) do
            total = total + c
        end
        return total
    end

    return db
end
-- }}}

-- {{{ create_mock_registry
-- Create a mock ObjectRegistry with specified objects.
local function create_mock_registry(config)
    local reg = {
        units = config.units or {},
        doodads = config.doodads or {},
        regions = config.regions or {},
        sounds = config.sounds or {},
        cameras = {},
        counts = {
            units = #(config.units or {}),
            doodads = #(config.doodads or {}),
            regions = #(config.regions or {}),
            sounds = #(config.sounds or {}),
            cameras = 0,
        },
    }
    return reg
end
-- }}}

-- {{{ create_mock_map
-- Create a mock Map object.
local function create_mock_map(config)
    local map = {
        registry = config.registry,
        object_data = config.object_data,
    }
    return map
end
-- }}}
-- }}}

-- {{{ Tests for helper functions

print("\n=== Testing Helper Functions ===\n")

test("is_custom_id: identifies custom IDs with digits", function()
    assert_true(validation.is_custom_id("H001"), "H001 should be custom")
    assert_true(validation.is_custom_id("A003"), "A003 should be custom")
    assert_true(validation.is_custom_id("u000"), "u000 should be custom")
    assert_true(validation.is_custom_id("I999"), "I999 should be custom")
end)

test("is_custom_id: identifies base game IDs without digits", function()
    assert_false(validation.is_custom_id("hfoo"), "hfoo should not be custom")
    assert_false(validation.is_custom_id("Hpal"), "Hpal should not be custom")
    assert_false(validation.is_custom_id("AHhb"), "AHhb should not be custom")
    assert_false(validation.is_custom_id("phea"), "phea should not be custom")
end)

test("is_custom_id: handles edge cases", function()
    assert_false(validation.is_custom_id(nil), "nil should not be custom")
    assert_false(validation.is_custom_id(""), "empty should not be custom")
    assert_false(validation.is_custom_id("abc"), "3 chars should not be custom")
    assert_false(validation.is_custom_id("abcde"), "5 chars should not be custom")
end)

test("classify_id: classifies custom unit IDs", function()
    local result = validation.classify_id("H001")
    assert_true(result.is_custom, "H001 should be custom")
    assert_eq(result.type, "unit", "H001 should be unit type")
end)

test("classify_id: classifies custom ability IDs", function()
    local result = validation.classify_id("A003")
    assert_true(result.is_custom, "A003 should be custom")
    assert_eq(result.type, "ability", "A003 should be ability type")
end)

test("classify_id: classifies custom item IDs", function()
    local result = validation.classify_id("I002")
    assert_true(result.is_custom, "I002 should be custom")
    assert_eq(result.type, "item", "I002 should be item type")
end)
-- }}}

-- {{{ Tests for ValidationReport

print("\n=== Testing ValidationReport ===\n")

test("ValidationReport: initializes with empty errors/warnings", function()
    local report = validation.ValidationReport.new()
    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(#report.warnings, 0, "should have no warnings")
    assert_true(report:is_valid(), "should be valid initially")
end)

test("ValidationReport: add_error increments invalid count", function()
    local report = validation.ValidationReport.new()
    report:add_error("test", "Test error")
    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.stats.invalid, 1, "invalid count should be 1")
    assert_false(report:is_valid(), "should not be valid with errors")
end)

test("ValidationReport: add_warning does not affect validity", function()
    local report = validation.ValidationReport.new()
    report:add_warning("test", "Test warning")
    assert_eq(#report.warnings, 1, "should have 1 warning")
    assert_true(report:is_valid(), "warnings do not affect validity")
end)

test("ValidationReport: summary returns correct counts", function()
    local report = validation.ValidationReport.new()
    report:add_error("cat1", "Error 1")
    report:add_error("cat2", "Error 2")
    report:add_warning("cat3", "Warning 1")
    report:mark_valid()
    report:mark_valid()
    report:mark_valid()

    local summary = report:summary()
    assert_eq(summary.errors, 2, "should have 2 errors")
    assert_eq(summary.warnings, 1, "should have 1 warning")
    assert_eq(summary.valid, 3, "should have 3 valid")
    assert_eq(summary.invalid, 2, "should have 2 invalid")
    assert_eq(summary.total_checked, 5, "should have 5 total")
end)
-- }}}

-- {{{ Tests for unit placement validation

print("\n=== Testing Unit Placement Validation ===\n")

test("validate_unit_placements: valid base game unit passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                { id = "hfoo", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_unit_placements(map, report)

    -- Base game ID not in our database = warning, but still valid
    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.units_checked, 1, "should check 1 unit")
    assert_eq(report.stats.valid, 1, "should mark 1 valid")
end)

test("validate_unit_placements: custom unit in objectdb passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                { id = "H001", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({
            { id = "H001", type = "unit" },
        }),
    })

    local report = validation.ValidationReport.new()
    validation.validate_unit_placements(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.valid, 1, "should mark 1 valid")
end)

test("validate_unit_placements: custom unit not in objectdb fails", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                { id = "H001", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_unit_placements(map, report)

    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.errors[1].category, "unit_placement", "error category")
end)

test("validate_unit_placements: unit using ability ID fails type check", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                { id = "A001", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({
            { id = "A001", type = "ability" },
        }),
    })

    local report = validation.ValidationReport.new()
    validation.validate_unit_placements(map, report)

    assert_eq(#report.errors, 1, "should have 1 error for type mismatch")
    assert_eq(report.errors[1].category, "type_mismatch", "error category should be type_mismatch")
end)
-- }}}

-- {{{ Tests for doodad placement validation

print("\n=== Testing Doodad Placement Validation ===\n")

test("validate_doodad_placements: valid base game doodad passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            doodads = {
                { id = "LTlt", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_doodad_placements(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.doodads_checked, 1, "should check 1 doodad")
end)

test("validate_doodad_placements: custom doodad not in objectdb fails", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            doodads = {
                { id = "D001", creation_number = 1, position = { x = 0, y = 0 } },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_doodad_placements(map, report)

    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.errors[1].category, "doodad_placement", "error category")
end)
-- }}}

-- {{{ Tests for item drop validation

print("\n=== Testing Item Drop Validation ===\n")

test("validate_item_drops: valid item drop passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    item_drops = {
                        sets = {
                            {
                                items = {
                                    { id = "I001", chance = 100 },
                                },
                            },
                        },
                    },
                },
            },
        }),
        object_data = create_mock_objectdb({
            { id = "I001", type = "item" },
        }),
    })

    local report = validation.ValidationReport.new()
    validation.validate_item_drops(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.item_drops_checked, 1, "should check 1 item drop")
end)

test("validate_item_drops: custom item not in objectdb fails", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    item_drops = {
                        sets = {
                            {
                                items = {
                                    { id = "I999", chance = 100 },
                                },
                            },
                        },
                    },
                },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_item_drops(map, report)

    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.errors[1].category, "item_drop", "error category")
end)

test("validate_item_drops: item drop using unit ID fails type check", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    item_drops = {
                        sets = {
                            {
                                items = {
                                    { id = "H001", chance = 100 },
                                },
                            },
                        },
                    },
                },
            },
        }),
        object_data = create_mock_objectdb({
            { id = "H001", type = "unit" },
        }),
    })

    local report = validation.ValidationReport.new()
    validation.validate_item_drops(map, report)

    assert_eq(#report.errors, 1, "should have 1 error for type mismatch")
    assert_eq(report.errors[1].category, "type_mismatch", "error category")
end)
-- }}}

-- {{{ Tests for ability reference validation

print("\n=== Testing Ability Reference Validation ===\n")

test("validate_ability_references: valid ability passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    abilities = {
                        { id = "A001", level = 1 },
                    },
                },
            },
        }),
        object_data = create_mock_objectdb({
            { id = "A001", type = "ability" },
        }),
    })

    local report = validation.ValidationReport.new()
    validation.validate_ability_references(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.abilities_checked, 1, "should check 1 ability")
end)

test("validate_ability_references: custom ability not in objectdb fails", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    abilities = {
                        { id = "A999", level = 1 },
                    },
                },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_ability_references(map, report)

    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.errors[1].category, "ability_reference", "error category")
end)
-- }}}

-- {{{ Tests for waygate validation

print("\n=== Testing Waygate Validation ===\n")

test("validate_waygates: valid waygate destination passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    waygate_dest = 100,
                },
            },
            regions = {
                { name = "Target Region", creation_number = 100 },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_waygates(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.waygates_checked, 1, "should check 1 waygate")
    assert_eq(report.stats.valid, 1, "should mark 1 valid")
end)

test("validate_waygates: invalid waygate destination fails", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    waygate_dest = 999,  -- No region with this ID
                },
            },
            regions = {
                { name = "Other Region", creation_number = 100 },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_waygates(map, report)

    assert_eq(#report.errors, 1, "should have 1 error")
    assert_eq(report.errors[1].category, "waygate", "error category")
end)

test("validate_waygates: inactive waygate (-1) is skipped", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                {
                    id = "hfoo",
                    creation_number = 1,
                    position = { x = 0, y = 0 },
                    waygate_dest = -1,  -- Inactive
                },
            },
            regions = {},
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_waygates(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(report.stats.waygates_checked, 0, "should not check inactive waygates")
end)
-- }}}

-- {{{ Tests for region sound validation

print("\n=== Testing Region Sound Validation ===\n")

test("validate_region_sounds: valid sound reference passes", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            regions = {
                {
                    name = "Sound Region",
                    creation_number = 1,
                    ambient_sound = "ForestAmbience",
                },
            },
            sounds = {
                { name = "ForestAmbience" },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_region_sounds(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(#report.warnings, 0, "should have no warnings")
    assert_eq(report.stats.sounds_checked, 1, "should check 1 sound")
end)

test("validate_region_sounds: missing sound reference warns", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            regions = {
                {
                    name = "Sound Region",
                    creation_number = 1,
                    ambient_sound = "MissingSound",
                },
            },
            sounds = {
                { name = "OtherSound" },
            },
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_region_sounds(map, report)

    -- Missing sounds are warnings, not errors
    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(#report.warnings, 1, "should have 1 warning")
    assert_eq(report.warnings[1].category, "region_sound", "warning category")
end)

test("validate_region_sounds: empty sound is skipped", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            regions = {
                {
                    name = "Silent Region",
                    creation_number = 1,
                    ambient_sound = "",
                },
            },
            sounds = {},
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.ValidationReport.new()
    validation.validate_region_sounds(map, report)

    assert_eq(#report.errors, 0, "should have no errors")
    assert_eq(#report.warnings, 0, "should have no warnings")
    assert_eq(report.stats.sounds_checked, 0, "should not check empty sounds")
end)
-- }}}

-- {{{ Tests for validate_map integration

print("\n=== Testing validate_map Integration ===\n")

test("validate_map: returns report for nil map", function()
    local report = validation.validate_map(nil)
    assert_eq(#report.errors, 1, "should have 1 error")
end)

test("validate_map: warns if no registry", function()
    local map = { registry = nil, object_data = nil }
    local report = validation.validate_map(map)
    assert_eq(#report.warnings, 2, "should warn about missing registry and object_data")
end)

test("validate_map: runs all validators", function()
    local map = create_mock_map({
        registry = create_mock_registry({
            units = {
                { id = "hfoo", creation_number = 1, position = { x = 0, y = 0 } },
            },
            doodads = {
                { id = "LTlt", creation_number = 2, position = { x = 0, y = 0 } },
            },
            regions = {},
            sounds = {},
        }),
        object_data = create_mock_objectdb({}),
    })

    local report = validation.validate_map(map)

    assert_eq(report.stats.units_checked, 1, "should check units")
    assert_eq(report.stats.doodads_checked, 1, "should check doodads")
end)
-- }}}

-- {{{ Tests for format_report

print("\n=== Testing format_report ===\n")

test("format_report: produces readable output", function()
    local report = validation.ValidationReport.new()
    report:add_error("test", "Test error", { detail = "value" })
    report:add_warning("test", "Test warning")
    report:mark_valid()

    local output = validation.format_report(report)

    assert_true(output:find("Validation Report"), "should have header")
    assert_true(output:find("ERRORS:"), "should have errors section")
    assert_true(output:find("WARNINGS:"), "should have warnings section")
    assert_true(output:find("FAILED"), "should show failed result")
end)

test("format_report: shows PASSED for valid report", function()
    local report = validation.ValidationReport.new()
    report:mark_valid()

    local output = validation.format_report(report)

    assert_true(output:find("PASSED"), "should show passed result")
end)
-- }}}

-- {{{ Summary
print("\n=== Test Summary ===\n")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
print(string.format("Total: %d", passed + failed))

if failed > 0 then
    print("\nSome tests FAILED!")
    os.exit(1)
else
    print("\nAll tests PASSED!")
    os.exit(0)
end
-- }}}
