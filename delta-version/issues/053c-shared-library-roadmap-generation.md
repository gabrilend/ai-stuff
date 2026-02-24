# Issue 053c: Shared Library Roadmap Generation

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: Issue 053b (Component Similarity Detection)

---

## Current Behavior

After similarity detection (053b), we have clusters of related components across projects. However:

- No automated way to prioritize which shared components to build first
- No scheduling that accounts for cross-project dependencies
- No calculation of effort reduction from shared libraries
- Each project's roadmap remains independent

---

## Intended Behavior

Create a roadmap generator that:

1. **Prioritizes shared components** by usage count and dependency depth
2. **Calculates optimal build order** using topological sort
3. **Estimates effort reduction** from building once vs. N times
4. **Generates collective phases** with shared infrastructure first
5. **Outputs per-project adjusted roadmaps** that depend on shared components

### Prioritization Algorithm

```
Priority Score = (Usage Count × 2) + (Dependency Depth × 1.5) + (Complexity Estimate × 0.5)

Example:
┌────────────────────────────────────────────────────────────────────┐
│ Component: threadpool                                               │
│ Usage Count: 5 projects                           → 10 points      │
│ Dependency Depth: 3 (other components depend)     → 4.5 points     │
│ Complexity: Medium (estimated 20 hours)           → 10 points      │
│ TOTAL PRIORITY: 24.5 points                       → Build First    │
├────────────────────────────────────────────────────────────────────┤
│ Component: json-parser                                              │
│ Usage Count: 8 projects                           → 16 points      │
│ Dependency Depth: 1 (leaf component)              → 1.5 points     │
│ Complexity: Low (estimated 5 hours, or use lib)   → 2.5 points     │
│ TOTAL PRIORITY: 20 points                         → Use existing   │
└────────────────────────────────────────────────────────────────────┘
```

### Dependency Graph

```
                    ┌─────────────────────┐
                    │  SHARED: threadpool │
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
    ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
    │ SHARED: async │  │ SHARED: llm   │  │ world-edit    │
    │ file-loader   │  │ client        │  │ Phase 4       │
    └───────┬───────┘  └───────┬───────┘  └───────────────┘
            │                  │
            │                  │
            ▼                  ▼
    ┌───────────────┐  ┌───────────────┐
    │ symbeline     │  │ llm-http      │
    │ Phase 3       │  │ Phase 2       │
    └───────────────┘  └───────────────┘
```

### Effort Reduction Calculation

```lua
-- If 5 projects each need a threadpool (20 hours each):
-- Traditional: 5 × 20 = 100 hours
-- Shared library: 20 + (5 × 2) = 30 hours  (build once + integration per project)
-- Reduction: 70 hours (70%)
```

---

## Suggested Implementation Steps

### 1. Build Dependency Graph

```lua
-- -- {{{ build_dependency_graph
local function build_dependency_graph(clusters, project_data)
    local graph = {
        nodes = {},     -- All components and project phases
        edges = {},     -- Dependencies between them
        shared = {}     -- Shared component clusters
    }

    -- Add shared components as nodes
    for _, cluster in ipairs(clusters) do
        if cluster.library_candidate then
            local node_id = "SHARED:" .. cluster.canonical_name
            graph.nodes[node_id] = {
                type = "shared",
                name = cluster.canonical_name,
                projects = cluster.members,
                usage_count = cluster.total_projects
            }
            table.insert(graph.shared, node_id)
        end
    end

    -- Add project phases as nodes
    for _, project in ipairs(project_data) do
        for _, phase in ipairs(project.roadmap.phases) do
            local node_id = project.name .. ":Phase" .. phase.number
            graph.nodes[node_id] = {
                type = "project_phase",
                project = project.name,
                phase_number = phase.number,
                phase_name = phase.name,
                components = phase.components
            }

            -- Create edges from shared components to this phase
            for _, comp in ipairs(phase.components) do
                local shared_node = find_shared_node(graph, comp)
                if shared_node then
                    graph.edges[shared_node] = graph.edges[shared_node] or {}
                    table.insert(graph.edges[shared_node], node_id)
                end
            end
        end
    end

    return graph
end
-- }}}
```

