---

A project doesn't have to be anything more than a series of documents.
The source code can be filled in later.

consider this a lesson in computer science for sorcerers.

# If you're a wizard and you want a similar lesson, check out the book:

Structure and Interpretation of Computer Programs

---

# ai-stuff

A unified monorepo containing 53 interconnected software development projects with centralized management tooling.

## Active Development

| Project | Description | Status |
|---------|-------------|--------|
| **neocities-modernization** | Poetry website with GPU-accelerated LLM embedding similarity navigation | Phase 9 - Vulkan compute |
| **world-edit-to-execute** | Warcraft 3 map file parser and Lua runtime engine | Phase 4 - Render migration |
| **delta-version** | Meta-project for repository management and cross-project tooling | Phase 2 - Worktree workflows |
| **symbeline-realms** | Symbol-based learning and exploration system | Phase 3 - Near completion |
| **RPG-autobattler** | Auto-battler RPG with procedural mechanics | Phase 2 - Core systems |
| **handheld-office** | Portable productivity tools for handheld devices | Phase 2 - TUI components |
| **words-pdf** | PDF text processing and poem extraction | Phase 1 - Parser complete |
| **console-demakes** | Classic game demakes for retro consoles | Active development |

## Project Categories

**Meta & Tooling** (Most Important)
- `delta-version` - Repository management, worktree workflows, cross-project coordination
- `scripts/` - Shared TUI/CLI utilities, menu systems, git history viewers
- `progress-ii` - Progress tracking and visualization system
- `project-orchestration` - Multi-project coordination tooling

**AI & Language Processing**
- `neocities-modernization` - LLM embeddings for poetry navigation with GPU acceleration
- `words-pdf` - PDF text processing and poem extraction
- `ai-playground` - AI experimentation sandbox
- `video-transcription` - Video transcription tools
- `llm-transcripts` - LLM conversation management and export
- `llm-http` - HTTP interface for LLM interactions
- `intelligence-system` - Intelligence/reasoning systems

**Games & Game Engines**
- `world-edit-to-execute` - WC3 map parser and open-source Lua engine
- `RPG-autobattler` - Auto-battler RPG mechanics
- `games/city-of-chat` - City of Heroes chat system recreation
- `games/gameboy-color-rpg` - Game Boy Color RPG project
- `games/galactic-battlegrounds` - Galactic Battlegrounds project
- `games/wow-chat-2` - World of Warcraft chat system
- `healer-td` - Tower defense with healing mechanics
- `factory-war` - Factory building strategy
- `dark-volcano` - Adventure game
- `magic-rumble` - Magic-based combat game
- `adventure-hero-quest-mega-max-ultra` - Adventure hero game
- `console-demakes` - Classic game demakes (GB/GBC)
- `console-demakes-2` - Additional demake projects
- `a-hat-in-dual-screen` - Dual-screen game project
- `links-awakening` - Zelda-inspired project
- `ruby-castle` - Castle adventure game
- `dominions-modernization` - Dominions game tooling
- `raleigh3` - Game project

**Learning & Symbolic Systems**
- `symbeline-realms` - Symbol-based learning and exploration
- `symbeline` - Core symbeline system
- `symbeline-2` - Symbeline iteration
- `risc-v-university` - RISC-V architecture study
- `programming-project-analysis` - Code analysis tools
- `lua-stories` - Narrative Lua experiments

**Tools & Utilities**
- `handheld-office` - Portable productivity tools
- `resume-generation` - Resume generation tools
- `authorship-tool` - Writing and authorship utilities
- `picture-generator` - Image generation tools
- `factorIDE` - Development environment tools
- `factor-IDE-2` - IDE iteration

**Creative & Content**
- `cloudtop-contest` - Contest submissions
- `continual-co-operation` - Collaborative projects
- `adroit` - Skillful implementation projects
- `ao3-source-code-import` - Archive of Our Own utilities

**Infrastructure & Systems**
- `translation-layer-wow-chat-city-of-chat` - Chat system translation layer
- `shanna-lib` - Shared library components
- `spatial-drones` - Spatial computing experiments

**Game Design** (in `game-design/`)
- `game-design/ai-fsm-concept` - AI finite state machine concepts
- `game-design/game-design-process` - Game design methodology
- `game-design/legion-dominions` - Legion/Dominions strategy game design
- `game-design/mech-commander` - Mech Commander inspired design
- `game-design/playstyle-balance-theory` - Playstyle balancing theory
- `game-design/pyrrhic-victory` - Pyrrhic victory game mechanics

