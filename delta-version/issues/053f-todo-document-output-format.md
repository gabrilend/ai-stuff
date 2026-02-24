# Issue 053f: TODO Document Output Format

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: Issue 053c (Shared Library Roadmap Generation)

---

## Current Behavior

There is no standard output format for TODONE's cross-project roadmap. Without this:

- No single document showing collective work items
- Scattered project roadmaps remain disconnected
- Shared components aren't visible in one place
- Progress tracking is fragmented

---

## Intended Behavior

Create a TODO.md generator that:

1. **Outputs to `/home/ritz/programming/ai-stuff/TODO.md`**
2. **Lists shared infrastructure first** (build once, use everywhere)
3. **Shows per-project phases** with dependencies on shared components
4. **Includes effort reduction statistics**
5. **Provides methodology documentation** for reproducibility

### Document Structure

```markdown
# Collective TODO Roadmap
Generated: 2026-02-23 12:00:00 by TODONE v1.0

## Executive Summary
- 24 projects analyzed
- 7 shared components identified
- 180 hours estimated reduction (35%)

## Shared Infrastructure (Build First)

### SHARED-001: [Component Name]
...

## Per-Project Phases

### [Project Name]
...

## Statistics

## Methodology

## Changelog
```

---

## Suggested Implementation Steps

### 1. Document Generator

```lua
-- -- {{{ generate_todo_document.lua
local function generate_todo_document(roadmap_data, config)
    local sections = {}

    -- Header
    table.insert(sections, generate_header(config))

    -- Executive Summary
    table.insert(sections, generate_summary(roadmap_data))

    -- Shared Infrastructure
    table.insert(sections, generate_shared_section(roadmap_data.collective_phases))

    -- Per-Project Phases
    table.insert(sections, generate_project_sections(roadmap_data))

    -- Statistics
    table.insert(sections, generate_statistics(roadmap_data))

    -- Methodology
    table.insert(sections, generate_methodology(config))

    -- Changelog
    table.insert(sections, generate_changelog(roadmap_data))

    return table.concat(sections, "\n\n---\n\n")
end
-- }}}
```

### 2. Header Section

```lua
-- -- {{{ generate_header
local function generate_header(config)
    return string.format([[
# Collective TODO Roadmap

> *Generated: %s by TODONE v%s*
> *Source: %s*

This document coordinates development across all projects in the ai-stuff directory.
Shared components are listed first to maximize code reuse and minimize duplicated effort.

**Legend:**
- [ ] Pending
- [~] In Progress
- [x] Complete
- ★ Shared component (library candidate)
- → Depends on
]], os.date("%Y-%m-%d %H:%M:%S"), config.version or "1.0", config.source_dir)
end
-- }}}
```

### 3. Executive Summary

```lua
-- -- {{{ generate_summary
local function generate_summary(roadmap_data)
    local stats = roadmap_data.total_effort_reduction or {}
    local shared_count = 0
    for _, phase in ipairs(roadmap_data.collective_phases or {}) do
        if phase.type == "shared" then
            shared_count = shared_count + #(phase.components or {})
        end
    end

    return string.format([[
## Executive Summary

| Metric | Value |
|--------|-------|
| Projects Analyzed | %d |
| Shared Components | %d |
| Library Candidates | %d |
| Estimated Reduction | %d hours (%d%%) |
| Analysis Date | %s |

### Key Findings

%s
]], roadmap_data.project_count or 0,
    shared_count,
    roadmap_data.library_candidates or 0,
    stats.hours or 0,
    stats.percentage or 0,
    os.date("%Y-%m-%d"),
    generate_key_findings(roadmap_data))
end

local function generate_key_findings(roadmap_data)
    local findings = {}

    -- Find highest-value shared components
    local top_shared = get_top_shared_components(roadmap_data, 3)
    for i, comp in ipairs(top_shared) do
        table.insert(findings, string.format(
            "%d. **%s**: Used by %d projects (saves ~%d hours)",
            i, comp.name, comp.usage_count, comp.reduction_hours
        ))
    end

    if #findings == 0 then
        table.insert(findings, "- No significant shared components identified")
    end

    return table.concat(findings, "\n")
end
-- }}}
```

### 4. Shared Infrastructure Section

```lua
-- -- {{{ generate_shared_section
local function generate_shared_section(collective_phases)
    local lines = {"## ★ Shared Infrastructure (Build First)"}
    local shared_count = 0

    for _, phase in ipairs(collective_phases or {}) do
        if phase.type == "shared" then
            shared_count = shared_count + 1
            table.insert(lines, "")
            table.insert(lines, string.format("### SHARED-%03d: %s", shared_count, phase.name))
            table.insert(lines, "")

            for _, comp in ipairs(phase.components or {}) do
                table.insert(lines, string.format("#### %s", comp.name))
                table.insert(lines, "")
                table.insert(lines, string.format("**Used by**: %s", table.concat(comp.used_by or {}, ", ")))
                table.insert(lines, string.format("**Suggested location**: `%s`", comp.suggested_location or "TBD"))
                table.insert(lines, string.format("**Effort reduction**: ~%d hours", comp.reduction or 0))
                table.insert(lines, "")
                table.insert(lines, "**Status**: [ ] Not started")
                table.insert(lines, "")
                table.insert(lines, "**Tasks**:")
                table.insert(lines, "- [ ] Design API interface")
                table.insert(lines, "- [ ] Implement core functionality")
                table.insert(lines, "- [ ] Write tests")
                table.insert(lines, "- [ ] Document usage")
                table.insert(lines, "- [ ] Integrate with dependent projects")
                table.insert(lines, "")
            end
        end
    end

    if shared_count == 0 then
        table.insert(lines, "")
        table.insert(lines, "*No shared components identified. Projects can proceed independently.*")
    end

    return table.concat(lines, "\n")
end
-- }}}
```

