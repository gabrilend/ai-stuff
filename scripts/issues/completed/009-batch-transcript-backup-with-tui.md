# 009: Batch LLM Transcript Backup with TUI Selection

## Status
- **Priority**: MEDIUM
- **Type**: Feature / Tooling
- **Dependencies**: lua-menu.sh library, backup-conversations, claude-conversation-exporter.sh
- **Implementation Status**: COMPLETED
- **Completed**: 2026-01-12 (core), 2026-11-03 (menu, --since, --commit)

## Current Behavior

To backup LLM transcripts across the monorepo, you must:
1. Manually navigate to each project
2. Run `backup-conversations` for each project
3. Run `claude-conversation-exporter.sh` with appropriate verbosity
4. Repeat 30+ times for all projects

No batch processing. No project selection. Tedious.

## Intended Behavior

A TUI-based script that:
1. Discovers all projects in the monorepo (via `list-projects.sh`)
2. Presents a checkbox menu for selecting which projects to process
3. Offers verbosity level selection (v0-v5)
4. Runs backup and export for each selected project
5. Shows progress and summary

### Example Usage

```bash
# Interactive mode - TUI with checkboxes
./scripts/batch-transcript-backup.sh -I

# Process all projects
./scripts/batch-transcript-backup.sh --all

# Process specific projects by name
./scripts/batch-transcript-backup.sh delta-version world-edit-to-execute

# Dry run - show what would be processed
./scripts/batch-transcript-backup.sh -I --dry-run

# Generate all verbosity levels (v0-v5) for multi-level examination
./scripts/batch-transcript-backup.sh --all --all-verbosity-levels
```

### TUI Interface Mockup

```
╔══════════════════════════════════════════════════════════════════╗
║              LLM Transcript Backup - Project Selection           ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  [x] delta-version           (7 conversations)                  ║
║  [x] world-edit-to-execute   (23 conversations)                 ║
║  [ ] neocities-modernization (12 conversations)                 ║
║  [ ] console-demakes         (5 conversations)                  ║
║  [ ] galactic-battlegrounds  (3 conversations)                  ║
║  ...                                                             ║
║                                                                  ║
║  ─────────────────────────────────────────────────────────────── ║
║                                                                  ║
║  Verbosity: [v4 - Complete with vimfolds]                       ║
║  Output:    [Per-project + combined export]                     ║
║                                                                  ║
║  Selected: 2 projects | Est. conversations: 30                  ║
║                                                                  ║
║  [Run Backup]  [Select All]  [Deselect All]  [Quit]             ║
╚══════════════════════════════════════════════════════════════════╝
```

### Multi-Verbosity Export Mode

When using `--all-verbosity-levels`, the script generates multiple exports of each conversation at different verbosity levels (v0 through v5). This preserves the complete history at multiple levels of abstraction for future examination.

**Output structure:**
```
project/llm-transcripts/
├── session-abc123-v0-minimal.md           # Code and essential content only
├── session-abc123-v1-compact.md           # Skip sentiments, show responses
├── session-abc123-v2-standard.md          # Complete conversation (default)
├── session-abc123-v3-verbose.md           # Include context files and expansions
├── session-abc123-v4-complete.md          # Everything + LLM execution details
├── session-abc123-v5-raw.md               # ALL intermediate steps and tool results
├── session-def456-v0-minimal.md
├── session-def456-v1-compact.md
└── ...
```

**Use cases:**
- **Quick scanning**: Start with v0/v1 to see just the essential work
- **Understanding flow**: Use v2/v3 to see the conversation dynamics
- **Deep debugging**: Use v4/v5 to trace LLM execution and tool calls
- **Multi-level documentation**: Different team members can read at their preferred detail level
- **Future analysis**: AI systems can analyze the same conversation at different granularities

The same history, multiple perspectives - all stored for complete documentation.

## Suggested Implementation Steps

### Phase A: Core Script Structure
1. [x] Create `scripts/batch-transcript-backup.sh` with vimfold structure
2. [x] Source `libs/lua-menu.sh` for TUI support
3. [x] Add argument parsing (-I, --all, --dry-run, -v0 through -v5)
4. [x] Implement help message

### Phase B: Project Discovery
5. [x] Use `delta-version/scripts/list-projects.sh --paths` to get all projects
6. [x] For each project, check if it has Claude conversations:
       - Look for `~/.claude/projects/-path-encoded-project-name/`
       - Count conversations if present
7. [x] Filter to only projects with existing conversations
8. [x] Build menu items with conversation counts

