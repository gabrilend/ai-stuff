# Issue A01: Git History Prettifier

**Phase:** A - Infrastructure Tools
**Type:** Tool
**Priority:** Medium
**Dependencies:** None

---

## Current Behavior

`scripts/git-history.sh` exists and writes one markdown file per phase
(`docs/history/phase-X-commits.md`, or wherever `-o` points), with optional
statistics, date filters, and a TUI picker. It works as a CLI and can be
sourced as a library.

Phase is decided by the issue files a commit touched, not by the commit
message. The first version read "Issue 204:" / "Phase 2:" out of commit
subjects; once the house commit style became plain English with no issue
numbers, no commit matched and every phase came out empty. Every finished
piece of work still edits its issue file and moves it into
`issues/completed/`, and the filename (or a `phase-N/` folder) names the
phase, so that is what the tool reads now -- one `git log --name-status`
pass over the project's `issues/` folder.

It finds the repository root through git, so a project that is one folder
of the monorepo works, and its line statistics cover only that folder.
Verified against delta-version (phases 0, 1, 2, A) and soren-ds (phases
through 10), writing into a scratch folder.

Not yet done: the per-project `src/cli/` symlink, incremental updates
(every run rewrites the files whole).

**Open question (owner):** in a four-digit issue number such as `1001`,
is the phase `10` (issue 01) or `1` (issue 001)? The tool reads it as
phase 10 because soren-ds, the one project past phase 9, named its files
that way. `progress-dashboard.lua` must use the same rule; until the
convention is written down in CLAUDE.md, the two tools can only agree by
copying each other.

---

## Intended Behavior

A project-abstract tool that:
- Generates prettified commit logs segmented by phase
- Outputs human-readable markdown files
- Preserves statistics and metadata
- Creates greppable, book-like history documents
- Works across any project following the issue naming convention

---

## Suggested Implementation Steps

1. **Create shared script**
   ```
   /home/ritz/programming/ai-stuff/scripts/git-history.sh
   ```
   Symlinked into projects as `src/cli/git-history.sh`

2. **Define configuration interface**
   ```bash
   # Project-specific config (passed as args or sourced from .git-history.conf)
   PROJECT_DIR=""           # Project root
   OUTPUT_DIR=""            # Where to write history files (default: docs/history/)
   PHASE_PATTERN=""         # Regex to detect phase from commit messages
   ISSUE_PATTERN=""         # Regex to extract issue IDs
   ```

3. **Implement phase detection**
   ```bash
   # Default pattern: "Issue XXX:" or "Phase X:" in commit messages
   # Extract phase from issue number (1XX = Phase 1, 2XX = Phase 2, etc.)
   detect_phase_from_commit() {
       local message="$1"
       # Parse "Issue 204:" -> Phase 2
       # Parse "Phase A:" -> Phase A
   }
   ```

4. **Implement commit formatting**
   ```bash
   format_commit() {
       local hash="$1"
       local date="$2"
       local author="$3"
       local subject="$4"
       local body="$5"
       local files_changed="$6"

       # Output markdown format:
       # ## [abc1234] Subject Line
       # **Date:** 2025-12-16 | **Author:** Name
       #
       # Body text...
       #
       # **Files changed:**
       # - path/to/file.lua (+10, -5)
   }
   ```

5. **Implement phase file generation**
   ```bash
   generate_phase_history() {
       local phase="$1"
       local output_file="${OUTPUT_DIR}/phase-${phase}-commits.md"

       # Header
       echo "# Phase ${phase} - Commit History"
       echo ""
       echo "Generated: $(date)"
       echo "Total commits: $(count_phase_commits $phase)"
       echo ""

       # Commits in reverse chronological order
       for commit in $(get_commits_for_phase $phase); do
           format_commit $commit
       done
   }
   ```

6. **Implement statistics summary**
   ```bash
   generate_statistics() {
       # Per-phase stats:
       # - Commit count
       # - Lines added/removed
       # - Files touched
       # - Date range
       # - Top contributors
   }
   ```

7. **Add CLI interface**
   ```bash
   # Modes:
   # -a, --all           Generate history for all phases
   # -p, --phase X       Generate for specific phase
   # -s, --stats         Include statistics summary
   # -o, --output DIR    Output directory
   # -I, --interactive   TUI mode for selecting phases
   # --since DATE        Only commits after date
   # --until DATE        Only commits before date
   ```

8. **Support incremental updates**
   ```bash
   # Track last processed commit per phase
   # Only append new commits on subsequent runs
   # Store state in .git-history-state
   ```

---

## Library Design

The script should be usable as both CLI tool and sourceable library:

```bash
# As CLI
./git-history.sh -p 2 -o docs/history/

# As library
source /path/to/scripts/git-history.sh
git_history_init "$PROJECT_DIR"
commits=$(git_history_get_phase_commits 2)
git_history_format_markdown "$commits" > output.md
```

### Exported Functions

| Function | Description |
|----------|-------------|
| `git_history_init` | Initialize with project directory |
| `git_history_detect_phase` | Detect phase from commit message |
| `git_history_get_phase_commits` | Get commits for a phase |
| `git_history_format_markdown` | Format commits as markdown |
| `git_history_format_plain` | Format commits as plain text |
| `git_history_get_stats` | Get statistics for phase/project |

---

## Output Format

```markdown
# Phase 2 - Commit History

Generated: 2025-12-16T19:30:00
Commits: 15 | Lines: +2,450 / -320 | Files: 45

---

## [4d13b5a4] Issue 204: Implement war3map.w3c camera parser

**Date:** 2025-12-16 19:33 | **Author:** User Name

Add parser for WC3 camera preset files with support for both
standard (pre-1.31) and extended (1.31+) formats.

**Files changed:** (5 files, +667, -14)
- `src/parsers/w3c.lua` (+180)
- `src/tests/test_w3c.lua` (+250)
- `issues/progress.md` (+15, -5)
...

---

## [0eef48d6] Issue 203: Implement war3map.w3r region parser
...
```

---

## Related Documents

- CLAUDE.md (requirement source)
- docs/history/ (output location)
- /home/ritz/programming/ai-stuff/scripts/ (shared scripts location)

---

## Acceptance Criteria

- [x] Script lives in shared scripts directory
- [ ] Symlink created in project src/cli/
- [x] Detects phases from the issue files each commit touches
- [x] Generates per-phase markdown files
- [x] Includes commit statistics (scoped to the project folder)
- [x] Includes file change details
- [ ] Supports incremental updates
- [x] Works as both CLI and library
- [x] Interactive mode with TUI
- [x] Project-abstract (works on any conforming project, monorepo or not)

---

## Notes

This tool fulfills the CLAUDE.md requirement for commit history files.
The phase detection should be configurable to support different naming
conventions across projects.

Consider integrating with the issue-splitter.sh for consistent styling
and TUI patterns.
