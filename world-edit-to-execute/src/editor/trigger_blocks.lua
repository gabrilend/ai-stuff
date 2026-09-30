--[[
The Trigger Editor's Blocks (Issue 905)

What a trigger made in the editor is built from, as the World Editor's
trigger GUI offers them: events (what starts it), conditions (what must
hold) and actions (what it does, some holding more actions: if / then /
else, loops, units picked in a region). Each block kind has a label, its
parameters (a key, a kind of value, a default) and the JASS it becomes.

A parameter's value is the kind's literal (a number, a text, a player
number from 0, a unit type 'hfoo', a region's variable, a trigger's or a
variable's name, a unit named by role: "triggering", "dying", "killing"
...) or, for any kind, { expr = "JASS expression" }: the World Editor's
"custom script" in one slot. A number where text is wanted, or text where
a number is, is taken as an expression too.

    local blocks = require("editor.trigger_blocks")
    blocks.EVENTS.unit_dies        { label, params, jass = function(a, T, ctx) }
    blocks.CONDITIONS.owner_is     { label, params, jass = function(a, ctx) -> expression }
    blocks.ACTIONS.display_text    { label, params, jass = function(a, ctx) -> lines, holds }
    blocks.value(kind, v, ctx)     a parameter's value as JASS
    blocks.defaults(section, kind) the parameters a new block starts with
    blocks.describe(section, b)    one line for the list ("A unit dies")
]]

local blocks = {}

-- {{{ values
-- units by role, as the World Editor names them
blocks.UNITS = {
    triggering = "GetTriggerUnit()", dying = "GetDyingUnit()", killing = "GetKillingUnit()",
    entering = "GetEnteringUnit()", leaving = "GetLeavingUnit()", last_created = "GetLastCreatedUnit()",
    picked = "GetEnumUnit()", casting = "GetSpellAbilityUnit()", trained = "GetTrainedUnit()",
    constructed = "GetConstructedStructure()", leveling = "GetLevelingUnit()", attacker = "GetAttacker()",
}
blocks.UNIT_ROLES = { "triggering", "dying", "killing", "entering", "leaving", "last_created", "picked",
                      "casting", "trained", "constructed", "leveling", "attacker" }
blocks.COMPARE = { "==", "!=", "<", "<=", ">", ">=" }
blocks.ORDERS = { "move", "attack", "patrol" }
blocks.VAR_TYPES = { "integer", "real", "boolean", "string", "unit", "group", "player", "location", "timer" }

local function quote(s)
    s = tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
    return '"' .. s .. '"'
end
blocks.quote = quote

local function real(v)
    local s = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ".0")
    return s
end

-- the JASS name of a trigger or a variable the editor made
function blocks.safe(name)
    local s = tostring(name or ""):gsub("[^%w_]", "_"):gsub("^_+", ""):gsub("_+$", "")
    if s == "" or s:match("^%d") then s = "T" .. s end
    return s
end
function blocks.trigger_var(name) return "gg_trg_" .. blocks.safe(name) end
function blocks.variable_var(name) return "udg_" .. blocks.safe(name) end

function blocks.value(kind, v, ctx)
    if type(v) == "table" and v.expr then return v.expr end
    if kind == "integer" then
        if type(v) == "number" then return tostring(math.floor(v)) end
        return tostring(v or 0)
    elseif kind == "real" then
        if type(v) == "number" then return real(v) end
        return tostring(v or "0.0")
    elseif kind == "string" then
        return quote(v or "")
    elseif kind == "boolean" then
        if v == nil then return "false" end
        return tostring(v)
    elseif kind == "player" then
        if type(v) == "number" then return "Player(" .. math.floor(v) .. ")" end
        if v == "triggering" then return "GetTriggerPlayer()" end
        if v == "owner" then return "GetOwningPlayer(GetTriggerUnit())" end
        return tostring(v or "Player(0)")
    elseif kind == "force" then
        if v == nil or v == "all" then return "GetPlayersAll()" end
        if type(v) == "number" then return "GetForceOfPlayer(Player(" .. math.floor(v) .. "))" end
        return tostring(v)
    elseif kind == "unit" then
        if blocks.UNITS[v] then return blocks.UNITS[v] end
        if type(v) == "string" and v:match("^var:") then return blocks.variable_var(v:sub(5)) end
        return tostring(v or "null")
    elseif kind == "unit_type" or kind == "ability" then
        if type(v) == "string" and #v == 4 and not v:find("'", 1, true) then return "'" .. v .. "'" end
        return tostring(v or 0)
    elseif kind == "region" then
        return tostring(v or "null")
    elseif kind == "trigger" then
        return blocks.trigger_var(v)
    elseif kind == "variable" then
        return blocks.variable_var(v)
    elseif kind == "compare" or kind == "order" then
        return tostring(v)
    end
    return tostring(v)
end
-- }}}

