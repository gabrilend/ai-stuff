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

    -- Type identification
    self.type_id = data.id
    self.id = data.id  -- Alias for compatibility with tests/other code
    self.variation = data.variation or 0

    -- Position and orientation
    self.position = data.position and {
        x = data.position.x or 0,
        y = data.position.y or 0,
        z = data.position.z or 0,
    } or { x = 0, y = 0, z = 0 }
    self.angle = data.angle or 0

    -- Scale (defaults to 1.0 if not provided)
    self.scale = data.scale and {
        x = data.scale.x or 1,
        y = data.scale.y or 1,
        z = data.scale.z or 1,
    } or { x = 1, y = 1, z = 1 }

    -- Ownership
    self.player = data.player or 0

    -- Base stats (-1 = use default from object data)
    self.base_hp = data.hp or -1
    self.base_mp = data.mp or -1

    -- Item drops (from 202b)
    self.item_drops = data.item_drops or {}

    -- Modified abilities (from 202c)
    self.abilities = data.abilities or {}

    -- Hero data (from 202d, nil for non-heroes)
    self.hero_data = data.hero_data

    -- Random unit data (from 202e, nil if not random)
    self.random_unit = data.random_unit

    -- Waygate destination (from 202e, -1 if not a waygate)
    self.waygate_dest = data.waygate_dest or -1

    -- Creation ID for trigger references
    self.creation_id = data.creation_number or data.creation_id

    -- Flags from parser
    self.gold_amount = data.gold_amount or 0
    self.target_acquisition = data.target_acquisition or -1

    -- Runtime state (nil until game starts)
    self.current_hp = nil
    self.current_mp = nil
    self.is_alive = true

    return self
end
-- }}}

-- {{{ is_hero
-- Check if this unit is a hero.
-- Heroes have hero_data from the parser, or capital first letter in type ID.
-- @return true if this is a hero unit
function Unit:is_hero()
    -- Primary check: has hero data from parser
    if self.hero_data then
        return true
    end
    -- Fallback: capital first letter (but not random units)
    if self.type_id and not self:is_random() then
        local first = self.type_id:byte(1)
        return first and first >= 65 and first <= 90
    end
    return false
end
-- }}}

-- {{{ is_building
-- Check if this unit is a building.
-- WC3 buildings typically have lowercase first letter and specific patterns.
-- @return true if this is a building
function Unit:is_building()
    if not self.type_id then return false end
    local first = self.type_id:byte(1)
    local second = self.type_id:byte(2)

    -- Buildings: lowercase first letter
    if not first or first < 97 or first > 122 then
        return false
    end

    -- Common building patterns by race:
    -- Human: htow (Town Hall), hbar (Barracks), etc.
    -- Orc: ogre (Great Hall), obar (Barracks), etc.
    -- Undead: unpl (Necropolis), usep (Crypt), etc.
    -- Night Elf: etol (Tree of Life), eaow (Ancient of War), etc.
    -- Neutral: nmer (Mercenary Camp), nmrk (Marketplace), etc.

    -- Buildings often have specific second chars
    -- 'b' = barracks-type, 't' = town hall-type, etc.
    -- But this heuristic isn't perfect - WC3 doesn't have a clear flag

    -- For now, consider it a building if first letter is lowercase
    -- and it's not an item (which would have 'i' prefix for some)
    -- This is an approximation; proper detection needs object data lookup
    -- Note: 'g' removed - too many false positives (ogru=Grunt vs ogrv=Great Hall)
    return second and (
        second == string.byte('t') or  -- town hall types
        second == string.byte('b') or  -- barracks types
        second == string.byte('a') or  -- altar, ancient types
        second == string.byte('w') or  -- workshop types
        second == string.byte('f') or  -- farm types
        second == string.byte('s')     -- sanctuary, spirit types
    )
end
-- }}}

-- {{{ is_item
-- Check if this unit entry represents a preplaced item.
-- Items in WC3 are stored in war3mapUnits.doo with specific type ID patterns.
-- @return true if this is a preplaced item
function Unit:is_item()
    if not self.type_id then return false end
    -- Items typically start with 'I' (uppercase) for custom items
    -- or lowercase for standard items like 'bspd' (Boots of Speed)
    -- Check for common item prefixes
    local first = self.type_id:sub(1, 1)
    if first == "I" then
        return true
    end
    -- Standard items often have specific 4-char codes
    -- This is a heuristic; proper detection needs object data lookup
    return false
end
-- }}}

