# progress-dashboard.lua

Scans issue directories and generates progress statistics with ASCII visualizations. Works on any project following the phase-based issue naming convention (e.g., `301-feature-name.md`).

## Use Cases

### Quick Terminal Progress View
Display ASCII progress bars for each phase.

```bash
lua progress-dashboard.lua
```

### Generate Markdown Report
Create a progress report for documentation or sharing.

```bash
lua progress-dashboard.lua -m > docs/progress.md
```

### JSON Output for Automation
Get structured data for CI/CD or other tools.

```bash
lua progress-dashboard.lua -j | jq '.phases["3"].completed'
```

### Verbose Issue Listing
Show individual issues with their status icons.

```bash
lua progress-dashboard.lua -v
```

### Filter to Specific Phase
Focus on a single phase's progress.

```bash
lua progress-dashboard.lua -p 3
```

### Project-Specific Dashboard
Check progress for a different project.

```bash
lua progress-dashboard.lua -d /path/to/other-project
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `-d, --dir <path>` | Project directory (default: current) |
| `-t, --terminal` | Terminal output with ASCII graphics (default) |
| `-m, --markdown` | Markdown output |
| `-j, --json` | JSON output |
| `-p, --phase <n>` | Show only specific phase |
| `-v, --verbose` | Show individual issues |
| `-h, --help` | Show help |

## Capabilities

- **Phase Detection**: Extracts phase from issue filenames (first digit of ID)
- **Status Detection**: Determines status from acceptance criteria checkboxes or Status field
- **Criteria Counting**: Tracks `- [ ]` and `- [x]` checkboxes for completion percentage
- **Sub-Issue Recognition**: Identifies sub-issues (e.g., 301a, 301b) vs root issues
- **Completed Directory**: Scans `issues/completed/` for finished issues

## Terminal Output Format

```
╔════════════════════════════════════════════════════════════╗
║              PROJECT PROGRESS DASHBOARD                    ║
╠════════════════════════════════════════════════════════════╣
║ Phase 3: ██████████████░░░░░░░░░░░░░░░░░░ 8/15 (53%)
║   Issues: 5 done, 3 in progress, 7 pending
║   Criteria: █████████░░░░░░░░░░░░░░░░ 42/98 (43%)
╠────────────────────────────────────────────────────────────╣
║ TOTAL: 23/45 issues (51%) | 89/187 criteria (48%)
╚════════════════════════════════════════════════════════════╝
```

## Status Icons (Verbose Mode)

| Icon | Meaning |
|------|---------|
| ✓ (green) | Completed |
| ◐ (yellow) | In progress (some criteria done) |
| ○ (red) | Pending (no criteria done) |

## Library Usage

The script can be required as a Lua module:

```lua
local dashboard = require("progress-dashboard")
dashboard.init("/path/to/project")
local phases = dashboard.scan()
dashboard.render_terminal(phases)
```

### Library Functions

| Function | Description |
|----------|-------------|
| `init(project_dir)` | Initialize with project path |
| `scan()` | Scan issues and return list |
| `group_by_phase(issues)` | Group issues by phase ID |
| `render_terminal(phases)` | Print ASCII dashboard |
| `render_markdown(phases)` | Return markdown string |
| `render_json(phases)` | Return JSON string |
| `get_stats(phases)` | Return total/completed counts |

## Issue File Requirements

Issues should have:
- Filename starting with digits: `301-feature.md`
- Optional `**Status:** Completed` line
- Acceptance criteria with checkboxes: `- [ ] Task` or `- [x] Done`

## Related Scripts

- `issue-splitter.sh` - Generate and manage issue files
- `git-history.sh` - Track commits by phase