-- {{{ building templates
-- "call Foo({a}, {b})": {key} is the parameter's value as JASS, {T} the
-- trigger's variable
local function fill(template, params, a, ctx, T)
    local kinds = {}
    for _, p in ipairs(params) do kinds[p[1]] = p[2] end
    return (template:gsub("{([%w_]+)}", function(k)
        if k == "T" then return T or "" end
        return blocks.value(kinds[k], a[k], ctx)
    end))
end
blocks.fill = fill

local function event(label, params, template, extra)
    local b = { label = label, params = params }
    b.jass = function(a, T, ctx) return fill(template, params, a, ctx, T) end
    for k, v in pairs(extra or {}) do b[k] = v end
    return b
end

local function cond(label, params, template)
    return { label = label, params = params, jass = function(a, ctx) return fill(template, params, a, ctx) end }
end

local function act(label, params, template)
    return { label = label, params = params, jass = function(a, ctx) return { fill(template, params, a, ctx) } end }
end

local function any_unit(ev)
    return "call TriggerRegisterAnyUnitEventBJ({T}, " .. ev .. ")"
end
-- }}}

-- {{{ events
blocks.EVENTS = {
    map_init = { label = "Map initialization", params = {}, map_init = true,
                 jass = function() return nil end },
    elapsed = event("Elapsed game time is {seconds} seconds", { { "seconds", "real", 5 } },
        "call TriggerRegisterTimerEventSingle({T}, {seconds})"),
    periodic = event("Every {seconds} seconds of game time", { { "seconds", "real", 2 } },
        "call TriggerRegisterTimerEventPeriodic({T}, {seconds})"),
    unit_dies = event("A unit dies", {}, any_unit("EVENT_PLAYER_UNIT_DEATH")),
    unit_attacked = event("A unit is attacked", {}, any_unit("EVENT_PLAYER_UNIT_ATTACKED")),
    enters_region = event("A unit enters {region}", { { "region", "region", nil } },
        "call TriggerRegisterEnterRectSimple({T}, {region})"),
    leaves_region = event("A unit leaves {region}", { { "region", "region", nil } },
        "call TriggerRegisterLeaveRectSimple({T}, {region})"),
    player_chat = event("{player} types a chat message containing {text}",
        { { "player", "player", 0 }, { "text", "string", "-go" }, { "exact", "boolean", true } },
        "call TriggerRegisterPlayerChatEvent({T}, {player}, {text}, {exact})"),
    spell_effect = event("A unit starts the effect of an ability", {}, any_unit("EVENT_PLAYER_UNIT_SPELL_EFFECT")),
    unit_trained = event("A unit finishes training a unit", {}, any_unit("EVENT_PLAYER_UNIT_TRAIN_FINISH")),
    construct_finish = event("A unit finishes construction", {}, any_unit("EVENT_PLAYER_UNIT_CONSTRUCT_FINISH")),
    hero_level = event("A hero gains a level", {}, any_unit("EVENT_PLAYER_HERO_LEVEL")),
    custom = { label = "Custom: {code}", params = { { "code", "code", "" } },
               jass = function(a, T) return (tostring(a.code or ""):gsub("{T}", T)) end },
}
blocks.EVENT_ORDER = { "map_init", "elapsed", "periodic", "unit_dies", "unit_attacked", "enters_region",
                       "leaves_region", "player_chat", "spell_effect", "unit_trained", "construct_finish",
                       "hero_level", "custom" }
-- }}}

