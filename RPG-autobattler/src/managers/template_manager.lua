-- {{{ Template manager
-- Keeps the unit templates in play by name: the defaults that come with
-- the game and any a player registers. Only valid templates are kept.
--
--   TemplateManager:new()
--   manager:register_template(template)  true, or false and the errors
--   manager:get_template(name)
--   manager:remove_template(name)
--   manager:list()                       names, sorted
--   manager:create_default_templates(sets)  the game's own templates
--                                        (src/data/default_templates.lua)
--   manager:save_to_storage(storage) / load_from_storage(storage)
local TemplateManager = {}
TemplateManager.__index = TemplateManager

local UnitTemplate = require("src.data.unit_template")
local DefaultTemplates = require("src.data.default_templates")

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
-- The data for the default templates of the named sets (all when nil),
-- from src/data/default_templates.lua, as UnitTemplate.new takes it.
function TemplateManager.default_template_data(set_names)
    return DefaultTemplates.data(set_names)
end
-- }}}

-- {{{ TemplateManager:create_default_templates
-- Registers the default templates of the named sets (all when nil).
-- Returns the templates by name; errors if a default doesn't validate,
-- since that's a mistake in the game's data.
function TemplateManager:create_default_templates(set_names)
    local made = {}
    for _, data in ipairs(TemplateManager.default_template_data(set_names)) do
        local template = UnitTemplate.new(data)
        template.default_set = data.set
        template.archetype = data.archetype
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
