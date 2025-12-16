#!/usr/bin/env lua5.2

-- {{{ HTML5-Only Web Server for Ollama Interface
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
-- Remove socket.http since we're using curl instead
local json = require("dkjson") -- Use dkjson from project libs
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
        if section:trim() ~= "" then
            table.insert(sections, section:trim())
        end
    end
    
    return sections
end
-- }}}

-- {{{ string trim utility
function string:trim()
    return self:match("^%s*(.-)%s*$")
end
-- }}}

-- {{{ get random text samples within character limit
local function get_random_samples(sections, max_chars)
    if #sections == 0 or max_chars <= 0 then return "" end
    
    local samples = {}
    local total_chars = 0
    local attempts = 0
    
    while total_chars < max_chars and attempts < 50 do
        local random_index = math.random(1, #sections)
        local section = sections[random_index]
        
        local formatted_section = string.rep("-", 80) .. "\n" .. 
                                 section .. "\n" .. 
                                 string.rep("-", 80)
        
        -- Check if adding this section would exceed limit
        if total_chars + #formatted_section + 2 > max_chars then
            break
        end
        
        table.insert(samples, formatted_section)
        total_chars = total_chars + #formatted_section + 2 -- +2 for \n\n
        attempts = attempts + 1
    end
    
    return table.concat(samples, "\n\n")
end
-- }}}

-- {{{ get system status with mood/posture (10%)
local function get_system_status()
    local handle = io.popen("uptime")
    local uptime = handle:read("*a")
    handle:close()
    
    local time = os.date("%H:%M:%S")
    local cpu = math.random(10, 80) -- simulated
    local memory = math.random(30, 90) -- simulated
    
    -- Add mood and posture elements
    local moods = {"contemplative", "energetic", "melancholic", "curious", "serene", "restless"}
    local postures = {"upright", "relaxed", "focused", "wandering", "alert", "meditative"}
    local mood = moods[math.random(1, #moods)]
    local posture = postures[math.random(1, #postures)]
    
    return string.format("CPU: %.1f%%, Memory: %.1f%%, Time: %s, Mood: %s, Posture: %s", 
                        cpu, memory, time, mood, posture)
end
-- }}}

-- {{{ detect concise response pairs
local function is_concise_pair(user_msg, ai_msg)
    local user_len = #user_msg
    local ai_len = #ai_msg
    
    -- Both messages under 50 characters considered concise
    if user_len <= 50 and ai_len <= 50 then
        return true, math.min(user_len, ai_len) -- Return the more concise length
    end
    
    return false, 0
end
-- }}}

-- {{{ filter to user messages only
local function filter_user_messages(history)
    local user_messages = {}
    for _, entry in ipairs(history) do
        if entry:match("^USER:") then
            table.insert(user_messages, entry)
        end
    end
    return user_messages
end
-- }}}

-- {{{ prioritized conversation memory management  
local function prioritized_conversation_memory(history, max_chars, preserve_concise)
    if #history == 0 then return "" end
    
    -- Filter to only user messages (AI can re-imagine its responses)
    local user_only_history = filter_user_messages(history)
    local full_text = table.concat(user_only_history, "\n")
    
    if #full_text <= max_chars then
        return full_text
    end
    
    -- If contextual needs are important, prioritize concise exchanges
    if preserve_concise then
        local priority_content = ""
        local regular_content = {}
        
        -- Scan for concise user messages in recent history (AI responses excluded)
        for i = #user_only_history, 1, -1 do
            local entry = user_only_history[i]
            local user_msg = entry:gsub("^USER: ", "")
            
            -- Prioritize shorter, more concise user messages
            if #user_msg <= 50 then
                if #priority_content + #entry + 1 <= max_chars * 0.6 then
                    priority_content = entry .. "\n" .. priority_content
                end
            else
                table.insert(regular_content, 1, entry)
            end
        end
        
        -- Fill remaining space with regular content
        local remaining_space = max_chars - #priority_content
        local regular_text = ""
        
        for i = 1, #regular_content do
            local test_text = regular_content[i] .. "\n" .. regular_text
            if #test_text <= remaining_space then
                regular_text = test_text
            else
                break
            end
        end
        
        return (priority_content .. regular_text):gsub("^\n+", ""):gsub("\n+$", "")
    else
        -- Normal truncation - take most recent user messages only
        local truncated = ""
        for i = #user_only_history, 1, -1 do
            local test_text = user_only_history[i] .. "\n" .. truncated
            if #test_text <= max_chars then
                truncated = test_text
            else
                break
            end
        end
        
        return truncated:gsub("^\n+", ""):gsub("\n+$", "")
    end
end
-- }}}

-- {{{ detect contextual importance
local function assess_contextual_importance(conversation_history, user_message)
    -- Check if recent exchanges suggest high contextual needs
    local recent_count = math.min(4, #conversation_history)
    local concise_pairs = 0
    
    for i = #conversation_history - recent_count + 1, #conversation_history, 2 do
        if i + 1 <= #conversation_history then
            local user_msg = conversation_history[i] or ""
            local ai_msg = conversation_history[i + 1] or ""
            
            if user_msg:match("^USER:") and ai_msg:match("^AI:") then
                local u = user_msg:gsub("^USER: ", "")
                local a = ai_msg:gsub("^AI: ", "")
                if is_concise_pair(u, a) then
                    concise_pairs = concise_pairs + 1
                end
            end
        end
    end
    
    -- High importance if 50% or more recent pairs are concise
    return concise_pairs >= (recent_count / 4)
end
-- }}}

-- {{{ call ollama api
local function call_ollama(inspiration_context, conversation_context, user_message, system_status, high_contextual_importance)
    local system_content
    
    if high_contextual_importance then
        -- Contextual needs are important - reduce inspiration, preserve conversation
        system_content = "System Status: " .. system_status -- Only 10% for status
        -- Note: inspiration may be reduced or omitted in favor of conversation context
    else
        -- Typical operations - normal ratios (50% inspiration + 10% status)
        system_content = inspiration_context .. "\n\nSystem Status: " .. system_status
    end
    
    local messages = {
        {
            role = "system",
            content = system_content
        },
        {
            role = "assistant", 
            content = conversation_context -- Prioritized conversation memory
        },
        {
            role = "user",
            content = user_message
        }
    }
    
    local request_body = json.encode({
        model = "gemma3:12b-it-qat", -- Google's newest 12.2B model with 131k token context - massive!
        messages = messages,
        stream = false,
        options = {
            temperature = 0.7,
            max_tokens = 20 -- Strict limit for 80 chars
        }
    })
    
    -- Use curl method like fuzzy-computing.lua to avoid ltn12 issues
    local input_file = "/tmp/ollama_request_" .. os.time() .. ".json"
    local output_file = "/tmp/ollama_response_" .. os.time() .. ".json"
    
    -- Write request to file
    local f = io.open(input_file, "w")
    if not f then
        return "Error creating request file"
    end
    f:write(request_body)
    f:close()
    
    -- Make curl request
    local curl_cmd = string.format(
        "curl -s -X POST %s/api/chat -H 'Content-Type: application/json' -d @%s > %s",
        ollama_config.OLLAMA_ENDPOINT, input_file, output_file
    )
    
    local result = os.execute(curl_cmd)
    
    -- Read response
    local response_file = io.open(output_file, "r")
    if not response_file then
        -- Cleanup
        os.remove(input_file)
        return "Error reading response file"
    end
    
    local response_text = response_file:read("*all")
    response_file:close()
    
    -- Cleanup
    os.remove(input_file)
    os.remove(output_file)
    
    if response_text and response_text ~= "" then
        local response = json.decode(response_text)
        if response and response.message then
            return response.message.content or "No response from Ollama"
        end
        return "Invalid response format from Ollama"
    else
        return "Empty response from Ollama"
    end
end
-- }}}

-- {{{ limit response to exactly 80 characters
local function limit_response(response)
    if #response <= 80 then return response end
    
    -- Hard truncate at exactly 80 characters
    return response:sub(1, 80)
end
-- }}}

-- {{{ generate expansion mode page
local function generate_expansion_page(initial_response, context, system_status)
    return string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Words-PDF Ollama Interface - Expansion Mode</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            margin: 0;
            padding: 20px;
            background-color: #1a1a1a;
            color: #00ff00;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .expansion-container {
            border: 1px solid #ffff00;
            padding: 10px;
            margin: 20px 0;
            background-color: #001100;
        }
        .expansion-prompt {
            color: #ffff00;
            font-size: 0.9em;
            margin-bottom: 10px;
        }
        .expanding-response {
            color: #00ff00;
            font-family: inherit;
            line-height: 1.2;
            white-space: pre-wrap;
        }
        .response-line {
            max-width: 80ch;
            margin-bottom: 2px;
            word-wrap: break-word;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Spacebar Expansion Mode</h1>
        
        <div class="expansion-container">
            <div class="expansion-prompt">Press SPACEBAR for next line, or type any key to exit...</div>
            <div id="expandingResponse" class="expanding-response">
                <div class="response-line">1: %s</div>
            </div>
        </div>
        
        <div id="systemStatus">System: %s</div>
        
        <script>
            let responseLines = ["%s"];
            let currentContext = "%s";
            
            // Update system status every 0.6-0.8 seconds
            function updateSystemStatus() {
                fetch('/system-status')
                .then(response => response.text())
                .then(status => {
                    document.getElementById('systemStatus').textContent = 'System: ' + status;
                })
                .catch(err => console.log('Status update failed'));
                
                // Random interval between 0.6-0.8 seconds (600-800ms)
                const randomInterval = 600 + Math.random() * 200;
                setTimeout(updateSystemStatus, randomInterval);
            }
            
            document.addEventListener('keydown', function(e) {
                if (e.code === 'Space') {
                    e.preventDefault();
                    generateNextLine();
                } else {
                    window.location.href = '/';
                }
            });
            
            function generateNextLine() {
                fetch('/expand-line', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({
                        context: currentContext,
                        previousLines: responseLines.join('\\n'),
                        lineNumber: responseLines.length + 1
                    })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.line) {
                        responseLines.push(data.line);
                        displayLines();
                    }
                })
                .catch(err => console.log('Line generation failed:', err));
            }
            
            function displayLines() {
                const container = document.getElementById('expandingResponse');
                container.innerHTML = '';
                
                responseLines.forEach((line, index) => {
                    const lineDiv = document.createElement('div');
                    lineDiv.className = 'response-line';
                    lineDiv.textContent = (index + 1) + ': ' + line;
                    container.appendChild(lineDiv);
                });
            }
            
            // Start system status updates
            updateSystemStatus();
        </script>
    </div>
</body>
</html>]], initial_response, system_status, initial_response:gsub('"', '\\"'), context:gsub('"', '\\"'))
end
-- }}}

-- {{{ generate html page
local function generate_html_page(inspiration, conversation_context, ai_response, system_status)
    return string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Words-PDF Ollama Interface</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            margin: 0;
            padding: 20px;
            background-color: #1a1a1a;
            color: #00ff00;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .inspiration-section {
            border: 1px solid #ffff00;
            padding: 10px;
            margin: 20px 0;
            background-color: #001100;
            white-space: pre-wrap;
            font-size: 0.9em;
        }
        .conversation-history {
            border: 1px solid #00ffff;
            padding: 10px;
            margin: 10px 0;
            background-color: #000011;
            max-height: 200px;
            overflow-y: auto;
        }
        .form-container {
            margin: 20px 0;
        }
        input[type="text"] {
            width: 70%%;
            background-color: #000;
            border: 1px solid #00ff00;
            color: #00ff00;
            padding: 10px;
            font-family: inherit;
            margin-right: 10px;
        }
        input[type="submit"] {
            background-color: #000;
            border: 1px solid #00ff00;
            color: #00ff00;
            padding: 10px 20px;
            cursor: pointer;
            font-family: inherit;
        }
        .ai-response {
            border: 1px solid #00ff00;
            padding: 10px;
            margin: 20px 0;
            background-color: #000;
            color: #00ff00;
            max-width: 80ch;
        }
        .system-status {
            border: 1px solid #ff0000;
            padding: 5px;
            margin: 10px 0;
            background-color: #110000;
            font-size: 0.8em;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Words-PDF Ollama Interface (HTML5 Only)</h1>
        
        <section class="inspiration-section">
            <h3>Current Inspiration Sample (50%% of prompt):</h3>
            <div>%s</div>
        </section>

        <section class="conversation-history">
            <h4>Recent Conversation Context (40%% of prompt):</h4>
            <div>%s</div>
        </section>

        <form class="form-container" method="GET" action="">
            <label for="message">Your Message:</label><br>
            <input type="text" name="message" placeholder="Enter your message..." required />
            <input type="submit" value="Send" />
        </form>

        <section class="ai-response">
            <h4>Latest AI Response (Limited to 80 characters):</h4>
            <div>%s</div>
        </section>

        <section class="system-status">
            <h4>System Status (10%% of prompt):</h4>
            <div id="mainSystemStatus">%s</div>
        </section>
    </div>
    
    <script>
        // Update system status on main page every 0.6-0.8 seconds
        function updateMainSystemStatus() {
            fetch('/system-status')
            .then(response => response.text())
            .then(status => {
                document.getElementById('mainSystemStatus').textContent = status;
            })
            .catch(err => console.log('Main status update failed'));
            
            // Random interval between 0.6-0.8 seconds (600-800ms)
            const randomInterval = 600 + Math.random() * 200;
            setTimeout(updateMainSystemStatus, randomInterval);
        }
        
        // Start system status updates when page loads
        document.addEventListener('DOMContentLoaded', function() {
            updateMainSystemStatus();
        });
    </script>
</body>
</html>]], inspiration, conversation_context, ai_response, system_status)
end
-- }}}

