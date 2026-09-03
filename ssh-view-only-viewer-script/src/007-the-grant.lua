-- 007-the-grant.lua
--
-- Brings a temporary view-only account into existence, and takes it away
-- again.  This is the only part of the project that needs root, so it is
-- built to make that step small and refusable: it does not act, it
-- writes down what acting would consist of.  A caller can print the plan,
-- read every command, and decide.  Running it is a separate, deliberate
-- act that has to be armed.
--
-- The account is always prefixed, so a stranger claiming to be someone
-- who already has a login on this machine gets a new account beside them
-- rather than a reset password on theirs.
--
-- LuaJIT (5.1) syntax.  No 5.4 constructs.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"
if arg and arg[1] then DIR = arg[1] end

local grant = {}

-- Every account this project creates begins with this.  It is the reason
-- a packet naming an existing user cannot reach that user's account, and
-- it is what the sweeper recognises its own work by.
grant.PREFIX = "view-"

-- Every account this project creates is placed in this group.  Presence
-- in it is the test for "we made this"; an account carrying our prefix
-- but not in this group was made by something else wearing our name, and
-- is left alone.
grant.GROUP = "viewonly"

-- How long a grant lives, in seconds.  Long enough to connect and look
-- around, short enough that one forgotten is not a standing door.
grant.LIFETIME_SECONDS = 900

-- A shell that cannot be used.  The account exists to satisfy sshd's
-- need for a user; it is never meant to run anything, and the room in
-- phase 3 forces a command regardless.  Setting this as well means a
-- misconfigured sshd fails closed rather than dropping someone at a
-- prompt.
grant.NOLOGIN_SHELL = "/usr/sbin/nologin"

-- {{{ local function shell_quote()
local function shell_quote(text)
    if type(text) ~= "string" then
        error("shell_quote: expected a string, got " .. type(text))
    end
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function grant.account_for()
-- The system account name a packet's name becomes.
--
-- Refuses rather than truncating.  A silently shortened name is how two
-- different visitors end up sharing one account, and the length cap in
-- the arrangement exists precisely to leave room for this prefix.
function grant.account_for(asked_as)
    if type(asked_as) ~= "string" or #asked_as == 0 then
        error("account_for: a name is required")
    end

    local account = grant.PREFIX .. asked_as

    -- 32 is where Linux itself stops accepting a user name.
    if #account > 32 then
        error("account_for: prefixed name is too long to be a system account: "
              .. account)
    end

    return account
end
-- }}}

-- {{{ local function read_command()
local function read_command(command)
    local pipe = io.popen(command, "r")
    if not pipe then
        error("could not run: " .. command)
    end
    local output = pipe:read("*a")
    pipe:close()
    return output
end
-- }}}

-- {{{ function grant.account_exists()
-- Whether a system account by this name is present.  Read-only.
--
-- getent is asked rather than /etc/passwd being read, because an account
-- can live in a directory service the file knows nothing about, and an
-- account we fail to notice is one we might try to create over the top
-- of.
function grant.account_exists(account)
    local output = read_command("getent passwd " .. shell_quote(account))
    return output:match("%S") ~= nil
end
-- }}}

-- {{{ function grant.account_is_ours()
-- Whether an existing account is one this project created.
--
-- Membership of our group is the test, not the prefix.  The prefix is a
-- convention anything could adopt; the group is something only a
-- privileged act could have put an account into.  An account wearing our
-- prefix while outside the group is somebody else's, and the grant stops
-- rather than adopting it.
function grant.account_is_ours(account)
    local output = read_command("id -nG " .. shell_quote(account))
    for word in output:gmatch("%S+") do
        if word == grant.GROUP then return true end
    end
    return false
end
-- }}}

-- {{{ local function step()
local function step(command, because)
    return { command = command, because = because }
end
-- }}}

