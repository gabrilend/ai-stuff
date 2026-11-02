# Issue 017: TUI Dropdown/Select Component

## Status
- **Priority**: Medium
- **Type**: Feature
- **Status**: Built (branch `claude/menu-dropdown`)
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
1. [x] Add "select" item type handling to `render_item()`
2. [x] Track expanded state per dropdown (`state.expanded_dropdown = item_id`)
3. [x] Render collapsed view: `[value ▼]`
4. [x] Implement expand trigger (Space/Enter on dropdown)

### Phase 2: Expanded View
5. [x] Calculate dropdown position (below or above item depending on space)
6. [x] Render expanded options list with border
7. [x] Highlight current selection within dropdown
8. [x] Track cursor position within expanded dropdown

### Phase 3: Interaction
9. [x] Handle j/k navigation within expanded dropdown
10. [x] Handle selection (Space/Enter) - update value, collapse
11. [x] Handle cancel (Escape) - collapse without changing
12. [x] Prevent main menu navigation while dropdown is expanded

### Phase 4: Dynamic Options
13. [x] Add `select_dynamic` type that calls options function
14. [x] Cache options during expansion (don't re-fetch on every render)
15. [x] Show loading indicator if fetch takes time

### Phase 5: Polish
16. [ ] Animation for expand/collapse (optional, see Issue 10-018)
17. [x] Scrollable viewport for long lists
18. [x] Keyboard shortcut to jump to option by first letter

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

### What Happened

Built in `libs/menu.lua`, `libs/lua-menu.sh` and `libs/menu-runner.lua`,
with every step above but 16 (animation, optional).

- **Item types** `select` and `select_dynamic`. Options are
  `{value, label, description, disabled, disabled_reason}` tables or plain
  strings. From bash: `menu_set_item_options ID "value|label|desc|reason" ...`
  for a fixed list, `menu_set_item_options_command ID "command"` for a
  fetched one (the command prints the same lines). From Lua, `options` may be
  a table, or for `select_dynamic` a function.
- **Closed**: `Label: [chosen label ▼]`, cut with "..." when too wide;
  `(no options available)` for an empty fixed list, `(none)` for a dynamic
  list not yet opened. LEFT/RIGHT cycle like a multistate item, passing over
  disabled options.
- **Open**: SPACE/ENTER opens a single-line box over the rows below the item,
  or above it when there is more room there; drawn last, on top. The chosen
  option is marked ●, the cursor's highlighted, disabled ones dim. The
  description area shows the cursor's option, and a disabled one's reason.
  The footer shows the dropdown's keys.
- **Keys while open** (focus trap): j/k and arrows move, SPACE/ENTER choose,
  ESC/q close unchanged, HOME/END (and PAGE keys) go to the ends, any other
  letter or digit jumps by first letter, CTRL-C/Q quit the menu.
- **Long lists**: ten options at a time, the window following the cursor,
  a scrollbar in the right border.
- **Dynamic options**: fetched on each opening with "loading..." shown
  while the fetch runs, then kept, so drawing and cycling never fetch. A
  failed or empty fetch flashes the item red and says why.
- **Command preview**: `flag value`.
- `menu-runner.lua` now looks for `dkjson` in its own checkout first
  (`scripts/libs/../../libs/lua/`), so a second checkout uses its own copy.

### Decisions

- **The command preview writes `--flag value`**, as multistate items do,
  not the `--flag=value` of the example above: one form for every item that
  carries a value, and the preview's flag colouring already knows it.
- **Inside the dropdown, only j and k (and q) are not jump letters.** g, h,
  l and i jump, so a label starting with any of them is reachable by its
  letter ("GPU Server" by g); HOME/END stand in for g/G.
- **The cursor stops at the ends** rather than wrapping; the letter jump
  wraps.
- **A disabled option can be under the cursor** (so its reason can be read)
  but is refused when chosen, and the dropdown stays open.
- **Ten rows at most**, fewer when the screen has less room.
- **A fixed list with no value starts on its first choosable option**; a
  dynamic one starts empty, since fetching at build time would run the
  command before anyone asked.
- **The pure-bash fallback (`libs/menu.sh`) is not given the new types.**
  It is used only when LuaJIT is missing; a menu using `select` needs the
  Lua menu.

### Tests

`libs/test-menu-screen.sh` gains 29 checks that drive a real menu in a
pretend terminal (`script`, replayed by `test-menu-screen-replay.lua`):
closed display, opening, marking, descriptions, choosing, escape, a refused
disabled option with its reason, letter jumps (including g), cycling both
ways, the command preview, a dynamic list, and a fifteen-option list that
opens upward, shows ten with a scrollbar, and chooses the option scrolled
to.
