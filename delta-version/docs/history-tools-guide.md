# Delta-Version History Management Tools

This guide documents the history reconstruction and narrative generation tools that transform flat project imports into story-like git histories.

## Overview

Delta-version provides two complementary tools for managing project histories:

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `reconstruct-history.sh` | Create git history from issue files | Projects without git, or with "blob" imports |
| `generate-history.sh` | Generate readable HISTORY.txt files | Any project with git commits |

Together, these tools fulfill the CLAUDE.md requirement:
> "git log should be appended to a long history file... prettified... that can be grepped through easily. Or, printed and read like a book."

---

## Tool 1: reconstruct-history.sh

### Purpose

Transforms projects with no git history (or flat "blob" imports) into repositories with meaningful, story-like commit histories based on issue files.

### The Problem It Solves

Many projects in the monorepo exist as single "initial commit" blobs:
```
commit abc123 "Initial import"
  └── 6000 files added at once
```

This obscures development history and makes `git log` and `git blame` useless.

### The Solution

Creates commits in narrative order:
```
commit 1: "Initial vision" (notes/vision.md)
commit 2: "Issue 001: Setup infrastructure"
commit 3: "Issue 002: Core module implementation"
...
commit N: "Import remaining files"
```

### Core Functions

#### Project Detection (035a)

```bash
# Determine what state a project is in
determine_project_state "$project_dir"
```

Returns one of:
- `external` - Project is outside monorepo (will be imported)
- `no_git` - No git history exists (create from scratch)
- `flat_blob` - Few commits with many files (needs reconstruction)
- `sparse_history` - Some commits but poor quality
- `good_history` - Healthy commit/file ratio (skip unless --force)

**Detection logic:**
```bash
# Flat blob heuristic
has_flat_history() {
    local commits=$(git rev-list --count HEAD)
    local files=$(git ls-files | wc -l)

    # ≤2 commits with >50 files = flat blob
    [[ "$commits" -le 2 && "$files" -gt 50 ]]
}
```

#### Dependency Graph (035b)

Issues aren't always numbered in the order they should be committed. Issue 005 might depend on Issue 007.

```bash
# Parse dependency fields from issue files
parse_issue_dependencies "$issue_file"
# Returns: "001 002 003" (space-separated issue IDs)

# Build complete dependency graph
build_dependency_graph "$issues_dir"
# Output: "issue_id:dep1 dep2 dep3" per line

# Sort issues respecting dependencies
topological_sort_issues < graph_input
# Output: Issues in correct order
```

**Supported dependency fields:**
```markdown
- **Dependencies**: 001, 002
- **Blocked By**: Issue 003
- **Blocks**: 005, 006  (reverse - adds this as dependency of 005/006)
```

**Algorithm:** Uses Kahn's algorithm for topological sorting:
1. Build directed graph from dependency relationships
2. Initialize queue with issues having no dependencies
3. Process queue: output issue, decrement dependents' in-degrees
4. When issue reaches in-degree 0, add to queue
5. Sort ties by issue number for deterministic output

#### Date Estimation (035c)

Commits should have realistic dates reflecting when work was actually done.

```bash
# Estimate date for a single issue
estimate_issue_date "$issue_file"
# Returns: epoch timestamp

# Interpolate dates to ensure chronological order
printf '%s\n' "${issues[@]}" | interpolate_dates
# Output: "filepath:epoch:source" per line
```

**Date source priority:**
1. **Explicit dates** - Parse "Completed: 2024-12-15" from issue content
2. **File mtime** - Use modification time from filesystem
3. **Interpolation** - Add 1 hour to previous issue's date
4. **Current time** - Last resort fallback

**Sanity checks:**
- No future dates (clamped to now)
- No dates before 2020 (clamped to minimum)
- Out-of-order dates are interpolated forward

### Usage Examples

```bash
# Preview what would happen (always do this first!)
./reconstruct-history.sh --dry-run /path/to/project

# Reconstruct history for a project
./reconstruct-history.sh /path/to/project

# Import external project and reconstruct
./reconstruct-history.sh /external/project

# Import with custom name
./reconstruct-history.sh --name my-project /external/project

# Force reconstruction (removes existing .git)
./reconstruct-history.sh --force /path/to/project

# Interactive selection from available projects
./reconstruct-history.sh -I
```