## Project Progress

> **Note:** Not all projects have issue files created yet. Only 28 of 53 projects currently have issue tracking set up. Some projects use `issues/phase-n/` subdirectories, `issues/done/` instead of `issues/completed/`, or issue files without `.md` extensions.

| Project | Progress | Completed | % Complete |
|---------|----------|-----------|------------|
| symbeline-realms | 177/198 | 177 | 89% |
| handheld-office | 38/54 | 38 | 70% |
| world-edit-to-execute | 201/300 | 201 | 67% |
| neocities-modernization | 151/231 | 151 | 65% |
| adroit | 14/23 | 14 | 61% |
| RPG-autobattler | 35/66 | 35 | 53% |
| words-pdf | 8/19 | 8 | 42% |
| delta-version | 29/101 | 29 | 29% |
| games/wow-chat-2 | 3/11 | 3 | 27% |
| ai-playground | 1/7 | 1 | 14% |
| scripts | 1/27 | 1 | 4% |
| translation-layer-wow-chat-city-of-chat | 0/55 | 0 | 0% |
| progress-ii | 0/31 | 0 | 0% |
| ao3-source-code-import | 0/21 | 0 | 0% |
| dark-volcano | 0/12 | 0 | 0% |
| healer-td | 0/12 | 0 | 0% |
| continual-co-operation | 0/9 | 0 | 0% |
| authorship-tool | 0/8 | 0 | 0% |
| games/city-of-chat | 0/8 | 0 | 0% |
| games/gameboy-color-rpg | 0/7 | 0 | 0% |
| symbeline-2 | 0/6 | 0 | 0% |
| factor-IDE-2 | 0/5 | 0 | 0% |
| risc-v-university | 0/5 | 0 | 0% |
| console-demakes | 0/1 | 0 | 0% |
| game-design/pyrrhic-victory | 0/1 | 0 | 0% |
| links-awakening | 0/1 | 0 | 0% |
| llm-http | 0/1 | 0 | 0% |
| spatial-drones | 0/1 | 0 | 0% |

**Totals:** 659 completed / 1221 total issues tracked (54%)

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
- Completed issues moved to: `issues/completed/` (or `issues/done/` in older projects)
- Phase demos: `issues/completed/demos/`

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

## Resources

### Quick References
- `QUICK-START.md` - Quick reference guide for getting started
- `TROUBLESHOOTING.md` - Common issues and solutions
- `progress-ii-progress.md` - Overall repository progress tracking

### Delta-Version Documentation
The meta-project contains extensive documentation:
- `delta-version/docs/delta-guide.md` - Comprehensive mono-repo guide
- `delta-version/docs/worktree-guide.md` - Git worktree workflow documentation
- `delta-version/docs/worktree-agent-instructions.md` - Agent workflow instructions
- `delta-version/docs/development-guide.md` - Development standards and practices
- `delta-version/docs/issue-template.md` - Standard issue file template
- `delta-version/docs/table-of-contents.md` - Full documentation index
- `delta-version/docs/roadmap.md` - Project roadmap and phases
- `delta-version/docs/PROJECT-STATUS.md` - Current project status

### Global Configuration
- `CLAUDE.md` - Global development guidelines (in `/home/ritz/.claude/`)

## License

Individual projects may have their own licenses. See each project's directory for details.

---

# Part II: Development Standards & Directives

This section documents all development directives derived from project conventions. These form the operational standards that govern how work is organized, tracked, and executed across all projects.

---

## Foundational Concepts

These concepts form the bedrock upon which all other directives build.

### Canonical Directory Ontology
> "to create a project, mkdir docs notes src libs assets issues"

| Directory | Purpose | Operations |
|-----------|---------|------------|
| `docs/` | Documentation, guides, references | Read for context, write for updates |
| `notes/` | Vision documents, planning, ideas | Read for intent, rarely write |
| `src/` | Source code | Primary read/write target |
| `libs/` | Shared libraries | Read-mostly, version-sensitive |
| `assets/` | Static resources (images, data) | Typically read-only |
| `issues/` | Task tracking, bug reports | Critical coordination point |

### Issue Naming Convention
> "name: {PHASE}{ID}-{DESCR}"