-- {{{ is_random
-- Check if this is a random unit placeholder.
-- Random units have type ID starting with 'Y' and random_unit data.
-- @return true if this is a random unit placeholder
function Unit:is_random()
    if self.random_unit then
        return true
    end
    if self.type_id then
        return self.type_id:sub(1, 1) == "Y"
    end
    return false
end
-- }}}

-- {{{ is_waygate
-- Check if this unit has an active waygate destination.
-- Waygates teleport units to a region identified by creation_id.
-- @return true if this is an active waygate
function Unit:is_waygate()
    return self.waygate_dest and self.waygate_dest >= 0
end
-- }}}

-- {{{ get_hero_level
-- Get the hero's level if this is a hero.
-- @return Hero level (1+) or nil if not a hero
function Unit:get_hero_level()
    if self.hero_data then
        return self.hero_data.level or 1
    end
    return nil
end
-- }}}

-- {{{ get_hero_stats
-- Get the hero's bonus stats from tomes.
-- @return Table with str_bonus, agi_bonus, int_bonus or nil if not a hero
function Unit:get_hero_stats()
    if self.hero_data then
        return {
            str_bonus = self.hero_data.str_bonus or 0,
            agi_bonus = self.hero_data.agi_bonus or 0,
            int_bonus = self.hero_data.int_bonus or 0,
        }
    end
    return nil
end
-- }}}

-- {{{ get_inventory
-- Get the hero's inventory (items by slot).
-- @return Table mapping slot (0-5) to item ID, or empty table if not a hero
function Unit:get_inventory()
    if self.hero_data and self.hero_data.inventory then
        return self.hero_data.inventory
    end
    return {}
end
-- }}}

-- {{{ get_waygate_destination
-- Get the waygate destination region creation ID.
-- @return Creation ID of destination region, or nil if not a waygate
function Unit:get_waygate_destination()
    if self:is_waygate() then
        return self.waygate_dest
    end
    return nil
end
-- }}}

-- {{{ has_item_drops
-- Check if this unit has item drops configured.
-- @return true if unit drops items on death
function Unit:has_item_drops()
    if not self.item_drops then return false end
    if self.item_drops.sets then
        return #self.item_drops.sets > 0
    end
    return false
end
-- }}}

-- {{{ get_item_drops
-- Get the item drop configuration.
-- @return Item drops table or nil
function Unit:get_item_drops()
    return self.item_drops
end
-- }}}

-- {{{ has_modified_abilities
-- Check if this unit has modified abilities.
-- @return true if unit has custom ability levels or autocast settings
function Unit:has_modified_abilities()
    return self.abilities and #self.abilities > 0
end
-- }}}

-- {{{ get_abilities
-- Get the modified abilities list.
-- @return Array of ability tables {id, level, autocast} or empty array
function Unit:get_abilities()
    return self.abilities or {}
end
-- }}}

-- {{{ __tostring
-- String representation for debugging.
function Unit:__tostring()
    local desc = self.type_id or "?"

    -- Add hero level if applicable
    if self:is_hero() and self.hero_data then
        desc = desc .. " L" .. (self.hero_data.level or 1)
    end

    -- Add markers for special types
    local markers = {}
    if self:is_hero() then markers[#markers + 1] = "HERO" end
    if self:is_building() then markers[#markers + 1] = "BUILDING" end
    if self:is_item() then markers[#markers + 1] = "ITEM" end
    if self:is_random() then markers[#markers + 1] = "RANDOM" end
    if self:is_waygate() then markers[#markers + 1] = "WAYGATE" end

    local marker_str = #markers > 0 and " [" .. table.concat(markers, ",") .. "]" or ""

    return string.format("Unit<%s%s P%d at (%.0f,%.0f)>",
        desc,
        marker_str,
        self.player or 0,
        self.position.x,
        self.position.y)
end
-- }}}
-- }}}

return Unit
