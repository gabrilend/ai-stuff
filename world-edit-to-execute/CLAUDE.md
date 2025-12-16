# World Edit to Execute - Project Instructions

## Project Overview

A WC3-compatible game engine that reads Warcraft 3 map files (.w3x/.w3m) like an emulator reads ROMs. See `notes/vision` for full philosophy.

## Key Documents

- `notes/vision` - Project philosophy and legal basis
- `docs/roadmap.md` - Development phases and **current focus/next steps**
- `docs/table-of-contents.md` - Documentation index
- `issues/progress.md` - Current phase status and issue tracking

---

## Issue Management Workflow

### Philosophy

Every change to the project must have an associated issue file. Issues are treated as
immutable records - they can be appended to but content is never deleted. This preserves
the history of decisions and allows reconstruction of the project's evolution.

### Iterative Development & Interface-First Design

**Core principle:** If the design/interface is in place, move on to the next issue.

When implementing a feature or component:

1. **Establish the interface first** - Define the public API, function signatures, and
   expected behavior before perfecting internal implementation details.

2. **Bugs in implementation are acceptable** - As long as the interface is correct,
   internal bugs can be treated as "unfixed bugs" that get patched in future iterations.
   The interface contract allows other components to be built in parallel.

3. **Iterate through issues, don't block** - It's better to complete a pass through all
   issues with working-but-imperfect implementations than to block on perfecting one
   component. Each pass through the issues directory is an opportunity to refine.

4. **Track refinements as sub-issues or notes** - When moving on despite known issues:
   - Add a note to the Implementation Notes section
   - Create a sub-issue for significant bugs
   - Or simply plan to address it on the next iteration

This approach enables:
- Parallel progress on dependent components
- Early integration testing of the full system
- Natural prioritization (frequently-hit bugs surface quickly)
- Avoiding premature optimization

**Example:** A TUI library with correct interfaces but minor rendering bugs can still
be integrated into tools. The integration will reveal which bugs matter most, guiding
the next iteration's priorities.

### Workflow Stages

```
1. ANALYZE    ──▶  2. REVIEW    ──▶  3. EXECUTE     ──▶  4. IMPLEMENT
   (Claude)           (Human)           (Tool/Human)        (Claude)

2. THINK      ──▶  2. PROCESS    ──▶  3. VALIDATE   ──▶  4. EXECUTE 
   (Human/Claude)     (Computer)         (Tool/Human)       (Claude)

   Suggest          Approve/modify    Create sub-issue   Write code
   sub-issues       recommendations   files if needed    for each issue
```

### Issue Lifecycle

1. **Creation** - Issue file created with sections:
   - Current Behavior, Intended Behavior, Suggested Implementation Steps
   - Related Documents, Acceptance Criteria, Notes

2. **Analysis** - Issue-splitter analyzes if splitting is beneficial
   - Appends `## Sub-Issue Analysis` section with recommendations
   - May recommend: split into sub-issues, keep as-is, or defer

3. **Execution** (if splitting recommended)
   - Sub-issue files created from recommendations
   - Original analysis renamed to `## Initial Analysis`
   - `## Generated Sub-Issues` section added listing created files

4. **Structure Review** (for roots with sub-issues)
   - Phase 2 of issue-splitter reviews root + sub-issues together
   - Appends `## Structure Review` with structural recommendations

5. **Implementation** - Code written to satisfy acceptance criteria
   - `## Implementation Notes` appended documenting changes made
   - Acceptance criteria checkboxes marked

6. **Completion** - Issue moved to `issues/completed/`
   - Related issues updated to reflect new current behavior
   - Git commit made referencing the issue

### Section Types in Issue Files

| Section | When Added | Purpose |
|---------|------------|---------|
| `## Sub-Issue Analysis` | After initial analysis | Recommendations for splitting |
| `## Initial Analysis` | After sub-issues created | Renamed from Sub-Issue Analysis |
| `## Structure Review` | Phase 2 review | Review of root + existing sub-issues |
| `## Generated Sub-Issues` | After execution | List of created sub-issue files |
| `## Implementation Notes` | After coding | Documentation of changes made |

---

## Project Tools

### Issue Splitter (`src/cli/issue-splitter.sh`)

Location: `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` (symlinked)

Automated tool for analyzing issues, managing sub-issue creation, and implementing features.

#### Capabilities

| Mode | Description |
|------|-------------|
| **Analyze** | Ask Claude to evaluate if issue should be split |
| **Review** | Review root issues that already have sub-issues |
| **Execute** | Create sub-issue files from analysis recommendations |
| **Implement** | Auto-implement issues via Claude CLI |
| **Stream** | Parallel processing with real-time output streaming |

#### Quick Start

```bash
# Interactive mode - TUI with checkbox selection and vim keybindings
./src/cli/issue-splitter.sh -I

# Analyze issues with parallel processing (streaming mode)
./src/cli/issue-splitter.sh --stream --parallel 3

# Execute recommendations to create sub-issue files
./src/cli/issue-splitter.sh -x

# Auto-implement an issue via Claude CLI
./src/cli/issue-splitter.sh -A
```

#### Processing Modes

**1. Analysis Mode (default)**
```bash
./src/cli/issue-splitter.sh -s              # Skip already-analyzed issues
./src/cli/issue-splitter.sh --stream        # Use parallel processing
./src/cli/issue-splitter.sh --stream --parallel 5 --delay 2
```
- Processes issues without sub-issues
- Skips sub-issues (102a, 102b, etc.)
- Skips roots that already have sub-issues (deferred to review)
- Appends `## Sub-Issue Analysis` to each processed issue

