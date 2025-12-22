-- Unit Class
-- Represents units, buildings, heroes, and items from war3mapUnits.doo.
-- Wraps parsed unit data with methods for querying unit type, hero status, etc.
--
-- Implementation: 206c-implement-unit-class

-- {{{ Unit class
local Unit = {}
Unit.__index = Unit

-- {{{ new
-- Create a new Unit from parsed unit data.
-- @param data Table from unitsdoo.parse() containing unit fields
-- @return Unit instance
function Unit.new(data)
    local self = setmetatable({}, Unit)
    -- TODO: Copy fields from data in 206c
    self.id = data.id
    self.position = data.position
    self.player = data.player
    self.creation_number = data.creation_number
    self.hero_data = data.hero_data
    self.waygate_dest = data.waygate_dest
    return self
end
-- }}}

-- {{{ Placeholder methods (implement in 206c)
function Unit:is_hero()
    -- TODO: Check if type ID starts with capital letter
    if not self.id then return false end
    local first = self.id:byte(1)
    return first >= 65 and first <= 90
end

function Unit:is_building()
    -- TODO: Check building flag or type ID pattern
    return false
end

function Unit:is_item()
    -- TODO: Check if this is a preplaced item
    return false
end

function Unit:is_random()
    -- TODO: Check random_flag
    return false
end

function Unit:is_waygate()
    -- TODO: Check waygate_dest >= 0
    return self.waygate_dest and self.waygate_dest >= 0
end

function Unit:get_hero_level()
    -- TODO: Return hero level from hero_data
    if self.hero_data then
        return self.hero_data.level or 1
    end
    return nil
end
-- }}}

-- {{{ __tostring
function Unit:__tostring()
    local hero_marker = self:is_hero() and " [HERO]" or ""
    return string.format("Unit<%s%s @ %.0f,%.0f player=%d>",
        self.id or "?",
        hero_marker,
        self.position and self.position.x or 0,
        self.position and self.position.y or 0,
        self.player or -1)
end
-- }}}
-- }}}

return Unit
