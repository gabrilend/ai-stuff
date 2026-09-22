-- ensure-ram-tiers.lua - the RAM scratch tiers, for Lua programs.
--
-- In plain terms: a Lua program that is about to write logs or build output into
-- its project's tmp/ folder calls this first, and the folder is guaranteed to be
-- there, even straight after a reboot erased it. It does not know how the tiers
-- are laid out; it asks the bash library `ensure-ram-tiers` next to it, which is
-- the one place that layout is written down. Two copies of the layout would drift,
-- which is how the tiers came to need rebuilding in the first place.
--
--   local tiers = dofile(DIR .. "/libs/ensure-ram-tiers.lua")
--   tiers.ensure(project_dir)     -- tools about to write into tmp/
--   tiers.restore(project_dir)    -- repair behind an existing tmp link only
--
-- Both raise a Lua error carrying the library's own message when it refuses.
-- LuaJIT-compatible: no 5.2+ features, and os.execute is not relied on for exit
-- codes, since LuaJIT and 5.2 report them differently.

-- {{{ local DIR
-- Where the scripts live. Overridable per call, for a checkout somewhere else.
local DIR = "/mnt/mtwo/programming/ai-stuff/scripts"
-- }}}

local M = {}

-- {{{ local function shell_quote()
-- Wraps text in single quotes for sh, turning each ' into '\'' so a folder name
-- containing a quote cannot end the argument early.
local function shell_quote(text)
    return "'" .. string.gsub(text, "'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function run_library()
-- Runs the bash library in one mode and turns a refusal into a Lua error.
--
-- The exit status is recovered by printing it after the command, because
-- io.popen():close() under LuaJIT returns true whatever happened. Standard error
-- is merged into the captured text so the refusal reaches the error message
-- instead of scrolling past on the terminal.
local function run_library(mode_flag, project_dir, scripts_dir)
    if type(project_dir) ~= "string" or project_dir == "" then
        error("ensure-ram-tiers: no project folder was named", 3)
    end
    local library = (scripts_dir or DIR) .. "/libs/ensure-ram-tiers"
    local command = "bash " .. shell_quote(library) .. " " .. mode_flag .. " "
        .. shell_quote(project_dir) .. " 2>&1; printf '\\n%s' \"$?\""
    local pipe = io.popen(command, "r")
    local output = pipe:read("*a")
    pipe:close()

    -- The last line is the exit status; everything before it is what was said.
    local said, status = string.match(output, "^(.-)\n?(%d+)$")
    if status == nil then
        error("ensure-ram-tiers: could not read the library's exit status: " .. output, 3)
    end
    if status ~= "0" then
        error(said ~= "" and said or ("ensure-ram-tiers: exited " .. status), 3)
    end
end
-- }}}

-- {{{ function M.ensure()
function M.ensure(project_dir, scripts_dir)
    run_library("--ensure", project_dir, scripts_dir)
end
-- }}}

-- {{{ function M.restore()
function M.restore(project_dir, scripts_dir)
    run_library("--restore", project_dir, scripts_dir)
end
-- }}}

return M
