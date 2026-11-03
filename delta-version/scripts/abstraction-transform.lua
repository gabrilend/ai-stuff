#!/usr/bin/env luajit
-- abstraction-transform.lua - a transcript rewritten as documentation at one
-- of three abstraction levels.
--
-- Issue 049b. The input is a conversation transcript, usually one already cut
-- down by transcript-detail.lua (049a). It is split into sections (each "###
-- User Request" with the response that follows it, or each "### " heading in
-- other files), long sections into chunks of about 800 words, and the local
-- model rewrites each chunk:
--
--   high    what the parts do and how they connect: inputs, outputs, routes
--   medium  what features do and roughly how, key decisions, workflow steps
--   low     the patterns and choices a maintainer needs, described in words
--
-- The result is one Markdown document with a table of contents and numbered
-- sections. A chunk the model cannot rewrite (no answer, or with --validate an
-- answer that fails the checks three retries running) is kept as written,
-- under a one-line marker that gives the reason, so nothing is lost.
--
-- Usage: abstraction-transform.lua TRANSCRIPT --level=high|medium|low
--                                  [--validate] [--cache=FILE] [--detail=N]
--                                  [--title=NAME] [--prompts=FILE]
--                                  [--out=FILE | --write] [--report] [--quiet]
--        abstraction-transform.lua TRANSCRIPT --compare-levels [same options]
--   --validate        check each rewrite and retry (up to 3 times) when it
--                     fails: no code outside low abstraction (and in low only
--                     at detail level 4 or 5), input and output named at high,
--                     at least a fifth of the original words kept
--   --cache=FILE      keep each rewrite here by (text, level) and reuse it
--   --detail=N        the detail level the input was cut to (1-5); otherwise
--                     read from transcript-detail's "left out" markers, or 5
--   --compare-levels  one document with every section at all three levels
--   --out=FILE        write the document here (never over an existing file)
--   --write           write it under the transcript's llm-transcripts folder,
--                     in generated/{level}-abstraction/ (never over a file)
--   --report          print each chunk's outcome instead of the document
--
-- Prompts come from ../config/abstraction-prompts.lua. The model is reached
-- through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST moves it). Exit
-- status: 0 done, 1 the model answered none of the chunks asked of it, 2
-- usage error or refused write.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. package.path
local PROMPTS_FILE = SCRIPT_DIR .. "/../config/abstraction-prompts.lua"
-- }}}

