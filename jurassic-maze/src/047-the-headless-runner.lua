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

-- 047-the-headless-runner.lua
--
-- The whole thing with no window and no engine.
--
-- This is the one that makes the project testable. A simulation observed only by
-- a person watching it has no tests, because "did that look right" is not an
-- assertion. Headless turns every property of a run into a number.

local M = {}

-- {{{ local function require_local(root, name)
local function require_local(root, name)
  return dofile(root .. "/src/" .. name .. ".lua")
end
-- }}}

-- {{{ function M.parse(argv)
-- The command line, as a table. Unknown flags are refused rather than ignored:
-- a misspelled flag that is silently dropped produces a run with the defaults
-- while somebody believes they changed something.
function M.parse(argv)
  local opts = { seed = 1, scene = "balls", ticks = 3600, overrides = {} }
  local numbers = {
    ["--seed"] = "seed", ["--width"] = "width", ["--depth"] = "depth",
    ["--layers"] = "layers", ["--terraces"] = "terrace_count",
    ["--capacity"] = "capacity",
  }

  local i = 1
  while i <= #argv do
    local a = argv[i]
    if numbers[a] then
      local field = numbers[a]
      local value = tonumber(argv[i + 1])
      if not value then error(a .. " needs a number") end
      if field == "seed" then opts.seed = value end
      opts.overrides[field] = value
      i = i + 2
    elseif a == "--scene" then
      opts.scene = argv[i + 1]; i = i + 2
    elseif a == "--ticks" then
      opts.ticks = tonumber(argv[i + 1]); i = i + 2
    elseif a == "--describe" then
      opts.describe_only = true; i = i + 1
    elseif a == "--quiet" then
      opts.quiet = true; i = i + 1
    elseif a == "--row" then
      opts.row_only = true; i = i + 1
    elseif a == "--headless" or a == "--terminal" then
      i = i + 1                        -- consumed by run-maze, not by us
    else
      error("unknown option '" .. tostring(a) .. "'")
    end
  end

  opts.overrides.seed = opts.seed
  return opts
end
-- }}}

-- {{{ function M.run(root, argv)
function M.run(root, argv)
  local Params = require_local(root, "028-maze-parameters")
  local Tick   = require_local(root, "039-the-tick")
  local Report = require_local(root, "048-the-report")

  local opts = M.parse(argv)
  local world = Tick.new_world(root, Params.with(opts.overrides), opts.scene)

  if opts.describe_only then
    local Validator = require_local(root, "032-the-validator")
    print(Validator.describe(world.report))
    return world.report
  end

  -- Per-pass timing, which is where the time goes without a profiler.
  local pass_time = {}
  for _ = 1, opts.ticks do
    Tick.tick(world, pass_time)
  end

  local r = Report.gather(world)

  if opts.row_only then
    print(Report.as_table_row(r))
  elseif not opts.quiet then
    print(Report.describe(r, pass_time))
  end

  -- The last thing a run does is write goodbye.
  Report.say_goodbye(root, r)
  return r
end
-- }}}

-- {{{ if invoked directly
-- This file is both a module and a program.
--
-- The alternative was passing the whole command line to `luajit -e`, and there
-- is no spelling of that which works: without `--`, luajit reads the run's own
-- `--seed` as an option meant for itself and prints its usage; with `--`, it
-- stops handling options and treats the next argument as a script to open.
-- Being a script directly sidesteps the argument handling entirely.
--
-- `arg[0]` is the file luajit was actually asked to run, so this fires only when
-- that file is this one -- never when the viewer or a test loads the module.
if arg and arg[0] and arg[0]:find("047%-the%-headless%-runner") then
  local root = arg[1]
  if not root then
    print("047-the-headless-runner.lua needs the project root as its first argument")
    os.exit(1)
  end
  local argv = {}
  for i = 2, #arg do argv[#argv + 1] = arg[i] end
  M.run(root, argv)
end
-- }}}

return M
