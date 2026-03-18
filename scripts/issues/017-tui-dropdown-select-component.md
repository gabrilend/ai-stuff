# Issue 017: TUI Dropdown/Select Component

## Status
- **Priority**: Medium
- **Type**: Feature
- **Status**: Open
- **Created**: 2026-03-18

## Current Behavior

The menu.lua TUI library supports these item types:
- `checkbox` - Boolean toggle (on/off)
- `flag` - CLI flag with value input
- `multistate` - Cycles through predefined states
- `action` - Executes a callback
- `text` - Display-only text

There is no collapsible dropdown/select component that:
1. Shows a compact single-line when collapsed (e.g., "Server: [gpu-server ▼]")
2. Expands to show all options when selected
3. Allows selecting one option from a dynamic list
4. Collapses back after selection

## Intended Behavior

Add a new item type `select` (or `dropdown`) that provides:

### Visual States

**Collapsed (default):**
```
  Server: [gpu-server ▼]          (only current selection visible)
```

**Expanded (when focused and activated):**
```
  Server: ┌───────────────────┐
          │ ● gpu-server      │   (currently selected)
          │   gpu-server-alt  │
          │   local           │
          └───────────────────┘
```

### Interaction Model

1. Navigate to dropdown item (j/k)
2. Press Space or Enter to expand
3. Use j/k to navigate options within dropdown
4. Press Space or Enter to select and collapse
5. Press Escape to cancel and collapse (keep previous value)

### API Design

```lua
-- Static options (known at menu build time)
menu_add_item(section, id, label, "select", default_value, description, options_table, cli_flag)

-- Example:
menu_add_item("settings", "server", "Ollama Server", "select", "gpu-server",
    "Select which Ollama server to use for embedding generation",
    {
        { value = "gpu-server", label = "GPU Server (CUDA)", description = "192.168.0.115:10265" },
        { value = "gpu-server-alt", label = "GPU Server Alt", description = "192.168.0.115:11434" },
        { value = "local", label = "Local", description = "localhost:11434" },
    },
    "--ollama")

-- Dynamic options (fetched at runtime)
menu_add_item(section, id, label, "select_dynamic", default_value, description,
    options_function,  -- Function that returns options table
    cli_flag)

-- Example with dynamic options:
menu_add_item("settings", "server", "Ollama Server", "select_dynamic", "gpu-server",
    "Select which Ollama server to use",
    function()
        -- Called each time dropdown is expanded
        return fetch_ollama_servers()
    end,
    "--ollama")
```

### Options Table Structure

Each option in the table:
```lua
{
    value = "string",        -- Internal value (used in CLI flag)
    label = "string",        -- Display text in dropdown
    description = "string",  -- Optional: shown as subtitle or tooltip
    disabled = false,        -- Optional: gray out if unavailable
    disabled_reason = "...", -- Optional: explain why disabled
}
```

### Command Preview Integration

When a dropdown value is selected, it contributes to the command preview:
```
Command: ./run.sh --ollama=gpu-server --generate-embeddings
                  ^^^^^^^^^^^^^^^^^ from select item
```

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Empty options list | Show "(no options available)" disabled |
| Single option | Still show dropdown, but selection is obvious |
| Very long list | Implement viewport scrolling (see Issue 015) |
| Option too wide | Truncate with "..." |
| Terminal resize | Recalculate dropdown position |

## Suggested Implementation Steps

### Phase 1: Core Component
1. [ ] Add "select" item type handling to `render_item()`
2. [ ] Track expanded state per dropdown (`state.expanded_dropdown = item_id`)
3. [ ] Render collapsed view: `[value ▼]`
4. [ ] Implement expand trigger (Space/Enter on dropdown)

### Phase 2: Expanded View
5. [ ] Calculate dropdown position (below or above item depending on space)
6. [ ] Render expanded options list with border
7. [ ] Highlight current selection within dropdown
8. [ ] Track cursor position within expanded dropdown

### Phase 3: Interaction
9. [ ] Handle j/k navigation within expanded dropdown
10. [ ] Handle selection (Space/Enter) - update value, collapse
11. [ ] Handle cancel (Escape) - collapse without changing
12. [ ] Prevent main menu navigation while dropdown is expanded

### Phase 4: Dynamic Options
13. [ ] Add `select_dynamic` type that calls options function
14. [ ] Cache options during expansion (don't re-fetch on every render)
15. [ ] Show loading indicator if fetch takes time

### Phase 5: Polish
16. [ ] Animation for expand/collapse (optional, see Issue 10-018)
17. [ ] Scrollable viewport for long lists
18. [ ] Keyboard shortcut to jump to option by first letter

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` - TUI library source
- Issue 015: List section scrollbar viewport (for long dropdown lists)
- Issue 10-018: Animated command option transitions (for expand/collapse animation)
- Neocities Issue 10-029: TUI Ollama server selector (consumer of this component)

## Technical Notes

### State Management

The dropdown needs its own state:
```lua
state.dropdown = {
    expanded_id = nil,          -- Which dropdown is currently expanded (nil = none)
    cursor_index = 1,           -- Position within expanded dropdown
    cached_options = {},        -- Options table (for dynamic fetch)
    scroll_offset = 0,          -- For viewport scrolling
}
```

### Z-Order Rendering

Expanded dropdown must render on top of other items. Options:
1. Render dropdown content last (after all other items)
2. Use tui.lua overlay layer if available

### Focus Trap

While dropdown is expanded, navigation keys (j/k) should:
- Navigate within dropdown options only
- NOT move to other menu items
- Escape or selection releases the trap

---

## Implementation Log

(To be filled during implementation)
