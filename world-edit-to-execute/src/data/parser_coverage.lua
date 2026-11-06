--[[
parser_coverage.lua - which of a map's files the project can read (Issue A06)

In plain terms: opens each test map, lists every file stored in it, and
runs the project's own parser on each file it has one for. The answer, per
map and per kind of file, is one of five: read, protected (a map
protector's placeholder, which the parser's module recognises and refuses
by that name), failed (the parser raised or gave nothing back), missing
(the map doesn't hold that file) or no parser (the project has nothing
that reads it yet). From that it builds a
per-kind summary, a map-by-kind matrix and a list of files nobody reads.
src/cli/parser-coverage.lua prints it, as text, Markdown or JSON.

Usage:
  local coverage = require("data.parser_coverage")
  local report = coverage.run({ "assets/DAoW-2.1.w3x", ... }, { kinds = nil })
  print(coverage.text(report))           -- or .markdown(report), .json(report)

A map's standard files (war3map.w3i and the rest, mpq/standard_names.lua)
are each their own kind. Every other stored file (imports, and files
stored with no known name) is grouped by its extension ("*.mdx"), so a map
with 300 imported models gives one row, counted file by file.
]]

local mpq = require("mpq")
local standard_names = require("mpq.standard_names")

local coverage = {}

-- {{{ The parsers
-- Each kind of file and how the project reads it: a module and the name of
-- its reading function. A kind not listed has no parser. A module that also
-- has `protected(data)` (wtg, wct: issue 302a) is asked first whether the
-- file is a map protector's placeholder; it answers with the reason or nil.
coverage.STANDARD = {
    ["war3map.w3i"] = { "parsers.w3i", "parse" },
    ["war3map.w3e"] = { "parsers.w3e", "parse" },
    ["war3map.wts"] = { "parsers.wts", "parse" },
    ["war3map.j"] = { "parsers.j", "parse" },
    ["scripts\\war3map.j"] = { "parsers.j", "parse" },
    ["war3map.doo"] = { "parsers.doo", "parse" },
    ["war3mapUnits.doo"] = { "parsers.unitsdoo", "parse" },
    ["war3map.w3r"] = { "parsers.w3r", "parse" },
    ["war3map.w3c"] = { "parsers.w3c", "parse" },
    ["war3map.w3s"] = { "parsers.w3s", "parse" },
    ["war3map.wtg"] = { "parsers.wtg", "parse" },
    ["war3map.wct"] = { "parsers.wct", "parse" },
    ["war3map.w3u"] = { "parsers.w3u", "parse" },
    ["war3map.w3t"] = { "parsers.w3t", "parse" },
    ["war3map.w3b"] = { "parsers.w3b", "parse" },
    ["war3map.w3d"] = { "parsers.w3d", "parse" },
    ["war3map.w3a"] = { "parsers.w3a", "parse" },
    ["war3map.w3h"] = { "parsers.w3h", "parse" },
    ["war3map.w3q"] = { "parsers.w3q", "parse" },
    ["war3map.wpm"] = { "demo.wc3map.footprint", "parse_wpm" },
    ["war3mapMap.blp"] = { "parsers.blp", "decode" },
    ["war3mapMap.tga"] = { "parsers.tga", "decode" },
    ["war3mapPreview.tga"] = { "parsers.tga", "decode" },
    ["war3mapMisc.txt"] = { "parsers.profile_txt", "parse" },
    ["war3mapSkin.txt"] = { "parsers.profile_txt", "parse" },
    ["war3mapExtra.txt"] = { "parsers.profile_txt", "parse" },
}

-- Other files, by extension (lower case)
coverage.BY_EXTENSION = {
    mdx = { "parsers.mdx", "parse" },
    blp = { "parsers.blp", "decode" },
    tga = { "parsers.tga", "decode" },
    jpg = { "parsers.jpeg", "decode" },
    jpeg = { "parsers.jpeg", "decode" },
    png = { "parsers.png", "decode" },
    slk = { "parsers.slk", "parse" },
}
-- }}}

-- {{{ local function kind_of(name)
-- The kind a stored file counts under: its own name if standard, else
-- "*.ext" by extension ("*.?" for none)
local standard_set = {}
for _, n in ipairs(standard_names.MAP_FILES) do standard_set[n] = true end

local function kind_of(name)
    if standard_set[name] then return name end
    local ext = name:match("%.([^.\\/]+)$")
    return "*." .. (ext and ext:lower() or "?")
end
coverage.kind_of = kind_of
-- }}}

