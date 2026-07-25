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

-- {{{ wrap_text
-- Wrap text to specified width, preserving markdown structure
local function wrap_text(text, width)
    width = width or 80
    local lines = {}

    for line in text:gmatch("[^\n]*") do
        if line:match("^%s*$") then
            -- Empty line
            table.insert(lines, "")
        elseif line:match("^#") or line:match("^%-") or line:match("^%*") or line:match("^```") then
            -- Don't wrap markdown headers, lists, or code blocks
            table.insert(lines, line)
        else
            -- Wrap regular text
            local wrapped = ""
            local current_line = ""

            for word in line:gmatch("%S+") do
                if #current_line + #word + 1 <= width then
                    if #current_line > 0 then
                        current_line = current_line .. " " .. word
                    else
                        current_line = word
                    end
                else
                    if #current_line > 0 then
                        table.insert(lines, current_line)
                    end
                    current_line = word
                end
            end

            if #current_line > 0 then
                table.insert(lines, current_line)
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ format_content
-- Format content by converting ### to ## and wrapping text
local function format_content(content)
    if not content or content == "" then
        return ""
    end

    -- Convert ### to ## (downgrade heading levels)
    content = content:gsub("\n###", "\n##")
    content = content:gsub("^###", "##")

    -- Wrap the text
    content = wrap_text(content, 80)

    return content
end
-- }}}

-- {{{ extract_askq_answers
-- Recover each AskUserQuestion answer from the tool-result string by anchoring
-- on the exact question text (known from the tool call). The result reads
-- '"Q1"="A1", "Q2"="A2", … . You can now continue…', and answers can themselves
-- contain commas or quotes, so we bound each answer by the *next question's*
-- anchor rather than by naive splitting. Returns answers[i] keyed by question
-- index; a question with no locatable answer is simply absent.
local function extract_askq_answers(result_string, questions)
    local answers = {}
    if type(result_string) ~= "string" then return answers end
    for i, q in ipairs(questions) do
        local anchor = '"' .. (q.question or "") .. '"="'
        local s = result_string:find(anchor, 1, true)
        if s then
            local astart = s + #anchor
            local aend
            local nq = questions[i + 1]
            if nq then
                -- '"Ai", "Q(i+1)"=' — the closing quote of Ai sits right before
                -- this anchor, so aend lands on Ai's last character.
                local ns = result_string:find('", "' .. (nq.question or "") .. '"="', astart, true)
                if ns then aend = ns - 1 end
            end
            if not aend then
                -- Last answer (or the next anchor was not found): stop before
                -- the trailing '". You can now continue…' sentence, else drop a
                -- single trailing closing quote.
                local suf = result_string:find('". You can now continue', astart, true)
                if suf then
                    aend = suf - 1
                else
                    aend = #result_string
                    if result_string:sub(aend, aend) == '"' then aend = aend - 1 end
                end
            end
            answers[i] = result_string:sub(astart, aend)
        end
    end
    return answers
end
-- }}}

