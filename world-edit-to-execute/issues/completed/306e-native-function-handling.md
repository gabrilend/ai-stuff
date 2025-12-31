# Issue 306e: Native Function Handling

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 306a-transpiler-infrastructure, 306d-transpile-expressions
**Parent Issue:** 306-create-jass-lua-transpiler

---

## Current Behavior

The transpiler identifies native functions via `is_native(ctx, name)` and
prefixes calls with `runtime.`. However, there is no mechanism to:
- Load native signatures from common.j/blizzard.j
- Handle special JASS constructs like `Condition(function X)`
- Distinguish between truly native functions and BJ (Blizzard JASS) wrappers

---

## Intended Behavior

Robust native function handling that:
- Loads native signatures from common.j and blizzard.j
- Correctly routes native calls through the runtime API
- Handles special constructs like `Condition()` and `Filter()`
- Distinguishes natives from BJ helper functions

**Special Constructs:**
```jass
call TriggerAddCondition(t, Condition(function MyCheck))
call TriggerAddAction(t, function MyAction)
call ForGroup(g, function DoForUnit)
```
Becomes:
```lua
runtime.TriggerAddCondition(t, runtime.Condition(MyCheck))
runtime.TriggerAddAction(t, MyAction)
runtime.ForGroup(g, DoForUnit)
```

**Native Detection:**
```jass
-- From common.j:
native CreateUnit takes player p, integer id, real x, real y, real f returns unit

-- User map function:
function SpawnUnit takes nothing returns unit
    return CreateUnit(Player(0), 'hfoo', 0, 0, 0)
endfunction
```
Becomes:
```lua
local function SpawnUnit()
    return runtime.CreateUnit(runtime.Player(0), 1751543663, 0, 0, 0)
end
```

---

## Suggested Implementation Steps

1. **Define native function categories**
   ```lua
   -- {{{ Native categories
   -- Natives are functions defined with 'native' keyword in common.j
   -- They are implemented by the game engine (or our runtime)

   -- BJ functions are regular functions in blizzard.j
   -- They are wrappers around natives for convenience
   -- BJ functions should NOT be prefixed with runtime.

   -- Examples:
   -- Native: CreateUnit, Player, GetTriggerUnit
   -- BJ: CreateNUnitsAtLoc, GetLastCreatedUnit
   -- }}}
   ```

2. **Create native signature registry**
   ```lua
   -- {{{ Native registry structure
   local native_registry = {
       -- Key: function name
       -- Value: signature info
       ["CreateUnit"] = {
           params = {
               {name = "p", param_type = "player"},
               {name = "id", param_type = "integer"},
               {name = "x", param_type = "real"},
               {name = "y", param_type = "real"},
               {name = "f", param_type = "real"},
           },
           return_type = "unit",
           is_constant = false,
       },
       -- ... more natives
   }
   -- }}}
   ```

3. **Implement native registry loader**
   ```lua
   -- {{{ load_natives_from_ast
   local function load_natives_from_ast(ast)
       local registry = {}

       for _, decl in ipairs(ast.declarations) do
           if decl.type == "NATIVE_DECL" then
               registry[decl.name] = {
                   params = decl.params,
                   return_type = decl.return_type,
                   is_constant = decl.is_constant,
               }
           end
       end

       return registry
   end
   -- }}}

   -- {{{ load_common_j_natives
   local function load_common_j_natives(common_j_source)
       -- Parse common.j to extract native signatures
       local lexer = require("jass.lexer")
       local parser = require("jass.parser")

       local tokens = lexer.tokenize(common_j_source)
       local ast, errors = parser.parse(tokens)

       if #errors > 0 then
           -- Log parsing errors but continue
           for _, err in ipairs(errors) do
               print("Warning: common.j parse error: " .. err.message)
           end
       end

       return load_natives_from_ast(ast)
   end
   -- }}}
   ```

4. **Integrate native registry with context**
   ```lua
   -- {{{ Updated create_context
   local function create_context(options)
       options = options or {}

       local ctx = {
           -- ... existing fields from 306a ...

           -- Native handling
           native_registry = options.native_registry or {},
           use_runtime_prefix = options.use_runtime_prefix ~= false,
       }

       return ctx
   end
   -- }}}

   -- {{{ is_native (updated)
   local function is_native(ctx, name)
       -- Check native registry first (from common.j)
       if ctx.native_registry[name] then
           return true
       end

       -- Check declarations collected from map script
       if ctx.natives[name] then
           return true
       end

       return false
   end
   -- }}}
   ```

