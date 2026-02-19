# Issue 049d: Ollama Processing Pipeline

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Critical (blocks all other 049 sub-issues)
**Created**: 2026-02-11
**Parent**: Issue 049 (LLM Transcript Abstraction Viewer)
**Dependencies**: None (foundation issue)

---

## Current Behavior

Ollama integration exists in the neocities-modernization project:
- `neocities-modernization/libs/ollama-config.lua` - Server configuration and selection
- `neocities-modernization/src/ollama-manager.lua` - Service management and readiness checks

However, these implementations are:
- Focused on embedding generation, not text generation/transformation
- Tied to the neocities project structure
- Not designed for the multi-prompt, validation-heavy workflow needed by 049

Delta-version currently has no direct Ollama integration for text generation tasks.

---

## Intended Behavior

A reusable Ollama client library that provides:
1. Text generation API (not just embeddings)
2. Configurable server selection (reuse existing config patterns)
3. Retry logic with exponential backoff
4. Response streaming for progress indication
5. Triple-check consensus validation (per Issue 035f patterns)
6. Rate limiting to prevent API overload
7. Response caching to avoid redundant processing

### API Design

```lua
local ollama = require("ollama-client")

-- Initialize with project root
ollama.init(DIR)

-- Simple generation
local response = ollama.generate("Summarize this: " .. content)

-- Generation with options
local response = ollama.generate(prompt, {
    model = "llama3",
    temperature = 0.3,
    max_tokens = 1024,
    stream = true,  -- Enable streaming for progress
})

-- Triple-check consensus
local result = ollama.generate_with_consensus(prompt, {
    required_agreement = 2,  -- 2/3 must agree
    max_attempts = 3,
})

-- Batch processing with rate limiting
local results = ollama.batch_generate(prompts, {
    rate_limit = 5,  -- requests per second
    on_progress = function(i, total) print(i .. "/" .. total) end,
})
```

---

## Suggested Implementation Steps

### 1. Create Client Library Skeleton

```lua
#!/usr/bin/env luajit
-- ollama-client.lua - Ollama API client for text generation
--
-- Provides a unified interface for Ollama text generation with support for
-- retry logic, streaming, consensus validation, and rate limiting.
--
-- Reuses server configuration patterns from neocities-modernization.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
-- }}}

local M = {}

-- {{{ Module state
local state = {
    initialized = false,
    server = nil,
    model = nil,
    cache = {},
    rate_limiter = nil,
}
-- }}}
```

### 2. Server Configuration Integration

```lua
-- {{{ init
-- Initialize the client with project root and optional overrides
function M.init(project_root, options)
    options = options or {}

    -- Try to load neocities ollama-config if available
    local ok, ollama_config = pcall(function()
        package.path = "/home/ritz/programming/ai-stuff/neocities-modernization/libs/?.lua;" .. package.path
        return require("ollama-config")
    end)

    if ok then
        ollama_config.set_project_root("/home/ritz/programming/ai-stuff/neocities-modernization")
        state.server = ollama_config.get_selected_server()
    else
        -- Fallback defaults
        state.server = {
            host = options.host or "localhost",
            port = options.port or 11434,
            model = options.model or "llama3",
        }
    end

    -- Override with options if provided
    if options.host then state.server.host = options.host end
    if options.port then state.server.port = options.port end
    state.model = options.model or state.server.model or "llama3"

    state.initialized = true
    return M
end
-- }}}
```

### 3. Core Generation Function

```lua
-- {{{ generate
-- Generate text using Ollama API
--
-- @param prompt string: The input prompt
-- @param options table: Optional settings (model, temperature, max_tokens, stream)
-- @return string: Generated text, or nil + error message
function M.generate(prompt, options)
    if not state.initialized then
        return nil, "Client not initialized. Call ollama.init() first."
    end

    options = options or {}
    local model = options.model or state.model
    local url = string.format("http://%s:%d/api/generate",
        state.server.host, state.server.port)

    -- Build request payload
    local payload = {
        model = model,
        prompt = prompt,
        stream = false,  -- Simplified: no streaming for now
        options = {
            temperature = options.temperature or 0.7,
            num_predict = options.max_tokens or 2048,
        },
    }

    -- Execute request
    local response, err = http_post(url, payload)
    if not response then
        return nil, "Ollama request failed: " .. (err or "unknown error")
    end

    -- Parse response
    local ok, result = pcall(json_decode, response)
    if not ok or not result.response then
        return nil, "Failed to parse Ollama response"
    end

    return result.response
end
-- }}}
```

