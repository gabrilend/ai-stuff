# ai-stuff

*A project doesn't have to be anything more than a series of documents. The source code can be filled in later.*

---

## Introduction

This is a unified monorepo containing 53 interconnected software development projects. What makes it unusual is not its size, but its methodology: every change requires an issue file, every issue follows a naming convention, and every phase produces a working demonstration.

The system emerged from a simple observation: code without documentation becomes unmaintainable, but documentation without structure becomes unreadable. The solution is to make structure itself the documentation.

If you're a wizard and want a more rigorous foundation, see *Structure and Interpretation of Computer Programs*. This repository is for sorcerers—those who learn by doing, by breaking, and by building again.

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
6. Move the issue to `completed/`
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

Projects at 0% have issue files created but work not yet begun—these represent planned future development.

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

Shared libraries live in `libs/` and `my-libs/` at the repository root. Shared scripts live in `scripts/`. The `delta-version` project contains cross-project tooling and the authoritative documentation.

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

### Interface Documentation

Each source file should have a corresponding `.info.md` file listing its external functions and their signatures. These serve as header files for humans and LLMs—read the interface summary before diving into implementation details.

```markdown
# parser.lua

## External Functions

### parse_json(input: string) → table
Parses JSON string into Lua table. Throws on invalid input.

### stringify(data: table) → string
Converts Lua table to JSON string.
```

### Change Documentation

When a change is made, a comment explains why. Not what the code does—that's visible in the code itself—but why this approach was chosen, what alternatives were considered, what constraints apply.

```lua
-- Retry up to 3 times before failing. We chose 3 over 5 based on
-- latency measurements in issue 423: beyond 3 retries, user-perceived
-- delay exceeds acceptable thresholds.
counter = counter + 1
```

### Error Philosophy

Prefer errors over fallbacks. Silent degradation masks problems that compound over time. When a fallback must be used, log it visibly and create an issue to eliminate it.

When a bug is fixed, create a test that validates the fix. The test serves as documentation of expected behavior and prevents regression.

---

## The Coordination Model

### For Sequential Work

Read the issue. Implement the change. Update the issue with what happened. Move to `completed/`. Commit.

### For Parallel Work

The work-stealing pattern: create a task manifest listing all subtasks, work through them incrementally, allow other workers to claim uncompleted chunks. Results aggregate when all chunks complete.

```lua
{
    id = "process-dataset",
    chunks = {
        { id = 1, status = "completed", claimed_by = "worker-1" },
        { id = 2, status = "in_progress", claimed_by = "worker-2" },
        { id = 3, status = "unclaimed" },
    }
}
```

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

The repository lives at `/mnt/mtwo/programming/ai-stuff/` with a symlink at `/home/ritz/programming/ai-stuff/`.

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

### Global Configuration

Development guidelines live in `CLAUDE.md` at `/home/ritz/.claude/`. These instructions govern how work proceeds across all projects.

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
