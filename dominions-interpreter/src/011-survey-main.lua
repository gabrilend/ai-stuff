-- 011-survey-main.lua
--
-- The entry point the survey script runs.
--
-- It exists as a real file rather than a string passed to the interpreter
-- because arguments are the point: luajit's -e treats the first thing after
-- the option terminator as a script name, so a command line built that way
-- silently loses its first argument. A file takes arguments the ordinary way,
-- and the ordinary way is the one that will still be right in a year.
--
-- The project directory arrives in the environment, set by the shell script,
-- which is where the one hard-coded path in the whole program lives.

local project_directory = os.getenv("DOMINIONS_INTERPRETER_DIR")
if not project_directory or project_directory == "" then
   io.stderr:write(
      "DOMINIONS_INTERPRETER_DIR is not set; run this through ./survey\n")
   os.exit(1)
end

package.path = project_directory .. "/src/?.lua;" .. package.path

local command = require("010-survey-command")

local arguments = {}
for index = 1, #arg do
   arguments[index] = arg[index]
end

os.exit(command.run(project_directory, arguments))
