#!/usr/bin/env luajit
-- 059-test-project-clone.lua
--
-- Tests the clone keeper (issue 501, src/058-project-clone.lua,
-- scripts/project-clone) on throwaway git repositories standing in for
-- kuvalu's checkout, here on this machine.
--
-- The keeper by itself: a first clone placed in RAM, holding only the
-- project's folder and none of the other folders' files; the same commit
-- again (nothing to do); a newer commit (fetched and checked out); an older
-- one already held (checked out, no fetch); a project switch and back (the
-- first clone kept, so no new clone); a RAM clone lost, as after a reboot,
-- made again; a project too big for its RAM share, a RAM folder that is not
-- a tmpfs, and one that cannot be made (each on disk, the log saying why);
-- a clone measured bigger once made than its estimate (moved to disk);
-- refusals (a project not listed, a commit the source lacks, a URL), and
-- the command that reaches kuvalu over SSH. The turn's step 2: the log line
-- and the receipt's counts, and a turn that goes on when there is no clone.
-- Then the rehearsal with the real turn in all three voices: each voice
-- clones the project at its first turn, keeps it, and fetches the newer
-- commit made while the rehearsal runs.
--
-- For a general: each voice now keeps its own copy of the project being
-- worked on, at the version kuvalu is at, in memory when it fits.
--
-- usage:
--   luajit 059-test-project-clone.lua [--dir ROOT]

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
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function q(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function exists(path) return select(2, shell("test -e " .. q(path))) == 0 end
-- }}}

-- {{{ the throwaway project, in RAM where this machine has a tmpfs
-- /dev/shm is a tmpfs on Linux; the clones placed "in RAM" are then really
-- in RAM. Where it is not, the RAM cases say the RAM folder is a tmpfs
-- through the keeper's filesystem seam.
local clone = dofile(DIR .. "/src/058-project-clone.lua")
local BASE = shell("mktemp -d -p /dev/shm 2>/dev/null || mktemp -d")
BASE = shell("cd " .. q(BASE) .. " && pwd -P")
local REAL_TMPFS = clone.filesystem_of(BASE) == "tmpfs"
local AS_TMPFS = not REAL_TMPFS and function() return "tmpfs" end or nil
local ROOT = BASE .. "/project/guide-feature"
shell("mkdir -p " .. q(ROOT .. "/input") .. " " .. q(ROOT .. "/output") .. " "
    .. q(BASE .. "/exec") .. " " .. q(BASE .. "/shm") .. " " .. q(BASE .. "/kuvalu"))
for _, name in ipairs({ "src", "libs", "scripts" }) do
    shell("ln -s " .. q(DIR .. "/" .. name) .. " " .. q(ROOT .. "/" .. name))
end
ffi.C.setenv("EXEC_TIER_ROOT", BASE .. "/exec", 1)
ffi.C.setenv("ARTIFACT_TIER_ROOT", BASE .. "/shm", 1)
local KEEP = (os.getenv("KEEP") or "") ~= ""
local RAM = ROOT .. "/tmp/shared-memory/clones"
local DISK = BASE .. "/disk-clones"
-- }}}

-- {{{ kuvalu's repositories, here: a monorepo with the project in a folder
local MONO = BASE .. "/kuvalu/ai-stuff"
local SECOND = BASE .. "/kuvalu/second"
local function commit(repo, message)
    shell("git -C " .. q(repo) .. " add -A && git -C " .. q(repo)
        .. " -c user.name=test -c user.email=test@localhost commit -q -m " .. q(message))
    return (shell("git -C " .. q(repo) .. " rev-parse --short=7 HEAD"))
end
shell("mkdir -p " .. q(MONO .. "/guide-feature/src") .. " " .. q(MONO .. "/other") .. " "
    .. q(SECOND) .. " && git -C " .. q(MONO) .. " init -q && git -C " .. q(SECOND) .. " init -q")
write(MONO .. "/guide-feature/src/a.lua", "local canvas_width = 60\n")
write(MONO .. "/guide-feature/src/b.lua", "local function blit(rows) return rows end\n")
shell("head -c 300000 /dev/urandom > " .. q(MONO .. "/other/big.bin"))
local C1 = commit(MONO, "one")
write(SECOND .. "/notes.txt", "a second project\n")
local S1 = commit(SECOND, "second one")

local SETTINGS = slurp(DIR .. "/input/project-clone")
local function clone_settings(over)
    local text = SETTINGS
    text = text:gsub('\nrepository%.guide%-feature%s*= [^\n]*',
        '\nrepository.guide-feature = "' .. MONO .. '"\nrepository.second = "' .. SECOND .. '"')
    text = text:gsub('\ndisk%-folder%s*= [^\n]*', '\ndisk-folder = "' .. DISK .. '"')
    for name, value in pairs(over or {}) do
        text = text:gsub("\n" .. name:gsub("%-", "%%-") .. "%s*= [^\n]*", "\n" .. name .. " = " .. value)
    end
    write(ROOT .. "/input/project-clone", text)
end
clone_settings()
local function keep(voice, name, at, seams)
    seams = seams or {}
    return pcall(clone.keep, { root = ROOT, voice = voice, project = { name = name, commit = at },
        memory = seams.memory, filesystem_of = seams.filesystem_of or AS_TMPFS,
        free_space = seams.free_space })
end
local function head_of(dir) return (shell("git -C " .. q(dir) .. " rev-parse --short=7 HEAD")) end
-- }}}

