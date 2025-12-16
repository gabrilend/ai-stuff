function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.window.setTitle("Magic Rumble")
    
    drawables = {}
    
    gamestate = "menu"
    
    require("src/menu")
    require("src/game")
    
    menu_init()
end

function love.update(dt)
    if gamestate == "menu" then
        menu_update(dt)
    elseif gamestate == "game" then
        game_update(dt)
    end
end

function love.draw()
    if gamestate == "menu" then
        for _, drawable in ipairs(drawables) do
            drawable:draw()
        end
    elseif gamestate == "game" then
        game_draw()
    end
end

function love.mousepressed(x, y, button)
    if gamestate == "menu" then
        menu_mousepressed(x, y, button)
    elseif gamestate == "game" then
        game_mousepressed(x, y, button)
    end
end

function love.keypressed(key)
    if gamestate == "game" then
        game_keypressed(key)
    end
end

function love.mousemoved(x, y, dx, dy)
    if gamestate == "game" then
        game_mousemoved(x, y, dx, dy)
    end
end

function love.mousereleased(x, y, button)
    if gamestate == "game" then
        game_mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if gamestate == "game" then
        game_wheelmoved(x, y)
    end
end