--[[
Other Programs, Started and Watched (Issue 913)

The small seam Test Map runs outside programs through: the W02 converter,
the local AzerothCore's servers and the W client. Everything that starts,
watches or stops a program goes through here, so the tests hand Test Map
a fake one (a shell script that opens a port, writes a receipt, crashes or
hangs) and nothing else changes.

  proc.spawn(argv, opts)   starts argv in the background, its own process
                           group (setsid), and returns its pid at once.
                           opts.dir: where it runs; opts.log: its output,
                           appended; opts.status: a file its exit code is
                           written to when it ends; opts.env: { NAME =
                           value } given to it alone. The environment is
                           set in this process just around the start and
                           put back after, so a value (the W client's
                           password) is never on any command line and
                           never written to a file.
  proc.alive(pid)          true while it runs (a zombie counts as gone)
  proc.start_time(pid)     when it started, in the kernel's clock ticks
                           since boot (/proc/<pid>/stat, field 22), or
                           nil: a pid and its start time name one process,
                           where a pid alone may since have been reused
  proc.self()              this process's pid
  proc.stop(pid, seconds)  TERM to its group, KILL after `seconds`; true
                           once it's gone
  proc.exit_code(status)   the code written to opts.status, or nil
  proc.port_open(host, port, ms)  true when something accepts a TCP
                           connection there, waiting at most ms for it
  proc.now()               seconds on the monotonic clock
  proc.sleep(seconds)

Linux only (/proc, setsid, the socket calls below); the project's
machines are.
]]

local ffi = require("ffi")
local clock = require("net.clock")

pcall(ffi.cdef, [[
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
int kill(int pid, int sig);
int getpid(void);
]])
pcall(ffi.cdef, [[
typedef struct { uint16_t family; uint16_t port; uint32_t addr; uint8_t zero[8]; } wete_sockaddr_in;
typedef struct { int fd; short events; short revents; } wete_pollfd;
int socket(int domain, int type, int protocol);
int connect(int fd, const void *addr, uint32_t len);
int poll(wete_pollfd *fds, unsigned long n, int timeout);
int getsockopt(int fd, int level, int name, void *val, uint32_t *len);
int inet_pton(int af, const char *src, void *dst);
int close(int fd);
]])

local C = ffi.C
local proc = {}

local SIGTERM, SIGKILL = 15, 9
local AF_INET, SOCK_STREAM, SOCK_NONBLOCK = 2, 1, 2048
local POLLOUT, SOL_SOCKET, SO_ERROR = 4, 1, 4

