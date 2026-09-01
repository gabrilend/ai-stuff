-- conf.lua
--
-- The engine reads this before it opens anything, so the window's shape and
-- which engine modules are started at all are decided here.
--
-- Like main.lua this carries no index: the engine chooses the name and the file
-- must sit at the root of the game directory. It holds settings and no logic.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

function love.conf(t)
  t.identity = "jurassic-maze"
  t.window.title = "jurassic-maze"
  t.window.width  = 1600
  t.window.height = 950
  t.window.resizable = true
  t.window.minwidth  = 900
  t.window.minheight = 600

  -- No multisampling. The maze is drawn as flat-shaded polygons that tile
  -- exactly, and antialiasing their shared edges produces a seam of blended
  -- colour along every one of them -- a faint bright grid over the whole maze,
  -- which is precisely what the outline mesh underneath is there to control.
  t.window.msaa = 0
  t.window.vsync = 1

  -- Started: graphics, window, input, timer, image. Everything else is off,
  -- because a module that is not started cannot be quietly depended on -- and
  -- the whole simulation has to keep running with none of them.
  t.modules.audio    = false
  t.modules.sound    = false
  t.modules.physics  = false
  t.modules.joystick = false
  t.modules.video    = false
  t.modules.touch    = false
end
