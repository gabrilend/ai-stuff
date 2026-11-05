-- 027-exact-shape.lua - the exact shape a turn must fill, and a reply cut to
-- it.
--
-- In plain terms: the owner's direction is "every chance we get we provide
-- the current window size to the LLM and force it to match." So each turn is
-- shown an example canvas of lorem-ipsum words built to the exact size, "this
-- is the exact shape you'll need to fill": every row is exactly the width
-- long, with a letter in its last column, ending on the end of a word. And a
-- reply too large is cut at the edge, "even in the middle of the word!", and
-- handed back with "this is all that'd fit, please rephrase the sentences
-- prior to the broken lines". A cut reply is never published: the turn keeps
-- asking until a reply fits (404). (issue 205, "The exact shape")
--
--   local shape = dofile(DIR .. "/src/027-exact-shape.lua")
--   local rows = shape.example(60, 20, turn_number)   -- fresh for each turn
--   shape.EXAMPLE_LINE                                 -- what the model is told
--   local cut = shape.cut(reply_text, 60, 20)
--   cut.rows, cut.broken (row numbers cut at the edge), cut.dropped (rows
--   past the height), cut.was_cut, cut.message
--
-- Widths are counted in UTF-8 code points (005), as everywhere else (open
-- question 4). LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local utf8 = dofile(DIR .. "/src/005-utf8.lua")
local fit = dofile(DIR .. "/src/012-fit-check.lua")

local M = {}

-- {{{ the words and the lines, word for word from issue 205
M.EXAMPLE_LINE = "this is the exact shape you'll need to fill"
M.CUT_LINE = "this is all that'd fit, please rephrase the sentences prior to the broken lines"
-- Lorem-ipsum words, grouped by length; every length from 1 to 12 has at
-- least one, so any remainder of a row can be closed by a word exactly that
-- long.
M.WORDS = {
    [1] = { "a", "e" }, [2] = { "ut", "in", "et" }, [3] = { "sed", "est", "non" },
    [4] = { "amet", "duis", "esse" }, [5] = { "lorem", "ipsum", "dolor" },
    [6] = { "tempor", "labore", "minima" }, [7] = { "aliquip", "nostrud", "officia" },
    [8] = { "pariatur", "deserunt", "proident" }, [9] = { "voluptate", "excepteur" },
    [10] = { "incididunt", "laboriosam" }, [11] = { "consectetur", "consequatur" },
    [12] = { "exercitation", "perspiciatis" },
}
-- }}}

-- {{{ local function chooser()
-- A small deterministic chooser (a linear congruential generator), so the
-- same turn gets the same example and each turn a fresh one.
local function chooser(seed)
    local state = (math.floor(seed or 1) % 2147483647)
    if state <= 0 then state = state + 2147483646 end
    return function(count)
        state = (state * 48271) % 2147483647
        return state % count + 1
    end
end
-- }}}

-- {{{ function M.example()
-- `height` rows of lorem-ipsum words, each exactly `width` characters, with
-- a letter in its last column, words separated by one space. Different
-- seeds give different rows.
function M.example(width, height, seed)
    if type(width) ~= "number" or type(height) ~= "number" or width < 1 or height < 1
        or width ~= math.floor(width) or height ~= math.floor(height) then
        error("shape.example: the width and height must be whole numbers, at least 1", 2)
    end
    local pick = chooser(seed)
    local rows = {}
    for row = 1, height do
        local words, left = {}, width
        while left > 0 do
            local length
            if left <= 12 and (left <= 2 or pick(3) == 1) then
                -- close the row with a word exactly as long as what is left
                length = left
            else
                -- any word that leaves room for a space and at least one letter
                length = pick(math.min(12, left - 2))
            end
            local choices = M.WORDS[length]
            words[#words + 1] = choices[pick(#choices)]
            left = left - length
            if left > 0 then left = left - 1 end
        end
        rows[row] = table.concat(words, " ")
    end
    return rows
end
-- }}}

-- {{{ function M.cut()
-- A reply cut to the canvas: each row cut at the width, even mid-word; rows
-- past the height dropped; missing rows left empty. Returns { rows, broken =
-- row numbers cut at the edge, dropped = how many rows past the height,
-- was_cut, message }: the message, for a cut reply, is the cut rows and the
-- line asking to rephrase, as the model is given it.
function M.cut(reply, width, height)
    local lines = fit.lines_of(reply)
    local rows, broken = {}, {}
    for row = 1, height do
        local characters = utf8.split(lines[row] or "") or {}
        if #characters > width then
            broken[#broken + 1] = row
            local kept = {}
            for column = 1, width do kept[column] = characters[column] end
            rows[row] = table.concat(kept)
        else
            rows[row] = table.concat(characters)
        end
    end
    local dropped = math.max(0, #lines - height)
    local result = { rows = rows, broken = broken, dropped = dropped,
                     was_cut = #broken > 0 or dropped > 0 }
    if result.was_cut then
        local notes = {}
        if #broken > 0 then
            notes[#notes + 1] = (#broken == 1 and "row " or "rows ") .. table.concat(broken, ", ")
                .. " cut at the edge"
        end
        if dropped > 0 then
            notes[#notes + 1] = string.format("%d row%s past the last %s dropped", dropped,
                dropped == 1 and "" or "s", dropped == 1 and "was" or "were")
        end
        result.message = table.concat(rows, "\n") .. "\n\n" .. M.CUT_LINE
            .. " (" .. table.concat(notes, "; ") .. ")\n"
    end
    return result
end
-- }}}

return M
