-- {{{ Template manager
-- Keeps the unit templates in play by name: the defaults that come with
-- the game and any a player registers. Only valid templates are kept.
--
--   TemplateManager:new()
--   manager:register_template(template)  true, or false and the errors
--   manager:get_template(name)
--   manager:remove_template(name)
--   manager:list()                       names, sorted
--   manager:create_default_templates()   one per ability set
--   manager:save_to_storage(storage) / load_from_storage(storage)
local TemplateManager = {}
TemplateManager.__index = TemplateManager

local UnitTemplate = require("src.data.unit_template")

-- The defaults: a name, a body and an ability set from
-- src/data/ability_templates.lua for each, plus any stats raised above
-- the body's own. Each must fit the default budget.
TemplateManager.DEFAULTS = {
    {name = "Warrior", unit_type = "melee", set = "basic_warrior", stats = {armor = 4},
        description = "Sword and power strike; holds the line."},
    {name = "Archer", unit_type = "ranged", set = "basic_archer",
        description = "Bow and piercing shot; fights from range while standing still."},
    {name = "Cleric", unit_type = "support", set = "support_cleric", stats = {health = 80},
        description = "Heals the weakest ally and wards a group."},
    {name = "Battle Mage", unit_type = "special", set = "battle_mage",
        description = "Meteors on clumped enemies; stirs allies to fury."},
    {name = "Brute", unit_type = "tank", set = "brute",
        description = "Stuns, cripples and sunders the armor of what it hits."},
    {name = "Druid", unit_type = "support", set = "druid",
        description = "Regeneration and healing circles from range."},
    {name = "Skirmisher", unit_type = "ranged", set = "skirmisher", stats = {speed = 55},
        description = "Poison darts and piercing shots."},
    {name = "Berserker", unit_type = "melee", set = "berserker", stats = {health = 140},
        description = "A cleaving axe and battle fury."},
    {name = "Crossbowman", unit_type = "ranged", set = "crossbowman",
        description = "Slow, heavy, accurate bolts."},
    {name = "Field Medic", unit_type = "support", set = "field_medic",
        description = "Emergency heals for allies near death."},
    {name = "Storm Caller", unit_type = "special", set = "storm_caller",
        description = "Static fields that slow and burn; curses that weaken."}
}

-- {{{ TemplateManager:new
function TemplateManager:new()
    local manager = {
        templates = {},
        default_names = {}
    }
    setmetatable(manager, self)
    return manager
end
-- }}}

-- {{{ TemplateManager:register_template
-- Keeps a valid template under its name, replacing any of that name.
-- Accepts a template or the data for one.
function TemplateManager:register_template(template)
    if not UnitTemplate.is_template(template) then
        template = UnitTemplate.new(template)
    end
    local ok, errors = template:validate()
    if not ok then
        return false, errors
    end
    self.templates[template.name] = template
    return true
end
-- }}}

-- {{{ TemplateManager:get_template
function TemplateManager:get_template(name)
    return self.templates[name]
end
-- }}}

-- {{{ TemplateManager:remove_template
function TemplateManager:remove_template(name)
    local had = self.templates[name] ~= nil
    self.templates[name] = nil
    return had
end
-- }}}

-- {{{ TemplateManager:list
function TemplateManager:list()
    local names = {}
    for name in pairs(self.templates) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end
-- }}}

-- {{{ TemplateManager.default_template_data
-- The data for the default templates, as UnitTemplate.new takes it.
function TemplateManager.default_template_data()
    local AbilityTemplates = require("src.data.ability_templates")
    local list = {}
    for _, default in ipairs(TemplateManager.DEFAULTS) do
        local abilities = {}
        for index, name in ipairs(AbilityTemplates.sets[default.set]) do
            abilities[index] = name
        end
        table.insert(list, {
            name = default.name,
            description = default.description,
            created_by = "Default",
            unit_type = default.unit_type,
            stats = default.stats,
            abilities = abilities
        })
    end
    return list
end
-- }}}

-- {{{ TemplateManager:create_default_templates
-- Registers every default. Returns the templates by name; errors if a
-- default doesn't validate, since that's a mistake in the game's data.
function TemplateManager:create_default_templates()
    local made = {}
    for _, data in ipairs(TemplateManager.default_template_data()) do
        local template = UnitTemplate.new(data)
        local ok, errors = self:register_template(template)
        if not ok then
            error("Default template " .. data.name .. " isn't valid: " .. table.concat(errors, "; "))
        end
        made[template.name] = template
        self.default_names[template.name] = true
    end
    return made
end
-- }}}

-- {{{ TemplateManager:save_to_storage
-- Saves every template to a TemplateStorage (src/storage/
-- template_storage.lua): defaults to "default", the rest to "user".
-- Returns how many were saved and a list of problems.
function TemplateManager:save_to_storage(storage)
    local saved, problems = 0, {}
    for _, name in ipairs(self:list()) do
        local category = self:is_default(name) and "default" or "user"
        local ok, message = storage:save_template(self.templates[name], category)
        if ok then
            saved = saved + 1
        else
            table.insert(problems, name .. ": " .. tostring(message))
        end
    end
    return saved, problems
end
-- }}}

-- {{{ TemplateManager:load_from_storage
-- Registers every valid template a TemplateStorage holds, in the given
-- category or all of them. Later categories ("imported" after "user"
-- after "default") win when names repeat. Returns how many were loaded
-- and a list of problems.
function TemplateManager:load_from_storage(storage, category)
    local loaded, problems = 0, {}
    local order = {default = 1, user = 2, imported = 3}
    local entries = storage:list_templates(category)
    table.sort(entries, function(a, b)
        if order[a.category] ~= order[b.category] then
            return order[a.category] < order[b.category]
        end
        return a.name < b.name
    end)
    for _, entry in ipairs(entries) do
        local template, info = storage:load_template(entry.name, entry.category)
        if not template then
            table.insert(problems, entry.name .. ": " .. tostring(info))
        else
            local ok, errors = self:register_template(template)
            if ok then
                loaded = loaded + 1
                self.default_names[template.name] = entry.category == "default" or nil
            else
                table.insert(problems, entry.name .. ": " .. table.concat(errors, "; "))
            end
        end
    end
    return loaded, problems
end
-- }}}

-- {{{ TemplateManager:is_default
function TemplateManager:is_default(name)
    return self.default_names[name] == true
end
-- }}}

return TemplateManager
-- }}}
