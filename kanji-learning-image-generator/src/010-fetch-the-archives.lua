-- 010-fetch-the-archives.lua
--
-- Gets the two published datasets this project reads, and writes down which
-- releases were taken.
--
-- For a general: everything this project knows about kanji comes from two files
-- other people maintain -- one holding the strokes of every character and the
-- order a hand writes them in, one holding what each character means. They are
-- about thirty megabytes together and are not committed here, because they are
-- somebody else's work and they are versioned where they live. This fetches
-- them, and records exactly which edition it got, so that a set of images
-- generated a year ago can still be traced to the dictionary that described it.
--
--   luajit src/010-fetch-the-archives.lua [--dir ROOT] [--force]

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")

local M = {}

-- {{{ shell_quote(text)
-- One argument, safe to hand to a shell.
local function shell_quote(text)
  return "'" .. tostring(text):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ tool_present(name)
-- Whether a command exists on this machine.
local function tool_present(name)
  local pipe = io.popen("command -v " .. shell_quote(name) .. " 2>/dev/null")
  if not pipe then return false end
  local found = pipe:read("*l")
  pipe:close()
  return found ~= nil and found ~= ""
end
-- }}}

-- {{{ file_size(path)
-- Bytes, or nil if there is no such file.
local function file_size(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local size = handle:seek("end")
  handle:close()
  return size
end
-- }}}

-- {{{ ends_of(path, bytes)
-- The first and last stretch of a file, for the shape check.
--
-- Both ends, and the last one is the point. A download fails by losing its
-- tail, so a check that reads only the beginning proves the file started
-- arriving and says nothing about whether it finished. An XML document that
-- still has its closing root element is a document that got all the way here.
--
-- Only the ends: reading fifteen megabytes to find two tags would make the
-- check cost more than the download. The head has to be generous even so --
-- KANJIDIC2 opens with a document type declaration several hundred lines long,
-- and its root element does not appear until well past the first few kilobytes.
local function ends_of(path, bytes)
  local handle = io.open(path, "rb")
  if not handle then return nil, nil end
  bytes = bytes or 65536
  local head = handle:read(bytes)
  local size = handle:seek("end")
  local tail_start = size - 512
  if tail_start < 0 then tail_start = 0 end
  handle:seek("set", tail_start)
  local tail = handle:read("*a")
  handle:close()
  return head, tail
end
-- }}}

-- {{{ M.fetch_one(name, archive, options)
-- Download, decompress, and check the shape of one archive.
--
-- Returns a table describing what happened, which the provenance file is
-- written from.
function M.fetch_one(name, archive, options)
  options = options or {}
  local target = project.path("assets", archive.file)
  local existing = file_size(target)

  -- Already here, and not being forced. A fifteen-megabyte download on every
  -- run is a download somebody starts working around.
  if existing and not options.force then
    return {
      name = name, file = archive.file, url = archive.url,
      bytes = existing, action = "kept", taken = "already on disk",
    }
  end

  if not tool_present("curl") then
    error("curl is not on this machine, and it is how the archives are fetched")
  end
  if not tool_present("gzip") then
    error("gzip is not on this machine, and both archives are compressed")
  end

  project.ensure_directory(project.path("assets"))
  local compressed = project.scratch("fetch/" .. archive.file .. ".gz")

  io.write("  " .. name .. ": taking " .. archive.url .. "\n")
  io.flush()
  local command = "curl --silent --show-error --location --fail " ..
                  "--output " .. shell_quote(compressed) .. " " ..
                  shell_quote(archive.url)
  local ok = os.execute(command)
  if not (ok == true or ok == 0) then
    error("could not download " .. name .. " from " .. archive.url ..
          "\n  curl exited unhappily. the network, or the release moved.")
  end

  local packed = file_size(compressed)
  if not packed or packed < 1024 then
    error("what came back for " .. name .. " is too small to be the archive (" ..
          tostring(packed) .. " bytes)")
  end

  -- Decompressed to a scratch name and only then moved into assets/, so a
  -- failed decompression cannot leave a half-file where a whole one belongs.
  local unpacked = project.scratch("fetch/" .. archive.file)
  ok = os.execute("gzip -dc " .. shell_quote(compressed) .. " > " ..
                  shell_quote(unpacked))
  if not (ok == true or ok == 0) then
    error("could not decompress " .. name .. "; the download is probably truncated")
  end

  local head, tail = ends_of(unpacked)
  if not head or not head:find(archive.opens_with, 1, true) then
    error("what arrived for " .. name .. " does not open like " .. name ..
          ":\n  expected " .. archive.opens_with .. " near the start.\n" ..
          "  upstream probably changed the format, or the URL now points\n" ..
          "  at something else entirely.")
  end
  if not tail or not tail:find(archive.closes_with, 1, true) then
    error("what arrived for " .. name .. " is not finished:\n" ..
          "  expected " .. archive.closes_with .. " at the end and it is not\n" ..
          "  there, so the download was cut off. try again.")
  end

  ok = os.execute("mv " .. shell_quote(unpacked) .. " " .. shell_quote(target))
  if not (ok == true or ok == 0) then
    error("could not move " .. name .. " into assets/")
  end
  os.remove(compressed)

  return {
    name = name, file = archive.file, url = archive.url,
    bytes = file_size(target), action = "fetched",
    taken = os.date("%Y-%m-%d %H:%M:%S"),
  }
end
-- }}}

-- {{{ M.require_archive(name)
-- The path to an archive, or an error saying how to get it.
--
-- Every reader calls this instead of building the path itself. A missing
-- archive is not a condition to work around -- there is no smaller set of
-- kanji to fall back to, and a program that carried on with an empty one would
-- report success having done nothing.
function M.require_archive(name)
  local settings = project.settings()
  local archive = settings.archives[name]
  if not archive then
    error("there is no archive called " .. tostring(name) ..
          "; input/settings.lua lists the ones there are")
  end
  local path = project.path("assets", archive.file)
  if not project.exists(path) then
    error("the " .. name .. " archive is not in assets/.\n" ..
          "  get it with:  luajit src/010-fetch-the-archives.lua")
  end
  return path
end
-- }}}

-- {{{ M.provenance()
-- What the provenance file currently says, as text, or nil.
function M.provenance()
  return project.read_file(project.path("assets", "archive-provenance.txt"))
end
-- }}}

-- {{{ M.fetch_all(options)
-- Both archives, and the provenance file written afterwards.
function M.fetch_all(options)
  local settings = project.settings()
  local results = {}
  -- sorted so the provenance file is written in a stable order and two runs
  -- produce the same bytes where nothing changed
  local names = {}
  for name in pairs(settings.archives) do names[#names + 1] = name end
  table.sort(names)

  for _, name in ipairs(names) do
    results[#results + 1] = M.fetch_one(name, settings.archives[name], options)
  end

  local lines = {
    "# the archives this project reads, and which editions are on disk",
    "#",
    "# written by src/010-fetch-the-archives.lua. a set of images is generated",
    "# against a specific dictionary, and this is how that is answerable later.",
    "",
  }
  for _, result in ipairs(results) do
    lines[#lines + 1] = result.name
    lines[#lines + 1] = "  from   " .. result.url
    lines[#lines + 1] = "  file   assets/" .. result.file
    lines[#lines + 1] = "  bytes  " .. tostring(result.bytes)
    lines[#lines + 1] = "  taken  " .. result.taken
    lines[#lines + 1] = ""
  end
  project.write_file(project.path("assets", "archive-provenance.txt"),
                     table.concat(lines, "\n"))
  return results
end
-- }}}

-- {{{ main(argv)
-- Run directly, this fetches. Loaded as a library, it does not.
local function main(argv)
  local options = project.arguments(argv)
  project.hello("010-fetch-the-archives")
  io.write("fetching the archives into " .. project.path("assets") .. "\n")

  local results = M.fetch_all({ force = options.force })

  local said = {}
  for _, result in ipairs(results) do
    local line = string.format("%-10s %-9s %9d bytes  %s",
                               result.name, result.action, result.bytes or 0,
                               result.file)
    io.write("  " .. line .. "\n")
    said[#said + 1] = line
  end
  io.write("provenance written to assets/archive-provenance.txt\n")
  said[#said + 1] = "provenance in assets/archive-provenance.txt"
  project.goodbye("010-fetch-the-archives", said)
end
-- }}}

if arg and arg[0] and arg[0]:find("010%-fetch%-the%-archives") then
  main(arg)
end

return M
