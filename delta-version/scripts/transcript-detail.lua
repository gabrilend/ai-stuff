#!/usr/bin/env luajit
-- transcript-detail.lua - a transcript at a chosen level of detail.
--
-- Issue 049, its smallest useful slice (049a, detail level filtering). A
-- conversation transcript is split into its sections (the "### User Request
-- N" / "### Assistant Response N" headings, or any "### " heading). The local
-- model classes each section by importance, and the sections below the
-- chosen level are left out, with a one-line marker where they were. Nothing
-- is rewritten: what is kept is the original text, word for word.
--
--   Level  keeps                                   classes
--   1      major decisions and outcomes only       ESSENTIAL
--   2      ... and key discussion                  + IMPORTANT
--   3      ... and supporting context              + USEFUL
--   4      ... and repeated tries and long asides  + VERBOSE
--   5      everything; the model is not asked      + NOISE
--
-- A section the model could not class is kept and counted, so a missing or
-- unclear answer never hides anything.
--
-- Usage: transcript-detail.lua TRANSCRIPT --detail=1..5 [--out=FILE]
--                              [--classes=FILE] [--report]
--   --classes=FILE  keep each section's class here, and reuse it next time
--                   while the section's text is unchanged (so levels 1-4
--                   cost one pass of the model, not four)
--   --report        print each section's class and size instead of the text
--   --out=FILE      write the result here (never over the transcript itself)
--
-- The model is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST
-- moves it). Exit status: 0 done, 1 the model could not be reached for any
-- section, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. package.path
-- }}}

