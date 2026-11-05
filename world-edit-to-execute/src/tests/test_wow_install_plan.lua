--[[
Tests for W02f step 2: the install plan of a build folder
(src/wowbuild/install_plan.lua). The converter writes install-plan.lua:
which rows go into which database and table, which files go to which of
the server's folders (the shim's included), checked here against a
stand-in for W02h's empty world database
(src/tests/fixtures/install-plan/empty-world-schema.lua), which is the
converter's own tables and columns, not AzerothCore's (W02f: unchecked).

    luajit src/tests/test_wow_install_plan.lua [project folder]

The real conversion needs the map archive reader (StormLib); without it
that part is skipped.
]]

-- {{{ Setup paths
local DIR = arg[1] or (debug.getinfo(1, "S").source:match("^@(.-)/?src/tests/[^/]*$"))
    or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if DIR == "" then DIR = "." end
if DIR:sub(-1) ~= "/" then DIR = DIR .. "/" end
package.path = DIR .. "src/?.lua;" .. DIR .. "src/?/init.lua;" .. package.path

local install_plan = require("wowbuild.install_plan")
local server_stamp = require("wowbuild.server_stamp")
local wowbuild = require("wowbuild")
-- }}}

-- {{{ Test infrastructure
local test_count, pass_count, skip_count = 0, 0, 0
local function test(name, condition, msg)
    test_count = test_count + 1
    if condition then
        pass_count = pass_count + 1
        print("  [PASS] " .. name)
    else
        print("  [FAIL] " .. name .. (msg and ": " .. tostring(msg) or ""))
    end
end
local function skip(name, why)
    skip_count = skip_count + 1
    print("  [SKIP] " .. name .. ": " .. why)
end
local function section(name) print("\n=== " .. name .. " ===") end
local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end
local function write(path, text)
    local dir = path:match("^(.*)/[^/]*$")
    if dir then os.execute("mkdir -p " .. quote(dir)) end
    local f = assert(io.open(path, "wb"))
    f:write(text)
    f:close()
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
local function has(list, needle)
    for _, s in ipairs(list or {}) do if tostring(s):find(needle, 1, true) then return true end end
    return false
end
local TMP = os.tmpname()
os.remove(TMP)
os.execute("mkdir -p " .. quote(TMP))

-- the stand-in, read as the plan is: data, in an empty environment
local SCHEMA
do
    local chunk = assert(loadfile(DIR .. "src/tests/fixtures/install-plan/empty-world-schema.lua"))
    setfenv(chunk, {})
    SCHEMA = chunk()
end
-- }}}

