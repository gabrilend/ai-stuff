-- Attribute Schema Module
-- Defines attribute types, flags, and the AttributeSchema class for validation.
--
-- AttributeSchema defines the structure and constraints for a single attribute:
-- type, range, default value, flags, and optional derived formula.
--
-- Usage:
--   local schema = require("libs.attributes.schema")
--   local attr = schema.AttributeSchema.new({
--       id = "strength",
--       type = schema.ATTR_TYPE.INTEGER,
--       min = 0, max = 999,
--       default = 10,
--   })
--   local valid, err = attr:validate(50)

-- Use compat for bitwise operations (LuaJIT compatible)
local compat = require("compat")
local band = compat.band

-- {{{ ATTR_TYPE - Attribute value types
local ATTR_TYPE = {
    INTEGER = "integer",    -- Whole numbers only
    FLOAT = "float",        -- Decimal numbers
    PERCENT = "percent",    -- 0.0 to 1.0 (or 0 to 100, configurable)
    BOOLEAN = "boolean",    -- true/false
    ENUM = "enum",          -- One of a fixed set of values
}
-- }}}

-- {{{ ATTR_FLAGS - Attribute behavior flags (bitfield)
local ATTR_FLAGS = {
    NONE = 0x00,            -- No special behavior
    PERSISTED = 0x01,       -- Saved to disk
    MODIFIABLE = 0x02,      -- Can have modifiers applied (buffs, equipment)
    DERIVED = 0x04,         -- Computed from other attributes
    HIDDEN = 0x08,          -- Not shown in UI
    READONLY = 0x10,        -- Cannot be set directly (only via formula or modifiers)
    CLAMPED = 0x20,         -- Automatically clamp to min/max on set
}
-- }}}

