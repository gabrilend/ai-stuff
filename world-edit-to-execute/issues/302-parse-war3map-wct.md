# Issue 302: Parse war3map.wct (Custom Text Triggers)

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** Medium
**Dependencies:** 102-implement-mpq-archive-parser, 301-parse-war3map-wtg

---

## Current Behavior

Cannot read custom text triggers. JASS code written directly in the trigger
editor (via "Convert to Custom Text") is inaccessible.

---

## Intended Behavior

A parser that extracts custom trigger text from war3map.wct:
- Per-trigger custom JASS code
- Map header comment text
- Trigger comment blocks

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/parsers/
   └── wct.lua          (this issue)
   ```

2. **Implement header parsing**
   ```lua
   -- war3map.wct header structure:
   -- Offset  Type      Description
   -- 0x00    int32     File format version (1 for TFT)
   -- 0x04    int32     Length of map header comment
   -- 0x08    string    Map header comment (custom JASS at top of war3map.j)
   ```

3. **Parse trigger count**
   ```lua
   -- int32:  Number of triggers (should match wtg trigger count)
   ```

4. **Parse trigger custom text entries**
   ```lua
   -- For each trigger (matching wtg order):
   -- int32:  Length of custom text (0 if not custom)
   -- string: Custom JASS text (if length > 0)
   ```

5. **Return structured data**
   ```lua
   return {
       version = 1,
       header_comment = "// Custom map header JASS...",
       triggers = {
           [1] = nil,  -- Not a custom text trigger
           [2] = "function Trig_CustomTrigger_Actions takes nothing returns nothing\n...",
           [3] = nil,  -- Not a custom text trigger
       },
   }
   ```

6. **Link with wtg data**
   ```lua
   -- Provide helper to merge wct data into wtg triggers
   function wct.merge_with_wtg(wct_data, wtg_data)
       for i, trigger in ipairs(wtg_data.triggers) do
           if trigger.is_custom_text then
               trigger.custom_jass = wct_data.triggers[i]
           end
       end
   end
   ```

---

## Technical Notes

### Custom Text Trigger Workflow

In World Editor:
1. User creates GUI trigger
2. User selects "Edit > Convert to Custom Text"
3. Trigger becomes editable as raw JASS
4. GUI representation is lost, only JASS remains

### Header Comment Usage

The header comment appears at the top of the generated war3map.j file.
Common uses:
- Library declarations
- Global function definitions
- Custom type extensions
- Import statements for vJASS

### Relationship to wtg

The wct file is indexed by trigger order from wtg:
- Same number of entries as triggers in wtg
- Entry i corresponds to trigger i in wtg
- Entry is empty (length 0) if trigger is not custom text

### Empty Entries

Non-custom triggers have:
```
int32: 0  (length = 0, no text follows)
```

Custom triggers have:
```
int32: N  (length = N bytes)
char[N]: JASS code
```

---

## Related Documents

- docs/formats/wct-custom-triggers.md (to be created)
- issues/301-parse-war3map-wtg.md (trigger structure)
- issues/303-parse-war3map-j.md (compiled JASS)

---

## Acceptance Criteria

- [ ] Can parse war3map.wct from test archives
- [ ] Correctly extracts header comment
- [ ] Correctly extracts custom trigger text
- [ ] Handles empty entries for non-custom triggers
- [ ] Provides merge helper for wtg data
- [ ] Returns structured Lua table
- [ ] Unit tests for parser

---

## Notes

The wct format is simpler than wtg. It essentially stores the raw JASS text
for triggers that were converted to custom text. This data is used:

1. During map save: Custom text is inserted into war3map.j
2. During map load: To restore editable JASS in trigger editor
3. For analysis: To understand what code runs for custom triggers

Without wct parsing, custom text triggers would appear as black boxes.

Reference: [WC3MapSpecification](https://github.com/ChiefOfGxBxL/WC3MapSpecification)
