#!/usr/bin/env luajit
-- 064-look.lua - the look tool: pieces of the project, focused or broad
-- (issue 503).
--
-- In plain terms: a voice's model, before it writes the canvas, may ask to
-- see the project the canvas is about: "look focused: WORDS" or "look broad:
-- WORDS" (403). The owner: "the tool call will be able to say 'I want a
-- highly focused insight' or 'I want a broad reaching exploration.' and
-- it'll deliver more or less similar or related pieces of architecture."
--
-- So a look:
--
--   1. takes the names in WORDS, by the index's own rule (names-v1, 060),
--      and asks the embedder endpoint for their vector;
--   2. reads the project's embedding index (.embedding-index/, in the
--      voice's clone, 501), refusing one built from another commit or by
--      another model;
--   3. measures every piece's similarity to the words, in one pass over the
--      vectors (a dot product each, since every vector is length 1);
--   4. ranks the pieces, nearest first, and chooses some by focus (below);
--   5. answers with the chosen pieces' source text, read from the clone,
--      nearest first, each labelled with its file, lines and similarity, up
--      to the token budget, counted with the voice's own chat model.
--
-- Choosing by focus (input/look). A focus of 1 chooses the `nearest` pieces
-- closest to the words, one after another. A focus of 0 chooses `spread`
-- pieces evenly across every rank, from the nearest to the farthest, so
-- the answer has a few close pieces, more middling ones and some far ones.
-- In between, the number of pieces is a straight line between the two, and
-- the reach down the ranks is (1 - focus) ^ curve of the way to the
-- farthest; the pieces are evenly spaced across that reach.
--
-- A look that cannot be answered says why, in words the model reads, and
-- never shows other files instead: no clone, no index, an index from
-- another commit or another model, no embedder, or no names in the words.
--
--   local look = dofile(DIR .. "/src/064-look.lua")
--   local values = look.read_settings(root)            -- input/look
--   local text, info = look.answer({
--       project = kept.project,        -- the project's folder in the clone
--       commit = full,                 -- the clone's commit, in full
--       embedder = endpoint,           -- the canvas's embedder line (046)
--       count_tokens = function(text) return caller.count_tokens(chat, text) end,
--       words = "canvas width", focus = 1, values = values,
--   })
--   info.refused, info.pieces, info.chosen, info.left_out, info.tokens
--   look.describe(info)                                 -- the log line
--
-- Run directly, it is one look against a folder with an index, printed:
--   luajit src/064-look.lua --project FOLDER --url URL --focus 0.5 WORDS...
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local index = dofile(DIR .. "/src/060-embedding-index.lua")

local M = {}

-- {{{ M.SETTINGS
-- input/look (docs/datapath-looking-into-the-project.md).
M.SETTINGS = {
    ["focused"] = { type = "decimal", required = true },   -- "look focused" as a focus
    ["broad"]   = { type = "decimal", required = true },   -- "look broad" as a focus
    ["nearest"] = { type = "whole", required = true },     -- pieces at focus 1
    ["spread"]  = { type = "whole", required = true },     -- pieces at focus 0
    ["curve"]   = { type = "decimal", required = true },   -- how far down the ranks
    ["budget"]  = { type = "whole", required = true },     -- tokens of source text
}
-- }}}

-- {{{ M.REFUSED
-- Why a look has nothing to show, by kind, as the model reads it. The kind
-- is what the turn counts (look-refused-<kind>).
M.REFUSED = {
    ["no-clone"]    = "this voice has no clone of the project",
    ["no-index"]    = "the project has no embedding index on this voice",
    ["index-commit"] = "the project's embedding index was built from another commit",
    ["index-model"] = "the project's embedding index was built by another embedding model",
    ["no-embedder"] = "there is no embedding model to read your words with",
    ["no-names"]    = "your words have no names in them to look for",
}
M.NOTHING = "There is nothing to show for this look: %s (%s). Write the canvas from what "
    .. "you have%s."
-- }}}

