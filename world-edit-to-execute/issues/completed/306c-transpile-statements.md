# Issue 306c: Transpile Statements

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 306a-transpiler-infrastructure, 306d-transpile-expressions
**Parent Issue:** 306-create-jass-lua-transpiler

---

## Current Behavior

The transpiler infrastructure (306a) has a stub for `transpile_statement()`
that emits only a placeholder comment. Function bodies (306b) call this stub
but get no actual statement output.

---

## Intended Behavior

Transpile all JASS statement types into equivalent Lua constructs:

**SET Statement:**
```jass
set x = 5
set arr[i] = value
```
Becomes:
```lua
x = 5
arr[i] = value
```

**CALL Statement:**
```jass
call DoSomething()
call CreateUnit(player, id, x, y, facing)
```
Becomes:
```lua
DoSomething()
runtime.CreateUnit(player, id, x, y, facing)
```

**IF Statement:**
```jass
if a > 0 then
    set a = 0
elseif a < 0 then
    set a = 1
else
    set a = 2
endif
```
Becomes:
```lua
if a > 0 then
    a = 0
elseif a < 0 then
    a = 1
else
    a = 2
end
```

**LOOP Statement:**
```jass
loop
    set i = i + 1
    exitwhen i >= 10
endloop
```
Becomes:
```lua
while true do
    i = i + 1
    if i >= 10 then break end
end
```

**RETURN Statement:**
```jass
return sum
return
```
Becomes:
```lua
return sum
return
```

---

## Suggested Implementation Steps

1. **Implement statement dispatcher**
   ```lua
   -- {{{ transpile_statement
   local function transpile_statement(ctx, node)
       if not node then
           add_error(ctx, "Nil statement node")
           return
       end

       if node.type == "SET_STMT" then
           transpile_set(ctx, node)

       elseif node.type == "CALL_STMT" then
           transpile_call(ctx, node)

       elseif node.type == "IF_STMT" then
           transpile_if(ctx, node)

       elseif node.type == "LOOP_STMT" then
           transpile_loop(ctx, node)

       elseif node.type == "EXITWHEN_STMT" then
           transpile_exitwhen(ctx, node)

       elseif node.type == "RETURN_STMT" then
           transpile_return(ctx, node)

       elseif node.type == "DEBUG_STMT" then
           -- Debug statements - optional handling
           transpile_debug(ctx, node)

       else
           add_error(ctx, "Unknown statement type: " .. tostring(node.type), node)
       end
   end
   -- }}}
   ```

2. **Implement SET statement**
   ```lua
   -- {{{ transpile_set
   local function transpile_set(ctx, node)
       local target = node.target  -- Variable name

       if node.index then
           -- Array assignment: set arr[i] = value
           local index_expr = transpile_expr(ctx, node.index)
           local value_expr = transpile_expr(ctx, node.value)
           emit(ctx, string.format("%s[%s] = %s", target, index_expr, value_expr))
       else
           -- Simple assignment: set x = value
           local value_expr = transpile_expr(ctx, node.value)
           emit(ctx, string.format("%s = %s", target, value_expr))
       end
   end
   -- }}}
   ```

3. **Implement CALL statement**
   ```lua
   -- {{{ transpile_call
   local function transpile_call(ctx, node)
       local func_name = node.function_name
       local args = {}

       -- Transpile each argument
       for _, arg in ipairs(node.arguments or {}) do
           args[#args + 1] = transpile_expr(ctx, arg)
       end

       local args_str = table.concat(args, ", ")

       -- Check if this is a native function call
       if is_native(ctx, func_name) then
           -- Native calls go through runtime
           emit(ctx, string.format("runtime.%s(%s)", func_name, args_str))
       else
           -- User-defined function call
           emit(ctx, string.format("%s(%s)", func_name, args_str))
       end
   end
   -- }}}
   ```

4. **Implement IF statement**
   ```lua
   -- {{{ transpile_if
   local function transpile_if(ctx, node)
       -- Main condition
       local cond_expr = transpile_expr(ctx, node.condition)
       emit(ctx, string.format("if %s then", cond_expr))

       -- Then branch
       ctx.indent = ctx.indent + 1
       for _, stmt in ipairs(node.then_branch or {}) do
           transpile_statement(ctx, stmt)
       end
       ctx.indent = ctx.indent - 1

       -- Elseif branches
       for _, elseif_clause in ipairs(node.elseif_branches or {}) do
           local elseif_cond = transpile_expr(ctx, elseif_clause.condition)
           emit(ctx, string.format("elseif %s then", elseif_cond))

           ctx.indent = ctx.indent + 1
           for _, stmt in ipairs(elseif_clause.body or {}) do
               transpile_statement(ctx, stmt)
           end
           ctx.indent = ctx.indent - 1
       end

       -- Else branch
       if node.else_branch and #node.else_branch > 0 then
           emit(ctx, "else")

           ctx.indent = ctx.indent + 1
           for _, stmt in ipairs(node.else_branch) do
               transpile_statement(ctx, stmt)
           end
           ctx.indent = ctx.indent - 1
       end

       emit(ctx, "end")
   end
   -- }}}
   ```