-- {{{ AttributeSchema class
local AttributeSchema = {}
AttributeSchema.__index = AttributeSchema

-- {{{ AttributeSchema.new
-- Create a new attribute schema from a specification table.
-- @param spec Table with attribute definition:
--   - id: Unique string identifier (required)
--   - index: Numeric array index (auto-assigned if nil)
--   - name: Display name (defaults to id)
--   - type: ATTR_TYPE value (defaults to INTEGER)
--   - min: Minimum value (optional)
--   - max: Maximum value (optional)
--   - default: Default value (defaults to 0 or false for boolean)
--   - flags: Bitfield of ATTR_FLAGS (defaults to NONE)
--   - derived_from: Array of attribute IDs this depends on (for derived attrs)
--   - formula: Function(get) to compute derived value
--   - enum_values: Array of valid values (for ENUM type)
--   - validator: Custom validation function(value) -> bool, error_msg
-- @return AttributeSchema instance
function AttributeSchema.new(spec)
    local self = setmetatable({}, AttributeSchema)

    -- Required fields
    self.id = spec.id
    if not self.id then
        error("AttributeSchema requires 'id' field")
    end

    -- Index (assigned by registry if not provided)
    self.index = spec.index

    -- Display name
    self.name = spec.name or spec.id

    -- Type with default
    self.type = spec.type or ATTR_TYPE.INTEGER

    -- Range constraints
    self.min = spec.min
    self.max = spec.max

    -- Default value (type-appropriate)
    if spec.default ~= nil then
        self.default = spec.default
    elseif self.type == ATTR_TYPE.BOOLEAN then
        self.default = false
    elseif self.type == ATTR_TYPE.ENUM then
        -- Default to first enum value if available
        self.default = spec.enum_values and spec.enum_values[1] or nil
    else
        self.default = 0
    end

    -- Flags bitfield
    self.flags = spec.flags or ATTR_FLAGS.NONE

    -- Derived attribute support
    self.derived_from = spec.derived_from or {}
    self.formula = spec.formula

    -- Enum values (for ENUM type)
    self.enum_values = spec.enum_values or {}

    -- Custom validator
    self.validator = spec.validator

    return self
end
-- }}}

-- {{{ AttributeSchema:validate
-- Validate a value against this schema's constraints.
-- @param value The value to validate
-- @return true if valid, or false and error message if invalid
function AttributeSchema:validate(value)
    -- Type check
    if self.type == ATTR_TYPE.INTEGER then
        if type(value) ~= "number" then
            return false, "Expected number, got " .. type(value)
        end
        if value ~= math.floor(value) then
            return false, "Expected integer, got float"
        end

    elseif self.type == ATTR_TYPE.FLOAT or self.type == ATTR_TYPE.PERCENT then
        if type(value) ~= "number" then
            return false, "Expected number, got " .. type(value)
        end

    elseif self.type == ATTR_TYPE.BOOLEAN then
        if type(value) ~= "boolean" then
            return false, "Expected boolean, got " .. type(value)
        end
        -- Booleans don't have range checks
        if self.validator then
            return self.validator(value)
        end
        return true

    elseif self.type == ATTR_TYPE.ENUM then
        local valid = false
        for i = 1, #self.enum_values do
            if self.enum_values[i] == value then
                valid = true
                break
            end
        end
        if not valid then
            return false, "Invalid enum value: " .. tostring(value)
        end
        -- Enums don't have range checks
        if self.validator then
            return self.validator(value)
        end
        return true
    end

    -- Range check (for numeric types)
    if self.min ~= nil and value < self.min then
        return false, "Below minimum: " .. self.min .. " (got " .. value .. ")"
    end
    if self.max ~= nil and value > self.max then
        return false, "Above maximum: " .. self.max .. " (got " .. value .. ")"
    end

    -- Custom validation
    if self.validator then
        return self.validator(value)
    end

    return true
end
-- }}}

-- {{{ AttributeSchema:clamp
-- Clamp a value to this schema's min/max range.
-- @param value The value to clamp
-- @return Clamped value
function AttributeSchema:clamp(value)
    if self.type == ATTR_TYPE.BOOLEAN or self.type == ATTR_TYPE.ENUM then
        return value
    end
    if self.min ~= nil and value < self.min then
        value = self.min
    end
    if self.max ~= nil and value > self.max then
        value = self.max
    end
    return value
end
-- }}}

-- {{{ Flag accessors

-- {{{ AttributeSchema:is_derived
-- Check if this attribute is computed from other attributes.
function AttributeSchema:is_derived()
    return band(self.flags, ATTR_FLAGS.DERIVED) ~= 0
end
-- }}}

-- {{{ AttributeSchema:is_modifiable
-- Check if modifiers (buffs, equipment) can be applied to this attribute.
function AttributeSchema:is_modifiable()
    return band(self.flags, ATTR_FLAGS.MODIFIABLE) ~= 0
end
-- }}}

-- {{{ AttributeSchema:is_persisted
-- Check if this attribute should be saved to disk.
function AttributeSchema:is_persisted()
    return band(self.flags, ATTR_FLAGS.PERSISTED) ~= 0
end
-- }}}

-- {{{ AttributeSchema:is_hidden
-- Check if this attribute should be hidden from UI.
function AttributeSchema:is_hidden()
    return band(self.flags, ATTR_FLAGS.HIDDEN) ~= 0
end
-- }}}

-- {{{ AttributeSchema:is_readonly
-- Check if this attribute cannot be set directly.
function AttributeSchema:is_readonly()
    return band(self.flags, ATTR_FLAGS.READONLY) ~= 0
end
-- }}}

-- {{{ AttributeSchema:is_clamped
-- Check if this attribute auto-clamps to min/max on set.
function AttributeSchema:is_clamped()
    return band(self.flags, ATTR_FLAGS.CLAMPED) ~= 0
end
-- }}}
-- }}}

-- {{{ AttributeSchema:has_dependencies
-- Check if this attribute depends on other attributes.
function AttributeSchema:has_dependencies()
    return #self.derived_from > 0
end
-- }}}

-- {{{ AttributeSchema:__tostring
function AttributeSchema:__tostring()
    local flags_str = ""
    if self:is_derived() then flags_str = flags_str .. "D" end
    if self:is_modifiable() then flags_str = flags_str .. "M" end
    if self:is_persisted() then flags_str = flags_str .. "P" end
    if self:is_readonly() then flags_str = flags_str .. "R" end
    if flags_str == "" then flags_str = "-" end

    return string.format("AttributeSchema<%s[%d] %s %s>",
        self.id,
        self.index or 0,
        self.type,
        flags_str)
end
-- }}}
-- }}}

-- {{{ Module exports
return {
    ATTR_TYPE = ATTR_TYPE,
    ATTR_FLAGS = ATTR_FLAGS,
    AttributeSchema = AttributeSchema,
}
-- }}}
