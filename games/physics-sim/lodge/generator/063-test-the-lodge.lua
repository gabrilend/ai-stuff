#!/usr/bin/env luajit
-- 063-test-the-lodge.lua
--
-- Builds small made-up lodges and checks the generator does what its
-- promises say: doors between rooms open, a link to a corner of a room lands
-- there and leaves a note on the way back, issue numbers find their files,
-- and -- the two that matter most -- a broken door or a line it does not
-- understand stops the build instead of being quietly smoothed over.
--
-- Run by `lodge/build --test`, which makes the scratch folders first.
--   luajit 063-test-the-lodge.lua PROJECT_DIR SCRATCH_DIR

local DIR = "/mnt/mtwo/programming/ai-stuff/games/physics-sim"
local SCRATCH = DIR .. "/tmp/lodge-test"
if arg[1] and arg[1] ~= "" then DIR = arg[1] end
if arg[2] and arg[2] ~= "" then SCRATCH = arg[2] end

local lodge = dofile(DIR .. "/lodge/generator/062-build-the-lodge.lua")

local PAGES = SCRATCH .. "/pages"
local OUT = SCRATCH .. "/out"
local passed, failed = 0, 0

-- {{{ local function write()
local function write(path, text)
  local handle = assert(io.open(path, "wb"))
  handle:write(text)
  handle:close()
end
-- }}}

-- {{{ local function read()
local function read(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ local function clear()
-- Removes the made-up rooms and pages between cases, so each case sees only
-- its own rooms. Files are removed one by one by name; no folder is touched.
local made = {}
local function clear()
  for _, path in ipairs(made) do
    os.remove(path)
  end
  made = {}
end
local function room(stem, text)
  write(PAGES .. "/" .. stem .. ".md", text)
  write(PAGES .. "/" .. stem .. ".css", "body { color: black; }\n")
  made[#made + 1] = PAGES .. "/" .. stem .. ".md"
  made[#made + 1] = PAGES .. "/" .. stem .. ".css"
  made[#made + 1] = OUT .. "/" .. stem .. ".html"
  made[#made + 1] = OUT .. "/" .. stem .. ".css"
end
-- }}}

-- {{{ local function check()
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    print("  ok    " .. name)
  else
    failed = failed + 1
    print("  FAIL  " .. name .. (detail and ("\n        " .. detail) or ""))
  end
end
-- }}}

-- {{{ local function build()
local function build()
  return pcall(lodge.build, { root = SCRATCH, pages_dir = PAGES, out_dir = OUT })
end
-- }}}

-- a made-up issue for mentions to find
write(SCRATCH .. "/issues/completed/606-ball-health.md", "# 606\n")
write(SCRATCH .. "/issues/221a-sleep.md", "# 221a\n")

print("lodge generator tests")

-- {{{ case: two rooms, a door each way, a section link with its note
clear()
room("001-front", table.concat({
  "# The front",
  "",
  "Go to [the back room](002-back.md) or straight to",
  "[the shelf](002-back.md#the-shelf).",
  "",
  "See issue 606 and issues 221a, 606 and 606.",
  "",
}, "\n"))
room("002-back", table.concat({
  "# The back",
  "",
  "## The shelf",
  "",
  "Jars.",
  "",
  "## The door",
  "",
  "Back to [the front](001-front.md).",
  "",
}, "\n"))
local ok, report = build()
check("two linked rooms build", ok, not ok and report or nil)
if ok then
  local front = read(OUT .. "/001-front.html")
  local back = read(OUT .. "/002-back.html")
  check("a door to a room becomes its page", front:find('href="002%-back%.html"', 1) ~= nil)
  check("a door to a section lands on it", front:find('href="002%-back%.html#the%-shelf"', 1) ~= nil)
  check("an issue mention links to its file", front:find('class="issue" href="[^"]*606%-ball%-health%.md"') ~= nil)
  local issue_links = select(2, front:gsub('class="issue"', ""))
  check("every number in an issue run is linked", issue_links == 4, "found " .. issue_links)
  local shelf = back:find('id="the%-shelf"')
  local note = back:find('class="pointed%-at"')
  local door = back:find('id="the%-door"')
  check("the shelf's note sits at the end of the shelf section",
    shelf and note and door and shelf < note and note < door)
  check("the note returns to the exact paragraph", back:find('href="001%-front%.html#b1"', 1) ~= nil)
  check("each room carries its own stylesheet", back:find('href="002%-back%.css"', 1) ~= nil)
  check("the rail marks the room being read", back:find('<li class="here"><span>The back</span>', 1, true) ~= nil)
end
-- }}}

-- {{{ case: a dead door stops the build and names every one
clear()
room("001-front", "# The front\n\n[gone](003-nowhere.md) and [also gone](../no/such/file.txt).\n\nissue 999\n")
ok, report = build()
check("a dead link stops the build", not ok)
check("every dead link is named",
  not ok and report:find("003%-nowhere") and report:find("no/such/file") and report:find("issue 999"),
  tostring(report))
-- }}}

-- {{{ case: a missing section stops the build
clear()
room("001-front", "# The front\n\n[x](002-back.md#no-such-corner)\n")
room("002-back", "# The back\n")
ok, report = build()
check("a link to a missing section stops the build", not ok and report:find("no%-such%-corner"), tostring(report))
-- }}}

-- {{{ case: a line shape outside the subset stops the build
clear()
room("001-front", "# The front\n\n<div>raw html</div>\n\n#### too deep\n")
ok, report = build()
check("an unknown line shape stops the build", not ok and report:find("001%-front%.md:3"), tostring(report))
check("every unknown line is named", not ok and report:find("001%-front%.md:5"), tostring(report))
-- }}}

-- {{{ case: a room with no stylesheet stops the build
clear()
write(PAGES .. "/001-bare.md", "# Bare\n")
made[#made + 1] = PAGES .. "/001-bare.md"
ok, report = build()
check("a room without its own stylesheet stops the build", not ok and report:find("no stylesheet"), tostring(report))
-- }}}

-- {{{ case: code spans are left alone
clear()
room("001-front", "# The front\n\nThe call `issue 606 [a](b.md) **x**` stays as written.\n")
ok, report = build()
check("code spans build", ok, not ok and report or nil)
if ok then
  local front = read(OUT .. "/001-front.html")
  check("nothing inside a code span is linked or bolded",
    front:find("<code>issue 606 %[a%]%(b%.md%) %*%*x%*%*</code>") ~= nil)
end
-- }}}

clear()
os.remove(OUT .. "/index.html")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
