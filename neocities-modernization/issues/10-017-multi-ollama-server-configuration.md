# Issue 10-017: Multi-Ollama Server Configuration

**Priority**: Medium
**Phase**: 10 (Developer Experience & Tooling)
**Status**: Open
**Created**: 2026-01-30

---

## Summary

Add support for multiple Ollama server configurations, allowing users to define several servers with different models and switch between them via TUI or CLI.

---

## Current Behavior

Ollama configuration is scattered and implicit:
- `OLLAMA_HOST` environment variable (or default `localhost:11434`)
- Model name passed via CLI flags or hardcoded
- No centralized server configuration

This makes it difficult to:
- Switch between local and remote Ollama instances
- Use different models for different runs
- Share configuration across team members

---

## Intended Behavior

### 1. Config Section for Ollama Servers

Add an `ollama_servers` section to `config.lua`:

```lua
-- {{{ ollama_servers
-- Define available Ollama servers for embedding generation.
-- The pipeline will use the server selected in the TUI or via --ollama flag.
-- At least one server must be defined. First server is the default.
ollama_servers = {
    {
        name = "local",                    -- Label shown in TUI
        description = "Local Ollama instance",
        host = "localhost",
        port = 11434,
        model = "nomic-embed-text",        -- Default embedding model
        -- Optional: alternative models available on this server
        available_models = {
            "nomic-embed-text",
            "mxbai-embed-large",
            "all-minilm"
        }
    },
    {
        name = "gpu-server",
        description = "Remote GPU server for faster embeddings",
        host = "192.168.0.115",
        port = 11434,
        model = "nomic-embed-text",
        available_models = {
            "nomic-embed-text",
            "mxbai-embed-large"
        }
    },
    {
        name = "gpu-server-alt",
        description = "Remote GPU server (alternate port)",
        host = "192.168.0.115",
        port = 10265,
        model = "mxbai-embed-large"
    }
},
-- }}}
```

### 2. TUI Selection in run.sh

Add Ollama server selection to the pipeline configuration menu:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Pipeline Configuration                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Ollama Server:                                                             │
│   (●) local - Local Ollama instance (nomic-embed-text)                       │
│   ( ) gpu-server - Remote GPU server (nomic-embed-text)                      │
│   ( ) gpu-server-alt - Remote GPU server alternate (mxbai-embed-large)       │
│                                                                              │
│   Select stages to run:                                                      │
│   ...                                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Selection behavior:**
- Radio button selection (exactly one must be selected)
- First server in config is selected by default
- Shows name, description, and current model
- Cannot deselect all (minimum one required)

### 3. CLI Flag Override

```bash
# Use specific server by name
./run.sh --ollama gpu-server

# Override model for the selected server
./run.sh --ollama gpu-server --model mxbai-embed-large

# List available servers
./run.sh --list-ollama
```

### 4. Environment Variable Construction

The selected server config constructs the `OLLAMA_HOST` environment variable:

```lua
-- From config
local server = selected_ollama_server
local ollama_host = string.format("http://%s:%d", server.host, server.port)

-- Set environment for child processes
os.execute(string.format("export OLLAMA_HOST='%s'", ollama_host))
```

---

## Files to Update

| File | Changes |
|------|---------|
| `config.lua` | Add `ollama_servers` section |
| `run.sh` | Add TUI selection, `--ollama` flag, server list display |
| `scripts/generate-embeddings.lua` | Read server config, use selected server |
| `src/centroid-generator.lua` | Use selected Ollama server |
| `libs/ollama-client.lua` | Accept server config object (if exists) |
| Any script calling Ollama | Update to use centralized config |

---

## Implementation Steps

### Step 1: Add Config Section

Add `ollama_servers` to `config.lua` with at least one default server.

### Step 2: Create Server Loader

```lua
-- libs/ollama-config.lua
local M = {}

function M.get_servers()
    local config = require("config-loader").load()
    return config.ollama_servers or {
        -- Fallback default
        {name = "local", host = "localhost", port = 11434, model = "nomic-embed-text"}
    }
end

function M.get_server_by_name(name)
    for _, server in ipairs(M.get_servers()) do
        if server.name == name then
            return server
        end
    end
    return nil
end

function M.get_default_server()
    local servers = M.get_servers()
    return servers[1]
end

function M.build_host_url(server)
    return string.format("http://%s:%d", server.host, server.port)
end

return M
```

### Step 3: Update run.sh TUI

Add radio button selection for Ollama servers before stage selection.

### Step 4: Update Embedding Scripts

```lua
-- In generate-embeddings.lua
local ollama_config = require("ollama-config")

-- Get server from CLI arg or use default
local server_name = arg_parser.get("--ollama") or nil
local server = server_name
    and ollama_config.get_server_by_name(server_name)
    or ollama_config.get_default_server()

if not server then
    error("Ollama server not found: " .. (server_name or "(default)"))
end

local ollama_host = ollama_config.build_host_url(server)
local model = arg_parser.get("--model") or server.model

print("Using Ollama server: " .. server.name .. " (" .. ollama_host .. ")")
print("Model: " .. model)
```

### Step 5: Validate Configuration

At pipeline start, verify the selected Ollama server is reachable:

```lua
function M.validate_server(server)
    local url = M.build_host_url(server) .. "/api/tags"
    local handle = io.popen(string.format("curl -s -o /dev/null -w '%%{http_code}' '%s'", url))
    local status = handle:read("*a")
    handle:close()
    return status == "200"
end
```

---

## TUI Implementation Details

### Radio Button Behavior

```lua
-- Menu items for Ollama selection
local ollama_items = {}
for i, server in ipairs(ollama_servers) do
    table.insert(ollama_items, {
        id = "ollama_" .. server.name,
        label = server.name .. " - " .. server.description .. " (" .. server.model .. ")",
        type = "radio",
        group = "ollama",  -- All in same radio group
        selected = (i == 1),  -- First is default
        value = server.name
    })
end

-- Radio group constraint: exactly one selected
-- When user selects one, deselect others in same group
function select_radio(items, selected_id, group)
    for _, item in ipairs(items) do
        if item.group == group then
            item.selected = (item.id == selected_id)
        end
    end
end
```

### Display Format

```
   Ollama Server:
   (●) local - Local Ollama instance (nomic-embed-text)
   ( ) gpu-server - Remote GPU server for faster embeddings (nomic-embed-text)
   ( ) gpu-server-alt - Remote GPU server (mxbai-embed-large)
```

---

## Success Criteria

- [ ] `ollama_servers` config section with name, host, port, model
- [ ] TUI radio button selection for Ollama server
- [ ] First server is default, exactly one must be selected
- [ ] CLI `--ollama NAME` flag to select server
- [ ] CLI `--model NAME` flag to override model
- [ ] CLI `--list-ollama` to show available servers
- [ ] All embedding scripts use selected server config
- [ ] Server validation at pipeline start (reachable check)
- [ ] Graceful error if selected server is unreachable

---

## Related Files

- `config.lua` - Main configuration file
- `run.sh` - Pipeline runner with TUI
- `scripts/generate-embeddings.lua` - Primary embedding generation
- `src/centroid-generator.lua` - Centroid embedding generation
- `issues/completed/1-002-configure-ollama-embedding-service.md` - Original Ollama setup
- `issues/completed/1-005-standardize-ollama-port-configuration.md` - Port standardization

---

## Notes

- The `available_models` field is optional - for future model selection UI
- Consider adding a "test connection" button in TUI
- Server validation should be quick (timeout after 2-3 seconds)
- If validation fails, show warning but allow user to proceed (server might come online)
- Store last-used server in a session file for convenience (optional enhancement)
