-- 032-checking-the-survey.lua
--
-- Checks phase 2 (issues 201–205): the walk and its skip table, the language
-- table, the include scanners (including the anchored-pattern trap that once
-- made every C include invisible), link resolution, the parallel reader's
-- output being identical at every thread count, and the summary being
-- rebuildable from the tables alone.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local walk = require("026-the-walk")
local languages = require("027-the-language-table")
local includes = require("028-include-lines")
local survey = require("029-the-survey")
local summary = require("030-the-survey-summary")
local case = require("018-the-case")
local text_tables = require("014-text-tables")

local folder = kit.scratch("survey")
local src = folder .. "/source"

-- A small source with every kind of thing the survey must handle.
kit.write_file(src .. "/main.lua", 'local util = require("lib.util")\nlocal cfg = require "config"\n-- require("commented.out")\nprint(util, cfg)\n')
kit.write_file(src .. "/lib/util.lua", 'local helper = require("helper")\nreturn {}\n')
kit.write_file(src .. "/lib/helper.lua", "return 1\n")
kit.write_file(src .. "/config.lua", "return {}\n")
kit.write_file(src .. "/engine/core.c", '#include "core.h"\n#include <stdio.h>\n// #include "gone.h"\nint main(void) { return 0; }\n')
kit.write_file(src .. "/engine/core.h", "#pragma once\n")
kit.write_file(src .. "/run.sh", "#!/bin/bash\nsource lib/env.sh\n. ./lib/env.sh\n")
kit.write_file(src .. "/lib/env.sh", "X=1\n")
kit.write_file(src .. "/tool", "#!/usr/bin/env luajit\nrequire('config')\n")
kit.write_file(src .. "/README.md", "# hello\nsecond line\n")
kit.write_file(src .. "/data.bin", "abc\0def")
kit.write_file(src .. "/a name with spaces.txt", "one\n")
kit.write_file(src .. "/.git/HEAD", "ref\n")
kit.write_file(src .. "/tmp/junk.lua", "x\n")
fs.run("ln -s " .. fs.quote(src .. "/config.lua") .. " " .. fs.quote(src .. "/config-link.lua"))

-- The walk: skipped folders absent, the link listed and marked, sorted.
local entries = walk.list(src, walk.SURVEY_SKIPS)
local by_path = {}
for _, e in ipairs(entries) do
    by_path[e.path] = e.kind
end
kit.check(by_path["main.lua"] == "file", "walk finds main.lua")
kit.check(by_path["lib/helper.lua"] == "file", "walk finds nested files")
kit.check(by_path[".git/HEAD"] == nil, "walk skips .git")
kit.check(by_path["tmp/junk.lua"] == nil, "walk skips tmp")
kit.equal(by_path["config-link.lua"], "link", "a link is listed as a link")
kit.check(by_path["a name with spaces.txt"] == "file", "a name with spaces survives")
kit.equal(entries[1].path < entries[2].path, true, "entries sorted")
local unskipped = walk.list(src, nil)
local saw_git = false
for _, e in ipairs(unskipped) do
    if e.path == ".git/HEAD" then saw_git = true end
end
kit.check(saw_git, "walk with no skip table lists everything")
kit.raises(function() walk.list(src, walk.SURVEY_SKIPS, 3) end, "more than the limit", "the file limit refuses")
kit.write_file(folder .. "/odd/new\nline.lua", "return 1\n")
local odd = walk.list(folder .. "/odd", nil)
kit.equal(odd[1].path, "new\nline.lua", "a name with a newline survives the walk")

-- The language table.
kit.equal(languages.classify("x/Makefile", "").language, "make", "Makefile by name")
kit.equal(languages.classify("a.c", "").scanner, "c", "C by extension")
kit.equal(languages.classify("a.S", "").language, "assembly", ".S is assembly")
kit.equal(languages.classify("tool", "#!/usr/bin/env luajit\n").language, "lua", "shebang through env")
kit.equal(languages.classify("tool", "#!/bin/bash -e\n").language, "shell", "shebang with flags")
kit.equal(languages.classify("blob", "ab\0cd").role, "binary", "NUL means binary")
kit.equal(languages.classify("notes", "plain words").language, "other", "unknown is other")

