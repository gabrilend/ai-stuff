-- main.lua - the door LÖVE knocks on.
--
-- LÖVE insists on a file with exactly this name, so it is the one source file
-- without a reading-order number. It holds no logic: it hands LÖVE's
-- callbacks to the game (016-the-game.lua), which is where the story is.

local game = require("016-the-game")

love.run = game.run
-- The person's input reaches the game only when no script drives it: a
-- scripted run (pictures, checks) opens on the person's screen, and their
-- typing and mouse there would otherwise change what the script set up
-- (they did: stray spins and a wrong view distance in the history).
-- {{{ local function from_the_person()
local function from_the_person(handler)
    return function(...)
        -- a script drives this run: the person's input is not for it
        if game.scripted_run then
            return
        end
        handler(...)
    end
end
-- }}}
love.mousepressed = from_the_person(game.mousepressed)
love.mousemoved = from_the_person(game.mousemoved)
love.mousereleased = from_the_person(game.mousereleased)
love.keypressed = from_the_person(game.keypressed)
love.keyreleased = from_the_person(game.keyreleased)
love.focus = from_the_person(game.focus)
love.wheelmoved = from_the_person(game.wheelmoved)
