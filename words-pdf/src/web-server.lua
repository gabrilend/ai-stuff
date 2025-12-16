#!/usr/bin/env luajit

-- {{{ Simple Continuous Conversation Web Server
local DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf"

-- Get character limit from command line argument (default 80)
local CHAR_LIMIT = tonumber(arg and arg[1]) or 80
print("Character limit set to: " .. CHAR_LIMIT)

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
local server_config = require("server-config")
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
print("Loaded " .. #compiled_sections .. " text sections")
-- }}}

-- {{{ conversation storage and configuration
local conversation_history = {}
local current_char_limit = CHAR_LIMIT  -- Track current limit (can be changed via /context)
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
            total_chars = total_chars + #section + 2
        end
        attempts = attempts + 1
    end
    
    return table.concat(samples, "\n\n")
end

local function generate_system_status()
    local moods = {"contemplative", "energetic", "melancholic", "curious", "serene", "restless"}
    local postures = {"upright", "relaxed", "focused", "wandering", "alert", "meditative"}
    
    local mood = moods[math.random(#moods)]
    local posture = postures[math.random(#postures)]
    local cpu = math.random(15, 85) .. "%"
    local memory = math.random(20, 70) .. "%"
    
    -- Generate time with milliseconds if configured
    local time
    if server_config.SHOW_MILLISECONDS then
        local socket_time = socket.gettime()
        local seconds = math.floor(socket_time)
        local milliseconds = math.floor((socket_time - seconds) * 1000)
        time = os.date("%H:%M:%S", seconds) .. string.format(".%03d", milliseconds)
    else
        time = os.date("%H:%M:%S")
    end
    
    return string.format("CPU:%s Mem:%s %s.%s %s", cpu, memory, mood, posture, time)
end

local function handle_slash_command(command)
    local cmd, arg = command:match("^/(%w+)%s*(.*)")
    if not cmd then
        return nil, "Invalid command format. Type /help for available commands."
    end
    
    cmd = cmd:lower()
    
    if cmd == "help" then
        return "system", [[Available commands:
/help - Show this help message
/context <number> - Set character limit for AI responses (current: ]] .. current_char_limit .. [[)

Example: /context 150]]
    
    elseif cmd == "context" then
        local new_limit = tonumber(arg)
        if not new_limit or new_limit < server_config.MIN_CHAR_LIMIT or new_limit > server_config.MAX_CHAR_LIMIT then
            return "system", string.format("Usage: /context <number> (%d-%d). Current limit: %d", 
                server_config.MIN_CHAR_LIMIT, server_config.MAX_CHAR_LIMIT, current_char_limit)
        end
        
        local old_limit = current_char_limit
        current_char_limit = new_limit
        return "system", string.format("Character limit changed from %d to %d", old_limit, new_limit)
    
    else
        return nil, "Unknown command '" .. cmd .. "'. Type /help for available commands."
    end
end

local function call_ollama(messages, for_spacebar)
    local temp_file = "/tmp/ollama_request_" .. os.time() .. ".json"
    local response_file = "/tmp/ollama_response_" .. os.time() .. ".json"
    
    -- Adjust parameters based on whether this is spacebar continuation
    local options = {}
    if for_spacebar then
        -- Spacebar: continuation-focused parameters
        options = {
            temperature = 0.4,        -- Lower for more focused continuation
            top_p = 0.95,            -- High for creative but coherent flow
            num_ctx = 131072,        -- Full Gemma3 context window  
            repetition_penalty = 1.1, -- Avoid repetition loops
            -- No stop tokens - let it flow naturally
        }
    else
        -- Normal response: more creative parameters  
        options = {
            temperature = 0.7,       -- Moderate creativity
            top_p = 0.9,            -- Good balance
            num_ctx = 131072,       -- Full Gemma3 context window
            stop = {}               -- Remove \n stop token
        }
    end
    
    local request_data = {
        model = "gemma3:12b-it-qat", -- Using Gemma3 with massive context
        messages = messages,
        stream = false,
        options = options
    }
    
    local file = io.open(temp_file, "w")
    if not file then return "Error creating request" end
    
    local json_data = json.encode(request_data)
    print("DEBUG: JSON request data: " .. string.sub(json_data, 1, 200) .. "...")
    file:write(json_data)
    file:close()
    
    local curl_cmd = string.format(
        'curl -s --max-time 300 -X POST "%s/api/chat" -H "Content-Type: application/json" -d @%s > %s 2>&1',
        ollama_config.OLLAMA_ENDPOINT, temp_file, response_file
    )
    
    print("DEBUG: Calling Ollama with command: " .. curl_cmd)
    print("DEBUG: Request file: " .. temp_file)
    print("DEBUG: Response file: " .. response_file)
    print("DEBUG: Using 5-minute timeout for model loading...")
    
    local exit_code = os.execute(curl_cmd)
    print("DEBUG: Curl exit status: " .. tostring(exit_code))
    print("DEBUG: Exit code type: " .. type(exit_code))
    
    -- Check if response file was created
    local response_exists = io.open(response_file, "r")
    if response_exists then
        response_exists:close()
        print("DEBUG: Response file created successfully")
    else
        print("DEBUG: Response file was not created")
    end
    
    -- Validate curl execution succeeded (Lua returns true for success)  
    if exit_code == nil then
        print("DEBUG: Command execution failed completely - curl may not be available")
        os.remove(response_file)
        return "Error: Cannot execute curl command - check if curl is installed"
    elseif exit_code ~= true and exit_code ~= 0 then
        print("DEBUG: Curl command failed with exit status: " .. tostring(exit_code))
        os.remove(response_file)
        return "Error: Network request failed (status: " .. tostring(exit_code) .. ") - Check if Ollama model is loading"
    end
    
    os.remove(temp_file)
    
    -- Read response content with validation
    local response_content = ""
    local response_file_handle = io.open(response_file, "r")
    if response_file_handle then
        response_content = response_file_handle:read("*all")
        response_file_handle:close()
        os.remove(response_file)
        
        -- Validate response content
        print("DEBUG: Response file size: " .. #response_content .. " bytes")
        if #response_content == 0 then
            print("DEBUG: Empty response from Ollama")
            return "Error: Empty response from AI service"
        end
        
        -- Check for HTML error responses (common when Ollama is down)
        if response_content:match("^%s*<[Hh][Tt][Mm][Ll]") then
            print("DEBUG: Received HTML instead of JSON (Ollama may be offline)")
            return "Error: AI service returned HTML (service may be offline)"
        end
    else
        print("DEBUG: Could not open response file: " .. response_file)
        return "Error: Could not read AI response file"
    end
    
    -- Enhanced debug logging for response analysis
    print("DEBUG: Raw response preview (first 300 chars): " .. response_content:sub(1, 300))
    print("DEBUG: Response starts with: '" .. response_content:sub(1, 20) .. "'")
    print("DEBUG: Response ends with: '" .. response_content:sub(-20) .. "'")
    
    -- Robust JSON parsing with detailed error handling
    local success, response_data = pcall(json.decode, response_content)
    if success and response_data then
        print("DEBUG: JSON parsed successfully")
        
        -- Debug the response structure
        if type(response_data) ~= "table" then
            print("DEBUG: Response is not a table, got: " .. type(response_data))
            return "Error: AI response has unexpected format (not JSON object)"
        end
        
        -- Check for Ollama error responses
        if response_data.error then
            print("DEBUG: Ollama returned error: " .. tostring(response_data.error))
            return "Error: AI service error - " .. tostring(response_data.error)
        end
        
        if response_data.message and response_data.message.content then
            local content = response_data.message.content
            print("DEBUG: Extracted content (" .. #content .. " chars): " .. content:sub(1, 50) .. "...")
            
            -- Apply character limit
            if #content > current_char_limit then
                content = content:sub(1, current_char_limit)
                print("DEBUG: Truncated to " .. current_char_limit .. " characters")
            end
            return content
        else
            print("DEBUG: Response structure analysis:")
            print("DEBUG: - Has message field: " .. tostring(response_data.message ~= nil))
            if response_data.message then
                print("DEBUG: - Message has content field: " .. tostring(response_data.message.content ~= nil))
                local message_keys = {}
                for k, _ in pairs(response_data.message or {}) do
                    table.insert(message_keys, k)
                end
                print("DEBUG: - Message fields: " .. table.concat(message_keys, ", "))
            end
            return "Error: AI response missing expected content structure"
        end
    else
        print("DEBUG: JSON parsing failed")
        print("DEBUG: Parse error: " .. tostring(response_data))
        print("DEBUG: Attempting to identify response type...")
        
        -- Try to identify what we got instead of JSON
        if response_content:match("^%s*{.*}%s*$") then
            print("DEBUG: Looks like JSON but failed to parse - possible syntax error")
            return "Error: Malformed JSON response from AI service"
        elseif response_content:match("Connection refused") then
            print("DEBUG: Connection refused - Ollama service not running")
            return "Error: AI service connection refused (is Ollama running?)"
        elseif response_content:match("curl:") then
            print("DEBUG: Curl error in response")
            return "Error: Network error - " .. response_content:sub(1, 100)
        else
            print("DEBUG: Unknown response format")
            return "Error: Unexpected response format from AI service"
        end
    end
end
-- }}}

-- {{{ html generation
local function generate_conversation_html()
    local html_messages = {}
    
    for i, entry in ipairs(conversation_history) do
        if entry.type == "user" then
            table.insert(html_messages, string.format([[
                <div class="message user-message">
                    <strong>USER:</strong> %s
                </div>
            ]], entry.content))
        elseif entry.type == "ai" then
            table.insert(html_messages, string.format([[
                <div class="message ai-message">
                    <strong>%d.</strong> %s
                </div>
            ]], entry.number, entry.content))
        elseif entry.type == "system" then
            table.insert(html_messages, string.format([[
                <div class="message system-message">
                    <strong>SYSTEM:</strong> %s
                </div>
            ]], entry.content))
        end
    end
    
    return table.concat(html_messages, "\n")
end

-- {{{ build_conversation_messages - Create proper assistant/user message flow
local function build_conversation_messages(for_spacebar)
    local messages = {}
    
    -- Add inspiration as the assistant's internal voice/system context
    local inspiration = get_random_samples(compiled_sections, math.floor(200000 * 0.5))
    local system_status = generate_system_status()
    
    if for_spacebar then
        -- For spacebar: frame as the AI continuing its own thought
        table.insert(messages, {
            role = "system",
            content = "You are a poetry-inspired AI continuing your previous response. Your mind is filled with these verses:\n\n" .. inspiration .. "\n\nStatus: " .. system_status .. "\n\nContinue your previous thought seamlessly, building on what you just said. Focus on word-flow and creative continuation."
        })
        
        -- Add the conversation flow showing the AI's previous responses
        local ai_responses_since_user = {}
        local found_last_user = false
        
        for i = #conversation_history, 1, -1 do
            local entry = conversation_history[i]
            if entry.type == "user" and not found_last_user then
                found_last_user = true
                table.insert(messages, {role = "user", content = entry.content})
            elseif entry.type == "ai" and found_last_user then
                table.insert(ai_responses_since_user, 1, entry.content) -- Insert at beginning
            end
        end
        
        -- Add AI's previous responses as assistant messages
        for _, response in ipairs(ai_responses_since_user) do
            table.insert(messages, {role = "assistant", content = response})
        end
        
    else
        -- For initial response: frame as responding to user with poetry-inspired mind
        table.insert(messages, {
            role = "system", 
            content = "You are a poetry-inspired AI. Your mind contains these verses:\n\n" .. inspiration .. "\n\nStatus: " .. system_status .. "\n\nRespond creatively and thoughtfully to the user's message."
        })
        
        -- Add recent conversation flow
        local recent_messages = {}
        for i = math.max(1, #conversation_history - 6), #conversation_history do
            if conversation_history[i] then
                local entry = conversation_history[i]
                if entry.type == "user" then
                    table.insert(recent_messages, {role = "user", content = entry.content})
                elseif entry.type == "ai" then
                    table.insert(recent_messages, {role = "assistant", content = entry.content})
                end
            end
        end
        
        for _, msg in ipairs(recent_messages) do
            table.insert(messages, msg)
        end
    end
    
    return messages
end
-- }}}

-- {{{ Legacy build_context for backward compatibility
local function build_context()
    -- This is kept for any remaining single-message contexts
    local CONTEXT_LIMIT = 400000
    local inspiration = get_random_samples(compiled_sections, math.floor(CONTEXT_LIMIT * 0.5))
    local system_status = generate_system_status()
    
    local conversation_context = ""
    for _, entry in ipairs(conversation_history) do
        if entry.type == "user" then
            conversation_context = conversation_context .. "USER: " .. entry.content .. "\n"
        end
    end
    
    return "--- SYSTEM STATUS ---\n" .. system_status .. "\n--- INSPIRATION ---\n" .. inspiration .. "\n\n--- CONVERSATION ---\n" .. conversation_context
end
-- }}}

local function generate_main_page()
    local conversation_html = generate_conversation_html()
    
    return string.format([[
<!DOCTYPE html>
<html>
<head>
    <title>Words-PDF Continuous Chat</title>
    <style>
        body { 
            font-family: 'Courier New', monospace; 
            background: #1a1a1a; 
            color: #00ff00; 
            margin: 0; 
            padding: 20px; 
        }
        .container { max-width: 800px; margin: 0 auto; }
        .header { 
            text-align: center; 
            border-bottom: 1px solid #00ff00; 
            padding-bottom: 10px; 
            margin-bottom: 20px; 
        }
        .system-status { 
            color: #ffff00; 
            font-size: 12px; 
            margin-top: 5px; 
        }
        .conversation { 
            min-height: 400px; 
            border: 1px solid #00ff00; 
            padding: 15px; 
            margin-bottom: 20px; 
            background: #000; 
        }
        .message { 
            margin-bottom: 15px; 
            padding: 8px; 
            border-radius: 5px; 
        }
        .user-message { 
            background: #003300; 
            border-left: 3px solid #00ff00; 
            color: #00ffff; 
        }
        .ai-message { 
            background: #000033; 
            border-left: 3px solid #6666ff; 
            color: #99ccff; 
        }
        .system-message { 
            background: #330300; 
            border-left: 3px solid #ff6600; 
            color: #ffaa66; 
            font-style: italic;
        }
        .input-form { 
            display: flex; 
            gap: 10px; 
        }
        .message-input { 
            flex: 1; 
            background: #000; 
            border: 1px solid #00ff00; 
            color: #00ff00; 
            padding: 10px; 
            font-family: inherit; 
        }
        .send-button { 
            background: #003300; 
            border: 1px solid #00ff00; 
            color: #00ff00; 
            padding: 10px 20px; 
            cursor: pointer; 
            font-family: inherit; 
        }
        .send-button:hover { background: #006600; }
        .instructions { 
            font-size: 12px; 
            color: #666; 
            margin-top: 10px; 
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Words-PDF Continuous Chat</h1>
            <div class="system-status" id="systemStatus">%s</div>
        </div>
        
        <div class="conversation" id="conversation">
            %s
        </div>
        
        <form class="input-form" method="POST" action="/">
            <input type="text" name="message" class="message-input" 
                   placeholder="Type your message..." autocomplete="off" 
                   id="messageInput" autofocus>
            <button type="submit" class="send-button">Send</button>
        </form>
        
        <div class="instructions">
            Press ENTER or click Send to add your message. 
            Press SPACEBAR (when input is empty) to generate next AI line.
            Use slash commands: /help, /context &lt;number&gt;
        </div>
    </div>
    
    <script>
        let aiResponseCount = %d;
        
        // System status updates
        function updateStatus() {
            fetch('/status').then(r => r.text()).then(s => {
                document.getElementById('systemStatus').textContent = s;
            });
        }
        function scheduleNextUpdate() {
            const minInterval = %d;  // From config
            const maxInterval = %d;  // From config
            const randomInterval = minInterval + Math.random() * (maxInterval - minInterval);
            const showTiming = %s;   // From config
            
            if (showTiming) {
                console.log('Next status update in ' + randomInterval.toFixed(1) + 'ms at ' + new Date().toLocaleTimeString() + '.' + new Date().getMilliseconds().toString().padStart(3, '0'));
            }
            
            setTimeout(() => {
                updateStatus();
                scheduleNextUpdate();
            }, randomInterval);
        }
        scheduleNextUpdate();
        
        // Spacebar handling
        document.addEventListener('keydown', function(e) {
            const input = document.getElementById('messageInput');
            
            if (e.code === 'Space' && input.value.trim() === '') {
                e.preventDefault();
                // Generate next AI line
                fetch('/spacebar', {method: 'POST'})
                    .then(r => r.text())
                    .then(html => {
                        document.body.innerHTML = html;
                    });
            }
        });
    </script>
</body>
</html>
    ]], generate_system_status(), conversation_html, #conversation_history, 
        server_config.STATUS_UPDATE_MIN, server_config.STATUS_UPDATE_MAX, 
        server_config.SHOW_TIMING_INFO and "true" or "false")
end
-- }}}

-- {{{ server
local function start_server()
    math.randomseed(os.time())
    
    local server = socket.bind("localhost", 8080)
    if not server then
        print("ERROR: Could not bind to localhost:8080")
        return
    end
    
    print("Starting simple continuous chat server on http://localhost:8080")
    print("Using Gemma3 with full 131k token context window")
    
    while true do
        local client = server:accept()
        if client then
            client:settimeout(10)
            
            local request_line = client:receive("*l")
            if request_line then
                local method, path = request_line:match("(%S+) (%S+)")
                
                if method == "GET" then
                    if path == "/" then
                        local html = generate_main_page()
                        local response = string.format(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %d\r\n\r\n%s",
                            #html, html
                        )
                        client:send(response)
                    elseif path == "/status" then
                        local status = generate_system_status()
                        
                        -- Log timing info if configured
                        if server_config.SHOW_TIMING_INFO then
                            local current_time = socket.gettime()
                            local seconds = math.floor(current_time)
                            local milliseconds = math.floor((current_time - seconds) * 1000)
                            local time_str = os.date("%H:%M:%S", seconds) .. string.format(".%03d", milliseconds)
                            print("Status update generated at " .. time_str .. ": " .. status)
                        end
                        
                        local response = string.format(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n%s",
                            #status, status
                        )
                        client:send(response)
                    end
                    
                elseif method == "POST" then
                    -- Read headers to get content length
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
                    
                    if path == "/" then
                        -- User submitted a message
                        local message = body:match("message=([^&]*)")
                        if message then
                            message = message:gsub("%%(%x%x)", function(hex)
                                return string.char(tonumber(hex, 16))
                            end):gsub("+", " ")
                            
                            if message:trim() ~= "" then
                                -- Check if it's a slash command
                                if message:match("^/") then
                                    local cmd_type, cmd_response = handle_slash_command(message)
                                    
                                    -- Add user command to history
                                    table.insert(conversation_history, {
                                        type = "user",
                                        content = message
                                    })
                                    
                                    -- Add system response
                                    table.insert(conversation_history, {
                                        type = "system",
                                        content = cmd_response
                                    })
                                else
                                    -- Regular message - Add user message
                                    table.insert(conversation_history, {
                                        type = "user",
                                        content = message
                                    })
                                    
                                    -- Generate AI response
                                    local messages = build_conversation_messages(false)
                                    local ai_response = call_ollama(messages, false)
                                    
                                    -- Add AI response with number (count responses after last user message)
                                    local ai_number = 1
                                    local found_last_user = false
                                    for i = #conversation_history, 1, -1 do
                                        local entry = conversation_history[i]
                                        if entry.type == "user" and not found_last_user then
                                            found_last_user = true
                                        elseif entry.type == "ai" and found_last_user then
                                            ai_number = ai_number + 1
                                        end
                                    end
                                    
                                    table.insert(conversation_history, {
                                        type = "ai",
                                        content = ai_response,
                                        number = ai_number
                                    })
                                end
                            end
                        end
                        
                        -- Redirect back to main page
                        local response = "HTTP/1.1 302 Found\r\nLocation: /\r\n\r\n"
                        client:send(response)
                        
                    elseif path == "/spacebar" then
                        -- Generate next AI line (spacebar continuation)
                        local messages = build_conversation_messages(true)
                        local ai_response = call_ollama(messages, true)
                        
                        -- Add AI response with next number (count responses after last user message)
                        local ai_number = 1
                        local found_last_user = false
                        for i = #conversation_history, 1, -1 do
                            local entry = conversation_history[i]
                            if entry.type == "user" and not found_last_user then
                                found_last_user = true
                            elseif entry.type == "ai" and found_last_user then
                                ai_number = ai_number + 1
                            end
                        end
                        
                        table.insert(conversation_history, {
                            type = "ai", 
                            content = ai_response,
                            number = ai_number
                        })
                        
                        -- Return updated page
                        local html = generate_main_page()
                        local response = string.format(
                            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: %d\r\n\r\n%s",
                            #html, html
                        )
                        client:send(response)
                    end
                end
            end
            
            client:close()
        end
    end
end

-- {{{ string trim utility
function string:trim()
    return self:match("^%s*(.-)%s*$")
end
-- }}}

start_server()
-- }}}