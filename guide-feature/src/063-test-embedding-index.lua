#!/usr/bin/env luajit
-- 063-test-embedding-index.lua
--
-- Tests the embedding index (issue 502): its rules and files (060), its
-- builder (061, scripts/build-embedding-index), its checker and git hooks
-- (062, scripts/check-embedding-index, scripts/install-index-hooks), against
-- a stand-in embedding server (047) on 127.0.0.1.
--
-- The rules: names-v1 in Lua, shell and C, with comments, strings and the
-- #! line left out, identifiers split, keywords and one-letter names
-- dropped, each name once; a query read the same way. pieces-v1: folds,
-- functions at the left edge, blocks, long pieces cut, nameless ones left
-- out. The files: written and read back, vectors made length 1, and each
-- thing the checker refuses. The builder, in a throwaway monorepo: the
-- index of the commit (not the working tree), the files it skips, up to
-- date, renamed for a commit that touched only other projects, only changed
-- pieces embedded, batches, the endpoints file's embedder, refusals that
-- leave the index as it was, one build at a time. The hooks: added beside
-- what a hook already does and before its exit, once; a commit rebuilding
-- the index in the background; removed again. Then guide-feature's own
-- index, built the way the build guide says, which phase 5's look tool
-- (503) is tested against.
--
-- For a general: the project is cut into pieces, each piece's names turned
-- into a direction in meaning, so a voice can later ask for the pieces
-- nearest a question.
--
-- usage:
--   luajit 063-test-embedding-index.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
pcall(ffi.cdef, "int poll(void *fds, unsigned long nfds, int timeout);")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    shell("mkdir -p " .. "'" .. string.gsub(string.match(path, "^(.*)/[^/]*$"), "'", "'\\''") .. "'")
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end
local function show(list) return "{ " .. table.concat(list, ", ") .. " }" end
-- }}}

local index = dofile(DIR .. "/src/060-embedding-index.lua")
local builder = dofile(DIR .. "/src/061-build-embedding-index.lua")
local tools = dofile(DIR .. "/src/062-embedding-index-tools.lua")
local json = dofile(DIR .. "/libs/dkjson.lua")

