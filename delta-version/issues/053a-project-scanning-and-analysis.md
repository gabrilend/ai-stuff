# Issue 053a: Project Scanning and Analysis

**Phase**: 0 - Tooling
**Status**: Open
**Priority**: High
**Created**: 2026-02-23
**Parent**: Issue 053 (TODONE - Cross-Project Roadmap Coordinator)
**Dependencies**: Issue 023 (Project Listing Utility)

---

## Current Behavior

There is no automated way to extract and normalize roadmap/issue data from all projects in the ai-stuff directory. Each project may have:

- Different documentation structures
- Varying issue file formats
- Roadmaps in different locations (docs/roadmap.md, notes/vision.md, README.md)
- Different naming conventions for components and phases

Manual extraction would require reading 24+ projects individually.

---

## Intended Behavior

Create a project scanner that:

1. **Uses list-projects.sh** to discover all projects
2. **Extracts structured data** from each project:
   - Roadmap phases and milestones
   - Issue files (open and completed)
   - Mentioned components and technologies
   - Dependencies between phases/issues
3. **Normalizes data** into a common format for downstream analysis
4. **Caches results** for incremental updates

### Data Extraction Targets

```
Per Project:
├── docs/roadmap.md          → Phases, milestones, timeline
├── docs/table-of-contents.md → Document structure
├── notes/vision.md          → Project goals, intended components
├── issues/*.md              → Planned work items
├── issues/completed/*.md    → Completed work (for reference)
├── issues/progress.md       → Current status
├── project.meta.json        → Metadata (if exists)
└── src/                     → Code patterns (file types, imports)
```

### Normalized Output Format

```json
{
  "project": "symbeline-realms",
  "scanned_at": "2026-02-23T12:00:00Z",
  "roadmap": {
    "phases": [
      {
        "number": 1,
        "name": "Foundation",
        "status": "complete",
        "components": ["entity-system", "world-grid"]
      },
      {
        "number": 2,
        "name": "Core Features",
        "status": "in_progress",
        "components": ["threadpool", "async-loading", "state-machine"]
      }
    ]
  },
  "issues": {
    "open": [
      {"id": "201", "title": "Implement threadpool", "components": ["threading", "task-queue"]},
      {"id": "202", "title": "Build TUI interface", "components": ["tui", "input-handling"]}
    ],
    "completed": [...]
  },
  "components": {
    "threadpool": {"mentions": 3, "contexts": ["issues/201.md", "docs/roadmap.md"]},
    "tui": {"mentions": 5, "contexts": ["issues/202.md", "issues/205.md", "..."]}
  },
  "technologies": ["lua", "luajit", "sqlite"],
  "dependencies": {
    "external": ["my-libs/tui", "libs/sqlite"],
    "internal": {"202": ["201"]}
  }
}
```

---

## Suggested Implementation Steps

### 1. Project Discovery

```bash
# -- {{{ discover_projects
discover_projects() {
    local base_dir="${1:-/home/ritz/programming/ai-stuff}"

    # Use existing list-projects.sh
    "$base_dir/delta-version/scripts/list-projects.sh" -p
}
# }}}
```

### 2. Roadmap Parser

