-- 157-observations.lua
--
-- Observations (docs/068, issue 906, step 1): "so it looks like the sheep
-- are out of the barn because they pushed through the door". A station's
-- result that holds an error becomes an observation — what happened, and
-- the mechanism that let it happen — written by a turn that reads the
-- result (and, given one, the station's blueprint). An observation that
-- names no mechanism is sent back, up to MOST_ATTEMPTS times, with the
-- same mood-vs-mechanism check a lesson gets (085's `mood_of`, docs/069):
-- a mood is not a mechanism. A kept observation is appended, never
-- rewritten. Turning it into an adjustment — a request file in the
-- station's own case for the update step (008) — is step 2.

local fs = require("017-the-filesystem")
local lesson = require("085-the-lesson")

local observations = {}

observations.FIELDS = { "station", "what_happened", "mechanism" }
observations.MOST_ATTEMPTS = 3

-- {{{ function observations.holds_error
-- Whether a station's result holds an error (docs/068: "error error
-- detected"): a text with a line that opens with the word "error" (any
-- case), or a table whose `error` field is a non-empty string. Returns the
-- error's own words, or nil.
function observations.holds_error(result)
    if type(result) == "table" then
        if type(result.error) == "string" and result.error:match("%S") then
            return result.error
        end
        return nil
    end
    if type(result) ~= "string" then
        return nil
    end
    for line in (result .. "\n"):gmatch("([^\n]*)\n") do
        if line:lower():match("^%s*error%f[%A]") then
            return (line:gsub("^%s+", ""))
        end
    end
    return nil
end
-- }}}

-- {{{ function observations.build
-- fields: station (string), what_happened (string), mechanism (string).
-- Returns the observation, or nil and why it is sent back: a missing
-- field, or a mechanism that is not a short sentence or reads as a mood
-- (the lesson's own checks, so the two can never disagree about what a
-- mechanism is).
function observations.build(fields)
    for _, name in ipairs(observations.FIELDS) do
        if type(fields[name]) ~= "string" or not fields[name]:match("%S") then
            return nil, "the observation has no " .. name:gsub("_", " ")
        end
    end
    local ok, err = pcall(lesson.build, {
        case = fields.station, ledger_lines = {},
        what_happened = fields.what_happened, mechanism = fields.mechanism,
    })
    if not ok then
        return nil, (tostring(err):gsub("^.-lesson%.build: ", ""))
    end
    return { station = fields.station, what_happened = fields.what_happened, mechanism = fields.mechanism }
end
-- }}}

-- {{{ function observations.prompt
-- The observing turn's prompt: the station, its error and whole result,
-- its blueprint when there is one, the form of the answer, and why the
-- last answer was sent back.
function observations.prompt(station, result, blueprint, sent_back)
    local lines = {
        "turn: observe " .. station,
        "",
        "The station '" .. station .. "' gave a result that holds an error:",
        "",
        type(result) == "table" and ("error: " .. tostring(result.error)) or tostring(result),
        "",
    }
    if blueprint then
        lines[#lines + 1] = "The station's blueprint:"
        lines[#lines + 1] = ""
        lines[#lines + 1] = blueprint
        lines[#lines + 1] = ""
    end
    lines[#lines + 1] = "Say what happened, and the mechanism that let it happen: who or what"
    lines[#lines + 1] = "does what, and what follows from it — not how it went. \"The sheep are out"
    lines[#lines + 1] = "because they pushed through the door\" names a mechanism; \"the gate was bad\""
    lines[#lines + 1] = "is a mood, and is sent back. Answer with exactly these two lines:"
    lines[#lines + 1] = "what happened: <one sentence>"
    lines[#lines + 1] = "mechanism: <one short sentence>"
    if sent_back then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Your last answer was sent back: " .. sent_back
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ function observations.parse
-- An answer's `what happened:` and `mechanism:` lines (first of each).
function observations.parse(text)
    local what, mechanism
    for line in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do
        local key, value = line:match("^%s*([%a ]-)%s*:%s*(.-)%s*$")
        key = key and key:lower()
        if key == "what happened" and not what then
            what = value
        elseif key == "mechanism" and not mechanism then
            mechanism = value
        end
    end
    return what, mechanism
end
-- }}}

-- {{{ function observations.observe
-- One station's result made into an observation. opts:
--   station    the station's name
--   result     its result (text or a table)
--   blueprint  the station's blueprint text (optional)
--   ask        function(prompt, attempt) -> answer text, or nil and why
--   file       where kept observations are appended (optional)
-- Returns { status = "clean" } for a result that holds no error (nothing
-- to observe), { status = "kept", observation, attempts } once an answer
-- names a mechanism, or { status = "waiting", attempts, sent_back } after
-- MOST_ATTEMPTS answers that do not: the result waits for the person, and
-- is never silently dropped.
function observations.observe(opts)
    if not observations.holds_error(opts.result) then
        return { status = "clean" }
    end
    local sent_back = {}
    for attempt = 1, observations.MOST_ATTEMPTS do
        local prompt = observations.prompt(opts.station, opts.result, opts.blueprint, sent_back[#sent_back])
        local text, why = opts.ask(prompt, attempt)
        local kept
        if text then
            local what, mechanism = observations.parse(text)
            kept, why = observations.build({ station = opts.station, what_happened = what, mechanism = mechanism })
        else
            why = "no answer: " .. tostring(why)
        end
        if kept then
            if opts.file then
                observations.append(opts.file, kept)
            end
            return { status = "kept", observation = kept, attempts = attempt }
        end
        sent_back[#sent_back + 1] = why
    end
    return { status = "waiting", attempts = observations.MOST_ATTEMPTS, sent_back = sent_back }
end
-- }}}

-- {{{ function observations.append
-- Appends one kept observation as a Markdown section, in one append-mode
-- write; never reads or rewrites what is there (the lesson's discipline).
function observations.append(path, one)
    local folder = path:match("^(.*)/[^/]*$")
    if folder then
        fs.make_folder(folder)
    end
    local file = assert(io.open(path, "ab"))
    file:write(string.format("## %s\n\n%s\n\nMechanism: %s\n\n", one.station, one.what_happened, one.mechanism))
    file:close()
    return one
end
-- }}}

return observations
