-- 011-test-the-draw.lua
--
-- Proves the draw hands out what it should and refuses what it should
-- not.  The tests that matter most are the ones about the corpus
-- boundary: each is a different way of asking the draw to return a file
-- from outside the folder it was pointed at, and each must be refused.
-- The rest establish that a viewer is never handed the same file twice,
-- that two viewers may be handed the same file, and that a corpus which
-- runs out says so rather than starting over.
--
-- LuaJIT (5.1) syntax.  Run via 012-run-tests.sh.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local draw = dofile(DIR .. "/src/008-the-draw.lua")

local SANDBOX = DIR .. "/tmp/shared-memory/test-corpus"

local passed = 0
local failed = 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok    " .. name)
    else
        failed = failed + 1
        print("  FAIL  " .. name)
        if detail then print("        " .. tostring(detail)) end
    end
end
-- }}}

-- {{{ local function run()
-- One command, run for its effect.  Kept separate from the module's own
-- reader so a test-setup failure is never mistaken for a module failure.
local function run(command)
    local ok = os.execute(command)
    if ok ~= true and ok ~= 0 then
        error("test setup failed: " .. command)
    end
end
-- }}}

-- {{{ local function build_sandbox()
-- Lays out a corpus and, beside it, the things a leaky boundary would
-- reach: a sibling directory whose name merely starts with the corpus
-- name, and a secret one level up that a symlink and a ".." both aim at.
local function build_sandbox()
    run("rm -rf " .. SANDBOX)
    run("mkdir -p " .. SANDBOX .. "/lend")
    run("mkdir -p " .. SANDBOX .. "/lend-secrets")
    run("mkdir -p " .. SANDBOX .. "/elsewhere")

    run("printf 'one\\n'   > " .. SANDBOX .. "/lend/first.txt")
    run("printf 'two\\n'   > " .. SANDBOX .. "/lend/second.txt")
    run("printf 'three\\n' > " .. SANDBOX .. "/lend/third.txt")

    run("printf 'sibling\\n' > " .. SANDBOX .. "/lend-secrets/private.txt")
    run("printf 'outside\\n' > " .. SANDBOX .. "/elsewhere/secret.txt")
end
-- }}}

print("")
print("the corpus boundary")
build_sandbox()

local lend = SANDBOX .. "/lend"

check("a file inside the corpus is inside",
    draw.is_under(lend, lend .. "/first.txt") == true)

check("a sibling sharing a name prefix is outside",
    draw.is_under(lend, SANDBOX .. "/lend-secrets/private.txt") == false,
    "lend-secrets starts with the string 'lend' but is not under it")

check("a path climbing out with .. is outside",
    draw.is_under(lend, lend .. "/../elsewhere/secret.txt") == false)

check("the corpus root is not inside itself",
    draw.is_under(lend, lend) == false,
    "handing out a directory is not a thing this project does")

check("a root given with a trailing slash behaves the same",
    draw.is_under(lend .. "/", lend .. "/first.txt") == true)

check("a path that does not exist is outside",
    draw.is_under(lend, lend .. "/never-written.txt") == false)

run("ln -s " .. SANDBOX .. "/elsewhere/secret.txt " .. lend .. "/a-link")
check("a symlink pointing out of the corpus is outside",
    draw.is_under(lend, lend .. "/a-link") == false,
    "resolution follows the link before the boundary is tested")

print("")
print("building the roll")

local roll, escaped = draw.build_roll(lend)
check("the three real files are found", #roll == 3, "found " .. #roll)
check("the escaping symlink is reported, not silently dropped",
    #escaped == 1, "reported " .. #escaped)

for _, entry in ipairs(roll) do
    check("every entry is under the corpus: " .. entry.path:match("[^/]+$"),
        draw.is_under(lend, entry.path) == true)
end

run("rm -f " .. lend .. "/a-link")

print("")
print("drawing")

roll = draw.build_roll(lend)
local ceiling = 99
local alice = {}

local first = draw.pick(roll, alice, ceiling)
check("a viewer with an empty corpus history receives something",
    first ~= nil)
draw.stamp(first, alice, os.time())

local second = draw.pick(roll, alice, ceiling)
draw.stamp(second, alice, os.time())
check("the same viewer is not handed the same file twice",
    first.path ~= second.path)

local third = draw.pick(roll, alice, ceiling)
draw.stamp(third, alice, os.time())

local fourth, reason = draw.pick(roll, alice, ceiling)
check("a viewer who has seen everything is told the well ran dry",
    fourth == nil and reason ~= nil, reason)
check("running dry reports a reason, not an error",
    type(reason) == "string" and #reason > 0, tostring(reason))

local bob = {}
local bobs_first = draw.pick(roll, bob, ceiling)
check("a second viewer may be handed a file the first already saw",
    bobs_first ~= nil,
    "the already-held filter is per viewer, not global")

print("")
print("the repeat ceiling")

roll = draw.build_roll(lend)
local carol = {}
local strict = 1

-- Every file already handed out once, by anyone.
for _, entry in ipairs(roll) do entry.drawn = 1 end

local worn, worn_reason = draw.pick(roll, carol, strict)
check("a ceiling of one stops a fresh viewer once each file has gone out",
    worn == nil, "this is the bound on a viewer who only ever deletes")
check("the ceiling refusal explains itself", worn_reason ~= nil, worn_reason)

print("")
print("an empty corpus")

run("mkdir -p " .. SANDBOX .. "/nothing")
local empty_roll = draw.build_roll(SANDBOX .. "/nothing")
check("an empty corpus builds an empty roll", #empty_roll == 0)

local nothing, nothing_reason = draw.pick(empty_roll, {}, ceiling)
check("an empty corpus refuses rather than errors", nothing == nil)
check("an empty corpus says it is empty",
    nothing_reason == "the corpus is empty", nothing_reason)

print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

run("rm -rf " .. SANDBOX)

if failed > 0 then os.exit(1) end
