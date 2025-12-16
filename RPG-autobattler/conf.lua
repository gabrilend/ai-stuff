-- {{{ love.conf
function love.conf(t)
    t.title = "RPG-Autobattler"
    t.version = "11.5"
    t.console = true
    
    t.window.width = 1024
    t.window.height = 768
    t.window.resizable = false
    t.window.vsync = 1
    
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.touch = false
    t.modules.video = false
end
-- }}}