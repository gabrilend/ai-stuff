#!/usr/bin/env luajit
-- claudemd-why.lua - why a guideline exists, found in the saved
-- conversations that led to it.
--
-- Issue 040, its transcript memory (040g), smallest useful slice. Given a
-- guideline (its text, or a proposal id from claudemd-revise.lua), it reads
-- the saved conversations in llm-transcripts/ folders and finds the
-- exchanges that talk about it: those holding most of the guideline's key
-- words. The context pack at the top of each transcript (copies of
-- CLAUDE.md and the like) is skipped, so a guideline is not found merely
-- because it was already written down. The local model then drafts a
-- decision record from those exchanges: when it was decided, the context,
-- the alternatives considered, the reasoning. Every excerpt is cited by
-- file and line.
--
-- Transcripts are only ever read. The record is printed; --write saves it
-- as a new file in the analysis/ folder of claudemd-revise's state, which
-- lives outside every repository. An existing record is never replaced.
--
-- Usage: claudemd-why.lua GUIDELINE | ID [--transcripts=DIR]... [--dir=MONOREPO]
--                         [--state=DIR] [--no-model] [--most=N] [--write]
--   GUIDELINE        the guideline's words, or the id of a proposal (P001)
--   --transcripts=DIR  a folder of transcripts to read (repeatable); by
--                    default every */llm-transcripts/ folder of the monorepo
--   --dir=MONOREPO   default /mnt/mtwo/programming/ai-stuff
--   --state=DIR      claudemd-revise's state (default
--                    ~/.local/share/claudemd-revisions)
--   --no-model       print the evidence only
--   --most=N         at most N exchanges (default 5)
--   --write          save the record under STATE/analysis/
--
-- The model is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST
-- moves it). Exit status: 0 done, 1 nothing found or the model failed,
-- 2 usage error.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff"
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. SCRIPT_DIR .. "/../../libs/lua/?.lua;" .. package.path
local STATE = (os.getenv("XDG_DATA_HOME") or ((os.getenv("HOME") or ".") .. "/.local/share"))
    .. "/claudemd-revisions"
-- }}}

