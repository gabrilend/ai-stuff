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

local DKJSON_PATH = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;"

local palette = require("002-palette")
local emit = require("008-emit")
local easing = require("016-easing")
local score = require("022-score")
local compile = require("024-compile")

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
    rule("call", "canvascall | strokecall")
    rule("canvascall",
         '"{" ws "\\"tool\\"" ws ":" ws "\\"canvas\\"" ws '
         .. '"," ws "\\"size\\"" ws ":" ws int '
         .. '"," ws "\\"fps\\"" ws ":" ws int '
         .. '"," ws "\\"length\\"" ws ":" ws tenths '
         .. '"," ws "\\"seed\\"" ws ":" ws int ws "}"')
    rule("strokecall",
         '"{" ws "\\"tool\\"" ws ":" ws "\\"stroke\\"" '
         .. '("," ws "\\"name\\"" ws ":" ws string)? '
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
        .. "call per painted thing. Emit one canvas call first, then "
        .. "one stroke call per gesture, each with its time in "
        .. "seconds (tenths only), a color, a shape, and a fade "
        .. "pick. Times order the strokes — speak them in any order "
        .. "you like. Carry the person's own sentence in each "
        .. "call's prose field. Translate literally: when the "
        .. "person says the wrong word but the right mechanism, "
        .. "choose the vocabulary word for the mechanism.\n\n"
        .. "THE LANGUAGE:\n\n" .. slurp(dir .. "/docs/score-format.md")
        .. "\n\nA MINIMAL EXAMPLE SCORE:\n\n"
        .. slurp(dir .. "/input/orbit.lua")
        .. "\n\nA FULL TRANSLATION (the founding vision):\n\n"
        .. slurp(dir .. "/input/two-clocks.lua")
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

-- {{{ function porch.collect()
-- Tool-calls (already parsed from JSON) into a raw score: strokes
-- arrive in any order and settle by the walk-back insertion as
-- they land — time is the truth, arrival breaks the ties.
function porch.collect(calls)
    local raw = { canvas = nil, strokes = {} }
    for _, call in ipairs(calls) do
        if call.tool == "canvas" then
            raw.canvas = { size = call.size, fps = call.fps,
                           length = call.length, seed = call.seed }
        elseif call.tool == "stroke" then
            local build = SHAPE_FROM[call.shape and call.shape.kind]
            local stroke = {
                name = call.name, at = call.at, lasts = call.lasts,
                color = call.color, fade = call.fade,
                ease = call.ease, emit = call.emit,
                shape = build and build(call.shape) or call.shape,
                comment = call.prose,
            }
            score.insert(raw.strokes, stroke)
        end
    end
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
-- verbatim. Returns score_text, compiled on success; on exhausted
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
        local raw = porch.collect(porch.parse_calls(reply))
        local text = raw.canvas and score.write(raw) or nil
        if not raw.canvas then
            last_errors = "the reply never called the canvas tool"
            last_draft = reply
        else
            local ok, result = pcall(compile.score, raw)
            if ok then
                return text, result
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
