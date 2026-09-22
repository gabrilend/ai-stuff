-- hook-gate.lua
--
-- The parts every Claude Code hook in this directory shares: reading the JSON
-- the harness sends on standard input, spending a one-time permission token,
-- printing a refusal, and announcing a warning.
--
-- How the harness reads a hook's answer (as of Claude Code 2.1.280):
--   exit 0 with nothing printed        -> no objection
--   exit 0 with JSON on standard out   -> the JSON is read; for a PreToolUse
--                                         hook, permissionDecision "deny"
--                                         refuses the command and the reason
--                                         goes to the model; systemMessage is
--                                         shown to the person as a warning
--   exit 2                             -> blocks the tool call (not used here)
--   any other exit                     -> a non-blocking error; the command
--                                         runs anyway
--
-- A gate that cannot read its input used to allow the command and say nothing.
-- The reason given was that a crashed gate would block every command -- but a
-- crash is a non-blocking error, so that was never true. Now the gate still
-- lets the command run (a gate that blocks everything when jq goes missing is
-- a gate that gets uninstalled), but it says so to the person every time, as a
-- systemMessage. A fallback that is announced is a warning; a fallback that is
-- silent was the bug.
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local gate = {}

-- {{{ function gate.load_json()
-- dkjson lives in the monorepo's shared Lua libraries. Its path comes from the
-- scripts directory, never from the current directory, since a hook runs from
-- wherever the session happens to be.
function gate.load_json(scripts_dir)
    local path = scripts_dir .. "/../libs/lua/dkjson.lua"
    local chunk, err = loadfile(path)
    if not chunk then return nil, "cannot load dkjson from " .. path .. ": " .. tostring(err) end
    return chunk()
end
-- }}}

-- {{{ local function json_escape()
-- Just enough JSON string escaping to announce a problem when dkjson itself is
-- what failed to load.
local function json_escape(s)
    return (s:gsub('[%c"\\]', function(c)
        local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }
        return named[c] or string.format("\\u%04x", c:byte())
    end))
end
-- }}}

-- {{{ function gate.warn_and_allow()
-- The announced fallback: the command runs, and the person is told this gate
-- did not look at it. Written to standard error too, for logs and tests.
function gate.warn_and_allow(gate_name, message)
    local text = gate_name .. ": " .. message .. " -- this command was NOT checked."
    io.stderr:write(text, "\n")
    io.stdout:write('{"systemMessage":"', json_escape(text), '"}\n')
    os.exit(0)
end
-- }}}

-- {{{ function gate.read_input()
-- Reads and decodes the hook input. Every way this can fail ends in an
-- announced warning, never in a silent pass.
function gate.read_input(gate_name, scripts_dir)
    local json, err = gate.load_json(scripts_dir)
    if not json then gate.warn_and_allow(gate_name, err) end
    local raw = io.read("*a")
    if not raw or raw == "" then gate.warn_and_allow(gate_name, "no hook input on standard input") end
    local input, _, decode_err = json.decode(raw)
    if type(input) ~= "table" then
        gate.warn_and_allow(gate_name, "hook input is not a JSON object (" .. tostring(decode_err) .. ")")
    end
    return input, json
end
-- }}}

-- {{{ function gate.pending_command()
-- The shell command a PreToolUse hook on Bash is being asked about.
function gate.pending_command(gate_name, input)
    local tool_input = input.tool_input
    if type(tool_input) ~= "table" or type(tool_input.command) ~= "string" then
        gate.warn_and_allow(gate_name, "hook input has no tool_input.command")
    end
    return tool_input.command
end
-- }}}

-- {{{ function gate.spend_token()
-- A person creates the token to allow one offending command. Spending it means
-- deleting it before standing aside, so a crash after this point still uses
-- the grant up -- the safe direction to fail. Returns true when a token was
-- there and is now gone; false when there was none; and nil plus a message
-- when it is there but cannot be removed (a non-empty directory, say), which
-- the caller treats as "no permission".
function gate.spend_token(token_path)
    local exists = os.rename(token_path, token_path)
    if not exists then return false end
    local removed, err = os.remove(token_path)
    if not removed then
        return nil, "the permission token " .. token_path .. " exists but could not be removed (" .. tostring(err) .. "), so it was not honoured"
    end
    return true
end
-- }}}

-- {{{ function gate.refuse()
-- Prints a PreToolUse refusal. The reason is written for the model: what was
-- wrong, why it matters, what to do instead, and how the person can lift the
-- refusal once.
function gate.refuse(json, reason)
    io.stdout:write(json.encode({
        hookSpecificOutput = {
            hookEventName = "PreToolUse",
            permissionDecision = "deny",
            permissionDecisionReason = reason,
        },
    }), "\n")
    os.exit(0)
end
-- }}}

-- {{{ function gate.refuse_unless_token()
-- The common ending: spend a token if the person left one, otherwise refuse.
function gate.refuse_unless_token(json, token_path, reason)
    local spent, token_problem = gate.spend_token(token_path)
    if spent then os.exit(0) end
    if token_problem then reason = reason .. " (" .. token_problem .. ")" end
    gate.refuse(json, reason)
end
-- }}}

-- {{{ function gate.shell_quote()
-- Quotes one word for /bin/sh, for the few gates that run git themselves.
function gate.shell_quote(word)
    return "'" .. word:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function gate.run()
-- Runs a command line and returns its standard output and whether it
-- succeeded. Standard error is folded into the output so a failure explains
-- itself.
function gate.run(argv)
    local quoted = {}
    for i, w in ipairs(argv) do quoted[i] = gate.shell_quote(w) end
    local handle = io.popen(table.concat(quoted, " ") .. " 2>&1", "r")
    local out = handle:read("*a")
    local ok, _, code = handle:close()
    -- LuaJIT's close returns true/nil; with 5.2 compat it also returns the code
    if ok == true or code == 0 then return out, true end
    return out, false
end
-- }}}

return gate
