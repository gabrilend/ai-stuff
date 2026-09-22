# git-history.sh

Generates prettified commit logs segmented by project phase. Outputs human-readable markdown files preserving statistics and metadata. Works on any project that keeps issue files named by phase (`522-fix-update-script.md`, `A03-test-runner.md`, or files under `issues/phase-N/`), whether the project is its own repository or one folder of a monorepo.

## Use Cases

### Generate History for a Specific Phase
Extract all commits related to Phase 2 implementation.

```bash
./git-history.sh -p 2
```

### Generate History for All Phases
Create separate history files for each detected phase.

```bash
./git-history.sh -a
```

### Include Detailed Statistics
Add commit counts, lines added/removed, and date ranges.

```bash
./git-history.sh -a -s
```

### Filter by Date Range
Generate history for recent work only.

```bash
./git-history.sh -p 3 --since "2 weeks ago"
./git-history.sh -a --since "2024-01-01" --until "2024-06-30"
```

### Interactive Phase Selection
Use TUI to select which phases to export.

```bash
./git-history.sh -I
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `-d, --dir <path>` | Project directory (default: current) |
| `-o, --output <dir>` | Output directory (default: `docs/history`) |
| `-p, --phase <n>` | Generate for specific phase (0, 1, 2, A, etc.) |
| `-a, --all` | Generate for all detected phases |
| `-s, --stats` | Include detailed statistics table |
| `--since <date>` | Only commits after date (git date format) |
| `--until <date>` | Only commits before date |
| `-I, --interactive` | TUI mode for selecting phases |
| `-h, --help` | Show help message |

## Capabilities

- **Phase Detection**: A commit belongs to a phase when it touches one of that phase's issue files -- editing it, or moving it into `issues/completed/` when the work is done. The phase comes from the issue filename (or its `phase-N/` folder). Commit messages are not read, because the house style writes them in plain English with no issue numbers. See the comment above `git_history_phase_of_issue_path` in the script for every filename shape and the open question about four-digit numbers.
- **Project-Scoped Statistics**: In a monorepo, line counts and changed-file lists cover only the project's own folder, not the whole commit.
- **Automatic Phase Discovery**: Scans commit history to find all phases present
- **Markdown Output**: Creates `docs/history/phase-X-commits.md` files
- **File Change Tracking**: Lists modified files with status (A/M/D)
- **Statistics Summary**: Tracks insertions, deletions, date ranges

## Output Format

Each phase history file contains:

```markdown
# Phase 2 - Commit History

Generated: 2024-12-27 14:00:00

## Statistics

| Metric | Value |
|--------|-------|
| Commits | 15 |
| Lines Added | +1234 |
| Lines Removed | -567 |
| Date Range | 2024-12-01 to 2024-12-15 |

## Commits

Total: 15 commits

---

## [a1b2c3d] The parser reads the core grammar

**Date:** 2024-12-01 | **Author:** ritz <ritz@example.com>

Description of the changes...

**Files changed:**
```
M       src/parser.lua
A       src/lexer.lua
```

*3 files changed, 150 insertions(+), 20 deletions(-)*

---
```

## Library Usage

The script can be sourced for programmatic use:

```bash
source /path/to/scripts/git-history.sh
git_history_init "$PROJECT_DIR"
commits=$(git_history_get_phase_commits 2)
git_history_format_markdown 2 > output.md
```

### Library Functions

| Function | Description |
|----------|-------------|
| `git_history_init <dir>` | Initialize with project directory |
| `git_history_get_phases` | Detect all phases in commit history |
| `git_history_get_phase_commits <phase>` | Get commit hashes for a phase |
| `git_history_format_commit <hash>` | Format a single commit as markdown |
| `git_history_format_markdown <phase>` | Generate full markdown document |
| `git_history_get_stats <phase>` | Get statistics for a phase |

## Related Scripts

- `progress-dashboard.lua` - Track issue completion (complements commit history)
- `issue-splitter.sh` - Manage issue files that commits reference
