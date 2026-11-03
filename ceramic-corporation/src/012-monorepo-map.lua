-- ceramic-corporation — an organisation as a map everyone can read
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

-- 012-monorepo-map.lua
--
-- Writes the monorepo's queue of open pull requests as an org map.
--
-- The monorepo has the shape the vision describes: many projects, one person
-- who merges, and a queue of pull requests, many built on others. This turns a
-- snapshot of that queue (scripts/list-open-pull-requests) and a hand-kept
-- list of open questions into org.map, so the blocked board can say which
-- merge or answer frees the most:
--
--   * each open pull request is a work box held by the owner, who merges;
--   * a pull request built on another's branch waits on that one (`in base`);
--     one built on a branch no open pull request carries has its base as a
--     fixed value, because nothing blocks it but retargeting;
--   * each project is a role held by the builder: its next round of work,
--     which branches from main and so waits on every open pull request that
--     touches the project;
--   * each open question is a work box held by the owner, wired to its project.
--
-- The output is deterministic: the same input writes the same file, so a
-- re-run shows no diff and a fresh snapshot's diff is exactly what changed.
--
-- Run directly: `luajit 012-monorepo-map.lua INPUT_DIR ORG_DIR`.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/src/[^/]+$") or "."
local reader = dofile(ROOT .. "/src/007-org-reader.lua")

local M = {}

M.OWNER = "ritz"
M.BUILDER = "claude"

-- {{{ function M.project_name()
-- A top-level directory as a map name: lowercase, anything outside the name
-- alphabet a hyphen. The repository root is "repository-root".
function M.project_name(dir)
  if dir == "." then return "repository-root" end
  local name = dir:lower():gsub("[^a-z0-9%-]", "-"):gsub("%-%-+", "-"):gsub("^%-+", "")
                  :gsub("%-+$", "")
  return name
end
-- }}}

-- {{{ function M.quote()
-- A quoted field in the shared grammar.
function M.quote(s)
  s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end
-- }}}

