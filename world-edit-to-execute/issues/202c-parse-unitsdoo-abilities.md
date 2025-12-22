# Issue 202c: Parse unitsdoo Modified Abilities

**Phase:** 2 - Data Model
**Type:** Feature
**Priority:** Medium
**Dependencies:** 202a-parse-unitsdoo-header-and-basic-fields
**Parent Issue:** 202-parse-war3map-units-doo

---

## Current Behavior

After 202a, the parser skips modified ability data. Units with custom ability
configurations (different levels, autocast settings) lose this information.

---

## Intended Behavior

Parse the modified abilities section within unit entries. This defines which
abilities have been customized from their defaults.

Returns structured data:
```lua
unit.abilities = {
    {
        id = "AHbz",      -- Blizzard
        autocast = true,  -- Autocast enabled
        level = 2,        -- Ability level
    },
    {
        id = "AHwe",      -- Water Elemental
        autocast = false,
        level = 3,
    },
}
```

---

## Suggested Implementation Steps

1. **Locate abilities section in unit entry**
   - After item drops section
   - Before hero data section

2. **Parse ability count**
   ```lua
   -- int32: Number "k" of modified abilities
   ```

3. **Parse each ability entry**
   ```lua
   -- For each ability:
   --   char[4]: Ability ID (e.g., "AHbz" = Blizzard)
   --   int32:   Autocast enabled (0 = off, 1 = on)
   --   int32:   Ability level (1+)
   ```

4. **Handle edge cases**
   - 0 abilities = unit uses all defaults
   - Only modified abilities are listed (not all abilities)

5. **Add format output for abilities**

---

## Technical Notes

### Ability ID Format

```lua
-- Format: A{race}{ability}
-- A = Ability prefix
-- {race} = H(uman), O(rc), U(ndead), E(lf), N(eutral)
-- {ability} = 2-char ability code

-- Examples:
AHbz = "Blizzard",
AHwe = "Water Elemental",
AHfs = "Flame Strike",
AOcr = "Critical Strike",
AUan = "Animate Dead",
AEsh = "Shadow Strike",
```

### Autocast Abilities

Only certain abilities support autocast:
- Heal, Inner Fire, Slow, Polymorph
- Frost Armor, Unholy Frenzy, Cripple
- Faerie Fire, Abolish Magic, Roar

For non-autocast abilities, the autocast field is ignored (always 0).

---

## Related Documents

- issues/202a-parse-unitsdoo-header-and-basic-fields.md
- issues/202-parse-war3map-units-doo.md (parent)

---

## Acceptance Criteria

- [ ] Correctly parses ability count
- [ ] Correctly parses ability IDs
- [ ] Correctly parses autocast flag
- [ ] Correctly parses ability levels
- [ ] Handles units with no modified abilities
- [ ] Handles units with multiple modified abilities
- [ ] Unit tests for ability parsing
- [ ] Format output shows ability info

---

## Notes

Modified abilities are common in hero arena and RPG maps where units have
custom skill configurations. This also applies to preplaced creeps with
specific ability levels.
