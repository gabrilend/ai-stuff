--[[
daemon.lua - runs the matchmaking server until it is told to stop (issue 801g)

In plain terms: the loop shared by `src/cli/matchmaking-serve.lua` and
`src/cli/world-edit-matchmaking.lua serve`. It starts the server, the NAT
reflector (801d) and the asset mirror (801f) when asked; writes a state
file every few seconds (what `status` and `lobbies` read); and stops
cleanly on SIGTERM or SIGINT: every lobby's members are told, the state
file says it stopped, and it returns. SIGHUP has it look at the mirror's
folder again.

    local daemon = require("matchmaking.daemon")
    local code = daemon.run({
        server = { bind = "0.0.0.0:8080", ... },  -- server.lua's settings
        nat = { port = 3478, alt_ip = nil },       -- or nil
        mirror = { contact = "...", packs_dir = "..." },  -- or nil
        log = function(line) end,                  -- or nil
        state_file = "matchmaking.state", state_interval = 2,
        seconds = nil,                             -- stop after this long
        signals = true,                            -- TERM, INT, HUP
        on_listen = function(ip, port, reflector) end,
    })
    -- 0 when it stopped as asked; nil and why when it couldn't start.

Signals are taken through a signalfd (Linux, through LuaJIT's FFI):
they're blocked for the process and read between ticks, so a signal
never interrupts the server mid-message.

The state file is a Lua table (`return { ... }`), written whole to a
`.part` file and renamed, so a reader never sees half of one.
]]

local server = require("matchmaking.server")
local nat = require("matchmaking.nat")
local packs = require("matchmaking.packs")

local daemon = {}

-- {{{ signals
local ffi = require("ffi")
local function cdef(s) pcall(ffi.cdef, s) end
cdef("typedef struct { unsigned long val[16]; } wete_sigset_t;")
cdef("int sigemptyset(wete_sigset_t *set);")
cdef("int sigaddset(wete_sigset_t *set, int signum);")
cdef("int sigprocmask(int how, const wete_sigset_t *set, wete_sigset_t *oldset);")
cdef("int signalfd(int fd, const wete_sigset_t *mask, int flags);")
cdef("long read(int fd, void *buf, unsigned long count);")
cdef("int close(int fd);")
cdef("int getpid(void);")

daemon.SIGNALS = { HUP = 1, INT = 2, TERM = 15 }
local SIG_BLOCK, SIG_SETMASK, SFD_NONBLOCK, SFD_CLOEXEC = 0, 2, 2048, 524288

-- Blocks `names` for this process and gives a reader of them: `:take()`
-- returns the name of one that came, or nil; `:close()` unblocks them.
function daemon.signals(names)
    local set, old = ffi.new("wete_sigset_t"), ffi.new("wete_sigset_t")
    ffi.C.sigemptyset(set)
    for _, n in ipairs(names) do ffi.C.sigaddset(set, daemon.SIGNALS[n]) end
    if ffi.C.sigprocmask(SIG_BLOCK, set, old) ~= 0 then return nil, "signals could not be blocked" end
    local fd = ffi.C.signalfd(-1, set, SFD_NONBLOCK + SFD_CLOEXEC)
    if fd < 0 then
        ffi.C.sigprocmask(SIG_SETMASK, old, nil)
        return nil, "no signalfd"
    end
    local by_number = {}
    for _, n in ipairs(names) do by_number[daemon.SIGNALS[n]] = n end
    local buf = ffi.new("uint8_t[128]")                   -- one struct signalfd_siginfo
    local r = {}
    function r.take()
        if ffi.C.read(fd, buf, 128) ~= 128 then return nil end
        return by_number[ffi.cast("uint32_t *", buf)[0]] or "?"
    end
    function r.close()
        ffi.C.close(fd)
        ffi.C.sigprocmask(SIG_SETMASK, old, nil)
    end
    return r
end

function daemon.pid() return ffi.C.getpid() end
-- }}}

-- {{{ the state file
-- Plain data as Lua source: tables, strings, numbers, booleans.
function daemon.serialize(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "string" then return string.format("%q", v) end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        return v == math.floor(v) and string.format("%d", v) or string.format("%.17g", v)
    end
    if t == "boolean" or t == "nil" then return tostring(v) end
    if t ~= "table" then return "nil" end
    local inner = indent .. "  "
    local parts, n = {}, #v
    for i = 1, n do parts[#parts + 1] = inner .. daemon.serialize(v[i], inner) end
    local keys = {}
    for k in pairs(v) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. daemon.serialize(k) .. "]")
        parts[#parts + 1] = inner .. key .. " = " .. daemon.serialize(v[k], inner)
    end
    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
end

-- Writes `state` to `path` whole (through path .. ".part").
function daemon.write_state(path, state)
    local tmp = path .. ".part"
    local f, err = io.open(tmp, "w")
    if not f then return nil, err end
    f:write("return ", daemon.serialize(state), "\n")
    f:close()
    return os.rename(tmp, path)
end

-- The state in `path`, or nil and why. Read with no globals at all.
function daemon.read_state(path)
    local chunk, err = loadfile(path)
    if not chunk then return nil, err end
    setfenv(chunk, {})
    local ok, state = pcall(chunk)
    if not ok or type(state) ~= "table" then return nil, path .. " holds no state" end
    return state
end
-- }}}

-- {{{ daemon.run
function daemon.run(o)
    local log = o.log or function() end
    local config = {}
    for k, v in pairs(o.server or {}) do config[k] = v end
    config.log = log
    local registry
    if o.mirror then
        local f = io.open(o.mirror.packs_dir .. "/.", "r")
        if not f then return nil, "no folder " .. o.mirror.packs_dir end
        f:close()
        registry = packs.registry(o.mirror.packs_dir)
        config.mirror = { contact = o.mirror.contact, packs = registry }
        log("mirroring " .. #registry:list() .. " packs from " .. o.mirror.packs_dir .. " as " .. o.mirror.contact)
        for _, why in ipairs(registry.skipped) do log("not mirrored: " .. why) end
    end
    local ok_new, srv = pcall(server.new, config)
    if not ok_new then return nil, srv end
    local ok, err = pcall(srv.start, srv)
    if not ok then return nil, err end
    local ip, port = srv:address()
    local reflector
    if o.nat then
        local rok, r = pcall(nat.reflector_udp, ip, o.nat.port, o.nat.alt_ip)
        if not rok then srv:stop() return nil, r end
        reflector = r
        log("NAT reflector on " .. r.ip .. ":" .. r.port .. " and :" .. r.alt_port .. (o.nat.alt_ip and (", and " .. o.nat.alt_ip) or ""))
    end
    local sig
    if o.signals then
        local why
        sig, why = daemon.signals({ "TERM", "INT", "HUP" })
        if not sig then log("no signal handling: " .. why) end
    end
    log("listening on " .. ip .. ":" .. port)
    if o.on_listen then o.on_listen(ip, port, reflector) end

    local pid, started = daemon.pid(), os.time()
    local interval = o.state_interval or 2
    local last_write, last_bytes_in, last_bytes_out, last_at = -math.huge, 0, 0, srv.clock()
    local function state(running, stopped_by)
        local now = srv.clock()
        local s = srv:stats()
        local dt = math.max(now - last_at, 1e-6)
        local st = { pid = pid, running = running, stopped_by = stopped_by, started = started, updated = os.time(),
            uptime_seconds = math.floor(s.uptime_seconds), bind = { ip = ip, port = port },
            stats = s, bytes_in_per_second = (s.bytes_in - last_bytes_in) / dt,
            bytes_out_per_second = (s.bytes_out - last_bytes_out) / dt,
            lobbies = srv:lobby_list(), now = now }
        last_bytes_in, last_bytes_out, last_at = s.bytes_in, s.bytes_out, now
        if reflector then st.nat = { ip = reflector.ip, port = reflector.port, alt_port = reflector.alt_port } end
        if registry then
            st.mirror = { contact = o.mirror.contact, packs_dir = o.mirror.packs_dir, packs = {} }
            for i, p in ipairs(registry:list()) do st.mirror.packs[i] = { id = p.id, hash = p.hash, size = p.size } end
        end
        return st
    end
    local function write(running, stopped_by)
        if not o.state_file then return end
        local wok, werr = daemon.write_state(o.state_file, state(running, stopped_by))
        if not wok then log("state file not written: " .. tostring(werr)) end
    end

    local stop_at = o.seconds and srv.clock() + o.seconds
    local stopped_by = "time up"
    while not stop_at or srv.clock() < stop_at do
        srv:tick(reflector and 0.01 or 0.05)
        if reflector then reflector:poll() end
        local name = sig and sig.take()
        if name == "TERM" or name == "INT" then stopped_by = "SIG" .. name break end
        if name == "HUP" and registry then
            registry:reload()
            log("mirror folder read again: " .. #registry:list() .. " packs")
            last_write = -math.huge
        end
        if srv.clock() - last_write >= interval then
            write(true)
            last_write = srv.clock()
        end
    end
    log("stopping: " .. stopped_by)
    if reflector then reflector:close() end
    srv:stop()
    write(false, stopped_by)
    if sig then sig.close() end
    return 0, stopped_by
end
-- }}}

return daemon
