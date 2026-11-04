-- contents-page.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Draws the table of contents: every commit, oldest first, grouped by the
-- conversation it came out of, each with a button that opens that
-- conversation at the moment of the commit.
--
-- Part of the table of contents (contents/). It is handed plain tables --
-- the groups, a short description of each conversation, and the page's
-- furniture -- and returns one HTML string. It loads no transcript and no
-- part of the conversation page; the only thing the two agree on is the id
-- a commit line carries, which the builder hands to both.
--
-- THE LOOK IS double-diaper-dungeon's STORY PAGE, for every project: the
-- owner's choice on 2026-10-04, being the newer of the two looks and the one
-- she reviewed live. Taken from that project's src/051-commit-timeline.lua.
-- A page for input that the game's page could have had is byte for byte the
-- game's page; three cases only other projects meet are drawn only when they
-- happen (see group_heading and commit_html).

local M = {}

-- This folder; page-head lives in the library's shared libs/.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function escape()
local function escape(text)
  return (tostring(text)
    :gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
-- }}}

-- {{{ function M.stylesheet()
-- The page's own rules. The commits are the thing being read, so
-- everything else is small and gets out of their way.
function M.stylesheet()
  return [[
body { background: var(--ground); color: var(--plain); margin: 0;
       padding: 2rem 1rem 6rem; line-height: 1.5; }
.sheet { max-width: 52rem; margin: 0 auto; }
h1 { color: var(--spirit); margin-bottom: 0.4rem; }
.intro { opacity: 0.8; margin-top: 0; }
a { color: var(--intellect); }

/* One conversation's stretch of commits. The heading is small: the commits
   are what is being read. */
.group { margin: 0 0 1.6rem; border-left: 2px solid var(--plain); padding-left: 1rem; }
.group:hover { border-left-color: var(--spirit); }
.group h2 { font-size: 0.85rem; font-weight: normal; margin: 0 0 0.4rem; }
.group h2 .said { opacity: 0.7; font-style: italic; }
.group h2.none { opacity: 0.5; }

/* A commit is one row: what happened on the left, when and the button on
   the right, so a commit costs one line until somebody unfolds it. */
.commits { list-style: none; margin: 0; padding: 0; }
.commit { display: flex; gap: 0.8rem; align-items: baseline;
          padding: 0.25rem 0; border-bottom: 1px dotted rgba(127,127,127,0.25); }
.commit .what { flex: 1 1 auto; min-width: 0; }
.commit .when { flex: 0 0 auto; opacity: 0.55; font-size: 0.75rem; }
.commit .transcript { flex: 0 0 auto; font-size: 0.75rem; padding: 0.05rem 0.5rem;
                      border: 1px solid var(--intellect); text-decoration: none; }
.commit .transcript:hover { border-color: var(--spirit); color: var(--spirit); }
.commit .no-transcript { flex: 0 0 auto; font-size: 0.75rem; opacity: 0.35;
                         padding: 0.05rem 0.5rem; border: 1px dashed var(--plain); }

/* The first paragraph shows; the rest unfolds. <details> is the browser
   doing it; nothing on this site runs a script. */
.commit details summary { cursor: pointer; list-style: none; }
.commit details summary::-webkit-details-marker { display: none; }
.commit details summary::after { content: " \2026"; opacity: 0.6; }
.commit details[open] summary::after { content: ""; }
.commit .more { white-space: pre-wrap; margin: 0.4rem 0 0.2rem; font-size: 0.92rem;
                opacity: 0.9; }
]]
end
-- }}}

-- The rule for a conversation filed under another project, added to the
-- stylesheet only on a page that has one, so a page without stays exactly as
-- it was.
local ELSEWHERE_CSS = ".group h2 .where-filed { opacity: 0.6; }\n"