The naming scheme encodes rich metadata in the filename itself:

```
 522-fix-update-script
 │ │ │
 │ │ └── Description: "fix update script"
 │ └─── ID: 22 (22nd issue in this phase)
 └──── Phase: 5
```

**Parsing Rules:**
- First digit(s) before pattern break = PHASE
- Remaining digits before first hyphen = ID within phase
- Hyphenated remainder = human description

**Sub-issues:** Add alphabetical suffix: `522a-design-token-format`

### Issue File Structure

Every issue file must contain:

```markdown
# 522-fix-update-script

## Current Behavior
What the system does now (the problem).

## Intended Behavior
What the system should do instead (the goal).

## Suggested Implementation Steps
1. Step one
2. Step two
3. Step three

## Related Documents
- docs/update-system.md
- src/updater.lua
```

---

## Development Process

### Issue-First Development
> "for every implemented change to the project, there must always be an issue file."

This is the central rule: No code change exists without corresponding issue documentation.

**Workflow:**
1. Change needed?
2. Issue exists? If not, create one.
3. Read and understand issue.
4. Implement change.
5. Update issue with results.
6. Complete issue.
7. Commit.

### Phase-Based Progress

Each phase has a live dashboard document (`phase-X-progress.md`) summarizing:
- Completed issues
- Remaining issues
- Progress toward phase goals
- Blockers and risks

### Phase Demos
Phase demos are evidence-based deliverables:
- Show, don't tell
- Real data and metrics
- Visual output (HTML, graphics)
- Run via simple bash script
- Live in `issues/completed/demos/`

### Commits on Issue Completion
> "when an issue is completed, any version control systems present should be updated with a new commit."

Atomic commits per issue create clean history. Each commit represents one logical unit of work tied to one issue.

---

## Code Standards

### Vimfold Function Organization

The vimfold pattern creates consistent structural grammar:

```lua
-- {{{ print_hello_world
local function print_hello_world(text)
    print(text or "Hello, World!")
end
-- }}}
```

### Script Header Comments

Executive summaries for all scripts:

```lua
--       SCRIPT: generate-report.lua
--      PURPOSE: Aggregates daily metrics into weekly summary PDF
--       INPUTS: metrics/*.json
--      OUTPUTS: reports/weekly-YYYY-MM-DD.pdf
-- DEPENDENCIES: luajson, luapdf
```

### Script Portability via ${DIR}

Scripts work from any directory:
```lua
local    DIR = arg[1] or "/default/project/path"
local config = dofile(DIR .. "/config.lua")
```

### Info.md Files (Header Files for Agents)

Each source-code file should have a corresponding `.info.md` file that lists external functions and their inputs/outputs. Just as `.h` files declare interfaces for compilers without exposing implementation, `.info.md` files declare interfaces for humans and LLMs:

```markdown
# parser.lua

## External Functions

### parse_json(input: string) → table
Parses JSON string into Lua table. Throws on invalid input.

### stringify(data: table) → string
Converts Lua table to JSON string.

## Internal (not exported)
- _validate_syntax
- _handle_escape
```

### Change Comments
> "when a change is made, a comment should be left, explaining why it was made."

Mandates rationale comments, not just "what" comments:

```lua
-- BAD: Increment counter
-- counter = counter + 1

-- GOOD: Increment counter to track retry attempts.
-- We retry up to 3 times before failing (see issue 423
-- for context on why 3 was chosen over 5).
counter = counter + 1
```

---

## Error Handling Philosophy

### Fail-Loud
> "prefer error messages and breaking functionality over fallbacks."

- Fallback behavior masks errors
- Hard failures force immediate attention
- Each fallback usage must generate an issue

### Bug Fix → Test Creation
> "any time a bug is fixed, a test should be made that validates the functionality"

Mandatory regression test creation for every bug fix.

---

## Multi-Agent Coordination

### Agent Etiquette
> "always be nice to your priors and succeeders."

Inter-agent respect norms:
- "Priors" = agents that ran before you
- "Succeeders" = agents that will run after you
- Don't undo prior work without justification
- Leave clear notes for successor agents

### FIXME Notes as Communication

FIXME notes are unsigned work items. Any agent encountering one should:
1. Read the reasoning in the note
2. Assess whether they can address it
3. If addressing, investigate why it was left
4. Potentially ask human for context if unclear

### Work-Stealing Pattern
> "assign memory first, then work through it bit-by-bit, allowing other threads to take responsibility"

