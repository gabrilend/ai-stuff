# Issue 305b: Parse Declarations

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 305a-parser-infrastructure
**Parent Issue:** 305-build-jass-parser

---

## Current Behavior

Parser infrastructure exists (305a) with token consumption helpers and error
handling, but no actual parsing logic. Cannot parse JASS type definitions,
global variables, native declarations, or function signatures.

---

## Intended Behavior

Parse all top-level JASS declarations:
- Type definitions: `type handle extends integer`
- Globals blocks: `globals ... endglobals` with variable declarations
- Native declarations: `native FunctionName takes param_list returns type`
- Function signatures: `function Name takes params returns type` (body parsing delegated to 305d)

```lua
local parser = require("jass.parser")
local lexer = require("jass.lexer")

local tokens = lexer.tokenize([[
type unit extends handle

globals
    constant integer MAX_PLAYERS = 12
    unit array allUnits
endglobals

native CreateUnit takes player p, integer id, real x, real y, real f returns unit

function InitGame takes nothing returns nothing
endfunction
]])

local ast, errors = parser.parse(tokens)
-- ast.type == "PROGRAM"
-- ast.declarations contains TYPE_DEF, GLOBAL_BLOCK, NATIVE_DECL, FUNCTION_DEF nodes
```

---

## Suggested Implementation Steps

1. **Import dependencies and create parse entry point**
   ```lua
   local lexer = require("jass.lexer")
   local TOKEN = lexer.TOKEN

   -- Import infrastructure from 305a
   local AST = parser.AST
   local create_state = parser.create_state
   local at_end = parser.at_end
   -- ... other helpers

   -- {{{ parse
   -- Main entry point: parse token stream into AST
   -- @param tokens Array of tokens from lexer
   -- @return ast, errors
   function parser.parse(tokens)
       local state = create_state(tokens)
       local program = parse_program(state)
       return program, state.errors
   end
   -- }}}
   ```

2. **Implement program parsing (top-level)**
   ```lua
   -- {{{ parse_program
   -- Parse entire JASS program
   -- program = (type_def | globals | native | function)*
   local function parse_program(state)
       local program = make_node(AST.PROGRAM, peek(state))
       program.declarations = {}

       -- Skip leading newlines
       while match(state, TOKEN.NEWLINE) do end

       while not at_end(state) do
           local decl = nil

           if check(state, TOKEN.TYPE) then
               decl = parse_type_def(state)
           elseif check(state, TOKEN.GLOBALS) then
               decl = parse_globals_block(state)
           elseif check(state, TOKEN.NATIVE) then
               decl = parse_native_decl(state)
           elseif check(state, TOKEN.CONSTANT) and check_next(state, TOKEN.NATIVE) then
               decl = parse_native_decl(state)
           elseif check(state, TOKEN.FUNCTION) then
               decl = parse_function_def(state)
           elseif check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
               advance(state)  -- Skip blank lines and comments
           else
               error_at_current(state, "Expected type, globals, native, or function declaration")
               synchronize(state)
           end

           if decl then
               program.declarations[#program.declarations + 1] = decl
           end

           -- Skip trailing newlines after each declaration
           while match(state, TOKEN.NEWLINE) do end
       end

       return program
   end
   -- }}}
   ```

3. **Implement check_next helper** (for lookahead)
   ```lua
   -- {{{ check_next
   -- Look ahead one token beyond current
   local function check_next(state, token_type)
       if state.pos + 1 > #state.tokens then return false end
       return state.tokens[state.pos + 1].type == token_type
   end
   -- }}}
   ```

4. **Parse type definitions**
   ```lua
   -- {{{ parse_type_def
   -- Parse type declaration: type NAME extends BASE_TYPE
   local function parse_type_def(state)
       local node = make_node(AST.TYPE_DEF, peek(state))

       consume(state, TOKEN.TYPE, "Expected 'type'")
       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected type name")
       node.name = name_token and name_token.value or "?"

       consume(state, TOKEN.EXTENDS, "Expected 'extends'")
       node.base_type = parse_type(state)

       return node
   end
   -- }}}
   ```

