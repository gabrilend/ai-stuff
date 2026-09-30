--[[
The AI Editor's Panel (Issue 909)

Opened from the toolbar ("AI"), over the whole view, as the WC3 AI
Editor's window: the computer players on the left (each with where its
profile came from: the profiles folder, the map, or derived), "Export"
to write the changed ones to the profiles folder; on the right the
chosen one's tabs:

  General     name, race, the options (checkboxes), workers on gold and
              lumber, the target priorities
  Heroes      the heroes in order, each with its skill order (typed:
              ability ids, commas between)
  Build       the build priorities: kind, what, how many, condition
  Groups      the attack groups (one shown at a time) and their units
  Waves       the timing, and which group each wave sends
  Conditions  the named conditions

Numbers change by - / +; kinds and groups cycle; ids, names and
conditions are typed (a condition as a Lua table:
{ "gold", ">=", 500 }, or a name in quotes); unit types can also be
picked from what the player's buildings train. Every line moves up or
down or goes (^ v x).

    local aui = require("editor.ai_ui").new(E, w, h)
    aui:update(input); aui:draw(render)
]]

local editor_ai = require("editor.ai")

local ai_ui = {}
ai_ui.LEFT = 300
ai_ui.TABS = { "General", "Heroes", "Build", "Groups", "Waves", "Conditions" }
ai_ui.PICK_PAGE = 24
ai_ui.RACES = { "human", "orc", "undead", "nightelf", "custom" }

local AUI = {}
AUI.__index = AUI

local C = {
    panel = { 22, 24, 30 }, edge = { 70, 74, 86 }, button = { 44, 48, 58 }, active = { 90, 120, 60 },
    text = { 225, 225, 215 }, dim = { 140, 140, 130 }, gold = { 240, 200, 90 }, head = { 130, 170, 230 },
    warn = { 240, 120, 90 },
}

function ai_ui.new(E, w, h, opts)
    local self = setmetatable({ E = E, w = w, h = h, tab = "Build", pick_page = 0, opts = opts or {} }, AUI)
    if not E.ai_list then
        local ok, err = E:load_ai({ root = self.opts.root })
        if not ok then E:say("AI profiles: " .. tostring(err)) end
    end
    self.entry = E:ai_profiles()[1]
    self:layout()
    return self
end

local function short(s, n)
    s = tostring(s)
    return #s > n and (s:sub(1, n - 2) .. "..") or s
end

