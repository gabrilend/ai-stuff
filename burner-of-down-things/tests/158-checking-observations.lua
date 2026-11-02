-- 158-checking-observations.lua
--
-- Checks issue 906, step 1, with a stand-in observer: an observation
-- without a mechanism is refused (sent back); one with a mechanism is
-- kept, appended and never rewritten; a result with no error makes no
-- observation; one never fixed waits for the person, never dropped.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local obs = require("157-observations")

local scratch = kit.scratch("observations")
local file = scratch .. "/output/switchboard/observations.md"

-- {{{ local function stand_in
local function stand_in(answers)
    local asker = { prompts = {} }
    return setmetatable(asker, { __call = function(self, prompt, attempt)
        self.prompts[#self.prompts + 1] = prompt
        return answers[attempt]
    end }), asker
end
-- }}}

local result = "drew 3 bars\nerror error detected: the chart station got 4 labels for 3 values\n"
kit.equal(obs.holds_error(result), "error error detected: the chart station got 4 labels for 3 values", "a result holding an error is found, by its own line")
kit.equal(obs.holds_error("all fine\nno errors here\n"), nil, "'no errors' is not an error line")
kit.equal(obs.holds_error({ error = "a joint did not fit" }), "a joint did not fit", "a table's error field is an error")
kit.equal(obs.holds_error({ error = "" }), nil, "an empty error field is none")

-- Refused, then kept.
local ask = stand_in({
    "what happened: the chart came out wrong\nmechanism: the chart was bad",
    "what happened: the chart station got four labels for three values and stopped\nmechanism: the table station appends a header row that the chart station counts as data",
})
local first = obs.observe({ station = "chart-bars", result = result, ask = ask, file = file, blueprint = "Takes integer-array, gives canvas." })
kit.equal(first.status, "kept", "an observation naming a mechanism is kept")
kit.equal(first.attempts, 2, "after the mood was sent back once")
kit.check(ask.prompts[2]:find("reads as a mood", 1, true) ~= nil, "a mechanism that is a mood is sent back, saying so: " .. (ask.prompts[2]:match("sent back: ([^\n]*)") or ""))
kit.check(ask.prompts[1]:find("error error detected", 1, true) ~= nil, "the observer is handed the result")
kit.check(ask.prompts[1]:find("Takes integer-array, gives canvas.", 1, true) ~= nil, "and the station's blueprint")
kit.equal(first.observation.mechanism, "the table station appends a header row that the chart station counts as data", "the kept mechanism is the answer's")

local written = kit.fs.read(file)
kit.check(written:find("## chart-bars\n", 1, true) == 1, "the kept observation is appended under its station")
kit.check(written:find("the chart was bad", 1, true) == nil, "the refused mood is never written")

local second = obs.observe({ station = "png-paint", result = { error = "no display" },
    ask = stand_in({ "what happened: the painter could not open a window\nmechanism: a painter started without a display refuses before drawing" }), file = file })
kit.equal(second.status, "kept", "a second observation is kept")
local again = kit.fs.read(file)
kit.equal(again:sub(1, #written), written, "appending never rewrites what was already there")

-- Never fixed: waits for the person.
local stubborn = obs.observe({ station = "chart-bars", result = result, ask = stand_in({
    "what happened: it broke\nmechanism: bad",
    "mechanism: things went wrong",
    nil,
}) })
kit.equal(stubborn.status, "waiting", "after three answers with no mechanism, the result waits for the person")
kit.equal(#stubborn.sent_back, 3, "each answer's reason is kept")
kit.check(stubborn.sent_back[2]:find("no what happened", 1, true) ~= nil, "an answer missing what happened is sent back")
kit.check(stubborn.sent_back[3]:find("no answer", 1, true) ~= nil, "no answer at all is sent back")

kit.equal(obs.observe({ station = "x", result = "drew 3 bars\n", ask = function() error("never asked") end }).status, "clean",
    "a result with no error asks no one and keeps nothing")

local built, why = obs.build({ station = "s", what_happened = "w", mechanism = "the door was bad" })
kit.equal(built, nil, "build refuses a mood directly")
kit.check(why:find("mood", 1, true) ~= nil, "naming it a mood")

kit.finish()
