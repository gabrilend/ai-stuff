--[[
Object Data Parser - Core Module

Parses the shared binary format used by all WC3 object modification files:
w3u (units), w3t (items), w3a (abilities), w3b (destructibles),
w3d (doodads), w3h (buffs), w3q (upgrades).

Binary format (version 2):
  int32       version
  Table       original_table
  Table       custom_table

Table:
  int32       count
  Object[count]

Object:
  char[4]     original_id
  char[4]     new_id (0x00000000 for original table)
  int32       mod_count
  Modification[mod_count]

Modification:
  char[4]     field_id
  int32       var_type (0=int, 1=real, 2=unreal, 3=string)
  [int32      level]   (only w3a, w3d, w3q)
  [int32      column]  (only w3a, w3d, w3q)
  <value>     data
  char[4]     end_marker

Usage:
  local objectdata = require("parsers.objectdata")
  local result = objectdata.parse(data, { has_level_column = false })
]]

local compat = require("compat")

local objectdata = {}

-- {{{ Constants
-- Variable types
objectdata.VAR_TYPE = {
    INT = 0,
    REAL = 1,
    UNREAL = 2,  -- Real clamped to 0.0-1.0
    STRING = 3,
}

-- File type configurations
objectdata.FILE_CONFIG = {
    w3u = { name = "units", has_level_column = false },
    w3t = { name = "items", has_level_column = false },
    w3b = { name = "destructibles", has_level_column = false },
    w3d = { name = "doodads", has_level_column = true },
    w3a = { name = "abilities", has_level_column = true },
    w3h = { name = "buffs", has_level_column = false },
    w3q = { name = "upgrades", has_level_column = true },
}
-- }}}

-- {{{ Helper functions

-- {{{ local function read_char4
-- Read a 4-character ID string (e.g., 'hfoo').
local function read_char4(data, pos)
    if pos + 3 > #data then
        return nil, pos, "Unexpected end of data reading char[4]"
    end
    local id = data:sub(pos, pos + 3)
    return id, pos + 4
end
-- }}}

-- {{{ local function read_int32
-- Read a signed 32-bit little-endian integer.
local function read_int32(data, pos)
    if pos + 3 > #data then
        return nil, pos, "Unexpected end of data reading int32"
    end
    local value, next_pos = compat.unpack_int32(data, pos)
    return value, next_pos
end
-- }}}

-- {{{ local function read_uint32
-- Read an unsigned 32-bit little-endian integer.
local function read_uint32(data, pos)
    if pos + 3 > #data then
        return nil, pos, "Unexpected end of data reading uint32"
    end
    local value, next_pos = compat.unpack_uint32(data, pos)
    return value, next_pos
end
-- }}}

-- {{{ local function read_float
-- Read a 32-bit IEEE 754 float.
local function read_float(data, pos)
    if pos + 3 > #data then
        return nil, pos, "Unexpected end of data reading float"
    end
    local value, next_pos = compat.unpack_float(data, pos)
    return value, next_pos
end
-- }}}

-- {{{ local function read_string
-- Read a null-terminated string.
local function read_string(data, pos)
    local null_pos = data:find("\0", pos, true)
    if not null_pos then
        return nil, pos, "Unterminated string"
    end
    local str = data:sub(pos, null_pos - 1)
    return str, null_pos + 1
end
-- }}}

-- {{{ local function is_null_id
-- Check if an ID is all zeros (null).
local function is_null_id(id)
    return id == "\0\0\0\0"
end
-- }}}

-- {{{ local function id_to_string
-- Convert a 4-byte ID to a readable string.
-- Handles both printable and non-printable characters.
local function id_to_string(id)
    if is_null_id(id) then
        return nil
    end
    -- Check if all characters are printable
    local printable = true
    for i = 1, 4 do
        local b = id:byte(i)
        if b < 32 or b > 126 then
            printable = false
            break
        end
    end
    if printable then
        return id
    end
    -- Return as hex for non-printable IDs
    return string.format("0x%02X%02X%02X%02X",
        id:byte(1), id:byte(2), id:byte(3), id:byte(4))
end
-- }}}

-- }}}

