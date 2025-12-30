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

- [ ] Long-running test (10000 timer create/fire cycles) doesn't leak memory
- [ ] Orphaned periodic timers are detected and cleaned
- [ ] Timer count has a sane upper bound
- [ ] Test: Create 100 periodic timers, destroy their "owners", verify cleanup

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
**Status:** UNCLAIMED
