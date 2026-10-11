#!/usr/bin/env lua
-- conversation-parser.lua - Parse Claude conversation JSONL files
-- Extracts user requests and assistant responses into markdown summaries

-- {{{ load_dkjson
local function load_dkjson()
    -- Try multiple paths for dkjson
    local paths = {
        "/home/ritz/programming/ai-stuff/libs/lua/dkjson.lua",
        "/mnt/mtwo/programming/ai-stuff/libs/lua/dkjson.lua",
        "./libs/lua/dkjson.lua",
    }

    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            return dofile(path)
        end
    end

    error("Could not find dkjson.lua in known paths")
end
-- }}}

-- {{{ split_lines
-- Split on newlines exactly, keeping empty lines, so that concatenating the
-- result back with newlines reproduces the input byte for byte.
--
-- The obvious Lua spelling of this, gmatch("[^\n]*"), is a trap: the pattern
-- can match the empty string at the position just after a match, so it yields
-- a phantom empty line after every real one. The wrapper below used that
-- spelling and therefore emitted a blank line after every source line for as
-- long as it has existed, which is why a single blank between two paragraphs
-- arrived in the finished transcript as two. Measured on the tracked ai-stuff
-- corpus immediately before the fix: 31,021 such lines across 503 transcripts.
--
-- It matters beyond tidiness. A blank line between two quoted lines ends a
-- markdown blockquote, so a pasted-back passage spanning several terminal
-- rows was being broken into one quote block per row.
local function split_lines(text)
    local lines = {}
    local pos = 1
    while true do
        local newline = text:find("\n", pos, true)
        if not newline then
            lines[#lines + 1] = text:sub(pos)
            break
        end
        lines[#lines + 1] = text:sub(pos, newline - 1)
        pos = newline + 1
    end
    return lines
end
-- }}}

-- {{{ wrap_text
-- Wrap prose to the target width while leaving structure alone.
--
-- What wraps: plain paragraphs (including ones that OPEN with **bold** - the
-- old "^%*" exemption meant to spare "* " bullets caught those by accident),
-- list items ("- ", "* ", "1. ") with a hanging indent so continuations sit
-- under the item's text, and blockquotes with their "> " repeated.
--
-- What passes through untouched, because wrapping corrupts its meaning:
-- headers (a split header stops being a header), everything between ```
-- fences (the old code had no fence state and word-wrapped code), table
-- rows, tab/4-space indented code, and that same indented code sitting
-- inside a blockquote - which is how a pasted-back diagram arrives, and
-- word-wrapping one destroys the alignment that was its whole content.
-- A single token longer than the
-- width - a URL, a path - also stays long: there is no honest place to
-- break it.
local function wrap_text(text, width)
    width = width or 80
    local lines = {}
    local in_code_block = false

    -- {{{ wrap_with_prefix
    -- Word-wrap one line's body; the first output line carries first_prefix
    -- (indent plus any list marker), continuations carry cont_prefix.
    local function wrap_with_prefix(first_prefix, cont_prefix, body)
        local current = nil
        for word in body:gmatch("%S+") do
            if current == nil then
                current = first_prefix .. word
            elseif #current + 1 + #word <= width then
                current = current .. " " .. word
            else
                table.insert(lines, current)
                current = cont_prefix .. word
            end
        end
        table.insert(lines, current or first_prefix)
    end
    -- }}}

    for _, line in ipairs(split_lines(text)) do
        if line:match("^%s*```") then
            -- Fence line: emit as-is and flip code state.
            table.insert(lines, line)
            in_code_block = not in_code_block
        elseif in_code_block then
            -- Inside a fence: verbatim, always.
            table.insert(lines, line)
        elseif line:match("^%s*$") then
            table.insert(lines, "")
        elseif #line <= width then
            -- Already fits (this also spares horizontal rules and the
            -- 80-dash separators the exporter itself writes).
            table.insert(lines, line)
        elseif line:match("^#") or line:match("^%s*|")
            or line:match("^    ") or line:match("^\t")
            or line:match("^>%s%s%s%s%s") then
            -- Unwrappable structure: headers, table rows, indented code.
            table.insert(lines, line)
        else
            -- Prose. Split off a list marker or quote marker if present so
            -- continuations can be indented to match.
            local indent, marker, body = line:match("^(%s*)([%-%*] )(.*)$")
            if not indent then
                indent, marker, body = line:match("^(%s*)(%d+%. )(.*)$")
            end
            if indent then
                -- List item: continuations hang under the text, not the marker.
                wrap_with_prefix(indent .. marker,
                    indent .. string.rep(" ", #marker), body)
            else
                indent, marker, body = line:match("^(%s*)(>%s?)(.*)$")
                if indent then
                    -- Blockquote: every continuation repeats the quote mark.
                    wrap_with_prefix(indent .. marker, indent .. marker, body)
                else
                    -- Plain paragraph (this is where **bold openers land now);
                    -- any leading indent is preserved on every line.
                    indent = line:match("^(%s*)")
                    wrap_with_prefix(indent, indent, line:sub(#indent + 1))
                end
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- How confident a match has to be before a line is called a quote, and how
-- weak a neighbour's match may be once a confident one sits beside it.
-- Derived from the corpus, not chosen: bucketing every match by length shows
-- that under about thirty characters the hits are coincidence ("sure",
-- "file.", "before touching it.") and over about forty they are real. A
-- single threshold cannot serve, because a real paste ENDS in a short
-- fragment - the tail of a wrapped paragraph is a line like "the years in
-- between.", which is a quote only because of what sits above it.
local QUOTE_SEED_LENGTH = 40
local QUOTE_EXTEND_LENGTH = 12

-- {{{ spoken_form
-- Reduce text to what a reader actually SAW, so a paste can meet its source.
--
-- The user works by selecting a line of the assistant's answer in the
-- terminal and pasting it back to reply to that line specifically. What the
-- clipboard receives is what Claude Code drew, not what the model typed, and
-- the two differ in ways that defeat a literal comparison:
--
--   - emphasis is gone. The model wrote "**Notes poems still don't appear**
--     on the 2,500 word pages"; the paste carries no asterisks. Measured over
--     every session log on disk, comparing raw text finds 1588 pasted lines
--     and comparing this reduced form finds 3028 - the markers alone hide
--     nearly half of them.
--   - the pane's line-wrapping is baked in. One sentence of the model's prose
--     comes back as four rows broken at whatever width the terminal was, so
--     collapsing every whitespace run to a single space is what lets a row
--     be found inside the paragraph it came from.
--
-- Both sides of every comparison pass through here.
local function spoken_form(text)
    text = text:gsub("%*%*", "")   -- bold
    text = text:gsub("__", "")     -- bold, underscore spelling
    text = text:gsub("`", "")      -- inline code, and fence lines with it
    text = text:gsub("%*", "")     -- italics, and the bullet star
    text = text:gsub("%s+", " ")   -- the terminal's wrap, and the left margin
    text = text:gsub("^ ", "")
    text = text:gsub(" $", "")
    return text
end
-- }}}


-- {{{ mark_quoted_lines
-- Turn the lines the user pasted back from the model into blockquotes, and
-- leave the user's own words alone.
--
-- prior_speech is every assistant text block seen SO FAR in this conversation,
-- already reduced by spoken_form. It has to be "so far" rather than "all of
-- it": the model routinely echoes the user's phrasing back, so searching text
-- the model had not yet written would mark the user's own words as a quote of
-- a reply that did not exist yet.
--
-- The rule is seed-and-extend rather than one threshold. A line long enough
-- that coincidence is implausible seeds a quote; the run then walks outward
-- taking neighbours on a much weaker test and stops at the first line that
-- matches nothing. That keeps the short tail of a wrapped paragraph and
-- rejects an isolated "sure" that happens to appear in a long earlier answer.
--
-- What is deliberately NOT done: the row breaks are left exactly as they
-- arrived. Re-joining them would read better as prose, but a pasted ASCII
-- diagram comes back through this same path and its line breaks are its
-- entire content.
local function mark_quoted_lines(text, prior_speech)
    if not prior_speech or #prior_speech == 0 then
        return text
    end

    local lines = split_lines(text)

    -- How much of each line can be found somewhere the model already spoke.
    -- Substring, not equality: the pasted row is a fragment of a paragraph.
    local found = {}
    for index, line in ipairs(lines) do
        local spoken = spoken_form(line)
        if #spoken >= QUOTE_EXTEND_LENGTH then
            for _, said in ipairs(prior_speech) do
                if said:find(spoken, 1, true) then
                    found[index] = #spoken
                    break
                end
            end
        end
    end

    -- Seed. Nothing confident means nothing was pasted; leave the message be
    -- rather than pay for the rest of the passes.
    local quoted = {}
    local seeded = false
    for index = 1, #lines do
        if (found[index] or 0) >= QUOTE_SEED_LENGTH then
            quoted[index] = true
            seeded = true
        end
    end
    if not seeded then
        return text
    end

    -- {{{ extend_run
    -- Walk away from a seed in one direction, stopping at the first line that
    -- is not clearly part of the same paste.
    --
    -- A blank line stops the walk. A paste arrives as adjacent rows - the
    -- terminal's own row breaks, nothing between them - so a blank is where
    -- the paste ended and the user's own words began. Letting the walk cross
    -- one lets a quote swallow the reply written underneath it, and a short
    -- phrase in that reply echoing the answer it responds to is exactly the
    -- accidental match the length thresholds exist to reject.
    --
    -- Pasting two whole paragraphs is not lost to this: each is long enough to
    -- seed on its own, and the blank between them is rejoined by the
    -- interior-blank pass below. A blank line never reaches the threshold, so
    -- it needs no case of its own here.
    local function extend_run(from, step)
        local index = from + step
        while lines[index] do
            if (found[index] or 0) < QUOTE_EXTEND_LENGTH then
                break
            end
            quoted[index] = true
            index = index + step
        end
    end
    -- }}}

    for index = 1, #lines do
        if (found[index] or 0) >= QUOTE_SEED_LENGTH then
            extend_run(index, 1)
            extend_run(index, -1)
        end
    end

    -- A blank row with quoted lines on both sides is interior to the run and
    -- joins it; one hanging off either end does not. Interior blanks are
    -- emitted as a bare marker so the run stays a single quote block instead
    -- of breaking into one block per row.
    for index = 1, #lines do
        if not quoted[index] and lines[index]:match("^%s*$") then
            local before, after = false, false
            for back = index - 1, 1, -1 do
                if quoted[back] then before = true break end
                if not lines[back]:match("^%s*$") then break end
            end
            for forward = index + 1, #lines do
                if quoted[forward] then after = true break end
                if not lines[forward]:match("^%s*$") then break end
            end
            before = before and after
            if before then quoted[index] = true end
        end
    end

    -- The copied left margin is kept rather than stripped, and it carries
    -- information: Claude Code indents prose by two spaces, so a quoted line
    -- lands as "> " plus two - ordinary quoted prose. Anything the user had
    -- indented further (a diagram, a code listing) lands as "> " plus four or
    -- more, which markdown reads as a code block inside the quote, and its
    -- alignment survives into HTML instead of collapsing.
    for index = 1, #lines do
        if quoted[index] then
            if lines[index]:match("^%s*$") then
                lines[index] = ">"
            else
                lines[index] = "> " .. lines[index]
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ strip_terminal_escapes
-- Remove the bytes that were meant for a terminal rather than for a file.
--
-- Slash-command output is composed to be drawn, not stored. It carries CSI
-- sequences - the escape byte, "[", some digits and semicolons, then a letter
-- naming the effect - which a terminal reads as "bold on", "colour", "reset".
-- Copied into a markdown file they are invisible control characters that
-- corrupt every reader that is not a terminal: an editor, a diff, a web page,
-- a search index.
--
-- Three encodings of the same thing reach us, and all three are real, found by
-- searching the corpus rather than guessed:
--
--   * the raw escape byte, decimal 27, which is what the JSON decoder hands
--     back for the six-character "backslash-u-0-0-1-b" it finds in the log.
--     This is much the commonest case.
--   * those six characters still literal, which is what a log records when the
--     text it captured had ALREADY been JSON-encoded once before being stored,
--     so the decoder unwraps only the outer layer.
--   * the printable stand-in U+241B (SYMBOL FOR ESCAPE), which appears where
--     something upstream had already replaced the control byte with a visible
--     symbol.
--
-- Each is stripped by the same shape: introducer, optional digits and
-- semicolons, one letter. A lone introducer with no sequence after it is
-- dropped last, so a stray byte cannot survive by not matching the full form.
local function strip_terminal_escapes(text)
    if type(text) ~= "string" then return text end

    text = text:gsub("\27%[[%d;]*%a", "")          -- the real control byte
    text = text:gsub("\\u001[bB]%[[%d;]*%a", "")   -- one JSON layer left on
    text = text:gsub("\226\144\155%[[%d;]*%a", "") -- U+241B, printable stand-in

    text = text:gsub("\27", "")
    text = text:gsub("\\u001[bB]", "")
    text = text:gsub("\226\144\155", "")

    return text
end
-- }}}


-- {{{ quote_block
-- Prefix every line of an already-formatted block with the quote marker, so a
-- reader can see at a glance that this was said while the work was still going
-- on rather than after it had finished (issue 028).
--
-- The marker occupies two columns, so callers wrap to the measure minus two
-- and add the marker here. That is what keeps a quoted line the same total
-- width as an unquoted one instead of two columns wider.
local function quote_block(text)
    local out = {}
    for _, line in ipairs(split_lines(text)) do
        if line == "" then
            out[#out + 1] = ">"
        else
            out[#out + 1] = "> " .. line
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ split_envelope
-- Separate what the USER wrote from what the HARNESS wrote, inside a single
-- message that holds both.
--
-- A session log has only one seat for text addressed to the model, so Claude
-- Code files its own machine-authored messages there too: the boilerplate
-- caveat that precedes local command output, the scaffolding of a slash
-- command, that command's output, notifications that a background task
-- finished, and reminders addressed to the model. All of it used to arrive
-- under a "### User Request N" heading, indistinguishable from something the
-- user typed and consuming a number in the same sequence (issue 022).
--
-- Returns two things: the prose actually left after the machine's text is
-- lifted out, and a list of the envelope items that were lifted, each a table
-- of { kind, text }. An item's kind decides how the caller renders it:
--
--   command  a slash command the user invoked. Carries the command and its
--            arguments. What the command DID is a separate item, because the
--            log files it as a separate message.
--   output   what a local command printed. For /model this is the only place
--            the chosen model is named, which is why it is kept rather than
--            dropped (see issue 023).
--   note     a background task reporting in. Reduced to its summary line; the
--            full result is a JSON dump running to thousands of characters
--            and is not prose anybody reads. Also carries the task's id
--            (a string, or nil when the notification had none).
--   recap    the machine-written summary that opens a continued session.
--
-- Two kinds are removed and NOT returned, because they carry nothing a reader
-- of the transcript wants: the local-command caveat, which is fixed
-- boilerplate saying "do not respond to this", and system reminders, which are
-- addressed to the model rather than written by the user.
--
-- A tag whose closing half is missing will not match, and its text stays in
-- the prose where a reader can see it. That is deliberate: a silent drop would
-- hide the fact that the log's shape had changed again.
local function split_envelope(text)
    local items = {}
    if type(text) ~= "string" then return "", items end
    local rest = text

    rest = rest:gsub("<local%-command%-caveat>.-</local%-command%-caveat>", "")
    rest = rest:gsub("<system%-reminder>.-</system%-reminder>", "")
    -- The fixed rules the harness prepends to every forked subagent's orders
    -- ("you are a worker fork, execute one directive"). Identical in every
    -- fork, addressed to the model, and written by neither speaker; the
    -- directive after it is the part a reader wants (issue 025).
    rest = rest:gsub("<fork%-boilerplate>.-</fork%-boilerplate>", "")

    rest = rest:gsub("<task%-notification>(.-)</task%-notification>",
        function(body)
            local summary = body:match("<summary>(.-)</summary>")
            local status = body:match("<status>(.-)</status>")
            local id = body:match("<task%-id>(.-)</task%-id>")
            local said = summary or ("task " .. (id or "?"))
            -- The summary almost always ends by saying it completed, so
            -- repeating a "completed" status just stutters. A status worth
            -- printing is one that says something the summary did not -
            -- a failure, a cancellation.
            if status and status ~= "" and status ~= "completed" then
                said = said .. " (" .. status .. ")"
            end
            -- The task id rides along so the renderer can link a finished
            -- helper to its own transcript (issue 025): a helper's log is
            -- agent-<task id>.jsonl, so the id is the key to its file.
            items[#items + 1] = { kind = "note", text = said, id = id }
            return ""
        end)

    -- The command's own name and arguments arrive as separate tags in one
    -- message. Arguments are read before the name is removed, because
    -- removing them in the wrong order loses the pairing.
    local args = rest:match("<command%-args>(.-)</command%-args>")
    -- A skill invocation wears the same scaffolding as a slash command, with
    -- one extra tag. The difference matters downstream: a slash command is
    -- followed by its output, whereas a skill is followed by the skill's whole
    -- text arriving as if the user had typed it. The caller needs to know
    -- which it is looking at to know what to do with the message after this
    -- one.
    local is_skill = rest:find("<skill%-format>") ~= nil
    rest = rest:gsub("<command%-args>.-</command%-args>", "")
    rest = rest:gsub("<command%-message>.-</command%-message>", "")
    rest = rest:gsub("<skill%-format>.-</skill%-format>", "")
    rest = rest:gsub("<command%-name>(.-)</command%-name>",
        function(name)
            local said = name
            if args and args:match("%S") then
                said = said .. " " .. args:match("^%s*(.-)%s*$")
            end
            items[#items + 1] = {
                kind = is_skill and "skill" or "command",
                text = said,
            }
            return ""
        end)

    for _, tag in ipairs({ "local%-command%-stdout", "local%-command%-stderr" }) do
        rest = rest:gsub("<" .. tag .. ">(.-)</" .. tag .. ">",
            function(body)
                local said = body:match("^%s*(.-)%s*$")
                if said ~= "" then
                    items[#items + 1] = { kind = "output", text = said }
                end
                return ""
            end)
    end

    if rest:find("This session is being continued from a previous conversation",
        1, true) then
        items[#items + 1] = { kind = "recap", text = rest:match("^%s*(.-)%s*$") }
        rest = ""
    end

    return rest:match("^%s*(.-)%s*$"), items
end
-- }}}

-- {{{ user_text_of
-- Reduce a message's content to the single string the user is taken to have
-- said, whatever shape the log stored it in.
--
-- Content arrives either as a plain string or as a list of typed blocks. The
-- exporter only ever handled the string case, and emitted a heading with
-- nothing under it whenever a message arrived as a list - which is where the
-- empty numbered blocks in the corpus come from (issue 022). Here the list
-- case is handled by joining its text blocks, so the heading and the words
-- arrive together or neither does.
local function user_text_of(content)
    if type(content) == "string" then
        return content
    end
    if type(content) ~= "table" then
        return ""
    end
    local parts = {}
    for _, item in ipairs(content) do
        if type(item) == "table" and item.type == "text" and item.text then
            parts[#parts + 1] = item.text
        elseif type(item) == "string" then
            parts[#parts + 1] = item
        end
    end
    return table.concat(parts, "\n\n")
end
-- }}}

-- {{{ format_content
-- Put one block of text into the shape the transcript wants: heading levels
-- pushed down one, so a heading the model wrote cannot outrank the transcript's
-- own "### User Request" headings, then wrapped to the measure.
--
-- The measure is a parameter rather than a constant because narration is
-- quoted, and the two columns the quote marker takes have to come out of the
-- text's width or the quoted lines end up two columns wider than everything
-- else (issue 028).
local function format_content(content, width)
    if not content or content == "" then
        return ""
    end

    content = content:gsub("\n###", "\n##")
    content = content:gsub("^###", "##")

    content = wrap_text(content, width or 80)

    return content
end
-- }}}

-- {{{ extract_askq_answers
-- Recover what the user actually chose, from the structured record the
-- harness files rather than from the English sentence it also writes.
--
-- The sentence was the old source, and it was the wrong one. It reads
-- '"Q1"="A1", "Q2"="A2". Read the answers carefully...', so recovering an
-- answer meant finding the question text, stepping past an equals sign and a
-- quote, and reading forward to a guessed boundary. Two things defeated that,
-- both silently. An answer is not always quoted - a custom reply arrives as
-- '=(no option selected) notes: ...' with no quotes at all, and read as no
-- answer. And the boundary was guessed from a comma, while 172 of the 503
-- answers in the corpus contain a comma of their own.
--
-- Alongside that sentence the log carries a machine-readable copy on the
-- message record itself, under toolUseResult:
--
--   answers      map: question text -> the answer, as a single string. For a
--                multi-select question the chosen labels arrive already
--                joined. Present on all 240 question exchanges in the corpus,
--                so there is no older shape to fall back to.
--   annotations  map: question text -> { notes, preview }. "notes" is free
--                text the user typed alongside their pick - their own
--                reasoning, in their own words. 115 of the 240 exchanges
--                carry some, and every one of them used to be discarded.
--
-- Both maps are keyed by the full question text, which is also what the tool
-- call carries, so pairing them needs no positional guessing at all.
--
-- Returns two lists keyed by question index: the answers, and the notes. A
-- question with neither is simply absent from both.
local function extract_askq_answers(tool_use_result, questions)
    local answers, notes = {}, {}
    if type(tool_use_result) ~= "table" then return answers, notes end

    local recorded = tool_use_result.answers
    local annotated = tool_use_result.annotations

    for i, q in ipairs(questions) do
        local key = q.question or ""
        if type(recorded) == "table" and type(recorded[key]) == "string" then
            answers[i] = recorded[key]
        end
        if type(annotated) == "table" and type(annotated[key]) == "table" then
            local note = annotated[key].notes
            if type(note) == "string" and note:match("%S") then
                notes[i] = note
            end
        end
    end

    return answers, notes
end
-- }}}

-- {{{ format_askuserquestion
-- Render one question exchange, with its outcome, as readable markdown - so
-- the decision it captured survives in the transcript instead of being dropped
-- with the rest of the tool stream.
--
-- For each question: the header and the question, every option that was
-- offered, and what came back. An answer that exactly matches one of the
-- offered labels is shown as a selection; anything else is shown as an
-- answer, so words the user typed themselves stay visibly distinct from a
-- menu pick. Any note they added is shown under it, because a note is the
-- part that says WHY, and it is usually the more informative half.
local function format_askuserquestion(input, tool_use_result)
    local questions = input and input.questions
    if type(questions) ~= "table" then return "" end
    local answers, notes = extract_askq_answers(tool_use_result, questions)

    local parts = { "**[Asked the user]**" }
    for i, q in ipairs(questions) do
        parts[#parts + 1] = ""
        local header = q.header and (" — " .. q.header) or ""
        parts[#parts + 1] = string.format("*Q%d%s:* %s", i, header,
            q.question or "")
        if type(q.options) == "table" then
            for _, opt in ipairs(q.options) do
                local desc = opt.description and (" — " .. opt.description) or ""
                parts[#parts + 1] = string.format("- %s%s", opt.label or "", desc)
            end
        end
        local ans = answers[i]
        if ans then
            local is_option = false
            if type(q.options) == "table" then
                for _, opt in ipairs(q.options) do
                    if opt.label == ans then is_option = true break end
                end
            end
            parts[#parts + 1] =
                (is_option and "→ **Selected:** " or "→ **Answered:** ") .. ans
        else
            parts[#parts + 1] = "→ *(no answer recorded)*"
        end
        if notes[i] then
            parts[#parts + 1] = "→ **They added:** " .. notes[i]
        end
    end
    return table.concat(parts, "\n")
end
-- }}}

-- {{{ utc_fields_to_epoch
-- Turn a UTC calendar reading into the instant it actually names.
--
-- Lua's os.time reads the table handed to it as LOCAL time, and the session
-- logs record UTC (their timestamps end in "Z"). Calling os.time on those
-- fields directly therefore lands one whole UTC offset away from the truth -
-- seven or eight hours here, depending on daylight saving. That error used to
-- be stamped onto every transcript's mtime, and the matching error in the
-- date reducer below put it in every filename too (issue 018).
--
-- Standard Lua has no timegm, so the offset is measured rather than assumed:
-- break the first, wrong answer back down into UTC fields, push those through
-- os.time a second time, and the gap between the two passes IS the offset
-- that os.time applied - including whichever daylight-saving rule was in
-- force on that date. Adding the gap back lands on the true instant.
--
-- Both passes must ask the same question, and that turns on one field. A UTC
-- breakdown comes back carrying isdst = false, because UTC keeps no daylight
-- saving; handing that table straight back to os.time forces it to convert at
-- the STANDARD offset while the first pass had already guessed the DAYLIGHT
-- one. The two passes then measure different offsets and the gap between them
-- is an hour short - correct all winter, an hour early all summer, which is
-- the sort of fault that hides for half the year. Clearing the field puts the
-- second pass back on the same footing as the first: both guess, both guess
-- alike, and the gap is the offset and nothing else.
--
-- The one place this can still slip is a reading falling within the offset's
-- own width of a daylight-saving boundary, where the two passes can land on
-- opposite sides. That is a sub-hour ambiguity twice a year, and it cannot
-- move a calendar date except for a conversation ending within an hour of
-- midnight on those two nights.
local function utc_fields_to_epoch(time_table)
    local as_if_local = os.time(time_table)
    if not as_if_local then
        return nil
    end
    local utc_view = os.date("!*t", as_if_local)
    utc_view.isdst = nil
    local round_trip = os.time(utc_view)
    if not round_trip then
        return as_if_local
    end
    return as_if_local + (as_if_local - round_trip)
end
-- }}}

-- {{{ parse_timestamp
-- Parse timestamp from various formats
local function parse_timestamp(timestamp_value)
    if not timestamp_value then
        return nil
    end

    -- If it's already a number, convert to seconds
    if type(timestamp_value) == "number" then
        -- If more than 10 digits, it's milliseconds
        if timestamp_value > 10000000000 then
            return math.floor(timestamp_value / 1000)
        else
            return math.floor(timestamp_value)
        end
    end

    -- If it's a string, try to parse ISO format
    if type(timestamp_value) == "string" then
        -- Try extracting Unix timestamp directly if it looks like a number
        local num = tonumber(timestamp_value)
        if num then
            return parse_timestamp(num)
        end

        -- Try parsing ISO 8601 format: 2025-12-19T06:32:02.001Z
        local year, month, day, hour, min, sec =
            timestamp_value:match("(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")

        if year then
            -- These fields came out of a "...Z" string, so they are UTC and
            -- must be converted as UTC. Handing them straight to os.time,
            -- which would read them as local, is the bug issue 018 records.
            local time_table = {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            }
            return utc_fields_to_epoch(time_table)
        end
    end

    return nil
end
-- }}}

-- {{{ to_date_string
-- Reduce a raw timestamp value to the calendar date "YYYY-MM-DD" on which the
-- conversation was actually held, in this machine's local time.
--
-- The earlier version of this function copied the date characters straight
-- out of the ISO string, which is a UTC reading. That filed every evening
-- conversation under the following day: 7:49pm local is already past midnight
-- in UTC, so a session held on the 16th was named for the 17th. The comment
-- here used to defend that choice on the grounds that it matched the mtime -
-- and it did match, because the mtime was wrong in exactly the same
-- direction. Both halves are corrected together (issue 018); correcting only
-- one would trade a shared error for a disagreement.
--
-- So: always resolve to a real instant first, then ask local time what day
-- that instant fell on. No '!' on the format string - that would be UTC again.
local function to_date_string(timestamp_value)
    local epoch = parse_timestamp(timestamp_value)
    if epoch then
        return os.date("%Y-%m-%d", epoch)
    end

    return nil
end
-- }}}

-- {{{ load_helper_names
-- Read the table the exporter leaves for us: which transcript file holds each
-- helper conversation already saved in this project, so a parent's "helper
-- finished" line can link to it (issue 025).
--
-- The table is a plain text file, one helper per line:
--   agent-<task id> <TAB> <transcript filename, no folder>
-- Its path arrives in the environment variable TRANSCRIPT_HELPER_NAMES.
--
-- Returns a table mapping the conversation id (string) to the filename
-- (string). Two paths: the variable is unset, meaning the caller keeps no
-- helper table (a test, or a library user), and the result is empty so no
-- line gets a link; or it is set, and a file that cannot be read or a line
-- that is not "id TAB name" is an error - the exporter wrote it moments ago,
-- so either failure means the two have stopped agreeing.
local function load_helper_names()
    local names = {}
    local path = os.getenv("TRANSCRIPT_HELPER_NAMES")
    if not path then return names end
    local f = io.open(path, "r")
    if not f then
        error("TRANSCRIPT_HELPER_NAMES names a file that cannot be read: " .. path)
    end
    for line in f:lines() do
        if line ~= "" then
            local id, name = line:match("^([^\t]+)\t([^\t]+)$")
            if not id then
                f:close()
                error("malformed line in helper-name table " .. path .. ": " .. line)
            end
            names[id] = name
        end
    end
    f:close()
    return names
end
-- }}}

-- {{{ runs_a_commit
-- Whether a shell command RUNS a commit, as against mentioning one. The
-- command is cut into steps at newlines, ";", "&&", "||" and "|"; a step runs
-- a commit when its first word (after any VAR=value settings) is a path ending
-- in commit-own-changes, or is git with "commit" as a later word. A search
-- for the words - grep "commit-own-changes: committed" - is a step whose
-- first word is grep, and does not count.
--
-- Two things before the first word are looked past (issue 040), because
-- real loops that committed into many repositories hid behind them and so
-- were never read at all: the shell's own words that open a step ("do",
-- "then", "if" ...), as in `while read R; do git -C "$R" commit ...`; and an
-- output being captured, as in `out=$(commit-own-changes "$R" -F - ...)`.
local SHELL_OPENERS = {
    ["do"] = true, ["then"] = true, ["else"] = true, ["elif"] = true,
    ["if"] = true, ["while"] = true, ["until"] = true, ["!"] = true,
    ["{"] = true, ["("] = true, ["time"] = true,
}

local function runs_a_commit(command)
    for step in (command .. "\n"):gsub("&&", "\n"):gsub("||", "\n"):gsub("[;|]", "\n"):gmatch("([^\n]*)\n") do
        local words = step:gsub("^%s*", ""):gsub("^[%w_]+=%$%(", ""):gsub("^[%w_]+=%S*%s+", "")
        local opener = words:match("^(%S+)")
        while opener and SHELL_OPENERS[opener] do
            words = words:gsub("^%S+%s*", "")
            opener = words:match("^(%S+)")
        end
        local first = words:match("^(%S+)") or ""
        if first:match("commit%-own%-changes$") then
            return true
        end
        if first == "git" and (" " .. words .. " "):find("%scommit%s") then
            return true
        end
        -- git's own lower-level way of making a commit, which prints only the
        -- new commit's full hash (issue 040: "Seven stickers..." in
        -- double-diaper-dungeon was made this way, then put on the branch by
        -- update-ref).
        if first == "git" and (" " .. words .. " "):find("%scommit%-tree%s") then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ commits_reported
-- The commits a command's output says were just made (issue 035), so the
-- transcript can record which commits its conversation made.
--
-- Takes one tool-result record from the log; reads its output text, which is
-- `toolUseResult.stdout` (a string) for a shell command. Returns a list of
-- { hash = <string, hex>, subject = <string>, repository = <string or nil> }.
--
-- The two routes by which a commit is made print two shapes:
--
--   commit-own-changes: committed 8a235a0fe on main in /mnt/mtwo/.../ai-stuff
--     Close four finished issues that had never been filed away
--
--   [main 6b80531] One service per mailbox, instead of one mailbox per machine
--   [main (root-commit) 1a2b3c4] First commit
--
-- The first names its repository and puts the subject on the next line; plain
-- git names neither the repository nor anything but the branch.
--
-- Output is only read when the command that printed it was a commit:
-- `commands_by_id` maps a call id to its command string, and the command must
-- run commit-own-changes or `git ... commit`. Without that, any output QUOTING
-- a commit report counted - found the first time this ran, on a session that
-- had searched old logs for exactly these lines. A commit command that runs a
-- test suite making throwaway commits can still print fixture commits; the
-- page matches recorded commits against the project's real history, and one
-- it cannot find there is simply not linked.
local function commits_reported(msg, commands_by_id)
    local found = {}
    local content = msg.message and msg.message.content
    local call_id = type(content) == "table" and type(content[1]) == "table"
        and content[1].tool_use_id or nil
    local command = call_id and commands_by_id[call_id] or ""
    -- Two kinds of command: a commit, whose output is read; anything else,
    -- whose output is not, however much it looks like a commit report.
    if not runs_a_commit(command) then
        return found
    end
    local result = msg.toolUseResult
    local text = type(result) == "table" and result.stdout or nil
    if type(text) ~= "string" or text == "" then
        return found
    end
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    for i, line in ipairs(lines) do
        local hash, repository = line:match("^commit%-own%-changes: committed (%x+) on %S+ in (.+)$")
        if hash then
            local subject = (lines[i + 1] or ""):match("^%s+(.-)%s*$") or ""
            found[#found + 1] = { hash = hash, subject = subject, repository = repository }
        else
            local plain_hash, subject = line:match("^%[.- (%x+)%] (.-)%s*$")
            -- Seven hex digits is git's shortest abbreviation; anything
            -- shorter in brackets is not a commit report.
            if plain_hash and #plain_hash >= 7 then
                found[#found + 1] = { hash = plain_hash, subject = subject }
            end
        end
    end
    return found
end
-- }}}

-- {{{ pictures_reported
-- The pictures a see-in-3d command kept in its project (scripts issue A10),
-- each as the markdown line it becomes in the transcript:
--
--   ![a desk with a lamp -- front, right / top, angle](/abs/.../views.jpg)
--
-- The command prints one "see-in-3d: kept PATH | CAPTION" line per picture.
-- Only a command that runs see-in-3d is read, so output that merely quotes
-- such a line (a search of old logs, a test's fixture) adds nothing. The
-- path stays absolute: the transcript may be read from anywhere, and the
-- page builder turns it into a picture copied beside the page.
local function pictures_reported(msg, commands_by_id)
    local found = {}
    local content = msg.message and msg.message.content
    local call_id = type(content) == "table" and type(content[1]) == "table"
        and content[1].tool_use_id or nil
    local command = call_id and commands_by_id[call_id] or ""
    -- Two kinds of command: one that runs see-in-3d's render or imagine step,
    -- whose output is read; anything else -- including a search that names
    -- see-in-3d, the first version's false positive -- whose output is not.
    local runs_it = false
    for tail in command:gmatch("see%-in%-3d([^|;&\n]*)") do
        local words = " " .. tail .. " "
        if words:find("%srender%s") or words:find("%simagine%s") then runs_it = true end
    end
    if not runs_it then
        return found
    end
    local result = msg.toolUseResult
    local text = type(result) == "table" and result.stdout or nil
    if type(text) ~= "string" then
        return found
    end
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local path, caption = line:match("^see%-in%-3d: kept (/%S+) | (.-)%s*$")
        if path then
            caption = caption:gsub("[%[%]]", "")
            found[#found + 1] = "![" .. caption .. "](" .. path .. ")"
        end
    end
    return found
end
-- }}}

-- {{{ commit_line
-- The line a recorded commit becomes in the transcript:
--
--   *[commit] 8a235a0fe in ai-stuff - Close four finished issues...*
--
-- One line, never wrapped, so a reader can take the hash and the subject from
-- it without joining lines. The repository is named by its folder's name
-- when the output gave one. Asterisks in the subject are escaped so they
-- cannot end the line's italics early.
local function commit_line(commit)
    local where = commit.repository and (" in " .. commit.repository:match("([^/]+)/*$")) or ""
    local subject = commit.subject:gsub("%*", "\\*")
    return "*[commit] " .. commit.hash .. where .. " - " .. subject .. "*"
end
-- }}}

-- RECOVERING A COMMIT WHOSE ANNOUNCEMENT IS MISSING (issue 040).
--
-- commits_reported believes only an announcement at the start of a line of
-- the command's output. Sessions hid that line in four ways, all measured in
-- real logs: piping the commit through `tail -3`, which kept git's last
-- lines and dropped the first; `git commit -q`, which prints nothing; a loop
-- committing into many repositories at once, `-C "$R"`; and catching
-- commit-own-changes' report in a variable and printing it later with a
-- prefix. The commit happened every time, and git still knows it.
--
-- So for a commit command with no announcement, git is asked. The rule is
-- strict on purpose, because a line naming the wrong commit is worse than no
-- line: a commit is recovered only when git holds one with EXACTLY the
-- message's subject (or the hash the output mentions), committed between 5
-- seconds before the command and 600 seconds after. A refused commit -- one
-- tried three times in double-diaper-dungeon and refused every time -- has
-- no such commit, and nothing is recorded.

-- Seconds before and after a command a recovered commit may carry. Ten
-- minutes covers a commit hook that runs a test suite; every measured case
-- landed within a minute.
local RECOVERY_BEFORE, RECOVERY_AFTER = 5, 600

-- How many commit commands had a subject but no single match, counted for
-- the exporter's report (main writes RECOVERY_UNMATCHED: to stderr).
local recovery_unmatched = 0

-- {{{ shell_quote
local function shell_quote(text)
    return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ lines_from
-- Runs a read-only command and returns its output lines (a list of strings).
local function lines_from(command)
    local pipe = io.popen(command, "r")
    local out = {}
    if not pipe then return out end
    for line in pipe:lines() do out[#out + 1] = line end
    pipe:close()
    return out
end
-- }}}

-- {{{ assignments_in
-- The plain `NAME=value` settings a command makes (string -> string), so
-- `MSG=/dev/shm/m.txt ... -F "$MSG"` can be followed to the file it names.
-- Only literal values: a value holding $ or $( is not resolved.
local function assignments_in(command)
    local vars = {}
    for step in (command .. "\n"):gsub("[;&|]", "\n"):gmatch("([^\n]*)\n") do
        local name, value = step:match("^%s*([%w_]+)=(%S+)")
        if name then
            value = value:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
            if not value:find("[%$`]") then vars[name] = value end
        end
    end
    return vars
end
-- }}}

-- {{{ expand
-- Replaces $NAME and ${NAME} with what assignments_in found. A name it does
-- not know is left as written, so a loop's "$R" stays visibly unresolved.
local function expand(text, vars)
    return (text:gsub("%${?([%w_]+)}?", function(name)
        return vars[name]
    end))
end
-- }}}

-- {{{ subject_of_commit
-- The subject of the message a commit command gave, in this order: a file
-- named after -F, as last written before the command (by heredoc or by the
-- Write tool, from `writes`, base name -> list of { index, first_line }); a
-- heredoc on standard input with -F -; the text after -m. Nil when none.
local function subject_of_commit(command, call_index, writes, vars)
    local file = command:match("commit[^\n]-%-F%s+([^%s;&|]+)")
    if file and file ~= "-" then
        file = expand(file:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"), vars)
        local base = file:match("([^/]+)$")
        local best = nil
        for _, write in ipairs(writes[base] or {}) do
            if write.index <= call_index then best = write end
        end
        if best and best.first_line ~= "" then return best.first_line end
    end
    local stdin = command:match("%-F %-[^\n]-<<%-?['\"]?[%w_]+['\"]?[^\n]*\n([^\n]*)")
    if stdin and stdin ~= "" then return stdin end
    local m = command:match("%-m '([^']+)'") or command:match('%-m "([^"]+)"')
    if m then return m:match("^([^\n]*)") end
    return nil
end
-- }}}

-- {{{ known_repositories
-- Every repository on the machine holding an llm-transcripts/ folder, found
-- the way rederive-transcripts finds projects: the same roots, the same
-- depth, worktrees and backups left out. Asked only for a loop whose
-- repository cannot be read from the command, and worked out once per run.
-- TRANSCRIPT_SEARCH_ROOTS (space-separated folders) replaces the roots, for
-- a test's throwaway repositories.
local KNOWN_REPOSITORIES = nil
local function known_repositories()
    if KNOWN_REPOSITORIES then return KNOWN_REPOSITORIES end
    local roots = os.getenv("TRANSCRIPT_SEARCH_ROOTS") or "/mnt/mtwo /mnt/cmdo /mnt/kaun"
    local seen, list = {}, {}
    for root in roots:gmatch("%S+") do
        for _, folder in ipairs(lines_from("find " .. shell_quote(root)
                .. " -maxdepth 8 -type d -name llm-transcripts -not -path '*/.git/*' 2>/dev/null")) do
            if not folder:find("/ai%-worktrees/") and not folder:find("/backups/") then
                local top = lines_from("git -C " .. shell_quote(folder) .. " rev-parse --show-toplevel 2>/dev/null")[1]
                if top and not seen[top] then
                    seen[top] = true
                    list[#list + 1] = top
                end
            end
        end
    end
    table.sort(list)
    KNOWN_REPOSITORIES = list
    return list
end
-- }}}

-- {{{ matches_in
-- The commits in one repository with exactly this subject, inside the window
-- around `epoch`: a list of full hashes.
local function matches_in(repository, subject, epoch)
    local found = {}
    for _, row in ipairs(lines_from("git -C " .. shell_quote(repository)
            .. " log --all --format='%H %ct %s' --fixed-strings --grep=" .. shell_quote(subject) .. " 2>/dev/null")) do
        local hash, when, s = row:match("^(%x+) (%d+) (.*)$")
        when = tonumber(when)
        if hash and s == subject and when >= epoch - RECOVERY_BEFORE and when <= epoch + RECOVERY_AFTER then
            found[#found + 1] = hash
        end
    end
    return found
end
-- }}}

-- {{{ commit_named
-- One commit the output names by hash, if the repository holds it and it was
-- made inside the window: { hash, subject }, or nil. The window is what keeps
-- an old report quoted in the output from counting.
local function commit_named(repository, hash, epoch)
    local row = lines_from("git -C " .. shell_quote(repository) .. " log -1 --format='%ct %s' "
        .. shell_quote(hash) .. " -- 2>/dev/null")[1]
    local when, subject = (row or ""):match("^(%d+) (.*)$")
    when = tonumber(when)
    if when and when >= epoch - RECOVERY_BEFORE and when <= epoch + RECOVERY_AFTER then
        return { hash = hash, subject = subject }
    end
    return nil
end
-- }}}

-- {{{ commits_recovered
-- The commits a commit command made that commits_reported could not see, as
-- a list of { hash, subject, repository }. `call` is { command, epoch, cwd,
-- index }; `output` the command's printed text; `writes` the session's file
-- writes; `recorded` the set of seven-character hashes already in the
-- transcript, which nothing is recorded twice against.
local function commits_recovered(call, output, writes, recorded)
    local found = {}
    local vars = assignments_in(call.command)
    local literal = call.command:match("git%s+%-C%s+([^%s;&|]+)[^\n]-%scommit")
    local repository = literal and expand(literal:gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"), vars)
    local loop = repository and repository:find("%$") ~= nil
    if loop then repository = nil end
    repository = repository or (not loop and call.cwd) or nil

    -- {{{ add
    local function add(hash, subject, where, name_it)
        local short = hash:sub(1, 7)
        if recorded[short] then return end
        recorded[short] = true
        found[#found + 1] = { hash = hash:sub(1, 9), subject = subject,
                              repository = name_it and where or nil }
    end
    -- }}}

    -- First, an announcement the output holds somewhere other than the start
    -- of a line: commit-own-changes' report caught and printed with a prefix.
    -- It names its repository; the window still has to hold.
    for hash, where in output:gmatch("committed (%x%x%x%x%x%x%x+) on %S+ in (/[^%s:]+)") do
        local commit = commit_named(where, hash, call.epoch)
        if commit then add(commit.hash, commit.subject, where, true) end
    end
    -- And `git commit-tree`, which prints nothing but the new commit's full
    -- hash on a line of its own.
    if repository and call.command:find("commit%-tree") then
        for line in (output .. "\n"):gmatch("([^\n]*)\n") do
            local hash = line:match("^(%x+)%s*$")
            if hash and #hash == 40 then
                local commit = commit_named(repository, hash, call.epoch)
                if commit then add(commit.hash, commit.subject, repository, false) end
            end
        end
    end
    if #found > 0 then return found end

    -- Then the message's subject, asked of git.
    local subject = subject_of_commit(call.command, call.index, writes, vars)
    if not subject then return found end
    if repository then
        local hits = matches_in(repository, subject, call.epoch)
        if #hits == 1 then
            add(hits[1], subject, repository, false)
        else
            recovery_unmatched = recovery_unmatched + 1
        end
    elseif loop then
        -- A loop: every repository on the machine with exactly one match gets
        -- its line, naming that repository; any with two gets none.
        local any = false
        for _, where in ipairs(known_repositories()) do
            local hits = matches_in(where, subject, call.epoch)
            if #hits == 1 then
                add(hits[1], subject, where, true)
                any = true
            elseif #hits > 1 then
                recovery_unmatched = recovery_unmatched + 1
            end
        end
        if not any then recovery_unmatched = recovery_unmatched + 1 end
    end
    return found
end
-- }}}

-- {{{ recap_text
-- The prose of a recap Claude Code wrote while the person was away, without
-- the "(disable recaps in /config)" it always ends with: that is an
-- instruction to whoever is at the keyboard, harness furniture like the
-- local-command caveat, and says nothing about the conversation (issue 037).
-- A recap whose content is not a string means the record's shape changed,
-- which is reported rather than printed as "nil".
local function recap_text(content)
    if type(content) ~= "string" then
        error("recap record content is not text: " .. type(content))
    end
    local text = content:gsub("%s*%(disable recaps in /config%)%s*$", "")
    return text:match("^%s*(.-)%s*$")
end
-- }}}

-- {{{ recap_place
-- Where a recap falls, in the words a reader can find in the body: the last
-- "User Request" heading written before it. Zero means it came before any.
local function recap_place(after_request)
    if after_request < 1 then
        return "before Request 1"
    end
    return "after Request " .. after_request
end
-- }}}

-- {{{ parse_conversation
-- Turn one session log into a readable markdown transcript.
--
-- The log is a list of message records. Three kinds matter here: what the user
-- typed, what the model wrote back, and what the harness filed into the user's
-- seat because that is the only seat text addressed to the model can occupy.
-- The third kind used to be indistinguishable from the first; split_envelope
-- is what tells them apart now.
local function parse_conversation(jsonl_file, output_file)
    local json = load_dkjson()
    local helper_names = load_helper_names()

    -- Read and parse all messages
    local messages = {}
    -- first_timestamp anchors the start date, final_timestamp the end date.
    -- Some JSONL lines (summaries, file snapshots) carry no timestamp, so we
    -- keep the first and last that actually have one rather than head/tail.
    local first_timestamp = nil
    local final_timestamp = nil

    local f = io.open(jsonl_file, "r")
    if not f then
        error("Could not open file: " .. jsonl_file)
    end

    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        if line ~= "" then
            local success, data = pcall(json.decode, line)
            if success and type(data) == "table" then
                table.insert(messages, data)
                -- Track the first and latest timestamps
                if data.timestamp then
                    if not first_timestamp then
                        first_timestamp = data.timestamp
                    end
                    final_timestamp = data.timestamp
                end
            end
        end
    end

    f:close()

    -- Pre-pass one: map every tool-result back to the tool call it answers, so
    -- the question renderer can pair a question block with its outcome. What
    -- is kept is the whole toolUseResult record rather than the prose string
    -- inside it, because the structured answers and the user's own notes live
    -- on the record and only a sentence lives in the string (issue 019).
    local tool_results_by_id = {}
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "user" then
            local content = msg.message and msg.message.content
            if type(content) == "table" then
                for _, item in ipairs(content) do
                    if type(item) == "table" and item.tool_use_id
                        and item.type == "tool_result" then
                        tool_results_by_id[item.tool_use_id] = msg.toolUseResult
                    end
                end
            end
        end
    end

    -- The other direction: every shell command the model ran, by its call id
    -- (string -> the command string). A command's output is only believed to
    -- report a commit when the command was a commit (see commits_reported):
    -- output that merely QUOTES a commit report - a search through old logs,
    -- a test printing its fixtures - otherwise reads exactly like one.
    local commands_by_id = {}
    -- For recovering a commit whose announcement is missing (issue 040):
    -- each command's moment, folder and place in the session (call id ->
    -- { command, epoch, cwd, index }), and every file the session wrote, by
    -- heredoc in a command or by the Write tool (base name -> list of
    -- { index, first_line }, in order), so `-F <file>` can be followed back
    -- to the subject written into it.
    local calls_by_id = {}
    local writes = {}
    local call_index = 0
    -- {{{ note_write
    local function note_write(path, first_line)
        local base = path:match("([^/]+)$")
        if not base then return end
        writes[base] = writes[base] or {}
        table.insert(writes[base], { index = call_index, first_line = first_line or "" })
    end
    -- }}}
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "assistant" then
            local content = msg.message and msg.message.content
            if type(content) == "table" then
                for _, item in ipairs(content) do
                    if type(item) == "table" and item.type == "tool_use" and item.id
                        and type(item.input) == "table" then
                        call_index = call_index + 1
                        if type(item.input.command) == "string" then
                            local command = item.input.command
                            commands_by_id[item.id] = command
                            calls_by_id[item.id] = { command = command, index = call_index,
                                epoch = parse_timestamp(msg.timestamp), cwd = msg.cwd }
                            for path, first in command:gmatch("cat%s+>>?%s*([^%s<]+)%s*<<%-?['\"]?[%w_]+['\"]?[^\n]*\n([^\n]*)") do
                                note_write(expand(path:gsub('^"(.*)"$', "%1"), assignments_in(command)), first)
                            end
                        elseif item.name == "Write" and type(item.input.file_path) == "string"
                            and type(item.input.content) == "string" then
                            note_write(item.input.file_path, item.input.content:match("^([^\n]*)"))
                        end
                    end
                end
            end
        end
    end
    -- The seven-character hashes this transcript records, so a recovered
    -- commit is never written a second time. Seeded with every commit the
    -- session ANNOUNCED anywhere, before any line is written: a commit whose
    -- first command showed nothing is often announced by a later one (a
    -- retry, a hook's report), and the first build of the recovery wrote
    -- such commits twice -- five times in double-diaper-dungeon alone.
    local recorded_hashes = {}
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "user" and msg.toolUseResult then
            for _, commit in ipairs(commits_reported(msg, commands_by_id)) do
                recorded_hashes[commit.hash:sub(1, 7)] = true
            end
        end
    end

    -- Pre-pass two: every model that served a reply in this session, in the
    -- order each was first seen. The header needs the whole list before the
    -- first message is written, which is why this cannot wait for the main
    -- loop. Read from the per-message field rather than from any /model
    -- command, because a model can arrive by launch flag, by a changed
    -- default, or by delegation, and the command sees none of those
    -- (issue 023).
    -- The harness files its own notices - "you have hit your session limit",
    -- and the like - as assistant messages under a placeholder model name.
    -- Nothing served those replies, so they are kept out of the header list
    -- and rendered as notices rather than as prose the model wrote.
    local SYNTHETIC_MODEL = "<synthetic>"

    -- Pre-pass three: is this the log of a forked subagent? A fork inherits
    -- its parent's whole conversation instead of starting from a fresh
    -- prompt, and its log opens with a "fork-context-ref" record pointing
    -- back at the parent rather than repeating that history. Its first user
    -- message is then an odd shape: the answer to the parent's spawning call
    -- (a tool result) with the fork's directive riding along as a text block
    -- in the same message. The main loop below skips any message that opens
    -- with a tool result, which for a fork swallowed the directive and - with
    -- no user turn ever opened - every word the fork said after it, leaving a
    -- header and nothing else (issue 025). Only in a fork, and only for its
    -- first user turn, are the text blocks of such a message read as the
    -- request. Ordinary sessions keep the old rule untouched, so no existing
    -- transcript changes shape.
    local is_fork_log = false
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "fork-context-ref" then
            is_fork_log = true
            break
        end
    end

    local models_seen, models_order = {}, {}
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "assistant" then
            local model = msg.message and msg.message.model
            if type(model) == "string" and model ~= ""
                and model ~= SYNTHETIC_MODEL and not models_seen[model] then
                models_seen[model] = true
                models_order[#models_order + 1] = model
            end
        end
    end

    -- Generate markdown output
    local out_file = io.open(output_file, "w")
    if not out_file then
        error("Could not open output file: " .. output_file)
    end

    -- The body is gathered in memory and written after the header and the
    -- recap contents (issue 037): the contents list sits above the body but
    -- is only known once the body has been walked. Everything below writes
    -- through out:write exactly as it did when out was the file.
    local out = { parts = {} }
    function out:write(text)
        self.parts[#self.parts + 1] = text
    end

    -- Each entry: { epoch = <number, seconds>, after_request = <number>,
    -- text = <string> }. Filled by the walk, written above the body.
    local recaps = {}

    -- Extract conversation ID from filename
    local conversation_id = jsonl_file:match("([^/]+)%.jsonl$") or "unknown"

    local RULE = string.rep("-", 80)

    -- Header
    out_file:write("# Conversation Summary: " .. conversation_id .. "\n")
    out_file:write("\n")
    out_file:write("Generated on: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    if #models_order > 0 then
        out_file:write("Models: " .. table.concat(models_order, ", ") .. "\n")
    end
    out_file:write("\n")

    local user_count = 1
    local current_user_uuid = nil
    -- Each entry is { text = <what was said>, model = <what said it> }. The
    -- model travels with the block so a change can be marked where it happened
    -- rather than where the flush happens to fall.
    local assistant_blocks = {}
    local last_model_announced = nil
    -- True once a response section has already been written for the current
    -- user turn, so a second one can say it is a continuation instead of
    -- claiming the same number twice.
    local response_continued = false
    -- A slash command whose output has not arrived yet. The log files the
    -- command and what it did as two separate messages, so pairing them takes
    -- a one-item memory that survives from one message to the next.
    local pending_command = nil
    -- The name of a skill just invoked, held until the message carrying that
    -- skill's text arrives in the user's seat behind it.
    local pending_skill = nil
    -- Everything the model has said so far this conversation, reduced to
    -- the form a reader saw, so a line the user pastes back can be found
    -- in it. Unlike assistant_blocks above, this is NEVER emptied at a
    -- user turn: the user quotes answers from far earlier in the session,
    -- not only the one they just read.
    local prior_speech = {}

    -- {{{ emit_marginal(text)
    -- Write one short line that is neither a user turn nor an assistant turn -
    -- a command that was run, a background task reporting in, a change of
    -- model. It sits on the assistant's side of the page because it is a fact
    -- about the machine, and carries no number because it is not part of the
    -- conversation's counting.
    local function emit_marginal(text)
        out:write(wrap_text(text, 80) .. "\n")
        out:write("\n")
        out:write(RULE .. "\n")
        out:write("\n")
    end
    -- }}}

    -- {{{ flush_pending_command()
    -- Write a slash command that never got its output, so an invocation is
    -- never silently lost just because nothing was printed after it.
    local function flush_pending_command()
        if pending_command then
            emit_marginal("`" .. pending_command .. "`")
            pending_command = nil
        end
    end
    -- }}}

    -- {{{ flush_assistant()
    -- Write everything the model said since the last user turn.
    --
    -- Two things happen here that did not before. The blocks are kept apart
    -- instead of being joined, and every block but the last is marked as
    -- narration - what was said while the work was still going on, as against
    -- the considered answer at the end (issue 028). And where the model
    -- changed between one block and the next, a line says so (issue 023).
    --
    -- Both flush points in the old code were copies of each other, which is
    -- exactly the drift this single routine exists to prevent.
    local function flush_assistant()
        if not current_user_uuid or #assistant_blocks == 0 then
            return
        end

        local heading = "### Assistant Response " .. (user_count - 1)
        if response_continued then
            heading = heading .. " (continued)"
        end
        out:write(heading .. "\n")
        out:write("\n")

        -- The considered answer is the last block of prose; a commit line
        -- after it (the reply ended by committing) must not turn the answer
        -- into narration.
        local last_prose = 0
        for i, block in ipairs(assistant_blocks) do
            if not block.commit_line and not block.picture_line then last_prose = i end
        end

        for i, block in ipairs(assistant_blocks) do
            -- Three kinds of block: a commit the conversation made, written as
            -- its own line exactly as recorded; a picture it looked at, a
            -- markdown picture line on its own (issue A10); or prose.
            if block.commit_line then
                out:write(block.commit_line .. "\n")
            elseif block.picture_line then
                out:write(block.picture_line .. "\n")
            else
                if block.model and block.model ~= last_model_announced then
                    if last_model_announced ~= nil then
                        out:write("*model: " .. block.model .. "*")
                        out:write("\n\n")
                    end
                    last_model_announced = block.model
                end

                local is_narration = (i < last_prose)
                if is_narration then
                    -- Two columns are spent on the quote marker, so the text
                    -- is measured and positioned in the 78 that remain. That
                    -- is what keeps a quoted line's right edge level with an
                    -- unquoted one's.
                    local body = format_content(block.text, 78)
                    out:write(quote_block(body) .. "\n")
                else
                    out:write(format_content(block.text, 80) .. "\n")
                end
            end
            out:write("\n")
        end

        out:write(RULE .. "\n")
        out:write("\n")
        assistant_blocks = {}
        response_continued = true
    end
    -- }}}

    for _, msg in ipairs(messages) do
        local msg_type = msg.type or ""

        -- Process user messages (skip tool results)
        if msg_type == "user" then
            local content = msg.message and msg.message.content or ""

            -- Check if this is a tool result (skip it)
            local is_tool_result = false
            if type(content) == "table" and #content > 0 then
                if content[1].tool_use_id then
                    is_tool_result = true
                end
            end

            -- A fork's directive: a tool result carrying the fork's orders as
            -- text (see pre-pass three). Read it as the request only while no
            -- user turn has been opened yet; any later tool result in a fork is
            -- an ordinary tool result and is skipped like everywhere else.
            if is_tool_result and is_fork_log and not current_user_uuid then
                is_tool_result = false
            end

            if not is_tool_result then
                local raw = strip_terminal_escapes(user_text_of(content))
                local prose, envelope = split_envelope(raw)

                -- Anything reaching the page has to come after what the model
                -- said before it, so pending prose is written out first.
                if #envelope > 0 or prose ~= "" then
                    flush_assistant()
                end

                for _, item in ipairs(envelope) do
                    if item.kind == "command" then
                        flush_pending_command()
                        pending_command = item.text
                    elseif item.kind == "output" then
                        -- The output of the command just seen belongs on the
                        -- same line as it: for /model this is the only place
                        -- the chosen model is ever named, and the verb tells a
                        -- change apart from a dismissal.
                        if pending_command then
                            emit_marginal("`" .. pending_command .. "` - "
                                .. item.text)
                            pending_command = nil
                        else
                            emit_marginal(item.text)
                        end
                    elseif item.kind == "skill" then
                        flush_pending_command()
                        emit_marginal("`" .. item.text .. "` *(skill)*")
                        pending_skill = item.text
                    elseif item.kind == "note" then
                        flush_pending_command()
                        -- Two paths: the task is a helper whose transcript
                        -- the exporter has already saved, so the line ends
                        -- with a link to that file; or it is anything else
                        -- (a background shell command, a helper that never
                        -- spoke and so has no file), and the line is the
                        -- summary alone.
                        local helper_file = item.id and helper_names["agent-" .. item.id]
                        if helper_file then
                            emit_marginal("*[background task] " .. item.text
                                .. " — [" .. helper_file .. "](" .. helper_file .. ")*")
                        else
                            emit_marginal("*[background task] " .. item.text .. "*")
                        end
                    elseif item.kind == "recap" then
                        flush_pending_command()
                        out:write("### Session Recap (written by the harness, not by either speaker)\n")
                        out:write("\n")
                        out:write(format_content(item.text, 80) .. "\n")
                        out:write("\n")
                        out:write(RULE .. "\n")
                        out:write("\n")
                    end
                end

                -- A message that was nothing but harness traffic is not a user
                -- turn and must not take a number in the user's sequence. This
                -- is also what stops the empty numbered blocks: a heading is
                -- now only ever written when there are words to put under it.
                if prose ~= "" and pending_skill then
                    -- The body of the skill just invoked, arriving in the
                    -- user's seat as though they had typed a reference manual.
                    -- It is the same text every time that skill is used, it is
                    -- addressed to the model rather than to any reader, and at
                    -- several thousand words it buries the conversation it
                    -- sits inside. The invocation line above already records
                    -- that it happened, which is the part worth keeping.
                    pending_skill = nil
                elseif prose ~= "" then
                    flush_pending_command()
                    out:write("### User Request " .. user_count .. "\n")
                    out:write("\n")
                    local quoted = mark_quoted_lines(prose, prior_speech)
                    out:write(format_content(quoted, 80) .. "\n")
                    out:write("\n")
                    out:write(RULE .. "\n")
                    out:write("\n")

                    current_user_uuid = msg.uuid or ""
                    user_count = user_count + 1
                    response_continued = false
                end

            -- A command's output. Dropped like every tool result, except for
            -- the commits it reports: those are kept as a line in the reply
            -- where they happened, so the transcript says which commits its
            -- conversation made (issue 035) - the only evidence that
            -- outlives the session log. Two paths: a turn is open, and each
            -- commit becomes a block of the reply; or none is (a fork's
            -- first orders), and there is no reply to put it in.
            elseif current_user_uuid then
                local reported = commits_reported(msg, commands_by_id)
                -- Two paths: the output announced its commits, and they are
                -- written as they are; or a commit command announced nothing,
                -- and git is asked which commits it made (issue 040).
                if #reported == 0 then
                    local content = msg.message and msg.message.content
                    local call_id = type(content) == "table" and type(content[1]) == "table"
                        and content[1].tool_use_id or nil
                    local call = call_id and calls_by_id[call_id]
                    if call and call.epoch and runs_a_commit(call.command) then
                        local result = msg.toolUseResult
                        local printed = type(result) == "table"
                            and ((result.stdout or "") .. "\n" .. (result.stderr or "")) or ""
                        reported = commits_recovered(call, printed, writes, recorded_hashes)
                    end
                end
                for _, commit in ipairs(reported) do
                    recorded_hashes[commit.hash:sub(1, 7)] = true
                    assistant_blocks[#assistant_blocks + 1] = { commit_line = commit_line(commit) }
                end
                -- And the pictures a see-in-3d run kept: shown where they
                -- were made, between the words before and after (issue A10).
                for _, picture in ipairs(pictures_reported(msg, commands_by_id)) do
                    assistant_blocks[#assistant_blocks + 1] = { picture_line = picture }
                end
            end

        -- Process assistant messages
        -- Collect every text block the model emitted between user turns.
        -- A single assistant message can interleave text and tool_use blocks,
        -- and a single user turn can produce several assistant messages while
        -- the model narrates its work. All of those text blocks are prose
        -- the model wanted the user to read, so we keep them all and skip
        -- only tool_use (and thinking) blocks.
        elseif msg_type == "assistant" and current_user_uuid then
            local content_list = msg.message and msg.message.content or {}
            local model = msg.message and msg.message.model

            if model == SYNTHETIC_MODEL then
                -- A notice from the harness wearing the model's seat. It is
                -- not something the model said, so it must not be mistaken
                -- for an answer, and it must not be marked as narration
                -- either. It goes in the margin, where the commands go.
                flush_assistant()
                for _, item in ipairs(content_list) do
                    if type(item) == "table" and item.type == "text"
                        and (item.text or "") ~= "" then
                        emit_marginal("*" ..
                            strip_terminal_escapes(item.text) .. "*")
                    end
                end
            elseif type(content_list) == "table" then
                for _, item in ipairs(content_list) do
                    if type(item) == "table" and item.type == "text" then
                        local text = strip_terminal_escapes(item.text or "")
                        if text ~= "" then
                            assistant_blocks[#assistant_blocks + 1] =
                                { text = text, model = model }
                            prior_speech[#prior_speech + 1] = spoken_form(text)
                        end
                    elseif type(item) == "table" and item.type == "tool_use"
                        and item.name == "AskUserQuestion" then
                        -- Rescue the decision this question captured instead of
                        -- dropping it like every other tool call.
                        local block = format_askuserquestion(item.input,
                            tool_results_by_id[item.id])
                        if block ~= "" then
                            assistant_blocks[#assistant_blocks + 1] =
                                { text = block, model = model }
                        end
                    end
                end
            end

        -- A recap Claude Code wrote while the person was away (issue 037).
        -- It is not placed in the body; it is noted for the contents list at
        -- the top, with the number of the last request heading already
        -- written, so a reader can find the spot. user_count is always the
        -- NEXT request's number, hence the minus one; zero means the recap
        -- came before any request.
        elseif msg_type == "system" and msg.subtype == "away_summary" then
            -- A recap with no readable time cannot be placed in the list;
            -- every one seen so far has had one, so its absence means the
            -- record's shape changed and is reported rather than guessed.
            local epoch = parse_timestamp(msg.timestamp)
            if not epoch then
                error("recap record has no readable timestamp: " .. tostring(msg.timestamp))
            end
            recaps[#recaps + 1] = {
                epoch = epoch,
                after_request = user_count - 1,
                text = recap_text(msg.content),
            }
        end
    end

    -- The race fingerprint (issue 020): a user turn exists but no assistant
    -- prose followed it. At Stop-hook time this almost always means the
    -- exporter read the JSONL before the reply's line was flushed - the one
    -- shape the Stop-hook race can produce. Computed here, at the same
    -- boundary the final flush uses, so the two can never disagree.
    local ends_with_user = (current_user_uuid ~= nil)
        and (#assistant_blocks == 0)

    flush_assistant()
    flush_pending_command()

    -- Two paths: the log held recaps, and they are listed between the header
    -- and the body; or it held none, and no Contents heading is written,
    -- because an empty list says nothing.
    if #recaps > 0 then
        out_file:write("## Contents\n")
        out_file:write("\n")
        for i, recap in ipairs(recaps) do
            out_file:write(wrap_text(i .. ". " .. os.date("%Y-%m-%d %H:%M", recap.epoch)
                .. ", " .. recap_place(recap.after_request) .. " - " .. recap.text, 80) .. "\n")
        end
        out_file:write("\n")
    end
    out_file:write(RULE .. "\n")
    out_file:write("\n")
    out_file:write(table.concat(out.parts))
    out_file:close()

    -- A session that wrote no turn at all -- someone opened /config, closed
    -- it, and said nothing -- is a husk, however many system entries gave it
    -- dates. It hands back no dates, so the exporter writes no file and
    -- retires any it wrote before (issue 020's husk rule). Found when
    -- double-diaper-dungeon's test of its own transcripts met one with a
    -- header and nothing under it.
    if not table.concat(out.parts):find("### ", 1, true) then
        return nil, nil, nil, ends_with_user
    end

    -- Hand back three dating signals: the end epoch (used to stamp the file's
    -- mtime, unchanged) plus the start and end calendar dates (used to build
    -- the date-range filename) - and the race fingerprint, so the shell
    -- wrapper can decide to wait and re-read (issue 020).
    return parse_timestamp(final_timestamp),
        to_date_string(first_timestamp),
        to_date_string(final_timestamp),
        ends_with_user
end
-- }}}

-- {{{ main
-- Main entry point
local function main(args)
    if #args < 2 then
        io.stderr:write("Usage: conversation-parser.lua <input.jsonl> <output.md>\n")
        os.exit(1)
    end

    local jsonl_file = args[1]
    local output_file = args[2]

    local success, timestamp, start_date, final_date, ends_with_user =
        pcall(parse_conversation, jsonl_file, output_file)

    if not success then
        io.stderr:write("Error parsing conversation: " .. tostring(timestamp) .. "\n")
        os.exit(1)
    end

    -- Emit the dating signals to stderr for the shell wrapper to capture.
    -- FINAL_TIMESTAMP drives the mtime; START_DATE/FINAL_DATE drive the name.
    -- ENDS_WITH_USER drives the exporter's wait-and-re-read race guard.
    if timestamp then
        io.stderr:write("FINAL_TIMESTAMP:" .. timestamp .. "\n")
    end
    -- Commit commands that announced nothing and matched no single commit
    -- (issue 040): counted, so the exporter can say so, never fatal.
    if recovery_unmatched > 0 then
        io.stderr:write("RECOVERY_UNMATCHED:" .. recovery_unmatched .. "\n")
    end
    if start_date then
        io.stderr:write("START_DATE:" .. start_date .. "\n")
    end
    if final_date then
        io.stderr:write("FINAL_DATE:" .. final_date .. "\n")
    end
    if ends_with_user then
        io.stderr:write("ENDS_WITH_USER:1\n")
    end

    return 0
end
-- }}}

-- Run main if executed as script.
-- arg[0] is checked for existence as well as content: when this file is
-- pulled in as a library by something that was itself started with -e, arg
-- exists but arg[0] does not, and indexing straight into it took the whole
-- process down rather than simply declining to run main.
if arg and arg[0] and arg[0]:match("conversation%-parser%.lua$") then
    os.exit(main(arg))
end

-- Export functions for use as library
return {
    parse_conversation = parse_conversation,
    parse_timestamp = parse_timestamp,
    -- Exported so the archive repair tool corrects dates by the very same
    -- reasoning the exporter uses, rather than keeping a second copy of it
    -- that could drift.
    utc_fields_to_epoch = utc_fields_to_epoch,
    format_content = format_content,
    wrap_text = wrap_text,
    spoken_form = spoken_form,
    mark_quoted_lines = mark_quoted_lines,
}