### 5. Per-Project Sections

```lua
-- -- {{{ generate_project_sections
local function generate_project_sections(roadmap_data)
    local lines = {"## Per-Project Phases"}

    -- Group phases by project
    local by_project = {}
    for _, phase in ipairs(roadmap_data.collective_phases or {}) do
        if phase.type == "project" then
            local project = phase.project
            by_project[project] = by_project[project] or {}
            table.insert(by_project[project], phase)
        end
    end

    -- Sort projects alphabetically
    local projects = {}
    for project, _ in pairs(by_project) do
        table.insert(projects, project)
    end
    table.sort(projects)

    for _, project in ipairs(projects) do
        local phases = by_project[project]
        table.insert(lines, "")
        table.insert(lines, string.format("### %s", project))
        table.insert(lines, "")

        -- Check for adjustments
        local adj = roadmap_data.per_project_adjustments and
                    roadmap_data.per_project_adjustments[project]
        if adj then
            table.insert(lines, string.format(
                "*Adjusted from %d to %d phases (uses shared components)*",
                adj.original_phases or 0, adj.adjusted_phases or 0
            ))
            table.insert(lines, "")
        end

        for _, phase in ipairs(phases) do
            local deps = ""
            if phase.depends_on and #phase.depends_on > 0 then
                deps = string.format(" → *depends on: %s*", table.concat(phase.depends_on, ", "))
            end
            table.insert(lines, string.format("- [ ] Phase %d: %s%s",
                phase.project_phase or 0, phase.name or "Unnamed", deps))
        end
        table.insert(lines, "")
    end

    return table.concat(lines, "\n")
end
-- }}}
```

### 6. Statistics Section

```lua
-- -- {{{ generate_statistics
local function generate_statistics(roadmap_data)
    local stats = roadmap_data.analysis_stats or {}
    local effort = roadmap_data.total_effort_reduction or {}

    return string.format([[
## Statistics

### Component Analysis
| Metric | Count |
|--------|-------|
| Total components found | %d |
| Unique components | %d |
| Clustered (similar) | %d |
| Unclustered (unique) | %d |

### Similarity Detection
| Tier | Matches |
|------|---------|
| Tier 1: Exact match | %d |
| Tier 2: Synonym lookup | %d |
| Tier 3: Fuzzy match | %d |
| Tier 4: Ollama check | %d |
| Tier 5: Opus analysis | %d |

### Effort Analysis
| Metric | Value |
|--------|-------|
| Traditional effort | %d hours |
| With shared libraries | %d hours |
| Reduction | %d hours (%d%%) |
]],
    stats.total_components or 0,
    stats.unique_components or 0,
    stats.clustered or 0,
    stats.unclustered or 0,
    stats.tier1 or 0,
    stats.tier2 or 0,
    stats.tier3 or 0,
    stats.tier4 or 0,
    stats.tier5 or 0,
    effort.traditional_hours or 0,
    effort.shared_hours or 0,
    effort.hours or 0,
    effort.percentage or 0)
end
-- }}}
```

### 7. Methodology Section

