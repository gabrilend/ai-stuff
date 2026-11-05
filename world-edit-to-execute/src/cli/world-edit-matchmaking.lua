#!/usr/bin/env luajit
--[[
world-edit-matchmaking.lua - the matchmaking server's command-line tool (issue 801g)

In plain terms: runs the matchmaking server from a configuration file
(or flags), and answers questions about one that is running: its
numbers, its lobbies, one lobby, its log, and the asset packs it mirrors.
A running server writes a state file every few seconds; `status`,
`lobbies` and `lobby` read that file, so they need no connection to the
server and work as any user who can read it.

Usage: world-edit-matchmaking.lua COMMAND [options]   (--help for each)

  serve            run the server (SIGTERM or Ctrl-C stops it cleanly)
  status           the running server's numbers
  lobbies          its lobbies
  lobby ID         one lobby
  logs             its log (--follow to keep watching)
  assets list|add|remove   the packs it mirrors
  validate-config FILE     check a configuration file

Options most commands take: --config FILE (where the server's files
are), --state FILE (the state file itself), --json (for scripts),
--no-color, -q (less), -v (more).
]]

-- The project: the folder this file sits in (src/cli/ of it), or the owner's.
local self_path = arg and arg[0] or ""
local DIR = self_path:match("^(.*)/src/cli/[^/]+$") or (self_path:match("^src/cli/") and ".")
    or (self_path:match("^%.?/?[^/]+%.lua$") and "../..") or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local config = require("matchmaking.config")
local daemon = require("matchmaking.daemon")
local packs = require("matchmaking.packs")

local cli = {}

