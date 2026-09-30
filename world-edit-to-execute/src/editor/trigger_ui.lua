--[[
The Trigger Editor's Panel (Issue 905)

Opened from the toolbar ("Triggers"), over the whole view:

  left     the editor's triggers (+ Trigger), the variables (+ Variable),
           the map's own triggers (paged)
  right    for one of the editor's triggers: its name (click to rename),
           On / Off, Code (the JASS it becomes, read only), Delete; its
           events, conditions and actions as a tree, each line with move
           up, move down and remove, "+ Event", "+ Condition", "+ Action"
           (and "+" in each part of an if / then / else or a loop) opening
           a list of block kinds; the chosen block's parameters below,
           each changed by - / +, by cycling through its choices, or by
           clicking it and typing (Enter keeps, Esc drops)
           for a variable: name, type, initial value, array, Delete
           for one of the map's triggers: its variable, the function that
           makes it, its events, its condition and action functions (each
           opens in the code view to edit; Apply keeps the edit) and
           Switch off / on
  code     the code view (editor/textedit.lua) in place of the tree

    local tui = require("editor.trigger_ui").new(E, w, h)
    tui:update(input)      -- input: mx, my, lp, keys, chars, wheel, ctrl
    tui:draw(render)
]]

local blocks = require("editor.trigger_blocks")
local textedit = require("editor.textedit")

local trigger_ui = {}
trigger_ui.MAP_PAGE = 14
trigger_ui.LEFT = 300

local TUI = {}
TUI.__index = TUI

local C = {
    panel = { 22, 24, 30 }, edge = { 70, 74, 86 }, button = { 44, 48, 58 }, active = { 90, 120, 60 },
    text = { 225, 225, 215 }, dim = { 140, 140, 130 }, gold = { 240, 200, 90 }, head = { 130, 170, 230 },
    warn = { 240, 120, 90 }, off = { 120, 110, 100 },
}

function trigger_ui.new(E, w, h)
    local self = setmetatable({ E = E, w = w, h = h, map_page = 0, sel = nil, block = nil }, TUI)
    self:layout()
    return self
end