### Dry Run Output Example

```
=== DRY RUN MODE ===

Project Analysis:
  Name:      my-project
  Directory: /path/to/my-project
  State:     no_git

Planned Reconstruction:

  Commit 1 - Vision:
    + notes/vision.md @ 2024-06-15

  Commits 2..N - Completed Issues (dependency-ordered with dates):
    [2] 001-setup-infrastructure (depends on: none) @ 2024-06-20 [explicit]
        "Issue 001: Setup Infrastructure"
    [3] 002-core-module (depends on: 001) @ 2024-07-01 [mtime]
        "Issue 002: Implement Core Module"
    [4] 003-cli-interface (depends on: 001 002) @ 2024-07-15 [interpolated]
        "Issue 003: Create CLI Interface"

  Final Commit - Remaining Files:
    ~150 files in ~12 directories

Total commits that would be created: 5
```

---

## Tool 2: generate-history.sh

### Purpose

Creates human-readable HISTORY.txt files from git log that can be "printed and read like a book."

### The Problem It Solves

Git log output is optimized for developers, not narrative reading:
- Reverse chronological (newest first)
- Dense metadata (hashes, timestamps)
- No visual separation
- Requires manual effort to create documentation

### The Solution

Generates formatted history documents:
```
================================================================================
                      MY-PROJECT - Development History
================================================================================

This document traces the development of my-project from inception to present.
Generated: 2024-12-17 14:30:00

--------------------------------------------------------------------------------

[1] Initial vision: Project purpose and goals
    2024-06-15

    Establishes the foundational vision for this project.

--------------------------------------------------------------------------------

[2] Issue 001: Setup Infrastructure
    2024-06-20

    Adds the base configuration and directory structure:
    - Created src/, docs/, libs/ directories
    - Added initial configuration files
    - Set up build system

--------------------------------------------------------------------------------

... (continues chronologically)

================================================================================
                                 End of History
                              47 commits recorded
                         (2024-06-15 to 2024-12-17)
================================================================================
```

### Core Functions

#### Commit Extraction

```bash
# Get all commits for a project in chronological order
get_project_commits "$project_name"
# Output: "hash|date|subject" per line

# Get commit body separately
get_commit_body "$hash"
# Returns: Multi-line commit body text
```

#### Filtering

```bash
# Should this commit be skipped based on filters?
should_skip_commit "$hash" "$project_name"
# Returns: 0 (skip) or 1 (include)
```

