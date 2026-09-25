--[[
huffman.lua - MPQ Huffman decompression (compression byte 0x01)

Warcraft III compresses mostly sound (and, in some protected maps, other
files) with an adaptive Huffman code: the decoder starts from one of nine
fixed weight tables, and after every byte it bumps that byte's weight and
rebalances the tree (the Faller-Gallager-Knuth method), so the code tracks
the data as it goes. A byte never seen before is sent as an escape code
followed by the raw byte.

Ported to Lua from StormLib's huff.cpp (decompression only):
  Copyright (c) Ladislav Zezula 1998-2026, and ShadowFlare.
  StormLib is released under the MIT licence; its licence text is kept in
  deps/licenses/stormlib/LICENSE when built by scripts/build-dependencies.sh.
StormLib's "quick link" cache (it remembers the tree position after 7 bits
to decode faster) is left out: it changes speed, not output.

Usage:
  local huffman = require("mpq.huffman")
  local bytes, err = huffman.decompress(data, expected_length)

Issue: issues/completed/113-remaining-mpq-compressions.md
]]

local compat = require("compat")
local band, bor, lshift, rshift = compat.band, compat.bor, compat.lshift, compat.rshift
local unpack = unpack or table.unpack

local M = {}

local DECODE_ERROR = 0x1FF       -- returned by decode_one on a truncated or empty tree
local END_OF_STREAM = 0x100      -- the symbol that ends a sector
local NEW_BYTE = 0x101           -- escape: the next 8 bits are a byte not yet in the tree
local MAX_ITEMS = 515            -- the item pool size StormLib (and Storm) allow

