# ai-stuff

A unified monorepo containing 30+ interconnected software development projects with centralized management tooling.

## Repository Structure

```
ai-stuff/
├── delta-version/          # Meta-project: Repository management & tooling
├── scripts/                # Shared utilities library (TUI, CLI tools)
├── libs/                   # Shared Lua libraries
├── neocities-modernization/  # Active: Poetry website with LLM embeddings
├── world-edit-to-execute/    # Active: Warcraft 3 map parser/engine
└── [25+ other projects]      # Various development projects
```

## Core Projects

### Delta-Version (Meta-Project)
Central repository management system providing:
- Git infrastructure and branch isolation
- Automated tooling for cross-project operations
- Issue tracking and progress management
- Unified development workflows

### Active Development

| Project | Description | Phase |
|---------|-------------|-------|
| **world-edit-to-execute** | Warcraft 3 map file parser and Lua runtime engine | Phase 2/4 |
| **neocities-modernization** | Poetry website with LLM embedding similarity navigation | Phase 8 |

### Project Categories

**Games & Game Engines**
- `world-edit-to-execute` - WC3 map parser and open-source engine
- `RPG-autobattler` - Auto-battler RPG mechanics
- `healer-td` - Tower defense with healing mechanics
- `factory-war` - Factory building strategy
- `dark-volcano` - Adventure game
- `magic-rumble` - Magic-based game
- `adventure-hero-quest-mega-max-ultra` - Adventure hero game
- `console-demakes` - Classic game demakes

**AI & Language Processing**
- `ai-playground` - AI experimentation sandbox
- `neocities-modernization` - LLM embeddings for poetry navigation
- `words-pdf` - PDF text processing

**Tools & Utilities**
- `delta-version` - Repository management
- `scripts/` - Shared TUI/CLI utilities
- `progress-ii` - Progress tracking system
- `resume-generation` - Resume generation tools
- `handheld-office` - Portable productivity tools

**Learning & Education**
- `risc-v-university` - RISC-V architecture study
- `symbeline` - Symbol-based learning

**Creative & Content**
- `cloudtop-contest` - Contest submissions
- `continual-co-operation` - Collaborative projects
- `adroit` - Skillful implementation projects

## Development Philosophy

This repository follows principles from `CLAUDE.md`:

1. **Issue-Driven Development**: Every change requires an issue file
2. **Phase-Based Progress**: Work organized into numbered phases with demos
3. **Immutable Issues**: Issue files are append-only (no deletions)
4. **Commit Discipline**: Each completed issue gets a git commit
5. **Lua-First**: LuaJIT-compatible Lua is the preferred language

## Shared Infrastructure

### Scripts Library (`scripts/`)
```
scripts/
├── libs/
│   ├── tui.sh          # Terminal UI components
│   └── menu.sh         # Interactive menu system
├── git-history.sh      # Prettified git log viewer
├── progress-dashboard.lua  # Issue status visualization
├── test-runner.sh      # Unified test execution
└── issue-splitter.sh   # Issue file management
```

### Issue File Format
Issues follow the naming convention: `{PHASE}{ID}-{DESCR}.md`
- Example: `522-fix-update-script.md` (Phase 5, Issue 22)

Required sections:
- Current Behavior
- Intended Behavior
- Suggested Implementation Steps

## Getting Started

```bash
# Clone the repository
git clone <repo-url> ai-stuff
cd ai-stuff

# List active projects
./delta-version/scripts/list-projects.sh

# Run a phase demo (for projects with demos)
cd world-edit-to-execute
./run-demo.sh
```

## License

Individual projects may have their own licenses. See each project's directory for details.
