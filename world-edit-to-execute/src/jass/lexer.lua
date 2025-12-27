--[[
JASS Lexer - Core Infrastructure

Tokenizes JASS source code into a stream of tokens for parsing.
Handles whitespace consumption, comment preservation, newline emission,
and position tracking. The scan_token function delegates to handlers
for keywords, operators, and literals (implemented in 304b and 304c).

JASS is newline-sensitive (no semicolons), so NEWLINE tokens are emitted
to allow the parser to determine statement boundaries.
]]

local lexer = {}

-- {{{ TOKEN
-- Complete token type definitions for the JASS language.
-- Keywords, operators, and literals will be recognized by scan_token handlers.
local TOKEN = {
    -- Keywords
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

    -- Literals (recognized by 304c)
    INTEGER = "INTEGER",
    REAL = "REAL",
    STRING = "STRING",
    RAWCODE = "RAWCODE",

    -- Identifiers (recognized by 304b)
    IDENTIFIER = "IDENTIFIER",

    -- Operators (recognized by 304b)
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

    -- Punctuation (recognized by 304b)
    LPAREN = "LPAREN",
    RPAREN = "RPAREN",
    LBRACKET = "LBRACKET",
    RBRACKET = "RBRACKET",
    COMMA = "COMMA",

    -- Special tokens (handled by this infrastructure)
    NEWLINE = "NEWLINE",
    COMMENT = "COMMENT",
    EOF = "EOF",
}
-- }}}

lexer.TOKEN = TOKEN

-- {{{ create_state
-- Creates a new lexer state for tokenizing source code.
-- The state tracks position, line/column numbers, and accumulated tokens.
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

-- {{{ peek
-- Look at character at current position + offset (default 0).
-- Returns nil if position is beyond end of source.
local function peek(state, offset)
    offset = offset or 0
    local pos = state.pos + offset
    if pos > #state.source then
        return nil
    end
    return state.source:sub(pos, pos)
end
-- }}}

-- {{{ advance
-- Move forward one character, updating line/col tracking.
-- Returns the consumed character.
local function advance(state)
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
-- Returns true if we've consumed all source characters.
local function is_at_end(state)
    return state.pos > #state.source
end
-- }}}

-- {{{ make_token
-- Creates a token with full position information.
-- Tokens include start position (line, col) and end position for error reporting.
local function make_token(type, value, start_line, start_col, end_line, end_col)
    return {
        type = type,
        value = value,
        line = start_line,
        col = start_col,
        end_line = end_line,
        end_col = end_col,
    }
end
-- }}}

-- {{{ add_token
-- Creates a token and appends it to the state's token list.
-- Uses current state position for end_line/end_col.
local function add_token(state, type, value, start_line, start_col)
    local token = make_token(
        type,
        value,
        start_line,
        start_col,
        state.line,
        state.col
    )
    state.tokens[#state.tokens + 1] = token
    return token
end
-- }}}

-- {{{ skip_whitespace
-- Consume spaces, tabs, and carriage returns without emitting tokens.
-- Newlines are NOT consumed here - they are significant in JASS.
local function skip_whitespace(state)
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

-- {{{ scan_comment
-- Called after we've seen "//" - consume rest of line as comment.
-- Comments are emitted as COMMENT tokens to preserve source fidelity.
local function scan_comment(state, start_line, start_col)
    local content = {}

    while not is_at_end(state) and peek(state) ~= "\n" do
        content[#content + 1] = advance(state)
    end

    add_token(state, TOKEN.COMMENT, table.concat(content), start_line, start_col)
end
-- }}}

-- {{{ scan_newline
-- Emit a NEWLINE token. JASS uses newlines as statement terminators.
local function scan_newline(state)
    local start_line = state.line
    local start_col = state.col
    advance(state)  -- Consume the '\n'
    add_token(state, TOKEN.NEWLINE, "\n", start_line, start_col)
end
-- }}}

-- {{{ scan_token
-- Dispatch function for recognizing tokens.
-- This is a stub that will be extended by 304b (keywords, identifiers, operators)
-- and 304c (literals: numbers, strings, rawcodes).
--
-- Returns true if a token was recognized, false otherwise.
-- The main loop will error on unrecognized characters.
local function scan_token(state, start_line, start_col)
    -- Placeholder: to be implemented by 304b and 304c
    -- Currently returns nil to indicate no token was recognized
    return nil
end
-- }}}

-- {{{ tokenize
-- Main entry point: tokenizes source code into a list of tokens.
-- Returns the token list on success, or throws an error on invalid input.
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
            scan_comment(state, start_line, start_col)

        else
            -- Delegate to scan_token (implemented by 304b, 304c)
            local token = scan_token(state, start_line, start_col)
            if not token then
                -- Unknown character - fail fast with clear error message
                local unknown = advance(state)
                error(string.format(
                    "Unexpected character '%s' at line %d, column %d",
                    unknown, start_line, start_col
                ))
            end
        end
    end

    -- Add EOF token at end of input
    add_token(state, TOKEN.EOF, "", state.line, state.col)

    return state.tokens
end
-- }}}

-- {{{ module export
-- Export internal helpers for use by 304b and 304c.
-- These sub-issues will extend scan_token functionality.
lexer._internal = {
    peek = peek,
    advance = advance,
    is_at_end = is_at_end,
    make_token = make_token,
    add_token = add_token,
    create_state = create_state,
    skip_whitespace = skip_whitespace,
}

return lexer
-- }}}