-- {{{ small helpers
local function fail(text) error("look: " .. text, 0) end
local function now()
    local pipe = io.popen("date +%s.%N")
    local value = tonumber(pipe:read("*l"))
    pipe:close()
    return value or os.time()
end
local function round(x) return math.floor(x + 0.5) end
-- }}}

-- {{{ function M.read_settings()
-- input/look, checked: focus words between 0 and 1, at least one piece,
-- spread no fewer than nearest, a curve above 0.
function M.read_settings(root)
    local values = settings.read("look", M.SETTINGS, { root = root })
    for _, name in ipairs({ "focused", "broad" }) do
        if values[name] < 0 or values[name] > 1 then
            fail("input/look: " .. name .. " is a focus, from 0 to 1")
        end
    end
    if values.nearest < 1 then fail("input/look: nearest must be at least 1") end
    if values.spread < values.nearest then fail("input/look: spread cannot be below nearest") end
    if values.curve <= 0 then fail("input/look: curve must be above 0") end
    if values.budget < 1 then fail("input/look: budget must be at least 1") end
    return values
end
-- }}}

-- {{{ function M.focus_of()
-- The model's word ("focused", "broad") as a focus, by input/look.
function M.focus_of(word, values)
    local focus = values[word]
    if type(focus) ~= "number" then fail("there is no focus called " .. tostring(word)) end
    return focus
end
-- }}}