### 4. HTTP Request Handler

```lua
-- {{{ http_post
-- Execute HTTP POST request using curl
local function http_post(url, payload)
    local json_payload = json_encode(payload)

    -- Escape for shell
    local escaped_payload = json_payload:gsub("'", "'\\''")

    local cmd = string.format(
        "curl -s -X POST '%s' -H 'Content-Type: application/json' -d '%s' --max-time 120",
        url, escaped_payload
    )

    local handle = io.popen(cmd)
    local response = handle:read("*a")
    local success = handle:close()

    if not success or response == "" then
        return nil, "Request failed or timed out"
    end

    return response
end
-- }}}
```

### 5. JSON Encoding/Decoding

```lua
-- {{{ json_encode
-- Simple JSON encoder (sufficient for Ollama payloads)
local function json_encode(tbl)
    if type(tbl) ~= "table" then
        if type(tbl) == "string" then
            return '"' .. tbl:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
        end
        return tostring(tbl)
    end

    -- Check if array
    local is_array = #tbl > 0
    local parts = {}

    if is_array then
        for _, v in ipairs(tbl) do
            table.insert(parts, json_encode(v))
        end
        return "[" .. table.concat(parts, ",") .. "]"
    else
        for k, v in pairs(tbl) do
            table.insert(parts, '"' .. k .. '":' .. json_encode(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
end
-- }}}

-- {{{ json_decode
-- Simple JSON decoder using Lua pattern matching
-- Note: For production, consider using a proper JSON library like cjson
local function json_decode(str)
    -- Handle common cases
    local ok, result = pcall(function()
        -- Try to use loadstring for simple cases (NOT safe for untrusted input)
        -- For Ollama responses this is acceptable
        local chunk = loadstring("return " .. str:gsub('null', 'nil'):gsub('true', 'true'):gsub('false', 'false'))
        if chunk then
            return chunk()
        end
    end)

    if ok then return result end

    -- Fallback: extract response field manually
    local response = str:match('"response"%s*:%s*"([^"]*)"')
    if response then
        return { response = response:gsub('\\n', '\n'):gsub('\\"', '"') }
    end

    return nil
end
-- }}}
```

### 6. Triple-Check Consensus

```lua
-- {{{ generate_with_consensus
-- Generate text multiple times and require consensus
--
-- Per Issue 035f patterns: guards against LLM hallucinations by requiring
-- agreement between multiple generation attempts.
--
-- @param prompt string: The input prompt
-- @param options table: Settings including required_agreement (default 2), max_attempts (default 3)
-- @return table: {response, agreement_count, all_responses}
function M.generate_with_consensus(prompt, options)
    options = options or {}
    local required = options.required_agreement or 2
    local attempts = options.max_attempts or 3
    local responses = {}
    local counts = {}

    for i = 1, attempts do
        local response, err = M.generate(prompt, options)
        if response then
            -- Normalize for comparison (trim, lowercase for classification)
            local normalized = response:gsub("^%s+", ""):gsub("%s+$", "")
            if options.normalize_for_comparison then
                normalized = normalized:lower():match("^%w+") or normalized
            end

            responses[i] = response
            counts[normalized] = (counts[normalized] or 0) + 1

            -- Check for early consensus
            if counts[normalized] >= required then
                return {
                    response = response,
                    agreement_count = counts[normalized],
                    all_responses = responses,
                    achieved_consensus = true,
                }
            end
        else
            responses[i] = nil
        end
    end

    -- No consensus: return most common response with warning
    local best_response = nil
    local best_count = 0
    for _, resp in pairs(responses) do
        local normalized = resp:gsub("^%s+", ""):gsub("%s+$", "")
        if counts[normalized] and counts[normalized] > best_count then
            best_count = counts[normalized]
            best_response = resp
        end
    end

    return {
        response = best_response,
        agreement_count = best_count,
        all_responses = responses,
        achieved_consensus = false,
    }
end
-- }}}
```

### 7. Batch Processing with Rate Limiting

```lua
-- {{{ batch_generate
-- Process multiple prompts with rate limiting and progress callback
--
-- @param prompts table: Array of prompts to process
-- @param options table: Settings including rate_limit, on_progress
-- @return table: Array of responses (nil for failed requests)
function M.batch_generate(prompts, options)
    options = options or {}
    local rate_limit = options.rate_limit or 5  -- requests per second
    local delay = 1.0 / rate_limit
    local results = {}

    for i, prompt in ipairs(prompts) do
        -- Progress callback
        if options.on_progress then
            options.on_progress(i, #prompts, prompt)
        end

        -- Generate
        local response, err = M.generate(prompt, options)
        results[i] = response

        -- Rate limiting (sleep before next request, except for last)
        if i < #prompts then
            os.execute(string.format("sleep %.2f", delay))
        end
    end

    return results
end
-- }}}
```

