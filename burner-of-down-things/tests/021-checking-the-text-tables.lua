-- 021-checking-the-text-tables.lua
--
-- Checks the one reader and writer of tables and records (issue 102): every
-- byte survives a round trip, a torn row is refused with its line number, a
-- record always writes the same bytes, and a record file cannot run code.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local text_tables = require("014-text-tables")

-- Every byte value, alone and together, survives escape and unescape.
local all_bytes = {}
for b = 0, 255 do
    local c = string.char(b)
    all_bytes[#all_bytes + 1] = c
    kit.equal(text_tables.unescape(text_tables.escape(c)), c, "byte " .. b .. " round trip")
end
local everything = table.concat(all_bytes)
kit.equal(text_tables.unescape(text_tables.escape(everything)), everything, "all bytes round trip")
local tricky = "\\t is not a tab\t\n\\\\n\r\\"
kit.equal(text_tables.unescape(text_tables.escape(tricky)), tricky, "backslashes and escapes round trip")
kit.check(not text_tables.escape(tricky):find("[\t\n]"), "an escaped field has no tab or newline")

-- A whole table round trip.
local folder = kit.scratch("text-tables")
local path = folder .. "/t.tsv"
local header = { "path", "note" }
local rows = { { "a/b.lua", "has\ta tab" }, { "c", "" }, { "d e", "line one\nline two" } }
text_tables.write(path, header, rows)
local back, back_header = text_tables.read(path)
kit.equal(#back, 3, "three rows back")
kit.equal(back_header[2], "note", "header back")
kit.equal(back[1].note, "has\ta tab", "tab field back")
kit.equal(back[2].note, "", "empty field back")
kit.equal(back[3].note, "line one\nline two", "newline field back")

-- A short row is refused, naming its line.
kit.write_file(folder .. "/torn.tsv", "#a\tb\n1\t2\n3\n")
kit.raises(function() text_tables.read(folder .. "/torn.tsv") end, "torn.tsv:3", "short row names line 3")
kit.write_file(folder .. "/no-newline.tsv", "#a\n1")
kit.raises(function() text_tables.read(folder .. "/no-newline.tsv") end, "torn", "missing last newline refused")
kit.raises(function() text_tables.write(folder .. "/bad.tsv", header, { { "only one" } }) end,
    "row 1", "writing a short row refused")

-- Records: nested round trip, identical bytes, no code.
local record = { name = "x", n = 3, f = 0.5, yes = true, list = { "a", "b" }, nested = { deep = { 1, 2 } } }
local rpath = folder .. "/r.lua"
text_tables.write_record(rpath, record)
local first_bytes = kit.fs.read(rpath)
text_tables.write_record(rpath, text_tables.read_record(rpath))
kit.equal(kit.fs.read(rpath), first_bytes, "a record rewrites to identical bytes")
local r = text_tables.read_record(rpath)
kit.equal(r.nested.deep[2], 2, "nested value back")
kit.equal(r.f, 0.5, "fraction back")
kit.equal(r.list[1], "a", "list back")
kit.write_file(folder .. "/evil.lua", "os.exit(3)\nreturn {}\n")
kit.raises(function() text_tables.read_record(folder .. "/evil.lua") end, "did more than return a table",
    "a record that calls os.exit is refused")
kit.write_file(folder .. "/not-table.lua", "return 4\n")
kit.raises(function() text_tables.read_record(folder .. "/not-table.lua") end, "does not return a table",
    "a record returning a number is refused")
kit.raises(function() text_tables.write_record(folder .. "/fn.lua", { f = print }) end, "cannot hold a function",
    "a function in a record is refused")

kit.finish()