-- {{{ local function commit_html()
-- One commit as one row.
--
-- WHAT IS SHOWN IS THE BODY, NOT THE SUBJECT. She asked for the subject line
-- to go: "it doesn't really give us any information that we need." The
-- subjects are written to be skimmed and are often a turn of phrase; the body
-- is what actually happened. So the body's first paragraph is the row, and
-- the rest of the body unfolds under it. A commit with no body has only its
-- subject, and then the subject is shown, because an empty row would be a
-- hole in the story.
--
-- THE BUTTON, three ways:
--   the commit's conversation has a page, and a line to land on: the button
--     opens the page at that line;
--   it has a page and no line (attributed by the transcript it saved): the
--     button opens the page at its top;
--   no page: the button is drawn dimmed rather than left out, so every row
--     has the same shape and a missing one reads as missing rather than as a
--     layout glitch.
local function commit_html(commit, conversations)
  local text = commit.body or commit.subject
  local first, rest = text:match("^(.-)\n%s*\n(.*)$")
  if not first then
    first, rest = text, nil
  end
  first = first:gsub("%s*\n%s*", " ")

  local what
  if rest and rest:match("%S") then
    what = string.format('<details><summary>%s</summary><div class="more">%s</div></details>',
      escape(first), escape(rest))
  else
    what = escape(first)
  end

  local found = commit.conversation and conversations[commit.conversation]
  local button
  if found and commit.anchor then
    button = string.format('<a class="transcript" href="%s#%s">transcript</a>',
      escape(found.href), escape(commit.anchor))
  elseif found then
    button = string.format('<a class="transcript" href="%s">transcript</a>', escape(found.href))
  else
    button = '<span class="no-transcript" title="no saved conversation mentions this commit">transcript</span>'
  end

  return string.format('<li class="commit"><div class="what">%s</div>'
    .. '<span class="when">%s</span>%s</li>', what, escape(commit.date), button)
end
-- }}}

-- {{{ local function group_heading()
-- The small heading over a group of commits, four ways:
--   a conversation with a page: its title as a link, and the first thing
--     she said in it;
--   the same, filed under another project in the same repository: the
--     heading says where;
--   a conversation the evidence names whose transcript is gone: said so;
--   no conversation at all: said so, rather than guessed.
local function group_heading(group, conversations)
  local found = group.conversation and conversations[group.conversation]
  if found then
    local heading = string.format('<h2><a href="%s">%s</a>', escape(found.href), escape(found.title))
    if found.elsewhere then
      heading = heading .. ' <span class="where-filed">(filed under '
        .. escape(found.elsewhere) .. ")</span>"
    end
    if found.summary then
      heading = heading .. ' <span class="said">&ldquo;' .. escape(found.summary) .. "&rdquo;</span>"
    end
    return heading .. "</h2>"
  elseif group.conversation then
    return '<h2 class="none">written under a name the project no longer carries</h2>'
  end
  return '<h2 class="none">no saved conversation mentions these</h2>'
end
-- }}}

-- {{{ function M.render()
-- The whole page: the strip along the top, then every commit oldest first,
-- in groups by the conversation it came out of.
--
--   groups         list of { conversation = <key or nil>, commits = <list> },
--                  from attribution.group
--   conversations  transcript key (string) -> { href, title, summary,
--                  elsewhere }: href and title strings, summary and
--                  elsewhere strings or nil
--   opts.title       string, the heading and the window's title
--   opts.base_path   string, the route from this page to the site's root,
--                    where the font is
--   opts.colours_css string, a :root { } block of the colours
--   opts.nav         string of HTML or nil, a strip of links for the top
--   opts.nav_css     string or nil, that strip's rules
function M.render(groups, conversations, opts)
  local page_head = dofile(HERE .. "../libs/page-head.lua")
  local title = opts.title or "How this got made"

  local body = { '<div class="sheet">' }
  if opts.nav then
    body[#body + 1] = opts.nav
  end
  body[#body + 1] = "<h1>" .. escape(title) .. "</h1>"
  body[#body + 1] = '<p class="intro">Every commit, oldest first, grouped by the'
    .. " conversation it came out of. The button on each one opens that"
    .. " conversation at the moment the commit was made.</p>"

  local elsewhere = false
  for _, group in ipairs(groups) do
    local found = group.conversation and conversations[group.conversation]
    if found and found.elsewhere then
      elsewhere = true
    end
    body[#body + 1] = '<section class="group">'
    body[#body + 1] = group_heading(group, conversations)
    body[#body + 1] = '<ul class="commits">'
    for _, commit in ipairs(group.commits) do
      body[#body + 1] = commit_html(commit, conversations)
    end
    body[#body + 1] = "</ul>"
    body[#body + 1] = "</section>"
  end

  body[#body + 1] = "</div>"

  return table.concat({
    "<!DOCTYPE html>",
    '<html lang="en">',
    page_head.head({
      title = escape(title),
      -- How deep this page sits. The font lives at the site root, and a page
      -- that guesses wrong loads no font at all and silently falls back.
      base_path = opts.base_path or ".",
      extra_css = (opts.colours_css or "") .. "\n" .. (opts.nav_css or "") .. M.stylesheet()
        .. (elsewhere and ELSEWHERE_CSS or ""),
    }),
    "<body>",
    table.concat(body, "\n"),
    "</body>",
    "</html>",
  }, "\n")
end
-- }}}

return M
