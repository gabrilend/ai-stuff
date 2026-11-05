#!/usr/bin/env luajit
-- 029-test-screens.lua
--
-- Tests issue 205's parts that can be checked here: the exact-shape example
-- and the cut reply (027); the screen list, the canvases and turns each
-- screen mode makes, the rounds and the contexts they hold, and what each
-- screen shows meanwhile (028); and a smaller canvas drawn centred at the
-- largest letter size that fits (022's layout). The three modes run the same
-- scripted series of context changes and screens.
--
-- For a general: every screen watching gets a canvas made for its own size,
-- so no word is ever cut off by a moving edge. This proves each mode makes
-- the canvases it should, in the order it should, and that a model is shown
-- the exact shape it must fill.
--
-- usage:
--   luajit 029-test-screens.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local shape = dofile(DIR .. "/src/027-exact-shape.lua")
local screens = dofile(DIR .. "/src/028-screens.lua")
local viewer = dofile(DIR .. "/src/022-viewer.lua")
local utf8 = dofile(DIR .. "/src/005-utf8.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

io.write("\n=== the exact shape ===\n")
-- {{{
local known = {}
for _, list in pairs(shape.WORDS) do
    for _, word in ipairs(list) do known[word] = true end
end
local exact, letters_last, only_known, single_spaces = true, true, true, true
local long_last = 0
for width = 1, 80 do
    for seed = 1, 5 do
        for _, row in ipairs(shape.example(width, 3, seed)) do
            if #string.match(row, "(%S+)$") > 2 then long_last = long_last + 1 end
            if utf8.length(row) ~= width then exact = false end
            if not string.match(row, "%a$") or not string.match(row, "^%a") then letters_last = false end
            if string.find(row, "  ", 1, true) then single_spaces = false end
            for word in string.gmatch(row, "%S+") do
                if not known[word] then only_known = false end
            end
        end
    end
end
check("every row of every example is exactly the width, widths 1 to 80", exact)
check("every row starts with a letter and has a letter in its last column", letters_last)
check("so every row ends on the end of a word: whole lorem-ipsum words, one space apart",
    only_known and single_spaces)
check("rows do not all close on a word of one or two letters: longer closing words are chosen too",
    long_last > 300, long_last)
check("the example has the height asked for", #shape.example(60, 20, 1) == 20)
check("the same turn gets the same example, and another turn a fresh one",
    table.concat(shape.example(60, 20, 7), "|") == table.concat(shape.example(60, 20, 7), "|")
    and table.concat(shape.example(60, 20, 7), "|") ~= table.concat(shape.example(60, 20, 8), "|"))
check("every word length from 1 to 12 has a word", (function()
    for length = 1, 12 do
        for _, word in ipairs(shape.WORDS[length] or {}) do
            if #word ~= length then return false end
        end
        if not shape.WORDS[length] or #shape.WORDS[length] == 0 then return false end
    end
    return true
end)())
check("a size that is not whole numbers of at least 1 is refused",
    not pcall(shape.example, 0, 3) and not pcall(shape.example, 4, 1.5)
    and not pcall(shape.example, "60", 20))
check("the line the model is shown is the owner's, word for word",
    shape.EXAMPLE_LINE == "this is the exact shape you'll need to fill")
-- }}}

io.write("\n=== a reply cut to the canvas ===\n")
-- {{{
local cut = shape.cut("the cat sat on the mat\nshort\nthird\nfourth\nfifth\n", 10, 3)
check("a row too wide is cut at the edge, even in the middle of a word",
    cut.rows[1] == "the cat sa" and cut.rows[2] == "short" and #cut.rows == 3)
check("rows past the height are dropped, and counted", cut.dropped == 2 and cut.rows[3] == "third")
check("the cut rows go back with the owner's words and what was cut",
    cut.was_cut and cut.message == "the cat sa\nshort\nthird\n\nthis is all that'd fit, please "
        .. "rephrase the sentences prior to the broken lines (row 1 cut at the edge; 2 rows past "
        .. "the last were dropped)\n", cut.message)
local fits = shape.cut("a\nb\n", 10, 3)
check("a reply that fits is not cut: no message, missing rows left empty",
    not fits.was_cut and fits.message == nil and fits.rows[3] == "" and #fits.broken == 0)
local wide = shape.cut("café olé\n", 6, 1)
check("widths are counted in characters, so a two-byte letter is one",
    wide.rows[1] == "café o" and wide.broken[1] == 1)
local edge = shape.cut("abcd\nabc\n", 3, 1)
check("one character past the edge is cut; one row past the last is named in the singular",
    edge.rows[1] == "abc" and edge.broken[1] == 1 and edge.message:find(
        "(row 1 cut at the edge; 1 row past the last was dropped)", 1, true) ~= nil, edge.message)
check("several broken rows are all named", shape.cut("abcdef\nab\nabcdef\n", 3, 3).message
    :find("(rows 1, 3 cut at the edge)", 1, true) ~= nil)
-- }}}

io.write("\n=== the screens ===\n")
-- {{{
local LIST = {
    { name = "phone", width = 40, height = 30, watched = true },
    { name = "watch", width = 12, height = 4, watched = true },
    { name = "tablet", width = 60, height = 30, watched = false },
    { name = "desktop", width = 120, height = 40, watched = true },
}
local watched = screens.watched(LIST)
local function names(list, field)
    local out = {}
    for index, item in ipairs(list) do out[index] = item[field or "name"] end
    return table.concat(out, " ")
end
check("the watched screens, largest first; one not watched is left out",
    names(watched) == "desktop phone watch", names(watched))
check("equal sizes are ordered by width, then name, whatever order they came in",
    names(screens.watched({ { name = "b", width = 10, height = 10, watched = true },
        { name = "aaa", width = 5, height = 20, watched = true },
        { name = "a", width = 10, height = 10, watched = true } })) == "a b aaa")
check("a screen with no name, a size that is not whole, no watched flag, or a name twice "
    .. "is refused",
    not pcall(screens.watched, { { width = 1, height = 1, watched = true } })
    and not pcall(screens.watched, { { name = "x", width = 1.5, height = 1, watched = true } })
    and not pcall(screens.watched, { { name = "x", width = 1, height = 1 } })
    and not pcall(screens.watched, { { name = "x", width = 1, height = 1, watched = true },
        { name = "x", width = 2, height = 2, watched = false } }))
check("round and asynchronous make a canvas for each watched screen, at its own size",
    names(screens.canvases("round", watched)) == "desktop phone watch"
    and screens.canvases("asynchronous", watched)[2].width == 40)
local small = screens.canvases("smallest", { { name = "wide", width = 50, height = 2, watched = true },
    { name = "square", width = 20, height = 10, watched = true } })
check("smallest makes one canvas, as narrow as the narrowest and as short as the shortest, "
    .. "so it fits every screen", #small == 1 and small[1].width == 20 and small[1].height == 2)
check("no screen watched, no canvas", #screens.canvases("round", {}) == 0
    and #screens.plan("smallest", {}, { "v" }) == 0)
check("an unknown mode is refused", not pcall(screens.canvases, "biggest", watched))
-- }}}

io.write("\n=== the same scripted series in the three modes ===\n")
-- {{{
-- Contexts arrive while turns run. "work" finishes the batch under way.
local VOICES = { "fg-sora-1", "fg-sora-2", "fg-sora-3" }
local NO_PHONE = {}
for index, screen in ipairs(LIST) do
    NO_PHONE[index] = { name = screen.name, width = screen.width, height = screen.height,
                        watched = screen.watched and screen.name ~= "phone" }
end
local SERIES = {
    { "context", "c1", LIST }, { "work" }, { "context", "c2", LIST }, { "context", "c3", LIST },
    { "work" }, { "work" }, { "work" }, { "work" }, { "work" },
    { "context", "c4", NO_PHONE }, { "work" }, { "work" }, { "work" },
}
local function play(mode)
    local keeper = screens.keeper({ mode = function() return mode end })
    local seen = { painted = {}, batches = {}, made = {}, shows = {}, slots = {} }
    local batch
    local function begin(b)
        batch = b
        if b then seen.batches[#seen.batches + 1] = b end
    end
    for step, event in ipairs(SERIES) do
        if event[1] == "context" then
            local started = keeper:context(event[2], event[3], VOICES)
            if started then begin(started) end
        elseif batch then
            if not seen.painted[#seen.painted] or seen.painted[#seen.painted] ~= batch.context then
                seen.painted[#seen.painted + 1] = batch.context
            end
            for _, turn in ipairs(batch.turns) do
                seen.made[turn.canvas] = { width = turn.width, height = turn.height }
                seen.slots[#seen.slots + 1] = turn.slot
            end
            if step == 2 then
                for _, screen in ipairs(watched) do
                    seen.shows[screen.name] = screens.display(screen, mode, seen.made)
                end
            end
            begin(keeper:batch_done())
        end
    end
    seen.counts = keeper.counts
    return seen
end
local round, async, smallest = play("round"), play("asynchronous"), play("smallest")

check("round: each context paints the watched screens one after another, largest first",
    names(round.batches[1].turns, "canvas") == "desktop desktop desktop"
    and names(round.batches[2].turns, "canvas") == "phone phone phone"
    and names(round.batches[3].turns, "canvas") == "watch watch watch")
check("round: three screens and three voices is nine turns a context",
    #round.batches[1].turns + #round.batches[2].turns + #round.batches[3].turns == 9)
check("round: contexts arriving mid-round wait; only the newest is kept (c2 skipped)",
    table.concat(round.painted, " ") == "c1 c3 c4" and round.counts["contexts-held"] == 1
    and round.counts["contexts-skipped"] == 1, table.concat(round.painted, " "))
check("round: the phone no longer watched leaves two screens, six turns",
    round.counts.rounds == 3 and round.counts.batches == 8 and round.counts.turns == 24,
    round.counts.batches .. " " .. round.counts.turns)
check("round: after the first screen, the others show the loading animation",
    round.shows.desktop.canvas == "desktop" and round.shows.phone.loading
    and round.shows.watch.loading)

check("asynchronous: each context is one batch, every voice on every screen at once",
    #async.batches[1].turns == 9 and async.counts.batches == async.counts.rounds)
check("asynchronous: each of those turns has its own endpoint slot",
    table.concat(async.slots, ",", 1, 9) == "1,2,3,4,5,6,7,8,9")
check("asynchronous: no round outlasts a context change, so c2 is painted too",
    table.concat(async.painted, " ") == "c1 c2 c3 c4" and async.counts.turns == 33
    and async.counts["contexts-skipped"] == 0, table.concat(async.painted, " "))
check("asynchronous: after the first batch every screen shows its own canvas",
    async.shows.desktop.canvas == "desktop" and async.shows.phone.canvas == "phone"
    and async.shows.watch.canvas == "watch" and not async.shows.watch.centred)

check("smallest: one canvas at the watch's size, three turns a context",
    #smallest.batches[1].turns == 3 and smallest.batches[1].turns[1].canvas == "smallest"
    and smallest.batches[1].turns[1].width == 12 and smallest.batches[1].turns[1].height == 4
    and smallest.counts.turns == 12)
check("smallest: every screen shows that one canvas; the bigger ones centred",
    smallest.shows.desktop.canvas == "smallest" and smallest.shows.desktop.centred
    and smallest.shows.phone.centred and not smallest.shows.watch.centred)
-- }}}

io.write("\n=== the mode, and what a screen shows ===\n")
-- {{{
local mode = "round"
local keeper = screens.keeper({ mode = function() return mode end })
local first = keeper:context("c1", LIST, VOICES)
mode = "smallest"
keeper:context("c2", LIST)
local next_batch = keeper:batch_done()
check("a mode changed mid-round takes effect at the next round, not this one",
    first.mode == "round" and next_batch.mode == "round" and next_batch.turns[1].canvas == "phone")
keeper:batch_done()
local c2 = keeper:batch_done()
check("the next round is read in the new mode", c2.mode == "smallest" and c2.context == "c2"
    and keeper:batch_done() == nil and not keeper.busy)
check("a keeper needs a mode to read", not pcall(screens.keeper, {}))

local phone = { name = "phone", width = 40, height = 30, watched = true }
check("a screen opening with a canvas cached at another size shows the loading animation",
    screens.display(phone, "round", { phone = { width = 120, height = 40 } }).loading)
check("so does one cached at a smaller size: in round mode no canvas is drawn centred",
    screens.display(phone, "round", { phone = { width = 40, height = 20 } }).loading)
check("and its own canvas once made",
    screens.display(phone, "round", { phone = { width = 40, height = 30 } }).canvas == "phone")
check("in smallest mode a canvas too big for a screen that joined is not shown either",
    screens.display({ name = "watch", width = 10, height = 4, watched = true }, "smallest",
        { smallest = { width = 12, height = 4 } }).loading)
check("in smallest mode a canvas as wide as the screen but shorter is drawn centred",
    screens.display({ name = "strip", width = 12, height = 9, watched = true }, "smallest",
        { smallest = { width = 12, height = 4 } }).centred == true)

local ROOT = os.tmpname()
os.remove(ROOT)
os.execute("mkdir -p '" .. ROOT .. "/input' && ln -s '" .. DIR .. "/libs' '" .. ROOT .. "/libs'")
local handle = io.open(ROOT .. "/input/screens", "w")
handle:write('screen-mode = "asynchronous"\n')
handle:close()
check("the mode is read from input/screens", screens.read_mode(ROOT) == "asynchronous")
handle = io.open(ROOT .. "/input/screens", "w")
handle:write('screen-mode = "largest"\n')
handle:close()
check("a mode that is not one of the three is refused there", not pcall(screens.read_mode, ROOT))
check("the project's input/screens starts in round mode", screens.read_mode(DIR) == "round")
os.execute("rm -rf '" .. ROOT .. "'")
-- }}}

io.write("\n=== a smaller canvas, centred (smallest mode, in every viewer) ===\n")
-- {{{
local LETTER = { across = 0.6, down = 1.2, max = 48, min = 6 }
local watch_canvas = { width = 12, height = 4 }
local desk = viewer.layout(watch_canvas, 1200, 800, LETTER)
check("on a big window the letters grow only to the maximum, and the canvas sits centred",
    desk.size == 48 and desk.left == 427 and desk.top == 284,
    desk.size .. " " .. desk.left .. " " .. desk.top)
local wrist = viewer.layout(watch_canvas, 160, 80, LETTER)
check("on a small window, the largest letter size that fits",
    wrist.size == 16 and wrist.left == 22 and wrist.top == 1,
    wrist.size .. " " .. wrist.left .. " " .. wrist.top)
check("the canvas drawn is never wider or taller than the window",
    desk.width <= 1200 and desk.height <= 800 and wrist.width <= 160 and wrist.height <= 80)
local none, why = viewer.layout(watch_canvas, 40, 20, LETTER)
check("a window that needs letters below the smallest gets an error, not a squeeze",
    none == nil and why == "the canvas is 12x4; this window holds it only at letter size 4.2, "
        .. "below the smallest of 6", why)
-- }}}

io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
