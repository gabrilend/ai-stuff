I've read the issue file. Let me analyze whether it should be split into sub-issues.

## Analysis

This issue is already quite well-structured and has a clear linear progression. However, it does contain several distinct implementation tasks that could benefit from being tracked separately. The main areas are:

1. Creating the shared library structure with multiple component files
2. Setting up symlinks across projects
3. Updating existing scripts to use the library
4. Documentation

## Suggested Sub-Issues

### 005a-create-shared-tui-directory-structure
**Description:** Create the base directory structure at `/home/ritz/programming/ai-stuff/libs/tui/` and implement the main `tui.sh` module with init/cleanup functions.

**Covers:**
- Creating the libs/tui directory
- Implementing tui.sh (main module with tui_init, tui_cleanup, tui_clear, tui_get_dimensions)
- Implementing keybindings.sh (tui_read_key, tui_wait_key)

**Dependencies:** 004 (the TUI design must exist first)

---

### 005b-implement-checkbox-component
**Description:** Implement the checkbox multi-select component as a standalone module.

**Covers:**
- Creating checkbox.sh with all checkbox_* functions
- State management (TUI_CHECKBOX_STATE, TUI_CHECKBOX_ITEMS, etc.)
- Rendering, toggling, navigation, select all/none

**Dependencies:** 005a (needs keybindings.sh for key handling)

---

### 005c-implement-multistate-and-number-components
**Description:** Implement the multi-state toggle and number input components.

**Covers:**
- Creating multistate.sh with multistate_define, multistate_render, multistate_cycle, multistate_get
- Creating number-input.sh with number_input function
- These are simpler components that can be grouped together

**Dependencies:** 005a (needs keybindings.sh)

---

### 005d-create-symlinks-and-integrate
**Description:** Set up project symlinks and update issue-splitter.sh to use the shared library.

**Covers:**
- Creating symlink at world-edit-to-execute/src/cli/lib/tui
- Creating symlink at scripts/lib/tui
- Updating issue-splitter.sh to source from TUI_LIB_DIR
- Testing that sourcing works from multiple locations

**Dependencies:** 005a, 005b, 005c (all components must exist)

---

### 005e-document-tui-library
**Description:** Create README.md and ensure library is properly documented.

**Covers:**
- Writing README.md with usage examples
- Documenting all components and their APIs
- Adding any inline documentation needed

**Dependencies:** 005b, 005c (need to know final API to document)

---

## Dependency Graph

```
004 (prerequisite - TUI design)
 │
 ▼
005a (core + keybindings)
 │
 ├──────┬──────┐
 ▼      ▼      │
005b   005c    │
 │      │      │
 └──────┴──────┘
        │
        ▼
      005d (integration)
        │
        ▼
      005e (documentation)
```

## Recommendation

**Split this issue.** While the issue is well-written, it encompasses 5 distinct files to create plus integration work. Splitting allows:

1. Parallel work on 005b and 005c after 005a is done
2. Clear checkpoints for testing individual components
3. Easier tracking of which components are complete
4. Documentation can be written incrementally as components finish

The split also aligns with the modular design philosophy stated in the issue itself—each component should be "independently sourceable."