-- {{{ conditions: each a boolean expression
blocks.CONDITIONS = {
    unit_type_is = cond("Unit-type of {unit} is {unit_type}", { { "unit", "unit", "triggering" }, { "unit_type", "unit_type", "hfoo" } },
        "GetUnitTypeId({unit}) == {unit_type}"),
    owner_is = cond("{unit} belongs to {player}", { { "unit", "unit", "triggering" }, { "player", "player", 0 } },
        "GetOwningPlayer({unit}) == {player}"),
    is_hero = cond("{unit} is a hero", { { "unit", "unit", "triggering" } },
        "IsUnitType({unit}, UNIT_TYPE_HERO)"),
    is_alive = cond("{unit} is alive", { { "unit", "unit", "triggering" } },
        "GetWidgetLife({unit}) > 0.405"),
    ability_is = cond("Ability being cast is {ability}", { { "ability", "ability", "AHbz" } },
        "GetSpellAbilityId() == {ability}"),
    gold_compare = cond("{player}'s gold {compare} {value}",
        { { "player", "player", 0 }, { "compare", "compare", ">=" }, { "value", "integer", 100 } },
        "GetPlayerState({player}, PLAYER_STATE_RESOURCE_GOLD) {compare} {value}"),
    integer_compare = cond("{a} {compare} {b}", { { "a", "integer", 0 }, { "compare", "compare", "==" }, { "b", "integer", 0 } },
        "{a} {compare} {b}"),
    real_compare = cond("{a} {compare} {b}", { { "a", "real", 0 }, { "compare", "compare", "==" }, { "b", "real", 0 } },
        "{a} {compare} {b}"),
    boolean_is = cond("{a} is {b}", { { "a", "boolean", true }, { "b", "boolean", true } }, "{a} == {b}"),
    custom = { label = "Custom: {code}", params = { { "code", "code", "true" } },
               jass = function(a) return tostring(a.code or "true") end },
}
blocks.CONDITION_ORDER = { "unit_type_is", "owner_is", "is_hero", "is_alive", "ability_is", "gold_compare",
                           "integer_compare", "real_compare", "boolean_is", "custom" }
-- }}}

