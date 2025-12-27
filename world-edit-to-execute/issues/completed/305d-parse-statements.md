# Issue 305d: Parse Statements

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 305a-parser-infrastructure, 305c-parse-expressions
**Parent Issue:** 305-build-jass-parser

---

## Current Behavior

Parser infrastructure (305a) and expression parsing (305c) exist. Declaration
parsing (305b) has placeholder functions for parse_statement and parse_local_decl.
Function bodies cannot be properly parsed.

---

## Intended Behavior

Parse all JASS statement types within function bodies:
- `set` statements: variable and array assignment
- `call` statements: procedure calls (no return value used)
- `if` statements: if/elseif/else/endif chains
- `loop` statements: loop/endloop blocks
- `exitwhen` statements: conditional loop exit
- `return` statements: with optional return value
- `local` declarations: local variable declarations

```lua
local parser = require("jass.parser")

-- Parse function body containing all statement types
local ast = parser.parse(lexer.tokenize([[
function Example takes nothing returns nothing
    local integer i = 0
    local unit array units

    set i = 5
    set units[0] = CreateUnit(Player(0), 'hfoo', 0, 0, 0)

    call DisplayTextToPlayer(Player(0), 0, 0, "Hello")

    if i > 0 then
        set i = i - 1
    elseif i < 0 then
        set i = 0
    else
        return
    endif

    loop
        set i = i + 1
        exitwhen i >= 10
    endloop

    return
endfunction
]]))
```

---

## Suggested Implementation Steps

1. **Create statement parsing dispatcher**
   ```lua
   -- {{{ parse_statement
   -- Parse a single statement
   -- Dispatches to specific statement parsers based on leading keyword
   local function parse_statement(state)
       -- Skip blank lines and comments within statements
       while match(state, TOKEN.NEWLINE) or match(state, TOKEN.COMMENT) do end

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
       elseif check(state, TOKEN.DEBUG) then
           -- Debug statements: just skip the keyword and parse rest
           advance(state)
           return parse_statement(state)
       else
           error_at_current(state, "Expected statement")
           synchronize(state)
           return nil
       end
   end
   -- }}}
   ```

2. **Parse SET statements (variable assignment)**
   ```lua
   -- {{{ parse_set_stmt
   -- Parse set statement: set IDENT = expr | set IDENT[expr] = expr
   local function parse_set_stmt(state)
       local node = make_node(AST.SET_STMT, peek(state))

       consume(state, TOKEN.SET, "Expected 'set'")

       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected variable name")
       node.target = name_token and name_token.value or "?"

       -- Check for array index
       node.index = nil
       if match(state, TOKEN.LBRACKET) then
           node.index = parse_expression(state)
           consume(state, TOKEN.RBRACKET, "Expected ']' after array index")
       end

       consume(state, TOKEN.ASSIGN, "Expected '=' in set statement")
       node.value = parse_expression(state)

       return node
   end
   -- }}}
   ```

3. **Parse CALL statements (procedure calls)**
   ```lua
   -- {{{ parse_call_stmt
   -- Parse call statement: call IDENT(args)
   local function parse_call_stmt(state)
       local node = make_node(AST.CALL_STMT, peek(state))

       consume(state, TOKEN.CALL, "Expected 'call'")

       local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name")
       node.function_name = name_token and name_token.value or "?"

       consume(state, TOKEN.LPAREN, "Expected '(' after function name")
       node.arguments = parse_arguments(state)
       consume(state, TOKEN.RPAREN, "Expected ')' after arguments")

       return node
   end
   -- }}}
   ```

4. **Parse IF statements (conditionals)**
   ```lua
   -- {{{ parse_if_stmt
   -- Parse if statement: if expr then stmts (elseif expr then stmts)* (else stmts)? endif
   local function parse_if_stmt(state)
       local node = make_node(AST.IF_STMT, peek(state))

       consume(state, TOKEN.IF, "Expected 'if'")
       node.condition = parse_expression(state)
       consume(state, TOKEN.THEN, "Expected 'then' after if condition")

       -- Skip newlines after then
       while match(state, TOKEN.NEWLINE) do end

       -- Parse then-branch statements
       node.then_branch = {}
       while not check_any(state, TOKEN.ELSEIF, TOKEN.ELSE, TOKEN.ENDIF) and not at_end(state) do
           if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
               advance(state)
           else
               local stmt = parse_statement(state)
               if stmt then
                   node.then_branch[#node.then_branch + 1] = stmt
               end
           end
       end

       -- Parse elseif branches
       node.elseif_branches = {}
       while match(state, TOKEN.ELSEIF) do
           local elseif_branch = {
               condition = parse_expression(state),
               body = {},
           }
           consume(state, TOKEN.THEN, "Expected 'then' after elseif condition")

           while match(state, TOKEN.NEWLINE) do end

           while not check_any(state, TOKEN.ELSEIF, TOKEN.ELSE, TOKEN.ENDIF) and not at_end(state) do
               if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
                   advance(state)
               else
                   local stmt = parse_statement(state)
                   if stmt then
                       elseif_branch.body[#elseif_branch.body + 1] = stmt
                   end
               end
           end

           node.elseif_branches[#node.elseif_branches + 1] = elseif_branch
       end

       -- Parse else branch
       node.else_branch = nil
       if match(state, TOKEN.ELSE) then
           node.else_branch = {}

           while match(state, TOKEN.NEWLINE) do end

           while not check(state, TOKEN.ENDIF) and not at_end(state) do
               if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
                   advance(state)
               else
                   local stmt = parse_statement(state)
                   if stmt then
                       node.else_branch[#node.else_branch + 1] = stmt
                   end
               end
           end
       end

       consume(state, TOKEN.ENDIF, "Expected 'endif'")

       return node
   end
   -- }}}
   ```

