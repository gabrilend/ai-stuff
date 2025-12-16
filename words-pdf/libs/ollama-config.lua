-- {{{ local function detect_ollama_endpoint
local function detect_ollama_endpoint()
    -- Try different possible Ollama endpoints
    local endpoints = {
        "http://localhost:11434",
        "http://127.0.0.1:11434", 
        "http://192.168.0.115:11434"
    }
    
    for _, endpoint in ipairs(endpoints) do
        local cmd = "curl -s --max-time 2 " .. endpoint .. "/api/tags > /dev/null 2>&1"
        local result = os.execute(cmd)
        if result == 0 or result == true then
            return endpoint
        end
    end
    
    return nil
end
-- }}}

-- {{{ local function get_ollama_endpoint
local function get_ollama_endpoint()
    -- Check if OLLAMA_HOST environment variable is set
    local ollama_host = os.getenv("OLLAMA_HOST")
    if ollama_host then
        return "http://" .. ollama_host
    end
    
    -- Auto-detect endpoint
    local endpoint = detect_ollama_endpoint()
    if endpoint then
        return endpoint
    end
    
    -- Default fallback
    return "http://localhost:11434"
end
-- }}}

local M = {}

M.OLLAMA_ENDPOINT = get_ollama_endpoint()

return M