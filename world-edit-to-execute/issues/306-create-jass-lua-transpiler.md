# Issue 306: Create JASS-to-Lua Transpiler

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 305-build-jass-parser

---

## Current Behavior

Cannot execute JASS code. Even with parsing complete, there is no way
to run the trigger logic in our Lua-based engine.

---

## Intended Behavior

A transpiler that converts JASS AST into equivalent Lua code:
- Variable declarations → Lua locals/globals
- Function definitions → Lua functions
- Control flow → Lua if/while/for
- Native calls → Runtime API calls
- Type system → Runtime type checking (optional)

---

## Suggested Implementation Steps

1. **Create transpiler module**
   ```
   src/jass/
   ├── lexer.lua        (from 304)
   ├── parser.lua       (from 305)
   └── transpiler.lua   (this issue)
   ```

2. **Define transpilation context**
   ```lua
   local function create_context()
       return {
           indent = 0,
           output = {},
           globals = {},      -- Track global variables
           functions = {},    -- Track function signatures
           current_func = nil,
           errors = {},
       }
   end
   ```

3. **Implement AST visitor**
   ```lua
   function transpiler.transpile(ast)
       local ctx = create_context()

       -- First pass: collect declarations
       collect_declarations(ctx, ast)

       -- Second pass: generate code
       for _, decl in ipairs(ast.declarations) do
           transpile_declaration(ctx, decl)
       end

       return table.concat(ctx.output, "\n"), ctx.errors
   end
   ```

4. **Transpile declarations**
   ```lua
   -- JASS globals block → Lua module globals
   local function transpile_globals(ctx, node)
       emit(ctx, "-- Globals")
       for _, var in ipairs(node.variables) do
           if var.is_array then
               emit(ctx, string.format("local %s = {}", var.name))
           elseif var.initial_value then
               emit(ctx, string.format("local %s = %s",
                   var.name, transpile_expr(ctx, var.initial_value)))
           else
               emit(ctx, string.format("local %s = %s",
                   var.name, default_value(var.var_type)))
           end
       end
   end

   -- JASS function → Lua function
   local function transpile_function(ctx, node)
       local params = {}
       for _, p in ipairs(node.params) do
           params[#params + 1] = p.name
       end

       emit(ctx, string.format("local function %s(%s)",
           node.name, table.concat(params, ", ")))
       ctx.indent = ctx.indent + 1

       -- Local variables
       for _, local_var in ipairs(node.locals) do
           transpile_local_decl(ctx, local_var)
       end

       -- Statements
       for _, stmt in ipairs(node.body) do
           transpile_statement(ctx, stmt)
       end

       ctx.indent = ctx.indent - 1
       emit(ctx, "end")
   end
   ```

5. **Transpile statements**
   ```lua
   -- set x = value → x = value
   local function transpile_set(ctx, node)
       if node.index then
           -- Array assignment
           emit(ctx, string.format("%s[%s] = %s",
               node.variable, transpile_expr(ctx, node.index),
               transpile_expr(ctx, node.value)))
       else
           emit(ctx, string.format("%s = %s",
               node.variable, transpile_expr(ctx, node.value)))
       end
   end

   -- call Func(args) → Func(args)
   local function transpile_call(ctx, node)
       local args = {}
       for _, arg in ipairs(node.arguments) do
           args[#args + 1] = transpile_expr(ctx, arg)
       end
       emit(ctx, string.format("%s(%s)",
           node.function_name, table.concat(args, ", ")))
   end

   -- if/then/else/endif → if/then/else/end
   local function transpile_if(ctx, node)
       emit(ctx, string.format("if %s then",
           transpile_expr(ctx, node.condition)))
       ctx.indent = ctx.indent + 1
       for _, stmt in ipairs(node.then_body) do
           transpile_statement(ctx, stmt)
       end
       ctx.indent = ctx.indent - 1

       for _, elseif_clause in ipairs(node.elseifs or {}) do
           emit(ctx, string.format("elseif %s then",
               transpile_expr(ctx, elseif_clause.condition)))
           ctx.indent = ctx.indent + 1
           for _, stmt in ipairs(elseif_clause.body) do
               transpile_statement(ctx, stmt)
           end
           ctx.indent = ctx.indent - 1
       end

       if node.else_body then
           emit(ctx, "else")
           ctx.indent = ctx.indent + 1
           for _, stmt in ipairs(node.else_body) do
               transpile_statement(ctx, stmt)
           end
           ctx.indent = ctx.indent - 1
       end

       emit(ctx, "end")
   end

   -- loop/endloop → while true do/end with break
   local function transpile_loop(ctx, node)
       emit(ctx, "while true do")
       ctx.indent = ctx.indent + 1
       for _, stmt in ipairs(node.body) do
           transpile_statement(ctx, stmt)
       end
       ctx.indent = ctx.indent - 1
       emit(ctx, "end")
   end

   -- exitwhen condition → if condition then break end
   local function transpile_exitwhen(ctx, node)
       emit(ctx, string.format("if %s then break end",
           transpile_expr(ctx, node.condition)))
   end
   ```

