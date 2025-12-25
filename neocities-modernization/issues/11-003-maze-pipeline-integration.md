# Issue 11-003: Maze Pipeline Integration

## Current Behavior

The main pipeline (`run.sh`) generates similar/, different/, and chronological HTML pages. Maze generation is not integrated.

## Intended Behavior

Add maze generation as an optional stage in the main pipeline, with appropriate flags and freshness checking.

### Pipeline Stage

```
Existing Pipeline:
    1. Extract poems
    2. Parse and validate
    3. Generate embeddings
    4. Calculate similarity matrix
    5. Generate HTML (similar, different, chronological)

New Stage:
    6. Generate maze pages (optional)
        a. Compute dimension extremes (if not cached)
        b. Filter to maze exits (if not cached)
        c. Generate maze HTML pages
```

### CLI Integration

```bash
# Full pipeline including maze
./run.sh --include-maze

# Just maze generation (assumes dependencies exist)
./run.sh --maze-only

# Skip maze even if enabled by default
./run.sh --skip-maze
```

### Freshness Checking

Maze cache should be regenerated when:
- embeddings.json changes (embeddings affect extremes)
- poems.json changes (new poems added)
- Algorithm configuration changes

```lua
function is_maze_cache_fresh()
    local cache_mtime = get_mtime("assets/dimension_maze_cache.json")
    local embeddings_mtime = get_mtime("assets/embeddings/.../embeddings.json")
    local poems_mtime = get_mtime("assets/poems.json")

    return cache_mtime > embeddings_mtime and cache_mtime > poems_mtime
end
```

### Menu Integration

Add to interactive menu (`run.sh -I`):

```
┌─────────────────────────────────────────────────────────────────┐
│  PIPELINE OPTIONS                                               │
│                                                                 │
│  [x] Generate similar pages                                     │
│  [x] Generate different pages                                   │
│  [ ] Generate maze pages         ← New option                   │
│  [x] Generate chronological index                               │
└─────────────────────────────────────────────────────────────────┘
```

### Output Verification

After maze generation, verify:
- All 7,793 maze pages exist
- All exit links are valid (target files exist)
- No broken references

```lua
function verify_maze_output()
    local missing = {}
    local broken_links = {}

    for poem_id = 1, #poems do
        local path = string.format("output/maze/%d.html", poem_id)
        if not file_exists(path) then
            table.insert(missing, poem_id)
        else
            -- Check exit links
            local exits = get_exits(poem_id)
            for _, exit_id in ipairs(exits) do
                local exit_path = string.format("output/maze/%d.html", exit_id)
                if not file_exists(exit_path) then
                    table.insert(broken_links, {from = poem_id, to = exit_id})
                end
            end
        end
    end

    return #missing == 0 and #broken_links == 0, missing, broken_links
end
```

## Suggested Implementation Steps

### Step 1: Add Maze Flag to run.sh
- [ ] Add `--include-maze`, `--maze-only`, `--skip-maze` flags
- [ ] Update help text

### Step 2: Implement Freshness Check
- [ ] Add `is_maze_cache_fresh()` function
- [ ] Skip regeneration if cache is current

### Step 3: Add Pipeline Stage
- [ ] Call dimension-extreme computation (11-002a)
- [ ] Call similarity filtering (11-002b)
- [ ] Call HTML generation (11-002c)

### Step 4: Add Menu Option
- [ ] Add maze checkbox to TUI menu
- [ ] Implement corresponding action

### Step 5: Add Verification
- [ ] Check all pages generated
- [ ] Validate exit links
- [ ] Report statistics

### Step 6: Documentation
- [ ] Update run.sh help text
- [ ] Update docs/data-flow-architecture.md
- [ ] Add maze to roadmap completion criteria

## Configuration

Add to `config/input-sources.json`:

```json
{
    "maze": {
        "enabled": false,
        "exits_per_room": 6,
        "preview_length": 50,
        "enable_special_rooms": true
    }
}
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Missing embeddings | Error with "run embeddings first" message |
| Partial maze cache | Warn and regenerate |
| Disk full during generation | Fail fast with cleanup |
| Interrupted generation | Resume from last completed page |

## Files to Modify

- `run.sh` (add maze flags and stage)
- `src/main.lua` (add maze menu option)
- `config/input-sources.json` (add maze config section)

## Dependencies

- All 11-002 sub-issues complete
- embeddings.json exists
- poems.json exists

## Related Issues

- **11-002a through 11-002d**: Maze generation components
- **8-001**: Pattern for pipeline integration

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Low (final integration step)

**Created**: 2025-12-25

**Status**: Open

**Depends On**: 11-002a, 11-002b, 11-002c, 11-002d
