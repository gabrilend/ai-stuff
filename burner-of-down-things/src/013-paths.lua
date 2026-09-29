-- 013-paths.lua
--
-- Where everything is. The machine is always run with one project folder
-- (DIR), and every other path it uses is built here from that folder, so no
-- module ever invents a path from a string of its own. Also sets the module
-- search path once, so the rest of the source can load itself and the shared
-- thread library by name.

local paths = {}

-- The shared Lua libraries of the monorepo. The thread library (effil) is
-- built for LuaJIT in its own build folder; the machine does not copy it.
local SHARED_LUA_LIBS = "/home/ritz/programming/ai-stuff/libs/lua"
local THREAD_LIBRARY_BUILD = SHARED_LUA_LIBS .. "/effil-jit/build"

-- The house tools the machine calls: the issue validator and the project
-- skeleton builder. Named here so a move of either is a one-line change.
local HOUSE_SCRIPTS = "/home/ritz/programming/ai-stuff/scripts"

-- {{{ local function require_absolute
local function require_absolute(dir)
    -- A relative DIR would make every path depend on where the machine was
    -- started from, which is exactly what DIR exists to prevent.
    if type(dir) ~= "string" or dir:sub(1, 1) ~= "/" then
        error("paths: the project folder must be an absolute path, got " .. tostring(dir))
    end
    -- A trailing slash would produce doubled slashes in every path built.
    return (dir:gsub("/+$", ""))
end
-- }}}

-- {{{ function paths.for_project
-- Returns the table of the project's own paths. Every value is absolute and
-- begins with DIR.
function paths.for_project(dir)
    dir = require_absolute(dir)
    return {
        dir = dir,
        src = dir .. "/src",
        tests = dir .. "/tests",
        fixtures = dir .. "/tests/fixtures",
        cases = dir .. "/cases",
        input = dir .. "/input",
        output = dir .. "/output",
        docs = dir .. "/docs",
        -- The studio's pool (docs/067, open question 13): kept in the
        -- project, outside git, until the owner decides otherwise.
        pool = dir .. "/pool",
        -- tmp/ points at /tmp/<project>; shared-memory/ inside it points at
        -- /dev/shm/<project>, which is where logs and throwaway artifacts go.
        scratch = dir .. "/tmp/shared-memory",
        exec_scratch = dir .. "/tmp/tmp",
        house_scripts = HOUSE_SCRIPTS,
        validate_issues = HOUSE_SCRIPTS .. "/validate-issues",
        init_project = "/mnt/mtwo/programming/ai-stuff/scripts/init-project.sh",
        skills = (os.getenv("HOME") or "/home/ritz") .. "/.claude/skills",
        thread_library_build = THREAD_LIBRARY_BUILD,
    }
end
-- }}}

-- {{{ function paths.set_search_path
-- Makes `require "013-paths"` style loading work from anywhere, and makes the
-- thread library loadable. Called once, by the entry point and by tests.
function paths.set_search_path(dir)
    dir = require_absolute(dir)
    package.path = dir .. "/src/?.lua;" .. dir .. "/libs/?.lua;" .. package.path
    package.cpath = THREAD_LIBRARY_BUILD .. "/?.so;" .. package.cpath
end
-- }}}

return paths
