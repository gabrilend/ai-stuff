# Issue 306a: Transpiler Infrastructure

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 305-build-jass-parser
**Parent Issue:** 306-create-jass-lua-transpiler

---

## Current Behavior

No transpiler module exists. The JASS parser (305) produces an AST but there is
no mechanism to convert it to executable Lua code.

---

## Intended Behavior

A transpiler module with core infrastructure for converting JASS AST to Lua:
- Transpilation context for tracking state during code generation
- Output emission with proper indentation management
- Main entry point that orchestrates the transpilation process
- Two-pass architecture: collect declarations first, then generate code
- Error accumulation for reporting multiple issues

```lua
local transpiler = require("jass.transpiler")
local parser = require("jass.parser")
local lexer = require("jass.lexer")

local tokens = lexer.tokenize(jass_source)
local ast, parse_errors = parser.parse(tokens)
local lua_code, transpile_errors = transpiler.transpile(ast)

-- lua_code is now syntactically valid Lua
-- transpile_errors contains any issues encountered
```

---

## Suggested Implementation Steps

1. **Create transpiler module file**
   ```
   src/jass/
   ├── lexer.lua        (from 304)
   ├── parser.lua       (from 305)
   └── transpiler.lua   (this issue)
   ```

2. **Define the transpilation context structure**
   ```lua
   -- {{{ create_context
   local function create_context()
       return {
           -- Output management
           indent = 0,           -- Current indentation level
           output = {},          -- Array of output lines

           -- Declaration tracking (populated in first pass)
           globals = {},         -- Global variable declarations {name -> type}
           functions = {},       -- Function signatures {name -> {params, return_type}}
           natives = {},         -- Native function declarations {name -> {params, return_type}}
           types = {},           -- Type definitions {name -> extends}

           -- Current state
           current_func = nil,   -- Name of function being transpiled (for locals)
           in_loop = false,      -- Whether we're inside a loop (for exitwhen)

           -- Error accumulation
           errors = {},          -- Array of error messages
       }
   end
   -- }}}
   ```

3. **Implement output emission helper**
   ```lua
   -- {{{ emit
   local function emit(ctx, line)
       -- Generate proper indentation
       local indent_str = string.rep("    ", ctx.indent)
       ctx.output[#ctx.output + 1] = indent_str .. line
   end
   -- }}}

   -- {{{ emit_blank
   local function emit_blank(ctx)
       ctx.output[#ctx.output + 1] = ""
   end
   -- }}}

   -- {{{ emit_comment
   local function emit_comment(ctx, text)
       emit(ctx, "-- " .. text)
   end
   -- }}}
   ```

4. **Implement error reporting**
   ```lua
   -- {{{ add_error
   local function add_error(ctx, message, node)
       local err = {
           message = message,
           line = node and node.line,
           column = node and node.column,
       }
       ctx.errors[#ctx.errors + 1] = err
   end
   -- }}}

   -- {{{ format_error
   local function format_error(err)
       if err.line then
           return string.format("Line %d, Col %d: %s",
               err.line, err.column or 0, err.message)
       else
           return err.message
       end
   end
   -- }}}
   ```

5. **Implement first pass: declaration collection**
   ```lua
   -- {{{ collect_declarations
   local function collect_declarations(ctx, ast)
       -- First pass: scan all declarations to build symbol tables
       -- This allows forward references to work correctly

       for _, decl in ipairs(ast.declarations) do
           if decl.type == "TYPE_DEF" then
               ctx.types[decl.name] = decl.extends

           elseif decl.type == "GLOBAL_BLOCK" then
               for _, var in ipairs(decl.variables) do
                   ctx.globals[var.name] = {
                       var_type = var.var_type,
                       is_array = var.is_array,
                       is_constant = var.is_constant,
                   }
               end

           elseif decl.type == "NATIVE_DECL" then
               ctx.natives[decl.name] = {
                   params = decl.params,
                   return_type = decl.return_type,
                   is_constant = decl.is_constant,
               }

           elseif decl.type == "FUNCTION_DEF" then
               ctx.functions[decl.name] = {
                   params = decl.params,
                   return_type = decl.return_type,
               }
           end
       end
   end
   -- }}}
   ```

