# 201 - Implement Transcriber Engine with Caching

## Status
- Phase: 2
- Priority: High
- Dependencies: 103, 104

---

## Current Behavior

No translation engine exists. The vision describes LLM-generated code
but does not specify how translations are cached or reused.

---

## Intended Behavior

Build a **transcriber engine** - not just a translator, but a system
that constructs semantic meaning structures and caches them for reuse.

### Core Concept

Each game is treated as an **API** that players can access with
either client. The transcriber sits between them:

```
WoW Client  -->  [Transcriber Engine]  -->  CoH Server (Rogue Isles)
CoH Client  -->  [Transcriber Engine]  -->  WoW Server (Azeroth)
```

The transcriber:
1. Processes inputs/outputs from both games
2. Builds semantic meaning structures
3. Carries data through the other game's structures and functionality
4. Caches the "sense" - calibrated ahead of time by the LLM

### Caching Strategy

The LLM generates translation code **once** per semantic concept.
After that, the cached translation is reused.

```lua
-- Example: Fireball translation cached after first generation
cache["ability:fireball"] = {
  wow_to_coh = function(wow_data)
    return {
      power_id = "Fire_Blast",
      damage = scale_damage(wow_data.damage, "wow", "coh"),
      cast_time = wow_data.cast_time,
      recharge = wow_data.cooldown,
    }
  end,
  coh_to_wow = function(coh_data)
    return {
      spell_id = 133,  -- Fireball
      damage = scale_damage(coh_data.damage, "coh", "wow"),
      cast_time = coh_data.activation,
      cooldown = coh_data.recharge,
    }
  end,
  semantic_tags = {"fire", "ranged", "damage", "projectile"},
  generated_by = "llm-transcription-v1",
  generated_at = 1702900000,
}
```

### What Gets Cached

1. **Ability translations** - Fireball <-> Fire Blast, etc.
2. **Character appearance mappings** - CoH costume <-> WoW transmog
3. **Zone equivalences** - Rogue Isles regions <-> Azeroth zones
4. **Entity mappings** - Minions, pets, NPCs
5. **Progression translations** - Enhancements <-> item stats

---

## Character Appearance: Cross-Game Costume System

When a character crosses games, they enter a **character creator
part two** - transmog style, everything unlocked.

### CoH Character in Azeroth

Every CoH costume piece has an analogue in WoW:
- Shoulder pads, capes, helmets map to WoW transmog
- Body types map to WoW race/build options
- Colors map to WoW dye system (or approximation)

The player helps design how they'll look in Azeroth.
The LLM suggests mappings, the player refines.

### WoW Character in Paragon City / Rogue Isles

Every WoW armor set can be expressed in CoH costume pieces.
The costume creator opens with suggested translations.

**Bonus mechanic:** Every time a WoW character in CoH receives a
random Enhancement drop from battle, they unlock a new random
CoH costume piece. Progression in one game enriches the other.

---

## Technical Architecture

### The Transcriber Engine

```
src/transcriber/
  engine.lua           -- Core transcription logic
  cache.lua            -- Semantic cache management
  generator.lua        -- LLM code generation interface
  validator.lua        -- Verify generated code is safe/correct

  semantic/
    abilities.lua      -- Ability meaning structures
    appearances.lua    -- Costume/transmog mappings
    zones.lua          -- World space translations
    entities.lua       -- Character/NPC/pet mappings
```

### Cache Storage

```
assets/cache/
  abilities/           -- Cached ability translations
  appearances/         -- Cached costume mappings
  zones/               -- Cached zone translations
  entities/            -- Cached entity translations

  index.lua            -- Master cache index
  version.lua          -- Cache version for invalidation
```

### LLM Transcription Flow

```
1. Event occurs (player casts ability)
        |
        v
2. Check cache for semantic match
        |
        +--> Cache hit: Use cached translation
        |
        +--> Cache miss: Query LLM for translation
                |
                v
        3. LLM generates translation code
                |
                v
        4. Validator checks generated code
                |
                v
        5. Store in cache for future use
                |
                v
        6. Execute translation
```

---

## Suggested Implementation Steps

1. **Design cache data structures**
   - Define what a cached translation looks like
   - Plan cache key scheme (semantic tags, ability IDs, etc.)
   - Design cache invalidation strategy

2. **Build cache manager**
   - Load/save cache to disk
   - Lookup by semantic key
   - Handle cache versioning

3. **Implement LLM generator interface**
   - Prompt templates for ability translation
   - Prompt templates for appearance mapping
   - Response parsing and code extraction

4. **Build code validator**
   - Sandbox for testing generated code
   - Safety checks (no file access, network, etc.)
   - Correctness checks (output matches expected structure)

5. **Create transcriber engine core**
   - Event handling pipeline
   - Cache-first lookup
   - Fallback to LLM generation
   - Translation execution

6. **Implement appearance system**
   - CoH costume piece database
   - WoW transmog item database
   - Cross-game mapping generator
   - "Character creator part two" interface design

7. **Build enhancement-to-costume unlock system**
   - Track WoW character's CoH enhancement drops
   - Map enhancement rarity to costume piece unlock
   - Persist unlocks across sessions

---

## The Deeper Concept

The transcriber engine is not just code.

It builds **semantic meaning structures** - representations of
what actions, appearances, and events *mean* independent of
which game they occur in.

