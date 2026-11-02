-- {{{ Template Storage Test Suite
-- Checks issue 060 without a window: templates save and load back the
-- same, sort into user, default and imported, keep backups before every
-- overwrite or delete, export and import without overwriting, read
-- older formats and warn on newer ones, survive a damaged index, work
-- on real files as well as in memory, and the library searches,
-- filters, and remembers favourites, recent use and use counts.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_template_storage').run_all()"
local TestSuite = {}

local json = require("libs.dkjson.dkjson")
local UnitTemplate = require("src.data.unit_template")
local TemplateManager = require("src.managers.template_manager")
local TemplateStorage = require("src.storage.template_storage")
local TemplateLibrary = require("src.storage.template_library")
local FileBackends = require("src.storage.file_backends")

-- {{{ local function new_storage
-- Storage in memory with a clock that ticks one second per call.
local function new_storage(backend)
    local now = 1000
    return TemplateStorage:new({backend = backend or FileBackends.memory(), clock = function()
        now = now + 1
        return now
    end})
end
-- }}}

-- {{{ local function guard
local function guard()
    return UnitTemplate.new({name = "Gate Guard", description = "Holds the gate", unit_type = "melee",
        stats = {health = 150, armor = 4}, appearance = {primary_color = {0.2, 0.4, 0.9}, size_modifier = 1.25},
        abilities = {"primary_melee_attack", {template = "power_strike", changes = {range = 18}}}})
end
-- }}}

-- {{{ TestSuite.test_save_and_load
function TestSuite.test_save_and_load()
    local storage = new_storage()
    local original = guard()
    local ok, path = storage:save_template(original, "user", {tags = {"defence"}})
    assert(ok and path == "templates/user/gate-guard.template", "Saved under its slug: " .. tostring(path))

    local loaded, info = storage:load_template("Gate Guard", "user")
    assert(loaded and loaded.is_valid, "Loads back valid")
    assert(loaded.name == "Gate Guard" and loaded.description == "Holds the gate", "Name and description")
    assert(loaded.stats.health == 150 and loaded.stats.armor == 4, "Stats")
    assert(loaded.appearance.size_modifier == 1.25 and loaded.appearance.primary_color[3] == 0.9, "Looks")
    assert(loaded:ability_config(2).range == 18, "Ability changes")
    assert(loaded.points_used == original.points_used, "The same cost")
    assert(info.metadata.tags[1] == "defence" and #info.warnings == 0, "Metadata, no warnings")
    assert(info.game_version == TemplateStorage.GAME_VERSION, "The game version is recorded")

    local missing, why = storage:load_template("Nobody", "user")
    assert(not missing and why:find("No template named", 1, true), "Missing templates say so")
    local bad, reason = storage:save_template(UnitTemplate.new({name = "Broken", abilities = {}}), "user")
    assert(not bad and reason:find("isn't valid", 1, true), "Invalid templates aren't saved")
    local odd, message = storage:save_template(guard(), "favourites")
    assert(not odd and message:find("Unknown category", 1, true), "Only the three categories")
    print("✓ Save and load test passed")
end
-- }}}

-- {{{ TestSuite.test_categories
function TestSuite.test_categories()
    local storage = new_storage()
    storage:save_template(guard(), "user")
    storage:save_template(guard(), "default")
    storage:save_template(UnitTemplate.new({name = "Archer Two", unit_type = "ranged",
        abilities = {"primary_ranged_attack"}}), "imported")
    assert(#storage:list_templates() == 3, "Three templates in all")
    assert(#storage:list_templates("user") == 1 and #storage:list_templates("default") == 1, "One each")
    local imported = storage:list_templates("imported")[1]
    assert(imported.name == "Archer Two" and imported.unit_type == "ranged" and imported.category == "imported",
        "Entries carry what search needs")
    assert(imported.abilities[1] == "primary_ranged_attack", "Including ability names")

    -- Names whose slugs collide get their own files.
    storage:save_template(UnitTemplate.new({name = "Gate-Guard", abilities = {"primary_melee_attack"}}), "user")
    local files = {}
    for _, entry in ipairs(storage:list_templates("user")) do
        files[entry.file] = true
    end
    assert(files["gate-guard.template"] and files["gate-guard-2.template"], "Colliding slugs are numbered")
    print("✓ Categories test passed")
end
-- }}}

-- {{{ TestSuite.test_backups
function TestSuite.test_backups()
    local storage = new_storage()
    storage.max_backups = 3
    local t = guard()
    storage:save_template(t, "user")
    assert(#storage:list_backups("Gate Guard", "user") == 0, "No backup of a first save")
    for health = 160, 200, 10 do
        t.stats.health = health
        storage:save_template(t, "user")
    end
    local backups = storage:list_backups("Gate Guard", "user")
    assert(#backups == 3, "Only the newest three are kept")
    assert(backups[1].serial == 3 and backups[3].serial == 5, "Oldest first, numbered")
    assert(not storage.backend.exists("templates/backups/user/gate-guard.1.template"), "Old backups are removed")

    local ok, restored = storage:restore_backup("Gate Guard", "user")
    assert(ok and restored.stats.health == 190, "The newest backup holds the save before the last")
    assert(storage:load_template("Gate Guard", "user").stats.health == 190, "Restoring saves it")

    assert(storage:delete_template("Gate Guard", "user"), "Deleting works")
    assert(not storage:load_template("Gate Guard", "user"), "And it's gone")
    local ok2, back = storage:restore_backup("Gate Guard", "user")
    assert(ok2 and back.stats.health == 190, "A deleted template can be brought back")
    assert(not storage:delete_template("Nobody", "user"), "Deleting what isn't there says so")
    print("✓ Backups test passed")
end
-- }}}

-- {{{ TestSuite.test_export_import
function TestSuite.test_export_import()
    local alice = new_storage()
    alice:save_template(guard(), "user")
    local text = alice:export_template("Gate Guard", "user")
    assert(type(text) == "string" and text:find(TemplateStorage.FORMAT, 1, true), "Exports the file text")

    local bob = new_storage()
    local ok, template, warnings = bob:import_template(text)
    assert(ok and template.name == "Gate Guard" and #warnings == 0, "Imports cleanly")
    assert(bob:load_template("Gate Guard", "imported"), "Into the imported category")
    local ok2, second = bob:import_template(text)
    assert(ok2 and second.name == "Gate Guard 2", "A second import is renamed, not overwritten")
    assert(bob:load_template("Gate Guard", "imported").name == "Gate Guard", "The first is untouched")

    local bad, why = bob:import_template("not json at all")
    assert(not bad and why:find("Not a template file", 1, true), "Junk is refused")
    local empty, why2 = bob:import_template(json.encode({hello = "world"}))
    assert(not empty and why2:find("no template", 1, true), "JSON without a template is refused")
    print("✓ Export and import test passed")
end
-- }}}

-- {{{ TestSuite.test_formats
function TestSuite.test_formats()
    local storage = new_storage()
    -- A bare to_save_data() table, from before the envelope.
    local bare = json.encode(guard():to_save_data())
    local ok, template = storage:import_template(bare)
    assert(ok and template.stats.health == 150, "Bare save data is read as format 0")
    -- The shape the issue's sketch wrote.
    local sketch = json.encode({template_version = 1, timestamp = 5, template_data = guard():to_save_data(),
        metadata = {author = "Ritz", tags = {"old"}}})
    local ok2, old, warnings = storage:import_template(sketch)
    assert(ok2 and old.name == "Gate Guard 2" and #warnings == 0, "The sketch's shape is read too")
    assert(storage:list_templates("imported")[2].tags[1] == "old", "Its metadata survives")
    -- A newer format: read what we can, and say so.
    local future = json.decode(storage:export_template("Gate Guard", "imported"))
    future.format_version = 7
    future.template.new_field = "something new"
    local ok3, _, warnings3 = storage:import_template(json.encode(future))
    assert(ok3 and warnings3[1]:find("newer format", 1, true), "Newer files load with a warning")
    -- A file whose template no longer passes the rules still loads, with
    -- warnings, so a player can fix it.
    local stale = json.decode(storage:export_template("Gate Guard", "imported"))
    stale.template.stats.health = 9000
    storage.backend.write("templates/imported/gate-guard.template", json.encode(stale))
    local loaded, info = storage:load_template("Gate Guard", "imported")
    assert(loaded and not loaded.is_valid and info.warnings[1]:find("No longer valid", 1, true),
        "Out-of-date templates load with warnings")
    print("✓ Formats test passed")
end
-- }}}

-- {{{ TestSuite.test_damaged_index
function TestSuite.test_damaged_index()
    local backend = FileBackends.memory()
    local storage = new_storage(backend)
    storage:save_template(guard(), "user")
    storage:save_template(UnitTemplate.new({name = "Scout", unit_type = "special", abilities = {"primary_ranged_attack"}}),
        "default")
    backend.write("templates/template_index.json", "{{{ broken")
    local again = new_storage(backend)
    assert(again.warnings[1]:find("rebuilt", 1, true), "A damaged index is noticed")
    assert(#again:list_templates() == 2, "And rebuilt from the files")
    assert(again:load_template("Scout", "default").unit_type == "special", "Templates load after the rebuild")
    local reopened = new_storage(backend)
    assert(#reopened.warnings == 0 and #reopened:list_templates() == 2, "The rebuilt index was saved")
    print("✓ Damaged index test passed")
end
-- }}}

-- {{{ TestSuite.test_disk
-- The same on real files, in a fresh folder under the system's temp.
function TestSuite.test_disk()
    local folder = os.tmpname()
    os.remove(folder)
    local backend = FileBackends.disk(folder)
    local storage = new_storage(backend)
    local ok = storage:save_template(guard(), "user")
    assert(ok, "Saved to disk")
    local file = io.open(folder .. "/templates/user/gate-guard.template", "rb")
    assert(file, "The file is really there")
    file:close()
    local reopened = new_storage(FileBackends.disk(folder))
    local loaded = reopened:load_template("Gate Guard", "user")
    assert(loaded and loaded.stats.health == 150, "A new storage on the same folder finds it")
    reopened:delete_template("Gate Guard", "user")
    -- Tidy up what this test made.
    os.remove(folder .. "/templates/backups/user/gate-guard.1.template")
    os.remove(folder .. "/templates/template_index.json")
    for _, sub in ipairs({"backups/user", "backups/default", "backups/imported", "backups", "user", "default", "imported", ""}) do
        os.remove(folder .. "/templates/" .. sub)
    end
    os.remove(folder)
    print("✓ Disk test passed")
end
-- }}}

-- {{{ TestSuite.test_manager_round_trip
function TestSuite.test_manager_round_trip()
    local storage = new_storage()
    local manager = TemplateManager:new()
    manager:create_default_templates()
    manager:register_template(guard())
    local saved, problems = manager:save_to_storage(storage)
    assert(saved == #manager:list() and #problems == 0, "Every template is saved")
    assert(#storage:list_templates("default") == #manager:list() - 1, "Defaults go to default")
    assert(storage:load_template("Gate Guard", "user"), "Others go to user")

    local fresh = TemplateManager:new()
    local loaded = fresh:load_from_storage(storage)
    assert(loaded == saved and #fresh:list() == #manager:list(), "All come back")
    assert(fresh:is_default("Warrior") and not fresh:is_default("Gate Guard"), "Defaults stay marked")
    print("✓ Manager round trip test passed")
end
-- }}}

-- {{{ TestSuite.test_library
function TestSuite.test_library()
    local storage = new_storage()
    local manager = TemplateManager:new()
    manager:create_default_templates()
    manager:save_to_storage(storage)
    storage:save_template(guard(), "user", {tags = {"defence"}})
    local library = TemplateLibrary:new(storage)

    local results = library:search("warrior")
    assert(results[1].name == "Warrior", "An exact name comes first")
    local heal = library:search("heal")
    local names = {}
    for _, row in ipairs(heal) do names[row.name] = true end
    assert(names["Cleric"] and names["Field Medic"] and names["Druid"], "Ability names are searched")
    assert(library:search("defence")[1].name == "Gate Guard", "Tags are searched")
    assert(#library:search("warrior archer") == 0, "Every word must match")
    assert(#library:search("") == #storage:list_templates(), "No words lists everything")

    assert(#library:search("", {unit_type = "ranged"}) == 3, "Filter by body")
    assert(#library:search("", {category = "user"}) == 1, "Filter by category")
    for _, row in ipairs(library:search("", {max_points = 60})) do
        assert(row.points_used <= 60, "Filter by points")
    end
    assert(library:search("", {ability = "static_field"})[1].name == "Storm Caller", "Filter by ability")

    library:set_favorite("Druid", "default")
    assert(library:is_favorite("Druid", "default") and not library:is_favorite("Druid", "user"), "Favourites by category")
    assert(#library:search("", {favorites_only = true}) == 1, "Favourites only")
    local supports = library:search("support")
    assert(supports[1].name == "Druid" and supports[1].favorite, "Favourites rise in results")

    assert(library:use("Gate Guard", "user"), "Using loads the template")
    library:use("Archer", "default")
    library:use("Gate Guard", "user")
    local recent = library:recent()
    assert(recent[1].name == "Gate Guard" and recent[2].name == "Archer" and #recent == 2, "Recent, newest first, no repeats")
    assert(library:usage_count("Gate Guard", "user") == 2, "Uses are counted")

    local reopened = TemplateLibrary:new(storage)
    assert(reopened:is_favorite("Druid", "default") and reopened:usage_count("Gate Guard", "user") == 2
        and reopened:recent()[1].name == "Gate Guard", "Preferences are kept")
    library:set_favorite("Druid", "default", false)
    assert(not TemplateLibrary:new(storage):is_favorite("Druid", "default"), "And favourites can be cleared")
    print("✓ Library test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running template storage tests...")
    TestSuite.test_save_and_load()
    TestSuite.test_categories()
    TestSuite.test_backups()
    TestSuite.test_export_import()
    TestSuite.test_formats()
    TestSuite.test_damaged_index()
    TestSuite.test_disk()
    TestSuite.test_manager_round_trip()
    TestSuite.test_library()
    print("✅ All template storage tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
