-- {{{ Template Editor Test Suite
-- Checks the logic of issue 062 without a window: tabs, every kind of
-- edit (name, body, colours, size, stats, abilities, budget fixes),
-- undo and redo (with changes grouped into one step), unsaved-change tracking, saving and loading through
-- template storage, the feedback list, the preview hookup, and a panel
-- layout that fits windows of many sizes.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_template_editor').run_all()"
local TestSuite = {}

local TemplateEditor = require("src.editor.template_editor")
local TemplateStorage = require("src.storage.template_storage")
local FileBackends = require("src.storage.file_backends")
local TemplateCosts = require("src.data.template_costs")
local UnitTemplate = require("src.data.unit_template")
local TemplateManager = require("src.managers.template_manager")

-- {{{ local function fresh
local function fresh(template)
    return TemplateEditor:new({template = template, storage = TemplateStorage:new({backend = FileBackends.memory()})})
end
-- }}}

-- {{{ TestSuite.test_tabs
function TestSuite.test_tabs()
    local editor = fresh()
    assert(editor.tab == "stats", "The first tab is stats")
    assert(editor:switch_tab("preview") and editor.tab == "preview", "Tabs can be chosen")
    assert(editor:switch_tab("settings") == false and editor.tab == "preview", "Unknown tabs are refused")
    assert(editor:next_tab(1) == "stats", "Tabs wrap forward")
    assert(editor:next_tab(-1) == "preview", "And back")
    print("✓ Tabs test passed")
end
-- }}}

-- {{{ TestSuite.test_edits
function TestSuite.test_edits()
    local editor = fresh()
    assert(editor.template.is_valid and not editor:is_dirty(), "A new template is valid and clean")
    editor:set_name("Iron Wall")
    editor:set_description("Holds the lane.")
    assert(editor.template.name == "Iron Wall" and editor:is_dirty(), "Naming makes it dirty")

    editor:set_stat("health", 160)
    assert(editor:set_unit_type("tank") == "tank", "The body can change")
    for _, stat in ipairs(UnitTemplate.STAT_NAMES) do
        assert(editor.template.stats[stat] == TemplateCosts.bodies.tank[stat], "Stats go to the new body's: " .. stat)
    end
    assert(editor.template.appearance.shape == require("src.entities.unit").get_unit_shape("tank"),
        "The shape follows the body")
    assert(editor:set_unit_type("dragon") == nil, "Unknown bodies are refused")

    local color = editor:set_color("primary", 2, 0.5, -1)
    assert(color[1] == 1 and color[2] == 0.5 and color[3] == 0, "Colours are held to 0-1")
    assert(editor:set_color("tertiary", 1, 1, 1) == nil, "Two colours only")
    assert(editor:set_size(9) == TemplateEditor.SIZE_LIMITS.max, "Size is held to its limits")

    local kept, note = editor:set_stat("health", 999)
    assert(kept == 500 and note, "Stats go through the allocator's limits")
    kept, note = editor:set_stat("armor", 40)
    assert(kept < 40 and note:find("over budget", 1, true), "And its budget")
    assert(editor.template.points_used <= editor.template.point_budget, "And stay in budget")
    assert(editor:apply_preset("bruiser"), "Presets apply")

    editor:set_stat("health", TemplateCosts.bodies.tank.health)
    editor:set_stat("armor", TemplateCosts.bodies.tank.armor)
    local ok, preview = editor:set_ability(2, "crippling_blow", {duration = 6})
    assert(ok and preview.valid, "An ability can be added")
    assert(editor.template.abilities[2].template == "crippling_blow" and editor.template.abilities[2].changes.duration == 6,
        "With its tuning")
    assert(editor:set_ability(1, "focus") == nil, "The primary slot refuses a buff")
    assert(editor:remove_ability(2) and #editor.template.abilities == 1, "An ability can be removed")
    assert(editor:remove_ability(1) == nil, "But not the last one")
    print("✓ Edits test passed")
end
-- }}}

-- {{{ TestSuite.test_undo_redo
function TestSuite.test_undo_redo()
    local editor = fresh()
    editor:set_name("First Name")
    editor:set_stat("health", 150)
    editor:set_stat("health", 150)
    assert(#editor.undo_stack == 2, "An edit that changes nothing isn't a step")
    assert(editor:undo() == "set health" and editor.template.stats.health == 120, "Undo")
    assert(editor:undo() == "rename" and editor.template.name == "New Unit", "Undo again")
    assert(editor:undo() == nil and not editor:is_dirty(), "Back at the start, and clean")
    assert(editor:redo() == "rename" and editor:redo() == "set health", "Redo")
    assert(editor.template.stats.health == 150 and editor:redo() == nil, "All the way")
    editor:undo()
    editor:set_name("Other Name")
    assert(editor:redo() == nil, "A new edit clears redo")
    for i = 1, TemplateEditor.HISTORY_LIMIT + 10 do
        editor:set_name("Name " .. i)
    end
    assert(#editor.undo_stack == TemplateEditor.HISTORY_LIMIT, "History is limited")
    assert(editor.last_change and editor.last_change.delta == 0, "Each change is recorded for a screen")
    editor:set_stat("speed", 80)
    assert(editor.last_change.delta == 4 and editor.last_change.groups.stats == 4, "With its points")
    print("✓ Undo and redo test passed")
end
-- }}}

-- {{{ TestSuite.test_grouped_changes
-- A slider drag makes many changes; with a group they undo as one step,
-- and the stat helpers behave like the allocator's.
function TestSuite.test_grouped_changes()
    local editor = fresh()
    assert(editor:step_stat("health", 1) == 130 and editor:step_stat("health", -1) == 120, "Stepping a stat")
    assert(#editor.undo_stack == 2, "Each step is a step")
    editor:begin_group("drag health")
    for _, fraction in ipairs({0.1, 0.2, 0.3, 0.25}) do
        assert(editor:set_stat_fraction("health", fraction), "A slider position")
    end
    local dragged = editor.template.stats.health
    assert(editor:end_group() == true, "The group changed something")
    assert(#editor.undo_stack == 3, "The whole drag is one undo step")
    assert(editor:undo() == "drag health" and editor.template.stats.health == 120, "Undone in one go")
    assert(editor:redo() == "drag health" and editor.template.stats.health == dragged, "Redone in one go")
    editor:begin_group("still")
    assert(editor:end_group() == false and #editor.undo_stack == 3, "A group that changes nothing adds nothing")
    editor:begin_group("left open")
    editor:set_stat("speed", 70)
    editor:undo()
    editor:set_stat("speed", 75)
    assert(#editor.undo_stack == 4 and editor:undo() == "set speed", "Undo closes an open group: the next change is its own step")
    assert(editor:step_stat("nothing", 1) == nil, "An unknown stat is refused")
    print("✓ Grouped changes test passed")
end
-- }}}

-- {{{ TestSuite.test_save_and_load
function TestSuite.test_save_and_load()
    local editor = fresh()
    editor:set_name("Saved Unit")
    editor:set_stat("health", 200)
    local ok, path = editor:save()
    assert(ok and path:find("saved-unit", 1, true) and not editor:is_dirty(), "Saving makes it clean")
    editor:set_stat("health", 250)
    assert(editor:load("Saved Unit") == nil, "Loading over unsaved changes is refused")
    assert(editor:new_template("ranged") == nil, "So is starting anew")
    assert(not editor:can_exit() and editor:can_exit(true), "And leaving, unless forced")
    assert(editor:revert() and editor.template.stats.health == 200 and not editor:is_dirty(), "Revert to the save")
    assert(editor:undo() == "revert", "Revert is undoable")
    local loaded, info = editor:load("Saved Unit", nil, true)
    assert(loaded.stats.health == 200 and info.saved_at, "A forced load")
    assert(#editor.undo_stack == 0 and not editor:is_dirty(), "Loading starts a fresh history")
    assert(editor:load("Nobody") == nil, "Missing templates")
    local over = TemplateEditor:new({template = UnitTemplate.new({name = "Too Much", unit_type = "melee",
        stats = {armor = 40, health = 500}, abilities = {"primary_melee_attack"}}), storage = editor.storage})
    local saved, why = over:save()
    assert(saved == false and why:find("isn't valid", 1, true), "An invalid template isn't saved")
    assert(TemplateEditor:new():save() == false, "No storage, no save")
    local blank = editor:new_template("ranged", true)
    assert(blank.unit_type == "ranged" and blank.abilities[1].template == "primary_ranged_attack", "A new ranged unit")
    print("✓ Save and load test passed")
end
-- }}}

-- {{{ TestSuite.test_feedback_and_fixes
function TestSuite.test_feedback_and_fixes()
    local editor = fresh(UnitTemplate.new({name = "Heavy Hitter", unit_type = "melee",
        stats = {health = 250, armor = 8}, abilities = {"axe_attack", "power_strike", "battle_fury"}}))
    local feedback = editor:feedback()
    assert(feedback[1].severity == "error" and feedback[1].text:find("Over budget"), "Over budget leads the feedback")
    local suggestions = editor:optimize()
    assert(#suggestions > 0, "Ways back into budget")
    assert(editor:apply_suggestion(suggestions[1]), "One can be applied")
    assert(editor.template.points_used <= editor.template.point_budget, "And it fits")
    assert(editor.last_change.back_in_budget, "A screen hears it came back in budget")
    assert(editor:undo() == suggestions[1].description, "Undo names the fix")
    print("✓ Feedback and fixes test passed")
end
-- }}}

-- {{{ TestSuite.test_preview_hookup
function TestSuite.test_preview_hookup()
    local warrior = TemplateManager:new():create_default_templates({"starter"})["Warrior"]
    local editor = fresh(warrior)
    local first = editor:analysis()
    assert(first.survival.health == warrior.stats.health, "The preview analyses the template being edited")
    assert(editor:analysis() == first, "And keeps it while nothing changes")
    editor:set_stat("health", 200)
    assert(editor:analysis().survival.health == 200, "And follows changes")
    print("✓ Preview hookup test passed")
end
-- }}}

-- {{{ TestSuite.test_layout
function TestSuite.test_layout()
    local names = {"tabs", "editor", "preview", "budget", "buttons"}
    for _, size in ipairs({{320, 240}, {640, 480}, {800, 600}, {999, 700}, {1000, 700}, {1280, 720}, {1920, 1080},
            {2560, 1440}}) do
        local width, height = size[1], size[2]
        local layout = TemplateEditor.layout(width, height)
        assert(layout.mode == (width >= TemplateEditor.WIDE and "wide" or "narrow"), "Mode by width")
        for i, name in ipairs(names) do
            local r = layout[name]
            assert(r.x >= 0 and r.y >= 0 and r.x + r.width <= width and r.y + r.height <= height,
                string.format("%s fits %dx%d", name, width, height))
            assert(r.width > 0 and r.height > 0, string.format("%s is visible at %dx%d", name, width, height))
            for j = i + 1, #names do
                local o = layout[names[j]]
                local apart = r.x + r.width <= o.x or o.x + o.width <= r.x or r.y + r.height <= o.y
                    or o.y + o.height <= r.y
                assert(apart, string.format("%s and %s don't overlap at %dx%d", name, names[j], width, height))
            end
        end
        if layout.mode == "wide" then
            assert(layout.editor.y == layout.preview.y and layout.editor.width > layout.preview.width,
                "Wide: side by side, editor larger")
        else
            assert(layout.preview.y > layout.editor.y and layout.preview.width == layout.editor.width, "Narrow: stacked")
        end
    end
    print("✓ Layout test passed")
end
-- }}}

-- {{{ TestSuite.test_speed
function TestSuite.test_speed()
    local editor = fresh()
    local start = os.clock()
    for i = 1, 100 do
        editor:set_stat("health", 120 + (i % 10) * 10)
        editor:budget()
        editor:analysis()
    end
    local seconds = os.clock() - start
    assert(seconds < 5, string.format("100 edits with budget and preview take %.2f s", seconds))
    print(string.format("✓ Speed test passed (%.2f s)", seconds))
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running template editor tests...")
    TestSuite.test_tabs()
    TestSuite.test_edits()
    TestSuite.test_undo_redo()
    TestSuite.test_grouped_changes()
    TestSuite.test_save_and_load()
    TestSuite.test_feedback_and_fixes()
    TestSuite.test_preview_hookup()
    TestSuite.test_layout()
    TestSuite.test_speed()
    print("✅ All template editor tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