-- {{{ Configuration
local config = {
    levels = { "high", "medium", "low" },
    chunk_words = 800,        -- a chunk grows until the next paragraph would pass this
    max_retries = 3,          -- retries after a rejected rewrite, with --validate
    min_word_ratio = 0.2,     -- a rewrite keeps at least this share of the words
    code_detail = 4,          -- low abstraction may hold code from this detail level up
    temperature = 0.3,
    max_tokens = 1024,
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("abstraction-transform: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local file = io.open(path, "r")
    if file then file:close() return true end
    return false
end
-- }}}

-- {{{ local function fingerprint()
-- FNV-1a, 32 bits, as transcript-detail.lua uses for its saved classes.
local function fingerprint(text)
    local hash = 2166136261
    for index = 1, #text do
        hash = bit.bxor(hash, text:byte(index))
        hash = bit.tobit(hash * 16777619)
    end
    return bit.tohex(hash)
end
-- }}}

-- {{{ local function words()
local function words(text)
    local count = 0
    for _ in text:gmatch("%S+") do count = count + 1 end
    return count
end
-- }}}

-- {{{ local function trim()
local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ local function cut()
-- The first LIMIT bytes of TEXT, backed off to a whole UTF-8 character.
local function cut(text, limit)
    if #text <= limit then return text end
    local stop = limit
    while stop > 0 and text:byte(stop + 1) and text:byte(stop + 1) >= 0x80
        and text:byte(stop + 1) < 0xC0 do
        stop = stop - 1
    end
    return text:sub(1, stop) .. "..."
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}
-- }}}

-- {{{ local function split_units()
-- preamble, units, detail. A unit is one exchange (a "### User Request"
-- heading with the "### Assistant Response" after it) in a transcript that
-- has them, or one "### " section in any other file. transcript-detail.lua's
-- "*[N sections left out at detail level D]*" lines are taken out of the text
-- and kept as notes on the unit before them; D is returned as the detail level.
local MARKER = "^%*%[%d+ sections? left out at detail level (%d)%]%*$"

local function split_units(text)
    local exchanges = text:find("\n### User Request", 1, true) ~= nil
        or text:sub(1, 16) == "### User Request"
    local preamble, units, current, detail = {}, {}, nil, nil
    local lead_notes = {}
    local function start(line)
        current = { heading = line, lines = { line }, notes = {} }
        units[#units + 1] = current
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local marked = line:match(MARKER)
        if marked then
            detail = tonumber(marked)
            if current then current.notes[#current.notes + 1] = line
            else lead_notes[#lead_notes + 1] = line end
        elseif exchanges and line:match("^### User Request") then
            start(line)
        elseif exchanges and line:match("^### Assistant Response") then
            -- The answer joins its request; a second answer, or one with no
            -- request before it, is a unit of its own.
            if not (current and current.heading:match("^### User Request") and not current.answered) then
                start(line)
            else
                current.lines[#current.lines + 1] = line
            end
            current.answered = true
        elseif not exchanges and line:match("^### ") then
            start(line)
        elseif current then
            current.lines[#current.lines + 1] = line
        else
            preamble[#preamble + 1] = line
        end
    end
    for _, unit in ipairs(units) do
        unit.text = trim(table.concat(unit.lines, "\n"))
        unit.lines = nil
    end
    return trim(table.concat(preamble, "\n")), units, detail, lead_notes
end
-- }}}

-- {{{ local function title_of()
-- An exchange is named by the first line of its request; a section by its
-- heading.
local function title_of(unit)
    local heading = unit.heading:gsub("^###%s*", "")
    if unit.heading:match("^### User Request") then
        for line in unit.text:gmatch("[^\n]+") do
            if not line:match("^###") and line:match("%S") then
                return cut(trim(line:gsub("^[#>*%-%s]+", "")), 60)
            end
        end
    end
    return cut(trim(heading), 60)
end
-- }}}

-- {{{ local function chunks_of()
-- Paragraphs (blank-line separated, never splitting a ``` block) gathered
-- into chunks of about config.chunk_words. One paragraph longer than that is
-- a chunk of its own, whole.
local function chunks_of(text)
    local paragraphs, current, fenced = {}, {}, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^%s*```") then fenced = not fenced end
        if line:match("^%s*$") and not fenced then
            if #current > 0 then paragraphs[#paragraphs + 1] = table.concat(current, "\n") end
            current = {}
        else
            current[#current + 1] = line
        end
    end
    if #current > 0 then paragraphs[#paragraphs + 1] = table.concat(current, "\n") end

    local chunks, gathered, count = {}, {}, 0
    for _, paragraph in ipairs(paragraphs) do
        local size = words(paragraph)
        if count > 0 and count + size > config.chunk_words then
            chunks[#chunks + 1] = table.concat(gathered, "\n\n")
            gathered, count = {}, 0
        end
        gathered[#gathered + 1] = paragraph
        count = count + size
    end
    if #gathered > 0 then chunks[#chunks + 1] = table.concat(gathered, "\n\n") end
    return chunks
end
-- }}}

-- {{{ local function validate()
-- ok, reason. The checks from the issue: code only in low abstraction and
-- only at detail level 4 or 5, input and output named at high, and the
-- rewrite not shrunk below a fifth of the original's words.
local function code_allowed(level, detail)
    return level == "low" and detail >= config.code_detail
end

local function validate(original, rewrite, level, detail)
    if rewrite:match("```") and not code_allowed(level, detail) then
        return false, "a code block at " .. level .. " abstraction"
            .. (level == "low" and (", detail level " .. detail) or "")
    end
    if level == "high" then
        local lower = rewrite:lower()
        if not (lower:find("input", 1, true) and lower:find("output", 1, true)) then
            return false, "no inputs and outputs named at high abstraction"
        end
    end
    if words(rewrite) < words(original) * config.min_word_ratio then
        return false, "under a fifth of the original words"
    end
    return true
end
-- }}}

-- {{{ Cache
-- One line per rewrite: key, tab, the text with \ \n \t escaped. New
-- rewrites are appended, so the file only grows.
local function escape(text)
    return (text:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t"))
end

local function unescape(text)
    return (text:gsub("\\(.)", { ["\\"] = "\\", n = "\n", t = "\t" }))
end

local function load_cache(path)
    local cache = {}
    for line in (read_file(path or "") or ""):gmatch("[^\n]+") do
        local key, value = line:match("^(%x+%-[%w%-]+)\t(.*)$")
        if key then cache[key] = unescape(value) end
    end
    return cache
end

local function cache_key(chunk, level, detail)
    local variant = level
    if level == "low" and not code_allowed(level, detail) then variant = "low-nocode" end
    return fingerprint(chunk) .. "-" .. variant
end
-- }}}

-- {{{ local function load_prompts()
local function load_prompts(path)
    local chunk, err = loadfile(path)
    if not chunk then fail("cannot read the prompts: " .. tostring(err)) end
    local ok, prompts = pcall(chunk)
    if not ok or type(prompts) ~= "table" then fail("the prompts file must return a table: " .. path) end
    for _, level in ipairs(config.levels) do
        if type(prompts[level]) ~= "string" then fail("the prompts file has no " .. level .. " prompt") end
    end
    return prompts
end
-- }}}

-- {{{ local function transform_chunk()
-- text, outcome ("rewritten", "cached" or "kept") and, when kept, the reason.
local function transform_chunk(state, chunk, level)
    local key = cache_key(chunk, level, state.detail)
    if state.cache[key] then return state.cache[key], "cached" end

    local system = state.prompts[level]
    if level == "low" and not code_allowed(level, state.detail) then
        system = system .. "\nInclude no code blocks."
    end
    -- Once the server cannot be reached, the rest is kept without asking,
    -- so a stopped server costs one timeout, not one per chunk.
    if state.down then return chunk, "kept", "the model could not be reached" end
    local tries = state.validate and (1 + config.max_retries) or 1
    local reason
    state.asked = state.asked + 1
    for _ = 1, tries do
        local prompt = system
        if reason then
            prompt = prompt .. "\nYour last answer was rejected (" .. reason .. "). Fix that."
        end
        local answer, err = state.client.complete(prompt, chunk,
            { temperature = config.temperature, max_tokens = config.max_tokens })
        if not answer then
            state.unanswered = state.unanswered + 1
            err = tostring(err)
            if err:match("^unreachable") or err:match("^no reply") then
                state.down = true
                return chunk, "kept", "the model could not be reached"
            end
            return chunk, "kept", "no answer from the model: " .. cut(err, 80)
        end
        answer = trim(answer:gsub("<think>.-</think>", ""))
        local ok = answer ~= ""
        if not ok then reason = "an empty answer"
        elseif state.validate then ok, reason = validate(chunk, answer, level, state.detail) end
        if ok then
            state.cache[key] = answer
            state.new_cache[#state.new_cache + 1] = key .. "\t" .. escape(answer)
            return answer, "rewritten"
        end
    end
    return chunk, "kept", reason
end
-- }}}

-- {{{ local function transform_units()
-- Gives each unit .results[level] = { text, chunks = { {outcome, reason, words, words_out} } }.
local function transform_units(state, units, levels)
    local total = #units * #levels
    local step = 0
    for _, level in ipairs(levels) do
        for index, unit in ipairs(units) do
            step = step + 1
            if not state.quiet then
                io.stderr:write(string.format("abstraction-transform: [%d/%d] %s: %s\n",
                    step, total, level, unit.title))
            end
            local parts, record = {}, {}
            for _, chunk in ipairs(chunks_of(unit.text)) do
                local text, outcome, reason = transform_chunk(state, chunk, level)
                state.counts[outcome] = state.counts[outcome] + 1
                if outcome == "kept" then
                    state.reasons[reason] = (state.reasons[reason] or 0) + 1
                    text = "*[kept as written: " .. reason .. "]*\n\n" .. text
                end
                parts[#parts + 1] = text
                record[#record + 1] = { outcome = outcome, reason = reason,
                    words = words(chunk), words_out = words(outcome == "kept" and chunk or text) }
            end
            unit.results = unit.results or {}
            unit.results[level] = { text = table.concat(parts, "\n\n"), chunks = record }
            unit.index = index
        end
    end
end
-- }}}

-- {{{ local function assemble()
-- The document: header, table of contents, numbered sections, each followed
-- by the notes of what transcript-detail left out after it.
local function assemble(meta, units, levels, lead_notes)
    local compare = #levels > 1
    local out = {}
    out[#out + 1] = string.format("# %s - %s, Detail Level %d\n", meta.name,
        compare and "Abstraction Levels Compared" or (levels[1]:upper() .. " Abstraction"), meta.detail)
    out[#out + 1] = "Generated: " .. os.date("%Y-%m-%d %H:%M")
    out[#out + 1] = "Source: " .. meta.source
    out[#out + 1] = "Sections: " .. #units .. "\n"
    out[#out + 1] = "---\n"
    out[#out + 1] = "## Table of Contents\n"
    for index, unit in ipairs(units) do
        out[#out + 1] = string.format("%d. [%s](#section-%d)", index, unit.title, index)
    end
    out[#out + 1] = "\n---\n"
    for _, note in ipairs(lead_notes) do out[#out + 1] = note .. "\n" end
    for index, unit in ipairs(units) do
        out[#out + 1] = string.format('<a id="section-%d"></a>\n', index)
        out[#out + 1] = string.format("## Section %d: %s\n", index, unit.title)
        for _, level in ipairs(levels) do
            if compare then out[#out + 1] = "### " .. level:sub(1, 1):upper() .. level:sub(2) .. "\n" end
            out[#out + 1] = unit.results[level].text .. "\n"
        end
        for _, note in ipairs(unit.notes) do out[#out + 1] = note .. "\n" end
        out[#out + 1] = "---\n"
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function report()
local function report(units, levels)
    local lines = {}
    for index, unit in ipairs(units) do
        for _, level in ipairs(levels) do
            for part, chunk in ipairs(unit.results[level].chunks) do
                lines[#lines + 1] = string.format("%3d.%d  %-6s %-9s %5d -> %-5d %s%s", index, part,
                    level, chunk.outcome, chunk.words, chunk.words_out, unit.title,
                    chunk.reason and ("  (" .. chunk.reason .. ")") or "")
            end
        end
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ local function write_path()
-- Where --write puts the document: the llm-transcripts folder the transcript
-- sits in, generated/{level}-abstraction/ (or compare-levels/).
local function write_path(source, levels)
    local root = source:match("^(.*llm%-transcripts)/")
    if not root then
        fail("--write needs a transcript inside an llm-transcripts folder; use --out=FILE")
    end
    local folder = root .. "/generated/" .. (#levels > 1 and "compare-levels" or (levels[1] .. "-abstraction"))
    return folder, folder .. "/" .. source:match("([^/]*)$")
end
-- }}}

-- {{{ local function show_help()
local function show_help()
    local file = io.open(arg[0], "r")
    if not file then return end
    for line in file:lines() do
        if line:match("^%-%- {{{") then break end
        if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
    end
    file:close()
end
-- }}}

-- {{{ main
local function main(argv)
    local options, path = {}, nil
    local valued = { level = true, cache = true, detail = true, title = true, prompts = true, out = true }
    local flags = { validate = true, ["compare-levels"] = true, write = true, report = true, quiet = true }
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        local flag = argument:match("^%-%-([%w%-]+)$")
        if key and valued[key] and options[key] == nil then options[key] = value
        elseif flag and flags[flag] and not options[flag] then options[flag] = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") and not path then path = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not path then fail("name a transcript") end

    local levels
    if options["compare-levels"] then
        if options.level then fail("--compare-levels makes all three levels; leave out --level") end
        levels = config.levels
    elseif options.level == "high" or options.level == "medium" or options.level == "low" then
        levels = { options.level }
    else
        fail("--level takes high, medium or low (or use --compare-levels)")
    end
    if options.out and options.write then fail("--out and --write both name where to write; give one") end
    if options.out and options.out == path then fail("--out would overwrite the transcript itself") end
    if options.out and exists(options.out) then fail(options.out .. " already exists; nothing written") end
    local folder, target = nil, options.out
    if options.write then
        folder, target = write_path(path, levels)
        if exists(target) then fail(target .. " already exists; nothing written") end
    end

    local text = read_file(path) or fail("cannot read " .. path)
    local preamble, units, marked_detail, lead_notes = split_units(text)
    local detail = marked_detail or 5
    if options.detail then
        detail = tonumber(options.detail)
        if not detail or detail < 1 or detail > 5 or detail % 1 ~= 0 then
            fail("--detail takes a level from 1 to 5")
        end
    end
    if #units == 0 then fail("no sections found in " .. path .. " (no \"### \" headings)") end
    for _, unit in ipairs(units) do unit.title = title_of(unit) end

    local state = {
        client = require("llama-chat-client"),
        prompts = load_prompts(options.prompts or PROMPTS_FILE),
        cache = load_cache(options.cache), new_cache = {},
        validate = options.validate, detail = detail, quiet = options.quiet,
        asked = 0, unanswered = 0,
        counts = { rewritten = 0, cached = 0, kept = 0 }, reasons = {},
    }
    transform_units(state, units, levels)

    if options.cache and #state.new_cache > 0 then
        local file = io.open(options.cache, "a")
        if file then
            file:write(table.concat(state.new_cache, "\n") .. "\n")
            file:close()
        else
            io.stderr:write("abstraction-transform: could not save the cache to " .. options.cache .. "\n")
        end
    end

    local meta = { name = options.title or path:match("([^/]*)$"):gsub("%.md$", ""),
        source = path, detail = detail }
    local result = options.report and report(units, levels) or assemble(meta, units, levels, lead_notes)
    if target and not options.report then
        if folder then os.execute("mkdir -p " .. shell_quote(folder)) end
        local file = io.open(target, "w") or fail("cannot write " .. target)
        file:write(result)
        file:close()
    else
        io.write(result)
    end

    local why = {}
    for reason, count in pairs(state.reasons) do why[#why + 1] = count .. " " .. reason end
    table.sort(why)
    io.stderr:write(string.format("abstraction-transform: %s, detail level %d, %d sections: "
        .. "%d chunks rewritten, %d from the cache, %d kept as written%s%s\n",
        table.concat(levels, "+"), detail, #units, state.counts.rewritten, state.counts.cached,
        state.counts.kept, #why > 0 and (" (" .. table.concat(why, "; ") .. ")") or "",
        (target and not options.report) and ("; written to " .. target) or ""))
    if state.asked > 0 and state.unanswered == state.asked then return 1 end
    return 0
end
-- }}}

os.exit(main(arg))
