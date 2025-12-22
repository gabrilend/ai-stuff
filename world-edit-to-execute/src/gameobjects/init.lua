-- Game Object Type System
-- Provides unified wrapper classes for parsed WC3 map data.
-- Each class wraps parser output in a consistent API with methods
-- for querying object properties and state.
--
-- Usage:
--   local gameobjects = require("gameobjects")
--   local doodad = gameobjects.Doodad.new(parsed_doodad_data)
--   local unit = gameobjects.Unit.new(parsed_unit_data)

-- {{{ Module imports
-- Classes are required as they are implemented in sub-issues 206b-206f
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
