# Issue 305c: Parse Expressions

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 305a-parser-infrastructure
**Parent Issue:** 305-build-jass-parser

---

## Current Behavior

Parser infrastructure exists (305a) and declaration parsing is in progress (305b),
but there is no expression parsing. Variable initializers and statement expressions
cannot be parsed. The placeholder parse_expression() just consumes a single token.

---

## Intended Behavior

Implement full expression parsing with correct operator precedence using
recursive descent:

```lua
-- Precedence levels (lowest to highest):
-- 1. or
-- 2. and
-- 3. == != < <= > >=
-- 4. + -
-- 5. * /
-- 6. unary (- not)
-- 7. primary (literals, identifiers, calls, array access, function refs)
```

Supports:
- Binary operators: `+`, `-`, `*`, `/`, `==`, `!=`, `<`, `<=`, `>`, `>=`, `and`, `or`
- Unary operators: `-` (negation), `not`
- Literals: integers, reals, strings, rawcodes, true, false, null
- Identifiers: variable references
- Function calls: `FunctionName(arg1, arg2, ...)`
- Array access: `arrayName[index]`
- Function references: `function FunctionName`
- Parenthesized expressions: `(expr)`

```lua
local parser = require("jass.parser")

-- Parse: (x + 5) * GetUnitX(u) - arr[i]
-- Produces correct AST respecting precedence
```

---

## Suggested Implementation Steps

1. **Create expression parsing entry point**
   ```lua
   -- {{{ parse_expression
   -- Parse an expression starting at current token
   -- Entry point for expression parsing - starts at lowest precedence
   local function parse_expression(state)
       return parse_or_expr(state)
   end
   -- }}}
   ```

2. **Implement OR expressions (lowest precedence)**
   ```lua
   -- {{{ parse_or_expr
   -- Parse OR expression: and_expr ("or" and_expr)*
   local function parse_or_expr(state)
       local left = parse_and_expr(state)

       while match(state, TOKEN.OR) do
           local node = make_node(AST.BINARY_EXPR, previous(state))
           node.operator = "or"
           node.left = left
           node.right = parse_and_expr(state)
           left = node
       end

       return left
   end
   -- }}}
   ```

3. **Implement AND expressions**
   ```lua
   -- {{{ parse_and_expr
   -- Parse AND expression: comparison ("and" comparison)*
   local function parse_and_expr(state)
       local left = parse_comparison(state)

       while match(state, TOKEN.AND) do
           local node = make_node(AST.BINARY_EXPR, previous(state))
           node.operator = "and"
           node.left = left
           node.right = parse_comparison(state)
           left = node
       end

       return left
   end
   -- }}}
   ```

4. **Implement comparison expressions**
   ```lua
   -- {{{ parse_comparison
   -- Parse comparison: additive (("==" | "!=" | "<" | "<=" | ">" | ">=") additive)*
   local function parse_comparison(state)
       local left = parse_additive(state)

       while true do
           local op = nil
           if match(state, TOKEN.EQ) then op = "=="
           elseif match(state, TOKEN.NE) then op = "!="
           elseif match(state, TOKEN.LT) then op = "<"
           elseif match(state, TOKEN.LE) then op = "<="
           elseif match(state, TOKEN.GT) then op = ">"
           elseif match(state, TOKEN.GE) then op = ">="
           else break
           end

           local node = make_node(AST.BINARY_EXPR, previous(state))
           node.operator = op
           node.left = left
           node.right = parse_additive(state)
           left = node
       end

       return left
   end
   -- }}}
   ```

5. **Implement additive expressions**
   ```lua
   -- {{{ parse_additive
   -- Parse additive: multiplicative (("+" | "-") multiplicative)*
   local function parse_additive(state)
       local left = parse_multiplicative(state)

       while true do
           local op = nil
           if match(state, TOKEN.PLUS) then op = "+"
           elseif match(state, TOKEN.MINUS) then op = "-"
           else break
           end

           local node = make_node(AST.BINARY_EXPR, previous(state))
           node.operator = op
           node.left = left
           node.right = parse_multiplicative(state)
           left = node
       end

       return left
   end
   -- }}}
   ```

6. **Implement multiplicative expressions**
   ```lua
   -- {{{ parse_multiplicative
   -- Parse multiplicative: unary (("*" | "/") unary)*
   local function parse_multiplicative(state)
       local left = parse_unary(state)

       while true do
           local op = nil
           if match(state, TOKEN.STAR) then op = "*"
           elseif match(state, TOKEN.SLASH) then op = "/"
           else break
           end

           local node = make_node(AST.BINARY_EXPR, previous(state))
           node.operator = op
           node.left = left
           node.right = parse_unary(state)
           left = node
       end

       return left
   end
   -- }}}
   ```

7. **Implement unary expressions**
   ```lua
   -- {{{ parse_unary
   -- Parse unary: ("-" | "not") unary | postfix
   local function parse_unary(state)
       if match(state, TOKEN.MINUS) then
           local node = make_node(AST.UNARY_EXPR, previous(state))
           node.operator = "-"
           node.operand = parse_unary(state)  -- Right-associative
           return node
       end

       if match(state, TOKEN.NOT) then
           local node = make_node(AST.UNARY_EXPR, previous(state))
           node.operator = "not"
           node.operand = parse_unary(state)
           return node
       end

       return parse_postfix(state)
   end
   -- }}}
   ```

