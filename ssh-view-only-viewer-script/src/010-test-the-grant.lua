-- 010-test-the-grant.lua
--
-- Proves the grant plans what it should and refuses what it should.
-- Nothing here creates an account: plans are values, and every one of
-- these tests reads a plan rather than running it.  That is the whole
-- reason the grant produces plans instead of acting -- the privileged
-- part can be tested exhaustively by an unprivileged test.
--
-- LuaJIT (5.1) syntax.  Run via 012-run-tests.sh.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local grant = dofile(DIR .. "/src/007-the-grant.lua")

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

-- {{{ local function raises()
-- Asserts a call refuses rather than returning something wrong.
local function raises(label, body)
    local ok, message = pcall(body)
    check(label, ok == false, "did not refuse")
    if ok == false then
        print("        refused: " .. tostring(message):gsub("^.-:%d+: ", ""))
    end
end
-- }}}

print("")
print("naming an account")

check("a name is prefixed",
    grant.account_for("ritz") == "view-ritz",
    "so a packet naming a real user cannot reach that user's account")

check("the prefix is present on every name",
    grant.account_for("kuvalu"):sub(1, #grant.PREFIX) == grant.PREFIX)

raises("a name too long once prefixed is refused, not truncated",
    function() return grant.account_for(string.rep("a", 30)) end)

raises("an empty name is refused",
    function() return grant.account_for("") end)

print("")
print("the creation plan")

local plan = grant.creation_plan("view-ritz", "s3cret", "/srv/viewing/view-ritz")

check("the plan has three steps", #plan == 3, #plan)

for index, item in ipairs(plan) do
    check("step " .. index .. " says why it exists",
        type(item.because) == "string" and #item.because > 0)
end

local whole = grant.describe(plan)

check("the password never appears in the plan text",
    whole:find("s3cret", 1, true) == nil,
    "it is fed on standard input, from the environment, at run time")

check("the account is created with no usable shell",
    whole:find(grant.NOLOGIN_SHELL, 1, true) ~= nil)

check("no home directory is created",
    whole:find("--no-create-home", 1, true) ~= nil,
    "the room already exists and belongs to root")

check("the account is placed in our group",
    whole:find(grant.GROUP, 1, true) ~= nil,
    "membership is how the sweeper later recognises its own work")

raises("a relative home is refused",
    function() return grant.creation_plan("view-ritz", "s3cret", "srv/viewing") end)

raises("an empty password is refused",
    function() return grant.creation_plan("view-ritz", "", "/srv/v") end)

print("")
print("quoting")

-- A name that reached this far would already have been refused by the
-- arrangement, but the grant must not depend on somebody else's check.
local nasty = grant.creation_plan("view-a'b", "p", "/srv/x")
local nasty_text = grant.describe(nasty)
check("a quote inside a name is escaped, not left to the shell",
    nasty_text:find("'\\''", 1, true) ~= nil,
    "the grant does not rely on the arrangement having checked first")

print("")
print("the removal plan")

local removal = grant.removal_plan("view-ritz")
local removal_text = grant.describe(removal)

check("removal is safe to run twice",
    removal_text:find("|| true", 1, true) ~= nil,
    "the sweeper will race itself, and absent is the desired state")

check("removal does not delete the home directory",
    removal_text:find("--remove", 1, true) == nil,
    "the room is root's and is shared, not this account's property")

raises("removing an unnamed account is refused",
    function() return grant.removal_plan("") end)

print("")
print("records and expiry")

local now = 1756800000
local record = grant.record_for("ritz", 12345, now)

check("a record names the prefixed account", record.account == "view-ritz")
check("a record keeps the name as asked", record.asked_as == "ritz")
check("a record expires after the lifetime",
    record.expires == now + grant.LIFETIME_SECONDS)

local records = {
    { account = "view-a", expires = now - 1 },
    { account = "view-b", expires = now },
    { account = "view-c", expires = now + 1 },
}

local done = grant.expired(records, now)
check("one already past is expired", done[1] and done[1].account == "view-a")
check("one expiring exactly now is expired",
    done[2] and done[2].account == "view-b",
    "the boundary belongs to removal, not to one more tick of access")
check("one still in future is not expired", #done == 2, #done)

check("nothing expires from an empty set", #grant.expired({}, now) == 0)

print("")
print("running a plan")

local ran, why, reached = grant.run(plan, false)
check("a plan does not run unless armed", ran == false, why)
check("an unarmed run reaches no steps", reached == 0, reached)
check("an unarmed run says why", why:find("armed", 1, true) ~= nil, why)

local harmless = {
    { command = "true",  because = "succeeds" },
    { command = "false", because = "fails" },
    { command = "true",  because = "should never be reached" },
}
local ok2, why2, reached2 = grant.run(harmless, true)
check("a failing step stops the plan", ok2 == false, why2)
check("the caller is told how far it got", reached2 == 1, reached2)
check("the failure names the step's reason",
    why2:find("fails", 1, true) ~= nil, why2)

local ok3, _, reached3 = grant.run({
    { command = "true", because = "one" },
    { command = "true", because = "two" },
}, true)
check("a plan whose steps all succeed reports success", ok3 == true)
check("a successful plan reaches every step", reached3 == 2, reached3)

print("")
print(string.format("%d passed, %d failed", passed, failed))
print("")

if failed > 0 then os.exit(1) end
