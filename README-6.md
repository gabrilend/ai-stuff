---

A project doesn't have to be anything more than a series of documents.
The source code can be filled in later.

consider this a lesson in computer science for sorcerers.

# If you're a wizard and you want a similar lesson, check out the book:

Structure and Interpretation of Computer Programs

---

## the following readme was auto-generated:

---

# ai-stuff

A unified monorepo containing 42 interconnected software development projects with centralized management tooling.

## Repository Structure

```
ai-stuff/
├── delta-version/              # Meta-project: Repository management & tooling
├── scripts/                    # Shared utilities library (TUI, CLI tools)
├── libs/ & my-libs/            # Shared Lua libraries
├── neocities-modernization/    # Active: Poetry website with GPU-accelerated LLM embeddings (Phase 9)
├── world-edit-to-execute/      # Active: Warcraft 3 map parser/engine
└── [37+ other projects]        # Various development projects
```

## Core Projects

### Delta-Version (Meta-Project)
Central repository management system providing:
- Git infrastructure and branch isolation
- Automated tooling for cross-project operations
- Issue tracking and progress management
- Unified development workflows
- See `delta-version/docs/` for worktree agent instructions

### Active Development

| Project | Description | Phase | Recent Work |
|---------|-------------|-------|-------------|
| **neocities-modernization** | Poetry website with GPU-accelerated LLM embedding similarity navigation | Phase 9 | Vulkan compute infrastructure, GPU similarity matrix generation |
| **world-edit-to-execute** | Warcraft 3 map file parser and Lua runtime engine | Phase 2/4 | Threadpool implementation, render migration |

## Project Categories

**Games & Game Engines**
- `world-edit-to-execute` - WC3 map parser and open-source engine
- `RPG-autobattler` - Auto-battler RPG mechanics
- `healer-td` - Tower defense with healing mechanics
- `factory-war` - Factory building strategy
- `dark-volcano` - Adventure game
- `magic-rumble` - Magic-based game
- `adventure-hero-quest-mega-max-ultra` - Adventure hero game
- `console-demakes` & `console-demakes-2` - Classic game demakes
- `a-hat-in-dual-screen` - Dual-screen game project
- `links-awakening` - Zelda-inspired project
- `ruby-castle` - Castle adventure game

**AI & Language Processing**
- `ai-playground` - AI experimentation sandbox
- `neocities-modernization` - LLM embeddings for poetry navigation with GPU acceleration
- `words-pdf` - PDF text processing and poem extraction
- `video-transcription` - Video transcription tools
- `llm-transcripts` - LLM conversation management

**Tools & Utilities**
- `delta-version` - Repository management and mono-repo tooling
- `scripts/` - Shared TUI/CLI utilities (menu systems, git history viewers)
- `progress-ii` - Progress tracking system
- `resume-generation` - Resume generation tools
- `handheld-office` - Portable productivity tools
- `authorship-tool` - Writing and authorship utilities
- `picture-generator` - Image generation tools
- `project-orchestration` - Multi-project coordination

**Learning & Education**
- `risc-v-university` - RISC-V architecture study
- `symbeline` - Symbol-based learning
- `programming-project-analysis` - Code analysis tools

**Creative & Content**
- `cloudtop-contest` - Contest submissions
- `continual-co-operation` - Collaborative projects
- `adroit` - Skillful implementation projects
- `ao3-source-code-import` - Archive of Our Own utilities

**Infrastructure & Systems**
- `translation-layer-wow-chat-city-of-chat` - Chat system translation layer
- `intelligence-system` - Intelligence/reasoning systems
- `factorIDE` - Development environment tools
- `shanna-lib` - Shared library components

## Project Progress

> **Note:** Not all projects have issue files created yet. Only 15 of 43 projects currently have issue tracking set up. Numbers shown reflect only tracked issues and may not represent actual project completion.

| Project | Progress | Completed | % Complete |
|---------|----------|-----------|------------|
| symbeline-realms | 177/198 | 177 | 89% |
| world-edit-to-execute | 201/284 | 201 | 71% |
| neocities-modernization | 145/240 | 145 | 60% |
| RPG-autobattler | 35/66 | 35 | 53% |
| delta-version | 30/90 | 30 | 33% |
| scripts | 1/26 | 1 | 4% |
| translation-layer-wow-chat-city-of-chat | 0/43 | 0 | 0% |
| ao3-source-code-import | 0/21 | 0 | 0% |
| handheld-office | 0/17 | 0 | 0% |
| healer-td | 0/12 | 0 | 0% |
| my-libs | 0/9 | 0 | 0% |
| authorship-tool | 0/7 | 0 | 0% |
| llm-http | 0/2 | 0 | 0% |
| progress-ii | 0/2 | 0 | 0% |
| spatial-drones | 0/1 | 0 | 0% |

