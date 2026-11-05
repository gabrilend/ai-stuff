#!/usr/bin/env luajit
-- 003-test-settings.lua
--
-- Reads a good settings file and checks every value came out as the kind it
-- was declared; then one bad file for each way a file can be wrong, checking
-- each is refused with its file and line. Then the endpoints file, good and
-- bad, and that reading makes the RAM tiers.
--
-- For a general: every program in this project takes its knobs from one small
-- file. This proves a mistyped knob stops the program with the line to fix,
-- instead of the program running on a value nobody chose.
--
-- The project it reads is a throwaway copy, made under the system's temporary
-- folder with its own RAM tiers there, so nothing of the real project is
-- touched.
--
-- usage:
--   luajit 003-test-settings.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
ffi.cdef("int setenv(const char *name, const char *value, int overwrite);")

local settings = dofile(DIR .. "/src/001-settings.lua")

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

-- {{{ local function refused()
-- Runs fn, and checks it raised an error whose message starts with `start`
-- and contains `part`.
local function refused(name, start, part, fn)
    local ok, message = pcall(fn)
    check(name, not ok and string.sub(tostring(message), 1, #start) == start
        and string.find(tostring(message), part, 1, true) ~= nil,
        ok and "it was accepted" or message)
end
-- }}}

-- {{{ local function shell()
local function shell(command)
    local pipe = io.popen(command .. " 2>&1")
    local text = pipe:read("*a")
    pipe:close()
    return (string.gsub(text, "\n$", ""))
end
-- }}}

-- {{{ the throwaway project
-- A root named guide-feature (the tiers are named after it), holding links to
-- the real src/ and libs/, and its own input/ and output/. The tiers' roots are
-- moved under the same throwaway folder, the way the library allows for tests.
local BASE = shell("mktemp -d")
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p '" .. ROOT .. "/input' '" .. ROOT .. "/output' '"
    .. BASE .. "/exec' '" .. BASE .. "/shm'")
shell("ln -s '" .. DIR .. "/src' '" .. ROOT .. "/src'")
shell("ln -s '" .. DIR .. "/libs' '" .. ROOT .. "/libs'")
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)

local function write(path, text)
    local handle = assert(io.open(ROOT .. "/" .. path, "w"))
    handle:write(text)
    handle:close()
end
-- }}}

-- {{{ the declarations used throughout
local DECLARED = {
    ["canvas-size"]   = { type = "WxH", required = true },
    ["mark-lifetime"] = { type = "whole", required = true },
    ["merge-mode"]    = { type = "choice", of = { "newest", "distill" }, required = true },
    ["voices"]        = { type = "names", required = true },
    ["fade"]          = { type = "decimal" },
    ["title"]         = { type = "text" },
    ["not-set"]       = { type = "whole" },
}
local GOOD = table.concat({
    "# the blitter's settings, as a person would write them",
    "",
    "canvas-size   = 80x24            # columns x rows",
    "  mark-lifetime=12",
    'merge-mode    = "newest"',
    'voices        = "fg-sora-1, fg-sora-2 fg-sora-3"',
    "fade          = -0.25",
    'title         = "a \\"quoted\\" # not a comment \\\\ end"   # a comment',
}, "\n") .. "\n"
-- }}}

io.write("\n=== a good file ===\n")
-- {{{
write("input/blitter", GOOD)
local ok, values, lines = pcall(settings.read, "blitter", DECLARED, { root = ROOT })
check("a good file is read", ok, values)
if ok then
    check("WxH is a width and a height",
        values["canvas-size"].width == 80 and values["canvas-size"].height == 24)
    check("whole is a number", values["mark-lifetime"] == 12)
    check("choice is its word", values["merge-mode"] == "newest")
    check("names is a list, split on commas and spaces",
        #values.voices == 3 and values.voices[1] == "fg-sora-1"
        and values.voices[3] == "fg-sora-3")
    check("decimal is a number", values.fade == -0.25)
    check("text keeps its escaped quotes, its # and its backslash",
        values.title == 'a "quoted" # not a comment \\ end', values.title)
    check("an optional setting not set is absent, with no default", values["not-set"] == nil)
    check("each setting's line is kept", lines["merge-mode"] == 5 and lines.title == 8)
end
-- }}}

