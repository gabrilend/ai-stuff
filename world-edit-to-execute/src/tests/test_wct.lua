-- war3map.wct Parser Test
-- Tests the wct parser with synthetic data and real map files.
-- Run from project root: lua src/tests/test_wct.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local mpq = require("mpq")
local wct = require("parsers.wct")

-- {{{ Test configuration
local TEST_MAP = DIR .. "/assets/DAoW-2.1.w3x"
-- }}}

-- {{{ Utility functions
local function print_separator(title)
    print("\n" .. string.rep("=", 60))
    print(title)
    print(string.rep("=", 60))
end

local function test(name, fn)
    io.write("Testing " .. name .. "... ")
    local ok, err = pcall(fn)
    if ok then
        print("PASS")
        return true
    else
        print("FAIL: " .. tostring(err))
        return false
    end
end

-- {{{ pack_int32
-- Packs an integer as little-endian int32
local function pack_int32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end
-- }}}

-- {{{ create_wct_data
-- Creates synthetic WCT data for testing
local function create_wct_data(version, header_comment, triggers)
    local parts = {}

    -- Version
    parts[#parts + 1] = pack_int32(version)

    -- Header comment (only for version >= 1)
    if version >= 1 then
        if header_comment and #header_comment > 0 then
            parts[#parts + 1] = pack_int32(#header_comment)
            parts[#parts + 1] = header_comment
        else
            parts[#parts + 1] = pack_int32(0)
        end
    end

    -- Trigger count
    parts[#parts + 1] = pack_int32(#triggers)

    -- Trigger entries
    for _, text in ipairs(triggers) do
        if text and #text > 0 then
            parts[#parts + 1] = pack_int32(#text)
            parts[#parts + 1] = text
        else
            parts[#parts + 1] = pack_int32(0)
        end
    end

    return table.concat(parts)
end
-- }}}
-- }}}

-- {{{ Synthetic data tests
local function run_synthetic_tests()
    local passed = 0
    local failed = 0

    print_separator("Synthetic WCT Data Tests")

    -- Test 1: Empty WCT (no triggers)
    if test("Empty WCT v1", function()
        local data = create_wct_data(1, "", {})
        local result = assert(wct.parse(data))
        assert(result.version == 1, "wrong version")
        assert(result.header_comment == "", "header should be empty")
        assert(result.trigger_count == 0, "should have 0 triggers")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 2: WCT with header comment
    if test("WCT with header comment", function()
        local header = "// Custom header\nglobals\n    integer myGlobal = 5\nendglobals"
        local data = create_wct_data(1, header, {})
        local result = assert(wct.parse(data))
        assert(result.header_comment == header, "header mismatch")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 3: WCT with mixed triggers (some custom, some not)
    if test("WCT with mixed triggers", function()
        local triggers = {
            "",  -- Not custom
            "function Trig_Test_Actions takes nothing returns nothing\n    call DisplayTextToPlayer(Player(0), 0, 0, \"Hello\")\nendfunction",
            "",  -- Not custom
            "function MyCustomFunc takes nothing returns nothing\nendfunction",
        }
        local data = create_wct_data(1, "", triggers)
        local result = assert(wct.parse(data))
        assert(result.trigger_count == 4, "should have 4 triggers")
        assert(result.triggers[1] == nil, "trigger 1 should be nil")
        assert(result.triggers[2] ~= nil, "trigger 2 should have text")
        assert(result.triggers[3] == nil, "trigger 3 should be nil")
        assert(result.triggers[4] ~= nil, "trigger 4 should have text")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 4: Version 0 (ROC)
    if test("WCT v0 (no header)", function()
        local triggers = { "// Custom trigger" }
        local data = create_wct_data(0, nil, triggers)
        local result = assert(wct.parse(data))
        assert(result.version == 0, "wrong version")
        assert(result.header_comment == "", "v0 should have no header")
        assert(result.triggers[1] ~= nil, "should have trigger 1")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 5: get_custom_trigger_count
    if test("get_custom_trigger_count", function()
        local triggers = { "", "custom1", "", "custom2", "custom3" }
        local data = create_wct_data(1, "", triggers)
        local result = assert(wct.parse(data))
        local count = wct.get_custom_trigger_count(result)
        assert(count == 3, "expected 3 custom triggers, got " .. count)
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 6: format function
    if test("wct.format()", function()
        local header = "// Map header"
        local triggers = { "", "function Test takes nothing returns nothing\nendfunction" }
        local data = create_wct_data(1, header, triggers)
        local result = assert(wct.parse(data))
        local formatted = wct.format(result)
        assert(formatted and #formatted > 0, "format returned empty")
        assert(formatted:find("WCT"), "missing title")
        assert(formatted:find("Version: 1"), "missing version")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 7: merge_with_wtg
    if test("merge_with_wtg", function()
        local triggers = { "", "custom code", "" }
        local data = create_wct_data(1, "// Header", triggers)
        local wct_result = assert(wct.parse(data))

        -- Create mock WTG data
        local wtg_data = {
            triggers = {
                { name = "Init" },
                { name = "CustomTrigger" },
                { name = "OtherTrigger" },
            }
        }

        local ok, err = wct.merge_with_wtg(wct_result, wtg_data)
        assert(ok, "merge failed: " .. tostring(err))
        assert(wtg_data.header_comment == "// Header", "header not merged")
        assert(wtg_data.triggers[1].custom_jass == nil, "trigger 1 should have no custom")
        assert(wtg_data.triggers[2].custom_jass == "custom code", "trigger 2 should have custom")
        assert(wtg_data.triggers[3].custom_jass == nil, "trigger 3 should have no custom")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 8: Error handling - empty data
    if test("Error on empty data", function()
        local result, err = wct.parse("")
        assert(result == nil, "should return nil")
        assert(err ~= nil, "should return error")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 9: Error handling - nil data
    if test("Error on nil data", function()
        local result, err = wct.parse(nil)
        assert(result == nil, "should return nil")
        assert(err ~= nil, "should return error")
    end) then passed = passed + 1 else failed = failed + 1 end

    return passed, failed
end
-- }}}

-- {{{ Real map tests
local function test_all_maps()
    print_separator("Testing All Available Maps")

    local maps_dir = DIR .. "/assets"
    local handle = io.popen("ls " .. maps_dir .. "/*.w3x " .. maps_dir .. "/*.w3m 2>/dev/null")
    if not handle then
        print("Cannot list maps directory")
        return 0, 0
    end

    local maps = {}
    for line in handle:lines() do
        maps[#maps + 1] = line
    end
    handle:close()

    print("Found " .. #maps .. " map files\n")

    local success_count = 0
    local fail_count = 0
    local no_wct_count = 0

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        io.write(string.format("%-50s ", map_name))

        local archive, err = mpq.open(map_path)
        if not archive then
            print("OPEN FAIL: " .. err)
            fail_count = fail_count + 1
        else
            if not archive:has("war3map.wct") then
                print("NO WCT")
                no_wct_count = no_wct_count + 1
                success_count = success_count + 1  -- Not a failure
            else
                local wct_data, wct_err = archive:extract("war3map.wct")
                if not wct_data then
                    print("EXTRACT FAIL: " .. wct_err)
                    fail_count = fail_count + 1
                else
                    local result, parse_err = wct.parse(wct_data)
                    if result then
                        local custom_count = wct.get_custom_trigger_count(result)
                        local header_len = result.header_comment and #result.header_comment or 0
                        print(string.format("OK v%d %d/%d custom (hdr=%d)",
                            result.version, custom_count, result.trigger_count, header_len))
                        success_count = success_count + 1
                    else
                        print("PARSE FAIL: " .. tostring(parse_err))
                        fail_count = fail_count + 1
                    end
                end
            end
            archive:close()
        end
    end

    print("")
    print(string.format("Success: %d / %d (%d maps without wct)",
        success_count, success_count + fail_count, no_wct_count))

    return success_count, fail_count
end
-- }}}

-- {{{ Main
local function main()
    local total_passed = 0
    local total_failed = 0

    -- Run synthetic tests
    local syn_passed, syn_failed = run_synthetic_tests()
    total_passed = total_passed + syn_passed
    total_failed = total_failed + syn_failed

    print_separator("Synthetic Tests Summary")
    print(string.format("Passed: %d / %d", syn_passed, syn_passed + syn_failed))

    -- Run tests on real maps
    local map_passed, map_failed = test_all_maps()
    total_passed = total_passed + map_passed
    total_failed = total_failed + map_failed

    -- Final summary
    print_separator("Final Results")
    print(string.format("Total Passed: %d / %d", total_passed, total_passed + total_failed))

    if total_failed > 0 then
        print("SOME TESTS FAILED")
        return false
    else
        print("ALL TESTS PASSED")
        return true
    end
end
-- }}}

local ok = main()
os.exit(ok and 0 or 1)
