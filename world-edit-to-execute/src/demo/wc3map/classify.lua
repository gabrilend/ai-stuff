--[[
Classify (Issue 517d)

Decides which design (geometry/designs.lua) stands in for each object a map
places, from the best evidence at hand, strongest first:

  1. the object's model path, for custom objects that set one
     ("buildings\human\..." is a human building)
  2. its name, for custom objects ("Tandred's Flagship" is a ship)
  3. its parent, for custom objects (a copy of the knight rides a horse)
  4. a table of stock object ids (below). WRITTEN FROM MEMORY of the game,
     not read from its data: the stock tables are on the owner's install,
     not here. Where the owner's game data is available, a stock row's
     fields should take this table's place.
  5. naming conventions: a capital first letter is a hero; the first letter
     of a unit id is its race (h, o, u, e; n neutral); the second letter of
     a doodad id its kind (T tree, R rock, P plant, O prop, S structure)

Each result says which rule decided it (`by`), so a scene can count how
much of what it draws is guessed.

    local classify = require("demo.wc3map.classify")
    local spec = classify.unit("hkni", { name = "...", model = "...", parent = "..." })
    local spec = classify.doodad("LTlt", info)   -- nil: draws nothing (blockers)
]]

local classify = {}

-- {{{ Stock ids (from memory; see the header)
local function load_list(t, text, fields)
    for id, a in text:gmatch("(%w%w%w%w):(%w+)") do
        local row = {}
        for k, v in pairs(fields) do row[k] = v end
        row.what = a
        t[id] = row
    end
end

local STOCK = {}
-- buildings: what = footprint class
load_list(STOCK, "htow:hall hkee:hall hcas:hall hhou:small hbar:medium hbla:medium hlum:medium " ..
    "harm:medium hars:medium hgra:medium halt:altar hvlt:small hwtw:tower hgtw:tower hctw:tower " ..
    "hatw:tower", { design = "building", race = "human" })
load_list(STOCK, "ogre:hall ostr:hall ofrt:hall otrb:small obar:medium ofor:medium obea:medium " ..
    "osld:medium otto:medium oalt:altar ovln:small owtw:tower", { design = "building", race = "orc" })
load_list(STOCK, "unpl:hall unp1:hall unp2:hall uzig:small uzg1:tower uzg2:tower usep:medium " ..
    "ugrv:medium uslh:medium utod:medium ubon:medium usap:medium uaod:altar utom:small",
    { design = "building", race = "undead" })
load_list(STOCK, "etol:hall etoa:hall etoe:hall emow:small eaom:medium eaoe:medium eaow:medium " ..
    "etrp:tower edob:medium eate:altar eden:medium edos:medium", { design = "building", race = "nightelf" })
load_list(STOCK, "ngol:special nmrk:special ntav:medium ngme:small ngad:medium nfoh:special " ..
    "nmoo:special", { design = "building", race = "neutral" })
-- units: what = archetype
load_list(STOCK, "hpea:worker hfoo:infantry hkni:mounted hrif:gunner hmtm:siege hgyr:flyer " ..
    "hgry:flyer hmpr:caster hsor:caster hspt:infantry hdhw:flyer hmil:infantry hwat:heavy " ..
    "hbsh:ship hdes:ship hbot:ship hphx:flyer", { design = "unit", race = "human" })
load_list(STOCK, "opeo:worker ogru:infantry orai:mounted otau:heavy ohun:ranged otbk:ranged " ..
    "ocat:siege oshm:caster odoc:caster owyv:flyer okod:beast otbr:flyer ospw:caster",
    { design = "unit", race = "orc" })
load_list(STOCK, "uaco:worker ugho:infantry uabo:heavy ucry:beast ugar:flyer umtw:siege " ..
    "unec:caster uban:caster ufro:flyer uobs:heavy ushd:caster uske:infantry",
    { design = "unit", race = "undead" })
load_list(STOCK, "ewsp:worker earc:ranged esen:mounted edry:beast edot:caster edoc:caster " ..
    "emtg:heavy ehip:flyer efdr:flyer echm:flyer ebal:siege", { design = "unit", race = "nightelf" })
load_list(STOCK, "nban:infantry nbrg:ranged nrog:infantry nenf:infantry nbld:infantry " ..
    "nogr:heavy nogm:heavy nomg:heavy nftr:ranged nftb:infantry ngnl:infantry nkob:infantry " ..
    "nwlf:beast nspr:beast nmrl:infantry nfel:beast nzom:infantry", { design = "unit", race = "neutral" })
load_list(STOCK, "nmyr:infantry nnsw:caster nsnp:beast nnmg:infantry", { design = "unit", race = "naga" })
load_list(STOCK, "ncb0:medium ncb1:medium ncb2:medium ncb3:medium ncb4:medium ncb5:medium " ..
    "ncb6:medium ncb7:medium ncb8:medium ncb9:medium ncba:medium ncbb:medium ncbc:medium " ..
    "ncbd:medium ncbe:medium ncbf:medium ntnt:small npgf:small", { design = "building", race = "neutral" })
load_list(STOCK, "hshy:medium", { design = "building", race = "human" })
load_list(STOCK, "oshy:medium", { design = "building", race = "orc" })
load_list(STOCK, "eshy:medium", { design = "building", race = "nightelf" })
load_list(STOCK, "ushp:medium", { design = "building", race = "undead" })
load_list(STOCK, "hhes:infantry hcth:infantry nhea:ranged", { design = "unit", race = "human" })
load_list(STOCK, "nchg:infantry nchp:worker nass:infantry ninf:heavy nbal:heavy nogl:heavy " ..
    "ngnb:infantry nitr:ranged ncen:mounted nfgu:infantry", { design = "unit", race = "neutral" })
load_list(STOCK, "uktn:caster", { design = "unit", race = "undead" })

-- heroes (capital letter): archetype
local HEROES = {
    Hpal = "infantry", Hamg = "caster", Hmkg = "infantry", Hblm = "caster",
    Obla = "infantry", Ofar = "caster", Otch = "heavy", Oshd = "caster",
    Udea = "mounted", Ulic = "caster", Udre = "caster", Ucrl = "beast",
    Ekee = "beast", Emoo = "ranged", Edem = "infantry", Ewar = "infantry",
}
-- }}}