-- {{{ the throwaway place
local BASE = shell("mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
shell("mkdir -p " .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm"))
local KEEP = (os.getenv("KEEP") or "") ~= ""
-- }}}

io.write("\n=== names-v1 ===\n")
-- {{{
local got = index.names('local canvasWidth = row_count -- the rows\nlocal s = "string text"\n', "lua")
check("Lua: identifiers split at _ and case, comments, strings, keywords and one letter left out",
    same(got, { "canvas", "width", "row", "count" }), show(got))
got = index.names("--[[ hidden\nstill ]] visible = [==[ also\nhidden ]==] .. other_name\n", "lua")
check("Lua: long comments and long strings left out", same(got, { "visible", "other", "name" }), show(got))
got = index.names('#!/bin/sh\n# a comment\nfor file in "$DIR"/*; do echo $# ${#list}; done\n', "hash")
check("shell: # comments and the #! line left out, but not $# or ${#...}",
    same(got, { "file", "echo", "list" }), show(got))
got = index.names('// note\nint maxWidth = 3; /* gone\n too */ char *nameText = "x\\"y";\n', "c")
check("C and JavaScript: // and /* */ comments, strings with escapes",
    same(got, { "max", "width", "name", "text" }), show(got))
got = index.names("#!/usr/bin/env luajit\nlocal for_each = is_ready\n", "lua")
check("Lua: a first #! line is left out, and keywords met once split (for_each, is_ready)",
    same(got, { "each", "ready" }), show(got))
got = index.names("blit blit_rows blitRows rows_blit", "lua")
check("each name once, in the order first seen", same(got, { "blit", "rows" }), show(got))
got = index.query_names("How is the canvas_width checked? Don't guess.")
check("a query is read the same way, an apostrophe not starting a string",
    same(got, { "how", "the", "canvas", "width", "checked", "don", "guess" }), show(got))
check("the language of a file: by extension, else by its #! line",
    index.language_of("a/b.lua") == "lua" and index.language_of("scripts/turn", "#!/bin/sh") == "hash"
    and index.language_of("x", "#!/usr/bin/env luajit") == "lua" and index.language_of("README.md") == nil
    and index.language_of("notes", "plain words") == nil)
-- }}}

io.write("\n=== pieces-v1 ===\n")
-- {{{
local FOLDED = table.concat({
    "-- a header",                          -- 1
    "local settings = dofile(path)",        -- 2
    "",                                     -- 3
    "-- {{{ M.SETTINGS",                    -- 4
    "M.SETTINGS = {",                       -- 5
    "    width = 3,",                       -- 6
    "}",                                    -- 7
    "-- }}}",                               -- 8
    "",                                     -- 9
    "-- {{{ function M.keep()",             -- 10
    "function M.keep(opts)",                -- 11
    "    -- {{{ an inner fold",             -- 12
    "    local inner = opts.inner",         -- 13
    "    -- }}}",                           -- 14
    "    return inner",                     -- 15
    "end",                                  -- 16
    "-- }}}",                               -- 17
    "return settings_table",                -- 18
}, "\n") .. "\n"
local cut = index.cut(FOLDED, "lua", 60)
local summary = {}
for _, p in ipairs(cut) do summary[#summary + 1] = p.first .. "-" .. p.last .. " " .. p.kind end
check("each outermost fold is a piece, an inner fold inside it; lines between are blocks",
    same(summary, { "1-2 block", "4-8 structure", "10-17 function", "18-18 block" }), show(summary))
check("a piece's names are its own lines' names",
    cut[3] and same(cut[3].names, { "keep", "opts", "inner" }), cut[3] and show(cut[3].names))
local PLAIN = "local function a_one(x)\n    return x\nend\n\nlocal list = { 1, 2 }\n\n"
    .. "function M.two()\n    if ok then\n        return 2\n    end\nend\n"
summary = {}
for _, p in ipairs(index.cut(PLAIN, "lua", 60)) do summary[#summary + 1] = p.first .. "-" .. p.last .. " " .. p.kind end
check("with no folds: Lua functions from the left edge to their end, the rest blocks",
    same(summary, { "1-3 function", "5-5 structure", "7-11 function" }), show(summary))
summary = {}
for _, p in ipairs(index.cut("#!/bin/sh\nset -e\n\nshow_it() {\n    echo \"$1\"\n}\n\nshow_it go\n", "hash", 60)) do
    summary[#summary + 1] = p.first .. "-" .. p.last .. " " .. p.kind
end
check("shell functions, name() { to }", same(summary, { "4-6 function", "8-8 block" }), show(summary))
local long = { "-- {{{ function M.long()" }
for i = 1, 25 do long[#long + 1] = "local name_" .. i .. " = " .. i end
long[#long + 1] = "-- }}}"
summary = {}
for _, p in ipairs(index.cut(table.concat(long, "\n"), "lua", 10)) do summary[#summary + 1] = p.first .. "-" .. p.last end
check("a piece longer than piece-lines is cut into parts", same(summary, { "1-10", "11-20", "21-27" }),
    show(summary))
check("a piece with no names is left out",
    #index.cut("-- only a comment\n-- and another\n\nreturn 1\n", "lua", 60) == 0)
-- }}}

io.write("\n=== the index's files ===\n")
-- {{{
local F = BASE .. "/files/.embedding-index"
local PIECES = {
    { file = "src/a.lua", first = 1, last = 3, kind = "function", names = { "canvas", "width" } },
    { file = "src/b.lua", first = 2, last = 2, kind = "block", names = { "blit" } },
}
index.write(F, { commit = string.rep("a", 40), tree = string.rep("b", 40), model = "m one", dimensions = 3,
                 rule = index.RULE }, PIECES, { { 3, 0, 4 }, { 0, 2, 0 } })
local found = index.read(F)
check("written and read back: meta, pieces, vectors made length 1",
    found and found.meta.commit == string.rep("a", 40) and found.meta.model == "m one"
    and found.meta.dimensions == 3 and found.meta.pieces == 2 and found.meta.rule == "names-v1"
    and found.pieces[1].file == "src/a.lua" and found.pieces[1].names == "canvas width"
    and math.abs(found.vectors[0] - 0.6) < 1e-6 and math.abs(found.vectors[2] - 0.8) < 1e-6
    and math.abs(found.vectors[4] - 1) < 1e-6, found and index.meta_text(found.meta))
check("the vectors file is 32-bit floats, piece by piece", #slurp(F .. "/vectors") == 2 * 3 * 4)
local lines = function(file) return ({ ["src/a.lua"] = 3, ["src/b.lua"] = 5 })[file] end
local _, problems = index.check(F, { commit = string.rep("a", 40), lines_of = lines })
check("a good index checks", problems and #problems == 0, problems and table.concat(problems, "; "))
_, problems = index.check(F, { commit = string.rep("c", 40), lines_of = lines })
check("built from another commit: refused, naming both",
    problems and has(problems[1], "built from commit " .. string.rep("a", 40) .. ", and the project is at "),
    problems and problems[1])
_, problems = index.check(F, { lines_of = function(file) return file == "src/a.lua" and 2 or nil end })
check("a piece past its file's end, or in a file not there: refused",
    problems and has(table.concat(problems, "; "), "piece 1 ends at line 3 of src/a.lua, which has 2")
    and has(table.concat(problems, "; "), "piece 2's file src/b.lua is not in the project"),
    problems and table.concat(problems, "; "))
local good_vectors = slurp(F .. "/vectors")
write(F .. "/vectors", string.sub(good_vectors, 1, 20))
_, problems = index.check(F, {})
check("a vectors file of the wrong size: refused", problems and has(problems[1], "the vectors file is 20 bytes"),
    problems and problems[1])
local doubled = ffi.new("float[6]")
ffi.copy(doubled, good_vectors, 24)
doubled[0], doubled[2] = 1.2, 1.6
write(F .. "/vectors", ffi.string(doubled, 24))
_, problems = index.check(F, {})
check("a vector not of length 1: refused", problems and has(problems[1], "piece 1's vector has length 2.0000"),
    problems and problems[1])
write(F .. "/vectors", good_vectors)
local good_meta = slurp(F .. "/meta")
write(F .. "/meta", (good_meta:gsub("\nmodel = [^\n]*", "")))
_, problems = index.check(F, {})
check("a meta file without a field: refused", problems and has(problems[1], "meta has no model"),
    problems and problems[1])
write(F .. "/meta", (good_meta:gsub("pieces = 2", "pieces = 3")))
_, problems = index.check(F, {})
check("meta and pieces disagreeing: refused", problems and has(problems[1], "need 36"), problems and problems[1])
write(F .. "/meta", good_meta)
-- }}}

io.write("\n=== the builder ===\n")
-- {{{
local SERVER = BASE .. "/server"
local function start_server(kind)
    local folder = SERVER .. "-" .. kind
    shell("mkdir -p " .. q(folder))
    local pid = shell("luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind " .. kind
        .. " --dimensions 64 --port-file " .. q(folder .. "/port") .. " --requests " .. q(folder .. "/requests")
        .. " --parent $PPID > /dev/null 2>&1 & echo $!")
    local port
    for _ = 1, 100 do
        port = slurp(folder .. "/port")
        if port then break end
        sleep(0.05)
    end
    return { pid = pid, url = "http://127.0.0.1:" .. tostring(port and port:match("%d+")), folder = folder }
end
local embedder = start_server("embedding")
local chatter = start_server("chat")
local function embed_requests()
    local n, texts = 0, 0
    for line in string.gmatch(slurp(embedder.folder .. "/requests") or "", "[^\n]+") do
        local r = json.decode(line)
        if r.path == "/v1/embeddings" then
            n = n + 1
            texts = texts + #r.body.input
        end
    end
    return n, texts
end

local MONO = BASE .. "/mono"
local P = MONO .. "/guide-feature"
local function commit(message)
    shell("git -C " .. q(MONO) .. " add -A && git -C " .. q(MONO)
        .. " -c user.name=test -c user.email=test@localhost commit -q -m " .. q(message))
    return (shell("git -C " .. q(MONO) .. " rev-parse HEAD"))
end
shell("mkdir -p " .. q(P) .. " && git -C " .. q(MONO) .. " init -q")
-- the project's own .gitignore, as guide-feature's: the index and the RAM tiers' door
write(P .. "/.gitignore", "/.embedding-index*\ntmp\n.claude/\n")
write(P .. "/input/embedding-index", (slurp(DIR .. "/input/embedding-index"):gsub("batch%s*= %d+", "batch = 8")))
write(P .. "/src/001-canvas.lua", table.concat({
    "-- {{{ function M.canvas_width()", "function M.canvas_width(canvas)", "    return canvas.width",
    "end", "-- }}}", "", "-- {{{ function M.blit_rows()", "function M.blit_rows(rows, marks)",
    "    return rows", "end", "-- }}}", "" }, "\n"))
local many = {}
for i = 1, 20 do
    many[#many + 1] = "-- {{{ function M.helper_" .. i .. "()\nfunction M.helper_" .. i .. "(value_" .. i
        .. ")\n    return value_" .. i .. "\nend\n-- }}}\n"
end
write(P .. "/src/002-helpers.lua", table.concat(many, "\n"))
write(P .. "/scripts/run-blitter", "#!/bin/sh\nexec luajit \"$DIR/src/016-blitter.lua\" --dir \"$DIR\" blitter_args\n")
write(P .. "/libs/vendored.lua", "local function vendored_thing() return 1 end\n")
write(P .. "/docs/notes.md", "# notes with canvas words\n")
write(MONO .. "/other/thing.lua", "local other_project = 1\n")
local C1 = commit("one")

-- where the builder's log and receipt go: a project root of its own here, as a
-- voice's own root is when it indexes its clone (503)
local LOGS = BASE .. "/logs/guide-feature"
shell("mkdir -p " .. q(LOGS) .. " && ln -s " .. q(DIR .. "/src") .. " " .. q(LOGS .. "/src") .. " && ln -s "
    .. q(DIR .. "/libs") .. " " .. q(LOGS .. "/libs"))
local function build(extra)
    local opts = { root = P, url = embedder.url, timeout = 10, log_root = LOGS }
    for key, value in pairs(extra or {}) do opts[key] = value end
    return pcall(builder.build, opts)
end
local ok, done = build()
local built = index.read(P .. "/.embedding-index")
check("it builds the index of the commit the checkout is at",
    ok and done.outcome == "built" and built and built.meta.commit == C1 and built.meta.model == "stand-in-embedding"
    and built.dimensions == 64 and built.meta.rule == "names-v1" and built.meta.tree ~= nil,
    ok and builder.describe(done) or done)
local files = {}
for _, p in ipairs(built and built.pieces or {}) do files[p.file] = (files[p.file] or 0) + 1 end
check("from the project's code files, named from the project's folder: Lua, and scripts by their #! line",
    files["src/001-canvas.lua"] == 2 and files["src/002-helpers.lua"] == 20 and files["scripts/run-blitter"] == 1,
    json.encode(files))
check("leaving out libs/ (skip), what is not code, and the monorepo's other projects",
    files["libs/vendored.lua"] == nil and files["docs/notes.md"] == nil and files["other/thing.lua"] == nil
    and files["../other/thing.lua"] == nil, json.encode(files))
local requests, texts = embed_requests()
check("every piece embedded, in batches of the setting's size", requests == 3 and texts == 23,
    requests .. " requests, " .. texts .. " texts")
local good, said = tools.check(P)
check("the checker says it can be used", good and has(said[1], "the index can be used: commit "
    .. string.sub(C1, 1, 7) .. ", 23 pieces of 64 dimensions, model stand-in-embedding, rule names-v1"),
    table.concat(said, "\n"))

write(P .. "/src/003-new.lua", "local function uncommitted_work() return 1 end\n")
ok, done = build()
check("built again at the same commit: up to date, nothing asked; the working tree is not the commit",
    ok and done.outcome == "up to date" and embed_requests() == 3, ok and builder.describe(done) or done)
os.remove(P .. "/src/003-new.lua")

write(MONO .. "/other/thing.lua", "local other_project = 2\n")
local C2 = commit("another project")
ok, done = build()
built = index.read(P .. "/.embedding-index")
check("a commit that touched only another project: the index renamed to it, nothing embedded",
    ok and done.outcome == "renamed" and built.meta.commit == C2 and embed_requests() == 3,
    ok and builder.describe(done) or done)

write(P .. "/src/001-canvas.lua", (slurp(P .. "/src/001-canvas.lua"):gsub("rows, marks", "rows, marks, cuts")))
local C3 = commit("blit takes cuts")
ok, done = build()
local after, after_texts = embed_requests()
check("a commit that changed one function: only its piece embedded, the rest kept",
    ok and done.outcome == "built" and done.embedded == 1 and done.reused == 22 and after == 4 and after_texts == 24
    and index.read(P .. "/.embedding-index").meta.commit == C3, ok and builder.describe(done) or done)
check("and the log and receipt say so", has(slurp(BASE .. "/shm/guide-feature/build-embedding-index.log"),
    "23 pieces from 3 files, 64 dimensions, model stand-in-embedding; 1 embedded, 22 kept"),
    slurp(BASE .. "/shm/guide-feature/build-embedding-index.log"))

write(P .. "/src/001-canvas.lua", (slurp(P .. "/src/001-canvas.lua"):gsub("canvas.width", "canvas.width + 1")))
local C4 = commit("wider")
ok, done = build({ url = chatter.url })
check("a server that does not embed is refused, and the index left as it was",
    not ok and has(done, "does not support embeddings")
    and index.read(P .. "/.embedding-index").meta.commit == C3, done)
ok, done = build({ url = "http://127.0.0.1:9" })
check("an endpoint that does not answer: refused, naming it, the index left as it was",
    not ok and has(done, "http://127.0.0.1:9") and index.read(P .. "/.embedding-index").meta.commit == C3, done)
write(P .. "/endpoints", 'stand-in-embed.url = "' .. embedder.url .. '"\nstand-in-embed.kind = "embedding"\n'
    .. "stand-in-embed.timeout = 10\nuse.embedder = \"stand-in-embed\"\n")
-- reading the endpoints file makes sure of the project's RAM tiers, with its own copy of the library
for _, name in ipairs({ "ensure-ram-tiers", "ensure-ram-tiers.lua" }) do
    shell("ln -s " .. q(DIR .. "/libs/" .. name) .. " " .. q(P .. "/libs/" .. name))
end
ok, done = build({ url = false })
check("with no address given, the project's endpoints file's embedder is used",
    ok and done.outcome == "built" and done.endpoint == "stand-in-embed"
    and index.read(P .. "/.embedding-index").meta.commit == C4, ok and builder.describe(done) or done)
os.remove(P .. "/endpoints")

write(P .. "/src/001-canvas.lua", (slurp(P .. "/src/001-canvas.lua"):gsub("%+ 1", "+ 2")))
commit("wider still")
local sleeper = shell("sleep 30 > /dev/null 2>&1 & echo $!")
shell("mkdir -p " .. q(P .. "/.embedding-index.lock") .. " && echo " .. sleeper .. " > " .. q(P .. "/.embedding-index.lock/pid"))
ok, done = build()
check("one build at a time: a build while another runs says so and leaves it",
    ok and done.outcome == "busy" and index.read(P .. "/.embedding-index").meta.commit == C4,
    ok and builder.describe(done) or done)
shell("kill " .. sleeper)
sleep(0.2)
ok, done = build()
check("a lock whose builder is gone is taken over", ok and done.outcome == "built"
    and not slurp(P .. "/.embedding-index.lock/pid"), ok and builder.describe(done) or done)
local out, status = shell("cd " .. q(P) .. " && luajit " .. q(DIR .. "/src/062-embedding-index-tools.lua")
    .. " --dir " .. q(P) .. " check")
check("scripts/check-embedding-index: exit 0 and the line", status == 0 and has(out, "the index can be used"), out)
-- }}}

io.write("\n=== the git hooks ===\n")
-- {{{
-- the project here carries its own scripts/ and src/, as a real checkout does
shell("mkdir -p " .. q(P .. "/scripts"))
shell("cp " .. q(DIR .. "/scripts/build-embedding-index") .. " " .. q(P .. "/scripts/"))
-- the hook runs the script in the project, which runs the builder beside it:
-- give the project a src/ and libs/ that point at this one's
for _, name in ipairs({ "src", "libs" }) do
    shell("mkdir -p " .. q(P .. "/" .. name) .. " && for f in " .. q(DIR .. "/" .. name) .. "/*; do "
        .. "[ -e " .. q(P .. "/" .. name) .. "/$(basename \"$f\") ] || ln -s \"$f\" " .. q(P .. "/" .. name) .. "/; done")
end
write(P .. "/endpoints", 'stand-in-embed.url = "' .. embedder.url .. '"\nstand-in-embed.kind = "embedding"\n'
    .. "stand-in-embed.timeout = 10\nuse.embedder = \"stand-in-embed\"\n")
local HOOKS = MONO .. "/.git/hooks"
write(HOOKS .. "/post-commit", "#!/bin/sh\necho another project hook ran >> " .. q(BASE .. "/other-hook") .. "\nexit 0\n")
local first = tools.hooks(P)
local post_commit = slurp(HOOKS .. "/post-commit") or ""
check("each of the three hooks gets the block, the existing one keeping what it does",
    same(first, { "post-commit: added beside what it already does", "post-merge: added", "post-checkout: added" })
    and has(post_commit, "echo another project hook ran")
    and has(slurp(HOOKS .. "/post-merge"), "--hook post-merge"), show(first))
check("in an existing hook, before its exit, where it would otherwise never run",
    string.find(post_commit, "build-embedding-index", 1, true) < string.find(post_commit, "\nexit 0", 1, true),
    post_commit)
check("installing again changes nothing", same(tools.hooks(P),
    { "post-commit: already there", "post-merge: already there", "post-checkout: already there" })
    and slurp(HOOKS .. "/post-commit") == post_commit)
write(P .. "/src/001-canvas.lua", (slurp(P .. "/src/001-canvas.lua"):gsub("%+ 2", "+ 3")))
local C6 = commit("through the hook")
local rebuilt
for _ = 1, 100 do
    rebuilt = index.read(P .. "/.embedding-index")
    if rebuilt and rebuilt.meta.commit == C6 then break end
    sleep(0.1)
end
check("a commit runs the hook, which builds the index for it in the background",
    rebuilt and rebuilt.meta.commit == C6 and has(slurp(BASE .. "/other-hook"), "another project hook ran"),
    rebuilt and rebuilt.meta.commit)
-- a commit made with the hooks passed by, so the index is behind it
write(P .. "/src/001-canvas.lua", (slurp(P .. "/src/001-canvas.lua"):gsub("%+ 3", "+ 4")))
shell("git -C " .. q(MONO) .. " add -A && git -C " .. q(MONO) .. " -c core.hooksPath=/dev/null"
    .. " -c user.name=test -c user.email=test@localhost commit -q -m quiet")
local requests_before = embed_requests()
out, status = shell(q(P .. "/scripts/build-embedding-index") .. " --hook post-checkout a b 0")
check("a post-checkout of single files builds nothing", status == 0 and embed_requests() == requests_before
    and out == "" and index.read(P .. "/.embedding-index").meta.commit == C6, out)
out, status = shell(q(P .. "/scripts/build-embedding-index") .. " --hook post-checkout a b 1")
local QUIET = shell("git -C " .. q(MONO) .. " rev-parse HEAD")
check("a post-checkout of a commit builds, in the hook's own run",
    status == 0 and index.read(P .. "/.embedding-index").meta.commit == QUIET, out)
local removed = tools.hooks(P, { remove = true })
check("--remove takes the blocks out, keeping the other hook and dropping the hooks it made",
    same(removed, { "post-commit: removed", "post-merge: removed, and the hook with it (it held nothing else)",
        "post-checkout: removed, and the hook with it (it held nothing else)" })
    and slurp(HOOKS .. "/post-commit") == "#!/bin/sh\necho another project hook ran >> " .. q(BASE .. "/other-hook")
        .. "\nexit 0\n" and not slurp(HOOKS .. "/post-merge"), show(removed))
-- }}}

io.write("\n=== guide-feature's own index, built as the guide says ===\n")
-- {{{
-- the project's files as they are now, committed in a repository of their own
local OWN = BASE .. "/own"
shell("mkdir -p " .. q(OWN .. "/guide-feature") .. " && cd " .. q(DIR) .. " && git ls-files -co --exclude-standard -z . "
    .. "| xargs -0 -I{} sh -c 'test -f \"$1\" && mkdir -p " .. q(OWN .. "/guide-feature") .. "/$(dirname \"$1\") "
    .. "&& cp -P \"$1\" " .. q(OWN .. "/guide-feature") .. "/\"$1\"' _ {}")
shell("git -C " .. q(OWN) .. " init -q && git -C " .. q(OWN) .. " add -A && git -C " .. q(OWN)
    .. " -c user.name=test -c user.email=test@localhost commit -q -m own")
local started = os.time()
ok, done = pcall(builder.build, { root = OWN .. "/guide-feature", url = embedder.url, timeout = 30,
                                  log_root = LOGS })
local own = index.read(OWN .. "/guide-feature/.embedding-index")
local kinds, from = {}, {}
for _, p in ipairs(own and own.pieces or {}) do
    kinds[p.kind] = (kinds[p.kind] or 0) + 1
    from[string.match(p.file, "^[^/]+")] = true
end
check("it builds: hundreds of pieces from src/ and scripts/, none from libs/",
    ok and own and own.count > 500 and from.src and from.scripts and not from.libs,
    ok and builder.describe(done) or done)
check("functions, structures and blocks among them", (kinds["function"] or 0) > 100
    and (kinds.structure or 0) > 10 and (kinds.block or 0) > 10, json.encode(kinds))
good, said = tools.check(OWN .. "/guide-feature")
check("and it checks: every piece inside its file at the commit", good, table.concat(said, "\n"))
local keeper_piece = false
for _, p in ipairs(own and own.pieces or {}) do
    if p.file == "src/058-project-clone.lua" and has(" " .. p.names .. " ", " ram ")
        and has(" " .. p.names .. " ", " share ") then keeper_piece = true end
end
check("the clone keeper's choice of RAM is a piece, by its names", keeper_piece)
io.write("        (" .. (own and own.count or 0) .. " pieces in " .. (os.time() - started) .. " s)\n")
-- }}}

shell("kill " .. embedder.pid .. " " .. chatter.pid)
if failed > 0 and KEEP then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
