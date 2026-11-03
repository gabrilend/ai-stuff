-- {{{ EditorState
-- The unit template editor as a game state. It only hands LÖVE's
-- drawing and input to the template editor screen
-- (src/editor/template_editor_screen.lua), which hands every change to
-- the editor's tested logic in src/editor/. Templates are saved to
-- LÖVE's save folder through template storage.
local BaseState = require("src.systems.base_state")
local debug = require("src.utils.debug")
local TemplateEditorScreen = require("src.editor.template_editor_screen")
local TemplateStorage = require("src.storage.template_storage")

local EditorState = BaseState:new("editor")

-- {{{ EditorState:enter
function EditorState:enter()
    BaseState.enter(self)
    local ok, storage = pcall(TemplateStorage.new, TemplateStorage)
    if not ok then
        debug.warn("Template storage unavailable, saving is off: " .. tostring(storage), "EDITOR")
        storage = nil
    end
    local width, height = love.graphics.getDimensions()
    self.screen = TemplateEditorScreen.new({
        storage = storage,
        width = width,
        height = height,
        keyboard = love.keyboard,
        on_exit = function()
            require("src.systems.state_manager"):change_state("menu")
        end
    })
    if love.keyboard and love.keyboard.setKeyRepeat then
        love.keyboard.setKeyRepeat(true)
    end
    debug.info("Editor state entered", "EDITOR")
end
-- }}}

-- {{{ EditorState:exit
function EditorState:exit()
    BaseState.exit(self)
    self.screen = nil
    debug.info("Editor state exited", "EDITOR")
end
-- }}}

-- {{{ EditorState:update
function EditorState:update(dt)
    BaseState.update(self, dt)
    local width, height = love.graphics.getDimensions()
    if width ~= self.screen.width or height ~= self.screen.height then
        self.screen:resize(width, height)
    end
    self.screen:update(dt)
end
-- }}}

-- {{{ EditorState:draw
function EditorState:draw()
    BaseState.draw(self)
    self.screen:draw(love.graphics)
    if debug.enabled and debug.drawDebugInfo then
        debug.drawDebugInfo(0, 0, 0)
    end
end
-- }}}

-- {{{ EditorState:keypressed
-- Escape goes to the screen, which asks before dropping unsaved changes
-- and returns to the menu itself.
function EditorState:keypressed(key)
    if BaseState.keypressed(self, key) then
        return true
    end
    return self.screen:keypressed(key) or key == "escape"
end
-- }}}

-- {{{ EditorState:mousepressed
function EditorState:mousepressed(x, y, button)
    return self.screen:mousepressed(x, y, button)
end
-- }}}

-- {{{ EditorState:mousereleased
function EditorState:mousereleased(x, y, button)
    return self.screen:mousereleased(x, y, button)
end
-- }}}

-- {{{ EditorState:mousemoved
function EditorState:mousemoved(x, y, dx, dy)
    return self.screen:mousemoved(x, y)
end
-- }}}

-- {{{ EditorState:wheelmoved
function EditorState:wheelmoved(x, y)
    return self.screen:wheelmoved(x, y)
end
-- }}}

-- {{{ EditorState:textinput
function EditorState:textinput(text)
    return self.screen:textinput(text)
end
-- }}}

-- {{{ EditorState:resize
function EditorState:resize(width, height)
    self.screen:resize(width, height)
    return true
end
-- }}}

return EditorState
-- }}}
