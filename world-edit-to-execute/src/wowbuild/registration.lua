--[[
registration.lua - a converted map's rows in WoW's tables, and the ids they take (issue W02c)

A converted map is known to the client and the server by numbers: its map
id (Map.dbc: which folder under World\Maps\ holds its ground), its zone
(AreaTable.dbc), its loading screen (LoadingScreens.dbc), its creatures'
looks (CreatureDisplayInfo.dbc and CreatureModelData.dbc, from W02b's
display ids) and its sides (FactionTemplate.dbc and Faction.dbc, from W02b's
factions). This module picks the numbers and builds the rows; wowbuild's
output step writes them as tables (wowbuild.dbc), SQL and patch-W.MPQ.

The id scheme (decided 2026-11-04, W02c; the owner's to overturn): each
converted map in a build folder takes a slot, 0-99, and every id it uses
is base + slot x width:

  kind             table(s)                              base        width   slot 0-99 covers
  map              Map.dbc, creature.map                 900         1       900-999
  area             AreaTable.dbc, each ADT chunk's area  9000        10      9000-9999 (one zone now)
  loading_screen   LoadingScreens.dbc                    900         1       900-999
  display          CreatureDisplayInfo.dbc, and          50000       1000    50000-149999
                   CreatureModelData.dbc (same numbers)
  faction          FactionTemplate.dbc, and Faction.dbc  3000        100     3000-12999
                   (same numbers)
  entry            creature_template.entry               9000000     10000   9000000-9999999
  guid             creature.guid                         1000000     50000   1000000-5999999
  area_bit         AreaTable.AreaBit (the explored-zones bit; under 4096)  4095 - slot
  subarea_bit      AreaTable.AreaBit of the map's other areas (W10g)  3995 - 9 x slot - (k - 1),
                   its area k = 1-9 (ids area + k)                      3096-3995
  area_more        AreaTable.dbc: a map's areas past its first nine   10000       90      10000-18999
                   (W10h); their bits the lowest free of 3096-3995 in the folder
  light            Light.dbc (the map's default light, W02i)  20000       1       20000-20099
  light_params     LightParams.dbc (W02i)                20000       4       20000-20399
  light_int_band   LightIntBand.dbc: a set's 18 bands    359983      72      359983-367182
  light_float_band LightFloatBand.dbc: a set's 6 bands   119995      24      119995-122394

Why these: map ids keep three digits because AzerothCore's mmaps
generator reads a map id from the first three characters of each .map
file's name (W02d runs it), and the 3.3.5a tables end at 724 (from memory,
unchecked). Every other block starts above the stock tables' highest ids as
remembered (AreaTable about 4990, LoadingScreens about 260, CreatureDisplayInfo
about 32000, CreatureModelData about 3000, FactionTemplate about 2240, Faction
about 1200, Light and LightParams a few thousand, so their bands under
about 60000 and 20000: all unchecked) and inside the server's limits (a creature's
entry and guid are 24 bits in its object id; creature.map is a 16-bit
column; the server's map files keep areas as 16 bits). Guids start low so
the server's own counter, which starts after the highest guid, keeps
most of its 16.7 million for creatures the triggers create (W02e).
When the stock tables are given (wowbuild.convert's stock_dbc), any stock
row inside these blocks is reported and replaced.

A slot is kept by the map's directory: a map converted again into the same
build folder keeps its slot (read from its old registration.lua); a new one
takes the lowest slot no other map of the folder holds; opts.slot asks for
one (refused when another map holds it).

    local registration = require("wowbuild.registration")
    local ids = registration.ids(0)             -- { map = 900, area = 9000, ... }
    local slot = registration.choose_slot(build_dir, "WC3_DAoW_2_1", nil)
    local R = registration.rows(info, C, ids, { directory = ..., strings = ..., area_bit = ... })
]]

local registration = {}

registration.SLOTS = 100
registration.SCHEME = {
    map = { base = 900, width = 1 },
    area = { base = 9000, width = 10 },
    -- a map's areas past its first nine (W10h, editor/wowareas.lua): AreaTable ids too
    area_more = { base = 10000, width = 90 },
    loading_screen = { base = 900, width = 1 },
    display = { base = 50000, width = 1000 },
    faction = { base = 3000, width = 100 },
    entry = { base = 9000000, width = 10000 },
    guid = { base = 1000000, width = 50000 },
    -- the light (W02i, wowbuild.light): a map's default light and its
    -- parameter sets; the band rows' numbers follow from a set's (set x 18
    -- - 17 + band, set x 6 - 5 + band), so their blocks are the sets' own
    light = { base = 20000, width = 1 },
    light_params = { base = 20000, width = 4 },
    light_int_band = { base = 20000 * 18 - 17, width = 4 * 18 },
    light_float_band = { base = 20000 * 6 - 5, width = 4 * 6 },
}
registration.AREA_BIT_TOP = 4095          -- PLAYER_EXPLORED_ZONES: 128 x 32 bits
-- a map's own areas made in the editor (W10g, editor/wowareas.lua): the
-- zone is the area block's first id; up to 9 more, its next ids, each with
-- an explored-zones bit of its own from a block under the zones' bits:
-- slot s's area k (1-9) takes bit 3995 - 9s - (k - 1), so slot 0-99 covers
-- 3096-3995 (above the stock table's bits as remembered: unchecked)
registration.SUBAREAS = registration.SCHEME.area.width - 1
registration.SUBAREA_BIT_TOP = registration.AREA_BIT_TOP - registration.SLOTS
function registration.subarea_bit(slot, k)
    return registration.SUBAREA_BIT_TOP - slot * registration.SUBAREAS - (k - 1)
end
-- the bits any map's areas past its own nine take, the lowest free first
-- (W10h): the whole block, so a map with many areas borrows the bits of
-- the slots a folder fills last (slots are taken lowest first)
registration.SUBAREA_BIT_FLOOR = registration.SUBAREA_BIT_TOP - registration.SLOTS * registration.SUBAREAS + 1
-- the kinds a table's ID column takes besides TABLE_KIND's (W10h)
registration.ALSO = { area = { "area_more" } }
registration.FILE = "registration.lua"   -- in World/Maps/<dir>/, beside the ground

-- which id kind each table's ID column takes (for the stock rows a merge drops)
registration.TABLE_KIND = {
    Map = "map", AreaTable = "area", LoadingScreens = "loading_screen",
    CreatureDisplayInfo = "display", CreatureModelData = "display",
    FactionTemplate = "faction", Faction = "faction",
    Light = "light", LightParams = "light_params", LightIntBand = "light_int_band", LightFloatBand = "light_float_band",
}

-- {{{ registration.ids
function registration.ids(slot)
    assert(type(slot) == "number" and slot >= 0 and slot < registration.SLOTS and slot == math.floor(slot),
        "a slot is a whole number from 0 to " .. (registration.SLOTS - 1))
    local ids = { slot = slot }
    for kind, s in pairs(registration.SCHEME) do
        ids[kind] = s.base + slot * s.width
        ids[kind .. "_last"] = ids[kind] + s.width - 1
    end
    ids.area_bit = registration.AREA_BIT_TOP - slot
    return ids
end

-- every id of every slot: is `id` of kind `kind` inside the scheme's blocks?
function registration.in_scheme(kind, id)
    local s = registration.SCHEME[kind]
    if id >= s.base and id < s.base + s.width * registration.SLOTS then return true end
    for _, other in ipairs(registration.ALSO[kind] or {}) do
        if registration.in_scheme(other, id) then return true end
    end
    return false
end

-- the slot a map id belongs to, or nil
function registration.slot_of_map(map_id)
    local s = registration.SCHEME.map
    local slot = map_id - s.base
    if slot >= 0 and slot < registration.SLOTS and slot == math.floor(slot) then return slot end
end
-- }}}

-- {{{ reading a registration back (data only)
function registration.read(path)
    local chunk = loadfile(path, "t", {})
    if not chunk then return nil end
    if setfenv then setfenv(chunk, {}) end
    local ok, t = pcall(chunk)
    if ok and type(t) == "table" and t.format == 1 then return t end
end

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

-- every map registered in the build folder: { [directory] = registration }
function registration.in_build(build_dir)
    local found = {}
    local p = io.popen("ls -1 " .. quote(build_dir .. "/World/Maps") .. " 2>/dev/null")
    if p then
        for dir in p:lines() do
            local r = registration.read(build_dir .. "/World/Maps/" .. dir .. "/" .. registration.FILE)
            if r and r.directory == dir then found[dir] = r end
        end
        p:close()
    end
    return found
end
-- }}}

-- {{{ registration.choose_slot
-- Returns the slot, or nil and why
function registration.choose_slot(build_dir, directory, wanted)
    local others = registration.in_build(build_dir)
    local held = {}
    for dir, r in pairs(others) do
        if dir ~= directory then held[r.slot] = dir end
    end
    if wanted ~= nil then
        if held[wanted] then
            return nil, string.format("slot %d (map id %d) is held by %s in this build folder", wanted,
                registration.SCHEME.map.base + wanted, held[wanted])
        end
        return wanted
    end
    local own = others[directory]
    if own and not held[own.slot] then return own.slot end
    for s = 0, registration.SLOTS - 1 do
        if not held[s] then return s end
    end
    return nil, "every slot (0-" .. (registration.SLOTS - 1) .. ") is held by another map in this build folder"
end
-- }}}

-- {{{ registration.clean_text
-- A WC3 map's text as one plain line: its colour codes (|cAARRGGBB, |r)
-- and line breaks (|n, control characters) taken out
function registration.clean_text(s, limit)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""):gsub("|[nN]", " ")
    s = s:gsub("%c", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if limit and #s > limit then s = s:sub(1, limit) end
    return s
end
-- }}}

-- {{{ registration.model_name: CreatureModelData's name for a model path
-- 3.3.5a's own rows name a model ".mdx" and the client reads the ".m2"
-- (unchecked whether ".m2" works there too); a map's own WC3 model keeps
-- its name, since it is a WC3 .mdx
function registration.model_name(path, own)
    if own then return path end
    return (path:gsub("%.[mM]2$", ".mdx"))
end
-- }}}

-- {{{ registration.area_row: one AreaTable row of a map's own
-- o: id, bit (AreaBit), name, parent (0: a zone), flags; the other columns
-- as the zone's (W02c)
function registration.area_row(ids, o)
    return {
        ID = o.id, ContinentID = ids.map, ParentAreaID = o.parent or 0, AreaBit = o.bit, Flags = o.flags or 0,
        ExplorationLevel = 0, AreaName = o.name, FactionGroupMask = 0, MinElevation = -500, AmbientMultiplier = 0,
        LightID = 0,
    }
end
-- }}}

-- {{{ registration.rows
-- info: parsers.w3i's (or nil); C: wowbuild.creatures' (displays,
-- factions); ids: registration.ids(slot) (with area_bit settled);
-- opts: directory, strings (parsers.wts's), picture (the loading screen's
-- archive path). Returns { Map = { row }, AreaTable = ..., ... } and a
-- table of notes; the light's (wowbuild.light) are the second value.
function registration.rows(info, C, ids, opts)
    local resolve = require("wowbuild.creatures").resolve_string
    local name = registration.clean_text(resolve(info and info.name, opts.strings), 120)
    if name == "" or name:match("^TRIGSTR_") then name = opts.directory end
    local rows = {}
    rows.Map = { {
        ID = ids.map, Directory = opts.directory, InstanceType = 0, Flags = 0, PVP = 0,
        MapName = name, AreaTableID = ids.area, MapDescription0 = "", MapDescription1 = "",
        LoadingScreenID = ids.loading_screen, MinimapIconScale = 1, CorpseMapID = -1, CorpseX = 0, CorpseY = 0,
        TimeOfDayOverride = -1, ExpansionID = 0, RaidOffset = 0, MaxPlayers = 0,
    } }
    rows.AreaTable = { registration.area_row(ids, { id = ids.area, bit = ids.area_bit, name = name }) }
    rows.LoadingScreens = { { ID = ids.loading_screen, Name = opts.directory, FileName = opts.picture or "", HasWideScreen = 0 } }

    -- the creatures' looks: one display a model and size, one model row a display
    rows.CreatureDisplayInfo, rows.CreatureModelData = {}, {}
    for _, d in ipairs(C and C.displays or {}) do
        local r = d.radius or 1
        rows.CreatureDisplayInfo[#rows.CreatureDisplayInfo + 1] = {
            ID = d.id, ModelID = d.id, SoundID = 0, ExtendedDisplayInfoID = 0, CreatureModelScale = d.scale or 1,
            CreatureModelAlpha = 255, TextureVariation1 = "", TextureVariation2 = "", TextureVariation3 = "",
            PortraitTextureName = "", SizeClass = 1,
        }
        rows.CreatureModelData[#rows.CreatureModelData + 1] = {
            ID = d.id, Flags = 0, ModelName = registration.model_name(d.wow, d.own), SizeClass = 1, ModelScale = 1,
            CollisionWidth = r * 0.5, CollisionHeight = r * 2, MountHeight = 0,
            GeoBoxMinX = -r, GeoBoxMinY = -r, GeoBoxMinZ = 0, GeoBoxMaxX = r, GeoBoxMaxY = r, GeoBoxMaxZ = r * 2,
            WorldEffectScale = 1, AttachedEffectScale = 1,
        }
    end

    -- the sides: one group bit a faction (from 16 up, above the four the
    -- stock FactionGroup.dbc uses: 1 player, 2 Alliance, 4 Horde, 8 monster);
    -- hostility by masks, since a template lists only four enemies by name
    rows.FactionTemplate, rows.Faction = {}, {}
    local factions = C and C.factions or {}
    if #factions > 28 then error("more than 28 factions: no group bits left", 0) end
    local bit_of = {}
    for i, f in ipairs(factions) do bit_of[f.template] = 2 ^ (3 + i) end
    for _, f in ipairs(factions) do
        local enemies = 0
        for _, e in ipairs(f.enemies or {}) do enemies = enemies + (bit_of[e] or 0) end
        rows.FactionTemplate[#rows.FactionTemplate + 1] = {
            ID = f.template, Faction = f.template, Flags = 0, FactionGroup = bit_of[f.template],
            FriendGroup = bit_of[f.template], EnemyGroup = enemies,
        }
        rows.Faction[#rows.Faction + 1] = {
            ID = f.template, ReputationIndex = -1, ParentFactionID = 0,
            Name = registration.clean_text(f.name, 120), Description = "",
        }
    end

    -- the light: the map's default, with its own fog and water tint (W02i)
    local light_rows, light_said = require("wowbuild.light").rows(info, ids, opts.yards_per_unit)
    for name, list in pairs(light_rows) do rows[name] = list end
    return rows, light_said
end
-- }}}

return registration
