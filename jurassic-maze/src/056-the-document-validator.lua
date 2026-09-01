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

-- 056-the-document-validator.lua
--
-- Checks the documents and issues against each other, and against what is
-- actually on disk.
--
-- A compiler for the written half. It cannot check prose -- and prose is where
-- documentation actually rots -- but it can check every claim that has a
-- referent: a link that points nowhere, a source file with no companion page, a
-- document nobody listed in the contents, an issue the roadmap promises and
-- which does not exist.
--
-- Every one of those is a small thing that nobody notices for months and that
-- makes a reader distrust the whole set when they finally do.

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

-- {{{ local function exists(path)
local function exists(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  -- A directory opens as a file on some systems and not others, so ask the
  -- filesystem rather than trusting the answer either way.
  return os.execute("test -e '" .. path .. "'") == 0
     or os.execute("test -e '" .. path .. "'") == true
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

-- {{{ function M.check(root)
-- Returns a list of complaints. An empty list is the whole of a pass.
function M.check(root)
  local complaints = {}
  local checked = 0
  local function complain(fmt, ...)
    complaints[#complaints + 1] = string.format(fmt, ...)
  end

  -- Every Markdown file in the project, and where it lives.
  local pages = {}
  for _, dir in ipairs({ "docs", "issues", "issues/completed", "src", "assets",
                         "inspiration" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.md$")) do
      pages[#pages + 1] = dir .. "/" .. name
    end
  end
  pages[#pages + 1] = "COPYING.md"

  -- {{{ every link points at something
  for _, page in ipairs(pages) do
    local text = read_file(root .. "/" .. page) or ""
    local dir = page:match("^(.*)/[^/]+$") or ""

    for label, href in text:gmatch("%[([^%]]+)%]%(([^%)]+)%)") do
      if not href:match("^https?:") and not href:match("^#") then
        local target = href:gsub("#.*$", "")
        -- Resolve relative to the page's own directory, the way a reader's
        -- editor and a Markdown viewer both would.
        local resolved = dir .. "/" .. target
        while resolved:match("[^/]+/%.%./") do
          resolved = resolved:gsub("[^/]+/%.%./", "", 1)
        end
        resolved = resolved:gsub("^%./", ""):gsub("^/", "")
        checked = checked + 1
        if not exists(root .. "/" .. resolved) then
          complain("%s: link '%s' points at %s, which is not there",
                   page, label, resolved)
        end
      end
    end
  end
  -- }}}

  -- {{{ every source file has a companion, and every companion has a source
  for _, dir in ipairs({ "src", "assets" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.lua$")) do
      local companion = dir .. "/" .. name:gsub("%.lua$", ".info.md")
      checked = checked + 1
      if not exists(root .. "/" .. companion) then
        complain("%s/%s has no companion page at %s", dir, name, companion)
      end
    end
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.info%.md$")) do
      local source = dir .. "/" .. name:gsub("%.info%.md$", ".lua")
      checked = checked + 1
      if not exists(root .. "/" .. source) then
        complain("%s/%s describes %s, which is not there", dir, name, source)
      end
    end
  end
  -- }}}

  -- {{{ no companion page is still the stub the tool wrote
  for _, dir in ipairs({ "src", "assets" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "%.info%.md$")) do
      local text = read_file(root .. "/" .. dir .. "/" .. name) or ""
      checked = checked + 1
      if text:match("\nTODO\n") then
        -- Not fatal on its own -- a file can legitimately be a placeholder --
        -- but it must say so rather than leaving the tool's own word there.
        complain("%s/%s is still the stub new-source-file wrote", dir, name)
      end
    end
  end
  -- }}}

  -- {{{ every document is in the contents
  local contents = read_file(root .. "/docs/table-of-contents.md") or ""
  for _, name in ipairs(list_dir(root .. "/docs", "%.md$")) do
    if name ~= "table-of-contents.md" then
      checked = checked + 1
      if not contents:find(name, 1, true) then
        complain("docs/%s is not listed in the table of contents", name)
      end
    end
  end
  -- }}}

  -- {{{ every issue the roadmap names exists somewhere
  local roadmap = read_file(root .. "/docs/025-roadmap.md") or ""
  for href in roadmap:gmatch("%(%.%./issues/([^%)]+)%)") do
    checked = checked + 1
    if not exists(root .. "/issues/" .. href)
       and not exists(root .. "/issues/completed/" .. href) then
      complain("the roadmap names issues/%s, which is in neither issues/ nor issues/completed/",
               href)
    end
  end
  -- }}}

  -- {{{ every issue has the three sections an issue must have
  for _, dir in ipairs({ "issues", "issues/completed" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "^%d.*%.md$")) do
      local text = read_file(root .. "/" .. dir .. "/" .. name) or ""
      for _, heading in ipairs({ "## Current behavior", "## Intended behavior",
                                 "## Suggested implementation steps" }) do
        checked = checked + 1
        if not text:find(heading, 1, true) then
          complain("%s/%s has no '%s' section", dir, name, heading)
        end
      end
    end
  end
  -- }}}

  -- {{{ every open question that says it blocks an issue names one that exists
  local questions = read_file(root .. "/docs/026-open-questions.md") or ""
  for list in questions:gmatch("%*Blocks:%*%s*([^\n]+)") do
    for number in list:gmatch("(%d%d%d)") do
      checked = checked + 1
      local found = false
      for _, dir in ipairs({ "issues", "issues/completed" }) do
        for _, name in ipairs(list_dir(root .. "/" .. dir, "^" .. number)) do
          if name then found = true end
        end
      end
      if not found then
        complain("open questions say they block issue %s, which does not exist", number)
      end
    end
  end
  -- }}}

  -- {{{ the file index counter agrees with the highest file on disk
  local counter = tonumber((read_file(root .. "/.file-index-counter") or "0"))
  local highest, holder = -1, nil
  for _, dir in ipairs({ "docs", "src", "assets", "tests", "notes" }) do
    for _, name in ipairs(list_dir(root .. "/" .. dir, "^%d%d%d%-")) do
      local n = tonumber(name:match("^(%d%d%d)"))
      if n and n > highest then highest, holder = n, dir .. "/" .. name end
    end
  end
  checked = checked + 1
  if counter < highest then
    complain("the index counter says %03d and %s is on disk -- two files will " ..
             "claim one number", counter, holder)
  end
  -- }}}

  return complaints, checked
end
-- }}}

-- {{{ if invoked directly
if arg and arg[0] and arg[0]:find("056%-the%-document%-validator") then
  local root = arg[1]
  if not root then
    print("056-the-document-validator.lua needs the project root as its first argument")
    os.exit(1)
  end
  local complaints, checked = M.check(root)
  for _, line in ipairs(complaints) do print("  " .. line) end
  print("")
  if #complaints == 0 then
    print(string.format("%d references check out", checked))
    os.exit(0)
  end
  print(string.format("%d references checked, %d complaints", checked, #complaints))
  os.exit(1)
end
-- }}}

return M
