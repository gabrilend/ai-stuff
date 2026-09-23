-- {{{ effil-loader.lua
-- The one place that knows where the threading library (effil) lives and how
-- to load it.
--
-- effil is a compiled C library, so Lua finds it through package.cpath (the
-- search path for .so files), not package.path.  It is built outside this
-- project, so its folder has to be added by hand.  Two places need to load it:
-- the HTML generator, which runs its page workers on it, and run.sh's
-- pre-flight gate (issue 10-069), which tries loading it before a build starts
-- so a broken library stops the run in the first seconds instead of hours in.
-- Both read the path from here, so the check always tests the same file the
-- generator will load.
-- }}}

local M = {}

-- {{{ M.CPATH_ENTRY
-- Where the LuaJIT build of effil is compiled to.  "?" is Lua's placeholder
-- for the module name, so this matches .../build/effil.so.
M.CPATH_ENTRY = "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so"
-- }}}

-- {{{ function M.try_load
-- Adds the effil folder to the C search path (once) and requires the library.
--
-- cpath_entry : optional string, a different "?.so" pattern to search instead
--               of M.CPATH_ENTRY.  Only the tests pass one, to prove that a
--               library that cannot be found is reported rather than skipped.
-- returns     : effil (table) on success; or nil and an error message (string).
function M.try_load(cpath_entry)
    local entry = cpath_entry or M.CPATH_ENTRY
    if not package.cpath:find(entry, 1, true) then
        package.cpath = package.cpath .. ";" .. entry
    end
    local ok, result = pcall(require, "effil")
    if ok then
        return result
    end
    return nil, tostring(result)
end
-- }}}

return M
