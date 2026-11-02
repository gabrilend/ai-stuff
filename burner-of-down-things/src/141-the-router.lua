-- 141-the-router.lua
--
-- The router (docs/068, issue 904): the light model's one job — "it looks
-- like I'm being handed a circle, so here I'll hand this to the place that
-- needs a circle". A router turn is handed a parcel's tag (if any), the
-- types the machine recognised in it, and the station table, and answers
-- two lines, `shape: …` and `station: …`, nothing else. The machine checks
-- the answer against the table: an unknown station, an unknown shape, or a
-- shape the station does not take is sent back with the table's nearest
-- names, up to MOST_ATTEMPTS times; then the parcel waits for the person.
-- Every routing is one ledger line: `routed` or `route-failed`.
--
-- Who answers is handed in as `ask(prompt, attempt)`: a scripted stand-in
-- (`stand_in`) for checks and demos, or one ollama turn through the
-- harness table (`harness_asker`), run by hand once a model is chosen
-- (docs/010 question 12). The router never picks another harness when the
-- one it was given refuses: that refusal is raised, not routed around.

local fs = require("017-the-filesystem")
local ledger = require("016-ledger")
local parcel_mod = require("079-the-parcel")
local shape_types = require("081-the-shape-types")
local harnesses = require("037-the-harness-table")

local router = {}

-- docs/068: "sent back with the table's nearest names, up to three times".
router.MOST_ATTEMPTS = 3
-- How many nearest names a sending-back offers.
router.NEAREST = 3

-- {{{ local function distance
-- Levenshtein distance between two strings, by bytes: how many single
-- insertions, deletions or substitutions turn one into the other.
local function distance(a, b)
    local previous = {}
    for j = 0, #b do
        previous[j] = j
    end
    for i = 1, #a do
        local current = { [0] = i }
        for j = 1, #b do
            local cost = (a:byte(i) == b:byte(j)) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end
router.distance = distance
-- }}}

