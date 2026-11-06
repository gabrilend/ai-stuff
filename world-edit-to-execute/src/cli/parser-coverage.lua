#!/usr/bin/env luajit
-- parser-coverage.lua - which files in the test maps the project can read, and whether it does
--
-- In plain terms: opens every map in assets/ (or the ones named), lists
-- every file inside each, and runs the project's reader for that kind of
-- file on it. The report says, for each kind of file, how many maps hold
-- one and how many of those it read without an error; which kinds have no
-- reader yet; and a matrix of map against kind. Printed as a table, or
-- written as Markdown or JSON.
--
-- Usage:
--   luajit src/cli/parser-coverage.lua [--dir DIR] [options]
--
--   --dir DIR           project root (default: the path below)
--   -m, --map FILE      one map (repeatable); default every .w3x/.w3m in assets/
--   -f, --file KIND     only this kind of file (repeatable), e.g. war3map.w3e or *.blp
--   -v, --verbose       print each failure's error, and per-kind read times
--   --matrix            print only the matrix (Markdown)
--   --json              print the whole report as JSON
--   --markdown FILE     also write the report as Markdown to FILE
--   -h, --help
--
-- Kinds: a map's own data files by name (war3map.w3i ...), every other
-- file by extension (*.blp, *.mdx ...). Files the archive holds without a
-- name (StormLib calls them File00000041.xxx) are given a kind by their
-- first bytes when those are an MDX, BLP or TGA signature, else by
-- StormLib's guessed extension.
--
-- Issue: issues/completed/A06-parser-coverage-report.md

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if arg and arg[1] == "--dir" then
    DIR = arg[2]
    table.remove(arg, 1)
    table.remove(arg, 1)
end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local M = {}

-- {{{ Readers
-- How each kind of file is read: the module and the function to call.
-- A function that raises, or returns nil (and maybe a message), failed.
M.READERS = {
    ["war3map.w3i"] = { "parsers.w3i", "parse" },
    ["war3map.wts"] = { "parsers.wts", "parse" },
    ["war3map.w3e"] = { "parsers.w3e", "parse" },
    ["war3map.doo"] = { "parsers.doo", "parse" },
    ["war3mapunits.doo"] = { "parsers.unitsdoo", "parse" },
    ["war3map.w3r"] = { "parsers.w3r", "parse" },
    ["war3map.w3c"] = { "parsers.w3c", "parse" },
    ["war3map.w3s"] = { "parsers.w3s", "parse" },
    ["war3map.wtg"] = { "parsers.wtg", "parse" },
    ["war3map.wct"] = { "parsers.wct", "parse" },
    ["war3map.j"] = { "parsers.j", "parse" },
    ["scripts\\war3map.j"] = { "parsers.j", "parse" },
    ["war3map.w3u"] = { "parsers.w3u", "parse" },
    ["war3map.w3t"] = { "parsers.w3t", "parse" },
    ["war3map.w3b"] = { "parsers.w3b", "parse" },
    ["war3map.w3d"] = { "parsers.w3d", "parse" },
    ["war3map.w3a"] = { "parsers.w3a", "parse" },
    ["war3map.w3h"] = { "parsers.w3h", "parse" },
    ["war3map.w3q"] = { "parsers.w3q", "parse" },
    ["war3map.wpm"] = { "parsers.wpm", "parse" },
    ["war3map.shd"] = { "parsers.shd", "parse" },
    ["war3map.mmp"] = { "parsers.mmp", "parse" },
    ["war3mapmisc.txt"] = { "parsers.profile_txt", "parse" },
    ["war3mapskin.txt"] = { "parsers.profile_txt", "parse" },
    ["war3mapextra.txt"] = { "parsers.profile_txt", "parse" },
    ["*.blp"] = { "parsers.blp", "decode" },
    ["*.tga"] = { "parsers.tga", "decode" },
    ["*.mdx"] = { "parsers.mdx", "parse" },
    ["*.jpg"] = { "parsers.jpeg", "decode" },
    ["*.png"] = { "parsers.png", "decode" },
    ["*.slk"] = { "parsers.slk", "parse" },
    ["*.txt"] = { "parsers.profile_txt", "parse" },
}
-- Object data a map stores again without a name (protected maps plant
-- copies) is read by the same reader as the named file
for _, ext in ipairs({ "w3u", "w3t", "w3b", "w3d", "w3a", "w3h", "w3q" }) do
    M.READERS["*." .. ext] = { "parsers." .. ext, "parse" }
end

-- The map data files every map is expected to have a reader for: shown
-- in the report even when a map lacks one ("not in the map")
M.MAP_FILES = {
    "war3map.w3i", "war3map.wts", "war3map.w3e", "war3map.doo", "war3mapunits.doo",
    "war3map.w3r", "war3map.w3c", "war3map.w3s", "war3map.wtg", "war3map.wct", "war3map.j",
    "scripts\\war3map.j", "war3mapmisc.txt", "war3mapskin.txt", "war3mapextra.txt",
    "war3map.w3u", "war3map.w3t", "war3map.w3b", "war3map.w3d", "war3map.w3a", "war3map.w3h",
    "war3map.w3q", "war3map.shd", "war3map.wpm", "war3map.mmp", "war3map.imp",
}

-- Files the archive keeps for itself, not the map's content
local ARCHIVE_OWN = { ["(listfile)"] = true, ["(attributes)"] = true, ["(signature)"] = true }
-- }}}