io.write("\n=== the RAM tiers ===\n")
-- {{{
check("tmp/ was made", shell("readlink '" .. ROOT .. "/tmp'") == BASE .. "/exec/guide-feature")
check("tmp/shared-memory/ leads into the artifact room",
    shell("cd '" .. ROOT .. "/tmp/shared-memory' && pwd -P") == BASE .. "/shm/guide-feature")
-- }}}

io.write("\n=== read again ===\n")
-- {{{
write("input/blitter", (string.gsub(GOOD, '"newest"', '"distill"')))
local again = settings.read("blitter", DECLARED, { root = ROOT })
check("a second read sees the edited file", again["merge-mode"] == "distill")
write("input/blitter", GOOD)
-- }}}

io.write("\n=== each kind of bad file is refused, with its place ===\n")
-- {{{
local function bad(name, text, start, part, declared)
    write("input/bad", text)
    refused(name, start, part, function()
        return settings.read("bad", declared or DECLARED, { root = ROOT })
    end)
end
local REST = 'mark-lifetime = 12\nmerge-mode = "newest"\nvoices = "a"\n'

refused("a missing file", "input/nothing:", "no settings file", function()
    return settings.read("nothing", DECLARED, { root = ROOT })
end)
bad("an unknown name", "canvas-size = 80x24\n" .. REST .. "mode = 3\n",
    "input/bad:5:", "'mode' is not one of this file's settings")
bad("a missing required name", "canvas-size = 80x24\nvoices = \"a\"\n",
    "input/bad:", "'mark-lifetime', 'merge-mode' are required and not set")
bad("a setting set twice", "canvas-size = 80x24\n" .. REST .. "canvas-size = 10x10\n",
    "input/bad:5:", "set again (first on line 1)")
bad("a quoted whole number", 'canvas-size = 80x24\nmark-lifetime = "12"\nmerge-mode = "newest"\nvoices = "a"\n',
    "input/bad:2:", "must be a whole number")
bad("a fraction where a whole number goes", "canvas-size = 80x24\nmark-lifetime = 1.5\n",
    "input/bad:2:", "must be a whole number")
bad("a word where a decimal goes", "canvas-size = 80x24\n" .. REST .. "fade = half\n",
    "input/bad:5:", "must be a number")
bad("bare text", "canvas-size = 80x24\n" .. REST .. "title = hello\n",
    "input/bad:5:", "must be text in double quotes")
bad("a size with no x", "canvas-size = 80\n" .. REST,
    "input/bad:1:", "must be a size")
bad("a size of zero rows", "canvas-size = 80x0\n" .. REST,
    "input/bad:1:", "must be a size")
bad("a word that is not a choice", 'canvas-size = 80x24\nmark-lifetime = 12\nmerge-mode = "newst"\nvoices = "a"\n',
    "input/bad:3:", 'must be one of "newest", "distill"')
bad("a choice written bare", "canvas-size = 80x24\nmark-lifetime = 12\nmerge-mode = newest\nvoices = \"a\"\n",
    "input/bad:3:", "must be one of")
bad("a name twice in a list", 'canvas-size = 80x24\nmark-lifetime = 12\nmerge-mode = "newest"\nvoices = "a b a"\n',
    "input/bad:4:", "names 'a' twice")
bad("a list entry that is not a name", 'canvas-size = 80x24\nmark-lifetime = 12\nmerge-mode = "newest"\nvoices = "a b/c"\n',
    "input/bad:4:", "'b/c', which is not a name")
bad("a line with no =", "canvas-size 80x24\n",
    "input/bad:1:", "expected `name = value`")
bad("a name with a space-free but bad character", "canvas/size = 80x24\n",
    "input/bad:1:", "is not a setting's name")
bad("no value", "canvas-size =   # nothing\n",
    "input/bad:1:", "no value after '='")
bad("an unclosed quote", 'title = "open\n',
    "input/bad:1:", "no closing quote")
bad("an unknown escape", 'title = "a\\nb"\n',
    "input/bad:1:", "is not an escape here")
bad("text after a value", "canvas-size = 80x24 wide\n",
    "input/bad:1:", "more after the value: wide")
bad("a line number counts blank and comment lines", "# one\n\n# three\ncanvas-size = big\n",
    "input/bad:4:", "must be a size")
refused("a program's own unknown type is the program's fault", "settings: bad declares", "unknown type", function()
    return settings.read("bad", { x = { type = "colour" } }, { root = ROOT })
end)
refused("a choice declared without its words", "settings: bad declares", "without its words", function()
    return settings.read("bad", { x = { type = "choice" } }, { root = ROOT })
end)
refused("a program name that is not a name", "settings:", "is not a program's name", function()
    return settings.read("../etc", DECLARED, { root = ROOT })
end)
-- }}}

