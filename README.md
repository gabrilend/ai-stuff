# ai-stuff

*A project doesn't have to be anything more than a series of documents. The source code can be filled in later.*

---

## Introduction

This is a unified monorepo containing 53 interconnected software development projects. What makes it unusual is not its size, but its methodology: every change requires an issue file, every issue follows a naming convention, and every phase produces a working demonstration.

The system emerged from a simple observation: code without documentation becomes unmaintainable, but documentation without structure becomes unreadable. The solution is to make structure itself the documentation.

If you're a wizard who wields power through knowledge and want a more rigorous foundation, see *Structure and Interpretation of Computer Programs*.

This repository is for sorcerers - those who use vision to see a problem and solution, language to describe that path, and will to compel reality to stitch itself into the proper configuration.

---

## The Paradigm

### Issue-Driven Development

No code change exists without a corresponding issue file. This is the central rule.

An issue file is not a ticket in a tracking system. It is a markdown document that lives in the repository, versioned alongside the code it describes. Each issue contains three required sections: what the system does now (Current Behavior), what it should do instead (Intended Behavior), and how to get there (Suggested Implementation Steps).

The workflow is simple:
1. Identify a change that needs to be made
2. Create or find the issue file that describes it
3. Read and understand the issue
4. Implement the change
5. Update the issue with what actually happened
6. Move the issue to `issues/completed/`
7. Commit

This creates a development history that can be read like a narrative. Each issue tells a story: here was a problem, here was a plan, here is what we learned.

### Phase-Based Progress

Work is organized into phases. Each phase has a progress file (`phase-X-progress.md`) that tracks completed issues and remaining work. When a phase completes, a demonstration program is created that shows—not describes—what was accomplished.

Phase demos live in `issues/completed/demos/` and run via simple bash scripts. They produce real output: rendered graphics, processed data, working interfaces. The ability to demonstrate progress at any phase boundary keeps the work honest.

### The Naming Convention

Issue files follow a precise naming scheme: `{PHASE}{ID}-{DESCR}.md`

```
 522-fix-update-script.md
 │ │ │
 │ │ └── Description: "fix update script"
 │ └─── ID: 22 (22nd issue in this phase)
 └──── Phase: 5
```

This encoding serves multiple purposes. Files sort chronologically within each phase. The filename alone tells you when the issue was created and what it addresses. Automated tools can parse phase and ID without reading file contents.

For complex issues, sub-issues use an alphabetical suffix: `522a-design-token-format.md`, `522b-implement-token-generation.md`. The parent issue completes only when all children complete.

---

## The Projects

Twenty-eight projects currently have active issue tracking, with 659 issues completed out of 1,221 total (54% overall completion).

### Active Development

| Project | Focus | Status |
|---------|-------|--------|
| **neocities-modernization** | Poetry website with GPU-accelerated LLM similarity navigation | Phase 9 |
| **world-edit-to-execute** | Warcraft 3 map parser and Lua runtime engine | Phase 4 |
| **symbeline-realms** | Symbol-based learning and exploration | Phase 3 (89% complete) |
| **delta-version** | Repository management and cross-project tooling | Phase 2 |
| **RPG-autobattler** | Auto-battler RPG with procedural mechanics | Phase 2 |
| **handheld-office** | Portable productivity tools | Phase 2 (70% complete) |

### Progress Overview

The most mature projects have completion rates above 60%:

| Project | Progress | Complete |
|---------|----------|----------|
| symbeline-realms | 177/198 | 89% |
| handheld-office | 38/54 | 70% |
| world-edit-to-execute | 201/300 | 67% |
| neocities-modernization | 151/231 | 65% |
| adroit | 14/23 | 61% |
| RPG-autobattler | 35/66 | 53% |
| words-pdf | 8/19 | 42% |
| delta-version | 29/101 | 29% |

Feel free to poke around. I recommend reading the `notes/`, `docs/`, and `issues/` directories.

### Project Categories

**Meta & Tooling** forms the foundation: `delta-version` manages the repository itself, `scripts/` provides shared utilities, `progress-ii` handles visualization, and `project-orchestration` coordinates multi-project work.

**AI & Language Processing** includes `neocities-modernization` (LLM embeddings for poetry navigation), `words-pdf` (PDF text extraction), `llm-transcripts` (conversation management), and `intelligence-system` (reasoning frameworks).

