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

Automated tool for analyzing issues and managing sub-issue creation.

#### Capabilities

| Mode | Description |
|------|-------------|
| **Analyze** | Ask Claude to evaluate if issue should be split |
| **Review** | Review root issues that already have sub-issues |
| **Execute** | Create sub-issue files from analysis recommendations (planned) |

#### Usage

```bash
# Interactive mode - select issues and options via menu
./src/cli/issue-splitter.sh -I

# Analyze all issues, skip those with existing analysis
./src/cli/issue-splitter.sh -s

# Review-only mode (just review roots with sub-issues)
./src/cli/issue-splitter.sh -r

# Dry run (preview what would be processed)
./src/cli/issue-splitter.sh -n

# Archive copies of analyses to issues/analysis/
./src/cli/issue-splitter.sh -a
```

#### Processing Phases

1. **Phase 1: Analysis** - Processes issues without sub-issues
   - Skips sub-issues (102a, 102b, etc.)
   - Skips roots that already have sub-issues (deferred to Phase 2)
   - Appends `## Sub-Issue Analysis` to each processed issue

2. **Phase 2: Structure Review** - Reviews roots with existing sub-issues
   - Reads root issue + all its sub-issues
   - Appends `## Structure Review` with structural recommendations

#### Flags Reference

| Flag | Description |
|------|-------------|
| `-d, --dir <path>` | Project directory (default: world-edit-to-execute) |
| `-p, --pattern <glob>` | Issue file pattern (default: `[0-9]*.md`) |
| `-s, --skip-existing` | Skip issues that already have analysis |
| `-r, --review-only` | Only run Phase 2 (structure review) |
| `-n, --dry-run` | Show what would be processed |
| `-a, --archive` | Save copies to issues/analysis/ directory |
| `-I, --interactive` | Interactive mode with menus |
| `-h, --help` | Show help |

### Planned Tool Enhancements (Phase 0)

| Feature | Issue | Status |
|---------|-------|--------|
| Execute mode (auto-create sub-issues) | 003 | Pending |
| Streaming queue (parallel processing) | 002 | In Progress |
| Checkbox-style TUI | 004 | Pending |
| Shared TUI library | 005 | Pending |
| Analysis section renaming | 006 | Pending |

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
