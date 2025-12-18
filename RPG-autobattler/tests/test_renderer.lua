-- {{{ Renderer Test Suite
local TestSuite = {}

-- Load modules to test
local Renderer = require("src.systems.renderer")
local Colors = require("src.constants.colors")
local Shapes = require("src.constants.shapes")

-- Mock Love2D functions for testing
local function setup_love2d_mock()
    _G.love = _G.love or {}
    _G.love.graphics = _G.love.graphics or {}
    _G.love.timer = _G.love.timer or {}
    
    -- Mock graphics functions
    _G.love.graphics.clear = function() end
    _G.love.graphics.setColor = function() end
    _G.love.graphics.setLineWidth = function() end
    _G.love.graphics.circle = function() end
    _G.love.graphics.rectangle = function() end
    _G.love.graphics.line = function() end
    _G.love.graphics.print = function() end
    _G.love.graphics.polygon = function() end
    _G.love.graphics.push = function() end
    _G.love.graphics.pop = function() end
    _G.love.graphics.translate = function() end
    _G.love.graphics.rotate = function() end
    _G.love.graphics.scale = function() end
    _G.love.graphics.setFont = function() end
    _G.love.graphics.getFont = function()
        return {
            getWidth = function() return 50 end,
            getHeight = function() return 12 end
        }
    end
    
    -- Mock timer functions
    _G.love.timer.getTime = function() return os.clock() end
end

-- {{{ Renderer Basic Tests
function TestSuite.test_renderer_init()
    setup_love2d_mock()
    
    local renderer = {}
    setmetatable(renderer, {__index = Renderer})
    renderer:init()
    
    assert(renderer.draw_calls == 0, "Draw calls should start at 0")
    assert(renderer.frame_time == 0, "Frame time should start at 0")
    assert(type(renderer.shapes) == "table", "Shapes should be a table")
    
    print("✓ Renderer initialization test passed")
end

function TestSuite.test_renderer_frame_cycle()
    setup_love2d_mock()
    
    local renderer = {}
    setmetatable(renderer, {__index = Renderer})
    renderer:init()
    
    -- First frame
    renderer:begin_frame()
    assert(renderer.draw_calls == 0, "Draw calls should reset at frame start")
    
    renderer:draw_circle(100, 100, 10, Colors.RED)
    assert(renderer.draw_calls == 1, "Draw calls should increment")
    
    renderer:end_frame()
    
    -- Second frame to test last_frame_draw_calls
    renderer:begin_frame()
    assert(renderer.last_frame_draw_calls == 1, "Last frame draw calls should be recorded")
    assert(renderer.draw_calls == 0, "Draw calls should reset for new frame")
    
    renderer:end_frame()
    
    print("✓ Renderer frame cycle test passed")
end

function TestSuite.test_renderer_primitives()
    setup_love2d_mock()
    
    local renderer = {}
    setmetatable(renderer, {__index = Renderer})
    renderer:init()
    renderer:begin_frame()
    
    local initial_calls = renderer.draw_calls
    
    -- Test circle drawing
    renderer:draw_circle(50, 50, 10, Colors.BLUE)
    assert(renderer.draw_calls == initial_calls + 1, "Circle drawing should increment draw calls")
    
    -- Test rectangle drawing
    renderer:draw_rectangle(100, 100, 20, 15, Colors.GREEN)
    assert(renderer.draw_calls == initial_calls + 2, "Rectangle drawing should increment draw calls")
    
    -- Test line drawing
    renderer:draw_line(0, 0, 100, 100, Colors.RED, 2)
    assert(renderer.draw_calls == initial_calls + 3, "Line drawing should increment draw calls")
    
    -- Test text drawing
    renderer:draw_text("Test", 200, 200, Colors.WHITE)
    assert(renderer.draw_calls == initial_calls + 4, "Text drawing should increment draw calls")
    
    -- Test polygon drawing
    renderer:draw_polygon({0, 0, 10, 0, 5, 10}, Colors.YELLOW)
    assert(renderer.draw_calls == initial_calls + 5, "Polygon drawing should increment draw calls")
    
    -- Test arrow drawing (should be 3 draw calls: main line + 2 head lines)
    renderer:draw_arrow(300, 300, 350, 350, Colors.CYAN, 2, 8)
    assert(renderer.draw_calls == initial_calls + 8, "Arrow drawing should increment draw calls by 3")
    
    print("✓ Renderer primitives test passed")
end

function TestSuite.test_renderer_transforms()
    setup_love2d_mock()
    
    local renderer = {}
    setmetatable(renderer, {__index = Renderer})
    renderer:init()
    
    -- Test transform functions (these mainly test they don't crash)
    renderer:push_transform()
    renderer:translate(10, 20)
    renderer:rotate(math.pi / 4)
    renderer:scale(2, 1.5)
    renderer:pop_transform()
    
    print("✓ Renderer transforms test passed")
end

function TestSuite.test_renderer_debug_features()
    setup_love2d_mock()
    
    local renderer = {}
    setmetatable(renderer, {__index = Renderer})
    renderer:init()
    
    -- Test debug feature toggles
    renderer:set_debug_wireframes(true)
    assert(renderer.debug_wireframes == true, "Debug wireframes should be enabled")
    
    renderer:set_debug_bounds(true)
    assert(renderer.debug_bounds == true, "Debug bounds should be enabled")
    
    renderer:set_show_draw_calls(true)
    assert(renderer.show_draw_calls == true, "Show draw calls should be enabled")
    
    -- Test stats retrieval
    local stats = renderer:get_stats()
    assert(type(stats) == "table", "Stats should return a table")
    assert(type(stats.draw_calls) == "number", "Stats should include draw calls")
    assert(type(stats.frame_time) == "number", "Stats should include frame time")
    
    print("✓ Renderer debug features test passed")
end
-- }}}

-- {{{ Colors Tests
function TestSuite.test_colors_basic()
    -- Test basic color definitions
    assert(type(Colors.RED) == "table", "RED should be a table")
    assert(#Colors.RED >= 3, "Colors should have at least RGB components")
    assert(Colors.RED[1] == 1, "RED should have red component = 1")
    assert(Colors.RED[2] == 0, "RED should have green component = 0")
    assert(Colors.RED[3] == 0, "RED should have blue component = 0")
    
    print("✓ Colors basic test passed")
end

function TestSuite.test_colors_utility_functions()
    -- Test color interpolation
    local red = Colors.RED
    local blue = Colors.BLUE
    local purple = Colors.lerp(red, blue, 0.5)
    
    assert(purple[1] == 0.5, "Lerped color should have intermediate red component")
    assert(purple[2] == 0, "Lerped color should have zero green component")
    assert(purple[3] == 0.5, "Lerped color should have intermediate blue component")
    
    -- Test alpha modification
    local semi_red = Colors.with_alpha(Colors.RED, 0.5)
    assert(semi_red[4] == 0.5, "Alpha should be modified correctly")
    
    -- Test brightness modification
    local bright_red = Colors.brighten(Colors.RED, 1.5)
    assert(bright_red[1] == 1, "Brightness should be clamped to 1")
    
    local dark_red = Colors.darken(Colors.RED, 0.5)
    assert(dark_red[1] == 0.5, "Darkness should reduce color values")
    
    -- Test health color function
    local high_health = Colors.get_health_color(0.8)
    local low_health = Colors.get_health_color(0.2)
    assert(high_health == Colors.HEALTH_HIGH, "High health should return high health color")
    assert(low_health == Colors.HEALTH_LOW, "Low health should return low health color")
    
    -- Test player color function
    local p1_color = Colors.get_player_color(1)
    local p2_color = Colors.get_player_color(2)
    assert(p1_color == Colors.PLAYER_1, "Player 1 should return player 1 color")
    assert(p2_color == Colors.PLAYER_2, "Player 2 should return player 2 color")
    
    print("✓ Colors utility functions test passed")
end
-- }}}

-- {{{ Shapes Tests
function TestSuite.test_shapes_basic()
    -- Test shape definitions
    assert(type(Shapes.UNIT_MELEE) == "table", "UNIT_MELEE should be a table")
    assert(Shapes.UNIT_MELEE.type == "rectangle", "UNIT_MELEE should be a rectangle")
    assert(type(Shapes.UNIT_MELEE.width) == "number", "UNIT_MELEE should have width")
    assert(type(Shapes.UNIT_MELEE.height) == "number", "UNIT_MELEE should have height")
    
    assert(Shapes.UNIT_RANGED.type == "circle", "UNIT_RANGED should be a circle")
    assert(type(Shapes.UNIT_RANGED.radius) == "number", "UNIT_RANGED should have radius")
    
    print("✓ Shapes basic test passed")
end

function TestSuite.test_shapes_utility_functions()
    -- Test bounds calculation
    local circle_bounds = Shapes.get_bounds(Shapes.UNIT_RANGED)
    assert(circle_bounds.width == Shapes.UNIT_RANGED.radius * 2, "Circle bounds width should be diameter")
    assert(circle_bounds.height == Shapes.UNIT_RANGED.radius * 2, "Circle bounds height should be diameter")
    
    local rect_bounds = Shapes.get_bounds(Shapes.UNIT_MELEE)
    assert(rect_bounds.width == Shapes.UNIT_MELEE.width, "Rectangle bounds should match shape dimensions")
    assert(rect_bounds.height == Shapes.UNIT_MELEE.height, "Rectangle bounds should match shape dimensions")
    
    -- Test scaling
    local scaled_circle = Shapes.scale(Shapes.UNIT_RANGED, 2)
    assert(scaled_circle.radius == Shapes.UNIT_RANGED.radius * 2, "Scaled circle should have doubled radius")
    
    local scaled_rect = Shapes.scale(Shapes.UNIT_MELEE, 1.5, 2)
    assert(scaled_rect.width == Shapes.UNIT_MELEE.width * 1.5, "Scaled rectangle width should be correct")
    assert(scaled_rect.height == Shapes.UNIT_MELEE.height * 2, "Scaled rectangle height should be correct")
    
    -- Test collision radius
    local circle_radius = Shapes.get_collision_radius(Shapes.UNIT_RANGED)
    assert(circle_radius == Shapes.UNIT_RANGED.radius, "Circle collision radius should equal radius")
    
    local rect_radius = Shapes.get_collision_radius(Shapes.UNIT_MELEE)
    assert(rect_radius > 0, "Rectangle collision radius should be positive")
    
    -- Test copy
    local copy = Shapes.copy(Shapes.UNIT_MELEE)
    assert(copy.width == Shapes.UNIT_MELEE.width, "Copied shape should have same properties")
    assert(copy ~= Shapes.UNIT_MELEE, "Copy should be a different table")
    
    print("✓ Shapes utility functions test passed")
end
-- }}}

-- {{{ Run All Tests
function TestSuite.run_all()
    print("Running Renderer Test Suite...")
    print(string.rep("=", 50))
    
    -- Renderer tests
    TestSuite.test_renderer_init()
    TestSuite.test_renderer_frame_cycle()
    TestSuite.test_renderer_primitives()
    TestSuite.test_renderer_transforms()
    TestSuite.test_renderer_debug_features()
    
    -- Colors tests
    TestSuite.test_colors_basic()
    TestSuite.test_colors_utility_functions()
    
    -- Shapes tests
    TestSuite.test_shapes_basic()
    TestSuite.test_shapes_utility_functions()
    
    print(string.rep("=", 50))
    print("✅ All renderer tests passed successfully!")
end
-- }}}

return TestSuite
-- }}}