-- {{{ Chat Log Display
-- Real-time chat-log style display for LLM narrations

local ChatLog = {}
ChatLog.__index = ChatLog

-- {{{ ChatLog constructor
function ChatLog:new(x, y, width, height)
    local obj = {
        x = x or 50,
        y = y or 50,
        width = width or 300,
        height = height or 400,
        
        -- Message storage
        messages = {},
        max_messages = 100,
        
        -- Visual settings
        line_height = 16,
        padding = 8,
        scroll_offset = 0,
        auto_scroll = true,
        
        -- Colors and styling
        colors = {
            background = {0.05, 0.05, 0.1, 0.95},
            border = {0.3, 0.3, 0.4},
            text_user = {0.9, 0.9, 1.0},
            text_ai = {0.3, 0.8, 0.3},
            text_system = {0.8, 0.8, 0.3},
            text_error = {0.8, 0.3, 0.3},
            text_timestamp = {0.5, 0.5, 0.5},
            scroll_bar = {0.4, 0.4, 0.5},
            scroll_thumb = {0.6, 0.6, 0.7}
        },
        
        -- Fonts
        font = love.graphics.getFont(),
        font_small = nil,
        
        -- Animation
        message_fade_in = {},
        animation_duration = 0.5,
        
        -- Interaction
        scroll_dragging = false,
        scroll_drag_start = 0,
        
        -- Auto-typing effect
        typing_effect = true,
        typing_speed = 30,  -- characters per second
        current_typing = nil,
        
        -- Message formatting
        word_wrap = true,
        show_timestamps = true,
        show_message_types = true,
        compact_mode = false
    }
    
    setmetatable(obj, self)
    
    -- Initialize small font if available
    pcall(function()
        obj.font_small = love.graphics.newFont(12)
    end)
    
    return obj
end
-- }}}

-- {{{ Message Management
function ChatLog:add_message(text, message_type, sender)
    message_type = message_type or "ai"
    sender = sender or (message_type == "user" and "User" or "AI Assistant")
    
    local message = {
        text = text,
        type = message_type,
        sender = sender,
        timestamp = os.time(),
        formatted_time = os.date("%H:%M:%S"),
        id = #self.messages + 1,
        fade_alpha = 0,
        wrapped_lines = nil,
        
        -- Typing animation state
        typing_progress = 0,
        fully_typed = false
    }
    
    -- Pre-calculate wrapped lines if word wrap is enabled
    if self.word_wrap then
        message.wrapped_lines = self:wrap_text(text, self.width - self.padding * 2 - 20)
    end
    
    table.insert(self.messages, message)
    
    -- Start fade-in animation
    self.message_fade_in[message.id] = {
        start_time = love.timer.getTime(),
        duration = self.animation_duration
    }
    
    -- Start typing animation
    if self.typing_effect then
        self.current_typing = message
    else
        message.fully_typed = true
    end
    
    -- Auto-scroll to bottom
    if self.auto_scroll then
        self:scroll_to_bottom()
    end
    
    -- Limit message history
    if #self.messages > self.max_messages then
        local removed_message = table.remove(self.messages, 1)
        self.message_fade_in[removed_message.id] = nil
        
        -- Adjust IDs
        for i, msg in ipairs(self.messages) do
            msg.id = i
        end
    end
end

function ChatLog:add_ai_narration(text)
    self:add_message(text, "ai", "Neural Network AI")
end

function ChatLog:add_system_message(text)
    self:add_message(text, "system", "System")
end

function ChatLog:add_error_message(text)
    self:add_message(text, "error", "Error")
end

function ChatLog:clear_messages()
    self.messages = {}
    self.message_fade_in = {}
    self.current_typing = nil
    self.scroll_offset = 0
end
-- }}}

-- {{{ Text Wrapping and Formatting
function ChatLog:wrap_text(text, max_width)
    if not self.word_wrap then
        return {text}
    end
    
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    local lines = {}
    local current_line = ""
    local font = self.font
    
    for _, word in ipairs(words) do
        local test_line = current_line == "" and word or (current_line .. " " .. word)
        local line_width = font:getWidth(test_line)
        
        if line_width <= max_width then
            current_line = test_line
        else
            if current_line ~= "" then
                table.insert(lines, current_line)
                current_line = word
            else
                -- Single word is too long, break it
                table.insert(lines, word)
                current_line = ""
            end
        end
    end
    
    if current_line ~= "" then
        table.insert(lines, current_line)
    end
    
    return #lines > 0 and lines or {text}
end

function ChatLog:calculate_message_height(message)
    local base_height = self.line_height
    
    if self.word_wrap and message.wrapped_lines then
        base_height = #message.wrapped_lines * self.line_height
    end
    
    -- Add space for timestamp and sender if shown
    if self.show_timestamps or self.show_message_types then
        base_height = base_height + (self.line_height * 0.7)
    end
    
    -- Add padding between messages
    base_height = base_height + self.padding / 2
    
    return base_height
end

function ChatLog:get_total_content_height()
    local total_height = 0
    for _, message in ipairs(self.messages) do
        total_height = total_height + self:calculate_message_height(message)
    end
    return total_height + self.padding * 2
end

function ChatLog:get_visible_message_range()
    local content_area_height = self.height - self.padding * 2
    local current_y = -self.scroll_offset
    local visible_messages = {}
    
    for i, message in ipairs(self.messages) do
        local message_height = self:calculate_message_height(message)
        
        -- Check if message is visible
        if current_y + message_height >= 0 and current_y < content_area_height then
            table.insert(visible_messages, {index = i, message = message, y_offset = current_y})
        end
        
        current_y = current_y + message_height
    end
    
    return visible_messages
end
-- }}}

-- {{{ Animation and Updates
function ChatLog:update(dt)
    local current_time = love.timer.getTime()
    
    -- Update fade-in animations
    for message_id, anim in pairs(self.message_fade_in) do
        local elapsed = current_time - anim.start_time
        local progress = math.min(elapsed / anim.duration, 1.0)
        
        if progress >= 1.0 then
            self.message_fade_in[message_id] = nil
        end
        
        -- Find message and update its fade alpha
        for _, message in ipairs(self.messages) do
            if message.id == message_id then
                message.fade_alpha = progress
                break
            end
        end
    end
    
    -- Update typing animation
    if self.current_typing and not self.current_typing.fully_typed then
        local typing_progress = self.current_typing.typing_progress + (self.typing_speed * dt)
        local total_chars = string.len(self.current_typing.text)
        
        if typing_progress >= total_chars then
            self.current_typing.fully_typed = true
            self.current_typing = nil
        else
            self.current_typing.typing_progress = typing_progress
        end
    end
end

function ChatLog:get_typing_text(message)
    if message.fully_typed then
        return message.text
    end
    
    local char_count = math.floor(message.typing_progress)
    local partial_text = string.sub(message.text, 1, char_count)
    
    -- Add cursor effect
    if char_count < string.len(message.text) then
        partial_text = partial_text .. "|"
    end
    
    return partial_text
end
-- }}}

-- {{{ Scrolling
function ChatLog:scroll(delta)
    local content_height = self:get_total_content_height()
    local visible_height = self.height - self.padding * 2
    local max_scroll = math.max(0, content_height - visible_height)
    
    self.scroll_offset = math.max(0, math.min(max_scroll, self.scroll_offset - delta))
end

function ChatLog:scroll_to_bottom()
    local content_height = self:get_total_content_height()
    local visible_height = self.height - self.padding * 2
    self.scroll_offset = math.max(0, content_height - visible_height)
end

function ChatLog:get_scroll_bar_info()
    local content_height = self:get_total_content_height()
    local visible_height = self.height - self.padding * 2
    
    if content_height <= visible_height then
        return nil  -- No scroll bar needed
    end
    
    local scroll_bar_height = visible_height
    local thumb_height = (visible_height / content_height) * scroll_bar_height
    local thumb_position = (self.scroll_offset / (content_height - visible_height)) * (scroll_bar_height - thumb_height)
    
    return {
        bar_x = self.x + self.width - 12,
        bar_y = self.y + self.padding,
        bar_width = 8,
        bar_height = scroll_bar_height,
        thumb_x = self.x + self.width - 12,
        thumb_y = self.y + self.padding + thumb_position,
        thumb_width = 8,
        thumb_height = math.max(20, thumb_height)
    }
end
-- }}}

-- {{{ Rendering
function ChatLog:draw()
    -- Draw background
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Draw border
    love.graphics.setColor(self.colors.border)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Set up clipping for content area
    love.graphics.push()
    love.graphics.intersectScissor(
        self.x + self.padding, 
        self.y + self.padding, 
        self.width - self.padding * 2 - 15, -- Leave space for scroll bar
        self.height - self.padding * 2
    )
    
    -- Draw messages
    self:draw_messages()
    
    love.graphics.pop()
    
    -- Draw scroll bar
    self:draw_scroll_bar()
end

function ChatLog:draw_messages()
    local visible_messages = self:get_visible_message_range()
    
    for _, msg_info in ipairs(visible_messages) do
        local message = msg_info.message
        local y_pos = self.y + self.padding + msg_info.y_offset
        
        -- Calculate alpha including fade-in effect
        local alpha = message.fade_alpha or 1.0
        
        -- Draw message header (timestamp, sender)
        if self.show_timestamps or self.show_message_types then
            local header_text = ""
            if self.show_timestamps then
                header_text = message.formatted_time
            end
            if self.show_message_types then
                if header_text ~= "" then header_text = header_text .. " " end
                header_text = header_text .. "[" .. message.sender .. "]"
            end
            
            love.graphics.setColor(self.colors.text_timestamp[1], 
                                  self.colors.text_timestamp[2], 
                                  self.colors.text_timestamp[3], alpha)
            love.graphics.setFont(self.font_small or self.font)
            love.graphics.print(header_text, self.x + self.padding, y_pos)
            
            y_pos = y_pos + (self.line_height * 0.7)
        end
        
        -- Choose text color based on message type
        local text_color = self.colors.text_ai
        if message.type == "user" then
            text_color = self.colors.text_user
        elseif message.type == "system" then
            text_color = self.colors.text_system
        elseif message.type == "error" then
            text_color = self.colors.text_error
        end
        
        love.graphics.setColor(text_color[1], text_color[2], text_color[3], alpha)
        love.graphics.setFont(self.font)
        
        -- Draw message text (with word wrapping if enabled)
        if self.word_wrap and message.wrapped_lines then
            for _, line in ipairs(message.wrapped_lines) do
                love.graphics.print(line, self.x + self.padding + 10, y_pos)
                y_pos = y_pos + self.line_height
            end
        else
            local display_text = self:get_typing_text(message)
            love.graphics.print(display_text, self.x + self.padding + 10, y_pos)
        end
    end
end

function ChatLog:draw_scroll_bar()
    local scroll_info = self:get_scroll_bar_info()
    if not scroll_info then return end
    
    -- Draw scroll bar background
    love.graphics.setColor(self.colors.scroll_bar)
    love.graphics.rectangle("fill", scroll_info.bar_x, scroll_info.bar_y, 
                           scroll_info.bar_width, scroll_info.bar_height)
    
    -- Draw scroll thumb
    love.graphics.setColor(self.colors.scroll_thumb)
    love.graphics.rectangle("fill", scroll_info.thumb_x, scroll_info.thumb_y, 
                           scroll_info.thumb_width, scroll_info.thumb_height)
end
-- }}}

-- {{{ Input Handling
function ChatLog:mouse_pressed(x, y, button)
    if button ~= 1 then return false end
    
    -- Check if clicking on scroll bar
    local scroll_info = self:get_scroll_bar_info()
    if scroll_info and x >= scroll_info.bar_x and x <= scroll_info.bar_x + scroll_info.bar_width and
       y >= scroll_info.bar_y and y <= scroll_info.bar_y + scroll_info.bar_height then
        
        self.scroll_dragging = true
        self.scroll_drag_start = y
        return true
    end
    
    return false
end

function ChatLog:mouse_moved(x, y)
    if self.scroll_dragging then
        local scroll_info = self:get_scroll_bar_info()
        if scroll_info then
            local drag_delta = y - self.scroll_drag_start
            local content_height = self:get_total_content_height()
            local visible_height = self.height - self.padding * 2
            local scroll_ratio = drag_delta / scroll_info.bar_height
            local max_scroll = content_height - visible_height
            
            self.scroll_offset = math.max(0, math.min(max_scroll, 
                                 self.scroll_offset + scroll_ratio * max_scroll))
            self.scroll_drag_start = y
        end
    end
end

function ChatLog:mouse_released(x, y, button)
    if button == 1 and self.scroll_dragging then
        self.scroll_dragging = false
        return true
    end
    return false
end

function ChatLog:wheel_moved(x, y)
    self:scroll(y * 20)  -- Scroll speed
end
-- }}}

-- {{{ Configuration
function ChatLog:set_auto_scroll(enabled)
    self.auto_scroll = enabled
end

function ChatLog:set_typing_effect(enabled)
    self.typing_effect = enabled
    if not enabled then
        -- Complete all current typing animations
        for _, message in ipairs(self.messages) do
            message.fully_typed = true
        end
        self.current_typing = nil
    end
end

function ChatLog:set_word_wrap(enabled)
    self.word_wrap = enabled
    -- Recalculate wrapped lines for all messages
    if enabled then
        for _, message in ipairs(self.messages) do
            message.wrapped_lines = self:wrap_text(message.text, self.width - self.padding * 2 - 20)
        end
    end
end

function ChatLog:set_show_timestamps(enabled)
    self.show_timestamps = enabled
end

function ChatLog:set_compact_mode(enabled)
    self.compact_mode = enabled
    self.line_height = enabled and 14 or 16
    self.padding = enabled and 4 or 8
end

function ChatLog:resize(new_width, new_height)
    self.width = new_width
    self.height = new_height
    
    -- Recalculate word wrapping for all messages
    if self.word_wrap then
        for _, message in ipairs(self.messages) do
            message.wrapped_lines = self:wrap_text(message.text, self.width - self.padding * 2 - 20)
        end
    end
end

function ChatLog:get_stats()
    return {
        message_count = #self.messages,
        scroll_offset = self.scroll_offset,
        total_height = self:get_total_content_height(),
        typing_active = self.current_typing ~= nil
    }
end
-- }}}

return ChatLog
-- }}}