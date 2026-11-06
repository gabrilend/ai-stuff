# ai-stuff

this project is not intended to confuse or distract you. It is something fun, beautiful, artistic, whatever, to explore, while you use the main tools and utilities of the project, which is rmail, the ceramic core engine, etc... whatever you find use in. feel free to patch or improve or even just build any of these for your own use. They are AGPL, so if you want to use them you gotta do so by sending someone a copy of your source-code. Nothing less.

I've noticed recently that people are building large stacks of artwork and hiding secret messages in them. That's stupid. Don't hide your secrets, tell them. Use rmail. I'm like, pretty sure it works. I mean, it's a work in progress of course, but it'll never get worse, and it's always improving.

god I wish I had like, 200,000$ in bitcoin.

A mesh network can never track you unless it follows you. This is the beauty and peril of [a city square with people, but pronounced living in the modern age], you can always tell when you're noticed.

"hey so-and-so was asking about you again"

[cross dressing, but pronounced trans] is the art of "boobs are part of the outfit"

said some guy in a 70s bar

"drag queens are sexy, not opinionated" said some guy manually examining LLM connections

I dunno, maybe the collective spirit of humanity is bad.

I know we're trending toward good,

but perhaps part of that is letting go-behind all of the [parts of yourself which both control and destroy you, but pronounced herd]

"isolation is it's own reward." said some guy in the modern age

"the jedi order created the sith" said some guy who was the bad guy

"I'm not a bad guy" said I and probably some other guys

I tell the truth because it is right not to lie. such is a principled life.

"delibertarian" for a prosperous life.

---

*A project doesn't have to be anything more than a series of documents. The source code can be filled in later.*

---

## Introduction

This is a unified monorepo containing <!-- census:projects:words -->one hundred and one<!-- /census --> projects. <!-- census:top_level:Words -->Eighty-two<!-- /census --> sit at the top level; the other <!-- census:on_shelves:words -->nineteen<!-- /census --> live on a shelf inside another directory — a game under `games/`, a study under `game-design/`, a device under `roms/`, a subproject under `symbeline-realms/subprojects/`. <!-- census:loose_ideas:Words -->Thirteen<!-- /census --> further ideas are loose notes on those shelves, written down and not yet given a directory of their own. What makes it unusual is not its size, but its methodology: every change requires an issue file, every issue follows a naming convention, and every phase produces a working demonstration.

Every number on this page is regenerated rather than retyped. `delta-version/scripts/census-projects.lua --write-readme` rewrites them in place, and `--check-readme` names any that have gone stale; run it when a figure here looks old, because it will be.

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

Nothing in it is hidden inside the artwork. A secret worth keeping in a picture is a decision worth telling in an issue, in plain words, where anyone can read it; and like the mail the opening lines recommend, an issue is a work in progress that can be added to and never made worse, only improved.

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

Of the <!-- census:projects:words -->one hundred and one<!-- /census -->, <!-- census:tracked:digits -->63<!-- /census --> track issues, <!-- census:building:digits -->21<!-- /census --> are building without them, <!-- census:vision:digits -->16<!-- /census --> are a vision document waiting to start, and <!-- census:empty_clause:text -->one is an empty directory<!-- /census -->. A project with no issue file is not a failed project; it is one that has not needed the apparatus yet, and the apparatus is what the rest of this page describes.

Across the <!-- census:tracked:digits -->63<!-- /census --> that track: <!-- census:completed:digits -->1,479<!-- /census --> issues completed out of <!-- census:issues:digits -->3,213<!-- /census -->, which is <!-- census:percent:digits -->46<!-- /census -->% overall. Another <!-- census:shelved:digits -->64<!-- /census --> issues are shelved — filed under an archive or marked superseded, meaning set aside or overtaken rather than finished. Those are counted apart and never folded into the completed figure, so retiring a mode cannot inflate a percentage.

The wish at the top of this page was for two hundred thousand dollars in bitcoin. What the page can count instead is the ledger above, and not one entry in it can be spent; every one of them can be read.

### Active Development

Ranked by how many file changes git recorded inside each project over the last
three months, which is where the attention actually went rather than where the
issue count is highest:

