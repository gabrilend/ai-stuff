#!/usr/bin/env luajit
-- test_parser_coverage.lua - the parser coverage report (issue A06)
--
-- In plain terms: the tool sorts files into kinds the way the report
-- needs (a map's data files by name, the rest by extension, unnamed ones
-- by their first bytes), calls a damaged file a failure, and over two of
-- the test maps reports every map data file read, the files with no
-- reader, a matrix row per map, and the same numbers as JSON and Markdown.
--
-- Run: luajit src/tests/test_parser_coverage.lua [DIR]
-- Issue: issues/completed/A06-parser-coverage-report.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path
arg = { [0] = "test" }
local cov = dofile(DIR .. "/src/cli/parser-coverage.lua")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end

-- {{{ Kinds
print("\n=== Kinds of file ===")
test("a map data file is its own kind, whatever its case", cov.kind_of("War3Map.W3E") == "war3map.w3e")
test("the script in its folder", cov.kind_of("Scripts\\war3map.j") == "scripts\\war3map.j")
test("other files by extension", cov.kind_of("war3mapImported\\Footman.blp") == "*.blp"
    and cov.kind_of("Units\\UnitUI.slk") == "*.slk")
test("an unnamed file by its first bytes", cov.kind_of("File00000041.xxx", "MDLX....") == "*.mdx"
    and cov.kind_of("File00000042.xxx", "BLP1....") == "*.blp")
test("an unnamed file of no known signature keeps StormLib's extension",
    cov.kind_of("File00000043.xxx", "RIFF....") == "*.xxx")
test("the archive's own files aren't counted", cov.kind_of("(listfile)") == nil and cov.kind_of("(attributes)") == nil)
-- }}}

-- {{{ Reading one file
print("\n=== Reading one file ===")
local status, err = cov.read_file("war3map.w3e", "W3E!\1\0\0\0")
test("a damaged terrain file is a failure, with its error", status == "fail" and err ~= nil, tostring(err))
status = cov.read_file("war3map.shd", "anything")
test("a kind with no reader says so", status == "no_parser")
status, err = cov.read_file("*.txt", "[hfoo]\nArt=x.blp\n")
test("a readable file is a success", status == "success", tostring(err))
-- }}}

-- {{{ Two maps
print("\n=== Two test maps ===")
local maps = { DIR .. "/assets/Daow4.4.w3x", DIR .. "/assets/DAoW-2.1.w3x" }
local r = cov.report(maps)
test("both maps opened", #r.maps == 2 and #r.unreadable == 0)
local w3i = r.kinds["war3map.w3i"]
test("map info read in both", w3i.parser and w3i.maps_with == 2 and w3i.maps_ok == 2 and w3i.maps_failed == 0)
test("terrain read in both", r.kinds["war3map.w3e"].maps_ok == 2)
local shd = r.kinds["war3map.shd"]
test("the shadow map is listed as having no reader", shd and not shd.parser and shd.files == 2)
test("every map data file is listed, present or not", r.kinds["war3map.imp"] ~= nil and r.kinds["war3map.w3c"] ~= nil)
test("the map data files come first, in their order", r.order[1] == "war3map.w3i" and r.order[2] == "war3map.wts")
local t = r.totals
test("totals add up", t.files == t.files_read + t.files_failed + t.files_without_parser and t.files > 10,
    string.format("%d = %d + %d + %d", t.files, t.files_read, t.files_failed, t.files_without_parser))
test("nothing fails on these maps", t.files_failed == 0, tostring(t.files_failed))
test("status per map: read, no reader, not in the map",
    cov.status(r.maps[1], "war3map.w3i") == "success" and cov.status(r.maps[1], "war3map.shd") == "no_parser"
    and cov.status(r.maps[1], "war3map.imp") == "missing")

local only = cov.report({ maps[1] }, { ["war3map.w3e"] = true })
test("-f narrows the report to one kind", #only.order == 1 and only.order[1] == "war3map.w3e" and only.totals.files == 1)

local bad = cov.report({ DIR .. "/assets/no-such-map.w3x" })
test("a map that won't open is reported, not fatal", #bad.unreadable == 1 and #bad.maps == 0)
-- }}}

-- {{{ Output
print("\n=== Output ===")
local matrix = cov.matrix(r)
local rows = {}
for line in matrix:gmatch("[^\n]+") do rows[#rows + 1] = line end
test("matrix: a header, a rule and a row per map", #rows == 4 and rows[3]:find("^| Daow4%.4 |"))
local _, cells = rows[3]:gsub("|", "")
local _, heads = rows[1]:gsub("|", "")
test("matrix: as many cells as columns", cells == heads)

local md = cov.markdown(r)
test("markdown: summary, kinds and matrix", md:find("# Parser Coverage Report", 1, true)
    and md:find("| war3map.w3i | parsers.w3i.parse | 2/2 |", 1, true) and md:find("## Matrix", 1, true))

local js = cov.json(r)
local _, opens = js:gsub("[%[{]", "")
local _, closes = js:gsub("[%]}]", "")
test("JSON: balanced, with totals, kinds and maps", opens == closes and js:find('"totals"', 1, true)
    and js:find('"kind": "war3map.w3i"', 1, true) and js:find('"name": "Daow4.4"', 1, true))
test("JSON strings are escaped", cov.json_encode('a"b\\c\n') == '"a\\"b\\\\c\\n"')

-- the column (in characters, not bytes) of every "│" on a line
local function bars(line)
    local cols, col = {}, 0
    for ch in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        col = col + 1
        if ch == "│" then cols[#cols + 1] = col end
    end
    return table.concat(cols, ",")
end
local term = cov.terminal(r)
local layouts, lines = {}, 0
for line in term:gmatch("[^\n]+") do
    if line:find("│", 1, true) then
        lines = lines + 1
        layouts[bars(line)] = true
    end
end
local distinct = 0
for _ in pairs(layouts) do distinct = distinct + 1 end
test("terminal: the table's columns line up", lines > 10 and distinct == 1, distinct .. " layouts")
-- }}}

print(string.format("\n%d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
