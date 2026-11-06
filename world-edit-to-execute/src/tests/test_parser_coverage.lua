#!/usr/bin/env luajit
-- test_parser_coverage.lua - the parser coverage report (Issue A06)
--
-- Checks how stored files are grouped into kinds, that a real test map's
-- files are read and counted, that a parser that raises is counted as a
-- failure with its message, that a map that won't open is reported, and the
-- three outputs and the command-line tool.
--
-- Run: luajit src/tests/test_parser_coverage.lua [DIR]

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local coverage = require("data.parser_coverage")

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
    end
end

local MAP = DIR .. "/assets/DAoW-2.1.w3x"

-- {{{ kinds
check("standard file is its own kind", coverage.kind_of("war3map.w3e") == "war3map.w3e")
check("script path kept", coverage.kind_of("scripts\\war3map.j") == "scripts\\war3map.j")
check("imports grouped by extension", coverage.kind_of("war3mapImported\\Foo.MDX") == "*.mdx")
check("no extension", coverage.kind_of("war3mapImported\\README") == "*.?")
check("known kind has a reader", coverage.reader_for("war3map.w3i") and coverage.reader_for("war3map.w3i").fn ~= nil)
check("extension kind has a reader", coverage.reader_for("*.blp") and coverage.reader_for("*.blp").fn ~= nil)
check("unknown kind has none", coverage.reader_for("war3map.shd") == nil)
check("unknown extension has none", coverage.reader_for("*.wav") == nil)
-- every listed parser loads and has its function
for kind in pairs(coverage.STANDARD) do
    local r = coverage.reader_for(kind)
    check("reader loads for " .. kind, r and r.fn ~= nil, r and r.err)
end
for ext in pairs(coverage.BY_EXTENSION) do
    local r = coverage.reader_for("*." .. ext)
    check("reader loads for *." .. ext, r and r.fn ~= nil, r and r.err)
end
-- }}}

-- {{{ a real map
local m = coverage.scan_map(MAP)
check("map opens", m.error == nil, m.error)
check("map name", m.name == "DAoW-2.1", m.name)
check("w3i read", m.kinds["war3map.w3i"] and m.kinds["war3map.w3i"].read == 1)
check("w3e read", coverage.map_status(m, "war3map.w3e") == "read")
check("script read", coverage.map_status(m, "scripts\\war3map.j") == "read")
check("shadow map has no parser", coverage.map_status(m, "war3map.shd") == "no_parser")
check("units file missing", coverage.map_status(m, "war3mapUnits.doo") == "missing")
local listed_missing = false
for _, k in ipairs(m.missing) do if k == "war3mapUnits.doo" then listed_missing = true end end
check("missing list names it", listed_missing)
local sizes = true
for _, f in ipairs(m.files) do
    if f.status ~= "no_parser" and not f.size then sizes = false end
end
check("read files carry their size", sizes)
-- }}}

