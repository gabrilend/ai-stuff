# Issue 053e: Anthropic API with Ollama-Style Output

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: None

---

## Current Behavior

The Anthropic API returns responses in a different format than Ollama. This means:

- Downstream code must handle two different response formats
- Switching between backends requires code changes
- No unified interface for LLM operations
- Difficult to compare outputs or fall back between providers

---

## Intended Behavior

Create an Anthropic API wrapper that:

1. **Calls Claude Opus 4.5** for heavy analysis tasks
2. **Returns Ollama-compatible JSON** format
3. **Provides unified interface** identical to Ollama client
4. **Enables seamless backend switching** without downstream changes

### The Key Insight

```
┌─────────────────────────────────────────────────────────────────────┐
│                    UNIFIED LLM INTERFACE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Downstream Code:                                                   │
│  ────────────────                                                   │
│  local response = llm:query(prompt)                                 │
│  print(response.response)  -- Same field regardless of backend     │
│  print(response.eval_count)  -- Token usage in same format         │
│                                                                     │
│  Backend could be:                                                  │
│  - Ollama (local, cheap, fast)                                     │
│  - Anthropic (cloud, expensive, powerful)                          │
│  - Future: OpenAI, Google, local fine-tuned models                 │
│                                                                     │
│  Caller doesn't know, doesn't care.                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Ollama Response Format (Target)

```json
{
  "model": "llama3",
  "created_at": "2026-02-23T12:00:00Z",
  "response": "The analysis shows...",
  "done": true,
  "context": [1, 2, 3, ...],
  "total_duration": 5000000000,
  "load_duration": 1000000000,
  "prompt_eval_count": 100,
  "prompt_eval_duration": 2000000000,
  "eval_count": 200,
  "eval_duration": 2000000000
}
```

### Anthropic Response Format (Source)

```json
{
  "id": "msg_01XFDUDYJgAACzvnptvVoYEL",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "The analysis shows..."
    }
  ],
  "model": "claude-opus-4-5-20251101",
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 100,
    "output_tokens": 200
  }
}
```

---

## Suggested Implementation Steps

### 1. Anthropic Client with Ollama Wrapper

```lua
-- -- {{{ anthropic_ollama_client.lua
-- Anthropic API client that returns Ollama-compatible responses

local json = require("json")
local https = require("ssl.https")
local ltn12 = require("ltn12")

local AnthropicClient = {}
AnthropicClient.__index = AnthropicClient

function AnthropicClient.new(config)
    local self = setmetatable({}, AnthropicClient)
    self.api_key = config.api_key or os.getenv("ANTHROPIC_API_KEY")
    self.model = config.model or "claude-opus-4-5-20251101"
    self.timeout = config.timeout or 120
    self.max_tokens = config.max_tokens or 4000

    if not self.api_key then
        error("ANTHROPIC_API_KEY not set")
    end

    return self
end

function AnthropicClient:raw_query(prompt, options)
    options = options or {}

    local request_body = json.encode({
        model = options.model or self.model,
        max_tokens = options.max_tokens or self.max_tokens,
        messages = {
            {role = "user", content = prompt}
        },
        temperature = options.temperature or 0.3
    })

    local response_body = {}
    local start_time = os.clock()

    local result, status_code = https.request({
        url = "https://api.anthropic.com/v1/messages",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = self.api_key,
            ["anthropic-version"] = "2023-06-01",
            ["Content-Length"] = #request_body
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),
        timeout = self.timeout
    })

    local elapsed_time = os.clock() - start_time

    if not result or status_code ~= 200 then
        return nil, "Anthropic request failed: " .. (status_code or "connection error")
    end

    local anthropic_response = json.decode(table.concat(response_body))
    return anthropic_response, elapsed_time
end

-- The key function: convert Anthropic response to Ollama format
function AnthropicClient:query(prompt, options)
    local anthropic_response, elapsed_time = self:raw_query(prompt, options)
    if not anthropic_response then
        return nil, elapsed_time  -- elapsed_time contains error message
    end

    return self:wrap_as_ollama(anthropic_response, elapsed_time, options)
end

function AnthropicClient:wrap_as_ollama(anthropic_response, elapsed_time, options)
    local response_text = ""
    if anthropic_response.content and #anthropic_response.content > 0 then
        response_text = anthropic_response.content[1].text or ""
    end

    local input_tokens = anthropic_response.usage and anthropic_response.usage.input_tokens or 0
    local output_tokens = anthropic_response.usage and anthropic_response.usage.output_tokens or 0

    -- Convert elapsed seconds to nanoseconds (Ollama format)
    local duration_ns = math.floor(elapsed_time * 1e9)

    return {
        -- Core response fields (Ollama compatible)
        model = anthropic_response.model or self.model,
        created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        response = response_text,
        done = true,

        -- Context (Anthropic doesn't use rolling context like Ollama)
        context = {},

        -- Timing (estimated based on token counts)
        total_duration = duration_ns,
        load_duration = 0,  -- Not applicable for API
        prompt_eval_count = input_tokens,
        prompt_eval_duration = math.floor(duration_ns * 0.3),  -- Estimate
        eval_count = output_tokens,
        eval_duration = math.floor(duration_ns * 0.7),  -- Estimate

        -- Anthropic-specific fields (preserved for debugging)
        _anthropic = {
            id = anthropic_response.id,
            stop_reason = anthropic_response.stop_reason,
            type = anthropic_response.type
        }
    }
end
-- }}}

