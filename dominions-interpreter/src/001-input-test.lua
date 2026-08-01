-- 001-input-test.lua
--
-- Proves the input gate. The interesting cases are the refusals: a missing
-- path must be named, and a missing nation must come back as a question
-- rather than a choice.

local input = require("000-input")

local test = {}

-- {{{ local function write_temporary()
local function write_temporary(path, contents)
   local handle = assert(io.open(path, "w"))
   handle:write(contents)
   handle:close()
end
-- }}}

-- {{{ function test.run()
function test.run(check, home)
   local scratch = "/tmp/dominions-interpreter"
   os.execute('mkdir -p "' .. scratch .. '"')

   -- The key-value parser.
   local settings_path = scratch .. "/test-pairs"
   write_temporary(settings_path, table.concat({
      "# a comment",
      "",
      "one   first value",
      "two   /a/path with spaces/in it",
      "one   overridden",
   }, "\n"))

   local settings, reason = input.read_pairs(settings_path)
   check("a settings file parses", settings ~= nil)
   check("a value keeps its spaces",
      settings and settings["two"] == "/a/path with spaces/in it")
   check("a later line overrides an earlier one",
      settings and settings["one"] == "overridden")

   write_temporary(scratch .. "/test-bad", "this-line-has-no-value\n")
   settings, reason = input.read_pairs(scratch .. "/test-bad")
   check("a malformed line is refused with its line number",
      settings == nil and reason ~= nil and string.find(reason, "line 1") ~= nil)

   settings, reason = input.read_pairs(scratch .. "/nothing-here")
   check("a missing settings file is a reason, not an empty table",
      settings == nil and reason ~= nil)

   -- The door roster. Parsed only; nothing is contacted.
   input.configure(scratch)
   os.execute('mkdir -p "' .. scratch .. '/input"')
   write_temporary(scratch .. "/input/cluster", table.concat({
      "# three little machines",
      "cluster-one   192.168.1.41 8080 both",
      "cluster-two   192.168.1.42 8080 completion",
      "cluster-three 192.168.1.43 8080",
   }, "\n"))

   local doors, trouble = input.cluster()
   check("the roster parses", doors ~= nil and #doors == 3)
   check("a door keeps its port as a number",
      doors and doors[1].port == 8080)
   check("a door with no stated kind answers both",
      doors and doors[3].kind == "both")

   write_temporary(scratch .. "/input/cluster",
      "cluster-one 192.168.1.41 8080 oracle\n")
   doors, trouble = input.cluster()
   check("an unknown door kind is refused by name",
      doors == nil and trouble ~= nil and string.find(trouble, "oracle") ~= nil)

   write_temporary(scratch .. "/input/cluster", "# nothing but comments\n")
   doors, trouble = input.cluster()
   check("a roster naming no doors is refused", doors == nil)

   if not home then
      return
   end

   -- Against the real collection: a savegame folder holding more than one turn
   -- file must come back as candidates, never as a choice.
   write_temporary(scratch .. "/input/game", table.concat({
      "dominions-home    " .. home,
      "dominions-binary  " .. home .. "/dom6manual.txt",
      "game              december-woes",
   }, "\n"))

   local game, why = input.game()
   check("a real savegame resolves", game ~= nil, why)
   check("no nation was chosen for us", game and game.nation == nil)
   check("the nations found are listed",
      game and #game.nations >= 1)

   write_temporary(scratch .. "/input/game", table.concat({
      "dominions-home    " .. home,
      "dominions-binary  " .. home .. "/dom6manual.txt",
      "game              december-woes",
      "nation            no_such_nation",
   }, "\n"))
   game, why = input.game()
   check("a nation with no turn file is refused, and the real ones listed",
      game == nil and why ~= nil and string.find(why, "found:") ~= nil)

   write_temporary(scratch .. "/input/game", table.concat({
      "dominions-home    /no/such/place",
      "dominions-binary  /no/such/binary",
      "game              nowhere",
   }, "\n"))
   game, why = input.game()
   check("a path that does not exist is refused with its key named",
      game == nil and why ~= nil
      and string.find(why, "dominions%-home") ~= nil)
end
-- }}}

return test
