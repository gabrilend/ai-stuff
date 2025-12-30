# 10-008: Implement Multi-Line Command Wrapping

## Status
- **Phase**: 10
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open
- **Created**: 2025-12-23
- **Related To**: 10-004 (Command Preview System)

## Current Behavior

When the built-up command exceeds the terminal width, it is truncated:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ Command: ./run.sh --validate --extract --embed --catalog --generate --paral...║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

Key code location in `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`:
- Line 1349: `local max_len = state.cols - col - 2`

The command is capped at `max_len` characters and truncated with "..." if it exceeds.

## Intended Behavior

Long commands should wrap to multiple lines using backslash continuation, with wrapped
lines aligned to the start of the flags (not the script name):

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ Command: ./run.sh --validate --extract --embed --catalog \                    ║
║                   --generate --parallel 8 --force --verbose                   ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

Or with longer script paths:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ Command: /home/ritz/scripts/run.sh --validate --extract \                     ║
║                                    --embed --catalog --generate \             ║
║                                    --parallel 8 --force --verbose             ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

### Key Requirements

1. **Backslash continuation**: Insert `\` before each line break (except last line)
2. **Column alignment**: Subsequent lines indent to align with first flag
3. **Word-aware wrapping**: Never break in the middle of a flag or value
4. **Preserve editability**: Command remains fully editable when focused
5. **Copy support**: `~` key copies the multi-line version (with backslashes) to clipboard

## Implementation Details

### Line Width Calculation

```lua
-- Calculate wrap points:
-- Line 1: "Command: ./script.sh --flag1 --flag2 \"
--         ^col     ^cmd_start  ^first_flag
-- Line 2+: "                    --flag3 --flag4"
--          ^indent_to_first_flag

local available_width = state.cols - col - 2  -- Account for borders
local cmd_base_len = #state.command_base + 1  -- Script + space
local flag_indent = col + string.len("Command: ") + cmd_base_len
```

### Token-Based Wrapping

The library already has `parse_command_tokens()` (line 544) which tokenizes
the command into flag/value pairs. Use this to determine safe wrap points.

```lua
-- Pseudocode for wrapping logic
local function wrap_command_text(cmd_text, max_width, indent_width)
    local tokens = parse_command_tokens(cmd_text)
    local lines = {}
    local current_line = ""
    local first_line = true

    for _, token in ipairs(tokens) do
        local test_len = #current_line + 1 + #token.text
        local line_max = first_line and max_width or (max_width - indent_width)

        if test_len > line_max - 2 then  -- Reserve space for " \"
            -- Wrap to next line
            table.insert(lines, current_line .. " \\")
            current_line = string.rep(" ", indent_width) .. token.text
            first_line = false
        else
            if #current_line > 0 then
                current_line = current_line .. " " .. token.text
            else
                current_line = token.text
            end
        end
    end
    table.insert(lines, current_line)

    return lines
end
```

### Render Considerations

1. **Single-line items**: If command fits on one line, render as before
2. **Multi-line items**:
   - Item takes multiple rows in the TUI grid
   - Cursor navigation must work across lines
   - Highlight applies to all lines when focused

### State Changes

May need to track:
- `state.command_line_count` - Number of lines the command occupies
- `state.command_wrapped_lines` - Cached wrapped line array
- `state.cursor_line` - Which wrapped line the cursor is on (for editing)

## Suggested Implementation Steps

### Phase 1: Wrapping Logic
1. [ ] Create `wrap_command_to_lines(cmd_text, max_width, indent)` function
2. [ ] Add unit tests for wrapping edge cases (empty, single token, exact fit)
3. [ ] Handle edge case: first flag longer than remaining line 1 width

### Phase 2: Rendering
4. [ ] Modify `render_item()` to handle multi-line text items
5. [ ] Reserve additional rows for wrapped command lines
6. [ ] Maintain proper item indexing despite multi-row items

### Phase 3: Editing
7. [ ] Update cursor movement to navigate across wrapped lines
8. [ ] Ensure insertions/deletions trigger rewrap
9. [ ] Preserve cursor position semantically (in command string) across rewraps

### Phase 4: Clipboard
10. [ ] Update `~` key handler to copy multi-line version with backslashes
11. [ ] Optionally: Alternative key for single-line (no backslash) version

### Phase 5: Testing
12. [ ] Test with various terminal widths (80, 120, minimal)
13. [ ] Test with very long script paths
14. [ ] Test editing in middle of wrapped command
15. [ ] Regression test: short commands still work as before

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| Command fits on one line | No wrapping, no backslash |
| Empty command | Single line with just script name |
| Single very long flag value | Wrap before the flag if possible |
| Terminal resize during display | Rewrap to new width |
| Cursor at wrap boundary | Clear visual indication of position |

## Configuration Options (Optional)

Could add to menu config:
```lua
state.config = {
    wrap_long_commands = true,      -- Enable multi-line wrapping
    wrap_continuation_char = "\\",   -- Character to use (could be nil for no char)
    min_wrap_width = 40,            -- Don't wrap if terminal narrower than this
}
```

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` - TUI library source
- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua` - Framebuffer renderer
- Issue 10-004: Built-up command preview (provides the command preview feature)
- Issue 10-007: Text-entry field display (related rendering logic)

## Notes

This enhancement improves usability for complex pipelines with many flags. It also
makes the `~` key copy feature more useful, as the copied command will be properly
formatted for pasting into a terminal.

The existing `parse_command_tokens()` function (line 544) provides the tokenization
needed for word-aware wrapping. The challenge is coordinating multi-row rendering
with the existing single-row item model.

---

## Implementation Log

(To be filled during implementation)

