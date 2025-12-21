# 009: Batch LLM Transcript Backup with TUI Selection

## Status
- **Priority**: MEDIUM
- **Type**: Feature / Tooling
- **Dependencies**: lua-menu.sh library, backup-conversations, claude-conversation-exporter.sh

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

## Suggested Implementation Steps

### Phase A: Core Script Structure
1. [ ] Create `scripts/batch-transcript-backup.sh` with vimfold structure
2. [ ] Source `libs/lua-menu.sh` for TUI support
3. [ ] Add argument parsing (-I, --all, --dry-run, -v0 through -v5)
4. [ ] Implement help message

### Phase B: Project Discovery
5. [ ] Use `delta-version/scripts/list-projects.sh --paths` to get all projects
6. [ ] For each project, check if it has Claude conversations:
       - Look for `~/.claude/projects/-path-encoded-project-name/`
       - Count conversations if present
7. [ ] Filter to only projects with existing conversations
8. [ ] Build menu items with conversation counts

### Phase C: TUI Menu Integration
9. [ ] Create checkbox section for project selection
10. [ ] Add verbosity dropdown (v0-v5 with descriptions)
11. [ ] Add output mode option (per-project / combined / both)
12. [ ] Show selection summary (count, estimated size)
13. [ ] Add Select All / Deselect All actions

### Phase D: Backup Execution
14. [ ] For each selected project:
    - Run `backup-conversations` to pull from ~/.claude/
    - Run `claude-conversation-exporter.sh` with selected verbosity
    - Save to `project/llm-transcripts/`
15. [ ] Show progress indicator (X of Y projects)
16. [ ] Generate summary report on completion

### Phase E: Advanced Features
17. [ ] Add `--commit` flag to git commit after backup
18. [ ] Add `--since <date>` to only backup recent conversations
19. [ ] Add `--output-dir` to specify custom output location
20. [ ] Add `--combined` to generate single export across all projects

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

---

*Quest bounty: Batch operations with TUI flair.*