return AnthropicClient
```

### 2. Unified LLM Interface

```lua
-- -- {{{ unified_llm.lua
-- Unified interface that can use either Ollama or Anthropic

local OllamaClient = require("ollama_client")
local AnthropicClient = require("anthropic_ollama_client")

local UnifiedLLM = {}
UnifiedLLM.__index = UnifiedLLM

function UnifiedLLM.new(config)
    local self = setmetatable({}, UnifiedLLM)

    self.light_client = OllamaClient.new({
        model = config.light_model or "llama3"
    })

    self.heavy_client = AnthropicClient.new({
        model = config.heavy_model or "claude-opus-4-5-20251101",
        api_key = config.anthropic_api_key
    })

    self.default_backend = config.default_backend or "light"

    return self
end

function UnifiedLLM:query(prompt, options)
    options = options or {}
    local backend = options.backend or self.default_backend

    if backend == "heavy" or backend == "anthropic" or backend == "opus" then
        return self.heavy_client:query(prompt, options)
    else
        return self.light_client:query(prompt, options)
    end
end

-- Convenience methods
function UnifiedLLM:quick_query(prompt, options)
    options = options or {}
    options.backend = "light"
    return self:query(prompt, options)
end

function UnifiedLLM:deep_query(prompt, options)
    options = options or {}
    options.backend = "heavy"
    return self:query(prompt, options)
end

-- Auto-select based on task complexity
function UnifiedLLM:smart_query(prompt, options)
    options = options or {}

    -- Heuristics for backend selection
    local prompt_length = #prompt
    local needs_heavy = false

    -- Long prompts likely need better reasoning
    if prompt_length > 2000 then needs_heavy = true end

    -- Certain keywords suggest complex tasks
    local complex_keywords = {"analyze", "compare", "evaluate", "reason", "explain why"}
    for _, keyword in ipairs(complex_keywords) do
        if prompt:lower():match(keyword) then
            needs_heavy = true
            break
        end
    end

    -- Allow override
    if options.force_light then needs_heavy = false end
    if options.force_heavy then needs_heavy = true end

    options.backend = needs_heavy and "heavy" or "light"
    return self:query(prompt, options)
end
-- }}}