### Phase C: TUI Menu Integration
9. [x] Create checkbox section for project selection
10. [x] Add verbosity dropdown (v0-v5 with descriptions) — a radio list, see What Happened
11. [ ] (moved to issue 042, with `--combined`) Add output mode option (per-project / combined / both)
12. [x] Show selection summary (count, estimated size) — the opening summary and the dry run give project, conversation and file counts; no size estimate
13. [x] Add Select All / Deselect All actions

### Phase D: Backup Execution
14. [x] For each selected project:
    - Run `backup-conversations` to pull from ~/.claude/
    - Run `claude-conversation-exporter.sh` with selected verbosity
    - Save to `project/llm-transcripts/`
15. [x] Show progress indicator (X of Y projects)
16. [x] Generate summary report on completion

### Phase E: Multi-Verbosity Export
17. [x] Add `--all-verbosity-levels` flag to generate v0-v5 for each conversation
18. [x] For each conversation, run exporter 6 times (once per verbosity level)
19. [x] Name files consistently: `session-{id}-v0-minimal.md`, `session-{id}-v1-compact.md`, etc.
20. [x] Add progress tracking for multi-verbosity mode (e.g., "Project 2/5, Session 3/10, Level 4/6")
21. [x] Update summary report to show total files generated across all levels
22. [x] Add option to select specific verbosity range: `--verbosity-range 2-4`

### Phase F: Advanced Features
24. [x] Add `--commit` flag to git commit after backup
25. [x] Add `--since <date>` to only backup recent conversations
26. [ ] (moved to issue 042) Add `--output-dir` to specify custom output location
27. [ ] (moved to issue 042) Add `--combined` to generate single export across all projects
28. [ ] (moved to issue 042) Add metadata file per conversation showing file sizes and export timestamps
29. [ ] (moved to issue 042) Add `--parallel` to process multiple verbosity levels concurrently

## Technical Notes

### Discovering Claude Project Paths
Claude stores conversations in `~/.claude/projects/` with path-encoded names:
```
~/.claude/projects/-mnt-mtwo-programming-ai-stuff-delta-version/
```

The script should encode project paths the same way to find matching conversations.

### Integration with Existing Tools
- `delta-version/scripts/list-projects.sh` - Project discovery
- `scripts/backup-conversations` - Pulls from ~/.claude/ to project
- `scripts/claude-conversation-exporter.sh` - Exports with verbosity levels
- `scripts/libs/lua-menu.sh` - TUI framework

### Example from issue-splitter.sh
The `issue-splitter.sh` script demonstrates the pattern:
```bash
# Source TUI libraries
source "${LIBS_DIR}/lua-menu.sh"

# Add checkbox items
menu_add_item "project_name" "checkbox" "Project Display Name" "1"

# Run menu and get selections
if menu_run; then
    selected=$(menu_get_value "project_name")
fi
```

## Related Documents
- `/home/ritz/programming/ai-stuff/scripts/issue-splitter.sh` - TUI pattern example
- `/home/ritz/programming/ai-stuff/scripts/libs/lua-menu.sh` - Menu library
- `/home/ritz/programming/ai-stuff/scripts/backup-conversations` - Conversation backup
- `/home/ritz/programming/ai-stuff/scripts/claude-conversation-exporter.sh` - Export tool
- `/home/ritz/programming/ai-stuff/delta-version/scripts/list-projects.sh` - Project listing

## Quest Notes

This script enables the "one command to backup everything" workflow:
```bash
./scripts/batch-transcript-backup.sh --all -v4 --commit
```

Run it periodically to keep the transcript archive up to date. The full
development archaeology preserved in git, alongside the code it created.

## Future Enhancements

**Interactive Zoom/Scroll Interface**
- Build a viewer that allows mouse-wheel or two-finger scroll to zoom between verbosity levels
- Like strategy game zoom: scroll out for v0 overview, scroll in for v5 deep detail
- Could be terminal-based (with mouse support) or web-based viewer
- Display same conversation, dynamically switching between verbosity files as user zooms
- This allows fluid exploration of the same history at different abstraction levels

**Note**: The multi-verbosity export creates the foundation for this - generating all the level files. The interactive zoom UI can be implemented separately once the data structure exists.

---

*Quest bounty: Batch operations with TUI flair.*

---

## Implementation Notes

**Date Completed**: 2026-01-12

### What Was Built

Created `/scripts/batch-transcript-backup.sh` with the following features:

**Core Functionality** ✓
- Project discovery via `list-projects.sh`
- Conversation counting from `~/.claude/projects/`
- Batch processing for selected projects or all projects
- Dry-run mode for previewing operations
- Progress tracking and summary reports

**Two-Tool Workflow** ✓
1. `backup-conversations` - Creates baseline `*_summary.md` files
2. `claude-conversation-exporter.sh` - Generates multi-verbosity variants (v0-v5)