-- {{{ weight tables
-- One table per data type (the first byte of the compressed data picks it).
-- Only the first 256 entries matter; a zero means "not in the starting tree".
-- Each table is written as runs: {value, count} pairs expanded at load, to keep
-- the long zero stretches readable.
local function expand(runs)
    local out, i = {}, 0
    for r = 1, #runs, 2 do
        for _ = 1, runs[r + 1] do
            out[i] = runs[r]
            i = i + 1
        end
    end
    assert(i == 256, "weight table must have 256 entries, has " .. i)
    return out
end

local function literal(list)
    local out = {}
    for i = 1, #list do out[i - 1] = list[i] end
    return out
end

local WEIGHTS = {}
M.WEIGHTS = WEIGHTS  -- exposed so the tables can be checked against the reference source

-- 0: sparse
WEIGHTS[0] = expand({ 0x0A, 1, 0x00, 254, 0x02, 1 })

-- 1: binary
WEIGHTS[1] = literal({
    0x54, 0x16, 0x16, 0x0D, 0x0C, 0x08, 0x06, 0x05, 0x06, 0x05, 0x06, 0x03, 0x04, 0x04, 0x03, 0x05,
    0x0E, 0x0B, 0x14, 0x13, 0x13, 0x09, 0x0B, 0x06, 0x05, 0x04, 0x03, 0x02, 0x03, 0x02, 0x02, 0x02,
    0x0D, 0x07, 0x09, 0x06, 0x06, 0x04, 0x03, 0x02, 0x04, 0x03, 0x03, 0x03, 0x03, 0x03, 0x02, 0x02,
    0x09, 0x06, 0x04, 0x04, 0x04, 0x04, 0x03, 0x02, 0x03, 0x02, 0x02, 0x02, 0x02, 0x03, 0x02, 0x04,
    0x08, 0x03, 0x04, 0x07, 0x09, 0x05, 0x03, 0x03, 0x03, 0x03, 0x02, 0x02, 0x02, 0x03, 0x02, 0x02,
    0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x01, 0x01, 0x01, 0x02, 0x01, 0x02, 0x02,
    0x06, 0x0A, 0x08, 0x08, 0x06, 0x07, 0x04, 0x03, 0x04, 0x04, 0x02, 0x02, 0x04, 0x02, 0x03, 0x03,
    0x04, 0x03, 0x07, 0x07, 0x09, 0x06, 0x04, 0x03, 0x03, 0x02, 0x01, 0x02, 0x02, 0x02, 0x02, 0x02,
    0x0A, 0x02, 0x02, 0x03, 0x02, 0x02, 0x01, 0x01, 0x02, 0x02, 0x02, 0x06, 0x03, 0x05, 0x02, 0x03,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x03, 0x01, 0x01, 0x01,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x04, 0x04, 0x04, 0x07, 0x09, 0x08, 0x0C, 0x02,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x03,
    0x04, 0x01, 0x02, 0x04, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01,
    0x04, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x02, 0x01, 0x01, 0x02, 0x02, 0x02, 0x06, 0x4B,
})

-- 2: text
WEIGHTS[2] = expand({
    0x00, 9, 0x03, 1, 0x27, 1, 0x00, 2, 0x23, 1, 0x00, 18,
    0xFF, 1, 0x01, 7, 0x02, 2, 0x01, 2, 0x06, 1, 0x0E, 1, 0x10, 1, 0x04, 1,
    0x06, 1, 0x08, 1, 0x05, 1, 0x04, 2, 0x03, 2, 0x02, 2, 0x03, 2, 0x01, 2, 0x02, 1, 0x01, 2,
    0x01, 1, 0x04, 1, 0x02, 1, 0x04, 1, 0x02, 3, 0x01, 2, 0x04, 1, 0x01, 2, 0x02, 1, 0x03, 2, 0x02, 1,
    0x03, 1, 0x01, 1, 0x03, 1, 0x06, 1, 0x04, 1, 0x01, 6, 0x02, 1, 0x01, 1, 0x02, 1, 0x01, 2,
    0x01, 1, 0x29, 1, 0x07, 1, 0x16, 1, 0x12, 1, 0x40, 1, 0x0A, 2, 0x11, 1, 0x25, 1, 0x01, 1, 0x03, 1,
    0x17, 1, 0x10, 1, 0x26, 1, 0x2A, 1,
    0x10, 1, 0x01, 1, 0x23, 2, 0x2F, 1, 0x10, 1, 0x06, 1, 0x07, 1, 0x02, 1, 0x09, 1, 0x01, 5, 0x00, 1,
    0x00, 128,
})

-- 3: general
WEIGHTS[3] = literal({
    0xFF, 0x0B, 0x07, 0x05, 0x0B, 0x02, 0x02, 0x02, 0x06, 0x02, 0x02, 0x01, 0x04, 0x02, 0x01, 0x03,
    0x09, 0x01, 0x01, 0x01, 0x03, 0x04, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01,
    0x05, 0x01, 0x01, 0x01, 0x0D, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x01, 0x01, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x01,
    0x0A, 0x04, 0x02, 0x01, 0x06, 0x03, 0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x03, 0x01, 0x01, 0x01,
    0x05, 0x02, 0x03, 0x04, 0x03, 0x03, 0x03, 0x02, 0x01, 0x01, 0x01, 0x02, 0x01, 0x02, 0x03, 0x03,
    0x01, 0x03, 0x01, 0x01, 0x02, 0x05, 0x01, 0x01, 0x04, 0x03, 0x05, 0x01, 0x03, 0x01, 0x03, 0x03,
    0x02, 0x01, 0x04, 0x03, 0x0A, 0x06, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x02, 0x01, 0x0A, 0x02, 0x05, 0x01, 0x01, 0x02, 0x07, 0x02, 0x17, 0x01, 0x05, 0x01, 0x01,
    0x0E, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x06, 0x02, 0x01, 0x04, 0x05, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
    0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x07, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x01,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x11,
})

-- 4: 4-bit ADPCM samples
WEIGHTS[4] = expand({
    0xFF, 1, 0xFB, 1, 0x98, 1, 0x9A, 1, 0x84, 1, 0x85, 1, 0x63, 1, 0x64, 1,
    0x3E, 2, 0x22, 2, 0x13, 2, 0x18, 1, 0x17, 1, 0x00, 240,
})

-- 5: 6-bit ADPCM samples
WEIGHTS[5] = expand({
    0xFF, 1, 0xF1, 1, 0x9D, 1, 0x9E, 1, 0x9A, 1, 0x9B, 1, 0x9A, 1, 0x97, 1, 0x93, 2, 0x8C, 1, 0x8E, 1,
    0x86, 1, 0x88, 1, 0x80, 1, 0x82, 1,
    0x7C, 2, 0x72, 1, 0x73, 1, 0x69, 1, 0x6B, 1, 0x5F, 1, 0x60, 1, 0x55, 1, 0x56, 1, 0x4A, 1, 0x4B, 1,
    0x40, 1, 0x41, 1, 0x37, 2,
    0x2F, 2, 0x27, 2, 0x21, 2, 0x1B, 1, 0x1C, 1, 0x17, 2, 0x13, 2, 0x10, 2, 0x0D, 2,
    0x0B, 2, 0x09, 2, 0x08, 2, 0x07, 2, 0x06, 1, 0x05, 2, 0x04, 3, 0x19, 1, 0x18, 1,
    0x00, 192,
})

-- 6: 3-bit stereo
WEIGHTS[6] = expand({
    0xC3, 1, 0xCB, 1, 0xF5, 1, 0x41, 1, 0xFF, 1, 0x7B, 1, 0xF7, 1, 0x21, 1, 0x00, 56,
    0xBF, 1, 0xCC, 1, 0xF2, 1, 0x40, 1, 0xFD, 1, 0x7C, 1, 0xF7, 1, 0x22, 1, 0x00, 56,
    0x7A, 1, 0x46, 1, 0x00, 126,
})

-- 7: 4-bit stereo
WEIGHTS[7] = expand({
    0xC3, 1, 0xD9, 1, 0xEF, 1, 0x3D, 1, 0xF9, 1, 0x7C, 1, 0xE9, 1, 0x1E, 1,
    0xFD, 1, 0xAB, 1, 0xF1, 1, 0x2C, 1, 0xFC, 1, 0x5B, 1, 0xFE, 1, 0x17, 1, 0x00, 48,
    0xBD, 1, 0xD9, 1, 0xEC, 1, 0x3D, 1, 0xF5, 1, 0x7D, 1, 0xE8, 1, 0x1D, 1,
    0xFB, 1, 0xAE, 1, 0xF0, 1, 0x2C, 1, 0xFB, 1, 0x5C, 1, 0xFF, 1, 0x18, 1, 0x00, 48,
    0x70, 1, 0x6C, 1, 0x00, 126,
})

-- 8: 5-bit stereo
WEIGHTS[8] = expand({
    0xBA, 1, 0xC5, 1, 0xDA, 1, 0x33, 1, 0xE3, 1, 0x6D, 1, 0xD8, 1, 0x18, 1,
    0xE5, 1, 0x94, 1, 0xDA, 1, 0x23, 1, 0xDF, 1, 0x4A, 1, 0xD1, 1, 0x10, 1,
    0xEE, 1, 0xAF, 1, 0xE4, 1, 0x2C, 1, 0xEA, 1, 0x5A, 1, 0xDE, 1, 0x15, 1,
    0xF4, 1, 0x87, 1, 0xE9, 1, 0x21, 1, 0xF6, 1, 0x43, 1, 0xFC, 1, 0x12, 1, 0x00, 32,
    0xB0, 1, 0xC7, 1, 0xD8, 1, 0x33, 1, 0xE3, 1, 0x6B, 1, 0xD6, 1, 0x18, 1,
    0xE7, 1, 0x95, 1, 0xD8, 1, 0x23, 1, 0xDB, 1, 0x49, 1, 0xD0, 1, 0x11, 1,
    0xE9, 1, 0xB2, 1, 0xE2, 1, 0x2B, 1, 0xE8, 1, 0x5C, 1, 0xDD, 1, 0x15, 1,
    0xF1, 1, 0x87, 1, 0xE7, 1, 0x20, 1, 0xF7, 1, 0x44, 1, 0xFF, 1, 0x13, 1, 0x00, 32,
    0x5F, 1, 0x9E, 1, 0x00, 126,
})
-- }}}

