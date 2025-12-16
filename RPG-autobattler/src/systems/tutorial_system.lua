-- {{{ TutorialSystem
local TutorialSystem = {}

local Colors = require("src.constants.colors")
local Vector2 = require("src.utils.vector2")
local debug = require("src.utils.debug")

-- {{{ TutorialSystem:new
function TutorialSystem:new(renderer)
    local system = {
        renderer = renderer,
        name = "tutorial",
        
        -- Tutorial state
        active = false,
        current_step = 1,
        total_steps = 0,
        tutorial_steps = {},
        
        -- Display settings
        box_width = 300,
        box_height = 120,
        box_padding = 15,
        arrow_length = 40,
        arrow_width = 8,
        
        -- Colors
        box_color = {0.1, 0.1, 0.15, 0.9},
        box_border_color = {0.4, 0.6, 1.0, 1.0},
        text_color = {0.9, 0.9, 0.9, 1.0},
        title_color = {0.4, 0.8, 1.0, 1.0},
        arrow_color = {1.0, 0.8, 0.2, 1.0},
        
        -- Animation
        fade_in_duration = 0.5,
        current_fade = 0.0,
        fade_direction = 1
    }
    setmetatable(system, {__index = TutorialSystem})
    
    debug.log("TutorialSystem created", "TUTORIAL")
    return system
end
-- }}}

-- {{{ TutorialSystem:add_step
function TutorialSystem:add_step(title, description, target_position, arrow_direction, interaction_hint)
    local step = {
        title = title or "Tutorial Step",
        description = description or "No description provided",
        target_position = target_position or Vector2:new(400, 300),
        arrow_direction = arrow_direction or "down", -- "up", "down", "left", "right"
        interaction_hint = interaction_hint or "Press SPACE to continue",
        box_position = nil, -- Will be calculated based on target and arrow direction
        box_width = nil, -- Will be calculated based on content
        box_height = nil, -- Will be calculated based on content
        completed = false
    }
    
    -- Calculate dynamic box dimensions based on content
    self:calculate_box_dimensions(step)
    
    -- Calculate box position based on target and arrow direction
    step.box_position = self:calculate_box_position(step.target_position, step.arrow_direction, step.box_width, step.box_height)
    
    table.insert(self.tutorial_steps, step)
    self.total_steps = #self.tutorial_steps
    
    debug.log("Added tutorial step: " .. step.title, "TUTORIAL")
end
-- }}}

-- {{{ TutorialSystem:calculate_box_dimensions
function TutorialSystem:calculate_box_dimensions(step)
    local min_width = 250
    local max_width = 400
    local base_height = 80 -- Title + padding + interaction hint space
    local line_height = 18
    local extra_spacing = 36 -- Two lines of extra space before interaction hint
    
    -- Calculate title width (rough estimation)
    local title_width = #step.title * 8 + self.box_padding * 2
    
    -- Calculate description dimensions
    local desc_width = max_width - self.box_padding * 2
    local desc_lines = self:calculate_wrapped_lines(step.description, desc_width)
    local desc_height = #desc_lines * line_height
    
    -- Calculate interaction hint width
    local hint_width = #step.interaction_hint * 7 + self.box_padding * 2
    
    -- Set dynamic width based on content
    step.box_width = math.max(min_width, math.min(max_width, math.max(title_width, hint_width)))
    
    -- Recalculate description with actual box width
    desc_width = step.box_width - self.box_padding * 2
    desc_lines = self:calculate_wrapped_lines(step.description, desc_width)
    desc_height = #desc_lines * line_height
    
    -- Set dynamic height
    step.box_height = base_height + desc_height + extra_spacing
end
-- }}}

-- {{{ TutorialSystem:calculate_wrapped_lines
function TutorialSystem:calculate_wrapped_lines(text, width)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local lines = {}
    local line = ""
    
    for _, word in ipairs(words) do
        local test_line = line == "" and word or line .. " " .. word
        -- Approximate character width check (rough estimation)
        if #test_line * 7 > width and line ~= "" then
            table.insert(lines, line)
            line = word
        else
            line = test_line
        end
    end
    
    if line ~= "" then
        table.insert(lines, line)
    end
    
    return lines
end
-- }}}

-- {{{ TutorialSystem:calculate_box_position
function TutorialSystem:calculate_box_position(target_pos, arrow_dir, box_width, box_height)
    local offset_distance = self.arrow_length + 20
    
    if arrow_dir == "up" then
        return Vector2:new(target_pos.x - box_width/2, target_pos.y - box_height - offset_distance)
    elseif arrow_dir == "down" then
        return Vector2:new(target_pos.x - box_width/2, target_pos.y + offset_distance)
    elseif arrow_dir == "left" then
        return Vector2:new(target_pos.x - box_width - offset_distance, target_pos.y - box_height/2)
    elseif arrow_dir == "right" then
        return Vector2:new(target_pos.x + offset_distance, target_pos.y - box_height/2)
    else
        return Vector2:new(target_pos.x - box_width/2, target_pos.y + offset_distance)
    end
end
-- }}}

-- {{{ TutorialSystem:start_tutorial
function TutorialSystem:start_tutorial()
    if #self.tutorial_steps == 0 then
        debug.warn("No tutorial steps defined", "TUTORIAL")
        return false
    end
    
    self.active = true
    self.current_step = 1
    self.current_fade = 0.0
    self.fade_direction = 1
    
    debug.log("Started tutorial with " .. self.total_steps .. " steps", "TUTORIAL")
    return true
end
-- }}}

-- {{{ TutorialSystem:stop_tutorial
function TutorialSystem:stop_tutorial()
    self.active = false
    self.current_step = 1
    self.current_fade = 0.0
    
    debug.log("Stopped tutorial", "TUTORIAL")
end
-- }}}

-- {{{ TutorialSystem:next_step
function TutorialSystem:next_step()
    if not self.active then
        return false
    end
    
    if self.current_step < self.total_steps then
        self.tutorial_steps[self.current_step].completed = true
        self.current_step = self.current_step + 1
        self.current_fade = 0.0
        self.fade_direction = 1
        
        debug.log("Advanced to tutorial step " .. self.current_step, "TUTORIAL")
        return true
    else
        -- Tutorial completed
        self.tutorial_steps[self.current_step].completed = true
        self:stop_tutorial()
        debug.log("Tutorial completed", "TUTORIAL")
        return false
    end
end
-- }}}

-- {{{ TutorialSystem:previous_step
function TutorialSystem:previous_step()
    if not self.active then
        return false
    end
    
    if self.current_step > 1 then
        self.current_step = self.current_step - 1
        self.tutorial_steps[self.current_step].completed = false
        self.current_fade = 0.0
        self.fade_direction = 1
        
        debug.log("Returned to tutorial step " .. self.current_step, "TUTORIAL")
        return true
    end
    
    return false
end
-- }}}

-- {{{ TutorialSystem:update
function TutorialSystem:update(dt)
    if not self.active then
        return
    end
    
    -- Update fade animation
    if self.fade_direction == 1 then
        self.current_fade = math.min(1.0, self.current_fade + dt / self.fade_in_duration)
    else
        self.current_fade = math.max(0.0, self.current_fade - dt / self.fade_in_duration)
    end
end
-- }}}

-- {{{ TutorialSystem:handle_input
function TutorialSystem:handle_input(key)
    if not self.active then
        return false
    end
    
    -- No timeout/cooldown - immediate response
    if key == "space" or key == "return" or key == "right" then
        self:next_step()
        return true
    elseif key == "backspace" or key == "left" then
        self:previous_step()
        return true
    elseif key == "escape" then
        self:stop_tutorial()
        return true
    end
    
    return false
end
-- }}}

-- {{{ TutorialSystem:draw
function TutorialSystem:draw()
    if not self.active or self.current_step > self.total_steps then
        return
    end
    
    local step = self.tutorial_steps[self.current_step]
    if not step then
        return
    end
    
    local alpha = self.current_fade
    
    -- Draw highlight circle around target
    self:draw_target_highlight(step.target_position, alpha)
    
    -- Draw arrow pointing to target
    self:draw_arrow(step, alpha)
    
    -- Draw tutorial box
    self:draw_tutorial_box(step, alpha)
    
    -- Draw step counter
    self:draw_step_counter(alpha)
end
-- }}}

-- {{{ TutorialSystem:draw_target_highlight
function TutorialSystem:draw_target_highlight(target_pos, alpha)
    local highlight_color = {self.arrow_color[1], self.arrow_color[2], self.arrow_color[3], alpha * 0.3}
    local border_color = {self.arrow_color[1], self.arrow_color[2], self.arrow_color[3], alpha * 0.8}
    
    -- Pulsing highlight circle
    local pulse = math.sin(love.timer.getTime() * 3) * 0.1 + 0.9
    local radius = 25 * pulse
    
    self.renderer:draw_circle(target_pos.x, target_pos.y, radius, highlight_color, "fill")
    self.renderer:draw_circle(target_pos.x, target_pos.y, radius, border_color, "line")
end
-- }}}

-- {{{ TutorialSystem:draw_arrow
function TutorialSystem:draw_arrow(step, alpha)
    local arrow_color = {self.arrow_color[1], self.arrow_color[2], self.arrow_color[3], alpha}
    local box_pos = step.box_position
    local target_pos = step.target_position
    local direction = step.arrow_direction
    local box_width = step.box_width
    local box_height = step.box_height
    
    local start_pos = Vector2:new(0, 0)
    local end_pos = Vector2:new(0, 0)
    
    -- Calculate arrow start and end positions
    if direction == "down" then
        start_pos = Vector2:new(box_pos.x + box_width/2, box_pos.y + box_height)
        end_pos = Vector2:new(target_pos.x, target_pos.y - 25)
    elseif direction == "up" then
        start_pos = Vector2:new(box_pos.x + box_width/2, box_pos.y)
        end_pos = Vector2:new(target_pos.x, target_pos.y + 25)
    elseif direction == "right" then
        start_pos = Vector2:new(box_pos.x + box_width, box_pos.y + box_height/2)
        end_pos = Vector2:new(target_pos.x - 25, target_pos.y)
    elseif direction == "left" then
        start_pos = Vector2:new(box_pos.x, box_pos.y + box_height/2)
        end_pos = Vector2:new(target_pos.x + 25, target_pos.y)
    end
    
    -- Draw arrow
    self.renderer:draw_arrow(
        start_pos.x, start_pos.y,
        end_pos.x, end_pos.y,
        arrow_color, 3, self.arrow_width
    )
end
-- }}}

-- {{{ TutorialSystem:draw_tutorial_box
function TutorialSystem:draw_tutorial_box(step, alpha)
    local box_color = {self.box_color[1], self.box_color[2], self.box_color[3], alpha * self.box_color[4]}
    local border_color = {self.box_border_color[1], self.box_border_color[2], self.box_border_color[3], alpha}
    local text_color = {self.text_color[1], self.text_color[2], self.text_color[3], alpha}
    local title_color = {self.title_color[1], self.title_color[2], self.title_color[3], alpha}
    
    local box_x = step.box_position.x
    local box_y = step.box_position.y
    local box_width = step.box_width
    local box_height = step.box_height
    
    -- Draw box background
    self.renderer:draw_rectangle(box_x, box_y, box_width, box_height, box_color, "fill")
    
    -- Draw box border
    self.renderer:draw_rectangle(box_x, box_y, box_width, box_height, border_color, "line")
    
    -- Draw title
    local title_x = box_x + self.box_padding
    local title_y = box_y + self.box_padding
    self.renderer:draw_text(step.title, title_x, title_y, title_color)
    
    -- Draw description (word wrapped)
    local desc_x = box_x + self.box_padding
    local desc_y = title_y + 25
    local desc_width = box_width - self.box_padding * 2
    local desc_lines_used = self:draw_wrapped_text(step.description, desc_x, desc_y, desc_width, text_color)
    
    -- Draw interaction hint at bottom with proper spacing
    local hint_x = box_x + self.box_padding
    local hint_y = box_y + box_height - 25 -- Always at bottom with padding
    local hint_color = {text_color[1] * 0.8, text_color[2] * 0.8, text_color[3] * 0.8, alpha}
    self.renderer:draw_text(step.interaction_hint, hint_x, hint_y, hint_color)
end
-- }}}

-- {{{ TutorialSystem:draw_wrapped_text
function TutorialSystem:draw_wrapped_text(text, x, y, width, color)
    -- Simple word wrapping (could be enhanced)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local line = ""
    local line_height = 18
    local current_y = y
    local lines_drawn = 0
    
    for _, word in ipairs(words) do
        local test_line = line == "" and word or line .. " " .. word
        -- Approximate character width check (rough estimation)
        if #test_line * 7 > width and line ~= "" then
            self.renderer:draw_text(line, x, current_y, color)
            line = word
            current_y = current_y + line_height
            lines_drawn = lines_drawn + 1
        else
            line = test_line
        end
    end
    
    if line ~= "" then
        self.renderer:draw_text(line, x, current_y, color)
        lines_drawn = lines_drawn + 1
    end
    
    return lines_drawn
end
-- }}}

-- {{{ TutorialSystem:draw_step_counter
function TutorialSystem:draw_step_counter(alpha)
    local counter_text = "Step " .. self.current_step .. " of " .. self.total_steps
    local counter_color = {self.text_color[1], self.text_color[2], self.text_color[3], alpha * 0.7}
    
    -- Position in top-right corner
    local counter_x = love.graphics.getWidth() - 120
    local counter_y = 20
    
    self.renderer:draw_text(counter_text, counter_x, counter_y, counter_color)
end
-- }}}

-- {{{ TutorialSystem:is_active
function TutorialSystem:is_active()
    return self.active
end
-- }}}

-- {{{ TutorialSystem:get_current_step
function TutorialSystem:get_current_step()
    return self.current_step
end
-- }}}

-- {{{ TutorialSystem:skip_to_step
function TutorialSystem:skip_to_step(step_number)
    if step_number >= 1 and step_number <= self.total_steps then
        self.current_step = step_number
        self.current_fade = 0.0
        self.fade_direction = 1
        return true
    end
    return false
end
-- }}}

-- {{{ TutorialSystem:clear_steps
function TutorialSystem:clear_steps()
    self.tutorial_steps = {}
    self.total_steps = 0
    self.current_step = 1
    self.active = false
    
    debug.log("Cleared all tutorial steps", "TUTORIAL")
end
-- }}}

return TutorialSystem
-- }}}