-- {{{ Configuration
local config = {
    weights = { ESSENTIAL = 100, IMPORTANT = 75, USEFUL = 50, VERBOSE = 25, NOISE = 0 },
    thresholds = { 100, 75, 50, 25, 0 },
    max_section_chars = 6000,
    system_prompt = table.concat({
        "Task: classify-section.",
        "You class one section of a conversation between a person and an AI assistant",
        "by how much it matters to someone reading the conversation later.",
        "ESSENTIAL: major decisions, architectural choices, final outcomes.",
        "IMPORTANT: key discussions, reasons, implementation milestones.",
        "USEFUL: supporting context and helpful explanations.",
        "VERBOSE: debugging attempts, repeated tries, long asides.",
        "NOISE: greetings, confirmations, raw tool output, tangents.",
        "Reply with exactly one of those five words and nothing else.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message)
    io.stderr:write("transcript-detail: " .. message .. "\n")
    os.exit(2)
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

-- {{{ local function fingerprint()
-- A short hash of a section's text (FNV-1a, 32 bits), to tell whether a
-- saved class still belongs to the same text.
local function fingerprint(text)
    local hash = 2166136261
    for index = 1, #text do
        hash = bit.bxor(hash, text:byte(index))
        hash = bit.tobit(hash * 16777619)
    end
    return bit.tohex(hash)
end
-- }}}
-- }}}

-- {{{ local function split_sections()
-- { preamble, sections = { { heading, text } } }. The preamble (title,
-- generation date) is everything before the first section heading. A
-- transcript with "### User Request" / "### Assistant Response" headings is
-- split only there, so a "### " heading inside a response stays inside it;
-- any other file is split at every "### " heading.
local function is_exchange_heading(line)
    return line:match("^### User Request") or line:match("^### Assistant Response")
end

local function split_sections(text)
    local preamble, sections, current = {}, {}, nil
    local exchanges = text:find("\n### User Request", 1, true) or text:find("\n### Assistant Response", 1, true)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if (exchanges and is_exchange_heading(line)) or (not exchanges and line:match("^### ")) then
            current = { heading = line, lines = { line } }
            sections[#sections + 1] = current
        elseif current then
            current.lines[#current.lines + 1] = line
        else
            preamble[#preamble + 1] = line
        end
    end
    for _, section in ipairs(sections) do
        section.text = table.concat(section.lines, "\n")
        section.lines = nil
    end
    return table.concat(preamble, "\n"), sections
end
-- }}}

-- {{{ local function load_classes()
local function load_classes(path)
    local saved = {}
    for line in (read_file(path or "") or ""):gmatch("[^\n]+") do
        local print_, class = line:match("^%d+\t(%x+)\t(%u+)$")
        if print_ then saved[print_] = class end
    end
    return saved
end
-- }}}

-- {{{ local function save_classes()
local function save_classes(path, sections)
    local file = io.open(path, "w")
    if not file then
        io.stderr:write("transcript-detail: could not save classes to " .. path .. "\n")
        return
    end
    for index, section in ipairs(sections) do
        if section.class ~= "UNCLASSED" then
            file:write(string.format("%d\t%s\t%s\n", index, section.print, section.class))
        end
    end
    file:close()
end
-- }}}

-- {{{ local function classify()
-- Gives each section .class (one of the five words, or UNCLASSED) and
-- returns how many were asked of the model and how many it failed.
local function classify(sections, saved)
    local client = require("llama-chat-client")
    local asked, failed, why = 0, 0, nil
    for _, section in ipairs(sections) do
        section.print = fingerprint(section.text)
        if saved[section.print] then
            section.class = saved[section.print]
        else
            asked = asked + 1
            local answer, err = client.complete(config.system_prompt,
                section.text:sub(1, config.max_section_chars))
            local word = answer and answer:match("^%s*(%u+)")
            if word and config.weights[word] then
                section.class = word
            else
                section.class = "UNCLASSED"
                failed = failed + 1
                why = why or err or ("unclear answer: " .. tostring(answer):sub(1, 60))
            end
        end
    end
    return asked, failed, why
end
-- }}}

-- {{{ local function render()
local function render(preamble, sections, level)
    local threshold = config.thresholds[level]
    local out, left_out = { preamble }, 0
    local function flush()
        if left_out > 0 then
            out[#out + 1] = string.format("*[%d section%s left out at detail level %d]*\n", left_out,
                left_out == 1 and "" or "s", level)
            left_out = 0
        end
    end
    local kept = 0
    for _, section in ipairs(sections) do
        local weight = config.weights[section.class]
        if section.class == "UNCLASSED" or weight >= threshold then
            flush()
            out[#out + 1] = section.text
            kept = kept + 1
        else
            left_out = left_out + 1
        end
    end
    flush()
    return table.concat(out, "\n"), kept
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
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key and ({ detail = true, out = true, classes = true })[key] then options[key] = value
        elseif argument == "--report" then options.report = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        elseif not argument:match("^%-") and not path then path = argument
        else fail("unknown or repeated argument " .. argument .. " (see --help)") end
    end
    if not path then fail("name a transcript") end
    local level = tonumber(options.detail or "")
    if not level or level < 1 or level > 5 or level % 1 ~= 0 then
        fail("--detail takes a level from 1 (decisions only) to 5 (everything)")
    end
    if options.out and options.out == path then fail("--out would overwrite the transcript itself") end
    local text = read_file(path) or fail("cannot read " .. path)

    local preamble, sections = split_sections(text)
    local result, kept, asked, failed, why
    if level == 5 then
        result, kept, asked, failed = text, #sections, 0, 0
    else
        asked, failed, why = classify(sections, load_classes(options.classes))
        if options.classes then save_classes(options.classes, sections) end
        result, kept = render(preamble, sections, level)
    end

    if options.report then
        for index, section in ipairs(sections) do
            print(string.format("%3d  %-10s %6d chars  %s", index, section.class or "-",
                #section.text, section.heading))
        end
    elseif options.out then
        local file = io.open(options.out, "w") or fail("cannot write " .. options.out)
        file:write(result)
        file:close()
    else
        io.write(result)
    end
    io.stderr:write(string.format("transcript-detail: level %d keeps %d of %d sections "
        .. "(%d chars of %d); %d asked of the model, %d unclassed%s\n", level, kept, #sections,
        #result, #text, asked, failed, why and (" (" .. why .. ")") or ""))
    if #sections > 0 and asked > 0 and failed == asked then return 1 end
    return 0
end
-- }}}

os.exit(main(arg))