-- {{{ weight-sorted list
-- Every tree item also sits in one circular list sorted by weight. The head
-- is a sentinel: head.next is the heaviest item (the root), head.prev the
-- lightest. item.prev points toward heavier items, item.next toward lighter.

-- {{{ local function remove_item
local function remove_item(item)
    if item.next ~= nil then
        item.prev.next = item.next
        item.next.prev = item.prev
        item.next = nil
        item.prev = nil
    end
end
-- }}}

-- {{{ local function link_two
-- Puts item2 directly after item1 in the list.
local function link_two(item1, item2)
    item2.next = item1.next
    item2.prev = item1.next.prev
    item1.next.prev = item2
    item1.next = item2
end
-- }}}

-- {{{ local function find_higher_or_equal
-- From item, walks toward heavier items and returns the first whose weight is
-- at least `weight`, or the head if none.
local function find_higher_or_equal(tree, item, weight)
    local head = tree.head
    if item ~= nil then
        while item ~= head do
            if item.weight >= weight then
                return item
            end
            item = item.prev
        end
    end
    return head
end
-- }}}
-- }}}

-- {{{ local function create_item
-- Takes a new item from the pool and puts it at the front ("after" the head)
-- or back ("before" the head) of the list. Returns nil when the pool is full.
local function create_item(tree, value, weight, at_front)
    if tree.used >= MAX_ITEMS then
        return nil
    end
    tree.used = tree.used + 1
    local item = { value = value, weight = weight, parent = nil, child_lo = nil }
    if at_front then
        link_two(tree.head, item)
    else
        link_two(tree.head.prev, item)
    end
    return item
end
-- }}}

