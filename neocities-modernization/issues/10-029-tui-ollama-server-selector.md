# Issue 10-029: TUI Ollama Server Selector

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2026-03-18
- **Depends On**: scripts/issues/017 (TUI dropdown component)

## Current Behavior

The run.sh TUI (`-I` flag) provides checkboxes and flags for pipeline configuration, but Ollama server selection is CLI-only:
- `--ollama NAME` - Select server by name
- `--model NAME` - Override model
- `--list-ollama` - List available servers

Users must remember server names and type them as CLI flags. The TUI has no visibility into available servers.

## Intended Behavior

Add a dropdown selector to the TUI that:
1. Shows current Ollama server selection (default from config)
2. Expands to show all configured servers from `config.lua`
3. Updates the command preview when selection changes
4. Optionally shows a second dropdown for model selection

### Visual Design

**Settings section in TUI:**
```
═══════════════════════════════════════════════════════════════════════════════
                         Configuration
═══════════════════════════════════════════════════════════════════════════════
  [ ] Verbose output                              --verbose
  [ ] Dry run (show commands)                     --dry-run
  [ ] Low priority (nice -n 10)                   --low-priority

  Ollama Server: [gpu-server ▼]                   --ollama=gpu-server
  Model:         [nomic-embed-text ▼]             --model=nomic-embed-text
```

**When Ollama Server dropdown is expanded:**
```
  Ollama Server: ┌─────────────────────────────────────────┐
                 │ ● gpu-server       (192.168.0.115:10265)│
                 │   gpu-server-alt   (192.168.0.115:11434)│
                 │   local            (localhost:11434)    │
                 └─────────────────────────────────────────┘
```

**When Model dropdown is expanded (filtered by server):**
```
  Model:         ┌──────────────────────────┐
                 │ ● nomic-embed-text       │
                 │   mxbai-embed-large      │
                 └──────────────────────────┘
```

### Data Flow

1. On TUI initialization:
   - Load `ollama_servers` from config.lua via `ollama-config.lua`
   - Set default selection to `default_ollama_server` or first in list

2. Build options for server dropdown:
   ```lua
   local servers = ollama.get_servers()
   local options = {}
   for _, s in ipairs(servers) do
       table.insert(options, {
           value = s.name,
           label = s.name,
           description = string.format("%s:%d", s.host, s.port),
       })
   end
   ```

3. When server selection changes:
   - Update model dropdown options to show `available_models` for that server
   - Reset model to server's default if current model not available

4. Command preview shows:
   ```
   ./run.sh --ollama=gpu-server --model=nomic-embed-text --generate-embeddings
   ```

### Server Availability Indicator (optional enhancement)

Could show connectivity status:
```
  Ollama Server: ┌─────────────────────────────────────────┐
                 │ ✓ gpu-server       (192.168.0.115:10265)│  <-- green = reachable
                 │ ✗ gpu-server-alt   (192.168.0.115:11434)│  <-- red = unreachable
                 │ ? local            (localhost:11434)    │  <-- gray = not checked
                 └─────────────────────────────────────────┘
```

This could be done with async validation on dropdown expansion (non-blocking).

## Suggested Implementation Steps

### Phase 1: Dependencies
1. [ ] Wait for scripts/issues/017 (dropdown component) to be implemented
2. [ ] Verify ollama-config.lua is accessible from run.sh context

### Phase 2: Integration
3. [ ] Add "settings" section to TUI (or use existing)
4. [ ] Create server dropdown using `menu_add_item` with "select" type
5. [ ] Pass options built from `ollama.get_servers()`
6. [ ] Set default value from `ollama.get_default_server().name`

### Phase 3: Model Dropdown
7. [ ] Add model dropdown below server dropdown
8. [ ] Filter models based on selected server's `available_models`
9. [ ] Add dependency: model dropdown disabled if no server selected

### Phase 4: Command Integration
10. [ ] Wire dropdown values to shell variables (`$OLLAMA_SERVER`, `$MODEL_NAME`)
11. [ ] Verify command preview shows correct flags
12. [ ] Test actual execution uses selected values

### Phase 5: Polish
13. [ ] Consider async server availability checking
14. [ ] Handle case where config has no servers (show warning)
15. [ ] Test with various terminal widths

## Files to Modify

| File | Changes |
|------|---------|
| `run.sh` | Add dropdowns to `interactive_mode_tui()` function |
| scripts/libs/menu.lua | (via Issue 017) Add dropdown component |

## Code Location

The integration point is in `run.sh` around line 1300-1400, in the `interactive_mode_tui()` function, after the existing sections:

```bash
# ═══════════════════════════════════════════════════════════════════════════
# Section 4: Ollama Configuration (NEW)
# ═══════════════════════════════════════════════════════════════════════════
menu_add_section "ollama" "multi" "Ollama Configuration"

# Server selector (requires Issue 017 dropdown component)
# Options will be populated dynamically from config.lua
OLLAMA_OPTIONS=$(luajit -e "
    package.path = '$DIR/libs/?.lua;' .. package.path
    local ollama = require('ollama-config')
    local servers = ollama.get_servers()
    local options = {}
    for _, s in ipairs(servers) do
        table.insert(options, s.name .. '|' .. s.name .. '|' .. s.host .. ':' .. s.port)
    end
    print(table.concat(options, ';'))
")

menu_add_item "ollama" "server" "Ollama Server" "select" "$DEFAULT_SERVER" \
    "Select which Ollama server to use" "$OLLAMA_OPTIONS" "--ollama"
```

## Related Documents

- Issue 10-017: Multi-Ollama server configuration (completed - provides the config infrastructure)
- scripts/issues/017: TUI dropdown component (dependency - provides the UI component)
- `libs/ollama-config.lua`: Server configuration loader
- `config.lua`: Server definitions (`ollama_servers` section)

## Testing Checklist

- [ ] Dropdown shows all servers from config
- [ ] Default server is pre-selected
- [ ] Changing selection updates command preview
- [ ] Pipeline uses selected server when executed
- [ ] Model dropdown updates when server changes
- [ ] Works with single server configuration
- [ ] Works with no servers (shows appropriate message)

---

## Implementation Log

(To be filled during implementation)
