# Issue 051g: Module Interconnection Network

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: Medium
**Created**: 2026-02-12
**Parent**: Issue 051 (Git Repository Documentation Generator)
**Dependencies**: Issues 051a-051f

---

## Current Behavior

The documentation generation pipeline (051a-051f) operates as a linear sequence. Each stage produces output files that must be manually passed to subsequent stages. There is no:

1. Unified API for invoking stages programmatically
2. Abstraction layer for tool composition
3. Network of interconnected modules
4. Event system for pipeline orchestration

This limits extensibility and makes it difficult to build higher-level tools on top of the pipeline.

---

## Intended Behavior

Create a module interconnection network that:

1. **Abstracts each stage** as a callable module with defined inputs/outputs
2. **Provides API layer** for Lua and Bash invocation
3. **Enables composition** of stages into custom pipelines
4. **Supports event hooks** for monitoring and extension
5. **Documents interface contracts** for each module

### The Network Concept

From the original request:
> "First abstracted, then implemented, and then networked. These phase demos can use the current state of the project's utilities but they must accomplish or demonstrate the capabilities... In this way, the different phases can feel 'modularized' in systematic [tool/tool-call] abstractions that are easily interconnected by a computer charting an arc."

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Module Interconnection Network                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│    ┌─────────┐      ┌─────────┐      ┌─────────┐                           │
│    │  051a   │─────▶│  051b   │─────▶│  051c   │                           │
│    │ Analyze │      │ Roadmap │      │ Issues  │                           │
│    └────┬────┘      └────┬────┘      └────┬────┘                           │
│         │                │                │                                 │
│         │    ┌───────────┴───────────┐    │                                 │
│         │    │                       │    │                                 │
│         │    │     EVENT BUS         │    │                                 │
│         │    │  (hooks, listeners)   │    │                                 │
│         │    │                       │    │                                 │
│         │    └───────────┬───────────┘    │                                 │
│         │                │                │                                 │
│    ┌────▼────┐      ┌────▼────┐      ┌────▼────┐                           │
│    │  051f   │      │  051d   │      │  051e   │                           │
│    │ Install │      │Complete │      │ Demos   │                           │
│    └─────────┘      └─────────┘      └─────────┘                           │
│                                                                             │
│    ┌─────────────────────────────────────────────────────────────────────┐ │
│    │                          API LAYER                                  │ │
│    │                                                                     │ │
│    │  Lua:   local gen = require("doc-generator")                        │ │
│    │         gen.analyze("/path/to/repo")                                │ │
│    │         gen.roadmap({phases = 4})                                   │ │
│    │                                                                     │ │
│    │  Bash:  doc-gen.sh analyze /path/to/repo                            │ │
│    │         doc-gen.sh roadmap --phases=4                               │ │
│    │                                                                     │ │
│    │  JSON:  {"command": "analyze", "repo": "/path"}                     │ │
│    │                                                                     │ │
│    └─────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Suggested Implementation Steps

### 1. Define Module Interface Contract

```lua
-- -- {{{ Module Interface Specification
-- Each module in the network must implement this interface:
--
-- module.name          - String identifier
-- module.version       - Semver string
-- module.inputs        - Table of input specifications
-- module.outputs       - Table of output specifications
-- module.run(ctx)      - Main execution function
-- module.validate(ctx) - Input validation function
--
-- Context object (ctx):
-- {
--   project_dir = "/path/to/project",
--   output_dir  = "/path/to/output",
--   config      = { ... },
--   state       = { ... },  -- shared state across modules
--   events      = EventBus, -- for emitting/listening to events
-- }
-- }}}

-- -- {{{ Example Module: 051a Analyzer
local analyzer = {
    name = "analyzer",
    version = "0.1.0",

    inputs = {
        { name = "project_dir", type = "path", required = true },
        { name = "llm_enabled", type = "boolean", default = true },
    },

    outputs = {
        { name = "kernel", type = "json", file = "tmp/kernel.json" },
        { name = "goal", type = "json", file = "tmp/goal.json" },
        { name = "vision", type = "markdown", file = "notes/vision.md" },
    },

    validate = function(ctx)
        if not ctx.project_dir or not path_exists(ctx.project_dir) then
            return false, "project_dir is required and must exist"
        end
        return true
    end,

    run = function(ctx)
        -- Implementation from 051a
        local kernel = extract_kernel(ctx.project_dir)
        local goal = extract_goal(ctx.project_dir)

        -- Store in context state for other modules
        ctx.state.kernel = kernel
        ctx.state.goal = goal

        -- Emit event
        ctx.events:emit("analyzer:complete", { kernel = kernel, goal = goal })

        return { success = true, outputs = { kernel = kernel, goal = goal } }
    end
}
-- }}}
```

