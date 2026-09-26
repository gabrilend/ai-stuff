#!/usr/bin/env luajit
-- test-transcript-site.lua
--
-- Checks the shared transcript pages (issue 035): that the reader reads what
-- the exporter writes - including the shapes other projects hold and
-- double-diaper-dungeon's never did - and that a whole project builds into
-- pages whose links land where they should.
--
-- In general terms: it feeds the reader small hand-made transcripts, each
-- built to show one shape, then builds a throwaway project inside a
-- throwaway repository and looks at the pages that come out.
--
-- Run: luajit test-transcript-site.lua [scripts-dir]

-- {{{ paths
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local SITE = DIR .. "/transcript-site"
local SCRATCH = (os.getenv("TMPDIR") or "/tmp") .. "/transcript-site-test-" .. os.time()
-- }}}

local reader = dofile(SITE .. "/transcript-reader.lua")
local page = dofile(SITE .. "/conversation-page.lua")

local failures = 0

-- {{{ local function check()
local function check(description, got, wanted)
  if got == wanted then
    print("  ok        " .. description)
  else
    failures = failures + 1
    print(string.format("  FAILED    %s\n              got    [%s]\n              wanted [%s]",
      description, tostring(got), tostring(wanted)))
  end
end
-- }}}

local RULE = string.rep("-", 80)

