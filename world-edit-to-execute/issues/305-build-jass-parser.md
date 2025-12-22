# Issue 305: Build JASS Parser

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 304-build-jass-lexer

---

## Current Behavior

No Abstract Syntax Tree (AST) generation for JASS. Cannot analyze or
transform JASS code programmatically.

---

## Intended Behavior

A parser that converts JASS token streams into an AST:
- Type declarations
- Global variable declarations
- Function declarations with parameters
- Statements (set, call, if, loop, return)
- Expressions (arithmetic, comparison, function calls)

---

## Suggested Implementation Steps

1. **Create parser module**
   ```
   src/jass/
   ├── lexer.lua        (from 304)
   └── parser.lua       (this issue)
   ```

2. **Define AST node types**
   ```lua
   local AST = {
       -- Top-level
       PROGRAM = "PROGRAM",
       TYPE_DEF = "TYPE_DEF",
       GLOBAL_BLOCK = "GLOBAL_BLOCK",
       VAR_DECL = "VAR_DECL",
       NATIVE_DECL = "NATIVE_DECL",
       FUNCTION_DEF = "FUNCTION_DEF",

       -- Statements
       SET_STMT = "SET_STMT",
       CALL_STMT = "CALL_STMT",
       IF_STMT = "IF_STMT",
       LOOP_STMT = "LOOP_STMT",
       EXITWHEN_STMT = "EXITWHEN_STMT",
       RETURN_STMT = "RETURN_STMT",
       LOCAL_DECL = "LOCAL_DECL",

       -- Expressions
       BINARY_EXPR = "BINARY_EXPR",
       UNARY_EXPR = "UNARY_EXPR",
       CALL_EXPR = "CALL_EXPR",
       ARRAY_ACCESS = "ARRAY_ACCESS",
       IDENTIFIER = "IDENTIFIER",
       LITERAL = "LITERAL",
       FUNCTION_REF = "FUNCTION_REF",
   }
   ```

3. **Implement recursive descent parser**
   ```lua
   function parser.parse(tokens)
       local state = {
           tokens = tokens,
           pos = 1,
           errors = {},
       }

       local program = parse_program(state)
       return program, state.errors
   end
   ```

4. **Parse top-level declarations**
   ```lua
   -- Program structure:
   -- type_def*
   -- globals_block?
   -- native_decl*
   -- function_def*

   local function parse_program(state)
       local program = { type = AST.PROGRAM, declarations = {} }

       while not at_end(state) do
           if check(state, TOKEN.TYPE) then
               program.declarations[#program.declarations + 1] = parse_type_def(state)
           elseif check(state, TOKEN.GLOBALS) then
               program.declarations[#program.declarations + 1] = parse_globals_block(state)
           elseif check(state, TOKEN.NATIVE) or check(state, TOKEN.CONSTANT) then
               program.declarations[#program.declarations + 1] = parse_native_decl(state)
           elseif check(state, TOKEN.FUNCTION) then
               program.declarations[#program.declarations + 1] = parse_function_def(state)
           else
               error_at_current(state, "Expected declaration")
               synchronize(state)
           end
       end

       return program
   end
   ```

5. **Parse function definitions**
   ```lua
   -- function name takes param_list returns type
   --     local_decl*
   --     statement*
   -- endfunction

   local function parse_function_def(state)
       consume(state, TOKEN.FUNCTION)
       local name = consume(state, TOKEN.IDENTIFIER).value
       consume(state, TOKEN.TAKES)
       local params = parse_param_list(state)
       consume(state, TOKEN.RETURNS)
       local return_type = parse_type(state)

       local locals = {}
       local body = {}

       -- Parse locals first
       while check(state, TOKEN.LOCAL) do
           locals[#locals + 1] = parse_local_decl(state)
       end

       -- Parse statements
       while not check(state, TOKEN.ENDFUNCTION) do
           body[#body + 1] = parse_statement(state)
       end

       consume(state, TOKEN.ENDFUNCTION)

       return {
           type = AST.FUNCTION_DEF,
           name = name,
           params = params,
           return_type = return_type,
           locals = locals,
           body = body,
       }
   end
   ```

