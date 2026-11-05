--[[
A fake AzerothCore server for the Test Map tests (issue 913): opens a TCP
port and accepts connections until it is stopped, as authserver and
worldserver do once they are up. No AzerothCore runs in the tests.

  luajit fake-server.lua <port> <starts-file> <build> [mode] [delay]

  starts-file  a line is added each time it starts: "<port> <build>"
  mode         listen (the default), never (runs, never opens the
               port: a server that hangs while starting), die (exits
               with code 3 after the delay without opening it)
  delay        seconds before it opens the port (or dies)
]]

local ffi = require("ffi")
ffi.cdef[[
typedef struct { uint16_t family; uint16_t port; uint32_t addr; uint8_t zero[8]; } fake_sockaddr_in;
int socket(int domain, int type, int protocol);
int setsockopt(int fd, int level, int name, const void *val, uint32_t len);
int bind(int fd, const void *addr, uint32_t len);
int listen(int fd, int backlog);
int accept(int fd, void *addr, void *len);
int close(int fd);
int poll(void *fds, unsigned long n, int timeout);
]]
local C = ffi.C

local port = assert(tonumber(arg[1]), "a port")
local starts, build = arg[2], arg[3]
local mode, delay = arg[4] or "listen", tonumber(arg[5] or "0")

local f = io.open(starts, "a")
f:write(port, " ", tostring(build), " ", tostring(os.getenv("WETE_TEST_MAP_BUILD")), "\n")
f:close()

local function sleep(s) C.poll(nil, 0, math.floor(s * 1000)) end
sleep(delay)
if mode == "die" then os.exit(3) end
if mode == "never" then while true do sleep(1) end end

local fd = C.socket(2, 1, 0)
local one = ffi.new("int[1]", 1)
C.setsockopt(fd, 1, 2, one, 4)                 -- SO_REUSEADDR
local sa = ffi.new("fake_sockaddr_in")
sa.family = 2
sa.port = bit.bor(bit.lshift(bit.band(port, 0xff), 8), bit.rshift(port, 8))
sa.addr = 0x0100007f                           -- 127.0.0.1, network order on little-endian
assert(C.bind(fd, sa, ffi.sizeof(sa)) == 0, "bind " .. port)
assert(C.listen(fd, 16) == 0)
while true do
    local c = C.accept(fd, nil, nil)
    if c >= 0 then C.close(c) end
end
