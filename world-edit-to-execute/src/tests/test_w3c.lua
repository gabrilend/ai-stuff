-- war3map.w3c Parser Test
-- Tests the w3c camera parser with synthetic data and against real map files.
-- Run from project root: lua5.4 src/tests/test_w3c.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local w3c = require("parsers.w3c")
local mpq = require("mpq")
local compat = require("compat")

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
-- }}}

-- {{{ Synthetic test data creation
local function pack_int32(n)
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

local function pack_float32(n)
    -- Use FFI if available, otherwise simple approximation
    local ffi_ok, ffi = pcall(require, "ffi")
    if ffi_ok then
        local buf = ffi.new("float[1]", n)
        return ffi.string(buf, 4)
    else
        -- Lua 5.3+ has string.pack
        if string.pack then
            return string.pack("<f", n)
        else
            -- Fallback: this won't be precise but works for testing structure
            return "\0\0\0\0"
        end
    end
end

local function create_synthetic_w3c(cameras)
    local parts = {}
    -- Header: version (0), camera count
    parts[#parts + 1] = pack_int32(0)  -- version
    parts[#parts + 1] = pack_int32(#cameras)  -- count

    for _, cam in ipairs(cameras) do
        -- 10 floats
        parts[#parts + 1] = pack_float32(cam.target_x or 0)
        parts[#parts + 1] = pack_float32(cam.target_y or 0)
        parts[#parts + 1] = pack_float32(cam.z_offset or 0)
        parts[#parts + 1] = pack_float32(cam.rotation or 90)
        parts[#parts + 1] = pack_float32(cam.aoa or 304)
        parts[#parts + 1] = pack_float32(cam.distance or 1650)
        parts[#parts + 1] = pack_float32(cam.roll or 0)
        parts[#parts + 1] = pack_float32(cam.fov or 70)
        parts[#parts + 1] = pack_float32(cam.far_clip or 5000)
        parts[#parts + 1] = pack_float32(cam.near_clip or 100)
        -- Null-terminated string
        parts[#parts + 1] = (cam.name or "Camera") .. "\0"
    end

    return table.concat(parts)
end
-- }}}

-- {{{ Synthetic data tests
local function run_synthetic_tests()
    local passed = 0
    local failed = 0

    print_separator("Synthetic Data Tests")

    -- Test 1: Empty camera list
    if test("Parse empty w3c (0 cameras)", function()
        local data = pack_int32(0) .. pack_int32(0)  -- version 0, count 0
        local result = assert(w3c.parse(data))
        assert(result.version == 0, "wrong version")
        assert(#result.cameras == 0, "should have 0 cameras")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 2: Single camera
    if test("Parse single camera", function()
        local data = create_synthetic_w3c({
            { name = "gg_cam_Camera_001", target_x = 100, target_y = 200 }
        })
        local result = assert(w3c.parse(data))
        assert(#result.cameras == 1, "should have 1 camera")
        assert(result.cameras[1].name == "gg_cam_Camera_001", "wrong name")
        -- Position might not be exact due to float packing approximation
        assert(result.cameras[1].target, "missing target")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 3: Multiple cameras
    if test("Parse multiple cameras", function()
        local data = create_synthetic_w3c({
            { name = "gg_cam_Intro" },
            { name = "gg_cam_Boss_Fight" },
            { name = "gg_cam_Victory" },
        })
        local result = assert(w3c.parse(data))
        assert(#result.cameras == 3, "should have 3 cameras")
        assert(result.cameras[1].name == "gg_cam_Intro", "wrong name 1")
        assert(result.cameras[2].name == "gg_cam_Boss_Fight", "wrong name 2")
        assert(result.cameras[3].name == "gg_cam_Victory", "wrong name 3")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 4: Name lookup
    if test("Camera lookup by name", function()
        local data = create_synthetic_w3c({
            { name = "gg_cam_Alpha" },
            { name = "gg_cam_Beta" },
        })
        local result = assert(w3c.parse(data))
        local cam = w3c.get_camera(result, "gg_cam_Beta")
        assert(cam, "camera not found")
        assert(cam.name == "gg_cam_Beta", "wrong camera returned")

        local missing = w3c.get_camera(result, "nonexistent")
        assert(missing == nil, "should return nil for missing")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 5: Format output
    if test("Format output", function()
        local data = create_synthetic_w3c({
            { name = "gg_cam_Test" },
        })
        local result = assert(w3c.parse(data))
        local formatted = w3c.format(result)
        assert(formatted and #formatted > 0, "format returned empty")
        assert(formatted:find("gg_cam_Test"), "camera name not in output")
    end) then passed = passed + 1 else failed = failed + 1 end

    -- Test 6: Invalid data handling
    if test("Reject invalid data", function()
        local result, err = w3c.parse(nil)
        assert(result == nil, "should reject nil")

        result, err = w3c.parse("")
        assert(result == nil, "should reject empty string")

        result, err = w3c.parse("short")
        assert(result == nil, "should reject short data")
    end) then passed = passed + 1 else failed = failed + 1 end

    return passed, failed
end
-- }}}

-- {{{ Test against all maps
local function test_all_maps()
    print_separator("Testing All Available Maps")

    local maps_dir = DIR .. "/assets"
    local handle = io.popen("ls " .. maps_dir .. "/*.w3x 2>/dev/null")
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
    local cameras_found = 0

    for _, map_path in ipairs(maps) do
        local map_name = map_path:match("([^/]+)$")
        io.write(string.format("%-50s ", map_name))

        local archive, err = mpq.open(map_path)
        if not archive then
            print("OPEN FAIL: " .. err)
            fail_count = fail_count + 1
        else
            local has_w3c = archive:has("war3map.w3c")
            if not has_w3c then
                print("OK (no cameras)")
                success_count = success_count + 1
            else
                local w3c_data, w3c_err = archive:extract("war3map.w3c")
                if not w3c_data then
                    print("EXTRACT FAIL: " .. w3c_err)
                    fail_count = fail_count + 1
                else
                    local result, parse_err = w3c.parse(w3c_data)
                    if result then
                        local count = #result.cameras
                        cameras_found = cameras_found + count
                        print(string.format("OK %d cameras", count))
                        success_count = success_count + 1

                        -- Print camera names if any
                        if count > 0 then
                            for i, cam in ipairs(result.cameras) do
                                print(string.format("    [%d] %s", i, cam.name))
                            end
                        end
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
    print(string.format("Success: %d / %d", success_count, success_count + fail_count))
    print(string.format("Total cameras found: %d", cameras_found))

    return success_count, fail_count
end
-- }}}

-- {{{ Main
local function main()
    print_separator("w3c Camera Parser Tests")

    local synth_passed, synth_failed = run_synthetic_tests()
    local map_passed, map_failed = test_all_maps()

    local total_passed = synth_passed + map_passed
    local total_failed = synth_failed + map_failed

    print_separator("Results")
    print(string.format("Synthetic tests: %d passed, %d failed", synth_passed, synth_failed))
    print(string.format("Map tests: %d passed, %d failed", map_passed, map_failed))
    print(string.format("Total: %d / %d", total_passed, total_passed + total_failed))

    if total_failed > 0 then
        print("\nSOME TESTS FAILED")
        os.exit(1)
    else
        print("\nALL TESTS PASSED")
        os.exit(0)
    end
end
-- }}}

main()
