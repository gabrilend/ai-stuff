-- Game Object Type System
-- Provides unified wrapper classes for parsed WC3 map data.
-- Each class wraps parser output in a consistent API with methods
-- for querying object properties and state.
--
-- Available classes:
--   Doodad  - Trees, destructibles, decorative objects (from war3map.doo)
--   Unit    - Units, buildings, heroes, items (from war3mapUnits.doo)
--   Region  - Trigger areas, waygate destinations (from war3map.w3r)
--   Camera  - Cinematic and gameplay cameras (from war3map.w3c)
--   Sound   - Sound definitions and ambient loops (from war3map.w3s)
--
-- Usage:
--   local gameobjects = require("gameobjects")
--   local doodad = gameobjects.Doodad.new(parsed_doodad_data)
--   local unit = gameobjects.Unit.new(parsed_unit_data)
--
-- Type checking:
--   if getmetatable(obj) == gameobjects.Unit then ... end
--
-- All classes provide:
--   - Class.new(parsed_data) constructor
--   - __tostring metamethod for debugging
--   - Defensive copying of nested tables
--   - LuaDoc-style documentation comments
--
-- Implementation: Issue 206 (206a-206g sub-issues)

-- {{{ Module imports
local Doodad = require("gameobjects.doodad")
local Unit = require("gameobjects.unit")
local Region = require("gameobjects.region")
local Camera = require("gameobjects.camera")
local Sound = require("gameobjects.sound")
-- }}}

-- {{{ Module exports
return {
    Doodad = Doodad,
    Unit = Unit,
    Region = Region,
    Camera = Camera,
    Sound = Sound,
}
-- }}}