5. **Parse LOOP statements**
   ```lua
   -- {{{ parse_loop_stmt
   -- Parse loop statement: loop stmts endloop
   local function parse_loop_stmt(state)
       local node = make_node(AST.LOOP_STMT, peek(state))

       consume(state, TOKEN.LOOP, "Expected 'loop'")

       while match(state, TOKEN.NEWLINE) do end

       -- Parse loop body
       node.body = {}
       while not check(state, TOKEN.ENDLOOP) and not at_end(state) do
           if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
               advance(state)
           else
               local stmt = parse_statement(state)
               if stmt then
                   node.body[#node.body + 1] = stmt
               end
           end
       end

       consume(state, TOKEN.ENDLOOP, "Expected 'endloop'")

       return node
   end
   -- }}}
   ```

6. **Parse EXITWHEN statements**
   ```lua
   -- {{{ parse_exitwhen_stmt
   -- Parse exitwhen statement: exitwhen expr
   local function parse_exitwhen_stmt(state)
       local node = make_node(AST.EXITWHEN_STMT, peek(state))

       consume(state, TOKEN.EXITWHEN, "Expected 'exitwhen'")
       node.condition = parse_expression(state)

       return node
   end
   -- }}}
   ```

7. **Parse RETURN statements**
   ```lua
   -- {{{ parse_return_stmt
   -- Parse return statement: return expr?
   local function parse_return_stmt(state)
       local node = make_node(AST.RETURN_STMT, peek(state))

       consume(state, TOKEN.RETURN, "Expected 'return'")

       -- Check if there's an expression to return
       -- Return is followed by newline or end of function if no value
       node.value = nil
       if can_start_expression(state) then
           node.value = parse_expression(state)
       end

       return node
   end
   -- }}}
   ```

8. **Parse LOCAL declarations**
   ```lua
   -- {{{ parse_local_decl
   -- Parse local variable declaration: local type [array] name [= expr]
   local function parse_local_decl(state)
       local node = make_node(AST.LOCAL_DECL, peek(state))

       consume(state, TOKEN.LOCAL, "Expected 'local'")

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
           node.initializer = parse_expression(state)
       elseif node.is_array and check(state, TOKEN.ASSIGN) then
           error_at_current(state, "Array variables cannot have initializers")
           advance(state)  -- Skip the = sign
           parse_expression(state)  -- Consume the invalid initializer
       end

       return node
   end
   -- }}}
   ```

9. **Update parse_function_def to use real statement parsing**
   ```lua
   -- {{{ parse_function_def
   -- Parse function definition (replaces placeholder from 305b)
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

       -- Parse local declarations (must come first in function body)
       node.locals = {}
       while check(state, TOKEN.LOCAL) do
           local local_decl = parse_local_decl(state)
           if local_decl then
               node.locals[#node.locals + 1] = local_decl
           end
           while match(state, TOKEN.NEWLINE) do end
       end

       -- Parse body statements
       node.body = {}
       while not check(state, TOKEN.ENDFUNCTION) and not at_end(state) do
           if check(state, TOKEN.NEWLINE) or check(state, TOKEN.COMMENT) then
               advance(state)
           elseif check(state, TOKEN.LOCAL) then
               -- Error: locals must come before statements
               error_at_current(state, "Local declarations must appear at the beginning of the function")
               local local_decl = parse_local_decl(state)
               if local_decl then
                   -- Still add it to preserve structure
                   node.locals[#node.locals + 1] = local_decl
               end
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

10. **Handle DEBUG keyword**
    ```lua
    -- JASS has a 'debug' keyword that prefixes statements for debug-only execution
    -- In parse_statement, if we see DEBUG, we skip it and parse the following statement
    -- The debug flag can be captured if needed for transpilation
    ```

11. **Export statement parsing functions**
    ```lua
    -- Add to module exports
    parser.parse_statement = parse_statement
    parser.parse_local_decl = parse_local_decl
    parser.parse_set_stmt = parse_set_stmt
    parser.parse_call_stmt = parse_call_stmt
    parser.parse_if_stmt = parse_if_stmt
    parser.parse_loop_stmt = parse_loop_stmt
    parser.parse_exitwhen_stmt = parse_exitwhen_stmt
    parser.parse_return_stmt = parse_return_stmt
    ```

---

## Technical Notes

### JASS Statement Grammar

```
stmt        = set_stmt | call_stmt | if_stmt | loop_stmt | exitwhen | return_stmt
set_stmt    = "set" IDENT ("=" | "[" expr "]" "=") expr
call_stmt   = "call" IDENT "(" args ")"
if_stmt     = "if" expr "then" stmts elseif* else? "endif"
elseif      = "elseif" expr "then" stmts
else        = "else" stmts
loop_stmt   = "loop" stmts "endloop"
exitwhen    = "exitwhen" expr
return_stmt = "return" expr?
```

### Local Declaration Order

JASS requires all local declarations to appear before any statements in
a function body. The parser enforces this with an error message but still
parses the misplaced local to maintain AST structure.

### Debug Statements

JASS supports `debug set x = 5` or `debug call Foo()` for debug-only
execution. The parser treats `debug` as a modifier and parses the
following statement normally.

### Empty Statement Bodies

Empty if/else/loop bodies are valid in JASS:
```jass
if false then
endif
```

The parser handles this by allowing empty statement arrays.

### Nested Structures

All control structures can be nested:
```jass
loop
    if condition then
        loop
            exitwhen true
        endloop
    endif
