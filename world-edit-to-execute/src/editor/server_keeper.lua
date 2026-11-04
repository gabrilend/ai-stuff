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

Each program's output goes to <log_dir>/<name>.log; the pids of what is
running are in <log_dir>/server.pids, for anyone cleaning up after an
editor that was killed before it could stop them.

A server already listening on the login port that this editor didn't
start is used as it is and never stopped (it isn't the editor's); the
keeper says so, since it can't start that one again for a new build.

Nothing here waits: begin() starts, step() is called again and again
(each frame of the editor's window, or in a loop by the tests) until it
says ready or failed.

    local keeper = require("editor.server_keeper").new(s.test_map.server,
        { proc = proc, log_dir = s.test_map.log_dir })
    keeper:begin(build_dir, stamp)    -- "started", "reused", "restarted", "outside", or nil and why
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

function K:write_pids()
    local f = io.open(self.log_dir .. "/server.pids", "w")
    if not f then return end
    for _, r in ipairs(self.running or {}) do f:write(r.name, " ", r.pid, "\n") end
    f:close()
end

function K:log_of(name) return self.log_dir .. "/" .. name .. ".log" end
-- }}}

-- {{{ K:begin
function K:begin(build, stamp)
    local p = self.proc
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
        local pid, why = p.spawn(sub_build(prog.command, build),
            { dir = prog.dir, log = self:log_of(name), status = status, env = { WETE_TEST_MAP_BUILD = build } })
        if not pid then
            self:stop()
            self.state = "failed"
            return nil, why
        end
        self.running[#self.running + 1] = { name = name, pid = pid, port = prog.port, status = status }
    end
    self:write_pids()
    self.state, self.owned, self.stamp = "starting", true, stamp
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
        os.remove(self.log_dir .. "/server.pids")
    end
    self.running, self.state, self.owned, self.stamp = nil, "stopped", false, nil
    return stopped
end
-- }}}

return server_keeper
