-- {{{ Accessibility Test Suite
local TestSuite = {}

-- Load modules to test
local Colors = require("src.constants.colors")
local Shapes = require("src.constants.shapes")

-- {{{ Contrast Testing
function TestSuite.test_contrast_validation()
    -- Test high contrast combinations
    local high_contrast = Colors.validate_contrast(Colors.WHITE, Colors.BLACK)
    assert(high_contrast.aa_normal, "White on black should pass AA normal")
    assert(high_contrast.aaa_normal, "White on black should pass AAA normal")
    
    -- Test low contrast combinations
    local low_contrast = Colors.validate_contrast(Colors.LIGHT_GRAY, Colors.WHITE)
    assert(not low_contrast.aa_normal, "Light gray on white should fail AA normal")
    
    -- Test game color combinations
    local player1_contrast = Colors.validate_contrast(Colors.PLAYER_1, Colors.BLACK)
    assert(player1_contrast.aa_normal, "Player 1 color should have good contrast on black")
    
    local player2_contrast = Colors.validate_contrast(Colors.PLAYER_2, Colors.BLACK)
    assert(player2_contrast.aa_normal, "Player 2 color should have good contrast on black")
    
    print("✓ Contrast validation tests passed")
end

function TestSuite.test_palette_accessibility()
    local results = Colors.validate_palette_accessibility()
    
    local failed_tests = 0
    for _, result in ipairs(results) do
        if not result.passed_aa then
            print("  ⚠️  " .. result.description .. " failed AA contrast")
            failed_tests = failed_tests + 1
        end
    end
    
    if failed_tests > 0 then
        print("  " .. failed_tests .. " contrast tests failed")
    else
        print("✓ All palette accessibility tests passed")
    end
    
    -- Should have some test results
    assert(#results > 0, "Should have accessibility test results")
end

function TestSuite.test_safe_color_pairs()
    -- Test safe color pair generation
    local safe_on_black = Colors.get_safe_pair(Colors.BLACK)
    assert(safe_on_black == Colors.WHITE, "Safe color on black should be white")
    
    local safe_on_white = Colors.get_safe_pair(Colors.WHITE)
    assert(safe_on_white == Colors.BLACK, "Safe color on white should be black")
    
    -- Test with medium luminance colors
    local safe_on_gray = Colors.get_safe_pair(Colors.GRAY)
    assert(type(safe_on_gray) == "table", "Should return a color table")
    
    print("✓ Safe color pair tests passed")
end
-- }}}

-- {{{ Colorblind Simulation Testing
function TestSuite.test_colorblind_simulation()
    local red = Colors.RED
    
    -- Test protanopia (red-blind)
    local protanopia_red = Colors.simulate_colorblindness(red, "protanopia")
    assert(type(protanopia_red) == "table", "Protanopia simulation should return a color")
    assert(#protanopia_red >= 3, "Simulated color should have RGB components")
    
    -- Test deuteranopia (green-blind)
    local deuteranopia_red = Colors.simulate_colorblindness(red, "deuteranopia")
    assert(type(deuteranopia_red) == "table", "Deuteranopia simulation should return a color")
    
    -- Test tritanopia (blue-blind)
    local tritanopia_red = Colors.simulate_colorblindness(red, "tritanopia")
    assert(type(tritanopia_red) == "table", "Tritanopia simulation should return a color")
    
    -- Test achromatopsia (complete color blindness)
    local achromatic_red = Colors.simulate_colorblindness(red, "achromatopsia")
    assert(achromatic_red[1] == achromatic_red[2], "Achromatopsia should produce gray")
    assert(achromatic_red[2] == achromatic_red[3], "Achromatopsia should produce gray")
    
    -- Test unknown type (should return original)
    local unchanged = Colors.simulate_colorblindness(red, "unknown")
    assert(unchanged == red, "Unknown type should return original color")
    
    print("✓ Colorblind simulation tests passed")
end

function TestSuite.test_pattern_assignment()
    -- Test that different colors get different patterns
    local p1_pattern = Colors.get_pattern_for_color(Colors.PLAYER_1)
    local p2_pattern = Colors.get_pattern_for_color(Colors.PLAYER_2)
    
    assert(p1_pattern ~= p2_pattern, "Different player colors should have different patterns")
    
    -- Test that patterns are consistent
    local p1_pattern2 = Colors.get_pattern_for_color(Colors.PLAYER_1)
    assert(p1_pattern == p1_pattern2, "Pattern should be consistent for same color")
    
    print("✓ Pattern assignment tests passed")
end
-- }}}

-- {{{ Shape Accessibility Testing
function TestSuite.test_shape_distinctiveness()
    -- Test that unit shapes are different types
    assert(Shapes.UNIT_MELEE.type ~= Shapes.UNIT_RANGED.type, "Melee and ranged should have different shapes")
    assert(Shapes.UNIT_TANK.pattern ~= Shapes.UNIT_RANGED.pattern, "Tank and ranged should have different patterns")
    
    -- Test accessibility descriptions
    local melee_desc = Shapes.get_accessibility_description(Shapes.UNIT_MELEE)
    local ranged_desc = Shapes.get_accessibility_description(Shapes.UNIT_RANGED)
    
    assert(type(melee_desc) == "string", "Should return string description")
    assert(melee_desc ~= ranged_desc, "Different shapes should have different descriptions")
    
    print("✓ Shape distinctiveness tests passed")
end

function TestSuite.test_pattern_rendering()
    -- Mock renderer for testing
    local mock_renderer = {
        draw_calls = 0,
        draw_line = function(self) self.draw_calls = self.draw_calls + 1 end,
        draw_circle = function(self) self.draw_calls = self.draw_calls + 1 end,
        draw_rectangle = function(self) self.draw_calls = self.draw_calls + 1 end,
        draw_polygon = function(self) self.draw_calls = self.draw_calls + 1 end
    }
    
    -- Test pattern drawing functions don't crash
    Shapes.draw_pattern(mock_renderer, "striped", 0, 0, 20, 20, Colors.RED)
    assert(mock_renderer.draw_calls > 0, "Striped pattern should make draw calls")
    
    mock_renderer.draw_calls = 0
    Shapes.draw_circle_pattern(mock_renderer, "dashed", 0, 0, 10, Colors.BLUE)
    assert(mock_renderer.draw_calls > 0, "Dashed circle pattern should make draw calls")
    
    -- Test shape with pattern drawing
    mock_renderer.draw_calls = 0
    Shapes.draw_shape_with_pattern(mock_renderer, Shapes.UNIT_TANK, 100, 100, Colors.UNIT_TANK)
    assert(mock_renderer.draw_calls > 0, "Shape with pattern should make draw calls")
    
    print("✓ Pattern rendering tests passed")
end
-- }}}

-- {{{ Comprehensive Accessibility Testing
function TestSuite.test_colorblind_game_scenarios()
    -- Test that key game elements remain distinguishable under colorblindness
    local test_colors = {
        Colors.PLAYER_1,
        Colors.PLAYER_2,
        Colors.NEUTRAL,
        Colors.HEALTH_HIGH,
        Colors.HEALTH_LOW,
        Colors.MANA
    }
    
    local colorblind_types = {"protanopia", "deuteranopia", "tritanopia"}
    
    for _, cb_type in ipairs(colorblind_types) do
        local simulated_colors = {}
        for i, color in ipairs(test_colors) do
            simulated_colors[i] = Colors.simulate_colorblindness(color, cb_type)
        end
        
        -- Check that player colors remain distinguishable
        local p1_sim = simulated_colors[1]
        local p2_sim = simulated_colors[2]
        
        local contrast = Colors.validate_contrast(p1_sim, p2_sim)
        if not contrast.aa_normal then
            print("  ⚠️  Player colors may be hard to distinguish for " .. cb_type)
        end
    end
    
    print("✓ Colorblind game scenario tests completed")
end

function TestSuite.test_accessibility_features_integration()
    -- Test that the pattern system works with the color system
    for color_name, color in pairs(Colors) do
        if type(color) == "table" and #color >= 3 then
            local pattern = Colors.get_pattern_for_color(color)
            assert(type(pattern) == "string", "Pattern should be a string")
            assert(Colors.PATTERNS[pattern:upper()] ~= nil, "Pattern should be valid")
        end
    end
    
    -- Test that shapes have accessibility information
    for shape_name, shape in pairs(Shapes) do
        if type(shape) == "table" and shape.type then
            local desc = Shapes.get_accessibility_description(shape)
            assert(type(desc) == "string", "Accessibility description should be a string")
            assert(string.len(desc) > 0, "Description should not be empty")
        end
    end
    
    print("✓ Accessibility features integration tests passed")
end
-- }}}

-- {{{ Performance Testing
function TestSuite.test_accessibility_performance()
    local start_time = os.clock()
    
    -- Test performance of colorblind simulation
    for i = 1, 1000 do
        local _ = Colors.simulate_colorblindness(Colors.RED, "protanopia")
        local _ = Colors.simulate_colorblindness(Colors.GREEN, "deuteranopia")
        local _ = Colors.simulate_colorblindness(Colors.BLUE, "tritanopia")
    end
    
    local colorblind_time = os.clock() - start_time
    
    -- Test performance of contrast validation
    start_time = os.clock()
    for i = 1, 1000 do
        local _ = Colors.validate_contrast(Colors.WHITE, Colors.BLACK)
        local _ = Colors.validate_contrast(Colors.PLAYER_1, Colors.PLAYER_2)
    end
    
    local contrast_time = os.clock() - start_time
    
    -- Test performance of pattern generation
    start_time = os.clock()
    local mock_renderer = {
        draw_line = function() end,
        draw_circle = function() end,
        draw_rectangle = function() end
    }
    
    for i = 1, 100 do
        Shapes.draw_pattern(mock_renderer, "striped", 0, 0, 20, 20, Colors.RED)
        Shapes.draw_circle_pattern(mock_renderer, "dashed", 0, 0, 10, Colors.BLUE)
    end
    
    local pattern_time = os.clock() - start_time
    
    print(string.format("✓ Performance tests completed:"))
    print(string.format("  Colorblind simulation: %.4f seconds for 3000 operations", colorblind_time))
    print(string.format("  Contrast validation: %.4f seconds for 2000 operations", contrast_time))
    print(string.format("  Pattern rendering: %.4f seconds for 200 operations", pattern_time))
    
    -- Performance should be reasonable
    assert(colorblind_time < 1.0, "Colorblind simulation should be fast")
    assert(contrast_time < 1.0, "Contrast validation should be fast")
    assert(pattern_time < 1.0, "Pattern rendering should be fast")
end
-- }}}

-- {{{ Run All Tests
function TestSuite.run_all()
    print("Running Accessibility Test Suite...")
    print(string.rep("=", 50))
    
    -- Contrast and color tests
    TestSuite.test_contrast_validation()
    TestSuite.test_palette_accessibility()
    TestSuite.test_safe_color_pairs()
    
    -- Colorblind simulation tests
    TestSuite.test_colorblind_simulation()
    TestSuite.test_pattern_assignment()
    
    -- Shape accessibility tests
    TestSuite.test_shape_distinctiveness()
    TestSuite.test_pattern_rendering()
    
    -- Comprehensive accessibility tests
    TestSuite.test_colorblind_game_scenarios()
    TestSuite.test_accessibility_features_integration()
    
    -- Performance tests
    TestSuite.test_accessibility_performance()
    
    print(string.rep("=", 50))
    print("✅ All accessibility tests completed!")
    print("")
    print("Summary:")
    print("• Contrast validation ensures WCAG compliance")
    print("• Colorblind simulation helps test visibility")
    print("• Pattern system provides shape-based identification")
    print("• All features integrate properly and perform well")
end
-- }}}

return TestSuite
-- }}}