5. **Handle special code-type parameters**
   ```lua
   -- {{{ handle_code_parameter
   -- Some natives take 'code' type parameters that expect function references
   -- JASS syntax: Condition(function MyFunc) or Filter(function MyFunc)
   -- The 'function' keyword is part of the expression, not a separate call

   -- In the AST, this appears as:
   -- {type = "FUNCTION_REF", name = "MyFunc"}

   -- When used as argument to natives like Condition():
   -- call TriggerAddCondition(t, Condition(function MyCheck))

   -- Transpiles to:
   -- runtime.TriggerAddCondition(t, runtime.Condition(MyCheck))

   -- The function reference just becomes the function name
   -- No special handling needed - transpile_expr handles FUNCTION_REF
   -- }}}
   ```

6. **Handle Condition() and Filter() wrappers**
   ```lua
   -- {{{ Special natives
   -- Condition(function X) returns boolexpr
   -- Filter(function X) returns boolexpr
   -- These wrap a function reference in a boolexpr handle

   -- In transpiled code:
   -- runtime.Condition(MyFunc)
   -- runtime.Filter(MyFunc)

   -- The runtime will handle creating the appropriate wrapper

   -- Note: These are natives, so they get the runtime. prefix automatically
   -- No special transpiler handling needed beyond the normal native path
   -- }}}
   ```

7. **Handle ForGroup/ForForce callbacks**
   ```lua
   -- {{{ Enumeration natives
   -- ForGroup(group, function DoForUnit)
   -- ForForce(force, function DoForPlayer)

   -- These pass a function to be called for each element
   -- Transpiles to:
   -- runtime.ForGroup(g, DoForUnit)

   -- The runtime iterates and calls the function
   -- }}}
   ```

8. **Handle ExecuteFunc**
   ```lua
   -- {{{ ExecuteFunc handling
   -- ExecuteFunc takes a STRING parameter that names the function
   -- call ExecuteFunc("MyFunction")

   -- This requires special runtime handling to look up the function
   -- Transpiled code:
   -- runtime.ExecuteFunc("MyFunction")

   -- The runtime must have access to a function registry
   -- This is handled in issue 307 (trigger framework)
   -- }}}
   ```

9. **Create built-in native list (fallback)**
   ```lua
   -- {{{ BUILTIN_NATIVES
   -- If common.j is not available, use a minimal built-in list
   -- This covers the most commonly used natives

   local BUILTIN_NATIVES = {
       -- Player/Unit creation
       "Player", "CreateUnit", "CreateUnitAtLoc",
       "GetTriggerUnit", "GetSpellAbilityUnit",

       -- Triggers
       "CreateTrigger", "TriggerRegisterAnyUnitEventBJ",
       "TriggerAddCondition", "TriggerAddAction",
       "Condition", "Filter",

       -- Groups
       "CreateGroup", "GroupAddUnit", "GroupRemoveUnit",
       "ForGroup", "FirstOfGroup",

       -- Regions/Rects
       "Rect", "GetRectCenterX", "GetRectCenterY",

       -- Math
       "Cos", "Sin", "Atan2", "SquareRoot",
       "GetRandomInt", "GetRandomReal",

       -- Strings
       "I2S", "R2S", "S2I", "S2R", "SubString",

       -- Display
       "DisplayTextToPlayer", "DisplayTimedTextToPlayer",

       -- Effects
       "AddSpecialEffect", "DestroyEffect",

       -- Timers
       "CreateTimer", "TimerStart", "DestroyTimer",
       "GetExpiredTimer",

       -- Handles
       "GetHandleId",
   }

   local function init_builtin_natives()
       local registry = {}
       for _, name in ipairs(BUILTIN_NATIVES) do
           registry[name] = {
               params = {},  -- Unknown params for builtins
               return_type = "unknown",
               is_constant = false,
               is_builtin = true,
           }
       end
       return registry
   end
   -- }}}
   ```

10. **Add transpiler option for common.j loading**
    ```lua
    -- {{{ transpile with options
    function transpiler.transpile(ast, options)
        options = options or {}

        local ctx = create_context({
            native_registry = options.native_registry or init_builtin_natives(),
            use_runtime_prefix = options.use_runtime_prefix,
        })

        -- ... rest of transpile logic from 306a ...
    end
    -- }}}

    -- {{{ Convenience loader
    function transpiler.load_natives(common_j_source)
        return load_common_j_natives(common_j_source)
    end
    -- }}}
    ```

11. **Update module exports**
    ```lua
    -- Add to transpiler module exports
    transpiler.load_natives = load_common_j_natives
    transpiler._init_builtin_natives = init_builtin_natives
    transpiler._BUILTIN_NATIVES = BUILTIN_NATIVES
    transpiler._load_natives_from_ast = load_natives_from_ast
    ```

---

## Technical Notes

### Native vs BJ Functions

| Category | Source | Prefix | Examples |
|----------|--------|--------|----------|
| Native | common.j | `runtime.` | CreateUnit, Player, GetRandomInt |
| BJ (wrapper) | blizzard.j | none | CreateNUnitsAtLoc, GetLastCreatedUnit |
| Map function | war3map.j | none | User-defined functions |

