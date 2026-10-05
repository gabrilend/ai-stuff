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

local reader = dofile(SITE .. "/conversation/transcript-reader.lua")
local page = dofile(SITE .. "/conversation/conversation-page.lua")

-- The page is handed its colours; any :root block will do for these checks.
local COLOURS = ":root { --plain: #ccc; }"

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

local html = page.render(with_contents, { title = "t", colours_css = COLOURS })
check("the Contents list is drawn", html:find('<nav class="contents">', 1, true) ~= nil, true)
check("an entry links to the turn after its request", html:find('<a href="#turn-3">after Request 1</a>', 1, true) ~= nil, true)
check("... and that turn carries the id", html:find('<section id="turn-3" class="turn said">', 1, true) ~= nil, true)
check("no recaps: no Contents list", page.render(basic, { colours_css = COLOURS }):find('<nav class="contents">', 1, true) == nil, true)

local linking = reader.read(transcript({ models = "m" }, {
  { "User Request 1", "go" },
  { "Assistant Response 1", "*[background task] Agent \"Review\" finished — [review-sep-1-26.md](review-sep-1-26.md)*\n\nSee [the docs](docs/x.md) and [a site](https://e.org/y.md)." },
}))
local linked_html = page.render(linking, { colours_css = COLOURS })
check("a link to a sibling transcript points at its page", linked_html:find('href="review-sep-1-26.html"', 1, true) ~= nil, true)
check("a link into a folder is left alone", linked_html:find('href="docs/x.md"', 1, true) ~= nil, true)
check("a link to another site is left alone", linked_html:find('href="https://e.org/y.md"', 1, true) ~= nil, true)

check("facts: no models line reads 'no model named'", page.render(no_models, { colours_css = COLOURS }):find("no model named", 1, true) ~= nil, true)
check("facts: an archived transcript reads 'not recorded'", page.render(archived, { colours_css = COLOURS }):find("date not recorded", 1, true) ~= nil, true)

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
git("commit -q -m 'Rebuild every transcript' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'")
-- 4. Code with no transcript at all.
write(project .. "/code.lua", "return 2\n")
git("add -A")
git("commit -q -m 'Code without a conversation' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'")

local run = io.popen("'" .. SITE .. "/build-transcript-pages' '" .. project .. "' 2>&1")
local report = run:read("*a")
local ok = run:close()
check("the build succeeds", ok == true or ok == 0, true)
check("it reports three conversations", report:find("conversations  3", 1, true) ~= nil, true)
check("it counts the five commits that touched this project, not the repository's",
  report:find("commits        5", 1, true) ~= nil, true)
check("it names the file that is not a transcript", report:find("wordcloud.md", 1, true) ~= nil, true)
check("one commit is known from a transcript's own record",
  report:find("by recorded   1", 1, true) ~= nil, true)
check("two are known by the one transcript they saved (one through a helper)",
  report:find("by saved      2", 1, true) ~= nil, true)
check("two have no conversation recorded (the bulk re-save and the bare code)",
  report:find("commits linked 3 of 5", 1, true) ~= nil, true)

local out = SCRATCH .. "/repo/one-project/llm-transcripts/HTML"
local index = io.open(out .. "/index.html"):read("*a")
check("the front page links the conversation", index:find('href="sep-1-26.html"', 1, true) ~= nil, true)
check("a recorded commit's button lands on its commit line",
  index:find('href="sep-1-26.html#commit-' .. recorded_hash:sub(1, 7) .. '"', 1, true) ~= nil, true)
check("... and the conversation page has that line's id",
  io.open(out .. "/sep-1-26.html"):read("*a"):find('id="commit-' .. recorded_hash:sub(1, 7) .. '"', 1, true) ~= nil, true)
check("a saved commit's button opens the page at its top",
  index:find('<a class="transcript" href="sep-1-26.html">transcript</a>', 1, true) ~= nil, true)
check("the helper's commit is drawn with its parent, not the helper",
  index:find("review-sep-1-26.html", 1, true) == nil, true)
check("the bulk re-save and the bare code say no conversation mentions them",
  select(2, index:gsub("no saved conversation mentions these", "")) == 1, true)
check("a commit with a body shows its body", index:find("The body of the first commit.", 1, true) ~= nil, true)
check("a commit without one shows its subject", index:find("Code without a conversation", 1, true) ~= nil, true)
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

