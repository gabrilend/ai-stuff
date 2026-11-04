-- conf.lua - LÖVE's settings door.
--
-- LÖVE reads a file with exactly this name before anything else, so it is one
-- of the two source files without a reading-order number. The window is not
-- opened here: the viewer opens it after reading input/, so its size comes
-- from input/viewer-settings.lua like every other setting.

function love.conf(t)
    t.identity = "poor-person-google-glass"
    t.version = "11.5"
    t.window = false
    t.modules.audio = false
    t.modules.sound = false
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
