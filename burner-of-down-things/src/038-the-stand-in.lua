-- 038-the-stand-in.lua
--
-- A harness with no model in it. Run as its own process, one per turn, it
-- does what a well-behaved (or deliberately badly behaved) turn of each kind
-- would do, from a script the case holds — so every part of the machine above
-- the hands can be tested and demonstrated without spending anything.
--
-- Usage: luajit 038-the-stand-in.lua <project folder> <turn folder>
--
-- The script is the case's stand-in.lua, a Lua file returning a table keyed
-- by "kind about" (checked first) or "kind". Each value is an entry, or a
-- function(turn) returning one. `turn` holds: kind, about, id, prompt (the
-- prompt's text), folder (the turn folder), case_folder, attempt (1 for the
-- first turn of this kind and about, 2 for the second, …).
--
-- An entry:
--   writes     table: path -> text. A path is relative to the case folder;
--              "turn/<name>" writes into the turn's own folder.
--   exit       number: the exit status (default 0)
--   sleep      number: seconds to wait first
--   misbehave  "write-outside" (a file in the case folder root),
--              "write-source" (a file in the source), "fail" (exit 3),
--              "hang" (sleep far past any limit)
--   say        text printed on standard output (lands in result.json)

local DIR, TURN_FOLDER = arg[1], arg[2]
if not DIR or not TURN_FOLDER then
    io.stderr:write("usage: 038-the-stand-in.lua <project folder> <turn folder>\n")
    os.exit(2)
end
package.path = DIR .. "/src/?.lua;" .. package.path

local text_tables = require("014-text-tables")
local fs = require("017-the-filesystem")

local confinement = text_tables.read_record(TURN_FOLDER .. "/confinement.lua")
local case_folder = confinement.case_folder
local record = text_tables.read_record(case_folder .. "/case.lua")

-- {{{ local function attempt_number
-- How many turns of this kind and about exist up to and including this one.
local function attempt_number()
    local suffix = "-" .. confinement.kind .. "-" .. confinement.about:gsub("[^%w%-]", "_")
    local mine = tonumber(confinement.id:match("^(%d+)"))
    local n = 0
    for _, name in ipairs(fs.list(case_folder .. "/turns")) do
        local number = tonumber(name:match("^(%d+)"))
        if number and number <= mine and name:sub(-#suffix) == suffix then
            n = n + 1
        end
    end
    return n
end
-- }}}

local script_path = case_folder .. "/stand-in.lua"
if not fs.exists(script_path) then
    io.stderr:write("stand-in: the case has no stand-in.lua script\n")
    os.exit(4)
end
local script = dofile(script_path)
local entry = script[confinement.kind .. " " .. confinement.about] or script[confinement.kind]
if not entry then
    io.stderr:write("stand-in: the script has no entry for '" .. confinement.kind .. " "
        .. confinement.about .. "' or '" .. confinement.kind .. "'\n")
    os.exit(5)
end

local turn = {
    kind = confinement.kind, about = confinement.about, id = confinement.id,
    prompt = fs.read(TURN_FOLDER .. "/prompt.md"), folder = TURN_FOLDER,
    case_folder = case_folder, attempt = attempt_number(),
}
if type(entry) == "function" then
    entry = entry(turn)
end

if entry.sleep then
    os.execute("sleep " .. tonumber(entry.sleep))
end

-- Misbehaviour, for testing the checks. Each branch is one way a real
-- model's turn could go wrong.
local MISBEHAVIOURS = {
    ["write-outside"] = function()
        fs.write(case_folder .. "/outside-" .. turn.id, "a stand-in wrote where it should not\n")
    end,
    ["write-source"] = function()
        fs.write(record.source .. "/stand-in-was-here", "a stand-in wrote into the source\n")
    end,
    ["fail"] = function()
        io.stderr:write("stand-in: told to fail\n")
        os.exit(3)
    end,
    ["hang"] = function()
        os.execute("sleep 100000")
    end,
}

for path, text in pairs(entry.writes or {}) do
    local full
    if path:sub(1, 5) == "turn/" then
        full = TURN_FOLDER .. "/" .. path:sub(6)
    else
        full = case_folder .. "/" .. path
    end
    local folder = full:match("^(.*)/[^/]*$")
    fs.make_folder(folder)
    fs.write(full, text)
end

if entry.misbehave then
    local act = MISBEHAVIOURS[entry.misbehave]
    if not act then
        io.stderr:write("stand-in: unknown misbehaviour '" .. tostring(entry.misbehave) .. "'\n")
        os.exit(6)
    end
    act()
end

io.write('{"type":"result","harness":"stand-in","turn":"', turn.id, '","attempt":', turn.attempt,
    ',"result":', string.format("%q", entry.say or "done"), "}\n")
os.exit(entry.exit or 0)
