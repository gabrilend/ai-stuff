#!/usr/bin/env luajit
--[[
matchmaking-serve.lua - runs the matchmaking server as a daemon (issue 801b)

In plain terms: starts the matchmaking server (src/matchmaking/server.lua)
and keeps it going until it is killed or its time is up. Prints one line,
"listening IP PORT", on standard output once it listens, so a script that
started it with port 0 learns the port. Logs every connection and lobby
event to standard error, each line stamped with the time in UTC.

The full command-line tool (status, lobby lists, configuration files,
asset packs) is issue 801g; this is only enough to run the server.

Usage: luajit src/cli/matchmaking-serve.lua [DIR] [--bind HOST:PORT]
         [--seconds N] [--quiet] [--max-lobbies N] [--max-players N]
         [--lobby-timeout N] [--idle-timeout N]
  DIR        the project (default /mnt/mtwo/programming/ai-stuff/world-edit-to-execute)
  --bind     where to listen (default 127.0.0.1:8080; 0.0.0.0:PORT opens it
             to every network the machine is on)
  --seconds  stop by itself after N seconds (default: run until killed)
  --quiet    no log lines
]]

local DIR = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
local args = { ... }
if args[1] and args[1]:sub(1, 2) ~= "--" then DIR = table.remove(args, 1) end
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local server = require("matchmaking.server")

-- {{{ the arguments
local config, seconds, quiet = {}, nil, false
local numeric = { ["--max-lobbies"] = "max_lobbies", ["--max-players"] = "max_players_per_lobby",
    ["--lobby-timeout"] = "lobby_timeout_seconds", ["--idle-timeout"] = "idle_timeout_seconds" }
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
    elseif numeric[a] then config[numeric[a]] = number(a)
    else io.stderr:write("matchmaking-serve: " .. a .. " is not an option\n") os.exit(2) end
    i = i + 1
end
-- }}}

if not quiet then
    config.log = function(line)
        io.stderr:write(os.date("!%Y-%m-%dT%H:%M:%SZ "), line, "\n")
    end
end

local srv = server.new(config)
local ok, err = pcall(srv.start, srv)
if not ok then io.stderr:write(err, "\n") os.exit(1) end
local ip, port = srv:address()
io.stdout:write("listening ", ip, " ", port, "\n")
io.stdout:flush()

local stop_at = seconds and srv.clock() + seconds
while not stop_at or srv.clock() < stop_at do
    srv:tick(0.05)
end
srv:stop()