-- {{{ function M.read_snapshot()
-- The tab-separated snapshot: comment lines start with #; the first may say
-- `# taken DATE ...`. Returns { taken, prs }, or nil and a message.
function M.read_snapshot(text)
  local snap = { prs = {} }
  local n = 0
  for line in text:gmatch("([^\n]*)\n?") do
    n = n + 1
    if line:sub(1, 1) == "#" then
      snap.taken = snap.taken or line:match("^# taken (%d%d%d%d%-%d%d%-%d%d)")
    elseif line ~= "" then
      local number, base, head, projects, title =
        line:match("^(%d+)\t([^\t]+)\t([^\t]+)\t([^\t]*)\t(.*)$")
      if not number then
        return nil, string.format("snapshot line %d is not NUMBER BASE HEAD PROJECTS TITLE", n)
      end
      local list = {}
      for p in projects:gmatch("[^,]+") do list[#list + 1] = p end
      snap.prs[#snap.prs + 1] = { number = tonumber(number), base = base, head = head,
                                  projects = list, title = title }
    end
  end
  table.sort(snap.prs, function(a, b) return a.number < b.number end)
  return snap
end
-- }}}

-- {{{ function M.read_questions()
-- The questions file, in the shared grammar: `question NAME` with `project`,
-- `says` and `source` lines. Returns the list, or nil and a message.
function M.read_questions(text, file)
  local problems = {}
  local lines = reader.lex(text, file, problems)
  if #problems > 0 then return nil, reader.format_problem(problems[1]) end
  local list = {}
  for _, line in ipairs(lines) do
    if line.kind == "head" then
      if line.fields[1] ~= "question" or #line.fields ~= 2 or not reader.is_name(line.fields[2]) then
        return nil, string.format("%s:%d: a head here is `question NAME`", file, line.n)
      end
      local q = { name = line.fields[2], line = line.n }
      for _, body in ipairs(line.body) do
        local kw, value = body.fields[1], body.fields[2]
        if kw == "project" and #body.fields == 2 and not body.quoted[2] then
          q.project = value
        elseif (kw == "says" or kw == "source") and #body.fields == 2 and body.quoted[2] then
          q[kw] = value
        else
          return nil, string.format("%s:%d: a question holds project, says and source", file, body.n)
        end
      end
      if not q.project or not q.says then
        return nil, string.format("%s:%d: %s needs a project and a says", file, line.n, q.name)
      end
      list[#list + 1] = q
    end
  end
  return list
end
-- }}}

-- {{{ function M.build()
-- The map's text. Refuses (nil, message) when two things would get one name.
function M.build(snap, questions)
  local names = { [M.OWNER] = "a person", [M.BUILDER] = "a person" }
  local function claim(name, what)
    if names[name] then
      return string.format("%s and %s would both be called %s", names[name], what, name)
    end
    names[name] = what
  end

  local by_head = {}
  for _, pr in ipairs(snap.prs) do by_head[pr.head] = pr end

  local projects = {}   -- name -> { dir, ins = { {port, from} } }
  local project_order = {}
  local function project(dir)
    local name = M.project_name(dir)
    if not projects[name] then
      projects[name] = { dir = dir, ins = {} }
      project_order[#project_order + 1] = name
    elseif projects[name].dir ~= dir then
      return nil, string.format("the directories %s and %s would both be called %s",
                                projects[name].dir, dir, name)
    end
    return name
  end

  local children = {}
  for _, pr in ipairs(snap.prs) do
    local err = claim("pr-" .. pr.number, "pull request #" .. pr.number)
    if err then return nil, err end
    local parent = by_head[pr.base]
    if parent then
      children[parent.number] = children[parent.number] or {}
      table.insert(children[parent.number], pr.number)
    end
    pr.project_names = {}
    for _, dir in ipairs(pr.projects) do
      local name, perr = project(dir)
      if not name then return nil, perr end
      pr.project_names[#pr.project_names + 1] = name
      table.insert(projects[name].ins, { port = "pr-" .. pr.number, from = "pr-" .. pr.number .. ".merged" })
    end
  end
  for _, q in ipairs(questions) do
    local err = claim("question-" .. q.name, "question " .. q.name)
    if err then return nil, err end
    local name, perr = project(q.project)
    if not name then return nil, perr end
    q.project_name = name
    table.insert(projects[name].ins, { port = "question-" .. q.name,
                                       from = "question-" .. q.name .. ".answer" })
  end
  table.sort(project_order)
  for _, name in ipairs(project_order) do
    local err = claim(name, "the project " .. projects[name].dir)
    if err then return nil, err end
  end

  local out = {}
  local function emit(s) out[#out + 1] = s end
  emit("# The ai-stuff monorepo's queue of open pull requests, written as an org map.")
  emit("# Generated by src/012-monorepo-map.lua from input/: do not edit by hand.")
  emit("# Change the input, or take a fresh snapshot, and run ./map-the-monorepo.")
  emit("")
  emit("org ai-stuff")
  emit("  says " .. M.quote(string.format(
    "the monorepo as of %s: %d open pull requests, %d open questions, %d projects waiting",
    snap.taken or "an unknown day", #snap.prs, #questions, #project_order)))
  emit("")
  emit("person " .. M.BUILDER)
  emit("  says \"builds in the background, one project per session, from main\"")
  emit("")
  emit("person " .. M.OWNER)
  emit("  says \"the owner: reviews and merges, and answers the questions\"")

  for _, name in ipairs(project_order) do
    local p = projects[name]
    emit("")
    emit("role " .. name)
    emit("  says " .. M.quote("the next round of work on " .. (p.dir == "." and "the repository root" or p.dir)
                                .. ", which branches from main"))
    emit("  held-by " .. M.BUILDER)
    for _, i in ipairs(p.ins) do emit("  in " .. i.port .. " - " .. i.from) end
  end

  for _, pr in ipairs(snap.prs) do
    emit("")
    emit("work pr-" .. pr.number)
    emit("  says " .. M.quote("#" .. pr.number .. ": " .. pr.title))
    emit("  held-by " .. M.OWNER)
    if pr.base ~= "main" then
      local parent = by_head[pr.base]
      if parent then
        emit("  in base - pr-" .. parent.number .. ".merged")
      else
        emit("  in base = " .. M.quote(pr.base .. ", which no open pull request carries: retarget onto main"))
      end
    end
    local kids = children[pr.number] or {}
    table.sort(kids)
    for _, k in ipairs(kids) do emit("  out merged - pr-" .. k .. ".base") end
    for _, name in ipairs(pr.project_names) do
      emit("  out merged - " .. name .. ".pr-" .. pr.number)
    end
  end

  for _, q in ipairs(questions) do
    emit("")
    emit("work question-" .. q.name)
    emit("  says " .. M.quote(q.says .. (q.source and (" (" .. q.source .. ")") or "")))
    emit("  held-by " .. M.OWNER)
    emit("  out answer - " .. q.project_name .. ".question-" .. q.name)
  end
  return table.concat(out, "\n") .. "\n"
end
-- }}}

-- {{{ function M.main()
function M.main(args)
  local input, dir = args[1], args[2]
  if not input or not dir then
    io.stderr:write("usage: 012-monorepo-map.lua INPUT_DIR ORG_DIR\n")
    return 2
  end
  local snap_text = reader.read_file(input .. "/open-pull-requests.tsv")
  if not snap_text then
    io.stderr:write("no snapshot at " .. input .. "/open-pull-requests.tsv\n")
    return 1
  end
  local snap, err = M.read_snapshot(snap_text)
  if not snap then io.stderr:write(err, "\n") return 1 end
  local questions = {}
  local q_text = reader.read_file(input .. "/questions")
  if q_text then
    questions, err = M.read_questions(q_text, input .. "/questions")
    if not questions then io.stderr:write(err, "\n") return 1 end
  end
  local text, berr = M.build(snap, questions)
  if not text then io.stderr:write(berr, "\n") return 1 end
  local f = assert(io.open(dir .. "/org.map", "wb"))
  f:write(text)
  f:close()
  print(string.format("%s/org.map: %d pull requests, %d questions", dir, #snap.prs, #questions))
  return 0
end
-- }}}

if arg and arg[0] and arg[0]:match("012%-monorepo%-map%.lua$") then
  os.exit(M.main(arg))
end

return M
