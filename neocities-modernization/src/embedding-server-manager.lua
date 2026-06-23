#!/usr/bin/env lua

-- {{{ embedding-server-manager.lua
-- Issue 10-049: Embedding-server manager. Originally written for Ollama
-- (10-005); reimplemented for llama.cpp. Provides liveness checks against
-- the configured inference server, can launch start-llamacpp-server.sh
-- when the server is down, and runs an end-to-end test embedding request.
--
-- Public API (preserved across the migration so call sites do not need
-- to change shape):
--   M.ensure_ready()           — return the endpoint URL once the server is up
--   M.test_embedding(ep, model) — send one /v1/embeddings request, verify shape
--
-- The big shape changes from the Ollama era:
--   - /api/tags        → /v1/models       (OpenAI-compatible liveness)
--   - /api/embeddings  → /v1/embeddings   (OpenAI-compatible inference)
--   - "prompt" body    → "input" body     (OpenAI request shape)
--   - response.embedding → response.data[1].embedding   (OpenAI response shape)
--   - "ollama pull"    → (removed)        (llama.cpp has the model on disk
--                                          already; nothing to pull)
--   - "ollama serve"   → delegate to scripts/start-llamacpp-server.sh
-- }}}

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

local DIR = setup_dir_path(arg and arg[1])
package.path = DIR .. "/libs/?.lua;" .. package.path
local inference_config = require("inference-server-config")

local M = {}

-- {{{ local function is_server_running
-- Pings /v1/models to verify the server is alive. /v1/models is llama.cpp's
-- OpenAI-compatible "what's loaded" endpoint — returns 200 with a JSON list
-- of one model when the server is healthy. We don't parse the list (the
-- consumer's job); exit code 0 from curl is enough to say "alive".
local function is_server_running(endpoint)
    local cmd = "curl -s --max-time 2 " .. endpoint .. "/v1/models > /dev/null 2>&1"
    local result = os.execute(cmd)
    return result == 0 or result == true
end
-- }}}

-- {{{ local function start_llamacpp_service
-- Invokes scripts/start-llamacpp-server.sh, which handles its own env setup
-- (libs/cuda on LD_LIBRARY_PATH), config resolution, and liveness wait.
-- Returning exit code 0 from the script means the server is up; we don't
-- need to wait again here.
local function start_llamacpp_service()
    print("Starting llama.cpp embedding server via scripts/start-llamacpp-server.sh...")
    local cmd = string.format('"%s/scripts/start-llamacpp-server.sh" "%s"', DIR, DIR)
    local result = os.execute(cmd)
    return result == 0 or result == true
end
-- }}}

-- {{{ function M.ensure_ready
-- Resolves the configured inference server, checks if it's running, starts
-- it if not. Returns the endpoint URL on success, nil on failure. The
-- public name dropped the "ollama" prefix in 10-049; callers update their
-- call site in the same atomic batch as the require rename.
function M.ensure_ready()
    local endpoint = inference_config.build_host_url()
    print("=== Inference Server Manager ===")
    print("Target endpoint: " .. endpoint)
    print("")

    print("Checking if the inference server is running...")
    if is_server_running(endpoint) then
        print("✓ Server is already running at " .. endpoint)
        return endpoint
    end

    print("✗ Server not running — attempting to start it")
    if start_llamacpp_service() and is_server_running(endpoint) then
        print("✓ Server is now ready at " .. endpoint)
        return endpoint
    end

    print("✗ Failed to start the inference server")
    print("  HINT: run ./scripts/start-llamacpp-server.sh manually for verbose output")
    return nil
end
-- }}}

-- {{{ function M.test_embedding
-- Sends a single test embedding request to /v1/embeddings (OpenAI shape)
-- and verifies the response body contains a "data" array with an
-- "embedding" key. We don't strictly validate the vector dimensions —
-- that's the consumer's job — but the substring check catches the
-- obvious "server started but doesn't actually serve embeddings" failure.
function M.test_embedding(endpoint, model)
    print("Testing embedding generation...")

    os.execute(string.format('"%s/scripts/ensure-tmp-symlink" "%s"', DIR, DIR))
    local result_path = DIR .. "/tmp/embedding_test.json"

    local test_cmd = string.format(
        "curl -s -X POST %s/v1/embeddings -H 'Content-Type: application/json' " ..
        "-d '{\"model\": \"%s\", \"input\": \"test embedding\"}' > %s",
        endpoint, model, result_path
    )
    os.execute(test_cmd)

    local result_file = io.open(result_path, "r")
    if not result_file then
        print("✗ Failed to read test response")
        return false
    end
    local content = result_file:read("*a")
    result_file:close()

    if content:find('"data"', 1, true) and content:find('"embedding"', 1, true) then
        print("✓ Embedding generation test passed")
        return true
    end
    print("✗ Embedding generation test failed")
    print("Response: " .. content)
    return false
end
-- }}}

-- {{{ function M.main
-- Interactive entry point for running the manager standalone.
function M.main(interactive_mode)
    if interactive_mode then
        print("=== Embedding Server Manager (interactive) ===")
        print("1. Ensure server is running, then test (default config)")
        print("2. Test embedding generation only")
        io.write("Select option (1-2): ")
        local choice = io.read()

        if choice == "1" or choice == "" then
            local endpoint = M.ensure_ready()
            if endpoint then
                M.test_embedding(endpoint, inference_config.get_selected_model())
            end
        elseif choice == "2" then
            local endpoint = inference_config.build_host_url()
            M.test_embedding(endpoint, inference_config.get_selected_model())
        else
            print("Invalid choice")
        end
    else
        local endpoint = M.ensure_ready()
        if endpoint then
            M.test_embedding(endpoint, inference_config.get_selected_model())
        end
    end
end
-- }}}

if arg then
    local interactive_mode = false
    for _, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive_mode = true
            break
        end
    end
    M.main(interactive_mode)
end

return M
