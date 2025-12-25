# Issue 11-002d: Add Special Room Features

## Current Behavior

Basic maze pages (from 11-002c) show poem content and 6 exit choices. All rooms look the same regardless of poem significance.

## Intended Behavior

Enhance certain maze rooms with special visual treatment to create landmarks, easter eggs, and discovery moments.

### Feature Categories

#### 1. Golden Poem Rooms ("Treasure Rooms")

Golden poems (431+ characters, typically from Fediverse) get enhanced visual treatment:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  ★ ═══════════════════════ TREASURE ROOM ═══════════════════════ ★           ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ╔═══════════════════════════════════════════════════════════════════════╗   ║
║  ║                                                                       ║   ║
║  ║  [GOLDEN POEM CONTENT]                                                ║   ║
║  ║                                                                       ║   ║
║  ║  the autumn leaves fall silently to earth                             ║   ║
║  ║  covering the ground in golden memories                               ║   ║
║  ║  while birds prepare their journey south                              ║   ║
║  ║  and we stand here, watching seasons change                           ║   ║
║  ║  [... more content ...]                                               ║   ║
║  ║                                                                       ║   ║
║  ╚═══════════════════════════════════════════════════════════════════════╝   ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
```

#### 2. Centroid Rooms ("Landmark Rooms")

The 5 centroid poems (melancholy, wonder, rage, tenderness, absurdity) serve as landmarks:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  ◆ ═══════════════════ LANDMARK: MELANCHOLY ═══════════════════ ◆            ║
╠═══════════════════════════════════════════════════════════════════════════════╣
```

Users who find these know they've reached a semantic "pole" in the poetry space.

#### 3. Easter Egg Rooms

Special treatment for poems with notable IDs:

| ID Pattern | Feature |
|------------|---------|
| 777, 7777 | "Lucky room" indicator |
| 42 | "Answer room" indicator |
| 1, 7793 | "First/Last room" indicator |
| Prime numbers | Subtle indicator? |

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  🎲 ═══════════════════════ ROOM 777 ═══════════════════════ 🎲              ║
╠═══════════════════════════════════════════════════════════════════════════════╣
```

(Note: Use ASCII art instead of emoji if emoji not supported)

#### 4. Frontier Rooms

Poems with low similarity to ALL their exits could be marked as "edge" rooms:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  ∴ ══════════════════ EDGE OF THE KNOWN ══════════════════ ∴                 ║
╠═══════════════════════════════════════════════════════════════════════════════╣
```

These are poems at the semantic periphery where choices lead in unfamiliar directions.

### Implementation Approach

#### Option A: Post-Processing
- Run after basic generation (11-002c)
- Read each HTML file, detect if special, rewrite with enhanced template
- Pro: Clean separation, easy to toggle
- Con: Slower (2 passes)

#### Option B: Integrated
- During generation (11-002c), check if poem is special
- Apply appropriate template variant
- Pro: Single pass
- Con: More complex generator

**Recommendation**: Option B (integrated) since the checks are simple lookups.

### Special Room Detection

```lua
function get_room_type(poem_id, poems_data, centroids)
    -- Check if golden poem
    if poems_data[poem_id].is_golden then
        return "treasure"
    end

    -- Check if centroid poem
    for mood, centroid_id in pairs(centroids) do
        if centroid_id == poem_id then
            return "landmark", mood
        end
    end

    -- Check easter egg IDs
    if poem_id == 777 or poem_id == 7777 then
        return "lucky"
    elseif poem_id == 42 then
        return "answer"
    elseif poem_id == 1 then
        return "first"
    elseif poem_id == #poems_data then
        return "last"
    end

    -- Check if frontier (low max similarity to exits)
    local max_sim = get_max_exit_similarity(poem_id)
    if max_sim < 0.6 then
        return "frontier"
    end

    return "normal"
end
```

### Configuration

```json
{
    "special_rooms": {
        "enable_treasure_rooms": true,
        "enable_landmark_rooms": true,
        "enable_easter_eggs": true,
        "enable_frontier_detection": true,
        "frontier_threshold": 0.6
    }
}
```

## Suggested Implementation Steps

### Step 1: Define Special Room Templates
- [ ] Create treasure room template (golden poems)
- [ ] Create landmark room template (centroids)
- [ ] Create easter egg templates (lucky, answer, first, last)
- [ ] Create frontier room template

### Step 2: Implement Detection Logic
- [ ] Load golden poem flags from poems.json
- [ ] Load centroid mappings from centroids.json
- [ ] Implement easter egg ID detection
- [ ] Implement frontier similarity detection

### Step 3: Integrate with Generator
- [ ] Modify maze-html-generator to check room type
- [ ] Apply appropriate template based on type
- [ ] Log special room statistics

### Step 4: Optional Enhancements
- [ ] Add ASCII art icons for different room types
- [ ] Consider subtle hints without giving away secrets
- [ ] Create "map" page showing landmark locations?

## Statistics to Track

| Metric | Expected Count |
|--------|----------------|
| Treasure rooms (golden) | ~431 |
| Landmark rooms (centroids) | 5 |
| Easter egg rooms | ~10 |
| Frontier rooms | ~100-500 (depends on threshold) |
| Normal rooms | ~7,000+ |

## Files to Modify

- `src/maze-html-generator.lua` (add special room logic)
- Create `src/maze-room-templates.lua` (template variants)

## Dependencies

- Basic maze generation (11-002c)
- `assets/centroids.json` (centroid poem IDs)
- Poems.json golden poem flags

## Related Issues

- **11-002c**: Basic maze generation (this extends it)
- **8-006**: Golden poem box-drawing format (reusable patterns)

---

**Phase**: 11 (Advanced Exploration)

**Priority**: Low (enhancement, not required for MVP)

**Created**: 2025-12-25

**Status**: Open

**Depends On**: 11-002c