endloop
```

The recursive descent naturally handles nesting.

---

## Related Documents

- issues/305a-parser-infrastructure.md (provides helpers)
- issues/305c-parse-expressions.md (provides parse_expression)
- issues/305-build-jass-parser.md (parent issue)
- issues/305b-parse-declarations.md (parse_function_def integration)
- issues/304-build-jass-lexer.md (token types)

---

## Acceptance Criteria

- [x] parse_statement() dispatches to correct statement parser
- [x] parse_set_stmt() handles simple variable assignment
- [x] parse_set_stmt() handles array element assignment
- [x] parse_call_stmt() parses procedure calls with arguments
- [x] parse_if_stmt() parses if/then/endif
- [x] parse_if_stmt() parses if/then/else/endif
- [x] parse_if_stmt() parses if/then/elseif/then/endif chains
- [x] parse_if_stmt() handles multiple elseif branches
- [x] parse_loop_stmt() parses loop/endloop blocks
- [x] parse_exitwhen_stmt() parses exitwhen with condition
- [x] parse_return_stmt() parses return without value
- [x] parse_return_stmt() parses return with expression
- [x] parse_local_decl() handles type, name, optional initializer
- [x] parse_local_decl() handles array declarations
- [x] parse_local_decl() rejects array initializers with error
- [x] Empty control structure bodies are allowed
- [x] Nested control structures parse correctly
- [x] Locals after statements produce error but still parse
- [x] Debug keyword is handled (skipped or captured)
- [x] All functions use vimfold markers per project conventions
- [x] Unit tests for each statement type

---

## Notes

This sub-issue completes the parser by implementing all statement types.
It depends on expression parsing (305c) being complete since most
statements contain expressions.

The parse_function_def function is updated here to replace the
placeholder from 305b, integrating local declarations and the full
statement parsing loop.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

- `src/jass/lexer.lua` - Added DEBUG token type and keyword mapping
- `src/jass/parser.lua` - Enhanced statement parsing with missing features
- `src/tests/test_parser_stmt.lua` - New test suite (109 tests)

### Implementation Details

Note: Most statement parsing was already implemented prior to this issue (likely as part
of 305b work). This issue completed the remaining acceptance criteria:

1. **DEBUG keyword handling** - Added in parse_statement:
   - When DEBUG token is encountered, skip it and parse following statement
   - Mark parsed statement with `is_debug = true` flag for transpiler use

2. **Array initializer error** - Added in parse_var_decl:
   - Check for `= expr` after array declaration
   - Report error "Array variables cannot have initializers"
   - Still parse the initializer to maintain AST structure

3. **Locals after statements error** - Added in parse_function_def:
   - Check for LOCAL token during body statement parsing
   - Report error "Local declarations must appear at the beginning of the function"
   - Still parse local and add to fn.locals to preserve structure

### Statement Types Implemented

| Statement | AST Node | Description |
|-----------|----------|-------------|
| `set x = expr` | SET_STMT | Simple variable assignment |
| `set arr[i] = expr` | SET_STMT | Array element assignment |
| `call Func(args)` | CALL_STMT | Procedure call |
| `if...then...endif` | IF_STMT | Conditional with elseif/else |
| `loop...endloop` | LOOP_STMT | Loop block |
| `exitwhen expr` | EXITWHEN_STMT | Loop exit condition |
| `return [expr]` | RETURN_STMT | Function return |
| `local type name` | LOCAL_DECL | Local variable declaration |
| `debug stmt` | stmt.is_debug | Debug-only execution |

### Test Coverage (109 tests)

- SET statements: simple and array assignment
- CALL statements: no args, single arg, multiple args, expression args
- IF statements: simple, if/else, if/elseif, multiple elseif, empty body, nested
- LOOP statements: simple, empty, nested
- EXITWHEN statements: simple and complex conditions
- RETURN statements: with and without value
- LOCAL declarations: with/without initializer, arrays
- DEBUG keyword: marking statements as debug-only
- Error cases: array initializers, locals after statements
- Integration: complex mixed statements, deeply nested structures
