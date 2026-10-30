-- 044-round-trip-test.lua — proof that the one reader and the one writer
-- agree on every film: encode, decode, encode again, the same bytes.
--
-- What this is, generally: for each gif in a folder, the studio's reader
-- (040-gif-decode.lua) takes the file apart into its palette, its delay and
-- every frame's raw colour indices; the studio's encoder (004-gif.lua) puts
-- them back together; the new file must equal the old one byte for byte.
-- Only films this studio wrote can pass (another encoder packs its codes
-- differently), so the folder is the shape films' own: the approved six by
-- default, or the owner's library when it is named. Issue 701b, step 4.
--
-- Usage: luajit src/044-round-trip-test.lua DIR [gif folder]
-- Prints one line per film and a summary; exits 1 if any failed.

-- Scripts run from anywhere: hard-coded home, overridable by argument.
local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
local FOLDER = arg and arg[2] or nil
package.path = DIR .. "/src/?.lua;" .. package.path

local ffi = require("ffi")
local encoder = require("004-gif")
local reader = dofile(DIR .. "/src/040-gif-decode.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function round_trip()
-- One film taken apart and put back. Two paths: the film is the kind this
-- encoder writes (one full palette, full-size frames, one delay), so it is
-- rebuilt and compared; or it is not, and that alone is the failure.
local function round_trip(bytes)
    local info = reader.facts(bytes, { structure = true })
    if info.global_colours ~= 256 then return false, "not a 256-colour film" end
    local delay = info.structure[1].delay_cs
    local frames = {}
    for i, frame in ipairs(info.structure) do
        if frame.left ~= 0 or frame.top ~= 0 or frame.local_palette
            or frame.width ~= info.source_width or frame.delay_cs ~= delay then
            return false, "frame " .. i .. " is not the kind this encoder writes"
        end
        local pixels = ffi.new("uint8_t[?]", #frame.indices)
        ffi.copy(pixels, frame.indices, #frame.indices)
        frames[i] = pixels
    end
    local palette = ffi.new("uint8_t[?]", 768)
    ffi.copy(palette, info.global_palette, 768)
    local again = encoder.encode{
        width = info.source_width, height = info.source_height,
        palette_bytes = palette, frames = frames, delay_cs = delay,
    }
    if again ~= bytes then return false, "rebuilt bytes differ" end
    return true, #info.structure .. " frames"
end
-- }}}

-- {{{ local function film_paths()
-- Which films to check. Two paths: a folder named on the command line (every
-- .gif in it), or the approved six, filmed fresh into RAM by the tool.
local function film_paths()
    local paths = {}
    if FOLDER then
        local listing = io.popen("ls -1 '" .. FOLDER .. "'")
        for line in listing:lines() do
            if line:match("%.gif$") then paths[#paths + 1] = FOLDER .. "/" .. line end
        end
        listing:close()
        return paths
    end
    local out = "/dev/shm/gif-generator/round-trip-test"
    os.execute(string.format("rm -rf %q && mkdir -p %q", out, out))
    local approved = dofile(DIR .. "/tests/shape-films/approved-films.lua")
    local names = {}
    for name in pairs(approved) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        os.execute(string.format("luajit %q %q %q --out=%q > /dev/null",
            DIR .. "/src/039-shape-films.lua", DIR, name, out))
        paths[#paths + 1] = out .. "/" .. name .. ".gif"
    end
    return paths
end
-- }}}

print("round trip: encode, decode, encode again")
local paths = film_paths()
check("there are films to check (" .. #paths .. ")", #paths > 0)
for _, path in ipairs(paths) do
    local handle = io.open(path, "rb")
    local bytes = handle and handle:read("*a")
    if handle then handle:close() end
    local ok, note = false, "cannot read"
    if bytes then
        local success, same, why = pcall(round_trip, bytes)
        if success then ok, note = same, why else note = tostring(same) end
    end
    check(path:match("([^/]+)%.gif$") .. " comes back byte-identical (" .. note .. ")", ok)
end

print("")
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
