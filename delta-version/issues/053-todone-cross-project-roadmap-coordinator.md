# Issue 053: TODONE - Cross-Project Roadmap Coordinator

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Related**: Issue 051 (Git Repository Documentation Generator), Issue 023 (Project Listing Utility)

---

## Current Behavior

Projects in `/home/ritz/programming/ai-stuff/` are developed independently, each with their own roadmaps, issue files, and implementation timelines. When multiple projects need similar functionality (threadpools, TUI frameworks, LLM clients, file parsers), each project implements its own version:

1. No visibility into cross-project component overlap
2. Duplicated effort building similar infrastructure
3. No coordinated scheduling to build shared components first
4. Libraries emerge organically rather than by design
5. Synergy opportunities remain invisible until discovered accidentally

### The Redundancy Problem

```
Project A (world-edit-to-execute):        Project B (symbeline-realms):
┌─────────────────────────────────┐      ┌─────────────────────────────────┐
│  Phase 2: Build threadpool      │      │  Phase 3: Build threadpool      │
│  Phase 3: Build TUI framework   │      │  Phase 2: Build TUI framework   │
│  Phase 4: Build LLM client      │      │  Phase 5: Build LLM client      │
└─────────────────────────────────┘      └─────────────────────────────────┘
                 │                                        │
                 └────────────── REDUNDANT ───────────────┘
                            3x duplicated effort
```

### What TODONE Could See

```
Collective Roadmap:
┌─────────────────────────────────────────────────────────────────────────────┐
│  ★ SHARED Phase 1: Build threadpool library (used by: A, B, C)              │
│  ★ SHARED Phase 2: Build TUI framework (used by: A, B, D)                   │
│  ★ SHARED Phase 3: Build LLM client (used by: A, B, E, F)                   │
│                                                                             │
│  Project A Phase 4: Domain-specific features (uses: threadpool, TUI, LLM)   │
│  Project B Phase 4: Domain-specific features (uses: threadpool, TUI, LLM)   │
└─────────────────────────────────────────────────────────────────────────────┘
                        Build once, use everywhere
```

---

## Intended Behavior

Create **TODONE** - a meta-project coordinator that:

1. **Scans all projects** to extract roadmaps, issues, and planned components
2. **Detects similar components** across projects (semantic analysis)
3. **Generates a collective TODO** that schedules shared work first
4. **Outputs to `/home/ritz/programming/ai-stuff/TODO.md`** as a readable roadmap
5. **Uses tiered LLM architecture**: Ollama for reorganization, Anthropic Opus for heavy analysis

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      TODONE Architecture                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PROJECT SCANNER (053a)                            │   │
│  │  list-projects.sh → parse roadmaps → extract issues → normalize      │   │
│  └────────────────────────────────┬────────────────────────────────────┘   │
│                                   │                                         │
│                                   ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │               COMPONENT SIMILARITY DETECTOR (053b)                   │   │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────────┐     │   │
│  │  │ Keyword     │  │ Semantic        │  │ Code Pattern         │     │   │
│  │  │ Matching    │  │ Clustering      │  │ Recognition          │     │   │
│  │  └─────────────┘  └─────────────────┘  └──────────────────────┘     │   │
│  └────────────────────────────────┬────────────────────────────────────┘   │
│                                   │                                         │
│                                   ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              ROADMAP GENERATOR (053c)                                │   │
│  │  Group similar components → Calculate build order → Schedule phases  │   │
│  │  Identify library candidates → Estimate effort reduction             │   │
│  └────────────────────────────────┬────────────────────────────────────┘   │
│                                   │                                         │
│                                   ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                   TODO DOCUMENT OUTPUT (053f)                        │   │
│  │  /home/ritz/programming/ai-stuff/TODO.md                             │   │
│  │  - Collective phases with shared components first                    │   │
│  │  - Per-project work items with dependencies                          │   │
│  │  - Library extraction candidates                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                      LLM INTEGRATION LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────┐  ┌──────────────────────────────────┐   │
│  │  OLLAMA INTEGRATION (053d)   │  │  ANTHROPIC API (053e)            │   │
│  │  - List reorganization       │  │  - Deep semantic analysis        │   │
│  │  - Quick similarity checks   │  │  - Complex roadmap reasoning     │   │
│  │  - Incremental updates       │  │  - Library extraction decisions  │   │
│  │  - Local, fast, cheap        │  │  - "Ollama-style" output format  │   │
│  └──────────────────────────────┘  └──────────────────────────────────┘   │
│                                                                             │
│               ┌─────────────────────────────────────┐                      │
│               │  UNIFIED LLM INTERFACE              │                      │
│               │  Both return Ollama-compatible JSON │                      │
│               │  Caller doesn't know which backend  │                      │
│               └─────────────────────────────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Two-Tier LLM Philosophy

