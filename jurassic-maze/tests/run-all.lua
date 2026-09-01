-- run-all.lua
--
-- The test harness. Finds every numbered test beside it, runs each one's `run`
-- function against a tiny assertion table, and prints what failed.
--
-- Unnumbered because it is not part of the reading order: it is the thing that
-- reads the others. Every file it loads is numbered and carries the licence
-- notice; this one is scaffolding.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local root = arg[1]
if not root then
  print("run-all.lua needs the project root as its first argument")
  os.exit(1)
end

local filters = {}
for i = 2, #arg do filters[#filters + 1] = arg[i] end

-- {{{ local function wanted(name)
local function wanted(name)
  if #filters == 0 then return true end
  for _, f in ipairs(filters) do
    if name:find(f, 1, true) then return true end
  end
  return false
end
-- }}}

local passed, failed = 0, 0
local failures = {}
local current = "?"

-- The assertion table. Deliberately small: four checks, each of which prints the
-- values it compared when it fails. A test framework here would be more code
-- than the tests.
local t = {}

-- {{{ function t.equal(got, want, what)
function t.equal(got, want, what)
  if got == want then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = string.format("%s: %s\n    got %s, wanted %s",
      current, what, tostring(got), tostring(want))
  end
end
-- }}}

-- {{{ function t.truthy(value, what)
function t.truthy(value, what)
  if value then passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = string.format("%s: %s\n    was %s", current, what,
                                            tostring(value))
  end
end
-- }}}

-- {{{ function t.falsy(value, what)
function t.falsy(value, what)
  if not value then passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = string.format("%s: %s\n    was %s", current, what,
                                            tostring(value))
  end
end
-- }}}

-- {{{ function t.raises(fn, what)
-- Checks that something refuses rather than carrying on. Half the design here is
-- about failing loudly, and a refusal nobody tested is a refusal that has never
-- run.
function t.raises(fn, what)
  local ok = pcall(fn)
  if ok then
    failed = failed + 1
    failures[#failures + 1] = string.format("%s: %s\n    it did not raise",
                                            current, what)
  else
    passed = passed + 1
  end
end
-- }}}

-- {{{ function t.fail(what)
function t.fail(what)
  failed = failed + 1
  failures[#failures + 1] = current .. ": " .. what
end
-- }}}

local names = {}
local pipe = io.popen("ls " .. root .. "/tests")
for name in pipe:lines() do
  if name:match("^%d%d%d%-.*%.lua$") then names[#names + 1] = name end
end
pipe:close()
table.sort(names)

local started = os.clock()

for _, name in ipairs(names) do
  if wanted(name) then
    current = name
    local before_failed = failed
    local module = dofile(root .. "/tests/" .. name)
    local ok, err = pcall(module.run, root, t)
    if not ok then
      failed = failed + 1
      failures[#failures + 1] = name .. ": the test itself raised\n    " .. tostring(err)
    end
    local mark = (failed == before_failed) and "ok  " or "FAIL"
    print(string.format("%s  %s", mark, name))
  end
end

print("")
if failed == 0 then
  print(string.format("%d checks passed in %.2fs", passed, os.clock() - started))
  os.exit(0)
else
  for _, f in ipairs(failures) do print(f) end
  print("")
  print(string.format("%d passed, %d FAILED in %.2fs", passed, failed,
                      os.clock() - started))
  os.exit(1)
end
