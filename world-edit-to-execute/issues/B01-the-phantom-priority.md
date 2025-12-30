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

- [ ] No node is processed more than once
- [ ] Pathfinding completes in fewer iterations on open terrain
- [ ] Test case: 64x64 open map with obstacles, count iterations before/after
- [ ] Memory usage doesn't explode (if using lazy deletion)

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
**Status:** UNCLAIMED