-- {{{ local function reader_for(kind)
local readers = {}
local function reader_for(kind)
    local spec = coverage.STANDARD[kind]
    if not spec and kind:sub(1, 2) == "*." then spec = coverage.BY_EXTENSION[kind:sub(3)] end
    if not spec then return nil end
    local key = spec[1] .. ":" .. spec[2]
    if readers[key] == nil then
        local ok, mod = pcall(require, spec[1])
        if ok and type(mod) == "table" and type(mod[spec[2]]) == "function" then
            readers[key] = { fn = mod[spec[2]], name = spec[1] .. "." .. spec[2],
                             protected = type(mod.protected) == "function" and mod.protected or nil }
        else
            readers[key] = { fn = nil, name = spec[1] .. "." .. spec[2],
                err = ok and "no function " .. spec[2] or tostring(mod) }
        end
    end
    return readers[key]
end
coverage.reader_for = reader_for
-- }}}

-- {{{ local function read_one(reader, data)
-- "read", "protected" or "failed", and the message when protected or failed.
-- "protected" only when the module's check names the file a placeholder and
-- the parser refuses it with that same reason, as 302a's tests require; a
-- placeholder refused for any other reason still counts as failed.
local function read_one(reader, data)
    if not reader.fn then return "failed", "cannot load " .. reader.name .. ": " .. reader.err end
    local reason
    if reader.protected then
        local pok, why = pcall(reader.protected, data)
        if pok and type(why) == "string" then reason = why end
    end
    local ok, result, err = pcall(reader.fn, data)
    if reason and ok and (result == nil or result == false) and err == reason then return "protected", reason end
    if not ok then return "failed", tostring(result) end
    if result == nil or result == false then return "failed", tostring(err or "nothing returned") end
    return "read"
end
-- }}}