return UnifiedLLM
```

### 3. Response Validation

```lua
-- -- {{{ validate_ollama_format
local function validate_ollama_format(response)
    local required_fields = {"model", "response", "done"}
    local optional_fields = {"created_at", "context", "total_duration",
                            "load_duration", "prompt_eval_count", "eval_count"}

    for _, field in ipairs(required_fields) do
        if response[field] == nil then
            return false, "Missing required field: " .. field
        end
    end

    if type(response.response) ~= "string" then
        return false, "response field must be string"
    end

    if type(response.done) ~= "boolean" then
        return false, "done field must be boolean"
    end

    return true, "Valid Ollama format"
end
-- }}}
```

### 4. Cost Tracking

```lua
-- -- {{{ cost_tracker.lua
-- Track API costs for Anthropic calls

local CostTracker = {}
CostTracker.__index = CostTracker

-- Pricing as of 2026-02 (per million tokens)
local PRICING = {
    ["claude-opus-4-5-20251101"] = {input = 15.0, output = 75.0},
    ["claude-sonnet-4-20250514"] = {input = 3.0, output = 15.0}
}

function CostTracker.new()
    local self = setmetatable({}, CostTracker)
    self.total_input_tokens = 0
    self.total_output_tokens = 0
    self.total_cost = 0
    self.calls = {}
    return self
end

function CostTracker:record(response, model)
    model = model or "claude-opus-4-5-20251101"
    local pricing = PRICING[model] or PRICING["claude-opus-4-5-20251101"]

    local input_tokens = response.prompt_eval_count or 0
    local output_tokens = response.eval_count or 0

    local input_cost = (input_tokens / 1000000) * pricing.input
    local output_cost = (output_tokens / 1000000) * pricing.output
    local total_cost = input_cost + output_cost

    self.total_input_tokens = self.total_input_tokens + input_tokens
    self.total_output_tokens = self.total_output_tokens + output_tokens
    self.total_cost = self.total_cost + total_cost

    table.insert(self.calls, {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        model = model,
        input_tokens = input_tokens,
        output_tokens = output_tokens,
        cost = total_cost
    })

    return total_cost
end

function CostTracker:summary()
    return {
        total_calls = #self.calls,
        total_input_tokens = self.total_input_tokens,
        total_output_tokens = self.total_output_tokens,
        total_cost = string.format("$%.4f", self.total_cost)
    }
end
-- }}}

return CostTracker
```

---

## Configuration

```lua
-- config/todone-anthropic.conf
return {
    api_key = os.getenv("ANTHROPIC_API_KEY"),
    model = "claude-opus-4-5-20251101",
    max_tokens = 4000,
    timeout = 120,

    -- Cost controls
    max_cost_per_run = 1.00,  -- USD
    warn_on_cost = 0.50,

    -- Caching (avoid redundant API calls)
    cache_responses = true,
    cache_ttl = 86400  -- 24 hours
}
```

---

## CLI Interface

```bash
# Test Anthropic connection
todone-anthropic.sh --test

# Query with specific backend
todone-llm.sh --backend=opus "Analyze these 24 projects..."
todone-llm.sh --backend=ollama "Sort this list..."

# Auto-select backend
todone-llm.sh --smart "Complex analysis task..."

# Cost tracking
todone-anthropic.sh --show-costs
todone-anthropic.sh --reset-costs
```

---

## Acceptance Criteria

- [ ] Anthropic client successfully calls API
- [ ] Response wrapped in valid Ollama format
- [ ] Unified interface works with both backends
- [ ] Smart query selects appropriate backend
- [ ] Cost tracking accurate for Anthropic calls
- [ ] Cached responses avoid redundant API calls
- [ ] Graceful error handling for API failures

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 053d: Ollama Integration (complementary)
- Issue 035f: Local LLM Integration (shared patterns)

---

## Notes

The Ollama-compatible wrapper is the linchpin of TODONE's dual-LLM architecture. By standardizing on a single response format, we gain:

1. **Code simplicity**: Downstream code doesn't branch on backend type
2. **Easy testing**: Mock either backend with the same response shape
3. **Future-proofing**: Add new backends (OpenAI, Gemini) with just a new wrapper
4. **Debugging**: Compare outputs side-by-side in the same format

The cost tracking is critical for responsible API usage. Opus calls are expensive (~$0.09 per 1K output tokens), so visibility into spending prevents surprise bills.

The "smart query" heuristics are intentionally simple. Over time, we may want to train a classifier to predict when heavy analysis is truly needed, but for now, keyword matching and prompt length are sufficient proxies.
