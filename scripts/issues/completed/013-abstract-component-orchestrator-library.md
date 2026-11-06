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

## What Happened

**2026-11-03.** Built as `libs/component-orchestrator.lua`, with the shell
wrapper `libs/component-orchestrator.sh` and notes in
`libs/component-orchestrator.info.md`. Tested by
`tests/test_component-orchestrator.lua` (48 checks), which uses real
processes: `sleep` for a daemon, netcat for something that listens on a port.

Steps 1-9 are done. Step 10, a TUI dashboard, is filed as issue 060.
`handheld-office`'s own orchestrator is not switched over; that belongs to
that project.

What the source did that was kept: registration with a command and a port,
state saved to a file and read back by the next run, a timestamped log,
start/stop/status. What was left behind as handheld-office's own: the cargo
build steps and the three hard-coded binaries.

Decisions:

- **State is tab-separated text, not JSON.** The bash wrapper and `grep` can
  read it, and the library needs no JSON module. Everything goes in one
  folder, `<project>/tmp/orchestrator/` (or `$ORCH_STATE_DIR`).
- **A component is stopped by its own pid, never by name.** The source used
  `pkill -f daemon`, which kills every process whose command line contains
  "daemon". Each component runs under `setsid`, so its pid is also its
  process group, and stop sends TERM to that group (helpers it spawned stop
  too), then KILL after `stop_wait` seconds.
- **A reused pid is not ours.** The process start time from `/proc` is saved
  with the pid. If it no longer matches, the component counts as `exited` and
  nothing is signalled. Without `/proc`, `kill -0` is the fallback.
- **Start waits until healthy.** With a port, `health_command` or
  `health_url`, start waits up to `start_wait` seconds for every check to
  pass. Without one, it waits a moment so a command that fails at once is
  caught. A failed start kills what it started, and the error quotes the
  last lines of the component's output.
- **`stop(name)` stops only that component.** `stop_all` stops dependents
  before the things they depend on. `start(name)` starts its dependencies
  first.
- **Exit statuses are read both ways.** A stock LuaJIT's `os.execute`
  returns a number; one built with Lua 5.2 compatibility returns
  true/nil plus a code. Group signals are written `kill -TERM -<pid>`,
  because dash's `kill` refuses `--`.
- **Ports are checked through bash's `/dev/tcp`**, so no netcat is needed at
  run time. `health_url` uses curl when it is given.