-- {{{ function M.ranks()
-- Which ranks a look chooses, 1 being the nearest, out of n pieces, at a
-- focus from 0 to 1: count = nearest + (spread - nearest) * (1 - focus),
-- evenly spaced from rank 1 to the reach, (1 - focus) ^ curve of the way to
-- rank n (and never fewer ranks than the count).
function M.ranks(n, focus, values)
    if n < 1 then return {} end
    if focus < 0 then focus = 0 elseif focus > 1 then focus = 1 end
    local broad = 1 - focus
    local count = round(values.nearest + (values.spread - values.nearest) * broad)
    if count > n then count = n end
    if count < 1 then count = 1 end
    local reach = round((broad ^ values.curve) * (n - 1))
    local last = math.max(count - 1, reach)
    local out = {}
    for i = 0, count - 1 do
        out[#out + 1] = (count == 1 and 0 or round(i * last / (count - 1))) + 1
    end
    return out
end
-- }}}

-- {{{ function M.score()
-- Every piece's similarity to `query` (a list of numbers, length 1), in one
-- pass over the index's vectors. Returns the piece numbers ranked, nearest
-- first (ties by piece number), and the similarities by piece number.
function M.score(found, query)
    local dimensions, vectors = found.dimensions, found.vectors
    local similarity, order = {}, {}
    for number = 1, found.count do
        local base, sum = (number - 1) * dimensions, 0
        for d = 0, dimensions - 1 do sum = sum + vectors[base + d] * query[d + 1] end
        similarity[number] = sum
        order[number] = number
    end
    table.sort(order, function(a, b)
        if similarity[a] ~= similarity[b] then return similarity[a] > similarity[b] end
        return a < b
    end)
    return order, similarity
end
-- }}}

-- {{{ function M.find()
-- The pieces a look chooses, without their text. opts: project (the
-- project's folder), commit (the full commit it is at), embedder (an
-- endpoint), words, focus (0 to 1), values (input/look); embed and
-- model_name replace the embedder's calls in tests. Returns { refused =
-- kind, why } or { chosen = { { number, file, first, last, kind,
-- similarity, rank } }, count, names, model }.
function M.find(opts)
    if not opts.project then
        return { refused = "no-clone", why = opts.no_clone or "the clone could not be made" }
    end
    local folder = opts.project .. "/" .. index.FOLDER
    local found, why = index.read(folder)
    if not found then return { refused = "no-index", why = why } end
    if opts.commit and found.meta.commit ~= opts.commit then
        return { refused = "index-commit", why = string.format("it is at %s and the clone at %s",
            string.sub(found.meta.commit, 1, 7), string.sub(opts.commit, 1, 7)) }
    end
    if found.meta.rule ~= index.RULE then
        return { refused = "index-model", why = "its name rule is " .. found.meta.rule
            .. ", and this look reads " .. index.RULE }
    end
    local names = index.query_names(opts.words or "")
    if #names == 0 then
        return { refused = "no-names", why = "names are words such as canvas, fit_check or "
            .. "turnRunner; small words and words like if and end are left out" }
    end
    if not opts.embedder and not opts.embed then
        return { refused = "no-embedder", why = opts.no_embedder or "the canvas names no embedder" }
    end
    local model = (opts.model_name or caller.model_name)(opts.embedder)
    if model ~= found.meta.model then
        return { refused = "index-model", why = "the index was built by " .. found.meta.model
            .. ", and the embedder serves " .. model }
    end
    local embed = opts.embed or function(texts) return caller.embed(opts.embedder, texts) end
    local vectors = embed({ table.concat(names, " ") })
    local query = vectors and vectors[1]
    if type(query) ~= "table" or #query ~= found.dimensions then
        return { refused = "index-model", why = string.format("the embedder gave %s numbers, and "
            .. "the index has %d", tostring(type(query) == "table" and #query or "no"), found.dimensions) }
    end
    query = index.normalise(query)
    if not query then return { refused = "no-names", why = "their vector is all zeros" } end
    local order, similarity = M.score(found, query)
    local chosen = {}
    for _, rank in ipairs(M.ranks(found.count, opts.focus, opts.values)) do
        local piece = found.pieces[order[rank]]
        chosen[#chosen + 1] = { number = piece.number, file = piece.file, first = piece.first,
            last = piece.last, kind = piece.kind, similarity = similarity[piece.number], rank = rank }
    end
    return { chosen = chosen, count = found.count, names = names, model = model }
end
-- }}}

-- {{{ function M.source()
-- A piece's lines from the clone's file, or nil when the file is not there.
-- `cache` keeps each file's lines for one look.
function M.source(project, piece, cache)
    local lines = cache[piece.file]
    if lines == nil then
        local handle = io.open(project .. "/" .. piece.file, "rb")
        if handle then
            local text = handle:read("*a")
            handle:close()
            lines = {}
            for line in string.gmatch(text .. (text:sub(-1) == "\n" and "" or "\n"), "([^\n]*)\n") do
                lines[#lines + 1] = line
            end
        else
            lines = false
        end
        cache[piece.file] = lines
    end
    if not lines then return nil end
    local out = {}
    for number = piece.first, math.min(piece.last, #lines) do out[#out + 1] = lines[number] end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function M.label()
function M.label(piece)
    return string.format("--- %s, lines %d-%d (%s), similarity %.3f", piece.file, piece.first,
        piece.last, piece.kind, piece.similarity)
end
-- }}}

-- {{{ function M.answer()
-- The look's answer, as the model reads it, and what happened, for the
-- log: { focus, words, refused, why, chosen, pieces (shown), left_out,
-- count, nearest, farthest, tokens, seconds }. opts as find(), and
-- count_tokens (text -> tokens, by the chat model's tokenizer) and
-- opts.name, the focus as the model wrote it ("focused", or a number).
function M.answer(opts)
    local started = now()
    local values = opts.values or fail("no settings (input/look)")
    local name = opts.name or string.format("%.2f", opts.focus)
    local heading = string.format("look %s (%s)", name, opts.words or "")
    local info = { focus = opts.focus, name = name, words = opts.words, pieces = 0, chosen = 0,
                   left_out = 0, tokens = 0 }
    local found = M.find(opts)
    if found.refused then
        info.refused, info.why = found.refused, found.why
        info.seconds = now() - started
        return string.format(M.NOTHING, M.REFUSED[found.refused], found.why,
            found.refused == "no-names" and ", or look again with names from the project" or ""), info
    end
    info.chosen, info.count = #found.chosen, found.count
    local count_tokens = opts.count_tokens or fail("no token counter")
    local cache, parts, shown = {}, {}, {}
    local budget = values.budget
    for _, piece in ipairs(found.chosen) do
        local text = M.source(opts.project, piece, cache)
        local block = M.label(piece) .. "\n" .. (text or "(this file is not in the clone)")
        local tokens = count_tokens(block)
        if info.tokens + tokens <= budget then
            parts[#parts + 1] = block
            shown[#shown + 1] = piece
            info.tokens = info.tokens + tokens
        else
            info.left_out = info.left_out + 1
        end
    end
    info.pieces = #shown
    info.shown = shown
    if #shown > 0 then
        info.nearest, info.farthest = shown[1].similarity, shown[#shown].similarity
    end
    local head = string.format("%s: %d of the project's %d pieces, nearest first.", heading,
        #shown, found.count)
    local tail = ""
    if info.left_out > 0 then
        tail = string.format("\n(%d more %s chosen and did not fit in the %d tokens a look may give.)",
            info.left_out, info.left_out == 1 and "piece was" or "pieces were", budget)
    end
    if #shown == 0 then
        head = heading .. ": every piece chosen was longer than a look may give."
    end
    info.seconds = now() - started
    return head .. (#parts > 0 and ("\n" .. table.concat(parts, "\n")) or "") .. tail, info
end
-- }}}

-- {{{ function M.describe()
-- The log line for a look.
function M.describe(info)
    local at = string.format("look %s (%s)", info.name or "?", info.words or "")
    if info.refused then return at .. ": refused, " .. info.refused .. ": " .. tostring(info.why) end
    local line = string.format("%s: %d of %d pieces", at, info.pieces, info.count or 0)
    if info.nearest then
        line = line .. string.format(", similarity %.3f to %.3f", info.nearest, info.farthest)
    end
    line = line .. string.format(", %d tokens", info.tokens)
    if info.left_out > 0 then line = line .. string.format(", %d left out", info.left_out) end
    return line .. string.format(", %.2f seconds", info.seconds or 0)
end
-- }}}

-- {{{ command line
-- One look against a folder with an index, printed: the answer, then the
-- log line. Tokens are counted with --count-url (a chat endpoint), or
-- estimated as words when there is none.
if arg and arg[0] and string.match(arg[0], "064%-look%.lua$") then
    local opts, words = { focus = 1 }, {}
    local root, url, timeout, count_url = DIR, nil, 60, nil
    local index_at = 1
    while arg[index_at] do
        local name, value = arg[index_at], arg[index_at + 1]
        if name == "--dir" then root = value; index_at = index_at + 2
        elseif name == "--project" then opts.project = value; index_at = index_at + 2
        elseif name == "--url" then url = value; index_at = index_at + 2
        elseif name == "--timeout" then timeout = tonumber(value); index_at = index_at + 2
        elseif name == "--count-url" then count_url = value; index_at = index_at + 2
        elseif name == "--focus" then
            opts.focus = tonumber(value) or value; index_at = index_at + 2
        else words[#words + 1] = name; index_at = index_at + 1
        end
    end
    if not opts.project or not url or #words == 0 then
        io.stderr:write("usage: 064-look.lua --project FOLDER --url EMBEDDER-URL [--timeout S] "
            .. "[--count-url CHAT-URL] [--focus 0..1|focused|broad] WORDS...\n")
        os.exit(2)
    end
    local ok, problem = pcall(function()
        opts.values = M.read_settings(root)
        if type(opts.focus) == "string" then
            opts.name = opts.focus
            opts.focus = M.focus_of(opts.focus, opts.values)
        end
        opts.words = table.concat(words, " ")
        opts.embedder = { name = "embedder", url = url, kind = "embedding", timeout = timeout }
        local chat = count_url and { name = "counter", url = count_url, kind = "chat", timeout = timeout }
        opts.count_tokens = function(text)
            if chat then return caller.count_tokens(chat, text) end
            local n = 0
            for _ in string.gmatch(text, "%S+") do n = n + 1 end
            return n
        end
        local text, info = M.answer(opts)
        print(text)
        print("=== " .. M.describe(info))
    end)
    if not ok then
        io.stderr:write(tostring(problem), "\n")
        os.exit(1)
    end
end
-- }}}

return M