**Filter options:**
- `--skip-specs` - Hide commits that only add issue specifications (issues/*.md)
- `--completed-only` - Show only commits touching issues/completed/

**Rationale:** Creating an issue spec is planning; completing work is implementation. The history narrative should focus on actual work done.

#### Formatting

```bash
# Format a single commit for text output
format_commit_txt "$index" "$date" "$subject" "$body"

# Format for markdown output
format_commit_md "$index" "$date" "$subject" "$body"
```

### Usage Examples

```bash
# Generate for all projects
./generate-history.sh --all

# Generate for specific project
./generate-history.sh --project delta-version

# Generate markdown format
./generate-history.sh --all --format md

# Only show completed work (skip planning commits)
./generate-history.sh --all --skip-specs

# Preview without creating files
./generate-history.sh --all --dry-run

# Interactive project selection
./generate-history.sh -I
```

### Output Formats

| Format | Extension | Use Case |
|--------|-----------|----------|
| txt | .txt | Plain text, maximum portability, grep-friendly |
| md | .md | Markdown, renders nicely on GitHub/GitLab |

### Dry Run Output Example

```
┌─────────────────────────────────────────────────────────────────────────────
│ PROJECT: delta-version
├─────────────────────────────────────────────────────────────────────────────
│ Output:  /path/to/delta-version/docs/HISTORY.txt
│ Format:  txt
│
│ Commits: 8 included, 0 skipped (of 8 total)
│ Range:   2024-12-15 to 2024-12-17
│
│ Commits to include:
│   [ 1] Initial commit: AI project collection
│   [ 2] Add donation/support links issue and update document...
│   [ 3] Add economic incentive system issues (033, 034)
│   [ 4] Issue 035a: Implement project detection and external...
│   ... and 4 more commits
└─────────────────────────────────────────────────────────────────────────────
```

---

## How The Tools Work Together

### Workflow for New Projects

```
1. Project with no git history
        │
        ▼
   reconstruct-history.sh
        │
        ├── Detects project state (no_git)
        ├── Finds vision file
        ├── Discovers completed issues
        ├── Orders by dependencies (topological sort)
        ├── Estimates dates (explicit → mtime → interpolate)
        └── Creates commits with proper dates
        │
        ▼
   Project now has meaningful git history
        │
        ▼
   generate-history.sh
        │
        ├── Reads git log (chronological)
        ├── Applies filters (skip-specs, etc.)
        ├── Formats as readable narrative
        └── Outputs to docs/HISTORY.txt
        │
        ▼
   Human-readable history document
```

### Workflow for Existing Projects

```
   Project with existing git history
        │
        ▼
   generate-history.sh (directly)
        │
        └── Creates docs/HISTORY.txt from existing commits
```

---

## Configuration

Both scripts use the `DIR` variable for the monorepo root:

```bash
# Default
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"

# Override for different location
DIR=/other/path ./generate-history.sh --all
```

### reconstruct-history.sh Thresholds

```bash
# A project is "flat blob" if:
FLAT_BLOB_THRESHOLD=2       # ≤2 commits
FLAT_BLOB_MIN_FILES=50      # AND >50 files

# A project has "good history" if:
GOOD_HISTORY_RATIO=20       # ≥1 commit per 20 files AND >5 commits
```

---

## Best Practices

### Before Reconstruction

1. **Always dry-run first**: `--dry-run` shows exactly what will happen
2. **Check for post-blob commits**: Real work after a blob import will be preserved (but warns you)
3. **Back up if uncertain**: The script creates orphan branches, but better safe than sorry

### Issue File Conventions

For best results, completed issues should include:

```markdown
# Issue 001: Setup Infrastructure

## Metadata
- **Dependencies**: None
- **Blocks**: 002, 003
- **Completed**: 2024-06-20

## Current Behavior
...

## Intended Behavior
...
```

### Vision File Location

The script searches in priority order:
1. `notes/vision.md`
2. `notes/vision`
3. `vision.md`
4. `vision`
5. `docs/vision.md`
6. `docs/vision`
7. Any file matching `vision-*`

---

## Troubleshooting

### "Project already has git history"

Use `--force` to override, but note this deletes existing history:
```bash
./reconstruct-history.sh --force /path/to/project
```

### Issues appearing in wrong order

Check the dependency fields in your issue files. Use `--verbose` to see the dependency graph being built:
```bash
./reconstruct-history.sh --verbose --dry-run /path/to/project
```

### Dates seem wrong

Use `--verbose` to see date sources:
```
[INFO]   Date for 001-setup.md: explicit (1718496000)
[INFO]   Date for 002-core.md: mtime (1719792000)
[INFO]   Date for 003-cli.md: interpolated (1719795600)
```

If dates are from mtime but seem wrong, check if files were copied without preserving timestamps. The `cp -a` flag preserves timestamps.

### "No completed issues found"

Ensure issues are in `issues/completed/` directory with names matching `NNN-*.md` pattern:
```
issues/
└── completed/
    ├── 001-setup-infrastructure.md
    ├── 002-core-module.md
    └── 003-cli-interface.md
```

---

## Future Development

Remaining sub-issues for Issue 035:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| 035d | File-to-issue association | Pending |
| 035e | History rewriting with rebase | Pending |
| 035f | Local LLM integration | Pending (optional) |

**035d** will associate source files with the issues that created them, so commits include both the issue file AND the relevant source code.

**035e** will handle projects with some post-blob commits that need to be preserved and rebased onto the reconstructed history.

**035f** (optional) will use local LLM to resolve ambiguous decisions with a triple-check pattern for consistency.

---

## Related Documents

- [PRIORITY.md](../issues/PRIORITY.md) - Issue prioritization and blocking relationships
- [progress.md](../issues/progress.md) - Overall project progress tracking
- [Issue 035](../issues/035-project-history-reconstruction.md) - Full specification
- [Issue 037](../issues/completed/037-project-history-narrative-generator.md) - History generator spec
