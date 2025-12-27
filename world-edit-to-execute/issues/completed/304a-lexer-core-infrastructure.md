# Issue 304a: Lexer Core Infrastructure

**Phase:** 3 - Logic Layer
**Type:** Feature
**Priority:** High
**Parent:** 304-build-jass-lexer
**Dependencies:** 303-parse-war3map-j

---

## Current Behavior

No JASS lexer exists. The project can extract war3map.j content from MPQ archives
(via issue 303) but cannot process it into tokens for parsing.

---

## Intended Behavior

A core lexer module that provides:

1. **Token type definitions** - Complete enum of all JASS token types
2. **Main tokenization loop** - The `lexer.tokenize(source)` entry point
3. **Position tracking** - Line, column, and absolute position for each token
4. **Whitespace handling** - Consume spaces/tabs without emitting tokens
5. **Comment handling** - Strip or preserve `// ...` single-line comments
6. **Newline handling** - Emit NEWLINE tokens (JASS is newline-sensitive)
7. **EOF handling** - Emit EOF token at end of input

The core infrastructure provides the scanning framework that 304b (keywords/operators)
and 304c (literals) will plug into.

---

## Suggested Implementation Steps

1. **Create the jass directory and lexer module**
   ```
   src/jass/
   └── lexer.lua
   ```

2. **Define the complete TOKEN type table**
   ```lua
   -- {{{ TOKEN
   local TOKEN = {
       -- Keywords (to be used by 304b)
       FUNCTION = "FUNCTION",
       ENDFUNCTION = "ENDFUNCTION",
       TAKES = "TAKES",
       RETURNS = "RETURNS",
       NOTHING = "NOTHING",
       GLOBALS = "GLOBALS",
       ENDGLOBALS = "ENDGLOBALS",
       LOCAL = "LOCAL",
       SET = "SET",
       CALL = "CALL",
       IF = "IF",
       THEN = "THEN",
       ELSE = "ELSE",
       ELSEIF = "ELSEIF",
       ENDIF = "ENDIF",
       LOOP = "LOOP",
       ENDLOOP = "ENDLOOP",
       EXITWHEN = "EXITWHEN",
       RETURN = "RETURN",
       CONSTANT = "CONSTANT",
       NATIVE = "NATIVE",
       TYPE = "TYPE",
       EXTENDS = "EXTENDS",
       ARRAY = "ARRAY",
       AND = "AND",
       OR = "OR",
       NOT = "NOT",
       TRUE = "TRUE",
       FALSE = "FALSE",
       NULL = "NULL",

       -- Literals (to be used by 304c)
       INTEGER = "INTEGER",
       REAL = "REAL",
       STRING = "STRING",
       RAWCODE = "RAWCODE",

       -- Identifiers (to be used by 304b)
       IDENTIFIER = "IDENTIFIER",

       -- Operators (to be used by 304b)
       PLUS = "PLUS",
       MINUS = "MINUS",
       STAR = "STAR",
       SLASH = "SLASH",
       EQUALS = "EQUALS",
       NOT_EQUALS = "NOT_EQUALS",
       LESS = "LESS",
       LESS_EQUALS = "LESS_EQUALS",
       GREATER = "GREATER",
       GREATER_EQUALS = "GREATER_EQUALS",
       ASSIGN = "ASSIGN",

       -- Punctuation (to be used by 304b)
       LPAREN = "LPAREN",
       RPAREN = "RPAREN",
       LBRACKET = "LBRACKET",
       RBRACKET = "RBRACKET",
       COMMA = "COMMA",

       -- Special (handled by this issue)
       NEWLINE = "NEWLINE",
       COMMENT = "COMMENT",
       EOF = "EOF",
   }
   -- }}}
   ```

3. **Implement the lexer state structure**
   ```lua
   -- {{{ create_state
   local function create_state(source)
       return {
           source = source,
           pos = 1,           -- Current position in source (1-indexed)
           line = 1,          -- Current line number
           col = 1,           -- Current column number
           tokens = {},       -- Accumulated tokens
       }
   end
   -- }}}
   ```

