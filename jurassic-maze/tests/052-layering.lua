-- jurassic-maze — a simulation living inside an isometric maze of stacked stone
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 052-layering.lua
--
-- Nothing in the simulation may mention the engine or the global generator.
--
-- Two crude greps, and both of them have caught the exact mistake they are
-- looking for in projects shaped like this one. The failure they prevent does
-- not look like what it is: one simulation file asks the graphics library for
-- the elapsed time, and headless stops working three files away, as a crash
-- about something else entirely.

local M = {}

-- Which files are allowed to know a window exists. Everything else under src/ is
-- the simulation and must run under a bare luajit with no engine present.
--
-- A list rather than a directory, because the split is not "these folders" -- it
-- is a statement about which layer each file belongs to, and stating it here
-- means adding a file to the viewer side is a deliberate edit to this list
-- rather than something that happens by putting a file somewhere.
local VIEWER_FILES = {
  ["042-the-renderer.lua"]        = true,
  ["044-the-director.lua"]        = true,
  ["045-the-viewer.lua"]          = true,
  ["046-the-terminal-viewer.lua"] = true,
  -- The three front ends added in phases nine and ten. Each is a thing a person
  -- looks at, and each is on this list by a deliberate edit rather than by
  -- sitting in a directory -- which is the whole reason the list is a list.
  ["079-the-client.lua"]          = true,
  ["080-the-front-desk.lua"]      = true,
  ["082-the-tracing-table.lua"]   = true,
  -- The exporter draws a canvas, which is the one thing it does that a headless
  -- run cannot, and it is the reason a scene has to be made with a window open.
  ["078-the-exporter.lua"]        = true,
}

-- {{{ local function read_file(path)
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end
-- }}}

-- {{{ local function list_lua(dir)
-- Directory listing without a shell pipeline, so this works the same whether it
-- is run from the test runner or from anywhere else.
local function list_lua(dir)
  local names = {}
  local pipe = io.popen("ls " .. dir)
  if not pipe then return names end
  for name in pipe:lines() do
    if name:match("%.lua$") then names[#names + 1] = name end
  end
  pipe:close()
  return names
end
-- }}}

-- {{{ function M.run(root, t)
function M.run(root, t)
  local checked = 0

  for _, name in ipairs(list_lua(root .. "/src")) do
    local text = read_file(root .. "/src/" .. name)
    if text then
      checked = checked + 1

      -- math.random is banned everywhere, viewer included. A viewer that drew
      -- from it would still be non-deterministic, and the point of the named
      -- streams is that there is exactly one way to get a random number.
      t.falsy(text:find("math%.random"),
              name .. " must not call math.random -- draw from a named stream")

      if not VIEWER_FILES[name] then
        -- The renderer's own name appears in the viewer's require list, which is
        -- fine; what is banned is the engine.
        t.falsy(text:find("love%."),
                name .. " is simulation and must not mention the engine")
        t.falsy(text:find("require%(\"love"),
                name .. " is simulation and must not require the engine")
      end
    end
  end

  t.truthy(checked > 10, "the layering check actually found the source files")

  -- The camera's stream exists and the simulation never reads it. A viewer that
  -- drew from a simulation stream would make the world depend on whether anybody
  -- was watching, and two runs of one seed would diverge on a keypress.
  local Streams = dofile(root .. "/src/029-random-streams.lua")
  local has_camera = false
  for _, n in ipairs(Streams.names()) do
    if n == "camera" then has_camera = true end
  end
  t.truthy(has_camera, "there is a stream named camera")

  for _, name in ipairs(list_lua(root .. "/src")) do
    if not VIEWER_FILES[name] then
      local text = read_file(root .. "/src/" .. name)
      if text then
        t.falsy(text:find("streams%.camera") or text:find("%.camera:next"),
                name .. " is simulation and must not draw from the camera stream")
      end
    end
  end
end
-- }}}

return M