-- {{{ actions: each some lines of JASS; control actions hold more
local function adjust(state, what)
    return function(a, ctx)
        local P, v = blocks.value("player", a.player, ctx), blocks.value("integer", a.value, ctx)
        if a.op == "add" then return { "call AdjustPlayerStateBJ(" .. v .. ", " .. P .. ", " .. state .. ")" } end
        return { "call SetPlayerStateBJ(" .. P .. ", " .. state .. ", " .. v .. ")" }
    end
end

blocks.ACTIONS = {
    display_text = act("Show {text} to {force} for {seconds} seconds",
        { { "force", "force", "all" }, { "text", "string", "Hello" }, { "seconds", "real", 10 } },
        "call DisplayTimedTextToForce({force}, {seconds}, {text})"),
    create_units = { label = "Create {count} {unit_type} for {player} at {region}",
        params = { { "count", "integer", 1 }, { "unit_type", "unit_type", "hfoo" }, { "player", "player", 0 },
                   { "region", "region", nil }, { "facing", "real", 270 } },
        jass = function(a, ctx)
            local V = blocks.value
            return { "call CreateNUnitsAtLoc(" .. V("integer", a.count) .. ", " .. V("unit_type", a.unit_type) .. ", "
                     .. V("player", a.player) .. ", GetRectCenter(" .. V("region", a.region) .. "), "
                     .. V("real", a.facing) .. ")" }
        end },
    kill_unit = act("Kill {unit}", { { "unit", "unit", "triggering" } }, "call KillUnit({unit})"),
    remove_unit = act("Remove {unit} from the game", { { "unit", "unit", "triggering" } }, "call RemoveUnit({unit})"),
    move_unit = act("Move {unit} instantly to {region}", { { "unit", "unit", "triggering" }, { "region", "region", nil } },
        "call SetUnitPosition({unit}, GetRectCenterX({region}), GetRectCenterY({region}))"),
    order_unit = act("Order {unit} to {order} to {region}",
        { { "unit", "unit", "triggering" }, { "order", "string", "attack" }, { "region", "region", nil } },
        "call IssuePointOrder({unit}, {order}, GetRectCenterX({region}), GetRectCenterY({region}))"),
    gold = { label = "Player - {op} {player}'s gold: {value}",
        params = { { "player", "player", 0 }, { "op", "op", "add" }, { "value", "integer", 100 } },
        jass = adjust("PLAYER_STATE_RESOURCE_GOLD") },
    lumber = { label = "Player - {op} {player}'s lumber: {value}",
        params = { { "player", "player", 0 }, { "op", "op", "add" }, { "value", "integer", 100 } },
        jass = adjust("PLAYER_STATE_RESOURCE_LUMBER") },
    set_variable = { label = "Set {variable} = {value}",
        params = { { "variable", "variable", nil }, { "value", "expr", "0" }, { "index", "expr", nil } },
        jass = function(a)
            local target = blocks.variable_var(a.variable)
            if a.index ~= nil and a.index ~= "" then target = target .. "[" .. blocks.value("integer", a.index) .. "]" end
            local v = a.value
            if type(v) == "table" and v.expr then v = v.expr end
            return { "set " .. target .. " = " .. tostring(v) }
        end },
    victory = act("Victory {player}", { { "player", "player", 0 } }, "call CustomVictoryBJ({player}, true, true)"),
    defeat = act("Defeat {player} with {text}", { { "player", "player", 0 }, { "text", "string", "Defeat!" } },
        "call CustomDefeatBJ({player}, {text})"),
    wait = act("Wait {seconds} seconds", { { "seconds", "real", 1 } }, "call TriggerSleepAction({seconds})"),
    enable_trigger = act("Turn on {trigger}", { { "trigger", "trigger", nil } }, "call EnableTrigger({trigger})"),
    disable_trigger = act("Turn off {trigger}", { { "trigger", "trigger", nil } }, "call DisableTrigger({trigger})"),
    run_trigger = act("Run {trigger} (checking conditions)", { { "trigger", "trigger", nil } },
        "call ConditionalTriggerExecute({trigger})"),
    comment = { label = "-- {text}", params = { { "text", "text", "" } },
                jass = function(a) return { "// " .. tostring(a.text or ""):gsub("\n", " ") } end },
    custom = { label = "Custom script: {code}", params = { { "code", "code", "" } },
               jass = function(a)
                   local out = {}
                   for line in (tostring(a.code or "") .. "\n"):gmatch("(.-)\n") do out[#out + 1] = line end
                   return out
               end },

    -- control: these hold actions, built by editor/triggers.lua
    if_then_else = { label = "If (conditions) then (actions) else (actions)", params = {},
                     holds = { "if_conditions", "then_actions", "else_actions" } },
    for_loop = { label = "For each {variable} from {from} to {to}, do (actions)",
                 params = { { "variable", "variable", nil }, { "from", "integer", 1 }, { "to", "integer", 10 } },
                 holds = { "loop_actions" } },
    pick_units = { label = "Pick every unit in {region} and do (actions)", params = { { "region", "region", nil } },
                   holds = { "loop_actions" } },
}
blocks.ACTION_ORDER = { "display_text", "create_units", "kill_unit", "remove_unit", "move_unit", "order_unit",
                        "gold", "lumber", "set_variable", "victory", "defeat", "wait", "enable_trigger",
                        "disable_trigger", "run_trigger", "if_then_else", "for_loop", "pick_units", "comment",
                        "custom" }
-- }}}

-- {{{ helpers
blocks.SECTIONS = { events = blocks.EVENTS, conditions = blocks.CONDITIONS, actions = blocks.ACTIONS,
                    if_conditions = blocks.CONDITIONS, then_actions = blocks.ACTIONS,
                    else_actions = blocks.ACTIONS, loop_actions = blocks.ACTIONS }
blocks.ORDER = { events = blocks.EVENT_ORDER, conditions = blocks.CONDITION_ORDER, actions = blocks.ACTION_ORDER,
                 if_conditions = blocks.CONDITION_ORDER, then_actions = blocks.ACTION_ORDER,
                 else_actions = blocks.ACTION_ORDER, loop_actions = blocks.ACTION_ORDER }

function blocks.spec(section, kind)
    local t = blocks.SECTIONS[section]
    return t and t[kind]
end

function blocks.defaults(section, kind)
    local spec = blocks.spec(section, kind)
    if not spec then return nil end
    local a = {}
    for _, p in ipairs(spec.params) do a[p[1]] = p[3] end
    return a
end

local function shown(v)
    if type(v) == "table" and v.expr then return v.expr end
    if v == nil then return "(none)" end
    return tostring(v)
end

function blocks.describe(section, b)
    local spec = blocks.spec(section, b.kind)
    if not spec then return "?" .. tostring(b.kind) end
    local kinds = {}
    for _, p in ipairs(spec.params) do kinds[p[1]] = p[2] end
    return (spec.label:gsub("{([%w_]+)}", function(k)
        local v = b.args[k]
        if kinds[k] == "player" and type(v) == "number" then return "Player " .. (v + 1) end
        if kinds[k] == "string" and type(v) == "string" then return '"' .. v .. '"' end
        if kinds[k] == "region" and type(v) == "string" then return (v:gsub("^gg_rct_", "")) end
        return shown(v)
    end))
end
-- }}}

return blocks
