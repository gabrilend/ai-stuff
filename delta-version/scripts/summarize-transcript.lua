#!/usr/bin/env luajit
-- summarize-transcript.lua - one conversation transcript, boiled down to a
-- summary, a one-sentence title, a file-name slug and a short paragraph.
--
-- Issue 056b. Most saved conversations are longer than the local model can
-- read at once, so this reads as much as fits, summarises that slice, moves
-- on to the next slice, and then summarises the summaries, again and again
-- if need be, until one summary is left (map, then reduce). Two more passes
-- turn that summary into a title of one sentence and a paragraph for a table
-- of contents. Slices are cut only between exchanges (a "### User Request N"
-- and the "### Assistant Response N" parts that answer it), so a request is
-- never read apart from its answer, unless one exchange is itself too big to
-- fit; then it is cut between lines.
--
-- It changes no file. The result goes to standard output or to --out=FILE,
-- for apply-summary.sh (056c) to fold into the transcript folder.
--
-- Usage: summarize-transcript.lua TRANSCRIPT [--out=FILE] [--json] [--quiet]
--                                 [--context=N] [--reserve=N] [--overhead=N]
--                                 [--plan]
--   --context   the model's context size in tokens (default 16384, the
--               words-pdf llama.cpp server's --ctx-size)
--   --reserve   tokens kept free for the model's answer (default 1024)
--   --overhead  tokens kept free for the instruction (default 512)
--               A slice holds at most context - reserve - overhead tokens.
--   --json      write the result as JSON instead of the plain record
--   --quiet     no progress lines on standard error
--   --plan      print how the transcript would be sliced (each slice's turns
--               and tokens) and stop; only /tokenize is called, so it shows
--               the cost of a run before the model is asked anything
--
-- Plain record (the default; apply-summary.sh reads it):
--   transcript-summary v1
--   conversation: <id from the "# Conversation Summary:" line>
--   source: <transcript path>
--   title: <one sentence>
--   slug: <lowercase-words-joined-by-dashes, at most 60 characters>
--   slices: <N>
--   levels: <reduce levels, 0 when one slice was enough>
--
--   ## Blurb
--   <one paragraph>
--
--   ## Summary
--   <the final summary>
--
-- Token counts come from the server's /tokenize, so slices are sized exactly.
-- The model is reached through libs/llama-chat-client.lua; INFERENCE_CHAT_HOST
-- moves it. Exit status: 0 done, 1 the model failed or could not be reached,
-- 2 usage error or nothing to summarise.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local config = {
    context = 16384,
    reserve = 1024,
    overhead = 512,
    title_tokens = 120,
    blurb_tokens = 400,
    max_levels = 12,
    slug_limit = 60,
    record_version = "transcript-summary v1",
    prompts = {
        slice = table.concat({
            "Task: summarize-slice.",
            "You are reading a slice of a software-development session transcript",
            "between a user and an AI assistant. Summarise what happened in it:",
            "the decisions made, the mechanisms built or changed, and the outcomes.",
            "Leave out pleasantries and play-by-play. Write plain prose, no headings.",
        }, "\n"),
        merge = table.concat({
            "Task: merge-summaries.",
            "You are given summaries of consecutive slices of one software-development",
            "session between a user and an AI assistant, in order. Merge them into one",
            "summary that keeps the decisions, mechanisms and outcomes and drops",
            "repetition. Write plain prose, no headings.",
        }, "\n"),
        title = table.concat({
            "Task: title.",
            "Here is the summary of a software-development session. Reply with one",
            "sentence, at most twelve words, saying what the session did. No quotes,",
            "no preamble.",
        }, "\n"),
        blurb = table.concat({
            "Task: blurb.",
            "Here is the summary of a software-development session. Reply with one",
            "paragraph of three to five sentences for a table of contents: what the",
            "session set out to do, what it decided, and what it left. No headings.",
        }, "\n"),
    },
}
-- }}}

