--[[
Cache: Loaded Assets, Kept Within a Byte Limit (Issue 601)

A least-recently-used cache charged in bytes. Each entry says what it
costs (a texture: its RGBA bytes; a file kept as bytes: its length); when
a new entry would take the total over the limit, the entries used longest
ago go first. An entry larger than the whole limit is handed back but not
kept.

    local cache = require("assets.cache")
    local c = cache.new(256 * 1024 * 1024)
    c:put(key, value, bytes)
    local v = c:get(key)              -- nil when absent; marks it just used
    c:has(key)                        -- without marking it used
    c:stats()                         -- { count, bytes, limit, hits, misses, evictions }
    c:clear()
]]

local cache = {}

local C = {}
C.__index = C

-- {{{ function cache.new
function cache.new(limit)
    if type(limit) ~= "number" or limit < 0 then
        error("cache: wants a byte limit (0 or more), got " .. tostring(limit), 2)
    end
    -- A doubly linked list, newest at head.next, oldest at head.prev.
    local head = {}
    head.next, head.prev = head, head
    return setmetatable({ limit = limit, head = head, entries = {}, bytes = 0, count = 0,
                          hits = 0, misses = 0, evictions = 0 }, C)
end
-- }}}

-- {{{ list helpers
local function unlink(e)
    e.prev.next, e.next.prev = e.next, e.prev
end

local function push_front(head, e)
    e.next, e.prev = head.next, head
    head.next.prev = e
    head.next = e
end
-- }}}

-- {{{ function C:remove
function C:remove(key)
    local e = self.entries[key]
    if not e then return false end
    unlink(e)
    self.entries[key] = nil
    self.bytes = self.bytes - e.bytes
    self.count = self.count - 1
    return true
end
-- }}}

-- {{{ function C:put
-- Keeps VALUE under KEY, charged BYTES; evicts the oldest entries to fit.
-- Returns true when it was kept.
function C:put(key, value, bytes)
    bytes = bytes or 0
    self:remove(key)
    if bytes > self.limit then
        return false
    end
    while self.bytes + bytes > self.limit do
        local oldest = self.head.prev
        self:remove(oldest.key)
        self.evictions = self.evictions + 1
    end
    local e = { key = key, value = value, bytes = bytes }
    push_front(self.head, e)
    self.entries[key] = e
    self.bytes = self.bytes + bytes
    self.count = self.count + 1
    return true
end
-- }}}

-- {{{ function C:get / C:has
function C:get(key)
    local e = self.entries[key]
    if not e then
        self.misses = self.misses + 1
        return nil
    end
    self.hits = self.hits + 1
    unlink(e)
    push_front(self.head, e)
    return e.value
end

function C:has(key)
    return self.entries[key] ~= nil
end
-- }}}

-- {{{ function C:keys
-- The keys, most recently used first.
function C:keys()
    local out, e = {}, self.head.next
    while e ~= self.head do
        out[#out + 1] = e.key
        e = e.next
    end
    return out
end
-- }}}

-- {{{ function C:stats / C:clear
function C:stats()
    return { count = self.count, bytes = self.bytes, limit = self.limit,
             hits = self.hits, misses = self.misses, evictions = self.evictions }
end

function C:clear()
    self.head.next, self.head.prev = self.head, self.head
    self.entries, self.bytes, self.count = {}, 0, 0
end
-- }}}

return cache