io.write("\n=== the first clone, in RAM ===\n")
-- {{{
local ok, kept = keep("fg-sora-1", "guide-feature", C1)
local CLONE = RAM .. "/fg-sora-1/guide-feature"
check("the first turn clones the project into the RAM folder, under the voice's name",
    ok and kept.made and kept.place == "ram" and kept.path == CLONE and head_of(CLONE) == C1,
    ok and clone.describe(kept) or kept)
check(REAL_TMPFS and "which is a tmpfs, really in memory" or "(this machine has no tmpfs at /dev/shm)",
    not REAL_TMPFS or clone.filesystem_of(CLONE) == "tmpfs", clone.filesystem_of(CLONE))
check("only the project's folder is checked out, and kuvalu named nothing else",
    ok and kept.project == CLONE .. "/guide-feature"
    and slurp(CLONE .. "/guide-feature/src/a.lua") == "local canvas_width = 60\n"
    and not exists(CLONE .. "/other"))
local missing = shell("git -C " .. q(CLONE) .. " rev-list --objects --missing=print HEAD")
check("and the other folder's files were never fetched (one commit, the project's files only)",
    has(missing, "?") and not has(shell("git -C " .. q(CLONE) .. " rev-list --count HEAD"), "2"),
    missing)
local files = #"local canvas_width = 60\n" + #"local function blit(rows) return rows end\n"
check("its size was estimated from the project's files at the commit, twice (checked out, stored)",
    ok and kept.estimate == 2 * files, ok and tostring(kept.estimate) .. " for " .. files)
check("the log line says where, how big, and why there",
    ok and has(clone.describe(kept), "project guide-feature at " .. C1 .. ": cloned in RAM at "
        .. CLONE) and has(clone.describe(kept), "of working room fit 50% of the "),
    ok and clone.describe(kept))
-- }}}

io.write("\n=== the same project again, newer and older ===\n")
-- {{{
ok, kept = keep("fg-sora-1", "guide-feature", C1)
check("the same commit again: nothing cloned, fetched or checked out",
    ok and not kept.made and not kept.fetched and not kept.checked_out and kept.place == "ram"
    and has(clone.describe(kept), "is already there"), ok and clone.describe(kept) or kept)
write(MONO .. "/guide-feature/src/a.lua", "local canvas_width = 80\n")
local C2 = commit(MONO, "two")
ok, kept = keep("fg-sora-1", "guide-feature", C2)
check("a newer commit: fetched and checked out, in the same clone",
    ok and not kept.made and kept.fetched and kept.checked_out and head_of(CLONE) == C2
    and slurp(CLONE .. "/guide-feature/src/a.lua") == "local canvas_width = 80\n"
    and has(clone.describe(kept), "was at " .. C1 .. "; fetched and checked out"),
    ok and clone.describe(kept) or kept)
ok, kept = keep("fg-sora-1", "guide-feature", C1)
check("back to the older commit, which it holds: checked out with no fetch",
    ok and not kept.fetched and kept.checked_out and head_of(CLONE) == C1,
    ok and clone.describe(kept) or kept)
-- }}}