-- {{{ The converter's SQL, statement by statement
section("The converter's SQL, statement by statement")
do
    local st = install_plan.statements(table.concat({
        "-- a comment; with a semicolon",
        "SET @MAP := 900;  -- the map",
        "/* a block; comment */",
        "DELETE FROM `creature` WHERE `map` = @MAP;",
        "INSERT INTO `creature_template` (`entry`, `name`, `faction`) VALUES",
        "  (@ENTRY + 0, 'it''s; (one)', 3),  -- a note, with (brackets",
        "  (@ENTRY + 1, 'two\\'s,\nlines', 4);",
        "REPLACE INTO `map_dbc` VALUES",
        "  (900, 'WC3_X', 0),",
        "  (901, 'WC3_Y', 0);",
        "INSERT INTO `t` (`a`, `b`) VALUES (1, 2), (3);",
        "UPDATE `creature` SET `map` = 1;",
    }, "\n"))
    test("six statements: comments and quoted text don't end one", #st == 6, #st)
    test("SET is kept as what it sets", st[1].does == "set" and st[1].set == "@MAP := 900", st[1].set)
    test("a delete names its table and its WHERE", st[2].does == "delete" and st[2].table == "creature"
        and st[2].where == "`map` = @MAP", st[2].where)
    local ins = st[3]
    test("an insert names its table and columns", ins.does == "insert" and ins.table == "creature_template"
        and table.concat(ins.columns, ",") == "entry,name,faction")
    test("... two rows of three values (a quote, a comma, a bracket, a line break inside text)",
        ins.rows == 2 and ins.values == 3, tostring(ins.rows) .. " " .. tostring(ins.values))
    test("a replace by position: no columns, rows and values", st[4].does == "replace" and st[4].columns == nil
        and st[4].rows == 2 and st[4].values == 3)
    test("rows of different widths are kept as such", st[5].values == nil and st[5].values_differ
        and table.concat(st[5].values_differ, ",") == "1,2")
    test("anything else is 'other'", st[6].does == "other" and st[6].first == "UPDATE")
    test("no statements in an empty text", #install_plan.statements("") == 0 and #install_plan.statements("-- only\n") == 0)
end
-- }}}

-- {{{ A build folder made by hand
local function made_build(b)
    write(b .. "/server/world.sql", table.concat({
        "SET @MAP := 900;",
        "DELETE FROM `creature` WHERE `map` = @MAP;",
        "INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES",
        "  (1, 0, 50000, 1, 1),",
        "  (2, 0, 50001, 1, 1);",
        "INSERT INTO `creature` (`guid`, `id`, `map`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `Comment`) VALUES",
        "  (1, 1, @MAP, 1, 1, 0.000, 0.000, 0.000, 0.0000, 300, 'W02b: hfoo');",
        "" }, "\n"))
    local row = {}
    for i = 1, 66 do row[i] = tostring(i) end
    write(b .. "/server/dbc.sql", "REPLACE INTO `map_dbc` VALUES\n  (" .. table.concat(row, ", ") .. ");\n")
    write(b .. "/server/dbc/Map.dbc", "WDBC map")
    write(b .. "/server/dbc/notes.txt", "not a table")
    write(b .. "/server/triggers/WC3_A/war3map.lua", "-- a")
    write(b .. "/server/triggers/WC3_A/map-data.lua", "return {}")
    write(b .. "/server/triggers/WC3_A/natives-report.lua", "return { seconds = 1 }")
    write(b .. "/patch-W.MPQ", "MPQ\26 bytes")
    write(b .. "/map.lua", "return {}")
    return install_plan.copy_shim(b, DIR)
end
-- }}}

-- {{{ The shim, copied into the build
section("The shim, copied into the build as bytes")
local B = TMP .. "/made"
do
    local copied = made_build(B)
    local modules, same, fake = 0, true, false
    local p = io.popen("ls " .. quote(DIR .. "server-side/ale/wc3shim"))
    for name in p:lines() do
        if name:match("%.lua$") then
            local there = read(B .. "/server/ale/wc3shim/" .. name)
            if name == "fake_ale.lua" then fake = there ~= nil
            else
                modules = modules + 1
                same = same and there == read(DIR .. "server-side/ale/wc3shim/" .. name)
            end
        end
    end
    p:close()
    test("every module of the shim, byte for byte", modules >= 7 and same, modules)
    test("... but not the stand-in for ALE (fake_ale.lua)", not fake)
    test("... with the folder's licence (AGPL v3)", read(B .. "/server/ale/LICENSE") == read(DIR .. "server-side/LICENSE")
        and (read(B .. "/server/ale/LICENSE") or ""):find("GNU AFFERO", 1, true) ~= nil)
    test("the files copied are listed", #copied == modules + 1 and copied[#copied].path == "server/ale/LICENSE")
    write(B .. "/server/ale/wc3shim/old_module.lua", "-- from an older shim")
    install_plan.copy_shim(B, DIR)
    test("copied again: a module the shim no longer has is gone", read(B .. "/server/ale/wc3shim/old_module.lua") == nil)
    local ok, err = pcall(install_plan.copy_shim, TMP .. "/elsewhere", TMP .. "/no-project")
    test("no shim where the project should be: refused, saying so", not ok and tostring(err):find("no shim", 1, true) ~= nil, err)
end
-- }}}

-- {{{ The plan
section("The plan of a build folder")
local plan, text
do
    server_stamp.write(B)
    plan, text = install_plan.write(B, wowbuild.serialize)
    test("written as install-plan.lua, and read back the same", read(B .. "/install-plan.lua") == text
        and install_plan.read(B) ~= nil)
    test("its first lines say it's data and unchecked", text:match("^%-%- W02f step 2") and text:find("Nothing in it is checked", 1, true))
    test("the same folder, the same plan, byte for byte", select(2, install_plan.write(B, wowbuild.serialize)) == text)
    test("no time in it", not text:find("written", 1, true) and not text:find("seconds", 1, true))

    test("the SQL in its order: the tables' rows, then the creatures",
        #plan.sql == 2 and plan.sql[1].file == "server/dbc.sql" and plan.sql[2].file == "server/world.sql")
    test("... both into the world database", plan.sql[1].database == "world" and plan.sql[2].database == "world")
    test("... the variables they set, kept", plan.sql[2].sets and plan.sql[2].sets[1] == "@MAP := 900")
    local T = plan.tables
    test("every statement but SET: which table, what it does", #T == 4 and T[1].table == "map_dbc" and T[1].does == "replace"
        and T[2].table == "creature" and T[2].does == "delete" and T[3].table == "creature_template_model"
        and T[4].table == "creature" and T[4].does == "insert", #T)
    test("... with its rows and values", T[1].rows == 1 and T[1].values == 66 and T[3].rows == 2 and T[3].values == 5
        and T[4].rows == 1 and T[4].values == 11)
    test("... its file and database", T[3].from == "server/world.sql" and T[3].database == "world")

    local by = {}
    for _, f in ipairs(plan.files) do by[f.from] = f end
    local map = by["server/dbc/Map.dbc"]
    test("a merged table goes to the server's dbc folder, replacing the stock one", map and map.place == "dbc"
        and map.to == "Map.dbc" and map.replaces ~= nil)
    test("... only tables (notes.txt stays)", by["server/dbc/notes.txt"] == nil)
    local init = by["server/ale/wc3shim/init.lua"]
    test("the shim goes to ALE's scripts, in its own folder", init and init.place == "ale_scripts" and init.to == "wc3shim/init.lua")
    local lic = by["server/ale/LICENSE"]
    test("... with its licence, which the server doesn't read (so no stamp)", lic and lic.to == "wc3shim/LICENSE" and lic.stamped == false)
    local s, d = by["server/triggers/WC3_A/war3map.lua"], by["server/triggers/WC3_A/map-data.lua"]
    test("a map's script and data go to the loader's folder, not ALE's scripts", s and d and s.place == "ale_maps"
        and s.to == "WC3_A/war3map.lua" and d.to == "WC3_A/map-data.lua")
    test("the reports aren't installed", by["server/triggers/WC3_A/natives-report.lua"] == nil and by["map.lua"] == nil)
    test("patch-W.MPQ is kept, with why", plan.kept[1] and plan.kept[1].file == "patch-W.MPQ" and plan.kept[1].why:find("W02d", 1, true))
    test("what waits: W02d's map files for the map, step 3's loader", has(plan.waiting, "W02d") and has(plan.waiting, "WC3_A")
        and has(plan.waiting, "step 3"))
    local unchecked, n = true, 0
    for _, p in pairs(plan.places) do n = n + 1 unchecked = unchecked and p.checked == false and p.note ~= nil end
    test("four places, each unchecked with a note of where it comes from", n == 4 and unchecked)
    test("every file goes to a place the plan names", (function()
        for _, f in ipairs(plan.files) do if not plan.places[f.place] then return false end end
        return true end)())
end
-- }}}

-- {{{ Read as data only
section("Read as data, refused when it isn't a plan")
do
    local b = TMP .. "/odd"
    write(b .. "/install-plan.lua", "return os.exit(3)")
    local p, why = install_plan.read(b)
    test("read in an empty environment: a plan that calls out is refused", p == nil and why ~= nil, why)
    write(b .. "/install-plan.lua", "return { format = 2 }")
    p, why = install_plan.read(b)
    test("format 2: refused", p == nil and why:find("format", 1, true), why)
    os.remove(b .. "/install-plan.lua")
    p, why = install_plan.read(b)
    test("no plan: nil and why", p == nil and why:find("no install-plan.lua", 1, true), why)
end
-- }}}

-- {{{ Checked against the stand-in
section("Checked against a stand-in for the empty world database")
do
    local ok, problems = install_plan.check(plan, SCHEMA, B)
    test("the made folder's plan fits the stand-in and the folder", ok, table.concat(problems or {}, "; "))

    local function fails(name, needle, p, schema, b)
        local good, list = install_plan.check(p or plan, schema or SCHEMA, b == nil and B or b or nil)
        test(name, not good and has(list, needle), table.concat(list or {}, "; "))
    end
    local s = copy(SCHEMA) s.world.creature_template_model = nil
    fails("a table the database lacks", "no table creature_template_model", nil, s)
    s = copy(SCHEMA) s.world.creature.columns[11] = nil
    fails("a column the table lacks", "no column Comment", nil, s)
    s = copy(SCHEMA) s.world.map_dbc.count = 67
    fails("a table filled by position with another width", "map_dbc's rows have 66 values, 67 wanted", nil, s)
    fails("a database the schema lacks", "no database world", nil, {})
    local p = copy(plan) p.tables[3].values = 4
    fails("rows with fewer values than columns", "4 values, 5 wanted", p)
    p = copy(plan) p.tables[3].values, p.tables[3].values_differ = nil, { 4, 5 }
    fails("rows of different widths", "have 4 or 5 values", p)
    p = copy(plan) p.tables[#p.tables + 1] = { does = "other", first = "UPDATE", from = "server/world.sql" }
    fails("a statement it can't place", "can't place", p)
    p = copy(plan) p.files[1].to = "../../etc/passwd"
    fails("a file going outside its place", "not a path inside its place", p)
    p = copy(plan) p.files[1].to = "/etc/passwd"
    fails("... or to an absolute path", "not a path inside its place", p)
    p = copy(plan) p.files[2].to = p.files[1].to p.files[2].place = p.files[1].place
    fails("two files to the same place", "goes where", p)
    p = copy(plan) p.files[1].place = "elsewhere"
    fails("a place the plan doesn't name", "no folder elsewhere", p)
    p = copy(plan) p.kept = {}
    fails("a file the server reads that the plan neither installs nor keeps", "patch-W.MPQ: the server reads it", p)
    p = copy(plan) p.files[#p.files + 1] = { from = "server/triggers/WC3_A/natives-report.lua", place = "ale_maps", to = "x.lua" }
    fails("a file the stamp doesn't name", "the server-stamp doesn't name it", p)
    p = copy(plan) p.files[#p.files + 1] = { from = "server/gone.lua", place = "ale_maps", to = "gone.lua", stamped = false }
    fails("a file the build doesn't hold", "server/gone.lua: not in the build", p)
    test("without a build folder, only the schema and the plan are checked", install_plan.check(plan, SCHEMA))
    test("not a plan: refused", not install_plan.check({ format = 9 }, SCHEMA))
end
-- }}}

-- {{{ The stamp names the shim now
section("The server's stamp names the shim")
do
    local files = server_stamp.files(B)
    test("every module of the shim the build holds", has(files, "server/ale/wc3shim/init.lua") and has(files, "server/ale/wc3shim/units.lua"))
    test("... not its licence, not the plan", not has(files, "LICENSE") and not has(files, "install-plan.lua"))
    local before = server_stamp.text(B)
    write(B .. "/server/ale/wc3shim/units.lua", "-- another shim")
    test("a changed shim module: another stamp", server_stamp.text(B) ~= before)
    local was = server_stamp.text(B)
    install_plan.write(B, wowbuild.serialize)
    test("a plan written anew: the same stamp", server_stamp.text(B) == was)
end
-- }}}

-- {{{ W02's converter writes it
section("W02's converter writes the plan and the shim")
do
    local map = DIR .. "assets/Daow4.4.w3x"
    local ok, err = pcall(function() require("mpq").open(map):close() end)
    if not ok then
        skip("the converter's plan on Daow 4.4", tostring(err):sub(1, 80))
    else
        local b = TMP .. "/daow"
        local report = wowbuild.convert(map, b, {})
        local p = install_plan.read(b)
        test("the build holds install-plan.lua, the report counts it", p ~= nil and report.install_plan
            and report.install_plan.file == "install-plan.lua" and report.install_plan.tables == #p.tables
            and report.install_plan.files == #p.files)
        local good, problems = install_plan.check(p, SCHEMA, b)
        test("it fits the stand-in, its build folder and its stamp", good, table.concat(problems or {}, "; "))
        local tables = {}
        for _, t in ipairs(p and p.tables or {}) do tables[t.table] = (tables[t.table] or 0) + (t.rows or 0) end
        test("the creatures' templates and models, and the client tables' rows, go into the world database",
            (tables.creature_template or 0) > 0 and (tables.creature_template_model or 0) > 0
            and (tables.map_dbc or 0) == 1 and (tables.areatable_dbc or 0) == 1, (tables.creature_template or 0))
        local shim, scripts = false, false
        for _, f in ipairs(p and p.files or {}) do
            shim = shim or f.from == "server/ale/wc3shim/init.lua"
            scripts = scripts or f.from == "server/triggers/" .. report.map_directory .. "/war3map.lua"
        end
        test("the shim and the map's script are installed", shim and scripts)
        local in_files = false
        for _, f in ipairs(report.files) do in_files = in_files or f.path == "install-plan.lua" end
        test("the report's file list has it", in_files)
        test("the stamp names the shim", (read(b .. "/server-stamp") or ""):find("server/ale/wc3shim/init.lua", 1, true) ~= nil)
        local text = read(b .. "/install-plan.lua")
        wowbuild.convert(map, b, {})
        test("converted again: the same plan, byte for byte", read(b .. "/install-plan.lua") == text)
        local bad = pcall(wowbuild.convert, map, b, { name = "not a name!" })
        test("a conversion refused before it began leaves the plan as it was", not bad and read(b .. "/install-plan.lua") == text)
        test("not built yet, says the report: W02f's later steps", has(report.not_built, "install-plan.lua"))
    end
end
-- }}}

os.execute("rm -rf " .. quote(TMP))

-- {{{ Summary
print(string.format("\n%s\nTests: %d passed, %d failed, %d skipped", string.rep("=", 50), pass_count,
    test_count - pass_count, skip_count))
os.exit(pass_count == test_count and 0 or 1)
-- }}}
