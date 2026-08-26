-- 009-where-things-are.lua
--
-- The project root, the paths hanging off it, and the two rituals every program
-- in this project observes: read input/ before doing anything, write output/
-- goodbye on the way out.
--
-- For a general: every program here needs to find its own files, and needs to
-- agree with every other program about where they are. This is that agreement,
-- written once. It also loads the settings file, which is where every tunable
-- number in the project lives, so that no program carries its own copy of a
-- number somebody is going to want to change.

-- {{{ ONE OF THESE PER PROCESS, NOT ONE PER FILE THAT ASKS
--
-- Every source file in this project begins by loading this one, and every one
-- of them does it by running the file rather than by name -- because these
-- filenames carry their index and their hyphens, and bending them into module
-- identifiers would mean the name a person opens and the name a program uses
-- are two different strings.
--
-- Run twice, a file produces two of everything in it, and the caches below stop
-- being caches. That is wasteful and it is not the reason this matters.
--
-- The ordered table in `018` is recognised by its metatable, and a second copy
-- of `018` has a second metatable -- so an ordered table built through one copy
-- is not an ordered table to the other. The workflow emitter built its objects
-- through its own copy and handed them to a writer holding a different one,
-- which did not recognise them, decided they were empty arrays, and wrote every
-- node in the graph as `[]`. Nothing errored.
--
-- So: the first run registers itself where the interpreter keeps loaded
-- modules, and every run after it hands back the same one.
local ALREADY = package.loaded["kanji-learning-image-generator.project"]
if ALREADY then return ALREADY end
-- }}}

local M = {}

-- {{{ DEFAULT_ROOT -- the project root, hard-coded, overridable by --dir
--
-- Hard-coded because a script must run from any directory and produce the same
-- result. Overridable because a copy of this project somewhere else is still
-- this project.
local DEFAULT_ROOT = "/mnt/mtwo/programming/ai-stuff/kanji-learning-image-generator"
-- }}}

-- {{{ M.here()
-- The directory this very file is sitting in, asked of the interpreter.
--
-- WHY THIS EXISTS. Twenty-odd source files need to load their siblings, and the
-- alternative is the project root written into every one of them -- which is
-- twenty-odd copies of a path that is wrong the moment the project moves. A
-- file asking where it itself is cannot be wrong about it.
--
-- This answers "where is my sibling", which is a different question from "where
-- is the project root". The root is DEFAULT_ROOT above, and the two are
-- reconciled -- loudly -- in M.root().
--
-- The answer is made absolute before it leaves. The interpreter reports the
-- path it was handed, so `luajit src/009-...` reports `src` -- a real answer to
-- a different question, and one that makes the project root come out as the
-- word "src". Every relative path is relative to where the shell was standing,
-- so that is what gets prepended.
function M.here()
  local source = debug.getinfo(1, "S").source
  local path = source:match("^@(.*)/[^/]*$")
  if not path then
    error("009 cannot tell where it is; the interpreter reported source " ..
          tostring(source))
  end
  if path:sub(1, 1) ~= "/" then
    -- pwd -P, not pwd. The plain one reports the path the shell walked, which
    -- can run through a symlink or a bind mount; the physical one reports where
    -- the directory actually is. The root check below compares two paths for
    -- equality, and two spellings of one directory would fail that comparison
    -- and raise an alarm about nothing.
    local pipe = io.popen("pwd -P")
    local cwd = pipe:read("*l")
    pipe:close()
    path = cwd .. "/" .. path
  end
  return M.canonical(path)
end
-- }}}

-- {{{ M.canonical(path)
-- One path, in the one spelling the filesystem agrees is where it is.
--
-- Symlinks, bind mounts, `.`, `..` and doubled slashes all make a directory
-- answer to more than one name, and anything that compares paths as strings is
-- wrong in the presence of any of them. This project has exactly that situation
-- on the machine it was written on -- the same directory is reachable under two
-- different absolute paths -- so the comparison in M.root() had to be taught the
-- difference between a different place and a different spelling.
function M.canonical(path)
  local pipe = io.popen("readlink -f '" .. tostring(path):gsub("'", "'\\''") ..
                        "' 2>/dev/null")
  if pipe then
    local resolved = pipe:read("*l")
    pipe:close()
    if resolved and resolved ~= "" then return (resolved:gsub("/+$", "")) end
  end
  -- readlink is absent or the path does not exist yet. Tidy the spelling by
  -- hand and say so, because a path this project could not canonicalise is a
  -- path that may compare unequal to itself later.
  local tidied = tostring(path):gsub("/%./", "/"):gsub("/+$", "")
  while tidied:find("/[^/]+/%.%./") do
    tidied = tidied:gsub("/[^/]+/%.%./", "/", 1)
  end
  io.stderr:write("notice: could not resolve " .. tostring(path) ..
                  " to a real location; using " .. tidied .. "\n")
  return tidied
end
-- }}}