-- {{{ handle line expansion requests
local function handle_line_expansion(request_body, sections)
    local data = json.decode(request_body)
    if not data then return "" end
    
    local context = data.context or ""
    local previous_lines = data.previousLines or ""
    local line_number = data.lineNumber or 1
    
    -- Generate different inspiration subset for this line (respecting character limits)
    local CONTEXT_LIMIT = 400000 -- Gemma3's massive 131k token context (~400k chars)
    local inspiration_chars = math.floor(CONTEXT_LIMIT * 0.5)
    local inspiration = get_random_samples(sections, inspiration_chars)
    local system_status = get_system_status()
    
    -- Build accumulated context including previous lines (respecting character limits)
    local CONTEXT_LIMIT = 400000 -- Gemma3's massive 131k token context (~400k chars)
    local inspiration_chars = math.floor(CONTEXT_LIMIT * 0.5)
    local context_chars = math.floor(CONTEXT_LIMIT * 0.4) 
    
    -- Add system status as "title" for this spacebar expansion context
    local status_title = "--- EXPANSION CONTEXT ---\n" .. system_status .. "\n--- USER CONTEXT ---\n"
    
    -- Truncate context if too long (accounting for status title)
    local available_chars = context_chars - #status_title
    local truncated_context = context
    local truncated_previous = previous_lines
    
    if #context + #previous_lines > available_chars then
        local available = available_chars - #context
        if available > 0 then
            truncated_previous = previous_lines:sub(1, available)
        else
            truncated_context = context:sub(1, available_chars - 50)
            truncated_previous = ""
        end
    end
    
    local full_context = status_title .. truncated_context .. "\n\nPrevious lines:\n" .. truncated_previous
    
    -- Generate next 80-character line  
    local next_line = call_ollama(inspiration, full_context, 
                                 string.format("Continue line %d:", line_number), 
                                 system_status, false)
    next_line = limit_response(next_line)
    
    return json.encode({line = next_line})
end
-- }}}

