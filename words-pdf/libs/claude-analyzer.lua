local M = {}
local dkjson = require("libs/dkjson")

-- Claude API configuration
M.CLAUDE_API_URL = "https://api.anthropic.com/v1/messages"
M.CLAUDE_MODEL = "claude-sonnet-4-20250514"

function M.analyze_full_corpus(text, api_key) -- {{{
    local prompt = [[
You are a literary and thematic analysis expert. I need you to analyze this entire corpus of personal writings (poetry, messages, notes, philosophical reflections) and identify the dominant themes present.

The corpus contains ~550k words across ~6,500 individual pieces including:
- Personal messages and relationship advice
- Political commentary and social critique  
- Technical programming discussions
- Philosophical and existential reflections
- Mental health and transgender experiences
- Poetry with metaphysical themes
- Technology and privacy concerns
- Abstract mathematical and dimensional thinking

Please provide:

1. **PRIMARY THEMES** (10-15 most dominant themes with brief descriptions)
2. **THEME DISTRIBUTION** (rough percentage breakdown)
3. **UNIQUE CHARACTERISTICS** (what makes this corpus distinctive)
4. **ARTISTIC VISUALIZATION SUGGESTIONS** (how each theme could be represented visually through generative art)

For each theme, provide:
- Theme name (single word, lowercase)
- Brief description (1-2 sentences)
- Key concepts/keywords associated with it
- Suggested visual/artistic representation (colors, patterns, shapes, movement)
- Estimated prevalence in the corpus (rough %)

Focus on themes that would translate well into generative/procedural art systems.

Here is the full corpus to analyze:

]] .. text

    local request_body = {
        model = M.CLAUDE_MODEL,
        max_tokens = 4000,
        messages = {
            {
                role = "user", 
                content = prompt
            }
        },
        betas = {"context-1m-2025-08-07"}
    }
    
    local json_data = dkjson.encode(request_body)
    
    -- Create temporary files for curl communication
    local input_file = "/tmp/claude_request_" .. os.time() .. ".json"
    local output_file = "/tmp/claude_response_" .. os.time() .. ".json"
    local headers_file = "/tmp/claude_headers_" .. os.time() .. ".txt"
    
    -- Write request to file
    local f = io.open(input_file, "w")
    f:write(json_data)
    f:close()
    
    -- Write headers to file
    local h = io.open(headers_file, "w")
    h:write("Content-Type: application/json\n")
    h:write("x-api-key: " .. api_key .. "\n")
    h:write("anthropic-version: 2023-06-01\n")
    h:close()
    
    -- Make curl request with headers
    local curl_cmd = string.format(
        "curl -s -X POST '%s' -H @%s -d @%s > %s",
        M.CLAUDE_API_URL, headers_file, input_file, output_file
    )
    
    print("Sending " .. #json_data .. " bytes to Claude API...")
    print("This may take 30-60 seconds for large corpus analysis...")
    
    local success = os.execute(curl_cmd)
    
    -- Read response
    local response_file = io.open(output_file, "r")
    if not response_file then
        -- Cleanup
        os.remove(input_file)
        os.remove(headers_file)
        print("Error: Could not read Claude API response")
        return nil
    end
    
    local response_text = response_file:read("*all")
    response_file:close()
    
    -- Cleanup
    os.remove(input_file)
    os.remove(output_file)
    os.remove(headers_file)
    
    if #response_text == 0 then
        print("Error: Empty response from Claude API")
        return nil
    end
    
    local response = dkjson.decode(response_text)
    if response and response.content and response.content[1] and response.content[1].text then
        return response.content[1].text
    elseif response and response.error then
        print("Claude API Error: " .. (response.error.message or "Unknown error"))
        print("Error type: " .. (response.error.type or "Unknown"))
        return nil
    else
        print("Unexpected response format")
        print("Response preview: " .. string.sub(response_text, 1, 500))
        return nil
    end
end -- }}}

function M.analyze_sample_for_testing(api_key) -- {{{
    -- Test with a smaller sample first
    local test_text = [[
From the corpus sample:

"I think of myself as a synecdoche for humanity, and though I'm not always right, I try to be aligned when possible. Most people I've found aren't really like me I can as I am, and I promise, I won't hurt you."

"How tremulous is life, how candid our internals. To think is to have a mind, and minds can be read. While complexity brings privacy, the distance can be vulnerabilizing. To see another is to recognize that which unites sentience."

"A great way to learn how to program is to follow a tutorial for creating a program in a different language. What is a computer if not a body? A brain? Then what separates it from you? Truly, are you nothing but a program run on a piece of hardware?"

"Recently, there's been a ton of buzz in the news about internet privacy. The liberation of the computer is the liberation of us all. But I believe the only person who can truly design a tool is the person who the tool is intended to be used by."
]]

    local prompt = "Analyze this sample text and identify 5-8 key themes that would work well for generative art. For each theme provide: name, description, artistic representation suggestions."
    
    local request_body = {
        model = M.CLAUDE_MODEL,
        max_tokens = 2000,
        messages = {
            {
                role = "user", 
                content = prompt .. "\n\nText to analyze:\n" .. test_text
            }
        }
    }
    
    local json_data = dkjson.encode(request_body)
    
    -- Create temporary files
    local input_file = "/tmp/claude_test_" .. os.time() .. ".json"
    local output_file = "/tmp/claude_test_response_" .. os.time() .. ".json"
    local headers_file = "/tmp/claude_test_headers_" .. os.time() .. ".txt"
    
    -- Write request
    local f = io.open(input_file, "w")
    f:write(json_data)
    f:close()
    
    -- Write headers
    local h = io.open(headers_file, "w")
    h:write("Content-Type: application/json\n")
    h:write("x-api-key: " .. api_key .. "\n")
    h:write("anthropic-version: 2023-06-01\n")
    h:close()
    
    -- Make request
    local curl_cmd = string.format(
        "curl -s -X POST '%s' -H @%s -d @%s > %s",
        M.CLAUDE_API_URL, headers_file, input_file, output_file
    )
    
    print("Testing Claude API connection...")
    os.execute(curl_cmd)
    
    -- Read response
    local response_file = io.open(output_file, "r")
    if not response_file then
        print("Error: Could not read test response")
        return nil
    end
    
    local response_text = response_file:read("*all")
    response_file:close()
    
    -- Cleanup
    os.remove(input_file)
    os.remove(output_file)
    os.remove(headers_file)
    
    local response = dkjson.decode(response_text)
    if response and response.content and response.content[1] and response.content[1].text then
        return response.content[1].text
    elseif response and response.error then
        print("Claude API Error: " .. (response.error.message or "Unknown error"))
        return nil
    else
        print("Unexpected response format")
        return nil
    end
end -- }}}

return M