### 8. Response Caching

```lua
-- {{{ get_cached_response
-- Check cache for existing response
local function get_cached_response(cache_key)
    return state.cache[cache_key]
end
-- }}}

-- {{{ set_cached_response
-- Store response in cache
local function set_cached_response(cache_key, response)
    state.cache[cache_key] = response
end
-- }}}

-- {{{ generate_cached
-- Generate with caching support
function M.generate_cached(prompt, options)
    options = options or {}

    -- Generate cache key
    local cache_key = prompt .. ":" .. (options.model or state.model)
    if options.skip_cache then
        -- bypass cache
    else
        local cached = get_cached_response(cache_key)
        if cached then
            return cached, nil, true  -- response, err, from_cache
        end
    end

    local response, err = M.generate(prompt, options)
    if response then
        set_cached_response(cache_key, response)
    end

    return response, err, false
end
-- }}}
```

### 9. Health Check and Status

```lua
-- {{{ is_healthy
-- Check if Ollama server is reachable and model is available
function M.is_healthy()
    if not state.initialized then
        return false, "Not initialized"
    end

    local url = string.format("http://%s:%d/api/tags",
        state.server.host, state.server.port)

    local cmd = string.format("curl -s -o /dev/null -w '%%{http_code}' --max-time 5 '%s'", url)
    local handle = io.popen(cmd)
    local status = handle:read("*a"):gsub("%s+", "")
    handle:close()

    if status == "200" then
        return true, "Server healthy"
    else
        return false, "Server returned HTTP " .. status
    end
end
-- }}}

-- {{{ get_status
-- Return current client status
function M.get_status()
    local healthy, msg = M.is_healthy()
    return {
        initialized = state.initialized,
        server = state.server,
        model = state.model,
        cache_size = count_table_keys(state.cache),
        healthy = healthy,
        health_message = msg,
    }
end
-- }}}
```

---

## CLI Interface

```bash
# Test connectivity
./scripts/ollama-client.lua --test

# Generate single response
./scripts/ollama-client.lua --prompt "Hello, world"

# Generate with specific model
./scripts/ollama-client.lua --model codellama --prompt "Explain this code"

# Test consensus mode
./scripts/ollama-client.lua --consensus --prompt "What color is the sky?"

# Show status
./scripts/ollama-client.lua --status
```

---

## File Locations

- **Script**: `delta-version/scripts/libs/ollama-client.lua`
- **Config Override**: `delta-version/config/ollama.lua` (optional)
- **Test**: `delta-version/tmp/test-ollama-client.lua`

---

## Acceptance Criteria

- [ ] Client initializes with sensible defaults (localhost:11434)
- [ ] Client can use neocities ollama-config if available
- [ ] Simple text generation works reliably
- [ ] Triple-check consensus validates responses
- [ ] Batch processing respects rate limits
- [ ] Response caching prevents redundant API calls
- [ ] Health check accurately reports server status
- [ ] Errors are handled gracefully with informative messages
- [ ] Works with multiple Ollama models (llama3, mistral, codellama)

---

## Technical Notes

### Model Selection

For transcript processing, different models may work better:
- **llama3**: Good general-purpose, balanced quality/speed
- **mistral**: Fast, good for classification tasks
- **codellama**: Better at code-related content

Consider allowing per-task model selection in the configuration.

### Timeout Handling

Ollama can be slow for large prompts. The 120-second timeout in `http_post` may need adjustment for:
- Large transcript sections
- Lower-end hardware
- Complex abstraction transformations

### JSON Library

The simple JSON encoder/decoder is sufficient for Ollama's API, but consider using `luajson` or `cjson` if available for better reliability.

### Error Categories

Distinguish between:
- Network errors (server unreachable)
- API errors (invalid request)
- Timeout errors (request took too long)
- Model errors (model not found)

Each should have specific retry strategies.

---

## Related

- Issue 049a: Uses this client for detail classification
- Issue 049b: Uses this client for abstraction transformation
- Issue 049c: Uses this client for chapter boundary detection
- Issue 035f: Established triple-check pattern
- neocities-modernization: Source of Ollama config patterns
