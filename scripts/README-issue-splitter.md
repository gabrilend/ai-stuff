# issue-splitter.sh

Iterates through issue files and uses Claude Code to suggest sub-issue splits. Responses are appended to each issue file as a "Sub-Issue Analysis" section, and optionally creates sub-issue files from the recommendations.

## Use Cases

### Analyzing Large Issues for Breakdown
When an issue is too complex for a single implementation pass, use the splitter to get Claude's recommendations on how to break it into smaller, manageable sub-issues.

```bash
./issue-splitter.sh --dir /path/to/project
```

### Interactive Mode with TUI
Launch the full TUI interface to configure options, select specific issues, and preview the command before execution.

```bash
./issue-splitter.sh -I
```

### Batch Processing with Parallel Execution
Process many issues simultaneously using parallel Claude calls with streaming output.

```bash
./issue-splitter.sh --stream --parallel 5
```

### Creating Sub-Issue Files from Recommendations
After analysis, execute recommendations to create skeleton sub-issue files.

```bash
./issue-splitter.sh -x                    # With confirmation prompts
./issue-splitter.sh -X                    # Without confirmation (auto-execute all)
./issue-splitter.sh -x -G                 # Generate complete files via Claude
```

### Interactive Feedback Loop
Have a back-and-forth conversation with Claude to refine the analysis.

```bash
./issue-splitter.sh -F --max-rounds 5
```

### Reviewing Existing Structure
Review root issues that already have sub-issues for further splitting opportunities.

```bash
./issue-splitter.sh -r
```

### Clearing Old Analysis
Remove analysis sections to re-run fresh analysis.

```bash
./issue-splitter.sh -C
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `-d, --dir <path>` | Project directory containing `issues/` folder |
| `-p, --pattern <glob>` | Issue file pattern (default: `[0-9]*.md`) |
| `-s, --skip-existing` | Skip issues that already have analysis sections |
| `-r, --review-only` | Only review roots with existing sub-issues |
| `-n, --dry-run` | Show what would be processed without running |
| `-I, --interactive` | Launch TUI for option selection |
| `-a, --archive` | Save analysis copies to `issues/analysis/` |
| `-x, --execute` | Create sub-issue files from recommendations |
| `-G, --generate-complete` | Use Claude to write full issue content (not skeletons) |
| `-X, --execute-all` | Execute without confirmation prompts |
| `-A, --auto-implement` | Invoke Claude CLI to implement issues |
| `-C, --clear` | Remove analysis sections (no Claude) |
| `-F, --feedback` | Interactive Q&A feedback loop |
| `-S, --session` | Reuse Claude context across issues |
| `-E, --expert` | Fresh context per issue (default) |
| `--max-rounds <n>` | Max feedback rounds (default: 10) |
| `--stream` | Enable parallel streaming mode |
| `--parallel <n>` | Max concurrent Claude calls (default: 3) |
| `--delay <n>` | Seconds between streamed outputs (default: 5) |

## Capabilities

- **Smart Skipping**: Automatically skips sub-issues and roots that already have sub-issues (reviews them at end instead)
- **Phase-Based Naming**: Generates sub-issue IDs following the `{phase}{id}{letter}` convention (e.g., 301a, 301b)
- **Dependency Tracking**: Parses Claude's dependency recommendations and includes them in generated files
- **Archive Mode**: Preserves analysis history in a separate directory
- **Verdict Detection**: Analyzes Claude's response to determine if splitting was recommended
- **TUI Integration**: Full lua-menu integration with file preview, command preview, and dependency handling between options

## TUI Sections

When run with `-I`, the TUI provides:

1. **Operation Mode** - Select analyze, feedback loop, review, execute, implement, or clear
2. **Processing Options** - Toggle streaming, skip-existing, archive, session mode, etc.
3. **Streaming Settings** - Configure parallel jobs and output delay
4. **Issues to Process** - Multi-select checkbox list with status indicators
5. **Content Preview** - Shows selected issue file content
6. **Command Preview** - Live preview of the command that will be executed
7. **Actions** - Run the selected configuration

## Related Scripts

- `progress-dashboard.lua` - Track issue completion across phases
- `git-history.sh` - Generate commit history by phase