```lua
-- -- {{{ parse_roadmap
local function parse_roadmap(roadmap_path)
    local content = read_file(roadmap_path)
    if not content then return nil end

    local phases = {}
    local current_phase = nil

    for line in content:gmatch("[^\n]+") do
        -- Detect phase headers: "## Phase 1: Foundation" or "### Phase 2 - Core"
        local phase_num, phase_name = line:match("^#+%s*Phase%s*(%d+)[:%s%-]+(.+)")
        if phase_num then
            current_phase = {
                number = tonumber(phase_num),
                name = phase_name:gsub("^%s+", ""):gsub("%s+$", ""),
                status = "pending",
                components = {}
            }
            table.insert(phases, current_phase)
        end

        -- Detect status markers
        if current_phase then
            if line:match("[✅✓]") or line:match("complete") then
                current_phase.status = "complete"
            elseif line:match("[▶⏳]") or line:match("in.progress") then
                current_phase.status = "in_progress"
            end

            -- Extract component mentions (quoted, backticked, or capitalized)
            for component in line:gmatch("`([^`]+)`") do
                table.insert(current_phase.components, normalize_component(component))
            end
        end
    end

    return phases
end
-- }}}
```

### 3. Issue File Parser

```lua
-- -- {{{ parse_issue_file
local function parse_issue_file(issue_path)
    local content = read_file(issue_path)
    if not content then return nil end

    local issue = {
        id = issue_path:match("(%d+[a-z]?)-[^/]+%.md$") or "unknown",
        path = issue_path,
        title = "",
        status = "open",
        components = {},
        dependencies = {},
        blocks = {}
    }

    -- Extract title from first heading
    issue.title = content:match("^#%s*[^:]+:%s*(.+)") or
                  content:match("^#%s*(.+)") or
                  issue_path:match("/([^/]+)%.md$")

    -- Extract status
    if content:match("Status:%s*Completed") or content:match("Status:%s*Done") then
        issue.status = "completed"
    elseif content:match("Status:%s*In.Progress") then
        issue.status = "in_progress"
    end

    -- Extract dependencies
    for dep in content:gmatch("Dependencies?:%s*Issue%s*(%d+)") do
        table.insert(issue.dependencies, dep)
    end
    for dep in content:gmatch("Depends%s*on:%s*Issue%s*(%d+)") do
        table.insert(issue.dependencies, dep)
    end

    -- Extract blocks
    for blocks in content:gmatch("Blocks:%s*Issue%s*(%d+)") do
        table.insert(issue.blocks, blocks)
    end

    -- Extract component mentions
    issue.components = extract_components(content)

    return issue
end
-- }}}
```

### 4. Component Extraction

```lua
-- -- {{{ extract_components
-- Extract mentioned components from text
-- Components are typically: backticked terms, capitalized tech names,
-- or common patterns like "build X", "implement Y", "create Z"
local function extract_components(text)
    local components = {}
    local seen = {}

    -- Backticked terms
    for term in text:gmatch("`([^`]+)`") do
        local normalized = normalize_component(term)
        if not seen[normalized] and is_likely_component(normalized) then
            table.insert(components, normalized)
            seen[normalized] = true
        end
    end

    -- Action patterns: "build/implement/create X"
    for action, component in text:gmatch("([Bb]uild|[Ii]mplement|[Cc]reate|[Aa]dd)%s+([%w%-_]+)") do
        local normalized = normalize_component(component)
        if not seen[normalized] and is_likely_component(normalized) then
            table.insert(components, normalized)
            seen[normalized] = true
        end
    end

    -- Known component patterns
    local patterns = {
        "threadpool", "thread%-pool", "worker%-pool",
        "tui", "terminal%-ui", "ncurses",
        "parser", "lexer", "tokenizer",
        "database", "sqlite", "storage",
        "http", "api", "server", "client",
        "llm", "ollama", "anthropic"
    }

    local lower_text = text:lower()
    for _, pattern in ipairs(patterns) do
        if lower_text:match(pattern) and not seen[pattern] then
            table.insert(components, pattern)
            seen[pattern] = true
        end
    end

    return components
end

local function normalize_component(name)
    -- Lowercase, replace underscores with hyphens, trim
    return name:lower():gsub("_", "-"):gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_likely_component(name)
    -- Filter out common non-component words
    local exclude = {
        "the", "a", "an", "is", "are", "was", "were",
        "this", "that", "these", "those",
        "file", "files", "directory", "path",
        "true", "false", "nil", "null"
    }
    for _, word in ipairs(exclude) do
        if name == word then return false end
    end
    return #name >= 3 and #name <= 50
end
-- }}}
```

### 5. Caching for Incremental Updates

```lua
-- -- {{{ cache_management
local CACHE_DIR = "/tmp/todone-cache"

local function get_cache_path(project_name)
    return CACHE_DIR .. "/" .. project_name .. ".json"
end

local function is_cache_valid(project_name, project_path)
    local cache_path = get_cache_path(project_name)
    if not file_exists(cache_path) then return false end

    local cache_mtime = get_mtime(cache_path)
    local project_mtime = get_newest_mtime(project_path .. "/issues")

    return cache_mtime > project_mtime
end

local function load_from_cache(project_name)
    local cache_path = get_cache_path(project_name)
    return json.decode(read_file(cache_path))
end

local function save_to_cache(project_name, data)
    os.execute("mkdir -p " .. CACHE_DIR)
    write_file(get_cache_path(project_name), json.encode(data))
end
-- }}}
```

---

## CLI Interface

```bash
# Scan all projects
todone-scan.sh

# Scan specific projects
todone-scan.sh --projects=symbeline-realms,world-edit-to-execute

# Force rescan (ignore cache)
todone-scan.sh --force

# Output formats
todone-scan.sh --format=json    # Machine-readable
todone-scan.sh --format=summary # Human-readable summary

# Show specific data
todone-scan.sh --show-components  # List all components across projects
todone-scan.sh --show-phases      # List all phases across projects
```

---

## Acceptance Criteria

- [ ] Successfully scans all projects from list-projects.sh
- [ ] Extracts roadmap phases where available
- [ ] Parses all issue files (open and completed)
- [ ] Identifies mentioned components with context
- [ ] Handles missing files gracefully
- [ ] Caches results for incremental updates
- [ ] Outputs normalized JSON format

---

## Related Documents

- Issue 053: TODONE main issue
- Issue 023: Project Listing Utility (dependency)
- `/delta-version/scripts/list-projects.sh`

---

## Notes

This scanner forms the foundation for all TODONE analysis. The quality of downstream similarity detection and roadmap generation depends entirely on accurate, comprehensive data extraction here.

The component extraction is intentionally broad - it's better to capture potential components and filter later than to miss important ones. The similarity detection phase (053b) will handle grouping and deduplication.