4. **Implement position helper functions**
   ```lua
   -- {{{ peek
   local function peek(state, offset)
       -- Look at character at current position + offset (default 0)
       offset = offset or 0
       local pos = state.pos + offset
       if pos > #state.source then
           return nil
       end
       return state.source:sub(pos, pos)
   end
   -- }}}

   -- {{{ advance
   local function advance(state)
       -- Move forward one character, updating line/col tracking
       local char = peek(state)
       if char == "\n" then
           state.line = state.line + 1
           state.col = 1
       else
           state.col = state.col + 1
       end
       state.pos = state.pos + 1
       return char
   end
   -- }}}

   -- {{{ is_at_end
   local function is_at_end(state)
       return state.pos > #state.source
   end
   -- }}}
   ```

5. **Implement token creation helper**
   ```lua
   -- {{{ make_token
   local function make_token(type, value, start_line, start_col, end_pos, end_line, end_col)
       return {
           type = type,
           value = value,
           line = start_line,
           col = start_col,
           end_pos = end_pos,
           end_line = end_line,
           end_col = end_col,
       }
   end
   -- }}}

   -- {{{ add_token
   local function add_token(state, type, value, start_line, start_col)
       local token = make_token(
           type,
           value,
           start_line,
           start_col,
           state.pos,
           state.line,
           state.col
       )
       state.tokens[#state.tokens + 1] = token
       return token
   end
   -- }}}
   ```

6. **Implement whitespace consumption**
   ```lua
   -- {{{ skip_whitespace
   local function skip_whitespace(state)
       -- Consume spaces and tabs (NOT newlines - those are significant)
       while not is_at_end(state) do
           local char = peek(state)
           if char == " " or char == "\t" or char == "\r" then
               advance(state)
           else
               break
           end
       end
   end
   -- }}}
   ```

7. **Implement comment handling**
   ```lua
   -- {{{ scan_comment
   local function scan_comment(state)
       -- Called when we've seen "//" - consume rest of line
       local start_line = state.line
       local start_col = state.col - 2  -- Account for already-consumed "//"
       local content = {}

       while not is_at_end(state) and peek(state) ~= "\n" do
           content[#content + 1] = advance(state)
       end

       -- Option: emit COMMENT token or discard
       -- For now, emit it so we preserve source fidelity
       add_token(state, TOKEN.COMMENT, table.concat(content), start_line, start_col)
   end
   -- }}}
   ```

8. **Implement newline handling**
   ```lua
   -- {{{ scan_newline
   local function scan_newline(state)
       local start_line = state.line
       local start_col = state.col
       advance(state)  -- Consume the '\n'
       add_token(state, TOKEN.NEWLINE, "\n", start_line, start_col)
   end
   -- }}}
   ```

9. **Implement the main tokenization loop**
   ```lua
   -- {{{ tokenize
   function lexer.tokenize(source)
       local state = create_state(source)

       while not is_at_end(state) do
           skip_whitespace(state)

           if is_at_end(state) then
               break
           end

           local start_line = state.line
           local start_col = state.col
           local char = peek(state)

           if char == "\n" then
               scan_newline(state)

           elseif char == "/" and peek(state, 1) == "/" then
               advance(state)  -- consume first '/'
               advance(state)  -- consume second '/'
               scan_comment(state)

           else
               -- Delegate to scan_token (implemented by 304b, 304c)
               -- For now, stub that advances and reports unknown char
               local token = scan_token(state, start_line, start_col)
               if not token then
                   -- Unknown character - create error or skip
                   local unknown = advance(state)
                   error(string.format(
                       "Unexpected character '%s' at line %d, column %d",
                       unknown, start_line, start_col
                   ))
               end
           end
       end

       -- Add EOF token
       add_token(state, TOKEN.EOF, "", state.line, state.col)

       return state.tokens
   end
   -- }}}
   ```

10. **Create stub for scan_token (to be implemented by 304b, 304c)**
    ```lua
    -- {{{ scan_token
    local function scan_token(state, start_line, start_col)
        -- This function will dispatch to:
        -- - scan_identifier_or_keyword (304b)
        -- - scan_operator (304b)
        -- - scan_number (304c)
        -- - scan_string (304c)
        -- - scan_rawcode (304c)
        --
        -- For now, return nil to indicate unhandled
        -- The main loop will error on unknown characters
        return nil
    end
    -- }}}
    ```