-- {{{ local function fixup_position
-- Moves a new item to its place by weight. Returns the heaviest weight seen so
-- far (items at or above it stay where they are).
local function fixup_position(tree, item, max_weight)
    if item.weight < max_weight then
        local higher = find_higher_or_equal(tree, tree.head.prev, item.weight)
        remove_item(item)
        link_two(higher, item)
        return max_weight
    end
    return item.weight
end
-- }}}

-- {{{ local function build_tree
-- Builds the starting tree for a data type from its weight table, plus the two
-- control symbols (end of stream, new byte), then pairs the lightest items
-- into parents until one root remains.
local function build_tree(tree, data_type)
    data_type = band(data_type, 0x0F)
    local weights = WEIGHTS[data_type]
    if not weights then
        return false
    end
    local max_weight = 0
    for byte = 0, 255 do
        if weights[byte] ~= 0 then
            local item = create_item(tree, byte, weights[byte], true)
            tree.by_byte[byte] = item
            max_weight = fixup_position(tree, item, max_weight)
        end
    end
    tree.by_byte[END_OF_STREAM] = create_item(tree, END_OF_STREAM, 1, false)
    tree.by_byte[NEW_BYTE] = create_item(tree, NEW_BYTE, 1, false)

    local head = tree.head
    local child_lo = head.prev
    while child_lo ~= head do
        local child_hi = child_lo.prev
        if child_hi == head then
            break
        end
        local parent = create_item(tree, 0, child_hi.weight + child_lo.weight, true)
        if parent == nil then
            return false
        end
        child_lo.parent = parent
        child_hi.parent = parent
        parent.child_lo = child_lo
        max_weight = fixup_position(tree, parent, max_weight)
        child_lo = child_hi.prev
    end
    return true
end
-- }}}

-- {{{ local function increment_and_rebalance
-- Adds one to the weight of item and of every ancestor. Whenever that makes an
-- item heavier than the one ahead of it in the list, the two swap places, in
-- the list and in the tree, so parents stay heavier than their children.
local function increment_and_rebalance(tree, item)
    while item ~= nil do
        item.weight = item.weight + 1
        local higher = find_higher_or_equal(tree, item.prev, item.weight)
        local child_hi = higher.next
        if child_hi ~= item then
            remove_item(child_hi)
            link_two(item, child_hi)
            remove_item(item)
            link_two(higher, item)

            local child_lo = child_hi.parent.child_lo
            local parent = item.parent
            if parent.child_lo == item then
                parent.child_lo = child_hi
            end
            if child_lo == child_hi then
                child_hi.parent.child_lo = item
            end
            parent = item.parent
            item.parent = child_hi.parent
            child_hi.parent = parent
        end
        item = item.parent
    end
end
-- }}}