-- {{{ filter to one kind
local only = coverage.scan_map(MAP, { kinds = { ["war3map.w3i"] = true } })
check("filter keeps one file", #only.files == 1 and only.files[1].kind == "war3map.w3i", #only.files)
check("filter: missing only within kinds", #only.missing == 0)
-- }}}

-- {{{ a parser that raises
package.preload["test_raising_reader"] = function()
    return { parse = function() error("broken on purpose") end }
end
local saved = coverage.STANDARD["war3map.w3i"]
coverage.STANDARD["war3map.w3i"] = { "test_raising_reader", "parse" }
local bad = coverage.scan_map(MAP, { kinds = { ["war3map.w3i"] = true } })
coverage.STANDARD["war3map.w3i"] = saved
check("raising parser counts as failed", coverage.map_status(bad, "war3map.w3i") == "failed")
check("failure keeps the message", bad.files[1].message and bad.files[1].message:find("broken on purpose", 1, true),
      bad.files[1].message)

package.preload["test_nil_reader"] = function()
    return { parse = function() return nil, "said no" end }
end
coverage.STANDARD["war3map.w3i"] = { "test_nil_reader", "parse" }
local said_no = coverage.scan_map(MAP, { kinds = { ["war3map.w3i"] = true } })
coverage.STANDARD["war3map.w3i"] = saved
check("nil result counts as failed", said_no.files[1].status == "failed" and said_no.files[1].message == "said no",
      said_no.files[1].message)
-- }}}

-- {{{ the whole run, with a map that won't open
local report = coverage.run({ MAP, DIR .. "/assets/no-such-map.w3x" })
local t = report.totals
check("two maps", t.maps == 2)
check("one unopened", t.maps_unopened == 1)
check("unopened map status", coverage.map_status(report.maps[2], "war3map.w3i") == "error")
check("files add up", t.files == t.read + t.failed + t.no_parser and t.files == #report.maps[1].files)
check("summary: w3i read in one map", report.summary["war3map.w3i"].maps_read == 1)
check("summary: parser named", report.summary["war3map.w3i"].parser == "parsers.w3i.parse")
check("summary: shd unread", report.summary["war3map.shd"].files_no_parser == 1 and not report.summary["war3map.shd"].parser)
check("standard kinds come first", report.kinds[1] == "(listfile)")
local fails = coverage.failures(report)
check("unopened map listed as a failure", #fails >= 1 and fails[#fails][2] == "(the map)")
local unread = coverage.unread_kinds(report)
check("unread kinds listed", #unread >= 1)
-- }}}

-- {{{ outputs
local text = coverage.text(report)
check("text has totals", text:find(coverage.totals_line(report), 1, true) ~= nil)
check("text has matrix", text:find("Matrix:", 1, true) ~= nil)
check("text: failures hidden without verbose", text:find("(-v lists", 1, true) ~= nil)
check("verbose text: messages", coverage.text(report, { verbose = true }):find("no-such-map", 1, true) ~= nil)
local matrix = coverage.text(report, { matrix = true })
check("matrix alone", matrix:find("PARSER COVERAGE", 1, true) == nil and matrix:find("DAoW-2.1", 1, true) ~= nil)
local md = coverage.markdown(report)
check("markdown headings", md:find("# Parser Coverage Report", 1, true) and md:find("## Compatibility Matrix", 1, true))
check("markdown failures table", md:find("## Failures", 1, true) ~= nil)
check("json encode", coverage.encode_json({ b = 1, a = { "x", "y\n" }, c = true }) == '{"a":["x","y\\n"],"b":1,"c":true}',
      coverage.encode_json({ b = 1, a = { "x", "y\n" }, c = true }))
local j = coverage.json(report)
check("json has totals", j:find('"totals":{', 1, true) ~= nil)
check("json is the same twice", j == coverage.json(report))
-- }}}

-- {{{ the command-line tool
local function run(args)
    local p = io.popen('cd "' .. DIR .. '" && luajit src/cli/parser-coverage.lua --dir "' .. DIR .. '" ' .. args .. ' 2>&1; echo "exit=$?"')
    local out = p:read("*a")
    p:close()
    return out, tonumber(out:match("exit=(%d+)%s*$"))
end
local out, code = run('-m "' .. MAP .. '"')
check("cli: one map, exit 0", code == 0, code)
check("cli: prints totals", out:find("1 maps (0 would not open)", 1, true) ~= nil)
out, code = run('--json -f war3map.w3i "' .. MAP .. '"')
check("cli: json filtered", code == 0 and out:find('"kinds":["war3map.w3i"]', 1, true) ~= nil, out:sub(1, 200))
out, code = run('-m "' .. DIR .. '/assets/no-such-map.w3x"')
check("cli: unopened map, exit 1", code == 1, code)
out, code = run('--bogus')
check("cli: unknown option, exit 2", code == 2, code)
-- }}}

print(string.format("Tests: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