local resolved_root = nil
local root_warned = false

-- {{{ M.root()
-- The project root. Hard-coded, overridable, and checked against reality.
--
-- The check matters more than it looks. This file lives in <root>/src, so its
-- own location states a root, and the constant at the top states another. When
-- they disagree, somebody has moved or copied the project and the constant is
-- stale.
--
-- Neither answer is silently preferred. Preferring the constant would make a
-- moved copy read the original's data -- the worst possible outcome, because it
-- works. Preferring the location would make the constant decorative. So: the
-- location wins, because it is a fact rather than a claim, and the disagreement
-- is announced once, because a fallback that nobody is told about is a fallback
-- that becomes folklore.
function M.root()
  if resolved_root then return resolved_root end

  local from_location = M.here():gsub("/src$", "")
  if from_location ~= M.canonical(DEFAULT_ROOT) and not root_warned then
    root_warned = true
    io.stderr:write(
      "notice: this project is at " .. from_location .. ", but 009 was written\n" ..
      "        with " .. DEFAULT_ROOT .. " hard-coded in it. Using the real\n" ..
      "        location. Update DEFAULT_ROOT in src/009-where-things-are.lua\n" ..
      "        if the project has moved for good.\n")
  end
  resolved_root = from_location
  return resolved_root
end
-- }}}

-- {{{ M.set_root(path)
-- Point the project somewhere else. What --dir does.
function M.set_root(path)
  if type(path) ~= "string" or path == "" then
    error("set_root wants a path, got " .. tostring(path))
  end
  resolved_root = M.canonical(path)
end
-- }}}