-- {{{ M.kind_of
-- The kind a file is counted under: its name for a map data file, else
-- "*.ext"; an unnamed file by its first bytes when they say what it is
function M.kind_of(name, data)
    local low = name:lower()
    if ARCHIVE_OWN[low] then return nil end
    if M.READERS[low] then return low end
    for _, f in ipairs(M.MAP_FILES) do if f == low then return low end end
    if low:match("^file%d+%.") and data then
        local magic = data:sub(1, 4)
        if magic == "MDLX" then return "*.mdx" end
        if magic == "BLP1" or magic == "BLP2" then return "*.blp" end
    end
    local ext = low:match("%.([%w_]+)$")
    return ext and ("*." .. ext) or "(no extension)"
end
-- }}}

-- {{{ M.read_file
-- Runs the kind's reader on the bytes: "success", "fail" (and the error),
-- or "no_parser"; and the seconds it took
function M.read_file(kind, data)
    local reader = M.READERS[kind]
    if not reader then return "no_parser" end
    local mod = require(reader[1])
    local fn = mod[reader[2]]
    local t0 = os.clock()
    local ok, result, err = pcall(fn, data)
    local took = os.clock() - t0
    if not ok then return "fail", tostring(result), took end
    if result == nil then return "fail", tostring(err or "the reader returned nothing"), took end
    return "success", nil, took
end
-- }}}

