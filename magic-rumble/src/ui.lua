local building_icons = {}
local selected_icon_index = nil
local king_move_button = nil
local king_move_mode = false

local UIIcon = {}
UIIcon.__index = UIIcon

function UIIcon:new(x, y, width, height, building_type, index)
    local icon = {
        x = x,
        y = y,
        width = width,
        height = height,
        building_type = building_type,
        index = index,
        hovered = false,
        selected = false
    }
    setmetatable(icon, UIIcon)
    return icon
end

function UIIcon:draw()
    local color = {0.3, 0.3, 0.3}
    if self.selected then
        color = {0.6, 0.6, 0.2}
    elseif self.hovered then
        color = {0.4, 0.4, 0.4}
    end
    
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    local font = love.graphics.getFont()
    local text_height = font:getHeight()
    love.graphics.print(self.building_type.name, self.x + 5, 
                       self.y + self.height - text_height - 5)
    
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", self.x + 15, self.y + 15, 10)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(tostring(self.building_type.cost), 
                       self.x + 10, self.y + 8)
    
    if player_get_gold() < self.building_type.cost then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle("fill", self.x, self.y, 
                              self.width, self.height)
    end
end

function UIIcon:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and 
           y >= self.y and y <= self.y + self.height
end

function UIIcon:click()
    if self.index == 0 then  -- King move button
        king_move_mode = not king_move_mode
        selected_icon_index = nil
        set_selected_building_type(nil)
    elseif player_get_gold() >= self.building_type.cost then
        ui_select_building(self.index)
    end
end

function ui_init()
    building_icons = {}
    selected_icon_index = nil
    king_move_mode = false
    
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local icon_width = 100
    local icon_height = 60
    local icon_spacing = 10
    
    local total_width = #get_building_types() * icon_width + 
                       (#get_building_types() - 1) * icon_spacing
    local start_x = (screen_width - total_width) / 2
    local start_y = screen_height - icon_height - 20
    
    for i, building_type in ipairs(get_building_types()) do
        local x = start_x + (i - 1) * (icon_width + icon_spacing)
        local icon = UIIcon:new(x, start_y, icon_width, icon_height, 
                               building_type, i)
        table.insert(building_icons, icon)
    end
    
    king_move_button = UIIcon:new(start_x - icon_width - icon_spacing, start_y, 
                                 icon_width, icon_height, 
                                 {name = "Move King", cost = 0}, 0)
end

function ui_update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    
    for _, icon in ipairs(building_icons) do
        icon.hovered = icon:isPointInside(mouseX, mouseY)
        icon.selected = (selected_icon_index == icon.index)
    end
    
    king_move_button.hovered = king_move_button:isPointInside(mouseX, mouseY)
    king_move_button.selected = king_move_mode
end

function ui_draw()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, love.graphics.getHeight() - 100, 
                          love.graphics.getWidth(), 100)
    
    king_move_button:draw()
    
    for _, icon in ipairs(building_icons) do
        icon:draw()
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Gold: " .. player_get_gold(), 10, 10)
    love.graphics.print("Hearts: " .. player_get_hearts(), 10, 30)
    
    local screen_width = love.graphics.getWidth()
    love.graphics.print("Enemy Hearts: " .. enemy_get_hearts(), 
                       screen_width - 120, 10)
    
    if get_selected_building_type() then
        love.graphics.print("Click on a controlled room to place building", 
                          10, love.graphics.getHeight() - 120)
    elseif king_move_mode then
        love.graphics.print("Click on a room to move your king there", 
                          10, love.graphics.getHeight() - 120)
    end
end

function ui_mousepressed(x, y, button)
    if button == 1 then
        if king_move_button:isPointInside(x, y) then
            king_move_button:click()
            return true
        end
        
        for _, icon in ipairs(building_icons) do
            if icon:isPointInside(x, y) then
                icon:click()
                king_move_mode = false
                return true
            end
        end
    end
    return false
end

function ui_select_building(index)
    if selected_icon_index == index then
        selected_icon_index = nil
        set_selected_building_type(nil)
    else
        selected_icon_index = index
        set_selected_building_type(index)
    end
end

function ui_select_building_by_index(index)
    if index >= 1 and index <= #building_icons then
        ui_select_building(index)
    end
end

function ui_clear_selection()
    selected_icon_index = nil
end

function is_king_move_mode()
    return king_move_mode
end

function clear_king_move_mode()
    king_move_mode = false
end