8. **Implement postfix expressions (calls, array access)**
   ```lua
   -- {{{ parse_postfix
   -- Parse postfix: primary ("[" expr "]" | "(" args ")")*
   local function parse_postfix(state)
       local expr = parse_primary(state)

       while true do
           if match(state, TOKEN.LBRACKET) then
               -- Array access: expr[index]
               local node = make_node(AST.ARRAY_ACCESS, previous(state))
               node.array = expr
               node.index = parse_expression(state)
               consume(state, TOKEN.RBRACKET, "Expected ']' after array index")
               expr = node

           elseif match(state, TOKEN.LPAREN) then
               -- Function call: expr(args)
               -- Note: In JASS, only identifiers can be called
               -- but we parse generally for error messages
               local node = make_node(AST.CALL_EXPR, previous(state))
               node.callee = expr
               node.arguments = parse_arguments(state)
               consume(state, TOKEN.RPAREN, "Expected ')' after arguments")
               expr = node
           else
               break
           end
       end

       return expr
   end
   -- }}}
   ```

9. **Implement argument list parsing**
   ```lua
   -- {{{ parse_arguments
   -- Parse function call arguments: (expr ("," expr)*)?
   -- @return Array of expression nodes
   local function parse_arguments(state)
       local args = {}

       -- Empty argument list
       if check(state, TOKEN.RPAREN) then
           return args
       end

       -- First argument
       args[#args + 1] = parse_expression(state)

       -- Remaining arguments
       while match(state, TOKEN.COMMA) do
           args[#args + 1] = parse_expression(state)
       end

       return args
   end
   -- }}}
   ```

10. **Implement primary expressions**
    ```lua
    -- {{{ parse_primary
    -- Parse primary expression: literal | identifier | "(" expr ")" | "function" IDENT
    local function parse_primary(state)
        -- Integer literal
        if match(state, TOKEN.INTEGER) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "integer"
            node.value = previous(state).value
            return node
        end

        -- Real literal
        if match(state, TOKEN.REAL) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "real"
            node.value = previous(state).value
            return node
        end

        -- String literal
        if match(state, TOKEN.STRING) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "string"
            node.value = previous(state).value
            return node
        end

        -- Rawcode literal (four-character code like 'hfoo')
        if match(state, TOKEN.RAWCODE) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "rawcode"
            node.value = previous(state).value
            return node
        end

        -- Boolean true
        if match(state, TOKEN.TRUE) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "boolean"
            node.value = true
            return node
        end

        -- Boolean false
        if match(state, TOKEN.FALSE) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "boolean"
            node.value = false
            return node
        end

        -- Null literal
        if match(state, TOKEN.NULL) then
            local node = make_node(AST.LITERAL, previous(state))
            node.literal_type = "null"
            node.value = nil
            return node
        end

        -- Function reference: function FunctionName
        if match(state, TOKEN.FUNCTION) then
            local node = make_node(AST.FUNCTION_REF, previous(state))
            local name_token = consume(state, TOKEN.IDENTIFIER, "Expected function name after 'function'")
            node.name = name_token and name_token.value or "?"
            return node
        end

        -- Identifier (variable reference or start of function call)
        if match(state, TOKEN.IDENTIFIER) then
            local node = make_node(AST.IDENTIFIER, previous(state))
            node.name = previous(state).value
            return node
        end

        -- Parenthesized expression
        if match(state, TOKEN.LPAREN) then
            local expr = parse_expression(state)
            consume(state, TOKEN.RPAREN, "Expected ')' after expression")
            return expr
        end

        -- Error: unexpected token
        error_at_current(state, "Expected expression")
        return nil
    end
    -- }}}
    ```

11. **Add helper to check if token can start an expression**
    ```lua
    -- {{{ can_start_expression
    -- Check if current token can begin an expression
    -- Useful for optional expression parsing (e.g., return statements)
    local function can_start_expression(state)
        return check_any(state,
            TOKEN.MINUS,
            TOKEN.NOT,
            TOKEN.INTEGER,
            TOKEN.REAL,
            TOKEN.STRING,
            TOKEN.RAWCODE,
            TOKEN.TRUE,
            TOKEN.FALSE,
            TOKEN.NULL,
            TOKEN.FUNCTION,
            TOKEN.IDENTIFIER,
            TOKEN.LPAREN
        )
    end
    -- }}}
    ```

12. **Export expression parsing functions**
    ```lua
    -- Add to module exports
    parser.parse_expression = parse_expression
    parser.can_start_expression = can_start_expression
    ```

---

## Technical Notes

### Operator Precedence Table

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (lowest) | `or` | Left |
| 2 | `and` | Left |
| 3 | `==` `!=` `<` `<=` `>` `>=` | Left |
| 4 | `+` `-` | Left |
| 5 | `*` `/` | Left |
| 6 (highest) | `-` (unary) `not` | Right |