**Games & Game Engines** is the largest category, with 18 projects spanning `world-edit-to-execute` (WC3 map parsing), `RPG-autobattler`, `healer-td`, `console-demakes` (Game Boy Color), and various game design experiments in `game-design/`.

**Learning & Symbolic Systems** explores `symbeline-realms`, `risc-v-university`, and `lua-stories`.

**Tools & Utilities** covers `handheld-office`, `resume-generation`, `authorship-tool`, and the `factorIDE` projects.

---

## The Structure

Every project follows a canonical directory layout:

```
project-name/
├── docs/           Documentation and guides
├── notes/          Planning, vision, brainstorming
├── src/            Source code
├── libs/           Project-specific libraries
├── issues/         Issue tracking
│   ├── phase-n/    Issues organized by phase
│   └── completed/  Archived completed issues
├── input/          Input files for processing
├── output/         Generated outputs
└── tmp/            Project-specific temporary files
```

The first thing a program should do is read `input/`. The last thing it should do is write to `output/`. This lifecycle makes programs composable: one project's output becomes another's input.

---

## The Standards

### Code Organization

Functions use vimfolds for consistent structure:

```lua
-- {{{ print_hello_world
local function print_hello_world(text)
    print(text or "Hello, World!")
end
-- }}}
```

Scripts begin with a header comment explaining purpose and usage at an executive level—fit for someone who needs to know what a script does without reading its implementation.

Scripts accept a `DIR` argument and use it for all path resolution, allowing execution from any working directory.

### Dependency Management

Libraries install locally to each project rather than globally. This keeps projects self-contained and reproducible—anyone cloning a project gets exactly the dependencies it needs without polluting their system or conflicting with other projects.

Each project maintains its dependencies in `libs/`:

```
project-name/
├── libs/
│   ├── json.lua          # Vendored directly
│   ├── socket/           # Multi-file library
│   └── install.sh        # Fetches external deps
└── scripts/
    └── run.sh            # Entry point
```

The `install.sh` script handles all dependency acquisition. It should be idempotent (safe to run multiple times) and explicit about what it fetches:

```bash
#!/bin/bash
# install.sh - Fetch all project dependencies
# Downloads json.lua and luasocket to libs/

DIR="${1:-$(dirname "$0")/..}"
LIBS_DIR="$DIR/libs"

mkdir -p "$LIBS_DIR"

# Fetch json.lua if missing
if [ ! -f "$LIBS_DIR/json.lua" ]; then
    curl -o "$LIBS_DIR/json.lua" \
        "https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"
fi

# Fetch luasocket if missing
if [ ! -d "$LIBS_DIR/socket" ]; then
    # ... installation steps
fi
```

The `run.sh` script serves as the single entry point. It ensures dependencies exist, sets up the environment, and launches the application:

```bash
#!/bin/bash
# run.sh - Launch the application
# Ensures dependencies are installed, then runs main.lua

DIR="${1:-$(dirname "$0")/..}"

# Ensure dependencies
"$DIR/scripts/install.sh" "$DIR"

# Set library path to include project libs
export LUA_PATH="$DIR/libs/?.lua;$DIR/src/?.lua;;"

# Launch
luajit "$DIR/src/main.lua" "$@"
```

This creates a clean workflow: clone the repo, run `libs/install.sh`, then `./scripts/run.sh` and everything works. No manual dependency hunting. No "works on my machine." The install script documents exactly what external code the project needs, configured to spec, and the run script pipelines the entire launch process into a single command.

### Interface Documentation

In C, header files (`.h`) declare what a module exposes without revealing implementation. Compilers use them to verify correct usage. Many languages don't have this concept, and even in C, headers serve compilers rather than humans.

The `.info.md` pattern solves this. Each source file gets a corresponding markdown file listing its external functions, their signatures, and brief descriptions. This creates language-agnostic header files optimized for human and LLM consumption.

Here's an example documenting a task worker module with a dispatch table pattern:

