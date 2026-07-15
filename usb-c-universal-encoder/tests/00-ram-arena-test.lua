-- 00-ram-arena-test.lua
--
-- Exercises the RAM arena: direct byte round-trips, bounds enforcement, the
-- region allocator's reuse of freed spans, resize behavior, and proof that the
-- arena is backed by a real, distinct memory address. Tests are cheap; this one
-- runs on every build so a regression in the ground-floor memory layer is caught
-- before anything above it is even loaded.
--
-- Run: luajit tests/00-ram-arena-test.lua   (paths resolve from the project root)

local arena_module = require("src.00-ram-arena")

local passed = 0

-- {{{ local function ok()
local function ok(condition, label)
    if not condition then
        error("FAIL: " .. label)
    end
    passed = passed + 1
    print("  ok - " .. label)
end
-- }}}

-- {{{ local function raises()
-- True when calling `fn` errors, so we can assert that bad accesses are refused
-- rather than silently tolerated.
local function raises(fn)
    local ok_call = pcall(fn)
    return not ok_call
end
-- }}}

print("ram-arena:")

-- Direct byte round-trip: what we poke in is what we read back.
local a = arena_module.new_arena(1024)
a.write_bytes(0, "hello")
ok(a.read_bytes(0, 5) == "hello", "bytes written at offset 0 read back")
a.write_bytes(100, "world")
ok(a.read_bytes(100, 5) == "world", "bytes written at offset 100 read back")

-- Binary-safe: embedded NUL bytes survive the round-trip.
local binary = string.char(0, 1, 2, 255, 0, 128)
a.write_bytes(200, binary)
ok(a.read_bytes(200, #binary) == binary, "binary payload (with NULs) round-trips")

-- Bounds are enforced, not clamped.
ok(raises(function() a.read_bytes(1020, 10) end), "read past capacity raises")
ok(raises(function() a.write_bytes(1024, "x") end), "write at capacity raises")
ok(raises(function() a.read_bytes(-1, 4) end), "negative offset raises")

-- Real memory: base address is a nonzero integer, and two arenas differ.
ok(a.base_address() ~= 0, "arena reports a nonzero base address")
local b = arena_module.new_arena(1024)
ok(a.base_address() ~= b.base_address(), "two arenas occupy different addresses")

-- Region allocator: bump, then reuse a freed span (first-fit).
local small = arena_module.new_arena(64)
local o1 = small.allocate(16)
local o2 = small.allocate(16)
ok(o1 == 0 and o2 == 16, "sequential allocations bump upward")
small.free(o1, 16)
local o3 = small.allocate(16)
ok(o3 == o1, "freed span is reused by the next fitting allocation")

-- Out-of-memory is an error, not a silent nil.
ok(raises(function() small.allocate(1000) end), "over-capacity allocation raises")

-- Resize: shrink keeps offset; grow relocates and preserves bytes.
local r = arena_module.new_arena(256)
local ro = r.allocate(10)
r.write_bytes(ro, "0123456789")
local ro_shrunk = r.resize(ro, 10, 4)
ok(ro_shrunk == ro, "shrink keeps the same offset")
ok(r.read_bytes(ro, 4) == "0123", "shrunk region keeps its surviving bytes")
local ro_grown = r.resize(ro, 4, 32)
ok(r.read_bytes(ro_grown, 4) == "0123", "grown region preserves bytes after relocation")

-- Stats reflect usage rather than being guessed.
local s = r.stats()
ok(s.capacity == 256 and s.used <= s.capacity, "stats report consistent capacity/used")

print(string.format("ram-arena: %d checks passed", passed))
