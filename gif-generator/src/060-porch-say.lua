-- 060-porch-say.lua — say a sentence to the real model and see what it
-- heard (601's last mile).
--
-- What this is, generally: the porch (032-porch.lua) was built and proven
-- against fake models. This is the door to a real one. It reads the
-- doors in input/cluster, posts the prompt, the grammar and what the
-- person said to the first door that answers (llama.cpp's server, at
-- /completion), lets the wall argue with the model for a few tries, and
-- then prints what the porch heard, line by line, and writes the score
-- to input/NAME.lua. Filming is a separate step (./run NAME), so the
-- person reads the lines before anything is drawn.
--
-- Usage:
--   luajit 060-porch-say.lua DIR --check
--       ask every door whether its server is up
--   luajit 060-porch-say.lua DIR "a sentence" [--name=NAME] [--door=DOOR] [--seed=N]
--       NAME defaults to "heard"; an existing input/NAME.lua is never
--       overwritten (the next free NAME-2, NAME-3, ... is used)

local DIR = "/mnt/mtwo/programming/ai-stuff/gif-generator"
if arg and arg[1] then DIR = arg[1] end
package.path = DIR .. "/src/?.lua;" .. package.path

local porch = require("032-porch")

-- {{{ local function options()
local function options(args)
    local opts = { name = "heard", words = {} }
    for i = 2, #args do
        local key, value = args[i]:match("^%-%-(%w+)=(.*)$")
        if key then
            opts[key] = value
        elseif args[i] == "--check" then
            opts.check = true
        else
            opts.words[#opts.words + 1] = args[i]
        end
    end
    opts.prose = table.concat(opts.words, " ")
    return opts
end
-- }}}

-- {{{ local function free_name()
-- The first input/NAME.lua not yet taken, so nothing is overwritten.
local function free_name(name)
    local function taken(n)
        local f = io.open(DIR .. "/input/" .. n .. ".lua", "r")
        if f then f:close() return true end
        return false
    end
    if not taken(name) then return name end
    local k = 2
    while taken(name .. "-" .. k) do k = k + 1 end
    return name .. "-" .. k
end
-- }}}

local opts = options(arg)
if not opts.name:match("^[%w%-_]+$") then
    io.stderr:write("porch: --name takes letters, digits, - and _ only\n")
    os.exit(1)
end
local ok_doors, doors = pcall(porch.cluster, DIR)
if not ok_doors then
    io.stderr:write(tostring(doors) .. "\n")
    os.exit(1)
end

if opts.check then
    local up = 0
    for _, door in ipairs(doors) do
        local ok, why = porch.door_health(door)
        print(string.format("  %-14s %s:%d  %s", door.name, door.host, door.port,
                            ok and "up" or ("not answering: " .. tostring(why))))
        if ok then up = up + 1 end
    end
    -- the prompt is long (the whole language, read verbatim), and a
    -- server started with a small context cuts it off; say how long
    local chars = #porch.prompt(DIR)
    local tokens = math.ceil(chars / 3.5 / 1024) * 1024
    print(string.format("  the prompt is %d characters, about %d tokens: start each server "
                        .. "with a context of at least %d (llama-server -c %d)",
                        chars, tokens, tokens + 4096, tokens + 4096))
    os.exit(up > 0 and 0 or 1)
end

if opts.prose == "" then
    io.stderr:write("porch: say a sentence, in quotes: "
                    .. "luajit src/060-porch-say.lua DIR \"curve the ball around the circle\"\n")
    os.exit(1)
end

-- the named door, or the first that is up
local door
for _, d in ipairs(doors) do
    if (opts.door and d.name == opts.door) or (not opts.door and porch.door_health(d)) then
        door = d
        break
    end
end
if not door then
    io.stderr:write(opts.door and ("porch: input/cluster names no door '" .. opts.door .. "'\n")
                    or "porch: no door in input/cluster is answering (try --check)\n")
    os.exit(1)
end

print("— asking " .. door.name .. " (" .. door.host .. ":" .. door.port .. ") —")
local transport = porch.door_transport(door, nil, tonumber(opts.seed) or 1)
local ok, text, second, third = pcall(porch.translate, DIR, opts.prose, transport)
if not ok then
    io.stderr:write(tostring(text) .. "\n")
    os.exit(1)
end

if not text then
    print("— the model's last reading still fails the wall —")
    print(second)
    print("— its draft —")
    print(third)
    os.exit(1)
end

print("— what the porch heard —")
for _, line in ipairs(third) do print("  " .. line) end
local name = free_name(opts.name)
local path = DIR .. "/input/" .. name .. ".lua"
local f = assert(io.open(path, "w"))
f:write(text)
f:close()
print("— written —")
print("  " .. path)
print("  film it: ./run " .. name)