```lua
-- -- {{{ generate_methodology
local function generate_methodology(config)
    return string.format([[
## Methodology

This TODO document was generated by TODONE using the following approach:

### Data Collection
- **Project discovery**: `list-projects.sh` from delta-version
- **Roadmap parsing**: Extracted phases from `docs/roadmap.md` files
- **Issue extraction**: Parsed all `issues/*.md` files
- **Component detection**: Keyword and pattern extraction from text

### Similarity Analysis
- **Tier 1**: Exact/normalized string matching
- **Tier 2**: Synonym dictionary lookup
- **Tier 3**: Levenshtein distance (threshold: 2)
- **Tier 4**: Ollama quick check (%s)
- **Tier 5**: Anthropic Opus deep analysis

### Roadmap Generation
- **Dependency graph**: Built from component usage across projects
- **Topological sort**: Ensures shared components scheduled first
- **Effort estimation**: Based on component complexity heuristics

### Configuration
```
Light LLM: %s
Heavy LLM: %s
Similarity threshold: %.2f
Minimum shared usage: %d projects
```

### Reproducibility
To regenerate this document:
```bash
todone.sh %s
```
]], config.light_model or "llama3",
    config.light_model or "llama3",
    config.heavy_model or "claude-opus-4-5-20251101",
    config.similarity_threshold or 0.7,
    config.min_shared_usage or 3,
    config.source_dir or "/home/ritz/programming/ai-stuff")
end
-- }}}
```

### 8. Changelog Section

```lua
-- -- {{{ generate_changelog
local function generate_changelog(roadmap_data)
    local changelog = roadmap_data.changelog or {}

    local lines = {"## Changelog"}
    table.insert(lines, "")

    if #changelog == 0 then
        table.insert(lines, string.format("### %s - Initial Generation", os.date("%Y-%m-%d")))
        table.insert(lines, "- First TODONE analysis")
        table.insert(lines, string.format("- %d projects scanned", roadmap_data.project_count or 0))
    else
        for _, entry in ipairs(changelog) do
            table.insert(lines, string.format("### %s - %s", entry.date, entry.title))
            for _, change in ipairs(entry.changes or {}) do
                table.insert(lines, string.format("- %s", change))
            end
            table.insert(lines, "")
        end
    end

    return table.concat(lines, "\n")
end
-- }}}
```

### 9. File Writer

```lua
-- -- {{{ write_todo_file
local function write_todo_file(content, output_path)
    output_path = output_path or "/home/ritz/programming/ai-stuff/TODO.md"

    -- Backup existing file if present
    local existing = io.open(output_path, "r")
    if existing then
        existing:close()
        local backup_path = output_path .. ".backup." .. os.date("%Y%m%d_%H%M%S")
        os.rename(output_path, backup_path)
        print("Backed up existing TODO to: " .. backup_path)
    end

    local file = io.open(output_path, "w")
    if not file then
        return false, "Could not write to " .. output_path
    end

    file:write(content)
    file:close()

    print("Wrote TODO document to: " .. output_path)
    return true
end
-- }}}
```

---

## Output Example

```markdown
# Collective TODO Roadmap

> *Generated: 2026-02-23 12:00:00 by TODONE v1.0*
> *Source: /home/ritz/programming/ai-stuff*

## Executive Summary

| Metric | Value |
|--------|-------|
| Projects Analyzed | 24 |
| Shared Components | 7 |
| Library Candidates | 3 |
| Estimated Reduction | 180 hours (35%) |

### Key Findings

1. **threadpool**: Used by 5 projects (saves ~60 hours)
2. **tui-framework**: Used by 4 projects (saves ~45 hours)
3. **ollama-client**: Used by 8 projects (saves ~75 hours)

---

## ★ Shared Infrastructure (Build First)

### SHARED-001: Core Threading Infrastructure

#### threadpool

**Used by**: symbeline-realms, llm-http, world-edit-to-execute, handheld-office, progress-ii
**Suggested location**: `/home/ritz/programming/ai-stuff/my-libs/threadpool/`
**Effort reduction**: ~60 hours

**Status**: [ ] Not started

**Tasks**:
- [ ] Design API interface
- [ ] Implement core functionality
- [ ] Write tests
- [ ] Document usage
- [ ] Integrate with dependent projects

---

## Per-Project Phases

### symbeline-realms

*Adjusted from 5 to 3 phases (uses shared components)*

- [ ] Phase 3: World generation → *depends on: SHARED:threadpool*
- [ ] Phase 4: Entity system
- [ ] Phase 5: Quest engine

### world-edit-to-execute

- [ ] Phase 4: DSL interpreter → *depends on: SHARED:threadpool*
- [ ] Phase 5: Visual editor → *depends on: SHARED:tui-framework*

---

## Statistics
...

## Methodology
...

## Changelog

### 2026-02-23 - Initial Generation
- First TODONE analysis
- 24 projects scanned
```

---

## CLI Interface

```bash
# Generate TODO document
todone-output.sh

# Output options
todone-output.sh --output=/custom/path/TODO.md
todone-output.sh --no-backup    # Don't backup existing
todone-output.sh --dry-run      # Preview without writing

# Format options
todone-output.sh --format=md    # Markdown (default)
todone-output.sh --format=html  # HTML (future)
todone-output.sh --format=json  # Machine-readable

# Section control
todone-output.sh --no-methodology
todone-output.sh --no-changelog
todone-output.sh --summary-only
```

---

## Acceptance Criteria

- [ ] Generates valid markdown document
- [ ] Shared components listed before project phases
- [ ] Dependencies shown with → notation
- [ ] Statistics accurately reflect analysis
- [ ] Methodology is reproducible
- [ ] Backup created before overwriting
- [ ] Dry-run mode works correctly

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 053c: Roadmap Generation (input)
- `/home/ritz/programming/ai-stuff/TODO.md` (output location)

---

## Notes

The TODO document is the primary user-facing output of TODONE. It should be:

1. **Readable**: A developer should understand priorities at a glance
2. **Actionable**: Each item has clear next steps
3. **Traceable**: Statistics and methodology enable verification
4. **Maintainable**: Incremental updates via `--update` mode

The document doubles as both a planning artifact and a progress tracker. As work completes, checkboxes can be updated (manually or via future automation), providing visibility into collective progress across all projects.