5. **Parse type references**
   ```lua
   -- {{{ parse_type
   -- Parse a type reference (identifier or 'nothing')
   -- @return Type name string
   local function parse_type(state)
       if match(state, TOKEN.NOTHING) then
           return "nothing"
       end

       local token = consume(state, TOKEN.IDENTIFIER, "Expected type name")
       return token and token.value or "?"
   end
   -- }}}
   ```

6. **Parse globals block**
   ```lua
   -- {{{ parse_globals_block
   -- Parse globals block: globals var_decl* endglobals
   local function parse_globals_block(state)
       local node = make_node(AST.GLOBAL_BLOCK, peek(state))
       node.declarations = {}

       consume(state, TOKEN.GLOBALS, "Expected 'globals'")

       -- Skip newline after globals keyword
       while match(state, TOKEN.NEWLINE) do end

       while not check(state, TOKEN.ENDGLOBALS) and not at_end(state) do
           if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
               advance(state)
           else
               local var_decl = parse_var_decl(state, true)  -- allow constant
               if var_decl then
                   node.declarations[#node.declarations + 1] = var_decl
               end
           end
       end

       consume(state, TOKEN.ENDGLOBALS, "Expected 'endglobals'")

       return node
   end
   -- }}}
   ```

7. **Parse variable declarations**
   ```lua
   -- {{{ parse_var_decl
   -- Parse variable declaration (used in globals and locals)
   -- var_decl = "constant"? type ("array")? IDENT ("=" expr)?
   -- @param allow_constant Whether 'constant' keyword is permitted
   local function parse_var_decl(state, allow_constant)
       local node = make_node(AST.VAR_DECL, peek(state))

       -- Check for constant modifier
       node.is_constant = false
       if allow_constant and match(state, TOKEN.CONSTANT) then
           node.is_constant = true
       end

       -- Parse type
       node.var_type = parse_type(state)

       -- Check for array
       node.is_array = match(state, TOKEN.ARRAY)

       -- Parse name
       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected variable name")
       node.name = name_token and name_token.value or "?"

       -- Check for initializer (not allowed for arrays)
       node.initializer = nil
       if not node.is_array and match(state, TOKEN.ASSIGN) then
           -- Expression parsing delegated to 305c
           -- For now, create placeholder; will be replaced when 305c integrates
           node.initializer = parse_expression(state)
       end

       return node
   end
   -- }}}
   ```

8. **Parse native declarations**
   ```lua
   -- {{{ parse_native_decl
   -- Parse native function declaration
   -- native_decl = "constant"? "native" IDENT "takes" params "returns" type
   local function parse_native_decl(state)
       local node = make_node(AST.NATIVE_DECL, peek(state))

       -- Check for constant modifier (for constant functions like GetUnitTypeId)
       node.is_constant = match(state, TOKEN.CONSTANT)

       consume(state, TOKEN.NATIVE, "Expected 'native'")

       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected native function name")
       node.name = name_token and name_token.value or "?"

       consume(state, TOKEN.TAKES, "Expected 'takes'")
       node.params = parse_param_list(state)

       consume(state, TOKEN.RETURNS, "Expected 'returns'")
       node.return_type = parse_type(state)

       return node
   end
   -- }}}
   ```

9. **Parse parameter lists**
   ```lua
   -- {{{ parse_param_list
   -- Parse function parameter list
   -- params = "nothing" | param ("," param)*
   -- param = type IDENT
   -- @return Array of {type, name} tables
   local function parse_param_list(state)
       local params = {}

       -- Check for "takes nothing"
       if match(state, TOKEN.NOTHING) then
           return params
       end

       -- Parse first parameter
       local param = parse_param(state)
       if param then
           params[#params + 1] = param
       end

       -- Parse remaining parameters
       while match(state, TOKEN.COMMA) do
           param = parse_param(state)
           if param then
               params[#params + 1] = param
           end
       end

       return params
   end
   -- }}}

   -- {{{ parse_param
   -- Parse single parameter: type name
   local function parse_param(state)
       local param_type = parse_type(state)
       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected parameter name")
       return {
           type = param_type,
           name = name_token and name_token.value or "?",
       }
   end
   -- }}}
   ```

