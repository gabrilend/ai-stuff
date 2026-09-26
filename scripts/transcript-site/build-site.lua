-- build-site.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Writes one project's transcript pages, and says what it saw doing it.
--
-- Run by build-transcript-pages, which settles the arguments:
--   luajit build-site.lua <project-dir> <out-dir> <palette-file>
--
-- The piece that joins the other three. The reader turns a transcript into
-- data, the page builder turns that data into a page, the timeline turns the
-- project's history into runs -- and this walks the project's
-- llm-transcripts/, calls all three, and puts the files in <out-dir>:
--
--   <out-dir>/index.html       the commit timeline, oldest first, each run of
--                              commits linked to the conversation behind it
--   <out-dir>/<name>.html      one page per transcript, named as it is
--
-- Taken from double-diaper-dungeon's src/052-build-site.lua (at its commit
-- 58f89bf), without that project's age gate, game pages and nested folders,
-- which belong to its public website rather than to transcripts.
--
-- IT REDACTS NOTHING AND REPORTS EVERYTHING. A fenced code block longer than
-- the threshold is counted and listed, never cut. A development record's
-- value is the reasoning together with the code it produced, so cutting the
-- code leaves an argument about something the reader cannot see; and a page
-- that quietly removed content would be the silent fallback the house rules
-- exist to prevent.

local PROJECT, OUT, PALETTE = ...

if not PROJECT or not OUT or not PALETTE then
  io.stderr:write("build-site: needs the project, the output directory and the palette file\n")
  os.exit(1)
end

local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local reader = dofile(HERE .. "transcript-reader.lua")
local page = dofile(HERE .. "conversation-page.lua")
local timeline = dofile(HERE .. "commit-timeline.lua")

-- A fenced block longer than this is worth mentioning. Not a limit anything
-- acts on: a number above which a person should glance at what went out.
local WORTH_MENTIONING = 200

-- {{{ local function slurp()
local function slurp(path)
  local file = io.open(path, "r")
  if not file then
    error("cannot read " .. path)
  end
  local text = file:read("*a")
  file:close()
  return text
end
-- }}}

-- {{{ local function spit()
-- Writes a file, and refuses rather than carries on if it cannot. A build
-- that could not write one page and finished anyway would leave a site with a
-- hole in it and an exit code saying all was well.
local function spit(path, text)
  local file = io.open(path, "w")
  if not file then
    error("cannot write " .. path)
  end
  file:write(text)
  file:close()
end
-- }}}