-- {{{ M.scan_map
-- Every file of one map, read: { name, files = { {name, kind, size,
-- status, error} }, kinds = kind -> { files, ok, failed, seconds,
-- errors } } or nil and a message
function M.scan_map(path, only)
    local mpq = require("mpq")
    local ok, archive = pcall(mpq.open, path)
    if not ok or not archive then return nil, "can't open: " .. tostring(archive) end
    local map = { path = path, name = (path:match("([^/]+)$") or path):gsub("%.w3[xm]$", ""), files = {}, kinds = {} }
    for _, name in ipairs(archive:list()) do
        local eok, data = pcall(archive.extract, archive, name)
        if not eok or not data then data = nil end
        local kind = M.kind_of(name, data)
        if kind and (not only or only[kind]) then
            local entry = { name = name, kind = kind, size = data and #data or 0 }
            if not data then
                entry.status, entry.error = "fail", "can't extract: " .. tostring(eok and "no data" or data)
            else
                entry.status, entry.error, entry.seconds = M.read_file(kind, data)
            end
            map.files[#map.files + 1] = entry
            local k = map.kinds[kind] or { files = 0, ok = 0, failed = 0, seconds = 0, errors = {} }
            map.kinds[kind] = k
            k.files = k.files + 1
            k.seconds = k.seconds + (entry.seconds or 0)
            if entry.status == "success" then k.ok = k.ok + 1
            elseif entry.status == "fail" then
                k.failed = k.failed + 1
                k.errors[#k.errors + 1] = name .. ": " .. entry.error
            end
        end
    end
    archive:close()
    return map
end
-- }}}

-- {{{ M.status
-- One map's status for one kind: "success" (every file read), "fail" (any
-- failed), "no_parser", or "missing" (the map holds none)
function M.status(map, kind)
    local k = map.kinds[kind]
    if not k then return "missing" end
    if not M.READERS[kind] then return "no_parser" end
    return k.failed > 0 and "fail" or "success"
end
-- }}}

-- {{{ M.report
-- Every map scanned, and the kinds summed across them
function M.report(paths, only)
    local r = { generated = os.date("%Y-%m-%d %H:%M"), maps = {}, unreadable = {}, kinds = {}, order = {} }
    local seen = {}
    local function add_kind(kind)
        if not seen[kind] then
            seen[kind] = true
            r.order[#r.order + 1] = kind
            r.kinds[kind] = { kind = kind, parser = M.READERS[kind] ~= nil, maps_with = 0, maps_ok = 0,
                              maps_failed = 0, files = 0, files_failed = 0, seconds = 0, errors = {} }
        end
    end
    for _, f in ipairs(M.MAP_FILES) do if not only or only[f] then add_kind(f) end end
    for _, path in ipairs(paths) do
        local map, err = M.scan_map(path, only)
        if not map then
            r.unreadable[#r.unreadable + 1] = { path = path, error = err }
        else
            r.maps[#r.maps + 1] = map
            local kinds = {}
            for kind in pairs(map.kinds) do kinds[#kinds + 1] = kind end
            table.sort(kinds)
            for _, kind in ipairs(kinds) do
                add_kind(kind)
                local s, k = r.kinds[kind], map.kinds[kind]
                s.maps_with = s.maps_with + 1
                s.files = s.files + k.files
                s.files_failed = s.files_failed + k.failed
                s.seconds = s.seconds + k.seconds
                local st = M.status(map, kind)
                if st == "success" then s.maps_ok = s.maps_ok + 1 elseif st == "fail" then s.maps_failed = s.maps_failed + 1 end
                for _, e in ipairs(k.errors) do s.errors[#s.errors + 1] = map.name .. ": " .. e end
            end
        end
    end
    -- the map files first in their listed order, then the rest: with a
    -- reader before without, then by name
    local fixed = {}
    for i, f in ipairs(M.MAP_FILES) do fixed[f] = i end
    table.sort(r.order, function(a, b)
        if fixed[a] and fixed[b] then return fixed[a] < fixed[b] end
        if fixed[a] or fixed[b] then return fixed[a] ~= nil end
        local pa, pb = M.READERS[a] ~= nil, M.READERS[b] ~= nil
        if pa ~= pb then return pa end
        return a < b
    end)
    -- totals
    local t = { kinds = #r.order, with_parser = 0, without_parser = 0, files = 0, files_read = 0, files_failed = 0,
                files_without_parser = 0 }
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        if s.parser then t.with_parser = t.with_parser + 1 else t.without_parser = t.without_parser + 1 end
        t.files = t.files + s.files
        if s.parser then
            t.files_read = t.files_read + s.files - s.files_failed
            t.files_failed = t.files_failed + s.files_failed
        else
            t.files_without_parser = t.files_without_parser + s.files
        end
    end
    r.totals = t
    return r
end
-- }}}

-- {{{ Output
local SYMBOL = { success = "✓", fail = "✗", missing = "○", no_parser = "—" }

-- {{{ M.matrix
-- Markdown: a row per map, a column per kind
function M.matrix(r)
    local short = {}
    for i, kind in ipairs(r.order) do short[i] = kind:gsub("^war3map", ""):gsub("^units%.doo$", "units") end
    local lines = { "| Map | " .. table.concat(short, " | ") .. " |" }
    lines[2] = "|-----|" .. string.rep("---|", #r.order)
    for _, map in ipairs(r.maps) do
        local cells = {}
        for i, kind in ipairs(r.order) do cells[i] = SYMBOL[M.status(map, kind)] end
        lines[#lines + 1] = "| " .. map.name .. " | " .. table.concat(cells, " | ") .. " |"
    end
    return table.concat(lines, "\n")
end
-- }}}

local function fraction(a, b) return b > 0 and (a .. "/" .. b) or "—" end

-- Characters, not bytes, so "—" and "✓" pad like one column
local function width(s) return #s:gsub("[\128-\191]", "") end
local function pad(s, n) return s .. string.rep(" ", math.max(0, n - width(s))) end

-- {{{ M.markdown
function M.markdown(r, verbose)
    local t = r.totals
    local lines = {
        "# Parser Coverage Report", "",
        "Generated " .. r.generated .. " by `src/cli/parser-coverage.lua` over " .. #r.maps .. " maps.", "",
        "## Summary", "",
        string.format("- %d kinds of file: %d with a reader, %d without.", t.kinds, t.with_parser, t.without_parser),
        string.format("- %d files: %d read, %d failed, %d with no reader.", t.files, t.files_read, t.files_failed,
            t.files_without_parser),
        "",
        "| Kind | Reader | Maps read | Maps failed | Files (failed) |" .. (verbose and " Seconds |" or ""),
        "|------|--------|-----------|-------------|----------------|" .. (verbose and "---------|" or ""),
    }
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        local reader = s.parser and table.concat(M.READERS[kind], ".") or "—"
        local row = string.format("| %s | %s | %s | %s | %d (%d) |", kind, reader,
            s.parser and fraction(s.maps_ok, s.maps_with) or "—", s.parser and fraction(s.maps_failed, s.maps_with) or "—",
            s.files, s.files_failed)
        if s.maps_with == 0 then row = string.format("| %s | %s | not in any map | — | 0 (0) |", kind, reader) end
        if verbose then row = row .. string.format(" %.3f |", s.seconds) end
        lines[#lines + 1] = row
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Matrix"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "✓ every file read, ✗ a file failed, ○ not in the map, — no reader yet"
    lines[#lines + 1] = ""
    lines[#lines + 1] = M.matrix(r)
    local any = false
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        if #s.errors > 0 then
            if not any then
                lines[#lines + 1] = ""
                lines[#lines + 1] = "## Failures"
                any = true
            end
            lines[#lines + 1] = ""
            lines[#lines + 1] = "### " .. kind
            lines[#lines + 1] = ""
            for i, e in ipairs(s.errors) do
                if not verbose and i > 3 then
                    lines[#lines + 1] = "- ... and " .. (#s.errors - 3) .. " more (-v shows all)"
                    break
                end
                lines[#lines + 1] = "- " .. e
            end
        end
    end
    for _, u in ipairs(r.unreadable) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Not opened: " .. u.path .. " (" .. u.error .. ")"
    end
    return table.concat(lines, "\n") .. "\n"
end
-- }}}

-- {{{ M.terminal
-- A boxed table for the terminal
function M.terminal(r, verbose)
    local w = 1
    for _, kind in ipairs(r.order) do w = math.max(w, #kind) end
    local rule = string.rep("─", w + 2) .. "┼────────┼─────────────┼─────────────┼───────────────"
    local out = {
        "PARSER COVERAGE REPORT: " .. #r.maps .. " maps, " .. r.generated,
        "",
        " " .. pad("Kind", w) .. " │ Reader │ Maps read   │ Maps failed │ Files (failed)",
        rule,
    }
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        local read = s.parser and fraction(s.maps_ok, s.maps_with) or "—"
        local failed = s.parser and fraction(s.maps_failed, s.maps_with) or "—"
        if s.maps_with == 0 then read, failed = "not in maps", "—" end
        out[#out + 1] = string.format(" %s │   %s    │ %s │ %s │ %d (%d)", pad(kind, w),
            s.parser and "✓" or "—", pad(read, 11), pad(failed, 11), s.files, s.files_failed)
    end
    local t = r.totals
    out[#out + 1] = ""
    out[#out + 1] = string.format("%d kinds: %d with a reader, %d without. %d files: %d read, %d failed, %d with no reader.",
        t.kinds, t.with_parser, t.without_parser, t.files, t.files_read, t.files_failed, t.files_without_parser)
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        if #s.errors > 0 then
            out[#out + 1] = ""
            out[#out + 1] = kind .. " failed:"
            for i, e in ipairs(s.errors) do
                if not verbose and i > 3 then
                    out[#out + 1] = "  ... and " .. (#s.errors - 3) .. " more (-v shows all)"
                    break
                end
                out[#out + 1] = "  " .. e
            end
        end
    end
    if verbose then
        out[#out + 1] = ""
        out[#out + 1] = "Seconds spent reading each kind:"
        for _, kind in ipairs(r.order) do
            local s = r.kinds[kind]
            if s.parser and s.files > 0 then out[#out + 1] = string.format("  %-" .. w .. "s %8.3f", kind, s.seconds) end
        end
    end
    for _, u in ipairs(r.unreadable) do out[#out + 1] = "Not opened: " .. u.path .. " (" .. u.error .. ")" end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ M.json
local function json(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return named[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return v == math.floor(v) and string.format("%d", v) or string.format("%.6g", v)
    elseif t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local inner = indent .. "  "
        if #v > 0 or next(v) == nil then
            local items = {}
            for i, x in ipairs(v) do items[i] = inner .. json(x, inner) end
            if #items == 0 then return "[]" end
            return "[\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local items = {}
        for _, k in ipairs(keys) do items[#items + 1] = inner .. json(k) .. ": " .. json(v[k], inner) end
        return "{\n" .. table.concat(items, ",\n") .. "\n" .. indent .. "}"
    end
    return "null"
end
M.json_encode = json

-- The report as JSON: totals, each kind's sums, and each map's status
-- per kind (with the failures' errors)
function M.json(r)
    local out = { generated = r.generated, totals = r.totals, kinds = {}, maps = {}, unreadable = r.unreadable }
    for _, kind in ipairs(r.order) do
        local s = r.kinds[kind]
        out.kinds[#out.kinds + 1] = { kind = s.kind, parser = s.parser, maps_with = s.maps_with, maps_ok = s.maps_ok,
            maps_failed = s.maps_failed, files = s.files, files_failed = s.files_failed, seconds = s.seconds,
            errors = s.errors }
    end
    for _, map in ipairs(r.maps) do
        local status = {}
        for _, kind in ipairs(r.order) do status[kind] = M.status(map, kind) end
        out.maps[#out.maps + 1] = { name = map.name, path = map.path, files = #map.files, status = status }
    end
    return json(out) .. "\n"
end
-- }}}
-- }}}

-- {{{ main
local function usage()
    print("Usage: luajit src/cli/parser-coverage.lua [--dir DIR] [-m MAP]... [-f KIND]... [-v] [--matrix | --json] [--markdown FILE]")
end

local function main(argv)
    local maps, only, verbose, mode, md_file = {}, nil, false, "terminal", nil
    local i = 1
    while i <= #argv do
        local a = argv[i]
        if a == "-m" or a == "--map" then maps[#maps + 1] = argv[i + 1]; i = i + 1
        elseif a == "-f" or a == "--file" then only = only or {}; only[argv[i + 1]:lower()] = true; i = i + 1
        elseif a == "-a" or a == "--all" then -- the default
        elseif a == "-v" or a == "--verbose" then verbose = true
        elseif a == "--matrix" then mode = "matrix"
        elseif a == "--json" then mode = "json"
        elseif a == "--markdown" then md_file = argv[i + 1]; i = i + 1
        elseif a == "-h" or a == "--help" then usage() return 0
        else io.stderr:write("unknown option: " .. tostring(a) .. "\n") usage() return 2 end
        i = i + 1
    end
    if #maps == 0 then
        local p = io.popen('ls "' .. DIR .. '/assets/" 2>/dev/null')
        for name in p:lines() do
            if name:lower():match("%.w3[xm]$") then maps[#maps + 1] = DIR .. "/assets/" .. name end
        end
        p:close()
    end
    if #maps == 0 then io.stderr:write("no maps found in " .. DIR .. "/assets/\n") return 1 end
    local r = M.report(maps, only)
    if mode == "matrix" then io.write(M.matrix(r), "\n")
    elseif mode == "json" then io.write(M.json(r))
    else io.write(M.terminal(r, verbose)) end
    if md_file then
        local f = assert(io.open(md_file, "w"))
        f:write(M.markdown(r, verbose))
        f:close()
        io.stderr:write("wrote " .. md_file .. "\n")
    end
    return (#r.unreadable > 0) and 1 or 0
end
-- }}}

if arg and arg[0] and arg[0]:match("parser%-coverage%.lua$") then
    os.exit(main(arg))
end

return M
