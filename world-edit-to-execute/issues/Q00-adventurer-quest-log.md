# The Adventurer's Quest Log

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║   🗡️  WORLD EDIT TO EXECUTE - QUEST BOARD  🗡️                    ║
║                                                                  ║
║   "Start small. Slay slimes. Then dragons."                     ║
║                                                                  ║
║   Quests sorted by difficulty. Complete them in order to        ║
║   level up your understanding of the codebase.                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Your Adventure Begins

Welcome, brave adventurer. Before you stand against the Boss Monsters documented in the Bounty Hall, you must hone your skills on lesser creatures.

Each quest teaches you something about the codebase. Complete them in order. By the time you reach the bosses, you'll have the weapons you need.

---

## Quest Tier: 🌱 Seedling (Trivial Fixes)

### Quest S1: The Trimmed Tale
**Location:** `src/parsers/wts.lua:48-52`
**XP Reward:** 50
**Skill Gained:** Parser Edge Cases

*"The trigger strings speak, but their first words are stolen. A newline, intentionally placed, vanishes into the void."*

```lua
-- THE PROBLEM
text = text:gsub("^\n", ""):gsub("\n$", "")
-- Strips legitimate leading/trailing newlines
```

**Your Quest:**
- [ ] Add a flag to preserve intentional whitespace
- [ ] Or document this as intended behavior
- [ ] Test with a WTS file containing `TRIGSTR_001` = `"\nHello"`

**Reward:** Understanding of the WTS format, parser modification basics.

---

### Quest S2: The Ghostly Zero
**Location:** `src/jass/transpiler.lua:879`
**XP Reward:** 75
**Skill Gained:** Silent Error Detection

*"The FourCC speaks its name, but when malformed, it whispers only zero. Is it truly zero, or is it lying?"*

```lua
if not str or #str ~= 4 then
    return 0  -- Silent failure, indistinguishable from valid 0x00000000
end
```

**Your Quest:**
- [ ] Return an error indicator for invalid FourCC
- [ ] Or add a warning/log message
- [ ] Test with `'foo'` (3 chars) and `'12345'` (5 chars)

**Reward:** The `add_error()` function becomes your ally.

---

## Quest Tier: 🌿 Apprentice (Simple Fixes)

### Quest A1: The Floating Falsehood
**Location:** `src/runtime/pathfinding/smooth.lua:80`
**XP Reward:** 100
**Skill Gained:** Floating Point Awareness

*"Three points lie on a line. The math says so. But the computer disagrees by 0.0000000001."*

```lua
local cross = (p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x)
return cross == 0  -- FLOATING POINT EQUALITY IS A LIE
```

**Your Quest:**
- [ ] Replace `== 0` with `math.abs(cross) < EPSILON`
- [ ] Choose appropriate EPSILON (1e-9 suggested)
- [ ] Test with points that should be collinear but have float coords

**Reward:** You learn the ancient wisdom: "Never compare floats directly."

---

### Quest A2: The Negative Clock
**Location:** `src/runtime/gameloop.lua:97-100`
**XP Reward:** 100
**Skill Gained:** Defensive Programming

*"Time flows backward. The game pretends it didn't happen. No warning. No trace. Just silent acceptance."*

```lua
if dt < 0 then
    dt = 0  -- Silent clamp, no warning
end
```

**Your Quest:**
- [ ] Add a warning log when dt < 0
- [ ] Track occurrences for debugging
- [ ] Document why this can happen (NTP, clock skew)

**Reward:** The gameloop reveals its secrets. You understand tick timing.

---

## Quest Tier: ⚔️ Journeyman (Moderate Fixes)

### Quest J1: The Boundary Crasher
**Location:** `src/compat.lua:98-107`
**XP Reward:** 200
**Skill Gained:** Binary Safety

*"The blacksmith gave me this piece of data storage, which holds a function that I can use to read four bytes. But when the scroll is torn short, the function reaches into the void and crashes."*

```lua
compat.unpack_uint32 = function(data, pos)
    pos = pos or 1
    local b1, b2, b3, b4 = data:byte(pos, pos + 3)  -- No bounds check!
    return bytes_to_uint32(b1, b2, b3, b4), pos + 4
    -- If data is too short, b1-b4 are nil, arithmetic fails
end
```

