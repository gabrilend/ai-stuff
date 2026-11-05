--[[
The Editor's Settings (Issue 913, step 1)

Where the programs Test Map runs live on this machine: W02's converter,
the local AzerothCore's servers and the W client. None of these places is
written in the code; they come from a settings file the owner keeps:

  $WETE_EDITOR_SETTINGS, else <project>/editor-settings.lua

a Lua data file returning a table (editor-settings.example.lua, beside
this project's README, lists every field; the file itself is not
committed, since it names this machine's folders and a test account).
It is read in an empty environment, so it can only hold data.

The test account's name and password:

  account    $W_CLIENT_ACCOUNT, else test_map.account
  password   $W_CLIENT_PASSWORD, else test_map.password

The password is never logged, never written to a file by the editor, and
never put on a command line: the W client is given it in its environment
as W_CLIENT_PASSWORD (proc.spawn's opts.env). Keeping it in the
environment rather than the settings file is the better habit.

    local settings = require("editor.settings")
    local s, why = settings.load(root)      -- the table, with defaults filled in
    s.test_map.server.programs[1].command   -- { "/path/to/authserver" }
]]

local settings = {}

settings.FILE = "editor-settings.lua"

-- {{{ defaults
-- nothing here names a place on any machine: a missing program is
-- reported when Test Map needs it
local function defaults()
    return {
        test_map = {
            convert = nil,           -- W02's converter: { program, args... }, run with <map> <build folder>
            convert_seconds = 600,
            build_dir = "tmp/test-map/build",      -- under the project's tmp/ (913 step 3)
            log_dir = "tmp/shared-memory/test-map",
            -- the W client's scripts/run (or a program taking the same
            -- arguments), not its binary: scripts/run adds the client's own
            -- --maps, --client, --settings, --world and --assets; Test Map
            -- adds the --test-map options after these words
            w_client = nil,          -- { program, args... }
            w_client_dir = nil,      -- where it runs (unset: the folder above scripts/, else the program's own)
            account = nil,
            password = nil,
            server = {
                host = "127.0.0.1",
                login_port = 3724,   -- the authserver's: what the W client logs in through
                start_seconds = 180, -- the longest to wait for every program's port
                stop_seconds = 20,   -- TERM, then KILL after this long
                programs = {},       -- { name, command = { program, args... }, dir, port }
            },
        },
    }
end
-- }}}

-- {{{ merging what the file gives over the defaults
local function merge(into, from)
    for k, v in pairs(from) do
        if type(v) == "table" and type(into[k]) == "table" and #v == 0 and next(v) ~= nil then
            merge(into[k], v)
        else
            into[k] = v
        end
    end
    return into
end
-- }}}

-- {{{ settings.read: the file alone, as data
function settings.read(path)
    local f = io.open(path, "r")
    if not f then return nil, "no settings file " .. path end
    local text = f:read("*a")
    f:close()
    local env = {}
    local chunk, err
    if setfenv then
        chunk, err = loadstring(text, "=" .. path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = load(text, "=" .. path, "t", env)
    end
    if not chunk then return nil, err end
    local ok, t = pcall(chunk)
    if not ok then return nil, t end
    if type(t) ~= "table" then return nil, path .. " doesn't return a table" end
    return t
end
-- }}}

-- {{{ settings.load
-- opts.path: a settings file; opts.env: a getenv to use instead of os.getenv
function settings.load(root, opts)
    opts = opts or {}
    root = root or "."
    local getenv = opts.getenv or os.getenv
    local path = opts.path or getenv("WETE_EDITOR_SETTINGS") or (root .. "/" .. settings.FILE)
    local s = defaults()
    local t, why = settings.read(path)
    if t then merge(s, t) end
    s.path, s.found = path, t ~= nil
    s.why = not t and why or nil
    local tm = s.test_map
    -- empty counts as unset (the W client takes an empty password as none)
    local function given(v) if v ~= nil and v ~= "" then return v end end
    tm.account = given(getenv("W_CLIENT_ACCOUNT")) or given(tm.account)
    tm.password = given(getenv("W_CLIENT_PASSWORD")) or given(tm.password)
    -- folders under the project, when given relative
    local function under(p)
        if type(p) ~= "string" or p:sub(1, 1) == "/" then return p end
        return root .. "/" .. p
    end
    tm.build_dir, tm.log_dir = under(tm.build_dir), under(tm.log_dir)
    if type(tm.convert) == "string" then tm.convert = { tm.convert } end
    if type(tm.w_client) == "string" then tm.w_client = { tm.w_client } end
    for _, p in ipairs(tm.server.programs or {}) do
        if type(p.command) == "string" then p.command = { p.command } end
    end
    return s
end
-- }}}

return settings