The key insight: **use a powerful model to orchestrate smaller tasks**.

```
Heavy Analysis (Opus 4.5):                 Light Tasks (Ollama):
┌──────────────────────────────┐          ┌──────────────────────────────┐
│ "Analyze these 24 projects   │          │ "Re-sort this list by        │
│  and identify components     │   ────▶  │  priority"                   │
│  that could be shared"       │          │                              │
│                              │          │ "Is 'threadpool' similar to  │
│ Returns structured analysis  │          │  'worker-pool'? (yes/no)"    │
│ with reasoning               │          │                              │
└──────────────────────────────┘          └──────────────────────────────┘
       One expensive call                    Many cheap calls
       Complex reasoning                     Simple transformations
```

### Unified Output Format (Ollama-Compatible)

```json
{
  "model": "opus-4.5",
  "created_at": "2026-02-23T12:00:00Z",
  "response": "Analysis complete. Found 7 shared components...",
  "done": true,
  "context": [...],
  "total_duration": 15000000000,
  "load_duration": 1000000000,
  "prompt_eval_count": 512,
  "eval_count": 1024
}
```

By wrapping Anthropic API responses in Ollama's format, the same downstream processing works regardless of which model performed the analysis.

---

## Suggested Implementation Steps

### Core Script Structure

```bash
#!/bin/bash
# -- {{{ todone.sh
# TODONE: Cross-Project Roadmap Coordinator
# Analyzes projects, detects shared components, generates collective TODO
# Uses tiered LLM: Opus for analysis, Ollama for reorganization

# Configuration
DIR="${1:-/home/ritz/programming/ai-stuff}"
OUTPUT_FILE="${OUTPUT_FILE:-$DIR/TODO.md}"
LLM_HEAVY="${LLM_HEAVY:-opus-4.5}"
LLM_LIGHT="${LLM_LIGHT:-llama3}"
SIMILARITY_THRESHOLD="${SIMILARITY_THRESHOLD:-0.7}"

# Pipeline stages
STAGES=(
    "scan"        # 053a: Extract roadmaps and issues from all projects
    "analyze"     # 053b: Detect component similarity
    "generate"    # 053c: Generate collective roadmap
    "output"      # 053f: Write TODO.md
)
# }}}
```

### CLI Interface

```bash
# Full pipeline (initial generation)
todone.sh /home/ritz/programming/ai-stuff

# Update existing TODO (uses Ollama for reorganization)
todone.sh --update

# Individual stages
todone.sh --stage=scan      # Just scan projects
todone.sh --stage=analyze   # Just detect similarities
todone.sh --stage=generate  # Just generate roadmap
todone.sh --stage=output    # Just write TODO.md

# Options
    --dry-run                Preview without writing files
    --heavy-only             Use Opus for all tasks (expensive but thorough)
    --light-only             Use Ollama only (cheap but less accurate)
    --projects=A,B,C         Analyze specific projects only
    --output=PATH            Override output file location
    --similarity=THRESHOLD   Component similarity threshold (0.0-1.0)
    --show-overlaps          Display component overlap matrix
    --show-libraries         List library extraction candidates
    --interactive            Approve shared components before grouping
```

### Output Format: TODO.md

