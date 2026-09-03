-- 014-the-doorman.lua
--
-- The program that waits by the door.  It listens for packets, asks the
-- arrangement whether each one is genuine, and for the ones that are,
-- asks the grant to make an account -- then takes that account away
-- again when its time is up.
--
-- It refuses to act on the system unless explicitly armed.  Unarmed, it
-- does everything except run the privileged commands, and prints them
-- instead.  That is the mode to watch it in first: a real packet, a real
-- verdict, and the exact commands that would have followed.
--
--   luajit 014-the-doorman.lua                     -- watch, change nothing
--   luajit 014-the-doorman.lua --armed             -- actually grant
--   luajit 014-the-doorman.lua --carrier stdin     -- read packets typed in
--
-- LuaJIT (5.1) syntax.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"

-- {{{ local function parse_arguments()
-- Options are read before anything else so that a mistyped one stops the
-- program before it has opened a socket or read a secret.
local function parse_arguments(argv)
    local settings = {
        dir     = DIR,
        carrier = "udp",
        port    = 4820,
        armed   = false,
    }

    local index = 1
    while argv and argv[index] do
        local option = argv[index]

        if option == "--armed" then
            settings.armed = true
        elseif option == "--carrier" then
            index = index + 1
            settings.carrier = argv[index]
        elseif option == "--port" then
            index = index + 1
            settings.port = tonumber(argv[index])
        elseif option == "--dir" then
            index = index + 1
            settings.dir = argv[index]
        elseif option == "--help" then
            settings.help = true
        elseif option:sub(1, 2) == "--" then
            error("unknown option: " .. option)
        else
            -- A bare first argument is the project directory, matching
            -- every other script here.
            settings.dir = option
        end

        index = index + 1
    end

    if not settings.port then error("--port needs a number") end
    if not settings.carrier then error("--carrier needs a name") end

    return settings
end
-- }}}

local settings = parse_arguments(arg)
DIR = settings.dir

local arrangement = dofile(DIR .. "/src/006-the-arrangement.lua")
local grant       = dofile(DIR .. "/src/007-the-grant.lua")
local listener    = dofile(DIR .. "/src/013-the-listener.lua")

-- {{{ local function say()
-- Everything the doorman reports goes through here, so that turning its
-- voice off later is one change rather than many.
local function say(text)
    io.write(text, "\n")
    io.flush()
end
-- }}}

-- {{{ local function read_input_files()
-- The first thing this program does is read what it was given.
--
-- The secret lives here.  It is the one value whose disclosure hands
-- over the whole mechanism, so the file's permissions are checked and a
-- world-readable one is refused rather than warned about -- a warning
-- would be read once and then lived with.
local function read_input_files(dir)
    local secret_path = dir .. "/input/secret"

    local handle = io.open(secret_path, "r")
    if not handle then
        error("no secret at " .. secret_path ..
              " -- write one there before starting (and chmod 600 it)")
    end
    local secret = handle:read("*l")
    handle:close()

    if not secret or #secret < 16 then
        error("the secret at " .. secret_path ..
              " is missing or shorter than 16 characters")
    end

    local mode = io.popen("stat -c '%a' " .. "'" .. secret_path .. "'", "r")
    local permissions = mode:read("*l")
    mode:close()

    -- Anything readable by group or other is refused.  The last two
    -- digits of the octal mode are those two audiences.
    if permissions and permissions:sub(-2) ~= "00" then
        error("the secret at " .. secret_path .. " is readable by others (mode "
              .. permissions .. ") -- chmod 600 it")
    end

    return secret
end
-- }}}

-- {{{ local function write_goodbye()
-- The last thing this program does is say it has finished, and how much
-- it did, so that a machine found later with an empty output directory
-- is known to have died rather than stopped.
local function write_goodbye(dir, granted, removed)
    local handle = io.open(dir .. "/output/goodbye", "w")
    if not handle then return end
    handle:write(string.format(
        "the doorman stopped at %s\n%d granted, %d removed\n",
        os.date("%Y-%m-%d %H:%M:%S"), granted, removed))
    handle:close()
end
-- }}}