BJ functions are helpers written in JASS that wrap natives. Since they're
regular JASS functions, they get transpiled to Lua along with the map code.
They don't need `runtime.` prefix because they'll exist in the transpiled code.

### common.j Loading

The ideal workflow:
1. Parse common.j to extract native signatures
2. Parse blizzard.j (natives are not BJ, regular functions are BJ)
3. Use collected natives when transpiling war3map.j

For simplicity, we can use a built-in list of common natives as fallback.

### Code Type Parameters

JASS `code` type represents a function reference. The syntax:
```jass
function MyCallback
```

This is an expression that evaluates to the function itself (not a call).
Used in callbacks like Condition(), Filter(), ForGroup(), etc.

### ExecuteFunc Challenges

`ExecuteFunc("FuncName")` calls a function by string name at runtime.
This requires the runtime to maintain a registry of all defined functions.
The transpiler emits `runtime.ExecuteFunc("FuncName")` and the runtime
must look up "FuncName" in a function table.

This is handled in issue 307 (trigger framework) by building a function
export table during transpilation.

---

## Related Documents

- issues/306-create-jass-lua-transpiler.md (parent issue)
- issues/306a-transpiler-infrastructure.md (is_native function)
- issues/306c-transpile-statements.md (CALL statement native detection)
- issues/306d-transpile-expressions.md (CALL_EXPR native detection)
- issues/307-implement-trigger-framework.md (runtime API)
- docs/formats/common-j.md (common.j native reference - to be created)

---

## Acceptance Criteria

- [x] Native registry data structure defined
- [x] `load_natives_from_ast()` extracts natives from parsed common.j
- [x] Built-in native list covers common cases as fallback
- [x] `is_native()` checks both registry and collected declarations
- [x] Native calls are prefixed with `runtime.`
- [x] BJ function calls are NOT prefixed
- [x] Condition() and Filter() are recognized as natives
- [x] ForGroup/ForForce callbacks transpile correctly
- [x] Function references (code type) pass through correctly
- [x] ExecuteFunc calls go through runtime
- [x] `transpiler.load_natives()` public API available
- [x] Transpiler options allow custom native registry
- [x] Unknown natives fall back to built-in list or pass through

---

## Notes

This sub-issue bridges transpilation and runtime. The transpiler's job is
to identify which calls need `runtime.` prefix; the actual implementations
live in the runtime (issues 307-308).

The built-in native list is intentionally minimal. Full common.j parsing
provides complete coverage but requires the parser (305) to handle common.j's
~1500 native declarations efficiently.

For initial development, the built-in list is sufficient. Full common.j
loading can be added as an optimization.

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Added BUILTIN_NATIVES list** (~170 native functions):
   - Player/Unit creation and management
   - Triggers (CreateTrigger, Condition, Filter, etc.)
   - Groups and Forces (ForGroup, ForForce)
   - Regions/Rects, Locations
   - Math functions (Cos, Sin, SquareRoot, GetRandomInt)
   - String functions (I2S, R2S, SubString)
   - Display/UI, Effects, Timers, Sound, Camera
   - Items, Destructables, Fog of war
   - Game state, Handles, ExecuteFunc

2. **Added native registry functions**:
   - `init_builtin_natives()` - creates fallback registry from BUILTIN_NATIVES
   - `load_natives_from_ast()` - extracts natives from parsed AST
   - `load_common_j_natives()` - parses common.j source and extracts natives
   - `merge_native_registries()` - combines multiple registries

3. **Updated create_context()** to accept options:
   - `native_registry` - pre-loaded native registry
   - `use_runtime_prefix` - whether to prefix native calls (default: true)

4. **Updated is_native()** to check multiple sources:
   - Pre-loaded native_registry (from common.j or custom)
   - ctx.natives (from map script native declarations)
   - builtin_natives_set (final fallback)

5. **Updated transpile()** to accept options parameter

6. **Created test suite** `src/tests/test_transpiler_native.lua`:
   - 20 tests covering all native handling scenarios
   - Built-in natives, registry loader, special constructs
   - Native vs BJ distinction, expression context

### Public API

```lua
-- Parse common.j and extract native signatures
local registry, errors = transpiler.load_natives(common_j_source)

-- Transpile with custom native registry
local lua_code, errors = transpiler.transpile(ast, {
    native_registry = registry,
    use_runtime_prefix = true,  -- default
})
```

### Test Results

All 20 tests pass:
- 4 built-in natives tests
- 4 native registry loader tests
- 5 special constructs tests (Condition, Filter, ForGroup, ExecuteFunc)
- 4 native vs BJ tests
- 3 expression context tests

