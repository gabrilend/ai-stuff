-- Debug lane creation issue
package.path = package.path .. ';./?.lua'

local Vector2 = require("src.utils.vector2")

print("1. Vector2 loaded")

local debug_mock = {
    log = function(msg, category) 
        print("[" .. (category or "DEBUG") .. "] " .. msg)
    end
}

print("2. Debug mock created")

-- Mock the lane system but with debug prints
local LaneSystem = {}

function LaneSystem:calculate_lane_properties(lane)
    print("3a. Starting calculate_lane_properties")
    local direction = lane.end_point:subtract(lane.start_point)
    lane.metadata.length = direction:length()
    lane.metadata.direction = direction:normalize()
    lane.metadata.perpendicular = Vector2:new(-lane.metadata.direction.y, lane.metadata.direction.x)
    print("3b. calculate_lane_properties completed, length:", lane.metadata.length)
end

function LaneSystem:generate_waypoints(sub_path, lane)
    print("4a. Starting generate_waypoints")
    local waypoint_count = math.max(3, math.floor(lane.metadata.length / 50))  -- WAYPOINT_SPACING = 50
    waypoint_count = math.min(waypoint_count, 20)
    print("4b. Will generate", waypoint_count, "waypoints")
    
    for i = 0, waypoint_count do
        print("4c. Generating waypoint", i, "of", waypoint_count)
        local t = i / waypoint_count
        local main_point = lane.start_point:lerp(lane.end_point, t)  -- Simple lerp instead of curve
        table.insert(sub_path.waypoints, main_point)
    end
    print("4d. generate_waypoints completed")
end

function LaneSystem:smooth_path(sub_path)
    print("5a. Starting smooth_path with", #sub_path.waypoints, "waypoints")
    sub_path.center_line = {}
    for _, waypoint in ipairs(sub_path.waypoints) do
        table.insert(sub_path.center_line, waypoint)
    end
    sub_path.metadata.smoothed = false
    print("5b. smooth_path completed (simplified)")
end

function LaneSystem:generate_sub_paths(lane)
    print("6a. Starting generate_sub_paths")
    for i = 1, 5 do  -- SUB_PATH_COUNT = 5
        print("6b. Generating sub-path", i)
        local sub_path = {
            id = i,
            waypoints = {},
            center_line = {},
            metadata = {}
        }
        
        self:generate_waypoints(sub_path, lane)
        self:smooth_path(sub_path)
        
        lane.sub_paths[i] = sub_path
        print("6c. Sub-path", i, "completed")
    end
    print("6d. generate_sub_paths completed")
end

function LaneSystem:create_lane(start_point, end_point, width)
    print("7a. Starting create_lane")
    local lane = {
        start_point = start_point,
        end_point = end_point,
        width = width or 60,
        sub_paths = {},
        curve_points = {},
        metadata = {}
    }
    
    self:calculate_lane_properties(lane)
    self:generate_sub_paths(lane)
    
    print("7b. create_lane completed")
    return lane
end

-- Test it
print("Starting test...")
local lane_system = {}
setmetatable(lane_system, {__index = LaneSystem})

local start = Vector2:new(100, 200)
local end_point = Vector2:new(400, 300)

print("Creating lane...")
local lane = lane_system:create_lane(start, end_point, 60)
print("SUCCESS: Lane created with", #lane.sub_paths, "sub-paths")