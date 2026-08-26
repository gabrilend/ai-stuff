-- conf.lua
--
-- LOVE reads this before it opens anything, so the window's shape and the
-- modules the engine bothers to start are decided here.
--
-- Like main.lua, this carries no index: the engine chooses the name and the file
-- must be at the game directory's root. It holds settings and no logic.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

function love.conf(t)
  t.identity = "hero-less-moba"
  t.window.title = "hero-less-moba -- nobody remembers why"
  t.window.width = 1600
  t.window.height = 950
  t.window.resizable = true
  t.window.minwidth = 1100
  t.window.minheight = 700
  -- Multisampling, because the map is drawn almost entirely out of lines and
  -- circles and the diagonal lanes alias badly without it.
  t.window.msaa = 4
  t.window.vsync = 1

  -- Started: graphics, window, input, timer, and the image module the renderer
  -- generates its disc with. Everything else is off, because a module that is not
  -- started cannot be quietly depended on.
  t.modules.audio = false
  t.modules.sound = false
  t.modules.physics = false
  t.modules.joystick = false
  t.modules.video = false
  t.modules.touch = false
end