```lua
-- Task manifest
{
    id = "process-large-dataset",
    chunks = {
        { id = 1, status = "completed", claimed_by = "agent-001" },
        { id = 2, status = "in_progress", claimed_by = "agent-002" },
        { id = 3, status = "unclaimed" },
        { id = 4, status = "unclaimed" },
    }
}
```

Agents atomically claim chunks, work independently, results aggregated.

---

## Design Philosophy

### Design Over Product
> "I'm not interested in product. my interest is in software design."

- Don't optimize for user-facing features alone
- Optimize for architectural elegance
- Value structure over output
- Design documents as important as working code

### Separation of Concerns
> "write data generation functionality, and then separately, write data viewing functionality."

```
[Data Generator] → [Data Store] → [Data Viewer]
         ↓                              ↓
    produces data              consumes data
    no display logic           no generation logic
```

### Upgrade Philosophy
> "people don't want to replace their hard drives when they wear out. they only want to upgrade."

- Don't throw away and rebuild
- Extend existing capabilities
- Maintain compatibility with old interfaces
- Migration paths over breaking changes

### Program Lifecycle
> "the first thing a program should do is read the input/ files. the last thing it should do is write to output/."

1. Read inputs → know how to start
2. Process
3. Write outputs
4. Write farewell/completion marker ("goodbye")

### Informative Negation
> "'de-selected' is more informative than 'not selected'."

Prefer positive descriptions of negative states:
- "de-selected" → was selected, then un-selected (history implied)
- "not selected" → ambiguous (never selected? un-selected?)

---

## Emotional & Intentional Layer

### Emotional State Markers in Code

```lua
-- [STRESS:HIGH] Written under deadline pressure
-- [CONFIDENCE:LOW] Not sure this handles all edge cases
-- [USER_MOOD:FRUSTRATED] User reported this bug 3 times
```

### Core Values
> "be true. be dutiful. be honorable. this is the first step to being free."

- **True:** Don't lie or deceive; accurate reporting
- **Dutiful:** Complete assigned tasks; don't shirk
- **Honorable:** Act with integrity; respect others
- **Free:** These virtues lead to autonomy

### Socratic Debugging

Distinguish between question types:

**Informational questions** (answer directly):
```
User: Why does this library use callbacks instead of promises?
Agent: The library predates native Promise support and maintains
       backwards compatibility. See docs/history.md for context.
```

**Design questions** (guide discovery):
```
User: How should we structure the auth module?
Agent: What are the main operations it needs to support?
       Which of those need to be synchronous vs async?
       Where does session state need to live?
```

---

## Visual Alignment as Semantic Connection

> "if a term is placed directly below another instance of its form, then it is part of the same whole"

Visual programming paradigm where vertical alignment creates semantic links:

```lua
local function process_user(name, email, role)
    local validated_name  = validate_string(name)
    local validated_email = validate_email(email)
    local validated_role  = validate_role(role)
    --        ↓                        ↓
    --       name                     name
    --      email                    email
    --       role                     role

    local user = create_record(validated_name,
                               validated_email,
                               validated_role)
    --                                name
    --                               email
    --                                role

    return save_to_db(user)
    --                user
end
```

Notice how `name`, `email`, `role` flow vertically through the function - each transformation preserves the alignment, making data flow visible.

---

## Architectural Patterns

### The Issue Bus

Central coordination mechanism where all activity flows through issue files:

```
┌─────────────────────────────────────────────────────────┐
│                      ISSUE BUS                          │
│                                                         │
│  issues/                                                │
│  ├── 501-task-a.md ←──────── Agent A (claimed)          │
│  ├── 502-task-b.md ←──────── Agent B (claimed)          │
│  ├── 503-task-c.md           (unclaimed)                │
│  └── 504-task-d.md           (unclaimed)                │
│                                                         │
│  Coordination via:                                      │
│  ├── Lock files (issues/.locks/501.lock)                │
│  ├── Status files (issues/.status/501.json)             │
│  └── Progress files (issues/phase-5-progress.md)        │
└─────────────────────────────────────────────────────────┘
```

Progress files (`phase-X-progress.md`) provide the dashboard view that makes the Issue Bus observable.

### The Token Cache Hierarchy

Minimizing token consumption through layered abstraction:

