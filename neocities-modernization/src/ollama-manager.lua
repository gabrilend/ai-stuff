#!/usr/bin/env lua

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(arg and arg[1])

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. package.path
local ollama_config = require("ollama-config")

local M = {}

-- {{{ local function is_ollama_running
local function is_ollama_running(endpoint)
    local cmd = "curl -s --max-time 2 " .. endpoint .. "/api/tags > /dev/null 2>&1"
    local result = os.execute(cmd)
    return result == 0 or result == true
end
-- }}}

-- {{{ local function check_model_available
local function check_model_available(endpoint, model)
    local cmd = "curl -s --max-time 5 " .. endpoint .. "/api/tags"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result:find(model, 1, true) then
        return true
    end
    return false
end
-- }}}

-- {{{ local function start_ollama_service
local function start_ollama_service(host, port)
    print("Starting Ollama service on " .. host .. ":" .. port .. "...")
    
    -- Set environment variable for host binding
    local env_cmd = "export OLLAMA_HOST=" .. host .. ":" .. port .. " && "
    local start_cmd = env_cmd .. "ollama serve > /tmp/ollama.log 2>&1 &"
    
    os.execute(start_cmd)
    
    -- Wait a few seconds for startup
    print("Waiting for Ollama to start...")
    os.execute("sleep 5")
    
    -- Check if it started successfully
    local endpoint = "http://" .. host .. ":" .. port
    if is_ollama_running(endpoint) then
        print("✓ Ollama started successfully at " .. endpoint)
        return endpoint
    else
        print("✗ Failed to start Ollama")
        return nil
    end
end
-- }}}

-- {{{ local function pull_model
local function pull_model(model)
    print("Installing model: " .. model .. "...")
    local cmd = "ollama pull " .. model
    local result = os.execute(cmd)
    if result == 0 or result == true then
        print("✓ Model " .. model .. " installed successfully")
        return true
    else
        print("✗ Failed to install model " .. model)
        return false
    end
end
-- }}}

-- {{{ function M.ensure_ollama_ready
function M.ensure_ollama_ready(target_host, target_port, required_model)
    target_host = target_host or "192.168.0.115"
    target_port = target_port or "10265"
    required_model = required_model or "embeddinggemma:latest"
    
    local target_endpoint = "http://" .. target_host .. ":" .. target_port
    
    print("=== Ollama Service Manager ===")
    print("Target endpoint: " .. target_endpoint)
    print("Required model: " .. required_model)
    print("")
    
    -- Check if Ollama is already running on target endpoint
    print("Checking if Ollama is running on target endpoint...")
    if is_ollama_running(target_endpoint) then
        print("✓ Ollama is already running at " .. target_endpoint)
        
        -- Check if required model is available
        print("Checking if " .. required_model .. " is available...")
        if check_model_available(target_endpoint, required_model) then
            print("✓ " .. required_model .. " is available")
            print("✓ Ollama is ready for use!")
            return target_endpoint
        else
            print("✗ " .. required_model .. " not found")
            if pull_model(required_model) then
                print("✓ Ollama is ready for use!")
                return target_endpoint
            else
                return nil
            end
        end
    else
        print("✗ Ollama not running on target endpoint")
        
        -- Try to start Ollama on the target endpoint
        local started_endpoint = start_ollama_service(target_host, target_port)
        if started_endpoint then
            -- Check and install model if needed
            print("Checking if " .. required_model .. " is available...")
            if not check_model_available(started_endpoint, required_model) then
                print("✗ " .. required_model .. " not found")
                if pull_model(required_model) then
                    print("✓ Ollama is ready for use!")
                    return started_endpoint
                else
                    return nil
                end
            else
                print("✓ " .. required_model .. " is available")
                print("✓ Ollama is ready for use!")
                return started_endpoint
            end
        else
            return nil
        end
    end
end
-- }}}

-- {{{ function M.test_embedding
function M.test_embedding(endpoint, model)
    print("Testing embedding generation...")
    
    -- Create test request
    local test_cmd = string.format(
        "curl -s -X POST %s/api/embeddings -H 'Content-Type: application/json' -d '{\"model\": \"%s\", \"prompt\": \"test embedding\"}' > /tmp/embedding_test.json",
        endpoint, model
    )
    
    os.execute(test_cmd)
    
    -- Check result
    local result_file = io.open("/tmp/embedding_test.json", "r")
    if result_file then
        local content = result_file:read("*a")
        result_file:close()
        
        if content:find('"embedding"', 1, true) then
            print("✓ Embedding generation test passed")
            return true
        else
            print("✗ Embedding generation test failed")
            print("Response: " .. content)
            return false
        end
    else
        print("✗ Failed to read test response")
        return false
    end
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("=== Ollama Manager Interactive Mode ===")
        print("1. Check and ensure Ollama is ready (default config)")
        print("2. Custom host/port configuration")
        print("3. Test embedding generation only")
        io.write("Select option (1-3): ")
        local choice = io.read()
        
        if choice == "1" or choice == "" then
            local endpoint = M.ensure_ollama_ready()
            if endpoint then
                M.test_embedding(endpoint, "embeddinggemma:latest")
            end
        elseif choice == "2" then
            io.write("Enter host (default: 192.168.0.115): ")
            local host = io.read()
            if host == "" then host = "192.168.0.115" end
            
            io.write("Enter port (default: 10265): ")
            local port = io.read()
            if port == "" then port = "10265" end
            
            io.write("Enter model (default: embeddinggemma:latest): ")
            local model = io.read()
            if model == "" then model = "embeddinggemma:latest" end
            
            local endpoint = M.ensure_ollama_ready(host, port, model)
            if endpoint then
                M.test_embedding(endpoint, model)
            end
        elseif choice == "3" then
            local endpoint = ollama_config.OLLAMA_ENDPOINT
            M.test_embedding(endpoint, "embeddinggemma:latest")
        else
            print("Invalid choice")
        end
    else
        -- Default non-interactive mode
        local endpoint = M.ensure_ollama_ready()
        if endpoint then
            M.test_embedding(endpoint, "embeddinggemma:latest")
        end
    end
end
-- }}}

-- Command line execution
if arg then
    local interactive_mode = false
    for i, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive_mode = true
            break
        end
    end
    
    M.main(interactive_mode)
end

return M