-- {{{ function grant.creation_plan()
-- The ordered commands that would bring an account into existence.
--
-- Nothing here runs.  The plan is a value: it can be printed, compared,
-- stored, or thrown away.  Every step carries the reason it exists, so
-- somebody reading the plan is reading an argument rather than a list.
--
-- The password is not in the plan as an argument.  It is fed to chpasswd
-- on standard input, because a command line is visible to every process
-- on the machine and standard input is not -- the same reasoning that
-- keeps the secret off the command line in the arrangement.
function grant.creation_plan(account, password, home)
    if type(account) ~= "string" or #account == 0 then
        error("creation_plan: an account name is required")
    end
    if type(password) ~= "string" or #password == 0 then
        error("creation_plan: a password is required")
    end
    if type(home) ~= "string" or home:sub(1, 1) ~= "/" then
        error("creation_plan: home must be an absolute path")
    end

    local plan = {}

    plan[#plan + 1] = step(
        "getent group " .. shell_quote(grant.GROUP) ..
            " > /dev/null || groupadd " .. shell_quote(grant.GROUP),
        "the group is how a granted account is later recognised as ours")

    plan[#plan + 1] = step(
        "useradd --no-create-home --home-dir " .. shell_quote(home) ..
            " --shell " .. shell_quote(grant.NOLOGIN_SHELL) ..
            " --gid " .. shell_quote(grant.GROUP) ..
            " " .. shell_quote(account),
        "no home is made: the room already exists and belongs to root")

    plan[#plan + 1] = step(
        "printf '%s:%s' " .. shell_quote(account) .. " \"$VIEWER_PASSWORD\"" ..
            " | chpasswd",
        "the password arrives by standard input, never on a command line")

    return plan
end
-- }}}

-- {{{ function grant.removal_plan()
-- The ordered commands that would take an account away.
--
-- Written so that running it twice is harmless.  The sweeper may well
-- try to remove something a previous sweep already removed -- a race it
-- is not worth preventing -- and a plan that errors on the second run
-- would turn that into a failure that repeats forever.
--
-- The home directory is deliberately NOT removed.  It is the room, it
-- belongs to root, and it is shared configuration rather than this
-- account's property.  userdel is told to leave it alone explicitly
-- rather than relying on the default, because the default has differed
-- between distributions.
function grant.removal_plan(account)
    if type(account) ~= "string" or #account == 0 then
        error("removal_plan: an account name is required")
    end

    local plan = {}

    plan[#plan + 1] = step(
        "getent passwd " .. shell_quote(account) .. " > /dev/null && " ..
            "userdel " .. shell_quote(account) .. " || true",
        "absent is the desired state, so an account already gone is success")

    return plan
end
-- }}}

-- {{{ function grant.expired()
-- Which of a set of records are past their time.
--
-- Separated from the sweeping so the decision can be tested without any
-- accounts existing.  A record whose expiry has arrived exactly is
-- expired: the boundary belongs to removal, because the alternative
-- leaves a door open for one more tick.
function grant.expired(records, now)
    if type(records) ~= "table" then
        error("expired: records must be a table, got " .. type(records))
    end
    if type(now) ~= "number" then
        error("expired: now must be a number, got " .. type(now))
    end

    local done = {}
    for _, record in ipairs(records) do
        if now >= record.expires then
            done[#done + 1] = record
        end
    end
    return done
end
-- }}}

-- {{{ function grant.record_for()
-- The record written down when an account is created.
function grant.record_for(asked_as, window, now)
    return {
        account  = grant.account_for(asked_as),
        asked_as = asked_as,
        window   = window,
        granted  = now,
        expires  = now + grant.LIFETIME_SECONDS,
    }
end
-- }}}

-- {{{ function grant.describe()
-- Renders a plan as text a person can read before deciding.
function grant.describe(plan)
    local lines = {}
    for index, item in ipairs(plan) do
        lines[#lines + 1] = string.format("%d. %s", index, item.because)
        lines[#lines + 1] = "     " .. item.command
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function grant.run()
-- The one place a plan is executed.
--
-- Refuses unless armed.  The default is to do nothing and say what would
-- have happened, because every command in a plan is privileged and the
-- cost of running one by accident is an account nobody meant to make.
--
-- Stops at the first failure rather than continuing.  Carrying on past a
-- failed account creation would mean setting a password on something
-- that is not there, and the plan would report success for a grant that
-- half-exists.  A partial application is returned as such: the caller is
-- told how far it got, so it can be undone.
function grant.run(plan, armed, environment)
    if not armed then
        return false, "not armed -- nothing was run", 0
    end

    local prefix = ""
    if environment then
        for key, value in pairs(environment) do
            prefix = prefix .. key .. "=" .. shell_quote(value) .. " "
        end
    end

    for index, item in ipairs(plan) do
        local ok = os.execute(prefix .. item.command)
        local succeeded = (ok == true or ok == 0)
        if not succeeded then
            return false,
                   "step " .. index .. " failed: " .. item.because,
                   index - 1
        end
    end

    return true, "applied", #plan
end
-- }}}

return grant