-- {{{ Keywords
-- Words in a model path or name that settle what an object is. Checked in
-- this order; the first list with a match wins.
local UNIT_WORDS = {
    { "ship", { "ship", "flagship", "frigate", "transport", "juggernaut", "boat", "destroyer", "galleon", "barge" } },
    { "flyer", { "dragon", "gryphon", "wyvern", "hawk", "drake", "wyrm", "phoenix", "gargoyle",
                 "hippogryph", "chimaera", "batrider", "zeppelin", "gyrocopter", "roc" } },
    { "siege", { "catapult", "cannon", "ballista", "demolisher", "wagon", "tank", "siege",
                 "engine", "glaive", "mortar" } },
    { "mounted", { "knight", "rider", "cavalry", "raider", "lancer", "horse", "charger" } },
    { "gunner", { "rifle", "rifleman", "riflemen", "musket", "musketeer", "gunner", "engineer", "crossbow", "crossbowman", "crossbowmen" } },
    { "ranged", { "archer", "ranger", "bowman", "bowmen", "hunter", "headhunter", "thrower", "harpooner", "sentinel" } },
    { "caster", { "priest", "priestess", "mage", "wizard", "sorcerer", "sorceress", "shaman", "warlock", "necromancer",
                  "witch", "druid", "summoner", "magus", "cleric", "lich", "oracle", "seer", "bishop",
                  "monk", "inquisitor" } },
    { "beast", { "wolf", "wolves", "bear", "spider", "boar", "raptor", "kodo", "hound", "beast", "stag",
                 "lion", "tiger", "crab", "turtle", "worg", "hydra" } },
    { "heavy", { "ogre", "giant", "golem", "abomination", "tauren", "elemental", "infernal",
                 "treant", "behemoth", "colossus", "doomguard", "construct" } },
    { "worker", { "peasant", "peon", "worker", "acolyte", "wisp", "builder", "miner", "villager" } },
}

local BUILDING_WORDS = {
    { "special", { "control point", "capture", "waygate", "portal", "statue", "monument",
                   "flag", "banner", "beacon", "fountain", "circle of power" } },
    { "hall", { "townhall", "town hall", "keep", "castle", "greathall", "great hall", "stronghold",
                "fortress", "necropolis", "halls", "treeof", "tree of", "citadel", "palace", "capital" } },
    { "tower", { "tower", "protector", "spire", "lighthouse", "obelisk" } },
    { "small", { "farm", "burrow", "ziggurat", "moonwell", "moon well", "house", "hut", "well",
                 "cottage", "tent", "shack" } },
    { "altar", { "altar", "shrine" } },
    { "medium", { "barracks", "temple", "monastery", "sanctum", "workshop", "forge", "lodge",
                  "den", "roost", "aviary", "mill", "crypt", "graveyard", "market", "tavern",
                  "library", "cathedral", "church", "inn", "stable", "bank", "harbor", "shipyard" } },
}

local RACE_WORDS = {
    { "human", { "\\human\\", "\\humans\\" } },
    { "orc", { "\\orc\\" } },
    { "undead", { "\\undead\\" } },
    { "nightelf", { "\\nightelf\\" } },
    { "naga", { "\\naga\\" } },
    { "demon", { "\\demon\\" } },
}

-- Model paths run words together ("DragonBuildingBlack"), so a word may
-- match anywhere in them; in names (whole = true) it must be a whole word,
-- plural allowed ("den" matches "Den of Wolves", not "Maiden"; "flag" not
-- "Flagship").
local function first_match(text, lists, whole)
    if not text or text == "" then return nil end
    -- drop the game's colour codes: |cffRRGGBB ... |r
    text = text:gsub("|[cC]%x%x%x%x%x%x%x%x", ""):gsub("|[rR]", ""):lower()
    for _, entry in ipairs(lists) do
        for _, word in ipairs(entry[2]) do
            if whole then
                if (" " .. text .. " "):find("[^%a]" .. word:gsub("%p", "%%%0") .. "s?[^%a]") then
                    return entry[1]
                end
            elseif text:find(word, 1, true) then
                return entry[1]
            end
        end
    end
    return nil
end
-- }}}