5. **Implement LOOP statement**
   ```lua
   -- {{{ transpile_loop
   local function transpile_loop(ctx, node)
       -- JASS loop becomes Lua while true do
       emit(ctx, "while true do")

       -- Track that we're in a loop (for exitwhen validation)
       local was_in_loop = ctx.in_loop
       ctx.in_loop = true

       ctx.indent = ctx.indent + 1
       for _, stmt in ipairs(node.body or {}) do
           transpile_statement(ctx, stmt)
       end
       ctx.indent = ctx.indent - 1

       -- Restore loop context
       ctx.in_loop = was_in_loop

       emit(ctx, "end")
   end
   -- }}}
   ```

6. **Implement EXITWHEN statement**
   ```lua
   -- {{{ transpile_exitwhen
   local function transpile_exitwhen(ctx, node)
       -- Validate we're inside a loop
       if not ctx.in_loop then
           add_error(ctx, "exitwhen outside of loop", node)
       end

       -- exitwhen condition → if condition then break end
       local cond_expr = transpile_expr(ctx, node.condition)
       emit(ctx, string.format("if %s then break end", cond_expr))
   end
   -- }}}
   ```

7. **Implement RETURN statement**
   ```lua
   -- {{{ transpile_return
   local function transpile_return(ctx, node)
       if node.value then
           -- Return with value
           local value_expr = transpile_expr(ctx, node.value)
           emit(ctx, string.format("return %s", value_expr))
       else
           -- Return without value (from "returns nothing" function)
           emit(ctx, "return")
       end
   end
   -- }}}
   ```

8. **Implement DEBUG statement (optional)**
   ```lua
   -- {{{ transpile_debug
   local function transpile_debug(ctx, node)
       -- JASS debug keyword: debug set x = 5, debug call Foo()
       -- Debug statements only execute in debug mode

       -- Option 1: Always emit (for development)
       -- Option 2: Wrap in debug check
       -- Option 3: Skip entirely

       -- We'll emit with a comment marker
       emit_comment(ctx, "debug: " .. node.inner_type)

       -- Transpile the inner statement
       if node.inner then
           transpile_statement(ctx, node.inner)
       end
   end
   -- }}}
   ```

9. **Handle edge cases**

   **Empty IF branches:**
   ```lua
   -- JASS allows empty then branches
   -- if false then
   -- endif

   -- Lua also allows empty branches, so this works naturally
   ```

   **Nested loops with exitwhen:**
   ```lua
   -- exitwhen only exits the innermost loop
   -- This is the same behavior as Lua's break
   -- The ctx.in_loop flag is properly saved/restored for nesting
   ```

   **Multiple exitwhen in one loop:**
   ```lua
   -- JASS allows multiple exitwhen statements
   -- Each becomes a separate if...break in Lua
   loop
       exitwhen a
       exitwhen b
   endloop

   -- Becomes:
   while true do
       if a then break end
       if b then break end
   end
   ```

10. **Update module exports**
    ```lua
    -- Add to transpiler module exports
    transpiler._transpile_statement = transpile_statement
    transpiler._transpile_set = transpile_set
    transpiler._transpile_call = transpile_call
    transpiler._transpile_if = transpile_if
    transpiler._transpile_loop = transpile_loop
    transpiler._transpile_exitwhen = transpile_exitwhen
    transpiler._transpile_return = transpile_return
    ```

---

## Technical Notes

### Statement Mapping

| JASS Statement | Lua Equivalent | Notes |
|----------------|----------------|-------|
| `set x = v` | `x = v` | Remove `set` keyword |
| `set arr[i] = v` | `arr[i] = v` | Direct mapping |
| `call Func()` | `Func()` or `runtime.Func()` | Remove `call`, add runtime prefix for natives |
| `if...then...endif` | `if...then...end` | Change `endif` to `end` |
| `elseif` | `elseif` | Direct mapping |
| `else` | `else` | Direct mapping |
| `loop...endloop` | `while true do...end` | Infinite loop pattern |
| `exitwhen cond` | `if cond then break end` | Convert to conditional break |
| `return expr` | `return expr` | Direct mapping |
| `return` | `return` | Direct mapping |