<!-- census:active_table -->
| Project | Focus | Issues | Phases |
|---------|-------|--------|--------|
| **world-edit-to-execute** | Reads a Warcraft III map and plays it again in a new engine, scriptable in Lua, wearing whatever art its modders bring | 263/411 | 16 |
| **neocities-modernization** | Poetry website with GPU-accelerated LLM similarity navigation | 210/316 | 17 |
| **poor-person-google-glass** | Glasses with no camera and no lens: a laser shaped by sliding slotted tabs, turned outward by a mirror cylinder | 13/37 | 7 |
| **hero-less-moba** | A lane-pushing game with the heroes, jungle, and item shop removed, to see what is still standing | 0/94 | 9 |
| **centered-ui-design** | A team strategy game whose controls sit in the middle of the map, on a rotating glass-and-metal wheel everyone votes through | 5/73 | 10 |
| **six-sided-dice-layer-cake** | A blueprint set a materials engineer could build from, every dimension given or derived | 96/96 | 14 |
| **my-own-custom-vtt** | A virtual tabletop: several people at different computers sharing one imaginary space | 96/105 | 13 |
| **scripts** | The shared workshop every project borrows from: the commit gate, the issue checker, the progress dashboard, the transcript keepers | 20/70 | — |
| **burner-of-down-things** | Takes a piece of software, describes it in issue files, and delivers a design that meets them | 60/111 | 10 |
| **kanji-learning-image-generator** | For each kanji, a recipe for a picture, where the picture is the kanji | 33/44 | 5 |
| **jurassic-maze** | A maze of stacked stone at a fixed corner-on angle, with a simulation inside that nobody plays and nobody wins | 55/60 | 10 |
<!-- /census -->

The phases column counts phases *defined*, not phases finished. A project with
nine phases and one completed issue has designed the whole shape and built one
piece of it, which is the normal order of work here. Where the progress
dashboard cannot tell how a project's issue names divide into phase and number,
the count comes from the project's own phase progress files instead, and where
there are none the cell is "—": the census would rather say nothing than guess.
The ranking leaves out a project's materials: what it reads in, what it
generates, and its saved conversations. What each project is
*for* is the one column no program can count; those sentences are kept by hand
in `delta-version/assets/project-focus.lua`.