-- {{{ race_of_id
local ID_RACE = { h = "human", o = "orc", u = "undead", e = "nightelf", n = "neutral" }
local function race_of_id(id)
    return ID_RACE[id:sub(1, 1):lower()] or "neutral"
end
-- }}}

-- {{{ classify.unit
-- id: 4-char unit id. info (optional): { name, model, parent } from the
-- map's own object data. Returns a design spec with `by` naming the rule.
function classify.unit(id, info, depth)
    info = info or {}
    local hero = id:sub(1, 1):match("%u") ~= nil
    local model = info.model and info.model:lower() or nil

    -- 1. model path
    if model and model:find("^buildings\\") then
        return { design = "building", race = first_match(model, RACE_WORDS) or race_of_id(id),
                 size = first_match(model, BUILDING_WORDS) or first_match(info.name, BUILDING_WORDS, true) or "medium",
                 by = "model" }
    end
    if model and model:find("^doodads\\") then
        return { design = "building", race = "neutral",
                 size = first_match(model, BUILDING_WORDS) or first_match(info.name, BUILDING_WORDS, true) or "special",
                 by = "model" }
    end
    local arch = model and model:find("^units\\") and first_match(model, UNIT_WORDS)
    if arch then
        return { design = "unit", race = first_match(model, RACE_WORDS) or race_of_id(id),
                 archetype = arch, hero = hero, by = "model" }
    end

    -- 2. name
    local size = first_match(info.name, BUILDING_WORDS, true)
    if size then
        return { design = "building", race = race_of_id(id), size = size, by = "name" }
    end
    arch = first_match(info.name, UNIT_WORDS, true)
    if arch then
        return { design = "unit", race = race_of_id(id), archetype = arch, hero = hero, by = "name" }
    end

    -- 3. parent (custom objects copy a stock one)
    if info.parent and info.parent ~= id and (depth or 0) < 4 then
        local spec = classify.unit(info.parent, info.parent_info, (depth or 0) + 1)
        if spec.by ~= "guess" then
            spec.by = "parent"
            spec.hero = spec.hero or hero
            return spec
        end
    end

    -- 4. stock table
    local row = STOCK[id]
    if row then
        if row.design == "building" then
            return { design = "building", race = row.race, size = row.what, by = "table" }
        end
        return { design = "unit", race = row.race, archetype = row.what, by = "table" }
    end
    if HEROES[id] then
        return { design = "unit", race = race_of_id(id), archetype = HEROES[id], hero = true, by = "table" }
    end

    -- 5. convention
    return { design = "unit", race = race_of_id(id), archetype = "infantry", hero = hero,
             by = "guess" }
end
-- }}}

