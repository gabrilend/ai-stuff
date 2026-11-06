#!/usr/bin/env luajit
-- parser-coverage.lua - which files in the test maps the project can read
--
-- In plain terms: opens every test map in assets/ (or the maps named),
-- runs the project's parser on each file it has one for, and prints how
-- each kind of file fared across the maps: read, failed, not in the map, or
-- no parser yet. It reads the maps only; it writes nothing unless asked to
-- (--markdown FILE).
--
-- Usage:
--   luajit src/cli/parser-coverage.lua [--dir DIR] [options] [MAP ...]
--     -a, --all          every map in DIR/assets (the default when no MAP is named)
--     -m, --map FILE     this map (may be given more than once; MAP ... works too)
--     -f, --file KIND    only this kind of file ("war3map.w3e", "*.mdx"; more than once)
--     -v, --verbose      list every failure with its message
--     --matrix           the matrix alone
--     --json             JSON instead of text
--     --markdown FILE    also write the report as Markdown to FILE
--
-- Exit: 0 when no file failed, 1 when any failed or a map would not open,
-- 2 on a usage error or no maps.
--
-- Issue: issues/completed/A06-parser-coverage-report.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local coverage = require("data.parser_coverage")

-- {{{ local function usage(message)
local function usage(message)
    if message then io.stderr:write("parser-coverage: ", message, "\n") end
    io.stderr:write("usage: luajit src/cli/parser-coverage.lua [--dir DIR] [-a] [-m MAP] [-f KIND] [-v] [--matrix] [--json] [--markdown FILE] [MAP ...]\n")
    os.exit(2)
end
-- }}}

-- {{{ Arguments
local maps, kinds, opts = {}, nil, {}
local i = 1
while i <= #arg do
    local a = arg[i]
    if a == "-a" or a == "--all" then
        opts.all = true
    elseif a == "-m" or a == "--map" then
        i = i + 1
        if not arg[i] then usage(a .. " needs a map") end
        maps[#maps + 1] = arg[i]
    elseif a == "-f" or a == "--file" then
        i = i + 1
        if not arg[i] then usage(a .. " needs a kind of file") end
        kinds = kinds or {}
        kinds[arg[i]] = true
    elseif a == "-v" or a == "--verbose" then
        opts.verbose = true
    elseif a == "--matrix" then
        opts.matrix = true
    elseif a == "--json" then
        opts.json = true
    elseif a == "--markdown" then
        i = i + 1
        if not arg[i] then usage("--markdown needs a file") end
        opts.markdown = arg[i]
    elseif a == "-h" or a == "--help" then
        usage()
    elseif a:sub(1, 1) == "-" then
        usage("unknown option " .. a)
    else
        maps[#maps + 1] = a
    end
    i = i + 1
end

if opts.all or #maps == 0 then
    local p = io.popen('ls -1 "' .. DIR .. '/assets/"*.w3x "' .. DIR .. '/assets/"*.w3m 2>/dev/null')
    if p then
        for line in p:lines() do maps[#maps + 1] = line end
        p:close()
    end
end
if #maps == 0 then usage("no maps found in " .. DIR .. "/assets") end
-- }}}

local report = coverage.run(maps, { kinds = kinds })

if opts.json then
    io.write(coverage.json(report))
else
    print(coverage.text(report, { verbose = opts.verbose, matrix = opts.matrix }))
end
if opts.markdown then
    local f = assert(io.open(opts.markdown, "w"))
    f:write(coverage.markdown(report))
    f:close()
    if not opts.json then print("\nMarkdown report: " .. opts.markdown) end
end

os.exit((report.totals.failed > 0 or report.totals.maps_unopened > 0) and 1 or 0)
