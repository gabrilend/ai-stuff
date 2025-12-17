#!/usr/bin/env lua
-- Test suite for w3s (sound definitions) parser
-- Tests parsing against synthetic data since test maps lack w3s files.
-- Run from project root: lua5.4 src/tests/test_w3s.lua

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local w3s = require("parsers.w3s")
local mpq = require("mpq")

-- {{{ Test configuration
local TEST_MAPS_DIR = DIR .. "/assets"
local VERBOSE = os.getenv("VERBOSE") == "1"
-- }}}

-- {{{ Utility functions
-- {{{ log
local function log(...)
    if VERBOSE then
        print(...)
    end
end
-- }}}

-- {{{ get_map_files
local function get_map_files()
    local files = {}
    local handle = io.popen('ls "' .. TEST_MAPS_DIR .. '"/*.w3x 2>/dev/null')
    if handle then
        for line in handle:lines() do
            files[#files + 1] = line
        end
        handle:close()
    end
    return files
end
-- }}}

-- {{{ pack_int32
-- Pack a signed 32-bit integer to little-endian bytes
local function pack_int32(val)
    -- Handle negative numbers
    if val < 0 then
        val = val + 0x100000000
    end
    return string.char(
        val % 256,
        math.floor(val / 256) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 16777216) % 256
    )
end
-- }}}

-- {{{ pack_uint32
-- Pack an unsigned 32-bit integer to little-endian bytes
local function pack_uint32(val)
    return string.char(
        val % 256,
        math.floor(val / 256) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 16777216) % 256
    )
end
-- }}}

-- {{{ pack_float32
-- Pack a 32-bit float to little-endian bytes (IEEE 754)
local function pack_float32(val)
    if val == 0 then
        return "\0\0\0\0"
    end

    local sign = 0
    if val < 0 then
        sign = 0x80
        val = -val
    end

    local mantissa, exp = math.frexp(val)
    exp = exp + 126

    if exp <= 0 then
        -- Denormalized
        mantissa = math.floor(mantissa * 2^(24 + exp) + 0.5)
        exp = 0
    else
        mantissa = math.floor((mantissa * 2 - 1) * 2^23 + 0.5)
    end

    local b1 = mantissa % 256
    local b2 = math.floor(mantissa / 256) % 256
    local b3 = math.floor(mantissa / 65536) % 128 + (exp % 2) * 128
    local b4 = math.floor(exp / 2) + sign

    return string.char(b1, b2, b3, b4)
end
-- }}}

-- {{{ pack_string
-- Pack a null-terminated string
local function pack_string(str)
    return str .. "\0"
end
-- }}}

-- {{{ build_sound_entry_v1
-- Build a version 1 sound entry binary data
local function build_sound_entry_v1(sound)
    local parts = {}

    -- Strings
    parts[#parts + 1] = pack_string(sound.name or "")
    parts[#parts + 1] = pack_string(sound.file or "")
    parts[#parts + 1] = pack_string(sound.eax or "DefaultEAXON")

    -- Flags
    local flags = 0
    if sound.looping then flags = flags + 0x01 end
    if sound.sound_3d then flags = flags + 0x02 end
    if sound.stop_out_range then flags = flags + 0x04 end
    if sound.music then flags = flags + 0x08 end
    parts[#parts + 1] = pack_uint32(flags)

    -- Fade in/out
    parts[#parts + 1] = pack_int32(sound.fade_in or 10)
    parts[#parts + 1] = pack_int32(sound.fade_out or 10)

    -- Volume and pitch
    parts[#parts + 1] = pack_int32(sound.volume or -1)
    parts[#parts + 1] = pack_float32(sound.pitch or 1.0)

    -- Unknown
    parts[#parts + 1] = pack_float32(0)

    -- Channel
    parts[#parts + 1] = pack_int32(sound.channel or 0)

    -- Distance
    parts[#parts + 1] = pack_float32(sound.min_distance or 0)
    parts[#parts + 1] = pack_float32(sound.max_distance or 10000)
    parts[#parts + 1] = pack_float32(sound.cutoff_distance or 3000)

    -- Cone
    parts[#parts + 1] = pack_float32(sound.cone_inside or 0)
    parts[#parts + 1] = pack_float32(sound.cone_outside or 0)
    parts[#parts + 1] = pack_int32(sound.cone_volume or 127)
    parts[#parts + 1] = pack_float32(sound.cone_x or 0)
    parts[#parts + 1] = pack_float32(sound.cone_y or 0)
    parts[#parts + 1] = pack_float32(sound.cone_z or 0)

    return table.concat(parts)
end
-- }}}

-- {{{ build_w3s_v1
-- Build a complete version 1 w3s file
local function build_w3s_v1(sounds)
    local parts = {}

    -- Header: version and count
    parts[#parts + 1] = pack_int32(1)  -- version 1
    parts[#parts + 1] = pack_int32(#sounds)

    -- Sound entries
    for _, sound in ipairs(sounds) do
        parts[#parts + 1] = build_sound_entry_v1(sound)
    end

    return table.concat(parts)
end
-- }}}
-- }}}

-- {{{ Test cases
-- {{{ test_parse_empty
local function test_parse_empty()
    print("Testing empty file...")

    local data = pack_int32(1) .. pack_int32(0)  -- version 1, 0 sounds
    local result = w3s.parse(data)

    assert(result, "Should parse empty w3s")
    assert(result.version == 1, "Version should be 1")
    assert(#result.sounds == 0, "Should have 0 sounds")

    print("  PASS: Empty file parsing works")
end
-- }}}

-- {{{ test_parse_single_sound
local function test_parse_single_sound()
    print("Testing single sound entry...")

    local data = build_w3s_v1({
        {
            name = "gg_snd_RainLoop",
            file = "Sound\\Ambient\\RainLoop.wav",
            eax = "DefaultEAXON",
            looping = true,
            sound_3d = false,
            channel = 10,  -- Looping Ambient
            volume = -1,
            pitch = 1.0,
            fade_in = 10,
            fade_out = 10,
        }
    })

    local result = w3s.parse(data)

    assert(result, "Should parse single sound")
    assert(result.version == 1, "Version should be 1")
    assert(#result.sounds == 1, "Should have 1 sound")

    local sound = result.sounds[1]
    assert(sound.name == "gg_snd_RainLoop", "Name mismatch")
    assert(sound.file == "Sound\\Ambient\\RainLoop.wav", "File mismatch")
    assert(sound.eax == "DefaultEAXON", "EAX mismatch")
    assert(sound.flags.looping == true, "Should be looping")
    assert(sound.flags.sound_3d == false, "Should not be 3D")
    assert(sound.channel == 10, "Channel mismatch")
    assert(sound.channel_name == "Looping Ambient", "Channel name mismatch")
    assert(sound.volume == -1, "Volume mismatch")

    print("  PASS: Single sound parsing works")
end
-- }}}

-- {{{ test_parse_multiple_sounds
local function test_parse_multiple_sounds()
    print("Testing multiple sound entries...")

    local data = build_w3s_v1({
        {
            name = "gg_snd_Background",
            file = "Sound\\Music\\Background.mp3",
            eax = "DefaultEAXON",
            music = true,
            channel = 7,  -- Music
        },
        {
            name = "gg_snd_Explosion",
            file = "Sound\\Combat\\Explosion.wav",
            eax = "CombatSoundsEAX",
            sound_3d = true,
            channel = 5,  -- Combat
            min_distance = 100,
            max_distance = 5000,
            cutoff_distance = 2000,
        },
        {
            name = "gg_snd_Click",
            file = "Sound\\UI\\Click.wav",
            eax = "DefaultEAXON",
            channel = 8,  -- User Interface
            volume = 80,
        },
    })

    local result = w3s.parse(data)

    assert(result, "Should parse multiple sounds")
    assert(#result.sounds == 3, "Should have 3 sounds")

    -- Check first sound (music)
    local s1 = result.sounds[1]
    assert(s1.name == "gg_snd_Background", "Sound 1 name mismatch")
    assert(s1.flags.music == true, "Sound 1 should be music")
    assert(s1.channel == 7, "Sound 1 channel mismatch")

    -- Check second sound (3D combat)
    local s2 = result.sounds[2]
    assert(s2.name == "gg_snd_Explosion", "Sound 2 name mismatch")
    assert(s2.flags.sound_3d == true, "Sound 2 should be 3D")
    assert(s2.eax == "CombatSoundsEAX", "Sound 2 EAX mismatch")
    assert(s2.eax_name == "Combat", "Sound 2 EAX name mismatch")
    assert(s2.distance.min == 100, "Sound 2 min distance mismatch")
    assert(s2.distance.max == 5000, "Sound 2 max distance mismatch")

    -- Check third sound (UI)
    local s3 = result.sounds[3]
    assert(s3.name == "gg_snd_Click", "Sound 3 name mismatch")
    assert(s3.channel == 8, "Sound 3 channel mismatch")
    assert(s3.volume == 80, "Sound 3 volume mismatch")

    print("  PASS: Multiple sound parsing works")
end
-- }}}

-- {{{ test_parse_flags
local function test_parse_flags()
    print("Testing flag combinations...")

    -- Test all flag combinations
    local test_cases = {
        { flags = {}, expected = { looping = false, sound_3d = false, stop_out_range = false, music = false } },
        { flags = { looping = true }, expected = { looping = true, sound_3d = false, stop_out_range = false, music = false } },
        { flags = { sound_3d = true }, expected = { looping = false, sound_3d = true, stop_out_range = false, music = false } },
        { flags = { looping = true, sound_3d = true, stop_out_range = true }, expected = { looping = true, sound_3d = true, stop_out_range = true, music = false } },
        { flags = { music = true }, expected = { looping = false, sound_3d = false, stop_out_range = false, music = true } },
    }

    for i, tc in ipairs(test_cases) do
        local data = build_w3s_v1({
            {
                name = "test_" .. i,
                file = "test.wav",
                looping = tc.flags.looping,
                sound_3d = tc.flags.sound_3d,
                stop_out_range = tc.flags.stop_out_range,
                music = tc.flags.music,
            }
        })

        local result = w3s.parse(data)
        local sound = result.sounds[1]

        for flag_name, expected_value in pairs(tc.expected) do
            assert(sound.flags[flag_name] == expected_value,
                string.format("Test %d: flag %s expected %s, got %s",
                    i, flag_name, tostring(expected_value), tostring(sound.flags[flag_name])))
        end
    end

    print("  PASS: Flag parsing works")
end
-- }}}

-- {{{ test_parse_channels
local function test_parse_channels()
    print("Testing channel parsing...")

    local channels = {
        [0] = "General",
        [5] = "Combat",
        [7] = "Music",
        [10] = "Looping Ambient",
        [14] = "Fire",
    }

    for channel_id, expected_name in pairs(channels) do
        local data = build_w3s_v1({
            {
                name = "test",
                file = "test.wav",
                channel = channel_id,
            }
        })

        local result = w3s.parse(data)
        local sound = result.sounds[1]

        assert(sound.channel == channel_id, "Channel ID mismatch")
        assert(sound.channel_name == expected_name,
            string.format("Channel %d: expected '%s', got '%s'",
                channel_id, expected_name, sound.channel_name))
    end

    print("  PASS: Channel parsing works")
end
-- }}}

-- {{{ test_parse_eax_effects
local function test_parse_eax_effects()
    print("Testing EAX effect parsing...")

    local effects = {
        "DefaultEAXON",
        "CombatSoundsEAX",
        "SpellsEAX",
        "MissilesEAX",
    }

    for _, eax in ipairs(effects) do
        local data = build_w3s_v1({
            {
                name = "test",
                file = "test.wav",
                eax = eax,
            }
        })

        local result = w3s.parse(data)
        local sound = result.sounds[1]

        assert(sound.eax == eax, "EAX mismatch: expected " .. eax)
        assert(sound.eax_name ~= nil, "EAX name should not be nil")
    end

    print("  PASS: EAX effect parsing works")
end
-- }}}

-- {{{ test_sound_table_class
local function test_sound_table_class()
    print("Testing SoundTable class...")

    local data = build_w3s_v1({
        { name = "gg_snd_Rain", file = "rain.wav" },
        { name = "gg_snd_Wind", file = "wind.wav" },
        { name = "gg_snd_Thunder", file = "thunder.wav" },
    })

    local st = w3s.new(data)

    -- Test count
    assert(st:count() == 3, "Count should be 3")

    -- Test get by name
    local rain = st:get("gg_snd_Rain")
    assert(rain ~= nil, "Should find Rain sound")
    assert(rain.file == "rain.wav", "Rain file mismatch")

    local missing = st:get("gg_snd_Missing")
    assert(missing == nil, "Should not find missing sound")

    -- Test names()
    local names = st:names()
    assert(#names == 3, "Should have 3 names")
    assert(names[1] == "gg_snd_Rain", "First name mismatch")

    -- Test pairs()
    local count = 0
    for i, sound in st:pairs() do
        count = count + 1
        assert(type(i) == "number", "Index should be number")
        assert(sound.name ~= nil, "Sound should have name")
    end
    assert(count == 3, "pairs() should iterate 3 times")

    print("  PASS: SoundTable class works")
end
-- }}}

-- {{{ test_format
local function test_format()
    print("Testing format output...")

    local data = build_w3s_v1({
        {
            name = "gg_snd_RainLoop",
            file = "Sound\\Ambient\\RainLoop.wav",
            eax = "DefaultEAXON",
            looping = true,
            channel = 10,
        },
        {
            name = "gg_snd_Battle",
            file = "Sound\\Combat\\Battle.wav",
            eax = "CombatSoundsEAX",
            sound_3d = true,
            channel = 5,
            volume = 80,
        },
    })

    local result = w3s.parse(data)
    local formatted = w3s.format(result)

    assert(formatted:find("Sound Definitions"), "Should have header")
    assert(formatted:find("Version: 1"), "Should show version")
    assert(formatted:find("Sound count: 2"), "Should show count")
    assert(formatted:find("gg_snd_RainLoop"), "Should show first sound name")
    assert(formatted:find("looping"), "Should show looping flag")
    assert(formatted:find("gg_snd_Battle"), "Should show second sound name")
    assert(formatted:find("3D"), "Should show 3D flag")

    print("  PASS: Format output works")
end
-- }}}

-- {{{ test_invalid_data
local function test_invalid_data()
    print("Testing invalid data handling...")

    -- Too short
    local result, err = w3s.parse("")
    assert(result == nil, "Should fail on empty data")
    assert(err ~= nil, "Should return error message")

    -- Too short (partial header)
    result, err = w3s.parse("\x01\x00\x00")
    assert(result == nil, "Should fail on partial header")

    -- nil data
    result, err = w3s.parse(nil)
    assert(result == nil, "Should fail on nil data")

    print("  PASS: Invalid data handling works")
end
-- }}}

-- {{{ test_real_maps
local function test_real_maps()
    print("Testing against real map files...")

    local map_files = get_map_files()
    if #map_files == 0 then
        print("  SKIP: No test maps found")
        return
    end

    local passed = 0
    local failed = 0
    local no_w3s = 0

    for _, map_path in ipairs(map_files) do
        local map_name = map_path:match("([^/]+)$")
        log("  Testing:", map_name)

        local ok, archive = pcall(mpq.open, map_path)
        if not ok then
            log("    SKIP: Cannot open MPQ -", archive)
            failed = failed + 1
            goto continue
        end

        -- Check if w3s exists
        if not archive:has("war3map.w3s") then
            log("    SKIP: No war3map.w3s in archive")
            no_w3s = no_w3s + 1
            archive:close()
            goto continue
        end

        -- Extract w3s
        local w3s_ok, w3s_data = pcall(archive.extract, archive, "war3map.w3s")
        if not w3s_ok then
            log("    FAIL: Cannot extract w3s -", w3s_data)
            failed = failed + 1
            archive:close()
            goto continue
        end

        -- Parse w3s
        local parse_ok, result = pcall(w3s.parse, w3s_data)
        if not parse_ok then
            log("    FAIL: Cannot parse w3s -", result)
            failed = failed + 1
            archive:close()
            goto continue
        end

        log(string.format("    Parsed: %d sounds", #result.sounds))

        passed = passed + 1
        archive:close()
        ::continue::
    end

    print(string.format("  Results: %d passed, %d failed, %d no w3s", passed, failed, no_w3s))
    if no_w3s == #map_files then
        print("  NOTE: No test maps contain war3map.w3s files (normal for melee maps)")
    elseif failed == 0 then
        print("  PASS: All maps with w3s parsed successfully")
    else
        print("  PARTIAL: Some maps failed")
    end
end
-- }}}
-- }}}

-- {{{ Main
local function main()
    print("=== W3S Parser Tests ===\n")

    test_parse_empty()
    test_parse_single_sound()
    test_parse_multiple_sounds()
    test_parse_flags()
    test_parse_channels()
    test_parse_eax_effects()
    test_sound_table_class()
    test_format()
    test_invalid_data()
    test_real_maps()

    print("\n=== All tests completed ===")
end

main()
-- }}}