6. **Implement main transpile entry point**
   ```lua
   -- {{{ transpile
   function transpiler.transpile(ast)
       local ctx = create_context()

       -- Validate input
       if not ast or ast.type ~= "PROGRAM" then
           add_error(ctx, "Invalid AST: expected PROGRAM node")
           return nil, ctx.errors
       end

       -- First pass: collect all declarations
       collect_declarations(ctx, ast)

       -- Emit header comment
       emit_comment(ctx, "Generated by JASS-to-Lua transpiler")
       emit_comment(ctx, "Source: war3map.j")
       emit_blank(ctx)

       -- Second pass: generate code for each declaration
       for _, decl in ipairs(ast.declarations) do
           transpile_declaration(ctx, decl)
           emit_blank(ctx)
       end

       -- Join output lines
       local output = table.concat(ctx.output, "\n")

       return output, ctx.errors
   end
   -- }}}
   ```

7. **Implement declaration dispatcher (stub)**
   ```lua
   -- {{{ transpile_declaration
   local function transpile_declaration(ctx, decl)
       -- Dispatcher for declaration types
       -- Actual implementations are in 306b

       if decl.type == "TYPE_DEF" then
           -- Type definitions don't generate code (Lua is dynamically typed)
           emit_comment(ctx, string.format("type %s extends %s",
               decl.name, decl.extends))

       elseif decl.type == "GLOBAL_BLOCK" then
           transpile_globals(ctx, decl)

       elseif decl.type == "NATIVE_DECL" then
           -- Native declarations don't generate code (provided by runtime)
           emit_comment(ctx, string.format("native %s (%s) -> %s",
               decl.name,
               format_params(decl.params),
               decl.return_type))

       elseif decl.type == "FUNCTION_DEF" then
           transpile_function(ctx, decl)

       else
           add_error(ctx, "Unknown declaration type: " .. tostring(decl.type), decl)
       end
   end
   -- }}}
   ```

8. **Implement helper utilities**
   ```lua
   -- {{{ format_params
   local function format_params(params)
       if not params or #params == 0 then
           return "nothing"
       end
       local parts = {}
       for _, p in ipairs(params) do
           parts[#parts + 1] = p.param_type .. " " .. p.name
       end
       return table.concat(parts, ", ")
   end
   -- }}}

   -- {{{ is_native
   local function is_native(ctx, name)
       return ctx.natives[name] ~= nil
   end
   -- }}}

   -- {{{ is_global
   local function is_global(ctx, name)
       return ctx.globals[name] ~= nil
   end
   -- }}}
   ```

9. **Create stub functions for later sub-issues**
   ```lua
   -- Stubs to be implemented in 306b-306e
   -- These allow the infrastructure to be tested before full implementation

   -- {{{ transpile_globals (stub)
   local function transpile_globals(ctx, node)
       emit_comment(ctx, "globals block - see 306b")
       -- Actual implementation in 306b
   end
   -- }}}

   -- {{{ transpile_function (stub)
   local function transpile_function(ctx, node)
       emit_comment(ctx, "function " .. node.name .. " - see 306b")
       -- Actual implementation in 306b
   end
   -- }}}

   -- {{{ transpile_statement (stub)
   local function transpile_statement(ctx, node)
       emit_comment(ctx, "statement - see 306c")
       -- Actual implementation in 306c
   end
   -- }}}

   -- {{{ transpile_expr (stub)
   local function transpile_expr(ctx, node)
       -- Actual implementation in 306d
       return "nil --[[expr]]"
   end
   -- }}}
   ```

10. **Export module interface**
    ```lua
    -- {{{ Module exports
    local transpiler = {}

    -- Main entry point
    transpiler.transpile = transpile

    -- Expose internals for sub-issues to extend
    transpiler._create_context = create_context
    transpiler._emit = emit
    transpiler._emit_blank = emit_blank
    transpiler._emit_comment = emit_comment
    transpiler._add_error = add_error
    transpiler._is_native = is_native
    transpiler._is_global = is_global
    transpiler._collect_declarations = collect_declarations

    return transpiler
    -- }}}
    ```

---

## Technical Notes

### Two-Pass Architecture

The transpiler uses two passes over the AST:

1. **Collection Pass** - Scans all declarations to build symbol tables:
   - `ctx.types` - Type definitions (for documentation only)
   - `ctx.globals` - Global variables (determines scoping)
   - `ctx.natives` - Native functions (for runtime dispatch)
   - `ctx.functions` - User functions (for forward reference support)

2. **Generation Pass** - Produces Lua code for each declaration:
   - Type definitions → comments only (Lua is dynamically typed)
   - Native declarations → comments only (provided by runtime)
   - Global blocks → Lua local variables
   - Functions → Lua function definitions

### Indentation Management

The `ctx.indent` counter tracks nesting depth. The `emit()` function prepends
`ctx.indent * 4` spaces to each line. This produces readable, debuggable output.

