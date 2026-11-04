-- 013-reading-a-description.lua - sentences into statements, or refusals.
--
-- In plain terms: a description is cut into sentences, each sentence into
-- words, and each sentence is matched against the few sentence shapes the
-- language has (docs/shape-words.md). A sentence that fits becomes a
-- statement: a small record saying which part it is about and what it says.
-- A sentence that fits nothing, a word the language does not have, a part
-- nobody named -- each is a refusal with its line and the nearest thing that
-- would have been understood. All refusals come back together, so a
-- description is fixed in one round, not one error at a time.
--
-- Words pass through four steps before matching:
--   1. lower case; "-shaped" split off ("disc-shaped" -> "disc shaped");
--      anything but letters, digits and spaces becomes a space
--   2. phrases that need their article joined ("a third" -> a_third)
--   3. a, an, the dropped
--   4. the other phrases joined ("on top of" -> on_top_of), and "N times"
--      with N in digits joined (3_times)
--
-- A statement is { line = whole, type = string, subject = reference, ... }
-- where a reference is { words = list of strings, text = string } until
-- names are resolved, then a part's name. Types and their fields:
--   declare     kind, kind_word, colour (or nil)
--   colour      colour
--   extent      extent ("along"/"across"/"deep"/"thin"/"all"), ratio,
--               other, other_extent
--   proportion  how ("shaped_like"/"scaled_to"/"same_size"), other
--   place       place (see PLACES in 012), other
--   direction   axis ("x"/"y"/"z")
--   aligned     other

local words = require("012-the-shape-words")

local M = {}

