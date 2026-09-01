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
-- {{{ function M.decide_the_seed()
-- Which match this is going to be, and where that decision gets written down.
--
-- Three sources, in order, and the order is what makes the whole thing usable:
--
--   1. **`HLM_SEED` in the environment.** A seed named on the command line. Nothing
--      overrides it and nothing is logged, because a seed somebody typed is a seed
--      they already have.
--   2. **`input/seed` holding the word `random`.** Draw one, and **write it down.**
--   3. **`input/seed` holding a number.** Use it. This is what the file has always
--      meant and it still means it.
--
-- **Why drawing one had to become possible.** Every match, every scene and every
-- screenshot came out of the same seed, so everything anybody looked at was the same
-- match. That is exactly right when comparing two versions of a rule and exactly wrong
-- the rest of the time: a bug that only happens in one arrangement of bodies is
-- invisible if there is only ever one arrangement, and worse, a rule that is broken in
-- general looks fine because the one match everybody watched happened not to hit it.
--
-- **Why a drawn seed is written down.** A seed nobody recorded is a match nobody can
-- get back, and the interesting ones are exactly the ones you did not expect and
-- therefore were not recording. The log is append-only and lives in the RAM tier with
-- the other ephemera -- it is a notebook, not an archive. When something worth keeping
-- happens, the seed is in there and it goes into `input/seed` by hand.
function M.decide_the_seed()
  local given = os.getenv("HLM_SEED")
  if given ~= nil and given ~= "" then
    local number = tonumber(given)
    if number == nil then
      error("HLM_SEED was set to '" .. given .. "', which is not a number")
    end
    return math.floor(number)
  end

  local written = read_input_file("seed")
  local number = tonumber(written)
  if number ~= nil then
    return math.floor(number)
  end

  -- Anything other than a number and the word `random` is a typo rather than an
  -- instruction, and a typo that silently played a random match would be the worst of
  -- both: a match nobody chose, from a file that looks like it chose one.
  if written:match("^%s*random%s*$") == nil then
    error("input/seed says '" .. written ..
          "', which is neither a number nor the word 'random'")
  end

  -- The clock and the process together. The clock alone gives two matches started in
  -- the same second the same seed, which is precisely what happens when a script runs
  -- several at once -- and "several at once, all identical" is the failure this is
  -- being built to end rather than a new way to have it.
  math.randomseed(os.time() + (tonumber(tostring({}):match("0x(%x+)"), 16) or 0))
  math.random()
  local drawn = math.random(1, 2147483647)
  M.write_down_the_seed(drawn)
  return drawn
end
-- }}}

-- {{{ function M.write_down_the_seed()
-- Appends a drawn seed to the notebook, and never rewrites a line of it.
--
-- Append-only on purpose: the value of the file is that a seed cannot be lost by
-- something later overwriting it, and a log that is rewritten is a log that can lose
-- the one line somebody needed.
--
-- Failure to write is **reported and not fatal.** The seed is already decided and the
-- match is already going to be played; refusing to play it because a notebook could
-- not be opened would be the tail wagging the dog. But it says so, loudly, because a
-- silent failure here is a match you will want back and cannot have.
function M.write_down_the_seed(seed)
  local directory = "/dev/shm/hero-less-moba"
  os.execute("mkdir -p " .. directory)
  local handle = io.open(directory .. "/seeds.log", "a")
  if handle == nil then
    io.stderr:write("could not write the seed notebook at " .. directory ..
                    "/seeds.log -- this match's seed is " .. seed ..
                    " and nothing else is going to remember it\n")
    return
  end
  handle:write(string.format("%s  seed %d\n", os.date("%Y-%m-%d %H:%M:%S"), seed))
  handle:close()
  io.stderr:write("seed " .. seed .. " (drawn; noted in " ..
                  directory .. "/seeds.log)\n")
end
-- }}}

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
  local seed = M.decide_the_seed()

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

  -- Which teams a bot plays. Optional, and absent means nobody -- the one input
  -- file that is allowed to be missing, because "nobody is a bot" is a real answer
  -- rather than an unmade decision.
  local bots = {}
  local handle = io.open(M.root .. "/input/bots", "r")
  if handle ~= nil then
    handle:close()
    for _, line in ipairs(read_input_list("bots")) do
      local number = tonumber(line)
      if number ~= nil then
        bots[#bots + 1] = number
      end
    end
  end

  return {
    root       = M.root,
    bots       = bots,
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
