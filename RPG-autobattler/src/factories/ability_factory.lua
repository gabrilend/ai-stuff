-- {{{ Ability factory
-- Builds abilities from the named templates in
-- src/data/ability_templates.lua, with any settings changed.
local AbilityFactory = {}

local Ability = require("src.components.ability")
local UnitAbilities = require("src.components.unit_abilities")
local AbilityTemplates = require("src.data.ability_templates")

-- {{{ local function deep_copy
local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = deep_copy(inner)
    end
    return copy
end
-- }}}

-- {{{ AbilityFactory.create_config
-- A fresh copy of the template's settings with `changes` laid over them,
-- named after the template unless changes name it.
function AbilityFactory.create_config(template_name, changes)
    local template = AbilityTemplates.abilities[template_name]
    if not template then
        error("Unknown ability template: " .. tostring(template_name))
    end
    local config = deep_copy(template)
    config.name = config.name or template_name
    for key, value in pairs(changes or {}) do
        config[key] = deep_copy(value)
    end
    return config
end
-- }}}

-- {{{ AbilityFactory.create
function AbilityFactory.create(template_name, changes)
    return Ability.new(AbilityFactory.create_config(template_name, changes))
end
-- }}}

-- {{{ AbilityFactory.create_set
-- The configs for a named set, ready for UnitAbilities.attach.
function AbilityFactory.create_set(set_name)
    local names = AbilityTemplates.sets[set_name]
    if not names then
        error("Unknown ability set: " .. tostring(set_name))
    end
    local configs = {}
    for index, name in ipairs(names) do
        configs[index] = AbilityFactory.create_config(name)
    end
    return configs
end
-- }}}

-- {{{ AbilityFactory.attach_set
-- Gives an entity a named set of abilities and its mana bars.
function AbilityFactory.attach_set(entity_manager, entity, set_name)
    return UnitAbilities.attach(entity_manager, entity, AbilityFactory.create_set(set_name))
end
-- }}}

-- {{{ AbilityFactory.template_names
function AbilityFactory.template_names()
    local names = {}
    for name in pairs(AbilityTemplates.abilities) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end
-- }}}

return AbilityFactory
-- }}}