-- {{{ local function distance()
-- How many single-letter edits turn a into b (Levenshtein), for suggesting
-- the nearest legal word.
local function distance(a, b)
    local previous = {}
    for j = 0, #b do previous[j] = j end
    for i = 1, #a do
        local current = { [0] = i }
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            current[j] = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        end
        previous = current
    end
    return previous[#b]
end
M.distance = distance
-- }}}

-- {{{ local function nearest()
-- The candidates closest to `word`, if close enough to be a likely slip (no
-- more than a third of the word's letters, at least one), as one string:
-- "'wide' or 'wider'". Equally near candidates are all offered, in
-- alphabetical order, since choosing one would be a guess.
local function nearest(word, candidates)
    local best, best_distance = {}, math.huge
    for candidate in pairs(candidates) do
        local d = distance(word, candidate)
        if d < best_distance then best, best_distance = { candidate }, d
        elseif d == best_distance then best[#best + 1] = candidate end
    end
    if #best == 0 or best_distance > math.max(1, math.floor(#word / 3)) then return nil end
    table.sort(best)
    local quoted = {}
    for i, candidate in ipairs(best) do quoted[i] = candidate:gsub("_", " ") end
    return table.concat(quoted, "' or '")
end
-- }}}

-- {{{ local function join_phrases()
-- Replaces each run of words matching a phrase with the phrase joined by
-- underscores. Longest phrases are tried first, so "aligned with axis of"
-- wins over "aligned with".
local function join_phrases(list, phrases)
    local split = {}
    for _, phrase in ipairs(phrases) do
        local parts = {}
        for word in phrase:gmatch("%S+") do parts[#parts + 1] = word end
        split[#split + 1] = parts
    end
    table.sort(split, function(a, b) return #a > #b end)
    local out, i = {}, 1
    while i <= #list do
        local joined = false
        for _, parts in ipairs(split) do
            local fits = true
            for k = 1, #parts do
                if list[i + k - 1] ~= parts[k] then fits = false break end
            end
            if fits then
                out[#out + 1] = table.concat(parts, "_")
                i = i + #parts
                joined = true
                break
            end
        end
        if not joined then
            out[#out + 1] = list[i]
            i = i + 1
        end
    end
    return out
end
-- }}}

-- {{{ function M.words_of()
-- One sentence's text to its list of words, through the four steps above.
function M.words_of(text)
    text = text:lower():gsub("%-shaped", " shaped"):gsub("[^%w%s%.]", " ")
    -- full stops only survive inside numbers (1.5 times)
    text = text:gsub("%.(%D)", " %1"):gsub("%.$", "")
    local list = {}
    for word in text:gmatch("%S+") do list[#list + 1] = word end
    list = join_phrases(list, words.PHRASES_WITH_ARTICLES)
    local kept = {}
    for _, word in ipairs(list) do
        if not words.DROPPED_WORDS[word] then kept[#kept + 1] = word end
    end
    kept = join_phrases(kept, words.PHRASES)
    -- "3 times" and "1.5 times": a ratio written in digits
    local out = {}
    for i, word in ipairs(kept) do
        if word == "times" and out[#out] and tonumber(out[#out]) then
            out[#out] = out[#out] .. "_times"
        else
            out[#out + 1] = word
        end
    end
    return out
end
-- }}}

-- {{{ function M.sentences_of()
-- The description's text to { line = whole, text = string } per sentence.
-- A sentence ends at a full stop followed by a space or the line's end; a
-- full stop between digits (1.5) does not end one. Lines starting with #
-- are comments.
function M.sentences_of(description)
    local sentences, line_number = {}, 0
    for line in (description .. "\n"):gmatch("([^\n]*)\n") do
        line_number = line_number + 1
        if not line:match("^%s*#") then
            -- a full stop between digits is hidden as a control character
            -- while the line is cut at the others, then put back
            local guarded = line:gsub("(%d)%.(%d)", "%1\1%2")
            for piece in (guarded .. "."):gmatch("([^%.]*)%.") do
                if piece:match("%S") then
                    sentences[#sentences + 1] = { line = line_number, text = (piece:gsub("\1", ".")) }
                end
            end
        end
    end
    return sentences
end
-- }}}

-- {{{ local function ratio_of()
-- A ratio word, or "N_times", to its number; nil otherwise.
local function ratio_of(word)
    if words.RATIOS[word] then return words.RATIOS[word] end
    local digits = word and word:match("^(%d+%.?%d*)_times$")
    return digits and tonumber(digits)
end
M.ratio_of = ratio_of
-- }}}

-- {{{ local function reference()
-- A run of words naming a part (resolved to a name later).
local function reference(list, from, to)
    local out = {}
    for i = from, to or #list do out[#out + 1] = list[i] end
    return { words = out, text = table.concat(out, " ") }
end
-- }}}

-- {{{ PREDICATES
-- Each sentence shape, as a function of the words after the joining verb
-- (`p`, a list) returning a statement's fields, or nil if the shape does
-- not fit. Tried in order; the first fit wins.
local PREDICATES = {
    -- NAME is a [COLOUR] KIND
    function(p)
        if #p == 1 and words.kind_of(p[1]) then
            return { type = "declare", kind = words.kind_of(p[1]), kind_word = p[1] }
        end
        if #p == 2 and words.COLOURS[p[1]] and words.kind_of(p[2]) then
            return { type = "declare", kind = words.kind_of(p[2]), kind_word = p[2], colour = p[1] }
        end
    end,
    -- NAME is COLOUR
    function(p)
        if #p == 1 and words.COLOURS[p[1]] then return { type = "colour", colour = p[1] } end
    end,
    -- NAME stands upright / lies left to right / is upright
    function(p)
        if #p == 1 and words.DIRECTIONS[p[1]] then return { type = "direction", axis = words.DIRECTIONS[p[1]] } end
    end,
    -- NAME is [RATIO] as DIM as OTHER [is DIM2]
    function(p)
        local ratio, at = 1, 1
        if ratio_of(p[1]) and p[2] == "as" then ratio, at = ratio_of(p[1]), 2 end
        if p[at] ~= "as" or not words.EXTENT_WORDS[p[at + 1]] or p[at + 2] ~= "as" or #p < at + 3 then return nil end
        local extent = words.EXTENT_WORDS[p[at + 1]]
        local last, other_extent = #p, extent
        -- "... as the drum is tall": a different extent of the other part
        if #p >= at + 5 and p[#p - 1] == "is" and words.EXTENT_WORDS[p[#p]] then
            other_extent = words.EXTENT_WORDS[p[#p]]
            last = #p - 2
        end
        return { type = "extent", extent = extent, ratio = ratio, other = reference(p, at + 3, last), other_extent = other_extent }
    end,
    -- NAME is RATIO size of OTHER ("half the size of")
    function(p)
        if ratio_of(p[1]) and p[2] == "size" and p[3] == "of" and #p >= 4 then
            return { type = "extent", extent = "all", ratio = ratio_of(p[1]), other = reference(p, 4), other_extent = "all" }
        end
    end,
    -- NAME is [DEGREE] COMPARATIVE than OTHER
    function(p)
        local degree, at = words.DEGREES.none, 1
        if words.DEGREES[p[1]] and p[1] ~= "none" then degree, at = words.DEGREES[p[1]], 2 end
        local comparative = words.COMPARATIVES[p[at]]
        if comparative and p[at + 1] == "than" and #p >= at + 2 then
            local ratio = (comparative[2] > 0) and degree or (1 / degree)
            return { type = "extent", extent = comparative[1], ratio = ratio, other = reference(p, at + 2), other_extent = comparative[1] }
        end
    end,
    -- NAME is shaped like / scaled to / the same size as OTHER
    function(p)
        if words.PROPORTIONS[p[1]] and #p >= 2 then
            return { type = "proportion", how = words.PROPORTIONS[p[1]], other = reference(p, 2) }
        end
    end,
    -- NAME is on top of / beside / through ... OTHER
    function(p)
        if words.PLACES[p[1]] and #p >= 2 then
            return { type = "place", place = words.PLACES[p[1]], other = reference(p, 2) }
        end
    end,
    -- NAME is aligned with the axis of OTHER
    function(p)
        if words.ALIGNING[p[1]] and #p >= 2 then
            return { type = "aligned", other = reference(p, 2) }
        end
    end,
}
-- }}}

-- Phrases that are both the verb and the start of what is said.
local VERB_PHRASES = {}
for word in pairs(words.DIRECTIONS) do VERB_PHRASES[word] = true end
for _, word in ipairs({ "passes_through", "goes_through", "runs_through", "shares_axis_with" }) do VERB_PHRASES[word] = true end

-- {{{ local function read_sentence()
-- One sentence's words to a statement (subject still unresolved), or nil.
local function read_sentence(list)
    -- there is a [COLOUR] KIND called NAME
    if list[1] == "there" and list[2] == "is" then
        local at, colour = 3, nil
        if words.COLOURS[list[3]] then colour, at = list[3], 4 end
        local kind = words.kind_of(list[at])
        if kind and list[at + 1] == "called" and #list >= at + 2 then
            return { type = "declare", kind = kind, kind_word = list[at], colour = colour, subject = reference(list, at + 2) }
        end
        return nil
    end
    for j, word in ipairs(list) do
        local joining = words.JOINING_WORDS[word]
        if j > 1 and (joining or VERB_PHRASES[word]) then
            local predicate = {}
            for k = joining and (j + 1) or j, #list do predicate[#predicate + 1] = list[k] end
            for _, shape in ipairs(PREDICATES) do
                local statement = shape(predicate)
                if statement then
                    statement.subject = reference(list, 1, j - 1)
                    return statement
                end
            end
            return nil
        end
    end
    return nil
end
-- }}}

-- {{{ local function resolver()
-- A function turning a reference into a part's name: by name, or by kind
-- when exactly one part has it ("the disc", "the disc shaped thing").
-- Returns the name, or nil and the reason.
local function resolver(parts)
    local by_name, names = {}, {}
    for _, part in ipairs(parts) do by_name[part.name] = part; names[part.name] = true end
    return function(ref)
        if by_name[ref.text] then return ref.text end
        local w = ref.words
        local kind = words.kind_of(w[1] or "")
        local kind_shaped = kind and (#w == 1 or (#w == 2 and w[2] == "thing") or (#w == 3 and w[2] == "shaped" and w[3] == "thing")
            or (#w == 2 and w[2] == "shaped"))
        if kind_shaped then
            local found = {}
            for _, part in ipairs(parts) do
                if part.kind == kind then found[#found + 1] = part.name end
            end
            if #found == 1 then return found[1] end
            if #found == 0 then return nil, "no part is a " .. w[1] end
            return nil, "'" .. ref.text .. "' could be any of: " .. table.concat(found, ", ") .. " (use a name)"
        end
        local guess = nearest(ref.text, names)
        return nil, "no part called '" .. ref.text .. "'" .. (guess and (" (did you mean '" .. guess .. "'?)") or "")
    end
end
-- }}}

-- {{{ function M.read()
-- description (string) -> { parts = list of { name, kind, kind_word,
-- colour, line }, statements = list }, refusals (list of { line, message },
-- empty when everything was read). Parts are in the order they were named.
function M.read(description)
    local sentences = M.sentences_of(description)
    local refusals, parts, statements = {}, {}, {}
    local said = {}
    -- the same refusal twice on one line (two sentences about the same
    -- unnamed part) is said once
    local function refuse(line, message)
        local key = line .. "\0" .. message
        if said[key] then return end
        said[key] = true
        refusals[#refusals + 1] = { line = line, message = message }
    end
    local legal = words.all_words()

    -- read every sentence; declarations make the parts
    local read = {}
    for _, sentence in ipairs(sentences) do
        local list = M.words_of(sentence.text)
        local statement = read_sentence(list)
        read[#read + 1] = { sentence = sentence, list = list, statement = statement }
        if statement and statement.type == "declare" then
            local name = statement.subject.text
            for _, part in ipairs(parts) do
                if part.name == name then refuse(sentence.line, "'" .. name .. "' was already named on line " .. part.line) end
            end
            parts[#parts + 1] = { name = name, kind = statement.kind, kind_word = statement.kind_word,
                colour = statement.colour, line = sentence.line }
        end
    end

    -- every word that is part of a name is legal too
    local name_words = {}
    for _, part in ipairs(parts) do
        for word in part.name:gmatch("%S+") do name_words[word] = true end
    end

    local resolve = resolver(parts)
    for _, entry in ipairs(read) do
        local line, statement = entry.sentence.line, entry.statement
        if statement == nil and entry.list[1] and (words.JOINING_WORDS[entry.list[1]] or VERB_PHRASES[entry.list[1]]) then
            -- "The a is a box": the name was only an article, and was dropped
            refuse(line, "'" .. entry.sentence.text:gsub("^%s+", "") .. "' has no part name before '"
                .. entry.list[1]:gsub("_", " ") .. "' (a name cannot be only 'a', 'an' or 'the')")
        elseif statement == nil then
            -- what went wrong: unknown words first, each with a suggestion.
            -- Words before the joining verb are the part's name, which may
            -- be new (a declaration with a misspelt kind); they are only
            -- blamed if nothing after the verb is
            local unknown = 0
            local verb_at = #entry.list + 1
            for j, word in ipairs(entry.list) do
                if j > 1 and (words.JOINING_WORDS[word] or VERB_PHRASES[word]) then verb_at = j break end
            end
            local function is_unknown(word)
                return not legal[word] and not name_words[word] and not ratio_of(word) and not tonumber(word)
            end
            for j, word in ipairs(entry.list) do
                if j > verb_at and is_unknown(word) then
                    unknown = unknown + 1
                    local guess = nearest(word, legal) or nearest(word, name_words)
                    refuse(line, "unknown word '" .. word .. "'" .. (guess and (" (nearest: '" .. guess:gsub("_", " ") .. "')") or ""))
                end
            end
            for j, word in ipairs(entry.list) do
                if unknown == 0 and j < verb_at and is_unknown(word) then
                    unknown = unknown + 1
                    local guess = nearest(word, legal) or nearest(word, name_words)
                    refuse(line, "unknown word '" .. word .. "'" .. (guess and (" (nearest: '" .. guess:gsub("_", " ") .. "')") or ""))
                end
            end
            if unknown == 0 then
                refuse(line, "'" .. entry.sentence.text .. "' is made of known words but fits no sentence shape (see docs/shape-words.md)")
            end
        elseif statement.type ~= "declare" then
            local subject, why = resolve(statement.subject)
            if subject == nil then refuse(line, why) end
            statement.subject = subject
            if statement.other then
                local other, why_other
                -- "it": the part the sentence is about ("the lens is half
                -- as deep as it is wide")
                if statement.other.text == "it" then other = subject else other, why_other = resolve(statement.other) end
                if other == nil then refuse(line, why_other) end
                -- a part may measure one of its extents by another of its
                -- own; anything else said of a part about itself says nothing
                local self_measure = statement.type == "extent" and statement.extent ~= statement.other_extent
                    and statement.extent ~= "all" and statement.other_extent ~= "all"
                if other ~= nil and other == subject and not self_measure then
                    refuse(line, "'" .. subject .. "' is compared with itself (only two different extents can be: 'as deep as it is wide')")
                end
                statement.other = other
            end
            statement.line = line
            statements[#statements + 1] = statement
        end
    end
    return { parts = parts, statements = statements }, refusals
end
-- }}}

return M
