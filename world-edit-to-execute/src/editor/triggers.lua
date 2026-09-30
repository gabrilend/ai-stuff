--[[
The Trigger Editor (Issue 905)

Two kinds of trigger:

  the editor's   made here from blocks (editor/trigger_blocks.lua): events,
                 conditions, actions (if / then / else, loops, units picked
                 in a region hold more actions), with the variables they
                 use. Saving writes them as JASS into the map's script, as
                 the World Editor does, so the map still plays in WC3; each
                 piece written stands between //EDITOR-BEGIN and
                 //EDITOR-END lines, taken out again when the map is opened
                 here. The blocks themselves are kept in the map as
                 war3mapEditor.lua, a table of data, and read back from it.
  the map's own  the triggers its script makes (set X = CreateTrigger() and
                 the TriggerRegister... / TriggerAddAction calls after it):
                 listed with their events and action functions; a function's
                 text can be rewritten (the code view), and a trigger can be
                 switched off (its TriggerAddAction calls become DoNothing()).

  E:triggers()                      the editor's triggers, in order
  E:new_trigger(name, category)     a new, empty trigger (initially on)
  E:delete_trigger(t), E:rename_trigger(t, name), E:set_trigger_on(t, on)
  E:add_block(t, section, kind, args, parent, at)
                                    section: events, conditions, actions;
                                    within a control action: if_conditions,
                                    then_actions, else_actions, loop_actions
                                    (parent the control block)
  E:remove_block(t, b), E:move_block(t, b, by), E:set_block_arg(b, key, v)
  E:variables(), E:new_variable(name, type, initial, opts), E:delete_variable(v)
  E:trigger_jass(t)                 the JASS one trigger becomes (code view)
  E:trigger_code()                  what saving writes into the script
  E:check_triggers(opts)            problems: { trigger, message } ...;
                                    opts.full also loads the whole saved
                                    script as the game would
  E:map_triggers()                  the script's own triggers
  E:map_function(name)              a script function's text, from where to where
  E:set_map_function(name, text)    rewritten (one step to undo)
  E:set_map_trigger_on(mt, on)

Every change is one step to undo.

    require("editor.triggers")(E)     -- editor/init.lua does this
]]

local blocks = require("editor.trigger_blocks")

local triggers = {}
triggers.FILE = "war3mapEditor.lua"
triggers.BEGIN, triggers.END = "//EDITOR-BEGIN", "//EDITOR-END"

