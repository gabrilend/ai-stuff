# BOUNTY BOARD: The Eternal Timer

```
╔══════════════════════════════════════════════════════════════════╗
║  ⚔️  BOSS MONSTER BOUNTY  ⚔️                                      ║
║                                                                  ║
║  Name: THE ETERNAL TIMER                                         ║
║  Threat Level: ███████░░░ (7/10)                                 ║
║  Location: The Temporal Heap (timers.lua:388-396)                ║
║  Reward: Memory stability, long-running game sessions            ║
║                                                                  ║
║  "They say it never dies. Each tick, it rises again.            ║
║   The heap grows. Memory bleeds. The game slows to              ║
║   a crawl as centuries of timers pile upon each other."         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## The Monster's Nature

The Eternal Timer is a creature of persistence. Periodic timers - those that repeat forever - are never cleaned from the heap. They are reinserted after each firing, their IDs incrementing eternally, their memory footprint growing without bound.

A map that spawns periodic timers in response to events will slowly consume all available memory. The game session that should last hours dies in minutes.

---

## Lair Location

```lua
-- timers.lua, lines 388-396
-- Handle periodic timers
if timer.periodic and timer.running then
    -- Reset for next period
    timer.elapsed = 0
    timer.expiration_time = game_time + timer.duration
    heap_insert(timer)  -- ETERNAL REINSERTION - NEVER FREED
end
```

---

## Battle Strategy

### What the Monster Exploits

1. Trigger creates periodic timer on unit spawn
2. Timer fires, is reinserted into heap
3. Unit dies, but timer reference is lost (no DestroyTimer call)
4. Timer continues firing forever, invisible to game logic
5. After 1000 unit spawns, 1000 orphan timers ticking

### Weapons Required

**Weapon 1: Timer Ownership Tracking**

```lua
-- Track which triggers/units own which timers
local timer_owners = {}  -- timer_id -> owner_handle

function CreateTimer(owner)
    local timer = { ... }
    timer_owners[timer.id] = owner
    return timer
end

function cleanup_orphan_timers()
    for timer_id, owner in pairs(timer_owners) do
        if not is_valid_handle(owner) then
            DestroyTimer(get_timer_by_id(timer_id))
        end
    end
end
```

**Weapon 2: Weak References**

```lua
-- Use weak tables so timers can be garbage collected
setmetatable(active_timers, { __mode = "v" })
```

**Weapon 3: Maximum Timer Limit**

```lua
local MAX_ACTIVE_TIMERS = 1000

function CreateTimer()
    if timer_count >= MAX_ACTIVE_TIMERS then
        warn("Timer limit reached, recycling oldest")
        destroy_oldest_timer()
    end
    -- ... create timer
end
```

---

## Victory Conditions

- [x] Long-running test (10000 timer create/fire cycles) doesn't leak memory
- [x] Orphaned periodic timers are detected and cleaned
- [ ] Timer count has a sane upper bound
- [x] Test: Create 100 periodic timers, destroy their "owners", verify cleanup

---

## Test Arena

```lua
-- Simulate a leaky map
local function stress_test_timers()
    local initial_count = get_timer_count()

    for i = 1, 1000 do
        local t = CreateTimer()
        TimerStart(t, 0.1, true, function()
            -- Periodic callback that does nothing
        end)
        -- "Forget" the timer handle (simulating lost reference)
    end

    -- Run game loop for simulated 10 seconds
    simulate_game_time(10.0)

    -- Force cleanup
    cleanup_orphan_timers()

    local final_count = get_timer_count()
    assert(final_count < initial_count + 100,
        "Timer leak detected: " .. final_count .. " active")
end
```

---

## Adventurer's Log

*"The old mage warned me: 'For every spell you cast on a timer, you must release it when done.' I did not listen. Now my game crawls, burdened by a thousand invisible clocks, each ticking toward nothing."*

— Trigger Script Author, post-mortem

---

## Related Scrolls

- `src/runtime/timers.lua` - The heap of eternals
- `src/runtime/triggers/` - Where timers are spawned
- WC3 native: `DestroyTimer()` - The weapon that should be used

---

**Bounty Posted By:** The Memory Conservation Society
**Date:** 2025-12-29
**Status:** CLAIMED AND COMPLETED

---

## Implementation Notes

**Fixed:** 2026-01-02

### Changes Made

1. **Added timer registry** (`src/runtime/timers.lua:27-30`)
   - Maps `timer_id -> timer` for all created timers
   - Allows finding orphans even when script has lost the reference
   - Cleared on `reset()`, entries removed on `destroy()`

2. **Added owner field to timers** (`src/runtime/timers.lua:180-182`)
   - Optional `owner` field tracks which entity/trigger owns the timer
   - Cleared when timer is destroyed

3. **New API functions:**
   - `timers.set_owner(timer, owner)` - Associate timer with an owner
   - `timers.get_owner(timer)` - Get timer's owner
   - `timers.cleanup_orphans(is_valid_fn)` - Destroy timers with invalid owners
   - `timers.get_registry_count()` - Get total timer count (for debugging)

4. **Runtime API registration** (`src/runtime/timers.lua:565-573`)
   - Added `TimerSetOwner`, `TimerGetOwner`, `CleanupOrphanTimers`

5. **Regression tests** (`src/tests/test_timers.lua:420-579`)
   - 27 new tests covering registry, ownership, and cleanup
   - Includes 100-timer leak simulation test

### Usage Example

```lua
-- When creating a timer for a unit
local t = CreateTimer()
TimerSetOwner(t, unit_handle)
TimerStart(t, 1.0, true, update_buff)

-- Periodically or on game pause
CleanupOrphanTimers(function(owner)
    return IsUnitAlive(owner)  -- or any validity check
end)
```

### Victory Condition Notes

- **Timer limit:** Not implemented. The cleanup mechanism is more flexible
  since it allows scripts to decide when to clean up. A hard limit could
  cause unexpected behavior. Can be added later if needed.

### Tests Pass

```
=== B02: Timer Registry ===
  [PASS] Registry tracks created timers
  [PASS] Registry removes destroyed timer
  [PASS] Registry empty after all destroyed

=== B02: Leak Prevention Simulation ===
  [PASS] 100 timers created
  [PASS] 50 orphans cleaned up
  [PASS] No timers remain

Tests: 100 passed, 0 failed
ALL TESTS PASSED
```
