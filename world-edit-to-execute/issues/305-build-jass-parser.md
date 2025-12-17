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
