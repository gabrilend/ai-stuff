-- main.lua - the door LÖVE knocks on.
--
-- LÖVE insists on a file with exactly this name, so it is the one source file
-- without a reading-order number. It holds no logic: it hands LÖVE's
-- callbacks to the game (016-the-game.lua), which is where the story is.

local game = require("016-the-game")

love.run = game.run
love.mousepressed = game.mousepressed
love.keypressed = game.keypressed
love.wheelmoved = game.wheelmoved