-- {{{ classify.doodad
-- Doodads and destructables. Returns a design spec, or nil for things the
-- game doesn't draw (pathing and sight blockers).
local TREE_SUFFIX = { tw = true, tr = true, lt = true, tc = true, st = true, ft = true, sh = true }
local PINE_TILESETS = { N = true, W = true, I = true }

function classify.doodad(id, info, depth)
    info = info or {}
    local text = ((info.name or "") .. " " .. (info.model or "")):lower()
    local tileset = id:sub(1, 1):upper()
    local kind = id:sub(2, 2)
    local suffix = id:sub(3, 4):lower()

    -- invisible in the game: pathing blockers, line-of-sight blockers
    if text:find("pathing blocker", 1, true) or text:find("line of sight", 1, true)
        or (tileset == "Y" and kind == "T" and suffix:match("^[pfalc][bc]$")) then
        return nil
    end

    -- 1-2. model and name
    if text:find("tree", 1, true) or text:find("pine", 1, true) then
        return { design = "tree", tileset = tileset, style = PINE_TILESETS[tileset] and "pine" or "round", by = "name" }
    end
    if text:find("rock", 1, true) or text:find("boulder", 1, true) then
        return { design = "rock", by = "name" }
    end
    if text:find("wall", 1, true) or text:find("pallisade", 1, true) or text:find("fence", 1, true) then
        return { design = "structure", style = "wall", by = "name" }
    end
    if text:find("lamp", 1, true) or text:find("torch", 1, true) or text:find("brazier", 1, true) then
        return { design = "prop", style = "lamp", by = "name" }
    end

    -- 3. parent
    if info.parent and info.parent ~= id and (depth or 0) < 4 then
        local spec = classify.doodad(info.parent, info.parent_info, (depth or 0) + 1)
        if spec == nil then return nil end
        if spec.by ~= "guess" then
            spec.by = "parent"
            return spec
        end
    end

    -- 5. convention: the second letter of the id
    if kind == "T" and (TREE_SUFFIX[suffix] or suffix:match("^w%d$")) then
        return { design = "tree", tileset = tileset, style = PINE_TILESETS[tileset] and "pine" or "round", by = "convention" }
    elseif kind == "R" then
        return { design = "rock", by = "convention" }
    elseif kind == "P" then
        return { design = "plant", tileset = tileset, by = "convention" }
    elseif kind == "S" then
        return { design = "structure", style = suffix:match("^w%d$") and "wall" or nil, by = "convention" }
    elseif kind == "O" then
        return { design = "prop", style = suffix:match("lp") and "lamp" or nil, by = "convention" }
    end
    return { design = "prop", by = "guess" }
end
-- }}}

return classify