```markdown
# Collective TODO Roadmap
Generated: 2026-02-23 by TODONE

## Shared Infrastructure (Build First)

### SHARED-001: Threadpool Library
**Used by**: world-edit-to-execute, symbeline-realms, llm-http
**Effort reduction**: ~40 hours (3 implementations → 1)
**Status**: Not started
**Suggested location**: /home/ritz/programming/ai-stuff/my-libs/threadpool/

### SHARED-002: TUI Framework Extensions
**Used by**: delta-version, progress-ii, authorship-tool
**Effort reduction**: ~25 hours
**Status**: Partial (delta-version has base implementation)
**Suggested location**: /home/ritz/programming/ai-stuff/my-libs/tui-ext/

### SHARED-003: Ollama Client Library
**Used by**: 8 projects
**Effort reduction**: ~60 hours
**Status**: Not started
**Suggested location**: /home/ritz/programming/ai-stuff/libs/ollama-client/

---

## Per-Project Phases (After Shared Infrastructure)

### world-edit-to-execute
- [ ] Phase 4: DSL interpreter (depends: SHARED-001)
- [ ] Phase 5: Visual editor (depends: SHARED-002)

### symbeline-realms
- [ ] Phase 3: World generation (depends: SHARED-001)
- [ ] Phase 4: Entity system

### llm-http
- [ ] Phase 2: Streaming support (depends: SHARED-003)
- [ ] Phase 3: Rate limiting

---

## Statistics
- Total projects analyzed: 24
- Shared components identified: 7
- Estimated effort reduction: 180 hours
- Library extraction candidates: 3

---

## Methodology
- Initial analysis: Anthropic Opus 4.5 (semantic understanding)
- Reorganization updates: Ollama llama3 (fast, local)
- Similarity threshold: 0.7
- Last full analysis: 2026-02-23
```

---

## Sub-Issues

| ID | Title | Status | Description |
|----|-------|--------|-------------|
| **053a** | Project Scanning and Analysis | 📝 Open | Extract roadmaps, issues, and planned components from all projects |
| **053b** | Component Similarity Detection | 📝 Open | Semantic analysis to find overlapping components across projects |
| **053c** | Shared Library Roadmap Generation | 📝 Open | Group similar components, calculate build order, generate collective phases |
| **053d** | Ollama Integration for Updates | 📝 Open | Light LLM tasks: reorganization, quick similarity checks, incremental updates |
| **053e** | Anthropic API with Ollama-style Output | 📝 Open | Heavy analysis returning Ollama-compatible JSON for unified processing |
| **053f** | TODO Document Output Format | 📝 Open | Generate readable TODO.md with shared infrastructure first |

### Implementation Order

```
053a (project scanning)
  │
  └──▶ 053b (similarity detection)
              │
              ├──▶ 053d (Ollama integration - light tasks)
              │
              └──▶ 053e (Anthropic API - heavy analysis)
                          │
                          └──▶ 053c (roadmap generation)
                                      │
                                      └──▶ 053f (TODO output)
```

### Parallel Development Opportunities

- **053d** (Ollama) and **053e** (Anthropic) can be developed in parallel
- Both must implement the same output interface
- **053a** and **053b** can be developed with mock LLM responses

---

## Acceptance Criteria

### Pipeline Completeness
- [ ] Full pipeline runs with `todone.sh /path/to/ai-stuff`
- [ ] Update mode uses Ollama for efficient reorganization
- [ ] Dry-run mode previews all changes
- [ ] Interactive mode allows approval of shared component groupings

### Component Detection Quality
- [ ] Identifies semantically similar components (not just keyword matches)
- [ ] Handles different naming conventions (threadpool, worker-pool, task-queue)
- [ ] Detects partial implementations that could be merged
- [ ] Ranks components by shared usage count

### Roadmap Quality
- [ ] Shared infrastructure scheduled before dependent phases
- [ ] Library extraction candidates clearly identified
- [ ] Effort reduction estimates provided
- [ ] Per-project phases show dependencies on shared components

### LLM Integration
- [ ] Opus used for initial deep analysis and complex reasoning
- [ ] Ollama used for updates, reorganization, and simple queries
- [ ] Both return Ollama-compatible JSON
- [ ] Graceful fallback if one LLM unavailable

### TODO.md Output
- [ ] Human-readable markdown format
- [ ] Shared components listed first with usage counts
- [ ] Per-project phases with dependency markers
- [ ] Statistics section with effort reduction estimates
- [ ] Methodology section documenting analysis parameters

---

## Technical Considerations

### Project Scanning Patterns

```lua
-- -- {{{ Project data extraction
local function scan_project(project_path)
    local data = {
        name = get_project_name(project_path),
        roadmap = {},
        issues = {},
        components = {}
    }

    -- Parse roadmap.md for phases
    local roadmap_path = project_path .. "/docs/roadmap.md"
    if file_exists(roadmap_path) then
        data.roadmap = parse_roadmap(roadmap_path)
    end

    -- Parse issue files for planned work
    local issues = glob(project_path .. "/issues/*.md")
    for _, issue_path in ipairs(issues) do
        local issue = parse_issue(issue_path)
        table.insert(data.issues, issue)

        -- Extract mentioned components
        for component in extract_components(issue.content) do
            data.components[component] = (data.components[component] or 0) + 1
        end
    end

    return data
end
-- }}}
```

