# Scripts Directory

Central repository for reusable shell and Lua scripts used across AI-assisted programming projects.

## Main Scripts

### issue-splitter.sh
Iterates through issue files and uses Claude Code to suggest sub-issue splits. Appends analysis to each issue file and supports creating sub-issue skeleton files.

**Features:**
- Interactive TUI mode with lua-menu integration
- Parallel streaming mode for batch processing
- Session mode for context reuse across issues
- Feedback loop for iterative refinement
- Archive mode for preserving analyses

**Usage:**
```bash
./issue-splitter.sh -I                    # Interactive mode
./issue-splitter.sh --dir /path/to/project
./issue-splitter.sh -x                    # Execute recommendations (create sub-issues)
./issue-splitter.sh -G                    # Generate complete issue files via Claude
```

### progress-dashboard.lua
Scans issue directories and generates progress statistics with ASCII visualizations. Works on any project following the phase-based issue naming convention (e.g., `301-feature-name.md`).

**Usage:**
```bash
lua progress-dashboard.lua -d /path/to/project    # Terminal output
lua progress-dashboard.lua -m                      # Markdown output
lua progress-dashboard.lua -p 3                    # Show only phase 3
```

### git-history.sh
Generates prettified commit logs segmented by project phase. Outputs human-readable markdown files preserving statistics and metadata.

**Usage:**
```bash
./git-history.sh -p 2           # Generate for phase 2
./git-history.sh -a             # All phases
./git-history.sh -I             # Interactive TUI mode
```

### sync-visions.sh
Discovers and symlinks vision documents from all projects into a centralized `visions/` directory. Provides statistics on documentation coverage.

**Usage:**
```bash
./sync-visions.sh                     # Scan default directory
./sync-visions.sh -v                  # Verbose output
./sync-visions.sh --stats             # Show statistics only
```

### state-daemon.sh
A background service that holds key-value state in RAM using FIFO pipes for IPC. Enables inter-script communication without file-based locking.

**Usage:**
```bash
./state-daemon.sh start               # Start daemon
./state-daemon.sh set KEY VALUE       # Set value
./state-daemon.sh get KEY             # Get value
./state-daemon.sh list                # List all keys
./state-daemon.sh stop                # Stop daemon
```

### backup-conversations
Extracts Claude conversation transcripts from `~/.claude/projects/` and writes summaries to project-specific `llm-transcripts/` directories. Filters intermediate problem-solving dialogue for clarity.

**Usage:**
```bash
./backup-conversations /path/to/project
```

### claude-conversation-exporter.sh
Full-featured conversation export with per-project output paths, verbosity controls, and stored configuration. Supports TUI-based project selection.

**Usage:**
```bash
./claude-conversation-exporter.sh               # Interactive project selection
./claude-conversation-exporter.sh -v 3          # High verbosity
```

### project-file-server
Generates a pure HTML interface for browsing programming projects in a tree structure. Uses native `<details>`/`<summary>` elements for collapsible folders.

**Usage:**
```bash
./project-file-server /path/to/projects         # Scan directory
./project-file-server -I                        # Interactive mode
./project-file-server -o ~/server.html          # Custom output file
```

### filesystem_scanner.sh
Scans filesystem hierarchy and generates a text-based tree. Supports cron scheduling for periodic scans.

**Usage:**
```bash
./filesystem_scanner.sh /path/to/scan
```

---

## Libraries (`libs/`)

### TUI Components

| File | Description |
|------|-------------|
| `menu.lua` | Interactive menu with vim keybindings, checkbox/flag/multistate items, content preview panel |
| `lua-menu.sh` | Bash wrapper providing API-compatible functions with `menu.sh` using Lua backend |
| `tui.lua` | Framebuffer-based TUI rendering engine |
| `input-dialog.lua` | Input dialog component for text entry |
| `menu-runner.lua` | Standalone runner for menu configurations |
| `project-file-server.lua` | Core logic for HTML file browser generation |

### Legacy Bash TUI (deprecated in favor of Lua)

| File | Description |
|------|-------------|
| `menu.sh` | Original bash menu implementation |
| `checkbox.sh` | Checkbox selection component |
| `input.sh` | Text input component |
| `multistate.sh` | Multi-state toggle component |

### Test Scripts

| File | Description |
|------|-------------|
| `test-lua-menu.sh` | Test suite for Lua menu |
| `test-menu.sh` | Test suite for bash menu |
| `test-checkbox.sh` | Checkbox component tests |
| `test-input.sh` | Input component tests |
| `test-multistate.sh` | Multistate component tests |

---

## Project-Specific Scripts (Abstraction Candidates)

The following scripts from other projects contain reusable patterns that could be abstracted into this directory.

### delta-version/scripts/

