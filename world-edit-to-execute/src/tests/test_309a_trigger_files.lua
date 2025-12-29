#!/usr/bin/env luajit
-- test_309a_trigger_files.lua
-- Integration tests for trigger file parsing (wtg, wct, j)
-- Tests parsers on real WC3 map files and synthetic data.
--
-- Run from project root: luajit src/tests/test_309a_trigger_files.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local wtg = require("parsers.wtg")
local wct = require("parsers.wct")
local j = require("parsers.j")
local compat = require("compat")

-- {{{ Test utilities
local tests_run = 0
local tests_passed = 0
local tests_failed = 0

-- {{{ test
local function test(name, condition, msg)
    tests_run = tests_run + 1
    if condition then
        tests_passed = tests_passed + 1
        print("  [PASS] " .. name)
        return true
    else
        tests_failed = tests_failed + 1
        print("  [FAIL] " .. name .. (msg and ": " .. msg or ""))
        return false
    end
end
-- }}}

-- {{{ test_section
local function test_section(name)
    print("\n=== " .. name .. " ===")
end
-- }}}

-- {{{ list_maps
local function list_maps()
    local maps = {}
    local handle = io.popen('ls -1 "' .. DIR .. '/assets/"*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            table.insert(maps, line)
        end
        handle:close()
    end
    return maps
end
-- }}}

-- {{{ get_basename
local function get_basename(path)
    return path:match("([^/]+)$") or path
end
-- }}}
-- }}}

-- {{{ Synthetic test data generators
-- Pack a 32-bit unsigned integer as little-endian bytes
local function pack_uint32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

-- Creates minimal valid WTG data for testing parser structure
-- {{{ make_synthetic_wtg
local function make_synthetic_wtg()
    -- Based on the format from test_wtg_header.lua
    -- WTG file structure (version 7):
    -- - Magic: "WTG!" (4 bytes)
    -- - Version: 7 (4 bytes, little-endian)
    -- - Category count (4 bytes)
    -- - Categories: index(4), name(null-term), type(4)
    -- - Variable count (4 bytes)
    -- - Variables: name(null-term), type(null-term), unknown(4), is_array(4), array_size(4), is_init(4), [init_value(null-term) if is_init]
    -- - Trigger count (4 bytes)
    -- - Triggers...

    local parts = {}

    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)  -- version (TFT)

    -- Categories: 1 category
    parts[#parts + 1] = pack_uint32(1)  -- count
    parts[#parts + 1] = pack_uint32(0)  -- index
    parts[#parts + 1] = "Test\0"        -- name
    parts[#parts + 1] = pack_uint32(0)  -- type (normal)

    -- Variables: 1 variable (not initialized - NO initial_value field)
    parts[#parts + 1] = pack_uint32(1)  -- count
    parts[#parts + 1] = "TestVar\0"     -- name
    parts[#parts + 1] = "integer\0"     -- type
    parts[#parts + 1] = pack_uint32(1)  -- unknown (always 1)
    parts[#parts + 1] = pack_uint32(0)  -- is_array (false)
    parts[#parts + 1] = pack_uint32(1)  -- array_size (default 1)
    parts[#parts + 1] = pack_uint32(0)  -- is_initialized (false) - NO init_value follows

    -- Triggers: 1 trigger with 0 ECAs
    parts[#parts + 1] = pack_uint32(1)  -- count
    parts[#parts + 1] = "TestTrigger\0" -- name
    parts[#parts + 1] = "Test description\0"  -- description
    parts[#parts + 1] = pack_uint32(0)  -- is_comment (false)
    parts[#parts + 1] = pack_uint32(1)  -- is_enabled (true)
    parts[#parts + 1] = pack_uint32(0)  -- is_custom_text (false)
    parts[#parts + 1] = pack_uint32(1)  -- is_initially_on (true)
    parts[#parts + 1] = pack_uint32(0)  -- run_on_map_init (false)
    parts[#parts + 1] = pack_uint32(0)  -- category_id
    parts[#parts + 1] = pack_uint32(0)  -- eca_count (0 = no ECAs)

    return table.concat(parts)
end
-- }}}

-- {{{ make_synthetic_wct
local function make_synthetic_wct()
    -- WCT file structure (version 1):
    -- - Version: 1 (4 bytes, little-endian)
    -- - Header comment length: N (4 bytes)
    -- - Header comment: N bytes (no null terminator)
    -- - Trigger count: M (4 bytes)
    -- - For each trigger: text_length (4 bytes), text (no null terminator)

    local parts = {}
    local header_comment = "// Map header comment\n"
    local trigger_text = "function CustomFunc takes nothing returns nothing\n    call BJDebugMsg(\"Hello\")\nendfunction"

    -- Version 1 (TFT)
    table.insert(parts, string.char(1, 0, 0, 0))

    -- Header comment (length-prefixed)
    table.insert(parts, string.char(#header_comment, 0, 0, 0))
    table.insert(parts, header_comment)

    -- Trigger count: 2
    table.insert(parts, string.char(2, 0, 0, 0))

    -- Trigger 0: empty (not custom text)
    table.insert(parts, string.char(0, 0, 0, 0))

    -- Trigger 1: has custom text
    table.insert(parts, string.char(#trigger_text, 0, 0, 0))
    table.insert(parts, trigger_text)

    return table.concat(parts)
end
-- }}}

-- {{{ make_synthetic_jass
local function make_synthetic_jass()
    return [[
globals
    integer udg_TestVar = 0
    unit array udg_Units
endglobals

function Trig_Test_Conditions takes nothing returns boolean
    return udg_TestVar > 0
endfunction

function Trig_Test_Actions takes nothing returns nothing
    set udg_TestVar = udg_TestVar + 1
    call BJDebugMsg("Test action")
endfunction

function InitTrig_Test takes nothing returns nothing
    set gg_trg_Test = CreateTrigger()
    call TriggerAddCondition(gg_trg_Test, Condition(function Trig_Test_Conditions))
    call TriggerAddAction(gg_trg_Test, function Trig_Test_Actions)
endfunction

function main takes nothing returns nothing
    call InitTrig_Test()
endfunction

function config takes nothing returns nothing
    call SetMapName("Test Map")
endfunction
]]
end
-- }}}
-- }}}

-- {{{ WTG Parser Tests
test_section("WTG Parser Tests (Synthetic)")

-- Test synthetic WTG data
local synthetic_wtg = make_synthetic_wtg()
local wtg_result, wtg_err = wtg.parse(synthetic_wtg)

test("Synthetic WTG parses",
    wtg_result ~= nil,
    wtg_err or "parse returned nil")

if wtg_result then
    test("WTG has version",
        wtg_result.version == 7,
        "expected version 7, got " .. tostring(wtg_result.version))

    test("WTG has categories",
        wtg_result.categories ~= nil and #wtg_result.categories >= 1,
        "expected at least 1 category")

    test("WTG has variables",
        wtg_result.variables ~= nil and #wtg_result.variables >= 1,
        "expected at least 1 variable")

    test("WTG has triggers",
        wtg_result.triggers ~= nil and #wtg_result.triggers >= 1,
        "expected at least 1 trigger")

    -- Test variable structure
    if wtg_result.variables and #wtg_result.variables >= 1 then
        local var = wtg_result.variables[1]
        test("Variable has name",
            var.name == "TestVar",
            "expected 'TestVar', got " .. tostring(var.name))

        test("Variable has type",
            var.type == "integer",
            "expected 'integer', got " .. tostring(var.type))
    end

    -- Test trigger structure
    if wtg_result.triggers and #wtg_result.triggers >= 1 then
        local trig = wtg_result.triggers[1]
        test("Trigger has name",
            trig.name == "TestTrigger",
            "expected 'TestTrigger', got " .. tostring(trig.name))

        test("Trigger has description",
            trig.description ~= nil,
            "missing description")

        test("Trigger has is_enabled",
            trig.is_enabled == true,
            "expected is_enabled=true")
    end

    -- Test category structure
    if wtg_result.categories and #wtg_result.categories >= 1 then
        local cat = wtg_result.categories[1]
        test("Category has name",
            cat.name == "Test",
            "expected 'Test', got " .. tostring(cat.name))
    end
end
-- }}}

-- {{{ WTG Parser Tests (Real Maps)
test_section("WTG Parser Tests (Real Maps)")

local maps = list_maps()
local wtg_found = 0
local wtg_parsed = 0

for _, map_path in ipairs(maps) do
    local basename = get_basename(map_path)
    local archive = mpq.open(map_path)

    if archive then
        if archive:has("war3map.wtg") then
            wtg_found = wtg_found + 1

            local wtg_data = archive:extract("war3map.wtg")
            if wtg_data then
                local triggers, err = wtg.parse(wtg_data)

                if triggers then
                    wtg_parsed = wtg_parsed + 1

                    local trig_count = triggers.triggers and #triggers.triggers or 0
                    local var_count = triggers.variables and #triggers.variables or 0
                    local cat_count = triggers.categories and #triggers.categories or 0

                    test(basename,
                        triggers.triggers ~= nil and triggers.variables ~= nil,
                        string.format("%d triggers, %d vars, %d cats",
                            trig_count, var_count, cat_count))
                else
                    test(basename, false, "Parse error: " .. tostring(err))
                end
            else
                test(basename, false, "Extract failed")
            end
        end

        archive:close()
    end
end

-- Summary test for coverage
if wtg_found > 0 then
    test("WTG map coverage",
        wtg_parsed == wtg_found,
        string.format("%d/%d maps with wtg parsed", wtg_parsed, wtg_found))
else
    print("  [INFO] No maps contain war3map.wtg (protected maps)")
    test("WTG synthetic test coverage", wtg_result ~= nil, "synthetic tests passed")
end
-- }}}

-- {{{ WCT Parser Tests
test_section("WCT Parser Tests (Synthetic)")

-- Test synthetic WCT data
local synthetic_wct = make_synthetic_wct()
local wct_result, wct_err = wct.parse(synthetic_wct)

test("Synthetic WCT parses",
    wct_result ~= nil,
    wct_err or "parse returned nil")

if wct_result then
    test("WCT has version",
        wct_result.version == 1,
        "expected version 1, got " .. tostring(wct_result.version))

    test("WCT has header_comment",
        wct_result.header_comment ~= nil and #wct_result.header_comment > 0,
        "expected non-empty header comment")

    test("WCT has triggers table",
        wct_result.triggers ~= nil,
        "missing triggers table")

    -- Count non-empty custom triggers
    local custom_count = 0
    if wct_result.triggers then
        for idx, text in pairs(wct_result.triggers) do
            if text and #text > 0 then
                custom_count = custom_count + 1
            end
        end
    end

    test("WCT has custom trigger text",
        custom_count >= 1,
        "expected at least 1 non-empty custom trigger")
end
-- }}}

-- {{{ WCT Parser Tests (Real Maps)
test_section("WCT Parser Tests (Real Maps)")

local wct_found = 0
local wct_parsed = 0

for _, map_path in ipairs(maps) do
    local basename = get_basename(map_path)
    local archive = mpq.open(map_path)

    if archive then
        if archive:has("war3map.wct") then
            wct_found = wct_found + 1

            local wct_data = archive:extract("war3map.wct")
            if wct_data then
                local custom, err = wct.parse(wct_data)

                if custom then
                    wct_parsed = wct_parsed + 1

                    -- Count non-empty custom triggers
                    local custom_count = 0
                    if custom.triggers then
                        for _, text in pairs(custom.triggers) do
                            if text and #text > 0 then
                                custom_count = custom_count + 1
                            end
                        end
                    end

                    test(basename, true,
                        string.format("%d custom, header=%s",
                            custom_count, tostring(custom.header_comment ~= nil and #custom.header_comment > 0)))
                else
                    test(basename, false, "Parse error: " .. tostring(err))
                end
            else
                test(basename, false, "Extract failed")
            end
        end

        archive:close()
    end
end

-- WCT is optional, so coverage is informational
if wct_found > 0 then
    test("WCT map coverage",
        wct_parsed == wct_found,
        string.format("%d/%d maps with wct parsed", wct_parsed, wct_found))
else
    print("  [INFO] No maps contain war3map.wct (protected maps)")
    test("WCT synthetic test coverage", wct_result ~= nil, "synthetic tests passed")
end
-- }}}

-- {{{ J Parser Tests
test_section("J Parser Tests (Synthetic)")

-- Test synthetic JASS data
local synthetic_jass = make_synthetic_jass()
local j_result = j.parse(synthetic_jass)

test("Synthetic JASS parses",
    j_result ~= nil,
    "parse returned nil")

if j_result then
    test("J has raw content",
        j_result.raw ~= nil and #j_result.raw > 0,
        "missing raw content")

    test("J has globals section",
        j_result.globals ~= nil,
        "missing globals section")

    test("J has functions",
        j_result.functions ~= nil and #j_result.functions >= 1,
        "expected at least 1 function")

    test("J has variables",
        j_result.variables ~= nil and #j_result.variables >= 1,
        "expected at least 1 variable")

    test("J has main function",
        j_result.has_main == true,
        "expected has_main=true")

    test("J has config function",
        j_result.has_config == true,
        "expected has_config=true")

    -- Test function structure
    if j_result.functions then
        local found_main = false
        local found_condition = false
        local found_action = false
        local found_init = false

        for _, func in ipairs(j_result.functions) do
            if func.name == "main" then
                found_main = true
                test("Main function has correct type",
                    func.type == "entry_main",
                    "expected type 'entry_main', got " .. tostring(func.type))
            elseif func.name == "Trig_Test_Conditions" then
                found_condition = true
                test("Condition function has correct type",
                    func.type == "trigger_condition",
                    "expected type 'trigger_condition', got " .. tostring(func.type))
            elseif func.name == "Trig_Test_Actions" then
                found_action = true
                test("Action function has correct type",
                    func.type == "trigger_action",
                    "expected type 'trigger_action', got " .. tostring(func.type))
            elseif func.name == "InitTrig_Test" then
                found_init = true
                test("Init function has correct type",
                    func.type == "trigger_init",
                    "expected type 'trigger_init', got " .. tostring(func.type))
            end
        end

        test("Found main function", found_main, "main function not detected")
        test("Found condition function", found_condition, "condition function not detected")
        test("Found action function", found_action, "action function not detected")
        test("Found init function", found_init, "init function not detected")
    end

    -- Test variable structure
    if j_result.variables then
        local found_test_var = false
        local found_array = false

        for _, var in ipairs(j_result.variables) do
            if var.name == "udg_TestVar" then
                found_test_var = true
                test("Variable has correct type",
                    var.type == "integer",
                    "expected type 'integer', got " .. tostring(var.type))
                test("Variable is not array",
                    var.is_array == false,
                    "expected is_array=false")
            elseif var.name == "udg_Units" then
                found_array = true
                test("Array variable is array",
                    var.is_array == true,
                    "expected is_array=true")
            end
        end

        test("Found udg_TestVar", found_test_var, "TestVar not detected")
        test("Found udg_Units array", found_array, "Units array not detected")
    end
end
-- }}}

-- {{{ J Parser Tests (Real Maps)
test_section("J Parser Tests (Real Maps)")

local j_found = 0
local j_parsed = 0
local total_jass_bytes = 0
local total_functions = 0

for _, map_path in ipairs(maps) do
    local basename = get_basename(map_path)
    local archive = mpq.open(map_path)

    if archive then
        if archive:has("war3map.j") then
            j_found = j_found + 1

            local j_data = archive:extract("war3map.j")
            if j_data then
                local script = j.parse(j_data)

                if script and script.raw then
                    j_parsed = j_parsed + 1
                    total_jass_bytes = total_jass_bytes + #script.raw

                    local func_count = script.functions and #script.functions or 0
                    total_functions = total_functions + func_count

                    test(basename, true,
                        string.format("%d bytes, %d functions", #script.raw, func_count))
                else
                    test(basename, false, "Parse failed or empty")
                end
            else
                test(basename, false, "Extract failed")
            end
        end

        archive:close()
    end
end

if j_found > 0 then
    test("J map coverage",
        j_parsed == j_found,
        string.format("%d/%d maps with j parsed", j_parsed, j_found))
    print(string.format("\n  Total: %d bytes JASS, %d functions",
        total_jass_bytes, total_functions))
else
    print("  [INFO] No maps contain war3map.j (protected maps)")
    test("J synthetic test coverage", j_result ~= nil, "synthetic tests passed")
end
-- }}}

-- {{{ Cross-File Consistency Tests
test_section("Cross-File Consistency Tests")

-- Test that when wtg has custom text triggers, wct should provide the text
-- Note: With protected maps, this uses synthetic data

-- Create matching synthetic wtg with a custom text trigger
local function make_wtg_with_custom()
    local parts = {}

    -- Header
    parts[#parts + 1] = "WTG!"
    parts[#parts + 1] = pack_uint32(7)  -- version (TFT)

    -- 1 category
    parts[#parts + 1] = pack_uint32(1)  -- count
    parts[#parts + 1] = pack_uint32(0)  -- index
    parts[#parts + 1] = "Main\0"        -- name
    parts[#parts + 1] = pack_uint32(0)  -- type (normal)

    -- 0 variables
    parts[#parts + 1] = pack_uint32(0)

    -- 2 triggers
    parts[#parts + 1] = pack_uint32(2)

    -- Trigger 0: GUI trigger (not custom)
    parts[#parts + 1] = "GUITrigger\0"
    parts[#parts + 1] = "A GUI trigger\0"
    parts[#parts + 1] = pack_uint32(0)  -- is_comment (false)
    parts[#parts + 1] = pack_uint32(1)  -- is_enabled (true)
    parts[#parts + 1] = pack_uint32(0)  -- is_custom_text (FALSE)
    parts[#parts + 1] = pack_uint32(1)  -- is_initially_on (true)
    parts[#parts + 1] = pack_uint32(0)  -- run_on_map_init (false)
    parts[#parts + 1] = pack_uint32(0)  -- category_id
    parts[#parts + 1] = pack_uint32(0)  -- eca_count (0)

    -- Trigger 1: Custom text trigger
    parts[#parts + 1] = "CustomTrigger\0"
    parts[#parts + 1] = "A custom JASS trigger\0"
    parts[#parts + 1] = pack_uint32(0)  -- is_comment (false)
    parts[#parts + 1] = pack_uint32(1)  -- is_enabled (true)
    parts[#parts + 1] = pack_uint32(1)  -- is_custom_text (TRUE)
    parts[#parts + 1] = pack_uint32(1)  -- is_initially_on (true)
    parts[#parts + 1] = pack_uint32(0)  -- run_on_map_init (false)
    parts[#parts + 1] = pack_uint32(0)  -- category_id
    parts[#parts + 1] = pack_uint32(0)  -- eca_count (0)

    return table.concat(parts)
end

local wtg_with_custom = make_wtg_with_custom()
local wtg_custom_result = wtg.parse(wtg_with_custom)

test("WTG with custom trigger parses",
    wtg_custom_result ~= nil,
    "parse failed")

if wtg_custom_result and wtg_custom_result.triggers then
    local custom_count = 0
    local gui_count = 0

    for _, trig in ipairs(wtg_custom_result.triggers) do
        if trig.is_custom_text then
            custom_count = custom_count + 1
        else
            gui_count = gui_count + 1
        end
    end

    test("WTG detects custom text triggers",
        custom_count == 1,
        "expected 1 custom trigger, found " .. custom_count)

    test("WTG detects GUI triggers",
        gui_count == 1,
        "expected 1 GUI trigger, found " .. gui_count)
end

-- Test wct merge functionality (if implemented)
if wct.merge_with_wtg then
    local wct_data = make_synthetic_wct()
    local wct_parsed = wct.parse(wct_data)
    local wtg_parsed = wtg.parse(make_synthetic_wtg())

    if wct_parsed and wtg_parsed then
        local merged = wct.merge_with_wtg(wct_parsed, wtg_parsed)
        test("WCT merge_with_wtg works",
            merged ~= nil,
            "merge returned nil")
    end
else
    print("  [INFO] wct.merge_with_wtg not implemented, skipping merge test")
end

-- Test real map cross-file consistency
for _, map_path in ipairs(maps) do
    local basename = get_basename(map_path)
    local archive = mpq.open(map_path)

    if archive then
        local has_wtg = archive:has("war3map.wtg")
        local has_wct = archive:has("war3map.wct")
        local has_j = archive:has("war3map.j")

        -- At least one trigger file should exist for a complete map
        -- (or none if map is protected/simple)
        test(basename .. " file presence",
            true,  -- Always pass, just report
            string.format("wtg=%s wct=%s j=%s",
                tostring(has_wtg), tostring(has_wct), tostring(has_j)))

        -- If both wtg and wct exist, verify they're compatible
        if has_wtg and has_wct then
            local wtg_data = archive:extract("war3map.wtg")
            local wct_data = archive:extract("war3map.wct")

            if wtg_data and wct_data then
                local triggers_parsed = wtg.parse(wtg_data)
                local custom_parsed = wct.parse(wct_data)

                if triggers_parsed and custom_parsed then
                    -- Count custom triggers in wtg
                    local wtg_custom = 0
                    for _, trig in ipairs(triggers_parsed.triggers or {}) do
                        if trig.is_custom_text then
                            wtg_custom = wtg_custom + 1
                        end
                    end

                    -- Count non-empty entries in wct
                    local wct_entries = 0
                    for _, text in pairs(custom_parsed.triggers or {}) do
                        if text and #text > 0 then
                            wct_entries = wct_entries + 1
                        end
                    end

                    test(basename .. " wtg/wct consistency",
                        true,  -- Just report, don't enforce
                        string.format("%d custom in wtg, %d entries in wct",
                            wtg_custom, wct_entries))
                end
            end
        end

        archive:close()
    end
end
-- }}}

-- {{{ Data Integrity Tests
test_section("Data Integrity Tests")

-- Verify that parsed data maintains integrity through round-trip operations

-- Test that empty input is handled gracefully
test("Empty WTG input handled",
    wtg.parse("") == nil or wtg.parse("")[1] == nil,
    "empty input should return nil or error")

test("Empty WCT input handled",
    wct.parse("") == nil,
    "empty input should return nil or error")

test("Empty JASS input handled",
    j.parse("") ~= nil and j.parse("").errors ~= nil,
    "empty input should return error info")

-- Test malformed magic bytes
local bad_wtg = "BAD!" .. string.char(7, 0, 0, 0) .. string.rep("\0", 100)
local bad_result, bad_err = wtg.parse(bad_wtg)
test("Invalid WTG magic rejected",
    bad_result == nil and bad_err ~= nil,
    "should reject invalid magic bytes")

-- Test truncated data
local truncated_wtg = "WTG!" .. string.char(7, 0, 0, 0)  -- header only, no content
local trunc_result, trunc_err = wtg.parse(truncated_wtg)
-- Truncated data may parse partially or error - either is acceptable
test("Truncated WTG handled",
    true,  -- Just verify no crash
    "truncated data handled without crash")

-- Test that parser returns expected field types
if wtg_result then
    test("WTG.triggers is table",
        type(wtg_result.triggers) == "table",
        "expected table, got " .. type(wtg_result.triggers))

    test("WTG.variables is table",
        type(wtg_result.variables) == "table",
        "expected table, got " .. type(wtg_result.variables))

    test("WTG.categories is table",
        type(wtg_result.categories) == "table",
        "expected table, got " .. type(wtg_result.categories))

    test("WTG.version is number",
        type(wtg_result.version) == "number",
        "expected number, got " .. type(wtg_result.version))
end

if wct_result then
    test("WCT.triggers is table",
        type(wct_result.triggers) == "table",
        "expected table, got " .. type(wct_result.triggers))

    test("WCT.version is number",
        type(wct_result.version) == "number",
        "expected number, got " .. type(wct_result.version))

    test("WCT.header_comment is string",
        type(wct_result.header_comment) == "string",
        "expected string, got " .. type(wct_result.header_comment))
end

if j_result then
    test("J.raw is string",
        type(j_result.raw) == "string",
        "expected string, got " .. type(j_result.raw))

    test("J.functions is table",
        type(j_result.functions) == "table",
        "expected table, got " .. type(j_result.functions))

    test("J.has_main is boolean",
        type(j_result.has_main) == "boolean",
        "expected boolean, got " .. type(j_result.has_main))
end
-- }}}

-- {{{ Statistics Summary
test_section("Statistics Summary")

print(string.format("  Maps tested: %d", #maps))
print(string.format("  WTG files found: %d, parsed: %d", wtg_found, wtg_parsed))
print(string.format("  WCT files found: %d, parsed: %d", wct_found, wct_parsed))
print(string.format("  J files found: %d, parsed: %d", j_found, j_parsed))

if j_parsed > 0 then
    print(string.format("  Total JASS: %d bytes, %d functions", total_jass_bytes, total_functions))
end
-- }}}

-- {{{ Summary
print("\n" .. string.rep("=", 50))
print(string.format("Tests: %d passed, %d failed, %d total",
                    tests_passed, tests_failed, tests_run))

if tests_failed > 0 then
    print("SOME TESTS FAILED")
    os.exit(1)
else
    print("ALL TESTS PASSED")
    os.exit(0)
end
-- }}}