-- The scanners: anchored patterns really match (the LuaJIT gmatch trap).
local c_found = includes.scan("c", '#include "a.h"\n  #  include <b.h>\n// #include "c.h"\n')
kit.equal(#c_found, 2, "C scanner finds both includes, skips the comment")
kit.equal(c_found[1].name, "a.h", "quoted include")
kit.equal(c_found[2].outside, true, "angle include is outside")
-- Only lines holding a keyword are pattern-matched; the last line with no
-- newline, and two keywords on one line, must still be found exactly once.
local tail_found = includes.scan("c", 'int x;\n#include "last.h"')
kit.equal(#tail_found, 1, "an include on a last line with no newline is found")
local twice_found = includes.scan("lua", 'local a = require("x") -- require here too\n')
kit.equal(#twice_found, 1, "a line holding the keyword twice is scanned once")
local sh_found = includes.scan("shell", "source a.sh\n. b.sh\n# source c.sh\n")
kit.equal(#sh_found, 2, "shell scanner finds source and dot")
local py_found = includes.scan("python", "import os\nfrom pkg.mod import thing\n")
kit.equal(#py_found, 2, "python scanner finds import and from")
kit.equal(py_found[2].name, "pkg.mod", "from-import names the module")
local js_found = includes.scan("javascript", 'import x from "./x"\nconst y = require("./y")\nimport "./z.css"\n')
kit.equal(#js_found, 3, "javascript scanner finds three forms")
local lua_found = includes.scan("lua", 'require("a.b")\nlocal c = require "c"\n-- require("d")\ndofile("e.lua")\n')
kit.equal(#lua_found, 3, "lua scanner finds require, bare require, dofile; skips comment")

-- Resolution: relative to the including file first, then the root.
local set = { ["lib/util.lua"] = true, ["lib/helper.lua"] = true, ["helper.lua"] = true, ["config.lua"] = true }
kit.equal(includes.resolve("lib/util.lua", "helper", "lua", set), "lib/helper.lua", "relative to the including file wins")
kit.equal(includes.resolve("main.lua", "lib.util", "lua", set), "lib/util.lua", "dots become slashes")
local to, inside = includes.resolve("main.lua", "socket", "lua", set)
kit.check(to == "socket" and inside == "no", "unresolved name is outside")
kit.equal(includes.normalise("a/./b/../c"), "a/c", "normalise . and ..")
kit.equal(includes.normalise("../x"), nil, "climbing out of the source is nil")

-- The parallel reader: identical tables at 1, 2 and every thread.
local project = kit.project_copy("survey-project")
local texts = {}
for _, threads in ipairs({ 1, 2, 7 }) do
    local file_text, link_text = survey.read_source(project, src, threads)
    texts[#texts + 1] = file_text .. "\n--\n" .. link_text
end
kit.equal(texts[2], texts[1], "two threads give the same tables as one")
kit.equal(texts[3], texts[1], "seven threads give the same tables as one")

-- A whole survey of a case, then the summary from the tables alone.
local record = case.open(project, "survey-check", src, "stand-in")
local counts = survey.run(project, record, nil)
kit.equal(counts.files, 13, "thirteen files surveyed (skips excluded, link included)")
local rows = text_tables.read(record.survey .. "/files.tsv")
local row_of = {}
for _, r in ipairs(rows) do row_of[r.path] = r end
kit.equal(row_of["README.md"].lines, "2", "README has two lines")
kit.equal(row_of["data.bin"].role, "binary", "data.bin is binary")
kit.equal(row_of["tool"].language, "lua", "shebang file is lua")
kit.equal(row_of["config-link.lua"].role, "link", "the link row")
local links = text_tables.read(record.survey .. "/links.tsv")
local link_set = {}
for _, l in ipairs(links) do link_set[l.from .. " -> " .. l.to] = l.inside end
kit.equal(link_set["main.lua -> lib/util.lua"], "yes", "main includes lib/util")
kit.equal(link_set["lib/util.lua -> lib/helper.lua"], "yes", "util includes helper (relative)")
kit.equal(link_set["engine/core.c -> engine/core.h"], "yes", "core.c includes core.h")
kit.equal(link_set["engine/core.c -> stdio.h"], "no", "stdio.h is outside")
kit.equal(link_set["run.sh -> lib/env.sh"], "yes", "run.sh sources env.sh")
kit.equal(link_set["main.lua -> commented.out"], nil, "the commented require is absent")

local s = summary.compute(record.survey)
kit.equal(s.totals.files, 13, "summary counts thirteen files")
kit.equal(s.foundations[1].path, "config.lua", "config.lua is the most included (main and tool)")
kit.equal(s.foundations[1].included_by, 2, "included by two files")
kit.equal(s.compile_units, 1, "core.c is a compile unit")
local is_entry = {}
for _, p in ipairs(s.entry_points) do is_entry[p] = true end
kit.check(is_entry["main.lua"] and is_entry["run.sh"] and is_entry["tool"], "main.lua, run.sh and tool are entry points")
kit.check(not is_entry["engine/core.c"], "core.c is not listed as an entry point")

-- The summary rebuilds with the source gone.
summary.write(record.survey)
local first = fs.read(record.survey .. "/summary.txt")
fs.remove_tree(src)
os.remove(record.survey .. "/summary.txt")
summary.write(record.survey)
kit.equal(fs.read(record.survey .. "/summary.txt"), first, "summary rebuilt identically without the source")

kit.finish()
