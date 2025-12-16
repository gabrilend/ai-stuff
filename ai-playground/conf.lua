-- {{{ love configuration
function love.conf(t)
    t.title = "AI Playground - Neural Network Visualizer"
    t.window.width = 1200
    t.window.height = 800
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    t.console = false
    t.version = "11.4"
    
    -- Enable modules we'll need
    t.modules.audio = false
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = false
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end
-- }}}