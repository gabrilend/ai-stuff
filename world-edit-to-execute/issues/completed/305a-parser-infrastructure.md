# Issue 305a: Parser Infrastructure

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Dependencies:** 304-build-jass-lexer
**Parent Issue:** 305-build-jass-parser

---

## Current Behavior

The JASS lexer (304) produces a token stream, but there is no parser infrastructure
to consume tokens and build an AST. No state management, error handling, or token
consumption helpers exist.

---

## Intended Behavior

Create the foundational parser module with:
- Parser state structure for tracking position and errors
- Token consumption and lookahead helpers
- Error reporting with source location information
- Error recovery/synchronization for multiple error reporting
- AST node type constants for the entire parser

```lua
local parser = require("jass.parser")

-- Create parser state from lexer output
local tokens = lexer.tokenize(source)
local state = parser.create_state(tokens)

-- Use helpers
if parser.check(state, TOKEN.FUNCTION) then
    parser.advance(state)
end

-- Error handling
parser.error_at_current(state, "Expected function name")
```

---

## Suggested Implementation Steps

1. **Create parser module file**
   ```
   src/jass/
   ├── lexer.lua      (from 304)
   └── parser.lua     (this issue)
   ```

2. **Define AST node type constants**
   ```lua
   -- All node types used across the parser
   -- Defined here so sub-issues can reference them
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

3. **Implement parser state creation**
   ```lua
   -- {{{ create_state
   -- Create parser state from token array
   -- @param tokens Array of tokens from lexer
   -- @return Parser state table
   local function create_state(tokens)
       return {
           tokens = tokens,
           pos = 1,
           errors = {},
       }
   end
   -- }}}
   ```

4. **Implement token inspection helpers**
   ```lua
   -- {{{ at_end
   -- Check if we've consumed all tokens
   local function at_end(state)
       return state.pos > #state.tokens or
              state.tokens[state.pos].type == TOKEN.EOF
   end
   -- }}}

   -- {{{ peek
   -- Look at current token without consuming
   local function peek(state)
       return state.tokens[state.pos]
   end
   -- }}}

   -- {{{ previous
   -- Get the most recently consumed token
   local function previous(state)
       return state.tokens[state.pos - 1]
   end
   -- }}}

   -- {{{ check
   -- Check if current token matches type (without consuming)
   local function check(state, token_type)
       if at_end(state) then return false end
       return peek(state).type == token_type
   end
   -- }}}

   -- {{{ check_any
   -- Check if current token matches any of the given types
   local function check_any(state, ...)
       local types = {...}
       for _, t in ipairs(types) do
           if check(state, t) then return true end
       end
       return false
   end
   -- }}}
   ```

5. **Implement token consumption helpers**
   ```lua
   -- {{{ advance
   -- Consume and return current token
   local function advance(state)
       if not at_end(state) then
           state.pos = state.pos + 1
       end
       return previous(state)
   end
   -- }}}

   -- {{{ match
   -- Consume token if it matches type, return true/false
   local function match(state, token_type)
       if check(state, token_type) then
           advance(state)
           return true
       end
       return false
   end
   -- }}}

   -- {{{ consume
   -- Consume token of expected type or report error
   -- @param state Parser state
   -- @param token_type Expected token type
   -- @param message Error message if mismatch
   -- @return The consumed token, or nil on error
   local function consume(state, token_type, message)
       if check(state, token_type) then
           return advance(state)
       end
       error_at_current(state, message or ("Expected " .. token_type))
       return nil
   end
   -- }}}
   ```

6. **Implement error reporting**
   ```lua
   -- {{{ error_at
   -- Report error at specific token
   -- @param state Parser state
   -- @param token Token where error occurred
   -- @param message Error description
   local function error_at(state, token, message)
       local err = {
           message = message,
           line = token.line or 0,
           column = token.column or 0,
           token_type = token.type,
           token_value = token.value,
       }
       state.errors[#state.errors + 1] = err
   end
   -- }}}

   -- {{{ error_at_current
   -- Report error at current token position
   local function error_at_current(state, message)
       error_at(state, peek(state), message)
   end
   -- }}}

   -- {{{ error_at_previous
   -- Report error at previously consumed token
   local function error_at_previous(state, message)
       error_at(state, previous(state), message)
   end
   -- }}}

   -- {{{ format_error
   -- Format error for display
   local function format_error(err)
       return string.format("Line %d, Column %d: %s",
           err.line, err.column, err.message)
   end
   -- }}}
   ```

7. **Implement error recovery/synchronization**
   ```lua
   -- {{{ synchronize
   -- Skip tokens until we find a synchronization point
   -- Used to recover from parse errors and continue parsing
   local function synchronize(state)
       advance(state)

       while not at_end(state) do
           -- Previous token ended a statement
           -- (JASS doesn't use semicolons, so we sync on keywords)

           -- Synchronize at declaration boundaries
           if check_any(state,
               TOKEN.TYPE,
               TOKEN.GLOBALS,
               TOKEN.NATIVE,
               TOKEN.CONSTANT,
               TOKEN.FUNCTION,
               TOKEN.ENDFUNCTION,
               TOKEN.ENDGLOBALS
           ) then
               return
           end

           -- Synchronize at statement boundaries
           if check_any(state,
               TOKEN.SET,
               TOKEN.CALL,
               TOKEN.IF,
               TOKEN.ENDIF,
               TOKEN.ELSEIF,
               TOKEN.ELSE,
               TOKEN.LOOP,
               TOKEN.ENDLOOP,
               TOKEN.EXITWHEN,
               TOKEN.RETURN,
               TOKEN.LOCAL
           ) then
               return
           end

           advance(state)
       end
   end
   -- }}}
   ```

8. **Implement helper for AST node creation**
   ```lua
   -- {{{ make_node
   -- Create an AST node with common fields
   -- @param node_type AST node type constant
   -- @param token Source token for location info
   -- @return New AST node table
   local function make_node(node_type, token)
       return {
           type = node_type,
           line = token and token.line or 0,
           column = token and token.column or 0,
       }
   end
   -- }}}
   ```

9. **Export module interface**
   ```lua
   -- {{{ Module exports
   return {
       -- AST node types
       AST = AST,

       -- State management
       create_state = create_state,

       -- Token inspection
       at_end = at_end,
       peek = peek,
       previous = previous,
       check = check,
       check_any = check_any,

       -- Token consumption
       advance = advance,
       match = match,
       consume = consume,

       -- Error handling
       error_at = error_at,
       error_at_current = error_at_current,
       error_at_previous = error_at_previous,
       format_error = format_error,

       -- Recovery
       synchronize = synchronize,

       -- AST construction
       make_node = make_node,
   }
   -- }}}
   ```

---

## Technical Notes

### Token Type Reference

The parser depends on token types from the lexer (304). Expected token types include:
- Keywords: FUNCTION, ENDFUNCTION, TAKES, RETURNS, NOTHING, LOCAL, SET, CALL, IF, THEN, ELSEIF, ELSE, ENDIF, LOOP, ENDLOOP, EXITWHEN, RETURN, TYPE, EXTENDS, GLOBALS, ENDGLOBALS, NATIVE, CONSTANT, ARRAY, AND, OR, NOT, TRUE, FALSE, NULL
- Literals: INTEGER, REAL, STRING, RAWCODE
- Operators: PLUS, MINUS, STAR, SLASH, EQ, NE, LT, LE, GT, GE, ASSIGN
- Punctuation: LPAREN, RPAREN, LBRACKET, RBRACKET, COMMA
- Other: IDENTIFIER, NEWLINE, COMMENT, EOF

### Error Recovery Strategy

JASS has clear statement and declaration boundaries without semicolons.
The synchronize function skips to the next keyword that starts a new
construct, allowing the parser to report multiple errors in one pass.

### State Immutability

Parser state is intentionally mutable. Each parse function modifies
`state.pos` as it consumes tokens. This is simpler than a pure functional
approach and matches the imperative style of JASS itself.

---

## Related Documents

- issues/304-build-jass-lexer.md (provides token stream)
- issues/305-build-jass-parser.md (parent issue)
- issues/305b-parse-declarations.md (uses this infrastructure)
- issues/305c-parse-expressions.md (uses this infrastructure)
- issues/305d-parse-statements.md (uses this infrastructure)

---

## Acceptance Criteria

- [x] Parser module created at src/jass/parser.lua
- [x] AST node type constants defined for all node types
- [x] create_state() creates valid parser state from token array
- [x] at_end() correctly detects end of token stream
- [x] peek() returns current token without advancing
- [x] previous() returns last consumed token
- [x] check() and check_any() test token types without consuming
- [x] advance() consumes and returns current token
- [x] match() conditionally consumes matching tokens
- [x] consume() enforces expected token type with error on mismatch
- [x] error_at(), error_at_current(), error_at_previous() record errors with location
- [x] format_error() produces human-readable error messages
- [x] synchronize() skips to next statement/declaration boundary
- [x] make_node() creates AST nodes with location info
- [x] All functions use vimfold markers per project conventions
- [x] Unit tests verify each helper function

---

## Notes

This sub-issue establishes the foundation that all other parser sub-issues
depend on. The helpers should be well-tested before proceeding to actual
parsing, as bugs here will cascade through the entire parser.

The TOKEN constants should be imported from the lexer module to ensure
consistency. If the lexer doesn't export them, this issue should add
that export as part of integration.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

- `src/jass/parser.lua` - Parser infrastructure module (280 lines)
- `src/tests/test_parser_infra.lua` - Test suite (56 tests)

### Implementation Details

1. **AST node types** - 14 node types defined covering:
   - Top-level: PROGRAM, TYPE_DEF, GLOBAL_BLOCK, VAR_DECL, NATIVE_DECL, FUNCTION_DEF
   - Statements: SET_STMT, CALL_STMT, IF_STMT, LOOP_STMT, EXITWHEN_STMT, RETURN_STMT, LOCAL_DECL
   - Expressions: BINARY_EXPR, UNARY_EXPR, CALL_EXPR, ARRAY_ACCESS, IDENTIFIER, LITERAL, FUNCTION_REF

2. **State management** - `create_state(tokens)` creates parser state with:
   - tokens: Array from lexer.tokenize()
   - pos: Current position (1-indexed)
   - errors: Accumulated parse errors

3. **Token inspection**
   - `at_end()` - Checks for EOF or position beyond tokens
   - `peek()` - Returns current token
   - `peek_next()` - Returns next token (two-token lookahead)
   - `previous()` - Returns last consumed token
   - `check(type)` - Tests current token type
   - `check_any(...)` - Tests against multiple types

4. **Token consumption**
   - `advance()` - Consumes and returns current token
   - `match(type)` - Conditionally consumes if type matches
   - `match_any(...)` - Matches against multiple types
   - `consume(type, msg)` - Enforces type or records error

5. **Error handling**
   - `error_at(token, msg)` - Records error at specific token
   - `error_at_current(msg)` - Records at current position
   - `error_at_previous(msg)` - Records at previous position
   - `format_error(err)` - Produces "Line X, Column Y: message"
   - `has_errors()` - Checks if errors exist
   - `get_errors()` - Returns formatted error array

6. **Recovery**
   - `synchronize()` - Skips to next statement/declaration boundary
   - `skip_newlines()` - Skips NEWLINE and COMMENT tokens

7. **AST construction**
   - `make_node(type, token)` - Creates node with type and location

### Additional Features Beyond Spec

- `peek_next()` for two-token lookahead (useful for distinguishing constructs)
- `match_any()` for matching multiple types in one call
- `skip_newlines()` for handling JASS's newline-sensitivity
- `has_errors()` and `get_errors()` convenience methods

### Test Coverage (56 tests)

- AST node type definitions
- State creation and management
- All token inspection functions
- All token consumption functions
- Error recording with location info
- Error formatting
- Synchronization to various keywords
- Newline/comment skipping
- Integration scenarios (parse patterns, error recovery)
