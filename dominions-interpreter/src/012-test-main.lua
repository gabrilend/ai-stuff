-- 012-test-main.lua
--
-- Runs every test module and reports in sentences.
--
-- Tests are cheap and there should be many of them, so the runner has to make
-- adding one costless: a module exposing run(check, home) is picked up by
-- being listed here, and nothing else is required of it.
--
-- The real savegame collection is passed in when it is available and the tests
-- skip the parts that need it when it is not. That keeps the suite runnable on
-- a machine without Dominions installed while making it far stronger on one
-- with it - which is the machine it matters on.

local project_directory = os.getenv("DOMINIONS_INTERPRETER_DIR")
if not project_directory or project_directory == "" then
   io.stderr:write("DOMINIONS_INTERPRETER_DIR is not set; run this through ./tests\n")
   os.exit(1)
end

package.path = project_directory .. "/src/?.lua;" .. package.path

local home = arg[1]
if home == "" then
   home = nil
end

local modules = {
   { name = "the input gate", module = "001-input-test" },
   { name = "the narrator", module = "003-narrator-test" },
   { name = "the disguise", module = "005-obfuscation-test" },
   { name = "the savegame reader", module = "007-savefile-test" },
}

local passed, failed = 0, 0
local failures = {}

-- {{{ local function check()
-- One assertion. Passes are counted and not printed - a suite that prints a
-- line per success buries the one line that matters.
local function check(what, condition, detail)
   if condition then
      passed = passed + 1
   else
      failed = failed + 1
      failures[#failures + 1] = what .. (detail and (" - " .. tostring(detail)) or "")
   end
end
-- }}}

print("running the tests" .. (home and (" against " .. home) or
   " without a Dominions folder, so the parts that need one are skipped"))
print("")

for index = 1, #modules do
   local entry = modules[index]
   local before = failed
   local ok, trouble = pcall(function()
      require(entry.module).run(check, home)
   end)
   if not ok then
      failed = failed + 1
      failures[#failures + 1] = entry.name .. " stopped: " .. tostring(trouble)
   end
   print(string.format("%s: %s",
      entry.name,
      failed == before and "everything held" or
         string.format("%d checks did not hold", failed - before)))
end

print("")
if failed == 0 then
   print(string.format("%d checks, all of them held", passed))
   os.exit(0)
end

print(string.format("%d checks, %d did not hold:", passed + failed, failed))
for index = 1, #failures do
   print("   " .. failures[index])
end
os.exit(1)
