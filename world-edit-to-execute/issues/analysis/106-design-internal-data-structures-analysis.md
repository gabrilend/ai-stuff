## Analysis: Issue 106 - Design Internal Data Structures

This issue is a good candidate for splitting. It contains **4 distinct data structure modules** plus integration/testing work, each with its own file and responsibilities. Splitting allows parallel development once dependencies (103, 104, 105) are met.

---

## Suggested Sub-Issues

### 106a-implement-stringtable-wrapper

**Description:** Implement the StringTable class that wraps parsed WTS data and provides TRIGSTR resolution.

**Scope:**
- Create `src/data/strings.lua`
- StringTable.new() constructor accepting parsed WTS data
- StringTable:get(id) for direct string lookup
- StringTable:resolve(text) for TRIGSTR_xxx substitution
- Unit tests for string resolution

**Dependencies:** 104 (WTS parser must exist to know input format)

---

### 106b-implement-terrain-class

**Description:** Implement the Terrain class that wraps parsed W3E data and provides spatial queries.

**Scope:**
- Create `src/data/terrain.lua`
- Terrain.new() constructor from parsed W3E data
- Terrain:get_tile(x, y) with bounds checking
- Terrain:get_height(x, y) and Terrain:get_height_interpolated(x, y)
- Terrain:is_pathable(x, y) based on tile flags
- Unit tests for terrain queries

**Dependencies:** 105 (W3E parser must exist to know input format)

---

### 106c-implement-player-force-structures

**Description:** Implement Player and Force data structures from parsed W3I player/force definitions.

**Scope:**
- Create `src/data/player.lua`
- Player.new() constructor with id, name, type, race, start_position, color, allies
- Define PLAYER_COLORS constant table
- Force structure (if complex enough to warrant its own class, otherwise a simple table)
- Unit tests for player/force creation

**Dependencies:** 103 (W3I parser defines player/force data shape)

---

### 106d-implement-map-class-and-loader

**Description:** Implement the central Map class that aggregates all components and provides the unified loading API.

**Scope:**
- Create `src/data/init.lua`
- Map.new() constructor with all metadata fields
- Map.load(w3x_path) orchestrating MPQ extraction and component creation
- Map:apply_info() to populate from W3I data
- Map:get_player(), Map:get_force() accessors
- Map:resolve_string(), Map:get_display_name() convenience methods
- Coordinate conversion: Map:tile_to_world(), Map:world_to_tile()
- Lazy loading via metatables (optional optimization)
- Integration tests with real .w3x files

**Dependencies:** 106a, 106b, 106c (all component classes must exist)

---

## Dependency Graph

```
103 (w3i parser) ──┬──→ 106c (player/force)
                   │
104 (wts parser) ──┼──→ 106a (stringtable)
                   │                         ╲
105 (w3e parser) ──┴──→ 106b (terrain)    ───→ 106d (map + loader)
                                             ╱
                   MPQ module (existing) ────╯
```

---

## Summary

| Sub-Issue | Name | Est. Complexity | Can Parallelize With |
|-----------|------|-----------------|---------------------|
| 106a | implement-stringtable-wrapper | Small | 106b, 106c |
| 106b | implement-terrain-class | Medium | 106a, 106c |
| 106c | implement-player-force-structures | Small | 106a, 106b |
| 106d | implement-map-class-and-loader | Medium | None (depends on a,b,c) |

**Recommendation:** Split this issue. The component classes (106a, 106b, 106c) can be developed in parallel once their parser dependencies are complete, and 106d serves as the integration point. This separation also makes testing cleaner—each component can be unit tested in isolation before integration testing in 106d.
