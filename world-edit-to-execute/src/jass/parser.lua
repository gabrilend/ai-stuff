--[[
JASS Parser - Core Infrastructure

Provides the foundational infrastructure for parsing JASS token streams:
- Parser state management
- Token consumption and lookahead helpers
- Error reporting with source location
- Error recovery/synchronization
- AST node type constants and creation helpers

This module is used by the parsing sub-modules (declarations, statements,
expressions) to build the complete AST.
]]

local lexer = require("jass.lexer")
local TOKEN = lexer.TOKEN

local parser = {}

-- {{{ AST
-- AST node type constants for the entire parser.
-- All node types are defined here for consistency across sub-modules.
local AST = {
    -- Top-level constructs
    PROGRAM = "PROGRAM",           -- Root node containing all declarations
    TYPE_DEF = "TYPE_DEF",         -- type foo extends bar
    GLOBAL_BLOCK = "GLOBAL_BLOCK", -- globals ... endglobals
    VAR_DECL = "VAR_DECL",         -- Variable declaration (in globals or local)
    NATIVE_DECL = "NATIVE_DECL",   -- native foo takes ... returns ...
    FUNCTION_DEF = "FUNCTION_DEF", -- function foo takes ... returns ... endfunction

    -- Statements
    SET_STMT = "SET_STMT",         -- set x = expr / set arr[i] = expr
    CALL_STMT = "CALL_STMT",       -- call foo(args)
    IF_STMT = "IF_STMT",           -- if ... then ... elseif ... else ... endif
    LOOP_STMT = "LOOP_STMT",       -- loop ... endloop
    EXITWHEN_STMT = "EXITWHEN_STMT", -- exitwhen condition
    RETURN_STMT = "RETURN_STMT",   -- return / return expr
    LOCAL_DECL = "LOCAL_DECL",     -- local type name = expr

    -- Expressions
    BINARY_EXPR = "BINARY_EXPR",   -- a + b, a == b, a and b, etc.
    UNARY_EXPR = "UNARY_EXPR",     -- -x, not x
    CALL_EXPR = "CALL_EXPR",       -- foo(args) as expression
    ARRAY_ACCESS = "ARRAY_ACCESS", -- arr[index]
    IDENTIFIER = "IDENTIFIER",     -- Variable reference
    LITERAL = "LITERAL",           -- Integer, real, string, rawcode, true, false, null
    FUNCTION_REF = "FUNCTION_REF", -- function foo (function reference)
}
-- }}}

parser.AST = AST

-- {{{ create_state
-- Create parser state from token array.
-- The state tracks current position and accumulated errors.
-- @param tokens Array of tokens from lexer.tokenize()
-- @return Parser state table
local function create_state(tokens)
    return {
        tokens = tokens,
        pos = 1,
        errors = {},
    }
end
-- }}}

-- {{{ at_end
-- Check if we've consumed all tokens.
-- Returns true if position is beyond token array or current token is EOF.
local function at_end(state)
    return state.pos > #state.tokens or
           state.tokens[state.pos].type == TOKEN.EOF
end
-- }}}

-- {{{ peek
-- Look at current token without consuming it.
-- @return Current token
local function peek(state)
    return state.tokens[state.pos]
end
-- }}}

-- {{{ peek_next
-- Look at next token without consuming current.
-- Useful for two-token lookahead.
-- @return Next token, or nil if at end
local function peek_next(state)
    if state.pos + 1 > #state.tokens then
        return nil
    end
    return state.tokens[state.pos + 1]
end
-- }}}

-- {{{ previous
-- Get the most recently consumed token.
-- @return Previous token
local function previous(state)
    return state.tokens[state.pos - 1]
end
-- }}}

-- {{{ check
-- Check if current token matches type without consuming.
-- @param state Parser state
-- @param token_type Expected token type
-- @return true if current token matches
local function check(state, token_type)
    if at_end(state) then return false end
    return peek(state).type == token_type
end
-- }}}

-- {{{ check_any
-- Check if current token matches any of the given types.
-- @param state Parser state
-- @param ... Token types to check
-- @return true if current token matches any type
local function check_any(state, ...)
    local types = {...}
    for _, t in ipairs(types) do
        if check(state, t) then return true end
    end
    return false
end
-- }}}

-- {{{ advance
-- Consume and return current token.
-- Increments position if not at end.
-- @return The consumed token (now previous)
local function advance(state)
    if not at_end(state) then
        state.pos = state.pos + 1
    end
    return previous(state)
end
-- }}}

