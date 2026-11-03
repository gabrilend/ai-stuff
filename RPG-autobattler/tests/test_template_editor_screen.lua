-- {{{ Template Editor Screen Test Suite
-- A smoke test of the template editor's screen against a stand-in for
-- LÖVE: no window, no font. The stand-in graphics object records every
-- call, so these check that the screen runs without errors at several
-- window sizes, on every tab, while sliders are dragged, text typed and
-- keys pressed, and that its input reaches the editor's tested logic.
-- They don't check that it looks right; only a person at a screen can.
-- Run from the project folder:
--   luajit -e "package.path='./?.lua;'..package.path; require('tests.test_template_editor_screen').run_all()"
local TestSuite = {}

local TemplateEditorScreen = require("src.editor.template_editor_screen")
local TemplateEditor = require("src.editor.template_editor")
local TemplateStorage = require("src.storage.template_storage")
local FileBackends = require("src.storage.file_backends")
local TemplateManager = require("src.managers.template_manager")

-- {{{ local function new_graphics
-- A stand-in love.graphics: each call is recorded with its arguments.
-- Drawing outside any panel's scissor, or with a colour out of 0-1, is
-- an error, as are non-number coordinates.
local function new_graphics()
    local g = {calls = {}, counts = {}}
    local function record(name, ...)
        local args = {...}
        g.calls[#g.calls + 1] = {name = name, args = args}
        g.counts[name] = (g.counts[name] or 0) + 1
    end
    local function numbers(name, first, ...)
        for index, value in ipairs({...}) do
            if index >= first then
                assert(type(value) == "number" and value == value, string.format(
                    "%s argument %d is %s", name, index, tostring(value)))
            end
        end
    end
    function g.setColor(r, gr, b, a)
        for _, part in ipairs({r, gr, b, a or 1}) do
            assert(type(part) == "number" and part >= 0 and part <= 1, "A colour part out of 0-1: " .. tostring(part))
        end
        record("setColor", r, gr, b, a)
    end
    function g.rectangle(mode, x, y, w, h)
        assert(mode == "fill" or mode == "line", "rectangle mode")
        numbers("rectangle", 1, x, y, w, h)
        assert(w >= 0 and h >= 0, "A rectangle with a negative size")
        record("rectangle", mode, x, y, w, h)
    end
    function g.circle(mode, x, y, radius)
        numbers("circle", 1, x, y, radius)
        record("circle", mode, x, y, radius)
    end
    function g.polygon(mode, ...)
        numbers("polygon", 1, ...)
        record("polygon", mode, ...)
    end
    function g.line(...)
        numbers("line", 1, ...)
        record("line", ...)
    end
    function g.printf(text, x, y, limit, align)
        assert(type(text) == "string", "printf text is " .. type(text))
        numbers("printf", 1, x, y, limit)
        assert(limit > 0, "printf needs a positive width")
        assert(align == "left" or align == "center" or align == "right", "printf align " .. tostring(align))
        record("printf", text, x, y, limit, align)
    end
    function g.setScissor(x, y, w, h)
        if x ~= nil then
            numbers("setScissor", 1, x, y, w, h)
        end
        record("setScissor", x, y, w, h)
    end
    function g.reset()
        g.calls, g.counts = {}, {}
    end
    function g.printed(pattern)
        for _, call in ipairs(g.calls) do
            if call.name == "printf" and call.args[1]:find(pattern) then
                return true
            end
        end
        return false
    end
    return g
end
-- }}}

-- {{{ local function new_keyboard
local function new_keyboard()
    local keyboard = {down = {}}
    function keyboard.isDown(...)
        for _, key in ipairs({...}) do
            if keyboard.down[key] then
                return true
            end
        end
        return false
    end
    return keyboard
end
-- }}}

-- {{{ local function new_screen
local function new_screen(width, height, template)
    local keyboard = new_keyboard()
    local editor = TemplateEditor:new({template = template,
        storage = TemplateStorage:new({backend = FileBackends.memory()})})
    local screen = TemplateEditorScreen.new({editor = editor, width = width, height = height, keyboard = keyboard,
        battles = 1})
    return screen, keyboard
end
-- }}}

-- {{{ local function frames
-- Runs a few frames: update, then draw.
local function frames(screen, g, count)
    for _ = 1, count or 3 do
        screen:update(1 / 60)
        g.reset()
        screen:draw(g)
        assert((g.counts.rectangle or 0) > 0 and (g.counts.printf or 0) > 0, "Each frame draws something")
    end
end
-- }}}

-- {{{ local function click
local function click(screen, id)
    local item = screen:find(id)
    assert(item, "Nothing on screen named " .. id)
    local x, y = item.rect.x + item.rect.width / 2, item.rect.y + item.rect.height / 2
    assert(screen:mousepressed(x, y, 1), "Clicking " .. id .. " did something")
    screen:mousereleased(x, y, 1)
    return item
end
-- }}}

-- {{{ local function template_named
local function template_named(name)
    local manager = TemplateManager:new()
    manager:create_default_templates({"starter"})
    return manager:get_template(name)
end
-- }}}

local SIZES = {{1280, 720}, {1920, 1080}, {800, 600}, {640, 480}, {320, 240}}

-- {{{ TestSuite.test_every_tab_at_every_size
-- Every tab and every preview mode, drawn at window sizes from wide to
-- tiny, with everything inside its panel.
function TestSuite.test_every_tab_at_every_size()
    local g = new_graphics()
    for _, size in ipairs(SIZES) do
        local screen = new_screen(size[1], size[2], template_named("Archer"))
        local layout = TemplateEditor.layout(size[1], size[2])
        for _, tab in ipairs(TemplateEditor.TABS) do
            if screen:find("tab:" .. tab) then
                click(screen, "tab:" .. tab)
            else
                screen.editor:switch_tab(tab)
            end
            assert(screen.editor.tab == tab, "On the " .. tab .. " tab")
            for _, mode in ipairs({"visual", "stats", "combat", "comparison"}) do
                screen.editor.preview:set_mode(mode)
                frames(screen, g, 2)
            end
        end
        -- Every item but a tooltip is clipped to its panel.
        for _, item in ipairs(screen.widgets) do
            if item.kind ~= "panel" and item.kind ~= "tooltip" then
                assert(item.clip, item.id .. " is clipped to a panel")
            end
        end
        assert(screen:find("panel:editor").rect.width == layout.editor.width, "Panels follow the layout")
    end
    print("✓ Every tab at every size test passed")
end
-- }}}

-- {{{ TestSuite.test_fits_common_windows
-- At the game's own window size (conf.lua: 1024x768) and other common
-- ones, everything on every tab fits inside its panel, so nothing is cut
-- off by clipping. Smaller windows clip instead.
function TestSuite.test_fits_common_windows()
    for _, size in ipairs({{1024, 768}, {1280, 720}, {1920, 1080}, {800, 600}}) do
        local screen = new_screen(size[1], size[2], template_named("Archer"))
        for _, tab in ipairs(TemplateEditor.TABS) do
            screen.editor:switch_tab(tab)
            for _, item in ipairs(screen:rebuild()) do
                local r, c = item.rect, item.clip
                if r and c then
                    assert(r.x >= c.x and r.y >= c.y and r.x + r.width <= c.x + c.width + 0.01
                        and r.y + r.height <= c.y + c.height + 0.01, string.format(
                        "%s on the %s tab spills out of its panel at %dx%d", item.id, tab, size[1], size[2]))
                end
            end
        end
    end
    print("✓ Fits common windows test passed")
end
-- }}}

-- {{{ TestSuite.test_tabs_by_click_and_key
function TestSuite.test_tabs_by_click_and_key()
    local g = new_graphics()
    local screen, keyboard = new_screen(1280, 720)
    frames(screen, g, 1)
    click(screen, "tab:abilities")
    assert(screen.editor.tab == "abilities", "A tab is chosen by clicking it")
    assert(screen:find("tab:abilities").active, "And shows as chosen")
    screen:keypressed("tab")
    assert(screen.editor.tab == "appearance", "Tab moves along")
    keyboard.down.lshift = true
    screen:keypressed("tab")
    keyboard.down.lshift = nil
    assert(screen.editor.tab == "abilities", "Shift-tab moves back")
    frames(screen, g, 2)
    assert(g.printed("^Abilities$"), "The panel's title names the tab")
    print("✓ Tabs by click and key test passed")
end
-- }}}

-- {{{ TestSuite.test_slider_drag
-- Dragging a stat slider sets the stat through the editor, live, and the
-- whole drag undoes as one step.
function TestSuite.test_slider_drag()
    local g = new_graphics()
    for _, size in ipairs({{1280, 720}, {800, 600}}) do
        local screen = new_screen(size[1], size[2])
        frames(screen, g, 1)
        local slider = screen:find("stat:speed")
        local r = slider.rect
        local y = r.y + r.height / 2
        local start = screen.editor.template.stats.speed
        screen:mousepressed(r.x + r.width * slider.fraction, y, 1)
        assert(screen.ui.drag == "stat:speed", "The drag starts on the slider")
        local seen = {}
        for _, share in ipairs({0.2, 0.35, 0.5, 0.45}) do
            screen:mousemoved(r.x + r.width * share, y)
            frames(screen, g, 1)
            seen[#seen + 1] = screen.editor.template.stats.speed
        end
        screen:mousereleased(r.x + r.width * 0.45, y, 1)
        assert(screen.ui.drag == nil, "The drag ends on release")
        local speed = screen.editor.template.stats.speed
        assert(speed ~= start, "The drag changed speed")
        assert(seen[3] > seen[1], "Speed follows the pointer while dragging")
        local check = TemplateEditor:new()
        local expected = check:set_stat_fraction("speed", screen:find("stat:speed").fraction)
        assert(expected == speed, "The slider's position is the stat's, as the allocator holds it")
        assert(#screen.editor.undo_stack == 1, "The whole drag is one undo step")
        screen:keypressed("z")
        assert(screen.editor.template.stats.speed ~= start, "Without ctrl, z does nothing")
        screen.keyboard.down.lctrl = true
        screen:keypressed("z")
        screen.keyboard.down.lctrl = nil
        assert(screen.editor.template.stats.speed == start, "Ctrl-z undoes the drag in one go")
        -- A drag past the end holds at the slider's end.
        screen:mousepressed(r.x + 1, y, 1)
        screen:mousemoved(r.x + r.width * 3, y)
        screen:mousereleased(r.x + r.width * 3, y, 1)
        frames(screen, g, 1)
        assert(screen.editor.template.points_used <= screen.editor.template.point_budget,
            "Dragging past the end stays within budget")
    end
    print("✓ Slider drag test passed")
end
-- }}}

-- {{{ TestSuite.test_buttons_and_presets
function TestSuite.test_buttons_and_presets()
    local g = new_graphics()
    local screen = new_screen(1280, 720)
    frames(screen, g, 1)
    local health = screen.editor.template.stats.health
    click(screen, "stat_up:health")
    assert(screen.editor.template.stats.health == health + 10, "Plus steps a stat up")
    click(screen, "stat_down:health")
    assert(screen.editor.template.stats.health == health, "Minus steps it down")
    click(screen, "preset:tank")
    assert(screen.editor.template.stats.health > health, "A preset spends points")
    click(screen, "button:undo")
    assert(screen.editor.template.stats.health == health, "Undo button")
    click(screen, "button:redo")
    assert(screen.editor.template.stats.health > health, "Redo button")
    click(screen, "button:save")
    assert(not screen.editor:is_dirty() and screen.ui.status:find("Saved"), "Save button saves and says so")
    assert(screen:find("button:revert").disabled, "Nothing to revert after saving")
    frames(screen, g, 2)
    print("✓ Buttons and presets test passed")
end
-- }}}

-- {{{ TestSuite.test_abilities_tab
function TestSuite.test_abilities_tab()
    local g = new_graphics()
    local screen = new_screen(1280, 720)
    click(screen, "tab:abilities")
    frames(screen, g, 1)
    click(screen, "slot:2")
    assert(screen.ui.slot == 2, "Choosing an empty slot")
    click(screen, "search")
    for _, letter in ipairs({"h", "e", "a", "l"}) do
        screen:textinput(letter)
    end
    assert(screen.ui.query == "heal", "Search filters as it's typed")
    frames(screen, g, 1)
    local found
    for _, item in ipairs(screen.widgets) do
        if item.id:match("^library:") then
            found = found or item.id
        end
    end
    assert(found, "The search finds a healing ability")
    click(screen, found)
    assert(#screen.editor.template.abilities == 2, "Clicking a library ability puts it in the slot")
    frames(screen, g, 1)
    local tuner
    for _, item in ipairs(screen.widgets) do
        if item.id:match("^tune:") then
            tuner = tuner or item
        end
    end
    assert(tuner, "The chosen ability can be tuned")
    local before = screen.editor.template.points_used
    screen:mousepressed(tuner.rect.x + 1, tuner.rect.y + 2, 1)
    screen:mousemoved(tuner.rect.x + tuner.rect.width * 0.1, tuner.rect.y + 2)
    screen:mousereleased(tuner.rect.x + tuner.rect.width * 0.1, tuner.rect.y + 2, 1)
    assert(screen.editor.template.abilities[2].changes, "Tuning records a change")
    assert(screen.editor.template.points_used ~= before, "And changes the cost")
    screen:keypressed("escape")
    click(screen, "remove:2")
    assert(#screen.editor.template.abilities == 1, "Removing the ability")
    screen:wheelmoved(0, -1)
    frames(screen, g, 2)
    print("✓ Abilities tab test passed")
end
-- }}}

-- {{{ TestSuite.test_appearance_tab
function TestSuite.test_appearance_tab()
    local g = new_graphics()
    local screen = new_screen(1024, 768)
    click(screen, "tab:appearance")
    click(screen, "name")
    for _ = 1, #"New Unit" do
        screen:keypressed("backspace")
    end
    for _, letter in ipairs({"S", "c", "o", "u", "t", " ", "é"}) do
        screen:textinput(letter)
    end
    screen:keypressed("backspace")
    screen:keypressed("return")
    assert(screen.editor.template.name == "Scout ", "Typing a name, with backspace removing a whole letter")
    click(screen, "body:ranged")
    assert(screen.editor.template.unit_type == "ranged", "Choosing a body")
    local slider = screen:find("color:primary:red")
    screen:mousepressed(slider.rect.x + slider.rect.width * 0.25, slider.rect.y + 2, 1)
    screen:mousereleased(slider.rect.x + slider.rect.width * 0.25, slider.rect.y + 2, 1)
    assert(math.abs(screen.editor.template.appearance.primary_color[1] - 0.25) < 0.02, "A colour slider")
    slider = screen:find("size")
    screen:mousepressed(slider.rect.x + slider.rect.width - 1, slider.rect.y + 2, 1)
    screen:mousereleased(slider.rect.x + slider.rect.width - 1, slider.rect.y + 2, 1)
    assert(screen.editor.template.appearance.size_modifier == TemplateEditor.SIZE_LIMITS.max, "The size slider")
    frames(screen, g, 2)
    assert(g.counts.polygon and g.counts.polygon > 0, "A ranged body is drawn as a triangle")
    print("✓ Appearance tab test passed")
end
-- }}}

-- {{{ TestSuite.test_preview_tab
function TestSuite.test_preview_tab()
    local g = new_graphics()
    local screen = new_screen(1280, 720, template_named("Warrior"))
    click(screen, "tab:preview")
    local zoom = screen.editor.preview.zoom
    click(screen, "zoom_in")
    assert(screen.editor.preview.zoom > zoom, "Zoom in")
    click(screen, "overlay:sight")
    assert(screen.editor.preview.overlays.sight == false, "An overlay switched off")
    click(screen, "run_battles")
    assert(screen.editor.preview.mode == "combat" and screen.ui.simulation, "Battles run and shown")
    frames(screen, g, 1)
    assert(g.printed("^Overall"), "The battles' result is drawn")
    click(screen, "mode:comparison")
    frames(screen, g, 1)
    assert(g.printed("No changes"), "Nothing changed since opening")
    print("✓ Preview tab test passed")
end
-- }}}

-- {{{ TestSuite.test_over_budget_and_leaving
-- Over budget: the bar shakes, a fix can be chosen; leaving with unsaved
-- changes asks first.
function TestSuite.test_over_budget_and_leaving()
    local g = new_graphics()
    local screen = new_screen(1280, 720)
    local left = 0
    screen.on_exit = function() left = left + 1 end
    frames(screen, g, 1)
    assert(screen:find("button:fixes").disabled, "No fixes within budget")
    -- Push stats past the budget the way a saved file might.
    screen.editor:edit("too much", function(data)
        data.stats.health = 999
        data.stats.armor = 40
    end)
    frames(screen, g, 1)
    assert(screen.ui.shake > 0, "Going over budget shakes the bar")
    assert(screen.editor:budget().status == "over" and g.printed("^! "), "And says so with a mark, not only colour")
    click(screen, "button:fixes")
    frames(screen, g, 1)
    click(screen, "fix:1")
    assert(screen.editor:budget().status ~= "over", "The first fix brings it back")
    screen:keypressed("escape")
    assert(left == 0 and screen.ui.confirm == "back", "Leaving with unsaved changes asks first")
    screen:keypressed("escape")
    assert(left == 1, "A second escape leaves")
    -- Hovering a bar segment shows its tooltip.
    local segment
    for _, item in ipairs(screen.widgets) do
        if item.kind == "segment" then
            segment = segment or item
        end
    end
    assert(segment, "The bar has segments")
    screen:mousemoved(segment.rect.x + 1, segment.rect.y + 1)
    frames(screen, g, 1)
    assert(screen:find("tooltip"), "A tooltip under the pointer")
    print("✓ Over budget and leaving test passed")
end
-- }}}

-- {{{ TestSuite.test_editor_state
-- The LÖVE state that holds the screen, with a stand-in love table.
function TestSuite.test_editor_state()
    local g = new_graphics()
    local window = {900, 650}
    g.getDimensions = function() return window[1], window[2] end
    g.clear = function() end
    g.print = function(text, x, y)
        assert(type(x) == "number" and type(y) == "number", "print needs a place")
    end
    local had = rawget(_G, "love")
    local stub = {graphics = g, keyboard = new_keyboard(), timer = {getTime = function() return 0 end,
        getFPS = function() return 60 end}}
    rawset(_G, "love", stub)
    local ok, problem = pcall(function()
        package.loaded["src.systems.editor_state"] = nil
        local EditorState = require("src.systems.editor_state")
        EditorState:enter()
        for _ = 1, 3 do
            EditorState:update(1 / 60)
            EditorState:draw()
        end
        EditorState:mousepressed(450, 30, 1)
        EditorState:mousemoved(460, 30, 10, 0)
        EditorState:mousereleased(460, 30, 1)
        EditorState:wheelmoved(0, 1)
        EditorState:textinput("x")
        window = {1200, 800}
        EditorState:resize(1200, 800)
        assert(EditorState.screen.width == 1200, "The state passes a resize on")
        window = {700, 900}
        EditorState:update(1 / 60)
        EditorState:draw()
        assert(EditorState.screen.width == 700 and EditorState.screen.height == 900,
            "And notices a new window size by itself")
        EditorState:exit()
    end)
    rawset(_G, "love", had)
    package.loaded["src.systems.editor_state"] = nil
    assert(ok, problem)
    print("✓ Editor state test passed")
end
-- }}}

-- {{{ TestSuite.run_all
function TestSuite.run_all()
    print("Running template editor screen tests...")
    TestSuite.test_every_tab_at_every_size()
    TestSuite.test_fits_common_windows()
    TestSuite.test_tabs_by_click_and_key()
    TestSuite.test_slider_drag()
    TestSuite.test_buttons_and_presets()
    TestSuite.test_abilities_tab()
    TestSuite.test_appearance_tab()
    TestSuite.test_preview_tab()
    TestSuite.test_over_budget_and_leaving()
    TestSuite.test_editor_state()
    print("✅ All template editor screen tests passed!")
    return true
end
-- }}}

return TestSuite
-- }}}