```markdown
# task_worker.lua

## Overview

Executes tasks by ID using a dispatch table. Call `run_task(id, args)`
where `id` indexes into the task registry. More efficient than switch
statements; adding tasks requires no control flow changes.

## Dispatch Table

| ID |       Task       |  Required Args   | Optional Args |     Returns     |
|----|------------------|------------------|---------------|-----------------|
| 1  | parse_document   | filepath         | encoding      | ast, errors     |
| 2  | validate_schema  | ast, schema_id   | strict_mode   | valid, messages |
| 3  | transform_output | ast, format      | pretty_print  | output_string   |
| 4  | write_file       | out_string, dest | overwrite     | bytes_written   |
| 5  | notify_complete  | task_chain_id    | webhook_url   | status_code     |

(each of the task functions, arguments, and return values could be documented here as well, but omitted for brevity)

## External Functions

### run_task(id: int, args: table) → result, error
Executes task by dispatch table index. Returns nil, error if ID invalid
or required args missing.

### queue_task(id: int, args: table) → task_handle
Adds task to threadpool queue. Returns handle for status polling.

### await_task(handle: task_handle, timeout_ms: int) → result, error
Blocks until task completes or timeout. Returns nil, "timeout" on timeout.

### get_task_info(id: int) → { name, required_args, optional_args, description }
Returns metadata for task ID without executing.

## Internal (not exported)
- _dispatch_table (the function pointer array)
- _validate_args
- _worker_thread_main
```

The dispatch table format makes the module's capabilities scannable at a glance. A caller can see all available operations, their IDs, and argument requirements without reading implementation code.

The benefit is token efficiency. An LLM exploring a codebase can read `task_worker.info.md` (40 lines) instead of `task_worker.lua` (800 lines) to understand what the module offers. Only when the interface description proves insufficient does it need the full source.

This creates a layered reading strategy: table of contents → info.md summaries → full source. Each layer filters out readers who got what they needed at the previous level.

### Change Documentation

When a change is made, a comment explains why. Not what the code does—that's visible in the code itself—but why this approach was chosen, what alternatives were considered, what constraints apply.

```lua
-- Retry up to 3 times before failing. We chose 3 over 5 based on
-- latency measurements in issue 423: beyond 3 retries, user-perceived
-- delay exceeds acceptable thresholds.
if counter < 3 then counter = counter + 1 else return false
```

### Error Philosophy

Prefer errors over fallbacks. Silent degradation masks problems that compound over time. When a fallback must be used, log it visibly and create an issue to eliminate it.

When a bug is fixed, create a test that validates the fix. The test serves as documentation of expected behavior and prevents regression.

---

## The Coordination Model

### For Sequential Work

Read the issue. Implement the change. Update the issue with what happened. Move to `issues/completed/`. Commit.

### For Parallel Work

Some tasks decompose naturally into independent chunks: processing 1000 files, running tests across modules, applying transformations to data partitions. When chunks don't depend on each other's results, they can execute simultaneously.

The work-stealing pattern coordinates this:

1. **Create a manifest** listing all chunks before starting work
2. **Claim chunks atomically** — a worker marks a chunk "in_progress" with their identifier
3. **Process independently** — each worker handles their claimed chunks
4. **Aggregate results** when all chunks reach "completed"

```lua
-- Task manifest (stored in issues/.tasks/ or similar)
{
    id = "process-dataset",
    created = "2026-02-24",
    chunks = {
        { id = 1, status = "completed", claimed_by = "worker-1", completed_at = "..." },
        { id = 2, status = "in_progress", claimed_by = "worker-2", started_at = "..." },
        { id = 3, status = "unclaimed" },
        { id = 4, status = "unclaimed" },
    }
}
```

**When to apply this pattern:**

- **Issue phases** — when a phase has many independent issues, multiple agents can claim different issues
- **Large refactors** — updating 50 files to use a new API can be split by file or directory
- **Test suites** — running tests across independent modules
- **Data processing** — transforming datasets that partition cleanly

**When not to apply:**