### 2. Topological Sort for Build Order

```lua
-- -- {{{ topological_sort
local function topological_sort(graph)
    local in_degree = {}
    local queue = {}
    local result = {}

    -- Calculate in-degrees
    for node_id, _ in pairs(graph.nodes) do
        in_degree[node_id] = 0
    end
    for from, to_list in pairs(graph.edges) do
        for _, to in ipairs(to_list) do
            in_degree[to] = (in_degree[to] or 0) + 1
        end
    end

    -- Start with nodes that have no dependencies
    for node_id, degree in pairs(in_degree) do
        if degree == 0 then
            table.insert(queue, node_id)
        end
    end

    -- Process queue
    while #queue > 0 do
        local current = table.remove(queue, 1)
        table.insert(result, current)

        for _, neighbor in ipairs(graph.edges[current] or {}) do
            in_degree[neighbor] = in_degree[neighbor] - 1
            if in_degree[neighbor] == 0 then
                table.insert(queue, neighbor)
            end
        end
    end

    return result
end
-- }}}
```

### 3. Calculate Effort Reduction

```lua
-- -- {{{ calculate_effort_reduction
local COMPLEXITY_HOURS = {
    low = 5,
    medium = 20,
    high = 50,
    very_high = 100
}

local INTEGRATION_HOURS = 2  -- Hours to integrate a shared library

local function calculate_effort_reduction(cluster)
    local usage_count = cluster.total_projects
    local complexity = estimate_complexity(cluster.canonical_name)
    local base_hours = COMPLEXITY_HOURS[complexity] or 20

    local traditional_effort = usage_count * base_hours
    local shared_effort = base_hours + (usage_count * INTEGRATION_HOURS)
    local reduction = traditional_effort - shared_effort
    local percentage = (reduction / traditional_effort) * 100

    return {
        component = cluster.canonical_name,
        usage_count = usage_count,
        complexity = complexity,
        traditional_hours = traditional_effort,
        shared_hours = shared_effort,
        reduction_hours = reduction,
        reduction_percent = percentage
    }
end

local function estimate_complexity(component_name)
    -- Heuristic based on component type
    local high_complexity = {"threadpool", "database", "parser", "compiler", "vm"}
    local medium_complexity = {"tui", "http", "client", "server", "state-machine"}
    local low_complexity = {"logger", "config", "json", "file-watcher"}

    for _, pattern in ipairs(high_complexity) do
        if component_name:match(pattern) then return "high" end
    end
    for _, pattern in ipairs(medium_complexity) do
        if component_name:match(pattern) then return "medium" end
    end
    return "low"
end
-- }}}
```

### 4. Generate Collective Phases

```lua
-- -- {{{ generate_collective_phases
local function generate_collective_phases(build_order, graph, effort_data)
    local phases = {}
    local current_phase = nil
    local phase_number = 0

    for _, node_id in ipairs(build_order) do
        local node = graph.nodes[node_id]

        if node.type == "shared" then
            -- Start new shared phase if needed
            if not current_phase or current_phase.type ~= "shared" then
                phase_number = phase_number + 1
                current_phase = {
                    number = phase_number,
                    type = "shared",
                    name = "Shared Infrastructure " .. phase_number,
                    components = {},
                    effort_reduction = 0
                }
                table.insert(phases, current_phase)
            end

            local effort = effort_data[node.name]
            table.insert(current_phase.components, {
                name = node.name,
                used_by = node.projects,
                reduction = effort and effort.reduction_hours or 0
            })
            current_phase.effort_reduction = current_phase.effort_reduction +
                                             (effort and effort.reduction_hours or 0)

        elseif node.type == "project_phase" then
            -- Add project phase
            phase_number = phase_number + 1
            table.insert(phases, {
                number = phase_number,
                type = "project",
                name = node.project .. " - " .. node.phase_name,
                project = node.project,
                project_phase = node.phase_number,
                depends_on = get_dependencies(graph, node_id)
            })
        end
    end

    return phases
end
-- }}}
```

