#!/usr/bin/env luajit
--[[
matchmaking-serve.lua - runs the matchmaking server as a daemon (issue 801b)

In plain terms: starts the matchmaking server (src/matchmaking/server.lua)
and keeps it going until it is killed or its time is up. Prints one line,
"listening IP PORT", on standard output once it listens, so a script that
started it with port 0 learns the port. Logs every connection and lobby
event to standard error, each line stamped with the time in UTC.

With --nat-port it also runs the UDP reflector of nat.lua (issue 801d)
on that port and the next, so players can learn their outside address
and kind of NAT; it prints a second line, "nat IP PORT ALT_PORT".

The full command-line tool (status, lobby lists, configuration files,
asset packs) is issue 801g; this is only enough to run the server.

Usage: luajit src/cli/matchmaking-serve.lua [DIR] [--bind HOST:PORT]
         [--seconds N] [--quiet] [--max-lobbies N] [--max-players N]
         [--lobby-timeout N] [--idle-timeout N] [--countdown N]
         [--nat-port P] [--nat-alt-ip IP] [--mirror-contact C --packs-dir DIR]
  DIR        the project (default /mnt/mtwo/programming/ai-stuff/world-edit-to-execute)
  --bind     where to listen (default 127.0.0.1:8080; 0.0.0.0:PORT opens it
             to every network the machine is on)
  --seconds  stop by itself after N seconds (default: run until killed)
  --quiet    no log lines
  --countdown  seconds between the host's start and the game's (default 0)
  --nat-port the UDP reflector on the bind address, ports P and P+1
             (P 0: any two free ports)
  --mirror-contact, --packs-dir  mirror the asset packs (*.pack) in that
             folder (issue 801f): players joining a lobby that needs them
             are told this rmail contact hands them out
  --nat-alt-ip  a second address of this machine the reflector also
             answers from, so the detector can tell a full cone NAT
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local args = { ... }
if args[1] and args[1]:sub(1, 2) ~= "--" then DIR = table.remove(args, 1) end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local server = require("matchmaking.server")
local nat = require("matchmaking.nat")
local packs = require("matchmaking.packs")

-- {{{ the arguments
local config, seconds, quiet, nat_port, nat_alt_ip = {}, nil, false, nil, nil
local mirror_contact, packs_dir
local numeric = { ["--max-lobbies"] = "max_lobbies", ["--max-players"] = "max_players_per_lobby",
    ["--lobby-timeout"] = "lobby_timeout_seconds", ["--idle-timeout"] = "idle_timeout_seconds",
    ["--countdown"] = "countdown_seconds" }
local i = 1
local function value(flag)
    local v = args[i + 1]
    if not v then io.stderr:write("matchmaking-serve: " .. flag .. " needs a value\n") os.exit(2) end
    i = i + 1
    return v
end
local function number(flag)
    local n = tonumber(value(flag))
    if not n or n < 0 then io.stderr:write("matchmaking-serve: " .. flag .. " needs a number\n") os.exit(2) end
    return n
end
while i <= #args do
    local a = args[i]
    if a == "--bind" then config.bind = value(a)
    elseif a == "--seconds" then seconds = number(a)
    elseif a == "--quiet" then quiet = true
    elseif a == "--nat-port" then nat_port = number(a)
    elseif a == "--nat-alt-ip" then nat_alt_ip = value(a)
    elseif a == "--mirror-contact" then mirror_contact = value(a)
    elseif a == "--packs-dir" then packs_dir = value(a)
    elseif numeric[a] then config[numeric[a]] = number(a)
    else io.stderr:write("matchmaking-serve: " .. a .. " is not an option\n") os.exit(2) end
    i = i + 1
end
if nat_alt_ip and not nat_port then io.stderr:write("matchmaking-serve: --nat-alt-ip needs --nat-port\n") os.exit(2) end
if (mirror_contact ~= nil) ~= (packs_dir ~= nil) then
    io.stderr:write("matchmaking-serve: --mirror-contact and --packs-dir go together\n") os.exit(2)
end
-- }}}

if not quiet then
    config.log = function(line)
        io.stderr:write(os.date("!%Y-%m-%dT%H:%M:%SZ "), line, "\n")
    end
end

if packs_dir then
    local f = io.open(packs_dir .. "/.", "r")
    if not f then io.stderr:write("matchmaking-serve: no folder " .. packs_dir .. "\n") os.exit(1) end
    f:close()
    config.mirror = { contact = mirror_contact, packs = packs.registry(packs_dir) }
    if config.log then
        config.log("mirroring " .. #config.mirror.packs:list() .. " packs from " .. packs_dir .. " as " .. mirror_contact)
        for _, why in ipairs(config.mirror.packs.skipped) do config.log("not mirrored: " .. why) end
    end
end

local srv = server.new(config)
local ok, err = pcall(srv.start, srv)
if not ok then io.stderr:write(err, "\n") os.exit(1) end
local ip, port = srv:address()
io.stdout:write("listening ", ip, " ", port, "\n")
local reflector
if nat_port then
    local rok, r = pcall(nat.reflector_udp, ip, nat_port, nat_alt_ip)
    if not rok then io.stderr:write(r, "\n") srv:stop() os.exit(1) end
    reflector = r
    io.stdout:write("nat ", reflector.ip, " ", reflector.port, " ", reflector.alt_port, "\n")
    if config.log then config.log("NAT reflector on " .. reflector.ip .. ":" .. reflector.port .. " and :" .. reflector.alt_port
        .. (nat_alt_ip and (", and " .. nat_alt_ip) or "")) end
end
io.stdout:flush()

-- The reflector's answers wait at most one short tick.
local stop_at = seconds and srv.clock() + seconds
while not stop_at or srv.clock() < stop_at do
    srv:tick(reflector and 0.01 or 0.05)
    if reflector then reflector:poll() end
end
if reflector then reflector:close() end
srv:stop()
