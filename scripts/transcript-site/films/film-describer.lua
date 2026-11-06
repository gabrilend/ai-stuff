-- film-describer.lua
-- Copyright (C) 2026 gabrilend. SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Part of the films (films/). Taken from double-diaper-dungeon's
-- src/064-film-describer.lua (issue 035d).
--
-- Looks at each film once, as a strip of frames, and keeps the description
-- under the film's fingerprint.
--
-- A film is a looping gif, about a hundred frames. A vision model reads still
-- pictures, so each film is boiled down to a strip: a few frames spread evenly
-- across its length, laid side by side in one picture, so the model sees the
-- shapes and how they change. It writes three or four sentences, and those are
-- kept.
--
-- KEPT BY FINGERPRINT, NOT BY NAME. A film's fingerprint is the SHA-256 of its
-- bytes: sixty-four letters that change completely if one pixel changes and
-- never change otherwise. Keyed that way, a film is described the first time it
-- appears and never again, a renamed film keeps its description, and an edited
-- film counts as a new one -- which it is.
--
-- The descriptions file is plain text, one film per line:
--   fingerprint <tab> current file name <tab> description
-- sorted by file name so a new film shows up as one added line in a diff.

local M = {}

-- This folder, where the model server's file sits beside this one.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- {{{ local function shell()
local function shell(command)
  local pipe = io.popen(command, "r")
  local out = pipe:read("*a")
  local ok = pipe:close()
  return out, ok
end
-- }}}

-- {{{ function M.list_films()
-- Every .gif directly in `folder`, as a list of { name, path }, sorted by
-- name. The stills folder beside them is not looked inside.
function M.list_films(folder)
  local out = shell("ls -1 '" .. folder .. "'")
  local films = {}
  for name in out:gmatch("[^\n]+") do
    if name:match("%.gif$") then
      films[#films + 1] = { name = name, path = folder .. "/" .. name }
    end
  end
  table.sort(films, function(a, b) return a.name < b.name end)
  if #films == 0 then error("no films in " .. folder) end
  return films
end
-- }}}

-- {{{ function M.fingerprint_films()
-- Fills in each film's `hash`, its fingerprint, with one call to sha256sum
-- for the whole folder.
function M.fingerprint_films(films)
  local paths = {}
  for i, film in ipairs(films) do paths[i] = "'" .. film.path .. "'" end
  local out = shell("sha256sum " .. table.concat(paths, " "))
  local by_path = {}
  for hash, path in out:gmatch("(%x+)  ([^\n]+)") do by_path[path] = hash end
  for _, film in ipairs(films) do
    film.hash = by_path[film.path]
    if not film.hash then error("could not fingerprint " .. film.path) end
  end
  return films
end
-- }}}

-- {{{ function M.read_descriptions()
-- The descriptions file as a table: fingerprint -> { name, text }. A file
-- that does not exist yet is an empty table -- the first run starts there --
-- but a line that does not have its three parts is an error, because a file
-- someone edited badly should be fixed, not half-read.
function M.read_descriptions(path)
  local found = {}
  local file = io.open(path, "r")
  if not file then return found end
  local number = 0
  for line in file:lines() do
    number = number + 1
    if line ~= "" then
      local hash, name, text = line:match("^(%x+)\t([^\t]+)\t(.+)$")
      if not hash then
        file:close()
        error(string.format("%s line %d is not fingerprint, name, description", path, number))
      end
      found[hash] = { name = name, text = text }
    end
  end
  file:close()
  return found
end
-- }}}

-- {{{ function M.write_descriptions()
-- Writes the table back, sorted by name. Tabs and line breaks inside a
-- description become spaces, because either would break the line apart.
function M.write_descriptions(path, descriptions)
  local rows = {}
  for hash, entry in pairs(descriptions) do
    local text = entry.text:gsub("[\t\r\n]+", " ")
    rows[#rows + 1] = { name = entry.name, line = hash .. "\t" .. entry.name .. "\t" .. text }
  end
  table.sort(rows, function(a, b) return a.name < b.name end)
  os.execute("mkdir -p '" .. path:match("^(.*)/") .. "'")
  local file = assert(io.open(path, "w"))
  for _, row in ipairs(rows) do file:write(row.line, "\n") end
  file:close()
end
-- }}}

-- {{{ function M.make_strip()
-- Writes a strip of `frames` frames from the film at `path` into `out_png`:
-- the film's frame count divided evenly, every step-th frame kept, laid in a
-- row. A film shorter than the strip uses every frame it has.
function M.make_strip(path, frames, out_png)
  local count = tonumber((shell(
    "ffprobe -v error -count_frames -select_streams v:0 " ..
    "-show_entries stream=nb_read_frames -of csv=p=0 '" .. path .. "'")))
  if not count or count < 1 then error("could not count the frames of " .. path) end
  local step = math.max(1, math.floor(count / frames))
  local across = math.min(frames, count)
  local out, ok = shell(string.format(
    "ffmpeg -v error -y -i '%s' -vf \"select='not(mod(n\\,%d))',tile=%dx1\" " ..
    "-frames:v 1 -update 1 '%s' 2>&1", path, step, across, out_png))
  if not ok then error("could not make a strip of " .. path .. ": " .. out) end
end
-- }}}

-- {{{ function M.describe_new()
-- Looks at every film that has no description yet, and brings the names of
-- the others up to date if a film was renamed. Saves after each film, so a
-- run that stops partway keeps what it already paid for.
--
-- `settings` is a project's films table (see films/README.md), its paths
-- already made absolute by the settings reader, and `client` one from the
-- model-server file. Returns the films, with hashes, and how many were newly
-- described.
function M.describe_new(settings, client, scratch)
  local path = settings.descriptions_file
  local films = M.fingerprint_films(M.list_films(settings.film_folder))
  local descriptions = M.read_descriptions(path)
  local server = dofile(HERE .. "model-server.lua")

  local renamed = false
  for _, film in ipairs(films) do
    local known = descriptions[film.hash]
    if known and known.name ~= film.name then
      known.name = film.name
      renamed = true
    end
  end
  if renamed then M.write_descriptions(path, descriptions) end

  local described = 0
  for _, film in ipairs(films) do
    if not descriptions[film.hash] then
      local strip = scratch .. "/film-strip.png"
      M.make_strip(film.path, settings.strip_frames, strip)
      io.write("  looking at " .. film.name .. " ... ")
      io.flush()
      local text = server.describe(client, settings.vision_model, settings.vision_prompt, strip)
      descriptions[film.hash] = { name = film.name, text = text }
      M.write_descriptions(path, descriptions)
      described = described + 1
      print("done")
    end
  end
  return films, described
end
-- }}}

return M
