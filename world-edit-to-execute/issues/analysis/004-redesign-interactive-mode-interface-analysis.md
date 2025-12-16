This is a substantial issue that would definitely benefit from splitting. The issue encompasses building a complete TUI framework plus integrating it into the issue-splitter tool. Here's my analysis:

## Sub-Issue Breakdown for Issue 004

This issue should be split into **6 sub-issues** organized by component/layer:

---

### 004a - Create TUI Core Library

**Description:** Build the foundational terminal UI utilities in `src/cli/lib/tui.sh` - terminal state management (init/cleanup), key reading with escape sequence handling, and basic color/formatting utilities.

**Covers:**
- `tui_init()` - alternative screen buffer, cursor hiding, echo disable
- `tui_cleanup()` - terminal state restoration with trap
- `tui_read_key()` - single key input with arrow/escape sequence parsing
- Color/formatting helper functions
- Terminal dimension detection

**Dependencies:** None (foundational layer)

---

### 004b - Implement Checkbox Component

**Description:** Create the checkbox selection component with cursor tracking, toggle functionality, and visual rendering (checked/unchecked/disabled states).

**Covers:**
- Checkbox state management (`CHECKBOX_STATE`, `CHECKBOX_ITEMS`, `CHECKBOX_CURSOR`)
- `checkbox_render()` - visual output with cursor indicator
- `checkbox_toggle()` - state toggling
- `checkbox_select_all()` / `checkbox_select_none()`
- Disabled item handling (`[○]` state)

**Dependencies:** 004a (uses `tui_read_key`)

---

### 004c - Implement Multi-State Toggle Component

**Description:** Create the multi-state toggle component for options with 3+ states (like output format, verbosity) that cycle with h/l keys.

**Covers:**
- Multi-state option definition (`MULTISTATE_OPTIONS` associative array)
- `multistate_render()` - `◀ [VALUE] ▶` display
- `multistate_cycle()` - left/right cycling with wraparound
- Integration with main navigation (h/l keys context-aware)

**Dependencies:** 004a (uses key reading), 004b (integrates with checkbox navigation)

---

### 004d - Implement Number Input and Text Input Components

**Description:** Create input components for numeric values (parallel count) and text/path entry (directory selection).

**Covers:**
- `number_input()` - bounded numeric input with +/- adjustment
- `text_input()` - single-line text entry with editing
- `path_input()` - path entry with potential tab completion
- Inline editing within the TUI context

**Dependencies:** 004a (uses key reading)

---

### 004e - Build Menu Structure and Navigation System

**Description:** Create the hierarchical menu system with sections, cursor movement between sections, and nested option expansion/collapse.

**Covers:**
- Menu structure definition (`MENU_STRUCTURE`, `MENU_STATE`)
- Section-based navigation (Mode, Options, Issues)
- Cursor movement across sections (j/k/g/G)
- Nested option expand/collapse (h/l for non-multistate items)
- Index-based jumping (1-9)
- Scrollable issue list with viewport management

**Dependencies:** 004b (checkbox), 004c (multistate), 004d (inputs)

---

### 004f - Integrate TUI into Issue-Splitter

**Description:** Replace the existing y/n prompts in `issue-splitter.sh` with the new TUI system, wire up configuration to execution, and add graceful degradation.

**Covers:**
- Main render loop integration
- Header/footer rendering with keybinding hints
- Configuration → execution bridging
- Graceful fallback when terminal doesn't support features
- Terminal resize handling
- Testing across terminal emulators

**Dependencies:** 004a, 004b, 004c, 004d, 004e (all components)

---

## Dependency Graph

```
004a (TUI Core)
  │
  ├──► 004b (Checkbox)
  │       │
  ├──► 004c (Multi-State) ──────┐
  │       │                     │
  └──► 004d (Inputs)            │
          │                     │
          └────────► 004e (Menu/Navigation)
                          │
                          └────► 004f (Integration)
```

## Summary

| ID | Name | Dependencies |
|----|------|--------------|
| 004a | create-tui-core-library | None |
| 004b | implement-checkbox-component | 004a |
| 004c | implement-multistate-toggle | 004a, 004b |
| 004d | implement-input-components | 004a |
| 004e | build-menu-navigation-system | 004b, 004c, 004d |
| 004f | integrate-tui-into-issue-splitter | 004a-e (all) |

This split allows parallel work on 004b, 004c, and 004d after 004a is complete, then convergence at 004e before final integration.
