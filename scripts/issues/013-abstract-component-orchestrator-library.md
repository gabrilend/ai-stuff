# 013: Abstract Component Orchestrator Library

## Current Behavior

Component lifecycle management is implemented in `handheld-office/scripts/orchestrator.lua`. This includes:
- Component registration with metadata (binary path, port, status)
- State persistence to files
- Logging with timestamps
- Build state tracking
- Start/stop/status operations

This pattern is useful for any multi-component system but is project-specific.

## Intended Behavior

A reusable library `libs/component-orchestrator.lua` that provides:
- `orchestrator.register(name, config)` - Register component
- `orchestrator.start(name)` / `orchestrator.start_all()` - Start components
- `orchestrator.stop(name)` / `orchestrator.stop_all()` - Stop components
- `orchestrator.status(name)` / `orchestrator.status_all()` - Check status
- `orchestrator.health_check(name)` - Health verification
- State persistence and recovery
- Process management with PID tracking
- Port availability checking

## Suggested Implementation Steps

1. Read `handheld-office/scripts/orchestrator.lua` thoroughly
2. Identify generic patterns vs project-specific logic
3. Design component configuration schema
4. Create `libs/component-orchestrator.lua`
5. Implement process spawning and PID tracking
6. Add state persistence (JSON to project's tmp/ directory)
7. Implement health check interface (port check, process alive)
8. Write test script `libs/test-component-orchestrator.lua`
9. Add bash wrapper `libs/component-orchestrator.sh` for shell scripts
10. Add TUI dashboard for component monitoring

## Source Scripts

- `../handheld-office/scripts/orchestrator.lua` (primary source)
- `./state-daemon.sh` (related - simpler state management)

## API Design

```lua
local orchestrator = require("libs/component-orchestrator")

-- Initialize with project directory for state persistence
orchestrator.init({
    project_dir = "/path/to/project",
    state_file = "tmp/orchestrator-state.json",
    log_file = "tmp/orchestrator.log"
})

-- Register components
orchestrator.register("daemon", {
    binary = "target/release/daemon",
    port = 8080,
    health_url = "http://localhost:8080/health",
    depends_on = {}
})

orchestrator.register("client", {
    binary = "target/release/client",
    depends_on = {"daemon"}
})

-- Lifecycle operations
orchestrator.start_all()           -- Respects dependency order
orchestrator.status_all()          -- Returns status table
orchestrator.health_check("daemon") -- Returns true/false
orchestrator.stop_all()            -- Reverse dependency order

-- Event hooks
orchestrator.on("start", function(name)
    print("Started: " .. name)
end)
```

```bash
# Bash wrapper usage
source libs/component-orchestrator.sh
orch_init "/path/to/project"
orch_register "daemon" "target/daemon" 8080
orch_start_all
orch_status_all
```

## Related Documents

- `README.md` - Scripts documentation
- `state-daemon.sh` - Simpler key-value state service
- `handheld-office/scripts/orchestrator.lua` - Source implementation
