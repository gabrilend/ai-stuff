# Project File Server

A Lua-based utility that generates an interactive HTML interface for browsing local programming projects in a tree structure. Uses `file://` protocol links to navigate directories directly from your browser.

## Overview

The Project File Server scans your programming directories and generates a self-contained HTML page with:

- **Tree-based navigation** - Expandable/collapsible directory structure
- **Project analytics sidebar** - File counts, type distributions, detected project files
- **Search functionality** - Filter projects and files in real-time
- **Quick access links** - Jump to common directories
- **Responsive design** - Works on desktop and mobile browsers

## Usage

### Quick Start

```bash
# Generate with defaults (scans ai-stuff, outputs to ai-stuff/project-file-server.html)
project-file-server

# Open in browser
xdg-open ~/programming/ai-stuff/project-file-server.html
```

### Command Line Options

```bash
# Interactive mode with menu
project-file-server -I

# Scan specific directory
project-file-server /path/to/projects

# Custom output location
project-file-server -o ~/my-server.html

# Combine options
project-file-server /path/to/projects -o /tmp/output.html

# Help
project-file-server -h
```

### Interactive Mode

Running with `-I` provides a menu-driven interface:

1. Generate/Update file server HTML
2. Start HTTP server (port 8080)
3. Start HTTP server (custom port)
4. Open file server in browser
5. Change directory to scan
6. Change output location
7. Exit

## Features

### Sidebar Analytics

| Section | Description |
|---------|-------------|
| **Project Statistics** | Total file and directory counts |
| **File Types** | Top 10 file extensions by count |
| **Quick Tools** | Expand All, Collapse All, Find Large Files, Recent Files |
| **Quick Access** | Links to common directories |
| **Project Files Found** | Detected README.md, package.json, Cargo.toml, etc. |

### Tree Navigation

- Click folder icons to expand/collapse
- `file://` links open directories in your file manager
- File sizes displayed in parentheses
- Dotted lines show hierarchy

### Search

- Type in search box to filter projects/files
- Matching items remain visible
- Parent directories auto-expand to show matches

## Architecture

```
project-file-server (runner script)
         │
         ▼
scripts/libs/project-file-server.lua (library)
         │
         ├── scan_directory_bash()     → Recursive directory scanning
         ├── get_project_analysis()    → File type and project detection
         ├── generate_sidebar_html()   → Analytics sidebar generation
         ├── generate_tree_html()      → Tree structure generation
         └── generate_html_page()      → Complete HTML assembly
         │
         ▼
    [output.html]                      → Self-contained HTML file
```

## Dependencies

- **Lua** (LuaJIT compatible)
- **dkjson** (located at `/home/ritz/programming/ai-stuff/libs/lua/dkjson.lua`)
- **Bash utilities**: `find`, `du`, `stat`, `wc`, `sed`, `sort`, `uniq`

## File Locations

| File | Path |
|------|------|
| Library | `/home/ritz/programming/ai-stuff/scripts/libs/project-file-server.lua` |
| Runner | `/home/ritz/programming/ai-stuff/scripts/project-file-server` |
| Default Output | `/home/ritz/programming/ai-stuff/project-file-server.html` |

## Configuration

The library has hardcoded paths that can be modified:

```lua
-- Line 8: Base path for shared libraries
local SCRIPT_DIR = "/home/ritz/programming/ai-stuff"

-- Line 659: Root directory to scan
local programming_root = "/mnt/mtwo/programming"
```

## Origin

Originally created as part of the **neocities-modernization** project (Issue 2-015) to provide a local file browsing interface. Migrated to shared utilities during project cleanup (Issue 8-009) on 2025-12-17.

## Related Documents

- `/home/ritz/programming/ai-stuff/neocities-modernization/issues/completed/2-015-implement-local-project-file-server.md`
- `/home/ritz/programming/ai-stuff/neocities-modernization/issues/completed/8-009-project-cleanup-and-organization.md`
