# phase-demo.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in phase-demo.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Neocities Modernization Project - Interactive Phase Demonstration
Production-ready deliverable showcasing all project achievements

Uses the TUI library for vim-style navigation when available.
Fallback to simple menu if TUI unavailable.

Usage: ./phase-demo.sh [DIRECTORY]

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `setup_dir_path()`
(No comment above it in the source.)

### `setup_tui_menu()`

```
Configure the TUI menu with all phase demonstrations and utilities
```

### `run_tui_selections()`

```
Execute the selected items from the TUI menu
```

### `run_tui_mode()`

```
Run the TUI-based interactive menu
```

### `show_main_menu()`
(No comment above it in the source.)

### `run_phase_demo()`
(No comment above it in the source.)

### `simple_menu_loop()`

```
Fallback simple menu loop (used when TUI unavailable)
```
