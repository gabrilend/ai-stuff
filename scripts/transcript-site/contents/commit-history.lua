-- commit-history.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Reads a folder's git history into a list of commits, oldest first: the
-- spine of the table of contents.
--
-- Part of the table of contents (contents/). It reads git and nothing else:
-- no transcript, no page, no other part of the library.
--
-- WHY THE COMMITS AND NOT THE FILES. A folder of transcripts has no reading
-- order. The files are named for the span of days they cover, which LOOKS
-- chronological and is not: several sessions run at once, a conversation begun
-- on Tuesday can be added to on Friday, and two files can cover overlapping
-- spans while belonging to different threads of work. Sorting by filename, by
-- date or by modification time all produce an order no human ever experienced.
-- The commits are the only true chronology, so they are the spine.
--
-- TWO KINDS OF HISTORY, told apart by where the folder sits (issue 035b):
--
--   the folder is its repository's top -- a standalone project, or a public
--   mirror like double-diaper-dungeon's. Every commit is read, EMPTY ONES
--   INCLUDED: a mirror writes an empty commit, carrying only the message,
--   where a project commit touched no transcript, and without it a stretch of
--   work would vanish from the story.
--
--   the folder is inside a larger repository -- a project in the ai-stuff
--   monorepo. Only commits that touched the folder are read, with paths
--   written from it, so the project sees its own "llm-transcripts/..." paths
--   exactly as a standalone one would.
--
-- EVERY COMMIT HAS A SOURCE. A mirror's commit copies a project commit and
-- names it on a "Mirrored-from:" line; the transcripts record the PROJECT's
-- hash, so that is the one a commit is matched by. A commit with no such line
-- is its own source. Matching on the source lets a mirror and a project be
-- read by the same rules.
--
-- Taken from double-diaper-dungeon's src/051-commit-timeline.lua and this
-- folder's older commit-timeline.lua, which read one kind of history each.

local M = {}

-- The separator between a commit's fields. Chosen because git will not put it
-- in a hash, a subject or a date, and a subject can contain anything else.
local FIELD = "\30"
local RECORD = "\31"

-- {{{ local function shell_quote()
-- Wraps a path so a space or a quote in it cannot end the argument early.
local function shell_quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_all()
-- Runs a read-only git command and returns everything it printed.
local function read_all(command, what)
  local pipe = io.popen(command, "r")
  if not pipe then
    error("could not read " .. what)
  end
  local text = pipe:read("*a")
  pipe:close()
  return text
end
-- }}}

-- {{{ function M.is_repository_top()
-- Whether a folder is the top of its git repository. Decides which kind of
-- history it has (see the header). A folder in no repository at all is an
-- error, since it has no history to tell.
function M.is_repository_top(folder)
  local top = read_all("git -C " .. shell_quote(folder) .. " rev-parse --show-toplevel",
    "the repository of " .. folder):gsub("%s+$", "")
  if top == "" then
    error(folder .. " is not in a git repository, so it has no history to tell")
  end
  local real = read_all("realpath " .. shell_quote(folder), folder):gsub("%s+$", "")
  return top == real
end
-- }}}

-- The trailers at the foot of a message are for machines, not readers. A
-- dispatch table: each row is a trailer's start and what becomes of it.
-- "Mirrored-from:" is kept as the commit's source and taken out of the text;
-- "Co-Authored-By:" is attribution git and GitHub read, which on a page would
-- be the same line under every commit; "Claude-Session:" is a link into a
-- session page only its owner can open.
local TRAILERS = {
  { pattern = "^Mirrored%-from: (%x+)", keep_as = "source" },
  { pattern = "^Co%-Authored%-By:" },
  { pattern = "^Claude%-Session:" },
}