6. **Parse statements**
   ```lua
   local function parse_statement(state)
       if check(state, TOKEN.SET) then
           return parse_set_stmt(state)
       elseif check(state, TOKEN.CALL) then
           return parse_call_stmt(state)
       elseif check(state, TOKEN.IF) then
           return parse_if_stmt(state)
       elseif check(state, TOKEN.LOOP) then
           return parse_loop_stmt(state)
       elseif check(state, TOKEN.EXITWHEN) then
           return parse_exitwhen_stmt(state)
       elseif check(state, TOKEN.RETURN) then
           return parse_return_stmt(state)
       else
           error_at_current(state, "Expected statement")
           return nil
       end
   end
   ```

7. **Parse expressions with precedence**
   ```lua
   -- Operator precedence (lowest to highest):
   -- 1. or
   -- 2. and
   -- 3. not
   -- 4. ==, !=, <, <=, >, >=
   -- 5. +, -
   -- 6. *, /
   -- 7. unary -, not
   -- 8. function call, array access

   local function parse_expression(state)
       return parse_or_expr(state)
   end
   ```

---

## Technical Notes

### JASS Grammar (Simplified)

```
program     = (type_def | globals | native | function)*
type_def    = "type" IDENT "extends" type
globals     = "globals" var_decl* "endglobals"
native      = "constant"? "native" IDENT "takes" params "returns" type
function    = "function" IDENT "takes" params "returns" type locals stmts "endfunction"
params      = "nothing" | param ("," param)*
param       = type IDENT
type        = IDENT | "nothing"
locals      = ("local" var_decl)*
var_decl    = type IDENT ("=" expr)? | type "array" IDENT
stmts       = stmt*
stmt        = set_stmt | call_stmt | if_stmt | loop_stmt | exitwhen | return_stmt
set_stmt    = "set" IDENT ("=" | "[" expr "]" "=") expr
call_stmt   = "call" IDENT "(" args ")"
if_stmt     = "if" expr "then" stmts elseif* else? "endif"
loop_stmt   = "loop" stmts "endloop"
exitwhen    = "exitwhen" expr
return_stmt = "return" expr?
expr        = or_expr
```

### Error Recovery

The parser should recover from errors to report multiple issues:
```lua
local function synchronize(state)
    advance(state)
    while not at_end(state) do
        -- Synchronize at statement boundaries
        if check(state, TOKEN.SET) or check(state, TOKEN.CALL) or
           check(state, TOKEN.IF) or check(state, TOKEN.LOOP) or
           check(state, TOKEN.RETURN) or check(state, TOKEN.ENDFUNCTION) then
            return
        end
        advance(state)
    end
end
```

### Native Functions

Native declarations define the engine API but have no body:
```jass
native CreateUnit takes player p, integer id, real x, real y, real f returns unit
```

These need special handling during transpilation (issue 306).

---

## Related Documents

- docs/jass/parser.md (to be created)
- docs/jass/grammar.md (to be created)
- issues/304-build-jass-lexer.md (token input)
- issues/306-create-jass-lua-transpiler.md (AST consumer)

---

## Acceptance Criteria

- [ ] Parses type declarations
- [ ] Parses globals block
- [ ] Parses native declarations
- [ ] Parses function definitions
- [ ] Parses all statement types
- [ ] Parses expressions with correct precedence
- [ ] Handles array access and declarations
- [ ] Recovers from parse errors
- [ ] Reports meaningful error messages with location
- [ ] Produces valid AST structure
- [ ] Unit tests for grammar constructs

---

## Notes

The parser converts flat token streams into hierarchical AST structures.
This enables:

1. Static analysis (type checking, dead code detection)
2. Transformation (optimization, transpilation)
3. Pretty printing (reformatting)
4. Documentation generation

The parser should be lenient enough to handle most maps while being
strict enough to catch actual errors.

