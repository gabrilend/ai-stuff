# Issue 040b: Build API Layer for Project/Script Integration

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: High
- **Type**: Implementation
- **Dependencies**: 040a (Event Taxonomy)
- **Blocks**: 040f (Interactive Interface)

## Current Behavior
Projects and scripts have no programmatic way to register conventions, propose guidelines, or query the existing CLAUDE.md content. Any integration requires manual editing.

## Intended Behavior
Create an API layer that allows:
1. Scripts to propose new guidelines
2. Projects to register their conventions
3. Tools to query existing guidelines
4. Automation to check for conflicts before proposing

## API Architecture

### Communication Method: Unix Domain Socket + File-based Fallback

Primary: `~/.claude/claudemd.sock` (Unix socket for real-time communication)
Fallback: `~/.claude/api/requests/` (file-based for async/batch operations)

```
┌──────────────────┐     ┌──────────────────┐
│   Lua Client     │     │   Bash Client    │
│  (require lib)   │     │  (CLI wrapper)   │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────┐
│              API Gateway                     │
│  (Socket listener + File watcher)           │
└─────────────────────┬───────────────────────┘
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │ propose │  │  query  │  │ check   │
    │ handler │  │ handler │  │ handler │
    └─────────┘  └─────────┘  └─────────┘
```

## API Endpoints

### 1. PROPOSE - Register a new guideline

**Request**:
```lua
{
    action = "propose",
    content = "All database queries should use prepared statements",
    category = "security",          -- Optional: auto-categorize if omitted
    confidence = "suggested",       -- suggested | experimental | established
    source = "security-audit.lua",  -- Script/tool identifier
    project = "delta-version",      -- Project context (optional)
    reasoning = "Found 3 SQL injection vulnerabilities",
    tags = {"sql", "security", "best-practice"}  -- Optional
}
```

**Response**:
```lua
{
    status = "accepted",
    proposal_id = "prop_20251229_001",
    conflicts = {},                 -- Empty if no conflicts
    similar = {"prop_20251215_042"} -- Similar existing proposals
}
```

### 2. QUERY - Search existing guidelines

**Request**:
```lua
{
    action = "query",
    category = "coding-style",      -- Filter by category
    contains = "vimfold",           -- Text search
    tags = {"lua"},                 -- Tag filter
    status = "established",         -- Filter by confidence level
    limit = 10                      -- Max results
}
```

**Response**:
```lua
{
    status = "success",
    count = 2,
    guidelines = {
        {
            id = "guide_001",
            content = "All functions should use vimfolds",
            category = "coding-style",
            confidence = "established",
            added = 1735000000,
            source = "user"
        },
        -- ...
    }
}
```

### 3. CHECK - Validate before proposing

**Request**:
```lua
{
    action = "check",
    content = "Use 4 spaces for indentation"
}
```

**Response**:
```lua
{
    status = "conflict",
    conflicts = {
        {
            id = "guide_042",
            content = "Use tabs for indentation",
            severity = "direct",    -- direct | partial | semantic
            resolution = "requires_human"
        }
    },
    suggestions = {
        "Consider scoping to specific file types",
        "Existing guideline may be outdated"
    }
}
```

### 4. STATUS - Check proposal status

**Request**:
```lua
{
    action = "status",
    proposal_id = "prop_20251229_001"
}
```

**Response**:
```lua
{
    status = "pending",
    created = 1735432800,
    reviewed = false,
    position_in_queue = 3
}
```

### 5. LIST - Get pending proposals

**Request**:
```lua
{
    action = "list",
    filter = "pending",  -- pending | approved | rejected | all
    limit = 20
}
```

## Client Libraries

### Lua Client (`libs/claudemd-client.lua`)

```lua
-- {{{ claudemd client library
-- Provides API access to the dynamic CLAUDE.md revision system.
-- Communicates via Unix socket or file-based fallback.

local claudemd = {}

local DIR = os.getenv("CLAUDEMD_DIR") or os.getenv("HOME") .. "/.claude"

-- {{{ local function send_request
local function send_request(request)
    -- Try socket first, fall back to file-based
    local socket_path = DIR .. "/claudemd.sock"
    local sock = require("socket.unix")()

    if sock:connect(socket_path) then
        sock:send(json.encode(request) .. "\n")
        local response = sock:receive("*l")
        sock:close()
        return json.decode(response)
    else
        -- File-based fallback
        local req_id = os.time() .. "_" .. math.random(10000)
        local req_file = DIR .. "/api/requests/" .. req_id .. ".json"
        local resp_file = DIR .. "/api/responses/" .. req_id .. ".json"

        write_file(req_file, json.encode(request))

        -- Poll for response (with timeout)
        for i = 1, 50 do
            if file_exists(resp_file) then
                local response = json.decode(read_file(resp_file))
                os.remove(resp_file)
                return response
            end
            os.execute("sleep 0.1")
        end

        return {status = "timeout", error = "No response within 5 seconds"}
    end
end
-- }}}

-- {{{ function claudemd.propose
function claudemd.propose(opts)
    return send_request({
        action = "propose",
        content = opts.content,
        category = opts.category,
        confidence = opts.confidence or "suggested",
        source = opts.source or "unknown",
        project = opts.project,
        reasoning = opts.reasoning,
        tags = opts.tags
    })
end
-- }}}

-- {{{ function claudemd.query
function claudemd.query(opts)
    return send_request({
        action = "query",
        category = opts.category,
        contains = opts.contains,
        tags = opts.tags,
        status = opts.status,
        limit = opts.limit or 100
    })
end
-- }}}

-- {{{ function claudemd.check_conflicts
function claudemd.check_conflicts(opts)
    return send_request({
        action = "check",
        content = opts.content
    })
end
-- }}}

return claudemd
-- }}}
```