-- {{{ writing and reading the kept table
local function ser(v, ind, out)
    local t = type(v)
    if t == "string" then out[#out + 1] = string.format("%q", v)
    elseif t == "number" then
        out[#out + 1] = (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.17g", v)
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" then
        local keys, n = {}, #v
        for k in pairs(v) do
            if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) and type(k) ~= "function" then
                if not tostring(k):match("^_") then keys[#keys + 1] = k end
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        out[#out + 1] = "{\n"
        for i = 1, n do out[#out + 1] = ind .. "  "; ser(v[i], ind .. "  ", out); out[#out + 1] = ",\n" end
        for _, k in ipairs(keys) do
            if type(v[k]) ~= "function" then
                out[#out + 1] = ind .. "  "
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then out[#out + 1] = k
                else out[#out + 1] = "["; ser(k, "", out); out[#out + 1] = "]" end
                out[#out + 1] = " = "
                ser(v[k], ind .. "  ", out)
                out[#out + 1] = ",\n"
            end
        end
        out[#out + 1] = ind .. "}"
    else out[#out + 1] = "nil" end
end

function triggers.serialize(data)
    local out = { "-- Triggers made in the map editor (world-edit-to-execute, issue 905).\n",
                  "-- The script's //EDITOR-BEGIN pieces are made from this.\n", "return " }
    ser(data, "", out)
    out[#out + 1] = "\n"
    return table.concat(out)
end

function triggers.deserialize(text)
    local f = loadstring(text, "=" .. triggers.FILE)
    if not f then return nil, "not a table" end
    setfenv(f, {})
    local ok, data = pcall(f)
    if not ok or type(data) ~= "table" then return nil, "not a table" end
    return data
end

-- the script without what the editor wrote into it
function triggers.strip(text)
    local n
    local function lit(x) return (x:gsub("%p", "%%%0")) end
    text, n = text:gsub("\n" .. lit(triggers.BEGIN) .. "\n.-\n" .. lit(triggers.END) .. "\n", "")
    return text, n
end
-- }}}

-- {{{ JASS for one trigger
local function lines_of(section, list, ctx, out, ind)
    for _, b in ipairs(list or {}) do
        local spec = blocks.spec(section, b.kind)
        if not spec then
            out[#out + 1] = ind .. "// unknown block " .. tostring(b.kind)
        elseif b.kind == "if_then_else" then
            local conds = {}
            for _, c in ipairs(b.if_conditions or {}) do
                local cs = blocks.spec("if_conditions", c.kind)
                conds[#conds + 1] = "(" .. (cs and cs.jass(c.args, ctx) or "true") .. ")"
            end
            out[#out + 1] = ind .. "if " .. (#conds > 0 and table.concat(conds, " and ") or "true") .. " then"
            lines_of("then_actions", b.then_actions, ctx, out, ind .. "    ")
            if b.else_actions and #b.else_actions > 0 then
                out[#out + 1] = ind .. "else"
                lines_of("else_actions", b.else_actions, ctx, out, ind .. "    ")
            end
            out[#out + 1] = ind .. "endif"
        elseif b.kind == "for_loop" then
            local v = b.args.variable and blocks.variable_var(b.args.variable) or "bj_forLoopAIndex"
            out[#out + 1] = ind .. "set " .. v .. " = " .. blocks.value("integer", b.args.from)
            out[#out + 1] = ind .. "loop"
            out[#out + 1] = ind .. "    exitwhen " .. v .. " > " .. blocks.value("integer", b.args.to)
            lines_of("loop_actions", b.loop_actions, ctx, out, ind .. "    ")
            out[#out + 1] = ind .. "    set " .. v .. " = " .. v .. " + 1"
            out[#out + 1] = ind .. "endloop"
        elseif b.kind == "pick_units" then
            -- the actions in a function of their own, ForGroup calls it
            ctx.funcs_n = ctx.funcs_n + 1
            local fname = ctx.prefix .. "_Func" .. string.format("%03d", ctx.funcs_n)
            local body = {}
            lines_of("loop_actions", b.loop_actions, ctx, body, "    ")
            table.insert(ctx.funcs, "function " .. fname .. " takes nothing returns nothing\n"
                .. table.concat(body, "\n") .. (#body > 0 and "\n" or "") .. "endfunction")
            out[#out + 1] = ind .. "call ForGroupBJ(GetUnitsInRectAll(" .. blocks.value("region", b.args.region)
                .. "), function " .. fname .. ")"
        else
            for _, l in ipairs(spec.jass(b.args, ctx)) do out[#out + 1] = ind .. l end
        end
    end
end

-- t: the trigger; n: its place (names its functions)
function triggers.jass(t, n)
    local prefix = "Trig_" .. blocks.safe(t.name)
    local T = blocks.trigger_var(t.name)
    local ctx = { prefix = prefix, funcs = {}, funcs_n = 0, trigger = t }
    local out = {}
    -- conditions
    local has_conds = #(t.conditions or {}) > 0
    if has_conds then
        out[#out + 1] = "function " .. prefix .. "_Conditions takes nothing returns boolean"
        for _, c in ipairs(t.conditions) do
            local cs = blocks.spec("conditions", c.kind)
            out[#out + 1] = "    if not (" .. (cs and cs.jass(c.args, ctx) or "true") .. ") then"
            out[#out + 1] = "        return false"
            out[#out + 1] = "    endif"
        end
        out[#out + 1] = "    return true"
        out[#out + 1] = "endfunction"
    end
    local body = {}
    lines_of("actions", t.actions, ctx, body, "    ")
    for _, f in ipairs(ctx.funcs) do out[#out + 1] = f end
    out[#out + 1] = "function " .. prefix .. "_Actions takes nothing returns nothing"
    for _, l in ipairs(body) do out[#out + 1] = l end
    out[#out + 1] = "endfunction"
    -- InitTrig
    out[#out + 1] = "function InitTrig_" .. blocks.safe(t.name) .. " takes nothing returns nothing"
    out[#out + 1] = "    set " .. T .. " = CreateTrigger()"
    if t.on == false then out[#out + 1] = "    call DisableTrigger(" .. T .. ")" end
    for _, e in ipairs(t.events or {}) do
        local es = blocks.spec("events", e.kind)
        local line = es and es.jass(e.args, T, ctx)
        if line then out[#out + 1] = "    " .. line end
    end
    if has_conds then
        out[#out + 1] = "    call TriggerAddCondition(" .. T .. ", Condition(function " .. prefix .. "_Conditions))"
    end
    out[#out + 1] = "    call TriggerAddAction(" .. T .. ", function " .. prefix .. "_Actions)"
    out[#out + 1] = "endfunction"
    return table.concat(out, "\n")
end

local function runs_at_init(t)
    for _, e in ipairs(t.events or {}) do if e.kind == "map_init" then return true end end
end
triggers.runs_at_init = runs_at_init

local VAR_INIT = { integer = "0", real = "0.0", boolean = "false", string = '""', unit = "null", group = "null",
                   player = "null", location = "null", timer = "null" }

local function variable_decl(v)
    local name = blocks.variable_var(v.name)
    if v.array then return v.type .. " array " .. name end
    local init = v.initial
    if init == nil or init == "" then init = VAR_INIT[v.type] or "null"
    elseif v.type == "string" then init = blocks.quote(init)
    elseif v.type == "real" then init = blocks.value("real", tonumber(init) or init)
    else init = tostring(init) end
    return v.type .. " " .. name .. " = " .. init
end
-- }}}

-- {{{ the map's own triggers, from the script
function triggers.scan(script)
    local list = {}
    if not script then return list end
    -- where each function starts and ends
    local fns = {}
    local pos = 1
    while true do
        local s, e, name = script:find("function%s+([%w_]+)%s+takes", pos)
        if not s then break end
        local es, ee = script:find("endfunction", e + 1, true)
        fns[#fns + 1] = { name = name, at = s, to = ee or #script }
        pos = (ee or #script) + 1
    end
    local function fn_at(p)
        for _, f in ipairs(fns) do if p >= f.at and p <= f.to then return f end end
    end
    local seen = {}
    pos = 1
    while true do
        local s, e, var = script:find("set%s+([%w_]+)%s*=%s*CreateTrigger%(%)", pos)
        if not s then break end
        pos = e + 1
        local f = fn_at(s)
        -- what follows up to the next trigger made with this variable, or the function's end
        local stop = f and f.to or #script
        local nxt = script:find("set%s+" .. var:gsub("%p", "%%%0") .. "%s*=%s*CreateTrigger%(%)", e + 1)
        if nxt and nxt < stop then stop = nxt end
        local span = script:sub(e + 1, stop)
        local ev = var:gsub("%p", "%%%0")
        local mt = { var = var, at = s, fn = f and f.name, events = {}, actions = {}, conditions = {}, calls = {} }
        for kind in span:gmatch("TriggerRegister([%w_]+)%(%s*" .. ev .. "%s*,") do mt.events[#mt.events + 1] = kind end
        local p2 = 1
        while true do
            local as, ae, action = span:find("TriggerAddAction%(%s*" .. ev .. "%s*,%s*function%s+([%w_]+)%s*%)", p2)
            if not as then break end
            mt.actions[#mt.actions + 1] = action
            mt.calls[#mt.calls + 1] = { at = e + as, to = e + ae }
            p2 = ae + 1
        end
        for c in span:gmatch("TriggerAddCondition%(%s*" .. ev .. "%s*,%s*Condition%(%s*function%s+([%w_]+)") do
            mt.conditions[#mt.conditions + 1] = c
        end
        local base = var:match("^gg_trg_(.+)$") or ((f and f.name or "?") .. ":" .. var)
        seen[base] = (seen[base] or 0) + 1
        mt.name = seen[base] > 1 and (base .. " #" .. seen[base]) or base
        list[#list + 1] = mt
    end
    return list, fns
end
-- }}}

local function install(E)

    -- {{{ loading
    function E:load_triggers(archive)
        local data = archive and archive:has(triggers.FILE) and archive:extract(triggers.FILE)
        local kept = data and triggers.deserialize(data)
        self.trig = kept or { version = 1, variables = {}, triggers = {} }
        self.trig.variables = self.trig.variables or {}
        self.trig.triggers = self.trig.triggers or {}
        if self.script then
            local n
            self.script, n = triggers.strip(self.script)
            self.had_editor_code = n > 0
        end
        self.map_trigger_list, self.script_functions = triggers.scan(self.script)
        self.map_fn_edits = {}
        self.map_trigger_off = {}
    end
    -- }}}

    local function changed(self)
        self.dirty.script = true
        self.dirty.triggers = true
    end

    -- {{{ triggers
    function E:triggers() return self.trig.triggers end
    function E:variables() return self.trig.variables end

    function E:trigger_named(name)
        for _, t in ipairs(self.trig.triggers) do if t.name == name then return t end end
    end

    local function free_name(self, base)
        local name, n = base, 1
        local script = self.script or ""
        while self:trigger_named(name) or script:find(blocks.trigger_var(name), 1, true) do
            n = n + 1
            name = base .. " " .. n
        end
        return name
    end

    function E:new_trigger(name, category)
        local t = { name = free_name(self, name or "Untitled Trigger"), category = category or "Triggers", on = true,
                    events = {}, conditions = {}, actions = {} }
        local list, me = self.trig.triggers, self
        self.history:run({ name = "New trigger " .. t.name,
            redo = function() list[#list + 1] = t; changed(me) end,
            undo = function()
                for i, x in ipairs(list) do if x == t then table.remove(list, i) break end end
                changed(me)
            end })
        return t
    end

    function E:delete_trigger(t)
        local list, me, at = self.trig.triggers, self
        for i, x in ipairs(list) do if x == t then at = i end end
        if not at then return false end
        self.history:run({ name = "Delete trigger " .. t.name,
            redo = function() table.remove(list, at); changed(me) end,
            undo = function() table.insert(list, at, t); changed(me) end })
        return true
    end

    local function set_key(self, obj, key, value, name)
        local old = obj[key]
        local me = self
        self.history:run({ name = name,
            redo = function() obj[key] = value; changed(me) end,
            undo = function() obj[key] = old; changed(me) end })
        return true
    end

    function E:rename_trigger(t, name)
        if name == t.name then return true end
        if self:trigger_named(name) then return false, "a trigger has that name" end
        return set_key(self, t, "name", name, "Rename trigger " .. t.name .. " to " .. name)
    end

    function E:set_trigger_on(t, on)
        return set_key(self, t, "on", on and true or false, (on and "Turn on " or "Turn off ") .. t.name)
    end

    function E:set_trigger_category(t, category)
        return set_key(self, t, "category", category, t.name .. " in " .. category)
    end
    -- }}}

    -- {{{ blocks
    -- which list b stands in, and where
    local function find_block(list, b)
        for i, x in ipairs(list or {}) do
            if x == b then return list, i end
            for _, hold in ipairs({ "if_conditions", "then_actions", "else_actions", "loop_actions" }) do
                if x[hold] then
                    local l, j = find_block(x[hold], b)
                    if l then return l, j end
                end
            end
        end
    end
    function E:block_place(t, b)
        for _, s in ipairs({ "events", "conditions", "actions" }) do
            local l, i = find_block(t[s], b)
            if l then return l, i end
        end
    end

    function E:add_block(t, section, kind, args, parent, at)
        local spec = blocks.spec(section, kind)
        if not spec then return nil, "no " .. tostring(kind) .. " in " .. tostring(section) end
        local list = parent and parent[section] or t[section]
        if not list then
            if not parent then return nil, "no section " .. section end
            parent[section] = {}
            list = parent[section]
        end
        local b = { kind = kind, args = blocks.defaults(section, kind) }
        for k, v in pairs(args or {}) do b.args[k] = v end
        for _, hold in ipairs(spec.holds or {}) do b[hold] = {} end
        at = at or (#list + 1)
        local me = self
        self.history:run({ name = "Add " .. blocks.describe(section, b),
            redo = function() table.insert(list, at, b); changed(me) end,
            undo = function()
                for i, x in ipairs(list) do if x == b then table.remove(list, i) break end end
                changed(me)
            end })
        return b
    end

    function E:remove_block(t, b)
        local list, at = self:block_place(t, b)
        if not list then return false end
        local me = self
        self.history:run({ name = "Remove " .. b.kind,
            redo = function() table.remove(list, at); changed(me) end,
            undo = function() table.insert(list, at, b); changed(me) end })
        return true
    end

    function E:move_block(t, b, by)
        local list, at = self:block_place(t, b)
        if not list then return false end
        local to = math.max(1, math.min(#list, at + by))
        if to == at then return false end
        local me = self
        self.history:run({ name = "Move " .. b.kind,
            redo = function() table.remove(list, at); table.insert(list, to, b); changed(me) end,
            undo = function() table.remove(list, to); table.insert(list, at, b); changed(me) end })
        return true
    end

    function E:set_block_arg(b, key, value)
        return set_key(self, b.args, key, value, b.kind .. " " .. key .. ": " .. tostring(value))
    end
    -- }}}

    -- {{{ variables
    function E:variable_named(name)
        for _, v in ipairs(self.trig.variables) do if v.name == name then return v end end
    end

    function E:new_variable(name, vtype, initial, opts)
        opts = opts or {}
        if self:variable_named(name) then return nil, "a variable has that name" end
        local v = { name = name, type = vtype or "integer", initial = initial, array = opts.array or nil,
                    size = opts.size }
        local list, me = self.trig.variables, self
        self.history:run({ name = "New variable " .. name,
            redo = function() list[#list + 1] = v; changed(me) end,
            undo = function()
                for i, x in ipairs(list) do if x == v then table.remove(list, i) break end end
                changed(me)
            end })
        return v
    end

    function E:delete_variable(v)
        local list, me, at = self.trig.variables, self
        for i, x in ipairs(list) do if x == v then at = i end end
        if not at then return false end
        self.history:run({ name = "Delete variable " .. v.name,
            redo = function() table.remove(list, at); changed(me) end,
            undo = function() table.insert(list, at, v); changed(me) end })
        return true
    end

    function E:set_variable(v, key, value)
        return set_key(self, v, key, value, "Variable " .. v.name .. " " .. key)
    end
    -- }}}

    -- {{{ JASS
    function E:trigger_jass(t)
        for i, x in ipairs(self.trig.triggers) do
            if x == t then return triggers.jass(t, i) end
        end
        return triggers.jass(t, 0)
    end

    -- nil when there is nothing to write
    function E:trigger_code()
        local ts, vs = self.trig.triggers, self.trig.variables
        if #ts == 0 and #vs == 0 then return nil end
        local g = {}
        for _, v in ipairs(vs) do g[#g + 1] = variable_decl(v) end
        for _, t in ipairs(ts) do g[#g + 1] = "trigger " .. blocks.trigger_var(t.name) .. " = null" end
        local f = {}
        for i, t in ipairs(ts) do f[#f + 1] = triggers.jass(t, i) end
        -- arrays with a size and an initial value, then each trigger made,
        -- then the map-initialization ones run
        local init = { "function EditorInitTriggers takes nothing returns nothing" }
        for _, v in ipairs(vs) do
            if v.array and v.initial ~= nil and v.initial ~= "" then
                local val = v.type == "string" and blocks.quote(v.initial) or tostring(v.initial)
                init[#init + 1] = "    set bj_forLoopAIndex = 0"
                init[#init + 1] = "    loop"
                init[#init + 1] = "        exitwhen bj_forLoopAIndex > " .. tostring(v.size or 1)
                init[#init + 1] = "        set " .. blocks.variable_var(v.name) .. "[bj_forLoopAIndex] = " .. val
                init[#init + 1] = "        set bj_forLoopAIndex = bj_forLoopAIndex + 1"
                init[#init + 1] = "    endloop"
            end
        end
        for _, t in ipairs(ts) do init[#init + 1] = "    call InitTrig_" .. blocks.safe(t.name) .. "()" end
        for _, t in ipairs(ts) do
            if runs_at_init(t) then
                init[#init + 1] = "    call ConditionalTriggerExecute(" .. blocks.trigger_var(t.name) .. ")"
            end
        end
        init[#init + 1] = "endfunction"
        f[#f + 1] = table.concat(init, "\n")
        return { globals = table.concat(g, "\n"), functions = table.concat(f, "\n"), call = "call EditorInitTriggers()" }
    end

    -- put the editor's code into the script text (save.lua calls this)
    function E:insert_trigger_code(text)
        local code = self:trigger_code()
        if not code then return text end
        local B, N = "\n" .. triggers.BEGIN .. "\n", "\n" .. triggers.END .. "\n"
        if code.globals ~= "" then
            local gs = text:find("endglobals", 1, true)
            if gs then
                text = text:sub(1, gs - 1) .. B .. code.globals .. N .. text:sub(gs)
            else
                text = B .. "globals\n" .. code.globals .. "\nendglobals" .. N .. text
            end
        end
        local ms, me = text:find("function%s+main%s+takes%s+nothing%s+returns%s+nothing")
        if not ms then return nil, "the script has no main function" end
        text = text:sub(1, ms - 1) .. B .. code.functions .. N .. text:sub(ms)
        ms, me = text:find("function%s+main%s+takes%s+nothing%s+returns%s+nothing")
        local es = text:find("endfunction", me + 1, true)
        if not es then return nil, "main never ends" end
        text = text:sub(1, es - 1) .. B .. code.call .. N .. text:sub(es)
        return text
    end

    function E:trigger_file()
        if #self.trig.triggers == 0 and #self.trig.variables == 0 and not self.dirty.triggers then return nil end
        return triggers.serialize(self.trig)
    end
    -- }}}

    -- {{{ checking
    local REQUIRED = { region = "a region", trigger = "a trigger", variable = "a variable" }

    function E:check_triggers(opts)
        opts = opts or {}
        local problems = {}
        local function bad(t, msg) problems[#problems + 1] = { trigger = t, message = msg } end
        local region_vars = {}
        for _, r in ipairs(self.regions and self:regions() or {}) do region_vars[r.var] = true end
        local names = {}
        for _, t in ipairs(self.trig.triggers) do
            local safe = blocks.safe(t.name)
            if names[safe] then bad(t, "two triggers are both " .. safe .. " in JASS") end
            names[safe] = true
            if #(t.events or {}) == 0 then bad(t, "no events: it never runs unless another trigger runs it") end
            local function walk(section, list)
                for _, b in ipairs(list or {}) do
                    local spec = blocks.spec(section, b.kind)
                    if not spec then bad(t, "unknown block " .. tostring(b.kind))
                    else
                        for _, p in ipairs(spec.params) do
                            local v, need = b.args[p[1]], REQUIRED[p[2]]
                            if need and v == nil and not (p[2] == "variable" and b.kind == "for_loop") then
                                bad(t, blocks.describe(section, b) .. ": needs " .. need)
                            elseif p[2] == "region" and type(v) == "string" and not region_vars[v] then
                                bad(t, "no region " .. v)
                            elseif p[2] == "trigger" and v ~= nil and type(v) ~= "table" and not self:trigger_named(v) then
                                bad(t, "no trigger " .. tostring(v))
                            elseif p[2] == "variable" and v ~= nil and not self:variable_named(v) then
                                bad(t, "no variable " .. tostring(v))
                            end
                        end
                        for _, hold in ipairs(spec.holds or {}) do walk(hold, b[hold]) end
                    end
                end
            end
            walk("events", t.events)
            walk("conditions", t.conditions)
            walk("actions", t.actions)
        end
        -- the JASS itself, parsed
        local code = self:trigger_code()
        if code then
            local lexer, parser = require("jass.lexer"), require("jass.parser")
            local src = "globals\n" .. code.globals .. "\nendglobals\n" .. code.functions .. "\n"
            local ok, tokens = pcall(lexer.tokenize, src)
            local ast, errs
            if ok then ok, ast, errs = pcall(parser.parse, tokens) end
            if not ok then bad(nil, "JASS: " .. tostring(tokens or ast))
            elseif errs and #errs > 0 then bad(nil, "JASS: " .. tostring(errs[1].message or errs[1])) end
        end
        if opts.full then
            local text, why = self:script_text()
            if not text then bad(nil, why)
            else
                local V = require("jass.vm").new(nil, {})
                local ok, err = V:load(text)
                if not ok then bad(nil, "the script: " .. tostring(err)) end
            end
        end
        return problems
    end
    -- }}}

    -- {{{ the map's own triggers
    function E:map_triggers() return self.map_trigger_list or {} end

    function E:map_function(name)
        local edit = self.map_fn_edits[name]
        for _, f in ipairs(self.script_functions or {}) do
            if f.name == name then
                return edit and edit.text or self.script:sub(f.at, f.to), f.at, f.to
            end
        end
    end

    function E:set_map_function(name, text)
        local old_text, at, to = self:map_function(name)
        if not at then return false, "no function " .. tostring(name) end
        if not text:match("^%s*function%s+" .. name .. "%s+takes") or not text:match("endfunction%s*$") then
            return false, "the text must still be function " .. name .. " ... endfunction"
        end
        local edits, me = self.map_fn_edits, self
        local before = edits[name]
        self.history:run({ name = "Edit function " .. name,
            redo = function() edits[name] = { at = at, to = to, text = text }; me.dirty.script = true end,
            undo = function() edits[name] = before; me.dirty.script = true end })
        return true
    end

    function E:set_map_trigger_on(mt, on)
        local off, me = self.map_trigger_off, self
        local was = off[mt] or false
        self.history:run({ name = (on and "Turn on " or "Turn off ") .. mt.name,
            redo = function() off[mt] = not on or nil; me.dirty.script = true end,
            undo = function() off[mt] = was or nil; me.dirty.script = true end })
        return true
    end

    -- edits to the script's text for the map's triggers (save.lua gathers these)
    function E:map_trigger_edits()
        local out, spans = {}, {}
        for _, e in pairs(self.map_fn_edits or {}) do
            out[#out + 1] = { at = e.at, to = e.to, text = e.text }
            spans[#spans + 1] = e
        end
        for mt in pairs(self.map_trigger_off or {}) do
            for _, c in ipairs(mt.calls) do
                out[#out + 1] = { at = c.at, to = c.to, text = "DoNothing()" }
            end
        end
        return out, spans
    end
    -- }}}
end

-- require("editor.triggers")(E) installs the methods; the table has the helpers
return setmetatable(triggers, { __call = function(_, E) return install(E) end })