-- {{{ output
local ffi = require("ffi")
pcall(ffi.cdef, "int isatty(int fd);")
local colour_on = false
local CODES = { green = "32", yellow = "33", red = "31", blue = "34", bold = "1" }
local function paint(c, s)
    if not colour_on or not CODES[c] then return s end
    return "\27[" .. CODES[c] .. "m" .. s .. "\27[0m"
end
local function out(...) io.stdout:write(...) io.stdout:write("\n") end
local function fail(text, code)
    io.stderr:write(paint("red", "error: "), text, "\n")
    os.exit(code or 1)
end

-- JSON for --json: tables with only 1..n keys are arrays.
local function json(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return v == math.floor(v) and string.format("%d", v) or string.format("%.6g", v)
    end
    if t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
            return named[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    end
    local n, count = #v, 0
    for _ in pairs(v) do count = count + 1 end
    if count == n and n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = json(v[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local val = v[k]
        if val == nil then val = v[tonumber(k)] end
        parts[#parts + 1] = json(k) .. ":" .. json(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end
cli.json = json

function cli.duration(s)
    s = math.max(0, math.floor(s))
    if s < 60 then return s .. "s" end
    if s < 3600 then return math.floor(s / 60) .. "m " .. s % 60 .. "s" end
    if s < 86400 then return math.floor(s / 3600) .. "h " .. math.floor(s % 3600 / 60) .. "m" end
    return math.floor(s / 86400) .. "d " .. math.floor(s % 86400 / 3600) .. "h"
end

function cli.bytes(n)
    if n < 1024 then return string.format("%d B", n) end
    if n < 1048576 then return string.format("%.1f KB", n / 1024) end
    if n < 1073741824 then return string.format("%.1f MB", n / 1048576) end
    return string.format("%.1f GB", n / 1073741824)
end
-- }}}

-- {{{ arguments
-- Splits `args` into the flags `spec` names (flag -> "value" or true)
-- and the rest; an unknown flag stops with a usage error.
local function parse(args, spec, command)
    local flags, rest, i = {}, {}, 1
    while i <= #args do
        local a = args[i]
        if a == "--help" or a == "-h" then flags.help = true
        elseif a:sub(1, 1) == "-" and #a > 1 then
            local kind = spec[a]
            if not kind then fail(a .. " is not an option of " .. command .. " (see " .. command .. " --help)", 2) end
            if kind == "value" then
                i = i + 1
                if args[i] == nil then fail(a .. " needs a value", 2) end
                flags[a] = args[i]
            else
                flags[a] = true
            end
        else
            rest[#rest + 1] = a
        end
        i = i + 1
    end
    return flags, rest
end

local COMMON = { ["--config"] = "value", ["--state"] = "value", ["--json"] = true, ["--no-color"] = true,
    ["-q"] = true, ["-v"] = true }
local function with(extra)
    local s = {}
    for k, v in pairs(COMMON) do s[k] = v end
    for k, v in pairs(extra or {}) do s[k] = v end
    return s
end

local function number(flags, name)
    local v = flags[name]
    if v == nil then return nil end
    local n = tonumber(v)
    if not n or n < 0 then fail(name .. " needs a number", 2) end
    return n
end

-- The configuration named by --config, checked; nil when none was named.
local function settings(flags)
    if not flags["--config"] then return nil end
    local s, problems = config.load(flags["--config"])
    if not s then
        for _, p in ipairs(problems) do io.stderr:write(paint("red", p.level .. ": "), p.text, "\n") end
        fail("the configuration " .. flags["--config"] .. " has errors (validate-config shows them)")
    end
    return s
end

local function state_path(flags)
    if flags["--state"] then return flags["--state"] end
    local s = settings(flags)
    return s and s.state_file or config.DEFAULTS.state_file
end
-- }}}

-- {{{ the running server, from its state file
local function alive(pid)
    local f = io.open("/proc/" .. tostring(pid) .. "/stat", "r")
    if not f then return false end
    local stat = f:read("*l") or ""
    f:close()
    return stat:match("^%d+ %b() (%a)") ~= "Z"
end

-- The state and whether the server is running now, or a failure.
local function running_state(flags)
    local path = state_path(flags)
    local st, err = daemon.read_state(path)
    if not st then
        fail("no state file at " .. path .. " (is the server running? `serve` writes it; --state or --config say where)")
    end
    local live = st.running and alive(st.pid)
    return st, live, path
end

local function not_running_line(st)
    if st.running == false then
        return "not running: stopped (" .. tostring(st.stopped_by) .. ") " .. cli.duration(os.time() - st.updated) .. " ago"
    end
    return "not running: process " .. st.pid .. " is gone without saying so; the last state is from "
        .. cli.duration(os.time() - st.updated) .. " ago"
end
-- }}}

-- {{{ help
local HELP = {
    main = [[
world-edit-matchmaking - run and watch the matchmaking server

  serve            run the server
  status           the running server's numbers
  lobbies          its lobbies
  lobby ID         one lobby, with its players
  logs             its log; --follow keeps watching
  assets list      the asset packs it mirrors
  assets add FILE [ID]   copy a pack into the mirror's folder
  assets remove ID       take a pack off the mirror
  validate-config FILE   check a configuration file

Every command takes --help. Most take --config FILE (to find the server's
state file, log and packs folder) or --state FILE, --json, --no-color.]],
    serve = [[
serve - run the matchmaking server until SIGTERM or Ctrl-C

  --config FILE        settings from a configuration file (see validate-config)
  --bind HOST:PORT     where to listen (default 127.0.0.1:8080)
  --nat-port P         the NAT reflector on UDP P and P+1 (issue 801d)
  --nat-alt-ip IP      a second address for the reflector to answer from
  --mirror-contact C   mirror asset packs: C is the mirror's rmail contact...
  --packs-dir DIR      ...and DIR the folder of *.pack files (issue 801f)
  --countdown N        seconds from the host's start to the game's
  --log-file FILE      append the log here (default: standard error)
  --state-file FILE    where `status` will find the numbers (default matchmaking.state)
  --state-interval N   write it every N seconds (default 2)
  --seconds N          stop after N seconds
  -q                   no log on standard error; -v: also there with a log file

Flags win over the file. Prints "listening IP PORT" once it listens.
SIGHUP has the mirror read its folder again.]],
    status = [[
status - the running server's numbers: lobbies, players, uptime, traffic

  --config FILE | --state FILE   where its state file is
  --json                         the whole state, for scripts
Exits 1 when no server is running.]],
    lobbies = [[
lobbies - the running server's lobbies: id, map, host, players, state

  --config FILE | --state FILE, --json]],
    lobby = [[
lobby ID - one lobby: its map, host, players and their ready marks

  --config FILE | --state FILE, --json]],
    logs = [[
logs - the server's log

  --config FILE | --log-file FILE   which log (from the configuration's log_file)
  -n N                              the last N lines (default 50)
  --follow                          keep printing new lines, like tail -f
  --seconds N                       with --follow: stop after N seconds]],
    assets = [[
assets list | add FILE [ID] | remove ID - the packs the mirror hands out

  --config FILE | --packs-dir DIR   the mirror's folder
  --json                            (list) for scripts
A pack is one file, ID.pack; ID defaults to the file's name without its
extension. A running server (found through --config or --state) is told
to read the folder again.]],
    ["validate-config"] = [[
validate-config FILE - check a configuration file and say what it sets

Every problem is listed with what to do instead. Exits 1 on any error.]],
}

local function help(name)
    out(HELP[name] or HELP.main)
    os.exit(0)
end
-- }}}

-- {{{ commands
local commands = {}

function commands.serve(args)
    local flags = parse(args, with({ ["--bind"] = "value", ["--nat-port"] = "value", ["--nat-alt-ip"] = "value",
        ["--mirror-contact"] = "value", ["--packs-dir"] = "value", ["--countdown"] = "value", ["--log-file"] = "value",
        ["--state-file"] = "value", ["--state-interval"] = "value", ["--seconds"] = "value" }), "serve")
    if flags.help then help("serve") end
    local s = settings(flags) or select(1, config.check({}, "."))
    if flags["--bind"] then
        local checked, problems = config.check({ bind = flags["--bind"] })
        if not checked then fail(problems[1].text, 2) end
        s.server.bind = flags["--bind"]
    end
    local countdown = number(flags, "--countdown")
    if countdown then s.server.countdown_seconds = countdown end
    local nport = number(flags, "--nat-port")
    if nport then s.nat = { port = nport, alt_ip = flags["--nat-alt-ip"] or (s.nat and s.nat.alt_ip) } end
    if flags["--nat-alt-ip"] and not s.nat then fail("--nat-alt-ip needs --nat-port", 2) end
    if (flags["--mirror-contact"] ~= nil) ~= (flags["--packs-dir"] ~= nil) then
        fail("--mirror-contact and --packs-dir go together", 2)
    end
    if flags["--packs-dir"] then s.mirror = { contact = flags["--mirror-contact"], packs_dir = flags["--packs-dir"] } end
    if flags["--log-file"] then s.log_file = flags["--log-file"] end
    if flags["--state-file"] then s.state_file = flags["--state-file"] end
    local interval = number(flags, "--state-interval")
    if interval then
        if interval <= 0 then fail("--state-interval should be seconds above 0", 2) end
        s.state_interval = interval
    end

    local file
    if s.log_file then
        file = io.open(s.log_file, "a")
        if not file then fail("can't write the log " .. s.log_file) end
        file:setvbuf("line")
    end
    local to_stderr = not flags["-q"] and (not file or flags["-v"])
    local function log(line)
        local stamped = os.date("!%Y-%m-%dT%H:%M:%SZ ") .. line
        if file then file:write(stamped, "\n") end
        if to_stderr then io.stderr:write(stamped, "\n") end
    end
    local code, err = daemon.run({ server = s.server, nat = s.nat, mirror = s.mirror, log = log,
        state_file = s.state_file, state_interval = s.state_interval, seconds = number(flags, "--seconds"),
        signals = true,
        on_listen = function(ip, port, reflector)
            io.stdout:write("listening ", ip, " ", port, "\n")
            if reflector then io.stdout:write("nat ", reflector.ip, " ", reflector.port, " ", reflector.alt_port, "\n") end
            io.stdout:flush()
        end })
    if file then file:close() end
    if not code then fail(tostring(err)) end
    os.exit(0)
end

function commands.status(args)
    local flags = parse(args, with(), "status")
    if flags.help then help("status") end
    local st, live = running_state(flags)
    if flags["--json"] then
        st.running_now = live and true or false
        out(json(st))
        os.exit(live and 0 or 1)
    end
    if not live then
        out(paint("red", not_running_line(st)))
        os.exit(1)
    end
    local s = st.stats or {}
    out(paint("green", "running") .. " as process " .. st.pid .. " on " .. st.bind.ip .. ":" .. st.bind.port)
    out("Lobbies: " .. (s.lobbies_active or 0) .. " active")
    out("Players: " .. (s.players_online or 0) .. " online, " .. (s.players_in_lobbies or 0) .. " in lobbies")
    out("Uptime: " .. cli.duration(st.uptime_seconds or 0))
    out(string.format("Traffic: %s/s in, %s/s out", cli.bytes(st.bytes_in_per_second or 0), cli.bytes(st.bytes_out_per_second or 0)))
    out("Messages: " .. (s.messages_per_second or 0) .. "/s; " .. (s.messages_in or 0) .. " in, " .. (s.messages_out or 0)
        .. " out since it started")
    if st.nat then out("NAT reflector: " .. st.nat.ip .. ":" .. st.nat.port .. " and :" .. st.nat.alt_port) end
    if st.mirror then out("Asset mirror: " .. #st.mirror.packs .. " packs, as " .. st.mirror.contact) end
    if not flags["-q"] then out(paint("blue", "updated " .. cli.duration(os.time() - st.updated) .. " ago")) end
    os.exit(0)
end

local STATE_COLOUR = { waiting = "green", countdown = "yellow", in_progress = "blue", starting = "yellow" }

local function host_of(l) return l.players and l.players[1] and l.players[1].name or "?" end

function commands.lobbies(args)
    local flags = parse(args, with(), "lobbies")
    if flags.help then help("lobbies") end
    local st, live = running_state(flags)
    if not live and not flags["--json"] then io.stderr:write(paint("yellow", not_running_line(st)), "\n") end
    local list = st.lobbies or {}
    if flags["--json"] then out(json(list)) os.exit(0) end
    if #list == 0 then out("no lobbies") os.exit(0) end
    out(string.format("%-6s %-28s %-14s %-8s %s", "ID", "MAP NAME", "HOST", "PLAYERS", "STATE"))
    for _, l in ipairs(list) do
        local players = #(l.players or {}) .. "/" .. l.max_players
        out(string.format("%-6s %-28s %-14s %-8s %s", tostring(l.game_id), l.map_name:sub(1, 28), host_of(l):sub(1, 14),
            players, paint(STATE_COLOUR[l.state] or "bold", l.state:upper())))
    end
    os.exit(0)
end

function commands.lobby(args)
    local flags, rest = parse(args, with(), "lobby")
    if flags.help then help("lobby") end
    local id = tonumber(rest[1])
    if not id then fail("lobby needs a lobby id (see `lobbies`)", 2) end
    local st, live = running_state(flags)
    local found
    for _, l in ipairs(st.lobbies or {}) do if l.game_id == id then found = l end end
    if not found then fail("no lobby " .. id .. (live and "" or " (" .. not_running_line(st) .. ")")) end
    if flags["--json"] then out(json(found)) os.exit(0) end
    local l = found
    out("Lobby: " .. l.game_id)
    out("Map: " .. l.map_name .. " (" .. l.map_hash .. ")")
    out("Mode: " .. l.game_mode .. ", region " .. l.region)
    out("Host: " .. host_of(l) .. " at " .. l.host_ip .. ", game port " .. l.host_port)
    out("Players: " .. #l.players .. "/" .. l.max_players)
    for i, p in ipairs(l.players) do
        out("  - " .. p.name .. (i == 1 and " (host)" or "") .. " " .. (p.ready and paint("green", "[ready]") or paint("yellow", "[not ready]")))
    end
    for _, p in ipairs(l.asset_packs or {}) do out("Asset pack: " .. p.id .. " (" .. p.hash .. ")") end
    out("State: " .. paint(STATE_COLOUR[l.state] or "bold", l.state:upper())
        .. (l.state == "countdown" and l.start_at and st.now and (", starting in " .. math.max(0, math.ceil(l.start_at - st.now)) .. "s") or ""))
    if l.created and st.now then out("Created: " .. cli.duration(st.now - l.created) .. " before the last update") end
    os.exit(0)
end

function commands.logs(args)
    local flags = parse(args, with({ ["--log-file"] = "value", ["-n"] = "value", ["--follow"] = true, ["--seconds"] = "value" }), "logs")
    if flags.help then help("logs") end
    local path = flags["--log-file"]
    if not path then
        local s = settings(flags)
        path = s and s.log_file
    end
    if not path then fail("which log? give --log-file, or --config with a log_file", 2) end
    local f = io.open(path, "r")
    if not f then fail("no log at " .. path) end
    local n = number(flags, "-n") or 50
    local lines = {}
    for line in f:lines() do
        lines[#lines + 1] = line
        if #lines > n then table.remove(lines, 1) end
    end
    for _, l in ipairs(lines) do out(l) end
    io.stdout:flush()
    if not flags["--follow"] then f:close() os.exit(0) end
    local socket = require("socket")
    local stop_at = number(flags, "--seconds") and socket.gettime() + number(flags, "--seconds")
    local partial = ""
    while not stop_at or socket.gettime() < stop_at do
        local more = f:read("*a")
        if more and #more > 0 then
            partial = partial .. more
            while true do
                local line, rest = partial:match("^([^\n]*)\n(.*)$")
                if not line then break end
                out(line)
                partial = rest
            end
            io.stdout:flush()
        else
            socket.sleep(0.2)
        end
    end
    f:close()
    os.exit(0)
end

-- The mirror's registry, from --packs-dir or the configuration.
local function mirror_registry(flags)
    local dir = flags["--packs-dir"]
    if not dir then
        local s = settings(flags)
        dir = s and s.mirror and s.mirror.packs_dir
    end
    if not dir then fail("which folder? give --packs-dir, or --config with an asset_mirror", 2) end
    local f = io.open(dir .. "/.", "r")
    if not f then fail("no folder " .. dir) end
    f:close()
    return packs.registry(dir), dir
end

-- Tells a running server to read the mirror's folder again, if one runs.
local function nudge(flags)
    if not (flags["--state"] or flags["--config"]) then return "no running server named (--config or --state)" end
    local st = daemon.read_state(state_path(flags))
    if not (st and st.running and alive(st.pid)) then return "no server running" end
    os.execute("kill -HUP " .. math.floor(st.pid))
    return "the running server (process " .. st.pid .. ") reads the folder again"
end

function commands.assets(args)
    local flags, rest = parse(args, with({ ["--packs-dir"] = "value" }), "assets")
    if flags.help or not rest[1] then help("assets") end
    local what = rest[1]
    local reg, dir = mirror_registry(flags)
    if what == "list" then
        local list = reg:list()
        if flags["--json"] then
            local l = {}
            for i, p in ipairs(list) do l[i] = { id = p.id, hash = p.hash, size = p.size } end
            out(json(l))
            os.exit(0)
        end
        if #list == 0 then out("no packs in " .. dir) end
        if #list > 0 then out(string.format("%-24s %10s  %s", "PACK ID", "SIZE", "HASH")) end
        for _, p in ipairs(list) do out(string.format("%-24s %10s  %s", p.id, cli.bytes(p.size), p.hash:sub(1, 23) .. "...")) end
        for _, why in ipairs(reg.skipped) do io.stderr:write(paint("yellow", "skipped: "), why, "\n") end
        os.exit(0)
    elseif what == "add" then
        local file = rest[2]
        if not file then fail("assets add needs a file", 2) end
        local id = rest[3] or file:match("([^/]+)$"):gsub("%.[^.]*$", "")
        if reg:has(id) then fail("there is already a pack " .. id .. " (remove it first)") end
        local p, err = reg:add(id, file)
        if not p then fail(err) end
        out(paint("green", "Added: ") .. p.id .. " (" .. cli.bytes(p.size) .. ", " .. p.hash .. ")")
        if not flags["-q"] then out(nudge(flags)) end
        os.exit(0)
    elseif what == "remove" then
        local id = rest[2]
        if not id then fail("assets remove needs a pack id", 2) end
        local ok, err = reg:remove(id)
        if not ok then fail(err) end
        out(paint("green", "Removed: ") .. id)
        if not flags["-q"] then out(nudge(flags)) end
        os.exit(0)
    end
    fail("assets " .. what .. "? (list, add or remove)", 2)
end

commands["validate-config"] = function(args)
    local flags, rest = parse(args, with(), "validate-config")
    if flags.help then help("validate-config") end
    local path = rest[1] or flags["--config"]
    if not path then fail("validate-config needs a file", 2) end
    local s, problems = config.load(path)
    if flags["--json"] then out(json({ valid = s ~= nil, problems = problems, settings = s })) os.exit(s and 0 or 1) end
    for _, p in ipairs(problems) do
        io.stdout:write(paint(p.level == "error" and "red" or "yellow", (p.level == "error" and "\226\156\151 " or "! ") .. p.level .. ": "), p.text, "\n")
    end
    if not s then
        out(paint("red", "Configuration not valid") .. " (" .. path .. ")")
        os.exit(1)
    end
    local sv = s.server
    out(paint("green", "\226\156\147 Configuration valid"))
    out("- Bind: " .. (sv.bind or "127.0.0.1:8080 (default)"))
    out("- Max lobbies: " .. (sv.max_lobbies or 1000) .. ", players each: " .. (sv.max_players_per_lobby or 12))
    out("- Countdown: " .. (sv.countdown_seconds or 0) .. "s")
    out("- NAT reflector: " .. (s.nat and ("UDP " .. s.nat.port .. " and " .. (s.nat.port + 1) .. (s.nat.alt_ip and (", also " .. s.nat.alt_ip) or "")) or "off"))
    out("- Asset mirror: " .. (s.mirror and ("on, as " .. s.mirror.contact .. ", " .. s.mirror.packs_dir) or "off"))
    out("- Log: " .. (s.log_file or "standard error"))
    out("- State file: " .. s.state_file .. ", every " .. s.state_interval .. "s")
    os.exit(0)
end
-- }}}

-- {{{ main
local args = { ... }
local name = table.remove(args, 1)
colour_on = ffi.C.isatty(1) == 1 and os.getenv("NO_COLOR") == nil
for _, a in ipairs(args) do if a == "--no-color" then colour_on = false end end
if name == nil or name == "--help" or name == "-h" or name == "help" then
    if name == "help" and args[1] then help(args[1]) end
    help("main")
end
local command = commands[name]
if not command then fail(name .. " is not a command (see --help)", 2) end
command(args)
-- }}}