6. **Transpile expressions**
   ```lua
   local function transpile_expr(ctx, node)
       if node.type == AST.LITERAL then
           return transpile_literal(node)
       elseif node.type == AST.IDENTIFIER then
           return node.name
       elseif node.type == AST.BINARY_EXPR then
           return string.format("(%s %s %s)",
               transpile_expr(ctx, node.left),
               operator_map[node.operator],
               transpile_expr(ctx, node.right))
       elseif node.type == AST.CALL_EXPR then
           return transpile_call_expr(ctx, node)
       elseif node.type == AST.ARRAY_ACCESS then
           return string.format("%s[%s]",
               node.array, transpile_expr(ctx, node.index))
       elseif node.type == AST.FUNCTION_REF then
           -- function Foo → Foo (first-class function)
           return node.name
       end
   end

   -- Operator mapping
   local operator_map = {
       ["=="] = "==",
       ["!="] = "~=",  -- JASS != → Lua ~=
       ["<"]  = "<",
       ["<="] = "<=",
       [">"]  = ">",
       [">="] = ">=",
       ["+"]  = "+",
       ["-"]  = "-",
       ["*"]  = "*",
       ["/"]  = "/",
       ["and"] = "and",
       ["or"]  = "or",
       ["not"] = "not",
   }
   ```

7. **Handle native functions**
   ```lua
   -- Native calls become runtime API calls
   -- CreateUnit(...) → runtime.CreateUnit(...)

   local function transpile_native_call(ctx, node)
       local args = {}
       for _, arg in ipairs(node.arguments) do
           args[#args + 1] = transpile_expr(ctx, arg)
       end
       return string.format("runtime.%s(%s)",
           node.function_name, table.concat(args, ", "))
   end
   ```

---

## Technical Notes

### Type System Differences

| JASS | Lua | Notes |
|------|-----|-------|
| integer | number | Lua numbers are floats |
| real | number | Direct mapping |
| boolean | boolean | Direct mapping |
| string | string | Direct mapping |
| handle types | userdata/table | Runtime objects |
| array | table | 1-indexed in Lua |
| null | nil | Direct mapping |

### JASS-Specific Constructs

**Function References:**
```jass
call TriggerAddCondition(t, Condition(function MyCondition))
```
Becomes:
```lua
runtime.TriggerAddCondition(t, runtime.Condition(MyCondition))
```

**String Concatenation:**
JASS uses `+` for strings, Lua uses `..`:
```lua
-- Detect string context and use ..
```

**Integer Division:**
JASS integer division truncates, Lua doesn't:
```lua
-- math.floor(a / b) for integer types
```

### Runtime API

The transpiled code depends on a runtime module providing:
- Native function implementations
- Handle management
- Event dispatch
- Timer management

This is covered in issues 307-308.

---

## Related Documents

- docs/jass/transpiler.md (to be created)
- issues/305-build-jass-parser.md (AST input)
- issues/307-implement-trigger-framework.md (runtime)
- issues/308-build-event-dispatch.md (event system)

---

## Acceptance Criteria

- [ ] Transpiles global variable declarations
- [ ] Transpiles function definitions
- [ ] Transpiles all statement types
- [ ] Transpiles expressions with correct operators
- [ ] Handles native function calls
- [ ] Handles function references
- [ ] Handles array operations
- [ ] Produces syntactically valid Lua
- [ ] Output is human-readable (proper indentation)
- [ ] Unit tests for all constructs

---

## Notes

