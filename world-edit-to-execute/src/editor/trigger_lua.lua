--[[
Triggers as Lua (Issue 905b)

The editor's triggers (editor/triggers.lua) written as Lua, one to one
with their blocks, and read back: the blocks and this text are two views
of one trigger, and editing either changes it. The JASS saved into the
map (the third view, read only) is made from the blocks.

    trigger "Count deaths" {
        category = "Combat",
        on = true,
        events = {
            unit_dies {},
        },
        conditions = {
            unit_type_is { unit = "dying", unit_type = "hfoo" },
        },
        actions = {
            if_then_else {
                if_conditions = { owner_is { unit = "dying", player = 0 } },
                then_actions = { set_variable { variable = "Deaths", value = "udg_Deaths + 1" } },
            },
            "call DoNothing()",          -- a string: kept as custom script
            display_text { text = "Gold: ", seconds = expr "udg_Gold * 1.0" },
        },
    }

    variable "Deaths" { type = "integer", initial = 0 }

A block is its kind (editor/trigger_blocks.lua) called with its
parameters; a control block's parts (if_conditions, then_actions,
else_actions, loop_actions) are lists of blocks. expr "..." is a JASS
expression in any slot. A string where an action (or event, or
condition) goes is custom script. What isn't one of these is an error
with its line, for the code view to mark.

The text runs as data: no globals but these, and a limit on how long it
may run.

    local tl = require("editor.trigger_lua")
    local text = tl.to_lua(trigger)                   -- one trigger
    local t, err, line = tl.from_lua(text)            -- back: a trigger, or why and where
    local all = tl.to_lua_all(triggers, variables)    -- the whole set
    local ts, vs, err, line = tl.from_lua_all(text)
    tl.words()                                        -- what autocomplete offers
]]

local blocks = require("editor.trigger_blocks")

local tl = {}

local HOLDS = { if_conditions = true, then_actions = true, else_actions = true, loop_actions = true }
local SECTION_OF = { events = "events", conditions = "conditions", actions = "actions" }

