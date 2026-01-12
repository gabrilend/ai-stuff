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

-- {{{ parse_conversation
-- Parse JSONL conversation file and generate markdown summary
local function parse_conversation(jsonl_file, output_file)
    local json = load_dkjson()

    -- Read and parse all messages
    local messages = {}
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
                -- Track the latest timestamp
                if data.timestamp then
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
                -- If we have accumulated assistant responses, output the last one
                if current_user_uuid and #assistant_responses > 0 then
                    out:write("### Assistant Response " .. (user_count - 1) .. "\n")
                    out:write("\n")
                    local formatted_response = format_content(assistant_responses[#assistant_responses])
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
        elseif msg_type == "assistant" and current_user_uuid then
            local content_list = msg.message and msg.message.content or {}
            local text_content = ""

            -- Extract text content from assistant message
            if type(content_list) == "table" then
                for _, item in ipairs(content_list) do
                    if type(item) == "table" and item.type == "text" then
                        text_content = item.text or ""
                        break
                    end
                end
            end

            if text_content ~= "" then
                table.insert(assistant_responses, text_content)
            end
        end
    end

    -- Output the final assistant response if we have one
    if current_user_uuid and #assistant_responses > 0 then
        out:write("### Assistant Response " .. (user_count - 1) .. "\n")
        out:write("\n")
        local formatted_response = format_content(assistant_responses[#assistant_responses])
        out:write(formatted_response .. "\n")
        out:write("\n")
        out:write(string.rep("-", 80) .. "\n")
    end

    out:close()

    -- Return final timestamp for file dating
    return parse_timestamp(final_timestamp)
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

    local success, timestamp = pcall(parse_conversation, jsonl_file, output_file)

    if not success then
        io.stderr:write("Error parsing conversation: " .. tostring(timestamp) .. "\n")
        os.exit(1)
    end

    -- Output timestamp to stderr for shell capture
    if timestamp then
        io.stderr:write("FINAL_TIMESTAMP:" .. timestamp .. "\n")
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
