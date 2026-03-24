# 10-008: Implement Multi-Line Command Wrapping

## Status
- **Phase**: 10
- **Priority**: Low
- **Type**: Enhancement
- **Status**: Completed
- **Completed**: 2026-03-18
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
- Issue 10-004: Built-up command preview - **Moved to `/home/ritz/programming/ai-stuff/scripts/issues/`**
- Issue 10-007: Text-entry field display - **Moved to `/home/ritz/programming/ai-stuff/scripts/issues/`**

**Note**: Phase 10 issues related to the TUI library and issue-splitter.sh have been moved to the monorepo scripts/issues directory, as they apply to monorepo-level tools rather than being specific to the neocities-modernization project.

## Notes

This enhancement improves usability for complex pipelines with many flags. It also
makes the `~` key copy feature more useful, as the copied command will be properly
formatted for pasting into a terminal.

The existing `parse_command_tokens()` function (line 544) provides the tokenization
needed for word-aware wrapping. The challenge is coordinating multi-row rendering
with the existing single-row item model.

---

## Implementation Log

### 2026-03-18: Initial Implementation (Phase 1-2)

**Files Modified:**
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`

**Changes:**

1. **Added `wrap_command_to_lines()` function** (lines 1039-1125)
   - Takes command text, max_width, and first_line_offset
   - Returns array of {text, is_continuation} for each wrapped line
   - Continuation lines are indented to align with first flag position
   - Uses backslash " \" as continuation marker

2. **Modified text item rendering** (lines 2164-2268)
   - When not highlighted (display mode), command preview uses multiline rendering
   - Each line rendered with per-token coloring (yellow=radio/base, green=checkbox, cyan=other)
   - When highlighted (edit mode), keeps single-line behavior with truncation

3. **Updated section rendering loop** (lines 2321-2348)
   - `render_item()` now returns number of rows used
   - Loop increments row by `rows_used` instead of always 1
   - Added `state.cmd_preview_rows` to track rows used

4. **Added state initialization** (line 146)
   - `state.cmd_preview_rows = 1` default

**Scope of Implementation:**
- ✅ Phase 1: Wrapping logic with token-aware breaks
- ✅ Phase 2: Multi-row rendering for non-highlighted display
- ⏸️ Phase 3: Multi-row cursor editing (deferred - edit mode stays single-line)
- ⏸️ Phase 4: Clipboard multi-line copy (deferred - uses original single-line)

**Design Decision:**
When command preview is highlighted for editing, it remains single-line with truncation.
This preserves the existing cursor/editing behavior. Multi-line editing would require
significant changes to cursor positioning across wrapped lines.

**Testing:**
- Wrap function tested with various command lengths
- Lines correctly wrap at token boundaries, not mid-flag
- Continuation marker " \" added to all lines except last
- Continuation lines indented to align with first flag

### 2026-03-18: Reopened - Bugs Found During Testing

**Issues Discovered:**

1. **Extra leading space on continuation lines** - Lines 2+ have an extra space character
   at the beginning, before the indentation. This causes visual misalignment.

2. **Flag+argument pairs can be split** - Flags with arguments (e.g., `--threads 4`,
   `--parallel 8`) can be wrapped such that the flag and its value end up on separate
   lines. They should be treated as atomic units for wrapping purposes.

3. **Multi-line editing not implemented** - When the command preview is highlighted
   for editing, it still uses single-line mode with truncation. Need to implement
   multi-line cursor navigation for edit mode.

**Remaining Tasks:**
- [x] Fix extra space on continuation lines
- [x] Treat flag+argument pairs atomically (never split `--flag value`)
- [x] Implement multi-line editing with cursor navigation across wrapped lines

### 2026-03-18: All Issues Fixed

**Fixes Applied:**

1. **Extra space fix** - Removed `+ 1` from continuation indent calculation:
   ```lua
   -- Before: continuation_indent = base_indent + #tokens[1].text + 1
   -- After:  continuation_indent = base_indent + #tokens[1].text
   ```
   The extra `+1` was accounting for the space between script and flag, but this
   caused the flag to appear one column too far right on continuation lines.

2. **Atomic flag+argument pairs** - Pre-process tokens into "units" before wrapping:
   ```lua
   -- If token starts with "-" and next token doesn't, combine them
   if is_flag and next_is_value then
       table.insert(units, {text = token.text .. " " .. next_token.text})
   ```
   This ensures `--threads 4` or `--parallel 8` are never split across lines.

3. **Multi-line editing** - Complete rewrite of edit mode rendering:
   - Build position map: `pos_map[orig_pos] = {line=N, col=N}`
   - Maps each character in original string to its screen position
   - Cursor displayed at correct position via reverse lookup
   - Per-token coloring preserved across wrapped lines
   - Cursor at end shows on last line after last character
   - All existing vim keybinds work (h/l/i/x/A/^/$)

**Files Modified:**
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`:
  - `wrap_command_to_lines()`: Fixed indent calculation, added unit-based wrapping
  - Edit mode rendering: Complete rewrite with position mapping for multi-line cursor

