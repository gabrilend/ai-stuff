-- {{{ Components module loader
local components = {}

-- Load all component constructors
components.Position = require("src.components.position")
components.Health = require("src.components.health")
components.Team = require("src.components.team")
components.Renderable = require("src.components.renderable")
components.Moveable = require("src.components.moveable")
components.Mana = require("src.components.mana")
components.Ability = require("src.components.ability")
components.UnitAbilities = require("src.components.unit_abilities")

-- Component type constants
components.POSITION = "position"
components.HEALTH = "health"
components.TEAM = "team"
components.RENDERABLE = "renderable"
components.MOVEABLE = "moveable"
components.MANA = "mana"
components.ABILITIES = "abilities"

return components
-- }}}