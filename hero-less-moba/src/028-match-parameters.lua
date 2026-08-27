-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 028-match-parameters.lua
--
-- The first thing any program in this project does is read the input/ directory,
-- and this is the file that does it.
--
-- A match is a small number of decisions made before it starts. They live as one
-- file per decision rather than as a wall of command-line flags because they
-- should be readable, diffable, and copyable -- anything you would pin down and
-- hand to somebody else so they can run the same match belongs there. A replay
-- header is very nearly the same set of fields.
--
-- Everything here refuses rather than guesses. A missing input file is named and
-- the program stops. Substituting a default for a match parameter would mean two
-- people running "the same" match and getting different games, and finding that
-- out three systems downstream.

local M = {}

-- The project root, discovered from this file's own location rather than
-- hard-coded, so the simulation runs the same whether it was started by the
-- headless runner, by LOVE, or by a test sitting somewhere else entirely.
-- {{{ local function project_root()
local function project_root()
  -- debug.getinfo on this very function yields "<root>/src/028-match-parameters.lua".
  -- Two directories up from that is the root. This is the one place in the
  -- project that does path arithmetic; everything else is handed the answer.
  local source = debug.getinfo(1, "S").source
  local path = source:match("^@(.*)$")
  if path == nil then
    error("match-parameters cannot locate itself: debug source was " .. tostring(source))
  end
  -- The prefix before "src/" is the root. When this file was loaded by a
  -- relative path from the root itself the prefix is empty, which is the current
  -- directory rather than the filesystem root -- so it is named "." explicitly
  -- instead of being left as an empty string that would silently build "/input".
  local root = path:match("^(.-)/?src/[^/]+$")
  if root == nil then
    error("match-parameters is not in a src/ directory: " .. path)
  end
  if root == "" then
    root = "."
  end
  return root
end
-- }}}

M.root = project_root()

-- {{{ local function read_input_file()
-- Reads one file out of input/ and returns its first line that is neither blank
-- nor a comment. The comment convention is a leading '#', so that every input
-- file can explain itself to the next person who opens it.
local function read_input_file(name)
  local path = M.root .. "/input/" .. name
  local handle = io.open(path, "r")
  if handle == nil then
    error("no input file at " .. path ..
          " -- the match cannot start without knowing '" .. name .. "'")
  end

  local value = 0
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    -- A blank line or a comment is skipped; the first line with content is the
    -- value, and everything after it is ignored so a file can carry notes below
    -- its answer.
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      value = trimmed
      break
    end
  end
  handle:close()

  if value == 0 then
    error("input file " .. path .. " has no value in it, only comments")
  end
  return value
end
-- }}}

-- {{{ local function read_input_list()
-- The same, but returns every content line rather than the first. Used by the
-- catalogue list, which is inherently plural.
local function read_input_list(name)
  local path = M.root .. "/input/" .. name
  local handle = io.open(path, "r")
  if handle == nil then
    error("no input file at " .. path ..
          " -- the match cannot start without knowing '" .. name .. "'")
  end

  local list = {}
  for line in handle:lines() do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      list[#list + 1] = trimmed
    end
  end
  handle:close()

  if #list == 0 then
    error("input file " .. path .. " lists nothing")
  end
  return list
end
-- }}}

-- {{{ function M.load()
-- Reads every input file and every catalogue it names, and returns the one
-- parameter record the rest of the program is built from.
--
-- Returns a table with:
--   root         string   the project root, absolute
--   seed         integer  the match seed
--   team_size    integer  players per side, and therefore lanes
--   lane_count   integer  the same number, named for what it decides
--   shape        table    from assets/024-map-shape.lua
--   unit         table    from assets/025-unit-table.lua
--   structure    table    from assets/026-structure-table.lua
--   upgrade      table    from assets/027-upgrade-table.lua
--   commander    table    from assets/053-commander-table.lua
function M.load()
  local seed = tonumber(read_input_file("seed"))
  if seed == nil then
    error("input/seed is not a number")
  end

  local team_size = tonumber(read_input_file("team-size"))
  if team_size == nil then
    error("input/team-size is not a number")
  end

  -- The catalogue list is read as paths and loaded in order. Loading them by
  -- name from a file rather than requiring them by hand is what lets a balance
  -- experiment swap one table without touching a line of code.
  local loaded = {}
  for _, relative in ipairs(read_input_list("catalogues")) do
    local path = M.root .. "/" .. relative
    local chunk, message = loadfile(path)
    if chunk == nil then
      error("catalogue " .. path .. " will not load: " .. tostring(message))
    end
    -- Keyed by the file's descriptive name -- "map-shape", "unit-table" -- with
    -- the index and extension stripped, so the parameter record reads as prose
    -- rather than as a list of file numbers.
    local key = relative:match("/%d+%-([%w%-]+)%.lua$")
    if key == nil then
      error("catalogue path is not an indexed lua file: " .. relative)
    end
    loaded[key] = chunk()
  end

  local required = {"map-shape", "unit-table", "structure-table", "upgrade-table",
                    "commander-table", "boon-table"}
  for _, key in ipairs(required) do
    if loaded[key] == nil then
      error("input/catalogues never named a " .. key .. " -- the match cannot start")
    end
  end

  return {
    root       = M.root,
    seed       = seed,
    team_size  = team_size,
    lane_count = team_size,
    shape      = loaded["map-shape"].parameters,
    unit       = loaded["unit-table"],
    structure  = loaded["structure-table"],
    upgrade    = loaded["upgrade-table"],
    commander  = loaded["commander-table"],
    boon       = loaded["boon-table"],
  }
end
-- }}}

return M