### 5. LLM-Assisted Refinement

```lua
-- -- {{{ llm_refine_roadmap
local function llm_refine_roadmap(draft_phases, clusters)
    -- Use Opus for intelligent refinement of the generated roadmap
    local prompt = [[
Review this auto-generated cross-project roadmap and suggest improvements:

Draft Roadmap:
]] .. json.encode(draft_phases) .. [[

Component Clusters:
]] .. json.encode(clusters) .. [[

Consider:
1. Are the shared phases in optimal order?
2. Should any components be split or merged?
3. Are there implicit dependencies not captured?
4. Would any project benefit from a different ordering?

Output refined roadmap as JSON with explanations for changes.
]]

    local response = anthropic_query(prompt, {
        model = "claude-opus-4-5-20251101",
        max_tokens = 4000,
        temperature = 0.3
    })

    return wrap_anthropic_response(response)
end
-- }}}
```

---

## Output Format

```json
{
  "collective_phases": [
    {
      "number": 1,
      "type": "shared",
      "name": "Core Threading Infrastructure",
      "components": [
        {
          "name": "threadpool",
          "used_by": ["symbeline-realms", "llm-http", "world-edit-to-execute"],
          "suggested_location": "/home/ritz/programming/ai-stuff/my-libs/threadpool/",
          "reduction_hours": 60
        }
      ],
      "total_reduction_hours": 60
    },
    {
      "number": 2,
      "type": "shared",
      "name": "User Interface Framework",
      "components": [
        {
          "name": "tui-framework",
          "used_by": ["delta-version", "progress-ii", "authorship-tool"],
          "suggested_location": "/home/ritz/programming/ai-stuff/my-libs/tui-ext/",
          "reduction_hours": 45
        }
      ],
      "total_reduction_hours": 45
    },
    {
      "number": 3,
      "type": "project",
      "name": "symbeline-realms - World Generation",
      "project": "symbeline-realms",
      "project_phase": 3,
      "depends_on": ["SHARED:threadpool"]
    }
  ],
  "per_project_adjustments": {
    "symbeline-realms": {
      "original_phases": 5,
      "adjusted_phases": 3,
      "removed_work": ["threadpool implementation"],
      "added_dependencies": ["SHARED:threadpool"]
    }
  },
  "total_effort_reduction": {
    "hours": 180,
    "percentage": 35
  }
}
```

---

## CLI Interface

```bash
# Generate roadmap
todone-roadmap.sh

# Options
todone-roadmap.sh --min-usage=3       # Only share if 3+ projects use it
todone-roadmap.sh --no-llm-refine     # Skip LLM refinement (faster)
todone-roadmap.sh --show-graph        # Display dependency graph
todone-roadmap.sh --show-reductions   # Show effort reduction details
```

---

## Acceptance Criteria

- [ ] Builds accurate dependency graph from clusters
- [ ] Topological sort produces valid build order
- [ ] Effort reduction calculations are reasonable
- [ ] Shared phases grouped logically
- [ ] Per-project phases show correct dependencies
- [ ] LLM refinement improves roadmap quality
- [ ] Handles cycles gracefully (reports them)

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 053b: Component Similarity Detection (dependency)
- Issue 053f: TODO Document Output (uses this output)

---

## Notes

The topological sort ensures that shared components are built before the project phases that depend on them. This is the mathematical foundation for "build once, use everywhere."

The effort reduction calculations are estimates. Real-world savings will vary based on implementation complexity and integration overhead. However, even conservative estimates typically show 30-50% reduction when 3+ projects share a component.

LLM refinement is optional but recommended for the initial analysis. It can catch subtle dependencies and suggest optimizations that pure algorithmic approaches miss.
