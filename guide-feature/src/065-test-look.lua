#!/usr/bin/env luajit
-- 065-test-look.lua
--
-- Tests the look tool (issue 503, src/064-look.lua) and what it stands on:
-- the embedder's line in the canvas (035, 046), the clone keeper copying the
-- project's embedding index (058), and the turn answering look calls (055),
-- against stand-in llama.cpp servers (047) on 127.0.0.1.
--
-- Choosing by focus: how many pieces and how far down the ranks, at focus
-- 1, 0 and between, and the settings it refuses. Scoring and answering, on
-- a small index made by hand: nearest first, labels, the token budget (a
-- piece that does not fit is left out and counted, a smaller one after it
-- still goes in), a file missing from the clone. Every refusal, in words the
-- model reads, with no pieces: no clone, no index, an index from another
-- commit, another name rule, another model, vectors of another length, no
-- names in the words, no embedder. The embedder's line: written last in the
-- canvas when the endpoints file has use.embedder, read back as an
-- embedding endpoint. The keeper: no index at the source, copied, already
-- there, copied and renamed for a commit that touched only other folders,
-- behind for one that touched the project, copied again once rebuilt, and a
-- copy that does not check. The turn: a model that looks focused and broad
-- before it writes, the pieces in its next prompt, the log line and the
-- receipt's counts; a canvas with no embedder (refused, and the turn goes
-- on). Then the reference looks: "canvas width" at focus 1, 0.5 and 0
-- against guide-feature's own index at a pinned commit, each compared with
-- its file in assets/test-looks/ (written again with --write-references).
--
-- For a general: a voice can now ask to see the parts of the project
-- nearest a question, a few close ones or a wide spread, and is told
-- plainly when there is nothing to show.
--
-- usage:
--   luajit 065-test-look.lua [--dir ROOT] [--write-references]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
local WRITE_REFERENCES = false
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
    if arg[index] == "--write-references" then WRITE_REFERENCES = true end
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
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function write(path, text)
    shell("mkdir -p " .. q(string.match(path, "^(.*)/[^/]*$")))
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function sleep(seconds) ffi.C.poll(nil, 0, math.floor(seconds * 1000)) end
local function list(t) return table.concat(t, ",") end
-- }}}