### Loop Translation

JASS `loop/endloop` is an infinite loop with explicit `exitwhen` conditions.
The idiomatic Lua translation is `while true do...end` with `break`.

This preserves semantics exactly:
- Loop runs until broken
- `exitwhen` at any point can break
- Multiple exit conditions are supported

### Native Function Detection

The `is_native()` function (from 306a context) determines if a function
is a native that should be prefixed with `runtime.`. This enables the
transpiled code to call into the runtime API.

User-defined functions (those in `ctx.functions`) are called directly
without prefix.

---

## Related Documents

- issues/306-create-jass-lua-transpiler.md (parent issue)
- issues/306a-transpiler-infrastructure.md (provides emit, is_native, context)
- issues/306b-transpile-declarations.md (function bodies call transpile_statement)
- issues/306d-transpile-expressions.md (transpile_expr for conditions/values)
- issues/306e-native-function-handling.md (native function prefix logic)
- src/jass/parser.lua (statement node structures)

---

## Acceptance Criteria

- [x] `transpile_statement()` dispatches to correct handler for each type
- [x] SET statement transpiles variable assignment correctly
- [x] SET statement transpiles array element assignment correctly
- [x] CALL statement transpiles user function calls correctly
- [x] CALL statement prefixes native functions with `runtime.`
- [x] IF statement transpiles condition and then branch
- [x] IF statement handles elseif branches correctly
- [x] IF statement handles else branch correctly
- [x] LOOP statement produces `while true do...end`
- [x] EXITWHEN statement produces `if...then break end`
- [x] EXITWHEN validation warns if used outside loop
- [x] RETURN statement with value transpiles correctly
- [x] RETURN statement without value transpiles correctly
- [x] Nested loops handle exitwhen correctly (innermost only)
- [x] Empty statement bodies produce valid Lua
- [x] Unknown statement types generate error (not crash)

---

## Notes

This sub-issue requires `transpile_expr()` from 306d for:
- SET statement value expressions
- CALL statement argument expressions
- IF/ELSEIF condition expressions
- EXITWHEN condition expressions
- RETURN value expressions

If 306d is not complete, temporary stubs returning placeholder strings
can be used for testing the statement structure.

The DEBUG statement handling is optional and can be implemented in
various ways depending on desired behavior (always emit, conditionally
emit, or skip).

---

## Implementation Notes

**Completed:** 2025-12-27

### Changes Made

1. **Replaced stub with full implementation** in `src/jass/transpiler.lua`:
   - `transpile_statement()` - main dispatcher (lines 531-568)
   - `transpile_set()` - SET statement handling (lines 382-400)
   - `transpile_call()` - CALL statement with native prefix (lines 402-426)
   - `transpile_if()` - IF/ELSEIF/ELSE branches (lines 429-469)
   - `transpile_loop()` - LOOP→while true do (lines 472-496)
   - `transpile_exitwhen()` - EXITWHEN→if break (lines 499-512)
   - `transpile_return()` - RETURN with/without value (lines 515-528)

2. **Created test suite** `src/tests/test_transpiler_stmt.lua`:
   - 27 tests covering all statement types
   - SET: simple, expressions, arrays
   - CALL: user functions, native prefixing
   - IF: simple, else, elseif, nested
   - LOOP: simple, exitwhen, multiple exits, nested
   - RETURN: with value, without value
   - Complex: locals+statements, nested structures

3. **Updated module exports** with all statement functions:
   - `_transpile_set`, `_transpile_call`, `_transpile_if`
   - `_transpile_loop`, `_transpile_exitwhen`, `_transpile_return`

### Technical Details

- **AST field names match parser**: `node.name` (not `target`), `node.arguments` (not `args`)
- **Loop context tracking**: `ctx.in_loop` and `ctx.loop_depth` for exitwhen validation
- **Debug statements**: Emit comment marker, then transpile inner statement
- **Indentation**: Uses context's indent level, consistent 4-space indentation

### Test Results

All 27 tests pass:
- 4 SET statement tests
- 4 CALL statement tests
- 5 IF statement tests
- 4 LOOP statement tests
- 4 RETURN statement tests
- 4 complex statement tests
- 2 error handling tests