-- {{{ layout
function AUI:layout()
    local E = self.E
    local b = {}
    self.buttons, self.labels = b, {}
    local function add(x, y, w, label, action, arg, active)
        b[#b + 1] = { x = x, y = y, w = w, h = 22, label = label, action = action, arg = arg, active = active }
    end
    local function label(x, y, s, c) self.labels[#self.labels + 1] = { x = x, y = y, s = s, c = c or C.text } end
    self.add, self.label = add, label
    -- the players
    local y = 46
    label(8, y, "Computer players", C.head); y = y + 24
    for _, e in ipairs(E:ai_profiles()) do
        local from = e.file and "folder" or (e.source:match("^map:") and "map" or "derived")
        add(8, y, 280, short(string.format("%d %s (%s)", e.player, e.name, from), 38), "entry", e, e == self.entry)
        y = y + 24
    end
    add(8, y + 8, 280, "Export changed to the profiles folder", "export")
    local e = self.entry
    if not e then label(ai_ui.LEFT + 8, 46, "No computer players own anything in this map.", C.dim) return b end
    local x = ai_ui.LEFT + 8
    for _, t in ipairs(ai_ui.TABS) do
        add(x, 46, 110, t, "tab", t, self.tab == t)
        x = x + 116
    end
    self.y = 80
    if self.picker then self:layout_picker(e) return b end
    local f = self["tab_" .. self.tab:lower()]
    f(self, e, e.profile)
    return b
end

-- a typed field: shows the buffer while typing
function AUI:field_button(x, y, w, key, text, commit)
    local f = self.field
    local editing = f and f.key == key
    self.add(x, y, w, editing and (f.buf .. "_") or short(text, math.floor(w / 8)), "field",
        { key = key, text = text, commit = commit }, editing)
end

-- ^ v x at the end of a line of list at path
function AUI:row_tools(e, path, i)
    local x = self.w - 8 - 92
    self.add(x, self.y, 28, "^", "move", { path, i, -1 })
    self.add(x + 32, self.y, 28, "v", "move", { path, i, 1 })
    self.add(x + 64, self.y, 28, "x", "remove", { path, i })
end

function AUI:number(e, path, step, lo, hi, label_text, x)
    x = x or (ai_ui.LEFT + 8)
    local v = self.E:ai_get(e, path) or 0
    self.label(x, self.y + 4, label_text, C.dim)
    self.add(x + 150, self.y, 80, (math.floor(v) == v) and tostring(v) or string.format("%.2f", v), "none")
    self.add(x + 234, self.y, 28, "-", "number", { path, -step, lo, hi })
    self.add(x + 266, self.y, 28, "+", "number", { path, step, lo, hi })
end

function AUI:condition_field(e, path, x, w)
    local c = self.E:ai_get(e, path)
    local E = self.E
    self:field_button(x, self.y, w, table.concat(path, "."), c == nil and "(always)" or editor_ai.condition_text(c),
        function(text)
            local v, ok = editor_ai.parse_condition(text)
            if ok then E:ai_set(e, path, v) else E:say("Not a condition: " .. text) end
        end)
end

function AUI:tab_general(e, p)
    local E, X = self.E, ai_ui.LEFT + 8
    self.label(X, self.y + 4, "Name", C.dim)
    self:field_button(X + 150, self.y, 300, "name", p.name, function(t) if t ~= "" then E:ai_set(e, { "name" }, t) end end)
    self.y = self.y + 26
    self.label(X, self.y + 4, "Race", C.dim)
    self.add(X + 150, self.y, 300, tostring(p.race), "cycle", { { "race" }, ai_ui.RACES })
    self.y = self.y + 32
    self.label(X, self.y, "Options", C.head); self.y = self.y + 22
    for i, o in ipairs(editor_ai.OPTIONS) do
        local col = (i - 1) % 3
        self.add(X + col * 200, self.y, 192, o:gsub("_", " "), "toggle", { "options", o }, p.options[o] == true)
        if col == 2 or i == #editor_ai.OPTIONS then self.y = self.y + 26 end
    end
    self.y = self.y + 8
    self:number(e, { "harvest", "gold" }, 1, 0, 30, "Workers on gold"); self.y = self.y + 26
    self:number(e, { "harvest", "lumber" }, 1, 0, 30, "Workers on lumber"); self.y = self.y + 32
    self.label(X, self.y + 4, "Target priorities", C.head)
    self.add(X + 150, self.y, 110, "+ Target", "insert", { { "targets" }, { kind = "enemy_base" } })
    self.y = self.y + 26
    for i, t in ipairs(p.targets) do
        self.add(X, self.y, 200, t.kind, "cycle", { { "targets", i, "kind" }, editor_ai.TARGETS })
        self:condition_field(e, { "targets", i, "condition" }, X + 208, 360)
        self:row_tools(e, { "targets" }, i)
        self.y = self.y + 26
    end
end

function AUI:tab_heroes(e, p)
    local E, X = self.E, ai_ui.LEFT + 8
    self.add(X, self.y, 110, "+ Hero", "insert", { { "heroes" }, { id = "Hpal", skills = {} } })
    self.label(X + 120, self.y + 4, "id, then its skill order (ability ids, commas between)", C.dim)
    self.y = self.y + 28
    for i, h in ipairs(p.heroes) do
        self.label(X, self.y + 4, tostring(i), C.dim)
        self:field_button(X + 20, self.y, 70, "hero" .. i, h.id or "", function(t) E:ai_set(e, { "heroes", i, "id" }, t) end)
        self.label(X + 98, self.y + 4, short(E:ai_name_of(h.id), 22), C.text)
        self:field_button(X + 280, self.y, self.w - X - 280 - 108, "skills" .. i, table.concat(h.skills or {}, ","),
            function(t)
                local list = {}
                for id in t:gmatch("[%w]+") do list[#list + 1] = id end
                E:ai_set(e, { "heroes", i, "skills" }, list)
            end)
        self:row_tools(e, { "heroes" }, i)
        self.y = self.y + 26
    end
end

function AUI:unit_lines(e, list, path, with_kind)
    local E, X = self.E, ai_ui.LEFT + 8
    for i, it in ipairs(list) do
        local x = X
        if with_kind then
            self.add(x, self.y, 90, it.kind or "unit", "cycle", { { path[1], i, "kind" }, editor_ai.BUILD_KINDS })
            x = x + 96
        end
        local kind = it.kind or "unit"
        if kind == "hero" then
            self.label(x, self.y + 4, "hero slot", C.dim)
            self:number(e, { path[1], i, "slot" }, 1, 1, 5, "", x - 150 + 80)
        elseif kind ~= "expansion" then
            local ipath = {}
            for k, v in ipairs(path) do ipath[k] = v end
            ipath[#ipath + 1] = i
            local idpath = { unpack(ipath) }; idpath[#idpath + 1] = "id"
            self:field_button(x, self.y, 64, table.concat(idpath, "."), it.id or "", function(t) E:ai_set(e, idpath, t) end)
            self.add(x + 68, self.y, 24, "..", "pick", idpath)
            self.label(x + 98, self.y + 4, short(E:ai_name_of(it.id), 20), C.text)
            local cpath = { unpack(ipath) }; cpath[#cpath + 1] = "count"
            self.add(x + 260, self.y, 40, tostring(it.count or 1), "none")
            self.add(x + 302, self.y, 24, "-", "number", { cpath, -1, 0, 99 })
            self.add(x + 328, self.y, 24, "+", "number", { cpath, 1, 0, 99 })
        end
        local cpath = { unpack(path) }; cpath[#cpath + 1] = i; cpath[#cpath + 1] = "condition"
        self:condition_field(e, cpath, X + (with_kind and 96 or 0) + 360, self.w - X - (with_kind and 96 or 0) - 360 - 108)
        self:row_tools(e, path, i)
        self.y = self.y + 26
    end
end

function AUI:tab_build(e, p)
    local X = ai_ui.LEFT + 8
    self.add(X, self.y, 110, "+ Unit", "insert", { { "build" }, { kind = "unit", id = e.trains[1] or "hfoo", count = 1 } })
    self.add(X + 116, self.y, 110, "+ Hero", "insert", { { "build" }, { kind = "hero", slot = 1 } })
    self.add(X + 232, self.y, 110, "+ Upgrade", "insert", { { "build" }, { kind = "upgrade", id = "Rhme", count = 1 } })
    self.add(X + 348, self.y, 110, "+ Expansion", "insert", { { "build" }, { kind = "expansion" } })
    self.y = self.y + 30
    self:unit_lines(e, p.build, { "build" }, true)
end

function AUI:tab_groups(e, p)
    local E, X = self.E, ai_ui.LEFT + 8
    local names = {}
    for k in pairs(p.groups) do names[#names + 1] = k end
    table.sort(names)
    if not self.group or not p.groups[self.group] then self.group = names[1] end
    local x = X
    for _, n in ipairs(names) do
        self.add(x, self.y, 100, n, "group", n, n == self.group)
        x = x + 104
    end
    self.add(x, self.y, 100, "+ Group", "new_group")
    self.y = self.y + 30
    if not self.group then return end
    self.add(X, self.y, 110, "+ Unit", "insert", { { "groups", self.group }, { id = e.trains[1] or "hfoo", count = 1 } })
    self.add(X + 116, self.y, 150, "Delete group", "delete_group", self.group)
    self.y = self.y + 30
    self:unit_lines(e, p.groups[self.group], { "groups", self.group }, false)
end

function AUI:tab_waves(e, p)
    local X = ai_ui.LEFT + 8
    self:number(e, { "waves", "initial_delay" }, 10, 0, 3600, "First wave after (s)"); self.y = self.y + 26
    self:number(e, { "waves", "delay" }, 10, 0, 3600, "Between waves (s)"); self.y = self.y + 26
    self:number(e, { "waves", "repeat_from" }, 1, 1, 99, "Then again from wave"); self.y = self.y + 26
    self:number(e, { "waves", "max_wait" }, 10, 0, 3600, "Longest wait to gather"); self.y = self.y + 26
    self:number(e, { "waves", "min_fraction" }, 0.1, 0, 1, "Goes with this much"); self.y = self.y + 32
    local names = {}
    for k in pairs(p.groups) do names[#names + 1] = k end
    table.sort(names)
    self.label(X, self.y + 4, "Waves", C.head)
    self.add(X + 150, self.y, 110, "+ Wave", "insert", { { "waves", "list" }, { group = names[1] or "main" } })
    self.y = self.y + 26
    for i, w in ipairs(p.waves.list) do
        self.label(X, self.y + 4, tostring(i), C.dim)
        self.add(X + 30, self.y, 150, tostring(w.group), "cycle", { { "waves", "list", i, "group" }, names })
        self:condition_field(e, { "waves", "list", i, "condition" }, X + 190, self.w - X - 190 - 108)
        self:row_tools(e, { "waves", "list" }, i)
        self.y = self.y + 26
    end
end

function AUI:tab_conditions(e, p)
    local E, X = self.E, ai_ui.LEFT + 8
    self.add(X, self.y, 140, "+ Condition", "new_condition")
    self.y = self.y + 30
    local names = {}
    for k in pairs(p.conditions) do names[#names + 1] = k end
    table.sort(names)
    for _, n in ipairs(names) do
        self.label(X, self.y + 4, n, C.text)
        self:condition_field(e, { "conditions", n }, X + 160, self.w - X - 160 - 44)
        self.add(self.w - 8 - 28, self.y, 28, "x", "set", { { "conditions", n }, nil })
        self.y = self.y + 26
    end
    self.y = self.y + 8
    self.label(X, self.y, 'e.g. { "gold", ">=", 500 }   { "and", "early", { "army", ">=", 8 } }   { "game_time", ">", 600 }', C.dim)
end

function AUI:layout_picker(e)
    local X = ai_ui.LEFT + 8
    local list = e.trains
    local pages = math.max(1, math.ceil(#list / ai_ui.PICK_PAGE))
    self.pick_page = math.max(0, math.min(self.pick_page, pages - 1))
    self.label(X, self.y + 4, string.format("What %s's buildings train (%d/%d)", e.name, self.pick_page + 1, pages), C.head)
    self.add(X + 420, self.y, 36, "<", "pick_page", -1)
    self.add(X + 460, self.y, 36, ">", "pick_page", 1)
    self.add(X + 510, self.y, 90, "Cancel", "pick_cancel")
    self.y = self.y + 30
    for k = 1, ai_ui.PICK_PAGE do
        local id = list[self.pick_page * ai_ui.PICK_PAGE + k]
        if not id then break end
        local col = (k - 1) % 2
        self.add(X + col * 330, self.y, 320, id .. "  " .. short(self.E:ai_name_of(id), 30), "picked", id)
        if col == 1 then self.y = self.y + 26 end
    end
end
-- }}}

-- {{{ actions
function AUI:commit()
    local f = self.field
    self.field = nil
    if f then f.commit(f.buf) end
end

function AUI:press(b)
    local E, e = self.E, self.entry
    local a, arg = b.action, b.arg
    if self.field and a ~= "field" then self:commit() end
    if a == "entry" then self.entry, self.picker = arg, nil
    elseif a == "tab" then self.tab, self.picker = arg, nil
    elseif a == "export" then E:export_ai()
    elseif a == "field" then
        if self.field then self:commit() end
        self.field = { key = arg.key, buf = arg.text == "(always)" and "" or arg.text, fresh = true, commit = arg.commit }
    elseif a == "number" then
        local path, step, lo, hi = arg[1], arg[2], arg[3], arg[4]
        local v = (E:ai_get(e, path) or 0) + step
        v = math.max(lo, math.min(hi, math.floor(v * 100 + 0.5) / 100))
        E:ai_set(e, path, v)
    elseif a == "cycle" then
        local path, list = arg[1], arg[2]
        if #list > 0 then
            local cur, at = E:ai_get(e, path), 0
            for i, x in ipairs(list) do if x == cur then at = i end end
            E:ai_set(e, path, list[at % #list + 1])
        end
    elseif a == "toggle" then
        E:ai_set(e, { arg[1], arg[2] }, not E:ai_get(e, { arg[1], arg[2] }))
    elseif a == "insert" then E:ai_insert(e, arg[1], editor_ai.copy(arg[2]))
    elseif a == "move" then E:ai_move(e, arg[1], arg[2], arg[3])
    elseif a == "remove" then E:ai_remove(e, arg[1], arg[2])
    elseif a == "set" then E:ai_set(e, arg[1], arg[2])
    elseif a == "group" then self.group = arg
    elseif a == "new_group" then
        local n = 1
        while e.profile.groups["group" .. n] do n = n + 1 end
        E:ai_set(e, { "groups", "group" .. n }, {})
        self.group = "group" .. n
    elseif a == "delete_group" then E:ai_set(e, { "groups", arg }, nil); self.group = nil
    elseif a == "new_condition" then
        local n = 1
        while e.profile.conditions["condition" .. n] do n = n + 1 end
        E:ai_set(e, { "conditions", "condition" .. n }, { "game_time", ">", 300 })
    elseif a == "pick" then self.picker = arg; self.pick_page = 0
    elseif a == "pick_page" then self.pick_page = self.pick_page + arg
    elseif a == "pick_cancel" then self.picker = nil
    elseif a == "picked" then
        E:ai_set(e, self.picker, arg)
        self.picker = nil
    end
    self:layout()
end

local function inside(b, x, y) return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h end

function AUI:update(input)
    local used = false
    if self.field then
        used = true
        local f = self.field
        if (input.chars or "") ~= "" then f.buf = (f.fresh and "" or f.buf) .. input.chars; f.fresh = false end
        for _, k in ipairs(input.keys or {}) do
            if k == "BACKSPACE" then f.buf = f.fresh and "" or f.buf:sub(1, -2); f.fresh = false
            elseif k == "ENTER" then self:commit()
            elseif k == "ESCAPE" then self.field = nil end
        end
        self:layout()
    else
        for _, k in ipairs(input.keys or {}) do
            if k == "ESCAPE" and self.picker then self.picker = nil; self:layout(); used = true end
        end
    end
    if input.lp then
        for _, b in ipairs(self.buttons) do
            if inside(b, input.mx or 0, input.my or 0) and b.action ~= "none" then self:press(b); return true end
        end
    end
    return used
end

function AUI:button(label)
    for _, b in ipairs(self.buttons) do if b.label == label then return b end end
end
-- }}}

-- {{{ drawing
function AUI:draw(render)
    local function rect(x, y, w, h, c, a) render.ui_rect(x, y, w, h, c[1], c[2], c[3], a or 255) end
    rect(0, 38, self.w, self.h - 66, C.panel, 250)
    rect(ai_ui.LEFT, 38, 1, self.h - 66, C.edge)
    for _, l in ipairs(self.labels) do render.ui_text(l.s, l.x, l.y, 14, l.c[1], l.c[2], l.c[3], 255) end
    for _, b in ipairs(self.buttons) do
        rect(b.x, b.y, b.w, b.h, b.active and C.active or C.button)
        render.ui_frame(b.x, b.y, b.w, b.h, 1, C.edge[1], C.edge[2], C.edge[3], 255)
        render.ui_text(b.label, b.x + 6, b.y + 5, 13, C.text[1], C.text[2], C.text[3], 255)
    end
    -- the profile's problems
    local y = self.h - 50
    for _, p in ipairs(self.E:ai_check()) do
        if p.entry == self.entry then
            render.ui_text("! " .. p.message, ai_ui.LEFT + 8, y, 13, C.warn[1], C.warn[2], C.warn[3], 255)
            y = y - 18
        end
    end
end
-- }}}

return ai_ui
