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

-- 057-the-relinker.lua
--
-- Repairs every relative link after an issue moves between directories.
--
-- An issue lives in issues/ while it is open and in issues/completed/ once it is
-- done, and that move breaks links in both directions and in silence. A link
-- inside the issue that said `../docs/002-the-stone.md` now means
-- `issues/docs/002-the-stone.md`, which is nowhere. A link to the issue from the
-- roadmap points at a gap. Nothing warns; the links simply stop working, and
-- stay broken until somebody clicks one.
--
-- Rather than asking anybody to remember, this works out where every issue
-- actually is and rewrites every reference to match. It is idempotent: running
-- it when nothing has moved changes nothing.

local M = {}

-- {{{ local function read_file(path)
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local text = f:read("*a")
  f:close()
  return text
end
-- }}}

-- {{{ local function write_file(path, text)
local function write_file(path, text)
  local f = io.open(path, "w")
  if not f then error("cannot write " .. path) end
  f:write(text)
  f:close()
end
-- }}}

-- {{{ local function list_dir(dir, pattern)
local function list_dir(dir, pattern)
  local names = {}
  local pipe = io.popen("ls " .. dir .. " 2>/dev/null")
  if not pipe then return names end
  for name in pipe:lines() do
    if name:match(pattern) then names[#names + 1] = name end
  end
  pipe:close()
  table.sort(names)
  return names
end
-- }}}

-- {{{ function M.relink(root)
-- Rewrites every reference to an issue so that it points where the issue is now.
--
-- Returns the number of files changed and a list of what changed in each.
function M.relink(root)
  -- Where each issue is, keyed by its file name.
  local where = {}
  for _, name in ipairs(list_dir(root .. "/issues", "%.md$")) do
    where[name] = "open"
  end
  for _, name in ipairs(list_dir(root .. "/issues/completed", "%.md$")) do
    where[name] = "done"
  end

  local changed, notes = 0, {}

  -- {{{ local function fix(path, transform)
  local function fix(path, transform)
    local text = read_file(path)
    if not text then return end
    local fixed, n = transform(text)
    if n > 0 and fixed ~= text then
      write_file(path, fixed)
      changed = changed + 1
      notes[#notes + 1] = string.format("%s: %d links", path:gsub(root .. "/", ""), n)
    end
  end
  -- }}}

  -- {{{ local function normalise(text, prefix_for)
  -- Rewrites every issue reference to the prefix it *should* have, whatever it
  -- has now.
  --
  -- The first version adjusted links instead of deriving them -- an open sibling
  -- gained a `../`, a completed one gained a `completed/` -- and that is only
  -- correct for a file that moves once. A link written while its target was open,
  -- rewritten when the target completed, and rewritten again when the *source*
  -- completed, ends up as `completed/completed/`. Deriving the whole prefix from
  -- where both files are now is idempotent by construction, and idempotent is
  -- the property that makes this safe to run from every completion and by hand
  -- whenever something looks wrong.
  local function normalise(text, prefix_for)
    local n = 0
    text = text:gsub("%]%(([%.%w/]-)(%d%d%d[%w%-]*%.md)%)", function(had, base)
      -- Only touch things that are plainly issue references. A path reaching out
      -- of the issues tree -- ../docs/003-carving-the-maze.md -- is not one.
      if had:find("docs/") or had:find("src/") or had:find("assets/")
         or had:find("notes/") or had:find("tests/") then
        return "](" .. had .. base .. ")"
      end
      local want = prefix_for(base)
      if want == nil then return "](" .. had .. base .. ")" end
      if want ~= had then n = n + 1 end
      return "](" .. want .. base .. ")"
    end)
    return text, n
  end
  -- }}}

  -- Inside a completed issue: it sits one directory deeper than it used to, so
  -- every escape out of issues/ needs one more step. `../../` already starts
  -- with `../.`, so this cannot apply twice.
  for _, name in ipairs(list_dir(root .. "/issues/completed", "%.md$")) do
    fix(root .. "/issues/completed/" .. name, function(text)
      local n = 0
      text = text:gsub("%]%(%.%./([%w])", function(first)
        n = n + 1
        return "](../../" .. first
      end)
      local fixed, m = normalise(text, function(base)
        if where[base] == "open" then return "../" end
        if where[base] == "done" then return "" end
        return nil
      end)
      return fixed, n + m
    end)
  end

  -- Inside an open issue.
  for _, name in ipairs(list_dir(root .. "/issues", "%.md$")) do
    fix(root .. "/issues/" .. name, function(text)
      return normalise(text, function(base)
        if where[base] == "open" then return "" end
        if where[base] == "done" then return "completed/" end
        return nil
      end)
    end)
  end

  -- Anything outside issues/ that names one: the roadmap, mostly, and whatever
  -- else grows a link later.
  for _, dir in ipairs({ "docs", "src", "assets" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.md$")) do
      fix(root .. "/" .. dir .. "/" .. name, function(text)
        local n = 0
        text = text:gsub("%]%(%.%./issues/([%w%-%./]+%.md)%)", function(target)
          local base = target:gsub("^completed/", "")
          local want = (where[base] == "done") and ("completed/" .. base) or base
          if want ~= target then n = n + 1 end
          return "](../issues/" .. want .. ")"
        end)
        return text, n
      end)
    end
  end

  return changed, notes
end
-- }}}

-- {{{ if invoked directly
if arg and arg[0] and arg[0]:find("057%-the%-relinker") then
  local root = arg[1]
  if not root then
    print("057-the-relinker.lua needs the project root as its first argument")
    os.exit(1)
  end
  local changed, notes = M.relink(root)
  for _, note in ipairs(notes) do print("  " .. note) end
  if changed == 0 then
    print("every link already points where it should")
  else
    print(string.format("%d files relinked", changed))
  end
end
-- }}}

return M