-- {{{ local function insert_new_branch
-- Adds a never-seen byte: the lightest leaf becomes a parent of itself (value1)
-- and the new byte (value2, weight 0), then the new leaf's weight is raised.
local function insert_new_branch(tree, value1, value2)
    local last = tree.head.prev
    local child_hi = create_item(tree, value1, last.weight, false)
    if child_hi == nil then
        return false
    end
    child_hi.parent = last
    tree.by_byte[value1] = child_hi

    local child_lo = create_item(tree, value2, 0, false)
    if child_lo == nil then
        return false
    end
    child_lo.parent = last
    last.child_lo = child_lo
    tree.by_byte[value2] = child_lo
    increment_and_rebalance(tree, child_lo)
    return true
end
-- }}}

-- {{{ bit stream
-- Bits are read lowest-first from each byte.

-- {{{ local function new_stream
local function new_stream(data)
    return { data = data, pos = 1, len = #data, bits = 0, count = 0 }
end
-- }}}

-- {{{ local function get_bit
local function get_bit(s)
    if s.count == 0 then
        if s.pos > s.len then return nil end
        s.bits = s.data:byte(s.pos)
        s.pos = s.pos + 1
        s.count = 8
    end
    local bit = band(s.bits, 1)
    s.bits = rshift(s.bits, 1)
    s.count = s.count - 1
    return bit
end
-- }}}

-- {{{ local function get_byte
local function get_byte(s)
    if s.count < 8 then
        if s.pos > s.len then return nil end
        s.bits = bor(s.bits, lshift(s.data:byte(s.pos), s.count))
        s.pos = s.pos + 1
        s.count = s.count + 8
    end
    local value = band(s.bits, 0xFF)
    s.bits = rshift(s.bits, 8)
    s.count = s.count - 8
    return value
end
-- }}}
-- }}}

-- {{{ local function decode_one
-- Walks from the root to a leaf: a 1 bit takes the heavier child, a 0 bit the
-- lighter one.
local function decode_one(tree, s)
    local head = tree.head
    if head.next == head then
        return DECODE_ERROR
    end
    local item = head.next
    while item.child_lo ~= nil do
        local bit = get_bit(s)
        if bit == nil then
            return DECODE_ERROR
        end
        if bit == 1 then
            item = item.child_lo.prev
        else
            item = item.child_lo
        end
    end
    return item.value
end
-- }}}

-- {{{ function M.decompress
-- data: the compressed bytes (after the MPQ compression byte).
-- expected_length: the most bytes to produce (the sector's size).
-- Returns the decompressed bytes, or nil and an error message.
function M.decompress(data, expected_length)
    if expected_length == 0 then
        return nil, "Huffman: zero output length"
    end
    local s = new_stream(data)
    local data_type = get_byte(s)
    if data_type == nil then
        return nil, "Huffman: empty input"
    end

    local head = {}
    head.next = head
    head.prev = head
    local tree = { head = head, used = 0, by_byte = {} }
    if not build_tree(tree, data_type) then
        return nil, string.format("Huffman: unknown data type 0x%02X", data_type)
    end
    -- Type 0 ("sparse") raises weights after output instead of on insertion.
    local sparse = (data_type == 0)

    local out, n = {}, 0
    while true do
        local value = decode_one(tree, s)
        if value == END_OF_STREAM then
            break
        end
        if value == DECODE_ERROR then
            return nil, "Huffman: data ended before the end-of-stream code"
        end
        if value == NEW_BYTE then
            value = get_byte(s)
            if value == nil then
                return nil, "Huffman: data ended inside a new byte"
            end
            if not insert_new_branch(tree, head.prev.value, value) then
                return nil, "Huffman: tree grew past its limit"
            end
            if not sparse then
                increment_and_rebalance(tree, tree.by_byte[value])
            end
        end
        if n >= expected_length then
            break
        end
        n = n + 1
        out[n] = value
        if sparse then
            increment_and_rebalance(tree, tree.by_byte[value])
        end
    end

    if n == 0 then
        return nil, "Huffman: produced no data"
    end
    -- string.char takes a limited number of arguments, so build in chunks.
    local parts = {}
    for i = 1, n, 4096 do
        parts[#parts + 1] = string.char(unpack(out, i, math.min(i + 4095, n)))
    end
    return table.concat(parts)
end
-- }}}

return M