-- {{{ layout
local function short(s, n)
    s = tostring(s)
    if #s > n then return s:sub(1, n - 2) .. ".." end
    return s
end

function TUI:layout()
    local E = self.E
    local b = {}
    self.buttons = b
    local function add(x, y, w, label, action, arg, active, colour)
        local btn = { x = x, y = y, w = w, h = 22, label = label, action = action, arg = arg, active = active, colour = colour }
        b[#b + 1] = btn
        return btn
    end
    self.labels = {}
    local function label(x, y, s, c) self.labels[#self.labels + 1] = { x = x, y = y, s = s, c = c or C.text } end
    -- {{{ the lists on the left
    local x, y = 8, 46
    add(x, y, 136, "+ Trigger", "new_trigger"); add(x + 144, y, 136, "+ Variable", "new_variable")
    y = y + 32
    label(x, y, "Triggers", C.head); y = y + 22
    for _, t in ipairs(E:triggers()) do
        add(x, y, 280, short(t.name, 34), "pick", { "trigger", t }, self.sel and self.sel[2] == t,
            t.on == false and C.off or nil)
        y = y + 24
    end
    y = y + 6
    label(x, y, "Variables", C.head); y = y + 22
    for _, v in ipairs(E:variables()) do
        add(x, y, 280, short(v.name .. " : " .. v.type .. (v.array and "[]" or ""), 34), "pick", { "variable", v },
            self.sel and self.sel[2] == v)
        y = y + 24
    end
    y = y + 6
    local mts = E:map_triggers()
    local pages = math.max(1, math.ceil(#mts / trigger_ui.MAP_PAGE))
    self.map_page = math.max(0, math.min(self.map_page, pages - 1))
    label(x, y, string.format("The map's triggers (%d)", #mts), C.head)
    add(x + 200, y - 2, 36, "<", "map_page", -1); add(x + 244, y - 2, 36, ">", "map_page", 1)
    y = y + 24
    for k = 1, trigger_ui.MAP_PAGE do
        local mt = mts[self.map_page * trigger_ui.MAP_PAGE + k]
        if not mt then break end
        add(x, y, 280, short(mt.name, 34), "pick", { "map", mt }, self.sel and self.sel[2] == mt,
            E.map_trigger_off[mt] and C.off or nil)
        y = y + 24
    end
    -- }}}
    local rx, ry = trigger_ui.LEFT + 8, 46
    local rw = self.w - rx - 8
    self.right = { x = rx, y = ry, w = rw }
    if self.code then
        add(rx, ry, 90, "Close", "close_code")
        if not self.code.readonly then add(rx + 98, ry, 90, "Apply", "apply_code") end
        label(rx + 200, ry + 4, self.code.title, C.gold)
        self.code_box = { x = rx, y = ry + 30, w = rw, h = self.h - ry - 30 - 36, size = 14 }
        return b
    end
    if not self.sel then
        label(rx, ry, "Pick a trigger or a variable on the left, or make one.", C.dim)
        return b
    end
    local kind, obj = self.sel[1], self.sel[2]
    if kind == "trigger" then self:layout_trigger(obj, add, label, rx, ry, rw)
    elseif kind == "variable" then self:layout_variable(obj, add, label, rx, ry, rw)
    elseif kind == "map" then self:layout_map(obj, add, label, rx, ry, rw) end
    return b
end

function TUI:layout_trigger(t, add, label, rx, ry, rw)
    local E = self.E
    local field = self.field
    local editing_name = field and field.target == "trigger_name"
    add(rx, ry, 300, editing_name and (field.buf .. "_") or t.name, "edit_name", nil, editing_name)
    add(rx + 308, ry, 70, t.on == false and "Off" or "On", "toggle_on", t, t.on ~= false)
    add(rx + 386, ry, 70, "Code", "show_code", t)
    add(rx + 464, ry, 70, "Delete", "delete_trigger", t)
    local y = ry + 32
    -- the chooser in place of the tree
    if self.chooser then
        local ch = self.chooser
        label(rx, y, "Add to " .. ch.section:gsub("_", " ") .. ":", C.head)
        add(rx + 400, y - 2, 80, "Cancel", "cancel_chooser")
        y = y + 26
        local col = 0
        for _, k in ipairs(blocks.ORDER[ch.section]) do
            local spec = blocks.spec(ch.section, k)
            add(rx + col * (rw / 2), y, rw / 2 - 8, short(spec.label:gsub("{([%w_]+)}", "%1"), 60), "choose", k)
            col = col + 1
            if col == 2 then col = 0; y = y + 26 end
        end
        return
    end
    local function row(b, section, depth, list)
        local sel = self.block == b
        add(rx + depth * 20, y, rw - depth * 20 - 100, short(blocks.describe(section, b), 90), "block", { b, section }, sel)
        add(rx + rw - 92, y, 28, "^", "move", { b, -1 })
        add(rx + rw - 60, y, 28, "v", "move", { b, 1 })
        add(rx + rw - 28, y, 28, "x", "remove", b)
        y = y + 24
    end
    local function list_of(section, list, depth, parent)
        for _, b in ipairs(list or {}) do
            row(b, section, depth, list)
            local spec = blocks.spec(section, b.kind)
            for _, hold in ipairs(spec and spec.holds or {}) do
                label(rx + (depth + 1) * 20, y + 3, ({ if_conditions = "If", then_actions = "Then", else_actions = "Else",
                    loop_actions = "Loop" })[hold], C.dim)
                add(rx + (depth + 1) * 20 + 50, y, 30, "+", "open_chooser", { hold, b })
                y = y + 24
                list_of(hold, b[hold], depth + 2, b)
            end
        end
    end
    for _, s in ipairs({ { "events", "Events", "+ Event" }, { "conditions", "Conditions", "+ Condition" },
                         { "actions", "Actions", "+ Action" } }) do
        label(rx, y + 3, s[2], C.head)
        add(rx + 110, y, 110, s[3], "open_chooser", { s[1] })
        y = y + 26
        list_of(s[1], t[s[1]], 1)
        y = y + 4
    end
    -- the chosen block's parameters
    if self.block then
        local b, section = self.block, self.block_section
        local spec = blocks.spec(section, b.kind)
        y = math.max(y + 8, self.h - 36 - 26 * (#spec.params + 1))
        label(rx, y + 3, spec.label:gsub("{([%w_]+)}", "%1"), C.gold)
        y = y + 26
        for _, p in ipairs(spec.params) do
            local key, pk = p[1], p[2]
            label(rx, y + 4, key, C.dim)
            local v = b.args[key]
            local editing = field and field.target == "arg" and field.key == key
            local shown = editing and (field.buf .. "_") or self:shown(pk, v)
            add(rx + 110, y, 360, short(shown, 50), "edit_arg", key, editing)
            if pk == "integer" or pk == "real" or pk == "player" then
                add(rx + 478, y, 30, "-", "step", { key, pk, -1 })
                add(rx + 514, y, 30, "+", "step", { key, pk, 1 })
            elseif pk == "unit" or pk == "region" or pk == "trigger" or pk == "variable" or pk == "compare"
                or pk == "op" or pk == "boolean" or pk == "force" then
                add(rx + 478, y, 30, "<", "cycle", { key, pk, -1 })
                add(rx + 514, y, 30, ">", "cycle", { key, pk, 1 })
            end
            y = y + 26
        end
    end
end

function TUI:shown(pk, v)
    if type(v) == "table" and v.expr then return "= " .. v.expr end
    if v == nil then return "(none)" end
    if pk == "player" and type(v) == "number" then return "Player " .. (v + 1) end
    if pk == "region" then return (tostring(v):gsub("^gg_rct_", "")) end
    return tostring(v)
end

function TUI:layout_variable(v, add, label, rx, ry, rw)
    local field = self.field
    local function editing(t) return field and field.target == t end
    label(rx, ry + 4, "Name", C.dim)
    add(rx + 110, ry, 300, editing("var_name") and (field.buf .. "_") or v.name, "edit_var", "name", editing("var_name"))
    label(rx, ry + 30, "Type", C.dim)
    add(rx + 110, ry + 26, 300, v.type, "var_type", v)
    label(rx, ry + 56, "Initial", C.dim)
    add(rx + 110, ry + 52, 300, editing("var_initial") and (field.buf .. "_") or tostring(v.initial == nil and "(default)" or v.initial),
        "edit_var", "initial", editing("var_initial"))
    add(rx + 110, ry + 78, 145, v.array and "Array: yes" or "Array: no", "var_array", v, v.array)
    add(rx + 265, ry + 78, 145, "Delete", "delete_variable", v)
end

function TUI:layout_map(mt, add, label, rx, ry, rw)
    local E = self.E
    local off = E.map_trigger_off[mt]
    label(rx, ry + 4, mt.name, C.gold)
    add(rx + rw - 140, ry, 140, off and "Switch on" or "Switch off", "map_on", mt, off)
    local y = ry + 32
    label(rx, y, "variable " .. mt.var .. "   made in function " .. tostring(mt.fn), C.text); y = y + 22
    label(rx, y, "events: " .. (#mt.events > 0 and table.concat(mt.events, ", ") or "(none found)"), C.text); y = y + 28
    local function fns(title, list)
        label(rx, y + 4, title, C.head)
        y = y + 26
        for _, f in ipairs(list) do
            add(rx + 20, y, 300, "Edit function " .. f, "edit_fn", f)
            y = y + 26
        end
    end
    fns("Conditions", mt.conditions)
    fns("Actions", mt.actions)
    if mt.fn then add(rx + 20, y + 8, 300, "Edit function " .. mt.fn .. " (makes it)", "edit_fn", mt.fn) end
end
-- }}}

-- {{{ actions
local function cycle_list(self, pk)
    local E = self.E
    if pk == "unit" then return blocks.UNIT_ROLES end
    if pk == "compare" then return blocks.COMPARE end
    if pk == "op" then return { "add", "set" } end
    if pk == "boolean" then return { true, false } end
    if pk == "force" then return { "all", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } end
    local out = {}
    if pk == "region" then for _, r in ipairs(E:regions()) do out[#out + 1] = r.var end end
    if pk == "trigger" then for _, t in ipairs(E:triggers()) do out[#out + 1] = t.name end end
    if pk == "variable" then for _, v in ipairs(E:variables()) do out[#out + 1] = v.name end end
    return out
end

function TUI:start_field(target, key, value)
    local v = value
    if type(v) == "table" and v.expr then v = v.expr end
    -- what's typed first replaces the old value; Backspace first clears it
    self.field = { target = target, key = key, buf = v == nil and "" or tostring(v), fresh = true }
end

function TUI:commit_field()
    local f, E = self.field, self.E
    self.field = nil
    if not f then return end
    local sel = self.sel and self.sel[2]
    if f.target == "trigger_name" then
        if f.buf ~= "" then
            local ok, why = E:rename_trigger(sel, f.buf)
            if not ok then E:say(why) end
        end
    elseif f.target == "var_name" then
        if f.buf ~= "" and not E:variable_named(f.buf) then E:set_variable(sel, "name", f.buf) end
    elseif f.target == "var_initial" then
        E:set_variable(sel, "initial", f.buf ~= "" and (tonumber(f.buf) or f.buf) or nil)
    elseif f.target == "arg" and self.block then
        local spec = blocks.spec(self.block_section, self.block.kind)
        local pk
        for _, p in ipairs(spec.params) do if p[1] == f.key then pk = p[2] end end
        local v = f.buf
        if pk == "integer" or pk == "real" or pk == "player" then v = tonumber(f.buf) or { expr = f.buf }
        elseif pk == "boolean" then v = (f.buf == "true") or (f.buf ~= "false" and { expr = f.buf }) or false
        elseif pk == "unit" or pk == "force" then v = blocks.UNITS[f.buf] and f.buf or { expr = f.buf } end
        E:set_block_arg(self.block, f.key, v)
    end
end

function TUI:press(b)
    local E = self.E
    local a, arg = b.action, b.arg
    local sel = self.sel and self.sel[2]
    if self.field and a ~= "edit_arg" then self:commit_field() end
    if a == "new_trigger" then
        local t = E:new_trigger("Untitled Trigger")
        self.sel, self.block, self.chooser = { "trigger", t }, nil, nil
    elseif a == "new_variable" then
        local n = 1
        while E:variable_named("Variable" .. n) do n = n + 1 end
        local v = E:new_variable("Variable" .. n, "integer", 0)
        self.sel, self.block = { "variable", v }, nil
    elseif a == "pick" then
        self.sel, self.block, self.chooser, self.code = arg, nil, nil, nil
    elseif a == "map_page" then self.map_page = self.map_page + arg
    elseif a == "edit_name" then self:start_field("trigger_name", nil, sel.name)
    elseif a == "toggle_on" then E:set_trigger_on(arg, arg.on == false)
    elseif a == "delete_trigger" then E:delete_trigger(arg); self.sel, self.block = nil, nil
    elseif a == "show_code" then
        self.code = { title = "JASS for " .. arg.name .. " (read only)", readonly = true,
                      te = textedit.new(E:trigger_jass(arg), { readonly = true }) }
    elseif a == "close_code" then self.code = nil
    elseif a == "apply_code" then
        local c = self.code
        local ok, why = E:set_map_function(c.fn, c.te:text())
        if ok then E:say("Function " .. c.fn .. " rewritten"); self.code = nil
        else E:say("Not kept: " .. tostring(why)) end
    elseif a == "open_chooser" then self.chooser = { section = arg[1], parent = arg[2] }
    elseif a == "cancel_chooser" then self.chooser = nil
    elseif a == "choose" then
        local ch = self.chooser
        self.chooser = nil
        local nb = E:add_block(sel, ch.section, arg, nil, ch.parent)
        if nb then self.block, self.block_section = nb, ch.section end
    elseif a == "block" then self.block, self.block_section = arg[1], arg[2]
    elseif a == "move" then E:move_block(sel, arg[1], arg[2])
    elseif a == "remove" then
        E:remove_block(sel, arg)
        if self.block == arg then self.block = nil end
    elseif a == "edit_arg" then
        if self.field then self:commit_field() end
        self:start_field("arg", arg, self.block.args[arg])
    elseif a == "step" then
        local key, pk, dir = arg[1], arg[2], arg[3]
        local v = self.block.args[key]
        if type(v) ~= "number" then v = 0 end
        local step = pk == "real" and (math.abs(v) >= 10 and 5 or 0.5) or 1
        v = v + dir * step
        if pk == "player" then v = math.max(0, math.min(27, v)) end
        E:set_block_arg(self.block, key, v)
    elseif a == "cycle" then
        local key, pk, dir = arg[1], arg[2], arg[3]
        local list = cycle_list(self, pk)
        if #list > 0 then
            local at = 0
            for i, x in ipairs(list) do if x == self.block.args[key] then at = i end end
            at = (at - 1 + dir) % #list + 1
            E:set_block_arg(self.block, key, list[at])
        end
    elseif a == "edit_var" then self:start_field("var_" .. arg, nil, sel[arg])
    elseif a == "var_type" then
        local at = 1
        for i, t in ipairs(blocks.VAR_TYPES) do if t == arg.type then at = i end end
        E:set_variable(arg, "type", blocks.VAR_TYPES[at % #blocks.VAR_TYPES + 1])
        E:set_variable(arg, "initial", nil)
    elseif a == "var_array" then E:set_variable(arg, "array", not arg.array or nil)
    elseif a == "delete_variable" then E:delete_variable(arg); self.sel = nil
    elseif a == "map_on" then E:set_map_trigger_on(arg, E.map_trigger_off[arg] and true or false)
    elseif a == "edit_fn" then
        local text = E:map_function(arg)
        if text then
            self.code = { title = "function " .. arg, fn = arg, readonly = false, te = textedit.new(text) }
        end
    end
    self:layout()
end
-- }}}

-- {{{ input
local function inside(b, x, y) return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h end

-- true when the panel used the keys (the editor's shortcuts then don't run)
function TUI:update(input)
    local mx, my = input.mx or 0, input.my or 0
    local used_keys = false
    if self.field then
        used_keys = true
        local f = self.field
        if (input.chars or "") ~= "" then
            f.buf = (f.fresh and "" or f.buf) .. input.chars
            f.fresh = false
        end
        for _, k in ipairs(input.keys or {}) do
            if k == "BACKSPACE" then
                f.buf = f.fresh and "" or f.buf:sub(1, -2)
                f.fresh = false
            elseif k == "ENTER" then self:commit_field()
            elseif k == "ESCAPE" then self.field = nil end
        end
        self:layout()
    elseif self.code then
        used_keys = true
        local te = self.code.te
        te:type(input.chars or "")
        for _, k in ipairs(input.keys or {}) do
            if k == "ESCAPE" then self.code = nil; break
            elseif input.ctrl and k == "ENTER" and not self.code.readonly then
                self:press({ action = "apply_code" }); break
            else te:key(k, input.ctrl) end
        end
        if self.code and input.wheel and input.wheel ~= 0 then self.code.te:scroll(-math.floor(input.wheel * 3)) end
    else
        for _, k in ipairs(input.keys or {}) do
            if k == "ESCAPE" then
                if self.chooser then self.chooser = nil else self.block = nil end
                self:layout()
                used_keys = true
            end
        end
    end
    if input.lp then
        for _, b in ipairs(self.buttons) do
            if inside(b, mx, my) and b.action ~= "none" then self:press(b); return true end
        end
        if self.code and self.code_box and inside(self.code_box, mx, my) and self.measure then
            self.code.te:click(mx, my, self.code_box, self.measure)
        end
    end
    return used_keys
end

-- the button showing label (tests press by name)
function TUI:button(label)
    for _, b in ipairs(self.buttons) do if b.label == label then return b end end
end
-- }}}

-- {{{ drawing
function TUI:draw(render)
    self.measure = render.ui_text_width
    local function rect(x, y, w, h, c, a) render.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
    rect(0, 38, self.w, self.h - 66, C.panel, 250)
    rect(trigger_ui.LEFT, 38, 1, self.h - 66, C.edge)
    for _, l in ipairs(self.labels) do render.ui_text(l.s, l.x, l.y, 14, l.c[1], l.c[2], l.c[3], 255) end
    for _, b in ipairs(self.buttons) do
        rect(b.x, b.y, b.w, b.h, b.active and C.active or C.button)
        render.ui_frame(b.x, b.y, b.w, b.h, 1, C.edge[1], C.edge[2], C.edge[3], 255)
        local c = b.colour or C.text
        render.ui_text(b.label, b.x + 6, b.y + 5, 13, c[1], c[2], c[3], 255)
    end
    if self.code and self.code_box then self.code.te:draw(render, self.code_box) end
    -- problems with the trigger in view (checked again after each change)
    if self.sel and self.sel[1] == "trigger" and not self.code and not self.chooser then
        local steps = #self.E.history.done + #self.E.history.undone
        if steps ~= self.checked_at then
            self.checked_at = steps
            self.problems = self.E:check_triggers()
        end
        local y = 48
        for _, p in ipairs(self.problems or {}) do
            if p.trigger == self.sel[2] or p.trigger == nil then
                render.ui_text("! " .. p.message, trigger_ui.LEFT + 560, y, 13, C.warn[1], C.warn[2], C.warn[3], 255)
                y = y + 18
            end
        end
    end
end
-- }}}

return trigger_ui