-- {{{ coverage.scan_map(path, options)
-- One map: { path, name, files = { {name, kind, size, status, message} },
-- kinds = { [kind] = {read, protected, failed, no_parser} }, missing = {kinds},
-- error = message if the map would not open }. options.kinds: a set of kinds
-- to look at (all when absent).
function coverage.scan_map(path, options)
    options = options or {}
    local want = options.kinds
    local map = { path = path, name = path:match("([^/]+)$"):gsub("%.w3[xm]$", ""),
                  files = {}, kinds = {}, missing = {} }
    local archive, err = mpq.open(path)
    if not archive then
        map.error = tostring(err)
        return map
    end
    local present = {}
    for _, name in ipairs(archive:list()) do
        local kind = kind_of(name)
        if not want or want[kind] then
            present[kind] = true
            local entry = { name = name, kind = kind }
            local counts = map.kinds[kind] or { read = 0, protected = 0, failed = 0, no_parser = 0 }
            map.kinds[kind] = counts
            local reader = reader_for(kind)
            if not reader then
                entry.status = "no_parser"
            else
                local data, xerr = archive:extract(name)
                if not data then
                    entry.status, entry.message = "failed", "cannot extract: " .. tostring(xerr)
                else
                    entry.size = #data
                    entry.status, entry.message = read_one(reader, data)
                end
            end
            counts[entry.status] = counts[entry.status] + 1
            map.files[#map.files + 1] = entry
        end
    end
    archive:close()
    for _, kind in ipairs(standard_names.MAP_FILES) do
        if not present[kind] and (not want or want[kind]) then map.missing[#map.missing + 1] = kind end
    end
    return map
end
-- }}}

-- {{{ local function map_status(map, kind)
-- One cell of the matrix: "read" (every file of the kind read), "failed"
-- (any failed), "protected" (none failed or read: a protector's
-- placeholder), "missing", "no_parser", or "error" (map didn't open)
local function map_status(map, kind)
    if map.error then return "error" end
    local c = map.kinds[kind]
    if not c then return "missing" end
    if c.failed > 0 then return "failed" end
    if c.read > 0 then return "read" end
    if (c.protected or 0) > 0 then return "protected" end
    return "no_parser"
end
coverage.map_status = map_status
-- }}}

-- {{{ coverage.run(paths, options)
-- Every map, then the totals: report = { maps, kinds (sorted list),
-- summary = { [kind] = { parser, maps_read, maps_protected, maps_failed,
-- maps_missing, files_read, files_protected, files_failed, files_no_parser } },
-- totals }
function coverage.run(paths, options)
    local report = { maps = {}, kinds = {}, summary = {} }
    for _, p in ipairs(paths) do report.maps[#report.maps + 1] = coverage.scan_map(p, options) end

    local seen = {}
    local function add_kind(k)
        if not seen[k] then seen[k] = true; report.kinds[#report.kinds + 1] = k end
    end
    -- standard kinds first, in their usual order; then extensions, sorted
    local want = options and options.kinds
    for _, k in ipairs(standard_names.MAP_FILES) do
        if not want or want[k] then add_kind(k) end
    end
    local exts = {}
    for _, m in ipairs(report.maps) do
        for k in pairs(m.kinds) do
            if not standard_set[k] and not seen[k] then seen[k] = true; exts[#exts + 1] = k end
        end
    end
    table.sort(exts)
    for _, k in ipairs(exts) do report.kinds[#report.kinds + 1] = k end

    local totals = { maps = #report.maps, maps_unopened = 0, files = 0, read = 0, protected = 0, failed = 0, no_parser = 0 }
    for _, m in ipairs(report.maps) do
        if m.error then totals.maps_unopened = totals.maps_unopened + 1 end
    end
    for _, k in ipairs(report.kinds) do
        local reader = reader_for(k)
        local s = { parser = reader and reader.name or nil, maps_read = 0, maps_protected = 0, maps_failed = 0,
                    maps_missing = 0, maps_no_parser = 0, files_read = 0, files_protected = 0, files_failed = 0,
                    files_no_parser = 0 }
        for _, m in ipairs(report.maps) do
            local st = map_status(m, k)
            if st == "read" then s.maps_read = s.maps_read + 1
            elseif st == "protected" then s.maps_protected = s.maps_protected + 1
            elseif st == "failed" then s.maps_failed = s.maps_failed + 1
            elseif st == "missing" then s.maps_missing = s.maps_missing + 1
            elseif st == "no_parser" then s.maps_no_parser = s.maps_no_parser + 1 end
            local c = m.kinds[k]
            if c then
                s.files_read = s.files_read + c.read
                s.files_protected = s.files_protected + c.protected
                s.files_failed = s.files_failed + c.failed
                s.files_no_parser = s.files_no_parser + c.no_parser
            end
        end
        report.summary[k] = s
        totals.read = totals.read + s.files_read
        totals.protected = totals.protected + s.files_protected
        totals.failed = totals.failed + s.files_failed
        totals.no_parser = totals.no_parser + s.files_no_parser
    end
    totals.files = totals.read + totals.protected + totals.failed + totals.no_parser
    report.totals = totals
    return report
end
-- }}}

-- {{{ Output
local SYMBOL = { read = "ok", protected = "prot", failed = "FAIL", missing = ".", no_parser = "-", error = "ERR" }
coverage.SYMBOL = SYMBOL
local LEGEND = "Legend: ok = read, prot = a protected map's placeholder, FAIL = a file failed, . = not in the map, "
    .. "- = no parser, ERR = map would not open"

-- Kinds that appear in at least one map (others only clutter the matrix)
local function kinds_present(report)
    local out = {}
    for _, k in ipairs(report.kinds) do
        local s = report.summary[k]
        if s.maps_missing < #report.maps then out[#out + 1] = k end
    end
    return out
end

-- {{{ local function short(kind)
-- A column heading: "w3i" for war3map.w3i, "Units.doo", "*.mdx"
local function short(kind)
    return (kind:gsub("^scripts\\", "s\\"):gsub("^war3map%.", ""):gsub("^war3map", ""))
end
-- }}}

-- {{{ local function summary_rows(report)
local function summary_rows(report)
    local rows = {}
    for _, k in ipairs(kinds_present(report)) do
        local s = report.summary[k]
        rows[#rows + 1] = {
            k, s.parser or "-",
            string.format("%d/%d", s.maps_read, #report.maps),
            string.format("%d/%d", s.maps_protected, #report.maps),
            string.format("%d/%d", s.maps_failed, #report.maps),
            string.format("%d/%d", s.maps_missing, #report.maps),
            tostring(s.files_read), tostring(s.files_protected), tostring(s.files_failed),
            tostring(s.files_no_parser),
        }
    end
    return rows
end
local SUMMARY_HEAD = { "File kind", "Parser", "Maps read", "Maps protected", "Maps failed", "Not in map",
                       "Files read", "Files protected", "Files failed", "Files unread" }
-- }}}

-- {{{ local function failures(report)
-- Every failed file: { map, file, message }
local function failures(report)
    local out = {}
    for _, m in ipairs(report.maps) do
        if m.error then out[#out + 1] = { m.name, "(the map)", m.error } end
        for _, f in ipairs(m.files) do
            if f.status == "failed" then out[#out + 1] = { m.name, f.name, f.message or "" } end
        end
    end
    return out
end
coverage.failures = failures
-- }}}

-- {{{ local function protected_files(report)
-- Every protector's placeholder: { map, file, reason }
local function protected_files(report)
    local out = {}
    for _, m in ipairs(report.maps) do
        for _, f in ipairs(m.files) do
            if f.status == "protected" then out[#out + 1] = { m.name, f.name, f.message or "" } end
        end
    end
    return out
end
coverage.protected_files = protected_files
-- }}}

-- {{{ local function unread_kinds(report)
-- Kinds found in maps with no parser, most files first: { kind, files, maps }
local function unread_kinds(report)
    local out = {}
    for _, k in ipairs(report.kinds) do
        local s = report.summary[k]
        if not s.parser and s.files_no_parser > 0 then
            out[#out + 1] = { k, s.files_no_parser, s.maps_no_parser }
        end
    end
    table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    return out
end
coverage.unread_kinds = unread_kinds
-- }}}

-- {{{ local function totals_line(report)
local function totals_line(report)
    local t = report.totals
    return string.format("%d maps (%d would not open); %d files: %d read, %d protected, %d failed, %d with no parser",
        t.maps, t.maps_unopened, t.files, t.read, t.protected, t.failed, t.no_parser)
end
coverage.totals_line = totals_line
-- }}}

-- {{{ local function aligned(rows, head)
local function aligned(rows, head)
    local width = {}
    for i, h in ipairs(head) do width[i] = #h end
    for _, r in ipairs(rows) do
        for i, c in ipairs(r) do if #c > width[i] then width[i] = #c end end
    end
    local function line(r)
        local cells = {}
        for i, c in ipairs(r) do cells[i] = c .. string.rep(" ", width[i] - #c) end
        return (table.concat(cells, "  "):gsub("%s+$", ""))
    end
    local lines = { line(head) }
    local rule = {}
    for i = 1, #head do rule[i] = string.rep("-", width[i]) end
    lines[#lines + 1] = table.concat(rule, "  ")
    for _, r in ipairs(rows) do lines[#lines + 1] = line(r) end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function matrix_rows(report)
local function matrix_rows(report)
    local kinds = kinds_present(report)
    local head = { "Map" }
    for _, k in ipairs(kinds) do head[#head + 1] = short(k) end
    local rows = {}
    for _, m in ipairs(report.maps) do
        local r = { m.name }
        for _, k in ipairs(kinds) do r[#r + 1] = SYMBOL[map_status(m, k)] end
        rows[#rows + 1] = r
    end
    return head, rows
end
-- }}}

-- {{{ coverage.text(report, options)
-- options.matrix: the matrix alone; options.verbose: every failure's message
function coverage.text(report, options)
    options = options or {}
    local head, rows = matrix_rows(report)
    if options.matrix then return aligned(rows, head) .. "\n\n" .. LEGEND end
    local out = { "PARSER COVERAGE", "", totals_line(report), "", aligned(summary_rows(report), SUMMARY_HEAD), "",
                  "Matrix:", "", aligned(rows, head), "", LEGEND }
    local unread = unread_kinds(report)
    if #unread > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "No parser yet (files, maps):"
        for _, u in ipairs(unread) do out[#out + 1] = string.format("  %s  %d files in %d maps", u[1], u[2], u[3]) end
    end
    local prot = protected_files(report)
    if #prot > 0 then
        out[#out + 1] = ""
        out[#out + 1] = string.format("Protected (a map protector's placeholder, not a parser failure): %d", #prot)
        for _, f in ipairs(prot) do out[#out + 1] = string.format("  %s  %s", f[1], f[2]) end
    end
    local fails = failures(report)
    if #fails > 0 then
        out[#out + 1] = ""
        out[#out + 1] = string.format("Failures: %d", #fails)
        if options.verbose then
            for _, f in ipairs(fails) do out[#out + 1] = string.format("  %s  %s: %s", f[1], f[2], f[3]) end
        else
            out[#out + 1] = "  (-v lists each with its message)"
        end
    end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ coverage.markdown(report, options)
local function md_table(head, rows)
    local function cell(c) return (c:gsub("|", "\\|"):gsub("\n", " ")) end
    local lines = { "| " .. table.concat(head, " | ") .. " |" }
    local rule = {}
    for i = 1, #head do rule[i] = "---" end
    lines[#lines + 1] = "|" .. table.concat(rule, "|") .. "|"
    for _, r in ipairs(rows) do
        local cs = {}
        for i, c in ipairs(r) do cs[i] = cell(c) end
        lines[#lines + 1] = "| " .. table.concat(cs, " | ") .. " |"
    end
    return table.concat(lines, "\n")
end

function coverage.markdown(report, options)
    options = options or {}
    local head, rows = matrix_rows(report)
    local out = { "# Parser Coverage Report", "", "Generated " .. os.date("!%Y-%m-%d %H:%M UTC") .. " by `src/cli/parser-coverage.lua`.", "",
                  totals_line(report) .. ".", "", "## Summary", "", md_table(SUMMARY_HEAD, summary_rows(report)), "",
                  "## Compatibility Matrix", "", md_table(head, rows), "", LEGEND .. "." }
    local unread = unread_kinds(report)
    if #unread > 0 then
        local r = {}
        for _, u in ipairs(unread) do r[#r + 1] = { u[1], tostring(u[2]), tostring(u[3]) } end
        out[#out + 1] = ""
        out[#out + 1] = "## No Parser Yet"
        out[#out + 1] = ""
        out[#out + 1] = md_table({ "File kind", "Files", "Maps" }, r)
    end
    local prot = protected_files(report)
    if #prot > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "## Protected"
        out[#out + 1] = ""
        out[#out + 1] = "A map protector's placeholder in place of the file; the parser refuses it by that name."
        out[#out + 1] = ""
        out[#out + 1] = md_table({ "Map", "File", "Reason" }, prot)
    end
    local fails = failures(report)
    if #fails > 0 then
        out[#out + 1] = ""
        out[#out + 1] = "## Failures"
        out[#out + 1] = ""
        out[#out + 1] = md_table({ "Map", "File", "Message" }, fails)
    end
    return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ coverage.json(report)
-- Keys sorted, so the same maps give the same bytes
local function encode(v, out)
    local t = type(v)
    if t == "table" then
        if #v > 0 or next(v) == nil then
            out[#out + 1] = "["
            for i, x in ipairs(v) do
                if i > 1 then out[#out + 1] = "," end
                encode(x, out)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            out[#out + 1] = "{"
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                encode(k, out)
                out[#out + 1] = ":"
                encode(v[k], out)
            end
            out[#out + 1] = "}"
        end
    elseif t == "string" then
        out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c)
            local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return named[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif t == "number" then
        out[#out + 1] = (v == math.floor(v) and string.format("%d", v)) or string.format("%.17g", v)
    elseif t == "boolean" then
        out[#out + 1] = tostring(v)
    else
        out[#out + 1] = "null"
    end
end
coverage.encode_json = function(v) local out = {}; encode(v, out); return table.concat(out) end

function coverage.json(report)
    local maps = {}
    for _, m in ipairs(report.maps) do
        local cells = {}
        for _, k in ipairs(report.kinds) do cells[k] = map_status(m, k) end
        local files = {}
        for _, f in ipairs(m.files) do
            files[#files + 1] = { name = f.name, kind = f.kind, size = f.size, status = f.status, message = f.message }
        end
        maps[#maps + 1] = { name = m.name, path = m.path, error = m.error, status = cells, files = files }
    end
    return coverage.encode_json({ kinds = report.kinds, summary = report.summary, totals = report.totals, maps = maps }) .. "\n"
end
-- }}}
-- }}}

return coverage
