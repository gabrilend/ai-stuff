# Delta-Version

**The meta-project for managing the ai-stuff monorepo.**

Delta-Version provides git repository infrastructure and tooling for 30+ projects in a unified repository. It handles project discovery, history reconstruction, gitignore unification, and cross-project coordination.

## What It Does

- **Project Discovery** - Find and list all projects in the monorepo
- **History Reconstruction** - Rebuild meaningful git history from issue files
- **Gitignore Unification** - Merge 900+ patterns into one organized `.gitignore`
- **Issue Management** - Create, validate, and complete issue tickets
- **Readable History** - Generate narrative HISTORY.txt files from git logs

## Quick Start

```bash
# List all projects
./scripts/list-projects.sh

# See what scripts are available
ls scripts/

# Generate history for a project
./scripts/generate-history.sh --project delta-version
```

For a full getting-started guide, see [docs/QUICK-START.md](docs/QUICK-START.md).

## Available Scripts

| Script | Purpose |
|--------|---------|
| `list-projects.sh` | Discover all projects (names, paths, JSON, interactive) |
| `reconstruct-history.sh` | Rebuild git history from issue files |
| `generate-history.sh` | Create readable HISTORY.txt narratives |
| `manage-issues.sh` | Issue creation, validation, and completion |
| `maintain-gitignore.sh` | Gitignore health monitoring and maintenance |
| `validate-gitignore.sh` | Test gitignore patterns (39 test cases) |
| `validate-repository.sh` | Verify repository structure and branches |
| `import-project-histories.sh` | Import external projects with history |
| `analyze-gitignore.sh` | Discover and categorize gitignore patterns |
| `generate-unified-gitignore.sh` | Produce the unified `.gitignore` |

## Project Structure

```
delta-version/
├── README.md           # You are here
├── run-demo.sh         # Run phase demonstrations
├── docs/               # Documentation
│   ├── QUICK-START.md      # 5-minute onboarding
│   ├── PROJECT-STATUS.md   # Current state overview
│   ├── history-tools-guide.md
│   └── ...
├── issues/             # Issue tracking
│   ├── completed/          # Finished issues
│   ├── progress.md         # Progress overview
│   └── PRIORITY.md         # What to work on next
├── scripts/            # Executable tools (see table above)
├── notes/              # Project notes and vision
├── assets/             # Generated data and configs
├── libs/               # Shared libraries
└── src/                # Source code
```

## Current Status

- **Phase 1** (Repository Infrastructure): Complete
- **Phase 2** (Gitignore Unification): Complete
- **History Reconstruction** (Issue 035): All sub-issues complete

See [docs/PROJECT-STATUS.md](docs/PROJECT-STATUS.md) for full details.

## Documentation

| Document | Description |
|----------|-------------|
| [QUICK-START.md](docs/QUICK-START.md) | Get up and running in 5 minutes |
| [PROJECT-STATUS.md](docs/PROJECT-STATUS.md) | Current state and what's working |
| [history-tools-guide.md](docs/history-tools-guide.md) | Deep dive on history tools |
| [roadmap.md](docs/roadmap.md) | Development phases and goals |
| [PRIORITY.md](issues/PRIORITY.md) | What to work on next |

## Repository

- **GitHub**: https://github.com/gabrilend/ai-stuff
- **Branch**: master (all projects), plus 5 project branches with preserved history
