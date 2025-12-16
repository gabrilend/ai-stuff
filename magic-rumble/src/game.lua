require("src/map")
require("src/ui")
require("src/player")
require("src/building")
require("src/building_preview")
require("src/unit")
require("src/ai")
require("src/king")
require("src/pathfinding")
require("src/pause_menu")

local camera = {x = 0, y = 0, zoom = 1.0}
local game_time = 0
local turn_timer = 0
local TURN_DURATION = 10
local MIN_ZOOM = 0.25
local MAX_ZOOM = 2.0

function game_init()
    map_init()
    ui_init()
    player_init()
    building_init()
    preview_init()
    unit_init()
    -- Spawn neutral defenders AFTER unit_init() clears the units array
    spawn_neutral_defenders()
    ai_init()
    king_init()
    pathfinding_init()
    pause_menu_init()
    
    camera.x = 0
    camera.y = 0
    camera.zoom = 1.0
    game_time = 0
    turn_timer = 0
end

function game_update(dt)
    -- Always update pause menu for smooth animations
    pause_menu_update(dt)
    
    -- Only update game logic if not paused
    if not pause_menu_is_visible() then
        game_time = game_time + dt
        turn_timer = turn_timer + dt
        
        if turn_timer >= TURN_DURATION then
            turn_timer = 0
            player_add_gold(1)
            player_add_gold_for_captured_rooms()
        end
        
        map_update(dt)
        unit_update(dt)
        building_update(dt)
        ui_update(dt)
        ai_update(dt)
        king_update(dt)
        pathfinding_update(dt)
    end
end

function game_draw()
    love.graphics.push()
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
    
    map_draw()
    building_draw()
    unit_draw()
    king_draw()
    preview_draw()
    
    -- Debug pathfinding visualization
    if debug_pathfinding then
        pathfinding_draw_debug_layer("enemy_threat", 0.3)
        pathfinding_draw_debug_layer("strategic_value", 0.2)
    end
    
    love.graphics.pop()
    
    ui_draw()
    
    -- Draw pause menu on top of everything
    pause_menu_draw()
    
    -- Debug text
    if debug_pathfinding then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Pathfinding Debug: F to toggle", 10, 10)
        love.graphics.print("Red = Enemy Threat, Green = Strategic Value", 10, 30)
    end
end

function game_mousepressed(x, y, button)
    -- Handle pause menu first
    if pause_menu_mousepressed(x, y, button) then
        return  -- Pause menu handled the click
    end
    
    -- Only handle game clicks if not paused
    if not pause_menu_is_visible() then
        local world_x = (x / camera.zoom) + camera.x
        local world_y = (y / camera.zoom) + camera.y
        
        if button == 1 then
            ui_mousepressed(x, y, button)
            if get_selected_building_type() then
                building_try_place(world_x, world_y)
            elseif is_king_move_mode() then
                king_try_move_to_room(world_x, world_y)
                clear_king_move_mode()
            end
        elseif button == 2 then
            start_camera_drag(x, y)
        end
    end
end

local debug_pathfinding = false

function game_keypressed(key)
    -- Handle pause menu first
    if pause_menu_keypressed(key) then
        return  -- Pause menu handled the key
    end
    
    -- Only handle game keys if not paused
    if not pause_menu_is_visible() then
        local scroll_speed = 200 / camera.zoom  -- Adjust scroll speed based on zoom
        if key == "w" or key == "up" then
            camera.y = camera.y - scroll_speed
        elseif key == "s" or key == "down" then
            camera.y = camera.y + scroll_speed
        elseif key == "a" or key == "left" then
            camera.x = camera.x - scroll_speed
        elseif key == "d" or key == "right" then
            camera.x = camera.x + scroll_speed
        elseif key == "q" then
            -- Zoom out
            camera.zoom = math.max(MIN_ZOOM, camera.zoom * 0.8)
        elseif key == "e" then
            -- Zoom in
            camera.zoom = math.min(MAX_ZOOM, camera.zoom * 1.25)
        elseif key >= "1" and key <= "5" then
            local index = tonumber(key)
            ui_select_building_by_index(index)
        elseif key == "f" then
            -- Toggle pathfinding debug visualization
            debug_pathfinding = not debug_pathfinding
        end
    end
end

local drag_start = nil

function start_camera_drag(x, y)
    drag_start = {x = x, y = y, cam_x = camera.x, cam_y = camera.y}
end

function game_mousemoved(x, y, dx, dy)
    -- Only handle mouse movement if not paused
    if not pause_menu_is_visible() then
        if drag_start and love.mouse.isDown(2) then
            camera.x = drag_start.cam_x - (x - drag_start.x)
            camera.y = drag_start.cam_y - (y - drag_start.y)
        end
        
        -- Update building preview
        local world_x = (x / camera.zoom) + camera.x
        local world_y = (y / camera.zoom) + camera.y
        preview_update(world_x, world_y)
    end
end

function game_mousereleased(x, y, button)
    if button == 2 then
        drag_start = nil
    end
end

function game_wheelmoved(x, y)
    -- Only handle zoom if not paused
    if not pause_menu_is_visible() then
        if y > 0 then
            -- Zoom in
            camera.zoom = math.min(MAX_ZOOM, camera.zoom * 1.1)
        elseif y < 0 then
            -- Zoom out
            camera.zoom = math.max(MIN_ZOOM, camera.zoom * 0.9)
        end
    end
end

function get_camera()
    return camera
end