-- {{{ main server function
local function start_server()
    local server = socket.bind("localhost", 8080)
    local sections = load_compiled_text()
    local conversation_history = {}
    
    print("HTML5-Only Ollama server with spacebar expansion starting on http://localhost:8080")
    
    while true do
        local client = server:accept()
        local request = client:receive()
        
        if request then
            -- Handle system status updates
            if request:match("GET /system%-status") then
                local status = get_system_status()
                local response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n" .. status
                client:send(response)
            -- Handle line expansion requests  
            elseif request:match("POST /expand%-line") then
                local content_length = request:match("Content%-Length: (%d+)")
                if content_length then
                    local body = client:receive(tonumber(content_length))
                    local response_data = handle_line_expansion(body, sections)
                    
                    local response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" .. response_data
                    client:send(response)
                end
            elseif request:match("GET /%?message=") then
                local message = request:match("GET /%?message=([^%s&]*)")
                if message then
                    -- Proper URL decoding
                    message = message:gsub("+", " ")        -- Plus to space
                    message = message:gsub("%%(%x%x)", function(hex)
                        return string.char(tonumber(hex, 16))
                    end)
                else
                    message = "No message received"
                end
                table.insert(conversation_history, "USER: " .. message)
                
                -- Assess contextual importance and adjust memory allocation
                local high_importance = assess_contextual_importance(conversation_history, message)
                local system_status = get_system_status() -- 10% for mood/posture/status
                
                -- Context allocation - Codestral likely supports 32k+ tokens (much more than LLaMA3's 8k)
                -- With GTX 1080Ti (11GB VRAM) and potentially larger context window
                local CONTEXT_LIMIT = 400000 -- Gemma3's massive 131k token context (~400k chars)
                local inspiration_chars = math.floor(CONTEXT_LIMIT * 0.5) -- 50% = ~1900 chars
                local conversation_chars = math.floor(CONTEXT_LIMIT * 0.4) -- 40% = ~1520 chars
                -- 10% reserved for system status (handled separately)
                
                local inspiration, context
                if high_importance then
                    -- Prioritize concise exchanges over inspiration
                    inspiration = "" -- May omit inspiration when context is critical
                    context = prioritized_conversation_memory(conversation_history, conversation_chars + inspiration_chars, true) -- Up to 60% for priority context
                else
                    -- Normal operations - standard ratios
                    inspiration = get_random_samples(sections, inspiration_chars) -- 50% of available space
                    context = prioritized_conversation_memory(conversation_history, conversation_chars, false) -- 40% of available space
                end
                
                -- Debug: log context sizes
                print(string.format("Context sizes - Inspiration: %d chars, Conversation: %d chars, Total: %d chars", 
                                  #inspiration, #context, #inspiration + #context))
                
                -- Get AI response with adaptive context allocation
                local ai_response = call_ollama(inspiration, context, message, system_status, high_importance)
                ai_response = limit_response(ai_response)
                table.insert(conversation_history, "AI: " .. ai_response)
                
                -- Redirect to expansion mode instead of showing static response
                local function url_encode(str)
                    return str:gsub("([^%w%-%.%_~])", function(c)
                        return string.format("%%%02X", string.byte(c))
                    end)
                end
                
                local encoded_response = url_encode(ai_response)
                local encoded_context = url_encode(context)
                local redirect_url = string.format("/?expand=true&response=%s&context=%s", 
                                                  encoded_response, encoded_context)
                
                local response = "HTTP/1.1 302 Found\r\nLocation: " .. redirect_url .. "\r\n\r\n"
                client:send(response)
            else
                -- Handle initial page and expansion mode display
                local expand = request:match("expand=true")
                if expand then
                    -- Show expansion interface
                    local response_param = request:match("response=([^&%s]+)")
                    local context_param = request:match("context=([^&%s]+)")
                    
                    -- Proper URL decoding function
                    local function url_decode(str)
                        if not str then return "" end
                        str = str:gsub("+", " ")
                        return str:gsub("%%(%x%x)", function(hex)
                            return string.char(tonumber(hex, 16))
                        end)
                    end
                    
                    local decoded_response = url_decode(response_param)
                    local decoded_context = url_decode(context_param)
                    
                    local system_status = get_system_status()
                    local html = generate_expansion_page(decoded_response, decoded_context, system_status)
                    local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" .. html
                    client:send(response)
                else
                    -- Send normal initial page
                    local system_status = get_system_status()
                    local html = generate_html_page("", "Welcome to the interface", "Ready for your first message...", system_status)
                    local response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" .. html
                    client:send(response)
                end
            end
        end
        
        client:close()
    end
end
-- }}}

-- {{{ main execution
if arg and arg[0]:match("web%-server%.lua") then
    start_server()
end
-- }}}
-- }}}