# Issue 106: File-Based Persistence Layer

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: Medium
**Created**: 2026-01-08

---

## Current Behavior

No persistence mechanism exists. The project needs to save and restore state across sessions.

---

## Intended Behavior

The system should:
- Save application state to files
- Restore state on startup
- Use human-readable formats (Lua tables, JSON)
- Store state in organized directory structure
- Support module-specific state storage
- Handle state versioning for compatibility
- Validate loaded state for corruption
- Provide clean state management API
- Be version control and grep friendly

---

## Suggested Implementation Steps

1. Create `src/persistence.lua` for state management
2. Design state directory structure (tmp/state/ or dedicated)
3. Implement Lua table serialization (save to .lua files)
4. Implement state deserialization (load from .lua files)
5. Create state file format with version metadata
6. Implement state validation on load
7. Add module-specific state namespaces
8. Create state save/restore API
9. Implement automatic state save on shutdown
10. Add state restoration on startup
11. Handle corrupted/invalid state files gracefully
12. Write tests for save/restore cycles
13. Document persistence API in src/persistence.info.md

---

## Related Documents

- docs/technical-design.md (Data Storage section)
- User's global instructions (human-readable, greppable)
- docs/roadmap.md (Phase 1)

---

## Implementation Notes

**State Directory Structure**:
```
tmp/state/
├── app-state.lua          # Core application state
├── modules/               # Module-specific state
│   ├── document-reader.lua
│   ├── tui.lua
│   └── ...
└── metadata.lua           # State version and integrity info
```

**State File Format**:
```lua
-- tmp/state/app-state.lua
return {
    version = "1.0.0",
    timestamp = 1704729825,
    data = {
        last_document = "/path/to/doc.txt",
        ui_state = {
            scroll_position = 42,
            active_view = "document"
        }
    }
}
```

**API Functions**:
```lua
-- Save state
persistence.save(namespace, data)
-- namespace: "app" | "module:module-name"
-- data: Lua table to serialize

-- Load state
local data = persistence.load(namespace)
-- Returns: table or nil if not found

-- Clear state
persistence.clear(namespace)

-- Save all state (called on shutdown)
persistence.save_all()

-- Restore all state (called on startup)
persistence.restore_all()
```

**Serialization Considerations**:
- Handle nested tables
- Preserve table structure
- Support basic types (string, number, boolean, nil)
- Cannot serialize functions or userdata (document this limitation)
- Pretty-print output for readability and grep-ability

**State Validation**:
- Check version compatibility
- Verify required fields present
- Type-check values
- Detect corruption (invalid Lua syntax)
- Fall back to empty state if invalid

---

## Testing Criteria

- [ ] Can save state to files
- [ ] Can restore state from files
- [ ] State files are human-readable
- [ ] State files are greppable
- [ ] Handles nested table structures
- [ ] Version metadata included
- [ ] Validates state on load
- [ ] Handles corrupted state gracefully
- [ ] Module-specific state isolated
- [ ] State persists across restarts

---

## Dependencies

- 104 (configuration system) - may configure state location

---

## Blocks

- Phase 1 demo (should restore UI state)
- Future phases (modules need state persistence)