### 2. Create Event Bus

```lua
-- -- {{{ Event Bus Implementation
local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    return setmetatable({
        listeners = {},
        history = {},
    }, EventBus)
end

function EventBus:on(event, callback)
    self.listeners[event] = self.listeners[event] or {}
    table.insert(self.listeners[event], callback)
    return self -- chainable
end

function EventBus:off(event, callback)
    if not self.listeners[event] then return self end
    for i, cb in ipairs(self.listeners[event]) do
        if cb == callback then
            table.remove(self.listeners[event], i)
            break
        end
    end
    return self
end

function EventBus:emit(event, data)
    -- Record in history
    table.insert(self.history, {
        event = event,
        data = data,
        timestamp = os.time(),
    })

    -- Notify listeners
    if self.listeners[event] then
        for _, callback in ipairs(self.listeners[event]) do
            local ok, err = pcall(callback, data)
            if not ok then
                io.stderr:write(string.format(
                    "[EventBus] Error in listener for %s: %s\n",
                    event, err
                ))
            end
        end
    end

    return self
end

function EventBus:get_history()
    return self.history
end
-- }}}
```

### 3. Create Pipeline Orchestrator

```lua
-- -- {{{ Pipeline Orchestrator
local Pipeline = {}
Pipeline.__index = Pipeline

function Pipeline.new(config)
    local self = setmetatable({}, Pipeline)

    self.modules = {}
    self.config = config or {}
    self.events = EventBus.new()
    self.state = {}

    return self
end

function Pipeline:register(module)
    self.modules[module.name] = module
    return self
end

function Pipeline:run_stage(name, inputs)
    local module = self.modules[name]
    if not module then
        return nil, "Unknown module: " .. name
    end

    -- Build context
    local ctx = {
        project_dir = self.config.project_dir,
        output_dir = self.config.output_dir,
        config = self.config,
        state = self.state,
        events = self.events,
    }

    -- Merge inputs
    for k, v in pairs(inputs or {}) do
        ctx[k] = v
    end

    -- Validate
    local valid, err = module.validate(ctx)
    if not valid then
        return nil, "Validation failed: " .. (err or "unknown")
    end

    -- Emit start event
    self.events:emit("stage:start", { name = name, ctx = ctx })

    -- Run
    local result = module.run(ctx)

    -- Emit complete event
    self.events:emit("stage:complete", { name = name, result = result })

    return result
end

function Pipeline:run_full(inputs)
    local stages = { "analyzer", "roadmap", "issues", "completion", "demos", "install" }
    local results = {}

    for _, stage in ipairs(stages) do
        local result, err = self:run_stage(stage, inputs)
        if not result then
            return nil, string.format("Stage %s failed: %s", stage, err)
        end
        results[stage] = result
    end

    return results
end
-- }}}
```

### 4. Create Bash CLI Wrapper

