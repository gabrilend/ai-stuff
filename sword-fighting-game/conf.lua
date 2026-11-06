-- conf.lua
--
-- The engine reads this before it opens anything, so the window's shape and
-- which engine modules start at all are decided here. Like main.lua it has
-- no index, because the engine chooses its name. Settings only, no logic.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- A depth buffer, because the world is drawn in three dimensions with the
-- engine's mesh and shader primitives; four samples of antialiasing for the
-- clay's soft edges. Modules the game does not use are not started, so they
-- cannot be quietly depended on.
-- {{{ function love.conf()
function love.conf(t)
	t.identity = "sword-fighting-game"
	t.window.title = "sword-fighting-game"
	t.window.width = 1280
	t.window.height = 720
	t.window.resizable = true
	t.window.depth = 24
	t.window.msaa = 4
	t.window.vsync = 1
	t.modules.audio = false
	t.modules.sound = false
	t.modules.physics = false
	t.modules.joystick = false
	t.modules.video = false
	t.modules.touch = false
end
-- }}}
