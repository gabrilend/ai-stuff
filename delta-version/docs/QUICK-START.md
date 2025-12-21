# Quick Start Guide

Get up and running with the ai-stuff monorepo in 5 minutes.

## Clone the Repository

```bash
git clone https://github.com/gabrilend/ai-stuff.git
cd ai-stuff
```

## Explore Available Projects

```bash
# List all 30+ projects
./delta-version/scripts/list-projects.sh

# Get full paths
./delta-version/scripts/list-projects.sh --paths

# Interactive selection
./delta-version/scripts/list-projects.sh --interactive
```

## Pick a Project

Each project lives in its own directory. Browse around:

```bash
ls -d */                    # See all project directories
cd world-edit-to-execute    # Enter a project
ls                          # See what's there
```

Most projects follow this structure:
```
project-name/
├── notes/vision.md    # What the project is about
├── docs/              # Documentation
├── issues/            # Task tracking
├── src/               # Source code
└── scripts/           # Runnable utilities
```

## Start Working

1. **Read the vision**: `cat notes/vision.md`
2. **Check open issues**: `ls issues/` (skip `completed/`)
3. **Make your changes**: Edit files as needed
4. **Commit**: Follow the project's conventions

## Useful Delta-Version Scripts

From the repository root:

| Script | Purpose |
|--------|---------|
| `delta-version/scripts/list-projects.sh` | Discover all projects |
| `delta-version/scripts/manage-issues.sh` | Create/validate/complete issues |
| `delta-version/scripts/generate-history.sh` | Generate readable HISTORY.txt |
| `delta-version/scripts/reconstruct-history.sh` | Rebuild git history from issues |

## Project Branches

Some projects have their own git branches with preserved history:

```bash
git branch -a              # See available branches
git checkout adroit        # Switch to a project branch
git checkout master        # Return to main (all projects)
```

Current project branches: `adroit`, `handheld-office`, `magic-rumble`, `progress-ii`, `risc-v-university`

## Where to Learn More

- `delta-version/docs/PROJECT-STATUS.md` - Current state of delta-version
- `delta-version/docs/history-tools-guide.md` - Deep dive on history tools
- `delta-version/docs/development-guide.md` - Development conventions
- Each project's `notes/vision.md` - Project-specific goals

## Common Tasks

### Create a new issue
```bash
./delta-version/scripts/manage-issues.sh create
```

### See project history as a story
```bash
./delta-version/scripts/generate-history.sh --project delta-version
```

### Find something across all projects
```bash
grep -r "search term" --include="*.lua" */src/
```

---

*For troubleshooting, see TROUBLESHOOTING.md (coming soon)*