-- {{{ local function parse_modification
-- Parse a single modification entry.
-- @param data Binary data
-- @param pos Current position
-- @param has_level_column Whether this format includes level/column fields
-- @return modification table, next position, or nil and error
local function parse_modification(data, pos, has_level_column)
    local mod = {}

    -- Field ID
    local field_id, err
    field_id, pos, err = read_char4(data, pos)
    if not field_id then return nil, pos, err end
    mod.field_id = id_to_string(field_id) or field_id

    -- Variable type
    local var_type
    var_type, pos, err = read_int32(data, pos)
    if not var_type then return nil, pos, err end
    mod.var_type = var_type

    -- Level and column (only for abilities, doodads, upgrades)
    if has_level_column then
        local level, column
        level, pos, err = read_int32(data, pos)
        if not level then return nil, pos, err end
        mod.level = level

        column, pos, err = read_int32(data, pos)
        if not column then return nil, pos, err end
        mod.column = column
    end

    -- Value (type-dependent)
    if var_type == objectdata.VAR_TYPE.INT then
        local value
        value, pos, err = read_int32(data, pos)
        if not value then return nil, pos, err end
        mod.value = value
    elseif var_type == objectdata.VAR_TYPE.REAL or var_type == objectdata.VAR_TYPE.UNREAL then
        local value
        value, pos, err = read_float(data, pos)
        if not value then return nil, pos, err end
        mod.value = value
        -- Clamp unreal to 0.0-1.0 if needed
        if var_type == objectdata.VAR_TYPE.UNREAL then
            if mod.value < 0 then mod.value = 0 end
            if mod.value > 1 then mod.value = 1 end
        end
    elseif var_type == objectdata.VAR_TYPE.STRING then
        local value
        value, pos, err = read_string(data, pos)
        if not value then return nil, pos, err end
        mod.value = value
    else
        -- Unknown type - treat as int and log warning
        local value
        value, pos, err = read_int32(data, pos)
        if not value then return nil, pos, err end
        mod.value = value
        mod.unknown_type = true
    end

    -- End marker (object ID that defined this modification)
    local end_marker
    end_marker, pos, err = read_char4(data, pos)
    if not end_marker then return nil, pos, err end
    mod.source_id = id_to_string(end_marker)

    return mod, pos
end
-- }}}

