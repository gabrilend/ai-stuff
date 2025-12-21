# 103 - Create Protocol Mapping Matrix

## Status
- Phase: 1
- Priority: High
- Dependencies: 101, 102

---

## Current Behavior

Even once both protocols are documented separately, there is no
systematic comparison showing how data maps between them.

---

## Intended Behavior

A mapping document (`docs/protocol-mapping.md`) should exist that:

1. Lists every major data type from both games side-by-side
2. Indicates translation feasibility for each pair
3. Notes where narrative system must fill gaps
4. Provides translation priority ordering

The matrix should answer: "When WoW sends X, what does CoH receive?"
and vice versa.

---

## Suggested Implementation Steps

1. Create initial comparison categories:
   - Character identity (name, race, class <-> archetype)
   - Position/movement (coordinates, facing, speed)
   - Combat (abilities, damage, CC, healing)
   - Social (chat, party, guild <-> supergroup)
   - Inventory (items, currency)
   - Progression (XP, levels, talents <-> powers)

2. For each category, create sub-mappings:
   - Direct equivalents (1:1 mapping)
   - Approximate equivalents (requires conversion)
   - No equivalent (requires narrative generation)
   - Incompatible (cannot translate, must ignore or fake)

3. Build translation lookup tables:
   ```lua
   wow_to_coh = {
     ["WARRIOR"] = "TANKER",
     ["WARLOCK"] = "MASTERMIND", -- close enough?
     -- etc.
   }
   ```

4. Document bidirectional asymmetries:
   - Some translations work one way but not the other
   - Example: CoH costume data has no WoW equivalent

5. Prioritize by gameplay impact:
   - P0: Movement, combat basics (game unplayable without)
   - P1: Abilities, stats (degraded experience)
   - P2: Social features (quality of life)
   - P3: Cosmetics (nice to have)

---

## Deliverable Format

```markdown
## Movement Data

| WoW Field | CoH Equivalent | Direction | Notes |
|-----------|----------------|-----------|-------|
| position_x | pos_x | bidirectional | Scale factor needed |
| facing | orientation | bidirectional | Radians vs degrees |
| mount_id | travel_power | wow->coh only | Map to flight/super speed |
```

---

## Notes

This matrix will be the primary reference for the Translation Engine
implementation in Phase 2+. It should be treated as a living document
that evolves as edge cases are discovered.
