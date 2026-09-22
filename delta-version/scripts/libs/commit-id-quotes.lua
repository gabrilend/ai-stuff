#!/usr/bin/env luajit
-- commit-id-quotes.lua - finds commit ids quoted in text and rewrites them to
-- the ids those commits have after a history rewrite.
--
-- In plain terms: when a repository's history is rebuilt, every commit gets a
-- new name, and every place that wrote an old name down -- a transcript, an
-- issue file, a commit message -- now points at a commit that is no longer on
-- the trunk. This library reads text, finds the words that are commit names
-- (full or shortened), looks each one up in an old-to-new table, and writes the
-- new name in its place, keeping a shortened name exactly as short as it was
-- unless that length would now be ambiguous.
--
-- What counts as a quoted commit id, and why each rule exists:
--   * a run of 7 to 40 lowercase hex digits, with no letter, digit or
--     underscore touching either end -- so the middle of a longer word, a hash
--     of some other length (sha256 is 64) and "abcdef1x" are never touched;
--   * containing at least one letter a-f, or being at least 8 characters
--     long -- a 7-digit number like 2025091 is far more likely a count than a
--     commit, and rewriting one would silently corrupt a figure; at 8 digits
--     the chance that a random number is the prefix of one of this
--     repository's ~1700 commits is about 1 in 2.5 million, and every 8-digit
--     match found in the real trunk was a genuine commit reference;
--   * resolving to exactly one commit in the "before" universe -- a prefix
--     that could mean two commits is left alone and reported, because guessing
--     would put a wrong name into a record;
--   * that commit being a key in the map with a different value -- commits the
--     rewrite did not touch keep their names.
--
-- Used three ways, by graft-project-histories:
--   luajit commit-id-quotes.lua msg   <work-dir>   (filter-branch message filter)
--   luajit commit-id-quotes.lua tree  <work-dir>   (rewrite a tree's text files)
--   luajit commit-id-quotes.lua verify-messages <work-dir>
--   luajit commit-id-quotes.lua translate <map> <universe> <file>...
-- and as a library (require) by its tests.

local M = {}

-- {{{ local function read_lines
local function read_lines(path)
   local f = assert(io.open(path, "r"), "cannot open " .. path)
   local lines = {}
   for line in f:lines() do
      if line ~= "" then lines[#lines + 1] = line end
   end
   f:close()
   return lines
end
-- }}}

-- {{{ function M.new_universe
-- A universe is the set of commit ids a shortened id is checked against. It is
-- indexed by the first seven characters, because seven is the shortest id this
-- library ever reads, so every candidate for a token sits under one key.
function M.new_universe()
   return { by7 = {}, count = 0 }
end
-- }}}

-- {{{ function M.universe_add
function M.universe_add(universe, full_id)
   local key = full_id:sub(1, 7)
   local bucket = universe.by7[key]
   if not bucket then
      bucket = {}
      universe.by7[key] = bucket
   end
   bucket[#bucket + 1] = full_id
   universe.count = universe.count + 1
end
-- }}}

-- {{{ function M.universe_from_file
function M.universe_from_file(path, universe)
   universe = universe or M.new_universe()
   for _, id in ipairs(read_lines(path)) do M.universe_add(universe, id) end
   return universe
end
-- }}}

-- {{{ function M.matches
-- Every id in the universe that starts with the token. A full 40-character
-- token can only match itself; a shorter one may match several.
function M.matches(universe, token)
   local found = {}
   local bucket = universe.by7[token:sub(1, 7)]
   if bucket then
      for _, id in ipairs(bucket) do
         if id:sub(1, #token) == token then found[#found + 1] = id end
      end
   end
   return found
end
-- }}}

-- {{{ function M.map_from_file
-- The map file holds one "old new" pair per line.
function M.map_from_file(path)
   local map = {}
   for _, line in ipairs(read_lines(path)) do
      local old, new = line:match("^(%x+) (%x+)$")
      assert(old, "bad map line in " .. path .. ": " .. line)
      map[old] = new
   end
   return map
end
-- }}}

-- {{{ local function new_stats
local function new_stats()
   return { rewritten = 0, lengthened = 0, ambiguous = 0, decimal_skipped = 0,
            unmapped = 0, pending = 0, notes = {}, restore_len = {} }
end
-- }}}

-- {{{ function M.rewrite
-- Rewrites every quoted id in text. ctx fields:
--   before   universe the text was written against (resolves tokens)
--   after    universe the result will be read against (checks new tokens are
--            unambiguous; lengthened until they are). nil skips the check,
--            which the message filter needs because later commits do not
--            exist yet; the verify pass checks those afterwards.
--   lookup   function(old_full) -> new_full, or nil when the target has not
--            been rewritten yet (a message quoting a later commit)
-- Returns the new text and a stats table.
function M.rewrite(text, ctx, stats)
   stats = stats or new_stats()
   local out, last, pos = {}, 1, 1
   while true do
      local s, e = text:find("[0-9a-f]+", pos)
      if not s then break end
      pos = e + 1
      local len = e - s + 1
      local before_ch = s > 1 and text:sub(s - 1, s - 1) or ""
      local after_ch = text:sub(e + 1, e + 1)
      local bounded = not before_ch:match("[%w_]") and not after_ch:match("[%w_]")
      -- A run that touches another word character is part of a larger word,
      -- and a run outside 7..40 is not a sha1 commit id; both are left as is.
      if bounded and len >= 7 and len <= 40 then
         local token = text:sub(s, e)
         if not token:find("[a-f]") and len < 8 then
            -- Seven digits only: counted when it would have matched, so the
            -- report shows what this rule left alone, then skipped either way.
            if #M.matches(ctx.before, token) == 1 then
               stats.decimal_skipped = stats.decimal_skipped + 1
               stats.notes[#stats.notes + 1] = "all-digit left " .. token
            end
         else
            local found = M.matches(ctx.before, token)
            if #found > 1 then
               stats.ambiguous = stats.ambiguous + 1
               stats.notes[#stats.notes + 1] = "ambiguous " .. token
            elseif #found == 1 then
               local new_full = ctx.lookup(found[1])
               if new_full == nil then
                  stats.pending = stats.pending + 1
                  stats.notes[#stats.notes + 1] = "pending " .. token
               elseif new_full == found[1] then
                  stats.unmapped = stats.unmapped + 1
               else
                  -- out_len lets a reverse check shorten a lengthened id
                  -- back to the length it was first written at.
                  local new_len = ctx.out_len and ctx.out_len(token) or len
                  local replacement = new_full:sub(1, new_len)
                  -- A new short id is lengthened until it (a) would itself be
                  -- recognised by the rule above -- a 7-character all-digit
                  -- id would not, so it grows to 8 -- and (b) is unambiguous
                  -- in the world where old and new ids both exist (the old
                  -- ones stay reachable through the archive tag). (b) needs
                  -- the after universe, which the message filter does not
                  -- have; its results are checked afterwards.
                  while new_len < 40 and ((not replacement:find("[a-f]") and new_len < 8)
                        or (ctx.after and #M.matches(ctx.after, replacement) > 1)) do
                     new_len = new_len + 1
                     replacement = new_full:sub(1, new_len)
                  end
                  if new_len ~= len then
                     stats.lengthened = stats.lengthened + 1
                     stats.notes[#stats.notes + 1] =
                        "lengthened " .. token .. " -> " .. replacement
                     stats.restore_len[replacement] = len
                  end
                  out[#out + 1] = text:sub(last, s - 1)
                  out[#out + 1] = replacement
                  last = e + 1
                  stats.rewritten = stats.rewritten + 1
               end
            end
         end
      end
   end
   out[#out + 1] = text:sub(last)
   return table.concat(out), stats
end
-- }}}

-- {{{ function M.map_problems
-- A map is trustworthy when no two old ids share a new id and every value is a
-- full id. Returns a list of problems; empty means sound.
function M.map_problems(map)
   local problems, seen = {}, {}
   for old, new in pairs(map) do
      if #new ~= 40 or #old ~= 40 then
         problems[#problems + 1] = "not a full id: " .. old .. " " .. new
      end
      if seen[new] and old ~= new then
         problems[#problems + 1] = "two old ids share " .. new .. ": " .. seen[new] .. " " .. old
      end
      seen[new] = old
   end
   return problems
end
-- }}}

-- {{{ local function slurp
local function slurp(path)
   local f = assert(io.open(path, "rb"), "cannot open " .. path)
   local data = f:read("*a")
   f:close()
   return data
end
-- }}}

-- {{{ local function spit
local function spit(path, data)
   local f = assert(io.open(path, "wb"), "cannot write " .. path)
   f:write(data)
   f:close()
end
-- }}}

-- {{{ local function run
local function run(cmd)
   local p = assert(io.popen(cmd, "r"))
   local out = p:read("*a")
   local ok, _, code = p:close()
   if ok ~= true and ok ~= 0 then error("command failed (" .. tostring(code) .. "): " .. cmd) end
   return out
end
-- }}}

-- {{{ local function shell_quote
local function shell_quote(s)
   return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function load_filter_map
-- The filter-branch run appends "old new" for each commit as it is rebuilt, so
-- during the run this file holds exactly the commits already done.
local function load_filter_map(work)
   local map = {}
   local f = io.open(work .. "/filter.map", "r")
   if f then
      for line in f:lines() do
         local old, new = line:match("^(%x+) (%x+)$")
         if old then map[old] = new end
      end
      f:close()
   end
   return map
end
-- }}}

-- {{{ local function mode_msg
-- Message filter for filter-branch: stdin is one commit message, stdout the
-- rewritten message. A token is looked up through the folder map first (an
-- original project commit becomes its moved copy), then through the ids
-- filter-branch has produced so far.
local function mode_msg(work)
   local before = M.universe_from_file(work .. "/universe.before")
   local folder = M.map_from_file(work .. "/folder.map")
   local candidates = M.universe_from_file(work .. "/rewritten.candidates")
   local done = load_filter_map(work)
   local ctx = {
      before = before,
      lookup = function(old)
         -- A commit outside the rewrite (another branch, a retired worktree)
         -- keeps its name; only commits being rebuilt can be pending.
         if #M.matches(candidates, old) ~= 1 and not folder[old] then return old end
         local moved = folder[old] or old
         return done[moved]
      end,
   }
   local text = io.read("*a")
   local result, stats = M.rewrite(text, ctx)
   if stats.pending > 0 then
      local log = assert(io.open(work .. "/msg-pending.log", "a"))
      log:write((os.getenv("GIT_COMMIT") or "?") .. " " .. table.concat(stats.notes, "; ") .. "\n")
      log:close()
   end
   io.write(result)
end
-- }}}

-- {{{ local function split_log
-- Parses `git log --format=%H%x00%B%x01` output into id -> message.
local function split_log(raw)
   local messages = {}
   for id, body in raw:gmatch("(%x+)%z(.-)\1") do
      messages[id:gsub("^%s+", "")] = body
   end
   return messages
end
-- }}}

-- {{{ local function mode_scan_messages
-- Lists the commits whose message holds at least one token the rewrite would
-- change, so the message filter only runs where it has work to do.
local function mode_scan_messages(work)
   local before = M.universe_from_file(work .. "/universe.before")
   local folder = M.map_from_file(work .. "/folder.map")
   local candidates = M.universe_from_file(work .. "/rewritten.candidates")
   local raw = io.read("*a")
   for id, body in pairs(split_log(raw)) do
      local ctx = {
         before = before,
         lookup = function(old)
            -- Any old id that will be rewritten counts; its final value is
            -- not known yet, so a placeholder different from it is enough.
            if #M.matches(candidates, old) == 1 or folder[old] then return ("0"):rep(40) end
            return old
         end,
      }
      local _, stats = M.rewrite(body, ctx)
      if stats.rewritten > 0 or stats.pending > 0 then io.write(id, "\n") end
   end
end
-- }}}

-- {{{ local function mode_verify_messages
-- Every rewritten commit's message must equal its original's message with the
-- final map applied, and every id written into a message must be unambiguous
-- in the world where old and new ids both exist.
local function mode_verify_messages(work)
   local before = M.universe_from_file(work .. "/universe.before")
   local after = M.universe_from_file(work .. "/universe.after")
   local map = M.map_from_file(work .. "/commits.map")
   local git = "git --git-dir=" .. shell_quote(work .. "/repo.git")
   local old_msgs = split_log(run(git .. " log --format='%H%x00%B%x01' old-main --branches='old/*'"))
   local new_msgs = split_log(run(git .. " log --format='%H%x00%B%x01' main"))
   local failures, checked, changed = 0, 0, 0
   for old, body in pairs(old_msgs) do
      local new = map[old]
      if not new then
         io.stderr:write("verify-messages: no map entry for " .. old .. "\n")
         failures = failures + 1
      else
         local expect = M.rewrite(body, { before = before, lookup = function(o) return map[o] end })
         checked = checked + 1
         if new_msgs[new] ~= expect then
            io.stderr:write("verify-messages: message differs for " .. old .. " -> " .. new .. "\n")
            failures = failures + 1
         elseif expect ~= body then
            changed = changed + 1
            -- The ids now written in this message must resolve uniquely.
            local _, stats = M.rewrite(expect, {
               before = after, after = after, lookup = function(n) return n end })
            if stats.ambiguous > 0 then
               io.stderr:write("verify-messages: ambiguous new id in " .. new .. ": " ..
                  table.concat(stats.notes, "; ") .. "\n")
               failures = failures + 1
            end
         end
      end
   end
   io.write(string.format("messages checked %d, changed %d, failures %d\n", checked, changed, failures))
   if failures > 0 then os.exit(1) end
end
-- }}}

-- {{{ local function mode_tree
-- Rewrites the text files named in <work>/tree.candidates (lines of
-- "mode blob\tpath" from ls-tree) and writes update-index lines for the files
-- that changed to stdout. Each changed file is also checked in reverse: undoing
-- the rewrite with the reversed map must give back the original bytes, unless
-- a token had to be lengthened (those are listed).
local function mode_tree(work)
   local before = M.universe_from_file(work .. "/universe.before")
   local after = M.universe_from_file(work .. "/universe.after")
   local map = M.map_from_file(work .. "/commits.map")
   local reverse = {}
   for old, new in pairs(map) do reverse[new] = old end
   local git = "git --git-dir=" .. shell_quote(work .. "/repo.git")
   local total = new_stats()
   local files_changed, reverse_failures = 0, 0
   local report = assert(io.open(work .. "/tree-report.txt", "w"))
   local scratch = work .. "/blob.tmp"
   for line in io.lines(work .. "/tree.candidates") do
      local mode, blob, path = line:match("^(%d+) (%x+)\t(.+)$")
      local text = run(git .. " cat-file blob " .. blob)
      local stats = new_stats()
      local result = M.rewrite(text, { before = before, after = after,
         lookup = function(o) return map[o] end }, stats)
      if result ~= text then
         files_changed = files_changed + 1
         -- Undo with the reversed map, shortening lengthened ids back to the
         -- length they were written at: the original bytes must come back.
         local back = M.rewrite(result, { before = after,
            lookup = function(n) return reverse[n] or n end,
            out_len = function(t) return stats.restore_len[t] or #t end })
         if back ~= text then
            reverse_failures = reverse_failures + 1
            report:write("REVERSE MISMATCH ", path, "\n")
         end
         spit(scratch, result)
         local new_blob = run(git .. " hash-object -w " .. shell_quote(scratch)):gsub("%s+$", "")
         io.write(mode, " ", new_blob, "\t", path, "\n")
         report:write(string.format("%d\t%s\n", stats.rewritten, path))
      end
      for k, v in pairs(stats) do
         if type(v) == "number" then total[k] = total[k] + v end
      end
      for _, note in ipairs(stats.notes) do report:write("  ", path, ": ", note, "\n") end
   end
   os.remove(scratch)
   report:close()
   io.stderr:write(string.format(
      "tree: files changed %d, ids rewritten %d, lengthened %d, ambiguous left %d, " ..
      "all-digit left %d, reverse mismatches %d\n",
      files_changed, total.rewritten, total.lengthened, total.ambiguous,
      total.decimal_skipped, reverse_failures))
   if reverse_failures > 0 then os.exit(1) end
end
-- }}}

-- {{{ local function mode_translate
-- Rewrites quoted ids in working-tree files in place, for files written after
-- the swap or never committed. The universe is every commit the repository now
-- knows (old ones stay reachable through the archive tag).
local function mode_translate(map_path, universe_path, files)
   local map = M.map_from_file(map_path)
   local universe = M.universe_from_file(universe_path)
   for _, path in ipairs(files) do
      local text = slurp(path)
      local stats = new_stats()
      local result = M.rewrite(text, { before = universe, after = universe,
         lookup = function(o) return map[o] or o end }, stats)
      if result ~= text then spit(path, result) end
      io.write(string.format("%s: %d rewritten, %d lengthened, %d ambiguous left\n",
         path, stats.rewritten, stats.lengthened, stats.ambiguous))
   end
end
-- }}}

-- {{{ local function main
local dispatch = {
   msg = function(a) mode_msg(a[2]) end,
   ["scan-messages"] = function(a) mode_scan_messages(a[2]) end,
   ["verify-messages"] = function(a) mode_verify_messages(a[2]) end,
   tree = function(a) mode_tree(a[2]) end,
   translate = function(a)
      local files = {}
      for i = 4, #a do files[#files + 1] = a[i] end
      mode_translate(a[2], a[3], files)
   end,
}

local function main(a)
   local handler = dispatch[a[1] or ""]
   if not handler then
      io.stderr:write("usage: commit-id-quotes.lua msg|scan-messages|verify-messages|tree <work-dir>\n" ..
                      "       commit-id-quotes.lua translate <map> <universe> <file>...\n")
      os.exit(2)
   end
   handler(a)
end
-- }}}

-- Run as a program only when invoked directly; `require` gets the table.
if arg and arg[0] and arg[0]:match("commit%-id%-quotes%.lua$") and not package.loaded["commit-id-quotes"] then
   main(arg)
end

return M
