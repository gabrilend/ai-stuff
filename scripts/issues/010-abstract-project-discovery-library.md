# 010: Abstract Project Discovery Library

## Current Behavior

**Built 2026-11-02** (see *What Happened*): `libs/project-discovery.lua` and
`libs/project-discovery.sh` exist. What follows is how things stood before.

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

## What Happened

Built on 2026-11-02:

- `libs/project-discovery.lua` -- the rules from list-projects.sh (skipped
  names, the marks and their points, the threshold of 50), plus the type
  classification that tool never had. Loadable with `dofile`, and runnable
  as a command (`scan`, `score`, `classify`) under luajit or lua5.4.
- `libs/project-discovery.sh` -- the bash API from this issue
  (`project_discovery_init`, `_scan`, `_score`, `_classify`, plus
  `_is_project`), filling `DISCOVERED_PROJECTS`, `PROJECT_SCORES` and
  `PROJECT_TYPES`.
- `libs/project-discovery.info.md`, and `tests/test-project-discovery.sh`
  (40 checks on a scratch shelf of fake projects, under both interpreters
  and through the bash face).

**Decisions made while building it:**

- *One implementation, not two.* The issue asked for a bash library and a
  Lua port. Two copies of a rulebook drift -- the reason
  `libs/issue-names.lua` and `libs/transcript-discovery.sh` each exist as the
  single owner of their rules -- so the rules live in Lua and the bash
  functions run it and read its tab-separated answer.
- *Kind of project* (not in list-projects.sh, so invented here): a build
  file settles it (Cargo.toml, go.mod, package.json, pyproject.toml /
  setup.py / requirements.txt, a .rockspec); otherwise the most common
  source extension in the folder and src/; a tie goes alphabetically so the
  answer never depends on directory order; otherwise `unknown`.
- *The base folder is never listed.* list-projects.sh's `find` visits the
  base too, so a base scoring 50 lists itself as a project; a shelf is not a
  book. On the monorepo this changes nothing: both list the same 41.
- *Test location.* The issue named `libs/test-project-discovery.sh`; the
  test runner finds tests in `tests/`, so it lives there.
- *Not done:* step 6 (making delta-version's list-projects.sh use the
  library) is delta-version's to change; step 8 (a TUI example) waits for a
  script that needs to pick a project.

