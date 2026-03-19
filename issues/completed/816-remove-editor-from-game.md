# 816 - Remove Editor From Game

## Current Behavior

The game includes a full editor overlay system (~800 lines in `025-editor.c`):

```c
// src/001-main.c
#include "024-editor.h"

EditorState* editor = editor_create(world);

// Input handling
if (IsKeyPressed(KEY_E) && !upgrade_manager->menu_open && !editor_is_overlay_open(editor)) {
    editor_toggle(editor);
}

if (editor_is_overlay_open(editor)) {
    editor_handle_overlay_input(editor);
}

// Rendering
if (editor_is_overlay_open(editor)) {
    editor_render_overlay(editor);
}
```

This adds significant complexity to the game and increases binary size.

## Intended Behavior

Remove the editor from the game entirely:

1. **Remove editor include** from `001-main.c`
2. **Remove editor state** creation/destruction
3. **Remove E key handling** for editor toggle
4. **Remove editor input/render calls**
5. **Keep stage pool system** - game still loads boards from `boards/`
6. **Keep board data module** - still used for stage loading

### What Stays

The game retains:
- `020-board-data.h/c` - For loading JSON boards
- `026-stage-pool.h/c` - For random stage selection
- `boards/` directory scanning and loading

### What Goes

Remove from game:
- `024-editor.h` include
- `025-editor.c` (not compiled into game)
- Editor state allocation
- E key check
- Editor overlay rendering
- Editor-specific UI constants

## Suggested Implementation Steps

### Step 1: Remove editor includes and state

```c
// src/001-main.c - REMOVE these lines

// #include "024-editor.h"  // REMOVE

// EditorState* editor = editor_create(world);  // REMOVE
```

### Step 2: Remove E key handling

```c
// REMOVE this block:
// if (IsKeyPressed(KEY_E) && !upgrade_manager->menu_open && !editor_is_overlay_open(editor)) {
//     editor_toggle(editor);
// }
```

### Step 3: Remove editor input handling

```c
// REMOVE this block:
// if (editor_is_overlay_open(editor)) {
//     editor_handle_overlay_input(editor);
//     editor_update_notification(editor, GetFrameTime());
// }
```

### Step 4: Remove editor-related checks

```c
// Change checks from editor_is_overlay_open to just menu checks:

// Before:
// if (!upgrade_manager->menu_open && !editor_is_overlay_open(editor)) { ... }

// After:
if (!upgrade_manager->menu_open) { ... }
```

### Step 5: Remove editor rendering

```c
// REMOVE this block:
// if (editor_is_overlay_open(editor)) {
//     editor_render_overlay(editor);
// }
```

### Step 6: Remove editor cleanup

```c
// REMOVE:
// editor_destroy(editor);
```

### Step 7: Update Makefile

```makefile
# Remove 025-editor.o from OBJS
OBJS = src/001-main.o \
       src/002-threadpool.o \
       # ... other objects ...
       # src/025-editor.o  # REMOVE THIS LINE
```

### Step 8: Optional - Keep editor files for reference

The editor source files (`024-editor.h`, `025-editor.c`) can be kept in the repository but excluded from compilation. They serve as reference for the standalone editor.

Alternatively, move them to a separate directory:
```
src/
  editor/           # Editor-specific code
    024-editor.h
    025-editor.c
```

## Files to Modify

- `src/001-main.c` - Remove all editor references
- `Makefile` - Remove `025-editor.o` from game build

## Files to Keep (not compiled into game)

- `src/024-editor.h` - Reference for standalone editor
- `src/025-editor.c` - Reference for standalone editor

## Testing

1. Build game: `make` or `make game`
2. Run game: `bin/physics-sim`
3. Press E - nothing should happen (key now unused)
4. Game should work normally otherwise
5. Stage pool still loads boards from `boards/`
6. Editor is only available via `bin/board-editor`

## Impact on Controls

| Key | Before | After |
|-----|--------|-------|
| E | Open editor overlay | Unused (available for future feature) |

## Related Issues

- 1201-standalone-editor-application.md (creates standalone editor)
- 1114-editor-overlay-mode.md (implemented overlay being removed)

## Notes

This issue should be implemented AFTER issue 1201 (standalone editor) is complete and tested. The standalone editor must be functional before removing the in-game editor.

If users need to create boards, they use `bin/board-editor` instead of pressing E in-game.