| Script | Purpose | Abstraction Potential |
|--------|---------|----------------------|
| [list-projects.sh](../delta-version/scripts/list-projects.sh) | Project directory discovery with scoring heuristics | High - generic project detection based on file patterns |
| [manage-issues.sh](../delta-version/scripts/manage-issues.sh) | Issue creation, validation, completion, search | High - complements issue-splitter.sh |
| [generate-history.sh](../delta-version/scripts/generate-history.sh) | Git history generation | Medium - similar to git-history.sh, consider merging |
| [validate-repository.sh](../delta-version/scripts/validate-repository.sh) | Repository health checks | Medium - useful for all projects |
| [maintain-gitignore.sh](../delta-version/scripts/maintain-gitignore.sh) | Gitignore pattern management | Medium - cross-project gitignore handling |

### neocities-modernization/scripts/

| Script | Purpose | Abstraction Potential |
|--------|---------|----------------------|
| [generate-html-parallel](../neocities-modernization/scripts/generate-html-parallel) | Multi-threaded processing with effil | High - parallel worker pattern is reusable |
| [precompute-diversity-sequences](../neocities-modernization/scripts/precompute-diversity-sequences) | Incremental batch processing with thermal management | Medium - batch processing with sleep patterns |

### handheld-office/scripts/

| Script | Purpose | Abstraction Potential |
|--------|---------|----------------------|
| [orchestrator.lua](../handheld-office/scripts/orchestrator.lua) | Multi-component build orchestration | High - generic component lifecycle management |
| [build.sh](../handheld-office/scripts/build.sh) | Rust/Cargo build wrapper | Low - project-specific |

### RPG-autobattler/libs/scripts/

| Script | Purpose | Abstraction Potential |
|--------|---------|----------------------|
| [build-all.sh](../RPG-autobattler/libs/scripts/build-all.sh) | Master dependency builder | Medium - dependency build orchestration pattern |

---

## Suggested Improvements

### 1. Integrate menu-tui into more scripts

The `lua-menu.sh` / `menu.lua` library provides a robust interactive interface. Scripts that currently use simple argument parsing could benefit from TUI mode:

- **filesystem_scanner.sh** - Add `-I` for directory selection and cron configuration
- **sync-visions.sh** - Add `-I` for selecting which projects to sync
- **state-daemon.sh** - Add `-I` for interactive key browsing and editing
- **backup-conversations** - Add `-I` for project selection with preview

### 2. Create abstract project-list library

Extract the project discovery logic from `delta-version/scripts/list-projects.sh` into a reusable `libs/project-discovery.sh`:

```bash
source libs/project-discovery.sh
list_projects "/path/to/base"
for project in "${DISCOVERED_PROJECTS[@]}"; do
    echo "Found: $project (score: ${PROJECT_SCORES[$project]})"
done
```

### 3. Create parallel-worker library

Extract the effil-based parallel processing pattern from `neocities-modernization/scripts/generate-html-parallel` into `libs/parallel-worker.lua`:

```lua
local parallel = require("libs/parallel-worker")
parallel.init({threads = 8, thermal_sleep = 0.1})
parallel.map(items, function(item)
    return process(item)
end)
```

### 4. Create issue-manager library

Extract core issue management functions from `delta-version/scripts/manage-issues.sh` into `libs/issue-manager.sh`:

```bash
source libs/issue-manager.sh
issue_init "/path/to/project"
next_id=$(issue_get_next_id)
issue_create "301" "implement-feature" "Description..."
issue_complete "301"
```

### 5. Create component-orchestrator library

Abstract the multi-component lifecycle from `handheld-office/scripts/orchestrator.lua`:

```lua
local orchestrator = require("libs/component-orchestrator")
orchestrator.register("daemon", {binary = "target/daemon", port = 8080})
orchestrator.register("client", {binary = "target/client"})
orchestrator.start_all()
orchestrator.health_check()
```

---

## Design Conventions

All scripts follow these patterns per `~/.claude/CLAUDE.md`:

1. **DIR variable at top** - Hard-coded default with argument override
2. **Vim folds** - Functions wrapped in `-- {{{ function_name` and `-- }}}`
3. **Header comment** - Brief explanation of purpose for executives
4. **Prefer Lua (LuaJIT)** - Python and Lua 5.4 syntax avoided
5. **Error over fallback** - Explicit failures rather than silent degradation
6. **Issue-driven changes** - No changes without corresponding issue file

---

## Related Directories

- `libs/` - Shared library code
- `issues/` - Issue tracking for scripts project itself
- `visions/` - Symlinked vision documents from all projects
- `debug/` - Debug utilities and logs
- `poem-context-generator/` - Poetry-specific context generation
- `world-edit-to-execute/` - Warcraft 3 trigger system scripts