10. **Parse function definition (signature only, body delegated)**
    ```lua
    -- {{{ parse_function_def
    -- Parse function definition
    -- function = "function" IDENT "takes" params "returns" type locals stmts "endfunction"
    local function parse_function_def(state)
        local node = make_node(AST.FUNCTION_DEF, peek(state))

        consume(state, TOKEN.FUNCTION, "Expected 'function'")

        local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name")
        node.name = name_token and name_token.value or "?"

        consume(state, TOKEN.TAKES, "Expected 'takes'")
        node.params = parse_param_list(state)

        consume(state, TOKEN.RETURNS, "Expected 'returns'")
        node.return_type = parse_type(state)

        -- Skip newlines before body
        while match(state, TOKEN.NEWLINE) do end

        -- Parse locals (delegated to 305d, placeholder here)
        node.locals = {}
        while check(state, TOKEN.LOCAL) do
            local local_decl = parse_local_decl(state)
            if local_decl then
                node.locals[#node.locals + 1] = local_decl
            end
            while match(state, TOKEN.NEWLINE) do end
        end

        -- Parse body statements (delegated to 305d, placeholder here)
        node.body = {}
        while not check(state, TOKEN.ENDFUNCTION) and not at_end(state) do
            if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
                advance(state)
            else
                local stmt = parse_statement(state)
                if stmt then
                    node.body[#node.body + 1] = stmt
                end
            end
        end

        consume(state, TOKEN.ENDFUNCTION, "Expected 'endfunction'")

        return node
    end
    -- }}}
    ```

11. **Add placeholder for parse_local_decl** (completed in 305d)
    ```lua
    -- {{{ parse_local_decl
    -- Parse local variable declaration: local var_decl
    -- Full implementation in 305d
    local function parse_local_decl(state)
        local node = make_node(AST.LOCAL_DECL, peek(state))
        consume(state, TOKEN.LOCAL, "Expected 'local'")

        -- Reuse var_decl parsing (no constant allowed for locals)
        local var = parse_var_decl(state, false)
        node.var_type = var.var_type
        node.name = var.name
        node.is_array = var.is_array
        node.initializer = var.initializer

        return node
    end
    -- }}}
    ```

12. **Add placeholder for parse_statement and parse_expression**
    ```lua
    -- Placeholder until 305c/305d integrate
    -- {{{ parse_expression
    local function parse_expression(state)
        -- Consume tokens until newline/comma/paren as placeholder
        local node = make_node(AST.LITERAL, peek(state))
        node.value = peek(state).value
        advance(state)
        return node
    end
    -- }}}

    -- {{{ parse_statement
    local function parse_statement(state)
        -- Placeholder: skip to next line
        while not check(state, TOKEN.NEWLINE) and not at_end(state) do
            advance(state)
        end
        return nil
    end
    -- }}}
    ```

---

## Technical Notes

### JASS Declaration Grammar

```
program     = (type_def | globals | native | function)*
type_def    = "type" IDENT "extends" type
globals     = "globals" var_decl* "endglobals"
var_decl    = "constant"? type "array"? IDENT ("=" expr)?
native      = "constant"? "native" IDENT "takes" params "returns" type
function    = "function" IDENT "takes" params "returns" type body "endfunction"
params      = "nothing" | param ("," param)*
param       = type IDENT
type        = IDENT | "nothing"
```

### Constant Natives

Some native functions are marked `constant`, meaning they have no side effects
and can be evaluated at compile time. The parser captures this but doesn't
enforce it.

### Array Variables

Array declarations cannot have initializers in JASS:
```jass
integer array myArray        // valid
integer array myArray = 0    // invalid
```

The parser should reject initializers on array declarations.

---

## Related Documents

