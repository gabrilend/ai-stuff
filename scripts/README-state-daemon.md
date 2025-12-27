# state-daemon.sh

A background service that holds key-value state in RAM using FIFO pipes for IPC. Enables inter-script communication without file-based locking. State persists across daemon restarts via automatic disk backup.

## Use Cases

### Start the State Service
Launch the daemon in background mode.

```bash
./state-daemon.sh start
```

### Store and Retrieve Values
Use from any script or terminal.

```bash
./state-daemon.sh set project_name "world-edit"
./state-daemon.sh set current_phase 3
./state-daemon.sh get project_name
# Output: world-edit
```

### Share State Between Scripts
Script A sets a value, Script B reads it:

```bash
# In script_a.sh
state-daemon.sh set build_status "complete"

# In script_b.sh
status=$(state-daemon.sh get build_status)
if [[ "$status" == "complete" ]]; then
    echo "Build finished!"
fi
```

### List All Keys
View what state is currently stored.

```bash
./state-daemon.sh list
```

### Dump All State
Get all key=value pairs.

```bash
./state-daemon.sh dump
```

### Clear All State
Reset the state store.

```bash
./state-daemon.sh clear
```

### Custom State Directory
Use project-specific state.

```bash
./state-daemon.sh /path/to/project/tmp start
./state-daemon.sh /path/to/project/tmp set key value
```

## Configuration Options

| Command | Description |
|---------|-------------|
| `start` | Start the daemon in background |
| `stop` | Stop the running daemon |
| `status` | Check daemon status and key count |
| `get <key>` | Get value for key |
| `set <key> <value>` | Set key to value |
| `del <key>` | Delete key |
| `list` | List all keys (one per line) |
| `dump` | Dump all key=value pairs |
| `count` | Get number of stored keys |
| `clear` | Delete all keys |
| `save` | Force save state to disk |
| `ping` | Health check |

## Capabilities

- **RAM-Based Storage**: Fast associative array in bash process
- **FIFO IPC**: Uses named pipes for communication (no sockets)
- **Persistence**: Automatically saves to disk on shutdown, loads on startup
- **Graceful Shutdown**: Handles SIGTERM/SIGINT to save state
- **Timeout Protection**: 5-second timeout on client commands
- **Unique Response Pipes**: Each client gets its own response pipe

## Directory Structure

```
/tmp/state-daemon/        # Default location (or custom)
├── daemon.pid            # PID file
├── request.fifo          # Request pipe
├── state.dat             # Persisted state
├── daemon.log            # Log file
└── responses/            # Per-request response pipes
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `STATE_DAEMON_DIR` | Override default directory (default: `/tmp/state-daemon`) |

## Usage in Scripts

```bash
#!/bin/bash
# Example: Build orchestration with shared state

# Start daemon if not running
./state-daemon.sh status >/dev/null 2>&1 || ./state-daemon.sh start

# Set build configuration
./state-daemon.sh set target "release"
./state-daemon.sh set jobs 4

# Read from another part of the script
target=$(./state-daemon.sh get target)
jobs=$(./state-daemon.sh get jobs)

# Track progress
./state-daemon.sh set build_step "compiling"
# ... do work ...
./state-daemon.sh set build_step "linking"
# ... do work ...
./state-daemon.sh set build_step "complete"
```

## Error Handling

| Response | Meaning |
|----------|---------|
| `OK:<value>` | Success with value |
| `ERR:key_not_found` | Key doesn't exist |
| `ERR:daemon_not_running` | Daemon not started |
| `ERR:timeout` | No response within 5 seconds |
| `ERR:unknown_command` | Invalid command |

## Related Scripts

- `issue-splitter.sh` - Could use for tracking processing state
- Component orchestrators - Useful for service coordination