The transpiler bridges the gap between WC3's JASS and our Lua runtime.
Design choices:

1. **Readability over optimization** - Generated code should be debuggable
2. **Runtime dependency** - Native functions call into runtime module
3. **Minimal transformation** - Keep structure close to original
4. **Error preservation** - Include source locations in comments

The transpiled code won't be 100% equivalent without the runtime (307-308),
but it should be syntactically valid and structurally correct.

Reference: [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/)
Reference: [JASS Language Specification](http://jass.sourceforge.net/doc/)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:13*

Looking at this issue, I can see it's a substantial piece of work covering the entire transpiler. Let me analyze whether splitting would be beneficial.

## Analysis

This issue covers several distinct concerns:
1. Core transpiler infrastructure (context, visitor pattern, output emission)
2. Declaration transpilation (globals, functions)
3. Statement transpilation (set, call, if, loop, exitwhen, return)
4. Expression transpilation (literals, identifiers, binary ops, calls, arrays, function refs)
5. Special handling (native functions, type differences, operator mapping)
6. Testing

The issue is **large enough to benefit from splitting**. Each category represents a logical unit that can be implemented and tested independently, and the acceptance criteria naturally group into these categories.

---

## Suggested Sub-Issues

### 306a-transpiler-infrastructure
**Description:** Create the core transpiler module with context management, output emission, and AST visitor skeleton.

**Covers:**
- `create_context()` function
- `emit()` helper with indentation
- Main `transpile()` entry point
- Two-pass structure (collect declarations, then generate)
- Error accumulation

**Dependencies:** None (first sub-issue)

---

### 306b-transpile-declarations
**Description:** Implement transpilation of JASS declarations - global variables and function definitions.

**Covers:**
- `transpile_globals()` - globals block → Lua locals
- `transpile_function()` - function definitions with params
- `transpile_local_decl()` - local variable declarations
- Default value handling by type
- Array initialization as empty tables

**Dependencies:** 306a

---

### 306c-transpile-statements
**Description:** Implement transpilation of all JASS statement types to Lua equivalents.

**Covers:**
- `transpile_set()` - variable and array assignment
- `transpile_call()` - call statements
- `transpile_if()` - if/elseif/else/endif → Lua if/elseif/else/end
- `transpile_loop()` - loop/endloop → while true do/end
- `transpile_exitwhen()` - exitwhen → if...break
- `transpile_return()` - return statements

**Dependencies:** 306a, 306d (needs expression transpilation)

---

### 306d-transpile-expressions
**Description:** Implement transpilation of JASS expressions with operator mapping.

**Covers:**
- Literal transpilation (integers, reals, booleans, strings, null)
- Identifier references
- Binary expressions with operator mapping (`!=` → `~=`)
- Call expressions
- Array access expressions
- Function references (`function Foo` → `Foo`)
- String concatenation (`+` → `..` in string context)
- Integer division handling

**Dependencies:** 306a

---

### 306e-native-function-handling
**Description:** Implement special handling for native function calls that bridge to the runtime API.

**Covers:**
- Detecting native vs user-defined functions
- Prefixing native calls with `runtime.`
- Handling special constructs like `Condition(function X)`
- Building the native function registry from common.j/blizzard.j signatures

**Dependencies:** 306a, 306d

---

### 306f-transpiler-tests
**Description:** Create comprehensive test suite for the transpiler.

**Covers:**
- Unit tests for each construct type
- Integration tests transpiling complete JASS snippets
- Validation that output is syntactically valid Lua (loadstring check)
- Test fixtures from real war3map.j samples
- Error case testing

**Dependencies:** 306a-306e (all implementation complete)

---

## Dependency Graph

```
306a (infrastructure)
  ├── 306b (declarations)
  ├── 306d (expressions)
  │     ├── 306c (statements) ← also depends on 306a
  │     └── 306e (natives)
  └────────────────────────────────────────┐
                                           ↓
                                    306f (tests)
```

---

## Recommendation

**Split into 6 sub-issues.** The natural separation allows:
- 306a and 306d can be worked on first (no cross-dependencies)
- 306b only needs the infrastructure
- 306c needs both infrastructure and expressions
- 306e is a refinement layer on top of expressions
- 306f validates everything works together

This structure allows iterative development where each piece can be tested in isolation before integration.