### Recursive Descent Approach

Each precedence level has its own parsing function that:
1. Parses the next higher precedence level
2. Checks for operators at its level
3. If found, creates a binary node and loops

This naturally handles left-associativity for binary operators.

### JASS-Specific Notes

- JASS uses `==` and `!=` (not `=` and `<>`)
- The `not` keyword is used instead of `!`
- String concatenation uses `+` operator
- No bitwise operators in standard JASS
- Function references (`function Name`) return a code type

### Array Access vs Function Calls

In JASS, array access uses `[]` and function calls use `()`. The parser
handles both in parse_postfix. An identifier followed by `[` is array
access; followed by `(` is a function call.

---

## Related Documents

- issues/305a-parser-infrastructure.md (provides helpers)
- issues/305-build-jass-parser.md (parent issue)
- issues/305b-parse-declarations.md (uses parse_expression for initializers)
- issues/305d-parse-statements.md (uses parse_expression in statements)
- issues/304-build-jass-lexer.md (token types)

---

## Acceptance Criteria

- [x] parse_expression() returns valid AST for all expression types
- [x] Operator precedence is correct (verified with test cases)
- [x] Left-associativity for binary operators (a + b + c = (a + b) + c)
- [x] Right-associativity for unary operators (--x = -(-x))
- [x] parse_or_expr() handles `or` operator
- [x] parse_and_expr() handles `and` operator
- [x] parse_comparison() handles all comparison operators
- [x] parse_additive() handles `+` and `-`
- [x] parse_multiplicative() handles `*` and `/`
- [x] parse_unary() handles `-` and `not`
- [x] parse_primary() handles all literal types
- [x] parse_primary() handles identifiers
- [x] parse_primary() handles parenthesized expressions
- [x] parse_primary() handles function references
- [x] parse_postfix() handles array access with `[]`
- [x] parse_postfix() handles function calls with `()`
- [x] parse_arguments() parses comma-separated argument lists
- [x] can_start_expression() correctly identifies expression starters
- [x] Error messages identify unexpected tokens
- [x] All functions use vimfold markers per project conventions
- [x] Unit tests for precedence and associativity

---

## Notes

Expression parsing is the most complex part of the parser due to
precedence handling. The recursive descent approach makes precedence
explicit in the call structure.

This sub-issue can be developed in parallel with 305b since it doesn't
depend on declaration parsing - only on the infrastructure from 305a.

The `parse_expression` function replaces the placeholder in 305b
when integration occurs.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Modified

- `src/jass/parser.lua` - Added expression parsing functions (~200 lines)
- `src/tests/test_parser_expr.lua` - New test suite (64 tests)

### Implementation Details

1. **Recursive descent with precedence** - Each precedence level has its own parsing function:
   - `parse_or_expr` - Lowest precedence, handles `or`
   - `parse_and_expr` - Handles `and`
   - `parse_comparison` - Handles `==`, `!=`, `<`, `<=`, `>`, `>=`
   - `parse_additive` - Handles `+`, `-`
   - `parse_multiplicative` - Handles `*`, `/`
   - `parse_unary` - Handles `-` (negation), `not`
   - `parse_postfix` - Handles `[]` array access, `()` function calls
   - `parse_primary` - Handles literals, identifiers, parenthesized expressions, function references

2. **Token type mapping** - Used actual lexer token names:
   - `TOKEN.EQUALS` (not `TOKEN.EQ`)
   - `TOKEN.NOT_EQUALS` (not `TOKEN.NE`)
   - `TOKEN.LESS`, `TOKEN.LESS_EQUALS`, `TOKEN.GREATER`, `TOKEN.GREATER_EQUALS`

3. **AST node structure** - Each expression type produces specific node:
   - `AST.BINARY_EXPR` with `operator`, `left`, `right`
   - `AST.UNARY_EXPR` with `operator`, `operand`
   - `AST.CALL_EXPR` with `callee`, `arguments`
   - `AST.ARRAY_ACCESS` with `array`, `index`
   - `AST.LITERAL` with `literal_type`, `value`
   - `AST.IDENTIFIER` with `name`
   - `AST.FUNCTION_REF` with `name`

4. **Left-associativity** - Binary operators associate left:
   - `a + b + c` parses as `(a + b) + c`
   - Achieved by using while loops that rebuild `left` with each iteration

5. **Right-associativity** - Unary operators associate right:
   - `--x` parses as `-(-x)`
   - Achieved by recursive call to `parse_unary` for operand

6. **Helper function** - `can_start_expression(state)` checks if current token can begin an expression (useful for optional expressions like in return statements)

### Test Coverage (64 tests)

- Literal parsing: integers, reals, strings, rawcodes, booleans, null
- Identifier parsing
- Binary operators: all arithmetic, comparison, and logical
- Unary operators: negation and `not`
- Operator precedence verification
- Left-associativity verification
- Complex nested expressions
- Parenthesized expressions
- Function calls: no args, single arg, multiple args
- Array access: simple and chained
- Function references
- Mixed postfix operations
- Expression starter detection
