#!/usr/bin/env lua

-- Load the fuzzy-computing library
local fuzzy = require("fuzzy-computing")

-- Read input from arguments or stdin
local input_text = ""
if arg and arg[1] then
    -- Use command line arguments
    input_text = table.concat(arg, " ")
else
    -- Read all available stdin at once
    input_text = io.read("*all") or ""
    -- Remove trailing newlines
    input_text = input_text:gsub("\n+$", "")
end

if input_text == "" then
    print("Error: No input provided")
    os.exit(1)
end

-- Classification prompt
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

-- Use a fast model for classification
local fast_model = "phi3:latest"
local classification_result = fuzzy.generate(classification_prompt, fast_model)

-- Extract the classification from the response
local classification = classification_result.message.content:lower():match("code") and "code" or "text"

-- Retry classification if result doesn't make sense
if classification ~= "code" and classification ~= "text" then
    classification_result = fuzzy.generate(classification_prompt, fast_model)
    classification = classification_result.message.content:lower():match("code") and "code" or "text"
end

-- Select appropriate model based on classification
local target_model
if classification == "code" then
    target_model = "phi3:latest"  -- Use same fast model for code
else
    target_model = "phi3:latest"  -- Use same fast model for text
end

-- Process the input with the appropriate model
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

local final_result = fuzzy.generate(processing_prompt, target_model)
-- Output is already printed by the generate function
