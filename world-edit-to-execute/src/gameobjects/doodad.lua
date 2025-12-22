-- Doodad Class
-- Represents trees, destructibles, and decorative objects from war3map.doo.
-- Wraps parsed doodad data with methods for querying visibility, solidity, etc.
--
-- Implementation: 206b-implement-doodad-class

-- {{{ Doodad class
local Doodad = {}
Doodad.__index = Doodad

-- {{{ new
-- Create a new Doodad from parsed doodad data.
-- @param data Table from doo.parse() containing doodad fields
-- @return Doodad instance
function Doodad.new(data)
    local self = setmetatable({}, Doodad)
    -- TODO: Copy fields from data in 206b
    self.id = data.id
    self.position = data.position
    self.creation_number = data.creation_number
    return self
end
-- }}}

-- {{{ Placeholder methods (implement in 206b)
function Doodad:is_visible()
    -- TODO: Check visibility flag
    return true
end

function Doodad:is_solid()
    -- TODO: Check solid/pathing flag
    return false
end

function Doodad:get_max_life()
    -- TODO: Return life value
    return self.life or 100
end
-- }}}

-- {{{ __tostring
function Doodad:__tostring()
    return string.format("Doodad<%s @ %.0f,%.0f>",
        self.id or "?",
        self.position and self.position.x or 0,
        self.position and self.position.y or 0)
end
-- }}}
-- }}}

return Doodad
