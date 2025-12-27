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

-- {{{ KEYWORDS
-- Maps lowercase keyword strings to their token types.
-- JASS is case-sensitive: "function" is a keyword, "Function" is an identifier.
local KEYWORDS = {
    ["function"] = TOKEN.FUNCTION,
    ["endfunction"] = TOKEN.ENDFUNCTION,
    ["takes"] = TOKEN.TAKES,
    ["returns"] = TOKEN.RETURNS,
    ["nothing"] = TOKEN.NOTHING,
    ["globals"] = TOKEN.GLOBALS,
    ["endglobals"] = TOKEN.ENDGLOBALS,
    ["local"] = TOKEN.LOCAL,
    ["set"] = TOKEN.SET,
    ["call"] = TOKEN.CALL,
    ["if"] = TOKEN.IF,
    ["then"] = TOKEN.THEN,
    ["else"] = TOKEN.ELSE,
    ["elseif"] = TOKEN.ELSEIF,
    ["endif"] = TOKEN.ENDIF,
    ["loop"] = TOKEN.LOOP,
    ["endloop"] = TOKEN.ENDLOOP,
    ["exitwhen"] = TOKEN.EXITWHEN,
    ["return"] = TOKEN.RETURN,
    ["constant"] = TOKEN.CONSTANT,
    ["native"] = TOKEN.NATIVE,
    ["type"] = TOKEN.TYPE,
    ["extends"] = TOKEN.EXTENDS,
    ["array"] = TOKEN.ARRAY,
    ["and"] = TOKEN.AND,
    ["or"] = TOKEN.OR,
    ["not"] = TOKEN.NOT,
    ["true"] = TOKEN.TRUE,
    ["false"] = TOKEN.FALSE,
    ["null"] = TOKEN.NULL,
}
-- }}}

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

-- {{{ is_alpha
-- Returns true if character is a letter (A-Z, a-z) or underscore.
-- Used for identifying the start of identifiers and keywords.
local function is_alpha(char)
    if not char then return false end
    local b = string.byte(char)
    return (b >= 65 and b <= 90)   -- A-Z
        or (b >= 97 and b <= 122)  -- a-z
        or char == "_"
end
-- }}}

-- {{{ is_digit
-- Returns true if character is a decimal digit (0-9).
local function is_digit(char)
    if not char then return false end
    local b = string.byte(char)
    return b >= 48 and b <= 57  -- 0-9
end
-- }}}

-- {{{ is_alnum
-- Returns true if character is alphanumeric (letter, digit, or underscore).
-- Used for continuing identifiers after the first character.
local function is_alnum(char)
    return is_alpha(char) or is_digit(char)
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

-- {{{ scan_identifier_or_keyword
-- Scans an identifier or keyword starting at the current position.
-- Called when first character is a letter or underscore.
-- JASS is case-sensitive: "function" is a keyword, "Function" is an identifier.
local function scan_identifier_or_keyword(state, start_line, start_col)
    local chars = {}

    -- Collect all alphanumeric characters
    while not is_at_end(state) and is_alnum(peek(state)) do
        chars[#chars + 1] = advance(state)
    end

    local value = table.concat(chars)

    -- Check if it's a keyword (exact match, case-sensitive)
    local keyword_type = KEYWORDS[value]
    if keyword_type then
        add_token(state, keyword_type, value, start_line, start_col)
    else
        add_token(state, TOKEN.IDENTIFIER, value, start_line, start_col)
    end

    return true
end
-- }}}

-- {{{ scan_operator
-- Scans operators at the current position.
-- Two-character operators (==, !=, <=, >=) are checked before single-character.
-- Returns true if an operator was recognized, false otherwise.
local function scan_operator(state, start_line, start_col)
    local char = peek(state)
    local next_char = peek(state, 1)

    -- Two-character operators first (must check before single-char)
    if char == "=" and next_char == "=" then
        advance(state)
        advance(state)
        add_token(state, TOKEN.EQUALS, "==", start_line, start_col)
        return true
    end

    if char == "!" and next_char == "=" then
        advance(state)
        advance(state)
        add_token(state, TOKEN.NOT_EQUALS, "!=", start_line, start_col)
        return true
    end

    if char == "<" and next_char == "=" then
        advance(state)
        advance(state)
        add_token(state, TOKEN.LESS_EQUALS, "<=", start_line, start_col)
        return true
    end

    if char == ">" and next_char == "=" then
        advance(state)
        advance(state)
        add_token(state, TOKEN.GREATER_EQUALS, ">=", start_line, start_col)
        return true
    end

    -- Single-character operators
    -- Note: // is handled as comment in the main loop before scan_token is called
    local SINGLE_CHAR_OPS = {
        ["+"] = TOKEN.PLUS,
        ["-"] = TOKEN.MINUS,
        ["*"] = TOKEN.STAR,
        ["/"] = TOKEN.SLASH,
        ["="] = TOKEN.ASSIGN,
        ["<"] = TOKEN.LESS,
        [">"] = TOKEN.GREATER,
    }

    local op_type = SINGLE_CHAR_OPS[char]
    if op_type then
        advance(state)
        add_token(state, op_type, char, start_line, start_col)
        return true
    end

    return false
end
-- }}}

-- {{{ scan_punctuation
-- Scans punctuation at the current position.
-- Returns true if punctuation was recognized, false otherwise.
local function scan_punctuation(state, start_line, start_col)
    local char = peek(state)

    local PUNCTUATION = {
        ["("] = TOKEN.LPAREN,
        [")"] = TOKEN.RPAREN,
        ["["] = TOKEN.LBRACKET,
        ["]"] = TOKEN.RBRACKET,
        [","] = TOKEN.COMMA,
    }

    local punc_type = PUNCTUATION[char]
    if punc_type then
        advance(state)
        add_token(state, punc_type, char, start_line, start_col)
        return true
    end

    return false
end
-- }}}

-- {{{ scan_token
-- Dispatch function for recognizing tokens.
-- Delegates to specialized scanners for identifiers, operators, punctuation,
-- and literals (304c). Returns true if a token was recognized.
local function scan_token(state, start_line, start_col)
    local char = peek(state)

    -- Identifier or keyword (starts with letter or underscore)
    if is_alpha(char) then
        return scan_identifier_or_keyword(state, start_line, start_col)
    end

    -- Operators
    if scan_operator(state, start_line, start_col) then
        return true
    end

    -- Punctuation
    if scan_punctuation(state, start_line, start_col) then
        return true
    end

    -- Literals will be handled by 304c (numbers, strings, rawcodes)
    -- For now, these characters will fall through and trigger an error:
    -- - Digits (0-9) - integer/real literals
    -- - Double quote (") - string literals
    -- - Single quote (') - rawcode literals
    -- - Dollar sign ($) - hex literals

    return false
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
-- Export internal helpers for use by 304c (literals).
-- Character classification helpers are used for number parsing.
lexer._internal = {
    -- Core state functions
    peek = peek,
    advance = advance,
    is_at_end = is_at_end,
    make_token = make_token,
    add_token = add_token,
    create_state = create_state,
    skip_whitespace = skip_whitespace,
    -- Character classification (for 304c literal parsing)
    is_alpha = is_alpha,
    is_digit = is_digit,
    is_alnum = is_alnum,
}

return lexer
-- }}}