-- {{{ local function transcript()
-- Builds a transcript the way the exporter lays one out: header lines, an
-- optional block above the first rule, then each turn under a rule and a
-- blank line. `parts` is a list of { heading, body }.
local function transcript(opts, parts)
  local out = { "# Conversation Summary: " .. (opts.id or "test-session-id"), "" }
  if opts.generated ~= false then out[#out + 1] = "Generated on: 2026-09-26 10:00:00" end
  if opts.models then out[#out + 1] = "Models: " .. opts.models end
  out[#out + 1] = ""
  if opts.above_rule then
    out[#out + 1] = opts.above_rule
    out[#out + 1] = ""
  end
  out[#out + 1] = RULE
  out[#out + 1] = ""
  if opts.before_first then
    out[#out + 1] = opts.before_first
    out[#out + 1] = ""
    out[#out + 1] = RULE
    out[#out + 1] = ""
  end
  for _, part in ipairs(parts) do
    out[#out + 1] = "### " .. part[1]
    out[#out + 1] = ""
    out[#out + 1] = part[2]
    out[#out + 1] = ""
    out[#out + 1] = RULE
    out[#out + 1] = ""
  end
  return table.concat(out, "\n")
end
-- }}}

-- {{{ local function refuses()
local function refuses(description, text, complaint)
  local ok, err = pcall(reader.read, text)
  check(description, (not ok) and tostring(err):find(complaint, 1, true) ~= nil, true)
end
-- }}}

print("== the reader: shapes every project's transcripts hold ==")

local basic = reader.read(transcript({ models = "claude-opus-5-5, claude-fable-5-1" }, {
  { "User Request 1", "hello" },
  { "Assistant Response 1", "hi there" },
  { "User Request 2", "again" },
  { "Assistant Response 2", "*model: claude-fable-5-1*\n\nhi from fable" },
}))
check("four turns in file order", #basic.exchanges, 4)
check("the first reply is served by the header's first model", basic.exchanges[2].model, "claude-opus-5-5")
check("a model marker changes the model from there on", basic.exchanges[4].model, "claude-fable-5-1")
check("a user turn has no model", basic.exchanges[1].model, nil)

local prose_heading = reader.read(transcript({ models = "m" }, {
  { "User Request 1", "lay it out" },
  { "Assistant Response 1", "Here is the plan.\n\n### Directory Layout\n\n- src/\n\n### 401a-core-fixed-timestep-loop\n\ndone" },
}))
check("a ### heading the model wrote in its prose is body, not a turn", #prose_heading.exchanges, 2)
check("... and stays in the reply's text",
  prose_heading.exchanges[2].body:find("### Directory Layout", 1, true) ~= nil, true)

local no_models = reader.read(transcript({}, {
  { "User Request 1", "hello" }, { "Assistant Response 1", "hi" },
}))
check("no models line: read, with an empty model list", #no_models.models, 0)
check("no models line: the header is still complete", no_models.header_complete, true)

refuses("no generated-on line, not archived: refused",
  transcript({ generated = false, models = "m" }, { { "User Request 1", "x" } }),
  "no generated-on line")

reader.use_archived_list({ ["old-one"] = true })
local archived = reader.read(transcript({ id = "old-one", generated = false }, {
  { "User Request 1", "x" }, { "Assistant Response 1", "y" },
}))
check("no generated-on line, archived: read", archived.generated_on, nil)
check("... and marked as an incomplete header", archived.header_complete, false)
reader.use_archived_list({})

refuses("a heading of an unknown shape under a rule is refused",
  transcript({ models = "m" }, { { "Something New 1", "x" } }), "unrecognised transcript heading")

local with_harness = reader.read(transcript({ models = "m", before_first = "`/model` - Set model to opus" }, {
  { "User Request 1", "hello" }, { "Assistant Response 1", "hi" },
}))
check("lines above the first request become a harness turn", with_harness.exchanges[1].kind, "harness")
check("... holding exactly those lines", with_harness.exchanges[1].body, "`/model` - Set model to opus")
check("no harness lines: no harness turn", basic.exchanges[1].kind, "user")

local contents_block = table.concat({
  "## Contents",
  "",
  "1. 2026-09-23 15:40, before Request 1 - Nothing yet.",
  "2. 2026-09-23 16:33, after Request 1 - I reviewed the README - and found",
  "   stale figures. Next: the folder question.",
  "3. 2026-09-23 21:35, after Request 2 - Done.",
}, "\n")
local with_contents = reader.read(transcript({ models = "m", above_rule = contents_block }, {
  { "User Request 1", "a" }, { "Assistant Response 1", "b" },
  { "User Request 2", "c" }, { "Assistant Response 2", "d" },
}))
check("three Contents entries", #with_contents.contents, 3)
check("'before Request 1' reads as zero", with_contents.contents[1].after_request, 0)
check("a wrapped entry is joined, and a ' - ' inside it is kept",
  with_contents.contents[2].text, "I reviewed the README - and found stale figures. Next: the folder question.")
check("the entry's time is read", with_contents.contents[2].when, "2026-09-23 16:33")
check("the Contents section is not a turn", with_contents.exchanges[1].kind, "user")
check("'after Request 1' lands on Request 2's turn", reader.turn_after_request(with_contents, 1), 3)
check("'after' the last request lands on the last turn", reader.turn_after_request(with_contents, 2), 4)
check("'before Request 1' lands on Request 1's turn", reader.turn_after_request(with_contents, 0), 1)

refuses("a Contents entry of an unknown shape is refused",
  transcript({ models = "m", above_rule = "## Contents\n\n1. yesterday - something" }, { { "User Request 1", "x" } }),
  "unrecognised Contents entry")

print("== the page ==")

local html = page.render(with_contents, { title = "t" })
check("the Contents list is drawn", html:find('<nav class="contents">', 1, true) ~= nil, true)
check("an entry links to the turn after its request", html:find('<a href="#turn-3">after Request 1</a>', 1, true) ~= nil, true)
check("... and that turn carries the id", html:find('<section id="turn-3" class="turn said">', 1, true) ~= nil, true)
check("no recaps: no Contents list", page.render(basic, {}):find('<nav class="contents">', 1, true) == nil, true)

local linking = reader.read(transcript({ models = "m" }, {
  { "User Request 1", "go" },
  { "Assistant Response 1", "*[background task] Agent \"Review\" finished — [review-sep-1-26.md](review-sep-1-26.md)*\n\nSee [the docs](docs/x.md) and [a site](https://e.org/y.md)." },
}))
local linked_html = page.render(linking, {})
check("a link to a sibling transcript points at its page", linked_html:find('href="review-sep-1-26.html"', 1, true) ~= nil, true)
check("a link into a folder is left alone", linked_html:find('href="docs/x.md"', 1, true) ~= nil, true)
check("a link to another site is left alone", linked_html:find('href="https://e.org/y.md"', 1, true) ~= nil, true)

check("facts: no models line reads 'no model named'", page.render(no_models, {}):find("no model named", 1, true) ~= nil, true)
check("facts: an archived transcript reads 'not recorded'", page.render(archived, {}):find("date not recorded", 1, true) ~= nil, true)

print("== a whole project, inside a larger repository ==")

-- The larger repository holds two projects; the build of one must see only
-- its own commits, with its own paths, as a project in the monorepo would.
local project = SCRATCH .. "/repo/one-project"
os.execute("mkdir -p '" .. project .. "/llm-transcripts' '" .. SCRATCH .. "/repo/other-project'")
local function write(path, text)
  local f = assert(io.open(path, "w")); f:write(text); f:close()
end
local function git(args)
  return os.execute("git -C '" .. SCRATCH .. "/repo' " .. args .. " > /dev/null")
end
git("init -q")
git("config user.email t@t")
git("config user.name t")
local function head()
  local pipe = io.popen("git -C '" .. SCRATCH .. "/repo' rev-parse HEAD")
  local hash = pipe:read("*l"); pipe:close()
  return hash
end

-- 1. Code with no transcript yet; the conversation that made it records its
--    hash in a later commit, which saves that conversation's transcript.
write(SCRATCH .. "/repo/other-project/x.txt", "x\n")
write(project .. "/code.lua", "return 1\n")
git("add -A")
git("commit -q -m 'Recorded work' -m 'The body of the first commit.'")
local recorded_hash = head():sub(1, 9)
write(project .. "/llm-transcripts/sep-1-26.md", transcript({ models = "m", above_rule = contents_block }, {
  { "User Request 1", "build it" },
  { "Assistant Response 1", "built\n\n*[commit] " .. recorded_hash .. " in repo - Recorded work*" },
  { "User Request 2", "more" },
  { "Assistant Response 2", "done, see [the helper](review-sep-1-26.md)" },
}))
write(project .. "/llm-transcripts/wordcloud.md", "not a transcript\n")
git("add -A")
git("commit -q -m 'Save the conversation'")
-- 2. A commit that saves only a helper's transcript: its parent made it.
write(project .. "/llm-transcripts/review-sep-1-26.md", transcript({ id = "agent-abc", models = "m" }, {
  { "User Request 1", "review" }, { "Assistant Response 1", "reviewed" },
}))
git("add -A")
git("commit -q -m 'Helper saved'")
-- 3. A bulk re-save of two main conversations: nobody can be named.
write(project .. "/llm-transcripts/sep-2-26.md", transcript({ id = "second", models = "m" }, {
  { "User Request 1", "x" }, { "Assistant Response 1", "y" },
}))
write(project .. "/llm-transcripts/sep-1-26.md", io.open(project .. "/llm-transcripts/sep-1-26.md"):read("*a") .. "\n")
git("add -A")
git("commit -q -m 'Rebuild every transcript'")
-- 4. Code with no transcript at all.
write(project .. "/code.lua", "return 2\n")
git("add -A")
git("commit -q -m 'Code without a conversation'")

local run = io.popen("'" .. SITE .. "/build-transcript-pages' '" .. project .. "' 2>&1")
local report = run:read("*a")
local ok = run:close()
check("the build succeeds", ok == true or ok == 0, true)
check("it reports three conversations", report:find("conversations  3", 1, true) ~= nil, true)
check("it counts the five commits that touched this project, not the repository's",
  report:find("commits        5", 1, true) ~= nil, true)
check("it names the file that is not a transcript", report:find("wordcloud.md", 1, true) ~= nil, true)
check("one commit is known from a transcript's own record",
  report:find("records making          1", 1, true) ~= nil, true)
check("two are known by the one transcript they saved (one through a helper)",
  report:find("they saved 2", 1, true) ~= nil, true)
check("two have no conversation recorded (the bulk re-save and the bare code)",
  report:find("recorded         2", 1, true) ~= nil, true)

local out = SCRATCH .. "/repo/one-project/llm-transcripts/HTML"
local index = io.open(out .. "/index.html"):read("*a")
check("the front page links the conversation", index:find('href="sep-1-26.html"', 1, true) ~= nil, true)
check("a recorded commit links to the turn that made it",
  index:find('href="sep-1-26.html#turn-2"', 1, true) ~= nil, true)
check("the helper's commit is drawn with its parent, not the helper",
  index:find("review-sep-1-26.html", 1, true) == nil, true)
check("the bulk re-save and the bare code say no conversation is recorded",
  select(2, index:gsub("No conversation is recorded", "")) == 1, true)
check("the front page shows the commit subject", index:find("Recorded work", 1, true) ~= nil, true)
check("the conversation's page exists", io.open(out .. "/sep-1-26.html") ~= nil, true)
check("the font is written beside the pages", io.open(out .. "/fonts/HackNerdFont-Regular.ttf") ~= nil
  and io.open(out .. "/fonts/HackNerdFont-Bold.ttf") ~= nil, true)

print("== the push hook ==")

local function run_quiet(command)
  local pipe = io.popen(command .. " 2>&1")
  local text = pipe:read("*a")
  local done = pipe:close()
  return text, (done == true or done == 0)
end

local repo = SCRATCH .. "/repo"
local hook = repo .. "/.git/hooks/pre-push"
local said_install = run_quiet("'" .. SITE .. "/install-pages-hook' '" .. repo .. "'")
check("the installer installs", said_install:find("installed", 1, true) ~= nil, true)
check("the hook runs the page builder", io.open(hook):read("*a"):find("build-pages-before-push", 1, true) ~= nil, true)
local ignore = io.open(repo .. "/.gitignore"):read("*a")
check("the pages are ignored by git", ignore:find("**/llm-transcripts/HTML/", 1, true) ~= nil, true)
run_quiet("'" .. SITE .. "/install-pages-hook' '" .. repo .. "'")
local _, lines = io.open(repo .. "/.gitignore"):read("*a"):gsub("llm%-transcripts/HTML", "")
check("a second install adds nothing", lines, 1)
local ignored = run_quiet("git -C '" .. repo .. "' check-ignore one-project/llm-transcripts/HTML/index.html")
check("git really ignores a page", ignored:find("index.html", 1, true) ~= nil, true)

local said_build, built_ok = run_quiet("'" .. SITE .. "/build-pages-before-push' '" .. repo .. "'")
check("the hook's builder succeeds", built_ok, true)
check("pages just built are already current", said_build:find("0 rebuilt, 1 already current", 1, true) ~= nil, true)
os.execute("touch '" .. project .. "/llm-transcripts/sep-2-26.md'")
os.execute("sleep 1; touch '" .. project .. "/llm-transcripts/sep-2-26.md'")
said_build = run_quiet("'" .. SITE .. "/build-pages-before-push' '" .. repo .. "'")
check("a newer transcript makes the pages rebuild", said_build:find("1 rebuilt", 1, true) ~= nil, true)

-- Someone else's hook is left exactly as it was.
local foreign = "#!/bin/bash\n# someone else's hook\n"
write(hook, foreign)
local said_skip = run_quiet("'" .. SITE .. "/install-pages-hook' '" .. repo .. "'")
check("another tool's pre-push hook is reported", said_skip:find("left as it is", 1, true) ~= nil, true)
check("... and left untouched", io.open(hook):read("*a"), foreign)

os.execute("rm -rf '" .. SCRATCH .. "'")

print("")
if failures == 0 then
  print("all good")
  os.exit(0)
end
print(failures .. " failed")
os.exit(1)