-- {{{ Configuration
local config = {
    most = 5,
    excerpt_chars = 1200,
    context_before = 4,     -- lines kept before the line that talks about it
    context_after = 10,     -- and after
    min_word = 4,
    stopwords = {
        "about", "after", "also", "always", "been", "before", "every", "from", "have", "into",
        "just", "like", "make", "more", "must", "never", "only", "over", "same", "should",
        "some", "than", "that", "their", "them", "then", "there", "these", "they", "this",
        "those", "under", "used", "uses", "using", "very", "what", "when", "where", "which",
        "while", "will", "with", "without", "would", "your",
    },
    exchange_start = "^### User Request",
    conversation_start = "^## .*Conversation",
    system_prompt = table.concat({
        "Task: decision-record.",
        "You reconstruct why a guideline for an AI coding assistant exists, from excerpts of the",
        "conversations where it came up. Write a decision record with the sections",
        "\"## Decision moment\", \"## Context\", \"## Alternatives considered\" and \"## Reasoning\".",
        "Use only what the excerpts say, cite them as [1], [2] and so on, and write \"not in the",
        "excerpts\" for anything they do not show.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("claudemd-why: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function lines_of()
local function lines_of(command)
    local handle = io.popen(command .. " 2>/dev/null")
    local lines = {}
    if not handle then return lines end
    for line in handle:lines() do lines[#lines + 1] = line end
    handle:close()
    return lines
end
-- }}}

-- {{{ local function exists()
local function exists(path)
    local ok, _, code = os.rename(path, path)
    return ok or code == 13
end
-- }}}
-- }}}

-- {{{ local function guideline_of()
-- The guideline's words: given directly, or a proposal's from the state.
local function guideline_of(text)
    if not text:match("^P%d+$") then return text, nil end
    local file = io.open(STATE .. "/proposals.tsv", "r")
    if file then
        for line in file:lines() do
            local id, guideline = line:match("^([^\t]*)\t[^\t]*\t[^\t]*\t([^\t]*)")
            if id == text then file:close() return guideline, id end
        end
        file:close()
    end
    fail("no proposal " .. text .. " in " .. STATE .. "/proposals.tsv", 1)
end
-- }}}

-- {{{ local function key_words()
local function key_words(text)
    local stop, seen, words = {}, {}, {}
    for _, word in ipairs(config.stopwords) do stop[word] = true end
    for word in text:lower():gmatch("[%w][%w%-]*") do
        word = word:gsub("%-+$", "")
        if #word >= config.min_word and not stop[word] and not seen[word] then
            seen[word] = true
            words[#words + 1] = word
        end
    end
    return words
end
-- }}}

-- {{{ local function exchanges_of()
-- One transcript's exchanges: from each "### User Request" to the next, or
-- to the next conversation. Anything before the first is the context pack.
local function exchanges_of(path)
    local file = io.open(path, "r")
    if not file then return {} end
    local exchanges, current, number = {}, nil, 0
    for line in file:lines() do
        number = number + 1
        if line:match(config.exchange_start) then
            current = { path = path, line = number, lines = { line } }
            exchanges[#exchanges + 1] = current
        elseif line:match(config.conversation_start) then
            current = nil
        elseif current then
            current.lines[#current.lines + 1] = line
        end
    end
    file:close()
    return exchanges
end
-- }}}

-- {{{ local function focus_line()
-- Where in an exchange the guideline is talked about: the line holding the
-- most key words (the first such line).
local function focus_line(exchange, words)
    local best, best_hits = 1, -1
    for index, line in ipairs(exchange.lines) do
        local lower, hits = line:lower(), 0
        for _, word in ipairs(words) do
            if lower:find(word, 1, true) then hits = hits + 1 end
        end
        if hits > best_hits then best, best_hits = index, hits end
    end
    return best
end
-- }}}

-- {{{ local function find_evidence()
-- The exchanges holding the most key words: at least half of them (and at
-- least two, when there are two), the best first, at most `most`; then
-- shown oldest first by file name and line.
local function find_evidence(folders, words, most)
    local needed = math.max(math.min(2, #words), math.ceil(#words / 2))
    local found, files = {}, 0
    for _, folder in ipairs(folders) do
        for _, path in ipairs(lines_of("find " .. shell_quote(folder) .. " -maxdepth 1 -name '*.md' -type f | sort")) do
            files = files + 1
            for _, exchange in ipairs(exchanges_of(path)) do
                local text = table.concat(exchange.lines, "\n"):lower()
                local hits = 0
                for _, word in ipairs(words) do
                    if text:find(word, 1, true) then hits = hits + 1 end
                end
                if hits >= needed then
                    exchange.hits = hits
                    exchange.focus = focus_line(exchange, words)
                    found[#found + 1] = exchange
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.hits ~= b.hits then return a.hits > b.hits end
        if #a.lines ~= #b.lines then return #a.lines < #b.lines end
        if a.path ~= b.path then return a.path < b.path end
        return a.line < b.line
    end)
    local kept = {}
    for index = 1, math.min(most, #found) do kept[index] = found[index] end
    table.sort(kept, function(a, b)
        if a.path ~= b.path then return a.path < b.path end
        return a.line < b.line
    end)
    return kept, #found, files
end
-- }}}

-- {{{ local function excerpt()
-- The exchange's request line, then the lines around where the guideline
-- is talked about, cut to excerpt_chars.
local function excerpt(exchange)
    local from = math.max(2, exchange.focus - config.context_before)
    local out = { exchange.lines[1] }
    if from > 2 then out[#out + 1] = "[...]" end
    for index = from, math.min(#exchange.lines, exchange.focus + config.context_after) do
        out[#out + 1] = exchange.lines[index]
    end
    if exchange.focus + config.context_after < #exchange.lines then out[#out + 1] = "[...]" end
    local text = table.concat(out, "\n"):gsub("%s+$", "")
    if #text > config.excerpt_chars then text = text:sub(1, config.excerpt_chars) .. "\n[...]" end
    return text
end
-- }}}

-- {{{ local function transcript_folders()
local function transcript_folders(given)
    if #given > 0 then
        for _, folder in ipairs(given) do
            if not exists(folder) then fail(folder .. " does not exist", 1) end
        end
        return given
    end
    return lines_of("find " .. shell_quote(DIR) .. " -mindepth 2 -maxdepth 2 -type d -name llm-transcripts | sort")
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
    local options, folders, words = {}, {}, {}
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key == "transcripts" then folders[#folders + 1] = value
        elseif key and ({ dir = true, state = true, most = true })[key] then options[key] = value
        elseif argument == "--no-model" or argument == "--write" then options[argument:sub(3)] = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") then words[#words + 1] = argument
        else fail("unknown argument " .. argument .. " (see --help)") end
    end
    if options.dir then DIR = options.dir end
    if options.state then STATE = options.state end
    if #words == 0 then fail("name a guideline, by its words or its proposal id") end
    local most = tonumber(options.most or tostring(config.most))
    if not most or most < 1 or most % 1 ~= 0 then fail("--most takes a whole number") end

    local guideline, id = guideline_of(table.concat(words, " "))
    local keys = key_words(guideline)
    if #keys == 0 then fail("the guideline has no words to search for", 1) end
    local kept, total, files = find_evidence(transcript_folders(folders), keys, most)
    if #kept == 0 then
        print(string.format("No exchange in %d transcript%s talks about this (searched for: %s).",
            files, files == 1 and "" or "s", table.concat(keys, ", ")))
        return 1
    end

    local evidence = { "## Evidence", "",
        string.format("%d of %d matching exchanges, from %d transcripts; searched for: %s.",
            #kept, total, files, table.concat(keys, ", ")) }
    for index, exchange in ipairs(kept) do
        evidence[#evidence + 1] = ""
        evidence[#evidence + 1] = string.format("### [%d] %s, line %d", index, exchange.path,
            exchange.line + exchange.focus - 1)
        evidence[#evidence + 1] = ""
        for line in (excerpt(exchange) .. "\n"):gmatch("([^\n]*)\n") do
            evidence[#evidence + 1] = line == "" and ">" or ("> " .. line)
        end
    end

    local out = { "# Why: " .. guideline, "" }
    if id then
        out[#out + 1] = "Proposal " .. id .. " in claudemd-revise.lua's state."
        out[#out + 1] = ""
    end
    if not options["no-model"] then
        local prompt = { "Guideline: " .. guideline, "" }
        for index, exchange in ipairs(kept) do
            prompt[#prompt + 1] = string.format("[%d] (%s, line %d)", index, exchange.path,
                exchange.line + exchange.focus - 1)
            prompt[#prompt + 1] = excerpt(exchange)
            prompt[#prompt + 1] = ""
        end
        local record, why = require("llama-chat-client").complete(config.system_prompt, table.concat(prompt, "\n"))
        if not record or not record:match("%S") then fail("the model gave no record: " .. tostring(why), 1) end
        record = record:gsub("<think>.-</think>", ""):gsub("^%s+", ""):gsub("%s+$", "")
        out[#out + 1] = record
        out[#out + 1] = ""
    end
    for _, line in ipairs(evidence) do out[#out + 1] = line end
    out[#out + 1] = ""
    out[#out + 1] = string.format("<!-- drafted by claudemd-why.lua on %s%s; check it against the excerpts -->",
        os.date("%Y-%m-%d"), options["no-model"] and ", evidence only" or "")
    local text = table.concat(out, "\n") .. "\n"

    if options.write then
        local name = (id or guideline:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):sub(1, 40):gsub("%-+$", ""))
            .. "-" .. os.date("%Y-%m-%d") .. ".md"
        local path = STATE .. "/analysis/" .. name
        if exists(path) then fail(path .. " already exists and is never replaced", 1) end
        os.execute("mkdir -p " .. shell_quote(STATE .. "/analysis"))
        local file = io.open(path, "w") or fail("cannot write " .. path, 1)
        file:write(text)
        file:close()
        io.stderr:write("claudemd-why: written to " .. path .. "\n")
    else
        io.write(text)
    end
    return 0
end
-- }}}

os.exit(main(arg))
