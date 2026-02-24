# Issue 053d: Ollama Integration for Updates

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: Issue 052 (Ollama Connection Configuration)

---

## Current Behavior

There is no lightweight LLM integration for TODONE's incremental update tasks. Without this:

- Every analysis requires expensive Opus API calls
- Simple reorganization tasks waste resources
- Local-first development is not possible
- Updates are slow and costly

---

## Intended Behavior

Create an Ollama integration layer for lightweight TODONE tasks:

1. **TODO list reorganization** (re-sort by priority)
2. **Quick similarity checks** (yes/no/maybe responses)
3. **Incremental change detection** (what's new since last scan)
4. **Simple text transformation** (format conversion, summaries)

### Use Cases for Ollama

```
┌─────────────────────────────────────────────────────────────────────┐
│  OLLAMA TASKS (cheap, fast, local)                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Re-sort TODO list:                                                 │
│  ─────────────────                                                  │
│  "Given these items and their priority scores, output them          │
│   sorted from highest to lowest priority"                           │
│                                                                     │
│  Quick similarity check:                                            │
│  ──────────────────────                                             │
│  "Is 'task-executor' similar to 'threadpool'?                       │
│   Answer: yes, no, or maybe"                                        │
│                                                                     │
│  Change summary:                                                    │
│  ───────────────                                                    │
│  "Summarize what changed between these two project scans            │
│   in 2-3 sentences"                                                 │
│                                                                     │
│  Format conversion:                                                 │
│  ─────────────────                                                  │
│  "Convert this JSON roadmap to markdown format"                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### NOT For Ollama (Use Opus Instead)

```
┌─────────────────────────────────────────────────────────────────────┐
│  OPUS TASKS (expensive but necessary)                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✗ Initial project analysis                                         │
│  ✗ Complex dependency reasoning                                     │
│  ✗ Library extraction decisions                                     │
│  ✗ Multi-project coordination strategy                              │
│  ✗ Anything requiring deep context understanding                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Ollama Client Library

```lua
-- -- {{{ ollama_client.lua
-- Lightweight Ollama client for TODONE

local json = require("json")
local http = require("socket.http")
local ltn12 = require("ltn12")

local OllamaClient = {}
OllamaClient.__index = OllamaClient

function OllamaClient.new(config)
    local self = setmetatable({}, OllamaClient)
    self.host = config.host or "localhost"
    self.port = config.port or 11434
    self.model = config.model or "llama3"
    self.timeout = config.timeout or 30
    return self
end

function OllamaClient:query(prompt, options)
    options = options or {}

    local request_body = json.encode({
        model = options.model or self.model,
        prompt = prompt,
        stream = false,
        options = {
            temperature = options.temperature or 0.3,
            num_predict = options.max_tokens or 500
        }
    })

    local response_body = {}
    local result, status_code = http.request({
        url = string.format("http://%s:%d/api/generate", self.host, self.port),
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = #request_body
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body)
    })

    if not result or status_code ~= 200 then
        return nil, "Ollama request failed: " .. (status_code or "connection error")
    end

    return json.decode(table.concat(response_body))
end
-- }}}

return OllamaClient
```

### 2. Task-Specific Functions

```lua
-- -- {{{ ollama_tasks.lua
-- High-level task functions using Ollama

local OllamaClient = require("ollama_client")
local client = OllamaClient.new({model = "llama3"})

-- -- {{{ resort_todo_list
local function resort_todo_list(items)
    local prompt = [[
Sort these TODO items by priority (highest first).
Output ONLY the sorted list, one item per line.

Items:
]] .. table.concat(items, "\n")

    local response = client:query(prompt, {temperature = 0.1})
    if not response then return items end  -- Fallback to original

    local sorted = {}
    for line in response.response:gmatch("[^\n]+") do
        line = line:gsub("^%s*%d+%.%s*", "")  -- Remove numbering
        if #line > 0 then
            table.insert(sorted, line)
        end
    end

    return sorted
end
-- }}}

-- -- {{{ quick_similarity_check
local function quick_similarity_check(component1, component2)
    local prompt = string.format([[
Are these two software components functionally similar?

Component A: %s
Component B: %s

Answer with ONLY one word: yes, no, or maybe
]], component1, component2)

    local response = client:query(prompt, {
        temperature = 0.1,
        max_tokens = 10
    })

    if not response then return nil, 0.5 end

    local answer = response.response:lower()
    if answer:match("yes") then
        return true, 0.85
    elseif answer:match("no") then
        return false, 0.85
    else
        return nil, 0.5  -- "maybe" or unclear
    end
end
-- }}}

-- -- {{{ summarize_changes
local function summarize_changes(old_scan, new_scan)
    local prompt = [[
Summarize the changes between these two project scans in 2-3 sentences.
Focus on: new components, removed components, and status changes.

Previous scan:
]] .. json.encode(old_scan) .. [[

New scan:
]] .. json.encode(new_scan)

    local response = client:query(prompt, {
        temperature = 0.3,
        max_tokens = 200
    })

    return response and response.response or "Unable to generate summary"
end
-- }}}

-- -- {{{ convert_to_markdown
local function convert_to_markdown(roadmap_json)
    local prompt = [[
Convert this JSON roadmap to clean markdown format.
Use headers for phases and bullet points for items.

JSON:
]] .. json.encode(roadmap_json)

    local response = client:query(prompt, {
        temperature = 0.2,
        max_tokens = 2000
    })

    return response and response.response or nil
end
-- }}}

return {
    resort_todo_list = resort_todo_list,
    quick_similarity_check = quick_similarity_check,
    summarize_changes = summarize_changes,
    convert_to_markdown = convert_to_markdown
}
```

### 3. Batch Processing for Similarity

```lua
-- -- {{{ batch_similarity_check
-- Batch multiple similarity checks to reduce Ollama calls

local function batch_similarity_check(pairs)
    -- Group into batches of 10
    local BATCH_SIZE = 10
    local results = {}

    for i = 1, #pairs, BATCH_SIZE do
        local batch = {}
        for j = i, math.min(i + BATCH_SIZE - 1, #pairs) do
            table.insert(batch, pairs[j])
        end

        local prompt = [[
For each pair below, answer if they are functionally similar.
Output one line per pair: "A-B: yes" or "A-B: no" or "A-B: maybe"

Pairs:
]]
        for _, pair in ipairs(batch) do
            prompt = prompt .. string.format("%s - %s\n", pair[1], pair[2])
        end

        local response = client:query(prompt, {
            temperature = 0.1,
            max_tokens = #batch * 20
        })

        if response then
            for line in response.response:gmatch("[^\n]+") do
                local a, b, answer = line:match("([^-]+)%-([^:]+):%s*(%w+)")
                if a and b and answer then
                    results[a:gsub("%s+$","") .. "-" .. b:gsub("^%s+","")] = answer:lower()
                end
            end
        end
    end

    return results
end
-- }}}
```

### 4. Connection Health Check

```lua
-- -- {{{ check_ollama_available
local function check_ollama_available()
    local response_body = {}
    local result, status_code = http.request({
        url = string.format("http://%s:%d/api/tags", client.host, client.port),
        method = "GET",
        sink = ltn12.sink.table(response_body)
    })

    if not result or status_code ~= 200 then
        return false, "Ollama not responding"
    end

    local data = json.decode(table.concat(response_body))
    local has_model = false
    for _, model in ipairs(data.models or {}) do
        if model.name:match(client.model) then
            has_model = true
            break
        end
    end

    if not has_model then
        return false, "Model '" .. client.model .. "' not available"
    end

    return true, "Ollama ready"
end
-- }}}
```

---

## Configuration

```lua
-- config/todone-ollama.conf
return {
    host = os.getenv("OLLAMA_HOST") or "localhost",
    port = tonumber(os.getenv("OLLAMA_PORT")) or 11434,
    model = os.getenv("TODONE_LIGHT_MODEL") or "llama3",
    timeout = 30,

    -- Task-specific model overrides
    similarity_model = "llama3",
    summary_model = "llama3",
    format_model = "llama3",

    -- Fallback behavior
    fallback_on_error = true,
    max_retries = 3
}
```

---

## CLI Interface

```bash
# Test Ollama connection
todone-ollama.sh --test

# Run specific task
todone-ollama.sh --resort "item1" "item2" "item3"
todone-ollama.sh --similar "threadpool" "worker-pool"
todone-ollama.sh --summarize old_scan.json new_scan.json

# Configuration
todone-ollama.sh --model=llama3.2
todone-ollama.sh --host=192.168.1.100
```

---

## Acceptance Criteria

- [ ] Ollama client connects successfully
- [ ] Health check validates model availability
- [ ] Resort function produces valid ordering
- [ ] Similarity check returns yes/no/maybe with confidence
- [ ] Batch processing reduces API calls
- [ ] Graceful fallback when Ollama unavailable
- [ ] Configuration via environment variables

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 052: Ollama Connection Configuration
- Issue 035f: Local LLM Integration (shared patterns)
- Issue 053e: Anthropic API (complementary integration)

---

## Notes

Ollama is the workhorse of TODONE's incremental updates. By handling routine tasks locally, we reserve expensive cloud API calls for situations where deep reasoning is truly necessary.

The batch processing for similarity checks is especially important - instead of N separate API calls for N pairs, we can often reduce this to N/10 calls with careful prompt engineering.

Model selection matters: smaller models (llama3) are faster for simple yes/no tasks, while larger models might be needed for nuanced summaries. The configuration allows task-specific model overrides for this purpose.