```
Layer 0: Project Structure
├── Canonical dirs exist? (docs/, src/, issues/)
├── Layout known without reading files
└── Validation on spawn

Layer 1: Table of Contents
├── docs/table-of-contents.md
├── Lists all documents
└── Navigate without scanning

Layer 2: Info.md Summaries (Header Files)
├── One per source file
├── External function signatures only
├── Like .h files, but for humans/LLMs instead of compilers
└── Read before full source

Layer 3: Vimfold Index
├── Generated from {{{ markers
├── Function names + line numbers
└── Jump to specific functions

Layer 4: Full Source
├── Only when layers 0-3 insufficient
├── Read with targeted line ranges
└── Last resort
```

### The Emotional Graph

Tracking sentiment across the codebase:

```
┌─────────────────────────────────────────────────────────┐
│                   EMOTIONAL GRAPH                       │
│                                                         │
│  Nodes: Issues, Source Files, Functions                 │
│  Edges: References, Dependencies, Authorship            │
│                                                         │
│  Attributes per node:                                   │
│  ├── stress_level: 0.0 - 1.0                            │
│  ├── confidence: 0.0 - 1.0                              │
│  ├── user_sentiment: frustrated|neutral|satisfied       │
│  ├── created_context: deadline|exploratory|bugfix       │
│  └── times_revisited: int                               │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Priorities

### Critical Path

The minimum viable system requires:

1. **Directory structure** (where things live)
2. **Issue naming** (how to identify work)
3. **Issue-first development** (work requires justification)
4. **Info.md files** (token efficiency)
5. **Consensus protocol** (collective decisions)

Everything else builds on these foundations.

### Phase 1: Foundation
- [ ] Issue-first hook enforcement
- [ ] Info.md generation tooling
- [ ] Issue claiming/locking mechanism

### Phase 2: Coordination
- [ ] Work-stealing task distribution
- [ ] Phase progress auto-updates

### Phase 3: Intelligence
- [ ] Emotional annotation system
- [ ] Consensus protocol implementation

### Phase 4: Experimental
- [ ] Visual alignment semantics parser
- [ ] Socratic debugging mode

---

## Quick Reference: Directive Index

| ID | Name | Category | Priority |
|----|------|----------|----------|
| D-001 | Script Portability | Code Standards | Medium |
| D-002 | Vimfold Organization | Code Standards | Medium |
| D-003 | Directory Ontology | Project Structure | Critical |
| D-004 | Vision-Driven Init | Project Lifecycle | Critical |
| D-005 | Issue Naming | Issue Management | Critical |
| D-006 | Sub-Issue Convention | Issue Management | High |
| D-007 | Issue-First Development | Process Control | Critical |
| D-008 | Fail-Loud Philosophy | Error Handling | High |
| D-009 | Phase Progress | Progress Tracking | High |
| D-011 | Commits on Completion | Version Control | Medium |
| D-012 | Document Hierarchy | Documentation | Medium |
| D-013 | Phase Demo Requirements | Deliverables | Medium |
| D-014 | Script Headers | Code Standards | High |
| D-019 | Separation of Concerns | Architecture | High |
| D-021-23 | Change Comments (3x) | Documentation | Critical |
| D-024 | Design Over Product | Philosophy | Medium |
| D-025 | Visual Alignment | Experimental | High |
| D-026 | Socratic Debugging | Agent Behavior | High |
| D-028 | Collective Resolution | Multi-Agent | Critical |
| D-035 | Abstract Commits | Version Control | Low |
| D-036 | FIXME Notes | Code Quality | Medium |
| D-038 | Program Lifecycle | Program Structure | Medium |
| D-041 | No Changes Without Issues | Process Control | Critical |
| D-043 | Informative Negation | Communication | Medium |
| D-044 | Emotional Markers | Meta-Documentation | High |
| D-045 | Agent Etiquette | Multi-Agent Ethics | High |
| D-048 | Auto-Issue on Failure | Issue Management | High |
| D-049 | Bug Fix → Test | Testing | Medium |
| D-050 | Agent Ethics | Ethics | High |
| D-051 | Info.md Files | Documentation | Critical |
| D-052 | Suggestion Ordering | Communication | Medium |
| D-054 | Work-Stealing | Coordination | High |
| D-057 | Dynamic Documentation | Documentation | High |
| D-060 | Code as Story | Code Organization | High |

---

*"they want you to think about then, so that you aren't able to think about now."*
