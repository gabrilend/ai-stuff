# BOUNTY BOARD: The Phantom Priority

```
╔══════════════════════════════════════════════════════════════════╗
║  ⚔️  BOSS MONSTER BOUNTY  ⚔️                                      ║
║                                                                  ║
║  Name: THE PHANTOM PRIORITY                                      ║
║  Threat Level: ████████░░ (8/10)                                 ║
║  Location: The Pathfinding Caverns (astar.lua:355-358)           ║
║  Reward: Faster pathfinding, fewer wasted cycles                 ║
║                                                                  ║
║  "It wears the face of a solved node, but carries the           ║
║   weight of its former self. Adventurers report seeing          ║
║   the same waypoint twice, thrice... their journeys             ║
║   taking far longer than the map suggests."                     ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## The Monster's Nature

Deep within the A* algorithm lurks a creature of duplicity. When a node is discovered, it joins the Open Set - a priority queue of places yet to explore. But when a BETTER path to that same node is found later, the monster refuses to update its priority.

The old entry remains. The node is processed multiple times. Iterations are wasted. The `max_iterations` limit is hit prematurely on complex maps.

---

## Lair Location

```lua
-- astar.lua, lines 355-358
if not in_open[neighbor_key] then
    open_set:push({ x = nx, y = ny }, f_score)
    in_open[neighbor_key] = true
end
-- THE PHANTOM LURKS HERE: No update when already in open set
```

---

## Battle Strategy

### What the Monster Exploits

1. Node N discovered with f_score = 100, added to open set
2. Later, better path to N found with f_score = 50
3. Old entry (f=100) stays in queue
4. Node N processed when f=100 entry is popped (WASTED)
5. Node N processed AGAIN when f=50 entry would be popped (if it existed)

### Weapons Required

The adventurer must implement **decrease-key** functionality:

```lua
-- PROPOSED SOLUTION (sketch)
if not in_open[neighbor_key] then
    open_set:push({ x = nx, y = ny }, f_score)
    in_open[neighbor_key] = true
    open_scores[neighbor_key] = f_score  -- Track current f_score
elseif f_score < open_scores[neighbor_key] then
    -- Update priority (requires heap modification or lazy deletion)
    open_set:update_priority(neighbor_key, f_score)
    open_scores[neighbor_key] = f_score
end
```

### Alternative Tactics

**Lazy Deletion Strategy:**
- Allow duplicates in the heap
- When popping, check if node was already processed (in closed set)
- Skip if already closed
- Simpler but uses more memory

```lua
local node = open_set:pop()
local key = node.x .. "," .. node.y
if closed[key] then
    -- Ghost node from old priority, skip it
    goto continue
end
```

---

## Victory Conditions

- [x] No node is processed more than once
- [x] Pathfinding completes in fewer iterations on open terrain
- [x] Test case: 64x64 open map with obstacles, count iterations before/after
- [x] Memory usage doesn't explode (if using lazy deletion)

---

## Test Arena

```lua
-- Create a map where this bug manifests
-- Open area with multiple paths to same destination
local grid = create_test_grid(64, 64)
-- Add scattered obstacles forcing path recalculation
place_obstacles(grid, "scattered")

local iterations_before = count_astar_iterations(grid, {0,0}, {63,63})
-- Apply fix
local iterations_after = count_astar_iterations(grid, {0,0}, {63,63})

assert(iterations_after < iterations_before * 0.7,
    "Fix should reduce iterations by at least 30%")
