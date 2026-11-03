-- supcom-derivative-clone — a factory war on dunes where nothing is out of range
-- Copyright (C) 2026 gabrilend
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU Affero General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at
-- your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
-- General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program. If not, see <https://www.gnu.org/licenses/>.
--
-- SPDX-License-Identifier: AGPL-3.0-or-later

-- 032-timers.lua
--
-- Every periodic effect, as a counter and a pair of integers.
--
-- The vision's healing rule, stated once so every periodic thing in the game can
-- point at it. A **counter** is one global countdown: a period in ticks, how many
-- times it has fired (its increment), and the tick it fires next. It never walks
-- anything. A thing subject to the effect stores two integers -- a value, and the
-- increment the value was written at -- and its current value is derived when
-- somebody asks:
--
--     current = min(cap, value + (increment_now - written_at))
--
-- A thousand tanks healing costs what one tank healing costs, which is nothing
-- until it is looked at. Every function here is a pure function of its
-- arguments except `advance`, which moves the one counter it is handed.

local M = {}

-- {{{ local function whole()
-- Refuses anything that is not a whole number, naming what it was for.
local function whole(value, what)
  if type(value) ~= "number" or value ~= math.floor(value) then
    error("timers: " .. what .. " is " .. tostring(value) .. ", not a whole number", 3)
  end
end
-- }}}

-- {{{ function M.counter()
-- A fresh counter: it has fired no times and fires first when the tick reaches
-- its period. A period below one tick would fire more than once a tick, which no
-- effect means, so it is refused.
function M.counter(period)
  whole(period, "a counter's period")
  if period < 1 then
    error("timers: a counter's period is " .. period .. ", and must be at least one tick", 2)
  end
  return {period = period, increment = 0, next = period}
end
-- }}}

-- {{{ function M.advance()
-- Brings a counter up to a tick: for every firing the tick has reached, the
-- increment rises by one and the next firing moves on by a period. Asking twice
-- for the same tick changes nothing the second time, so a system that needs the
-- increment of now can bring the counter up itself without disturbing the tick
-- that already did.
function M.advance(counter, tick)
  while tick >= counter.next do
    counter.increment = counter.increment + 1
    counter.next = counter.next + counter.period
  end
end
-- }}}

-- {{{ function M.read()
-- The current value of a pair: what was written, plus one for every increment
-- since, held to the cap.
function M.read(value, written_at, counter, cap)
  local current = value + (counter.increment - written_at)
  if current > cap then
    return cap
  end
  return current
end
-- }}}

-- {{{ function M.write()
-- A change from outside -- a shell lands, a shield takes a hit. The current value
-- is derived, the change applied, and the pair handed back stamped with the
-- increment of now; the caller stores both. Nothing holds the value above the
-- cap after a change either, and nothing holds it above zero: a health that goes
-- below zero is the die pass's business, not this one's.
function M.write(value, written_at, counter, cap, change)
  local current = M.read(value, written_at, counter, cap) + change
  if current > cap then
    current = cap
  end
  return current, counter.increment
end
-- }}}

-- {{{ function M.ticks_of()
-- Seconds, as the catalogue writes them, into whole ticks at a given rate,
-- rounded to the nearest tick. A duration that rounds to no ticks at all is
-- refused rather than lifted to one, because an effect that fires every zero
-- ticks is a catalogue mistake, not a fast effect. The tick's own `ticks_of` calls this with
-- the match's rate; it is here so the world can convert a counter's period while
-- it is being allocated, before there is a tick.
function M.ticks_of(seconds, ticks_per_second)
  if type(seconds) ~= "number" or seconds <= 0 then
    error("timers: " .. tostring(seconds) .. " seconds is not a positive number", 2)
  end
  whole(ticks_per_second, "ticks per second")
  local ticks = math.floor(seconds * ticks_per_second + 0.5)
  if ticks < 1 then
    error("timers: " .. seconds .. " seconds is less than half a tick at "
          .. ticks_per_second .. " ticks a second", 2)
  end
  return ticks
end
-- }}}

return M