-- {{{ writing
local function value(v)
    local t = type(v)
    if t == "table" and v.expr then return "expr " .. string.format("%q", v.expr) end
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
        return string.format("%.17g", v)
    end
    if t == "boolean" then return tostring(v) end
    return "nil"
end

local function key(k)
    if k:match("^[%a_][%w_]*$") then return k end
    return "[" .. string.format("%q", k) .. "]"
end

local function write_block(section, b, ind, out)
    local spec = blocks.spec(section, b.kind)
    -- custom script: a string of its own
    if b.kind == "custom" and spec and section ~= "events" then
        local code = tostring(b.args.code or "")
        out[#out + 1] = ind .. string.format("%q", code):gsub("\\\n", "\\n") .. ","
        return
    end
    local parts = {}
    -- the parameters in the catalog's order, then any others
    local seen = {}
    for _, p in ipairs(spec and spec.params or {}) do
        local v = b.args[p[1]]
        seen[p[1]] = true
        if v ~= nil then parts[#parts + 1] = key(p[1]) .. " = " .. value(v) end
    end
    local extra = {}
    for k in pairs(b.args or {}) do if not seen[k] then extra[#extra + 1] = k end end
    table.sort(extra)
    for _, k in ipairs(extra) do parts[#parts + 1] = key(k) .. " = " .. value(b.args[k]) end
    local holds = spec and spec.holds or {}
    if #holds == 0 then
        out[#out + 1] = ind .. b.kind .. " { " .. table.concat(parts, ", ") .. (#parts > 0 and " }," or "},")
        return
    end
    out[#out + 1] = ind .. b.kind .. " {"
    for _, p in ipairs(parts) do out[#out + 1] = ind .. "    " .. p .. "," end
    for _, h in ipairs(holds) do
        local list = b[h] or {}
        if #list == 0 then
            out[#out + 1] = ind .. "    " .. h .. " = {},"
        else
            out[#out + 1] = ind .. "    " .. h .. " = {"
            for _, sub in ipairs(list) do write_block(h, sub, ind .. "        ", out) end
            out[#out + 1] = ind .. "    },"
        end
    end
    out[#out + 1] = ind .. "},"
end

local function write_trigger(t, out)
    out[#out + 1] = "trigger " .. string.format("%q", t.name) .. " {"
    if t.category and t.category ~= "Triggers" then out[#out + 1] = "    category = " .. string.format("%q", t.category) .. "," end
    out[#out + 1] = "    on = " .. tostring(t.on ~= false) .. ","
    if t.comment and t.comment ~= "" then out[#out + 1] = "    comment = " .. string.format("%q", t.comment) .. "," end
    for _, s in ipairs({ "events", "conditions", "actions" }) do
        local list = t[s] or {}
        if #list == 0 then
            out[#out + 1] = "    " .. s .. " = {},"
        else
            out[#out + 1] = "    " .. s .. " = {"
            for _, b in ipairs(list) do write_block(s, b, "        ", out) end
            out[#out + 1] = "    },"
        end
    end
    out[#out + 1] = "}"
end

function tl.to_lua(t)
    local out = {}
    write_trigger(t, out)
    return table.concat(out, "\n") .. "\n"
end

function tl.to_lua_all(triggers, variables)
    local out = { "-- The map's triggers, as Lua (world-edit-to-execute, issue 905b)", "" }
    for _, v in ipairs(variables or {}) do
        local parts = { "type = " .. value(v.type or "integer") }
        if v.initial ~= nil then parts[#parts + 1] = "initial = " .. value(v.initial) end
        if v.array then parts[#parts + 1] = "array = true" end
        if v.size then parts[#parts + 1] = "size = " .. value(v.size) end
        out[#out + 1] = "variable " .. string.format("%q", v.name) .. " { " .. table.concat(parts, ", ") .. " }"
    end
    if #(variables or {}) > 0 then out[#out + 1] = "" end
    for _, t in ipairs(triggers or {}) do
        write_trigger(t, out)
        out[#out + 1] = ""
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ reading
local LIMIT = 200000       -- Lua instructions the text may take

-- a made block remembers the line that made it (for errors)
local function caller_line()
    local info = debug.getinfo(3, "l")
    return info and info.currentline or nil
end

local Block = {}           -- the metatable marking made blocks

local function run(text, name)
    local chunk, err = loadstring(text, "=" .. (name or "triggers"))
    if not chunk then
        local line = tonumber(tostring(err):match(":(%d+):"))
        return nil, tostring(err):gsub("^[^:]*:%d+: ", ""), line
    end
    local made = { triggers = {}, variables = {} }
    local env = {}
    env.expr = function(s)
        if type(s) ~= "string" then error("expr takes a text of JASS", 2) end
        return { expr = s }
    end
    env.trigger = function(tname)
        local line = caller_line()
        if type(tname) ~= "string" then error("trigger takes its name, then { ... }", 2) end
        return function(body)
            if type(body) ~= "table" then error("trigger " .. tname .. ": { ... } expected", 2) end
            made.triggers[#made.triggers + 1] = { name = tname, body = body, line = line }
        end
    end
    env.variable = function(vname)
        local line = caller_line()
        if type(vname) ~= "string" then error("variable takes its name, then { ... }", 2) end
        return function(body)
            made.variables[#made.variables + 1] = { name = vname, body = body or {}, line = line }
        end
    end
    -- any other name is a block kind (checked once it's placed)
    setmetatable(env, { __index = function(_, kind)
        if type(kind) ~= "string" then return nil end
        return function(args)
            local line = caller_line()
            if args ~= nil and type(args) ~= "table" then error(kind .. " takes { ... }", 2) end
            return setmetatable({ kind = kind, fields = args or {}, line = line }, Block)
        end
    end, __newindex = function(_, k) error("the triggers' text can't set " .. tostring(k), 2) end })
    setfenv(chunk, env)
    -- interpreted, so the instruction limit below is heard (LuaJIT's
    -- compiled loops don't call hooks)
    if jit then jit.off(chunk, true) end
    local count, stopped_at = 0, nil
    debug.sethook(function()
        count = count + 1
        if count * 1000 > LIMIT then
            local info = debug.getinfo(2, "l")
            stopped_at = info and info.currentline
            error("the text runs too long (a loop?)", 0)
        end
    end, "", 1000)
    local ok, rerr = pcall(chunk)
    debug.sethook()
    if not ok then
        local line = stopped_at or tonumber(tostring(rerr):match(":(%d+):"))
        local msg = tostring(rerr):gsub("^[^:]*:%d+: ", "")
        -- a library call (os.exit, string.rep ...): nothing but blocks here
        local lib = msg:match("attempt to index global '([%w_]+)'")
        if lib then msg = lib .. " isn't known here: the text holds triggers, variables and blocks" end
        return nil, msg, line
    end
    return made
end

-- a made block (or a string: custom script) into the editor's block, for section
local function to_block(section, item, where)
    if type(item) == "string" then
        if section == "events" then return nil, "an event can't be custom script (use custom { code = ... })", where end
        return { kind = "custom", args = { code = item } }
    end
    if getmetatable(item) ~= Block then
        return nil, "in " .. section .. ": a block (a kind with { ... }) or a string of JASS expected", where
    end
    local spec = blocks.spec(section, item.kind)
    if not spec then
        local list = {}
        for _, k in ipairs(blocks.ORDER[section] or {}) do list[#list + 1] = k end
        return nil, string.format("%s isn't one of the %s (%s)", item.kind, section:gsub("_", " "),
            table.concat(list, ", ")), item.line
    end
    local b = { kind = item.kind, args = blocks.defaults(section, item.kind) }
    local holds = {}
    for _, h in ipairs(spec.holds or {}) do holds[h] = true end
    for k, v in pairs(item.fields) do
        if holds[k] then
            if type(v) ~= "table" then return nil, item.kind .. "." .. k .. ": a list of blocks expected", item.line end
            local list = {}
            for i, sub in ipairs(v) do
                local sb, err, line = to_block(k, sub, item.line)
                if not sb then return nil, err, line end
                list[i] = sb
            end
            b[k] = list
        elseif HOLDS[k] then
            return nil, item.kind .. " has no " .. k, item.line
        else
            if type(v) == "table" and not v.expr then return nil, item.kind .. "." .. tostring(k) .. ": a value expected", item.line end
            b.args[k] = v
        end
    end
    for h in pairs(holds) do b[h] = b[h] or {} end
    return b
end

local function to_trigger(m)
    local body = m.body
    local t = { name = m.name, category = body.category or "Triggers", on = body.on ~= false, comment = body.comment,
                events = {}, conditions = {}, actions = {} }
    for k in pairs(body) do
        if not (SECTION_OF[k] or k == "category" or k == "on" or k == "comment") then
            return nil, "trigger " .. m.name .. " has no " .. tostring(k), m.line
        end
    end
    for s in pairs(SECTION_OF) do
        local list = body[s] or {}
        if type(list) ~= "table" or getmetatable(list) == Block then
            return nil, "trigger " .. m.name .. ": " .. s .. " = { ... } expected", m.line
        end
        for i, item in ipairs(list) do
            local b, err, line = to_block(s, item, m.line)
            if not b then return nil, err, line end
            t[s][i] = b
        end
    end
    return t
end

-- one trigger's text: the trigger, or nil, why and the line
function tl.from_lua(text)
    local made, err, line = run(text, "trigger")
    if not made then return nil, err, line end
    if #made.triggers ~= 1 or #made.variables > 0 then
        return nil, "one trigger \"name\" { ... } expected (found " .. #made.triggers .. ")", 1
    end
    return to_trigger(made.triggers[1])
end

-- the whole set: triggers, variables; or nil, nil, why, line
function tl.from_lua_all(text)
    local made, err, line = run(text, "triggers")
    if not made then return nil, nil, err, line end
    local ts, vs, names = {}, {}, {}
    for i, m in ipairs(made.triggers) do
        if names[m.name] then return nil, nil, "two triggers are called " .. m.name, m.line end
        names[m.name] = true
        local t, terr, tline = to_trigger(m)
        if not t then return nil, nil, terr, tline end
        ts[i] = t
    end
    for i, m in ipairs(made.variables) do
        local b = m.body
        vs[i] = { name = m.name, type = b.type or "integer", initial = b.initial, array = b.array or nil, size = b.size }
    end
    return ts, vs
end
-- }}}

-- {{{ what autocomplete offers
function tl.words(extra)
    local seen, out = {}, {}
    local function add(w) if w and not seen[w] then seen[w] = true; out[#out + 1] = w end end
    for _, w in ipairs({ "trigger", "variable", "expr", "events", "conditions", "actions", "category", "true", "false" }) do add(w) end
    for h in pairs(HOLDS) do add(h) end
    for _, order in pairs(blocks.ORDER) do
        for _, kind in ipairs(order) do
            add(kind)
            for _, sec in ipairs({ "events", "conditions", "actions" }) do
                local spec = blocks.spec(sec, kind)
                for _, p in ipairs(spec and spec.params or {}) do add(p[1]) end
            end
        end
    end
    for _, r in ipairs(blocks.UNIT_ROLES) do add(r) end
    for _, w in ipairs(extra or {}) do add(w) end
    table.sort(out)
    return out
end
-- }}}

return tl
