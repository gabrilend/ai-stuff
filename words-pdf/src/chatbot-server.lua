#!/usr/bin/env luajit

-- {{{ Conversational Chatbot Web Server for Words-PDF
local DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf"

-- Configure Lua package paths to find project libraries
package.path = DIR .. "/libs/?.lua;" .. 
               DIR .. "/libs/luasocket/?.lua;" .. 
               package.path
package.cpath = DIR .. "/libs/luasocket/socket/?.so;" .. 
                DIR .. "/libs/luasocket/src/?.so;" .. 
                package.cpath

-- {{{ load required modules
local socket = require("socket")
local json = require("dkjson")
local ollama_config = require("ollama-config")
-- }}}

-- {{{ load compiled text sections
local function load_compiled_text()
    local file = io.open(DIR .. "/input/compiled.txt", "r")
    if not file then return {} end
    
    local content = file:read("*all")
    file:close()
    
    local sections = {}
    for section in content:gmatch("([^" .. string.rep("-", 80) .. "]+)") do
        local trimmed = section:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            table.insert(sections, trimmed)
        end
    end
    
    return sections
end

local compiled_sections = load_compiled_text()
print("Loaded " .. #compiled_sections .. " text sections from compiled.txt")
-- }}}

-- {{{ utility functions
local function get_random_samples(sections, max_chars)
    if #sections == 0 or max_chars <= 0 then return "" end
    
    local samples = {}
    local total_chars = 0
    local attempts = 0
    
    while total_chars < max_chars and attempts < 20 do
        local idx = math.random(1, #sections)
        local section = sections[idx]
        
        if total_chars + #section <= max_chars then
            table.insert(samples, section)
            total_chars = total_chars + #section + 2 -- +2 for newlines
        end
        attempts = attempts + 1
    end
    
    return table.concat(samples, "\n\n")
end

local function generate_system_status()
    local moods = {"contemplative", "energetic", "melancholic", "curious", "serene", "restless", "focused", "wandering"}
    local postures = {"upright", "relaxed", "focused", "wandering", "alert", "meditative", "flowing", "static"}
    
    local mood = moods[math.random(#moods)]
    local posture = postures[math.random(#postures)]
    local cpu = math.random(15, 85) .. "%"
    local memory = math.random(20, 70) .. "%"
    local time = os.date("%H:%M:%S")
    
    return string.format("CPU:%s Mem:%s %s %s.%s", cpu, memory, mood, posture, time)
end

local function url_encode(str)
    return str:gsub("([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function url_decode(str)
    return str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end):gsub("+", " ")
end

local function parse_json_body(body)
    local success, data = pcall(json.decode, body)
    if success then
        return data
    else
        return nil
    end
end
-- }}}

-- {{{ ollama integration
local function call_ollama(messages)
    local temp_file = "/tmp/ollama_request_" .. os.time() .. ".json"
    local response_file = "/tmp/ollama_response_" .. os.time() .. ".json"
    
    local request_data = {
        model = "gemma3:12b-it-qat", -- Google's newest 12.2B model with 131k token context
        messages = messages,
        max_tokens = 20,
        stream = false,
        options = {
            temperature = 0.8,
            top_p = 0.9,
            stop = {"\n", ".", "!", "?"}
        }
    }
    
    local file = io.open(temp_file, "w")
    if not file then
        print("ERROR: Could not create temporary request file")
        return "Error: Could not create request"
    end
    file:write(json.encode(request_data))
    file:close()
    
    local curl_cmd = string.format(
        'curl -s -X POST "%s/api/chat" -H "Content-Type: application/json" -d @%s > %s',
        ollama_config.OLLAMA_ENDPOINT, temp_file, response_file
    )
    
    local exit_code = os.execute(curl_cmd)
    
    os.remove(temp_file)
    
    if exit_code ~= 0 then
        os.remove(response_file)
        return "Error: Ollama request failed"
    end
    
    local response_content = ""
    local response_file_handle = io.open(response_file, "r")
    if response_file_handle then
        response_content = response_file_handle:read("*all")
        response_file_handle:close()
        os.remove(response_file)
    else
        return "Error: Could not read response"
    end
    
    local response_data = json.decode(response_content)
    if response_data and response_data.message and response_data.message.content then
        local content = response_data.message.content
        -- Limit to 80 characters
        if #content > 80 then
            content = content:sub(1, 80)
        end
        return content
    else
        return "Error: Invalid response from AI"
    end
end
-- }}}

-- {{{ http response helpers
local function send_response(client, status, content_type, body)
    local response = string.format(
        "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s",
        status, content_type, #body, body
    )
    client:send(response)
end

local function send_html_file(client, filename)
    local file = io.open(DIR .. "/src/" .. filename, "r")
    if file then
        local content = file:read("*all")
        file:close()
        send_response(client, "200 OK", "text/html; charset=UTF-8", content)
    else
        send_response(client, "404 Not Found", "text/html", "<h1>404 Not Found</h1>")
    end
end

local function send_json_response(client, data)
    local json_str = json.encode(data)
    send_response(client, "200 OK", "application/json", json_str)
end
-- }}}

-- {{{ request handlers
local function handle_chat_request(client, body)
    local data = parse_json_body(body)
    if not data or not data.message then
        send_json_response(client, {error = "Invalid request"})
        return
    end
    
    local user_message = data.message
    local history = data.history or {}
    
    -- Build context with inspiration + conversation history
    local CONTEXT_LIMIT = 400000 -- Gemma3's massive context window
    local inspiration_chars = math.floor(CONTEXT_LIMIT * 0.5)
    local conversation_chars = math.floor(CONTEXT_LIMIT * 0.4)
    
    -- Get random inspiration
    local inspiration = get_random_samples(compiled_sections, inspiration_chars)
    
    -- Build conversation context from history (user messages only)
    local conversation_context = ""
    for _, entry in ipairs(history) do
        if entry.isUser then
            conversation_context = conversation_context .. "USER: " .. entry.content .. "\n"
        end
    end
    
    -- Truncate conversation if too long
    if #conversation_context > conversation_chars then
        conversation_context = conversation_context:sub(-conversation_chars)
    end
    
    -- Add system status
    local system_status = generate_system_status()
    local status_title = "--- SYSTEM STATUS ---\n" .. system_status .. "\n--- INSPIRATION ---\n"
    
    -- Build full context
    local full_context = status_title .. inspiration .. "\n\n--- CONVERSATION ---\n" .. conversation_context .. "USER: " .. user_message
    
    -- Create messages for Ollama
    local messages = {
        {
            role = "user",
            content = full_context
        }
    }
    
    -- Call Ollama
    local ai_response = call_ollama(messages)
    
    -- Determine if we should enter expansion mode (for longer responses)
    local expansion_context = nil
    if #ai_response >= 70 then -- Near the 80 char limit
        expansion_context = full_context
    end
    
    send_json_response(client, {
        response = ai_response,
        expansion_context = expansion_context,
        system_status = system_status
    })
end

local function handle_expand_request(client, body)
    local data = parse_json_body(body)
    if not data or not data.context then
        send_json_response(client, {error = "Invalid expansion request"})
        return
    end
    
    -- Generate next line with same context but different inspiration
    local inspiration = get_random_samples(compiled_sections, 10000) -- Smaller sample for expansion
    local context_with_inspiration = data.context .. "\n\n--- NEW INSPIRATION ---\n" .. inspiration
    
    local messages = {
        {
            role = "user", 
            content = context_with_inspiration .. "\n\nContinue with another line:"
        }
    }
    
    local ai_response = call_ollama(messages)
    
    send_json_response(client, {
        line = ai_response
    })
end

local function handle_system_status_request(client)
    local status = generate_system_status()
    send_response(client, "200 OK", "text/plain", status)
end
-- }}}

-- {{{ main server loop
local function start_server()
    math.randomseed(os.time())
    
    local server = socket.bind("localhost", 8080)
    if not server then
        print("ERROR: Could not bind to localhost:8080")
        return
    end
    
    print("Conversational chatbot server starting on http://localhost:8080")
    print("Using Gemma3 12B model with 131k token context window")
    
    while true do
        local client = server:accept()
        if client then
            client:settimeout(30) -- 30 second timeout
            
            local request = client:receive("*l")
            if request then
                local method, path = request:match("(%S+) (%S+)")
                
                if method == "GET" then
                    if path == "/" or path == "/index.html" then
                        send_html_file(client, "chatbot.html")
                    elseif path == "/system-status" then
                        handle_system_status_request(client)
                    elseif path:match("%.js$") then
                        send_html_file(client, path:sub(2)) -- Remove leading /
                    elseif path:match("%.wasm$") then
                        send_html_file(client, path:sub(2)) -- Remove leading /
                    else
                        send_response(client, "404 Not Found", "text/html", "<h1>404 Not Found</h1>")
                    end
                elseif method == "POST" then
                    -- Read Content-Length
                    local content_length = 0
                    local line
                    repeat
                        line = client:receive("*l")
                        if line and line:match("^Content%-Length:") then
                            content_length = tonumber(line:match("%d+"))
                        end
                    until not line or line == ""
                    
                    -- Read body
                    local body = ""
                    if content_length > 0 then
                        body = client:receive(content_length) or ""
                    end
                    
                    if path == "/chat" then
                        handle_chat_request(client, body)
                    elseif path == "/expand" then
                        handle_expand_request(client, body)
                    else
                        send_response(client, "404 Not Found", "text/html", "<h1>404 Not Found</h1>")
                    end
                end
            end
            
            client:close()
        end
    end
end
-- }}}

-- Start the server
start_server()
-- }}}