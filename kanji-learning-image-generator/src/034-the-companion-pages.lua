-- 034-the-companion-pages.lua
--
-- Writes the .info.md page that sits beside every source file, out of the
-- comments already in that source file.
--
-- For a general: this project's rule is that you read a file's companion page
-- rather than its code, unless you are chasing a specific bug in a specific
-- function. That only works if the page is true, and a page maintained by hand
-- stops being true on the first edit somebody makes in a hurry. So the page is
-- not maintained -- it is regenerated, from the source, every time.
--
-- The extraction is possible because every function in this project is wrapped
-- in a fold that names it, and the lines under that fold are its explanation.
-- That convention was already required for editing comfort; this makes it load
-- bearing, which is the cheapest kind of documentation there is.
--
--   luajit src/034-the-companion-pages.lua [--dir ROOT] [--check]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ source_files()
-- Every Lua file in src/, in index order.
--
-- Index order is reading order (docs/table-of-contents.md), and `ls` gives it
-- for free because the indices are zero-padded to the same width.
local function source_files()
  local names = {}
  local listing = io.popen('ls -1 "' .. project.path("src") .. '"/*.lua 2>/dev/null')
  if not listing then return names end
  for line in listing:lines() do
    names[#names + 1] = line
  end
  listing:close()
  table.sort(names)
  return names
end
-- }}}

-- {{{ strip_comment(line)
-- The text of a comment line, or nil if the line is not one.
local function strip_comment(line)
  local body = line:match("^%s*%-%-%s?(.*)$")
  if not body then return nil end
  return (body:gsub("%s+$", ""))
end
-- }}}