Every project's standing, most finished first, is in
[the appendix](#appendix-full-project-progress) at the foot of this page.

Feel free to poke around. I recommend reading the `notes/`, `docs/`, and `issues/` directories.

### Project Categories

**Meta & Tooling** forms the foundation: `delta-version` manages the repository itself and holds the project finder and the census this page is built from, `scripts/` provides shared utilities, `progress-ii` handles visualization, and `project-orchestration` coordinates multi-project work.

**AI & Language Processing** includes `neocities-modernization` (LLM embeddings for poetry navigation), `words-pdf` (poems laid out as pages with artwork keyed to each poem), `llm-transcripts` (conversation management), `llm-http`, and `intelligence-system` (reasoning frameworks).

**Games & Game Engines** is the largest category by a wide margin, spanning `hero-less-moba`, `supcom-derivative-clone`, `games/enheim-tome`, `jurassic-maze`, `world-edit-to-execute` (WC3 map parsing), `RPG-autobattler`, `healer-td`, `console-demakes` (Game Boy Color), the rest of the shelf under `games/`, and the design experiments in `game-design/`.

**Hardware & Devices** has grown into a category of its own: `soren-ds` (a handheld operating system for the Anbernic RG DS), `apple-IIds`, `six-sided-dice-layer-cake` (buildable blueprints), `graphene-factory`, `usb-c-universal-encoder`, and `handheld-office`.

**Learning & Symbolic Systems** explores `symbeline-realms`, `risc-v-university`, `kanji-learning-image-generator`, and `lua-stories`.

**Tools & Utilities** covers `resume-generation`, `authorship-tool`, `backwards-reader`, `filesystem-tapestry`, and the `factorIDE` projects.

---

## The Structure

Every project follows a canonical directory layout:

```
project-name/
├── notes/vision          Where it came from, in the author's own words
├── docs/                 Documents, numbered in reading order
│   ├── table-of-contents.md   Every document, as a tree
│   ├── balance-updates.md     Append-only ledger of knobs turned
│   └── HTML/                  Generated browsable copy, cross-linked
├── src/                  Source, numbered, each with a companion .info.md
├── libs/                 Project-local libraries, installed from a manifest
├── assets/               Data tables: every tunable number, in no document
├── tests/                Often written before the source they specify
├── issues/               Blueprints, named {PHASE}{ID}-{description}
│   ├── phase-n-progress.md    One tracker per phase, kept after it ends
│   └── completed/             Archived, never deleted
│       └── demos/             Phase demos: part of the deliverable
├── input/                Read first, at startup
├── output/               Written last; goodbye goes here
├── desire/               What we would like to be better
├── faith/                Expectation of boons and blessings
├── strategems/           Data-flow patterns that keep working
├── llm-transcripts/      The development, as conversation; rides with commits
├── .file-index-counter   Highest file index claimed, across the whole project
└── tmp/ → /tmp/project-name                  RAM tier, executable
    └── shared-memory/ → /dev/shm/project-name   RAM tier, logs and artefacts
```

The first thing a program should do is read `input/`. The last thing it should do is write to `output/`. This lifecycle makes programs composable: one project's output becomes another's input.

Ephemeral output never touches the disk. A project's `tmp/` is a symlink into `/tmp/`, which holds anything that needs to be executable, and `tmp/shared-memory/` is a second symlink into `/dev/shm/`, which is guaranteed RAM and holds logs and build artefacts. A run script creates both before it writes a line. Like the mesh network in the opening lines, a scratch file can never be tracked unless something follows it: once the power goes, whatever lived only in RAM leaves no trail, and you can always tell what was noticed, because it is what got written down.

The layout is a standard, not a census. It is kept by as many projects as have needed it — <!-- census:tmp_symlink:digits -->40<!-- /census --> have the RAM-tier symlink, <!-- census:input_dir:digits -->33<!-- /census --> read from an `input/` directory, <!-- census:transcripts:digits -->40<!-- /census --> carry their transcripts, <!-- census:index_counter:digits -->28<!-- /census --> number their files from a single counter, <!-- census:html_copy:digits -->23<!-- /census --> build the browsable HTML copy, and <!-- census:info_md:digits -->1,310<!-- /census --> source files across the repository have a companion `.info.md` beside them. `census-projects.lua --conventions` counts them again whenever you want to know how far the standard has actually spread.

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

The `install.sh` script handles all dependency acquisition. It takes a `DIR` argument so it runs from anywhere, it is idempotent — safe to run twice, fetching only what is missing — and it is explicit about what it pulls and from where. The `run.sh` script is the single entry point: it calls the installer, sets `LUA_PATH` to the project's own `libs/` and `src/`, and launches.

This creates a clean workflow: clone the repo, run `libs/install.sh`, then `./scripts/run.sh` and everything works. No manual dependency hunting. No "works on my machine." The install script documents exactly what external code the project needs, configured to spec, and the run script pipelines the entire launch process into a single command.

### Interface Documentation

In C, header files (`.h`) declare what a module exposes without revealing implementation. Compilers use them to verify correct usage. Many languages don't have this concept, and even in C, headers serve compilers rather than humans.

The `.info.md` pattern solves this: [a header file, but pronounced for people]. Each source file gets a corresponding markdown file listing its external functions, their signatures, and brief descriptions. This creates language-agnostic header files optimized for human and LLM consumption. The interface is not a costume pulled over the source; it is part of the outfit, the part the world meets first.

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

The dispatch table format makes the module's capabilities scannable at a glance. A caller can see all available operations, their IDs, and argument requirements without reading implementation code. The guy manually examining LLM connections, quoted at the top of this page, would recognise the ideal: an interface should be striking, not opinionated. It shows everything it can do and leaves the choosing to the caller.

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

Prefer errors over fallbacks. Silent degradation masks problems that compound over time. When a fallback must be used, log it visibly and create an issue to eliminate it. Every fallback is an order that creates its own sith: the path built to keep the system safe becomes the place its failures learn to hide.

When a bug is fixed, create a test that validates the fix. The test serves as documentation of expected behavior and prevents regression. A test tells the truth because it is right not to lie, and it has no other way to be; a principled codebase is one where that is true of every check.

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

Respect your predecessors: don't undo prior work without justification. Leave clear notes for successors, clear enough that the next one can say "hey, so-and-so was asking about you again" and know exactly who was asking, and about what. FIXME comments are unsigned work items—investigate the reasoning before modifying.

When multiple agents align on a decision, the system state changes qualitatively. Document consensus decisions and their rationale. A collective can be wrong together; a herd is what a crowd becomes when nobody writes down why. Written reasons are what let a group trend toward good, and let go-behind whatever both drove it and was destroying it, once a better reason arrives.

---

## The Philosophy

### Design Over Product

The interest here is software design, not product development. Architectural elegance matters. Structure matters. Design documents are as important as working code. Call it "delibertarian", as the top of the page does: every decision made deliberately, and everything made given away, for a prosperous life in the commons.

### Separation of Concerns

Data generation and data viewing are separate systems. Generators write to standardized formats. Viewers read from those formats. Neither crosses the boundary. Errors localize to one side. Here, at least, isolation is its own reward: a failure that cannot reach its neighbour is a failure already half found.

### Upgrade Over Replace

Don't throw away and rebuild. Extend existing capabilities. Maintain compatibility with old interfaces. Provide migration paths rather than breaking changes.

### Informative Negation

"De-selected" is more informative than "not selected." The former implies history: something was selected, then un-selected. Apply this principle to variable names, log messages, error reports. It is the difference between "not a bad guy", which anyone can say (I did, and probably some other guys), and "reformed", which only someone with a history can.

---

## The Look

⭐🌈🦄 ✨ 🐙🐠🐚🪸🐬🌊 ✨ 🌸🌷🌼🌺 ✨ 👗👒🎀👠 ✨ 🦊🦋🐝🐢 ✨ 🍓🍑🍋🍇🍉

The interfaces built here share one look: a black ground, and on it bright,
saturated colour that is never dimmed to be polite. Yellow stars, rainbows and
unicorns; reef blues and coral pinks; flower petals; outfits; animals; fruit.
Terminal menus, HTML documentation, phase demos and generated pictures all
draw from that one palette, so a screen from any project here looks as though
it belongs beside a screen from any other.

---

## Getting Started

To understand a project, read its `notes/vision` document first, then its `docs/table-of-contents.md`, which names every document in reading order and points at the roadmap. Then browse `issues/` to see current and completed work. A project that numbers its documents means the numbers as a reading order across the whole tree, not a per-directory sequence, so 001 through the last of them is a single argument meant to be read front to back.

To contribute, find or create an issue file before making changes. Follow the naming convention. Update the phase progress file when completing issues. Commit atomically—one issue, one commit.

To experiment without touching your own system, there is a sandbox: a container carrying LuaJIT, Vulkan, OpenGL, SDL2 and every project dependency, with the monorepo mounted at `/workspace`. Build it with `./docker-run.sh build`, then run `./docker-run.sh`, which detects your GPU and display and picks X11, VNC, or headless on its own — `./docker-run.sh --help` lists the modes if you want to force one, and VNC's password is `sandbox`. Changes inside are isolated; exit and restart for a clean tree.

The one thing it cannot detect its way out of: an NVIDIA card needs `nvidia-container-toolkit` installed on the host, or the container falls back to software rendering without saying why. `./docker-run.sh gpu-info` reports what it found.

### Key Resources

- `QUICK-START.md` — Quick reference for common operations
- `TROUBLESHOOTING.md` — Solutions to common problems
- `design-resume.md` — The directive registry, with the reasoning behind each rule
- `delta-version/scripts/list-projects.sh` — Find every project in the repository
- `delta-version/scripts/census-projects.lua` — Count them, and the issues under them; the source of this page's figures
- `scripts/progress-dashboard.lua` — Per-phase progress bars for one project
- `delta-version/docs/` — Comprehensive documentation suite
  - `delta-guide.md` — Full mono-repo guide
  - `worktree-guide.md` — Git worktree workflows
  - `development-guide.md` — Development standards
  - `issue-template.md` — Standard issue format

---

## Appendix: Directive Reference

The following directives govern development. Priority indicates enforcement
level. The full registry, with a written section behind each entry, is in
[design-resume.md](design-resume.md); this table is the subset that shapes
day-to-day work.

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
| D-063 | Local lib installation with install.sh | High |
| D-064 | Single-command launch via run.sh | High |
| D-049 | Bug fix implies a test | High |
| D-053 | Transcript archives ride with commits | High |
| D-057 | Dynamic documentation | High |
| D-060 | Code as story: files numbered in reading order | High |
| D-001 | Script portability via DIR | Medium |
| D-002 | Vimfold function organization | Medium |
| D-011 | Commits on issue completion | Medium |
| D-038 | Program lifecycle (input→output) | Medium |
| D-043 | Informative negation | Medium |
| D-061 | Table-of-contents generation | Medium |
| D-062 | Phase demos as deliverables | Medium |

---

## Appendix: Full Project Progress

Every project in the repository, most finished first, then the ones building
without issue tracking, then the ones that are still an intention. <!-- census:projects:digits -->101<!-- /census --> projects:
<!-- census:tracked:digits -->63<!-- /census --> track issues, <!-- census:building:digits -->21<!-- /census --> are building without them, <!-- census:vision:digits -->16<!-- /census --> are a vision document waiting
to start, and <!-- census:empty_clause:text -->one is an empty directory<!-- /census -->. <!-- census:completed:digits -->1,479<!-- /census --> issues completed of <!-- census:issues:digits -->3,213<!-- /census -->, <!-- census:percent:digits -->46<!-- /census -->%
overall, with <!-- census:shelved:digits -->64<!-- /census --> more shelved. Regenerate with
`delta-version/scripts/census-projects.lua --write-readme`.

A completed project is not a finished one. `six-sided-dice-layer-cake` has
closed every issue it has; that means the blueprint set answers every question
anyone has asked of it so far, not that nobody will ask another. Nor is a project
at zero an idle one — `hero-less-moba` has closed nothing, because its
<!-- census:total@hero-less-moba:words -->ninety-four<!-- /census --> issues are a design written down before a line of it is built.

Who did the work, in characters:

- **Human-written text:** <!-- census:human_written:millions -->2.5 million<!-- /census --> — what the person typed across every saved conversation, and every `notes/` folder
- **Machine-written text:** <!-- census:machine_written:millions -->12.2 million<!-- /census --> — what the model wrote across every saved conversation
- **Source code generated:** <!-- census:source_generated:millions -->25.8 million<!-- /census --> — the repository's own code, vendored libraries left out
- **Docs generated:** <!-- census:docs_generated:millions -->25.4 million<!-- /census --> — documents, `.info.md` files and issue files

Pasted error logs and program output are not counted as the person's; pasted
prose is, since pasting it meant reading it first.
`delta-version/scripts/measure-authorship.lua` shows how each piece was credited.

<!-- census:appendix_table -->
| Project | Progress | % |
|---------|----------|---|
| six-sided-dice-layer-cake | 96/96 | 100% |
| games/physics-sim | 186/189 | 98% |
| jurassic-maze | 55/60 | 92% |
| my-own-custom-vtt | 96/105 | 91% |
| symbeline-realms | 177/204 | 87% |
| handheld-office | 38/50 | 76% |
| kanji-learning-image-generator | 33/44 | 75% |
| every-software-image-able | 28/39 | 72% |
| neocities-modernization | 210/316 | 66% |
| world-edit-to-execute | 263/411 | 64% |
| gif-generator | 25/41 | 61% |
| burner-of-down-things | 60/111 | 54% |
| RPG-autobattler | 35/66 | 53% |
| adroit | 9/17 | 53% |
| words-pdf | 16/32 | 50% |
| screen-record-stream | 1/2 | 50% |
| delta-version | 49/124 | 40% |
| poor-person-google-glass | 13/37 | 35% |
| scripts | 20/70 | 29% |
| soren-ds | 49/176 | 28% |
| games/3d-rts | 7/29 | 24% |
| usb-c-universal-encoder | 2/10 | 20% |
| my-libs | 1/8 | 13% |
| centered-ui-design | 5/73 | 7% |
| games/first-person-spellcraft | 3/93 | 3% |
| distant-computer | 1/34 | 3% |
| supcom-derivative-clone | 1/76 | 1% |
| apple-IIds | 0/131 | 0% |
| hero-less-moba | 0/94 | 0% |
| games/enheim-tome | 0/91 | 0% |
| translation-layer-wow-chat-city-of-chat | 0/56 | 0% |
| guide-feature | 0/47 | 0% |
| ai-movie-generator | 0/32 | 0% |
| progress-ii | 0/31 | 0% |
| quantity-reception-optimizer | 0/24 | 0% |
| ao3-source-code-import | 0/21 | 0% |
| roms/symbeline-rumble | 0/19 | 0% |
| wow-reports | 0/18 | 0% |
| ut2k4-symbeline-rumble | 0/17 | 0% |
| dark-volcano | 0/12 | 0% |
| healer-td | 0/12 | 0% |
| symbeline-realms/subprojects/android-screen-filter | 0/9 | 0% |
| authorship-tool | 0/8 | 0% |
| dominions-interpreter | 0/8 | 0% |
| games/city-of-chat | 0/8 | 0% |
| continual-co-operation | 0/7 | 0% |
| filesystem-tapestry | 0/7 | 0% |
| games/gameboy-color-rpg | 0/7 | 0% |
| ai-playground | 0/6 | 0% |
| symbeline-2 | 0/6 | 0% |
| factor-IDE-2 | 0/5 | 0% |
| risc-v-university | 0/5 | 0% |
| xonotic-turning-radius | 0/4 | 0% |
| ruby-forge | 0/3 | 0% |
| ssh-view-only-viewer-script | 0/3 | 0% |
| game-design/pyrrhic-victory | 0/2 | 0% |
| 3d-generation-multiplayer-server | 0/1 | 0% |
| RGPL-license-development | 0/1 | 0% |
| console-demakes | 0/1 | 0% |
| games/wow-chat-2 | 0/1 | 0% |
| links-awakening | 0/1 | 0% |
| llm-http | 0/1 | 0% |
| spatial-drones | 0/1 | 0% |
| adventure-hero-quest-mega-max-ultra | — | *no issues filed* |
| backwards-reader | — | *no issues filed* |
| cloudtop-contest | — | *no issues filed* |
| factorIDE | — | *no issues filed* |
| factory-war | — | *no issues filed* |
| game-design/ai-fsm-concept | — | *no issues filed* |
| game-design/game-design-process | — | *no issues filed* |
| game-design/legion-dominions | — | *no issues filed* |
| game-design/mech-commander | — | *no issues filed* |
| game-design/playstyle-balance-theory | — | *no issues filed* |
| games/galactic-battlegrounds | — | *no issues filed* |
| games/malazan-army-on-the-move-web-game-toon | — | *no issues filed* |
| git-status-viewer | — | *no issues filed* |
| graphene-factory | — | *no issues filed* |
| lua-stories | — | *no issues filed* |
| mGBA-link-cable-support | — | *no issues filed* |
| magic-rumble | — | *no issues filed* |
| progress-reports | — | *no issues filed* |
| raleigh3 | — | *no issues filed* |
| resume-generation | — | *no issues filed* |
| symbeline | — | *no issues filed* |
| a-hat-in-dual-screen | — | *a vision, not yet started* |
| ceramic-corporation | — | *a vision, not yet started* |
| console-demakes-2 | — | *a vision, not yet started* |
| dominions-modernization | — | *a vision, not yet started* |
| games/nazi-heaven | — | *a vision, not yet started* |
| games/star-realms-tui | — | *a vision, not yet started* |
| intelligence-system | — | *a vision, not yet started* |
| jrpg-swarm | — | *a vision, not yet started* |
| math-solving-algorithm | — | *a vision, not yet started* |
| picture-generator | — | *a vision, not yet started* |
| programming-project-analysis | — | *a vision, not yet started* |
| project-orchestration | — | *a vision, not yet started* |
| ruby-castle | — | *a vision, not yet started* |
| runescape-too | — | *a vision, not yet started* |
| shanna-lib | — | *a vision, not yet started* |
| video-transcription | — | *a vision, not yet started* |
| magicka-forge-guide | — | *empty* |

`game-design/` holds 6 further ideas as loose notes, written down and not yet given a directory.

`new-projects/` holds 7 further ideas as loose notes, written down and not yet given a directory.

Not projects: docker-scripts, ideas, libs, llm-transcripts, notes, skills.
<!-- /census -->

---

*"They want you to think about then, so that you aren't able to think about now."*

---

The opening paragraph asks one thing of anyone who uses this with someone else: send them your source. The draft `RGPL` beside the licence (Our Great Public Library) is written to make that request binding.

License: GNU Affero General Public License, version 3 or later. The full license text is in LICENSE; COPYRIGHT explains what it covers, which subdirectories hold vendored third-party code under their own terms, and what the Affero clause adds on top of the ordinary GPL.
