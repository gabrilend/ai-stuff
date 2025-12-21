# Phase 6: Implement Transcriber Engine with Caching

## Status
- Priority: High
- Dependencies: Phase 3, Phase 4

---

## Current Behavior

No transcription engine exists. The vision describes LLM-generated
code but does not specify how translations are cached or reused.

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
}
```

---

## Character Appearance: Cross-Game Costume System

When a character crosses games, they enter **character creator
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

  index.lua            -- Master cache index
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
2. **Build cache manager** - Load/save, lookup, versioning
3. **Implement LLM generator interface** - Prompts, parsing
4. **Build code validator** - Sandbox, safety checks
5. **Create transcriber engine core** - Event pipeline
6. **Implement appearance system** - Costume <-> transmog
7. **Build enhancement-to-costume unlock system**

---

## The Deeper Concept

The transcriber engine builds **semantic meaning structures** -
representations of what actions, appearances, and events *mean*
independent of which game they occur in.

The sense is calibrated ahead of time.
Cached by an LLM AI transcription bot machine.
Ready to carry destiny between worlds.

---

## Phase Completion Criteria

- [ ] Transcriber engine processes events from both games
- [ ] Cache stores and retrieves translation code
- [ ] LLM generates translations for uncached abilities
- [ ] Generated code runs in sandbox safely
- [ ] Character appearance mapping works bidirectionally
- [ ] Enhancement drops unlock costume pieces
- [ ] Demo shows live translation with caching

---

## Log

- 2025-12-19: Phase created from issue 201
