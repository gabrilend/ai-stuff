-- 142-checking-the-router.lua
--
-- Checks issue 904, with the stand-in: an invented station is sent back
-- naming the nearest real one, and a good answer is recorded as one
-- ledger line (parcel, shape, station, attempts); three answers that do
-- not fit leave the parcel waiting for the person, also one ledger line.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local ledger = require("016-ledger")
local parcel = require("079-the-parcel")
local stations = require("093-the-station-table")
local router = require("141-the-router")

local scratch = kit.scratch("router")

-- A fixture table beside the real one: more than one station, so the
-- nearest names have something to choose between.
local ROWS = {
    { name = "txt-table", input = "table", output = "text" },
    { name = "chart-bars", input = "integer-array", output = "canvas" },
    { name = "chart-dots", input = "number-array", output = "canvas" },
    { name = "png-paint", input = "canvas", output = "image" },
}

-- {{{ local function drop
-- A parcel folder holding the given files.
local function drop(name, files)
    local folder = scratch .. "/" .. name
    kit.fs.make_folder(folder)
    for file, text in pairs(files) do
        kit.write_file(folder .. "/" .. file, text)
    end
    return parcel.read(folder)
end
-- }}}

-- {{{ local function new_ledger
local function new_ledger(name)
    local path = scratch .. "/" .. name .. ".ledger"
    ledger.create(path, "a fixture case")
    return path
end
-- }}}

-- A tagged parcel of integers, routed on the second try.
local numbers = drop("numbers", { ["a.txt"] = "language model prompt 7: a bar chart of these\n", ["b.txt"] = "3 1 4 1 5 9 2 6\n" })
local book = new_ledger("numbers")
local ask = router.stand_in({
    "shape: integer-array\nstation: chart-barz",
    "shape: integer-array\nstation: chart-bars",
})
local routed = router.route({ rows = ROWS, parcel = numbers, ask = ask, ledger = book })
kit.equal(routed.status, "routed", "a good answer is routed")
kit.equal(routed.station, "chart-bars", "to the station it named")
kit.equal(routed.shape, "integer-array", "with the shape it named")
kit.equal(routed.attempts, 2, "on the second attempt")
kit.equal(routed.row, ROWS[2], "the routed row is the table's own")

kit.check(ask.prompts[1]:find("language model prompt 7: a bar chart of these", 1, true) ~= nil, "the router is handed the tag")
kit.check(ask.prompts[1]:find("- b.txt: integer-array", 1, true) ~= nil, "the router is handed the types the machine recognised")
kit.check(ask.prompts[1]:find("- png-paint: canvas -> image", 1, true) ~= nil, "the router is handed the station table")
kit.check(ask.prompts[1]:find("sent back", 1, true) == nil, "a first prompt sends nothing back")
kit.check(ask.prompts[2]:find("there is no station 'chart-barz'; the nearest are 'chart-bars'", 1, true) ~= nil,
    "an invented station is sent back naming the nearest real one first")

local lines = ledger.read(book)
kit.equal(#lines, 2, "one routing is one ledger line")
kit.equal(lines[2].kind, "routed", "a good answer is recorded as routed")
kit.equal(lines[2].about, "7", "about the parcel, by its tag's number")
kit.equal(lines[2].text, "parcel 7: shape integer-array, station chart-bars, after 2 attempts",
    "the line holds the parcel, shape, station and attempts")
kit.check(ledger.verify(book).ok, "the ledger still verifies")

-- An untagged parcel that never gets a fitting answer.
local plain = drop("plain-words", { ["note.txt"] = "just some words\n" })
local held_book = new_ledger("plain")
local stubborn = router.stand_in({
    "shape: text\nstation: txt-table",          -- a station that does not take text
    "shape: words\nstation: txt-table",         -- a shape that does not exist
    "I think it is text.",                      -- not the form at all
})
local waiting = router.route({ rows = ROWS, parcel = plain, ask = stubborn, ledger = held_book })
kit.equal(waiting.status, "waiting", "after three answers that do not fit, the parcel waits for the person")
kit.equal(waiting.attempts, 3, "it was asked three times, no more")
kit.equal(#stubborn.prompts, 3, "the router was handed three prompts")
kit.check(waiting.sent_back[1]:find("takes 'table', not 'text'; no station takes 'text'", 1, true) ~= nil,
    "a shape the station does not take is sent back, saying what it takes")
kit.check(waiting.sent_back[2]:find("there is no shape 'words'", 1, true) ~= nil, "an unknown shape is sent back")
kit.check(waiting.sent_back[3]:find("'shape: ...' line", 1, true) ~= nil, "an answer not in the form is sent back")
kit.check(stubborn.prompts[1]:find("It has no tag", 1, true) ~= nil, "an untagged parcel is said to have no tag")
local held = ledger.read(held_book)
kit.equal(held[2].kind, "route-failed", "a parcel left waiting is one route-failed line")
kit.equal(held[2].about, "plain-words", "about the parcel by its folder's name when it has no tag")
kit.check(held[2].text:find("waits for the person", 1, true) ~= nil, "the line says the parcel waits for the person")
kit.equal(#held, 2, "and no more lines than that")

-- A shape the station does not take, where another station does.
local _, why = router.check(ROWS, "number-array", "chart-bars")
kit.equal(why, "the station 'chart-bars' takes 'integer-array', not 'number-array'; the stations taking 'number-array' are 'chart-dots'",
    "a wrong station for a known shape names the stations that take it")

-- The real table: its one station today.
local real = router.route({
    rows = stations.TABLE, parcel = drop("a-table", { ["t.lua"] = "return {}\n" }),
    ask = router.stand_in({ "shape: table\nstation: txt-table" }),
})
kit.equal(real.station, "txt-table", "the real station table routes a table to txt-table")
kit.equal(real.attempts, 1, "first time")

-- An answerer that refuses (a harness refused by name) is raised, not routed around.
kit.raises(function()
    router.route({ rows = ROWS, parcel = numbers, ask = function() error("harnesses: 'ollama' is installed but not serving") end })
end, "not serving", "a refused harness is raised by name, never routed around")

kit.equal(router.distance("chart-barz", "chart-bars"), 1, "the distance counts one changed letter as one")
kit.equal(table.concat(router.nearest("png", { "chart-dots", "txt-table", "png-paint" }, 2), " "), "png-paint txt-table",
    "the nearest names are by edit distance, nearest first")
kit.equal(table.concat(router.nearest("ab", { "ad", "ac" }), " "), "ac ad", "ties go by name")

kit.finish()
