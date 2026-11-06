#!/usr/bin/env luajit
-- Tests for libs/project-dir.lua (Issue 10-076): every program's project
-- folder comes from --dir PATH, and a word with no flag in front of it stops
-- the program, named. And the shell twin, libs/project-dir.sh, run through
-- bash with the same cases, so the two cannot drift apart.
--
-- Run directly:  luajit libs/project-dir.test.lua [--dir PROJECT]

local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local reader = dofile(here .. "project-dir.lua")
-- this test's own folder, read the way every program reads it
local DIR = dofile(here .. "project-dir.lua").read(arg, (here:gsub("libs/$", "")):gsub("/$", ""))
-- from here on a refusal is an error the cases below catch, not an exit
reader.raise_errors = true

local passed, failed = 0, 0
-- {{{ local function check()
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. tostring(detail)) or ""))
    end
end
-- }}}

-- {{{ local function words()
-- A command line as the reader sees it: arg[0] is the program's name.
local function words(...)
    local t = { ... }
    t[0] = "some-program"
    return t
end
-- }}}

-- {{{ Lua cases
do
    local dir, rest = reader.read(words(), "/default")
    check("no --dir: the default folder", dir == "/default" and #rest == 0, dir)

    dir = reader.read(words("--dir", "/p"), "/default")
    check("--dir PATH sets the folder", dir == "/p", dir)

    dir = reader.read(words("--dir=/p"), "/default")
    check("--dir=PATH sets the folder", dir == "/p", dir)

    dir = reader.read(words("--dir", "/p//"), "/default")
    check("trailing slashes are dropped", dir == "/p", dir)

    dir, rest = reader.read(words("--threads", "4", "--dir", "/p", "--force"), "/d", { ["--threads"] = true })
    check("the program's own flags come back in order, with their values",
        dir == "/p" and rest[1] == "--threads" and rest[2] == "4" and rest[3] == "--force" and #rest == 3,
        table.concat(rest, " "))

    local ok, err = pcall(reader.read, words("--threads", "4"), "/d")
    check("a value flag the program did not declare leaves its value stray, and stops it",
        not ok and err:find("unexpected word on the command line: 4", 1, true), err)

    ok, err = pcall(reader.read, words("wordcloud-poems", "64"), "/d")
    check("a bare word stops the program, named, with the program's name",
        not ok and err:find("some-program: unexpected word on the command line: wordcloud-poems", 1, true), err)

    ok, err = pcall(reader.read, words("--dir"), "/d")
    check("--dir with nothing after it stops", not ok and err:find("--dir needs a folder", 1, true), err)

    ok, err = pcall(reader.read, words("--dir", "--force"), "/d")
    check("--dir followed by a flag stops", not ok and err:find("--dir needs a folder", 1, true), err)

    ok, err = pcall(reader.read, words("--dir="), "/d")
    check("--dir= with nothing after it stops", not ok and err:find("--dir= needs a folder", 1, true), err)

    dir, rest = reader.read(words("--model=x", "--dir", "/p"), "/d")
    check("a --flag=value word needs no declaring", dir == "/p" and rest[1] == "--model=x", rest[1])

    dir, rest = reader.read(words("--dir", "/p", "--model", "", "--seed", "5"), "/d", "*")
    check("\"*\": every flag takes the next word, even an empty one",
        dir == "/p" and #rest == 4 and rest[2] == "" and rest[4] == "5", table.concat(rest, "|"))
end
-- }}}

-- {{{ shell cases: libs/project-dir.sh gives the same answers
-- {{{ local function sh()
-- Runs the shell reader on a command line; returns its exit status and
-- what it printed ("DIR|word word ..." on success, the error otherwise).
-- The driver is a file run by bash: io.popen goes through /bin/sh, which
-- cannot read bash's arrays, so the bash side must not be inline. The words
-- of `line` are plain (no spaces inside a word), so the shell splits them.
local DRIVER = DIR .. "/tmp/shared-memory/project-dir-test-driver.sh"
os.execute(string.format("mkdir -p %q", DIR .. "/tmp/shared-memory"))
do
    local f = assert(io.open(DRIVER, "w"))
    f:write("source '", DIR, "/libs/project-dir.sh'\n",
        "flags=\"$1\"; shift\n",
        "project_dir_read /default \"$flags\" \"$@\"\n",
        "printf '%s|%s' \"$DIR\" \"${PROJECT_ARGS[*]}\"\n")
    f:close()
end
local function sh(value_flags, line)
    local p = assert(io.popen(string.format("bash %q %q %s 2>&1; echo \"|exit=$?\"", DRIVER, value_flags, line)))
    local out = p:read("*a")
    p:close()
    local status = tonumber(out:match("|exit=(%d+)"))
    return status, (out:gsub("|exit=%d+%s*$", ""))
end
-- }}}
do
    local status, out = sh("", "")
    check("shell: no --dir: the default folder", status == 0 and out == "/default|", out)
    status, out = sh("", "--dir /p")
    check("shell: --dir PATH", status == 0 and out == "/p|", out)
    status, out = sh("", "--dir=/p/")
    check("shell: --dir=PATH, trailing slash dropped", status == 0 and out == "/p|", out)
    status, out = sh("--jobs", "--jobs 4 --dir /p --force")
    check("shell: own flags come back in order, with values", status == 0 and out == "/p|--jobs 4 --force", out)
    status, out = sh("", "wordcloud-poems 64")
    check("shell: a bare word stops the script, named",
        status == 1 and out:find("unexpected word on the command line: wordcloud-poems", 1, true), out)
    status, out = sh("", "--dir")
    check("shell: --dir with nothing after it stops", status == 1 and out:find("--dir needs a folder", 1, true), out)
    status, out = sh("", "--dir --force")
    check("shell: --dir followed by a flag stops", status == 1 and out:find("--dir needs a folder", 1, true), out)
end
-- }}}

-- {{{ a person at a terminal: one line and exit 1, no stack trace
do
    local program = DIR .. "/tmp/shared-memory/project-dir-test-program.lua"
    local f = assert(io.open(program, "w"))
    f:write("dofile('", DIR, "/libs/project-dir.lua').read(arg, '/d')\n")
    f:close()
    local p = assert(io.popen(string.format("luajit %q some-word 2>&1; echo \"|exit=$?\"", program)))
    local out = p:read("*a")
    p:close()
    os.remove(program)
    check("a refusal at the terminal exits 1 with one line, no traceback",
        out:find("|exit=1", 1, true) and out:find("unexpected word on the command line: some-word", 1, true)
            and not out:find("traceback", 1, true), out)
end
-- }}}

os.remove(DRIVER)
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
