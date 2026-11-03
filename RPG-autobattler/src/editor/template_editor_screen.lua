-- {{{ Template editor screen
-- The template editor on a screen: the one part of the editor that
-- draws and reads the mouse and keyboard. It holds no game rules. Every
-- change goes to the tested logic in src/editor/ (TemplateEditor and the
-- parts it hands work to), and this file only turns what that logic
-- holds into things to draw, and clicks and keys into calls.
--
-- Each frame works in two steps:
--   build()   makes a display list: plain tables (panels, buttons,
--             sliders, text, bar segments, circles, the unit) with
--             their places, from TemplateEditor.layout and what the
--             editor holds. Buttons and sliders carry the call to make
--             when used.
--   draw(g)   draws that list with g (love.graphics), nothing more.
-- Input finds the item under the pointer in the same list.
--
--   TemplateEditorScreen.new(options)  options: editor (a TemplateEditor,
--                                      or one is made with storage),
--                                      storage, width, height, keyboard
--                                      (love.keyboard), battles (per
--                                      opponent for "Run battles"),
--                                      on_exit (called on leaving)
--   screen:resize(w, h)  update(dt)  draw(g)
--   screen:mousepressed(x, y, button)  mousereleased  mousemoved(x, y)
--   screen:wheelmoved(dx, dy)  keypressed(key)  textinput(text)
--   screen:find(id)      the display item with that id, for tests
local TemplateEditorScreen = {}
TemplateEditorScreen.__index = TemplateEditorScreen

local TemplateEditor = require("src.editor.template_editor")
local TemplatePreview = require("src.editor.template_preview")
local TemplateCosts = require("src.data.template_costs")
local UnitTemplate = require("src.data.unit_template")

-- Sizes, in pixels.
local PAD, LINE, ROW, BUTTON = 8, 16, 26, 22

-- Colours, each {r, g, b, a}. Severity and group colours are never the
-- only sign: messages carry a mark and segments a label.
TemplateEditorScreen.COLORS = {
    background = {0.12, 0.10, 0.16, 1},
    panel = {0.18, 0.16, 0.24, 1},
    border = {0.40, 0.38, 0.50, 1},
    text = {0.92, 0.92, 0.95, 1},
    muted = {0.65, 0.65, 0.72, 1},
    button = {0.26, 0.24, 0.34, 1},
    active = {0.45, 0.38, 0.70, 1},
    hover = {0.34, 0.31, 0.46, 1},
    disabled = {0.20, 0.19, 0.24, 1},
    track = {0.10, 0.10, 0.14, 1},
    band = {0.22, 0.34, 0.26, 1},
    fill = {0.55, 0.50, 0.85, 1},
    knob = {0.95, 0.95, 1.00, 1},
    field = {0.08, 0.08, 0.12, 1},
    focus = {0.95, 0.80, 0.35, 1},
    sight = {0.45, 0.75, 0.95, 0.8},
    ability = {0.95, 0.65, 0.35, 0.8},
    tooltip = {0.05, 0.05, 0.08, 0.95},
    budget_line = {1, 1, 1, 1}
}
TemplateEditorScreen.GROUP_COLORS = {
    body = {0.45, 0.45, 0.55, 1},
    stats = {0.35, 0.65, 0.45, 1},
    abilities = {0.65, 0.45, 0.80, 1}
}
TemplateEditorScreen.SEVERITY = {
    error = {mark = "!", color = {1.00, 0.40, 0.40, 1}},
    warning = {mark = "?", color = {1.00, 0.80, 0.35, 1}},
    info = {mark = "i", color = {0.60, 0.80, 1.00, 1}},
    success = {mark = "+", color = {0.50, 0.90, 0.55, 1}}
}
TemplateEditorScreen.TAB_LABELS = {stats = "Stats", abilities = "Abilities", appearance = "Appearance",
    preview = "Preview"}
TemplateEditorScreen.MODE_LABELS = {visual = "Unit", stats = "Numbers", combat = "Battles", comparison = "Changes"}
TemplateEditorScreen.SHAKE_TIME = 0.35
TemplateEditorScreen.STATUS_TIME = 4

-- {{{ local function inside
local function inside(rect, x, y)
    return rect and x >= rect.x and y >= rect.y and x < rect.x + rect.width and y < rect.y + rect.height
end
-- }}}

-- {{{ local function rect
local function rect(x, y, width, height)
    return {x = x, y = y, width = math.max(0, width), height = math.max(0, height)}
end
-- }}}

-- {{{ local function fraction_of
local function fraction_of(value, min, max)
    if max <= min then
        return 0
    end
    return math.max(0, math.min(1, (value - min) / (max - min)))
end
-- }}}

-- {{{ local function number
local function number(value)
    if type(value) ~= "number" then
        return tostring(value)
    end
    if value == math.floor(value) then
        return string.format("%d", value)
    end
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end
-- }}}

-- {{{ TemplateEditorScreen.new
function TemplateEditorScreen.new(options)
    options = options or {}
    local love_table = rawget(_G, "love")
    local screen = {
        editor = options.editor or TemplateEditor:new({storage = options.storage}),
        width = options.width or 1280,
        height = options.height or 720,
        keyboard = options.keyboard or (love_table and love_table.keyboard),
        battles = options.battles or 6,
        on_exit = options.on_exit,
        ui = {
            slot = 1,            -- the ability slot being edited
            query = "",          -- the ability search
            scroll = 0,          -- first library row shown
            focus = nil,         -- the text field being typed in
            buffer = nil,        -- what has been typed there
            drag = nil,          -- the slider being dragged
            mouse = {x = -1, y = -1},
            hover = nil,         -- the item under the pointer
            fixes = false,       -- over-budget suggestions shown
            confirm = nil,       -- an action waiting for a second press
            status = nil, status_severity = "info", status_time = 0,
            shake = 0,
            seen_change = nil,
            simulation = nil, simulation_signature = nil,
            caches = {}
        },
        widgets = nil
    }
    return setmetatable(screen, TemplateEditorScreen)
end
-- }}}

-- {{{ TemplateEditorScreen:resize
function TemplateEditorScreen:resize(width, height)
    self.width, self.height = width, height
    self.widgets = nil
end
-- }}}

-- {{{ TemplateEditorScreen:say
-- A line in the status area for a few seconds.
function TemplateEditorScreen:say(text, severity)
    self.ui.status = text
    self.ui.status_severity = severity or "info"
    self.ui.status_time = TemplateEditorScreen.STATUS_TIME
end
-- }}}

-- {{{ TemplateEditorScreen:report
-- Says a call's note, if it gave one.
function TemplateEditorScreen:report(result, note)
    if result == nil or result == false then
        if type(note) == "table" then
            note = (note.errors and note.errors[1]) or "Not applied"
        end
        self:say(tostring(note or "Not applied"), "error")
    elseif type(note) == "string" then
        self:say(note, "warning")
    end
end
-- }}}

-- {{{ TemplateEditorScreen:cached
-- A value worked out once per template contents.
function TemplateEditorScreen:cached(key, make)
    local signature = self.editor.preview.signature
    local cache = self.ui.caches[key]
    if not cache or cache.signature ~= signature then
        cache = {signature = signature, value = make()}
        self.ui.caches[key] = cache
    end
    return cache.value
end
-- }}}

-- {{{ TemplateEditorScreen:update
function TemplateEditorScreen:update(dt)
    local ui = self.ui
    local change = self.editor.last_change
    if change and change ~= ui.seen_change then
        ui.seen_change = change
        if change.became_over then
            ui.shake = TemplateEditorScreen.SHAKE_TIME
        end
    end
    ui.shake = math.max(0, ui.shake - dt)
    if ui.status_time > 0 then
        ui.status_time = ui.status_time - dt
        if ui.status_time <= 0 then
            ui.status = nil
        end
    end
    self:rebuild()
end
-- }}}

-- {{{ TemplateEditorScreen:rebuild
function TemplateEditorScreen:rebuild()
    self.widgets = self:build()
    return self.widgets
end
-- }}}

-- {{{ TemplateEditorScreen:build
-- The display list for the current state. Items: {kind, id, rect, clip,
-- ...}; see draw() for what each kind carries.
function TemplateEditorScreen:build()
    local editor = self.editor
    editor:analysis()
    local list = {}
    local clip
    local function add(item)
        item.clip = item.clip or clip
        list[#list + 1] = item
        return item
    end
    local layout = TemplateEditor.layout(self.width, self.height)
    local budget_rect = layout.budget
    if self.ui.shake > 0 then
        local offset = math.floor(math.sin(self.ui.shake * 60) * 6 * self.ui.shake / TemplateEditorScreen.SHAKE_TIME)
        budget_rect = rect(budget_rect.x + offset, budget_rect.y, budget_rect.width, budget_rect.height)
    end
    local panels = {
        {"tabs", layout.tabs, nil},
        {"editor", layout.editor, TemplateEditorScreen.TAB_LABELS[editor.tab]},
        {"preview", layout.preview, "Preview: " .. TemplateEditorScreen.MODE_LABELS[editor.preview.mode]},
        {"budget", budget_rect, nil},
        {"buttons", layout.buttons, nil}
    }
    local inner = {}
    for _, panel in ipairs(panels) do
        clip = nil
        add({kind = "panel", id = "panel:" .. panel[1], rect = panel[2], title = panel[3]})
        local top = panel[3] and LINE + PAD or 0
        inner[panel[1]] = rect(panel[2].x + PAD, panel[2].y + PAD + top, panel[2].width - 2 * PAD,
            panel[2].height - 2 * PAD - top)
    end

    clip = layout.tabs
    self:build_tabs(add, rect(layout.tabs.x + PAD / 2, layout.tabs.y + PAD / 2, layout.tabs.width - PAD,
        layout.tabs.height - PAD))
    clip = layout.editor
    if self.ui.fixes then
        self:build_fixes(add, inner.editor)
    else
        local builders = {stats = self.build_stats, abilities = self.build_abilities,
            appearance = self.build_appearance, preview = self.build_preview_controls}
        builders[editor.tab](self, add, inner.editor)
    end
    clip = layout.preview
    self:build_preview_panel(add, inner.preview)
    clip = budget_rect
    self:build_budget(add, rect(budget_rect.x + PAD, budget_rect.y + PAD / 2, budget_rect.width - 2 * PAD,
        budget_rect.height - PAD))
    clip = layout.buttons
    self:build_buttons(add, rect(layout.buttons.x + PAD / 2, layout.buttons.y + PAD / 2, layout.buttons.width - PAD,
        layout.buttons.height - PAD))

    -- The pointer's item, and its tooltip on top of everything.
    clip = nil
    local hovered = self:item_at(list, self.ui.mouse.x, self.ui.mouse.y, true)
    self.ui.hover = hovered and hovered.id
    if hovered then
        hovered.hover = true
        if hovered.tooltip and #hovered.tooltip > 0 then
            local width = math.min(320, self.width - 2 * PAD)
            local height = #hovered.tooltip * LINE + PAD
            local x = math.max(0, math.min(self.ui.mouse.x + 14, self.width - width))
            local y = math.max(0, math.min(self.ui.mouse.y + 18, self.height - height))
            add({kind = "tooltip", id = "tooltip", rect = rect(x, y, width, height), lines = hovered.tooltip})
        end
    end
    return list
end
-- }}}

-- {{{ TemplateEditorScreen:build_tabs
function TemplateEditorScreen:build_tabs(add, area)
    local count = #TemplateEditor.TABS
    local width = (area.width - (count - 1) * PAD) / count
    for index, tab in ipairs(TemplateEditor.TABS) do
        add({kind = "button", id = "tab:" .. tab, rect = rect(area.x + (index - 1) * (width + PAD), area.y, width,
            area.height), text = TemplateEditorScreen.TAB_LABELS[tab], active = self.editor.tab == tab,
            action = function(screen)
                screen.ui.fixes = false
                screen.editor:switch_tab(tab)
            end})
    end
end
-- }}}

-- {{{ TemplateEditorScreen:build_stats
-- Presets, then one row per stat (name, slider with the recommended
-- range shaded, value, minus, plus, points), then the allocator's advice.
function TemplateEditorScreen:build_stats(add, area)
    local editor = self.editor
    local allocator = editor:stats()
    local y = area.y
    local presets = allocator:presets()
    local width = (area.width - (#presets - 1) * 4) / #presets
    for index, preset in ipairs(presets) do
        add({kind = "button", id = "preset:" .. preset.id, rect = rect(area.x + (index - 1) * (width + 4), y, width,
            BUTTON), text = preset.name, tooltip = {preset.description},
            action = function(screen) screen:report(screen.editor:apply_preset(preset.id)) end})
    end
    y = y + BUTTON + PAD
    local label_width, value_width, small = 90, 80, BUTTON
    local slider_width = area.width - label_width - value_width - 2 * small - 60 - 5 * 4
    for _, row in ipairs(allocator:rows()) do
        local x = area.x
        add({kind = "text", id = "stat_label:" .. row.stat, rect = rect(x, y + 4, label_width, LINE), text = row.name,
            tooltip = {row.description}})
        x = x + label_width + 4
        local stat = row.stat
        add({kind = "slider", id = "stat:" .. stat, rect = rect(x, y + 4, slider_width, ROW - 8),
            fraction = row.fraction,
            band = {fraction_of(row.recommended_min or row.min, row.min, row.max),
                fraction_of(row.recommended_max or row.max, row.min, row.max)},
            label = row.name,
            tooltip = {string.format("%s %s (allowed %s-%s, suggested %s-%s)", row.name, number(row.value),
                number(row.min), number(row.max), number(row.recommended_min or row.min),
                number(row.recommended_max or row.max)),
                string.format("The %s body gives %s; can afford up to %s", editor.template.unit_type,
                number(row.base), number(row.affordable_max))},
            change = function(screen, fraction) screen:report(screen.editor:set_stat_fraction(stat, fraction)) end})
        x = x + slider_width + 4
        local bought = row.value - row.base
        add({kind = "text", id = "stat_value:" .. stat, rect = rect(x, y + 4, value_width, LINE),
            text = number(row.value) .. (bought ~= 0 and string.format(" (%+g)", bought) or "")})
        x = x + value_width + 4
        add({kind = "button", id = "stat_down:" .. stat, rect = rect(x, y, small, BUTTON), text = "-",
            tooltip = {string.format("Saves %d points", row.refund)},
            action = function(screen) screen:report(screen.editor:step_stat(stat, -1)) end})
        x = x + small + 4
        add({kind = "button", id = "stat_up:" .. stat, rect = rect(x, y, small, BUTTON), text = "+",
            tooltip = {string.format("Costs %d more points", row.next_cost)},
            action = function(screen) screen:report(screen.editor:step_stat(stat, 1)) end})
        x = x + small + 4
        add({kind = "text", id = "stat_points:" .. stat, rect = rect(x, y + 4, 60, LINE),
            text = string.format("%d pts", row.points), color = "muted"})
        y = y + ROW + 2
    end
    y = y + PAD
    for index, suggestion in ipairs(allocator:suggestions()) do
        self:add_message(add, "stat_advice:" .. index, area.x, y, area.width, suggestion.severity, suggestion.message)
        y = y + LINE + 2
    end
end
-- }}}

-- {{{ TemplateEditorScreen:add_message
-- A line of feedback: its severity's mark, then the text, in its colour.
function TemplateEditorScreen:add_message(add, id, x, y, width, severity, text)
    local look = TemplateEditorScreen.SEVERITY[severity] or TemplateEditorScreen.SEVERITY.info
    return add({kind = "text", id = id, rect = rect(x, y, width, LINE), text = look.mark .. " " .. text,
        color = look.color, tooltip = {text}})
end
-- }}}

-- {{{ TemplateEditorScreen:build_abilities
-- Slots, the chosen slot's tuning sliders, and the library with its
-- search. Side by side when the panel is wide enough, else stacked.
function TemplateEditorScreen:build_abilities(add, area)
    local editor = self.editor
    local ui = self.ui
    local selector = editor:abilities()
    local slots = selector:slots()
    ui.slot = math.max(1, math.min(ui.slot, #editor.template.abilities + 1, #slots))
    local columns = area.width >= 560
    local left = columns and rect(area.x, area.y, math.floor(area.width * 0.48), area.height) or area
    local y = left.y
    for _, slot in ipairs(slots) do
        local text
        if slot.filled then
            text = string.format("%d. %s%s  (%d pts)", slot.index, slot.name, slot.primary and " [primary]" or "",
                slot.cost)
        else
            text = string.format("%d. empty%s", slot.index, slot.primary and " primary" or "")
        end
        add({kind = "button", id = "slot:" .. slot.index, rect = rect(left.x, y, left.width - BUTTON - 4, BUTTON),
            text = text, align = "left", active = ui.slot == slot.index,
            disabled = not slot.filled and slot.index > #editor.template.abilities + 1,
            action = function(screen)
                screen.ui.slot = slot.index
                screen.ui.scroll = 0
            end})
        if slot.filled then
            add({kind = "button", id = "remove:" .. slot.index, rect = rect(left.x + left.width - BUTTON, y, BUTTON,
                BUTTON), text = "x", tooltip = {"Remove " .. slot.name},
                action = function(screen) screen:report(screen.editor:remove_ability(slot.index)) end})
        end
        y = y + BUTTON + 4
    end
    y = y + PAD

    -- Tuning the chosen slot's library ability.
    local entry = editor.template.abilities[ui.slot]
    if entry and entry.template then
        local id = entry.template
        local limits = editor.library:limits(id) or {}
        local library_entry = editor.library:get(id)
        add({kind = "text", id = "tune_title", rect = rect(left.x, y, left.width, LINE),
            text = "Tune " .. (library_entry and library_entry.name or id), color = "muted"})
        y = y + LINE + 4
        local slot_index = ui.slot
        for _, property in ipairs(library_entry and library_entry.customizable or {}) do
            local limit = limits[property]
            if limit then
                local value = (entry.changes and entry.changes[property]) or limit.base
                add({kind = "text", id = "tune_label:" .. property, rect = rect(left.x, y + 4, 90, LINE),
                    text = property:gsub("_", " ")})
                add({kind = "slider", id = "tune:" .. property, rect = rect(left.x + 94, y + 4, left.width - 94 - 64,
                    ROW - 8), fraction = fraction_of(value, limit.min, limit.max), label = property,
                    tooltip = {string.format("%s %s (from %s to %s; the ability's own is %s)", property, number(value),
                        number(limit.min), number(limit.max), number(limit.base))},
                    change = function(screen, fraction)
                        local changes = {}
                        for key, kept in pairs(entry.changes or {}) do
                            changes[key] = kept
                        end
                        changes[property] = math.floor((limit.min + fraction * (limit.max - limit.min)) * 100 + 0.5)
                            / 100
                        screen:report(screen.editor:set_ability(slot_index, id, changes))
                    end})
                add({kind = "text", id = "tune_value:" .. property, rect = rect(left.x + left.width - 60, y + 4, 60,
                    LINE), text = number(value)})
                y = y + ROW
            end
        end
    elseif entry then
        add({kind = "text", id = "tune_title", rect = rect(left.x, y, left.width, LINE),
            text = "A custom ability: its numbers are set in its file", color = "muted"})
        y = y + LINE
    end

    -- The library.
    local right = columns and rect(area.x + left.width + PAD, area.y, area.width - left.width - PAD, area.height)
        or rect(area.x, y + PAD, area.width, area.y + area.height - y - PAD)
    y = right.y
    add({kind = "field", id = "search", rect = rect(right.x, y, right.width, BUTTON),
        text = ui.focus == "search" and ui.buffer or ui.query, placeholder = "Search abilities",
        focused = ui.focus == "search"})
    y = y + BUTTON + 4
    local primary = ui.slot == 1
    local results = editor.library:search(ui.query, {primary_only = primary})
    ui.scroll = math.max(0, math.min(ui.scroll, #results - 1))
    -- Room for the rows, keeping a line for the count below them.
    local rows = math.max(1, math.floor((right.y + right.height - y - LINE) / (BUTTON + 2)))
    for index = ui.scroll + 1, math.min(#results, ui.scroll + rows) do
        local found = results[index]
        local slot_index = ui.slot
        add({kind = "button", id = "library:" .. found.id, rect = rect(right.x, y, right.width, BUTTON),
            text = string.format("%s  [%s]  %d pts", found.name, found.subcategory or found.category,
                editor.library:cost(found.id, nil, primary)), align = "left",
            active = entry ~= nil and entry.template == found.id,
            tooltip = {found.description},
            action = function(screen) screen:report(screen.editor:set_ability(slot_index, found.id)) end})
        y = y + BUTTON + 2
    end
    if #results > rows then
        add({kind = "text", id = "library_more", rect = rect(right.x, y, right.width, LINE), color = "muted",
            text = string.format("%d-%d of %d (scroll for more)", ui.scroll + 1, math.min(#results, ui.scroll + rows),
                #results)})
    elseif #results == 0 then
        add({kind = "text", id = "library_more", rect = rect(right.x, y, right.width, LINE), color = "muted",
            text = "No ability matches"})
    end
    self.library_rect = right
end
-- }}}

-- {{{ TemplateEditorScreen:build_appearance
-- Name, description, body, two colours and size.
function TemplateEditorScreen:build_appearance(add, area)
    local editor = self.editor
    local template = editor.template
    local ui = self.ui
    local y = area.y
    for _, field in ipairs({{"name", "Name"}, {"description", "Description"}}) do
        local key = field[1]
        add({kind = "text", id = "label:" .. key, rect = rect(area.x, y + 4, 90, LINE), text = field[2]})
        add({kind = "field", id = key, rect = rect(area.x + 94, y, area.width - 94, BUTTON),
            text = ui.focus == key and ui.buffer or (template[key] or ""), focused = ui.focus == key,
            placeholder = field[2]})
        y = y + BUTTON + 6
    end
    add({kind = "text", id = "label:body", rect = rect(area.x, y + 4, 90, LINE), text = "Body"})
    local bodies = {}
    for body in pairs(TemplateCosts.bodies) do
        table.insert(bodies, body)
    end
    table.sort(bodies)
    local width = (area.width - 94 - (#bodies - 1) * 4) / #bodies
    for index, body in ipairs(bodies) do
        add({kind = "button", id = "body:" .. body, rect = rect(area.x + 94 + (index - 1) * (width + 4), y, width,
            BUTTON), text = body, active = template.unit_type == body,
            tooltip = {string.format("%s body: %d points; stats go back to its own", body,
                TemplateCosts.bodies[body].cost)},
            action = function(screen) screen:report(screen.editor:set_unit_type(body)) end})
    end
    y = y + BUTTON + PAD
    for _, which in ipairs({"primary", "secondary"}) do
        local color = template.appearance[which .. "_color"] or {1, 1, 1}
        add({kind = "text", id = "label:" .. which, rect = rect(area.x, y + 4, 90, LINE),
            text = which == "primary" and "Main colour" or "Edge colour"})
        add({kind = "swatch", id = "swatch:" .. which, rect = rect(area.x + 94, y, BUTTON * 2, BUTTON), color = color})
        local slider_x = area.x + 94 + BUTTON * 2 + PAD
        local slider_width = (area.width - (slider_x - area.x) - 2 * 4) / 3
        for part, name in ipairs({"red", "green", "blue"}) do
            add({kind = "slider", id = "color:" .. which .. ":" .. name, rect = rect(slider_x + (part - 1) *
                (slider_width + 4), y + 4, slider_width, ROW - 8), fraction = color[part] or 0, label = name,
                tooltip = {string.format("%s %d%%", name, math.floor((color[part] or 0) * 100 + 0.5))},
                change = function(screen, fraction)
                    local parts = {color[1], color[2], color[3]}
                    parts[part] = math.floor(fraction * 100 + 0.5) / 100
                    screen:report(screen.editor:set_color(which, parts[1], parts[2], parts[3]))
                end})
        end
        y = y + ROW + 4
    end
    local limits = TemplateEditor.SIZE_LIMITS
    local size = template.appearance.size_modifier or 1
    add({kind = "text", id = "label:size", rect = rect(area.x, y + 4, 90, LINE), text = "Size"})
    add({kind = "slider", id = "size", rect = rect(area.x + 94, y + 4, area.width - 94 - 64, ROW - 8),
        fraction = fraction_of(size, limits.min, limits.max), label = "size",
        tooltip = {string.format("Drawn at %s%% (from %s%% to %s%%)", number(math.floor(size * 100 + 0.5)),
            number(math.floor(limits.min * 100 + 0.5)), number(math.floor(limits.max * 100 + 0.5)))},
        change = function(screen, fraction)
            local value = limits.min + fraction * (limits.max - limits.min)
            screen:report(screen.editor:set_size(math.floor(value * 20 + 0.5) / 20))
        end})
    add({kind = "text", id = "size_value", rect = rect(area.x + area.width - 60, y + 4, 60, LINE),
        text = string.format("%d%%", math.floor(size * 100 + 0.5))})
end
-- }}}

-- {{{ TemplateEditorScreen:build_preview_controls
-- The preview tab's own panel: mode, zoom, overlays and battles.
function TemplateEditorScreen:build_preview_controls(add, area)
    local preview = self.editor.preview
    local y = area.y
    local modes = TemplatePreview.MODES
    local width = (area.width - (#modes - 1) * 4) / #modes
    for index, mode in ipairs(modes) do
        add({kind = "button", id = "mode:" .. mode, rect = rect(area.x + (index - 1) * (width + 4), y, width, BUTTON),
            text = TemplateEditorScreen.MODE_LABELS[mode], active = preview.mode == mode,
            action = function(screen) screen.editor.preview:set_mode(mode) end})
    end
    y = y + BUTTON + PAD
    add({kind = "button", id = "zoom_out", rect = rect(area.x, y, BUTTON * 2, BUTTON), text = "-",
        action = function(screen) screen.editor.preview:zoom_by(-1) end})
    add({kind = "text", id = "zoom", rect = rect(area.x + BUTTON * 2 + 4, y + 4, 80, LINE),
        text = string.format("zoom %d%%", math.floor(preview.zoom * 100 + 0.5)), align = "center"})
    add({kind = "button", id = "zoom_in", rect = rect(area.x + BUTTON * 2 + 88, y, BUTTON * 2, BUTTON), text = "+",
        action = function(screen) screen.editor.preview:zoom_by(1) end})
    y = y + BUTTON + PAD
    local overlays = TemplatePreview.OVERLAYS
    width = (area.width - (#overlays - 1) * 4) / #overlays
    for index, overlay in ipairs(overlays) do
        add({kind = "button", id = "overlay:" .. overlay, rect = rect(area.x + (index - 1) * (width + 4), y, width,
            BUTTON), text = (preview.overlays[overlay] and "[x] " or "[ ] ") .. overlay,
            active = preview.overlays[overlay],
            action = function(screen) screen.editor.preview:toggle(overlay) end})
    end
    y = y + BUTTON + PAD
    add({kind = "button", id = "run_battles", rect = rect(area.x, y, math.min(area.width, 200), BUTTON),
        text = "Run battles",
        tooltip = {string.format("%d headless battles against each starter body", self.battles)},
        action = function(screen) screen:run_battles() end})
    y = y + BUTTON + PAD
    add({kind = "text", id = "preview_note", rect = rect(area.x, y, area.width, LINE * 3), color = "muted",
        text = "Numbers shows the analysis; Changes compares with the last save. Battles walk units straight at "
            .. "each other, so they compare templates rather than predict matches."})
end
-- }}}

-- {{{ TemplateEditorScreen:run_battles
function TemplateEditorScreen:run_battles()
    local editor = self.editor
    self.ui.simulation = editor.preview:simulation(editor.template, {battles = self.battles})
    self.ui.simulation_signature = editor.preview.signature
    self.editor.preview:set_mode("combat")
    self:say("Battles run", "info")
end
-- }}}

-- {{{ TemplateEditorScreen:build_preview_panel
-- What the preview panel shows in each mode.
function TemplateEditorScreen:build_preview_panel(add, area)
    local editor = self.editor
    local preview = editor.preview
    local analysis = editor:analysis()
    local lines = {}
    local function line(text, color)
        table.insert(lines, {text = text, color = color})
    end
    if preview.mode == "visual" then
        local shapes = preview:overlay_shapes(editor.template)
        local cx, cy = area.x + area.width / 2, area.y + area.height / 2
        for index, circle in ipairs(shapes.circles) do
            add({kind = "circle", id = "circle:" .. index, x = cx, y = cy, radius = circle.radius,
                color = circle.kind == "sight" and "sight" or "ability", label = circle.label,
                label_y = cy - circle.radius - LINE})
        end
        add({kind = "unit", id = "unit", x = cx, y = cy, size = shapes.unit.size, shape = shapes.unit.shape,
            primary = shapes.unit.primary_color, secondary = shapes.unit.secondary_color,
            tooltip = {editor.template.name, editor.template.unit_type .. " body"}})
        if preview.overlays.stats then
            local survival = analysis.survival
            line(string.format("Health %s  Armor %s  Resist %s", number(survival.health), number(survival.armor),
                number(survival.magic_resist)))
            line(string.format("Speed %s  Sight %s", number(analysis.mobility.speed), number(analysis.mobility.sight)))
        end
        if preview.overlays.mana then
            for _, ability in ipairs(analysis.abilities) do
                line(string.format("%s: full mana in %.1fs", ability.name, ability.charge_time), "muted")
            end
        end
    elseif preview.mode == "stats" then
        local survival, offense = analysis.survival, analysis.offense
        line(string.format("Lasts %.0f physical / %.0f magical damage", survival.effective_health_physical,
            survival.effective_health_magical))
        line(string.format("Damage %.1f/s, burst %.0f, reach %s", offense.damage_per_second, offense.burst,
            number(offense.reach)))
        if offense.healing_per_second > 0 then
            line(string.format("Healing %.1f/s", offense.healing_per_second))
        end
        line(string.format("Speed %s, sight %s", number(analysis.mobility.speed), number(analysis.mobility.sight)))
        if analysis.support.buffs + analysis.support.debuffs > 0 then
            line(string.format("%d buffs, %d debuffs", analysis.support.buffs, analysis.support.debuffs))
        end
        for _, ability in ipairs(analysis.abilities) do
            local amount = ability.per_second and string.format("%.1f/s", ability.per_second)
                or string.format("%.0f%% uptime", (ability.uptime or 0) * 100)
            line(string.format("%d. %s (%s): every %.1fs, %s%s", ability.index, ability.name, ability.kind,
                ability.cycle, amount, ability.conditional and ", waits on a trigger" or ""), "muted")
        end
    elseif preview.mode == "combat" then
        local simulation = self.ui.simulation_signature == preview.signature and self.ui.simulation
        if simulation then
            line(string.format("Overall %.0f%% (%.0f-%.0f%%) over %d battles", simulation.overall.win_rate * 100,
                simulation.overall.low * 100, simulation.overall.high * 100, simulation.overall.battles))
            for _, row in ipairs(simulation.rows) do
                line(string.format("vs %s (%s): %.0f%%  %d-%d-%d", row.opponent, row.body, row.win_rate * 100,
                    row.wins, row.losses, row.draws))
            end
            line(simulation.note, "muted")
        else
            line("Press Run battles on the Preview tab to try this template.", "muted")
        end
    else
        local comparison = self:cached("comparison", function()
            return TemplatePreview.compare(UnitTemplate.new(editor.saved_data), editor.template)
        end)
        if #comparison.lines == 0 then
            line("No changes since the last save.", "muted")
        end
        for _, text in ipairs(comparison.lines) do
            line(text)
        end
    end
    local y = area.y
    for index, entry in ipairs(lines) do
        add({kind = "text", id = "preview_line:" .. index, rect = rect(area.x, y, area.width, LINE),
            text = entry.text, color = entry.color})
        y = y + LINE + 2
    end
end
-- }}}

-- {{{ TemplateEditorScreen:build_budget
-- The bar (a segment per part, the budget marked), the status and the
-- first findings, with a count of the rest.
function TemplateEditorScreen:build_budget(add, area)
    local budget = self.editor:budget()
    local bar = rect(area.x, area.y, area.width, 14)
    add({kind = "bar", id = "budget_bar", rect = bar})
    for _, segment in ipairs(budget.segments) do
        local start = segment.start * budget.budget / budget.scale
        local width = segment.points / budget.scale
        add({kind = "segment", id = "segment:" .. segment.key, rect = rect(bar.x + start * bar.width, bar.y,
            width * bar.width, bar.height), group = segment.group, label = segment.label, tooltip = segment.tooltip})
    end
    add({kind = "marker", id = "budget_line", x = bar.x + budget.budget / budget.scale * bar.width, y = bar.y - 2,
        height = bar.height + 4})
    local y = bar.y + bar.height + 4
    local half = math.floor(area.width / 2)
    self:add_message(add, "budget_status", area.x, y, half, budget.severity,
        string.format("%d / %d points: %s", budget.used, budget.budget, budget.message))
    local shown = 0
    for index = 2, #budget.messages do
        local message = budget.messages[index]
        if shown < 1 then
            self:add_message(add, "finding:" .. index, area.x + half, y, area.width - half, message.severity,
                message.text)
        end
        shown = shown + 1
    end
    if shown > 1 then
        local lines = {}
        for index = 2, #budget.messages do
            local look = TemplateEditorScreen.SEVERITY[budget.messages[index].severity]
            table.insert(lines, (look and look.mark or "-") .. " " .. budget.messages[index].text)
        end
        add({kind = "text", id = "findings_more", rect = rect(area.x + half, y + LINE + 2, area.width - half, LINE),
            text = string.format("and %d more (point here)", shown - 1), color = "muted", tooltip = lines})
    end
end
-- }}}

-- {{{ TemplateEditorScreen:build_fixes
-- Ways back under budget, from the optimizer.
function TemplateEditorScreen:build_fixes(add, area)
    local editor = self.editor
    local suggestions = self:cached("fixes", function() return editor:optimize() end)
    local y = area.y
    add({kind = "text", id = "fixes_title", rect = rect(area.x, y, area.width - 80, LINE),
        text = #suggestions > 0 and "Ways back under budget:" or "Nothing to fix: the template is within budget."})
    add({kind = "button", id = "fixes_close", rect = rect(area.x + area.width - 76, y - 4, 76, BUTTON), text = "Close",
        action = function(screen) screen.ui.fixes = false end})
    y = y + LINE + PAD
    for index, suggestion in ipairs(suggestions) do
        local notes = {string.format("Saves %d points, leaving %d used", suggestion.saves, suggestion.points_after)}
        for _, warning in ipairs(suggestion.new_warnings) do
            table.insert(notes, "? " .. warning)
        end
        add({kind = "button", id = "fix:" .. index, rect = rect(area.x, y, area.width, BUTTON), align = "left",
            text = string.format("%s (saves %d)%s%s", suggestion.description, suggestion.saves,
                suggestion.fits and "" or ", not enough alone",
                #suggestion.new_warnings > 0 and string.format(", %d new warnings", #suggestion.new_warnings) or ""),
            tooltip = notes,
            action = function(screen)
                screen:report(screen.editor:apply_suggestion(suggestion))
                screen.ui.fixes = false
            end})
        y = y + BUTTON + 4
    end
end
-- }}}

-- {{{ TemplateEditorScreen:build_buttons
function TemplateEditorScreen:build_buttons(add, area)
    local editor = self.editor
    local ui = self.ui
    local buttons = {
        {"save", "Save", function(screen)
            local ok, result = screen.editor:save()
            screen:say(ok and ("Saved to " .. tostring(result)) or ("Not saved: " .. tostring(result)),
                ok and "success" or "error")
        end},
        {"undo", "Undo", function(screen)
            local label = screen.editor:undo()
            screen:say(label and ("Undid " .. label) or "Nothing to undo", "info")
        end, #editor.undo_stack == 0},
        {"redo", "Redo", function(screen)
            local label = screen.editor:redo()
            screen:say(label and ("Redid " .. label) or "Nothing to redo", "info")
        end, #editor.redo_stack == 0},
        {"revert", "Revert", function(screen)
            screen:say(screen.editor:revert() and "Back to the last save" or "No changes since the last save", "info")
        end, not editor:is_dirty()},
        {"new", ui.confirm == "new" and "Drop changes?" or "New", function(screen)
            screen:confirmed("new", function(force)
                return screen.editor:new_template(screen.editor.template.unit_type, force)
            end)
        end},
        {"fixes", "Fix budget", function(screen) screen.ui.fixes = not screen.ui.fixes end,
            editor.template.points_used <= editor.template.point_budget},
        {"back", ui.confirm == "back" and "Leave anyway?" or "Back", function(screen) screen:leave() end}
    }
    local width = math.min(110, (area.width * 0.7 - (#buttons - 1) * 4) / #buttons)
    for index, button in ipairs(buttons) do
        add({kind = "button", id = "button:" .. button[1], rect = rect(area.x + (index - 1) * (width + 4), area.y,
            width, area.height), text = button[2], disabled = button[4], action = button[3],
            keeps_confirm = button[1] == ui.confirm})
    end
    local x = area.x + #buttons * (width + 4) + PAD
    local name = editor.template.name .. (editor:is_dirty() and " *" or "")
    add({kind = "text", id = "template_name", rect = rect(x, area.y, area.x + area.width - x, LINE), text = name,
        tooltip = editor:is_dirty() and {"Unsaved changes"} or nil})
    if ui.status then
        local look = TemplateEditorScreen.SEVERITY[ui.status_severity] or TemplateEditorScreen.SEVERITY.info
        add({kind = "text", id = "status", rect = rect(x, area.y + LINE, area.x + area.width - x, LINE),
            text = ui.status, color = look.color, tooltip = {ui.status}})
    end
end
-- }}}

-- {{{ TemplateEditorScreen:confirmed
-- Runs a call that the editor refuses while there are unsaved changes:
-- the first press asks, a second press forces it.
function TemplateEditorScreen:confirmed(name, call)
    local force = self.ui.confirm == name
    local result, note = call(force)
    if result then
        self.ui.confirm = nil
        return result
    end
    self.ui.confirm = name
    self:say(tostring(note) .. " (press again)", "warning")
    return nil
end
-- }}}

-- {{{ TemplateEditorScreen:leave
function TemplateEditorScreen:leave()
    return self:confirmed("back", function(force)
        local ok, note = self.editor:can_exit(force)
        if ok and self.on_exit then
            self.on_exit(self)
        end
        return ok, note
    end)
end
-- }}}

-- {{{ TemplateEditorScreen:item_at
-- The topmost item at a point, inside its panel; with `any`, items with
-- a tooltip count too, otherwise only ones that act.
function TemplateEditorScreen:item_at(list, x, y, any)
    for index = #list, 1, -1 do
        local item = list[index]
        local acts = item.action or item.change or item.kind == "field"
        if (acts or (any and item.tooltip)) and item.rect and inside(item.rect, x, y)
            and (not item.clip or inside(item.clip, x, y)) and not item.disabled then
            return item
        end
    end
    return nil
end
-- }}}

-- {{{ TemplateEditorScreen:find
function TemplateEditorScreen:find(id)
    for _, item in ipairs(self.widgets or self:rebuild()) do
        if item.id == id then
            return item
        end
    end
    return nil
end
-- }}}

-- {{{ local function slider_fraction
local function slider_fraction(item, x)
    return fraction_of(x, item.rect.x, item.rect.x + item.rect.width)
end
-- }}}

-- {{{ TemplateEditorScreen:commit_field
-- Hands what was typed to the editor (search filters as it is typed).
function TemplateEditorScreen:commit_field()
    local ui = self.ui
    local focus, text = ui.focus, ui.buffer
    ui.focus, ui.buffer = nil, nil
    if focus == "name" then
        if text:match("%S") then
            self:report(self.editor:set_name(text))
        else
            self:say("A name can't be empty", "error")
        end
    elseif focus == "description" then
        self:report(self.editor:set_description(text))
    end
end
-- }}}

-- {{{ TemplateEditorScreen:mousepressed
function TemplateEditorScreen:mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end
    self.ui.mouse = {x = x, y = y}
    local item = self:item_at(self.widgets or self:rebuild(), x, y)
    if self.ui.focus and (not item or item.id ~= self.ui.focus) then
        self:commit_field()
    end
    if not item then
        self:rebuild()
        return false
    end
    if not item.keeps_confirm then
        self.ui.confirm = nil
    end
    if item.kind == "field" then
        if self.ui.focus == item.id then
            self:rebuild()
            return true
        end
        self.ui.focus = item.id
        self.ui.buffer = item.id == "search" and self.ui.query or (self.editor.template[item.id] or "")
    elseif item.change then
        self.ui.drag = item.id
        self.editor:begin_group("drag " .. (item.label or item.id))
        item.change(self, slider_fraction(item, x))
    elseif item.action then
        item.action(self)
    end
    self:rebuild()
    return true
end
-- }}}

-- {{{ TemplateEditorScreen:mousemoved
function TemplateEditorScreen:mousemoved(x, y)
    self.ui.mouse = {x = x, y = y}
    if self.ui.drag then
        local item = self:find(self.ui.drag)
        if item and item.change then
            item.change(self, slider_fraction(item, x))
        end
    end
    self:rebuild()
    return self.ui.drag ~= nil
end
-- }}}

-- {{{ TemplateEditorScreen:mousereleased
function TemplateEditorScreen:mousereleased(x, y, button)
    if button ~= 1 or not self.ui.drag then
        return false
    end
    self:mousemoved(x, y)
    self.ui.drag = nil
    self.editor:end_group()
    self:rebuild()
    return true
end
-- }}}

-- {{{ TemplateEditorScreen:wheelmoved
-- Over the preview's unit: zoom. Over the ability library: scroll.
function TemplateEditorScreen:wheelmoved(dx, dy)
    local mouse = self.ui.mouse
    local layout = TemplateEditor.layout(self.width, self.height)
    if dy == 0 then
        return false
    end
    if inside(layout.preview, mouse.x, mouse.y) and self.editor.preview.mode == "visual" then
        self.editor.preview:zoom_by(dy > 0 and 1 or -1)
    elseif self.editor.tab == "abilities" and inside(self.library_rect, mouse.x, mouse.y) then
        self.ui.scroll = math.max(0, self.ui.scroll - (dy > 0 and 1 or -1))
    else
        return false
    end
    self:rebuild()
    return true
end
-- }}}

-- {{{ local function held
local function held(keyboard, ...)
    return keyboard and keyboard.isDown and keyboard.isDown(...) or false
end
-- }}}

-- {{{ TemplateEditorScreen:keypressed
-- Typing in a field: backspace, enter (keep), escape (drop). Otherwise
-- tab and shift-tab change tab, ctrl-z / ctrl-y (or ctrl-shift-z) undo
-- and redo, ctrl-s saves, escape leaves. Returns true when used.
function TemplateEditorScreen:keypressed(key)
    local ui = self.ui
    local used = true
    if ui.focus then
        if key == "backspace" then
            ui.buffer = ui.buffer:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
            if ui.focus == "search" then
                ui.query, ui.scroll = ui.buffer, 0
            end
        elseif key == "return" or key == "kpenter" then
            self:commit_field()
        elseif key == "escape" then
            if ui.focus == "search" then
                ui.query = ""
            end
            ui.focus, ui.buffer = nil, nil
        end
        self:rebuild()
        return true
    end
    local ctrl = held(self.keyboard, "lctrl", "rctrl", "lgui", "rgui")
    local shift = held(self.keyboard, "lshift", "rshift")
    if key == "tab" then
        self.ui.fixes = false
        self.editor:next_tab(shift and -1 or 1)
    elseif ctrl and (key == "y" or (key == "z" and shift)) then
        local label = self.editor:redo()
        self:say(label and ("Redid " .. label) or "Nothing to redo", "info")
    elseif ctrl and key == "z" then
        local label = self.editor:undo()
        self:say(label and ("Undid " .. label) or "Nothing to undo", "info")
    elseif ctrl and key == "s" then
        self:find("button:save").action(self)
    elseif key == "escape" then
        if ui.fixes then
            ui.fixes = false
        else
            self:leave()
        end
    else
        used = false
    end
    self:rebuild()
    return used
end
-- }}}

-- {{{ TemplateEditorScreen:textinput
function TemplateEditorScreen:textinput(text)
    local ui = self.ui
    if not ui.focus then
        return false
    end
    ui.buffer = ui.buffer .. text
    if ui.focus == "search" then
        ui.query, ui.scroll = ui.buffer, 0
    end
    self:rebuild()
    return true
end
-- }}}

-- {{{ Drawing
-- One function per kind of item; each only draws what the item holds.
local COLORS = TemplateEditorScreen.COLORS
local DRAW = {}

-- {{{ local function color
local function color(g, value)
    if type(value) == "string" then
        value = COLORS[value]
    end
    value = value or COLORS.text
    g.setColor(value[1], value[2], value[3], value[4] or 1)
end
-- }}}

-- {{{ DRAW.panel
function DRAW.panel(g, item)
    local r = item.rect
    color(g, "panel")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
    if item.title then
        color(g, "muted")
        g.printf(item.title, r.x + PAD, r.y + PAD / 2, math.max(1, r.width - 2 * PAD), "left")
    end
end
-- }}}

-- {{{ DRAW.button
function DRAW.button(g, item)
    local r = item.rect
    color(g, item.disabled and "disabled" or item.active and "active" or item.hover and "hover" or "button")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, item.active and "focus" or "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
    color(g, item.disabled and "muted" or "text")
    g.printf(item.text or "", r.x + 4, r.y + math.max(0, (r.height - LINE) / 2), math.max(1, r.width - 8),
        item.align or "center")
end
-- }}}

-- {{{ DRAW.slider
function DRAW.slider(g, item)
    local r = item.rect
    color(g, "track")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    if item.band then
        color(g, "band")
        g.rectangle("fill", r.x + item.band[1] * r.width, r.y, (item.band[2] - item.band[1]) * r.width, r.height)
    end
    color(g, "fill")
    g.rectangle("fill", r.x, r.y + r.height / 3, item.fraction * r.width, r.height / 3)
    color(g, item.hover and "focus" or "knob")
    g.rectangle("fill", r.x + item.fraction * r.width - 3, r.y - 2, 6, r.height + 4)
    color(g, "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
end
-- }}}

-- {{{ DRAW.text
function DRAW.text(g, item)
    local r = item.rect
    color(g, item.color or "text")
    g.printf(item.text or "", r.x, r.y, math.max(1, r.width), item.align or "left")
end
-- }}}

-- {{{ DRAW.field
function DRAW.field(g, item)
    local r = item.rect
    color(g, "field")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, item.focused and "focus" or "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
    local empty = (item.text or "") == ""
    color(g, empty and "muted" or "text")
    g.printf((empty and not item.focused and item.placeholder or item.text or "") .. (item.focused and "|" or ""),
        r.x + 4, r.y + math.max(0, (r.height - LINE) / 2), math.max(1, r.width - 8), "left")
end
-- }}}

-- {{{ DRAW.swatch
function DRAW.swatch(g, item)
    local r = item.rect
    color(g, item.color)
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
end
-- }}}

-- {{{ DRAW.bar
function DRAW.bar(g, item)
    local r = item.rect
    color(g, "track")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
end
-- }}}

-- {{{ DRAW.segment
function DRAW.segment(g, item)
    local r = item.rect
    color(g, TemplateEditorScreen.GROUP_COLORS[item.group])
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, item.hover and "focus" or "track")
    g.rectangle("line", r.x, r.y, r.width, r.height)
end
-- }}}

-- {{{ DRAW.marker
function DRAW.marker(g, item)
    color(g, "budget_line")
    g.line(item.x, item.y, item.x, item.y + item.height)
end
-- }}}

-- {{{ DRAW.circle
function DRAW.circle(g, item)
    color(g, item.color)
    g.circle("line", item.x, item.y, item.radius)
    if item.label then
        g.printf(item.label, item.x - 100, item.label_y, 200, "center")
    end
end
-- }}}

-- {{{ DRAW.unit
-- The unit's shape filled with its main colour, edged with the other.
function DRAW.unit(g, item)
    local half = item.size / 2
    for _, pass in ipairs({{"fill", item.primary}, {"line", item.secondary}}) do
        color(g, pass[2] or COLORS.text)
        if item.shape == "triangle" then
            g.polygon(pass[1], item.x, item.y - half, item.x + half, item.y + half, item.x - half, item.y + half)
        elseif item.shape == "rectangle" or item.shape == "square" then
            g.rectangle(pass[1], item.x - half, item.y - half, item.size, item.size)
        else
            g.circle(pass[1], item.x, item.y, half)
        end
    end
end
-- }}}

-- {{{ DRAW.tooltip
function DRAW.tooltip(g, item)
    local r = item.rect
    color(g, "tooltip")
    g.rectangle("fill", r.x, r.y, r.width, r.height)
    color(g, "border")
    g.rectangle("line", r.x, r.y, r.width, r.height)
    color(g, "text")
    for index, text in ipairs(item.lines) do
        g.printf(text, r.x + 4, r.y + 4 + (index - 1) * LINE, math.max(1, r.width - 8), "left")
    end
end
-- }}}

TemplateEditorScreen.DRAW = DRAW
-- }}}

-- {{{ TemplateEditorScreen:draw
-- Draws the display list, each item clipped to its panel.
function TemplateEditorScreen:draw(g)
    local list = self.widgets or self:rebuild()
    color(g, "background")
    g.rectangle("fill", 0, 0, self.width, self.height)
    local clip
    for _, item in ipairs(list) do
        if item.clip ~= clip then
            clip = item.clip
            if clip then
                g.setScissor(clip.x, clip.y, math.max(0, clip.width), math.max(0, clip.height))
            else
                g.setScissor()
            end
        end
        DRAW[item.kind](g, item)
    end
    g.setScissor()
    g.setColor(1, 1, 1, 1)
end
-- }}}

return TemplateEditorScreen
-- }}}
