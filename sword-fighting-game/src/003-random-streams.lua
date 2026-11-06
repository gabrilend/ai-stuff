-- 003-random-streams.lua
--
-- Named seeded generators: the determinism everything else rests on.
--
-- There is no global generator and nothing reads the clock. Each system draws
-- from its own stream, made from the run's seed and the stream's name, so that
-- changing how often the minds roll cannot change which swings are parried.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

local bit = require("bit")

local M = {}

-- The streams a battle carries. Adding a system that needs chance means adding
-- its name here, so the receipt can report its draws.
M.NAMES = { "movement", "hits", "minds", "ranged", "campaign", "scenery", "perks" }

-- xorshift32 with Marsaglia's triple 13, 17, 5. Changing any of the three
-- silently gives a generator with a far shorter period, so they are not knobs.
local SHIFT_A, SHIFT_B, SHIFT_C = 13, 17, 5

-- Zero is xorshift's fixed point: from it the generator returns zero forever.
-- A seed that hashes to zero is redirected to this odd constant.
local ZERO_ESCAPE = 0x6D2B79F5

local Stream = {}
Stream.__index = Stream

-- FNV-1a over the name's bytes. The FNV prime is 2^24 + 403, so the multiply
-- is done as a shift plus a small multiply: a plain h * prime would pass 2^53
-- and lose its low bits inside a double.
-- {{{ local function hash_name()
local function hash_name(name)
	local h = bit.tobit(2166136261)
	for i = 1, #name do
		h = bit.bxor(h, name:byte(i))
		h = bit.tobit(bit.lshift(h, 24) + h * 403)
	end
	return h
end
-- }}}

-- {{{ function M.new()
function M.new(seed, name)
	local state = bit.bxor(bit.tobit(seed), hash_name(name))
	-- zero would stick forever; any other start is fine
	if state == 0 then state = ZERO_ESCAPE end
	local s = setmetatable({ name = name, state = state, count = 0 }, Stream)
	-- the first few outputs of xorshift from nearby seeds are correlated;
	-- stepping past them makes seeds 1 and 2 give unrelated battles
	for _ = 1, 8 do s:next_raw() end
	s.count = 0
	return s
end
-- }}}

-- The next 31-bit non-negative integer. Everything else is built on this.
-- {{{ function Stream:next_raw()
function Stream:next_raw()
	local x = self.state
	x = bit.bxor(x, bit.lshift(x, SHIFT_A))
	x = bit.bxor(x, bit.rshift(x, SHIFT_B))
	x = bit.bxor(x, bit.lshift(x, SHIFT_C))
	self.state = x
	self.count = self.count + 1
	return bit.band(x, 0x7FFFFFFF)
end
-- }}}

-- A number in [0, 1).
-- {{{ function Stream:float()
function Stream:float()
	return self:next_raw() / 2147483648
end
-- }}}

-- An integer in lo..hi inclusive.
-- {{{ function Stream:between()
function Stream:between(lo, hi)
	return lo + self:next_raw() % (hi - lo + 1)
end
-- }}}

-- {{{ function Stream:chance()
function Stream:chance(p)
	return self:float() < p
end
-- }}}

-- A number in [lo, hi).
-- {{{ function Stream:range()
function Stream:range(lo, hi)
	return lo + (hi - lo) * self:float()
end
-- }}}

-- {{{ function Stream:pick()
function Stream:pick(list)
	return list[self:between(1, #list)]
end
-- }}}

-- Adds a set's draw counts into a name -> count table, for the receipt.
-- {{{ function M.add_draws()
function M.add_draws(total, set)
	for _, name in ipairs(M.NAMES) do total[name] = (total[name] or 0) + set[name].count end
	return total
end
-- }}}

-- Every stream a run uses, keyed by name.
-- {{{ function M.make_set()
function M.make_set(seed)
	local set = {}
	for _, name in ipairs(M.NAMES) do set[name] = M.new(seed, name) end
	return set
end
-- }}}

return M