-- {{{ function router.nearest
-- The `n` names nearest to `word` (NEAREST when not given), nearest first,
-- ties by name.
function router.nearest(word, names, n)
    local scored = {}
    for _, name in ipairs(names) do
        scored[#scored + 1] = { name = name, d = distance(word, name) }
    end
    table.sort(scored, function(x, y)
        if x.d ~= y.d then return x.d < y.d end
        return x.name < y.name
    end)
    local out = {}
    for i = 1, math.min(n or router.NEAREST, #scored) do
        out[i] = scored[i].name
    end
    return out
end
-- }}}

-- {{{ local function quoted_list
local function quoted_list(names)
    local out = {}
    for i, name in ipairs(names) do
        out[i] = "'" .. name .. "'"
    end
    return table.concat(out, ", ")
end
-- }}}

-- {{{ function router.known_shapes
-- Every shape a router may name: the closed list of types (081) and every
-- shape a station in `rows` takes or gives, each once, sorted.
function router.known_shapes(rows)
    local seen, out = {}, {}
    local function add(shape)
        if shape and not seen[shape] then
            seen[shape] = true
            out[#out + 1] = shape
        end
    end
    for _, t in ipairs(shape_types.TYPES) do
        add(t)
    end
    for _, row in ipairs(rows) do
        add(row.input)
        add(row.output)
    end
    table.sort(out)
    return out
end
-- }}}

-- {{{ function router.recognised
-- What the machine itself recognises in a parcel (079's read), before any
-- model: { tag_number, wish, tag_finding, files = {{name, shape}, ...} }.
-- A file nothing recognises reads as "unknown". 081's recognise is handed
-- the path too, for the recognisers that look at a name (902c).
function router.recognised(p)
    local number, wish = parcel_mod.tag(p)
    local seen = { files = {} }
    if number then
        seen.tag_number, seen.wish = number, wish
    elseif wish then
        seen.tag_finding = wish
    end
    for i, file in ipairs(p.files) do
        local shape = shape_types.recognise(fs.read(file.path), file.path) or "unknown"
        seen.files[i] = { name = file.name, shape = shape }
    end
    return seen
end
-- }}}

-- {{{ function router.prompt
-- The router turn's whole prompt: the tag, the recognised types, the
-- station table, the form of the answer, and — on a later attempt — why
-- the last answer was sent back.
function router.prompt(seen, rows, sent_back)
    local lines = {
        "turn: route",
        "",
        "You are handed a parcel. Name its shape and the station that takes that",
        "shape, from the table below, and nothing else. Do not do the work.",
        "",
    }
    if seen.tag_number then
        lines[#lines + 1] = "Its tag: language model prompt " .. seen.tag_number .. ": " .. seen.wish
    elseif seen.tag_finding then
        lines[#lines + 1] = "Its first line looks like a tag but is not well formed: " .. seen.tag_finding
    else
        lines[#lines + 1] = "It has no tag; work it out from what it holds."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "What the machine recognised in it, file by file:"
    for _, f in ipairs(seen.files) do
        lines[#lines + 1] = "- " .. f.name .. ": " .. f.shape
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "The stations (name: takes -> gives):"
    for _, row in ipairs(rows) do
        lines[#lines + 1] = "- " .. row.name .. ": " .. row.input .. " -> " .. row.output
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Answer with exactly these two lines:"
    lines[#lines + 1] = "shape: <the parcel's shape>"
    lines[#lines + 1] = "station: <the station's name>"
    if sent_back then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Your last answer was sent back: " .. sent_back
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function router.parse
-- An answer's text read as shape, station; or nil and a finding when it
-- does not hold one `shape:` line and one `station:` line, each one word.
function router.parse(text)
    if type(text) ~= "string" then
        return nil, nil, "the answer is empty"
    end
    local shape, station
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local key, value = line:match("^%s*(%a+)%s*:%s*(.-)%s*$")
        if key then
            key = key:lower()
            if key == "shape" and not shape then
                shape = value
            elseif key == "station" and not station then
                station = value
            end
        end
    end
    if not shape or shape == "" or not station or station == "" then
        return nil, nil, "the answer must hold a 'shape: ...' line and a 'station: ...' line"
    end
    if shape:find("%s") or station:find("%s") then
        return nil, nil, "a shape and a station are each one word, not '" .. shape .. "' and '" .. station .. "'"
    end
    return shape, station
end
-- }}}

-- {{{ function router.check
-- An answer checked against the station table (`rows`, shaped like 093's
-- TABLE). Returns the station's row, or nil and why it is sent back, with
-- the nearest names: an unknown station, an unknown shape, or a shape the
-- station does not take.
function router.check(rows, shape, station)
    local by_name, names, takers = {}, {}, {}
    for _, row in ipairs(rows) do
        by_name[row.name] = row
        names[#names + 1] = row.name
        if row.input == shape then
            takers[#takers + 1] = row.name
        end
    end
    local known = router.known_shapes(rows)
    local shape_known = false
    for _, s in ipairs(known) do
        if s == shape then
            shape_known = true
        end
    end
    if not by_name[station] then
        local why = "there is no station '" .. station .. "'; the nearest are " .. quoted_list(router.nearest(station, names))
        if #takers > 0 then
            why = why .. "; the stations taking '" .. shape .. "' are " .. quoted_list(takers)
        end
        return nil, why
    end
    if not shape_known then
        return nil, "there is no shape '" .. shape .. "'; the nearest are " .. quoted_list(router.nearest(shape, known))
    end
    local row = by_name[station]
    if row.input ~= shape then
        local why = "the station '" .. station .. "' takes '" .. row.input .. "', not '" .. shape .. "'"
        if #takers > 0 then
            why = why .. "; the stations taking '" .. shape .. "' are " .. quoted_list(takers)
        else
            why = why .. "; no station takes '" .. shape .. "'"
        end
        return nil, why
    end
    return row
end
-- }}}

-- {{{ function router.route
-- Routes one parcel. opts:
--   rows    the station table (093's TABLE, or any table shaped like it)
--   parcel  a parcel (079's read)
--   ask     function(prompt, attempt) -> the answer's text, or nil and why
--   ledger  a ledger path to write the routing to (optional; the case's
--           lock is the caller's, as for any append)
--   about   what the ledger line is about (default: the tag's number, else
--           the parcel folder's own name)
-- Returns { status = "routed", shape, station, row, attempts } or
-- { status = "waiting", attempts, sent_back = {why, ...} } after
-- MOST_ATTEMPTS answers that do not fit: the parcel waits for the person.
-- An `ask` that raises (a harness refused by name) is raised again, never
-- counted as an attempt and never routed around.
function router.route(opts)
    local seen = router.recognised(opts.parcel)
    local about = opts.about or (seen.tag_number and tostring(seen.tag_number))
        or opts.parcel.folder:match("([^/]+)/*$")
    local sent_back = {}
    for attempt = 1, router.MOST_ATTEMPTS do
        local prompt = router.prompt(seen, opts.rows, sent_back[#sent_back])
        local text, ask_why = opts.ask(prompt, attempt)
        local row, why
        if not text then
            why = "no answer: " .. tostring(ask_why)
        else
            local shape, station, finding = router.parse(text)
            if not shape then
                why = finding
            else
                row, why = router.check(opts.rows, shape, station)
                if row then
                    if opts.ledger then
                        ledger.append(opts.ledger, "routed", about, string.format(
                            "parcel %s: shape %s, station %s, after %d attempt%s",
                            about, shape, station, attempt, attempt == 1 and "" or "s"))
                    end
                    return { status = "routed", shape = shape, station = station, row = row, attempts = attempt }
                end
            end
        end
        sent_back[#sent_back + 1] = why
    end
    if opts.ledger then
        ledger.append(opts.ledger, "route-failed", about, string.format(
            "parcel %s: no answer fit after %d attempts; it waits for the person. Last sent back: %s",
            about, router.MOST_ATTEMPTS, sent_back[#sent_back]))
    end
    return { status = "waiting", attempts = router.MOST_ATTEMPTS, sent_back = sent_back }
end
-- }}}

-- {{{ function router.stand_in
-- A scripted answerer for checks and demos, in place of a model: the
-- answer for attempt n is answers[n] (a string, or a function(prompt)
-- returning one). It keeps every prompt it was handed in `.prompts`.
function router.stand_in(answers)
    local asker = { prompts = {} }
    setmetatable(asker, {
        __call = function(self, prompt, attempt)
            self.prompts[#self.prompts + 1] = prompt
            local answer = answers[attempt]
            if type(answer) == "function" then
                answer = answer(prompt)
            end
            if answer == nil then
                return nil, "the stand-in has no answer for attempt " .. attempt
            end
            return answer
        end,
    })
    return asker
end
-- }}}

-- {{{ function router.harness_asker
-- An answerer that runs each attempt as one turn of a harness row (by
-- default `ollama`, 903) in its own folder under `folder`:
-- `<folder>/route-<attempt>/prompt.md` in; result.json, stderr.txt and
-- exit out, by the harness table's own shell line. The row is asked for
-- once, first, so a stopped server refuses before any turn runs (903b).
-- The answer is the `answer` field 138's wrapper writes (903d).
function router.harness_asker(project, folder, model, harness_name)
    local name = harness_name or "ollama"
    local row = harnesses.row(name)
    local one_answer = dofile(project.src .. "/138-one-answer.lua")
    return function(prompt, attempt)
        local turn_folder = folder .. "/route-" .. attempt
        fs.make_folder(turn_folder)
        fs.write(turn_folder .. "/prompt.md", prompt)
        local turn = { folder = turn_folder, writes = { turn_folder .. "/" }, reads = {}, model = model }
        fs.run(harnesses.shell_line(project, row, turn))
        local exit = fs.exists(turn_folder .. "/exit") and tonumber((fs.read(turn_folder .. "/exit"):gsub("%s", "")))
        if exit ~= 0 then
            return nil, "the " .. name .. " turn in " .. turn_folder .. " exited " .. tostring(exit)
        end
        local answer = one_answer.decode(fs.read(turn_folder .. "/result.json"))
        if not answer then
            return nil, "the " .. name .. " turn's result.json holds no answer"
        end
        return answer
    end
end
-- }}}

return router
