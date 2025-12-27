# Issue 306b: Transpile Declarations

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 306a-transpiler-infrastructure
**Parent Issue:** 306-create-jass-lua-transpiler

---

## Current Behavior

The transpiler infrastructure (306a) exists with stubs for declaration
transpilation. `transpile_globals()` and `transpile_function()` only emit
placeholder comments.

---

## Intended Behavior

Transpile JASS declarations into equivalent Lua code:

**Global Variables:**
```jass
globals
    integer foo
    real bar = 3.14
    constant integer MAX = 100
    string array names
endglobals
```
Becomes:
```lua
-- Globals
local foo = 0
local bar = 3.14
local MAX = 100  -- constant
local names = {}
```

**Function Definitions:**
```jass
function AddIntegers takes integer a, integer b returns integer
    local integer sum
    set sum = a + b
    return sum
endfunction
```
Becomes:
```lua
local function AddIntegers(a, b)
    local sum = 0
    sum = a + b
    return sum
end
```

---

## Suggested Implementation Steps

1. **Define default values for JASS types**
   ```lua
   -- {{{ default_value
   local function default_value(var_type)
       -- Return Lua default value for JASS type
       local defaults = {
           integer = "0",
           real = "0.0",
           boolean = "false",
           string = '""',
           code = "nil",
           nothing = "nil",
       }

       -- Handle types are nil (null) by default
       if defaults[var_type] then
           return defaults[var_type]
       else
           -- Unknown type or handle type
           return "nil"
       end
   end
   -- }}}
   ```

2. **Implement globals block transpilation**
   ```lua
   -- {{{ transpile_globals
   local function transpile_globals(ctx, node)
       emit_comment(ctx, "Globals")

       for _, var in ipairs(node.variables) do
           local decl

           if var.is_array then
               -- Arrays become empty tables
               decl = string.format("local %s = {}", var.name)

           elseif var.initializer then
               -- Variable with initializer
               local init_value = transpile_expr(ctx, var.initializer)
               decl = string.format("local %s = %s", var.name, init_value)

           else
               -- Variable without initializer - use type default
               local def = default_value(var.var_type)
               decl = string.format("local %s = %s", var.name, def)
           end

           -- Add constant comment if applicable
           if var.is_constant then
               decl = decl .. "  -- constant"
           end

           emit(ctx, decl)
       end
   end
   -- }}}
   ```

3. **Implement function signature transpilation**
   ```lua
   -- {{{ transpile_function_signature
   local function transpile_function_signature(ctx, node)
       -- Build parameter list
       local params = {}
       for _, p in ipairs(node.params) do
           params[#params + 1] = p.name
       end

       local param_str = table.concat(params, ", ")

       -- Emit function definition line
       emit(ctx, string.format("local function %s(%s)", node.name, param_str))
   end
   -- }}}
   ```

4. **Implement local variable transpilation**
   ```lua
   -- {{{ transpile_local_decl
   local function transpile_local_decl(ctx, node)
       local decl

       if node.is_array then
           -- Local arrays become empty tables
           decl = string.format("local %s = {}", node.name)

       elseif node.initializer then
           -- Local with initializer
           local init_value = transpile_expr(ctx, node.initializer)
           decl = string.format("local %s = %s", node.name, init_value)

       else
           -- Local without initializer - use type default
           local def = default_value(node.var_type)
           decl = string.format("local %s = %s", node.name, def)
       end

       emit(ctx, decl)
   end
   -- }}}
   ```

5. **Implement full function transpilation**
   ```lua
   -- {{{ transpile_function
   local function transpile_function(ctx, node)
       -- Track current function for context
       ctx.current_func = node.name

       -- Emit signature
       transpile_function_signature(ctx, node)
       ctx.indent = ctx.indent + 1

       -- Emit local declarations first (JASS requires locals before statements)
       if node.locals and #node.locals > 0 then
           for _, local_var in ipairs(node.locals) do
               transpile_local_decl(ctx, local_var)
           end
           emit_blank(ctx)
       end

       -- Emit function body statements
       for _, stmt in ipairs(node.body) do
           transpile_statement(ctx, stmt)
       end

       -- Close function
       ctx.indent = ctx.indent - 1
       emit(ctx, "end")

       -- Clear current function context
       ctx.current_func = nil
   end
   -- }}}
   ```

6. **Handle special cases**

   **Empty Functions:**
   ```lua
   -- JASS allows empty functions
   -- function DoNothing takes nothing returns nothing
   -- endfunction

   -- For Lua, we still need a valid function body
   -- If no statements, we emit nothing (Lua allows empty functions)
   ```

   **Forward References:**
   ```lua
   -- JASS allows calling functions defined later in the file
   -- The two-pass architecture in 306a handles this by collecting
   -- all function signatures first

   -- For Lua, we use `local function` which gets hoisted in the local scope
   -- As long as all functions are defined before any are called at runtime,
   -- forward references work correctly
   ```

   **Constant Globals:**
   ```lua
   -- JASS has `constant` keyword for immutable globals
   -- Lua doesn't have const, so we just add a comment
   -- Could optionally wrap in a table with __newindex metatable, but
   -- that adds overhead for minimal benefit
   ```

