-- {{{ Ability selector
-- The logic behind choosing and tuning the abilities of a unit template,
-- with nothing drawn: a screen (issue 062's editor) shows what this holds
-- and calls these when the player clicks. It works on its own copy of the
-- template, so nothing changes until the player applies a choice.
--
--   AbilitySelector:new(template, library)  template: a UnitTemplate or
--                                           its data; library: an
--                                           AbilityLibrary (made if nil)
--   selector:slots()                 what each slot holds and costs
--   selector:select_slot(index)      start editing a slot (1 = primary);
--                                    loads what is there into the draft
--   selector:choose(id)              put a library ability in the draft
--   selector:set_property(name, v)   tune the draft; returns the value
--                                    kept (held to its limits) and notes
--   selector:custom(config)          a whole ability config of the
--                                    player's own in the draft
--   selector:preview()               what applying the draft would do
--   selector:apply()                 write the draft into the slot
--   selector:clear_slot(index)       remove a slot's ability
--   selector:result()                the edited template, a new
--                                    UnitTemplate
--
-- The draft is {template = id, changes = {...}} for a library ability or
-- {config = {...}} for a custom one: the same shapes a UnitTemplate
-- keeps, so applying it is a copy.
local AbilitySelector = {}
AbilitySelector.__index = AbilitySelector

local UnitTemplate = require("src.data.unit_template")
local AbilityLibrary = require("src.data.ability_library")
local Ability = require("src.components.ability")
local TemplateConstraints = require("src.data.template_constraints")

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

-- {{{ local function draft_entry
-- The draft as an entry for UnitTemplate.new.
local function draft_entry(draft)
    if draft.template then
        if next(draft.changes) then
            return {template = draft.template, changes = deep_copy(draft.changes)}
        end
        return draft.template
    end
    return deep_copy(draft.config)
end
-- }}}

-- {{{ AbilitySelector:new
function AbilitySelector:new(template, library)
    local data = UnitTemplate.is_template(template) and template:to_save_data() or deep_copy(template or {})
    local selector = {
        library = library or AbilityLibrary:new(),
        template = UnitTemplate.new(data),
        slot = nil,
        draft = nil,
        notes = {}
    }
    setmetatable(selector, self)
    return selector
end
-- }}}

-- {{{ AbilitySelector:max_slots
function AbilitySelector:max_slots()
    return TemplateConstraints.abilities.max_count
end
-- }}}

-- {{{ AbilitySelector:slots
-- One row per slot up to the limit: {index, primary, filled, id (library
-- id or nil for a custom ability), name, kind, cost}.
function AbilitySelector:slots()
    local rows = {}
    for index = 1, self:max_slots() do
        local entry = self.template.abilities[index]
        local row = {index = index, primary = index == 1, filled = entry ~= nil, cost = 0}
        if entry then
            local config = self.template:ability_config(index)
            row.id = entry.template
            row.name = (config and config.name) or entry.template or "?"
            row.kind = config and config.type
            row.cost = self.template.breakdown.abilities[index] or 0
        end
        rows[index] = row
    end
    return rows
end
-- }}}

-- {{{ AbilitySelector:select_slot
-- Start editing a slot. A slot past the last filled one is treated as the
-- next empty slot. Returns the slot index, or nil and a note.
function AbilitySelector:select_slot(index)
    if type(index) ~= "number" or index < 1 or index > self:max_slots() or index % 1 ~= 0 then
        return nil, string.format("Slot %s is not one of 1-%d", tostring(index), self:max_slots())
    end
    index = math.min(index, #self.template.abilities + 1)
    self.slot = index
    self.notes = {}
    local entry = self.template.abilities[index]
    if not entry then
        self.draft = nil
    elseif entry.template then
        self.draft = {template = entry.template, changes = deep_copy(entry.changes) or {}}
    else
        self.draft = {config = deep_copy(entry.config)}
    end
    return index
end
-- }}}

-- {{{ AbilitySelector:choose
-- Put a library ability in the draft, with no changes. The primary slot
-- takes only abilities that can be a primary. Returns the library entry,
-- or nil and a note.
function AbilitySelector:choose(id)
    if not self.slot then
        return nil, "Pick a slot first"
    end
    local entry = self.library:get(id)
    if not entry then
        return nil, "No ability named " .. tostring(id)
    end
    if self.slot == 1 and not entry.can_be_primary then
        return nil, string.format("%s is a %s ability; the primary slot needs one that deals damage or heals",
            entry.name, entry.category)
    end
    self.draft = {template = id, changes = {}}
    self.notes = {}
    return entry
end
-- }}}

-- {{{ AbilitySelector:set_property
-- Tune the draft. A library ability takes only its tunable properties,
-- held to their limits; a custom one takes any value, and preview() says
-- if it breaks a rule. Returns the value kept and the notes.
function AbilitySelector:set_property(name, value)
    if not self.draft then
        return nil, {"Choose an ability first"}
    end
    if self.draft.config then
        self.draft.config[name] = deep_copy(value)
        self.notes = {}
        return value, self.notes
    end
    local wanted = deep_copy(self.draft.changes)
    wanted[name] = value
    local clean, notes = self.library:clean_changes(self.draft.template, wanted)
    self.draft.changes = clean
    self.notes = notes
    local limits = self.library:limits(self.draft.template)
    local kept = clean[name]
    if kept == nil and limits[name] then
        kept = limits[name].base
    end
    return kept, notes
end
-- }}}

-- {{{ AbilitySelector:reset_property
-- Puts a tuned property of a library ability back to the template's value.
function AbilitySelector:reset_property(name)
    if self.draft and self.draft.changes then
        self.draft.changes[name] = nil
    end
end
-- }}}

-- {{{ AbilitySelector:custom
-- Put a whole ability config of the player's own in the draft. It must
-- build; the template's rules are checked by preview(). Returns true, or
-- nil and a note.
function AbilitySelector:custom(config)
    if not self.slot then
        return nil, "Pick a slot first"
    end
    if type(config) ~= "table" then
        return nil, "A custom ability is a table of settings"
    end
    local ok, problem = pcall(Ability.new, deep_copy(config))
    if not ok then
        return nil, "That ability can't be built: " .. tostring(problem):gsub("^.-:%d+: ", "")
    end
    self.draft = {config = deep_copy(config)}
    self.draft.config.name = self.draft.config.name or "custom_ability"
    self.notes = {}
    return true
end
-- }}}

-- {{{ AbilitySelector:trial
-- The template as it would be with the draft in the current slot.
function AbilitySelector:trial()
    local data = self.template:to_save_data()
    data.abilities[self.slot] = draft_entry(self.draft)
    return UnitTemplate.new(data)
end
-- }}}

-- {{{ AbilitySelector:preview
-- What applying the draft would do: {cost (of this ability), was (what
-- the slot cost before), points_used, change (in the template's total),
-- points_left, valid, errors, warnings, config, limits (for a library
-- ability), notes}. Nil and a note without a draft.
function AbilitySelector:preview()
    if not self.draft then
        return nil, "Choose an ability first"
    end
    local trial = self:trial()
    local config = trial:ability_config(self.slot)
    return {
        slot = self.slot,
        cost = trial.breakdown.abilities[self.slot] or 0,
        was = self.template.breakdown.abilities[self.slot] or 0,
        points_used = trial.points_used,
        change = trial.points_used - self.template.points_used,
        points_left = trial:points_left(),
        valid = trial.is_valid,
        errors = trial.validation_errors,
        warnings = trial.validation_warnings,
        config = config,
        limits = self.draft.template and self.library:limits(self.draft.template) or nil,
        notes = self.notes
    }
end
-- }}}

-- {{{ AbilitySelector:apply
-- Write the draft into the slot. Refused when the result has errors, so
-- the working template is always one that can be saved. Returns true and
-- the preview, or false and the preview (or nil and a note).
function AbilitySelector:apply()
    local preview, problem = self:preview()
    if not preview then
        return nil, problem
    end
    if not preview.valid then
        return false, preview
    end
    self.template = self:trial()
    return true, preview
end
-- }}}

-- {{{ AbilitySelector:clear_slot
-- Remove a slot's ability; the ones after it move up. The primary can be
-- cleared only when a second ability can take its place. Returns true,
-- or nil and a note.
function AbilitySelector:clear_slot(index)
    local abilities = self.template.abilities
    if not abilities[index] then
        return nil, string.format("Slot %s is empty", tostring(index))
    end
    if #abilities == 1 then
        return nil, "A template needs at least one ability"
    end
    local data = self.template:to_save_data()
    table.remove(data.abilities, index)
    local trial = UnitTemplate.new(data)
    if not trial.is_valid then
        return nil, "Removing it would leave the template invalid: " .. table.concat(trial.validation_errors, "; ")
    end
    self.template = trial
    if self.slot == index then
        self.slot, self.draft = nil, nil
    end
    return true
end
-- }}}

-- {{{ AbilitySelector:result
function AbilitySelector:result()
    return UnitTemplate.new(self.template:to_save_data())
end
-- }}}

return AbilitySelector
-- }}}