```bash
#!/bin/bash
# =============================================================================
# doc-gen.sh - CLI interface to documentation generator pipeline
#
# Usage:
#   doc-gen.sh <command> [options] <project_dir>
#
# Commands:
#   analyze     Run initial commit analysis (051a)
#   roadmap     Generate development roadmap (051b)
#   issues      Generate issue files (051c)
#   completion  Detect completion status (051d)
#   demos       Generate phase demos (051e)
#   install     Generate install script (051f)
#   full        Run complete pipeline
#
# Options:
#   --output-dir=PATH   Output directory (default: project_dir)
#   --llm-model=MODEL   LLM model for AI assistance
#   --no-llm            Disable LLM, use heuristics only
#   --dry-run           Preview without writing files
#   --json              Output results as JSON
# =============================================================================

set -euo pipefail

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LUA_PATH="$DIR/libs/?.lua;$DIR/libs/?/init.lua;$LUA_PATH"
export LUA_PATH

# -- {{{ Parse arguments
COMMAND=""
PROJECT_DIR=""
OUTPUT_DIR=""
LLM_MODEL="llama3"
LLM_ENABLED=true
DRY_RUN=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --llm-model=*)
            LLM_MODEL="${1#*=}"
            shift
            ;;
        --no-llm)
            LLM_ENABLED=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        analyze|roadmap|issues|completion|demos|install|full)
            COMMAND="$1"
            shift
            ;;
        *)
            if [[ -z "$PROJECT_DIR" ]]; then
                PROJECT_DIR="$1"
            fi
            shift
            ;;
    esac
done
# }}}

# -- {{{ Validate
if [[ -z "$COMMAND" ]]; then
    echo "Error: No command specified" >&2
    echo "Usage: doc-gen.sh <command> [options] <project_dir>" >&2
    exit 1
fi

if [[ -z "$PROJECT_DIR" ]]; then
    echo "Error: No project directory specified" >&2
    exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR}"
# }}}

# -- {{{ Run Lua pipeline
run_lua_pipeline() {
    lua "$DIR/libs/doc-generator/cli.lua" \
        --command="$COMMAND" \
        --project-dir="$PROJECT_DIR" \
        --output-dir="$OUTPUT_DIR" \
        --llm-model="$LLM_MODEL" \
        --llm-enabled="$LLM_ENABLED" \
        --dry-run="$DRY_RUN" \
        --json-output="$JSON_OUTPUT"
}
# }}}

# -- {{{ Main
main() {
    case "$COMMAND" in
        analyze|roadmap|issues|completion|demos|install)
            run_lua_pipeline
            ;;
        full)
            # Run all stages in sequence
            for stage in analyze roadmap issues completion demos install; do
                COMMAND="$stage"
                run_lua_pipeline || exit 1
            done
            ;;
    esac
}

main
# }}}
```

### 5. Create JSON API Layer

```lua
-- -- {{{ JSON API for external integration
-- Allows invoking the pipeline via JSON requests
-- Useful for IDE plugins, web interfaces, etc.

local json = require("cjson")

local JsonApi = {}

function JsonApi.handle_request(request_json)
    local ok, request = pcall(json.decode, request_json)
    if not ok then
        return json.encode({
            success = false,
            error = "Invalid JSON: " .. request,
        })
    end

    local command = request.command
    local project_dir = request.project_dir
    local options = request.options or {}

    if not command then
        return json.encode({
            success = false,
            error = "Missing required field: command",
        })
    end

    if not project_dir then
        return json.encode({
            success = false,
            error = "Missing required field: project_dir",
        })
    end

    -- Create pipeline
    local pipeline = Pipeline.new({
        project_dir = project_dir,
        output_dir = options.output_dir or project_dir,
        llm_model = options.llm_model or "llama3",
        llm_enabled = options.llm_enabled ~= false,
    })

    -- Register all modules
    pipeline:register(require("doc-generator.analyzer"))
    pipeline:register(require("doc-generator.roadmap"))
    pipeline:register(require("doc-generator.issues"))
    pipeline:register(require("doc-generator.completion"))
    pipeline:register(require("doc-generator.demos"))
    pipeline:register(require("doc-generator.install"))

    -- Run requested command
    local result, err
    if command == "full" then
        result, err = pipeline:run_full()
    else
        result, err = pipeline:run_stage(command)
    end

    if not result then
        return json.encode({
            success = false,
            error = err,
        })
    end

    return json.encode({
        success = true,
        result = result,
        events = pipeline.events:get_history(),
    })
end
-- }}}
```

### 6. Create Info Files for Each Module

```bash
# -- {{{ generate_module_info
# Creates {module}.info.md files documenting each module's interface
generate_module_info() {
    local module_name="$1"
    local output_dir="$2"

    local info_file="$output_dir/libs/doc-generator/${module_name}.info.md"
    mkdir -p "$(dirname "$info_file")"

    # This would be generated from the Lua module definition
    # For now, template:
    cat << EOF > "$info_file"
# Module: $module_name

## Interface

### Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| project_dir | path | yes | - | Path to git repository |
| output_dir | path | no | project_dir | Output directory |

### Outputs

| Name | Type | File | Description |
|------|------|------|-------------|
| (varies by module) | | | |

### Events Emitted

- \`${module_name}:start\` - Emitted when module begins
- \`${module_name}:complete\` - Emitted when module finishes
- \`${module_name}:error\` - Emitted on error

## Usage

### Lua

\`\`\`lua
local mod = require("doc-generator.$module_name")
local result = mod.run(ctx)
\`\`\`

### Bash

\`\`\`bash
doc-gen.sh $module_name /path/to/project
\`\`\`

### JSON API

\`\`\`json
{
  "command": "$module_name",
  "project_dir": "/path/to/project"
}
\`\`\`
EOF
}
# }}}
```