-- {{{ local function parse_object
-- Parse a single object definition.
-- @param data Binary data
-- @param pos Current position
-- @param is_custom Whether this is from the custom table
-- @param has_level_column Whether this format includes level/column fields
-- @return object table, next position, or nil and error
local function parse_object(data, pos, is_custom, has_level_column)
    local obj = {}
    local err

    -- Original object ID (parent)
    local original_id
    original_id, pos, err = read_char4(data, pos)
    if not original_id then return nil, pos, err end
    obj.original_id = id_to_string(original_id)

    -- New object ID (only meaningful for custom table)
    local new_id
    new_id, pos, err = read_char4(data, pos)
    if not new_id then return nil, pos, err end
    obj.new_id = id_to_string(new_id)

    -- For original table entries, new_id should be null
    if not is_custom and not is_null_id(new_id) then
        -- Some maps have non-null new_id in original table - treat as modification
        obj.new_id = nil
    end

    -- The ID used for lookup
    if is_custom and obj.new_id then
        obj.id = obj.new_id
        obj.parent_id = obj.original_id
    else
        obj.id = obj.original_id
    end

    -- Modification count
    local mod_count
    mod_count, pos, err = read_int32(data, pos)
    if not mod_count then return nil, pos, err end

    -- Parse modifications
    obj.modifications = {}
    for i = 1, mod_count do
        local mod
        mod, pos, err = parse_modification(data, pos, has_level_column)
        if not mod then
            return nil, pos, "Error parsing modification " .. i .. ": " .. (err or "unknown")
        end
        obj.modifications[#obj.modifications + 1] = mod
    end

    return obj, pos
end
-- }}}

-- {{{ local function parse_table
-- Parse an object table (original or custom).
-- @param data Binary data
-- @param pos Current position
-- @param is_custom Whether this is the custom table
-- @param has_level_column Whether this format includes level/column fields
-- @return table of objects, next position, or nil and error
local function parse_table(data, pos, is_custom, has_level_column)
    local objects = {}
    local err

    -- Object count
    local count
    count, pos, err = read_int32(data, pos)
    if not count then return nil, pos, err end

    -- Parse each object
    for i = 1, count do
        local obj
        obj, pos, err = parse_object(data, pos, is_custom, has_level_column)
        if not obj then
            return nil, pos, "Error parsing object " .. i .. ": " .. (err or "unknown")
        end
        objects[#objects + 1] = obj
    end

    return objects, pos
end
-- }}}

-- {{{ objectdata.parse
-- Parse object data from binary.
-- @param data Binary data string
-- @param options Table with optional settings:
--   has_level_column: boolean (default false)
-- @return ObjectDataTable or nil and error message
function objectdata.parse(data, options)
    options = options or {}
    local has_level_column = options.has_level_column or false

    if not data or #data < 4 then
        return nil, "Data too short"
    end

    local pos = 1
    local err

    -- Version
    local version
    version, pos, err = read_int32(data, pos)
    if not version then return nil, err end

    if version ~= 2 and version ~= 1 then
        return nil, "Unsupported object data version: " .. tostring(version)
    end

    -- Original table
    local original_objects
    original_objects, pos, err = parse_table(data, pos, false, has_level_column)
    if not original_objects then return nil, err end

    -- Custom table
    local custom_objects
    custom_objects, pos, err = parse_table(data, pos, true, has_level_column)
    if not custom_objects then return nil, err end

    -- Build result
    local result = {
        version = version,
        original = {},
        custom = {},
        _by_id = {},
    }

    -- Index original objects
    for _, obj in ipairs(original_objects) do
        result.original[obj.id] = obj
        result._by_id[obj.id] = obj
    end

    -- Index custom objects
    for _, obj in ipairs(custom_objects) do
        result.custom[obj.id] = obj
        result._by_id[obj.id] = obj
    end

    -- Set metatable for ObjectDataTable methods
    setmetatable(result, { __index = objectdata.ObjectDataTable })

    return result
end
-- }}}

-- {{{ ObjectDataTable class
objectdata.ObjectDataTable = {}

-- {{{ ObjectDataTable:get
-- Get an object by ID.
-- @param id Object ID string
-- @return Object table or nil
function objectdata.ObjectDataTable:get(id)
    return self._by_id[id]
end
-- }}}

-- {{{ ObjectDataTable:has
-- Check if an object exists.
-- @param id Object ID string
-- @return boolean
function objectdata.ObjectDataTable:has(id)
    return self._by_id[id] ~= nil
end
-- }}}

-- {{{ ObjectDataTable:get_modification
-- Get a specific modification for an object.
-- @param id Object ID
-- @param field_id Field ID to look for
-- @param level Optional level (for abilities/upgrades)
-- @return Modification value or nil
function objectdata.ObjectDataTable:get_modification(id, field_id, level)
    local obj = self._by_id[id]
    if not obj then return nil end

    for _, mod in ipairs(obj.modifications) do
        if mod.field_id == field_id then
            if level then
                if mod.level == level then
                    return mod.value
                end
            else
                return mod.value
            end
        end
    end

    return nil
end
-- }}}

-- {{{ ObjectDataTable:get_all_modifications
-- Get all modifications for an object.
-- @param id Object ID
-- @return Array of modifications or empty table
function objectdata.ObjectDataTable:get_all_modifications(id)
    local obj = self._by_id[id]
    if not obj then return {} end
    return obj.modifications
end
-- }}}

-- {{{ ObjectDataTable:get_parent
-- Get the parent object for a custom object.
-- @param id Custom object ID
-- @return Parent object or nil
function objectdata.ObjectDataTable:get_parent(id)
    local obj = self.custom[id]
    if not obj or not obj.parent_id then return nil end
    return self._by_id[obj.parent_id]
end
-- }}}

-- {{{ ObjectDataTable:is_custom
-- Check if an object is custom (user-created).
-- @param id Object ID
-- @return boolean
function objectdata.ObjectDataTable:is_custom(id)
    return self.custom[id] ~= nil
end
-- }}}

-- {{{ ObjectDataTable:count
-- Get counts of objects.
-- @return original_count, custom_count
function objectdata.ObjectDataTable:count()
    local orig = 0
    local cust = 0
    for _ in pairs(self.original) do orig = orig + 1 end
    for _ in pairs(self.custom) do cust = cust + 1 end
    return orig, cust
end
-- }}}

-- {{{ ObjectDataTable:all_ids
-- Get all object IDs.
-- @return Array of ID strings
function objectdata.ObjectDataTable:all_ids()
    local ids = {}
    for id in pairs(self._by_id) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end
-- }}}

-- {{{ ObjectDataTable:format
-- Format object data as readable string.
-- @return Formatted string
function objectdata.ObjectDataTable:format()
    local lines = {}
    local orig_count, cust_count = self:count()

    lines[#lines + 1] = string.format("Object Data (version %d)", self.version)
    lines[#lines + 1] = string.format("  Original objects: %d", orig_count)
    lines[#lines + 1] = string.format("  Custom objects: %d", cust_count)
    lines[#lines + 1] = ""

    -- Format original objects
    if orig_count > 0 then
        lines[#lines + 1] = "Original Objects:"
        for id, obj in pairs(self.original) do
            lines[#lines + 1] = string.format("  [%s] %d modifications", id, #obj.modifications)
            for _, mod in ipairs(obj.modifications) do
                local val_str
                if type(mod.value) == "string" then
                    val_str = '"' .. mod.value .. '"'
                else
                    val_str = tostring(mod.value)
                end
                if mod.level then
                    lines[#lines + 1] = string.format("    %s[%d,%d] = %s",
                        mod.field_id, mod.level, mod.column, val_str)
                else
                    lines[#lines + 1] = string.format("    %s = %s", mod.field_id, val_str)
                end
            end
        end
        lines[#lines + 1] = ""
    end

    -- Format custom objects
    if cust_count > 0 then
        lines[#lines + 1] = "Custom Objects:"
        for id, obj in pairs(self.custom) do
            lines[#lines + 1] = string.format("  [%s] (parent: %s) %d modifications",
                id, obj.parent_id or "none", #obj.modifications)
            for _, mod in ipairs(obj.modifications) do
                local val_str
                if type(mod.value) == "string" then
                    val_str = '"' .. mod.value .. '"'
                else
                    val_str = tostring(mod.value)
                end
                if mod.level then
                    lines[#lines + 1] = string.format("    %s[%d,%d] = %s",
                        mod.field_id, mod.level, mod.column, val_str)
                else
                    lines[#lines + 1] = string.format("    %s = %s", mod.field_id, val_str)
                end
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- }}}

return objectdata