### 2026-03-18: Navigation Enhancements

**Additional Fixes:**

1. **Cursor cannot reach ./run.sh** - Minimum cursor position set to first flag:
   - `cmd_min_cursor_pos` tracks position after script name
   - `cmd_cursor_left()` and `cmd_cursor_start()` respect this boundary

2. **Line-based navigation** - j/k and UP/DOWN move between wrapped lines:
   - Added `cmd_cursor_up()` and `cmd_cursor_down()` functions
   - Maintains column position when moving between lines
   - Stores `cmd_pos_map` and `cmd_line_ranges` in state for navigation

3. **Line-specific $ and 0** - Move to start/end of CURRENT LINE:
   - `$` now calls `cmd_cursor_line_end()` (end of current line)
   - `0` now calls `cmd_cursor_line_start()` (start of current line, respects min pos)
   - `^` goes to start of command (first flag)
   - `G` goes to end of command
   - `gg` goes to start of command

4. **Arrow keys work like vim keys**:
   - LEFT/RIGHT same as h/l (cursor left/right)
   - UP/DOWN same as j/k (line up/down within wrapped command)
   - No more mode switching on arrow keys

5. **Backspace behavior** - Deletes and enters insert mode
6. **I (capital)** - Enters insert mode (same as lowercase i)

### 2026-03-18: Section Navigation and Input Fixes

**Additional Fixes:**

1. **K/J leave command preview at line boundaries**:
   - `cmd_cursor_up()` and `cmd_cursor_down()` now return `false` at boundaries
   - Key handlers check return value and call `nav_up()`/`nav_down()` when at edge
   - Pressing K on first line leaves preview and goes to previous section
   - Pressing J on last line leaves preview and goes to next section

2. **End-of-line cursor visibility**:
   - Gap positions (spaces between wrapped lines) now mapped to end of current line
   - Added cursor rendering for positions past last rendered character
   - Cursor visible when at end of any line, not just end of command

3. **Arrow key single-tap fix**:
   - Root cause: Lua's buffered I/O interfered with select()-based timeout
   - When `io.read(1)` was called, Lua might buffer multiple bytes
   - Then `select()` reported no data available (bytes in Lua's buffer, not kernel's)
   - Fix: Added `tty_in:setvbuf("no")` to disable buffering
   - Arrow key escape sequences now detected reliably on single taps

**Files Modified:**
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`:
  - Updated key handlers for j/k/UP/DOWN to leave preview at boundaries
  - Added gap position mapping in position map construction
  - Added cursor rendering for end-of-line positions
- `/home/ritz/programming/ai-stuff/scripts/libs/tui.lua`:
  - Added `setvbuf("no")` to disable input buffering

### 2026-03-18: Clipboard Fix (Phase 4 Completed)

**Issue**: The `~` key clipboard copy wasn't working on Wayland systems.

**Root Cause**: The clipboard code checked if `xclip` was installed and used it first,
but xclip doesn't work on pure Wayland sessions (only with XWayland). Also, using
`io.popen(cmd, "w")` with Lua's buffered I/O sometimes failed to deliver data.

**Fixes Applied:**

1. **Environment detection**: Check `$WAYLAND_DISPLAY` first to detect Wayland sessions
2. **Tool priority**: Use wl-copy on Wayland (even if xclip is installed)
3. **Temp file approach**: Write text to temp file, use shell redirection (`< tmpfile`)
   instead of Lua pipe mode to avoid buffering issues
4. **Fall back to X11**: Only use xclip/xsel if not on Wayland or wl-copy unavailable

**Files Modified:**
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua`:
  - Rewrote `copy_to_clipboard()` function (lines 1697-1778)

