# Issue 051: Git Repository Documentation Generator

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-12
**Related**: Issue 035 (Project History Reconstruction - Inverse Operation)

---

## Current Behavior

There is no automated tooling to generate project documentation (vision documents, roadmaps, issue files, phase demos) from an existing git repository. When a project exists with commits but lacks the structured documentation system described in CLAUDE.md, developers must manually:

1. Read through commit history to understand project evolution
2. Manually write vision documents retrospectively
3. Create issue files by hand-analyzing what was accomplished
4. Guess at phase boundaries based on feature groupings
5. Write phase demos from scratch without guidance

This is time-consuming, error-prone, and results in inconsistent documentation quality across projects.

### The Documentation Gap

```
Existing Project State:
┌─────────────────────────────────────────────────────────┐
│  commit abc123: Initial project setup                   │
│  commit def456: Add core parser module                  │
│  commit ghi789: Implement caching layer                 │
│  commit jkl012: Fix edge case in parser                 │
│  ... (100+ commits)                                     │
│  commit xyz999: Current state (feature complete)        │
└─────────────────────────────────────────────────────────┘

Desired Documentation:
┌─────────────────────────────────────────────────────────┐
│  notes/vision.md         (project intent and goals)     │
│  docs/roadmap.md         (phases and milestones)        │
│  docs/table-of-contents.md                              │
│  issues/001-*.md         (individual work items)        │
│  issues/completed/*.md   (finished work)                │
│  issues/completed/demos/ (phase demonstrations)         │
│  scripts/install-deps.sh (dependency installation)      │
└─────────────────────────────────────────────────────────┘
```

---

## Intended Behavior

Create a utility that **reverse-engineers** structured project documentation from git commit history using AI-assisted analysis. The tool should:

1. **Analyze the arc** from initial commit to current state
2. **Extract the kernel** (original idea/vision) from early commits
3. **Chart the roadmap** by identifying logical phase boundaries
4. **Generate issue files** that correspond to actual development work
5. **Mark completed issues** based on commit evidence
6. **Create phase demos** that demonstrate each phase's capabilities
7. **Generate dependency scripts** for reproducible environments
8. **Network the modules** for interconnected, modular access

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Git Documentation Generator Pipeline                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐                                                        │
│  │ Input: Git Repo │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│  ┌────────▼────────┐     ┌──────────────────────────────────┐              │
│  │ 051a: Analyze   │────▶│ Extract: Initial commit → kernel │              │
│  │ Initial State   │     │          Current state → goal    │              │
│  └────────┬────────┘     └──────────────────────────────────┘              │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051b: Generate Roadmap  │◀── LLM Tool-Call Integration                  │
│  │ (AI-assisted phasing)   │    Programmatic generation via API            │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051c: Generate Issues   │──▶ One issue per logical work unit            │
│  │ from Roadmap            │    Follows issue naming conventions            │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051d: Detect Completion │──▶ Parse commits for completion evidence      │
│  │ Status                  │    Move to issues/completed/ automatically    │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051e: Generate Phase    │──▶ Demo scripts using project utilities       │
│  │ Demos                   │    Shows phase capabilities visually          │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051f: Generate Install  │──▶ Dependency detection and scripting         │
│  │ Scripts                 │    Reproducible environment setup             │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ 051g: Network Modules   │──▶ Interconnect abstractions                  │
│  │ (Modular Interconnect)  │    API layer for tool composition             │
│  └────────┬────────────────┘                                               │
│           │                                                                  │
│  ┌────────▼────────────────┐                                               │
│  │ Output: Fully           │                                               │
│  │ Documented Project      │                                               │
│  └─────────────────────────┘                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Philosophy: The Arc from Kernel to Success

The utility charts a **narrative arc**:

