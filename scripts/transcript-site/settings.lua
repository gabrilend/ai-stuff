-- settings.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Reads a project's transcript-site settings, fills in what the project left
-- out, and refuses anything it does not understand (issue 035e).
--
-- In general terms: every project keeps its conversations and its history in
-- its own way. This is the one place a project says how -- where the
-- transcripts are, whose history tells the story, where the pages go, what
-- colours they wear, whether it wants films -- so nothing else in the library
-- has to know anything about any particular project.
--
-- A project's settings are a Lua file that returns one table. Every field is
-- optional. The file is `transcript-site.settings.lua` in the project's top
-- folder, or any file named on the command line. See README.md for the table.

local M = {}

-- This folder, where the default palette and fonts live.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

M.DEFAULT_FILE_NAME = "transcript-site.settings.lua"

-- Every field a settings table may have, and what kind of value it holds.
-- A field not listed here is refused: a misspelt field would otherwise be
-- quietly ignored, and the project would get the default without knowing.
local KNOWN = {
  transcripts    = "string",
  history        = "string",
  output         = "string",
  pages          = "string",
  colours_css    = "function",
  palette_file   = "string",
  fonts          = "string",
  recap_contents = "boolean",
  harness_lines  = "boolean",
  attribution    = "table",
  title          = "string",
  nav            = "function",
  films          = "table",
  scratch        = "string",
}

-- The films table's fields, every one required when the table is there. A
-- films table missing one would fail halfway through describing a folder of
-- films, which is the worst place to find out.
local FILM_FIELDS = {
  film_folder = "string", descriptions_file = "string", message_centre_file = "string",
  choices_folder = "string", server = "string", vision_model = "string",
  embedding_model = "string", strip_frames = "number", message_characters = "number",
  vision_prompt = "string", neighbour_reach = "number", square_px = "number",
}

-- The films table's fields that are paths, read from the project folder when
-- they are not absolute.
local FILM_PATHS = { "film_folder", "descriptions_file", "message_centre_file", "choices_folder" }

-- {{{ local function absolute()
-- A path read from the project folder unless it already starts at the root.
local function absolute(project, path)
  if path:sub(1, 1) == "/" then
    return path
  end
  if path == "" then
    return project
  end
  return project .. "/" .. path
end
-- }}}

-- {{{ local function exists()
local function exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end
-- }}}

-- {{{ function M.route_up()
-- The route from a folder `pages` levels below the site's root back up to it:
-- "" -> ".", "story" -> "..", "site/story" -> "../..". Every page asks for
-- the font by this route, and a page that guesses wrong loads no font at all
-- and silently falls back to whatever the reader owns.
function M.route_up(pages)
  local depth = 0
  for _ in pages:gmatch("[^/]+") do
    depth = depth + 1
  end
  if depth == 0 then
    return "."
  end
  return ("../"):rep(depth):sub(1, -2)
end
-- }}}

-- {{{ function M.check()
-- Refuses a table with a field this file does not know, or a field holding
-- the wrong kind of value. Raises with the field's name.
function M.check(raw)
  for field, value in pairs(raw) do
    local wanted = KNOWN[field]
    if not wanted then
      error("transcript-site settings: no field called " .. tostring(field))
    end
    if type(value) ~= wanted then
      error(string.format("transcript-site settings: %s should be a %s, not a %s",
        field, wanted, type(value)))
    end
  end
  if raw.films then
    for field, wanted in pairs(FILM_FIELDS) do
      if type(raw.films[field]) ~= wanted then
        error(string.format("transcript-site settings: films.%s should be a %s", field, wanted))
      end
    end
    for field in pairs(raw.films) do
      if not FILM_FIELDS[field] then
        error("transcript-site settings: films has no field called " .. tostring(field))
      end
    end
  end
end
-- }}}

-- {{{ function M.resolve()
-- A raw settings table, checked and filled in, with every path absolute.
-- `project` is the project's folder, an absolute path. The table returned
-- carries every field in KNOWN (films and the two functions may be nil),
-- plus `project` and `base_path` (the route from the pages to the site root).
function M.resolve(project, raw)
  raw = raw or {}
  M.check(raw)
  local name = project:match("([^/]+)/*$")
  local out = {
    project        = project,
    transcripts    = absolute(project, raw.transcripts or "llm-transcripts"),
    history        = absolute(project, raw.history or ""),
    output         = absolute(project, raw.output or "llm-transcripts/HTML"),
    pages          = raw.pages or "",
    colours_css    = raw.colours_css,
    palette_file   = absolute(project, raw.palette_file or (HERE .. "default-palette.lua")),
    fonts          = absolute(project, raw.fonts or (HERE .. "fonts")),
    recap_contents = raw.recap_contents ~= false,
    harness_lines  = raw.harness_lines ~= false,
    attribution    = raw.attribution or { "recorded", "subject", "saved" },
    title          = raw.title or ("How " .. name .. " got made"),
    nav            = raw.nav,
    scratch        = absolute(project, raw.scratch or "tmp/shared-memory/transcript-site"),
  }
  out.base_path = M.route_up(out.pages)
  out.pages_folder = out.pages == "" and out.output or (out.output .. "/" .. out.pages)

  if raw.films then
    local films = {}
    for field, value in pairs(raw.films) do
      films[field] = value
    end
    for _, field in ipairs(FILM_PATHS) do
      films[field] = absolute(project, films[field])
    end
    out.films = films
  end
  return out
end
-- }}}

-- {{{ function M.load()
-- Reads a project's settings and resolves them. `file` is a settings file to
-- read; nil means the project's own transcript-site.settings.lua when it has
-- one, and the defaults when it does not. A file named on purpose that does
-- not exist is an error -- that is somebody's mistake, not a project without
-- settings.
function M.load(project, file)
  local path = file
  if not path then
    local own = project .. "/" .. M.DEFAULT_FILE_NAME
    if exists(own) then
      path = own
    end
  end
  local raw = {}
  if path then
    if not exists(path) then
      error("no settings file at " .. path)
    end
    raw = dofile(path)
    if type(raw) ~= "table" then
      error(path .. " should return a table of settings")
    end
  end
  local settings = M.resolve(project, raw)
  settings.file = path
  return settings
end
-- }}}

-- {{{ function M.colours_css()
-- The colours as a :root { } block, two ways: the project's own function, or
-- a palette file through site-palette.lua.
function M.colours_css(settings)
  if settings.colours_css then
    local css = settings.colours_css(settings.project)
    if type(css) ~= "string" or css == "" then
      error("the project's colours_css gave no CSS")
    end
    return css
  end
  local palette = dofile(HERE .. "site-palette.lua")
  local _, css = palette.load(settings.palette_file)
  return css
end
-- }}}

return M
