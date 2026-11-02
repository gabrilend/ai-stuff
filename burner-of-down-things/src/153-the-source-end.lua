-- 153-the-source-end.lua
--
-- The .src end (docs/067, issue 808, step 1): source files as assets,
-- "language and version printed at first line of each source-code file".
-- A table of languages — comment form, file extension, parser command —
-- where adding a language is adding a row; the first-line check; the
-- language's own parser run over the file; and the `.src` paintbrush,
-- `source{ language, version, purpose, prompt }`, read through the wall
-- (151). Writing the file is a turn of a model through the hands (808's
-- step 2); this piece is everything that checks what such a turn wrote.

local fs = require("017-the-filesystem")
local wall = require("151-the-wall")

local source_end = {}

-- One row per language. `comment` opens a line comment; the first line of
-- a file is `<comment> <language> <version>`. `parser` is the language's
-- own syntax check, %s the file's path; it exits 0 when the file parses.
-- `program` is the program the parser needs on the PATH.
source_end.LANGUAGES = {
    lua = { extension = "lua", comment = "--", parser = "luajit -bl %s > /dev/null", program = "luajit" },
    c = { extension = "c", comment = "//", parser = "cc -fsyntax-only -x c %s", program = "cc" },
    bash = { extension = "sh", comment = "#", parser = "bash -n %s", program = "bash" },
    javascript = { extension = "js", comment = "//", parser = "node --check %s", program = "node" },
}

-- {{{ function source_end.names
function source_end.names()
    local out = {}
    for name in pairs(source_end.LANGUAGES) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end
-- }}}

-- {{{ local function language_row
local function language_row(language)
    local row = source_end.LANGUAGES[language]
    if not row then
        error("source_end: no language '" .. tostring(language) .. "'; the languages are "
            .. table.concat(source_end.names(), ", ") .. " (did you mean '" .. tostring(wall.nearest(language, source_end.names())) .. "'?)")
    end
    return row
end
-- }}}

-- {{{ function source_end.first_line
-- The first line a file in `language` must open with, naming `version`.
function source_end.first_line(language, version)
    return language_row(language).comment .. " " .. language .. " " .. version
end
-- }}}

-- {{{ function source_end.check_first_line
-- Whether `text` (a file's whole text) opens with a line naming its
-- language and a version in that language's comment form:
-- `<comment> <language> <version text>`. With `version` given (the
-- canvas's), the line must also name it. Returns true, or nil and a
-- finding that says what the line should read.
function source_end.check_first_line(language, text, version)
    local row = language_row(language)
    local line = (text or ""):match("^([^\n]*)")
    local opening = row.comment .. " " .. language .. " "
    local rest = line:sub(1, #opening) == opening and line:sub(#opening + 1) or nil
    if not rest or not rest:match("%S") then
        return nil, "the first line must name the language and its version as '" .. opening .. "<version>', not '" .. line .. "'"
    end
    if version and not rest:find(version, 1, true) then
        return nil, "the first line names '" .. rest .. "', not the version '" .. version .. "' the canvas asked for"
    end
    return true
end
-- }}}

-- {{{ function source_end.check_parse
-- Runs the language's own parser over the file at `path`. Returns true,
-- or nil and the parser's own words. A parser that is not installed is
-- refused by name: a file is never passed because nothing checked it.
function source_end.check_parse(language, path)
    local row = language_row(language)
    if not fs.run("command -v " .. fs.quote(row.program) .. " > /dev/null 2>&1") then
        return nil, "the " .. language .. " parser needs '" .. row.program .. "', which is not installed"
    end
    -- In a subshell, so a parser line that sends its own standard output
    -- away (luajit -bl's listing) still has its standard error kept.
    local out, ok = fs.capture("( " .. string.format(row.parser, fs.quote(path)) .. " ) 2>&1")
    if ok then
        return true
    end
    return nil, (out:gsub("%s+$", ""))
end
-- }}}

-- {{{ function source_end.check_file
-- Both checks over one written file: its ending matches its language, its
-- first line names the language (and the canvas's version), and it parses.
-- Returns true, or nil and every finding (each a sentence), so a file
-- sent back carries all its faults at once.
function source_end.check_file(language, path, version)
    local row = language_row(language)
    local findings = {}
    if not path:match("%." .. row.extension .. "$") then
        findings[#findings + 1] = "a " .. language .. " file ends in ." .. row.extension .. ", not " .. (path:match("[^/]+$") or path)
    end
    local ok, why = source_end.check_first_line(language, fs.read(path), version)
    if not ok then
        findings[#findings + 1] = why
    end
    ok, why = source_end.check_parse(language, path)
    if not ok then
        findings[#findings + 1] = "it does not parse: " .. why
    end
    if #findings > 0 then
        return nil, findings
    end
    return true
end
-- }}}

-- The `.src` paintbrush (docs/067's "Each end" row): a canvas of one
-- `canvas{}` (category `source`) and one `source{}`.
source_end.SRC = {
    name = "src",
    source = "src/153-the-source-end.lua",
    words = {
        canvas = {
            doc = "what the canvas is: a source file, with its seed", once = true, required = true,
            order = { "category", "seed" },
            fields = {
                category = { type = "category", required = true, doc = "always `source` for this paintbrush" },
                seed = { type = "whole", default = 1, doc = "the seed every random choice starts from" },
            },
        },
        source = {
            doc = "the one file to write", once = true, required = true,
            order = { "language", "version", "purpose", "prompt" },
            fields = {
                language = {
                    type = { doc = "one of " .. table.concat(source_end.names(), ", "), check = function(v)
                        if not source_end.LANGUAGES[v] then
                            return "wants one of " .. table.concat(source_end.names(), ", ") .. ", got '" .. tostring(v) .. "'",
                                wall.nearest(v, source_end.names())
                        end
                    end },
                    required = true, doc = "the file's language, a row of the language table",
                },
                version = { type = "text", required = true, doc = "the language's version, named on the file's first line" },
                purpose = { type = "text", required = true, doc = "what the file is for, in a sentence" },
                prompt = { type = "text", required = true, doc = "what the turn writing it is asked" },
            },
        },
    },
}

-- {{{ function source_end.read
-- A `.src` canvas's text through the wall: its `source{}` fields and seed,
-- or nil and every finding — a category other than `source` among them.
function source_end.read(text, where)
    local words, findings = wall.load(text, source_end.SRC, where)
    local canvas, source
    for _, w in ipairs(words) do
        if w.word == "canvas" then canvas = w end
        if w.word == "source" then source = w end
    end
    if canvas and canvas.fields.category and canvas.fields.category ~= "source" then
        findings[#findings + 1] = { line = canvas.line, word = "canvas",
            message = "a .src canvas's category is 'source', not '" .. canvas.fields.category .. "'", suggestion = "source" }
    end
    if #findings > 0 then
        return nil, findings
    end
    local out = {}
    for k, v in pairs(source.fields) do
        out[k] = v
    end
    out.seed = canvas.fields.seed
    out.first_line = source_end.first_line(out.language, out.version)
    out.extension = source_end.LANGUAGES[out.language].extension
    return out
end
-- }}}

return source_end