-- {{{ quoting
local function q(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
proc.quote = q
-- }}}

-- {{{ proc.now, proc.sleep
function proc.now() return clock.now_ms() / 1000 end
function proc.sleep(s) clock.sleep_ms(s * 1000) end
-- }}}

-- {{{ proc.spawn
local has_setsid
function proc.spawn(argv, opts)
    opts = opts or {}
    if type(argv) == "string" then argv = { argv } end
    if not argv or not argv[1] then return nil, "nothing to run" end
    if has_setsid == nil then
        has_setsid = os.execute("command -v setsid >/dev/null 2>&1")
        has_setsid = has_setsid == true or has_setsid == 0
    end
    local words = {}
    for i, a in ipairs(argv) do words[i] = q(a) end
    local status = opts.status or "/dev/null"
    local log = opts.log or "/dev/null"
    -- sh -c runs the program and writes its exit code when it ends; setsid
    -- makes that sh the leader of its own group (it doesn't fork, as the
    -- background child isn't a group leader), so its pid is the group's
    local cmd = string.format("%s%s sh -c '\"$@\"; echo $? > \"$0\"' %s %s >>%s 2>&1 </dev/null & echo $!",
        opts.dir and ("cd " .. q(opts.dir) .. " || exit 1; ") or "",
        has_setsid and "setsid" or "", q(status), table.concat(words, " "), q(log))
    -- the environment for it alone: set around the start, put back after
    local saved = {}
    for k, v in pairs(opts.env or {}) do
        saved[k] = os.getenv(k) or false
        C.setenv(k, tostring(v), 1)
    end
    local p = io.popen(cmd)
    local out = p and p:read("*a") or ""
    if p then p:close() end
    for k, old in pairs(saved) do
        if old then C.setenv(k, old, 1) else C.unsetenv(k) end
    end
    local pid = tonumber(out:match("(%d+)"))
    if not pid then return nil, "couldn't start " .. tostring(argv[1]) end
    return pid
end
-- }}}

-- {{{ proc.alive, proc.stop, proc.exit_code
function proc.alive(pid)
    if not pid then return false end
    local f = io.open("/proc/" .. pid .. "/stat", "r")
    if not f then return false end
    local line = f:read("*l") or ""
    f:close()
    local state = line:match("^%d+ %b() (%a)")
    return state ~= nil and state ~= "Z" and state ~= "X"
end

-- the fields after the command's name, which is in brackets and may hold
-- spaces or brackets of its own: the state is field 3, the start time 22
local function stat_fields(pid)
    if not pid then return nil end
    local f = io.open("/proc/" .. pid .. "/stat", "r")
    if not f then return nil end
    local line = f:read("*l") or ""
    f:close()
    local after = line:match("^%d+ %(.*%) (.*)$")
    if not after then return nil end
    local fields = {}
    for w in after:gmatch("%S+") do fields[#fields + 1] = w end
    return fields
end

function proc.start_time(pid)
    local fields = stat_fields(pid)
    return fields and tonumber(fields[20])          -- field 22: the 20th after the name
end

function proc.self() return tonumber(C.getpid()) end

-- TERM to the whole group (the program and anything it started), then
-- KILL once `seconds` have passed
function proc.stop(pid, seconds)
    if not pid then return true end
    if not proc.alive(pid) then return true end
    if C.kill(-pid, SIGTERM) ~= 0 then C.kill(pid, SIGTERM) end
    local until_t = proc.now() + (seconds or 10)
    while proc.alive(pid) and proc.now() < until_t do proc.sleep(0.05) end
    if proc.alive(pid) then
        if C.kill(-pid, SIGKILL) ~= 0 then C.kill(pid, SIGKILL) end
        local t2 = proc.now() + 2
        while proc.alive(pid) and proc.now() < t2 do proc.sleep(0.05) end
    end
    return not proc.alive(pid)
end

function proc.exit_code(status)
    if not status then return nil end
    local f = io.open(status, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return tonumber(s:match("%-?%d+"))
end
-- }}}

-- {{{ proc.port_open
function proc.port_open(host, port, ms)
    if host == "localhost" then host = "127.0.0.1" end
    local sa = ffi.new("wete_sockaddr_in")
    sa.family = AF_INET
    sa.port = bit.bor(bit.lshift(bit.band(port, 0xff), 8), bit.rshift(port, 8))   -- network order
    if C.inet_pton(AF_INET, host, ffi.cast("void *", ffi.cast("char *", sa) + 4)) ~= 1 then
        return false, "not an IPv4 address: " .. tostring(host)
    end
    local fd = C.socket(AF_INET, bit.bor(SOCK_STREAM, SOCK_NONBLOCK), 0)
    if fd < 0 then return false, "no socket" end
    local ok = false
    if C.connect(fd, sa, ffi.sizeof(sa)) == 0 then ok = true
    else
        local pfd = ffi.new("wete_pollfd[1]")
        pfd[0].fd, pfd[0].events = fd, POLLOUT
        if C.poll(pfd, 1, ms or 200) == 1 then
            local err = ffi.new("int[1]")
            local len = ffi.new("uint32_t[1]", 4)
            ok = C.getsockopt(fd, SOL_SOCKET, SO_ERROR, err, len) == 0 and err[0] == 0
        end
    end
    C.close(fd)
    return ok
end
-- }}}

return proc
