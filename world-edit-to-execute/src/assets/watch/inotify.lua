--[[
Watch by Being Told: Linux inotify Through the FFI (Issue 606)

The kernel queues an event when a file under a watched folder is written,
added, moved or removed; changes() reads what is queued without waiting.
Every folder under each watched one gets its own watch (inotify doesn't
reach into sub-folders by itself), and a folder made later is watched as
soon as its event is read, with the files already in it reported.

    local inotify = require("assets.watch.inotify")
    if inotify.available() then
        local W = inotify.new({ "/path/to/pack-a" })
        for _, c in ipairs(W:changes()) do
            -- c.dir: the folder as given; c.rel: the file within it; c.gone: removed
        end
        W:add(dir)   W:close()
    end

When the kernel's queue overflows (thousands of events between two
reads), the events in it are lost: changes() then reports every file
under every folder, so nothing is missed, only read once more.
]]

local ffi = require("ffi")
local bit = require("bit")

local inotify = {}

ffi.cdef[[
int inotify_init1(int flags);
int inotify_add_watch(int fd, const char *pathname, uint32_t mask);
struct wcx_inotify_event { int wd; uint32_t mask; uint32_t cookie; uint32_t len; };
]]
-- read() and close() are libc's own; another module may have declared
-- them already, and declaring a function twice is an error in the FFI.
pcall(ffi.cdef, "long read(int fd, void *buf, size_t count);")
pcall(ffi.cdef, "int close(int fd);")

-- {{{ constants (linux/inotify.h)
inotify.IN_MODIFY      = 0x00000002
inotify.IN_CLOSE_WRITE = 0x00000008
inotify.IN_MOVED_FROM  = 0x00000040
inotify.IN_MOVED_TO    = 0x00000080
inotify.IN_CREATE      = 0x00000100
inotify.IN_DELETE      = 0x00000200
inotify.IN_Q_OVERFLOW  = 0x00004000
inotify.IN_IGNORED     = 0x00008000
inotify.IN_ISDIR       = 0x40000000
local IN_NONBLOCK, IN_CLOEXEC = 2048, 524288
local EAGAIN = 11
local MASK = bit.bor(inotify.IN_CLOSE_WRITE, inotify.IN_MOVED_FROM, inotify.IN_MOVED_TO,
                     inotify.IN_CREATE, inotify.IN_DELETE)
local HEAD = ffi.sizeof("struct wcx_inotify_event")
local BUFSIZE = 64 * 1024
-- }}}

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function find(dir, kind)
    local out = {}
    local p = io.popen("find -L " .. sh(dir) .. " -mindepth 1 -type " .. kind .. " -printf '%P\\n' 2>/dev/null")
    for rel in p:lines() do out[#out + 1] = rel end
    p:close()
    table.sort(out)
    return out
end

local function join(prefix, name)
    if prefix == "" then return name end
    return prefix .. "/" .. name
end
-- }}}

-- {{{ function inotify.available
-- True on Linux when an inotify instance can be made (a sandbox or an
-- exhausted per-user limit can refuse it).
function inotify.available()
    if jit.os ~= "Linux" then return false end
    local ok, fd = pcall(ffi.C.inotify_init1, bit.bor(IN_NONBLOCK, IN_CLOEXEC))
    if not ok or fd < 0 then return false end
    ffi.C.close(fd)
    return true
end
-- }}}

local W = {}
W.__index = W

-- {{{ function inotify.new
function inotify.new(dirs)
    if jit.os ~= "Linux" then error("inotify: Linux only", 2) end
    local fd = ffi.C.inotify_init1(bit.bor(IN_NONBLOCK, IN_CLOEXEC))
    if fd < 0 then error("inotify: can't start (errno " .. ffi.errno() .. ")", 2) end
    local self = setmetatable({ fd = fd, dirs = {}, seen = {}, wds = {}, watches = 0,
                                buf = ffi.new("uint8_t[?]", BUFSIZE), backend = "inotify" }, W)
    for _, dir in ipairs(dirs or {}) do self:add(dir) end
    return self
end
-- }}}

-- {{{ function W:watch
-- One folder: DIR is the watched folder as given, PREFIX the sub-folder
-- within it ("" for itself).
function W:watch(dir, prefix)
    local path = prefix == "" and dir or (dir .. "/" .. prefix)
    local wd = ffi.C.inotify_add_watch(self.fd, path, MASK)
    if wd < 0 then return false end
    if not self.wds[wd] then self.watches = self.watches + 1 end
    self.wds[wd] = { dir = dir, prefix = prefix }
    return true
end
-- }}}

-- {{{ function W:add
-- Watches DIR and every folder under it.
function W:add(dir)
    if self.seen[dir] then return end
    if not self:watch(dir, "") then
        error("inotify: can't watch " .. dir .. " (errno " .. ffi.errno() .. ")", 2)
    end
    self.seen[dir] = true
    self.dirs[#self.dirs + 1] = dir
    for _, sub in ipairs(find(dir, "d")) do self:watch(dir, sub) end
end
-- }}}

-- {{{ function W:changes
-- What the kernel reported since the last call, in the order it came;
-- reads without waiting.
function W:changes()
    local out, overflow = {}, false
    if not self.fd then return out end
    while true do
        local n = tonumber(ffi.C.read(self.fd, self.buf, BUFSIZE))
        if n <= 0 then
            -- EAGAIN: nothing more queued; anything else: stop reading too
            break
        end
        local off = 0
        while off + HEAD <= n do
            local ev = ffi.cast("struct wcx_inotify_event *", self.buf + off)
            local mask, len, wd = ev.mask, ev.len, ev.wd
            local name = len > 0 and ffi.string(self.buf + off + HEAD) or ""
            off = off + HEAD + len
            local w = self.wds[wd]
            if bit.band(mask, inotify.IN_Q_OVERFLOW) ~= 0 then
                overflow = true
            elseif bit.band(mask, inotify.IN_IGNORED) ~= 0 then
                if w then self.wds[wd] = nil; self.watches = self.watches - 1 end
            elseif w and name ~= "" then
                local rel = join(w.prefix, name)
                local gone = bit.band(mask, bit.bor(inotify.IN_DELETE, inotify.IN_MOVED_FROM)) ~= 0
                if bit.band(mask, inotify.IN_ISDIR) ~= 0 then
                    if not gone then
                        -- a new folder: watch it and what is under it, and
                        -- report the files already there (made before the watch)
                        self:watch(w.dir, rel)
                        local root = w.dir .. "/" .. rel
                        for _, sub in ipairs(find(root, "d")) do self:watch(w.dir, rel .. "/" .. sub) end
                        for _, f in ipairs(find(root, "f")) do
                            out[#out + 1] = { dir = w.dir, rel = rel .. "/" .. f, gone = false }
                        end
                    end
                else
                    out[#out + 1] = { dir = w.dir, rel = rel, gone = gone }
                end
            end
        end
    end
    if overflow then
        out = {}
        for _, dir in ipairs(self.dirs) do
            for _, sub in ipairs(find(dir, "d")) do self:watch(dir, sub) end
            for _, f in ipairs(find(dir, "f")) do out[#out + 1] = { dir = dir, rel = f, gone = false } end
        end
    end
    return out
end
-- }}}

-- {{{ function W:close
function W:close()
    if self.fd then
        ffi.C.close(self.fd)
        self.fd = nil
    end
    self.wds, self.dirs, self.seen, self.watches = {}, {}, {}, 0
end
-- }}}

return inotify