### Similarity Detection Approaches

1. **Keyword Matching** (fast, low accuracy):
   ```
   "threadpool" matches "thread-pool", "worker_pool", "ThreadPool"
   ```

2. **Semantic Clustering** (medium, requires embeddings):
   ```
   Embed component descriptions → K-means clustering → Group similar
   ```

3. **LLM-based Analysis** (slow, high accuracy):
   ```
   "Are these two components functionally similar?
    A: 'Build worker thread management system'
    B: 'Implement task queue with concurrent workers'"
   ```

### Ollama-Compatible Response Format

```lua
-- -- {{{ wrap_anthropic_response
local function wrap_anthropic_response(anthropic_response, model_name)
    return {
        model = model_name or "opus-4.5",
        created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        response = anthropic_response.content[1].text,
        done = true,
        context = {},  -- Anthropic doesn't use context tokens
        total_duration = (anthropic_response.usage.total_tokens or 0) * 50000,
        load_duration = 0,
        prompt_eval_count = anthropic_response.usage.input_tokens or 0,
        eval_count = anthropic_response.usage.output_tokens or 0
    }
end
-- }}}
```

---

## Symmetry with Issue 051

This tool complements Issue 051 (Git Documentation Generator):

| Issue 051 | Issue 053 (TODONE) |
|-----------|-------------------|
| Input: Git commits | Input: Project roadmaps/issues |
| Output: Project documentation | Output: Cross-project TODO |
| Scope: Single project | Scope: All projects |
| "History → Documentation" | "Documentation → Unified Roadmap" |

Together with existing tools:

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│   Git Commits      │     │  Project Docs      │     │  Collective TODO   │
│   (per project)    │────▶│  (per project)     │────▶│  (all projects)    │
│                    │ 051 │                    │ 053 │                    │
└────────────────────┘     └────────────────────┘     └────────────────────┘
```

---

## Related Documents

- Issue 051: Git Repository Documentation Generator (project-level docs)
- Issue 023: Create Project Listing Utility (project discovery)
- Issue 052: Update Ollama Connection Configuration (Ollama setup)
- Issue 035f: Local LLM Integration (shared LLM patterns)
- `/home/ritz/programming/ai-stuff/my-libs/` (target for extracted libraries)

---

## Metadata

- **Priority**: High
- **Complexity**: High
- **Dependencies**: Issue 023 (Project Listing Utility)
- **Blocks**: Efficient cross-project development
- **Impact**: Reduces duplicated effort, surfaces synergy opportunities

---

## Risk Assessment

- **Over-grouping**: LLM might group dissimilar components
  - Mitigation: User approval, similarity threshold, manual override
- **False positives**: Different components with similar names
  - Mitigation: Context-aware analysis, check actual implementations
- **Scope creep**: Trying to unify everything
  - Mitigation: Focus on high-value overlaps (3+ projects)
- **API costs**: Opus calls are expensive
  - Mitigation: Use Opus only for initial analysis, Ollama for updates
- **Stale TODO**: Roadmap diverges from actual project state
  - Mitigation: Incremental update mode, validation against current issues

---

## Future Extensions

1. **Automatic library extraction**: Generate library scaffolding from shared components
2. **Dependency graph visualization**: Show cross-project dependencies graphically
3. **Progress tracking**: Update TODO.md as work completes
4. **CI integration**: Regenerate TODO on project changes
5. **Team coordination**: Assign shared components to specific developers
6. **Cost estimation**: Calculate API costs before running heavy analysis

---

## Notes

TODONE embodies the principle of **"build once, use everywhere"**. By analyzing the entire project ecosystem holistically, it surfaces opportunities that would be invisible when looking at projects individually.

The two-tier LLM architecture exemplifies efficient resource usage: pay for expensive reasoning once to establish structure, then use cheap local models for maintenance. This mirrors how a senior architect might sketch the big picture while junior developers handle routine updates.

The Ollama-compatible output format is key to maintainability. By standardizing on a single response format, downstream processing doesn't need to know whether analysis came from a local model or a cloud API - enabling seamless scaling between accuracy and cost.