-- {{{ M.path(...)
-- Join fragments onto the project root.
function M.path(...)
  local parts = { M.root() }
  for i = 1, select("#", ...) do
    local piece = select(i, ...)
    parts[#parts + 1] = (tostring(piece):gsub("^/+", ""):gsub("/+$", ""))
  end
  return table.concat(parts, "/")
end
-- }}}

-- {{{ M.exists(path)
function M.exists(path)
  local handle = io.open(path, "rb")
  if handle then handle:close() return true end
  -- a directory opens on some systems and not others, so ask the shell as well
  return os.execute('test -e "' .. path .. '"') == true
      or os.execute('test -e "' .. path .. '"') == 0
end
-- }}}

-- {{{ M.read_file(path)
-- The whole file as a string, or nil and a reason.
function M.read_file(path)
  local handle, why = io.open(path, "rb")
  if not handle then return nil, why end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ M.write_file(path, text)
-- Written to a neighbouring temporary name and renamed into place.
--
-- WHY THE RENAME. A run killed halfway leaves a half-written file that has the
-- right name and the wrong contents, and everything downstream treats it as
-- finished -- a truncated PNG renders as a broken image somebody spends an hour
-- investigating. A rename within a directory is atomic, so a file either has
-- all of its bytes or does not exist.
function M.write_file(path, text)
  local temporary = path .. ".partial"
  local handle, why = io.open(temporary, "wb")
  if not handle then
    error("cannot write " .. path .. ": " .. tostring(why))
  end
  handle:write(text)
  handle:close()
  local ok, reason = os.rename(temporary, path)
  if not ok then
    error("cannot put " .. path .. " into place: " .. tostring(reason))
  end
  return #text
end
-- }}}

-- {{{ M.ensure_directory(path)
function M.ensure_directory(path)
  os.execute('mkdir -p "' .. path .. '"')
  return path
end
-- }}}

-- {{{ M.scratch(name)
-- A path inside the RAM tier, with the whole symlink chain built if it is not
-- already there.
--
-- Two tiers, and they are different on purpose: /tmp/<project> is for anything
-- executable and /dev/shm/<project> is for artifacts and logs. The project's
-- tmp/ points at the first and tmp/shared-memory/ at the second. Everything
-- this project writes at runtime is an artifact, so everything goes to the
-- second one.
--
-- Rebuilt on demand rather than assumed, because both tiers are cleared by a
-- reboot and the first program to run afterwards should not be the one that
-- fails.
local PROJECT_NAME = "kanji-learning-image-generator"
function M.scratch(name)
  local exec_tier = "/tmp/" .. PROJECT_NAME
  local artifact_tier = "/dev/shm/" .. PROJECT_NAME
  os.execute('mkdir -p "' .. exec_tier .. '" "' .. artifact_tier .. '"')
  os.execute('ln -sfn "' .. artifact_tier .. '" "' .. exec_tier .. '/shared-memory"')
  os.execute('ln -sfn "' .. exec_tier .. '" "' .. M.root() .. '/tmp"')
  if name then
    local full = artifact_tier .. "/" .. name
    -- a name with directories in it needs those directories
    local parent = full:match("^(.*)/[^/]*$")
    if parent and parent ~= artifact_tier then
      os.execute('mkdir -p "' .. parent .. '"')
    end
    return full
  end
  return artifact_tier
end
-- }}}

local loaded = {}

-- {{{ M.load(name)
-- Load a sibling source file by its indexed name, once.
--
-- `require` is not used because these filenames carry their index and their
-- hyphens -- 016-the-grey-canvas -- and those are the names the project reads
-- itself by. Bending them into module identifiers would mean the file a person
-- opens and the name a program uses are two different strings.
function M.load(name)
  if loaded[name] then return loaded[name] end
  local file = M.here() .. "/" .. name .. ".lua"
  local chunk, why = loadfile(file)
  if not chunk then
    error("cannot load " .. name .. ": " .. tostring(why))
  end
  local module = chunk()
  loaded[name] = module
  return module
end
-- }}}

-- {{{ M.arguments(argv)
-- The command line as a table. --key value, --flag, and bare words in order.
--
-- --dir is consumed here rather than by every program separately, because every
-- program accepts it and none of them should have to remember to.
function M.arguments(argv)
  local out = { words = {} }
  local index = 1
  while argv and index <= #argv do
    local item = argv[index]
    local key = item:match("^%-%-([%w%-_]+)$")
    if key then
      key = key:gsub("%-", "_")
      local next_item = argv[index + 1]
      -- a flag is a --key with nothing after it, or with another --key after
      -- it. a setting is a --key with a value after it. distinguishing them
      -- here means no program has to.
      if next_item and not next_item:match("^%-%-") then
        out[key] = next_item
        index = index + 2
      else
        out[key] = true
        index = index + 1
      end
    else
      out.words[#out.words + 1] = item
      index = index + 1
    end
  end
  if type(out.dir) == "string" then M.set_root(out.dir) end
  return out
end
-- }}}

local settings_cache = nil

-- {{{ M.settings()
-- Every tunable number in the project, read from input/settings.lua.
--
-- Read rather than defaulted. A program that carries its own copy of a blur
-- radius is a program that ignores the one place a person went to change it,
-- and the symptom of that is images that do not respond to the settings file.
function M.settings()
  if settings_cache then return settings_cache end
  local file = M.path("input", "settings.lua")
  local chunk, why = loadfile(file)
  if not chunk then
    error("the settings file is missing or will not parse: " .. tostring(why) ..
          "\n  every knob in this project lives in input/settings.lua;" ..
          "\n  docs/balance-updates.md says what each one is for.")
  end
  settings_cache = chunk()
  if type(settings_cache) ~= "table" then
    error("input/settings.lua must return a table")
  end
  return settings_cache
end
-- }}}

-- {{{ M.hello(program)
-- The startup ritual: read input/, say what was found, hand back the settings.
--
-- The first thing a program does is read the input directory. That is where it
-- learns how to start up; nothing here decides anything for itself that the
-- input directory could have decided.
-- The files this project knows how to read out of input/. Anything else in
-- there is something a person put there for a program to find, and naming it is
-- how they learn whether any program saw it.
--
-- The list is here rather than absent because a notice that fires on every run
-- is a notice nobody reads -- and one that fires on every run *of every worker
-- in a batch* is worse than that, since it drowns the report.
local EXPECTED_INPUT = {
  ["settings.lua"] = true,
  ["phrases.lua"] = true,
  ["arguments"] = true,
}

function M.hello(program)
  local settings = M.settings()
  local listing = io.popen('ls -1 "' .. M.path("input") .. '" 2>/dev/null')
  local others = {}
  if listing then
    for line in listing:lines() do
      if line ~= "" and not EXPECTED_INPUT[line] then
        others[#others + 1] = line
      end
    end
    listing:close()
  end
  if #others > 0 then
    io.stderr:write(program .. ": input/ also holds " ..
                    table.concat(others, ", ") ..
                    ", which nothing here reads\n")
  end
  return settings
end
-- }}}

-- {{{ M.goodbye(program, lines)
-- The last thing a program does: leave word in output/ of what it did.
--
-- output/ is a mailbox, not a record. Whatever ran last is what is in there,
-- and the next program overwrites it. It is for the person who walked away
-- while something was running and wants to know how it went.
function M.goodbye(program, lines)
  M.ensure_directory(M.path("output"))
  local text = {}
  text[#text + 1] = "goodbye from " .. program
  text[#text + 1] = os.date("%Y-%m-%d %H:%M:%S")
  text[#text + 1] = ""
  for _, line in ipairs(lines or {}) do text[#text + 1] = line end
  text[#text + 1] = ""
  M.write_file(M.path("output", "goodbye"), table.concat(text, "\n"))
end
-- }}}

package.loaded["kanji-learning-image-generator.project"] = M

return M
