# 010: Abstract Project Discovery Library

## Current Behavior

Project discovery logic is embedded in `delta-version/scripts/list-projects.sh`. This includes:
- Exclusion patterns for non-project directories
- Scoring heuristics based on file presence (src/, issues/, Cargo.toml, etc.)
- Project classification by type (Lua, Rust, Node, etc.)

This functionality cannot be reused by other scripts without copy-pasting.

## Intended Behavior

A reusable library `libs/project-discovery.sh` (and Lua equivalent `libs/project-discovery.lua`) that provides:
- `project_discovery_init(base_dir)` - Initialize with base directory
- `project_discovery_scan()` - Scan and return discovered projects
- `project_discovery_score(path)` - Get score for a specific path
- `project_discovery_classify(path)` - Get project type classification
- Configurable exclusion patterns
- Configurable scoring weights

## Suggested Implementation Steps

1. Read `delta-version/scripts/list-projects.sh` thoroughly
2. Extract `define_non_project_directories()` into configurable exclusion list
3. Extract `detect_project_characteristics()` into scoring function
4. Create `libs/project-discovery.sh` with sourcing interface
5. Add Lua port `libs/project-discovery.lua` for LuaJIT scripts
6. Update `delta-version/scripts/list-projects.sh` to use the library
7. Write test script `libs/test-project-discovery.sh`
8. Add TUI integration example using menu.lua

## Source Scripts

- `../delta-version/scripts/list-projects.sh` (primary source)
- `./claude-conversation-exporter.sh` (potential consumer)
- `./project-file-server` (potential consumer)

## API Design

```bash
# Bash usage
source libs/project-discovery.sh
project_discovery_init "/home/ritz/programming/ai-stuff"
project_discovery_scan

for project in "${DISCOVERED_PROJECTS[@]}"; do
    score="${PROJECT_SCORES[$project]}"
    type="${PROJECT_TYPES[$project]}"
    echo "$project: $score ($type)"
done
```

```lua
-- Lua usage
local discovery = require("libs/project-discovery")
discovery.init("/home/ritz/programming/ai-stuff")
local projects = discovery.scan()

for _, p in ipairs(projects) do
    print(p.path, p.score, p.type)
end
```

## Related Documents

- `README.md` - Scripts documentation
- `delta-version/scripts/list-projects.sh` - Source implementation