Reference: [JASS Language Specification](http://jass.sourceforge.net/doc/)
Reference: [Crafting Interpreters - Parsing](https://craftinginterpreters.com/parsing-expressions.html)

---

## Sub-Issue Analysis

*Generated by Claude Code on 2025-12-19 03:12*

Looking at this issue, I'll analyze whether splitting would be beneficial.

## Analysis

This is a substantial parser implementation with several distinct components:

1. **AST node type definitions** - Data structure definitions
2. **Parser infrastructure** - State management, error handling, synchronization
3. **Top-level declaration parsing** - type, globals, native, function
4. **Statement parsing** - set, call, if, loop, exitwhen, return
5. **Expression parsing with precedence** - The trickiest part

The issue is well-structured but covers a lot of ground. Splitting would help because:
- Expression parsing with precedence is complex enough to warrant isolation
- Statement parsing has 6 distinct statement types
- Testing can be done incrementally per sub-issue
- Each sub-issue has clear boundaries and can be verified independently

## Suggested Sub-Issues

### 305a-parser-infrastructure
**Description:** Create parser module with state management, token consumption helpers, error handling, and synchronization/recovery mechanisms.

**Covers:**
- Parser state structure (tokens, pos, errors)
- Helper functions: `at_end()`, `check()`, `advance()`, `consume()`, `peek()`, `previous()`
- Error reporting: `error_at_current()`, `error_at()` with location info
- Recovery: `synchronize()` function
- AST node type constants

**Dependencies:** 304 (lexer)

---

### 305b-parse-declarations
**Description:** Parse top-level declarations: type definitions, globals blocks, native declarations, and function signatures (without body parsing).

**Covers:**
- `parse_program()` - main entry point
- `parse_type_def()` - `type X extends Y`
- `parse_globals_block()` - `globals ... endglobals`
- `parse_var_decl()` - variable declarations (used in globals and locals)
- `parse_native_decl()` - native function signatures
- `parse_function_def()` skeleton - signature parsing, delegates body to 305d
- `parse_param_list()` and `parse_type()`

**Dependencies:** 305a

---

### 305c-parse-expressions
**Description:** Implement expression parsing with correct operator precedence using recursive descent.

**Covers:**
- Precedence chain: `parse_or_expr()` → `parse_and_expr()` → `parse_comparison()` → `parse_additive()` → `parse_multiplicative()` → `parse_unary()` → `parse_primary()`
- Binary expression nodes
- Unary expression nodes (-, not)
- Primary expressions: literals, identifiers, parenthesized expressions
- Function call expressions: `name(args)`
- Array access: `name[index]`
- Function references: `function name`

**Dependencies:** 305a

---

### 305d-parse-statements
**Description:** Parse all JASS statement types and function bodies.

**Covers:**
- `parse_statement()` dispatcher
- `parse_set_stmt()` - variable and array assignment
- `parse_call_stmt()` - procedure calls
- `parse_if_stmt()` - if/elseif/else/endif chains
- `parse_loop_stmt()` - loop/endloop
- `parse_exitwhen_stmt()` - loop exit condition
- `parse_return_stmt()` - return with optional expression
- `parse_local_decl()` - local variable declarations
- Complete function body parsing (locals then statements)

**Dependencies:** 305a, 305c (statements contain expressions)

---

### 305e-parser-tests
**Description:** Comprehensive test suite validating parser against JASS grammar constructs.

**Covers:**
- Unit tests for each declaration type
- Unit tests for each statement type
- Expression precedence tests
- Error recovery tests
- Integration test parsing a complete JASS file
- Edge cases: empty functions, nested ifs, complex expressions

**Dependencies:** 305a, 305b, 305c, 305d

---

## Dependency Graph

```
304 (lexer)
    │
    ▼
  305a (infrastructure)
    │
    ├──────────┬──────────┐
    ▼          ▼          │
  305b       305c         │
(decls)    (exprs)        │
    │          │          │
    │          ▼          │
    │        305d ◄───────┘
    │      (stmts)
    │          │
    ▼          ▼
    └────► 305e ◄────┘
         (tests)
```

This split allows parallel work on 305b and 305c after infrastructure is done, with 305d integrating expressions into statement parsing.
