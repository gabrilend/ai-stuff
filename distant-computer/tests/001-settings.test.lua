-- 001-settings.test.lua - checks that the settings reader accepts a good file
-- and refuses each kind of bad one, naming the right line.
--
-- In plain terms: writes small settings files into RAM scratch space, reads
-- them, and checks the answer or the refusal. Run by tests/run-tests, which
-- passes the project folder and a scratch folder.

local PROJECT_DIR = arg[1]
local SCRATCH_DIR = arg[2]
local settings = dofile(PROJECT_DIR .. "/src/001-settings.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(description, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        io.write("FAILED: ", description, detail and ("\n    " .. detail) or "", "\n")
    end
end
-- }}}

-- {{{ local function write_file()
local function write_file(name, text)
    local path = SCRATCH_DIR .. "/" .. name
    local file = assert(io.open(path, "w"))
    file:write(text)
    file:close()
    return path
end
-- }}}

-- {{{ local function refusal()
-- Reads a file that should be refused; gives the error text, or nil when it
-- was (wrongly) accepted.
local function refusal(path, declaration)
    local ok, message = pcall(settings.read, path, declaration)
    if ok then return nil end
    return message
end
-- }}}

local DECLARATION = {
    interval = { type = "whole", required = true },
    ratio = { type = "decimal", required = true },
    host = { type = "text", required = true },
    reason = { type = "text", required = false },
    projects = { type = "words", required = false },
}

-- a good file, with every type and every comment form
local good = write_file("good", table.concat({
    "# the whole file is described here",
    "",
    "interval = 30           # seconds",
    "ratio = .75",
    'host = "steward@203.0.113.7"',
    'reason = "fix issue #4, said \\"carefully\\" \\\\ twice"   # a comment after quotes',
    "projects = guide-feature, neocities-modernization ,distant-computer",
}, "\n") .. "\n")
local ok, values = pcall(settings.read, good, DECLARATION)
check("a good file is read", ok, not ok and values or nil)
if ok then
    check("whole number", values.interval == 30)
    check("decimal with no leading digit", values.ratio == 0.75)
    check("quoted text holding @", values.host == "steward@203.0.113.7")
    check("quoted text keeps # and unescapes", values.reason == 'fix issue #4, said "carefully" \\ twice',
        tostring(values.reason))
    check("list of words, spaces trimmed", values.projects and #values.projects == 3
        and values.projects[2] == "neocities-modernization")
end

-- The @ in host is not a bare-word character, so that line must be refused.
-- This checks the bare-word rule itself: a host with a user belongs in quotes.
local at_sign = write_file("at-sign", "interval = 1\nratio = 1\nhost = a@b\n")
local message = refusal(at_sign, DECLARATION)
check("@ is not a bare-word character", message and string.find(message, ":3:", 1, true), message)

-- each refusal, and the line it must name
local CASES = {
    { "missing file", nil, "cannot open" },
    { "undeclared name", "interval = 1\nratio = 1\nhost = a\ncolour = red\n", ":4: 'colour' is not a setting" },
    { "missing required", "interval = 1\n", ":0: missing required setting(s): host, ratio" },
    { "wrong type", "interval = soon\nratio = 1\nhost = a\n", ":1: interval: expected a whole number" },
    { "repeated name", "interval = 1\ninterval = 2\nratio = 1\nhost = a\n", ":2: 'interval' was already given on line 1" },
    { "no value", "interval =\nratio = 1\nhost = a\n", ":1: 'interval' has no value" },
    { "not name = value", "interval 1\n", ":1: expected 'name = value'" },
    { "sentence without quotes", "interval = 1\nratio = 1\nhost = two words\n", ":3: host:" },
    { "bad escape", 'interval = 1\nratio = 1\nhost = "C:\\temp"\n', ":3: host: only" },
    { "list item not a word", "interval = 1\nratio = 1\nhost = a\nprojects = a, \"b\"\n", ":4: projects:" },
}
for index, case in ipairs(CASES) do
    local path = case[2] and write_file("case-" .. index, case[2]) or (SCRATCH_DIR .. "/no-such-file")
    local text = refusal(path, DECLARATION)
    check("refuses: " .. case[1], text and string.find(text, case[3], 1, true),
        "got: " .. tostring(text))
end

-- a broken declaration is the program's error, raised before reading
local declared_badly = pcall(settings.read, good, { interval = { type = "integer", required = true } })
check("an unknown type in a declaration is refused", not declared_badly)

io.write(string.format("settings: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
