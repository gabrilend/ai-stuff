-- 000-run-all.lua
--
-- Runs every numbered test file in tests/, in order, under plain LuaJIT. A
-- test file returns a list of { name, function } cases; a case fails by
-- raising an error. Prints one line per case and a total, and exits 1 if
-- anything failed.
--
-- Usage: luajit tests/000-run-all.lua <project-dir>
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/sword-fighting-game"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/tests/?.lua;" .. package.path

local util = require("002-util")

-- The helpers every test file receives.
local T = { DIR = DIR }

-- {{{ function T.equal()
function T.equal(got, want, what)
	if got ~= want then
		error(string.format("%s: got %s, wanted %s", what or "value", tostring(got),
			tostring(want)), 2)
	end
end
-- }}}

-- {{{ function T.near()
function T.near(got, want, within, what)
	if math.abs(got - want) > within then
		error(string.format("%s: got %s, wanted %s within %s", what or "value",
			tostring(got), tostring(want), tostring(within)), 2)
	end
end
-- }}}

-- {{{ function T.truthy()
function T.truthy(v, what)
	if not v then error((what or "value") .. " should hold", 2) end
end
-- }}}

-- The function must stop with an error whose message contains `part`.
-- {{{ function T.raises()
function T.raises(fn, part)
	local ok, err = pcall(fn)
	if ok then error("expected an error mentioning " .. part, 2) end
	if not tostring(err):find(part, 1, true) then
		error("error should mention " .. part .. ", it said: " .. tostring(err), 2)
	end
end
-- }}}

-- A fresh configuration, catalogue and stream set, for tests that build
-- battles by hand.
-- {{{ function T.world()
function T.world(seed)
	local config = util.load_data_file(DIR .. "/src/001-config.def.lua")
	local catalogue = require("004-catalogue").load(DIR, {})
	return config, catalogue, require("003-random-streams").make_set(seed or 1)
end
-- }}}

local total, failed = 0, 0
for _, name in ipairs(util.list_files(DIR .. "/tests", ".lua")) do
	if name:match("^%d%d%d%-") and name ~= "000-run-all.lua" then
		local cases = dofile(DIR .. "/tests/" .. name)(T)
		for _, case in ipairs(cases) do
			total = total + 1
			local ok, err = pcall(case[2])
			-- a case passes by returning; any error is its failure message
			if ok then
				print(string.format("  ok    %s: %s", name, case[1]))
			else
				failed = failed + 1
				print(string.format("  FAIL  %s: %s\n        %s", name, case[1],
					tostring(err)))
			end
		end
	end
end
print(string.format("tests: %d cases, %d failed", total, failed))
os.exit(failed == 0 and 0 or 1)
