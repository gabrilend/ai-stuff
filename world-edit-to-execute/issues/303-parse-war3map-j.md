# Issue 303: Parse war3map.j (JASS Script)

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 102-implement-mpq-archive-parser

---

## Current Behavior

Cannot read the compiled JASS script. The actual executable game logic is
inaccessible, preventing trigger execution.

---

## Intended Behavior

Extract and prepare war3map.j for parsing:
- Extract raw JASS text from archive
- Validate JASS syntax structure
- Identify main sections (globals, functions, triggers)
- Prepare for lexer/parser pipeline

---

## Suggested Implementation Steps

1. **Create extractor module**
   ```
   src/parsers/
   └── j.lua            (this issue - extraction/validation)
   ```

2. **Extract JASS script**
   ```lua
   local j = require("parsers.j")
   local jass_text = j.extract(archive)  -- Get raw JASS from war3map.j
   ```

3. **Validate basic structure**
   ```lua
   -- Verify expected sections exist:
   -- - globals/endglobals block
   -- - function declarations
   -- - main() entry point
   -- - config() for map configuration
   ```

4. **Identify section boundaries**
   ```lua
   -- Return section offsets for later parsing:
   return {
       raw = jass_text,
       sections = {
           globals = { start = 1, finish = 500 },
           functions = {
               { name = "main", start = 501, finish = 800 },
               { name = "config", start = 801, finish = 1200 },
               { name = "Trig_Init_Actions", start = 1201, finish = 1500 },
           },
       },
   }
   ```

5. **Handle common.j and Blizzard.j references**
   ```lua
   -- Note: war3map.j depends on:
   -- - common.j (native function declarations)
   -- - Blizzard.j (standard library functions)
   -- These are not in the map file but needed for complete parsing
   ```

---

## Technical Notes

### JASS File Structure

A typical war3map.j has this structure:

```jass
// Map header comment (from wct)

globals
    // Global variable declarations
    trigger gg_trg_Init = null
    unit udg_Hero = null
    integer udg_Count = 0
endglobals

// Trigger functions
function Trig_Init_Conditions takes nothing returns boolean
    return true
endfunction

function Trig_Init_Actions takes nothing returns nothing
    // Trigger actions
endfunction

function InitTrig_Init takes nothing returns nothing
    set gg_trg_Init = CreateTrigger()
    call TriggerAddCondition(gg_trg_Init, Condition(function Trig_Init_Conditions))
    call TriggerAddAction(gg_trg_Init, function Trig_Init_Actions)
endfunction

// Main entry points
function main takes nothing returns nothing
    call SetCameraBounds(...)
    call InitTrig_Init()
    // ...
endfunction

function config takes nothing returns nothing
    call SetMapName("...")
    call SetPlayers(4)
    // ...
endfunction
```

### Generated vs Custom Code

The compiler generates:
- `gg_trg_*` trigger handles
- `udg_*` user-defined globals
- `InitTrig_*` trigger initialization
- `main()` and `config()` entry points

Custom code includes:
- Header comment from wct
- Custom text trigger bodies
- Library functions

### Dependencies

JASS scripts depend on external files:
- `common.j` - Engine native declarations (~5000 lines)
- `Blizzard.j` - Standard library (~10000 lines)

These define functions like `CreateUnit`, `GetTriggerUnit`, etc.

---

## Related Documents

- docs/formats/jass-script.md (to be created)
- issues/304-build-jass-lexer.md (tokenization)
- issues/305-build-jass-parser.md (AST generation)
- issues/301-parse-war3map-wtg.md (source triggers)

---

## Acceptance Criteria

- [ ] Can extract war3map.j from test archives
- [ ] Extracts complete JASS text
- [ ] Validates basic JASS structure
- [ ] Identifies globals section
- [ ] Identifies function boundaries
- [ ] Identifies main() and config() entry points
- [ ] Returns structured metadata
- [ ] Unit tests for extractor

---

## Notes

This issue focuses on extraction and basic validation, not full parsing.
The actual JASS parsing happens in issues 304-305 (lexer/parser).

The war3map.j file is the "compiled" output of the trigger editor. Even
if we perfectly parse wtg/wct, we need to handle war3map.j because:

1. Some maps use only custom JASS (no GUI triggers)
2. Protected maps may have modified/obfuscated JASS
3. The j file is what actually runs in-game

Reference: [JASS Manual](http://jass.sourceforge.net/doc/)
Reference: [WC3 Modding Wiki](https://wc3modding.info)