io.write("\n=== a project switch, and back ===\n")
-- {{{
ok, kept = keep("fg-sora-1", "second", S1)
check("a different project is cloned beside the first, at the whole repository (folder .)",
    ok and kept.made and kept.path == RAM .. "/fg-sora-1/second" and kept.project == kept.path
    and slurp(kept.path .. "/notes.txt") == "a second project\n", ok and clone.describe(kept) or kept)
ok, kept = keep("fg-sora-1", "guide-feature", C2)
check("returning to the first is a fetch into the clone it kept, not a new clone",
    ok and not kept.made and kept.path == CLONE and head_of(CLONE) == C2,
    ok and clone.describe(kept) or kept)
shell("rm -rf " .. q(CLONE))
ok, kept = keep("fg-sora-1", "guide-feature", C2)
check("a RAM clone that is gone (a reboot empties RAM) is made again",
    ok and kept.made and kept.place == "ram" and head_of(CLONE) == C2,
    ok and clone.describe(kept) or kept)
-- }}}

io.write("\n=== on disk when RAM will not do ===\n")
-- {{{
local MiB = 1024 * 1024
ok, kept = keep("fg-sora-2", "guide-feature", C2, { memory = function() return 600 * MiB end })
check("too big for the RAM share: cloned on disk, the slower path",
    ok and kept.made and kept.place == "disk" and kept.path == DISK .. "/fg-sora-2/guide-feature"
    and head_of(kept.path) == C2 and not exists(RAM .. "/fg-sora-2/guide-feature"),
    ok and clone.describe(kept) or kept)
check("and the log says why: the project and the working room against the share",
    ok and has(clone.describe(kept), "cloned on disk (the slower path) at " .. kept.path)
    and has(clone.describe(kept), "of working room are more than 50% of the 600.0 MiB of "
        .. "memory available (300.0 MiB)"), ok and clone.describe(kept))
ok, kept = keep("fg-sora-2", "guide-feature", C1, { memory = function() return 64 * 1024 * MiB end })
check("a disk clone stays where it is once made, even when RAM has room later",
    ok and not kept.made and kept.place == "disk" and head_of(kept.path) == C1,
    ok and clone.describe(kept) or kept)
ok, kept = keep("fg-sora-3", "guide-feature", C2, { filesystem_of = function() return "ext2/ext3" end })
check("a RAM folder that is not a tmpfs: on disk, saying so",
    ok and kept.place == "disk" and has(kept.why, "is not in memory (it is on ext2/ext3, not tmpfs)"),
    ok and clone.describe(kept) or kept)
write(BASE .. "/a-file", "not a folder\n")
clone_settings({ ["ram-folder"] = '"' .. BASE .. '/a-file/clones"' })
ok, kept = keep("fg-sora-4", "guide-feature", C2)
check("a RAM folder that cannot be made: on disk, saying so",
    ok and kept.place == "disk" and has(kept.why, "the RAM folder " .. BASE .. "/a-file/clones/fg-sora-4 "
        .. "cannot be made"), ok and clone.describe(kept) or kept)
-- the estimate (the project's files, twice) fits, but the clone as made,
-- with git's own files, does not
clone_settings({ ["working-room"] = "0" })
ok, kept = keep("fg-sora-5", "guide-feature", C2, { memory = function() return 40 * 1024 end })
check("a RAM clone measured bigger once made than the share: moved to disk, and the log says so",
    ok and kept.made and kept.moved and kept.place == "disk"
    and kept.path == DISK .. "/fg-sora-5/guide-feature" and head_of(kept.path) == C2
    and not exists(RAM .. "/fg-sora-5/guide-feature") and has(kept.why, "once cloned")
    and has(kept.why, "moved to disk"), ok and clone.describe(kept) or kept)
clone_settings()
-- }}}

io.write("\n=== refusals ===\n")
-- {{{
ok, kept = keep("fg-sora-1", "unlisted", C1)
check("a project input/project-clone does not list: refused, naming the line to add",
    not ok and has(kept, "input/project-clone has no repository.unlisted line"), kept)
local before = head_of(CLONE)
ok, kept = keep("fg-sora-1", "guide-feature", "deadbee")
check("a commit the source lacks: refused, and the clone left where it was",
    not ok and has(kept, "has no commit deadbee") and head_of(CLONE) == before, kept)
ok, kept = keep("fg-sora-1", "guide-feature", "not-a-commit")
check("a canvas with no proper commit: refused", not ok and has(kept, "names no commit"), kept)
check("a URL is refused: kuvalu is reached as HOST:/PATH, over SSH",
    select(2, clone.parse_repository("https://kuvalu/ai-stuff")) ~= nil
    and clone.parse_repository("kuvalu:/mnt/mtwo/programming/ai-stuff").host == "kuvalu")
check("the source is asked over SSH, never stopping for a password",
    clone.on_source("kuvalu:/mnt/a b", "ls-tree HEAD") == "ssh -o BatchMode=yes -o ConnectTimeout=10 "
        .. "'kuvalu' 'git -C '\\''/mnt/a b'\\'' ls-tree HEAD'",
    clone.on_source("kuvalu:/mnt/a b", "ls-tree HEAD"))
local out, status = shell("EXEC_TIER_ROOT=" .. q(BASE .. "/exec") .. " ARTIFACT_TIER_ROOT="
    .. q(BASE .. "/shm") .. " luajit " .. q(DIR .. "/src/058-project-clone.lua") .. " --dir "
    .. q(ROOT) .. " --voice fg-sora-1 --project guide-feature --commit " .. C1)
check("scripts/project-clone says what it did", status == 0
    and has(out, "project guide-feature at " .. C1 .. ": the clone ") and has(out, "checked out"), out)
-- }}}

io.write("\n=== the turn's step 2 ===\n")
-- {{{
local turn = dofile(DIR .. "/src/055-turn.lua")
local function fake_run()
    local r = { lines = {}, counts = {} }
    function r:log(line) self.lines[#self.lines + 1] = line end
    function r:count(name, n) self.counts[name] = (self.counts[name] or 0) + (n or 1) end
    return r
end
local run = fake_run()
local got = turn.project({ root = ROOT, voice = "fg-sora-6", clone = { filesystem_of = AS_TMPFS } },
    { headers = { project = { name = "guide-feature", commit = C2 } } }, run, "turn 1 on version 4")
check("a turn clones the project at its start, logs where, and counts it",
    got and got.place == "ram" and run.counts["clone-ram"] == 1 and run.counts["clone-made"] == 1
    and run.counts["clone-fetched"] == 1 and run.counts["clone-milliseconds"] ~= nil
    and has(run.lines[1], "turn 1 on version 4: project guide-feature at " .. C2 .. ": cloned in RAM"),
    run.lines[1])
run = fake_run()
got = turn.project({ root = ROOT, voice = "fg-sora-7", clone = { memory = function() return 1 end,
    filesystem_of = AS_TMPFS } },
    { headers = { project = { name = "guide-feature", commit = C2 } } }, run, "turn 1 on version 4")
check("a clone on disk is counted as such", got and got.place == "disk"
    and run.counts["clone-disk"] == 1 and run.counts["clone-ram"] == nil, run.lines[1])
run = fake_run()
got = turn.project({ root = ROOT, voice = "fg-sora-6" },
    { headers = { project = { name = "unlisted", commit = C2 } } }, run, "turn 2 on version 5")
check("a turn with no clone to be had logs why, counts it and goes on",
    got == nil and run.counts["clone-failed"] == 1
    and has(run.lines[1], "turn 2 on version 5: no clone of the project: project clone: "
        .. "input/project-clone has no repository.unlisted line"), run.lines[1])
-- }}}

io.write("\n=== the rehearsal: each voice's clone ===\n")
-- {{{
local json = dofile(DIR .. "/libs/dkjson.lua")
local series = dofile(DIR .. "/src/018-phase-1-series.lua")
local SERVER = BASE .. "/server"
shell("mkdir -p " .. q(SERVER))
write(SERVER .. "/replies", json.encode({ { rewrite = "lantern harbor kitten" } }))
local pid = shell("luajit " .. q(DIR .. "/src/047-stand-in-llama.lua") .. " --kind chat --port-file "
    .. q(SERVER .. "/port") .. " --replies " .. q(SERVER .. "/replies") .. " --parent $PPID > "
    .. q(SERVER .. "/out") .. " 2>&1 & echo $!")
local port
for _ = 1, 100 do
    port = slurp(SERVER .. "/port")
    if port then break end
    ffi.C.poll(nil, 0, 50)
end
local url = "http://127.0.0.1:" .. tostring(port and port:match("%d+"))
write(ROOT .. "/endpoints", table.concat({
    'stand-in.url = "' .. url .. '"', 'stand-in.kind = "chat"', "stand-in.timeout = 5",
    'use.fg-sora-1 = "stand-in"', 'use.fg-sora-2 = "stand-in"', 'use.fg-sora-3 = "stand-in"',
}, "\n") .. "\n")
write(ROOT .. "/input/blitter", series.SETTINGS)
write(ROOT .. "/input/turn-runner", slurp(DIR .. "/input/turn-runner"))
write(ROOT .. "/input/stand-in-turn", 'words = "unused"\nseconds = 0\n')
write(ROOT .. "/input/turn", slurp(DIR .. "/input/turn"))
write(ROOT .. "/input/turn-instructions", slurp(DIR .. "/input/turn-instructions"))
write(ROOT .. "/input/to-voices", 'send = "off"\nmailbox = "~/guide-mail"\ntell-the-voice = "on"\n'
    .. 'project-checkout = "' .. MONO .. '/guide-feature"\n')
write(ROOT .. "/input/rehearsal", 'minutes = 0.4\ncarrier = "stand-in"\nfirst-port = 41423\n'
    .. 'pace = 1\njitter = 0.5\nrmail = "luajit /nowhere/rmail.lua"\n')
-- a disk folder of its own, so the clones the cases above left are not met
clone_settings({ ["disk-folder"] = '"' .. BASE .. '/rehearsal-disk"' })
local rehearsal = dofile(DIR .. "/src/043-rehearsal.lua")
local seen, C3 = 0, nil
local rok, result = pcall(rehearsal.run, { root = ROOT, keep = true,
    on_version = function()
        seen = seen + 1
        -- kuvalu commits while the voices work: later versions name it
        if seen == 6 then
            write(MONO .. "/guide-feature/src/b.lua", "local function blit(rows, marks) return rows end\n")
            C3 = commit(MONO, "three")
        end
    end })
check("the rehearsal runs to its end", rok, result)
local WS = rok and result.workspace.base or (ROOT .. "/tmp/shared-memory/rehearsal")
local copied = slurp(WS .. "/project/guide-feature/input/project-clone") or ""
check("its voices clone from kuvalu's checkout, here: the repository and the project's folder",
    has(copied, 'repository.guide-feature = "' .. MONO .. '"')
    and has(copied, 'folder.guide-feature = "guide-feature"') and not has(copied, "kuvalu:"), copied)
local all_ok, detail = true, {}
for _, voice in ipairs({ "fg-sora-1", "fg-sora-2", "fg-sora-3" }) do
    local log = slurp(WS .. "/shm/guide-feature/turn-" .. voice .. ".log") or ""
    local made = select(2, string.gsub(log, ": cloned in RAM at ", ""))
        + select(2, string.gsub(log, ": cloned on disk %(the slower path%) at ", ""))
    local kept_lines = select(2, string.gsub(log, " is already there", ""))
    local fetched = has(log, "; fetched and checked out")
    detail[#detail + 1] = voice .. ": made " .. made .. ", kept " .. kept_lines
        .. (fetched and ", fetched" or "")
    if made ~= 1 or kept_lines < 1 then all_ok = false end
end
check("each voice cloned the project once, at its first turn, and kept it after",
    all_ok, table.concat(detail, "; "))
local fetched_any = false
for _, voice in ipairs({ "fg-sora-1", "fg-sora-2", "fg-sora-3" }) do
    local log = slurp(WS .. "/shm/guide-feature/turn-" .. voice .. ".log") or ""
    if C3 and has(log, "project guide-feature at " .. C3 .. ": the clone ")
        and has(log, "; fetched and checked out") then fetched_any = true end
end
check("the commit kuvalu made while the voices worked reached them, fetched into their clones",
    C3 ~= nil and fetched_any, table.concat(detail, "; "))
shell("kill " .. pid)
if failed > 0 and KEEP then io.write("kept ", WS, "\n") else shell("rm -rf " .. q(WS)) end
-- }}}

if failed > 0 and KEEP then io.write("kept ", BASE, "\n") else shell("rm -rf " .. q(BASE)) end
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