if settings.help then
    say("the doorman -- waits for a packet, opens a door, closes it again")
    say("")
    say("  --armed            actually create and remove accounts")
    say("  --carrier NAME     udp (default) or stdin")
    say("  --port N           udp port to wait on (default 4820)")
    say("  --dir PATH         project directory")
    say("")
    say("unarmed, every privileged command is printed instead of run.")
    os.exit(0)
end

local secret = read_input_files(DIR)

-- Live grants, by account name.  Held in memory and mirrored to the RAM
-- tier, so that a doorman restarted after a crash still knows what it
-- owes removal.
local live = {}
local granted_count = 0
local removed_count = 0

-- {{{ local function remember()
local function remember(record)
    live[record.account] = record

    local handle = io.open(DIR .. "/tmp/shared-memory/grants", "a")
    if handle then
        handle:write(string.format("%s %d %d\n",
            record.account, record.granted, record.expires))
        handle:close()
    end
end
-- }}}

-- {{{ local function forget()
local function forget(account)
    live[account] = nil
end
-- }}}

-- {{{ local function open_the_door()
-- What happens when a packet turns out to be genuine.
--
-- The password is derived rather than invented, so whoever knocked can
-- compute it themselves and no reply is ever sent.  It is passed to the
-- plan through the environment rather than written into a command, so it
-- never appears in the process list.
local function open_the_door(name, window, now)
    local account  = grant.account_for(name)
    local password = arrangement.password_for(secret, name, window)
    local home     = "/srv/viewing/" .. account

    if live[account] then
        say("  already open: " .. account .. " -- leaving it alone")
        return
    end

    if grant.account_exists(account) and not grant.account_is_ours(account) then
        say("  REFUSED: " .. account ..
            " exists and is not ours -- not touching it")
        return
    end

    local plan = grant.creation_plan(account, password, home)

    say("  granting " .. account .. ", expires in " ..
        grant.LIFETIME_SECONDS .. "s")
    say(grant.describe(plan))

    local ok, why = grant.run(plan, settings.armed,
                              { VIEWER_PASSWORD = password })
    say("  " .. why)

    if ok then
        remember(grant.record_for(name, window, now))
        granted_count = granted_count + 1
    end
end
-- }}}

-- {{{ local function sweep()
-- Removes every grant whose time has come.
--
-- Runs on the listener's heartbeat and once at startup.  The startup
-- sweep is the one that matters: it is what removes accounts left behind
-- by a doorman that was killed rather than stopped.
local function sweep(now)
    local records = {}
    for _, record in pairs(live) do records[#records + 1] = record end

    for _, record in ipairs(grant.expired(records, now)) do
        say("  expired: " .. record.account)
        local plan = grant.removal_plan(record.account)
        say(grant.describe(plan))
        local ok, why = grant.run(plan, settings.armed)
        say("  " .. why)
        if ok then
            forget(record.account)
            removed_count = removed_count + 1
        end
    end
end
-- }}}

-- {{{ local function on_packet()
-- One arriving packet.
--
-- A refusal is reported here and nowhere else: nothing is sent back to
-- whoever knocked.  Telling a stranger which part of their guess was
-- wrong is how a secret is found one field at a time, so the reason is
-- for this machine's operator only.
local function on_packet(data, from_host)
    local now = os.time()
    local packet = data:gsub("%s+$", "")

    local name, why = arrangement.verdict(secret, packet, now)

    if not name then
        say(os.date("%H:%M:%S") .. "  refused from " .. tostring(from_host) ..
            ": " .. tostring(why))
        return
    end

    say(os.date("%H:%M:%S") .. "  accepted from " .. tostring(from_host) ..
        ": " .. name)
    open_the_door(name, arrangement.window_of(now), now)
end
-- }}}

say("the doorman is up")
say("  carrier:  " .. settings.carrier ..
    (settings.carrier == "udp" and (" on port " .. settings.port) or ""))
say("  armed:    " .. tostring(settings.armed))
if not settings.armed then
    say("  nothing will be created or removed -- commands are printed only")
end
say("")

sweep(os.time())

local ok, problem = pcall(function()
    listener.listen(settings.carrier, {
        port = settings.port,
        tick_seconds = 5,
    }, function(data, from_host)
        on_packet(data, from_host)
        sweep(os.time())
    end, function() return true end)
end)

sweep(os.time())
write_goodbye(DIR, granted_count, removed_count)

if not ok then
    say("stopped: " .. tostring(problem))
    os.exit(1)
end
