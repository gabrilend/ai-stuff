#!/usr/bin/env lua

local DIR = arg and arg[1] or "/mnt/mtwo/programming/ai-stuff/continual-co-operation"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/libs/?/init.lua;" .. package.path

local dkjson = require("dkjson")
local socket = require("socket")
local http = require("socket.http")
local ollama_config = require("ollama-config")

local M = {}

-- {{{ local function init_memory_state
local function init_memory_state()
    return {
        context_window = {},
        important_memories = {},
        context_size = 0,
        max_context_size = 4000,
        session_id = tostring(os.time()),
        remember_count = {},
        file_outputs = {}
    }
end
-- }}}

-- {{{ local function save_memory_to_file
local function save_memory_to_file(memory_state, filepath)
    local file = io.open(filepath, "w")
    if file then
        file:write(dkjson.encode(memory_state, { indent = true }))
        file:close()
        return true
    end
    return false
end
-- }}}

-- {{{ local function load_memory_from_file
local function load_memory_from_file(filepath)
    local file = io.open(filepath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local memory_state, err = dkjson.decode(content)
        if memory_state then
            return memory_state
        else
            print("Error loading memory: " .. (err or "unknown"))
        end
    end
    return init_memory_state()
end
-- }}}

-- {{{ local function calculate_importance_score
local function calculate_importance_score(text, remember_count)
    local score = 0
    local length_bonus = math.min(#text / 100, 5)
    local remember_bonus = (remember_count or 0) * 10
    local keyword_bonus = 0
    
    local important_keywords = {
        "important", "remember", "critical", "key", "essential",
        "TODO", "FIXME", "NOTE", "WARNING", "ERROR"
    }
    
    for _, keyword in ipairs(important_keywords) do
        if string.find(text:lower(), keyword:lower()) then
            keyword_bonus = keyword_bonus + 5
        end
    end
    
    return score + length_bonus + remember_bonus + keyword_bonus
end
-- }}}

-- {{{ local function think_twice_mechanism
local function think_twice_mechanism(memory_state, text)
    local text_hash = tostring(text:sub(1, 50))
    local current_count = memory_state.remember_count[text_hash] or 0
    memory_state.remember_count[text_hash] = current_count + 1
    
    local importance = calculate_importance_score(text, current_count + 1)
    
    if current_count >= 1 or importance > 15 then
        table.insert(memory_state.important_memories, {
            text = text,
            timestamp = os.time(),
            importance = importance,
            remember_count = current_count + 1
        })
        return true
    end
    
    return false
end
-- }}}

-- {{{ local function prune_context_window
local function prune_context_window(memory_state)
    while memory_state.context_size > memory_state.max_context_size and #memory_state.context_window > 0 do
        local removed = table.remove(memory_state.context_window, 1)
        memory_state.context_size = memory_state.context_size - #removed.content
        
        think_twice_mechanism(memory_state, removed.content)
    end
end
-- }}}

-- {{{ local function add_to_context
local function add_to_context(memory_state, content, role)
    role = role or "user"
    local entry = {
        role = role,
        content = content,
        timestamp = os.time()
    }
    
    table.insert(memory_state.context_window, entry)
    memory_state.context_size = memory_state.context_size + #content
    
    prune_context_window(memory_state)
end
-- }}}

-- {{{ local function call_ollama
local function call_ollama(messages, model)
    model = model or "llama2"
    local endpoint = ollama_config.OLLAMA_ENDPOINT
    
    local request_body = dkjson.encode({
        model = model,
        messages = messages,
        stream = false
    })
    
    local response_body = {}
    local result, status = http.request{
        url = endpoint .. "/api/chat",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body)
        },
        source = request_body,
        sink = function(chunk)
            if chunk then
                table.insert(response_body, chunk)
            end
            return true
        end
    }
    
    if status == 200 then
        local response = table.concat(response_body)
        local parsed, err = dkjson.decode(response)
        if parsed and parsed.message and parsed.message.content then
            return parsed.message.content
        else
            return "Error parsing response: " .. (err or "unknown")
        end
    else
        return "Error: HTTP " .. tostring(status) .. " - " .. (result or "unknown")
    end
end
-- }}}

-- {{{ function M.create_session
function M.create_session(memory_file)
    memory_file = memory_file or (DIR .. "/memory-state.json")
    local memory_state = load_memory_from_file(memory_file)
    
    return {
        memory_state = memory_state,
        memory_file = memory_file,
        
        ask = function(self, prompt)
            add_to_context(self.memory_state, prompt, "user")
            
            local messages = {}
            for _, entry in ipairs(self.memory_state.context_window) do
                table.insert(messages, {
                    role = entry.role,
                    content = entry.content
                })
            end
            
            if #self.memory_state.important_memories > 0 then
                local important_context = "Important memories:\n"
                for i = math.max(1, #self.memory_state.important_memories - 5), #self.memory_state.important_memories do
                    local memory = self.memory_state.important_memories[i]
                    important_context = important_context .. "- " .. memory.text .. "\n"
                end
                
                table.insert(messages, 1, {
                    role = "system",
                    content = important_context
                })
            end
            
            local response = call_ollama(messages)
            
            add_to_context(self.memory_state, response, "assistant")
            
            local output_file = DIR .. "/outputs/conversation-" .. self.memory_state.session_id .. ".txt"
            os.execute("mkdir -p " .. DIR .. "/outputs")
            local file = io.open(output_file, "a")
            if file then
                file:write(string.format("[%s] User: %s\n", os.date("%Y-%m-%d %H:%M:%S"), prompt))
                file:write(string.format("[%s] Assistant: %s\n\n", os.date("%Y-%m-%d %H:%M:%S"), response))
                file:close()
            end
            
            save_memory_to_file(self.memory_state, self.memory_file)
            
            return response
        end,
        
        save = function(self)
            return save_memory_to_file(self.memory_state, self.memory_file)
        end,
        
        get_memory_stats = function(self)
            return {
                context_entries = #self.memory_state.context_window,
                context_size = self.memory_state.context_size,
                important_memories = #self.memory_state.important_memories,
                session_id = self.memory_state.session_id
            }
        end
    }
end
-- }}}

return M