```
      Kernel (Initial Vision)
           │
           │  ╭─────────────────────╮
           │  │ Phase 1: Foundation │
           ▼  ╰─────────────────────╯
          ╱╲
         ╱  ╲     ╭────────────────────────╮
        ╱    ╲    │ Phase 2: Core Features │
       ╱      ╲   ╰────────────────────────╯
      ╱        ╲
     ╱   THE    ╲     ╭─────────────────────────╮
    ╱    ARC     ╲    │ Phase 3: Enhancements   │
   ╱              ╲   ╰─────────────────────────╯
  ╱                ╲
 ╱                  ╲     ╭──────────────────────────╮
▼                    ▼    │ Phase N: Current Success │
                          ╰──────────────────────────╯
           │
           ▼
    Success Mark (Current State)
```

This curve passes through all the significant commits - the "electromechanical machinery of your CPU" - transforming raw development effort into readable narrative.

---

## Suggested Implementation Steps

### Core Script Structure

```bash
#!/bin/bash
# -- {{{ generate-docs-from-history.sh
# Reverse-engineers project documentation from git commit history.
# Transforms an undocumented repository into a fully documented project
# following CLAUDE.md conventions.

# Configuration
DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
LLM_MODEL="${LLM_MODEL:-llama3}"
LLM_ENABLED="${LLM_ENABLED:-true}"
OUTPUT_DIR="${OUTPUT_DIR:-}"  # Defaults to project root
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"

# Pipeline stages (can be run individually)
STAGES=(
    "analyze"      # 051a: Extract kernel and goal
    "roadmap"      # 051b: Generate roadmap via LLM
    "issues"       # 051c: Create issue files
    "completion"   # 051d: Detect and mark completed
    "demos"        # 051e: Generate phase demos
    "install"      # 051f: Create install scripts
    "network"      # 051g: Build module network
)
# }}}
```

### CLI Interface

```bash
# Full pipeline
generate-docs-from-history.sh /path/to/git/repo

# Individual stages
generate-docs-from-history.sh --stage=analyze /path/to/repo
generate-docs-from-history.sh --stage=roadmap /path/to/repo

# Options
    --dry-run                Preview without writing files
    --interactive            Prompt for approval at each stage
    --headless               Run without prompts
    --output-dir=PATH        Write documentation elsewhere
    --llm-model=MODEL        Specify LLM model (default: llama3)
    --no-llm                 Disable LLM, use heuristics only
    --phases=N               Force N phases in roadmap (default: auto-detect)
    --start-commit=HASH      Override initial commit
    --end-commit=HASH        Override target state (default: HEAD)

# Query commands
    --show-kernel            Display extracted project kernel
    --show-arc               Visualize the development arc
    --show-phases            List detected phases
    --show-completion        Show completion status per issue
```

### Output Structure

```
project/
├── notes/
│   └── vision.md                    # Extracted from kernel analysis
├── docs/
│   ├── roadmap.md                   # AI-generated phase breakdown
│   ├── table-of-contents.md         # Auto-generated TOC
│   └── architecture.md              # (optional) System design
├── issues/
│   ├── 001-initial-setup.md
│   ├── 002-core-parser.md
│   ├── 003-caching-layer.md
│   ├── ...
│   ├── progress.md                  # Phase progress tracking
│   └── completed/
│       ├── 001-initial-setup.md     # Moved when complete
│       ├── 002-core-parser.md
│       └── demos/
│           ├── phase-1-demo.sh
│           ├── phase-2-demo.sh
│           └── ...
├── scripts/
│   ├── install-deps.sh              # Dependency installation
│   ├── run-demo.sh                  # Demo runner
│   └── ...
└── libs/                            # (if applicable)
    └── ...
```

---

## LLM Tool-Call Integration

### Programmatic Generation Pattern

The roadmap generation uses LLM tool-calls as a structured API:

