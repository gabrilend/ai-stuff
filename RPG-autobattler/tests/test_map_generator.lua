-- {{{ Map Generator Test Suite
local TestSuite = {}

-- Load modules to test
local MapGenerator = require("src.systems.map_generator")
local Vector2 = require("src.utils.vector2")

-- Mock love.math.random for testing
local function setup_love_mock()
    _G.love = _G.love or {}
    _G.love.math = _G.love.math or {}
    _G.love.math.random = math.random
end

-- Helper function to validate map structure
local function validate_map_structure(map)
    assert(type(map) == "table", "Map should be a table")
    assert(type(map.width) == "number", "Map should have width")
    assert(type(map.height) == "number", "Map should have height")
    assert(type(map.nodes) == "table", "Map should have nodes table")
    assert(type(map.connections) == "table", "Map should have connections table")
    assert(type(map.spawn_points) == "table", "Map should have spawn_points table")
    assert(type(map.paths) == "table", "Map should have paths table")
    assert(type(map.metadata) == "table", "Map should have metadata")
end

-- {{{ Basic Map Generation Tests
function TestSuite.test_basic_map_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(800, 600, 1.0, 12345)
    
    validate_map_structure(map)
    
    assert(map.width == 800, "Map width should match input")
    assert(map.height == 600, "Map height should match input")
    assert(map.complexity == 1.0, "Map complexity should match input")
    assert(map.seed == 12345, "Map seed should be stored")
    
    print("✓ Basic map generation test passed")
end

function TestSuite.test_spawn_point_placement()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(1000, 800, 1.0, 42)
    
    assert(map.spawn_points.player_1, "Player 1 spawn point should exist")
    assert(map.spawn_points.player_2, "Player 2 spawn point should exist")
    
    -- Spawn points should be on opposite sides
    assert(map.spawn_points.player_1.x < map.width * 0.5, "Player 1 should be on left side")
    assert(map.spawn_points.player_2.x > map.width * 0.5, "Player 2 should be on right side")
    
    -- Distance between spawn points should be reasonable
    local distance = map.spawn_points.player_1:distance_to(map.spawn_points.player_2)
    assert(distance > map.width * 0.5, "Spawn points should be reasonably far apart")
    
    print("✓ Spawn point placement test passed")
end

function TestSuite.test_node_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(800, 600, 1.0, 123)
    
    assert(#map.nodes > 0, "Map should have intermediate nodes")
    
    -- Check node spacing
    local min_distance = math.huge
    for i = 1, #map.nodes do
        for j = i + 1, #map.nodes do
            local distance = map.nodes[i]:distance_to(map.nodes[j])
            min_distance = math.min(min_distance, distance)
        end
    end
    
    assert(min_distance > 30, "Nodes should have minimum spacing")
    
    print("✓ Node generation test passed")
end
-- }}}

-- {{{ Connectivity Tests
function TestSuite.test_base_connectivity()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(800, 600, 1.0, 456)
    
    -- Test that bases are connected
    local path = generator:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    assert(path ~= nil, "There should be a path between spawn points")
    assert(#path >= 2, "Path should have at least start and end points")
    
    print("✓ Base connectivity test passed")
end

function TestSuite.test_connection_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(600, 400, 1.5, 789)
    
    assert(#map.connections > 0, "Map should have connections")
    
    -- Verify connection structure
    for _, connection in ipairs(map.connections) do
        assert(connection.from, "Connection should have 'from' node")
        assert(connection.to, "Connection should have 'to' node")
        assert(connection.id, "Connection should have ID")
        assert(connection.bidirectional, "Connection should be bidirectional")
    end
    
    -- Check that spawn points have connections
    local p1_connected = false
    local p2_connected = false
    
    for _, connection in ipairs(map.connections) do
        if connection.from == map.spawn_points.player_1 or connection.to == map.spawn_points.player_1 then
            p1_connected = true
        end
        if connection.from == map.spawn_points.player_2 or connection.to == map.spawn_points.player_2 then
            p2_connected = true
        end
    end
    
    assert(p1_connected, "Player 1 spawn point should be connected")
    assert(p2_connected, "Player 2 spawn point should be connected")
    
    print("✓ Connection generation test passed")
end

function TestSuite.test_isolated_nodes()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(800, 600, 0.5, 101112)
    
    -- Check that all intermediate nodes have at least one connection
    for _, node in ipairs(map.nodes) do
        local connected = false
        for _, connection in ipairs(map.connections) do
            if connection.from == node or connection.to == node then
                connected = true
                break
            end
        end
        assert(connected, "All intermediate nodes should be connected")
    end
    
    print("✓ Isolated nodes test passed")
end
-- }}}

-- {{{ Path Geometry Tests
function TestSuite.test_path_geometry_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(400, 300, 1.0, 131415)
    
    assert(#map.paths == #map.connections, "Should have one path per connection")
    
    for _, path in ipairs(map.paths) do
        assert(path.start_point, "Path should have start point")
        assert(path.end_point, "Path should have end point")
        assert(path.width > 0, "Path should have positive width")
        assert(#path.points >= 2, "Path should have multiple points")
        assert(#path.control_points == 3, "Path should have 3 control points for bezier curve")
        
        -- Verify path points are in order from start to end
        local first_point = path.points[1]
        local last_point = path.points[#path.points]
        
        local start_distance = first_point:distance_to(path.start_point)
        local end_distance = last_point:distance_to(path.end_point)
        
        assert(start_distance < 5, "First path point should be near start")
        assert(end_distance < 5, "Last path point should be near end")
    end
    
    print("✓ Path geometry generation test passed")
end

function TestSuite.test_bezier_curve_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    -- Test bezier curve function directly
    local p0 = Vector2:new(0, 0)
    local p1 = Vector2:new(50, 100)
    local p2 = Vector2:new(100, 0)
    
    local start_point = generator:quadratic_bezier(p0, p1, p2, 0)
    local mid_point = generator:quadratic_bezier(p0, p1, p2, 0.5)
    local end_point = generator:quadratic_bezier(p0, p1, p2, 1)
    
    assert(start_point:distance_to(p0) < 0.1, "t=0 should give start point")
    assert(end_point:distance_to(p2) < 0.1, "t=1 should give end point")
    assert(mid_point.y > 0, "Mid point should be above x-axis due to curve")
    
    print("✓ Bezier curve generation test passed")
end
-- }}}

-- {{{ Complexity Tests
function TestSuite.test_complexity_levels()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local maps = {}
    local complexities = {0.5, 1.0, 1.5, 2.0}
    
    for _, complexity in ipairs(complexities) do
        local map = generator:generate_map(600, 400, complexity, 161718)
        maps[complexity] = map
    end
    
    -- Higher complexity should generally mean more nodes and connections
    assert(#maps[2.0].nodes >= #maps[0.5].nodes, "Higher complexity should have more nodes")
    assert(#maps[2.0].connections >= #maps[0.5].connections, "Higher complexity should have more connections")
    
    -- All maps should be valid regardless of complexity
    for _, map in pairs(maps) do
        validate_map_structure(map)
        
        local path = generator:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
        assert(path ~= nil, "All complexity levels should maintain connectivity")
    end
    
    print("✓ Complexity levels test passed")
end

function TestSuite.test_deterministic_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local seed = 192021
    local map1 = generator:generate_map(500, 400, 1.0, seed)
    local map2 = generator:generate_map(500, 400, 1.0, seed)
    
    -- Same seed should produce identical maps
    assert(#map1.nodes == #map2.nodes, "Same seed should produce same number of nodes")
    assert(#map1.connections == #map2.connections, "Same seed should produce same number of connections")
    
    -- Node positions should be identical
    for i = 1, #map1.nodes do
        local distance = map1.nodes[i]:distance_to(map2.nodes[i])
        assert(distance < 0.1, "Node positions should be identical with same seed")
    end
    
    print("✓ Deterministic generation test passed")
end
-- }}}

-- {{{ Performance Tests
function TestSuite.test_generation_performance()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local start_time = os.clock()
    local iterations = 10
    
    for i = 1, iterations do
        local map = generator:generate_map(800, 600, 1.5, i * 222324)
        assert(map.metadata.generation_time < 1.0, "Map generation should be fast")
    end
    
    local total_time = os.clock() - start_time
    local avg_time = total_time / iterations
    
    print(string.format("✓ Performance test passed: %.3fs average (%.3fs total for %d maps)", 
          avg_time, total_time, iterations))
    
    assert(avg_time < 0.5, "Average generation time should be reasonable")
end

function TestSuite.test_large_map_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(2048, 1536, 2.0, 252627)
    
    validate_map_structure(map)
    assert(map.metadata.generation_time < 2.0, "Large map generation should complete in reasonable time")
    
    -- Large maps should still maintain connectivity
    local path = generator:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    assert(path ~= nil, "Large maps should maintain connectivity")
    
    print("✓ Large map generation test passed")
end
-- }}}

-- {{{ Map Statistics Tests
function TestSuite.test_map_statistics()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(600, 400, 1.0, 282930)
    local stats = generator:get_map_stats(map)
    
    assert(type(stats) == "table", "Stats should be a table")
    assert(stats.dimensions.width == 600, "Stats should include correct dimensions")
    assert(stats.dimensions.height == 400, "Stats should include correct dimensions")
    assert(stats.nodes.total > 0, "Stats should show node count")
    assert(stats.connections.total > 0, "Stats should show connection count")
    assert(stats.paths.total_length > 0, "Stats should calculate total path length")
    assert(stats.generation_time >= 0, "Stats should include generation time")
    
    print("✓ Map statistics test passed")
end
-- }}}

-- {{{ Edge Case Tests
function TestSuite.test_minimal_complexity()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(400, 300, 0.0, 313233)
    
    validate_map_structure(map)
    
    -- Even minimal complexity should maintain connectivity
    local path = generator:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    assert(path ~= nil, "Minimal complexity should still be connected")
    
    print("✓ Minimal complexity test passed")
end

function TestSuite.test_small_map_generation()
    setup_love_mock()
    
    local generator = {}
    setmetatable(generator, {__index = MapGenerator})
    
    local map = generator:generate_map(200, 150, 1.0, 343536)
    
    validate_map_structure(map)
    
    -- Small maps should still work
    local path = generator:find_path(map.spawn_points.player_1, map.spawn_points.player_2, map.connections)
    assert(path ~= nil, "Small maps should maintain connectivity")
    
    print("✓ Small map generation test passed")
end
-- }}}

-- {{{ Run All Tests
function TestSuite.run_all()
    print("Running Map Generator Test Suite...")
    print(string.rep("=", 50))
    
    -- Basic tests
    TestSuite.test_basic_map_generation()
    TestSuite.test_spawn_point_placement()
    TestSuite.test_node_generation()
    
    -- Connectivity tests
    TestSuite.test_base_connectivity()
    TestSuite.test_connection_generation()
    TestSuite.test_isolated_nodes()
    
    -- Path geometry tests
    TestSuite.test_path_geometry_generation()
    TestSuite.test_bezier_curve_generation()
    
    -- Complexity tests
    TestSuite.test_complexity_levels()
    TestSuite.test_deterministic_generation()
    
    -- Performance tests
    TestSuite.test_generation_performance()
    TestSuite.test_large_map_generation()
    
    -- Statistics tests
    TestSuite.test_map_statistics()
    
    -- Edge case tests
    TestSuite.test_minimal_complexity()
    TestSuite.test_small_map_generation()
    
    print(string.rep("=", 50))
    print("✅ All map generator tests passed successfully!")
    print("")
    print("Summary:")
    print("• Map generation creates varied, connected networks")
    print("• Spawn points are properly placed and connected")
    print("• Path geometry uses smooth bezier curves")
    print("• Performance scales well with map size and complexity")
    print("• Deterministic generation works with seeds")
    print("• All edge cases handled gracefully")
end
-- }}}

return TestSuite
-- }}}