-- {{{ the throwaway place
local BASE = shell("mktemp -d -p /dev/shm 2>/dev/null || mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local ROOT = BASE .. "/voice/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local KEEP = (os.getenv("KEEP") or "") ~= ""
for _, name in ipairs({ "turn", "turn-instructions", "look" }) do
    write(ROOT .. "/input/" .. name, slurp(DIR .. "/input/" .. name))
end
-- }}}

local json = dofile(DIR .. "/libs/dkjson.lua")
local index = dofile(DIR .. "/src/060-embedding-index.lua")
local builder = dofile(DIR .. "/src/061-build-embedding-index.lua")
local look = dofile(DIR .. "/src/064-look.lua")
local clone = dofile(DIR .. "/src/058-project-clone.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local to_voices = dofile(DIR .. "/src/035-to-voices.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local turn_module = dofile(DIR .. "/src/055-turn.lua")

-- {{{ stand-in servers
local function start_server(name, kind, replies)
    local folder = BASE .. "/servers/" .. name
    shell("mkdir -p " .. q(folder))
    local command = "luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind " .. kind
        .. " --dimensions 64 --port-file " .. q(folder .. "/port") .. " --requests "
        .. q(folder .. "/requests") .. " --parent $PPID"
    if replies then
        write(folder .. "/replies", json.encode(replies))
        command = command .. " --replies " .. q(folder .. "/replies")
    end
    local pid = shell(command .. " > /dev/null 2>&1 & echo $!")
    local port
    for _ = 1, 100 do
        port = slurp(folder .. "/port")
        if port then break end
        sleep(0.05)
    end
    return { pid = pid, folder = folder, url = "http://127.0.0.1:" .. tostring(port and port:match("%d+")) }
end
local function requests(server, path)
    local out = {}
    for line in string.gmatch(slurp(server.folder .. "/requests") or "", "[^\n]+") do
        local r = json.decode(line)
        if not path or r.path == path then out[#out + 1] = r end
    end
    return out
end
local embedder = start_server("embedder", "embedding")
local EMBEDDER = { name = "stand-in-embed", url = embedder.url, kind = "embedding", timeout = 30 }
-- }}}

io.write("\n=== choosing by focus ===\n")
-- {{{
local V = { focused = 1, broad = 0, nearest = 4, spread = 12, curve = 2, budget = 2000 }
check("focus 1: the nearest four, one after another", list(look.ranks(1000, 1, V)) == "1,2,3,4",
    list(look.ranks(1000, 1, V)))
local broad = look.ranks(1000, 0, V)
check("focus 0: twelve, evenly spread from the nearest to the farthest",
    #broad == 12 and broad[1] == 1 and broad[12] == 1000 and broad[2] == 92, list(broad))
local middle = look.ranks(1000, 0.5, V)
check("focus 0.5: eight, reaching a quarter of the way down (curve 2)",
    #middle == 8 and middle[1] == 1 and middle[8] == 251, list(middle))
local straight = { focused = 1, broad = 0, nearest = 4, spread = 12, curve = 1, budget = 2000 }
check("with curve 1, focus 0.5 reaches half of the way",
    look.ranks(1000, 0.5, straight)[8] == 501, list(look.ranks(1000, 0.5, straight)))
check("a project with fewer pieces than chosen gives all of them, once each",
    list(look.ranks(3, 0, V)) == "1,2,3" and list(look.ranks(1, 0.5, V)) == "1",
    list(look.ranks(3, 0, V)))
local all_good = true
for n = 1, 60 do
    for step = 0, 20 do
        local ranks = look.ranks(n, step / 20, V)
        for i = 2, #ranks do if ranks[i] <= ranks[i - 1] then all_good = false end end
        if ranks[1] ~= 1 or ranks[#ranks] > n then all_good = false end
    end
end
check("at every focus and size: rank 1 first, then rising, never past the last", all_good)
check("the model's words as a focus, by input/look",
    look.focus_of("focused", V) == 1 and look.focus_of("broad", V) == 0
    and not pcall(look.focus_of, "sideways", V))
local values = look.read_settings(ROOT)
check("input/look reads: focused 1, broad 0, 4 to 12 pieces, curve 2, 2000 tokens",
    values.focused == 1 and values.broad == 0 and values.nearest == 4 and values.spread == 12
    and values.curve == 2 and values.budget == 2000)
shell("mkdir -p " .. q(BASE .. "/bad") .. " && ln -s " .. q(DIR .. "/src") .. " " .. q(BASE .. "/bad/src")
    .. " && ln -s " .. q(DIR .. "/libs") .. " " .. q(BASE .. "/bad/libs"))
write(BASE .. "/bad/input/look", (slurp(DIR .. "/input/look"):gsub("\nspread%s*= %d+", "\nspread = 2")))
local ok, problem = pcall(look.read_settings, BASE .. "/bad")
check("a spread below nearest is refused", not ok and has(problem, "spread cannot be below nearest"),
    problem)
-- }}}

io.write("\n=== scoring and answering, on an index made by hand ===\n")
-- {{{
local HAND = BASE .. "/hand"
write(HAND .. "/a.lua", "function alpha()\n    return 1\nend\nfunction beta_long()\n"
    .. "    -- " .. string.rep("many words in the beta piece ", 12) .. "\nend\n")
write(HAND .. "/b.lua", "gamma = 1\ngamma = 2\ndelta = 3\ndelta = 4\n")
local FULL = string.rep("a", 40)
index.write(HAND .. "/.embedding-index", { commit = FULL, model = "hand-model", dimensions = 3 }, {
    { file = "a.lua", first = 1, last = 3, kind = "function", names = { "alpha" } },
    { file = "a.lua", first = 4, last = 6, kind = "function", names = { "beta", "long" } },
    { file = "b.lua", first = 1, last = 2, kind = "block", names = { "gamma" } },
    { file = "b.lua", first = 3, last = 4, kind = "block", names = { "delta" } },
    { file = "gone.lua", first = 1, last = 1, kind = "block", names = { "epsilon" } },
}, { { 1, 0, 0 }, { 0.8, 0.6, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { -1, 0, 0 } })
local found = index.read(HAND .. "/.embedding-index")
local order, similarity = look.score(found, { 1, 0, 0 })
check("every piece scored in one pass, nearest first, ties by piece number",
    list(order) == "1,2,3,4,5" and math.abs(similarity[2] - 0.8) < 1e-6 and similarity[5] < -0.99,
    list(order))

local embedded = {}
local HV = { focused = 1, broad = 0, nearest = 2, spread = 5, curve = 1, budget = 100000 }
local function words_of(text)
    local n = 0
    for _ in string.gmatch(text, "%S+") do n = n + 1 end
    return n
end
local function hand(over)
    local opts = { project = HAND, commit = FULL, embedder = EMBEDDER, words = "alpha", focus = 1,
        name = "focused", values = HV, count_tokens = words_of,
        model_name = function() return "hand-model" end,
        embed = function(texts) embedded[#embedded + 1] = texts[1]; return { { 2, 0, 0 } } end }
    for key, value in pairs(over or {}) do opts[key] = value end
    return look.answer(opts)
end
local text, info = hand()
check("focus 1: the two nearest, labelled with file, lines, kind and similarity",
    info.pieces == 2 and has(text, "look focused (alpha): 2 of the project's 5 pieces, nearest first.")
    and has(text, "--- a.lua, lines 1-3 (function), similarity 1.000\nfunction alpha()\n    return 1\nend")
    and has(text, "--- a.lua, lines 4-6 (function), similarity 0.800"), text)
check("the words go to the embedder as their names, by the index's rule",
    embedded[1] == "alpha", embedded[1])
hand({ words = "the alphaValue if" })
check("(split and lower-cased, small words and keywords left out)",
    embedded[2] == "the alpha value", embedded[2])
text, info = hand({ focus = 0, name = "broad" })
check("focus 0: every piece, nearest to farthest, a file missing from the clone said so",
    info.pieces == 5 and info.nearest > 0.99 and info.farthest < -0.99
    and has(text, "--- gone.lua, lines 1-1 (block), similarity -1.000\n(this file is not in the clone)"), text)
-- the budget: room for pieces 1 and 3 but not 2, which is longer
local sizes = {}
for number = 1, 4 do
    local piece = { file = found.pieces[number].file, first = found.pieces[number].first,
        last = found.pieces[number].last, kind = found.pieces[number].kind, similarity = similarity[number] }
    sizes[number] = words_of(look.label(piece) .. "\n" .. look.source(HAND, piece, {}))
end
text, info = hand({ focus = 0.5, name = false, values = { focused = 1, broad = 0, nearest = 2, spread = 5, curve = 1,
    budget = sizes[1] + sizes[3] } })
check("over the budget: a longer piece left out, a shorter one after it still in",
    info.chosen == 4 and info.pieces == 2 and info.left_out == 2 and info.tokens == sizes[1] + sizes[3]
    and has(text, "lines 1-3") and has(text, "b.lua, lines 1-2") and not has(text, "lines 4-6"),
    text)
check("and the answer says how many did not fit",
    has(text, "(2 more pieces were chosen and did not fit in the " .. (sizes[1] + sizes[3])
        .. " tokens a look may give.)"), text)
check("the log line: pieces, similarities, tokens, left out",
    has(look.describe(info), "look 0.50 (alpha): 2 of 5 pieces, similarity 1.000 to 0.000, "
        .. (sizes[1] + sizes[3]) .. " tokens, 2 left out"), look.describe(info))

local function refused(name, over, kind, words)
    local said, got = hand(over)
    check(name, got.refused == kind and has(said, "There is nothing to show for this look: ")
        and not has(said, "---") and (not words or has(said, words)), said)
end
refused("no clone: refused", { project = false, no_clone = "the source cannot be reached" },
    "no-clone", "this voice has no clone of the project (the source cannot be reached)")
refused("no index: refused, never other files instead", { project = BASE .. "/voice" }, "no-index",
    "the project has no embedding index on this voice")
refused("an index from another commit: refused", { commit = string.rep("b", 40) }, "index-commit",
    "it is at aaaaaaa and the clone at bbbbbbb")
refused("an index from another model: refused", { model_name = function() return "other-model" end },
    "index-model", "the index was built by hand-model, and the embedder serves other-model")
refused("vectors of another length: refused", { embed = function() return { { 1, 0 } } end },
    "index-model", "the embedder gave 2 numbers, and the index has 3")
local before = #embedded
refused("words with no names: refused, without asking the embedder", { words = "a if end" }, "no-names",
    "look again with names from the project")
check("(the embedder was not asked)", #embedded == before)
refused("no embedder in the canvas: refused", { embedder = false, embed = false,
    no_embedder = "the canvas names no embedder" }, "no-embedder", "there is no embedding model")
local renamed_rule = (slurp(HAND .. "/.embedding-index/meta"):gsub('rule = "names%-v1"', 'rule = "names-v0"'))
write(BASE .. "/rule/.embedding-index/meta", renamed_rule)
shell("cp " .. q(HAND .. "/.embedding-index/pieces") .. " " .. q(HAND .. "/.embedding-index/vectors")
    .. " " .. q(BASE .. "/rule/.embedding-index/"))
refused("an index read by another name rule: refused", { project = BASE .. "/rule" }, "index-model",
    "its name rule is names-v0")
-- }}}

io.write("\n=== the embedder's line in the canvas ===\n")
-- {{{
local KUVALU = BASE .. "/kuvalu-root"
shell("mkdir -p " .. q(KUVALU) .. " && ln -s " .. q(DIR .. "/src") .. " " .. q(KUVALU .. "/src")
    .. " && ln -s " .. q(DIR .. "/libs") .. " " .. q(KUVALU .. "/libs"))
local ENDPOINTS = 'kuvalu-chat.url = "http://127.0.0.1:9"\nkuvalu-chat.kind = "chat"\nkuvalu-chat.timeout = 300\n'
    .. 'kuvalu-embed.url = "' .. embedder.url .. '"\nkuvalu-embed.kind = "embedding"\nkuvalu-embed.timeout = 60\n'
    .. 'use.fg-sora-1 = "kuvalu-chat"\n'
write(KUVALU .. "/endpoints", ENDPOINTS .. 'use.embedder = "kuvalu-embed"\n')
local lines, missing = to_voices.endpoint_lines(KUVALU, { "fg-sora-1" })
check("with use.embedder, the embedder's line comes last, after the voices'",
    #lines == 2 and lines[1].voice == "fg-sora-1" and lines[2].voice == "embedder"
    and lines[2].name == "kuvalu-embed" and lines[2].timeout == 60 and #missing == 0,
    json.encode(lines))
write(KUVALU .. "/endpoints", ENDPOINTS)
lines, missing = to_voices.endpoint_lines(KUVALU, { "fg-sora-1" })
check("without it, only the voices' lines, and nothing reported missing", #lines == 1 and #missing == 0)
write(KUVALU .. "/endpoints", (ENDPOINTS:gsub("kuvalu%-embed%.timeout = 60\n", ""))
    .. 'use.embedder = "kuvalu-embed"\n')
lines, missing = to_voices.endpoint_lines(KUVALU, { "fg-sora-1" })
check("an embedder with no timeout gets no line, and the reason is given",
    #lines == 1 and has(missing[1], "embedder's endpoint kuvalu-embed has no kuvalu-embed.timeout"),
    missing[1])
local CANVAS_TEXT = slurp(DIR .. "/assets/test-prompts/01-turn-prompt.canvas")
local function canvas_with(commit, endpoint_lines)
    return (CANVAS_TEXT:gsub("\nproject: guide%-feature %x+\n", "\nproject: guide-feature " .. commit .. "\n")
        :gsub("endpoints:\n.*$", "endpoints:\n" .. table.concat(endpoint_lines, "\n") .. "\n"))
end
local record = canvas.read(canvas_with("9f2c1e0", { "endpoint: fg-sora-1 kuvalu-chat 300 http://127.0.0.1:9",
    "endpoint: embedder kuvalu-embed 60 " .. embedder.url }), "to-voices", "test")
local e = caller.from_canvas(record, "embedder", ROOT)
local c = caller.from_canvas(record, "fg-sora-1", ROOT)
check("a voice reads the embedder's line as an embedding endpoint, its own as a chat one",
    e.kind == "embedding" and e.url == embedder.url and e.timeout == 60 and c.kind == "chat")
-- }}}

io.write("\n=== the keeper copies the project's index ===\n")
-- {{{
local MONO = BASE .. "/kuvalu/ai-stuff"
local P = MONO .. "/guide-feature"
local LOGS = BASE .. "/logs/guide-feature"
shell("mkdir -p " .. q(LOGS) .. " && ln -s " .. q(DIR .. "/src") .. " " .. q(LOGS .. "/src") .. " && ln -s "
    .. q(DIR .. "/libs") .. " " .. q(LOGS .. "/libs"))
local function commit(message)
    shell("git -C " .. q(MONO) .. " add -A && git -C " .. q(MONO)
        .. " -c user.name=test -c user.email=test@localhost commit -q -m " .. q(message))
    return (shell("git -C " .. q(MONO) .. " rev-parse --short=7 HEAD"))
end
local function full_of(short) return (shell("git -C " .. q(MONO) .. " rev-parse " .. short)) end
shell("git init -q " .. q(MONO))
write(P .. "/.gitignore", "/.embedding-index*\ntmp\n.claude/\n")
write(P .. "/input/embedding-index", slurp(DIR .. "/input/embedding-index"))
write(P .. "/src/001-canvas.lua", table.concat({
    "-- {{{ function M.canvas_width()", "function M.canvas_width(canvas)", "    return canvas.width",
    "end", "-- }}}", "", "-- {{{ function M.blit_rows()", "function M.blit_rows(rows, marks)",
    "    return rows", "end", "-- }}}", "" }, "\n"))
local many = {}
for i = 1, 12 do
    many[#many + 1] = "-- {{{ function M.helper_" .. i .. "()\nfunction M.helper_" .. i .. "(value_" .. i
        .. ")\n    return value_" .. i .. "\nend\n-- }}}\n"
end
write(P .. "/src/002-helpers.lua", table.concat(many, "\n"))
write(MONO .. "/other/thing.lua", "local other_project = 1\n")
local C1 = commit("one")
local function build_source()
    return pcall(builder.build, { root = P, url = embedder.url, timeout = 10, log_root = LOGS })
end
write(ROOT .. "/input/project-clone", (slurp(DIR .. "/input/project-clone")
    :gsub('\nrepository%.guide%-feature%s*= [^\n]*', '\nrepository.guide-feature = "' .. MONO .. '"')
    :gsub('\ndisk%-folder%s*= [^\n]*', '\ndisk-folder = "' .. BASE .. '/disk-clones"')))
local function keep(voice, at)
    return pcall(clone.keep, { root = ROOT, voice = voice, project = { name = "guide-feature", commit = at },
        filesystem_of = function() return "tmpfs" end })
end
local kept
ok, kept = keep("fg-sora-1", C1)
check("no index at the source: the clone is kept, and the index is none",
    ok and kept.index.state == "none" and has(clone.describe_index(kept), "no embedding index: the source "
        .. "has no index at " .. P .. "/.embedding-index"), ok and clone.describe_index(kept) or kept)
local built
ok, built = build_source()
check("(the source's index built at its commit)", ok and built.outcome == "built", built)
ok, kept = keep("fg-sora-1", C1)
local copied = index.read(ok and kept.project .. "/.embedding-index" or "")
check("then it is copied into the clone's project folder, whole",
    ok and kept.index.state == "copied" and copied and copied.meta.commit == full_of(C1)
    and copied.count == built.pieces, ok and clone.describe_index(kept) or kept)
check("and the log line says so", ok and clone.describe_index(kept)
    == "the embedding index was copied from the source, " .. built.pieces .. " pieces",
    ok and clone.describe_index(kept))
ok, kept = keep("fg-sora-1", C1)
check("the next turn at the same commit: already there",
    ok and kept.index.state == "already" and has(clone.describe_index(kept), "the embedding index is there"),
    ok and clone.describe_index(kept))
write(MONO .. "/other/thing.lua", "local other_project = 2\n")
local C2 = commit("only the other project")
ok, kept = keep("fg-sora-1", C2)
copied = index.read(ok and kept.project .. "/.embedding-index" or "")
check("a commit that touched only another project: the same index, renamed to the commit",
    ok and kept.index.state == "copied" and kept.index.renamed and copied
    and copied.meta.commit == full_of(C2) and has(clone.describe_index(kept), "renamed to this commit"),
    ok and clone.describe_index(kept) or kept)
write(P .. "/src/003-turn.lua", "-- {{{ function M.look_call()\nfunction M.look_call(reply_text)\n"
    .. "    return reply_text\nend\n-- }}}\n")
local C3 = commit("the project changed")
ok, kept = keep("fg-sora-1", C3)
copied = index.read(ok and kept.project .. "/.embedding-index" or "")
check("one that touched the project, before the source rebuilt: behind, and the old index left",
    ok and kept.index.state == "behind" and copied and copied.meta.commit == full_of(C2)
    and has(clone.describe_index(kept), "the source's index is at " .. C1 .. " and the clone at " .. C3),
    ok and clone.describe_index(kept) or kept)
text, info = look.answer({ project = kept.project, commit = kept.full, embedder = EMBEDDER,
    words = "canvas width", focus = 1, name = "focused", values = values, count_tokens = words_of })
check("so a look then is refused for the commit, not answered from the old index",
    info.refused == "index-commit", text)
ok, built = build_source()
ok, kept = keep("fg-sora-1", C3)
check("once the source has rebuilt: copied again", ok and kept.index.state == "copied"
    and index.read(kept.project .. "/.embedding-index").meta.commit == full_of(C3),
    ok and clone.describe_index(kept) or kept)
text, info = look.answer({ project = kept.project, commit = kept.full, embedder = EMBEDDER,
    words = "canvas width", focus = 1, name = "focused", values = values, count_tokens = words_of })
check("and a look reads the clone's own files: the canvas width function, nearest",
    not info.refused and info.shown[1].file == "src/001-canvas.lua" and info.shown[1].first == 1
    and has(text, "function M.canvas_width(canvas)\n    return canvas.width"), text)
ok, kept = keep("fg-sora-2", C3)
check("another voice's clone gets its own copy", ok and kept.index.state == "copied"
    and has(kept.project, "/fg-sora-2/"), ok and kept.project or kept)
-- }}}

io.write("\n=== the turn answers look calls ===\n")
-- {{{
local chat = start_server("chat", "chat", { "look focused: canvas width", "look broad: helper value",
    { rewrite = "lamp" } })
local GIVEN = BASE .. "/given"
write(GIVEN, canvas_with(C3, { "endpoint: fg-sora-1 stand-in-chat 30 " .. chat.url,
    "endpoint: fg-sora-2 stand-in-chat 30 " .. chat.url,
    "endpoint: embedder stand-in-embed 30 " .. embedder.url }))
local OUT = BASE .. "/out"
local SHM = BASE .. "/shm/guide-feature"
ok, problem = pcall(turn_module.run, { root = ROOT, voice = "fg-sora-1", turn = 1, canvas = GIVEN, out = OUT })
local log = slurp(SHM .. "/turn-fg-sora-1.log") or ""
local receipt = goodbye.read(ROOT .. "/output/goodbye-turn-fg-sora-1")
check("the turn runs: two looks, then a canvas that fits", ok and problem == "sent"
    and slurp(OUT) ~= nil, problem)
local asked = requests(chat, "/v1/chat/completions")
local second = asked[2] and asked[2].body.messages
local answer = second and second[#second].content or ""
check("the model's second ask holds the focused look's pieces, nearest first",
    #asked == 3 and has(answer, "look focused (canvas width): 4 of the project's ")
    and has(answer, "--- src/001-canvas.lua, lines 1-5 (function), similarity "), answer)
local third = asked[3] and asked[3].body.messages
local broad_answer = third and third[#third].content or ""
check("and its third the broad one's, more pieces", has(broad_answer, "look broad (helper value): ")
    and select(2, string.gsub(broad_answer, "\n%-%-%- ", "")) > 4, broad_answer)
check("the log says where the index came from and what each look gave",
    has(log, ": the embedding index is there, ")
    and string.find(log, "look focused %(canvas width%): 4 of %d+ pieces, similarity [%d.]+ to [%d.]+, %d+ tokens")
    and has(log, "look broad (helper value): "), log)
local counts = receipt and receipt.counters or {}
check("the receipt counts the index, the looks, their pieces and tokens",
    counts["index-already"] == 1 and counts["look-calls"] == 2 and counts["looks-focused"] == 1
    and counts["looks-broad"] == 1 and (counts["look-pieces"] or 0) > 8 and (counts["look-tokens"] or 0) > 50,
    json.encode(counts))
check("the tokens were counted by the voice's own chat model",
    #requests(chat, "/tokenize") >= 4, #requests(chat, "/tokenize"))

local chat2 = start_server("chat2", "chat", { "look focused: canvas width", { rewrite = "lamp" } })
write(GIVEN, canvas_with(C3, { "endpoint: fg-sora-2 stand-in-chat 30 " .. chat2.url }))
ok, problem = pcall(turn_module.run, { root = ROOT, voice = "fg-sora-2", turn = 1, canvas = GIVEN, out = OUT })
asked = requests(chat2, "/v1/chat/completions")
second = asked[2] and asked[2].body.messages
answer = second and second[#second].content or ""
receipt = goodbye.read(ROOT .. "/output/goodbye-turn-fg-sora-2")
counts = receipt and receipt.counters or {}
check("a canvas with no embedder: the look is refused, the model told why, the turn goes on",
    ok and problem == "sent" and has(answer, "there is no embedding model to read your words with")
    and counts["look-refused"] == 1 and counts["look-refused-no-embedder"] == 1, answer)
-- }}}

io.write("\n=== a copy that does not check ===\n")
-- {{{
write(P .. "/src/004-more.lua", "local function more_names(here) return here end\n")
local C4 = commit("more")
build_source()
local vectors = slurp(P .. "/.embedding-index/vectors")
write(P .. "/.embedding-index/vectors", string.sub(vectors, 1, #vectors - 4))
ok, kept = keep("fg-sora-1", C4)
check("is not used: failed, saying why, and the turn's clone is kept",
    ok and kept.index.state == "failed" and has(kept.index.why, "the copy does not check")
    and kept.full == full_of(C4) and not io.open(kept.project .. "/.embedding-index.part/.embedding-index/meta"),
    ok and clone.describe_index(kept) or kept)
write(P .. "/src/005-zero.lua", "local function zero_names(there) return there end\n")
local C5 = commit("zero")
build_source()
vectors = slurp(P .. "/.embedding-index/vectors")
write(P .. "/.embedding-index/vectors", string.rep("\0", #vectors))
ok, kept = keep("fg-sora-1", C5)
check("nor one that reads but does not check (vectors not of length 1)",
    ok and kept.index.state == "failed" and has(kept.index.why, "vector has length 0.0000, not 1"),
    ok and clone.describe_index(kept) or kept)
-- }}}

io.write("\n=== guide-feature's own index: one question, focused and broad ===\n")
-- {{{
-- The index of guide-feature's files at a pinned commit (issue 502's), so
-- the reference looks stay the same as the project moves on.
local PINNED = "be7b82761"
local REFERENCES = DIR .. "/assets/test-looks"
local prefix = shell("git -C " .. q(DIR) .. " rev-parse --show-prefix") or ""
local top = shell("git -C " .. q(DIR) .. " rev-parse --show-toplevel") or DIR
local OWN = BASE .. "/own/guide-feature"
local _, has_pinned = shell("git -C " .. q(DIR) .. " cat-file -e " .. PINNED .. "^{commit}")
if has_pinned ~= 0 then
    io.write("  (skipped: this checkout lacks commit " .. PINNED .. ")\n")
else
    shell("mkdir -p " .. q(OWN) .. " && git -C " .. q(top) .. " archive " .. q(PINNED .. ":" .. prefix)
        .. " | tar -C " .. q(OWN) .. " -xf - && git -C " .. q(OWN) .. " init -q && git -C " .. q(OWN)
        .. " add -A && git -C " .. q(OWN) .. " -c user.name=test -c user.email=test@localhost commit -q -m pinned")
    local started = os.time()
    ok, built = pcall(builder.build, { root = OWN, url = embedder.url, timeout = 30, log_root = LOGS })
    check("(guide-feature's index at " .. PINNED .. " built)", ok and built.outcome == "built", built)
    io.write("        (" .. tostring(ok and built.pieces) .. " pieces in " .. (os.time() - started) .. " s)\n")
    local own_full = shell("git -C " .. q(OWN) .. " rev-parse HEAD")
    local sets = {}
    for _, focus in ipairs({ 1, 0.5, 0 }) do
        local said, got = look.answer({ project = OWN, commit = own_full, embedder = EMBEDDER,
            words = "canvas width", focus = focus, values = values, count_tokens = words_of })
        local rows = {}
        for _, piece in ipairs(got.shown or {}) do
            rows[#rows + 1] = string.format("%4d  %.4f  %s %d-%d (%s)", piece.rank, piece.similarity,
                piece.file, piece.first, piece.last, piece.kind)
        end
        local reference = table.concat(rows, "\n") .. "\n"
        local name = string.format("canvas-width-focus-%s.txt", tostring(focus):gsub("%.", "-"))
        if WRITE_REFERENCES then write(REFERENCES .. "/" .. name, reference) end
        check(string.format("focus %s: the pieces of the reference %s", tostring(focus), name),
            not got.refused and reference == slurp(REFERENCES .. "/" .. name),
            "got:\n" .. reference .. "\n        " .. tostring(got.why))
        sets[focus] = got
    end
    local focused, wide = sets[1], sets[0]
    local shared = 0
    for _, a in ipairs(focused.shown or {}) do
        for _, b in ipairs(wide.shown or {}) do if a.number == b.number then shared = shared + 1 end end
    end
    check("visibly different sets: focused and broad share only the nearest piece",
        shared == 1 and #(wide.shown or {}) > #(focused.shown or {}), shared)
    check("focused stays near; broad reaches the far end",
        focused.farthest and wide.farthest and focused.farthest > sets[0.5].farthest
        and sets[0.5].farthest > wide.farthest and wide.shown[#wide.shown].rank == wide.count,
        string.format("%s %s %s", tostring(focused.farthest), tostring(sets[0.5].farthest),
            tostring(wide.farthest)))
end
-- }}}

shell("kill " .. embedder.pid .. " " .. chat.pid .. " " .. chat2.pid .. " 2>/dev/null")
if failed > 0 and KEEP then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