io.write("\n=== the endpoints file ===\n")
-- {{{
local ENDPOINTS = table.concat({
    "# -- the endpoints --",
    'kuvalu-qwen.url      = "http://192.168.1.100:20166"',
    'kuvalu-qwen.kind     = "chat"',
    "kuvalu-qwen.timeout  = 300",
    'kuvalu-qwen.model    = "models/qwen.gguf"',
    "kuvalu-qwen.port     = 20166",
    'kuvalu-embed.url     = "http://192.168.1.100:20167"',
    'kuvalu-embed.kind    = "embedding"',
    'far-away.url         = "https://example.invalid/llama"',
    'far-away.kind        = "chat"',
    'far-away.key-file    = "~/.config/guide-feature/keys/far-away"',
    "# -- who uses which --",
    'use.fg-sora-1 = "kuvalu-qwen"',
    'use.fg-sora-2 = "far-away"',
    'use.distiller = "kuvalu-qwen"',
    'use.embedder  = "kuvalu-embed"',
    'use.url       = "kuvalu-qwen"   # a role called url is a role, not an address',
    'use.timeout   = "kuvalu-qwen"   # and a role called timeout is text, not a number',
}, "\n") .. "\n"
write("endpoints", ENDPOINTS)
local eok, ends = pcall(settings.read_endpoints, { root = ROOT })
check("the endpoints file is read", eok, ends)
if eok then
    local qwen = ends.endpoints["kuvalu-qwen"]
    check("an endpoint's fields are grouped under its name",
        qwen.url == "http://192.168.1.100:20166" and qwen.kind == "chat"
        and qwen.timeout == 300 and qwen.port == 20166 and qwen.model == "models/qwen.gguf")
    check("a key-file is text", ends.endpoints["far-away"]["key-file"]
        == "~/.config/guide-feature/keys/far-away")
    check("roles name their endpoints", ends.use["fg-sora-2"] == "far-away"
        and ends.use.embedder == "kuvalu-embed")
    check("use.url is a role", ends.use.url == "kuvalu-qwen" and ends.endpoints.use == nil)
    check("use.timeout is a role, read as text by use.*", ends.use.timeout == "kuvalu-qwen")
end

local function bad_endpoints(name, text, start, part)
    write("endpoints", text)
    refused(name, start, part, function() return settings.read_endpoints({ root = ROOT }) end)
end
bad_endpoints("an endpoint with no kind", 'a.url = "http://x"\n',
    "endpoints:1:", "the endpoint 'a' has no a.kind")
bad_endpoints("an endpoint with no url", '\na.kind = "chat"\n',
    "endpoints:2:", "the endpoint 'a' has no a.url")
bad_endpoints("a kind that is not chat or embedding", 'a.url = "http://x"\na.kind = "vision"\n',
    "endpoints:2:", 'must be one of "chat", "embedding"')
bad_endpoints("a role naming no endpoint", 'a.url = "http://x"\na.kind = "chat"\nuse.fg-sora-1 = "b"\n',
    "endpoints:3:", "names 'b', which is not an endpoint")
bad_endpoints("a voice on an embedding endpoint",
    'a.url = "http://x"\na.kind = "embedding"\nuse.fg-sora-1 = "a"\n',
    "endpoints:3:", "needs a chat endpoint")
bad_endpoints("the embedder on a chat endpoint",
    'a.url = "http://x"\na.kind = "chat"\nuse.embedder = "a"\n',
    "endpoints:3:", "needs a embedding endpoint")
bad_endpoints("an unknown field", 'a.url = "http://x"\na.kind = "chat"\na.colour = "red"\n',
    "endpoints:3:", "'a.colour' is not one of this file's settings")
bad_endpoints("a quoted port", 'a.url = "http://x"\na.kind = "chat"\na.port = "1"\n',
    "endpoints:3:", "must be a whole number")
shell("rm '" .. ROOT .. "/endpoints'")
refused("no endpoints file", "endpoints:", "no endpoints file", function()
    return settings.read_endpoints({ root = ROOT })
end)
-- }}}

shell("rm -rf '" .. BASE .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