-- {{{ Utility Functions
local quiet = false

-- {{{ local function fail()
local function fail(code, message)
    io.stderr:write("summarize-transcript: " .. message .. "\n")
    os.exit(code)
end
-- }}}

-- {{{ local function note()
local function note(message)
    if not quiet then io.stderr:write("summarize-transcript: " .. message .. "\n") end
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

-- {{{ local function trim()
local function trim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ local function clean_answer()
-- The model's answer without a reasoning block (Qwen3 opens with
-- <think>...</think> unless told not to) and without surrounding space.
local function clean_answer(text)
    text = text:gsub("<think>.-</think>", "")
    text = text:gsub("^.-</think>", "")   -- a block whose opening tag was cut off
    return trim(text)
end
-- }}}
-- }}}

-- {{{ local function split_turns()
-- The transcript's header ("# Conversation Summary: ID", the generation line)
-- and its exchanges. An exchange runs from one "### User Request" heading to
-- the next, so the answer (and its "(continued)" parts) stays with its
-- request; an answer before any request (a continued session) opens an
-- exchange of its own. The exporter's separator lines stay with the exchange
-- before them. A file with no exchange headings is split at blank lines
-- instead, so any text can be summarised.
local function is_exchange_heading(line)
    return line:match("^### User Request") or line:match("^### Assistant Response")
end

local function split_turns(text)
    local header, turns, current = {}, {}, nil
    local has_exchanges = text:find("\n### User Request", 1, true)
        or text:find("\n### Assistant Response", 1, true)
    if not has_exchanges then
        for block in (text .. "\n\n"):gmatch("(.-)\n%s*\n") do
            if block:match("%S") then turns[#turns + 1] = block end
        end
        return "", turns
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^### User Request") or (not current and is_exchange_heading(line)) then
            current = { line }
            turns[#turns + 1] = current
        elseif current then
            current[#current + 1] = line
        else
            header[#header + 1] = line
        end
    end
    for index, lines in ipairs(turns) do turns[index] = trim(table.concat(lines, "\n")) end
    return table.concat(header, "\n"), turns
end
-- }}}

-- {{{ local function conversation_id()
local function conversation_id(header)
    return header:match("# Conversation Summary:%s*(%S+)") or ""
end
-- }}}

-- {{{ Sizing and slicing
local client

-- {{{ local function tokens()
local function tokens(text)
    local count, err = client.count_tokens(text)
    if not count then fail(1, "could not count tokens: " .. tostring(err)) end
    return count
end
-- }}}

-- {{{ local function split_oversized()
-- A single turn bigger than a slice is cut between lines, so no slice ever
-- overflows. (A single line bigger than a slice is cut between words.)
local function split_oversized(turn, budget)
    local pieces, current, current_size = {}, {}, 0
    local function close()
        if #current > 0 then pieces[#pieces + 1] = table.concat(current, "\n") end
        current, current_size = {}, 0
    end
    for line in (turn .. "\n"):gmatch("([^\n]*)\n") do
        local size = tokens(line) + 1
        if size > budget then
            close()
            local words = {}
            for word in line:gmatch("%S+") do
                words[#words + 1] = word
                if tokens(table.concat(words, " ")) >= budget then
                    table.remove(words)
                    pieces[#pieces + 1] = table.concat(words, " ")
                    words = { word }
                end
            end
            if #words > 0 then pieces[#pieces + 1] = table.concat(words, " ") end
        else
            if current_size + size > budget then close() end
            current[#current + 1] = line
            current_size = current_size + size
        end
    end
    close()
    return pieces
end
-- }}}

-- {{{ local function pack()
-- Packs texts, in order, into groups whose token total stays within the
-- budget. Each text is counted once; one token per join is allowed for.
-- Returns groups of texts and how many oversized texts had to be cut.
local function pack(texts, budget)
    local groups, current, current_size, cut = {}, {}, 0, 0
    local function close()
        if #current > 0 then groups[#groups + 1] = current end
        current, current_size = {}, 0
    end
    for _, text in ipairs(texts) do
        local size = tokens(text) + 1
        if size > budget then
            close()
            cut = cut + 1
            for _, piece in ipairs(split_oversized(text, budget)) do groups[#groups + 1] = { piece } end
        else
            if current_size + size > budget then close() end
            current[#current + 1] = text
            current_size = current_size + size
        end
    end
    close()
    return groups, cut
end
-- }}}
-- }}}

-- {{{ local function ask()
local function ask(prompt, text, max_tokens, what)
    local answer, err = client.complete(prompt, text, { max_tokens = max_tokens })
    if not answer then fail(1, what .. ": " .. tostring(err)) end
    answer = clean_answer(answer)
    if answer == "" then fail(1, what .. ": the model gave an empty answer") end
    return answer
end
-- }}}

-- {{{ local function summarize()
-- Map, then reduce until one summary is left. Returns the summary, the
-- number of slices and the number of reduce levels.
local function summarize(turns, budget)
    local slices, cut = pack(turns, budget)
    if cut > 0 then note(string.format("%d exchange(s) bigger than a slice were cut between lines", cut)) end
    note(string.format("map: %d slice(s) of at most %d tokens", #slices, budget))
    local summaries = {}
    for index, slice in ipairs(slices) do
        summaries[index] = ask(config.prompts.slice, table.concat(slice, "\n\n"), config.reserve,
            string.format("slice %d of %d", index, #slices))
    end

    local level = 0
    while #summaries > 1 do
        level = level + 1
        if level > config.max_levels then
            fail(1, "the summaries did not come down to one after " .. config.max_levels .. " levels")
        end
        local groups = pack(summaries, budget)
        if #groups >= #summaries then
            fail(1, string.format("level %d: %d summaries do not fit together in a slice, so " ..
                "merging cannot shrink them; raise --context or lower --reserve", level, #summaries))
        end
        local merged = {}
        for index, group in ipairs(groups) do
            merged[index] = ask(config.prompts.merge, table.concat(group, "\n\n"), config.reserve,
                string.format("level %d, group %d of %d", level, index, #groups))
        end
        note(string.format("reduce level %d: %d -> %d", level, #summaries, #merged))
        summaries = merged
    end
    return summaries[1], #slices, level
end
-- }}}

-- {{{ local function first_sentence()
local function first_sentence(text)
    local line = ""
    for candidate in text:gmatch("[^\n]+") do
        if candidate:match("%S") then line = candidate break end
    end
    line = trim(line:gsub("^#+%s*", ""):gsub("[*_`]", ""))
    line = line:gsub('^["\'“]+', ""):gsub('["\'”]+$', "")
    local sentence = line:match("^(.-[%.!?])%s") or line
    return trim(sentence)
end
-- }}}

-- {{{ local function slugify()
-- Lowercase ASCII words joined by "-", at most config.slug_limit characters,
-- cut at a word boundary.
local function slugify(title)
    local slug = title:lower():gsub("[^a-z0-9]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
    if #slug > config.slug_limit then
        slug = slug:sub(1, config.slug_limit)
        local cut = slug:match("^(.*)%-[^%-]*$")
        if cut and #cut > 0 then slug = cut end
    end
    if slug == "" then slug = "untitled-session" end
    return slug
end
-- }}}

-- {{{ Output
-- {{{ local function render_record()
local function render_record(result)
    return table.concat({
        config.record_version,
        "conversation: " .. result.conversation,
        "source: " .. result.source,
        "title: " .. result.title,
        "slug: " .. result.slug,
        "slices: " .. result.slices,
        "levels: " .. result.levels,
        "",
        "## Blurb",
        result.blurb,
        "",
        "## Summary",
        result.summary,
        "",
    }, "\n")
end
-- }}}

-- {{{ local function render_json()
local function render_json(result)
    local root = os.getenv("AISTUFF_ROOT") or "/mnt/mtwo/programming/ai-stuff"
    package.path = root .. "/libs/lua/?.lua;" .. package.path
    local json = require("dkjson")
    return json.encode(result, { indent = true, keyorder = { "conversation", "source", "title",
        "slug", "slices", "levels", "blurb", "summary" } }) .. "\n"
end
-- }}}
-- }}}

-- {{{ local function parse_arguments()
local function parse_arguments(argv)
    local options = { json = false }
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key == "out" then options.out = value
        elseif key == "context" or key == "reserve" or key == "overhead" then
            options[key] = tonumber(value)
            if not options[key] or options[key] < 1 then fail(2, "--" .. key .. " needs a positive number") end
        elseif argument == "--json" then options.json = true
        elseif argument == "--plan" then options.plan = true
        elseif argument == "--quiet" then quiet = true
        elseif argument == "--help" or argument == "-h" then
            for line in (read_file(arg[0]) or ""):gmatch("[^\n]*") do
                if line:match("^%-%- ") or line == "--" then print((line:gsub("^%-%- ?", ""))) end
                if line:match("^%-%- {{{") then break end
            end
            os.exit(0)
        elseif argument:match("^%-%-") then fail(2, "unknown option " .. argument)
        elseif not options.transcript then options.transcript = argument
        else fail(2, "one transcript at a time") end
    end
    if not options.transcript then fail(2, "usage: summarize-transcript.lua TRANSCRIPT [--out=FILE] [--json]") end
    return options
end
-- }}}

-- {{{ local function main()
local function main(argv)
    local options = parse_arguments(argv)
    config.context = options.context or config.context
    config.reserve = options.reserve or config.reserve
    config.overhead = options.overhead or config.overhead
    local budget = config.context - config.reserve - config.overhead
    if budget < 16 then fail(2, "context - reserve - overhead leaves only " .. budget .. " tokens for a slice") end

    local text = read_file(options.transcript)
    if not text then fail(2, "cannot read " .. options.transcript) end
    local header, turns = split_turns(text)
    if #turns == 0 then fail(2, options.transcript .. " holds nothing to summarise") end

    client = require("llama-chat-client")
    if not client.is_reachable() then
        fail(1, "the model is not reachable at " .. client.endpoint() ..
            "; start it with words-pdf/scripts/start-llamacpp-server.sh")
    end

    if options.plan then
        local slices, cut = pack(turns, budget)
        print(string.format("%d exchange(s) in %d slice(s) of at most %d tokens%s", #turns, #slices, budget,
            cut > 0 and string.format("; %d oversized exchange(s) cut between lines", cut) or ""))
        for index, slice in ipairs(slices) do
            local size = 0
            for _, piece in ipairs(slice) do size = size + tokens(piece) + 1 end
            print(string.format("slice %d: %d piece(s), %d tokens, from \"%s\" to \"%s\"", index, #slice, size,
                slice[1]:match("^[^\n]*"), slice[#slice]:match("^[^\n]*")))
        end
        return
    end

    local summary, slices, levels = summarize(turns, budget)
    local title = first_sentence(ask(config.prompts.title, summary, config.title_tokens, "title"))
    if title == "" then fail(1, "title: the model's answer held no sentence") end
    local blurb = ask(config.prompts.blurb, summary, config.blurb_tokens, "blurb")
    blurb = trim(blurb:gsub("%s*\n%s*", " "))

    local result = {
        conversation = conversation_id(header), source = options.transcript,
        title = title, slug = slugify(title), slices = slices, levels = levels,
        blurb = blurb, summary = summary,
    }
    local rendered = options.json and render_json(result) or render_record(result)
    if options.out then
        local file = io.open(options.out, "w")
        if not file then fail(2, "cannot write " .. options.out) end
        file:write(rendered)
        file:close()
        note("wrote " .. options.out)
    else
        io.write(rendered)
    end
end
-- }}}

main(arg)