7. **Handle takes nothing / returns nothing**
   ```lua
   -- {{{ transpile_function_signature (updated)
   local function transpile_function_signature(ctx, node)
       local params = {}

       -- "takes nothing" means empty parameter list
       if node.params then
           for _, p in ipairs(node.params) do
               -- Skip if type is "nothing" (shouldn't happen, but defensive)
               if p.param_type ~= "nothing" then
                   params[#params + 1] = p.name
               end
           end
       end

       local param_str = table.concat(params, ", ")
       emit(ctx, string.format("local function %s(%s)", node.name, param_str))

       -- Add return type comment if meaningful
       if node.return_type and node.return_type ~= "nothing" then
           -- Could emit as comment: -- returns node.return_type
       end
   end
   -- }}}
   ```

8. **Update module exports**
   ```lua
   -- Add to transpiler module exports (from 306a)
   transpiler._transpile_globals = transpile_globals
   transpiler._transpile_function = transpile_function
   transpiler._transpile_local_decl = transpile_local_decl
   transpiler._default_value = default_value
   ```

---

## Technical Notes

### JASS vs Lua Scoping

| JASS Concept | Lua Equivalent | Notes |
|--------------|----------------|-------|
| `globals` block | `local` at module level | Not truly global in Lua |
| function params | function params | Direct mapping |
| `local` in function | `local` in function | Direct mapping |
| forward references | Works with `local function` | Must define before runtime call |

### Variable Initialization

JASS requires all locals to be declared before any statements. This makes
transpilation straightforward - we emit all locals first, then all statements.

JASS variables without explicit initializers still have defined default values:
- `integer` → 0
- `real` → 0.0
- `boolean` → false
- `string` → "" (empty string)
- handle types → null (nil in Lua)

### Array Handling

JASS arrays are 1-indexed in our implementation (matching Lua convention).
Empty arrays are initialized as `{}`. JASS uses syntax `arr[index]` which
maps directly to Lua's table indexing.

Note: JASS arrays have a maximum size limit (8191 or 8192 depending on
context), but we don't enforce this in transpilation.

---

## Related Documents

- issues/306-create-jass-lua-transpiler.md (parent issue)
- issues/306a-transpiler-infrastructure.md (provides context, emit functions)
- issues/306c-transpile-statements.md (uses transpile_statement)
- issues/306d-transpile-expressions.md (uses transpile_expr for initializers)
- src/jass/parser.lua (GLOBAL_BLOCK, FUNCTION_DEF, VAR_DECL node structures)

---

## Acceptance Criteria

- [x] `default_value()` returns correct defaults for all JASS types
- [x] `transpile_globals()` emits Lua locals for all global variables
- [x] Global arrays are initialized as empty tables `{}`
- [x] Global initializers are correctly transpiled
- [x] Constant globals have comment annotation
- [x] `transpile_function()` emits correct function signature
- [x] Functions with "takes nothing" have empty parameter list
- [x] Local variables are emitted before statements
- [x] Local arrays are initialized as empty tables
- [x] Local initializers are correctly transpiled
- [x] Empty functions produce valid Lua
- [x] Function body statements are correctly indented
- [x] `end` keyword properly closes function
- [x] Multiple functions can be transpiled sequentially

---

## Notes

This sub-issue depends on `transpile_expr()` from 306d for handling
initializers. During development, if 306d is not yet complete, initializers
can temporarily output placeholder values.

The generated code uses `local function` rather than global functions.
This keeps the transpiled module self-contained and avoids polluting the
global namespace. If global exposure is needed, a separate export mechanism
can be added.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

- `src/jass/transpiler.lua` - Added declaration transpilation functions
- `src/tests/test_transpiler_infra.lua` - Updated test expectations
- `src/tests/test_transpiler_decl.lua` - New test suite (43 tests)

### Implementation Details

1. **default_value(var_type)** - Returns Lua default values:
   - `integer` → `"0"`
   - `real` → `"0.0"`
   - `boolean` → `"false"`
   - `string` → `'""'`
   - `code` → `"nil"`
   - Handle types (unit, player, etc.) → `"nil"`

2. **transpile_globals(ctx, node)** - Converts global variables:
   - Emits "-- Globals" comment header
   - Arrays → `local name = {}`
   - With initializer → `local name = <transpiled_expr>`
   - Without initializer → `local name = <default_value>`
   - Constants get `-- constant` annotation

3. **transpile_local_decl(ctx, node)** - Converts local declarations:
   - Same logic as globals (arrays, initializers, defaults)
   - Registers local name in ctx.current_locals for scoping

4. **transpile_function(ctx, node)** - Converts function definitions:
   - Sets ctx.current_func for context
   - Builds parameter list (skips 'nothing' type)
   - Emits `local function name(params)`
   - Emits local declarations first (JASS requirement)
   - Blank line between locals and statements
   - Emits body statements
   - Emits `end` to close function

### Generated Code Format

```lua
-- Globals
local foo = 0
local bar = 3.14
local MAX = 100  -- constant
local names = {}

local function AddIntegers(a, b)
    local sum = 0

    -- statement: SET_STMT (stub)
    -- statement: RETURN_STMT (stub)
end
```

### Test Coverage (43 tests)

- default_value for all primitive types and handle types
- Global variables: without initializer, with initializer, arrays, constants
- Function transpilation: empty, with params, with locals, with body
- Integration: globals and functions together, complete program structure

