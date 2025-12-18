# Lua Menu TUI - User Guide

A keyboard-driven terminal menu interface with vim-style navigation.

## Navigation

| Key | Action |
|-----|--------|
| `j` / `DOWN` | Move cursor down |
| `k` / `UP` | Move cursor up |
| `g` | Jump to first item |
| `G` | Jump to last item |
| `` ` `` / `~` | Jump to Run action |

## Selection & Toggling

| Key | Action |
|-----|--------|
| `SPACE` / `i` / `ENTER` | Toggle current item / Activate action |
| `h` / `LEFT` | Uncheck checkbox / Set number to 0 |
| `l` / `RIGHT` | Check checkbox / Set number to default |

## Quick Jump (Checkbox Items)

Press digit keys to jump directly to checkbox items by their index number.

### Single Digits (Items 1-10)

| Key | Jumps To |
|-----|----------|
| `1` | Checkbox 1 |
| `2` | Checkbox 2 |
| ... | ... |
| `9` | Checkbox 9 |
| `0` | Checkbox 10 |

### Repeated Digits (Items 11+)

For menus with more than 10 checkboxes, press the same digit multiple times:

| Keys | Index | Jumps To |
|------|-------|----------|
| `1` `1` | 11 | Checkbox 11 |
| `2` `2` | 22 | Checkbox 12 |
| `3` `3` | 33 | Checkbox 13 |
| ... | ... | ... |
| `9` `9` | 99 | Checkbox 19 |
| `0` `0` | 00 | Checkbox 20 |
| `1` `1` `1` | 111 | Checkbox 21 |
| `2` `2` `2` | 222 | Checkbox 22 |
| ... | ... | ... |

### Going Back (SHIFT + Digit)

If you overshoot, hold SHIFT and press the digit to go back one tier:

| At Index | Press | Goes To |
|----------|-------|---------|
| 555 (checkbox 25) | `SHIFT+5` (%) | 55 (checkbox 15) |
| 55 (checkbox 15) | `SHIFT+5` (%) | 5 (checkbox 5) |
| 5 (checkbox 5) | `SHIFT+5` (%) | (stays at 5) |

SHIFT+digit key mapping (US keyboard):
```
SHIFT+1 = !    SHIFT+2 = @    SHIFT+3 = #    SHIFT+4 = $    SHIFT+5 = %
SHIFT+6 = ^    SHIFT+7 = &    SHIFT+8 = *    SHIFT+9 = (    SHIFT+0 = )
```

### Tips

- Pressing a **different** digit resets the sequence
- Quick jump only works for **checkbox** items (not text fields or actions)
- The displayed index shows what keys to press (e.g., `22` means press `2` twice)

## Custom Shortcuts

Some menus define custom keyboard shortcuts for frequently-used items. These are shown
in a cyan-colored line at the bottom of the menu:

```
j/k:nav  space:toggle  `:action  q:quit
                f:flush  r:reset  x:execute
```

**Behavior:**
- Press the shortcut key once to **jump** to that item
- Press it again (when already on that item) to **toggle/activate** it

For example, if `f` is defined for "Flush Cache":
- First `f` press: cursor moves to "Flush Cache" item
- Second `f` press: toggles the checkbox on/off

## Number Entry Fields

Some menus have numeric input fields (shown as `Label: [  5]`).

| Key | Action |
|-----|--------|
| `LEFT` / `h` | Set to 0 |
| `RIGHT` / `l` | Set to default value |
| `0-9` | Enter digits (first digit clears, then appends) |
| `BACKSPACE` | Delete last digit |

**Note:** When cursor is on a number field, digit keys edit the value instead of jumping.

## Command Preview Editing (Vim-Style Modal)

Some menus display a live command preview showing the bash command being built from your selections.
When the cursor is on the command preview, it uses vim-style modal editing with three modes.

### Vim-Nav Mode (Default)

When you first navigate to the command preview, you're in **vim-nav mode**:

| Key | Action |
|-----|--------|
| `h` | Move cursor left |
| `l` | Move cursor right |
| `j` | Navigate to next menu item |
| `k` | Navigate to previous menu item |
| `0` | Go to start of line |
| `$` | Go to end of line |
| `x` | Delete character at cursor |
| `i` | Enter **insert mode** at cursor |
| `A` | Enter **insert mode** at end of line (append) |
| `ENTER` | Run command (if no invalid flags) |
| `q` | Quit |

### Insert Mode

Enter with `i` or `A`. The footer shows `-- INSERT --`:

| Key | Action |
|-----|--------|
| Any character | Insert at cursor (including h/j/k/l) |
| Arrow keys | Move cursor |
| `BACKSPACE` | Delete character before cursor |
| `DELETE` | Delete character at cursor |
| `ESC` | Exit to vim-nav mode |
| `UP` / `DOWN` | Navigate out (also exits insert mode) |
| `ENTER` | Run command (if no invalid flags) |

### Arrow Mode

If you use arrow keys while in vim-nav mode, you switch to **arrow mode**:

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor |
| Any character | Insert at cursor (including h/j/k/l/q) |
| `BACKSPACE` | Delete character before cursor |
| `ESC` | Return to vim-nav mode |
| `UP` / `DOWN` | Navigate out (returns to vim-nav) |
| `ENTER` | Run command (if no invalid flags) |

### Mode Reset

When you navigate away from the command preview (to another menu item), the mode
automatically resets to **vim-nav mode** for the next time you return.

### How Editing Works

As you edit the command text:
- **Valid flags** (like `--verbose`, `-s`) are shown in cyan and automatically check
  the corresponding options in the menu above
- **Invalid flags** (unrecognized options) are shown in **red** - you cannot run
  the command until these are fixed
- Options not present in the command are automatically unchecked

### Example

```
$ ./script.sh --verbose --skip-existing
```

If you delete `--verbose` from the command, the "Verbose" checkbox will be unchecked.
If you type `--invalid-flag`, it will be shown in red until corrected.

## Exiting

| Key | Action |
|-----|--------|
| `q` / `Q` / `ESC` | Quit without running |
| Select "Run" action | Execute with current settings |

To run: navigate to the Run action item (press `` ` `` to jump there) and press `SPACE` or `ENTER`.

## Display Legend

```
1  >[*] Selected checkbox      <- cursor here, checked
2   [ ] Unchecked checkbox
3   [o] Disabled checkbox
      Number Field: [  42]     <- editable number
      Option <[VALUE]>         <- cycle with LEFT/RIGHT
      Run Action -->           <- press SPACE to execute
```

## Example Session

```
1. Start menu (cursor on first item)
2. Press 'j' three times to move down
3. Press 'SPACE' to toggle a checkbox
4. Press '5' to jump to checkbox 5
5. Press 'l' to check it
6. Press '`' to jump to Run action
7. Press 'ENTER' to execute
```
