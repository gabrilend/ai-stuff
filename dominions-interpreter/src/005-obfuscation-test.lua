-- 005-obfuscation-test.lua
--
-- Proves the disguise module against the real collection rather than against a
-- fixture somebody wrote by hand. A parser that agrees with a hundred real
-- files spanning eighteen game versions has been tested harder than any
-- fixture could test it.

local obfuscation = require("004-obfuscation")

local test = {}

-- {{{ local function read()
local function read(path, limit)
   local handle = io.open(path, "rb")
   if not handle then
      return nil
   end
   local bytes = handle:read(limit or "*a")
   handle:close()
   return bytes
end
-- }}}

-- {{{ function test.run()
function test.run(check, home)
   -- The constant, asserted rather than trusted to work by accident. If this
   -- ever fails, a game update changed the scheme and the rest of the project
   -- is about to read noise.
   check("the mask is the one that was established",
      obfuscation.mask() == 0x4F)

   -- Revealing is its own inverse, which is why there is no hide function.
   local sample = "Peisandros holds the pass"
   check("revealing twice returns the original",
      obfuscation.reveal(obfuscation.reveal(sample)) == sample)

   check("a zero byte reveals to the separator",
      obfuscation.reveal(string.char(0)) == string.char(0x4F))

   -- The ambiguity at the centre of this format, asserted so nobody has to
   -- rediscover it: padding and the capital letter O are the same byte. A raw
   -- zero reveals to O, and the letter O in a name is stored as a raw zero, so
   -- the two are indistinguishable in the file and every name reader has to
   -- decide which it is looking at.
   check("a raw zero reveals to the letter O",
      obfuscation.reveal(string.char(0)) == "O")
   check("the letter O is stored as a raw zero",
      obfuscation.reveal("O") == string.char(0))

   check("printable rejects an empty chunk",
      obfuscation.is_printable("") == false)
   check("printable rejects binary",
      obfuscation.is_printable("ab\001cd") == false)
   check("printable accepts a name with a space and an apostrophe",
      obfuscation.is_printable("Two Spruce Forest") == true
      and obfuscation.is_printable("O'ngai") == true)

   if not home then
      return
   end

   -- Against real files. The game name is the first string after the header
   -- and must equal the folder it was found in - this is the standing check on
   -- the padding rule, and the reason it is a test rather than a comment.
   local checked = 0
   local listing = io.popen('ls -1 "' .. home .. '/savedgames" 2>/dev/null')
   if listing then
      for game in listing:lines() do
         local world = home .. "/savedgames/" .. game .. "/ftherlnd"
         local bytes = read(world, 4096)
         if bytes then
            local strings = obfuscation.strings(bytes, 16, 2)
            check("the world state of " .. game .. " names itself",
               strings[1] ~= nil and strings[1].text == game)
            check("the game name of " .. game .. " comes back with an offset",
               strings[1] ~= nil and type(strings[1].offset) == "number"
               and strings[1].offset > 0)
            checked = checked + 1
         end
      end
      listing:close()
   end

   check("more than fifty started savegames were read",
      checked > 50)
end
-- }}}

return test
