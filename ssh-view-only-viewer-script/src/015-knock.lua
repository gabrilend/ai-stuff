-- 015-knock.lua
--
-- The other end.  Shapes a packet, sends it, and prints the password the
-- listening machine will have set -- computed here rather than received,
-- because both sides derive it from the same secret and nothing about it
-- ever crosses the network.
--
--   luajit 015-knock.lua --host 192.168.1.10 --name ritz
--   luajit 015-knock.lua --name ritz --print-only
--
-- LuaJIT (5.1) syntax.

local DIR = "/home/ritz/programming/ai-stuff/ssh-view-only-viewer-script"

-- {{{ local function parse_arguments()
local function parse_arguments(argv)
    local settings = {
        dir  = DIR,
        host = "127.0.0.1",
        port = 4820,
    }

    local index = 1
    while argv and argv[index] do
        local option = argv[index]
        if option == "--host" then
            index = index + 1; settings.host = argv[index]
        elseif option == "--port" then
            index = index + 1; settings.port = tonumber(argv[index])
        elseif option == "--name" then
            index = index + 1; settings.name = argv[index]
        elseif option == "--dir" then
            index = index + 1; settings.dir = argv[index]
        elseif option == "--print-only" then
            settings.print_only = true
        elseif option == "--help" then
            settings.help = true
        else
            error("unknown option: " .. option)
        end
        index = index + 1
    end

    return settings
end
-- }}}

local settings = parse_arguments(arg)
DIR = settings.dir

if settings.help or not settings.name then
    print("knock -- ask a machine for a look at itself")
    print("")
    print("  --name NAME     who you are (becomes the account name)")
    print("  --host ADDRESS  who to ask (default 127.0.0.1)")
    print("  --port N        which port (default 4820)")
    print("  --print-only    shape the packet, send nothing")
    os.exit(settings.name and 0 or 1)
end

local arrangement = dofile(DIR .. "/src/006-the-arrangement.lua")

local handle = io.open(DIR .. "/input/secret", "r")
if not handle then
    error("no secret at " .. DIR .. "/input/secret")
end
local secret = handle:read("*l")
handle:close()

local now    = os.time()
local window = arrangement.window_of(now)
local packet = arrangement.build(secret, settings.name, now)

-- Derived, not awaited.  This is the whole reason the doorman never
-- replies: there is nothing it could tell us that we do not already
-- know.
local password = arrangement.password_for(secret, settings.name, window)

print("packet:   " .. packet)
print("account:  view-" .. settings.name)
print("password: " .. password)
print("")
print("this password is good for the window the packet was built in.")

if settings.print_only then
    print("(nothing sent)")
    os.exit(0)
end

local socket = require("socket")
local sock = assert(socket.udp())
assert(sock:sendto(packet, settings.host, settings.port))
sock:close()

print("sent to " .. settings.host .. ":" .. settings.port)
print("")
print("  ssh view-" .. settings.name .. "@" .. settings.host)
