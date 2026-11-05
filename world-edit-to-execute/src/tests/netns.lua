--[[
netns.lua - runs a test in a network of its own (issue 801b)

In plain terms: a test that opens sockets runs itself again under
`unshare -rn`, which gives it a fresh network holding nothing but a
loopback device, so nothing it does can reach or be reached from any
other network, and no port it takes can clash with one in use. The
loopback starts switched off there; this switches it on (an ioctl through
LuaJIT's FFI, so no `ip` command is needed).

- **`netns.enter(script, args)`**: outside, runs `script` again with
  `args` under `unshare -rn` and exits with its status; inside (the
  environment's WETE_NETNS is 1), switches the loopback on and returns.
  Exits 1, saying why, when unshare can't make a network.
]]

local netns = {}

local function quote(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

local function status(r, how, code)
    if type(r) == "number" then return r > 255 and math.floor(r / 256) or r end
    return code or (r and 0 or 1)
end

-- {{{ netns.loopback_up
function netns.loopback_up()
    local ffi = require("ffi")
    pcall(ffi.cdef, [[
        int socket(int domain, int type, int protocol);
        int ioctl(int fd, unsigned long request, ...);
        int close(int fd);
        struct netns_ifreq { char name[16]; short flags; char pad[22]; };
    ]])
    local SIOCGIFFLAGS, SIOCSIFFLAGS, IFF_UP = 0x8913, 0x8914, 1
    local fd = ffi.C.socket(2, 2, 0)                        -- AF_INET, SOCK_DGRAM
    if fd < 0 then error("netns: no socket to switch the loopback on with", 0) end
    local req = ffi.new("struct netns_ifreq")
    ffi.copy(req.name, "lo")
    local ok = ffi.C.ioctl(fd, SIOCGIFFLAGS, req) == 0
    req.flags = bit.bor(req.flags, IFF_UP)
    ok = ok and ffi.C.ioctl(fd, SIOCSIFFLAGS, req) == 0
    ffi.C.close(fd)
    if not ok then error("netns: the loopback could not be switched on", 0) end
end
-- }}}

-- {{{ netns.enter
function netns.enter(script, args)
    if os.getenv("WETE_NETNS") == "1" then return netns.loopback_up() end
    if status(os.execute("unshare -rn true 2>/dev/null")) ~= 0 then
        print("  [FAIL] this test needs `unshare -rn` (a network of its own) and couldn't make one; not run")
        os.exit(1)
    end
    local cmd = { "WETE_NETNS=1 unshare -rn luajit", quote(script) }
    for _, a in ipairs(args or {}) do cmd[#cmd + 1] = quote(a) end
    os.exit(status(os.execute(table.concat(cmd, " "))))
end
-- }}}

return netns