```lua
-- -- {{{ Example Lua client for LLM roadmap generation
local function generate_roadmap(commit_history, project_analysis)
    local prompt = [[
You are analyzing a git repository to generate a development roadmap.

Project Kernel (initial vision):
]] .. project_analysis.kernel .. [[

Current State (success mark):
]] .. project_analysis.current_state .. [[

Commit History Summary:
]] .. commit_history.summary .. [[

Generate a roadmap with distinct phases. For each phase:
1. Name the phase
2. List the key accomplishments
3. Identify which commits belong to this phase
4. Describe what capability was added

Output as JSON:
{
  "phases": [
    {
      "number": 1,
      "name": "Foundation",
      "description": "...",
      "commits": ["abc123", "def456"],
      "capabilities": ["...", "..."]
    }
  ]
}
]]

    -- LLM tool-call via ollama
    local response = llm_query(prompt, {
        model = LLM_MODEL,
        format = "json",
        temperature = 0.3  -- Low temp for structured output
    })

    return json.decode(response)
end
-- }}}
```

### Triple-Check Consensus for Critical Decisions

```bash
# -- {{{ llm_roadmap_with_consensus
llm_roadmap_with_consensus() {
    local commit_summary="$1"
    local kernel="$2"
    local current_state="$3"

    local -a responses

    # Get 3 independent roadmap generations
    for i in 1 2 3; do
        responses+=("$(generate_single_roadmap "$commit_summary" "$kernel" "$current_state")")
    done

    # Find consensus on phase count and boundaries
    local phase_counts=$(printf '%s\n' "${responses[@]}" | jq -r '.phases | length' | sort | uniq -c | sort -rn | head -1)
    local consensus_count=$(echo "$phase_counts" | awk '{print $2}')

    # Merge phase assignments using majority vote
    merge_roadmap_responses "${responses[@]}" "$consensus_count"
}
# }}}
```

---

## Symmetry with Issue 035

This tool is the **inverse operation** of Issue 035:

| Issue 035 | Issue 051 |
|-----------|-----------|
| Input: Issue files | Input: Git commits |
| Output: Git history | Output: Issue files |
| Reconstructs commits from docs | Reconstructs docs from commits |
| "Documentation → History" | "History → Documentation" |

Together, they form a **bidirectional translation layer**:

```
┌──────────────────┐                    ┌──────────────────┐
│                  │   Issue 035        │                  │
│  Documentation   │◀───────────────────│   Git History    │
│  (Issue Files)   │                    │   (Commits)      │
│                  │───────────────────▶│                  │
└──────────────────┘   Issue 051        └──────────────────┘
```

This enables:
- **Round-trip validation**: Generate docs, reconstruct history, compare
- **Documentation recovery**: Lost docs can be regenerated from history
- **History recovery**: Lost history can be reconstructed from docs
- **Format migration**: Transform between documentation styles

---

## Sub-Issues

| ID | Title | Status | Description |
|----|-------|--------|-------------|
| **051a** | Initial commit analysis and goal extraction | 📝 Open | Extract kernel from initial commits, define success criteria from current state |
| **051b** | AI-assisted roadmap generation | 📝 Open | LLM tool-call integration for phase detection and roadmap creation |
| **051c** | Issue file generation from roadmap | 📝 Open | Transform roadmap phases into individual issue files |
| **051d** | Completion status detection | 📝 Open | Analyze commits to determine which issues are complete |
| **051e** | Phase demo generation | 📝 Open | Create demonstration scripts for each phase |
| **051f** | Library install script generation | 📝 Open | Detect and script dependency installation |
| **051g** | Module interconnection network | 📝 Open | Build API layer for tool composition and modular access |

### Implementation Order

```
051a (kernel/goal extraction)
  │
  └──▶ 051b (roadmap generation) ──▶ 051c (issue creation)
                                          │
                                          └──▶ 051d (completion detection)
                                                      │
                                          ┌───────────┴───────────┐
                                          │                       │
                                  051e (phase demos)     051f (install scripts)
                                          │                       │
                                          └───────────┬───────────┘
                                                      │
                                              051g (network/API)
```

---

## Acceptance Criteria

### Pipeline Completeness
- [ ] Full pipeline runs without manual intervention (headless mode)
- [ ] Each stage can run independently
- [ ] Dry-run mode previews all changes
- [ ] Interactive mode allows approval at each stage

### Documentation Quality
- [ ] Generated vision.md accurately reflects project intent
- [ ] Roadmap phases are logically coherent
- [ ] Issue files follow CLAUDE.md naming conventions
- [ ] Completed issues are correctly identified and moved
- [ ] Progress.md accurately reflects completion status

