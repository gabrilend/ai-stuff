# Issue 011: TUI History Insert on Run

**Phase:** 0 - Tooling/Infrastructure
**Type:** Enhancement
**Priority:** Medium
**Dependencies:** 004 (Checkbox-style TUI)

---

## Current Behavior

When the user completes the interactive TUI mode (`-I`) and presses the "run" action:
1. The script extracts all selected options from the menu
2. It immediately executes the operation with those options
3. The user cannot easily re-run the same command without going through the TUI again

---

## Intended Behavior

When the user presses "run" in interactive mode:
1. The script builds the equivalent command-line string (already shown in preview)
2. Instead of executing, it adds the command to bash history via `history -s`
3. Exits cleanly back to the terminal
4. User can press "up" arrow to recall and execute the command
5. Subsequent runs can use "up" without re-entering TUI

This workflow enables:
- Quick iteration: run TUI once, then "up + enter" repeatedly
- Command discovery: learn the CLI flags by using TUI first
- Modification: edit the recalled command before running

---

## Suggested Implementation Steps

1. **Add new action item to TUI menu**
   - Add "Preview & Exit" or "Copy to History" action alongside "Run"
   - Or replace "Run" with dual behavior based on a toggle

2. **Build command string function**
   - Extract the command preview logic into a reusable function
   - Ensure it generates a valid, executable command string
   - Handle special characters and quoting properly

3. **Implement history insertion**
   ```bash
   # Add command to bash history (works in current shell)
   history -s "./issue-splitter.sh -s -S --parallel 3"

   # Alternative: append to history file directly
   echo "./issue-splitter.sh -s -S --parallel 3" >> ~/.bash_history
   ```

4. **Handle shell context limitations**
   - `history -s` only works if script is sourced, not executed
   - For executed scripts, consider alternatives:
     a. Print command with instructions to copy
     b. Write to a temp file and provide alias to recall
     c. Use `fc -s` or similar
     d. Output in a format the user can easily select/copy

5. **Add "history mode" flag**
   - `-H, --history-only` - TUI exits with command in history instead of executing
   - Or make this the default TUI behavior with `-R, --run-immediately` to execute

6. **User feedback**
   - Print message: "Command added to history. Press 'up' to recall."
   - Show the command that was added

---

## Technical Considerations

### Shell Context Problem

When a script is executed (not sourced), `history -s` modifies the subshell's
history, not the parent shell. Solutions:

1. **Clipboard approach** (cross-platform):
   ```bash
   echo "$cmd" | xclip -selection clipboard
   echo "Command copied to clipboard. Paste with Ctrl+Shift+V"
   ```

2. **History file approach**:
   ```bash
   echo "$cmd" >> "${HISTFILE:-$HOME/.bash_history}"
   echo "Command appended to history. May need new terminal or 'history -r'"
   ```

3. **Wrapper function approach** (requires user setup):
   ```bash
   # User adds to .bashrc:
   isplit() {
       eval "$(issue-splitter.sh -I --output-command)"
   }
   ```

4. **Output command approach** (simplest):
   ```bash
   # Script outputs the command, user can use !! or copy
   echo "Run this command:"
   echo "  $cmd"
   ```

### Recommended Approach

Implement option 4 (output command) as default, with option 2 (history file)
as `--append-history` flag for users who want automatic recall.

---

## Related Documents

- `src/cli/issue-splitter.sh` - Main script to modify
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` - TUI menu library
- `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` - Lua menu implementation

---

## Acceptance Criteria

- [ ] TUI mode can exit without executing, returning user to terminal
- [ ] Built command is displayed clearly for user to copy/recall
- [ ] Optional: command added to history file with `--append-history`
- [ ] User can press "up" to recall command (via history or manual copy)
- [ ] Works correctly with all option combinations
- [ ] Special characters in paths/options are properly escaped

---

## Notes

*This feature improves the "command discovery" workflow where users learn CLI
flags through the TUI, then transition to direct CLI usage for efficiency.*

The command preview already exists in the TUI (`cmd_preview` item), so the
string building logic is partially implemented. The main work is adding the
alternative exit path and history integration.
