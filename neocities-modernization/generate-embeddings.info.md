# generate-embeddings.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in generate-embeddings.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Embedding Generation Manager for Neocities Poetry Modernization

Generates vector embeddings for poems using inference server embedding models.
Supports incremental processing, cache management, and multiple models.

Uses TUI library for vim-style interactive mode when available.

Usage: ./generate-embeddings.sh [OPTIONS] [DIRECTORY]
```

## Functions

### `setup_dir_path()`
(No comment above it in the source.)

### `setup_embedding_tui_menu()`

```
Configure the TUI menu for embedding generation options
```

### `apply_tui_selections()`

```
Map TUI menu values to the script's flag variables
```

### `run_tui_interactive_mode()`

```
Run the TUI-based interactive mode
```

### `run_simple_interactive_mode()`

```
Fallback simple interactive mode (original implementation)
```

### `cleanup_and_exit()`

```
Graceful termination handler
```

### `monitor_progress()`

```
Create monitoring function
Issue 10-022: Updated to use PID-based detection instead of pgrep for process name
This is needed because we now use luajit -e instead of lua similarity-engine.lua
```
