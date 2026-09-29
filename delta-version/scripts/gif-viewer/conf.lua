-- conf.lua - The gif viewer's window settings, read by LÖVE before anything
-- else runs: a resizable black window titled for what it shows.

function love.conf(t)
    t.identity = "gif-viewer"
    t.window.title = "shape gifs"
    t.window.width = 960
    t.window.height = 960
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 320
    -- nothing here makes sound or uses a joystick or physics
    t.modules.audio = false
    t.modules.sound = false
    t.modules.joystick = false
    t.modules.physics = false
end