-- {{{ local function split_trailers()
-- Separates a body's reading lines from its trailers. Returns the lines kept
-- and the source hash, or nil when the message names none.
local function split_trailers(body_lines)
  local kept, source = {}, nil
  for _, line in ipairs(body_lines) do
    local trailer = false
    for _, row in ipairs(TRAILERS) do
      local captured = line:match(row.pattern)
      if captured then
        trailer = true
        if row.keep_as == "source" then
          source = captured
        end
        break
      end
    end
    if not trailer then
      kept[#kept + 1] = line
    end
  end
  return kept, source
end
-- }}}

-- {{{ function M.read()
-- Walks a folder's history and returns one record per commit, oldest first:
--
--   hash         string, the full hash of this commit
--   source       string, the hash the transcripts know it by: its
--                "Mirrored-from:" hash, or its own hash
--   subject      string
--   date         string, YYYY-MM-DD
--   body         string, or nil when the message has none; trailers removed
--   transcripts  list of strings, the transcript files it touched, as
--                "<transcripts>/<name>.md" written from the folder
--
-- `transcripts` (string, default "llm-transcripts") is the transcripts
-- folder's path inside `folder`; only a .md file directly inside it counts.
-- Raises if the history cannot be read or none of it is understood.
function M.read(folder, transcripts)
  transcripts = transcripts or "llm-transcripts"

  -- The record mark goes at the FRONT of the format, not the end. With it
  -- trailing, splitting the output hands you a chunk holding the PREVIOUS
  -- commit's file list followed by this commit's header, since --name-only
  -- prints a commit's files after the header line they belong to, and every
  -- commit gets its neighbour's files. Leading, each chunk is one header and
  -- then exactly its own files.
  --
  -- A separator follows the body too, so the body ends where git says it
  -- ends. It used to end at the first line that LOOKED like a file path,
  -- since --name-only prints the files after it: a message with a line
  -- beginning "llm-transcripts/HTML/, built by..." was cut there, the page
  -- showed half a sentence, and the "Mirrored-from:" line below it was lost,
  -- so the commit could never find its conversation. She noticed the commit
  -- with no conversation; the cut message was why.
  local format = RECORD .. "%H" .. FIELD .. "%s" .. FIELD .. "%ad" .. FIELD .. "%b" .. FIELD

  -- Two kinds of history (see the header): the whole repository, empty
  -- commits included; or only what touched this folder, written from it.
  local scope = ""
  if not M.is_repository_top(folder) then
    scope = " --relative -- ."
  end
  local text = read_all(string.format("git -C %s log --date=short --format=%s --name-only%s",
    shell_quote(folder), shell_quote(format), scope), "the history at " .. folder)

  if text == "" then
    error("the history at " .. folder .. " has no commits in it")
  end

  local prefix = "^" .. transcripts:gsub("%p", "%%%0") .. "/"
  local commits = {}
  for chunk in text:gmatch(RECORD .. "([^" .. RECORD .. "]*)") do
    local hash, subject, date, body_text, file_text =
      chunk:match("^(%x+)" .. FIELD .. "(.-)" .. FIELD .. "([%d%-]+)" .. FIELD .. "(.-)" .. FIELD .. "(.*)$")
    if hash then
      -- The body is everything before the last separator, and the files are
      -- everything after it: git puts them there, so nothing is guessed.
      local body_lines, files = {}, {}
      for line in (body_text .. "\n"):gmatch("([^\n]*)\n") do
        body_lines[#body_lines + 1] = line
      end
      for line in file_text:gmatch("[^\n]+") do
        -- Only a transcript counts: a .md file directly inside the
        -- transcripts folder. Pages and film choices kept beside them are
        -- not conversations.
        if line:match(prefix .. "[^/]+%.md$") then
          files[#files + 1] = line
        end
      end

      local kept, source = split_trailers(body_lines)
      local body = table.concat(kept, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      commits[#commits + 1] = {
        hash = hash, source = source or hash, subject = subject, date = date,
        body = (body ~= "" and body) or nil,
        transcripts = files,
      }
    end
  end

  if #commits == 0 then
    error("read the history at " .. folder .. " and understood none of it -- the format moved")
  end

  -- Oldest first, because the page is read top to bottom as a story.
  -- Collected forward and flipped, because git's own reverse walk and its
  -- name-only output do not compose the way one would hope.
  local ordered = {}
  for index = #commits, 1, -1 do
    ordered[#ordered + 1] = commits[index]
  end
  return ordered
end
-- }}}

-- {{{ function M.rename_map()
-- Follows every rename in the history, so a commit that touched a transcript
-- under an old name still finds the conversation that transcript became.
-- Returns a table: old path (string) -> the path it has now (string).
--
-- The exporter renames a transcript when a session resumes across a day
-- boundary, so history holds names that no longer exist on disk. Git recorded
-- the renames, so nothing has to be guessed. Walking them oldest to newest and
-- chaining them means a file renamed twice still resolves: if A became B and
-- B later became C, A answers C.
function M.rename_map(folder)
  local scope = ""
  if not M.is_repository_top(folder) then
    scope = " --relative -- ."
  end
  local text = read_all(string.format(
    "git -C %s log --reverse --diff-filter=R --name-status --format= -M%s",
    shell_quote(folder), scope), "the renames at " .. folder)

  local becomes = {}
  for line in text:gmatch("[^\n]+") do
    -- R<similarity><tab><old path><tab><new path>
    local from, to = line:match("^R%d*\t(.-)\t(.+)$")
    if from and to then
      for older, current in pairs(becomes) do
        if current == from then
          becomes[older] = to
        end
      end
      becomes[from] = to
    end
  end
  return becomes
end
-- }}}

-- {{{ function M.resolve()
-- The name a path goes by now, following renames; the path itself when it
-- was never renamed.
function M.resolve(path, becomes)
  return becomes[path] or path
end
-- }}}

return M