```

---

## Adventurer's Log

*"I watched the pathfinder circle the same rock three times before finding the gap. Each circle, it seemed to forget what it had learned. The Phantom Priority had claimed another victim."*

— Anonymous Unit, reporting slow movement orders

---

## Related Scrolls

- `src/runtime/pathfinding/astar.lua` - The monster's lair
- `src/runtime/pathfinding/heap.lua` - May need modification for decrease-key
- Issue 403b - Original A* implementation

---

**Bounty Posted By:** The Optimization Guild
**Date:** 2025-12-29
**Status:** CLAIMED AND COMPLETED

---

## Implementation Notes

**Date:** 2026-09-29

### What the monster really was

The bounty's diagnosis was close but not exact. `in_open` already kept a
node from being queued twice, so the old entry never sat beside a new one.
What went wrong instead: when a cheaper path to a queued node turned up, its
g_score changed but its queue priority stayed at the old, higher f. The node
then came out of the queue late, out of order. That did more than waste
iterations: the goal could be popped while a node with a lower true f still
waited under its stale priority, and A* returned a path **longer than the
shortest**. Against Dijkstra on random 40x40 grids (28% walls, 60 grids per
setting), the old search returned a longer path on 12/60 grids with
euclidean + diagonal, 3/60 with chebyshev + diagonal and 3/60 with
manhattan (4-way). Its "fast" iteration counts in those settings came
partly from stopping early on a wrong path.

### The fix (`src/runtime/pathfinding/astar.lua`)

1. **Lazy deletion.** Each open-set entry now carries the g it was pushed
   with, and every better path pushes a fresh entry at its true f. When an
   entry is popped, it is expanded only if its g still equals the node's
   g_score; otherwise it is a ghost of a worse path and is skipped without
   counting toward `max_iterations`. `in_open` and the now-unused `make_key`
   are gone. The same g check lets a node be expanded again when a
   heuristic that overestimates (manhattan with diagonals) finds it a
   cheaper path later.
2. **Tie-break on g.** `PriorityQueue:push(item, priority, tiebreak)` takes
   an optional third argument (default 0; lower comes out first among equal
   priorities). A* passes `-g`, so among equal f it expands the node
   furthest along. Open ground is full of equal-f cells; this walks
   straight through them instead of fanning out. Existing two-argument
   callers are unchanged.

Decision recorded in `CRITICAL-PATH.md` OQ-006 (lazy deletion over
decrease-key: no heap index to maintain, and the ghost entries are bounded
by the number of path improvements).

### Measurements (old -> new)

| Map (64x64, start 0,0 to 63,63) | Old | New |
|---|---|---|
| Open map, manhattan 4-way | 1708 iterations | 127 |
| Test arena in `test_astar.lua` (10% scattered walls) | 894 | 238 (-73%) |
| 20 maps, 5% walls, manhattan 4-way (sum) | 21663 | 4017 (-81%) |
| 20 maps, 10% walls, manhattan 4-way (sum) | 22170 | 5944 (-73%) |
| 20 maps, 20% walls, manhattan 4-way (sum) | 22420 | 15199 (-32%) |

With euclidean + diagonal at 5-10% walls the new search takes *more*
iterations (3501 -> 5207 at 5%), and the tie-break makes no difference
there (5215 without it). The difference is correctness: on those same
maps the old search returned a longer path on 1/20 (5%) and 7/20 (10%),
the new one on none.

Memory: across 240 searches on 64x64 maps (5-30% walls, three movement
settings), total pushes fell from 196606 to 174438; the largest open set
seen grew from 852 to 1267 entries (of 4096 cells).

### Victory condition notes

- **No node processed more than once:** holds with a consistent heuristic
  (manhattan or euclidean 4-way; euclidean or chebyshev 8-way): a node's
  first valid pop is at its final g. With manhattan + diagonal the
  heuristic overestimates and a node can be (correctly) reopened when a
  cheaper path appears; that is the price of that setting, not the
  phantom.

### Tests (`src/tests/test_astar.lua`, section "Shortest Path (B01)")

- Tie-break ordering of `PriorityQueue`
- Costs match Dijkstra on 25 deterministic 24x24 grids for each admissible
  setting (the old search fails euclidean + diagonal on 3 and chebyshev +
  diagonal on 1)
- 64x64 open map within 150 iterations (old: 1708)
- 64x64 test arena at least 30% below the old search's 894 (now 238)

```
Tests: 99 passed, 0 failed
ALL TESTS PASSED
```

The full suite (104 test files) passes.

