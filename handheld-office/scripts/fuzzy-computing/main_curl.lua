#!/usr/bin/env luajit

local dkjson = require("dkjson")

-- Read input from arguments or stdin
local input_text = ""
if arg and arg[1] then
    input_text = table.concat(arg, " ")
else
    input_text = io.read("*all") or ""
    input_text = input_text:gsub("\n+$", "")
end

if input_text == "" then
    print("Error: No input provided")
    os.exit(1)
end

-- Function to call Ollama using curl
local function generate_with_curl(context, model)
    local request_body = {
        model = model,
        messages = context,
        stream = false
    }
    local json_data = dkjson.encode(request_body)
    
    -- Create temp file for request
    local temp_file = os.tmpname()
    local f = io.open(temp_file, "w")
    if not f then
        error("Could not create temp file: " .. temp_file)
    end
    f:write(json_data)
    f:close()
    
    -- Use curl with timeout
    local curl_cmd = string.format(
        'curl -m 60 -s -X POST http://localhost:11434/api/chat -H "Content-Type: application/json" -d @%s',
        temp_file
    )
    
    local handle = io.popen(curl_cmd)
    local response_text = handle:read("*a")
    local success = handle:close()
    
    -- Clean up
    os.remove(temp_file)
    
    if not response_text or response_text == "" then
        error("Empty response from Ollama API. Curl command: " .. curl_cmd)
    end
    
    local response = dkjson.decode(response_text)
    if not response or not response.message or not response.message.content then
        error("Invalid response from API")
    end
    
    print(response.message.content)
    return response
end

-- Classification
local classification_prompt = {
    {
        role = "system",
        content = "You are a classifier. Respond with only the word 'code' or 'text'."
    },
    {
        role = "user", 
        content = "Is this code, or text? please respond with only the words 'code' or 'text': " .. input_text
    }
}

local fast_model = "EmbeddingGemma:latest"  -- Model for determining which type of input
local classification_result = generate_with_curl(classification_prompt, fast_model)

-- Extract classification
local classification = classification_result.message.content:lower():match("code") and "code" or "text"

-- Retry if unclear
if classification ~= "code" and classification ~= "text" then
    classification_result = generate_with_curl(classification_prompt, fast_model)
    classification = classification_result.message.content:lower():match("code") and "code" or "text"
end

-- Process with appropriate model based on classification
local target_model
if classification == "code" then
    target_model = "gemma3n:latest"  -- Code processing model
else
    target_model = "gemma3n:latest"  -- Text processing model
end

local processing_prompt = {
    {
        role = "system",
        content = classification == "code" 
            and "You are a helpful coding assistant. Analyze and respond to code-related queries."
            or "You are a helpful assistant. Respond to text-based queries naturally."
    },
    {
        role = "user",
        content = input_text
    }
}

generate_with_curl(processing_prompt, target_model)