-- {{{ format_askuserquestion
-- Render one AskUserQuestion tool call, with its recorded answers, as readable
-- markdown — so the decision it captured survives in the transcript instead of
-- being dropped with the rest of the tool stream. For each question: the header
-- and question, every option offered, and the outcome. An answer that exactly
-- matches an option label is shown as a Selection; anything else (a typed
-- correction, or a multi-select join) is shown as an Answer, so the user's own
-- words stay visibly distinct from a menu pick.
local function format_askuserquestion(input, result_string)
    local questions = input and input.questions
    if type(questions) ~= "table" then return "" end
    local answers = extract_askq_answers(result_string, questions)

    local parts = { "**[Asked the user]**" }
    for i, q in ipairs(questions) do
        parts[#parts + 1] = ""
        local header = q.header and (" — " .. q.header) or ""
        parts[#parts + 1] = string.format("*Q%d%s:* %s", i, header, q.question or "")
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
            parts[#parts + 1] = (is_option and "→ **Selected:** " or "→ **Answered:** ") .. ans
        else
            parts[#parts + 1] = "→ *(no answer recorded)*"
        end
    end
    return table.concat(parts, "\n")
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
            -- Convert to Unix timestamp (rough approximation)
            local time_table = {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            }
            return os.time(time_table)
        end
    end

    return nil
end
-- }}}

-- {{{ to_date_string
-- Reduce a raw timestamp value to a calendar date "YYYY-MM-DD".
-- We read the date straight off the ISO string when we can, on purpose:
-- the recorded timestamps are UTC ("...Z"), and pulling the date fields
-- verbatim keeps the filename date matching the date the file's mtime lands
-- on (mtime is stamped from the same fields via os.time), so naming and the
-- on-disk timestamp never disagree. Only if the value arrives as a bare epoch
-- number do we fall back to formatting it.
local function to_date_string(timestamp_value)
    if type(timestamp_value) == "string" then
        local year, month, day = timestamp_value:match("(%d%d%d%d)%-(%d%d)%-(%d%d)")
        if year then
            return year .. "-" .. month .. "-" .. day
        end
    end

    local epoch = parse_timestamp(timestamp_value)
    if epoch then
        return os.date("!%Y-%m-%d", epoch) -- '!' formats in UTC to match above
    end

    return nil
end
-- }}}

-- {{{ parse_conversation
-- Parse JSONL conversation file and generate markdown summary
local function parse_conversation(jsonl_file, output_file)
    local json = load_dkjson()

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

    -- Generate markdown output
    local out = io.open(output_file, "w")
    if not out then
        error("Could not open output file: " .. output_file)
    end

    -- Extract conversation ID from filename
    local conversation_id = jsonl_file:match("([^/]+)%.jsonl$") or "unknown"

    -- Header
    out:write("# Conversation Summary: " .. conversation_id .. "\n")
    out:write("\n")
    out:write("Generated on: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
    out:write("\n")
    out:write(string.rep("-", 80) .. "\n")
    out:write("\n")

    local user_count = 1
    local current_user_uuid = nil
    local assistant_responses = {}

    -- Pre-pass: map every tool-result back to the tool call it answers, so the
    -- AskUserQuestion renderer can pair a question block with its answer. The
    -- map covers all results (cheap); only AskUserQuestion is looked up below.
    local tool_results_by_id = {}
    for _, msg in ipairs(messages) do
        if (msg.type or "") == "user" then
            local content = msg.message and msg.message.content
            if type(content) == "table" then
                for _, item in ipairs(content) do
                    if type(item) == "table" and item.tool_use_id
                        and item.type == "tool_result" then
                        tool_results_by_id[item.tool_use_id] = item.content
                    end
                end
            end
        end
    end

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

            if not is_tool_result then
                -- Flush every assistant text block accumulated since the
                -- previous user turn, joined by blank lines so each chunk
                -- still reads as its own paragraph.
                if current_user_uuid and #assistant_responses > 0 then
                    out:write("### Assistant Response " .. (user_count - 1) .. "\n")
                    out:write("\n")
                    local combined = table.concat(assistant_responses, "\n\n")
                    local formatted_response = format_content(combined)
                    out:write(formatted_response .. "\n")
                    out:write("\n")
                    out:write(string.rep("-", 80) .. "\n")
                    out:write("\n")
                    assistant_responses = {}
                end

                -- Output user message
                out:write("### User Request " .. user_count .. "\n")
                out:write("\n")
                if type(content) == "string" then
                    local formatted_request = format_content(content)
                    out:write(formatted_request .. "\n")
                end
                out:write("\n")
                out:write(string.rep("-", 80) .. "\n")
                out:write("\n")

                current_user_uuid = msg.uuid or ""
                user_count = user_count + 1
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

            if type(content_list) == "table" then
                for _, item in ipairs(content_list) do
                    if type(item) == "table" and item.type == "text" then
                        local text = item.text or ""
                        if text ~= "" then
                            table.insert(assistant_responses, text)
                        end
                    elseif type(item) == "table" and item.type == "tool_use"
                        and item.name == "AskUserQuestion" then
                        -- Rescue the decision this question captured instead of
                        -- dropping it like every other tool call.
                        local block = format_askuserquestion(item.input,
                            tool_results_by_id[item.id])
                        if block ~= "" then
                            table.insert(assistant_responses, block)
                        end
                    end
                end
            end
        end
    end

    -- The race fingerprint (issue 020): a user turn exists but no assistant
    -- prose followed it. At Stop-hook time this almost always means the
    -- exporter read the JSONL before the reply's line was flushed - the one
    -- shape the Stop-hook race can produce. Computed here, at the same
    -- boundary the final flush uses, so the two can never disagree.
    local ends_with_user = (current_user_uuid ~= nil)
        and (#assistant_responses == 0)

    -- Final flush: same combining behavior as the mid-stream flush above,
    -- for any trailing assistant prose after the last user message.
    if current_user_uuid and #assistant_responses > 0 then
        out:write("### Assistant Response " .. (user_count - 1) .. "\n")
        out:write("\n")
        local combined = table.concat(assistant_responses, "\n\n")
        local formatted_response = format_content(combined)
        out:write(formatted_response .. "\n")
        out:write("\n")
        out:write(string.rep("-", 80) .. "\n")
    end

    out:close()

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

-- Run main if executed as script
if arg and arg[0]:match("conversation%-parser%.lua$") then
    os.exit(main(arg))
end

-- Export functions for use as library
return {
    parse_conversation = parse_conversation,
    parse_timestamp = parse_timestamp,
    format_content = format_content,
    wrap_text = wrap_text,
}