**Your Quest:**
- [ ] Check `#data >= pos + 3` before unpacking
- [ ] Return `nil, pos, "Truncated data"` on failure
- [ ] Update all callers to handle the error
- [ ] Test with truncated MPQ files

**Reward:** The compat module becomes robust. Malformed files no longer crash.

---

### Quest J2: The Truncated Return
**Location:** `src/runtime/ecs/query.lua:104`
**XP Reward:** 200
**Skill Gained:** Lua Table Mastery

*"I asked the oracle for four components. She gave me two and fell silent. The rest were lost to nil."*

```lua
return entity_id, unpack(components)
-- unpack() stops at first nil in array
```

**Your Quest:**
- [ ] Verify components table has no gaps before unpack
- [ ] Or use explicit indexed returns: `components[1], components[2], ...`
- [ ] Or return the table itself and let caller index
- [ ] Test with 4+ component queries

**Reward:** You master Lua's `unpack()` and its treacherous ways.

---

### Quest J3: The Ignored Errors
**Location:** `src/jass/transpiler.lua:296-297`
**XP Reward:** 250
**Skill Gained:** Error Propagation

*"The transpiler screams in agony at broken code. But it keeps working, producing Lua full of nil. The caller never knows."*

```lua
errors = {},  -- Errors accumulate here
-- But transpile() returns code even when errors exist
```

**Your Quest:**
- [ ] Return `nil, errors` when errors is non-empty
- [ ] Or add a `strict` mode that stops on first error
- [ ] Document the error handling policy
- [ ] Test with intentionally malformed JASS

**Reward:** Neat! You've upgraded your error handling potential. Broken JASS fails loudly.

---

## Quest Tier: 🏰 Veteran (Complex Fixes)

### Quest V1: The Counting Loop
**Location:** `src/runtime/ecs/query.lua:70-76`
**XP Reward:** 400
**Skill Gained:** Performance Optimization

*"Every time I ask 'who has these components?', the oracle counts every soul in every ledger. Ten thousand entities, a hundred queries per tick. The kingdom slows to a crawl."*

```lua
for i, storage in ipairs(storages) do
    local count = 0
    for _ in pairs(storage) do count = count + 1 end  -- O(n) PER QUERY
    -- ...
end
```

**Your Quest:**
- [ ] Cache component counts in the component registry
- [ ] Increment on `add_component()`, decrement on `remove_component()`
- [ ] Update query to use cached counts
- [ ] Benchmark before/after with 1000 entities, 100 queries

**Reward:** The ECS hums with efficiency. Query performance becomes O(1) for count lookup.

---

## The Boss Bounties

*When you have completed the Veteran quests, you are ready.*

| Bounty | Monster | Threat |
|--------|---------|--------|
| B01 | [The Phantom Priority](B01-the-phantom-priority.md) | ████████░░ |
| B02 | [The Eternal Timer](B02-the-eternal-timer.md) | ███████░░░ |
| B03 | [The Hivemind Component](B03-the-hivemind-component.md) | ███████░░░ |

---

## Progression Path

```
🌱 Seedling Quests (S1, S2)
      │
      ▼
🌿 Apprentice Quests (A1, A2)
      │
      ▼
⚔️ Journeyman Quests (J1, J2, J3)
      │
      ▼
🏰 Veteran Quest (V1)
      │
      ▼
🐉 Boss Bounties (B01, B02, B03)
```

---

## Adventurer's Equipment

As you complete quests, you gain tools:

| Quest | Tool Gained |
|-------|-------------|
| S1 | Parser edge case awareness |
| S2 | `add_error()` usage |
| A1 | Epsilon comparison technique |
| A2 | Defensive logging |
| J1 | Bounds checking pattern |
| J2 | Safe unpack alternatives |
| J3 | Error propagation design |
| V1 | Count caching pattern |

---

## Quest Completion Protocol

When completing a quest:

1. Create a branch: `quest/S1-trimmed-tale`
2. Write the fix
3. Add tests proving the fix
4. Update this log with completion notes
5. Submit for review

*"I can't get through its generic abstracted computer problem tact, let me try this..."*

```lua
-- (writes some source-code)
-- "Take that!"
```

---

**Quest Board Maintained By:** The Guild of Careful Coders
**Last Updated:** 2025-12-29