-- {{{ local function count_oversized()
-- Finds fenced code blocks longer than the threshold, so the run can list
-- them. Counts only; changes nothing.
local function count_oversized(conversation, name, found)
  for _, exchange in ipairs(conversation.exchanges) do
    local inside, lines, language = false, 0, nil
    for line in (exchange.body .. "\n"):gmatch("([^\n]*)\n") do
      local fence, tag = line:match("^(```+)(.*)$")
      if fence then
        if inside then
          if lines > WORTH_MENTIONING then
            found[#found + 1] = { file = name, lines = lines, language = language }
          end
          inside, lines, language = false, 0, nil
        else
          inside = true
          language = (tag ~= "" and tag) or nil
        end
      elseif inside then
        lines = lines + 1
      end
    end
  end
end
-- }}}

-- {{{ local function list_transcripts()
-- Every file directly inside llm-transcripts/ ending .md, sorted, so two runs
-- over an unchanged folder produce the same pages.
local function list_transcripts()
  local listing = io.popen("find '" .. PROJECT .. "/llm-transcripts' -maxdepth 1 -name '*.md' -type f")
  local paths = {}
  for line in listing:lines() do
    paths[#paths + 1] = line
  end
  listing:close()
  table.sort(paths)
  return paths
end
-- }}}

print("Reading " .. PROJECT .. "/llm-transcripts")

-- Checked before the output folder is made, so a project with nothing to
-- show is not left holding an empty HTML/ folder.
local transcripts = list_transcripts()
if #transcripts == 0 then
  io.stderr:write("build-site: " .. PROJECT .. "/llm-transcripts holds no transcripts\n")
  os.exit(1)
end
os.execute("mkdir -p '" .. OUT .. "'")

local conversations = {}
local evidence = { by_hash = {}, by_subject = {}, parent_of = {}, is_main = {}, links = {} }
local oversized = {}
local written, not_transcripts = 0, {}

for _, path in ipairs(transcripts) do
  local name = path:match("([^/]+)$")
  local text = slurp(path)

  -- Three outcomes. A file with no transcript header is not a transcript -- a
  -- word cloud, an analytics export, a note -- and the naming rulebook leaves
  -- such files alone, so this does too, and lists them. A transcript that
  -- reads becomes a page. A transcript that does NOT read stops the build: it
  -- means the exporter's format moved, and skipping it would publish a site
  -- quietly missing a conversation.
  if not text:match("^# Conversation Summary: ") then
    not_transcripts[#not_transcripts + 1] = name
  else
    local ok, conversation = pcall(reader.read, text)
    if not ok then
      io.stderr:write("build-site: cannot read " .. name .. "\n  " .. tostring(conversation) .. "\n")
      os.exit(1)
    end

    count_oversized(conversation, name, oversized)

    local out_name = name:gsub("%.md$", ".html")
    spit(OUT .. "/" .. out_name, page.render(conversation, {
      title = name:gsub("%.md$", ""),
      back = "index.html",
      base_path = ".",
      palette_file = PALETTE,
    }))
    written = written + 1

    local key = "llm-transcripts/" .. name
    conversations[key] = {
      href = out_name,
      summary = page.summary_line(reader.first_request(conversation), 96),
    }

    -- The evidence the timeline attributes commits by (see its attribute()):
    -- which commits this conversation records making, and at which turn;
    -- whether it is a main conversation or a helper (a helper's session id
    -- begins "agent-"); and which helpers it links to, since a helper's
    -- transcript saved in a commit stands for its parent's.
    evidence.is_main[key] = not conversation.session_id:match("^agent%-")
    for turn, exchange in ipairs(conversation.exchanges) do
      for _, commit in ipairs(exchange.commits or {}) do
        local record = { path = key, turn = turn, hash = commit.hash }
        evidence.by_hash[commit.hash:sub(1, 7)] = record
        local same = evidence.by_subject[commit.subject] or {}
        same[#same + 1] = record
        evidence.by_subject[commit.subject] = same
      end
      for linked in exchange.body:gmatch("%]%(([^/%)]+%.md)%)") do
        evidence.links[#evidence.links + 1] = { from = key, to = "llm-transcripts/" .. linked }
      end
    end
  end
end

-- {{{ evidence from the rest of the repository
-- A project that lives inside a larger repository (the ai-stuff monorepo) has
-- commits made from conversations filed under OTHER projects: a session
-- started at the repository's top commits to every project in it. Those
-- transcripts record the commits too, so every other llm-transcripts/ folder
-- in the repository is read for commit lines -- only those, since nothing
-- else about another project's conversations is this page's business -- and
-- a commit found there links to that project's pages, which sit in its own
-- llm-transcripts/HTML/ and are built by the same command.
local function lines_of(command)
  local pipe = assert(io.popen(command, "r"))
  local out = {}
  for line in pipe:lines() do out[#out + 1] = line end
  pipe:close()
  return out
end

local top = lines_of("git -C '" .. PROJECT .. "' rev-parse --show-toplevel")[1]
local elsewhere = 0
if top and top ~= PROJECT then
  local candidates = lines_of("grep -l -s '^\\*\\[commit\\] ' '" .. top .. "'/llm-transcripts/*.md '"
    .. top .. "'/*/llm-transcripts/*.md '" .. top .. "'/*/*/llm-transcripts/*.md")
  for _, path in ipairs(candidates) do
    if path:sub(1, #PROJECT + 1) ~= PROJECT .. "/" then
      local ok, other = pcall(reader.read, slurp(path))
      -- A transcript elsewhere that does not read is that project's build's
      -- problem to report; here it only means no evidence from it.
      if ok then
        -- The route from this project's HTML/ to the other's: up out of
        -- HTML/, llm-transcripts/ and this project's folders to the top,
        -- then down into the other project's HTML/.
        local depth = select(2, PROJECT:sub(#top + 1):gsub("/", "")) + 2
        local other_dir = path:match("^(.*)/llm%-transcripts/[^/]+$"):sub(#top + 2)
        local up = string.rep("../", depth)
        local href = up .. (other_dir ~= "" and (other_dir .. "/") or "") .. "llm-transcripts/HTML/"
          .. path:match("([^/]+)%.md$") .. ".html"
        local key = "elsewhere:" .. path
        conversations[key] = { href = href,
          summary = page.summary_line(reader.first_request(other), 96),
          elsewhere = other_dir ~= "" and other_dir or "the repository's top" }
        for turn, exchange in ipairs(other.exchanges) do
          for _, commit in ipairs(exchange.commits or {}) do
            local record = { path = key, turn = turn, hash = commit.hash }
            -- This project's own transcripts win a tie: a record there is
            -- nearer to the work than one filed elsewhere.
            if not evidence.by_hash[commit.hash:sub(1, 7)] then
              evidence.by_hash[commit.hash:sub(1, 7)] = record
            end
            elsewhere = elsewhere + 1
          end
        end
      end
    end
  end
end
-- }}}

-- A helper's parent is the transcript that links to it; a link between two
-- main conversations says nothing about who made what, so only links to
-- helpers count.
for _, link in ipairs(evidence.links) do
  if conversations[link.to] and not evidence.is_main[link.to] then
    evidence.parent_of[link.to] = link.from
  end
end

local commits = timeline.read_commits(PROJECT)
local becomes = timeline.rename_map(PROJECT)

-- A commit that touched a transcript under a name it has since outgrown still
-- belongs to the conversation that transcript became.
for _, commit in ipairs(commits) do
  for index, path in ipairs(commit.transcripts) do
    commit.transcripts[index] = timeline.resolve(path, becomes)
  end
end

timeline.attribute(commits, evidence)
local runs = timeline.group(commits)
local project_name = PROJECT:match("([^/]+)/*$")
spit(OUT .. "/index.html", timeline.render_index(runs, conversations, {
  title = "How " .. project_name .. " got made",
  base_path = ".",
  palette_file = PALETTE,
}))

print("")
print("  conversations  " .. written)
print("  commits        " .. #commits)
print("  runs           " .. #runs)
print("  written to     " .. OUT)

-- How each commit was attributed, so a reader of this report can see how
-- much of the front page rests on a transcript's own record.
local recorded, saved, unknown = 0, 0, 0
for _, commit in ipairs(commits) do
  if commit.how == "recorded" then recorded = recorded + 1
  elseif commit.how == "saved" then saved = saved + 1
  else unknown = unknown + 1 end
end
print("  commits a transcript records making          " .. recorded)
print("  commits known by the one transcript they saved " .. saved)
print("  commits with no conversation recorded         " .. unknown)

if #not_transcripts > 0 then
  print("  not transcripts, left alone: " .. table.concat(not_transcripts, ", "))
end

print("")
if #oversized == 0 then
  print("  No fenced block over " .. WORTH_MENTIONING .. " lines.")
else
  print("  " .. #oversized .. " fenced block(s) over " .. WORTH_MENTIONING .. " lines:")
  for _, block in ipairs(oversized) do
    print(string.format("    %-44s %4d lines   %s",
      block.file, block.lines, block.language or ""))
  end
end