-- {{{ M.read_source(path)
-- One source file, pulled apart into the pieces a page is made of.
--
-- Returns a table with:
--   name       the file's base name, without .lua
--   heading    the descriptive block at the top, as paragraphs
--   invocation the command line, if the header showed one
--   entries    an array of { name, arguments, external, doc }
--
-- The header block is everything from the second line to the first line that is
-- not a comment. Its first line is the filename, which is dropped -- the page
-- has a title already and repeating it there would be the same words twice.
--
-- A line in the header that looks like a command is pulled out as the
-- invocation, because "how do I run this" is the question a page gets asked
-- most and it should not be buried in a paragraph.
function M.read_source(path)
  local text = project.read_file(path)
  if not text then error("cannot read " .. path) end

  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end

  local name = path:match("([^/]+)%.lua$")
  local heading, invocation = {}, nil
  local index = 2

  while index <= #lines do
    local body = strip_comment(lines[index])
    if not body then break end
    -- the invocation is indented in the source, so the test has to allow for
    -- leading space; without that it lands in the prose and the page has no
    -- "how do I run this" section at all
    if body:match("^%s*luajit%s") or body:match("^%s*%./") then
      invocation = (body:gsub("^%s+", ""))
    else
      heading[#heading + 1] = body
    end
    index = index + 1
  end

  -- paragraphs, so the page reflows rather than keeping the source's wrapping
  local paragraphs, current = {}, {}
  for _, line in ipairs(heading) do
    if line == "" then
      if #current > 0 then
        paragraphs[#paragraphs + 1] = table.concat(current, " ")
        current = {}
      end
    else
      current[#current + 1] = line
    end
  end
  if #current > 0 then paragraphs[#paragraphs + 1] = table.concat(current, " ") end

  local entries = {}
  local at = 1
  while at <= #lines do
    local fold = lines[at]:match("^%s*%-%-%s*{{{%s*(.+)$")
    if fold then
      local fold_name = fold:match("^([%w_%.:]+)") or fold
      local arguments = fold:match("^[%w_%.:]+%s*(%b())") or ""
      -- a fold whose head is prose rather than a call is a section marker, not
      -- a function, and has no place in a list of what the file offers
      local is_call = fold:find("%b()") ~= nil
      local doc = {}
      local scan = at + 1
      while scan <= #lines do
        local body = strip_comment(lines[scan])
        if body == nil then break end
        doc[#doc + 1] = body
        scan = scan + 1
      end
      if is_call then
        entries[#entries + 1] = {
          name = fold_name,
          arguments = arguments,
          external = fold_name:sub(1, 2) == "M.",
          doc = doc,
        }
      end
      at = scan
    else
      at = at + 1
    end
  end

  return {
    name = name, path = path, heading = paragraphs,
    invocation = invocation, entries = entries,
  }
end
-- }}}

-- {{{ first_sentence(doc)
-- The opening line of a fold's comment -- what the function is, in one line.
local function first_sentence(doc)
  for _, line in ipairs(doc) do
    if line ~= "" then return line end
  end
  return ""
end
-- }}}

-- {{{ remaining_prose(doc)
-- Everything after the first line, as paragraphs.
local function remaining_prose(doc)
  local paragraphs, current = {}, {}
  local started = false
  for _, line in ipairs(doc) do
    if not started then
      if line ~= "" then started = true end
    else
      if line == "" then
        if #current > 0 then
          paragraphs[#paragraphs + 1] = table.concat(current, " ")
          current = {}
        end
      else
        current[#current + 1] = line
      end
    end
  end
  if #current > 0 then paragraphs[#paragraphs + 1] = table.concat(current, " ") end
  return paragraphs
end
-- }}}

-- {{{ M.who_uses(name, all_files)
-- Which other source files load this one.
--
-- The project loads siblings by name through src/009, so a mention of the
-- file's name in another file is a dependency. Grepping for it is exact enough
-- and needs no import graph.
function M.who_uses(name, all_files)
  local users = {}
  for _, path in ipairs(all_files) do
    local other = path:match("([^/]+)%.lua$")
    if other ~= name then
      local text = project.read_file(path)
      if text and text:find(name, 1, true) then
        users[#users + 1] = other
      end
    end
  end
  table.sort(users)
  return users
end
-- }}}

-- {{{ M.render(source, users)
-- One source file's description, as the text of its page.
function M.render(source, users)
  local out = {}
  local function say(line) out[#out + 1] = line or "" end

  say("# " .. source.name .. " — info")
  say()
  for _, paragraph in ipairs(source.heading) do
    say(paragraph)
    say()
  end

  say("*Lifted from this file's own comments by `034-the-companion-pages`. To")
  say("change this page, change the comments in `" .. source.name .. ".lua` and")
  say("run the sweep again.*")
  say()

  if source.invocation then
    say("## Invocation")
    say()
    say("```")
    say(source.invocation)
    say("```")
    say()
  end

  local external, internal = {}, {}
  for _, entry in ipairs(source.entries) do
    if entry.external then external[#external + 1] = entry
    else internal[#internal + 1] = entry end
  end

  if #external > 0 then
    say("## What it offers")
    say()
    say("| | |")
    say("|---|---|")
    for _, entry in ipairs(external) do
      say("| `" .. entry.name .. entry.arguments .. "` | " ..
          first_sentence(entry.doc) .. " |")
    end
    say()

    -- the longer explanations, for the entries that have one. a function whose
    -- comment is a single line has said everything it has to say and repeating
    -- the line under its own heading would be padding.
    for _, entry in ipairs(external) do
      local prose = remaining_prose(entry.doc)
      if #prose > 0 then
        say("### `" .. entry.name .. entry.arguments .. "`")
        say()
        say(first_sentence(entry.doc))
        say()
        for _, paragraph in ipairs(prose) do
          say(paragraph)
          say()
        end
      end
    end
  end

  if #internal > 0 then
    say("## Inside")
    say()
    say("Not reachable from outside the file. Listed because the page is also")
    say("what a person reads before opening the source.")
    say()
    say("| | |")
    say("|---|---|")
    for _, entry in ipairs(internal) do
      say("| `" .. entry.name .. entry.arguments .. "` | " ..
          first_sentence(entry.doc) .. " |")
    end
    say()
  end

  if #users > 0 then
    say("## Where it sits")
    say()
    local marked = {}
    for _, user in ipairs(users) do marked[#marked + 1] = "`" .. user .. "`" end
    say("Used by " .. table.concat(marked, ", ") .. ".")
    say()
  end

  return table.concat(out, "\n")
end
-- }}}

-- {{{ M.sweep(options)
-- Every source file's page, written. Returns what was written and what changed.
function M.sweep(options)
  options = options or {}
  local files = source_files()
  local written, changed = {}, {}
  for _, path in ipairs(files) do
    local source = M.read_source(path)
    local users = M.who_uses(source.name, files)
    local page = M.render(source, users)
    local target = path:gsub("%.lua$", ".info.md")
    local existing = project.read_file(target)
    if existing ~= page then
      changed[#changed + 1] = source.name
      if not options.check then project.write_file(target, page) end
    end
    written[#written + 1] = source.name
  end
  return written, changed
end
-- }}}

-- {{{ main(argv)
-- Run directly, this sweeps. --check reports what would change and writes
-- nothing, which is what a test wants.
local function main(argv)
  local options = project.arguments(argv)
  project.hello("034-the-companion-pages")
  local written, changed = M.sweep({ check = options.check })
  io.write(string.format("%d source files, %d pages %s\n",
           #written, #changed, options.check and "out of date" or "rewritten"))
  for _, name in ipairs(changed) do io.write("  " .. name .. "\n") end
  project.goodbye("034-the-companion-pages",
                  { #written .. " source files swept", #changed .. " pages touched" })
  if options.check and #changed > 0 then os.exit(1) end
end
-- }}}

if arg and arg[0] and arg[0]:find("034%-the%-companion%-pages") then
  main(arg)
end

return M