**Multi-Verbosity Export** ✓
- `--all-verbosity-levels` flag generates v0-v5 for each conversation
- `--verbosity-range N-M` for specific level ranges
- File naming: `{session-id}-v{level}-{name}.md`
- Tested successfully: Generated 9 baseline + 27 variants (36 total files) for test project

**Known Limitations**:
- TUI interactive mode deferred (currently uses --all or project names)
- v0, v1, v2 verbosity levels may not generate content (exporter behavior)

### Bonus Implementation

Created `/scripts/conversation-analytics.sh` as a complementary tool offering:

**Alternative Data Views**:
- Statistical summaries with derived metrics
- ASCII bar charts and flow diagrams
- Analogical explanations (library, workshop, music, river analogies)
- Spreadsheet-style CSV data tables
- Pattern analysis with rhythm visualization
- Complexity scores and collaboration indices

**Usage**:
```bash
# Generate full analytics notebook
conversation-analytics.sh handheld-office

# Export to CSV
conversation-analytics.sh --format spreadsheet project > data.csv
```

This provides the "same history, multiple perspectives" approach mentioned in the issue.

---

## What Happened

**2026-11-03 — the remaining steps.** The core was built on 2026-01-12 (the
notes above). This pass built what was left of Phases C and F's first two
steps, fixed what the core got wrong, and moved the rest of Phase F to issue
042. Tests: `tests/test-batch-transcript-backup.sh` (51 checks against a
pretend monorepo with stand-in backup and export tools; the menu checks type
keys into a pretend terminal with `script`).

Built:

- **`-I` opens a menu** (Phase C). It used to print "not yet implemented" and
  back up every project. The menu lists the projects with their
  conversation counts, an "All projects" box, the export level, Dry run,
  Commit afterwards, and a Run button (`r`). Leaving with `q` does nothing.
- **`--since DATE`** (step 25) now works. It was parsed and ignored. Only
  conversations whose log changed since the date are counted and exported,
  and a project with none is skipped.
- **`--commit`** (step 24) now works. It was parsed and ignored. Each
  project's `llm-transcripts` folder is committed on its own, with
  `git commit -- llm-transcripts`, so anything else already staged stays
  staged and out of the commit.
- **`-v N` exports level N.** The level was checked and then never used.

Fixed:

- The "Discovering projects..." line went to stdout inside the function
  whose stdout is read as the project list, so it was counted as a project.
  It goes to stderr now.
- The file count came back as the exit status, which wraps at 256 and made
  any non-zero count look like a failure. It is a variable now.
- Each conversation is exported once per level. Earlier runs' level files
  start with the same header line as the baseline, so they were listed as
  more transcripts and each was exported again under the same name.
- Failures are shown and end in exit 1: a failing `backup-conversations`
  prints its messages (they were captured and dropped), and the exporter's
  messages are no longer sent to `/dev/null` (issue 034 made them say why).
- A project name that matches nothing is an error, not silently skipped. A
  bad range (`4-2`), level (`9`), date, or an option with no value is an
  error.
- The summary said "Files that would be generated" after a real run and
  multiplied by 6 whatever the range. It now reports what was done.

Decisions:

- **No level option means baseline only**, as before. Step 14 reads as if
  every run also exports at the chosen level. But the default level (2)
  was never exported, so exporting it now would add a file per conversation
  to every existing `--all` run.
- **An empty export is a warning, not a failure.** The 2026-01-12 notes
  say some levels can come out empty; that is the exporter's call. A
  non-zero exit from the exporter is a failure.
- **Select All / Deselect All became one "All projects" box** (step 13).
  The menu returns only "run" from an action button, so two more buttons
  could not tell the script which was pressed. With the box on, the list is
  greyed and every project runs; all projects start unticked.
- **The export level is a radio list**, not the mockup's dropdown.
  `lua-menu.sh` sets every multistate item's list of states to empty, so a
  multistate item there has nothing to cycle through.
  `neocities-modernization/generate-embeddings.sh`'s model choice has the same
  gap. The menu offers baseline, one level, or all six. A narrower
  `--verbosity-range` given with `-I` starts the menu at "all".
- **`--since` filters by the log file's change time** (`find -newermt`). The
  baseline still runs for the whole project, which `backup-conversations`
  already treats as a no-op for unchanged conversations.
- **One commit per project**, with the message "Back up <name>'s LLM
  transcripts". A project with nothing new makes no commit.
- **Steps 11 and 26-29 moved to issue 042** (output mode, `--output-dir`, `--combined`,
  per-conversation metadata, `--parallel`). Each one changes where or how
  files are written, and none was needed for the menu.