**Totals:** 590 completed / 1017 total issues tracked (58%)

## Development Philosophy

This repository follows strict principles from `CLAUDE.md`:

1. **Issue-Driven Development**: Every change requires an issue file
2. **Phase-Based Progress**: Work organized into numbered phases with demos
3. **Immutable Issues**: Issue files are append-only (moved to `completed/` when done)
4. **Commit Discipline**: Each completed issue gets a git commit
5. **Lua-First**: LuaJIT-compatible Lua is the preferred language (disprefer Python)
6. **Fail-Fast**: Prefer error messages over fallbacks - notify on all fallbacks and create issues
7. **Documentation**: Every change needs explanatory comments for future maintainers
8. **Worktree Workflow**: Use isolated git worktrees for parallel development branches

## Shared Infrastructure

### Scripts Library (`scripts/`)
Located at `/home/ritz/programming/ai-stuff/scripts/` and `/home/ritz/programming/ai-stuff/my-libs/`

Common utilities:
- TUI components for terminal interfaces
- Menu systems for interactive CLI
- Git history prettification
- Progress visualization
- Issue management tools

### Libraries (`libs/` & `my-libs/`)
Shared Lua libraries for cross-project functionality.

### Issue File Format
Issues follow the naming convention: `{PHASE}{ID}-{DESCR}.md`
- Example: `9-002-port-similarity-matrix-to-vulkan.md` (Phase 9, Issue 002)
- Sub-issues: `{PHASE}{ID}{INDEX}-{DESCR}.md` (e.g., `9-001a-...`)

Required sections:
- Current Behavior
- Intended Behavior
- Suggested Implementation Steps
- (Optional) OB (Original Bug) notes for root cause insights

Progress tracking:
- Phase progress files: `issues/phase-X-progress.md`
- Completed issues moved to: `issues/completed/`
- Phase demos: `issues/completed/demos/`

## Recent Developments (Phase 9)

**Neocities-Modernization GPU Acceleration:**
- Implemented Vulkan compute infrastructure for embedding similarity
- GPU-accelerated similarity matrix generation (replacing CPU-based approach)
- Fail-fast error handling (removed CPU fallbacks per CLAUDE.md)
- Triangular matrix optimization for memory efficiency
- Parallel batch processing for diversity sequence generation

## Project Management

### Phase Demos
Completed phases include runnable demos in `issues/completed/demos/` that showcase:
- New tools and utilities from the phase
- Integration with previous phase functionality
- Visual demonstrations of outputs (HTML pages, graphical displays)
- Statistics and datapoints (not just descriptions)

### Version Control
- Git commits only after completing issue files
- Commit messages describe functionality abstractly (not implementation details)
- Branch isolation using worktree workflow (see `delta-version/docs/`)
- History preservation: prettified logs in phase-specific history files

### Testing
- Every bug fix requires a validation test
- Phase demo tests validate overall functionality
- Failed tests trigger skeleton issue file creation
- Test before marking issues complete

## Getting Started

```bash
# Clone the repository
git clone <repo-url> ai-stuff
cd ai-stuff

# View available projects
ls -d */

# Read project documentation
cat docs/table-of-contents.md

# Run a phase demo (for projects with demos)
cd neocities-modernization
./run.sh

# Or select a demo by phase number
./run-demo.sh
# (Enter phase number when prompted)
```

## Directory Conventions

Standard project structure:
```
project-name/
├── docs/           # Documentation and guides
├── notes/          # Planning, vision, brainstorming
├── src/            # Source code
├── libs/           # Project-specific libraries
├── assets/         # Resources (images, data files)
├── issues/         # Issue tracking
│   ├── completed/  # Archived completed issues
│   └── demos/      # Phase demonstration programs
├── input/          # Input files for program processing
├── output/         # Generated outputs
├── tmp/            # Project-specific temporary files
└── run.sh          # Main execution script
```

## Additional Resources

- `QUICK-START.md` - Quick reference guide
- `TROUBLESHOOTING.md` - Common issues and solutions
- `progress-ii-progress.md` - Overall repository progress tracking
- `CLAUDE.md` - Global development guidelines (in `/home/ritz/.claude/`)

## License

Individual projects may have their own licenses. See each project's directory for details.

---

*"they want you to think about then, so that you aren't able to think about now."*