### Bash CLI Wrapper (`scripts/claudemd`)

```bash
#!/bin/bash
# claudemd - CLI interface for CLAUDE.md revision API
# Wraps the Lua client for shell script access.

DIR="${CLAUDEMD_DIR:-$HOME/.claude}"
LUA_CLIENT="$DIR/libs/claudemd-client.lua"

case "$1" in
    propose)
        lua -e "
            local claudemd = dofile('$LUA_CLIENT')
            local result = claudemd.propose({
                content = '$2',
                source = '$(basename $0)',
                reasoning = '$3'
            })
            print(result.status, result.proposal_id or result.error)
        "
        ;;
    query)
        lua -e "
            local claudemd = dofile('$LUA_CLIENT')
            local result = claudemd.query({contains = '$2'})
            for _, g in ipairs(result.guidelines or {}) do
                print(g.content)
            end
        "
        ;;
    check)
        lua -e "
            local claudemd = dofile('$LUA_CLIENT')
            local result = claudemd.check_conflicts({content = '$2'})
            if result.status == 'conflict' then
                print('CONFLICT:', result.conflicts[1].content)
            else
                print('OK: No conflicts')
            end
        "
        ;;
    *)
        echo "Usage: claudemd {propose|query|check} [args]"
        ;;
esac
```

## API Server Implementation

### Main Server Loop (`src/api-server.lua`)

```lua
-- {{{ API Server for CLAUDE.md revision system
-- Listens on Unix socket and processes API requests.

local DIR = os.getenv("CLAUDEMD_DIR") or os.getenv("HOME") .. "/.claude"
local socket = require("socket")
local unix = require("socket.unix")

-- {{{ local function create_server
local function create_server()
    local server = unix()
    local socket_path = DIR .. "/claudemd.sock"

    -- Remove stale socket
    os.remove(socket_path)

    server:bind(socket_path)
    server:listen(5)

    -- Set permissions
    os.execute("chmod 600 " .. socket_path)

    return server
end
-- }}}

-- {{{ local function handle_request
local function handle_request(request)
    local handlers = {
        propose = require("handlers.propose"),
        query = require("handlers.query"),
        check = require("handlers.check"),
        status = require("handlers.status"),
        list = require("handlers.list")
    }

    local handler = handlers[request.action]
    if handler then
        return handler(request)
    else
        return {status = "error", error = "Unknown action: " .. tostring(request.action)}
    end
end
-- }}}

-- Main loop
local server = create_server()
print("CLAUDE.md API server listening on " .. DIR .. "/claudemd.sock")

while true do
    local client = server:accept()
    if client then
        local line = client:receive("*l")
        if line then
            local ok, request = pcall(json.decode, line)
            if ok then
                local response = handle_request(request)
                client:send(json.encode(response) .. "\n")
            else
                client:send('{"status":"error","error":"Invalid JSON"}\n')
            end
        end
        client:close()
    end
end
-- }}}
```

## Suggested Implementation Steps

1. **Create directory structure**
   ```
   ~/.claude/
   ├── api/
   │   ├── requests/     # File-based request queue
   │   └── responses/    # File-based response queue
   ├── libs/
   │   └── claudemd-client.lua
   └── src/
       ├── api-server.lua
       └── handlers/
           ├── propose.lua
           ├── query.lua
           ├── check.lua
           ├── status.lua
           └── list.lua
   ```

2. **Implement request handlers** (one per endpoint)

3. **Build Lua client library** with socket and file fallback

4. **Create Bash CLI wrapper** for shell integration

5. **Add startup script** for API server daemon

6. **Write integration tests** for each endpoint

## Security Considerations

- Socket permissions: 600 (owner only)
- Validate all input before processing
- Rate limiting for propose/check endpoints
- Source attribution required for all proposals
- Log all API access for audit

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040a](./040a-design-event-taxonomy.md) - Event types this API handles

## Notes
- Socket approach preferred for responsiveness
- File-based fallback ensures batch operations work
- Consider adding authentication for multi-user systems
