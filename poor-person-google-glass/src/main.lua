-- main.lua - the door LÖVE knocks on.
--
-- LÖVE insists on a file with exactly this name, so it has no reading-order
-- number. It holds no logic: it lets src/ find the project's libraries
-- (libs/, beside src/), then hands LÖVE's callbacks to the CAD viewer
-- (010-the-viewer.lua), which is where the story is.

-- the project folder is the first game argument (the view-cad script passes
-- it); libs/ is found from there, since LÖVE's own search sees only src/
local project_dir = love.arg.parseGameArguments(arg)[1]
if project_dir == nil then
    error("the viewer needs the project folder as its first argument (use the view-cad script)", 0)
end
package.path = project_dir .. "/libs/?.lua;" .. package.path

local viewer = require("010-the-viewer")

love.load = viewer.load
love.update = viewer.update
love.draw = viewer.draw
love.mousemoved = viewer.mousemoved
love.wheelmoved = viewer.wheelmoved
love.keypressed = viewer.keypressed
love.resize = viewer.resize
love.filedropped = viewer.filedropped
love.quit = viewer.quit
