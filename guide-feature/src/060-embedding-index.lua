#!/usr/bin/env luajit
-- 060-embedding-index.lua - the embedding index's own rules and files:
-- cutting a project into pieces, the names in a piece, and reading,
-- writing and checking .embedding-index/ (issue 502).
--
-- In plain terms: to let a voice's model look into a project, each piece of
-- the project's code (a function, a structure, a block) is turned into a
-- list of the names in it, and the list into a vector by an embedding
-- model. Pieces whose vectors point the same way use the same names, so
-- they are about the same part of the architecture. This file holds the
-- rules for the pieces and the names, and the file format the look tool
-- reads (docs/embedding-index-contract.md). The builder (061) calls the
-- embedding model; this file never does, so it can be copied into any other
-- project that wants an index, on its own (docs/embedding-index-build-
-- guide.md). It needs LuaJIT's FFI and nothing else.
--
-- The rules, each named, so an index says which it was built with:
--
--   names-v1  the names in code: identifiers (letters, digits and _,
--             starting with a letter or _), with comments and strings left
--             out, split at _ and where a lower-case letter meets a capital,
--             lower-cased, with language keywords and one-letter names
--             dropped, each kept once, in the order first seen. A query is
--             read the same way, as code with no comments or strings.
--   pieces-v1 a file cut into pieces: each outermost {{{ }}} fold is one
--             piece (this repository's house style); in a file with no
--             folds, each Lua function from a `function` line at the left
--             edge to its `end` at the left edge, each shell function from
--             `name() {` to `}`, and the rest in blocks of lines between
--             blank lines; a piece longer than piece-lines is cut into
--             parts; a piece with no names is left out.
--
--   local index = dofile(DIR .. "/src/060-embedding-index.lua")
--   index.names(text, "lua")            -- { "canvas", "width", ... }
--   index.query_names("the canvas width")
--   index.pieces(text, "lua", 60)       -- { { first, last, kind }, ... }
--   index.write(folder, meta, pieces, vectors)
--   local found = index.read(folder)    -- { meta, pieces, vectors (float*), count, dimensions }
--   index.check(folder, { commit = full, lines_of = function(file) ... end })
-- LuaJIT-compatible.

local ffi = require("ffi")

local M = {}

-- {{{ M.RULE, M.CUT, M.FOLDER
M.RULE = "names-v1"
M.CUT = "pieces-v1"
-- the index's folder, in the project's own folder
M.FOLDER = ".embedding-index"
-- the meta fields, and whether each is a whole number (the rest are text)
M.META = { commit = false, model = false, dimensions = true, pieces = true, rule = false,
           tree = false }
M.META_ORDER = { "commit", "tree", "model", "dimensions", "pieces", "rule" }
M.META_REQUIRED = { commit = true, model = true, dimensions = true, pieces = true, rule = true }
-- }}}

-- {{{ M.KEYWORDS
-- One list for every language the pieces come in (Lua, shell, Python, C,
-- JavaScript), so a query, which has no language, is read the same way.
M.KEYWORDS = {}
for word in string.gmatch([[
    and break do else elseif end false for function goto if in local nil not or
    repeat return then true until while
    case esac fi done elif export readonly declare shift exit set unset
    def class import from as pass lambda with yield none is try except finally
    raise global nonlocal assert del async await
    auto char const continue default double enum extern float int long register
    short signed sizeof static struct switch typedef union unsigned void volatile
    var let new this typeof instanceof delete catch throw null undefined
]], "%S+") do M.KEYWORDS[word] = true end
-- }}}

-- {{{ M.LANGUAGES
-- How each kind of file writes its comments and strings.
M.LANGUAGES = {
    lua  = { line = "--", long_comment = true, long_string = true, quotes = { '"', "'" } },
    hash = { line = "#", quotes = { '"', "'" }, triple = true },
    c    = { line = "//", block = { "/*", "*/" }, quotes = { '"', "'", "`" } },
}
M.EXTENSIONS = { lua = "lua", sh = "hash", bash = "hash", py = "hash", c = "c", h = "c",
                 js = "c", mjs = "c", ts = "c" }
-- }}}

-- {{{ function M.language_of()
-- The language of a file by its name, or by its first line (#!) when it has
-- no extension. nil for a file that is not code.
function M.language_of(path, first_line)
    local extension = string.match(path, "%.([%w]+)$")
    if extension then return M.EXTENSIONS[string.lower(extension)] end
    local interpreter = string.match(first_line or "", "^#!%s*%S*/env%s+(%S+)")
        or string.match(first_line or "", "^#!%s*%S*/(%S+)")
    if not interpreter then return nil end
    if string.match(interpreter, "lua") then return "lua" end
    if string.match(interpreter, "^b?a?sh$") or string.match(interpreter, "sh$")
        or string.match(interpreter, "^python") then return "hash" end
    if string.match(interpreter, "^node") then return "c" end
    return nil
end
-- }}}

-- {{{ function M.code_only()
-- The text with its comments and strings turned to spaces, every newline
-- kept, so a line number means the same line in both.
local function blank(text) return (string.gsub(text, "[^\n]", " ")) end

function M.code_only(text, language)
    local rules = M.LANGUAGES[language]
    if not rules then return text end
    local out, at, size = {}, 1, #text
    -- a first line naming the interpreter (#!) is not code in any language
    if string.sub(text, 1, 2) == "#!" then
        local newline = string.find(text, "\n", 1, true) or (size + 1)
        out[1] = blank(string.sub(text, 1, newline - 1))
        at = newline
    end
    while at <= size do
        local char = string.sub(text, at, at)
        local rest_start = at
        local stop
        if rules.long_comment and string.sub(text, at, at + 1) == "--"
            and string.match(text, "^%[=*%[", at + 2) then
            local equals = string.match(text, "^%[(=*)%[", at + 2)
            local close = string.find(text, "]" .. equals .. "]", at + 4 + #equals, true)
            stop = close and (close + #equals + 1) or size
        elseif rules.line and string.sub(text, at, at + #rules.line - 1) == rules.line
            and (rules.line ~= "#" or at == 1 or string.match(string.sub(text, at - 1, at - 1), "[%s;]")) then
            local newline = string.find(text, "\n", at, true)
            stop = newline and (newline - 1) or size
        elseif rules.block and string.sub(text, at, at + 1) == rules.block[1] then
            local close = string.find(text, rules.block[2], at + 2, true)
            stop = close and (close + 1) or size
        elseif rules.long_string and string.match(text, "^%[=*%[", at) then
            local equals = string.match(text, "^%[(=*)%[", at)
            local close = string.find(text, "]" .. equals .. "]", at + 2 + #equals, true)
            stop = close and (close + #equals + 1) or size
        elseif rules.triple and (string.sub(text, at, at + 2) == '"""' or string.sub(text, at, at + 2) == "'''") then
            local close = string.find(text, string.sub(text, at, at + 2), at + 3, true)
            stop = close and (close + 2) or size
        else
            for _, quote in ipairs(rules.quotes) do
                if char == quote then
                    local index = at + 1
                    while index <= size do
                        local c = string.sub(text, index, index)
                        if c == "\\" and quote ~= "'" or c == "\\" and language ~= "hash" then
                            index = index + 2
                        elseif c == quote then
                            break
                        elseif c == "\n" and quote ~= "`" and language ~= "hash" then
                            index = index - 1
                            break
                        else
                            index = index + 1
                        end
                    end
                    stop = math.min(index, size)
                    break
                end
            end
        end
        if stop then
            out[#out + 1] = blank(string.sub(text, rest_start, stop))
            at = stop + 1
        else
            local plain_end = at
            -- copy plain code up to the next character that could start something
            local next_at = string.find(text, "[%-%[#/\"'`]", at + 1)
            plain_end = next_at and (next_at - 1) or size
            out[#out + 1] = string.sub(text, at, plain_end)
            at = plain_end + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ function M.split_identifier()
-- canvas_width, canvasWidth -> { "canvas", "width" }; lower-cased.
function M.split_identifier(identifier)
    local parts = {}
    for part in string.gmatch(identifier, "[^_]+") do
        part = string.gsub(part, "(%l)(%u)", "%1 %2")
        part = string.gsub(part, "(%d)(%a)", "%1 %2")
        for word in string.gmatch(part, "%S+") do parts[#parts + 1] = string.lower(word) end
    end
    return parts
end
-- }}}

-- {{{ function M.names()
-- names-v1: the names in code, each once, in the order first seen.
function M.names(text, language)
    local code = language and M.code_only(text, language) or text
    local list, seen = {}, {}
    for identifier in string.gmatch(code, "[%a_][%w_]*") do
        if not M.KEYWORDS[identifier] then
            for _, name in ipairs(M.split_identifier(identifier)) do
                if #name > 1 and string.match(name, "^%a") and not M.KEYWORDS[name] and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = name
                end
            end
        end
    end
    return list
end

-- A query, as the model writes it: the same rule, with no comments or
-- strings to leave out (an apostrophe in a question is not a string).
function M.query_names(text) return M.names(text, nil) end
-- }}}

-- {{{ function M.pieces()
-- pieces-v1: a file's pieces, { first, last, kind } with line numbers from 1.
local function lines_of(text)
    local list = {}
    for line in string.gmatch(text .. (string.sub(text, -1) == "\n" and "" or "\n"), "([^\n]*)\n") do
        list[#list + 1] = line
    end
    return list
end

local function kind_of(lines, first, last, title)
    local text = title or ""
    if string.match(text, "^local%s+function") or string.match(text, "^function")
        or string.match(text, "^[%w_%.:]+%s*%(") then return "function" end
    for index = first, last do
        local line = lines[index]
        if line and string.match(line, "^%s*local%s+function%s") or line and string.match(line, "^%s*function%s")
            or line and string.match(line, "^[%w_%.]+%s*=%s*function") then
            return "function"
        end
        if line and (string.match(line, "^[%w_%.]+%s*=%s*{") or string.match(line, "^local%s+[%w_]+%s*=%s*{")) then
            return "structure"
        end
    end
    return "block"
end

-- Lines first..last as pieces of at most `most` lines, those with no names
-- left out later.
local function add(list, first, last, kind, most)
    if last < first then return end
    local at = first
    while at <= last do
        local stop = math.min(last, at + most - 1)
        list[#list + 1] = { first = at, last = stop, kind = kind }
        at = stop + 1
    end
end

-- The runs of lines between blank lines, from first to last.
local function blocks(list, lines, first, last, most)
    local start
    for index = first, last + 1 do
        local line = lines[index]
        local empty = index > last or not string.match(line, "%S")
        if empty and start then
            add(list, start, index - 1, kind_of(lines, start, index - 1), most)
            start = nil
        elseif not empty and not start then
            start = index
        end
    end
end

function M.pieces(text, language, most)
    most = most or 60
    local lines = lines_of(text)
    local list = {}
    -- the folds
    local depth, opened, title, outside = 0, nil, nil, 1
    local any_fold = false
    for index, line in ipairs(lines) do
        if string.find(line, "{{{", 1, true) then
            if depth == 0 then
                blocks(list, lines, outside, index - 1, most)
                opened, title = index, string.match(line, "{{{%s*(.-)%s*$")
                any_fold = true
            end
            depth = depth + 1
        elseif string.find(line, "}}}", 1, true) and depth > 0 then
            depth = depth - 1
            if depth == 0 then
                add(list, opened, index, kind_of(lines, opened, index, title), most)
                outside = index + 1
            end
        end
    end
    if depth > 0 then
        add(list, opened, #lines, kind_of(lines, opened, #lines, title), most)
    elseif any_fold then
        blocks(list, lines, outside, #lines, most)
    end
    if any_fold then return list end

    -- no folds: functions at the left edge, the rest in blocks
    local index, start_plain = 1, 1
    while index <= #lines do
        local line = lines[index]
        local closer
        if language == "lua" and (string.match(line, "^local%s+function%s") or string.match(line, "^function%s")
            or string.match(line, "^[%w_%.]+%s*=%s*function")) then
            closer = "^end"
        elseif language == "hash" and (string.match(line, "^[%w_%-]+%s*%(%)%s*{") or string.match(line, "^function%s+[%w_%-]+")) then
            closer = "^}"
        end
        if closer then
            local stop = index
            while stop < #lines and not string.match(lines[stop], closer .. "[%s%)]*$") do stop = stop + 1 end
            if stop == index and not string.match(lines[stop], closer .. "[%s%)]*$") then stop = #lines end
            blocks(list, lines, start_plain, index - 1, most)
            add(list, index, stop, "function", most)
            index, start_plain = stop + 1, stop + 1
        else
            index = index + 1
        end
    end
    blocks(list, lines, start_plain, #lines, most)
    return list
end
-- }}}

-- {{{ function M.cut()
-- A file's pieces with their names, nameless pieces left out:
-- { first, last, kind, names = { ... } }.
function M.cut(text, language, most)
    local code_lines = lines_of(M.code_only(text, language))
    local kept = {}
    for _, piece in ipairs(M.pieces(text, language, most)) do
        local slice = {}
        for index = piece.first, piece.last do slice[#slice + 1] = code_lines[index] or "" end
        piece.names = M.names(table.concat(slice, "\n"), nil)
        if #piece.names > 0 then kept[#kept + 1] = piece end
    end
    return kept
end
-- }}}

-- {{{ vectors: making and normalising
-- A list of numbers made length 1, or nil when it is all zeros.
function M.normalise(vector)
    local length = 0
    for index = 1, #vector do length = length + vector[index] * vector[index] end
    length = math.sqrt(length)
    if length == 0 then return nil end
    local out = {}
    for index = 1, #vector do out[index] = vector[index] / length end
    return out
end

local function little_endian()
    return ffi.abi("le")
end
-- }}}

-- {{{ function M.meta_text(), M.read_meta()
local function meta_value(name, value)
    if M.META[name] then return tostring(value) end
    return '"' .. string.gsub(tostring(value), '[\\"]', "\\%0") .. '"'
end

function M.meta_text(meta)
    local lines = { "# The embedding index (docs/embedding-index-contract.md). Made by a builder; not edited." }
    for _, name in ipairs(M.META_ORDER) do
        if meta[name] ~= nil then lines[#lines + 1] = name .. " = " .. meta_value(name, meta[name]) end
    end
    return table.concat(lines, "\n") .. "\n"
end

-- The meta file's fields, or nil and why. Reads name = value lines: text
-- quoted, whole numbers bare.
function M.read_meta(text)
    local meta = {}
    local number = 0
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        number = number + 1
        if string.match(line, "%S") and not string.match(line, "^%s*#") then
            local name, value = string.match(line, "^%s*([%w%-]+)%s*=%s*(.-)%s*$")
            if not name then return nil, "meta line " .. number .. " is not name = value" end
            if string.sub(value, 1, 1) == '"' then
                local inner = string.match(value, '^"(.*)"$')
                if not inner then return nil, "meta line " .. number .. ": the quoted text has no closing quote" end
                value = string.gsub(inner, "\\(.)", "%1")
                if M.META[name] then return nil, "meta: " .. name .. " must be a whole number" end
            else
                if M.META[name] == false then return nil, "meta: " .. name .. " must be quoted text" end
                if not string.match(value, "^%d+$") then return nil, "meta: " .. name .. " must be a whole number" end
                value = tonumber(value)
            end
            meta[name] = value
        end
    end
    for name in pairs(M.META_REQUIRED) do
        if meta[name] == nil then return nil, "meta has no " .. name end
    end
    return meta
end
-- }}}

-- {{{ function M.write()
-- Writes an index into `folder` (made if missing): meta, pieces, vectors.
-- pieces: { file, first, last, kind, names = { ... } }; vectors: one list of
-- numbers per piece, each of length meta.dimensions, made length 1 here.
function M.write(folder, meta, pieces, vectors)
    if not little_endian() then error("embedding index: this machine is not little-endian", 2) end
    os.execute("mkdir -p '" .. string.gsub(folder, "'", "'\\''") .. "'")
    local dimensions = meta.dimensions
    local block = ffi.new("float[?]", math.max(1, #pieces * dimensions))
    local lines = {}
    for number, piece in ipairs(pieces) do
        local vector = vectors[number]
        if type(vector) ~= "table" or #vector ~= dimensions then
            error("embedding index: piece " .. number .. " has no vector of " .. dimensions .. " numbers", 2)
        end
        local unit = M.normalise(vector)
        if not unit then error("embedding index: piece " .. number .. "'s vector is all zeros", 2) end
        for index = 1, dimensions do block[(number - 1) * dimensions + index - 1] = unit[index] end
        if string.find(piece.file, "[\t\n]") then
            error("embedding index: a file name with a tab or newline cannot be written: " .. piece.file, 2)
        end
        lines[number] = table.concat({ number, piece.file, piece.first, piece.last, piece.kind,
            table.concat(piece.names, " ") }, "\t")
    end
    local function put(name, text)
        local handle = assert(io.open(folder .. "/" .. name, "wb"))
        handle:write(text)
        handle:close()
    end
    local copy = {}
    for key, value in pairs(meta) do copy[key] = value end
    copy.pieces = #pieces
    copy.rule = copy.rule or M.RULE
    put("pieces", #lines > 0 and (table.concat(lines, "\n") .. "\n") or "")
    put("vectors", ffi.string(block, #pieces * dimensions * 4))
    put("meta", M.meta_text(copy))   -- last: an index with a meta is whole
end
-- }}}

-- {{{ function M.read()
-- The index in `folder`: { meta, pieces = { { number, file, first, last,
-- kind, names } }, vectors (float* of count x dimensions, row by row),
-- count, dimensions }, or nil and why.
function M.read(folder)
    local function slurp(name)
        local handle = io.open(folder .. "/" .. name, "rb")
        if not handle then return nil end
        local text = handle:read("*a")
        handle:close()
        return text
    end
    local meta_text = slurp("meta")
    if not meta_text then return nil, "there is no index at " .. folder .. " (no meta file)" end
    local meta, why = M.read_meta(meta_text)
    if not meta then return nil, folder .. ": " .. why end
    if meta.dimensions < 1 then return nil, folder .. ": meta says 0 dimensions" end
    local pieces_text = slurp("pieces")
    if not pieces_text then return nil, folder .. ": there is no pieces file" end
    local pieces = {}
    for line in string.gmatch(pieces_text, "([^\n]+)") do
        local number, file, first, last, kind, names =
            string.match(line, "^(%d+)\t([^\t]+)\t(%d+)\t(%d+)\t([^\t]+)\t(.*)$")
        if not number then
            return nil, folder .. ": pieces line " .. (#pieces + 1) .. " is not number, file, "
                .. "first line, last line, kind and names, tab-separated"
        end
        pieces[#pieces + 1] = { number = tonumber(number), file = file, first = tonumber(first),
                                last = tonumber(last), kind = kind, names = names }
    end
    local vectors_text = slurp("vectors")
    if not vectors_text then return nil, folder .. ": there is no vectors file" end
    local count = #pieces
    if #vectors_text ~= meta.pieces * meta.dimensions * 4 then
        return nil, string.format("%s: the vectors file is %d bytes, and %d pieces of %d "
            .. "dimensions need %d", folder, #vectors_text, meta.pieces, meta.dimensions,
            meta.pieces * meta.dimensions * 4)
    end
    if count ~= meta.pieces then
        return nil, string.format("%s: meta says %d pieces and the pieces file has %d", folder,
            meta.pieces, count)
    end
    if not little_endian() then return nil, "this machine is not little-endian" end
    local block = ffi.new("float[?]", math.max(1, count * meta.dimensions))
    ffi.copy(block, vectors_text, #vectors_text)
    return { meta = meta, pieces = pieces, vectors = block, count = count,
             dimensions = meta.dimensions, folder = folder }
end
-- }}}

-- {{{ function M.check()
-- Everything that must hold for an index to be used. opts: commit (the
-- full commit it must be at), lines_of (file -> its number of lines at that
-- commit, or nil when it has no such file). Returns the index and a list of
-- problems (empty when it is good); the index is nil when it cannot be read.
function M.check(folder, opts)
    opts = opts or {}
    local found, why = M.read(folder)
    if not found then return nil, { why } end
    local problems = {}
    local meta = found.meta
    if opts.commit and meta.commit ~= opts.commit then
        problems[#problems + 1] = "it was built from commit " .. meta.commit .. ", and the project is at "
            .. opts.commit
    end
    if meta.rule ~= M.RULE then
        problems[#problems + 1] = "its name rule is " .. meta.rule .. "; this reader knows " .. M.RULE
    end
    local sizes = {}
    for number, piece in ipairs(found.pieces) do
        if piece.number ~= number then
            problems[#problems + 1] = "piece " .. number .. " is numbered " .. piece.number
        end
        if piece.first < 1 or piece.last < piece.first then
            problems[#problems + 1] = "piece " .. number .. " has lines " .. piece.first .. " to " .. piece.last
        end
        if opts.lines_of then
            if sizes[piece.file] == nil then sizes[piece.file] = opts.lines_of(piece.file) or false end
            if sizes[piece.file] == false then
                problems[#problems + 1] = "piece " .. number .. "'s file " .. piece.file .. " is not in the project"
            elseif piece.last > sizes[piece.file] then
                problems[#problems + 1] = "piece " .. number .. " ends at line " .. piece.last .. " of "
                    .. piece.file .. ", which has " .. sizes[piece.file]
            end
        end
        local length = 0
        for index = 0, found.dimensions - 1 do
            local value = found.vectors[(number - 1) * found.dimensions + index]
            length = length + value * value
        end
        if math.abs(math.sqrt(length) - 1) > 1e-3 then
            problems[#problems + 1] = string.format("piece %d's vector has length %.4f, not 1", number,
                math.sqrt(length))
        end
        if #problems > 20 then
            problems[#problems + 1] = "(and more; the first twenty are shown)"
            break
        end
    end
    return found, problems
end
-- }}}

return M