- issues/305a-parser-infrastructure.md (provides helpers)
- issues/305-build-jass-parser.md (parent issue)
- issues/305c-parse-expressions.md (parse_expression integration)
- issues/305d-parse-statements.md (parse_statement, parse_local_decl integration)
- issues/304-build-jass-lexer.md (token types)

---

## Acceptance Criteria

- [ ] parse() accepts token array and returns (ast, errors)
- [ ] parse_program() returns PROGRAM node with declarations array
- [ ] parse_type_def() correctly parses `type X extends Y`
- [ ] parse_globals_block() parses globals/endglobals with var_decls
- [ ] parse_var_decl() handles constant, array, and initializer cases
- [ ] parse_native_decl() parses native function signatures
- [ ] parse_function_def() parses function signatures (body via placeholders)
- [ ] parse_param_list() handles "nothing" and comma-separated params
- [ ] parse_type() handles identifiers and "nothing" keyword
- [ ] Newlines and comments between declarations are skipped
- [ ] Errors reported with line/column for invalid syntax
- [ ] Error recovery allows parsing to continue after errors
- [ ] All functions use vimfold markers per project conventions
- [ ] Unit tests for each declaration type

---

## Notes

This sub-issue creates the main `parse()` entry point and handles all
top-level constructs. The parse_expression and parse_statement functions
are placeholders that will be replaced when 305c and 305d integrate.

Function bodies contain locals and statements which are parsed via
delegation to 305d. The structure is parsed here (parse_function_def
calls parse_local_decl and parse_statement in a loop).

---

## Implementation Notes

*Completed by Claude Code on 2025-12-27*

### Files Modified

| File | Description |
|------|-------------|
| `src/jass/parser.lua` | Added declaration parsing (~550 lines added) |
| `src/tests/test_parser_decl.lua` | Unit tests for declarations (19 tests) |

### Implementation Details

1. **Added to parser.lua:**
   - `parse()` - Main entry point accepting tokens, returning (ast, errors)
   - `parse_program()` - Top-level dispatcher for declarations
   - `parse_type_def()` - `type X extends Y` parsing
   - `parse_globals_block()` - `globals ... endglobals` with var_decls
   - `parse_var_decl()` - Variable declarations with constant/array/initializer
   - `parse_native_decl()` - Native function signatures
   - `parse_function_def()` - Function signatures, locals, and body
   - `parse_param_list()` / `parse_param()` - Parameter list parsing
   - `parse_type()` - Type references (identifiers or "nothing")
   - `parse_local_decl()` - Local variable declarations
   - `parse_expression()` - Placeholder (later replaced by 305c)
   - `parse_statement()` - Placeholder with basic set/call/return/if/loop

2. **Expression parsing (305c) was integrated concurrently:**
   - Full precedence-climbing expression parser added by parallel worker
   - Fixed syntax error in elseif loop (`then` → `do`)

3. **Test Coverage:**
   - Type definitions (simple, multiple)
   - Globals blocks (empty, variables, constants, arrays, initializers)
   - Native declarations (no params, with params, constant)
   - Function definitions (empty, params, locals, statements)
   - Mixed declarations (full file structure)
   - Error handling (missing tokens, recovery)

### Acceptance Criteria Status

- [x] parse() accepts token array and returns (ast, errors)
- [x] parse_program() returns PROGRAM node with declarations array
- [x] parse_type_def() correctly parses `type X extends Y`
- [x] parse_globals_block() parses globals/endglobals with var_decls
- [x] parse_var_decl() handles constant, array, and initializer cases
- [x] parse_native_decl() parses native function signatures
- [x] parse_function_def() parses function signatures (body via placeholders)
- [x] parse_param_list() handles "nothing" and comma-separated params
- [x] parse_type() handles identifiers and "nothing" keyword
- [x] Newlines and comments between declarations are skipped
- [x] Errors reported with line/column for invalid syntax
- [x] Error recovery allows parsing to continue after errors
- [x] All functions use vimfold markers per project conventions
- [x] Unit tests for each declaration type