### Error Accumulation

Rather than throwing on first error, the transpiler accumulates errors in
`ctx.errors`. This allows reporting multiple issues in a single pass, similar
to how compilers report multiple warnings/errors.

### Stub Pattern

This sub-issue creates stubs for functions implemented in later sub-issues.
This allows:
- Testing the infrastructure in isolation
- Incremental development and testing
- Clear module boundaries

---

## Related Documents

- issues/306-create-jass-lua-transpiler.md (parent issue)
- issues/306b-transpile-declarations.md (implements transpile_globals, transpile_function)
- issues/306c-transpile-statements.md (implements transpile_statement)
- issues/306d-transpile-expressions.md (implements transpile_expr)
- issues/305-build-jass-parser.md (provides AST input)
- src/jass/parser.lua (AST node types reference)

---

## Acceptance Criteria

- [x] Created src/jass/transpiler.lua module file
- [x] `create_context()` returns proper context structure
- [x] `emit()` produces correctly indented output
- [x] `emit_comment()` and `emit_blank()` work correctly
- [x] `add_error()` accumulates errors with location info
- [x] `collect_declarations()` populates globals, functions, natives, types
- [x] `transpile()` entry point processes AST and returns Lua string
- [x] First pass correctly identifies all declaration types
- [x] Output includes header comment with generation info
- [x] Stubs exist for transpile_globals, transpile_function, transpile_statement, transpile_expr
- [x] Module exports internal functions for sub-issues to use
- [x] Passes basic smoke test with minimal JASS input

---

## Notes

This sub-issue establishes the foundation for the entire transpiler. The design
prioritizes:

1. **Extensibility** - Internal functions exposed for sub-issues
2. **Testability** - Stubs allow infrastructure to be tested in isolation
3. **Debuggability** - Proper indentation and comments in output
4. **Error tolerance** - Multiple errors accumulated, not thrown

The stub functions will be replaced with real implementations as sub-issues
306b-306e are completed. Until then, the transpiler produces placeholder
comments showing where each construct would be transpiled.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

- `src/jass/transpiler.lua` - Transpiler infrastructure module (~300 lines)
- `src/tests/test_transpiler_infra.lua` - Test suite (87 tests)

### Implementation Details

1. **Context Structure** - `create_context()` returns:
   - Output management: `indent`, `output` array
   - Symbol tables: `globals`, `functions`, `natives`, `types`
   - State tracking: `current_func`, `current_locals`, `in_loop`, `loop_depth`
   - Error accumulation: `errors` array

2. **Output Emission**:
   - `emit(ctx, line)` - Adds line with proper indentation (4 spaces per level)
   - `emit_raw(ctx, line)` - Adds line without indentation
   - `emit_blank(ctx)` - Adds empty line
   - `emit_comment(ctx, text)` - Adds Lua comment with indentation
   - `indent(ctx)` / `dedent(ctx)` - Manage indentation level

3. **Error Handling**:
   - `add_error(ctx, message, node)` - Records error with optional location
   - `format_error(err)` - Formats error for display

4. **Helper Utilities**:
   - `format_params(params)` - Formats parameter list for comments
   - `is_native(ctx, name)` - Checks if name is a native function
   - `is_global(ctx, name)` - Checks if name is a global variable
   - `is_local(ctx, name)` - Checks if name is a local variable

5. **Two-Pass Architecture**:
   - Pass 1: `collect_declarations()` populates symbol tables
   - Pass 2: `transpile()` generates code for each declaration

6. **Stub Functions** for sub-issues:
   - `transpile_globals()` - Placeholder for 306b
   - `transpile_function()` - Placeholder for 306b
   - `transpile_statement()` - Placeholder for 306c
   - `transpile_expr()` - Placeholder for 306d

### Exported Interface

All internal functions are exposed with `_` prefix for sub-issues:
- `transpiler._create_context`
- `transpiler._emit`, `_emit_raw`, `_emit_blank`, `_emit_comment`
- `transpiler._indent`, `_dedent`
- `transpiler._add_error`, `_format_error`
- `transpiler._is_native`, `_is_global`, `_is_local`
- `transpiler._collect_declarations`
- `transpiler._transpile_declaration`, etc.

### Test Coverage (87 tests)

- Context creation and structure validation
- Output emission with indentation
- Blank lines and comments
- Indent/dedent management
- Error recording and formatting
- Helper utilities (format_params, is_native, is_global, is_local)
- Declaration collection for all types
- Main transpile entry point
- Full pipeline integration (lexer -> parser -> transpiler)

