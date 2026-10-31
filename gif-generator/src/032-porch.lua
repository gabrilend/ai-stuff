-- 032-porch.lua — the listening porch: prose in, a candidate score
-- out, by way of a small local model that paints in tool-calls.
--
-- What this is, generally: the translator is a CLIENT of the
-- pipeline, never a component of it. It builds its prompt from the
-- score-format contract and the shipped reference scores (one truth,
-- never rewritten for the model's benefit), constrains the model
-- with a grammar GENERATED from the same vocabulary tables the
-- validator trusts (misspelling becomes physically impossible — the
-- model's whole freedom is choosing among legal readings), collects
-- the arriving stroke tool-calls in time order with the walk-back
-- insertion, writes a canonical score with the person's sentences
-- riding as comments, and submits it to the same wall as everyone.
-- Wall errors are quoted back verbatim for a bounded number of
-- retries; still failing, the errors surface WITH the draft.
--
-- Transport is a handed-in function (the orchestrator's door — see
-- input/cluster.example). Tests hand in fakes; the live HTTP
-- adapter joins when the cluster lights. "there will be an
-- orchestrator" — the cluster's shape is its business, not ours.
--
-- Since issue 704 the porch hears both spaces: besides canvas and
-- stroke, the model may call shape, camera, world and pane, whose
-- words come from the 3D wall's own lists (048-shape-words.lua), read
-- here the moment the grammar is asked for, so a word added there is a
-- word the model may say. Every reading is said back in plain lines
-- (059-say-back.lua), written from the calls and not by the model, so a
-- person checks what was heard without reading Lua; the lines head the
-- score as comments.

local DKJSON_PATH = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;"

local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local palette = require("002-palette")
local emit = require("008-emit")
local easing = require("016-easing")
local score = require("022-score")
local compile = require("024-compile")
local sayback = dofile(HERE .. "059-say-back.lua")

package.path = DKJSON_PATH .. package.path
local json = require("dkjson")

local porch = {}

-- Bounded patience: how many times the wall's teaching is quoted
-- back before the errors surface to the person with the draft.
local TRIES = 3

-- {{{ local function sorted_words()
local function sorted_words(tbl)
    local list = {}
    for k in pairs(tbl) do list[#list + 1] = k end
    table.sort(list)
    return list
end
-- }}}

-- {{{ local function alternation()
-- legal words as a GBNF alternation: "\"ember\"" | "\"gold\"" ...
local function alternation(words)
    local parts = {}
    for _, w in ipairs(words) do
        parts[#parts + 1] = '"\\"' .. w .. '\\""'
    end
    return table.concat(parts, " | ")
end
-- }}}

-- {{{ local function gbnf_name()
-- A word as a GBNF rule name: llama.cpp takes letters, digits and dashes.
local function gbnf_name(prefix, word)
    return prefix .. "-" .. word:gsub("_", "-")
end
-- }}}

-- {{{ local function key()
-- A JSON key as GBNF: "\"word\"" ws ":" ws
local function key(word)
    return '"\\"' .. word .. '\\"" ws ":" ws'
end
-- }}}

-- {{{ local function three_d_rules()
-- The 3D half of the grammar, from the 3D wall's word lists: one rule
-- per context (a table of words in any order), one per motion kind and
-- camera motion kind (whose `kind` picks its words), and the runtime's
-- names as alternations. Every kind a word list names must be known
-- here, so the lists cannot grow a kind the model cannot say.
local function three_d_rules(rule)
    local words = dofile(HERE .. "048-shape-words.lua")
    local meshes = dofile(HERE .. "034-meshes.lua")
    local owned = dofile(HERE .. "035-choreography.lua").vocabulary()
    local compile = require("024-compile")
    local hues = {}
    for i, h in ipairs(compile.HOUSE_HUES) do hues[i] = h end
    hues[#hues + 1] = "cloud"
    table.sort(hues)

    local mesh_words, seen = {}, {}
    for _, list in pairs(words.MESH_PARAMS) do
        for _, entry in ipairs(list) do
            if not seen[entry[1]] then
                seen[entry[1]] = true
                mesh_words[#mesh_words + 1] = { entry[1], "value" }
            end
        end
    end
    table.sort(mesh_words, function(a, b) return a[1] < b[1] end)

    -- what each kind of value is, as a GBNF body
    local KIND = {
        value = "value", tag = "string", ref = "string",
        refs = '"[" ws (string (ws "," ws string)*)? ws "]"',
        hue = "hue3", hues = '"[" ws hue3 (ws "," ws hue3)* ws "]"',
        mesh = "mesh", mesh_params = "ctx-mesh-params",
        style = alternation(words.STYLES), shards = alternation(words.SHARDS),
        effect = alternation(owned.effects),
        solids = '"[" ws solid (ws "," ws solid)* ws "]"',
        motion = "motion", camera_motion = "camera-motion",
        route_point = "routepoint",
        route_points = '"[" ws routepoint (ws "," ws routepoint)* ws "]"',
        target = 'value | "\\"ahead\\""',
        roll_or_false = 'ctx-roll | "false"',
        place = alternation({ "back", "front", "world" }),
    }
    -- {{{ local function body_of()
    local function body_of(kind, where)
        if type(kind) == "table" then
            return '"[" ws ' .. gbnf_name("ctx", kind.list) .. " (ws \",\" ws "
                   .. gbnf_name("ctx", kind.list) .. ')* ws "]"'
        end
        -- a choice is held in parentheses, so the key before it is part
        -- of every branch
        if KIND[kind] then return "(" .. KIND[kind] .. ")" end
        if words.CONTEXTS[kind] then return gbnf_name("ctx", kind) end
        error("porch: the word list names a kind '" .. tostring(kind) .. "' (at " .. where
              .. ") the porch cannot say; teach it in three_d_rules()")
    end
    -- }}}
    -- {{{ local function table_rule()
    -- A table of `entries` as one rule: `head` first (a fixed opening such
    -- as the tool or the kind), then any of the words, in any order.
    local function table_rule(name, entries, head, where)
        local members = {}
        for _, entry in ipairs(entries) do
            members[#members + 1] = "(" .. key(entry[1]) .. " " .. body_of(entry[2], where .. "." .. entry[1]) .. ")"
        end
        local member = name .. "-word"
        if #members == 0 then
            rule(name, '"{" ws ' .. (head and (head .. " ") or "") .. 'ws "}"')
            return
        end
        rule(member, table.concat(members, " | "))
        if head then
            rule(name, '"{" ws ' .. head .. ' (ws "," ws ' .. member .. ')* ws "}"')
        else
            rule(name, '"{" ws (' .. member .. ' (ws "," ws ' .. member .. ')*)? ws "}"')
        end
    end
    -- }}}

    for _, name in ipairs(words.ORDER) do
        if name ~= "scene" then
            table_rule(gbnf_name("ctx", name), words.CONTEXTS[name], nil, name)
        end
    end
    table_rule("ctx-mesh-params", mesh_words, nil, "mesh_params")

    -- motions: the kind first, then its own words and the common ones
    -- {{{ local function kinds_rule()
    local function kinds_rule(name, prefix, kinds, common)
        local names = {}
        for kind in pairs(kinds) do names[#names + 1] = kind end
        table.sort(names)
        local alts = {}
        for _, kind in ipairs(names) do
            local entries = {}
            for _, e in ipairs(kinds[kind]) do entries[#entries + 1] = e end
            for _, e in ipairs(common or {}) do entries[#entries + 1] = e end
            local rname = gbnf_name(prefix, kind)
            table_rule(rname, entries, key("kind") .. ' "\\"' .. kind .. '\\""', prefix .. "." .. kind)
            alts[#alts + 1] = rname
        end
        rule(name, table.concat(alts, " | "))
    end
    -- }}}
    kinds_rule("motion", "motion", words.MOTIONS, words.MOTION_COMMON)
    kinds_rule("camera-motion", "camera-motion", words.CAMERA_MOTIONS)

    -- the calls: a shape is one scene instance; the camera is the scene's
    -- camera; the world is the rest of the scene's words; a pane is glass
    -- {{{ local function tool()
    local function tool(name) return key("tool") .. ' "\\"' .. name .. '\\""' end
    -- }}}
    -- each call may carry the person's sentence, as a stroke does
    -- {{{ local function with_prose()
    local function with_prose(entries)
        local list = {}
        for _, e in ipairs(entries) do list[#list + 1] = e end
        list[#list + 1] = { "prose", "tag" }
        return list
    end
    -- }}}
    table_rule("shapecall", with_prose(words.CONTEXTS.instance), tool("shape"), "shape")
    table_rule("cameracall", with_prose(words.CONTEXTS.camera), tool("camera"), "camera")
    local world = {}
    for _, entry in ipairs(words.CONTEXTS.scene) do
        if not compile.SAID_ELSEWHERE[entry[1]] then world[#world + 1] = entry end
    end
    world = with_prose(world)
    table_rule("worldcall", world, tool("world"), "world")
    table_rule("panecall", {
        { "name", "tag" }, { "place", "place" }, { "at", "value" },
        { "facing", "value" }, { "size", "value" }, { "pixels", "value" },
        { "prose", "tag" },
    }, tool("pane"), "pane")

    rule("hue3", alternation(hues))
    rule("mesh", alternation(meshes.names()))
    rule("solid", alternation(owned.solids))
    rule("routepoint", 'value | "{" ws ' .. key("part") .. ' string ws "," ws '
         .. key("plus") .. ' value ws "}"')
    rule("value", 'number | "true" | "false" | string | "[" ws (value (ws "," ws value)*)? ws "]"')
end
-- }}}

-- {{{ function porch.grammar()
-- The GBNF the model lives inside, generated from the vocabulary
-- tables — never hand-maintained, so a word added to a table is a
-- word the model may speak, automatically. Times are structurally
-- tenths: an integer with at most one decimal digit.
function porch.grammar()
    local g = {}
    -- {{{ local function rule()
    local function rule(name, body)
        g[#g + 1] = name .. " ::= " .. body
    end
    -- }}}
    rule("root", "call (ws call)*")
    rule("call", "canvascall | strokecall | shapecall | cameracall | worldcall | panecall")
    rule("canvascall",
         '"{" ws "\\"tool\\"" ws ":" ws "\\"canvas\\"" ws '
         .. '"," ws "\\"size\\"" ws ":" ws int '
         .. '"," ws "\\"fps\\"" ws ":" ws int '
         .. '"," ws ("\\"length\\"" ws ":" ws tenths | "\\"frames\\"" ws ":" ws int) '
         .. '"," ws "\\"seed\\"" ws ":" ws int '
         .. '("," ws "\\"background\\"" ws ":" ws background)? ws "}"')
    rule("background", alternation({ "black", "sky" }) .. " | hue")
    rule("strokecall",
         '"{" ws "\\"tool\\"" ws ":" ws "\\"stroke\\"" '
         .. '("," ws "\\"name\\"" ws ":" ws string)? '
         .. '("," ws "\\"pane\\"" ws ":" ws string)? '
         .. '"," ws "\\"at\\"" ws ":" ws tenths '
         .. '"," ws "\\"lasts\\"" ws ":" ws tenths '
         .. '"," ws "\\"color\\"" ws ":" ws hue '
         .. '"," ws "\\"fade\\"" ws ":" ws fade '
         .. '("," ws "\\"ease\\"" ws ":" ws ease)? '
         .. '"," ws "\\"shape\\"" ws ":" ws shape '
         .. '("," ws "\\"emit\\"" ws ":" ws emitblock)? '
         .. '("," ws "\\"prose\\"" ws ":" ws string)? ws "}"')
    rule("hue", alternation(sorted_words(palette.hues)))
    rule("fade", alternation(sorted_words(easing.ENVELOPES)))
    rule("ease", alternation(sorted_words(easing.EASINGS)))
    rule("emitfield", alternation(sorted_words(emit.DEFAULTS)))
    rule("shape", "arcshape | lineshape | pointshape | fillshape")
    rule("arcshape",
         '"{" ws "\\"kind\\"" ws ":" ws "\\"arc\\"" '
         .. '"," ws "\\"center\\"" ws ":" ws pair '
         .. '"," ws "\\"radius\\"" ws ":" ws int '
         .. '"," ws "\\"from\\"" ws ":" ws hour '
         .. '"," ws "\\"to\\"" ws ":" ws hour '
         .. '"," ws "\\"turn\\"" ws ":" ws turn ws "}"')
    rule("lineshape",
         '"{" ws "\\"kind\\"" ws ":" ws "\\"line\\"" '
         .. '"," ws "\\"from\\"" ws ":" ws anchor '
         .. '"," ws "\\"to\\"" ws ":" ws anchor ws "}"')
    rule("pointshape",
         '"{" ws "\\"kind\\"" ws ":" ws "\\"point\\"" '
         .. '"," ws "\\"at\\"" ws ":" ws anchor ws "}"')
    rule("fillshape",
         '"{" ws "\\"kind\\"" ws ":" ws "\\"fill\\"" '
         .. '"," ws "\\"vertices\\"" ws ":" ws '
         .. '"[" ws anchor (ws "," ws anchor)* ws "]" '
         .. '"," ws "\\"sweep\\"" ws ":" ws sweep ws "}"')
    rule("turn", '"\\"clockwise\\"" | "\\"counterclockwise\\""')
    rule("sweep", '"\\"at-once\\"" | "\\"downward\\"" | '
                  .. '"\\"radial\\"" | "\\"along\\""')
    rule("anchor", "pair | tipref")
    rule("tipref", '"{" ws "\\"tip\\"" ws ":" ws string ws "}"')
    rule("emitblock",
         '"{" ws emitfield ws ":" ws number '
         .. '(ws "," ws emitfield ws ":" ws number)* ws "}"')
    rule("pair", '"[" ws number ws "," ws number ws "]"')
    rule("hour", 'number | string')
    rule("tenths", '[0-9]+ ("." [0-9])?')
    rule("int", "[0-9]+")
    rule("number", '"-"? [0-9]+ ("." [0-9]+)?')
    rule("string", '"\\"" [^"]* "\\""')
    rule("ws", "[ \\t\\n]*")
    three_d_rules(rule)
    return table.concat(g, "\n") .. "\n"
end
-- }}}

-- {{{ function porch.prompt()
-- The system prompt, assembled from the truth people read: the
-- format contract and both reference scores, verbatim, plus the
-- painting instructions. Nothing about the vocabulary is written a
-- second time for the model's benefit.
function porch.prompt(dir)
    -- {{{ local function slurp()
    local function slurp(path)
        local f = assert(io.open(path, "r"),
                         "porch: missing " .. path)
        local text = f:read("*a")
        f:close()
        return text
    end
    -- }}}
    return "You translate motion prose into score tool-calls, one "
        .. "call per painted thing. Emit one canvas call first. A "
        .. "stroke of light in screen space is one stroke call per "
        .. "gesture, each with its time in seconds (tenths only), a "
        .. "color, a shape, and a fade pick. Times order the strokes "
        .. "— speak them in any order you like. A thing in world "
        .. "space is one shape call (its motion picks how it travels); "
        .. "the eye is at most one camera call, the sky at most one "
        .. "world call, and each pane of glass a stroke may be painted "
        .. "on is one pane call. A stroke that follows a shape names "
        .. "the shape's tag as its tip. Carry the person's own "
        .. "sentence in each call's prose field. Translate literally: "
        .. "when the person says the wrong word but the right "
        .. "mechanism, choose the vocabulary word for the mechanism.\n\n"
        .. "THE LANGUAGE:\n\n" .. slurp(dir .. "/docs/score-format.md")
        .. "\n\nTHE WORLD-SPACE WORDS:\n\n"
        .. slurp(dir .. "/docs/shape-format.md")
        .. "\n\nA MINIMAL EXAMPLE SCORE:\n\n"
        .. slurp(dir .. "/input/orbit.lua")
        .. "\n\nA FULL TRANSLATION (the founding vision):\n\n"
        .. slurp(dir .. "/input/two-clocks.lua")
        .. "\n\nA SCORE THAT SPEAKS BOTH SPACES:\n\n"
        .. slurp(dir .. "/tests/two-spaces/mixed.lua")
end
-- }}}

-- {{{ local function anchor_from()
-- a JSON anchor back into score form: [x, y] or { tip = "name" }
local function anchor_from(a)
    if a.tip then return { ref = "tip", of = a.tip } end
    return { a[1], a[2] }
end
-- }}}

-- Tool-call shapes back into score shapes: a dispatch table, one
-- row per kind, because a ladder of ifs is a list wearing stairs.
local SHAPE_FROM = {
    -- {{{ arc
    arc = function(sh)
        return { kind = "arc", center = { sh.center[1], sh.center[2] },
                 radius = sh.radius, from = sh.from, to = sh.to,
                 turn = sh.turn }
    end,
    -- }}}
    -- {{{ line
    line = function(sh)
        return { kind = "line", from = anchor_from(sh.from),
                 to = anchor_from(sh.to) }
    end,
    -- }}}
    -- {{{ point
    point = function(sh)
        return { kind = "point", at = anchor_from(sh.at) }
    end,
    -- }}}
    -- {{{ fill
    fill = function(sh)
        local verts = {}
        for i, v in ipairs(sh.vertices) do
            verts[i] = anchor_from(v)
        end
        return { kind = "fill", vertices = verts, sweep = sh.sweep }
    end,
    -- }}}
}

-- {{{ local function plain()
-- A decoded JSON value as plain tables (the decoder marks its arrays and
-- objects with a metatable; a score's tables carry none), without the
-- call's own `tool` and `prose`.
local function plain(v, top)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do
        if not (top and (k == "tool" or k == "prose")) then out[k] = plain(x) end
    end
    return out
end
-- }}}

-- {{{ function porch.collect()
-- Tool-calls (already parsed from JSON) into a raw score: strokes
-- arrive in any order and settle by the walk-back insertion as
-- they land — time is the truth, arrival breaks the ties. Shapes and
-- panes keep the order they were called in (a shape's place is its
-- name in the wall's words: "shape #2"); a second camera or world call
-- is kept as the second, for the wall to refuse in its own words. The
-- sentence each call carried rides in `said`, for the writer.
function porch.collect(calls)
    local raw = { canvas = nil, strokes = {}, shapes = {}, panes = {},
                  said = { shapes = {}, panes = {} } }
    local extra = {}
    for _, call in ipairs(calls) do
        if call.tool == "canvas" then
            raw.canvas = { size = call.size, fps = call.fps,
                           length = call.length, frames = call.frames,
                           seed = call.seed, background = call.background }
        elseif call.tool == "stroke" then
            local build = SHAPE_FROM[call.shape and call.shape.kind]
            local stroke = {
                name = call.name, pane = call.pane,
                at = call.at, lasts = call.lasts,
                color = call.color, fade = call.fade,
                ease = call.ease, emit = plain(call.emit),
                shape = build and build(call.shape) or call.shape,
                comment = call.prose,
            }
            score.insert(raw.strokes, stroke)
        elseif call.tool == "shape" or call.tool == "pane" then
            local list = call.tool == "shape" and "shapes" or "panes"
            raw[list][#raw[list] + 1] = plain(call, true)
            raw.said[list][#raw[list]] = call.prose
        elseif call.tool == "camera" or call.tool == "world" then
            if raw[call.tool] then extra[#extra + 1] = call.tool end
            raw[call.tool] = plain(call, true)
            raw.said[call.tool] = call.prose
        end
    end
    raw.called_twice = extra[1] and extra or nil
    return raw
end
-- }}}

-- {{{ function porch.parse_calls()
-- The model's reply text into call tables: one JSON object after
-- another (the grammar's root). dkjson tells us where each ends.
function porch.parse_calls(text)
    local calls = {}
    local pos = 1
    while true do
        local obj, next_pos, err = json.decode(text, pos)
        if not obj then
            if #calls == 0 then
                error("porch: the reply held no tool-calls at all: "
                      .. tostring(err))
            end
            break
        end
        calls[#calls + 1] = obj
        pos = next_pos
    end
    return calls
end
-- }}}

-- {{{ function porch.translate()
-- The whole porch, one prose text through one transport. The
-- transport is a function(request) → reply_text; request carries
-- prompt, grammar, prose, and (on retries) the wall's errors
-- verbatim. Returns score_text, compiled, heard on success; on exhausted
-- patience returns nil, errors, best_draft — never a silent repair,
-- never a silent drop.
function porch.translate(dir, prose, transport)
    local request = {
        prompt = porch.prompt(dir),
        grammar = porch.grammar(),
        prose = prose,
        errors = nil,
    }
    local last_errors, last_draft
    for _ = 1, TRIES do
        local reply = transport(request)
        local parsed, calls = pcall(porch.parse_calls, reply)
        local raw = parsed and porch.collect(calls) or {}
        local text = raw.canvas and (sayback.header(raw) .. score.write(raw)) or nil
        if not parsed then
            last_errors = calls
            last_draft = reply
        elseif not raw.canvas then
            last_errors = "the reply never called the canvas tool"
            last_draft = reply
        elseif raw.called_twice then
            last_errors = "the reply called the " .. raw.called_twice[1]
                .. " tool twice; a score has one " .. raw.called_twice[1]
                .. ", so put all its words in one call"
            last_draft = text
        else
            local ok, result = pcall(compile.score, raw)
            if ok then
                return text, result, sayback.lines(raw)
            end
            last_errors = result
            last_draft = text
        end
        -- the wall's teaching, quoted back verbatim — the same
        -- nearest-legal-word lines a human reads
        request.errors = last_errors
    end
    return nil, last_errors, last_draft
end
-- }}}

-- {{{ function porch.llama_body()
-- One request as the body llama.cpp's server takes at /completion: the
-- prompt, then what the person said, then (on a retry) the wall's
-- errors, then the place the tool-calls begin; the grammar rides
-- beside it, so the model can say only legal calls. Pure.
function porch.llama_body(request, seed)
    local text = request.prompt
        .. "\n\nTHE PERSON SAYS:\n\n" .. request.prose
    if request.errors then
        text = text .. "\n\nYOUR LAST READING FAILED THE WALL. Its words, "
            .. "verbatim; mend every line:\n\n" .. request.errors
    end
    text = text .. "\n\nTHE TOOL-CALLS, ONE JSON OBJECT PER LINE:\n\n"
    return {
        prompt = text,
        grammar = request.grammar,
        n_predict = 2048,
        temperature = 0.3,
        seed = seed or 1,
        cache_prompt = true,
    }
end
-- }}}

-- {{{ local function shell_run()
-- Runs a command line, returning what it printed and whether it ended
-- well.
local function shell_run(command)
    local pipe = assert(io.popen(command, "r"))
    local out = pipe:read("*a")
    local ok = pipe:close()
    return out, ok == true or ok == 0
end
-- }}}

-- {{{ function porch.door_transport()
-- A live transport for one door of input/cluster: each request is
-- posted to http://host:port/completion with curl, and the model's
-- text comes back. `run` is how a command line is run (tests hand in a
-- fake; by default, a shell). A door that doesn't answer, or answers
-- with something other than a completion, is a sentence naming the
-- door, never a silent empty reading.
function porch.door_transport(door, run, seed)
    run = run or shell_run
    if not tostring(door.host):match("^[%w%.%-:%[%]]+$") then
        error("porch: door '" .. door.name .. "' has a host the porch "
              .. "won't put on a command line: " .. tostring(door.host))
    end
    local url = "http://" .. door.host .. ":" .. door.port .. "/completion"
    return function(request)
        local path = os.tmpname()
        local f = assert(io.open(path, "w"))
        f:write(json.encode(porch.llama_body(request, seed)))
        f:close()
        local out, ok = run("curl -sS --max-time 900 -H 'Content-Type: application/json'"
            .. " --data-binary @'" .. path .. "' '" .. url .. "' 2>&1")
        os.remove(path)
        local answer = ok and json.decode(out) or nil
        if type(answer) ~= "table" or type(answer.content) ~= "string" then
            error("porch: door '" .. door.name .. "' (" .. url .. ") gave no "
                  .. "completion: " .. tostring(out):sub(1, 300), 0)
        end
        return answer.content
    end
end
-- }}}

-- {{{ function porch.door_health()
-- Whether a door's server is up: llama.cpp's server answers GET
-- /health. Returns true, or false and what came back.
function porch.door_health(door, run)
    run = run or shell_run
    if not tostring(door.host):match("^[%w%.%-:%[%]]+$") then
        return false, "a host the porch won't put on a command line"
    end
    local out, ok = run("curl -sS --max-time 10 'http://" .. door.host .. ":"
                        .. door.port .. "/health' 2>&1")
    local answer = ok and json.decode(out) or nil
    if type(answer) == "table" and answer.status == "ok" then return true end
    return false, (out:gsub("%s+$", ""))
end
-- }}}

-- {{{ function porch.cluster_doors()
-- The roster text parsed: lines of "name host port" (blank lines
-- and # comments pass by). Pure, so tests need no filesystem.
function porch.cluster_doors(text)
    local doors = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local name, host, port =
            line:match("^%s*([^#%s]%S*)%s+(%S+)%s+(%d+)%s*$")
        if name then
            doors[#doors + 1] = { name = name, host = host,
                                  port = tonumber(port) }
        end
    end
    return doors
end
-- }}}

-- {{{ function porch.cluster()
-- The orchestrator's door, from input/cluster. Zero doors is a
-- polite refusal with instructions — a missing cluster is a fact
-- to report, not a condition to hide.
function porch.cluster(dir)
    local f = io.open(dir .. "/input/cluster", "r")
    if not f then
        error("porch: no input/cluster file — the porch needs the "
              .. "orchestrator's door. Write lines of: "
              .. "name host port (see input/cluster.example)")
    end
    local text = f:read("*a")
    f:close()
    local doors = porch.cluster_doors(text)
    if #doors == 0 then
        error("porch: input/cluster names no doors — write lines "
              .. "of: name host port (see input/cluster.example)")
    end
    return doors
end
-- }}}

return porch