The sense is calibrated ahead of time.
Cached by an LLM AI transcription bot machine.
Ready to carry destiny between worlds.

---

## Notes

This issue bridges Phase 1 research with Phase 2 implementation.
The protocol knowledge from 101-105 informs what the transcriber
must handle. The caching strategy ensures the LLM isn't called
repeatedly for the same translations - performance is critical
for real-time gameplay feel.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-21 00:22*

I've read the issue file. This is a substantial issue that covers multiple distinct systems. Let me analyze it for splitting.

## Analysis

This issue contains **7 distinct implementation areas** as outlined in the suggested steps:

1. Cache data structures and design
2. Cache manager (load/save/lookup)
3. LLM generator interface
4. Code validator/sandbox
5. Transcriber engine core
6. Appearance/costume system
7. Enhancement-to-costume unlock system

These are clearly separable concerns with different technical domains. The appearance system alone (steps 6-7) is a significant feature that could be its own phase. The core transcriber (steps 1-5) forms the foundation.

## Recommendation: Split into sub-issues

| ID | Name | Description |
|----|------|-------------|
| 601a | design-cache-structures | Define cached translation format, key scheme, and invalidation strategy |
| 601b | build-cache-manager | Implement disk persistence, semantic lookup, and version handling for cache |
| 601c | implement-llm-generator | Create prompt templates and response parsing for LLM translation generation |
| 601d | build-code-validator | Sandbox environment and safety/correctness checks for generated translation code |
| 601e | create-transcriber-core | Event pipeline, cache-first lookup, LLM fallback, and translation execution |
| 601f | implement-appearance-system | Costume/transmog databases and cross-game mapping generator |
| 601g | build-enhancement-unlock | Track enhancement drops and map to costume piece unlocks |

## Dependency Chain

```
601a --> 601b --> 601e (cache must exist before manager, manager before engine)
         601c --> 601e (generator feeds into engine)
         601d --> 601e (validator gates generated code)
         
601f --> 601g (appearance system must exist before unlock system)
601e --> 601f (transcriber core handles appearance events)
```

The first five sub-issues (a-e) form the **core transcriber**, while f-g form the **appearance extension**. Consider completing a-e first as a functional milestone before tackling the appearance system.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-21 00:33*

Based on my analysis, this issue is quite large and covers multiple distinct systems. The suggested implementation steps already outline 7 separate areas, and there are clear dependency chains between them.

## Recommendation: Split into sub-issues

| ID | Name | Description |
|----|------|-------------|
| 601a | design-cache-structures | Define cached translation format, semantic key scheme, and invalidation strategy |
| 601b | build-cache-manager | Implement disk persistence, semantic lookup, and cache version handling |
| 601c | implement-llm-generator | Create prompt templates and response parsing for LLM translation generation |
| 601d | build-code-validator | Sandbox environment with safety and correctness checks for generated code |
| 601e | create-transcriber-core | Event pipeline with cache-first lookup, LLM fallback, and translation execution |
| 601f | implement-appearance-system | Costume and transmog databases with cross-game mapping generator |
| 601g | build-enhancement-unlock | Track enhancement drops and map to costume piece unlocks |

## Dependency Chain

```
601a ──┐
       ├──> 601b ──┐
                   │
       601c ───────┼──> 601e ──> 601f ──> 601g
                   │
       601d ───────┘
```

The core transcriber (a-e) should be completed first as a functional milestone. The appearance system (f-g) builds on top of the working transcriber and could reasonably be deferred to a later phase if needed - it's almost a feature enhancement rather than core infrastructure.

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-21 00:39*

I've read the issue file. Let me analyze it for splitting.

## Analysis

This is a substantial issue covering **7 distinct implementation areas** as outlined in the suggested steps. The systems span:

1. Cache data structures and design
2. Cache manager (load/save/lookup)
3. LLM generator interface
4. Code validator/sandbox
5. Transcriber engine core
6. Appearance/costume system
7. Enhancement-to-costume unlock system

These are clearly separable concerns with different technical domains. The appearance system (steps 6-7) is significant enough to be its own phase, while the core transcriber (steps 1-5) forms the foundation that must exist first.

## Recommendation: Split into sub-issues

| ID | Name | Description |
|----|------|-------------|
| 601a | design-cache-structures | Define cached translation format, semantic key scheme, and invalidation strategy |
| 601b | build-cache-manager | Implement disk persistence, semantic lookup, and cache version handling |
| 601c | implement-llm-generator | Create prompt templates and response parsing for LLM translation generation |
| 601d | build-code-validator | Sandbox environment with safety and correctness checks for generated code |
| 601e | create-transcriber-core | Event pipeline with cache-first lookup, LLM fallback, and translation execution |
| 601f | implement-appearance-system | Costume and transmog databases with cross-game mapping generator |
| 601g | build-enhancement-unlock | Track enhancement drops and map to costume piece unlocks |

## Dependency Chain

```
601a ──┐
       ├──> 601b ──┐
                   │
       601c ───────┼──> 601e ──> 601f ──> 601g
                   │
       601d ───────┘
```

The core transcriber (a-e) forms a functional milestone. The appearance system (f-g) builds on top and could reasonably be deferred - it's almost a feature enhancement rather than core infrastructure.