-- {{{ match
-- Consume token if it matches type, return success.
-- @param state Parser state
-- @param token_type Expected token type
-- @return true if token was consumed
local function match(state, token_type)
    if check(state, token_type) then
        advance(state)
        return true
    end
    return false
end
-- }}}

-- {{{ match_any
-- Consume token if it matches any of the given types.
-- @param state Parser state
-- @param ... Token types to match
-- @return true if a token was consumed
local function match_any(state, ...)
    local types = {...}
    for _, t in ipairs(types) do
        if check(state, t) then
            advance(state)
            return true
        end
    end
    return false
end
-- }}}

-- {{{ error_at
-- Report error at specific token.
-- Errors are accumulated in state.errors for later reporting.
-- @param state Parser state
-- @param token Token where error occurred
-- @param message Error description
local function error_at(state, token, message)
    local err = {
        message = message,
        line = token.line or 0,
        col = token.col or 0,
        token_type = token.type,
        token_value = token.value,
    }
    state.errors[#state.errors + 1] = err
end
-- }}}

-- {{{ error_at_current
-- Report error at current token position.
-- @param state Parser state
-- @param message Error description
local function error_at_current(state, message)
    error_at(state, peek(state), message)
end
-- }}}

-- {{{ error_at_previous
-- Report error at previously consumed token.
-- @param state Parser state
-- @param message Error description
local function error_at_previous(state, message)
    error_at(state, previous(state), message)
end
-- }}}

-- {{{ format_error
-- Format error for human-readable display.
-- @param err Error table from state.errors
-- @return Formatted error string
local function format_error(err)
    return string.format("Line %d, Column %d: %s",
        err.line, err.col, err.message)
end
-- }}}

-- {{{ consume
-- Consume token of expected type or report error.
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

-- {{{ synchronize
-- Skip tokens until we find a synchronization point.
-- Used to recover from parse errors and continue parsing.
-- Synchronization points are statement and declaration boundaries.
local function synchronize(state)
    advance(state)

    while not at_end(state) do
        -- Synchronize at declaration boundaries (top-level constructs)
        if check_any(state,
            TOKEN.TYPE,
            TOKEN.GLOBALS,
            TOKEN.ENDGLOBALS,
            TOKEN.NATIVE,
            TOKEN.CONSTANT,
            TOKEN.FUNCTION,
            TOKEN.ENDFUNCTION
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

-- {{{ skip_newlines
-- Skip any NEWLINE and COMMENT tokens.
-- JASS is newline-sensitive but for parsing we often want to skip them.
-- @param state Parser state
local function skip_newlines(state)
    while check_any(state, TOKEN.NEWLINE, TOKEN.COMMENT) do
        advance(state)
    end
end
-- }}}

-- {{{ make_node
-- Create an AST node with common fields.
-- @param node_type AST node type constant from AST table
-- @param token Source token for location info (optional)
-- @return New AST node table with type, line, col fields
local function make_node(node_type, token)
    return {
        type = node_type,
        line = token and token.line or 0,
        col = token and token.col or 0,
    }
end
-- }}}

-- {{{ has_errors
-- Check if any errors have been recorded.
-- @param state Parser state
-- @return true if state.errors is non-empty
local function has_errors(state)
    return #state.errors > 0
end
-- }}}

-- {{{ get_errors
-- Get formatted error messages.
-- @param state Parser state
-- @return Array of formatted error strings
local function get_errors(state)
    local result = {}
    for _, err in ipairs(state.errors) do
        result[#result + 1] = format_error(err)
    end
    return result
end
-- }}}

-- {{{ module export
parser.create_state = create_state

-- Token inspection
parser.at_end = at_end
parser.peek = peek
parser.peek_next = peek_next
parser.previous = previous
parser.check = check
parser.check_any = check_any

-- Token consumption
parser.advance = advance
parser.match = match
parser.match_any = match_any
parser.consume = consume

-- Error handling
parser.error_at = error_at
parser.error_at_current = error_at_current
parser.error_at_previous = error_at_previous
parser.format_error = format_error
parser.has_errors = has_errors
parser.get_errors = get_errors

-- Recovery
parser.synchronize = synchronize
parser.skip_newlines = skip_newlines

-- AST construction
parser.make_node = make_node

return parser
-- }}}
