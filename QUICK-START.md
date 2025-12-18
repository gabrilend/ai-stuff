# Quick Start Guide

Get productive with the ai-stuff monorepo in 5 minutes.

## Clone and Explore

```bash
# Clone the repository
git clone https://github.com/gabrilend/ai-stuff.git
cd ai-stuff

# List all 30+ projects
./delta-version/scripts/list-projects.sh

# Get full paths
./delta-version/scripts/list-projects.sh --paths

# JSON output (for scripting)
./delta-version/scripts/list-projects.sh --json
```

## Find a Project to Work On

### Active Projects (Recommended Starting Points)

| Project | What It Does | Status |
|---------|-------------|--------|
| `world-edit-to-execute` | Warcraft 3 map parser and Lua runtime | Active development |
| `neocities-modernization` | Poetry website with LLM embeddings | Phase 8 |
| `delta-version` | Repository management tools | Infrastructure |

### View Project Documentation

```bash
# Most projects have a vision document
cat handheld-office/notes/vision.md

# Check for issues (work to be done)
ls progress-ii/issues/

# Look for completed work
ls world-edit-to-execute/issues/completed/
```

## Development Workflow

### 1. Read the Vision First

Every project has a purpose defined in `notes/vision.md`. Read this before making changes.

```bash
cat [project]/notes/vision.md
```

### 2. Check for Existing Issues

Don't create duplicate work - check what's already planned:

```bash
# All issues
ls [project]/issues/

# Completed work
ls [project]/issues/completed/
```

### 3. Create an Issue Before Coding

**Every change needs an issue file.** This is a core principle.

```bash
# Use the issue manager (if working on delta-version)
./delta-version/scripts/manage-issues.sh --help

# Or create manually
vim [project]/issues/042-add-new-feature.md
```

Issue files need these sections:
- **Current Behavior** - What happens now
- **Intended Behavior** - What should happen
- **Suggested Implementation Steps** - How to do it

### 4. Make Your Changes

Code according to the issue specification.

### 5. Complete the Issue

```bash
# Move completed issue
mv [project]/issues/042-add-new-feature.md [project]/issues/completed/

# Commit with issue reference
git add .
git commit -m "Issue 042: Add new feature

Description of what was done.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

## Shared Tools

### TUI Libraries (scripts/libs/)

```bash
# Source TUI helpers for interactive scripts
source scripts/libs/tui.sh
source scripts/libs/menu.sh
```

### Delta-Version Scripts

```bash
# List projects
./delta-version/scripts/list-projects.sh

# Generate readable history file
./delta-version/scripts/generate-history.sh --project delta-version

# Manage issues
./delta-version/scripts/manage-issues.sh --help
```

## Language Preference

**Lua (LuaJIT-compatible)** is the preferred language for new development.

- Use LuaJIT syntax (not Lua 5.4)
- Disprefer Python unless necessary
- C is acceptable for performance-critical code

## Key Files to Know

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Project-specific coding conventions (root or per-project) |
| `notes/vision.md` | Project purpose and scope |
| `issues/progress.md` | Current completion status |
| `docs/roadmap.md` | Planned development phases |

## Common Commands

```bash
# See project status
cat [project]/issues/progress.md

# Run phase demo (if available)
./[project]/run-demo.sh

# Generate commit history narrative
./delta-version/scripts/generate-history.sh --project [project]

# Check for uncommitted changes
git status
```

## Need Help?

1. Read the project's `notes/vision.md`
2. Check `issues/` for context on current work
3. Look at `issues/completed/` for examples of finished work
4. Check `CLAUDE.md` for coding conventions

## Next Steps

- Browse the [README](README.md) for full project listing
- Explore [delta-version documentation](delta-version/docs/table-of-contents.md)
- Pick an open issue and start contributing!