**2. Review Mode**
```bash
./src/cli/issue-splitter.sh -r              # Review-only
./src/cli/issue-splitter.sh -r -s           # Skip already-reviewed
```
- Reviews root issues with existing sub-issues
- Reads root + all sub-issues together
- Appends `## Structure Review` with recommendations

**3. Execute Mode**
```bash
./src/cli/issue-splitter.sh -x              # With confirmation prompts
./src/cli/issue-splitter.sh -X              # Execute all without prompts
```
- Parses analysis recommendations from issue files
- Auto-creates sub-issue files from recommendations
- Renames `## Sub-Issue Analysis` to `## Initial Analysis`
- Adds `## Generated Sub-Issues` section

**4. Implement Mode**
```bash
./src/cli/issue-splitter.sh -A              # With confirmation
./src/cli/issue-splitter.sh -A -X           # Without confirmation
```
- Invokes Claude CLI with issue content
- Claude reads issue, implements code, updates issue file
- Uses `--dangerously-skip-permissions` for autonomous operation

**5. Interactive Mode**
```bash
./src/cli/issue-splitter.sh -I
```
- TUI with checkbox-style selection
- Vim keybindings (j/k navigation, i/space select, q quit)
- Select mode: Analyze, Review, Execute, or Implement
- Select options: Skip existing, Dry run, Archive, Execute all
- Select specific issues to process

#### Streaming Mode (Parallel Processing)

```bash
# Enable streaming with default settings (3 parallel, 5s delay)
./src/cli/issue-splitter.sh --stream

# Custom parallelism and delay
./src/cli/issue-splitter.sh --stream --parallel 5 --delay 2

# Streaming requires Bash 4.3+ (uses wait -n)
```

**How it works:**
1. Queue infrastructure creates temp directory for job coordination
2. Producer spawns parallel Claude calls (up to PARALLEL_COUNT)
3. Responses queued with .output, .meta, .ready files
4. Streamer displays outputs in order with formatted headers
5. Configurable delay between outputs ("grocery store divider" pattern)

#### Complete Flags Reference

| Flag | Description |
|------|-------------|
| `-d, --dir <path>` | Project directory (default: world-edit-to-execute) |
| `-p, --pattern <glob>` | Issue file pattern (default: `[0-9]*.md`) |
| `-s, --skip-existing` | Skip issues that already have analysis |
| `-r, --review-only` | Only run structure review (skip analysis) |
| `-n, --dry-run` | Show what would be processed |
| `-a, --archive` | Save copies to issues/analysis/ directory |
| `-x, --execute` | Execute recommendations (create sub-issues) |
| `-X, --execute-all` | Execute all without confirmation |
| `-A, --auto-implement` | Auto-implement issues via Claude CLI |
| `--stream` | Enable streaming mode with parallel processing |
| `--parallel <n>` | Max concurrent Claude calls (default: 3) |
| `--delay <n>` | Seconds between streamed outputs (default: 5) |
| `-I, --interactive` | Interactive mode with TUI menus |
| `-h, --help` | Show help |

### TUI Library (`/home/ritz/programming/ai-stuff/scripts/libs/`)

Shared terminal UI library for interactive scripts.

| Module | Description |
|--------|-------------|
| `tui.sh` | Core library (terminal modes, cursor, colors) |
| `checkbox.sh` | Checkbox component with selection state |
| `multistate.sh` | Multi-state toggle (radio button behavior) |
| `input.sh` | Text input component |
| `menu.sh` | Menu navigation with sections and vim keybindings |

**Usage in scripts:**
```bash
source "${LIBS_DIR}/tui.sh"
source "${LIBS_DIR}/menu.sh"

tui_init
menu_init
menu_set_title "My Tool" "Interactive Mode"
menu_add_section "options" "multi" "Options"
menu_add_item "options" "verbose" "Verbose" "checkbox" "0" "Enable verbose output"
menu_run
tui_cleanup
```

### Phase 0 Tool Summary (Completed)

| Feature | Issue | Status |
|---------|-------|--------|
| Direct output handling | 001 | **Completed** |
| Streaming queue (parallel processing) | 002 | **Completed** |
| Execute mode (auto-create sub-issues) | 003 | **Completed** |
| Checkbox-style TUI | 004 | **Completed** |
| Shared TUI library | 005 | **Completed** |
| Analysis section renaming | 006 | **Completed** |
| Auto-implement via Claude CLI | 007 | **Completed** |

## Issue Naming Convention

- Root issues: `{PHASE}{ID}-{description}.md` (e.g., `103-parse-war3map-w3i.md`)
- Sub-issues: `{PHASE}{ID}{letter}-{description}.md` (e.g., `102a-parse-mpq-header.md`)

Phase 1 = 1xx, Phase 2 = 2xx, etc.

## Implementation Language

Primary: **Lua** (with LuaJIT compatibility)

Chosen for:
- Native scripting integration (WC3 maps will be Lua-scriptable)
- Good binary parsing capabilities with string.unpack
- Cross-platform portability
- Existing ecosystem for game development
  - see /home/ritz/programming/ai-stuff/libs/lua/ for available libraries
  - can enable an Ollama server if requested to user
  - can provide samples of many types of input, including video, audio, and text

## Current Phase

**Phase 1: Foundation - File Format Parsing**

Focus on MPQ archive parsing and WC3 file format extraction before any gameplay logic.
