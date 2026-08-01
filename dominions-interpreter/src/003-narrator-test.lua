-- 003-narrator-test.lua
--
-- Proves the narrator. The case worth having is the last one: a worry without
-- a reason is a programming error caught at the call site, rather than an
-- empty string written into a file somebody reads later and learns nothing
-- from.

local narrator = require("002-narrator")

local test = {}

-- {{{ function test.run()
function test.run(check)
   local scratch = "/tmp/dominions-interpreter/shared-memory"
   os.execute('mkdir -p /dev/shm/dominions-interpreter')
   os.execute('mkdir -p /tmp/dominions-interpreter')
   os.execute('ln -sfn /dev/shm/dominions-interpreter '
      .. '/tmp/dominions-interpreter/shared-memory')

   local path = narrator.open(scratch, "test")
   narrator.quiet(true)
   check("the log opens in the RAM tier", path ~= nil)

   narrator.say("a sentence a person could read")
   narrator.worry("something was substituted", "the field could not be read")

   local handle = io.open(path, "r")
   check("the log can be opened for reading", handle ~= nil)
   local contents = handle and handle:read("*a") or ""
   if handle then handle:close() end

   check("what was said is in the log",
      string.find(contents, "a sentence a person could read", 1, true) ~= nil)
   check("a worry carries its reason",
      string.find(contents, "the field could not be read", 1, true) ~= nil)

   -- Lines are flushed as they are written, so a run can be followed with tail
   -- while it happens. The read above already proves it: the log is still
   -- open, and the text was there anyway.
   check("lines are flushed rather than buffered until close",
      string.find(contents, "something was substituted", 1, true) ~= nil)

   local refused = pcall(function()
      narrator.worry("a worry with no reason")
   end)
   check("a worry without a reason is refused at the call site",
      refused == false)

   local elapsed = narrator.timer()
   check("the timer returns seconds", type(elapsed()) == "number")

   narrator.close()
end
-- }}}

return test