print("== three parts that never meet (issue 035a) ==")

-- Every Lua file in a part folder is read for the name of a sibling part
-- folder. The parts take plain tables in and hand plain tables or strings
-- out; only build-site.lua joins them.
local PARTS = { "conversation", "contents", "films" }
for _, part in ipairs(PARTS) do
  local listing = io.popen("ls '" .. SITE .. "/" .. part .. "'/*.lua")
  local reaches = {}
  for path in listing:lines() do
    local text = io.open(path):read("*a")
    for _, other in ipairs(PARTS) do
      if other ~= part and (text:find(other .. "/", 1, true) and text:find("dofile", 1, true)) then
        for line in text:gmatch("[^\n]+") do
          if line:find("dofile", 1, true) and line:find(other .. "/", 1, true) then
            reaches[#reaches + 1] = path:match("[^/]+$") .. " -> " .. other
          end
        end
      end
    end
  end
  listing:close()
  check(part .. "/ loads no other part", table.concat(reaches, ", "), "")
end

print("== the conversation page meets the game's (issue 035c) ==")

local with_commit = reader.read(transcript({ models = "m" }, {
  { "User Request 1", "go" },
  { "Assistant Response 1", "done\n\n*[commit] abcdef123 - A thing*" },
}))
local filmed = page.render(with_commit, { colours_css = COLOURS, films = { "a.gif", "b.gif" },
  film_size = 128, base_path = "../.." })
check("a commit line carries its id", filmed:find('<em class="commit-mark" id="commit-abcdef1">', 1, true) ~= nil, true)
check("the id comes from one rule", page.commit_anchor("abcdef123"), "commit-abcdef1")
check("her message has its film, at the site root",
  filmed:find('<img class="film" src="../../films/a.gif" alt="" width="128" height="128" loading="lazy">', 1, true) ~= nil, true)
check("... and the turn is marked as filmed", filmed:find('class="turn said has-film"', 1, true) ~= nil, true)
local unfilmed = page.render(with_commit, { colours_css = COLOURS })
check("no films: no film", unfilmed:find('class="film"', 1, true) == nil, true)
check("a page with no Contents list carries none of its rules", unfilmed:find(".contents {", 1, true) == nil, true)
check("a page with no harness turn carries none of its rules", unfilmed:find(".harness {", 1, true) == nil, true)
check("a page with a Contents list carries its rules", html:find(".contents {", 1, true) ~= nil, true)
local coded = page.render(reader.read(transcript({ models = "m" }, {
  { "User Request 1", "go" },
  { "Assistant Response 1", "One file, `README.md`, written by hand.\n\n`★ Insight ─────`" },
})), { colours_css = COLOURS })
check("code inside a sentence stays in the sentence",
  coded:find("<p>One file, <code>README.md</code>, written by hand.</p>", 1, true) ~= nil, true)
check("a paragraph of one code span alone is marked to run wide",
  coded:find('<p class="code-line"><code>★ Insight ─────</code></p>', 1, true) ~= nil, true)
check("and no rule makes every lone element a block any more",
  coded:find("code:only-child {", 1, true) == nil, true)
check("her quoted lines are a quieter green, on every page",
  unfilmed:find(".said .what blockquote { color: color-mix(in srgb, var(--dexterity) 60%, #555555); }", 1, true) ~= nil, true)
check("no colours is refused, not drawn black on black",
  pcall(page.render, with_commit, {}), false)

print("== the settings (issue 035e) ==")

local settings_reader = dofile(SITE .. "/settings.lua")
local site = dofile(SITE .. "/build-site.lua")
check("the route up from the root", settings_reader.route_up(""), ".")
check("the route up from one folder", settings_reader.route_up("story"), "..")
check("the route up from two", settings_reader.route_up("site/story"), "../..")
check("an unknown field is refused", (pcall(settings_reader.resolve, "/p", { titel = "x" })), false)
check("a field of the wrong kind is refused", (pcall(settings_reader.resolve, "/p", { pages = 3 })), false)
check("a films table missing a field is refused", (pcall(settings_reader.resolve, "/p", { films = { server = "x" } })), false)
local defaults = settings_reader.resolve("/p/proj", {})
check("the default transcripts folder", defaults.transcripts, "/p/proj/llm-transcripts")
check("the default output", defaults.output, "/p/proj/llm-transcripts/HTML")
check("the default history is the project", defaults.history, "/p/proj")
check("the default title", defaults.title, "How proj got made")
check("no films unless asked", defaults.films, nil)
check("every attribution rule by default", table.concat(defaults.attribution, ","), "recorded,subject,saved")

local harnessed = reader.read(transcript({ models = "m", before_first = "*[slash command] /x*" },
  { { "User Request 1", "a" }, { "Assistant Response 1", "b" } }))
local before_count = #harnessed.exchanges
site.shape(harnessed, settings_reader.resolve("/p", { harness_lines = false, recap_contents = false }))
check("harness lines off: the harness turn is taken out", #harnessed.exchanges, before_count - 1)
check("... before anything numbers the turns", harnessed.exchanges[1].kind, "user")

print("== the story page for every project (issue 035b) ==")

-- A mirror-shaped repository: its own top, commits carrying "Mirrored-from:",
-- one of them empty. Read whole, empty commits included, matched by source.
local mirror = SCRATCH .. "/mirror"
os.execute("mkdir -p '" .. mirror .. "/llm-transcripts'")
local function mgit(args)
  return os.execute("git -C '" .. mirror .. "' " .. args .. " > /dev/null")
end
mgit("init -q")
mgit("config user.email t@t")
mgit("config user.name t")
write(mirror .. "/llm-transcripts/oct-1-26.md", transcript({ models = "m" }, {
  { "User Request 1", "make it" },
  { "Assistant Response 1", "made\n\n*[commit] 1234567aa - First thing*" },
}))
mgit("add -A")
mgit("commit -q -m 'First thing' -m 'What the first thing did.' -m 'Mirrored-from: 1234567aabbccdd' -m 'Co-Authored-By: x <y>'")
mgit("commit -q --allow-empty -m 'Second thing' -m 'Mirrored-from: 9999999aabbccdd'")
-- A body with a line that looks like a path: it once ended the body there.
mgit("commit -q --allow-empty -m 'Third thing' -m 'Pages can be read in" .. "\n"
  .. "llm-transcripts/HTML/, built by the builder.' -m 'Mirrored-from: 3333333aabbccdd'")
local history = dofile(SITE .. "/contents/commit-history.lua")
local attribution = dofile(SITE .. "/contents/attribution.lua")
local mirrored = history.read(mirror)
check("a mirror's empty commits are read", #mirrored, 3)
check("a body line that looks like a path stays in the body",
  mirrored[3].body, "Pages can be read in\nllm-transcripts/HTML/, built by the builder.")
check("... and the trailer below it is still read", mirrored[3].source, "3333333aabbccdd")
check("the files a commit touched are still found", #mirrored[1].transcripts, 1)
check("a commit's source is its Mirrored-from hash", mirrored[1].source, "1234567aabbccdd")
check("the machine trailers leave the body", mirrored[1].body, "What the first thing did.")
check("a commit with no trailer is its own source",
  history.read(project)[1].source == history.read(project)[1].hash, true)
local evidence = { by_hash = { ["1234567"] = { key = "llm-transcripts/oct-1-26.md", anchor = "commit-1234567", hash = "1234567aa" } },
  by_subject = { ["Second thing"] = { { key = "llm-transcripts/oct-1-26.md", anchor = "commit-x" } } },
  parent_of = {}, is_main = {} }
attribution.attribute(mirrored, evidence, { "recorded" })
check("recorded only: the recorded commit is attributed", mirrored[1].how, "recorded")
check("recorded only: the subject match is not used", mirrored[2].how, nil)
attribution.attribute(mirrored, evidence, { "recorded", "subject" })
check("with the subject rule: it is", mirrored[2].how, "subject")
check("an unknown rule is refused", (pcall(attribution.attribute, mirrored, evidence, { "guess" })), false)
local recorded_only = {
  { hash = "a", source = "a", subject = "s", date = "d", transcripts = {}, conversation = "k", anchor = "commit-a" },
}
local contents = dofile(SITE .. "/contents/contents-page.lua")
local filed = contents.render(attribution.group(recorded_only),
  { k = { href = "x.html", title = "x", elsewhere = "other-project" } }, { colours_css = COLOURS })
check("a conversation filed elsewhere says where", filed:find("(filed under other-project)", 1, true) ~= nil, true)
check("... and only then carries that rule", filed:find(".where-filed", 1, true) ~= nil, true)
local gone = contents.render(attribution.group(recorded_only), {}, { colours_css = COLOURS })
check("a conversation whose transcript is gone says so",
  gone:find("written under a name the project no longer carries", 1, true) ~= nil, true)
check("... and its button is dimmed", gone:find('class="no-transcript"', 1, true) ~= nil, true)

local two_record = site.gather_evidence({
  { name = "a.md", conversation = reader.read(transcript({ models = "m" },
    { { "Assistant Response 1", "*[commit] 2222222aa - y*" } })) },
  { name = "b.md", conversation = reader.read(transcript({ models = "m" },
    { { "Assistant Response 1", "*[commit] 2222222 - y again*" } })) },
}, function(name) return "llm-transcripts/" .. name end)
check("a hash recorded in two transcripts belongs to the first",
  two_record.by_hash["2222222"].key, "llm-transcripts/a.md")
check("... and lands on the line's id", two_record.by_hash["2222222"].anchor, "commit-2222222")

print("== the films' rules, with no model (issue 035d) ==")

local matcher = dofile(SITE .. "/films/film-matcher.lua")
check("the same direction scores one", matcher.cosine({ 1, 0 }, { 2, 0 }), 1)
check("unrelated directions score zero", matcher.cosine({ 1, 0 }, { 0, 3 }), 0)
local three = { { hash = "a", vector = { 1, 0 } }, { hash = "b", vector = { 0.9, 0.1 } }, { hash = "c", vector = { 0, 1 } } }
local chosen = matcher.choose({ "m1", "m2" }, {}, three, { m1 = { 1, 0 }, m2 = { 1, 0 } }, 1)
check("the nearest film wins", chosen[1], "a")
check("neighbours always look different", chosen[2], "b")
local twins = reader.read(transcript({ models = "m" }, {
  { "User Request 1", "same" }, { "Assistant Response 1", "x" }, { "User Request 2", "same" },
}))
local keys = matcher.message_keys(twins, SCRATCH .. "/keys")
check("the same words said twice get two keys", keys[3], keys[1] .. ":2")
check("a harness turn gets no film, by its own row",
  matcher.message_keys(with_harness, SCRATCH .. "/keys")[1], false)
local choices = SCRATCH .. "/choices/one.tsv"
matcher.add_choices(choices, { { key = "aa", hash = "bb" } })
matcher.add_choices(choices, { { key = "cc", hash = "dd" } })
local stored = matcher.read_choices(choices)
check("the choices file only grows", stored.aa == "bb" and stored.cc == "dd", true)

print("== what no conversation of the project made (issue 040) ==")

-- A project of its own: a document an assistant wrote, then her answers
-- added to it by hand (no trailer); a commit only another folder's
-- transcript records; and an ordinary recorded commit.
local own = SCRATCH .. "/own"
local other = SCRATCH .. "/other-transcripts"
os.execute("mkdir -p '" .. own .. "/llm-transcripts' '" .. own .. "/docs' '" .. other .. "'")
local function ogit(args) return os.execute("git -C '" .. own .. "' " .. args .. " > /dev/null") end
local function ohead()
  local p = io.popen("git -C '" .. own .. "' rev-parse HEAD"); local h = p:read("*l"); p:close(); return h
end
ogit("init -q"); ogit("config user.email t@t"); ogit("config user.name t")
write(own .. "/docs/questions.md", "# Questions\n\n## Q1. How tall?\n\nAn assistant asks this.\n\n## Q2. How wide?\n\nAnd this.\n")
ogit("add -A")
ogit("commit -q -m 'The questions' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'")
local asked = ohead()
write(own .. "/docs/questions.md", "# Questions\n\n## Q1. How tall?\n\nAn assistant asks this.\n\n-> very tall.\n\n## Q2. How wide?\n\nAnd this.\n\n-> not wide at all.\n")
write(own .. "/llm-transcripts/rode-along.md", "not her words\n")
ogit("add -A")
ogit("commit -q -m 'my answers'")
local by_hand = ohead()
write(own .. "/x.txt", "x\n")
ogit("add -A")
ogit("commit -q -m 'Made from elsewhere' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'")
local from_elsewhere = ohead()
write(other .. "/sep-1-26.md", transcript({ models = "m" }, {
  { "User Request 1", "everywhere" },
  { "Assistant Response 1", "done\n\n*[commit] " .. from_elsewhere:sub(1, 9) .. " in own - Made from elsewhere*" },
}))
write(own .. "/llm-transcripts/sep-2-26.md", transcript({ models = "m" }, {
  { "User Request 1", "build" },
  { "Assistant Response 1", "built\n\n*[commit] " .. asked:sub(1, 9) .. " - The questions*" },
}))
os.execute("rm -f '" .. own .. "/llm-transcripts/rode-along.md'")
ogit("add -A")
ogit("commit -q -m 'Save the conversation' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'")

local own_settings = settings_reader.resolve(own, { evidence_from = { other } })
local own_report = site.build(own_settings)
local own_index = io.open(own .. "/llm-transcripts/HTML/index.html"):read("*a")
check("a commit only another folder records is left off the page",
  own_index:find("Made from elsewhere", 1, true) == nil, true)
check("... and counted in the report", own_report.hidden_elsewhere, 1)
check("a commit made by hand is shown like any other",
  own_index:find("my answers", 1, true) ~= nil, true)
check("... with a button to a page of her own words",
  own_index:find('href="by-hand-' .. by_hand:sub(1, 7) .. '.html"', 1, true) ~= nil, true)
local hand_page = io.open(own .. "/llm-transcripts/HTML/by-hand-" .. by_hand:sub(1, 7) .. ".html")
local hand = hand_page and hand_page:read("*a") or ""
check("her page holds the lines she added", hand:find("very tall.", 1, true) ~= nil
  and hand:find("not wide at all.", 1, true) ~= nil, true)
check("... and not the lines around them the assistant wrote",
  hand:find("An assistant asks this.", 1, true) == nil, true)
check("... each under the heading it sits beneath, as a quiet label",
  hand:find('class="turn context"', 1, true) ~= nil and hand:find("Q2. How wide?", 1, true) ~= nil, true)
check("... naming the file", hand:find("docs/questions.md", 1, true) ~= nil, true)
check("... leaving out the transcripts folder's files", hand:find("not her words", 1, true) == nil, true)
check("... and says it was written by hand", hand:find("written by hand", 1, true) ~= nil, true)
check("a missing evidence_from folder stops the build",
  (pcall(site.build, settings_reader.resolve(own, { evidence_from = { SCRATCH .. "/nowhere" } }))), false)

print("== a pulled copy (issue 035e) ==")

-- Pulled as last committed, into a throwaway project, leaving the fonts out.
local puller = SCRATCH .. "/puller"
os.execute("mkdir -p '" .. puller .. "'")
local said_pull, pulled_ok = run_quiet("'" .. SITE .. "/pull-transcript-site' '" .. puller
  .. "' --without fonts --dir '" .. DIR .. "'")
check("the pull succeeds", pulled_ok, true)
local upstream = io.open(puller .. "/libs/transcript-site/UPSTREAM")
local upstream_text = upstream and upstream:read("*a") or ""
check("it writes down the commit it came from", upstream_text:match("commit      %x+") ~= nil, true)
check("... and what it left out", upstream_text:find("left out    fonts", 1, true) ~= nil, true)
check("the builder came with it", io.open(puller .. "/libs/transcript-site/build-site.lua") ~= nil, true)
check("the fonts did not", io.open(puller .. "/libs/transcript-site/fonts/README.md") == nil, true)
check("its RAM staging folder is gone once in place",
  io.open(puller .. "/tmp/shared-memory/pull-transcript-site/UPSTREAM") == nil, true)
local _, refused = run_quiet("'" .. SITE .. "/pull-transcript-site' '" .. puller
  .. "' --without no-such-thing --dir '" .. DIR .. "'")
check("leaving out something that is not there is refused", refused, false)
check("... and the copy already there is kept", io.open(puller .. "/libs/transcript-site/UPSTREAM") ~= nil, true)
check("it says what it pulled", said_pull:find("Pulled the transcript-site library", 1, true) ~= nil, true)

os.execute("rm -rf '" .. SCRATCH .. "'")

print("")
if failures == 0 then
  print("all good")
  os.exit(0)
end
print(failures .. " failed")
os.exit(1)