### Phase Demos
- [ ] Each phase has a runnable demo script
- [ ] Demos use actual project utilities
- [ ] Demos can be run via run-demo.sh
- [ ] Visual output where applicable (TUI, browser, etc.)

### Install Scripts
- [ ] Dependencies correctly detected from code analysis
- [ ] Install script is idempotent (safe to run multiple times)
- [ ] Cross-platform support (Linux, macOS) where possible

### Module Network
- [ ] API layer enables composition of pipeline stages
- [ ] Modules can be invoked programmatically (Lua, Bash)
- [ ] Clear interface contracts documented

---

## Technical Considerations

### Git Analysis Patterns

```bash
# Get initial commit (kernel source)
git rev-list --max-parents=0 HEAD

# Get commit statistics
git log --oneline --stat

# Get file change frequency (identifies core files)
git log --pretty=format: --name-only | sort | uniq -c | sort -rn

# Get author contributions (for multi-author projects)
git shortlog -sn

# Get commit message patterns (for categorization)
git log --pretty=format:"%s" | head -100
```

### Commit Categorization Heuristics

```
Commit Message Patterns → Issue Types:

"Initial"/"Setup"/"Init"     → Foundation issues
"Add"/"Implement"/"Create"   → Feature issues
"Fix"/"Bug"/"Patch"          → Bug fix issues
"Refactor"/"Clean"/"Improve" → Maintenance issues
"Test"/"Spec"                → Testing issues
"Doc"/"README"/"Comment"     → Documentation issues
"Merge"/"Rebase"             → (Skip or group)
```

### Phase Boundary Detection

Phases typically end when:
1. Major feature is complete (large commits followed by small fixes)
2. Directory structure changes significantly
3. README or documentation updated
4. Version numbers change (package.json, Cargo.toml, etc.)
5. Long time gap between commits

---

## Related Documents

- Issue 035: Project History Reconstruction (inverse operation)
- Issue 035f: Local LLM Integration (shared LLM patterns)
- Issue 049: LLM Transcript Abstraction Viewer (similar LLM usage)
- Issue 040: Dynamic CLAUDE.md Revision System (documentation management)
- CLAUDE.md: Project conventions to follow

---

## Metadata

- **Priority**: High
- **Complexity**: High
- **Dependencies**: None (uses existing tools: git, ollama)
- **Blocks**: Documentation for undocumented projects
- **Impact**: Enables rapid onboarding of legacy projects into documentation system

---

## Risk Assessment

- **Over-segmentation**: LLM might create too many phases
  - Mitigation: User approval, configurable phase count
- **Misattribution**: Commits might be assigned to wrong phases
  - Mitigation: Triple-check consensus, manual override
- **Incomplete kernel extraction**: Initial commits might not reveal true vision
  - Mitigation: Allow manual vision document editing
- **Demo generation failures**: Project might lack runnable entry points
  - Mitigation: Generate stub demos with TODO markers
- **Dependency detection misses**: Some deps might be implicit
  - Mitigation: Parse multiple sources (imports, configs, build files)

---

## Future Extensions

1. **Multi-repository support**: Generate docs for monorepo with multiple projects
2. **Incremental updates**: Re-run on new commits without full regeneration
3. **Custom templates**: User-defined issue and demo templates
4. **CI/CD integration**: Auto-update docs on push
5. **Web UI**: Browser-based interface for non-CLI users
6. **Export formats**: Generate PDF, HTML, Confluence pages

---

## Notes

This tool embodies the philosophy that **code is narrative**. Every commit tells part of a story, and this tool extracts that story into human-readable documentation. The "arc" from kernel to success is not just a metaphor - it's a literal path through the commit graph that can be charted, visualized, and documented.

The LLM integration enables intelligent phase detection that goes beyond simple heuristics. By using tool-calls as a structured API, the generation process becomes reproducible and auditable - every decision can be traced back to specific prompts and responses.
