-- {{{ runtime-overrides.lua
-- One run's command-line choices, materialized to a file in RAM so that every
-- short-lived child process of run.sh resolves them identically.
--
-- General description (for a CEO): run.sh launches a brand-new little program for
-- each stage of the pipeline and shuts it down before the next. A choice the
-- operator typed once -- "use THIS embedding model" -- only reached the stages
-- run.sh happened to hand it to; the others quietly fell back to the default
-- written in the config file. This module is a shared notepad in fast memory:
-- run.sh writes the run's choices on it once at the start, and every stage reads
-- the same note. It is rewritten from scratch on every run, so yesterday's note
-- can never be mistaken for today's. An empty note (or a missing key) means "the
-- operator chose nothing special here" -- so readers fall back to config.lua,
-- exactly as before.
--
-- Format: a Lua file that returns a table, read back via dofile -- the same
-- mechanism config.lua itself uses -- so there is no JSON dependency to carry.
-- Why this design over an environment variable: an env var dies with the shell
-- and reaches only children run.sh explicitly exports it to; a file is readable
-- from any process, any working directory, and is inspectable with `cat`. The
-- one hazard a file has and an env var does not -- staleness across runs -- is
-- removed by run.sh overwriting it at startup (see scripts/write-run-overrides).
-- }}}

local M = {}

-- {{{ Module state
-- project_root: where tmp/ (and thus the notepad) lives. cache/loaded: the
-- decoded table is read from disk at most once per process, then reused.
local project_root = nil
local cache = nil
local loaded = false
-- }}}

-- {{{ local function resolve_root()
-- Resolve the project root: an explicit set_project_root wins; otherwise infer
-- it from package.path (the "/libs/?.lua" entry every caller installs), and only
-- then fall back to the hard-coded path so a stray direct invocation still works.
local function resolve_root()
    if project_root then return project_root end
    local path = package.path:match("([^;]+)/libs/%?%.lua")
    project_root = path or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    return project_root
end
-- }}}

-- {{{ function M.set_project_root(path)
-- Idempotent: re-setting the same root is a no-op so callers can set it on every
-- access without throwing away the per-process cache (and re-reading the file).
function M.set_project_root(path)
    if path == project_root then return end
    project_root = path
    cache = nil
    loaded = false
end
-- }}}

-- {{{ function M.path()
-- The notepad lives in tmp/shared-memory/ (the /dev/shm RAM tier): wiped on
-- reboot -- exactly right, since one run's choices have no meaning after that
-- run ends. It is data, not code, so the noexec shared-memory tier is the right
-- home; Lua loadfile reads it as text, which noexec permits.
function M.path()
    return resolve_root() .. "/tmp/shared-memory/run-overrides.lua"
end
-- }}}

-- {{{ local function serialize_value(value)
-- Only the scalar kinds a CLI flag can carry are supported. Anything else is a
-- programming error at the call site, so we error loudly rather than emit a file
-- that would dofile() into something surprising.
local function serialize_value(value)
    local kind = type(value)
    if kind == "string" then
        return string.format("%q", value)
    elseif kind == "number" or kind == "boolean" then
        return tostring(value)
    end
    error("runtime-overrides: cannot serialize a value of type " .. kind)
end
-- }}}

-- {{{ function M.write(overrides)
-- Overwrite the notepad with exactly THIS run's overrides. Called once by run.sh
-- at startup, so the file is never older than the current run -- a previous
-- run's --model cannot survive into one that omits it. An empty table is a valid,
-- meaningful result ("return {}"): a present-but-empty notepad says "this run set
-- nothing special", and every reader then falls back to config.lua.
--
-- The tmp/shared-memory/ directory (the /dev/shm RAM tier, wiped on reboot) must already exist;
-- run.sh creates it just before calling the writer. If it does not, io.open
-- returns nil and we error loudly rather than silently lose the note -- a missing
-- notepad would reintroduce exactly the config-fallback bug this module fixes.
function M.write(overrides)
    overrides = overrides or {}
    local lines = {}
    for key, value in pairs(overrides) do
        lines[#lines + 1] = string.format("    [%q] = %s,", key, serialize_value(value))
    end
    local body = table.concat({
        "-- Auto-generated per run by run.sh (scripts/write-run-overrides).",
        "-- This run's command-line choices, so every stage resolves them the same",
        "-- way. Overwritten every run; safe to delete (the next run rewrites it).",
        "return {",
        table.concat(lines, "\n"),
        "}",
        "",
    }, "\n")

    local file, err = io.open(M.path(), "w")
    if not file then
        error("runtime-overrides: cannot write " .. M.path() .. ": " .. tostring(err))
    end
    file:write(body)
    file:close()

    -- Refresh the in-process view so a writer that also reads sees its own write.
    loaded = false
    cache = nil
end
-- }}}

-- {{{ local function load()
-- Read + decode the notepad at most once per process. A missing file (no run.sh
-- wrote one -- e.g. a stage launched by hand) or a malformed one both resolve to
-- an empty table, i.e. "no overrides", which is the safe, config-default answer.
local function load()
    if loaded then return cache end
    loaded = true
    local ok, result = pcall(dofile, M.path())
    if ok and type(result) == "table" then
        cache = result
    else
        cache = {}
    end
    return cache
end
-- }}}

-- {{{ function M.get(key)
-- Return the override for key, or nil when it was not set. An empty string is
-- treated as "not set" so run.sh can pass `--model ""` (no override) without the
-- writer needing to special-case it.
function M.get(key)
    local value = load()[key]
    if value == nil or value == "" then return nil end
    return value
end
-- }}}

-- {{{ function M.all()
-- The whole decoded table, for callers that want to inspect every override.
function M.all()
    return load()
end
-- }}}

return M
