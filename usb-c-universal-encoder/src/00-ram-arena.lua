-- 00-ram-arena.lua
--
-- The RAM arena: the ground floor of the whole system. It hands out a single,
-- real, contiguous block of memory (an actual malloc'd byte buffer via LuaJIT's
-- FFI, not a Lua table pretending to be memory) and lets the layers above poke it
-- directly at byte offsets. A tiny region allocator carves that block into spans
-- that files will later live in. Every access is bounds-checked, so a caller — or
-- a hostile opcode stream far upstream — can never read or write a single byte
-- outside the block we own. This is what makes "everything is a file, stored in
-- RAM" literal and what makes the system portable: give it a block of bytes and it
-- runs, no operating-system filesystem required.

local ffi = require("ffi")

-- {{{ local function new_arena()
-- Build a fresh arena of `capacity` bytes. Returns a table of methods that all
-- close over the same private memory + bookkeeping, so the raw pointer is never
-- exposed except as an integer address for inspection.
local function new_arena(capacity)
    if type(capacity) ~= "number" or capacity < 1 or capacity % 1 ~= 0 then
        error("arena: capacity must be a positive integer, got " .. tostring(capacity))
    end

    -- The real memory. `uint8_t[?]` is a variable-length array; LuaJIT zero-fills
    -- it and garbage-collects it when `buffer` is dropped, so we keep `buffer`
    -- alive on the closure for the arena's whole life.
    local buffer = ffi.new("uint8_t[?]", capacity)

    -- Bump pointer: the high-water mark of memory ever handed out. Everything at or
    -- above `top` is untouched; everything below may be allocated or on free_list.
    local top = 0

    -- Free list of reclaimed spans, each { offset = , size = }. Freed memory lands
    -- here so it can be reused before we grow `top` toward the ceiling.
    local free_list = {}

    -- {{{ local function check_range()
    -- Shared guard for every direct access. We refuse anything that would touch a
    -- byte outside [0, capacity); erroring here is deliberate — a silent clamp
    -- would turn a caller's bug into corrupted data much further away.
    local function check_range(offset, length)
        if type(offset) ~= "number" or offset < 0 or offset % 1 ~= 0 then
            error("arena: offset must be a non-negative integer, got " .. tostring(offset))
        end
        if type(length) ~= "number" or length < 0 or length % 1 ~= 0 then
            error("arena: length must be a non-negative integer, got " .. tostring(length))
        end
        if offset + length > capacity then
            error(string.format(
                "arena: access [%d,%d) exceeds capacity %d", offset, offset + length, capacity))
        end
    end
    -- }}}

    -- {{{ local function write_bytes()
    -- Copy a Lua string straight into the arena at `offset`. This is the direct-RAM
    -- poke: after this call the bytes physically live in our buffer.
    local function write_bytes(offset, data)
        if type(data) ~= "string" then
            error("arena: write_bytes expects a string payload")
        end
        check_range(offset, #data)
        if #data > 0 then
            ffi.copy(buffer + offset, data, #data)
        end
        return #data
    end
    -- }}}

    -- {{{ local function read_bytes()
    -- Read `length` bytes back out of the arena at `offset` as a Lua string.
    local function read_bytes(offset, length)
        check_range(offset, length)
        return ffi.string(buffer + offset, length)
    end
    -- }}}

    -- {{{ local function allocate()
    -- Reserve a span of `size` bytes and return its offset. First-fit over the free
    -- list, because reusing a returned span keeps `top` low and the arena packed;
    -- only when nothing on the free list fits do we bump `top` upward. Running past
    -- capacity is a hard error rather than a silent failure the caller can miss.
    local function allocate(size)
        if type(size) ~= "number" or size < 0 or size % 1 ~= 0 then
            error("arena: allocate size must be a non-negative integer, got " .. tostring(size))
        end

        -- First path: a reclaimed span is big enough. Carve from its front; if any
        -- tail remains it stays on the free list, otherwise the span is consumed.
        for index, span in ipairs(free_list) do
            if span.size >= size then
                local offset = span.offset
                if span.size == size then
                    table.remove(free_list, index)
                else
                    span.offset = span.offset + size
                    span.size = span.size - size
                end
                return offset
            end
        end

        -- Second path: no free span fits, so grow the high-water mark. If that would
        -- cross the ceiling the arena is genuinely full and we say so.
        if top + size > capacity then
            error(string.format(
                "arena: out of memory allocating %d bytes (used %d of %d)",
                size, top, capacity))
        end
        local offset = top
        top = top + size
        return offset
    end
    -- }}}

    -- {{{ local function coalesce_free_list()
    -- Merge adjacent free spans back into single larger ones, and pull `top` back
    -- down when the very top of the arena is free. Without this, repeated
    -- allocate/free of different sizes would shatter memory into unusable slivers.
    local function coalesce_free_list()
        table.sort(free_list, function(a, b) return a.offset < b.offset end)
        local merged = {}
        for _, span in ipairs(free_list) do
            local last = merged[#merged]
            if last and last.offset + last.size == span.offset then
                -- Touching the previous span: extend it rather than keep two.
                last.size = last.size + span.size
            else
                merged[#merged + 1] = { offset = span.offset, size = span.size }
            end
        end
        -- If the final free span runs to the high-water mark, hand it back to the
        -- bump allocator so future allocations do not think the arena is fuller.
        local last = merged[#merged]
        if last and last.offset + last.size == top then
            top = last.offset
            merged[#merged] = nil
        end
        free_list = merged
    end
    -- }}}

    -- {{{ local function free()
    -- Return a previously allocated span to the pool. We do not wipe the bytes;
    -- callers must not read freed memory, and leaving the bytes avoids needless work.
    local function free(offset, size)
        check_range(offset, size)
        if size > 0 then
            free_list[#free_list + 1] = { offset = offset, size = size }
            coalesce_free_list()
        end
    end
    -- }}}

    -- {{{ local function resize()
    -- Change the size of a span. Shrinking frees the tail in place and keeps the
    -- same offset (cheap). Growing has to relocate: we allocate the new span first,
    -- copy the surviving bytes, then free the old one — allocating first guarantees
    -- the allocator cannot hand us back the old span while we are still reading it.
    local function resize(offset, old_size, new_size)
        if new_size <= old_size then
            if new_size < old_size then
                free(offset + new_size, old_size - new_size)
            end
            return offset
        end
        local new_offset = allocate(new_size)
        if old_size > 0 then
            ffi.copy(buffer + new_offset, buffer + offset, old_size)
        end
        free(offset, old_size)
        return new_offset
    end
    -- }}}

    -- {{{ local function base_address()
    -- The real address of byte 0, as an integer, so a human or a test can confirm
    -- this is actual memory. Two arenas will report two different addresses.
    local function base_address()
        return tonumber(ffi.cast("uintptr_t", buffer))
    end
    -- }}}

    -- {{{ local function stats()
    -- A snapshot of usage, so documentation and demos can report live numbers
    -- instead of hardcoding figures that would go stale.
    local function stats()
        local free_below_top = 0
        for _, span in ipairs(free_list) do
            free_below_top = free_below_top + span.size
        end
        local used = top - free_below_top
        return {
            capacity = capacity,
            used = used,
            free = capacity - used,
            high_water = top,
            free_span_count = #free_list,
        }
    end
    -- }}}

    return {
        write_bytes = write_bytes,
        read_bytes = read_bytes,
        allocate = allocate,
        free = free,
        resize = resize,
        base_address = base_address,
        capacity = function() return capacity end,
        stats = stats,
    }
end
-- }}}

return {
    new_arena = new_arena,
}
