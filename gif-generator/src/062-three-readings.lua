-- 062-three-readings.lua — say a sentence once, get three readings to
-- pick from (issue 602).
--
-- What this is, generally: the front door for 061-readings.lua. It
-- plans who reads (every door in input/cluster, or one door with three
-- seeds), asks them all at once, each in its own process so a slow door
-- holds up no one, films each reading that passes the wall, and writes
-- the pick page. Picking moves one reading's score into input/.
--
-- Usage (./porch passes these through):
--   luajit 062-three-readings.lua DIR "a sentence" [--count=N]
--       N readings, 1 to 4 (her limit on processes), 3 by default;
--       they land in output/readings/SLUG/ with index.html to look at
--   luajit 062-three-readings.lua DIR --pick SLUG K [--name=NAME]
--       reading K's score becomes input/NAME.lua (NAME defaults to SLUG)
--   luajit 062-three-readings.lua DIR --one FOLDER K DOOR SEED
--       one reading, as the fan-out runs it

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local porch = require("032-porch")
local readings = dofile(DIR .. "/src/061-readings.lua")
local HERE = DIR .. "/src/062-three-readings.lua"

-- {{{ local function fail()
local function fail(text)
    io.stderr:write(text .. "\n")
    os.exit(1)
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function quote()
-- A word for the shell, in single quotes.
local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function doors()
local function doors()
    local ok, list = pcall(porch.cluster, DIR)
    if not ok then fail(tostring(list)) end
    return list
end
-- }}}

-- {{{ --one: one reading, as the fan-out runs it
if arg[2] == "--one" then
    local folder, k, name, seed = arg[3], tonumber(arg[4]), arg[5], tonumber(arg[6])
    local door
    for _, d in ipairs(doors()) do
        if d.name == name then door = d end
    end
    local prose = slurp(folder .. "/prose.txt")
    local result
    if not door then
        result = { ok = false, errors = "input/cluster names no door '" .. tostring(name) .. "'" }
    else
        result = readings.one(DIR, prose, porch.door_transport(door, nil, seed))
    end
    readings.land(folder, k, result, name, seed)
    os.exit(0)
end
-- }}}

-- {{{ --pick: one reading's score into input/
if arg[2] == "--pick" then
    local slug, k = arg[3], tonumber(arg[4])
    if not slug or not k then fail("porch: --pick SLUG K, as the pick page says") end
    local name = slug
    for i = 5, #arg do
        name = arg[i]:match("^%-%-name=(.+)$") or name
    end
    if not name:match("^[%w%-_]+$") then fail("porch: --name takes letters, digits, - and _ only") end
    local folder = DIR .. "/output/readings/" .. slug
    local ok, path = pcall(readings.pick, DIR, folder, k, name)
    if not ok then fail(tostring(path)) end
    print("  " .. path)
    print("  film it: ./run " .. name)
    os.exit(0)
end
-- }}}

-- {{{ a sentence: plan, ask everyone at once, film, write the page
local count, words = 3, {}
for i = 2, #arg do
    local n = arg[i]:match("^%-%-count=(%d+)$")
    if n then count = tonumber(n) else words[#words + 1] = arg[i] end
end
local prose = table.concat(words, " ")
if prose == "" then fail('porch: say a sentence, in quotes: ./porch --three "curve the ball around the circle"') end
if count < 1 or count > 4 then fail("porch: --count is 1 to 4 (never more than four processes at once)") end

local plan = readings.plan(doors(), count)
local slug = readings.slug(prose)
local root = DIR .. "/output/readings/"
local name, n = slug, 1
while slurp(root .. name .. "/prose.txt") do
    n = n + 1
    name = slug .. "-" .. n
end
local folder = root .. name
os.execute("mkdir -p " .. quote(folder))
local f = assert(io.open(folder .. "/prose.txt", "w"))
f:write(prose .. "\n")
f:close()

print("— asking " .. count .. " readings at once —")
local jobs = {}
for k, p in ipairs(plan) do
    print(string.format("  reading %d: %s, seed %d", k, p.door.name, p.seed))
    jobs[k] = "luajit " .. quote(HERE) .. " " .. quote(DIR) .. " --one " .. quote(folder)
        .. " " .. k .. " " .. quote(p.door.name) .. " " .. p.seed .. " &"
end
os.execute("( " .. table.concat(jobs, " ") .. " wait )")

print("— what each heard —")
for k = 1, count do
    local r = readings.read_said(folder, k)
    if not r then
        print("  reading " .. k .. ": never came back")
    elseif r.passed then
        print("  reading " .. k .. " (" .. r.door .. ", seed " .. r.seed .. "):")
        for _, line in ipairs(r.heard) do print("    " .. line) end
    else
        print("  reading " .. k .. " (" .. r.door .. ", seed " .. r.seed .. ") did not pass:")
        for _, line in ipairs(r.wall) do print("    " .. line) end
    end
end
print("— look, then pick —")
print("  " .. readings.page(folder, prose, count, name))
print("  pick one: ./porch --pick " .. name .. " K")
-- }}}
