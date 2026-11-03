-- {{{ Template editor
-- The template editor's logic, with nothing drawn: the template being
-- edited, its tabs, undo and redo, unsaved-change tracking, saving and
-- loading through template storage, and the four parts a screen shows:
--   stats       src/editor/stat_allocator.lua
--   abilities   src/editor/ability_selector.lua
--   budget      src/editor/point_budget.lua and
--               src/utils/budget_optimizer.lua
--   preview     src/editor/template_preview.lua
-- plus a layout of the screen's panels for any window size. A screen
-- (a LÖVE state) draws what this holds and calls these on input.
--
--   TemplateEditor:new(options)    options: template (a UnitTemplate or
--                                  its data), storage (TemplateStorage),
--                                  category (default "user")
-- Every change returns what the part it delegates to returns, records
-- an undo step, and keeps last_change (a PointBudget.change) for a
-- screen to animate.
local TemplateEditor = {}
TemplateEditor.__index = TemplateEditor

local UnitTemplate = require("src.data.unit_template")
local TemplateCosts = require("src.data.template_costs")
local Unit = require("src.entities.unit")
local StatAllocator = require("src.editor.stat_allocator")
local AbilitySelector = require("src.editor.ability_selector")
local AbilityLibrary = require("src.data.ability_library")
local PointBudget = require("src.editor.point_budget")
local BudgetOptimizer = require("src.utils.budget_optimizer")
local TemplatePreview = require("src.editor.template_preview")

TemplateEditor.TABS = {"stats", "abilities", "appearance", "preview"}
TemplateEditor.HISTORY_LIMIT = 50
TemplateEditor.SIZE_LIMITS = {min = 0.5, max = 1.5}
-- Below this width the panels stack instead of sitting side by side.
TemplateEditor.WIDE = 1000

-- {{{ local function blank
local function blank(unit_type)
    unit_type = unit_type or "melee"
    local primary = unit_type == "ranged" and "primary_ranged_attack" or "primary_melee_attack"
    return {name = "New Unit", unit_type = unit_type, abilities = {primary}}
end
-- }}}

-- {{{ TemplateEditor:new
function TemplateEditor:new(options)
    options = options or {}
    local template = options.template
    if UnitTemplate.is_template(template) then
        template = template:to_save_data()
    end
    local editor = {
        storage = options.storage,
        category = options.category or "user",
        library = AbilityLibrary:new(),
        preview = TemplatePreview:new(),
        tab = TemplateEditor.TABS[1],
        undo_stack = {},
        redo_stack = {},
        last_change = nil
    }
    setmetatable(editor, self)
    editor.template = UnitTemplate.new(template or blank())
    editor:mark_saved()
    return editor
end
-- }}}

-- {{{ TemplateEditor:switch_tab
function TemplateEditor:switch_tab(name)
    for _, tab in ipairs(TemplateEditor.TABS) do
        if tab == name then
            self.tab = name
            return true
        end
    end
    return false, "No tab named " .. tostring(name)
end
-- }}}

-- {{{ TemplateEditor:next_tab
-- One tab along (direction 1) or back (-1), wrapping round.
function TemplateEditor:next_tab(direction)
    local count = #TemplateEditor.TABS
    for index, tab in ipairs(TemplateEditor.TABS) do
        if tab == self.tab then
            self.tab = TemplateEditor.TABS[(index - 1 + (direction < 0 and -1 or 1)) % count + 1]
            return self.tab
        end
    end
end
-- }}}

-- {{{ TemplateEditor:replace
-- Puts a new template in place as one undoable step.
function TemplateEditor:replace(template, label)
    if TemplatePreview.signature(template) == TemplatePreview.signature(self.template) then
        return false
    end
    table.insert(self.undo_stack, {data = self.template:to_save_data(), label = label})
    if #self.undo_stack > TemplateEditor.HISTORY_LIMIT then
        table.remove(self.undo_stack, 1)
    end
    self.redo_stack = {}
    self:put(template)
    return true
end
-- }}}

-- {{{ TemplateEditor:put
function TemplateEditor:put(template)
    local before = PointBudget.summary(self.template)
    self.template = template
    self.last_change = PointBudget.change(before, PointBudget.summary(template))
end
-- }}}

-- {{{ TemplateEditor:edit
-- A change to the template's data as one undoable step.
function TemplateEditor:edit(label, change)
    local data = self.template:to_save_data()
    change(data)
    return self:replace(UnitTemplate.new(data), label)
end
-- }}}

-- {{{ TemplateEditor:undo
-- Returns the label of the step undone, or nil.
function TemplateEditor:undo()
    local step = table.remove(self.undo_stack)
    if not step then
        return nil
    end
    table.insert(self.redo_stack, {data = self.template:to_save_data(), label = step.label})
    self:put(UnitTemplate.new(step.data))
    return step.label
end
-- }}}

-- {{{ TemplateEditor:redo
function TemplateEditor:redo()
    local step = table.remove(self.redo_stack)
    if not step then
        return nil
    end
    table.insert(self.undo_stack, {data = self.template:to_save_data(), label = step.label})
    self:put(UnitTemplate.new(step.data))
    return step.label
end
-- }}}

-- {{{ TemplateEditor:mark_saved
-- The current template is the saved (or opened) version.
function TemplateEditor:mark_saved()
    self.saved_data = self.template:to_save_data()
    self.saved = TemplatePreview.signature(self.template)
end
-- }}}

-- {{{ TemplateEditor:is_dirty
function TemplateEditor:is_dirty()
    return TemplatePreview.signature(self.template) ~= self.saved
end
-- }}}

-- {{{ TemplateEditor:set_name
function TemplateEditor:set_name(name)
    self:edit("rename", function(data) data.name = name end)
    return self.template.name
end
-- }}}

-- {{{ TemplateEditor:set_description
function TemplateEditor:set_description(text)
    self:edit("describe", function(data) data.description = text end)
    return self.template.description
end
-- }}}

-- {{{ TemplateEditor:set_unit_type
-- Changes the body. Stats go back to the new body's own values, since
-- stats are priced against the body; the shape follows the body.
-- Abilities stay.
function TemplateEditor:set_unit_type(unit_type)
    local body = TemplateCosts.bodies[unit_type]
    if not body then
        return nil, "No body named " .. tostring(unit_type)
    end
    self:edit("change body", function(data)
        data.unit_type = unit_type
        for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
            data.stats[stat] = body[stat]
        end
        data.appearance.shape = Unit.get_unit_shape(unit_type)
    end)
    return unit_type
end
-- }}}

-- {{{ TemplateEditor:set_color
-- which: "primary" or "secondary"; each part held to 0-1.
function TemplateEditor:set_color(which, red, green, blue)
    if which ~= "primary" and which ~= "secondary" then
        return nil, "Colors are primary or secondary"
    end
    local function part(value)
        return math.max(0, math.min(1, tonumber(value) or 0))
    end
    local color = {part(red), part(green), part(blue)}
    self:edit("recolor", function(data) data.appearance[which .. "_color"] = color end)
    return color
end
-- }}}

-- {{{ TemplateEditor:set_size
function TemplateEditor:set_size(modifier)
    if type(modifier) ~= "number" then
        return nil, "Size is a number"
    end
    local limits = TemplateEditor.SIZE_LIMITS
    modifier = math.max(limits.min, math.min(limits.max, modifier))
    self:edit("resize", function(data) data.appearance.size_modifier = modifier end)
    return modifier
end
-- }}}

-- {{{ TemplateEditor:stats
-- A stat allocator on the current template; commit with apply_stats.
function TemplateEditor:stats()
    return StatAllocator:new(self.template)
end
-- }}}

-- {{{ TemplateEditor:apply_stats
function TemplateEditor:apply_stats(allocator, label)
    return self:replace(allocator:result(), label or "stats")
end
-- }}}

-- {{{ TemplateEditor:set_stat
-- One stat, as StatAllocator:set; returns the value kept and any note.
function TemplateEditor:set_stat(stat, value)
    local allocator = self:stats()
    local kept, note = allocator:set(stat, value)
    if kept ~= nil then
        self:apply_stats(allocator, "set " .. stat)
    end
    return kept, note
end
-- }}}

-- {{{ TemplateEditor:apply_preset
function TemplateEditor:apply_preset(id)
    local allocator = self:stats()
    local ok, spent = allocator:apply_preset(id)
    if ok then
        self:apply_stats(allocator, "preset " .. id)
    end
    return ok, spent
end
-- }}}

-- {{{ TemplateEditor:abilities
-- An ability selector on the current template; commit with
-- apply_abilities.
function TemplateEditor:abilities()
    return AbilitySelector:new(self.template, self.library)
end
-- }}}

-- {{{ TemplateEditor:apply_abilities
function TemplateEditor:apply_abilities(selector, label)
    return self:replace(selector:result(), label or "abilities")
end
-- }}}

-- {{{ TemplateEditor:set_ability
-- Puts library ability `id` with `changes` into `slot`. Returns true and
-- the selector's preview, or false and the preview (it would leave
-- errors), or nil and a note.
function TemplateEditor:set_ability(slot, id, changes)
    local selector = self:abilities()
    local index, problem = selector:select_slot(slot)
    if not index then
        return nil, problem
    end
    local entry, why = selector:choose(id)
    if not entry then
        return nil, why
    end
    local keys = {}
    for key in pairs(changes or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        selector:set_property(key, changes[key])
    end
    local ok, preview = selector:apply()
    if ok then
        self:apply_abilities(selector, "ability " .. index)
    end
    return ok, preview
end
-- }}}

-- {{{ TemplateEditor:remove_ability
function TemplateEditor:remove_ability(slot)
    local selector = self:abilities()
    local ok, problem = selector:clear_slot(slot)
    if ok then
        self:apply_abilities(selector, "remove ability " .. slot)
    end
    return ok, problem
end
-- }}}

-- {{{ TemplateEditor:budget
function TemplateEditor:budget()
    return PointBudget.summary(self.template)
end
-- }}}

-- {{{ TemplateEditor:feedback
-- Every message for the player, budget first then errors and warnings.
function TemplateEditor:feedback()
    return self:budget().messages
end
-- }}}

-- {{{ TemplateEditor:optimize
function TemplateEditor:optimize(options)
    return BudgetOptimizer.suggest(self.template, options)
end
-- }}}

-- {{{ TemplateEditor:apply_suggestion
function TemplateEditor:apply_suggestion(suggestion)
    return self:replace(BudgetOptimizer.apply(suggestion), suggestion.description)
end
-- }}}

-- {{{ TemplateEditor:analysis
function TemplateEditor:analysis()
    return self.preview:update(self.template)
end
-- }}}

-- {{{ TemplateEditor:save
-- Saves through storage. Returns true and the file's path, or false and
-- why (no storage, or the template has errors).
function TemplateEditor:save(metadata)
    if not self.storage then
        return false, "Nowhere to save: the editor has no template storage"
    end
    local ok, result = self.storage:save_template(self.template, self.category, metadata)
    if ok then
        self:mark_saved()
    end
    return ok, result
end
-- }}}

-- {{{ TemplateEditor:open
-- Starts editing another template (a fresh history). Refused while there
-- are unsaved changes, unless force.
function TemplateEditor:open(template, force)
    if self:is_dirty() and not force then
        return nil, "Unsaved changes; save first, or open anyway to drop them"
    end
    if not UnitTemplate.is_template(template) then
        template = UnitTemplate.new(template)
    end
    self.undo_stack, self.redo_stack, self.last_change = {}, {}, nil
    self.template = UnitTemplate.new(template:to_save_data())
    self:mark_saved()
    return self.template
end
-- }}}

-- {{{ TemplateEditor:load
-- Opens a saved template by name. Returns it and storage's info, or nil
-- and why.
function TemplateEditor:load(name, category, force)
    if not self.storage then
        return nil, "Nowhere to load from: the editor has no template storage"
    end
    if self:is_dirty() and not force then
        return nil, "Unsaved changes; save first, or load anyway to drop them"
    end
    local template, info = self.storage:load_template(name, category or self.category)
    if not template then
        return nil, info
    end
    self:open(template, true)
    return self.template, info
end
-- }}}

-- {{{ TemplateEditor:new_template
function TemplateEditor:new_template(unit_type, force)
    if unit_type and not TemplateCosts.bodies[unit_type] then
        return nil, "No body named " .. tostring(unit_type)
    end
    return self:open(blank(unit_type), force)
end
-- }}}

-- {{{ TemplateEditor:revert
-- Back to the last saved (or opened) version, as an undoable step.
function TemplateEditor:revert()
    return self:replace(UnitTemplate.new(self.saved_data), "revert")
end
-- }}}

-- {{{ TemplateEditor:can_exit
function TemplateEditor:can_exit(force)
    if self:is_dirty() and not force then
        return false, "Unsaved changes; save first, or leave anyway to drop them"
    end
    return true
end
-- }}}

-- {{{ TemplateEditor.layout
-- Where each panel goes in a window of this size: {mode ("wide" or
-- "narrow"), tabs, editor, preview, budget, buttons}, each {x, y,
-- width, height}. Wide windows put the editor and the preview side by
-- side; narrow ones stack them. Panels never overlap and, in a window
-- at least 190 high, stay inside it.
function TemplateEditor.layout(width, height)
    local margin, gap = 10, 10
    local tabs_height, budget_height, buttons_height = 40, 60, 40
    local inner_width = math.max(0, width - 2 * margin)
    local layout = {mode = width >= TemplateEditor.WIDE and "wide" or "narrow"}
    local y = margin
    layout.tabs = {x = margin, y = y, width = inner_width, height = tabs_height}
    y = y + tabs_height + gap
    local bottom = height - margin - buttons_height - gap - budget_height - gap
    local middle = math.max(0, bottom - y)
    if layout.mode == "wide" then
        local editor_width = math.floor((inner_width - gap) * 0.6)
        layout.editor = {x = margin, y = y, width = editor_width, height = middle}
        layout.preview = {x = margin + editor_width + gap, y = y, width = inner_width - editor_width - gap,
            height = middle}
    else
        local editor_height = math.floor(math.max(0, middle - gap) * 0.6)
        layout.editor = {x = margin, y = y, width = inner_width, height = editor_height}
        layout.preview = {x = margin, y = y + editor_height + gap, width = inner_width,
            height = math.max(0, middle - editor_height - gap)}
    end
    y = y + middle + gap
    layout.budget = {x = margin, y = y, width = inner_width, height = budget_height}
    y = y + budget_height + gap
    layout.buttons = {x = margin, y = y, width = inner_width, height = buttons_height}
    return layout
end
-- }}}

return TemplateEditor
-- }}}
