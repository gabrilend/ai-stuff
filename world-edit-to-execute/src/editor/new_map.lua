--[[
New Maps (Issue 911b)

A map made from nothing, as the World Editor's "New Map" makes one: flat
ground of the tileset's first texture with the map's edge marked,
players and their start locations, and a script that sets them up
(config) and starts the game (main: melee setup for a melee map, else
only the start). Gold mines by the start locations are made by the script
(CreateUnit and SetResourceAmount), so the editor shows and moves them
like any script unit.

  war3map.w3i   map info (parsers/w3i.lua's writer): name, author,
                description, size, margins, camera bounds, tileset,
                players, forces
  war3map.w3e   the ground: flat, height 0, cliff level 2, dry, the edge
                (the margins) flagged
  war3map.wpm   pathing: land everywhere, the edge closed
  war3map.shd   no shadows
  war3map.doo   no doodads
  war3map.j     the script
  the archive   a new MPQ with the 512-byte HM3W header in front (name,
                flags, player count)

    local new_map = require("editor.new_map")
    new_map.create("maps/mine.w3x", {
        name = "Two Rivers", author = "me", width = 96, height = 96,   -- playable tiles
        tileset = "L", melee = true,
        players = { { race = "human" }, { race = "orc", computer = true } },
    })
    local E = require("editor").open("maps/mine.w3x")

    luajit src/editor/new_map.lua maps/mine.w3x --name "Two Rivers" --size 96 --players human,orc:computer
]]

-- run as a script (see the end): find the project's modules first
local AS_SCRIPT = arg and arg[0] and (arg[0] == "new_map.lua" or arg[0]:match("editor/new_map%.lua$")) and arg[1]
if AS_SCRIPT then
    local root = arg[0]:match("^(.*)/src/editor/new_map%.lua$") or "."
    package.path = root .. "/src/?.lua;" .. root .. "/src/?/init.lua;" .. package.path
end

local w3i = require("parsers.w3i")
local w3e = require("parsers.w3e")
local doo = require("parsers.doo")
local bw = require("parsers.binwrite")

local new_map = {}

-- the ground and cliff tilesets a new map of each tileset starts with
new_map.TILESETS = {
    L = { name = "Lordaeron Summer", ground = { "Ldrt", "Ldro", "Ldrg", "Lrok", "Lgrs", "Lgrd" }, cliff = { "CLdi", "CLgr" },
          light = "L", day = "LordaeronSummerDay", night = "LordaeronSummerNight" },
    W = { name = "Lordaeron Winter", ground = { "Wdrt", "Wdro", "Wsng", "Wrok", "Wgrs", "Wsnw" }, cliff = { "CWsn", "CWgr" },
          light = "W", day = "LordaeronWinterDay", night = "LordaeronWinterNight" },
    B = { name = "Barrens", ground = { "Bdrt", "Bdrh", "Bdrr", "Bdrg", "Bdsr", "Bdsd", "Bflr", "Bgrr" }, cliff = { "CBde", "CBgr" },
          light = "B", day = "BarrensDay", night = "BarrensNight" },
    A = { name = "Ashenvale", ground = { "Adrt", "Adrd", "Agrs", "Arck", "Agrd", "Avin", "Adrg", "Alvd" }, cliff = { "CAdi", "CAgr" },
          light = "A", day = "AshenvaleDay", night = "AshenvaleNight" },
    N = { name = "Northrend", ground = { "Ndrt", "Ndrd", "Nrck", "Ngrs", "Nice", "Nsnw", "Nsnr" }, cliff = { "CNdi", "CNsn" },
          light = "N", day = "NorthrendDay", night = "NorthrendNight" },
}
new_map.RACES = { human = "RACE_PREF_HUMAN", orc = "RACE_PREF_ORC", undead = "RACE_PREF_UNDEAD",
                  nightelf = "RACE_PREF_NIGHTELF", night_elf = "RACE_PREF_NIGHTELF", random = "RACE_PREF_RANDOM" }
local RACE_W3I = { human = 1, orc = 2, undead = 3, nightelf = 4, night_elf = 4, random = 0 }
-- the margins the World Editor gives every map (left, right, bottom, top)
new_map.MARGINS = { 6, 6, 4, 8 }

-- {{{ the layout: sizes and where players start
local function layout(opts)
    local pw = math.max(32, math.floor((opts.width or 64) / 4 + 0.5) * 4)
    local ph = math.max(32, math.floor((opts.height or 64) / 4 + 0.5) * 4)
    local m = new_map.MARGINS
    local w, h = pw + m[1] + m[2], ph + m[3] + m[4]
    local L = { playable_width = pw, playable_height = ph, width = w, height = h,
                offset_x = -w * 64, offset_y = -h * 64 }
    L.left = L.offset_x + m[1] * 128
    L.right = L.offset_x + (w - m[2]) * 128
    L.bottom = L.offset_y + m[3] * 128
    L.top = L.offset_y + (h - m[4]) * 128
    -- the camera stays a little inside the playable area, as the WE sets it
    L.cam = { left = L.left + 512, right = L.right - 512, bottom = L.bottom + 256, top = L.top - 256 }
    -- players start around a ring inside the playable area, first at the bottom left
    local players = opts.players or { { race = "human" }, { race = "orc", computer = true } }
    local cx, cy = (L.left + L.right) / 2, (L.bottom + L.top) / 2
    local rx, ry = (L.right - L.left) / 2 - 1024, (L.top - L.bottom) / 2 - 1024
    for i, p in ipairs(players) do
        if not p.x then
            local a = math.rad(225) - (i - 1) * 2 * math.pi / #players
            p.x = math.floor((cx + math.cos(a) * rx) / 32 + 0.5) * 32
            p.y = math.floor((cy + math.sin(a) * ry) / 32 + 0.5) * 32
        end
    end
    L.players = players
    return L
end
-- }}}

-- {{{ the files
function new_map.info(opts, L)
    local tiles = new_map.TILESETS[opts.tileset or "L"] or new_map.TILESETS.L
    local players, forces = {}, {}
    for i, p in ipairs(L.players) do
        players[#players + 1] = { number = i - 1, type_id = p.computer and 2 or 1, race_id = RACE_W3I[p.race or "human"] or 1,
                                  fixed_start_raw = 1, name = p.name or ("Player " .. i), start_x = p.x, start_y = p.y,
                                  ally_low = 0, ally_high = 0 }
    end
    local mask = 0
    for i = 1, #L.players do mask = mask + 2 ^ (i - 1) end
    forces[1] = { flags = 0, player_mask = mask, name = "Force 1" }
    local c = L.cam
    return w3i.write({
        version = 25, saves = 1, editor_version = 6072,
        name = opts.name or "Just another Warcraft III map", author = opts.author or "Unknown",
        description = opts.description or "Nondescript", players_recommended = opts.recommended or "Any",
        camera_bounds = { c.left, c.bottom, c.right, c.top, c.left, c.top, c.right, c.bottom },
        margins = new_map.MARGINS, playable_width = L.playable_width, playable_height = L.playable_height,
        -- melee: the WE's "melee map" flag; with it or not, waves, and "properties opened"
        flags = (opts.melee and 0x0004 or 0) + 0x0400 + 0x0800 + 0x1000,
        tileset_code = opts.tileset or "L",
        loading_screen = { preset = -1, model = "", text = "", title = "", subtitle = "" }, game_data_set = 0,
        prologue = { model = "", text = "", title = "", subtitle = "" },
        fog = { style = 0, start_z = 3000, end_z = 5000, density = 0.5, color = 0xFF000000 },
        weather = "\0\0\0\0", sound_environment = "", light_environment = tiles.light,
        water_color = 0xFFFFFFFF,
        players = players, forces = forces,
    })
end

function new_map.terrain(opts, L)
    local tiles = new_map.TILESETS[opts.tileset or "L"] or new_map.TILESETS.L
    local t = { version = 11, tileset_code = opts.tileset or "L", custom_tileset = false,
                ground_tilesets = tiles.ground, cliff_tilesets = tiles.cliff,
                width = L.width + 1, height = L.height + 1, offset_x = L.offset_x, offset_y = L.offset_y,
                tilepoints = {} }
    local m = new_map.MARGINS
    local seed = 12345
    for y = 0, L.height do
        local row = {}
        for x = 0, L.width do
            -- the edge: outside the playable area
            local edge = x < m[1] or x > L.width - m[2] or y < m[3] or y > L.height - m[4]
            seed = (seed * 1103515245 + 12345) % 2147483648
            row[x] = { height = 0, water_level = -128, water_flags = edge and 0x4000 or 0, boundary = edge,
                       ground_texture = 0, is_ramp = false, is_blight = false, has_water = false, is_boundary = false,
                       texture_details = math.floor(seed / 65536) % 16, cliff_variation = 0, layer_height = 2,
                       cliff_texture = 0 }
        end
        t.tilepoints[y] = row
    end
    return w3e.write(t)
end

function new_map.pathing(L)
    local w, h = L.width * 4, L.height * 4
    local m = new_map.MARGINS
    local rows = {}
    local land, closed = string.char(0x40), string.char(0xCE)
    for y = 0, h - 1 do
        local edge_row = y < m[3] * 4 or y >= (L.height - m[4]) * 4
        if edge_row then rows[#rows + 1] = closed:rep(w)
        else rows[#rows + 1] = closed:rep(m[1] * 4) .. land:rep(w - (m[1] + m[2]) * 4) .. closed:rep(m[2] * 4) end
    end
    return bw.new():str("MP3W"):i32(0):i32(w):i32(h):done() .. table.concat(rows)
end

function new_map.shadows(L)
    return string.rep("\0", L.width * 4 * L.height * 4)
end

function new_map.doodads()
    return doo.write({ version = 8, subversion = 11, doodads = {}, tail_raw = string.rep("\0", 8) })
end

local function q(s) return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end
local function n1(v) return string.format("%.1f", v) end

function new_map.script(opts, L)
    local tiles = new_map.TILESETS[opts.tileset or "L"] or new_map.TILESETS.L
    local out = {}
    local function add(s) out[#out + 1] = s end
    add("//===========================================================================")
    add("// " .. tostring(opts.name or "New map") .. ": made by world-edit-to-execute's map editor (issue 911b)")
    add("//===========================================================================")
    add("globals")
    add("endglobals")
    add("")
    -- gold mines by each start, a little toward the middle
    add("function CreateNeutralPassiveBuildings takes nothing returns nothing")
    add("    local unit u")
    local cx, cy = (L.left + L.right) / 2, (L.bottom + L.top) / 2
    if opts.gold_mines ~= false then
        for _, p in ipairs(L.players) do
            local dx, dy = cx - p.x, cy - p.y
            local d = math.sqrt(dx * dx + dy * dy)
            local mx, my = p.x + dx / math.max(d, 1) * 640, p.y + dy / math.max(d, 1) * 640
            -- Player(15): neutral passive (a number, so the editor finds the call)
            add(string.format("    set u = CreateUnit(Player(15), 'ngol', %s, %s, 270.0)",
                n1(math.floor(mx / 32 + 0.5) * 32), n1(math.floor(my / 32 + 0.5) * 32)))
            add("    call SetResourceAmount(u, " .. math.floor(opts.gold or 12500) .. ")")
        end
    end
    add("endfunction")
    add("")
    add("function InitCustomPlayerSlots takes nothing returns nothing")
    for i, p in ipairs(L.players) do
        local P = "Player(" .. (i - 1) .. ")"
        add("    call SetPlayerStartLocation(" .. P .. ", " .. (i - 1) .. ")")
        add("    call SetPlayerColor(" .. P .. ", ConvertPlayerColor(" .. (i - 1) .. "))")
        add("    call SetPlayerRacePreference(" .. P .. ", " .. (new_map.RACES[p.race or "human"] or "RACE_PREF_HUMAN") .. ")")
        add("    call SetPlayerRaceSelectable(" .. P .. ", true)")
        add("    call SetPlayerController(" .. P .. ", " .. (p.computer and "MAP_CONTROL_COMPUTER" or "MAP_CONTROL_USER") .. ")")
    end
    add("endfunction")
    add("")
    add("function InitCustomTeams takes nothing returns nothing")
    for i in ipairs(L.players) do add("    call SetPlayerTeam(Player(" .. (i - 1) .. "), 0)") end
    add("endfunction")
    add("")
    add("function main takes nothing returns nothing")
    local c = L.cam
    add(string.format("    call SetCameraBounds(%s, %s, %s, %s, %s, %s, %s, %s)", n1(c.left), n1(c.bottom), n1(c.right),
        n1(c.top), n1(c.left), n1(c.top), n1(c.right), n1(c.bottom)))
    add('    call SetDayNightModels("Environment\\\\DNC\\\\DNCLordaeron\\\\DNCLordaeronTerrain\\\\DNCLordaeronTerrain.mdl", '
        .. '"Environment\\\\DNC\\\\DNCLordaeron\\\\DNCLordaeronUnit\\\\DNCLordaeronUnit.mdl")')
    add('    call NewSoundEnvironment("Default")')
    add("    call SetAmbientDaySound(" .. q(tiles.day) .. ")")
    add("    call SetAmbientNightSound(" .. q(tiles.night) .. ")")
    add('    call SetMapMusic("Music", true, 0)')
    add("    call CreateNeutralPassiveBuildings()")
    add("    call InitBlizzard()")
    if opts.melee ~= false then
        for _, f in ipairs({ "MeleeStartingVisibility", "MeleeStartingHeroLimit", "MeleeGrantHeroItems",
                             "MeleeStartingResources", "MeleeClearExcessUnits", "MeleeStartingUnits", "MeleeStartingAI",
                             "MeleeInitVictoryDefeat" }) do
            add("    call " .. f .. "()")
        end
    end
    add("endfunction")
    add("")
    add("function config takes nothing returns nothing")
    add("    call SetMapName(" .. q(opts.name or "New map") .. ")")
    add("    call SetMapDescription(" .. q(opts.description or "") .. ")")
    add("    call SetPlayers(" .. #L.players .. ")")
    add("    call SetTeams(" .. #L.players .. ")")
    add("    call SetGamePlacement(MAP_PLACEMENT_USE_MAP_SETTINGS)")
    for i, p in ipairs(L.players) do
        add(string.format("    call DefineStartLocation(%d, %s, %s)", i - 1, n1(p.x), n1(p.y)))
    end
    add("    call InitCustomPlayerSlots()")
    add("    call InitCustomTeams()")
    add("endfunction")
    return table.concat(out, "\n") .. "\n"
end

-- the 512-byte header in front of the archive
function new_map.header(opts, L)
    local head = "HM3W" .. string.rep("\0", 4) .. (opts.name or "New map") .. "\0"
        .. bw.new():u32(0):u32(#L.players):done()
    return head .. string.rep("\0", 512 - #head)
end
-- }}}

-- {{{ new_map.create
-- true and the file names written, or nil and why
function new_map.create(path, opts)
    opts = opts or {}
    local L = layout(opts)
    local files = {
        ["war3map.w3i"] = new_map.info(opts, L),
        ["war3map.w3e"] = new_map.terrain(opts, L),
        ["war3map.wpm"] = new_map.pathing(L),
        ["war3map.shd"] = new_map.shadows(L),
        ["war3map.doo"] = new_map.doodads(),
        ["war3map.j"] = new_map.script(opts, L),
    }
    local stormlib = require("mpq.stormlib")
    local tmp = path .. ".building"
    os.remove(tmp)
    local ok, err = pcall(function()
        local a = stormlib.create(tmp, 64)
        local names = {}
        for n in pairs(files) do names[#names + 1] = n end
        table.sort(names)
        for _, n in ipairs(names) do a:write(n, files[n]) end
        a:flush()
        a:close()
    end)
    if not ok then os.remove(tmp) return nil, err end
    local f = io.open(tmp, "rb")
    local archive = f:read("*a")
    f:close()
    os.remove(tmp)
    local o = io.open(path, "wb")
    if not o then return nil, "can't write " .. path end
    o:write(new_map.header(opts, L), archive)
    o:close()
    return true, files, L
end
-- }}}

-- {{{ from the command line
--   luajit src/editor/new_map.lua OUT.w3x [--name N] [--author A] [--size 96]
--       [--tileset L] [--players human,orc:computer,...] [--custom]
if AS_SCRIPT then
    local opts, out = { melee = true, players = {} }, arg[1]
    local i = 2
    while arg[i] do
        local k, v = arg[i], arg[i + 1]
        if k == "--name" then opts.name = v
        elseif k == "--author" then opts.author = v
        elseif k == "--size" then opts.width, opts.height = tonumber(v), tonumber(v)
        elseif k == "--tileset" then opts.tileset = v
        elseif k == "--players" then
            for item in v:gmatch("[^,]+") do
                local race, who = item:match("^(%w+):?(%w*)$")
                opts.players[#opts.players + 1] = { race = race, computer = who == "computer" }
            end
        elseif k == "--custom" then opts.melee = false; i = i - 1
        end
        i = i + 2
    end
    if #opts.players == 0 then opts.players = nil end
    local ok, why = new_map.create(out, opts)
    print(ok and ("made " .. out) or ("couldn't: " .. tostring(why)))
    os.exit(ok and 0 or 1)
end
-- }}}

return new_map
