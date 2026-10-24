-- script-help.lua: --help for every script, from the script's own header.
--
-- Every script opens with a comment saying what it is, how it works and how
-- to run it (a house rule), so that comment IS its help. A script calls
-- handle(arg) before it does anything else; given --help or -h, it prints the
-- header and exits, so asking for help never starts the work (asking
-- deploy-to-neocities for help used to start hashing the site and listing the
-- live one).
--
-- A script finds this file from its own folder, so it works from any
-- directory:
--   dofile(debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../libs/script-help.lua").handle(arg)

local M = {}

-- {{{ function M.header
-- The leading comment block of a file: after the "#!" line, every line that
-- is a comment ("--" or "#"), up to the first line that is not; fold markers
-- ("{{{", "}}}") left out, the comment marks and one space stripped.
-- path: the script's file; returns the text (string).
function M.header(path)
    local f = io.open(path, "r")
    if not f then error("script-help: cannot read " .. tostring(path)) end
    local lines, started = {}, false
    for line in f:lines() do
        if not started and line:match("^#!") then
            -- the interpreter line is not part of the help
        elseif line:match("^%s*%-%-") or line:match("^%s*#") then
            started = true
            local text = line:gsub("^%s*%-%-+ ?", ""):gsub("^%s*#+ ?", "")
            if not text:match("{{{") and not text:match("}}}") then
                lines[#lines + 1] = text
            end
        elseif started or line:match("%S") then
            break
        end
    end
    f:close()
    while lines[1] == "" do table.remove(lines, 1) end
    while lines[#lines] == "" do table.remove(lines) end
    if #lines == 0 then error("script-help: " .. path .. " has no header comment to show") end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function M.handle
-- Prints the calling script's header and exits 0 when its arguments hold
-- --help or -h; otherwise returns and the script carries on.
-- args: the script's arg table (arg[0] is the script's path).
function M.handle(args)
    for i = 1, #(args or {}) do
        if args[i] == "--help" or args[i] == "-h" then
            print(M.header(args[0]))
            os.exit(0)
        end
    end
end
-- }}}

return M
