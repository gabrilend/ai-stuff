-- exact-text.lua
--
-- Literal text search and replacement with a declared count. Text is compared
-- character for character (no pattern language), so nothing in the searched
-- text ever needs escaping, and a replacement happens only when the text
-- occurs exactly as many times as the caller says it should. This is the rule
-- the upstream-patch skill's replace-exactly.lua enforces from the command
-- line; here it is a library, so a tool can apply many edits in one process
-- and write nothing until all of them have succeeded.
--
-- Used by scripts/transcript-patches. Load with dofile; returns a table.

local M = {}

-- {{{ function M.count
-- Number of non-overlapping occurrences of needle in text. An empty needle is
-- a caller error rather than "infinitely many", since it can never be a
-- meaningful anchor.
function M.count(text, needle)
   assert(type(needle) == "string" and needle ~= "", "exact-text: empty needle")
   local found, pos = 0, 1
   while true do
      local s, e = text:find(needle, pos, true)
      if not s then return found end
      found = found + 1
      pos = e + 1
   end
end
-- }}}

-- {{{ function M.replace_all
-- Replace every non-overlapping occurrence of old with new. Returns the new
-- text and how many replacements were made. Plain find, so '%' in new is not
-- special either (string.gsub's replacement string would treat it as one).
function M.replace_all(text, old, new)
   assert(type(old) == "string" and old ~= "", "exact-text: empty old text")
   local out, pos, made = {}, 1, 0
   while true do
      local s, e = text:find(old, pos, true)
      if not s then break end
      out[#out + 1] = text:sub(pos, s - 1)
      out[#out + 1] = new
      pos = e + 1
      made = made + 1
   end
   out[#out + 1] = text:sub(pos)
   return table.concat(out), made
end
-- }}}

-- {{{ function M.replace_exactly
-- Replace old with new only if old occurs exactly `expected` times. Returns
-- the new text on success, or nil plus the count actually found, so the
-- caller can report precisely why it refused.
function M.replace_exactly(text, old, new, expected)
   local found = M.count(text, old)
   if found ~= expected then
      return nil, found
   end
   local result = M.replace_all(text, old, new)
   return result, found
end
-- }}}

return M