- Tasks with sequential dependencies (step 2 needs step 1's output)
- Small tasks where coordination overhead exceeds parallelism benefit
- Work requiring shared mutable state

The manifest serves as both coordination mechanism and progress tracker. Anyone can inspect it to see what's done, what's in progress, and what remains.

### For Agent Collaboration

Respect your predecessors: don't undo prior work without justification. Leave clear notes for successors. FIXME comments are unsigned work items—investigate the reasoning before modifying.

When multiple agents align on a decision, the system state changes qualitatively. Document consensus decisions and their rationale.

---

## The Philosophy

### Design Over Product

The interest here is software design, not product development. Architectural elegance matters. Structure matters. Design documents are as important as working code.

### Separation of Concerns

Data generation and data viewing are separate systems. Generators write to standardized formats. Viewers read from those formats. Neither crosses the boundary. Errors localize to one side.

### Upgrade Over Replace

Don't throw away and rebuild. Extend existing capabilities. Maintain compatibility with old interfaces. Provide migration paths rather than breaking changes.

### Informative Negation

"De-selected" is more informative than "not selected." The former implies history: something was selected, then un-selected. Apply this principle to variable names, log messages, error reports.

---

## Getting Started

To understand a project, read its `notes/vision` document first, then `docs/roadmap.md`, then browse `issues/` to see current and completed work.

To contribute, find or create an issue file before making changes. Follow the naming convention. Update the phase progress file when completing issues. Commit atomically—one issue, one commit.

### Key Resources

- `QUICK-START.md` — Quick reference for common operations
- `TROUBLESHOOTING.md` — Solutions to common problems
- `delta-version/docs/` — Comprehensive documentation suite
  - `delta-guide.md` — Full mono-repo guide
  - `worktree-guide.md` — Git worktree workflows
  - `development-guide.md` — Development standards
  - `issue-template.md` — Standard issue format

---

## Appendix: Directive Reference

The following directives govern development. Priority indicates enforcement level.

| ID | Directive | Priority |
|----|-----------|----------|
| D-003 | Canonical directory structure | Critical |
| D-005 | Issue naming convention | Critical |
| D-007 | Issue-first development | Critical |
| D-041 | No changes without issues | Critical |
| D-051 | Info.md interface files | Critical |
| D-021 | Change comments with rationale | Critical |
| D-028 | Consensus decision documentation | Critical |
| D-008 | Fail-loud error handling | High |
| D-009 | Phase progress tracking | High |
| D-014 | Script header comments | High |
| D-019 | Separation of concerns | High |
| D-045 | Agent etiquette | High |
| D-054 | Work-stealing coordination | High |
| D-055 | Local lib installation with install.sh | High |
| D-056 | Single-command launch via run.sh | High |
| D-001 | Script portability via DIR | Medium |
| D-002 | Vimfold function organization | Medium |
| D-011 | Commits on issue completion | Medium |
| D-038 | Program lifecycle (input→output) | Medium |
| D-043 | Informative negation | Medium |

---

## Appendix: Full Project Progress

28 projects with issue tracking. 659 completed. 1,221 total. 54% overall.

| Project | Progress | % |
|---------|----------|---|
| symbeline-realms | 177/198 | 89% |
| handheld-office | 38/54 | 70% |
| world-edit-to-execute | 201/300 | 67% |
| neocities-modernization | 151/231 | 65% |
| adroit | 14/23 | 61% |
| RPG-autobattler | 35/66 | 53% |
| words-pdf | 8/19 | 42% |
| delta-version | 29/101 | 29% |
| games/wow-chat-2 | 3/11 | 27% |
| ai-playground | 1/7 | 14% |
| scripts | 1/27 | 4% |
| translation-layer-wow-chat-city-of-chat | 0/55 | 0% |
| progress-ii | 0/31 | 0% |
| ao3-source-code-import | 0/21 | 0% |
| dark-volcano | 0/12 | 0% |
| healer-td | 0/12 | 0% |
| continual-co-operation | 0/9 | 0% |
| authorship-tool | 0/8 | 0% |
| games/city-of-chat | 0/8 | 0% |
| games/gameboy-color-rpg | 0/7 | 0% |
| symbeline-2 | 0/6 | 0% |
| factor-IDE-2 | 0/5 | 0% |
| risc-v-university | 0/5 | 0% |
| console-demakes | 0/1 | 0% |
| game-design/pyrrhic-victory | 0/1 | 0% |
| links-awakening | 0/1 | 0% |
| llm-http | 0/1 | 0% |
| spatial-drones | 0/1 | 0% |

---

*"They want you to think about then, so that you aren't able to think about now."*

---

License: Individual projects may have their own licenses. See each project's directory for details.