### 7. Create Integration Test

```lua
-- -- {{{ Integration test for module network
-- tests/test-network.lua

local Pipeline = require("doc-generator.pipeline")
local EventBus = require("doc-generator.events")

describe("Module Network", function()

    it("should register modules", function()
        local pipeline = Pipeline.new({
            project_dir = "/tmp/test-project",
        })

        pipeline:register({
            name = "test",
            version = "1.0.0",
            inputs = {},
            outputs = {},
            validate = function() return true end,
            run = function() return { success = true } end,
        })

        assert.is_not_nil(pipeline.modules.test)
    end)

    it("should emit events during pipeline run", function()
        local pipeline = Pipeline.new({
            project_dir = "/tmp/test-project",
        })

        local events_received = {}
        pipeline.events:on("stage:start", function(data)
            table.insert(events_received, "start:" .. data.name)
        end)
        pipeline.events:on("stage:complete", function(data)
            table.insert(events_received, "complete:" .. data.name)
        end)

        pipeline:register({
            name = "test",
            version = "1.0.0",
            inputs = {},
            outputs = {},
            validate = function() return true end,
            run = function() return { success = true } end,
        })

        pipeline:run_stage("test")

        assert.are.equal(2, #events_received)
        assert.are.equal("start:test", events_received[1])
        assert.are.equal("complete:test", events_received[2])
    end)

    it("should share state between modules", function()
        local pipeline = Pipeline.new({
            project_dir = "/tmp/test-project",
        })

        pipeline:register({
            name = "producer",
            version = "1.0.0",
            inputs = {},
            outputs = {},
            validate = function() return true end,
            run = function(ctx)
                ctx.state.shared_value = 42
                return { success = true }
            end,
        })

        pipeline:register({
            name = "consumer",
            version = "1.0.0",
            inputs = {},
            outputs = {},
            validate = function() return true end,
            run = function(ctx)
                return { success = true, value = ctx.state.shared_value }
            end,
        })

        pipeline:run_stage("producer")
        local result = pipeline:run_stage("consumer")

        assert.are.equal(42, result.value)
    end)

end)
-- }}}
```

---

## Directory Structure

```
libs/doc-generator/
├── init.lua              # Main module loader
├── pipeline.lua          # Pipeline orchestrator
├── events.lua            # Event bus implementation
├── analyzer.lua          # 051a module
├── roadmap.lua           # 051b module
├── issues.lua            # 051c module
├── completion.lua        # 051d module
├── demos.lua             # 051e module
├── install.lua           # 051f module
├── json-api.lua          # JSON API layer
├── analyzer.info.md      # Interface documentation
├── roadmap.info.md
├── issues.info.md
├── completion.info.md
├── demos.info.md
└── install.info.md

scripts/
└── doc-gen.sh            # Bash CLI wrapper
```

---

## Acceptance Criteria

- [ ] Each stage (051a-051f) wrapped as a module with defined interface
- [ ] Pipeline orchestrator can run stages individually or in sequence
- [ ] Event bus allows listening to stage events
- [ ] State sharing between modules works correctly
- [ ] Bash CLI provides access to all stages
- [ ] JSON API enables external integration
- [ ] Module info files document each interface
- [ ] Integration tests verify network functionality

---

## Technical Notes

### Design Principles

1. **Single Responsibility**: Each module does one thing well
2. **Explicit Dependencies**: Inputs/outputs clearly defined
3. **Event-Driven**: Loosely coupled through events
4. **State Isolation**: Shared state is explicit and controlled
5. **Multiple Interfaces**: Lua, Bash, and JSON APIs

### Performance Considerations

- Modules can be loaded lazily
- Events are synchronous by default (async optional)
- State is in-memory (persistent state via files)

### Extensibility Points

1. **Custom Modules**: Register new stages
2. **Event Hooks**: Add logging, metrics, validation
3. **State Transformers**: Modify data between stages
4. **Custom APIs**: Add GraphQL, gRPC, etc.

---

## Metadata

- **Priority**: Medium
- **Complexity**: High
- **Dependencies**: Issues 051a-051f
- **Blocks**: None (this is the final integration layer)
