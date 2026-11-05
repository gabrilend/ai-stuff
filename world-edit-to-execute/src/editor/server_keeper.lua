--[[
The Local AzerothCore, Kept by the Editor (Issue 913, step 2)

The owner, 2026-11-04, asked who starts the local AzerothCore Test Map
plays on: "the editor." So the editor starts it, waits until it accepts
logins, reuses it for the next Test Map, starts it again when the next
Test Map brings a different build, and stops it when the editor closes.

What it runs comes from the editor's settings (editor/settings.lua),
test_map.server:

  programs     in order, each { name, command = { program, args... },
               dir, port }: AzerothCore's authserver and worldserver. In a
               command, {build} is replaced by the build folder; the
               build folder is also in each one's environment as
               WETE_TEST_MAP_BUILD. How a build reaches the server (its
               rows, its scripts, its map files) is W02f's to decide; the
               keeper only starts what it is told to, with the build
               named.
  host, login_port   where the W client logs in (the authserver's port)
  start_seconds      the longest to wait for every program's port
  stop_seconds       TERM, then KILL after this long

Each program's output goes to <log_dir>/<name>.log. What is running is
in <log_dir>/server.pids (data: which editor started it, the build's
stamp, each program's name, command, port, pid and the pid's start time),
so the next editor can pick up after one that was killed before it could
stop its server (2026-11-05). On its first begin() a keeper reads that
file:

  - the editor that wrote it is still running: its server is left to it
    (the login port is open, so this one uses it as it is: "outside");
  - every program is still running, as the same process (the pid and its
    start time agree) and as the settings start it now: the server is
    taken over ("reclaimed"), waited on until it accepts connections, and
    reused or started again by the build's stamp, as if this editor had
    started it;
  - only some are: those are stopped, and the server is started anew;
  - none are: the file is removed.

A pid whose start time differs is another process that took the number
since, and is never stopped. A file that can't be read as that data (an
older editor's "name pid" lines) is left alone: with no start times its
pids can't be told from reused ones.

A server already listening on the login port that this editor didn't
start is used as it is and never stopped (it isn't the editor's); the
keeper says so, since it can't start that one again for a new build.

Nothing here waits: begin() starts, step() is called again and again
(each frame of the editor's window, or in a loop by the tests) until it
says ready or failed.

    local keeper = require("editor.server_keeper").new(s.test_map.server,
        { proc = proc, log_dir = s.test_map.log_dir })
    keeper:begin(build_dir, stamp)    -- "started", "reused", "restarted", "reclaimed", "outside",
                                      -- or nil and why
    keeper:step()                     -- "ready", "waiting", or nil and why
    keeper:stop()                     -- what it started, stopped
]]

local server_keeper = {}

local K = {}
K.__index = K

-- {{{ server_keeper.new
function server_keeper.new(cfg, opts)
    opts = opts or {}
    local self = setmetatable({ cfg = cfg or {}, proc = opts.proc or require("editor.proc"),
                                log_dir = opts.log_dir or "tmp/shared-memory/test-map",
                                say = opts.say or function() end,
                                state = "stopped", running = nil, stamp = nil, owned = false }, K)
    self.host = self.cfg.host or "127.0.0.1"
    self.login_port = self.cfg.login_port or 3724
    self.poll_every = opts.poll_every or 0.25
    return self
end
-- }}}

-- {{{ helpers
local function sub_build(argv, build)
    local out = {}
    for i, a in ipairs(argv) do out[i] = (tostring(a):gsub("{build}", function() return build end)) end
    return out
end

function K:all_alive()
    if not self.running then return false end
    for _, r in ipairs(self.running) do
        if not self.proc.alive(r.pid) then return false, r end
    end
    return true
end

-- {{{ server.pids: what this editor runs, for the next one
server_keeper.PIDS = "server.pids"
server_keeper.PIDS_FORMAT = 1

local function lua_string(v) return string.format("%q", tostring(v)) end

function K:pids_path() return self.log_dir .. "/" .. server_keeper.PIDS end

function K:write_pids()
    local p = self.proc
    local me = p.self and p.self()
    local o = { "-- Test Map's server, kept by the editor (src/editor/server_keeper.lua): data only",
                "return {", "    format = " .. server_keeper.PIDS_FORMAT .. "," }
    if me then
        o[#o + 1] = string.format("    editor = { pid = %d, started = %s },", me,
            tostring(p.start_time and p.start_time(me) or "nil"))
    end
    if self.stamp ~= nil then o[#o + 1] = "    stamp = " .. lua_string(self.stamp) .. "," end
    if self.build then o[#o + 1] = "    build = " .. lua_string(self.build) .. "," end
    o[#o + 1] = "    programs = {"
    for _, r in ipairs(self.running or {}) do
        local words = {}
        for i, a in ipairs(r.command or {}) do words[i] = lua_string(a) end
        o[#o + 1] = string.format("        { name = %s, pid = %d, started = %s, port = %s, command = { %s } },",
            lua_string(r.name), r.pid, tostring(r.started or "nil"), tostring(r.port or "nil"), table.concat(words, ", "))
    end
    o[#o + 1] = "    },"
    o[#o + 1] = "}"
    local path = self:pids_path()
    local f = io.open(path .. ".part", "w")
    if not f then return end
    f:write(table.concat(o, "\n"), "\n")
    f:close()
    os.rename(path .. ".part", path)
end

-- the file, read as data in an empty environment, or nil and why ("none":
-- there is no file)
function server_keeper.read_pids(path)
    local f = io.open(path, "r")
    if not f then return nil, "none" end
    local text = f:read(256 * 1024 + 1) or ""
    f:close()
    if #text > 256 * 1024 then return nil, "too big" end
    local chunk = loadstring(text, "=" .. server_keeper.PIDS)
    if not chunk then return nil, "not data this editor writes (an older editor's?)" end
    setfenv(chunk, {})
    local ok, t = pcall(chunk)
    if not ok or type(t) ~= "table" or t.format ~= server_keeper.PIDS_FORMAT or type(t.programs) ~= "table" then
        return nil, "not data this editor writes (an older editor's?)"
    end
    for _, r in ipairs(t.programs) do
        if type(r) ~= "table" or type(r.pid) ~= "number" or r.pid <= 1 or type(r.name) ~= "string" then
            return nil, "a program in it has no pid"
        end
    end
    return t
end
-- }}}

function K:log_of(name) return self.log_dir .. "/" .. name .. ".log" end
-- }}}

-- {{{ K:reclaim: a killed editor's server, taken over or stopped
-- Returns "reclaimed" (this keeper now runs it), "stopped" (what was left
-- of it), "gone", "theirs" (its editor still runs), or nil (nothing to do)
function K:reclaim(build)
    local p = self.proc
    if not (p.start_time and p.self) then return nil end
    local path = self:pids_path()
    local left, why = server_keeper.read_pids(path)
    if not left then
        if why ~= "none" then
            self.say("Test Map: " .. path .. " is " .. why .. "; left as it is, and nothing in it stopped")
        end
        return nil
    end
    local function same(pid, started)
        return pid and started and p.alive(pid) and p.start_time(pid) == started
    end
    local ed = left.editor
    if type(ed) == "table" and ed.pid ~= p.self() and same(ed.pid, ed.started) then
        self.say(string.format("Test Map: the server in %s is another editor's (pid %d, still running); left to it", path, ed.pid))
        return "theirs"
    end
    local live, n = {}, #left.programs
    for _, r in ipairs(left.programs) do
        if same(r.pid, r.started) then live[#live + 1] = r end
    end
    if #live == 0 then
        os.remove(path)
        self.say("Test Map: the server a closed editor left in " .. path .. " is gone")
        return "gone"
    end
    -- the same programs as the settings start now, in order, for this build?
    local programs, matches = self.cfg.programs or {}, #live == n and n == #(self.cfg.programs or {})
    for i, prog in ipairs(programs) do
        local r = left.programs[i]
        local name = prog.name or tostring(prog.command and prog.command[1])
        local want = prog.command and sub_build(prog.command, build) or {}
        matches = matches and r ~= nil and r.name == name and r.port == prog.port and left.build == build
            and type(r.command) == "table" and table.concat(r.command, "\0") == table.concat(want, "\0")
    end
    if not matches then
        for i = #live, 1, -1 do p.stop(live[i].pid, self.cfg.stop_seconds or 20) end
        os.remove(path)
        self.say(string.format("Test Map: stopped what was left of the server a closed editor started (%d of %d programs%s)",
            #live, n, #live == n and ", started otherwise than the settings say now" or ""))
        return "stopped"
    end
    self.running = {}
    for _, r in ipairs(left.programs) do
        self.running[#self.running + 1] = { name = r.name, pid = r.pid, started = r.started, port = r.port,
            command = r.command, status = self.log_dir .. "/" .. r.name .. ".status" }
    end
    self.owned, self.stamp, self.build = true, left.stamp, left.build
    self.state, self.started_at, self.polled_at = "starting", p.now(), -1e9
    self:write_pids()
    self.say("Test Map: took over the server a closed editor started (" .. n .. " programs)")
    return "reclaimed"
end
-- }}}

-- {{{ K:begin
function K:begin(build, stamp)
    local p = self.proc
    if not self.running and not self.reclaimed then
        self.reclaimed = true
        if self:reclaim(build) == "reclaimed" then
            if stamp ~= nil and stamp == self.stamp then return "reclaimed" end
            self.say("Test Map: a new build; stopping the server to start it with that")
            self:stop()
            local how, why = self:start(build, stamp)
            return how and "restarted" or nil, why
        end
    end
    if self.running and self:all_alive() then
        if stamp == self.stamp then
            self.state = "ready"
            return "reused"
        end
        self.say("Test Map: a new build; stopping the server to start it with that")
        self:stop()
        local how, why = self:start(build, stamp)
        return how and "restarted" or nil, why
    end
    if self.running then self:stop() end    -- one of them died: start them all again
    if p.port_open(self.host, self.login_port, 200) then
        self.state, self.owned, self.stamp = "ready", false, stamp
        return "outside"
    end
    return self:start(build, stamp)
end

function K:start(build, stamp)
    local p = self.proc
    local programs = self.cfg.programs or {}
    if #programs == 0 then
        self.state = "failed"
        return nil, "no AzerothCore programs in the editor's settings (test_map.server.programs)"
    end
    os.execute("mkdir -p " .. p.quote(self.log_dir))
    self.running = {}
    for _, prog in ipairs(programs) do
        local name = prog.name or tostring(prog.command and prog.command[1])
        if not prog.command or not prog.command[1] then
            self:stop()
            self.state = "failed"
            return nil, "the server program " .. name .. " has no command in the editor's settings"
        end
        local status = self.log_dir .. "/" .. name .. ".status"
        os.remove(status)
        local argv = sub_build(prog.command, build)
        local pid, why = p.spawn(argv,
            { dir = prog.dir, log = self:log_of(name), status = status, env = { WETE_TEST_MAP_BUILD = build } })
        if not pid then
            self:stop()
            self.state = "failed"
            return nil, why
        end
        self.running[#self.running + 1] = { name = name, pid = pid, port = prog.port, status = status, command = argv,
                                            started = p.start_time and p.start_time(pid) }
    end
    self.state, self.owned, self.stamp, self.build = "starting", true, stamp, build
    self:write_pids()
    self.started_at, self.polled_at = p.now(), -1e9
    return "started"
end
-- }}}

-- {{{ K:step
function K:step()
    local p = self.proc
    if self.state == "ready" then return "ready" end
    if self.state ~= "starting" then return nil, "the server isn't starting" end
    local alive, dead = self:all_alive()
    if not alive then
        local code = p.exit_code(dead.status)
        self:stop()
        self.state = "failed"
        return nil, string.format("%s exited%s before it accepted connections; its log: %s", dead.name,
            code and (" (code " .. code .. ")") or "", self:log_of(dead.name))
    end
    local now = p.now()
    if now - self.polled_at >= self.poll_every then
        self.polled_at = now
        local closed = {}
        local ports = { [self.login_port] = "the login port" }
        for _, r in ipairs(self.running) do if r.port then ports[r.port] = r.name end end
        for port, who in pairs(ports) do
            if not p.port_open(self.host, port, 100) then closed[#closed + 1] = who .. " (" .. port .. ")" end
        end
        if #closed == 0 then
            self.state = "ready"
            self.ready_after = now - self.started_at
            return "ready"
        end
        local limit = self.cfg.start_seconds or 180
        if now - self.started_at > limit then
            self:stop()
            self.state = "failed"
            table.sort(closed)
            return nil, string.format("AzerothCore didn't accept connections within %d s on %s", limit,
                table.concat(closed, ", "))
        end
    end
    return "waiting"
end
-- }}}

-- {{{ K:stop
-- stops what this editor started, the last started first; a server it
-- didn't start is left alone
function K:stop()
    local p = self.proc
    local stopped = 0
    if self.running then
        for i = #self.running, 1, -1 do
            local r = self.running[i]
            if p.alive(r.pid) then
                p.stop(r.pid, self.cfg.stop_seconds or 20)
                stopped = stopped + 1
            end
        end
        os.remove(self:pids_path())
    end
    self.running, self.state, self.owned, self.stamp, self.build = nil, "stopped", false, nil, nil
    return stopped
end
-- }}}

return server_keeper
