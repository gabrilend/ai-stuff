# Issue 051: A TUI dashboard for the component orchestrator

## Status
- **Priority**: Low
- **Type**: Feature
- **Status**: Open
- **Created**: 2026-11-03
- **Follows**: issue 013 (step 10)

## Current Behavior

`libs/component-orchestrator.lua` starts, stops and checks a project's
components, and `status` prints one line per component. There is no
interactive way to watch them or act on one.

## Intended Behavior

`component-orchestrator.lua <project> -I` opens a screen built with
`libs/tui.lua`. It lists each component with its state, pid, port and how
long it has been up, and refreshes every second or two. Keys start, stop or
restart the component under the cursor, and show the tail of its
`<name>.out` file.

## Suggested Implementation Steps

1. Lay the screen out with tui panels: a list panel and an output panel.
2. Draw `orch.status_all()` into the list; redraw only rows that changed.
3. Keys: j/k to move, s start, x stop, r restart, o toggle output, q quit.
4. A screen test in the style of `tests/test-menu-layout.sh`.