11. **Export the module**
    ```lua
    -- {{{ module export
    local lexer = {}
    lexer.TOKEN = TOKEN

    -- Re-export helpers for sub-issues to use
    lexer._internal = {
        peek = peek,
        advance = advance,
        is_at_end = is_at_end,
        make_token = make_token,
        add_token = add_token,
        create_state = create_state,
    }

    return lexer
    -- }}}
    ```

---

## Technical Notes

### Why NEWLINE tokens matter

JASS uses newlines as statement terminators (no semicolons). The parser needs
to know where statements end:

```jass
set x = 1
set y = 2
```

Without NEWLINE tokens, the parser can't tell these are two statements.

### Comment preservation

Comments are emitted as COMMENT tokens rather than discarded. This enables:
- Source-to-source transformations that preserve comments
- Documentation extraction
- Round-trip parsing

If the parser doesn't need comments, it can filter them out.

### Error handling strategy

The lexer should fail fast with clear error messages including:
- The unexpected character
- Line and column number
- Enough context to locate the problem

This is preferable to silently skipping invalid input.

---

## Related Documents

- issues/304-build-jass-lexer.md (parent issue)
- issues/304b-lexer-keywords-identifiers-operators.md (sibling - uses this infrastructure)
- issues/304c-lexer-literals.md (sibling - uses this infrastructure)
- issues/304d-lexer-tests-validation.md (sibling - tests this code)
- issues/303-parse-war3map-j.md (provides input source)
- docs/roadmap.md (Phase 3 context)

---

## Acceptance Criteria

- [x] src/jass/lexer.lua exists with proper module structure
- [x] TOKEN table contains all token type definitions
- [x] Position tracking works correctly (line, column, absolute position)
- [x] Whitespace (spaces, tabs, carriage returns) is consumed without emitting tokens
- [x] Comments (`// ...`) are parsed and emitted as COMMENT tokens
- [x] Newlines emit NEWLINE tokens
- [x] EOF token is emitted at end of input
- [x] Unknown characters produce clear error messages with location
- [x] Internal helpers are exposed for use by 304b and 304c
- [x] Module follows project vimfold conventions

---

## Notes

This issue establishes the foundation. It should be implemented first, then 304b
and 304c can be developed in parallel since they both plug into this infrastructure.

The `scan_token` stub will be replaced with real implementations as 304b and 304c
are completed. The architecture should make this pluggable - perhaps via a dispatch
table based on the first character seen.

---

## Implementation Notes

**Completed:** 2025-12-27

### Files Created

- `src/jass/lexer.lua` - Core lexer module (210 lines)
- `src/tests/test_lexer_core.lua` - Test suite (28 tests)

### Implementation Details

1. **TOKEN table** - Contains 47 token type definitions covering keywords, operators,
   punctuation, literals, and special tokens. Values are self-referential strings
   for easy debugging.

2. **State structure** - Tracks source, position (1-indexed), line/column numbers,
   and accumulated tokens list.

3. **Position helpers** - `peek(state, offset)`, `advance(state)`, `is_at_end(state)`
   provide character access with automatic line/column tracking on newlines.

4. **Token creation** - `make_token()` and `add_token()` create tokens with full
   position information including start and end positions for error reporting.

5. **Whitespace handling** - `skip_whitespace()` consumes spaces, tabs, and carriage
   returns without emitting tokens. Newlines are NOT consumed here since JASS uses
   them as statement terminators.

6. **Comment handling** - `scan_comment()` captures everything after `//` until newline.
   Comments are emitted as COMMENT tokens to preserve source fidelity.

7. **Newline handling** - `scan_newline()` emits NEWLINE tokens which the parser
   uses to determine statement boundaries.

8. **Main loop** - `tokenize(source)` orchestrates the scanning, delegating to
   `scan_token()` for unrecognized characters (stub for 304b/304c).

9. **Error handling** - Unknown characters produce clear error messages with
   the character, line number, and column number.

10. **Internal exports** - `lexer._internal` exposes helper functions for use by
    304b (keywords/operators) and 304c (literals).

### Test Coverage

- Empty input and whitespace-only input
- Single and multiple newlines with position tracking
- Comments (single, multiple, empty, with position tracking)
- Whitespace consumption (spaces, tabs, carriage returns)
- Line/column tracking across newlines
- Error messages for unknown characters with correct positions
- Internal helper function behavior
- TOKEN table completeness
