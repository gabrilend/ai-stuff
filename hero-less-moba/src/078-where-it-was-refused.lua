-- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

-- 078-where-it-was-refused.lua
--
-- Where a refusal is shown: beside the place the refused thing was attempted, rather
-- than in a corner (issue 704, step 4).
--
-- A refusal is the game's only manual. A player learns that nothing can be placed
-- during a surge by being told so **at the moment and in the place they tried**, with
-- their eyes still on the thing they were trying to do. Read off the bottom of the
-- panel a second later, the same sentence is about something they have already
-- stopped looking at.
--
-- ## Pure, and the viewer's own
--
-- This is the viewer's bookkeeping, not the simulation's: it remembers where on the
-- screen or the map each of this player's commands was made, and when a refusal comes
-- back it is shown there. Nothing here is read by the simulation, nothing here calls
-- LÖVE, and so all of it can be tested headless. The panel draws what it returns.
--
-- ## How a refusal finds its place
--
-- The command queue numbers every command as it arrives, and the refusal it raises
-- carries that number back. A command is applied at the top of the next tick, so once
-- a tick has run, **every attempt made before it has either been refused or been
-- accepted** and the book of attempts is emptied. Nothing is matched by guesswork:
-- the same player and the same arrival number is the same command.

local M = {}

-- {{{ M.settings
-- **Every number here is chosen by Claude, open for Ritz.** None of them has been
-- looked at on screen.
M.settings = {
  -- Seconds a refusal stays beside its place. The same six the corner list has always
  -- used: long enough to read a sentence without looking away, and one number fewer
  -- for anybody to wonder about.
  lifetime = 6.0,
  -- The most shown at once. Older ones go first. A player refused five times in six
  -- seconds is being told the same thing, and a sixth line would be wallpaper.
  most = 4,
  -- How far above the point the newest line sits, in screen pixels, so that it is
  -- read beside the cursor rather than underneath it.
  lift = 22,
  -- The height of one line of a sentence, in screen pixels.
  line = 15,
  -- How wide a sentence may be before it wraps onto a second line, in screen pixels.
  width = 280,
  -- How close two places must be to stack rather than overlap: in world units for a
  -- place on the map, in screen pixels for a place on the panel. A refused drop and a
  -- second try a pace away are one place.
  crowd_world = 40,
  crowd_screen = 60,
}
-- }}}

-- {{{ function M.create()
-- An empty book: no attempts waiting, nothing shown.
function M.create()
  return {attempt = {}, shown = {}}
end
-- }}}

-- {{{ function M.attempted()
-- Remembers where a command was made. `place` is `{space = "world" | "screen", x, y}`:
-- the map is remembered in world units, so that a refusal stays on the ground it was
-- about while the camera moves -- and it does move, back to wherever it was, the moment
-- a stone is dropped. The panel does not move, so it is remembered in pixels.
function M.attempted(book, command, place)
  if command.arrival == nil then
    error("an attempt is remembered after it is queued, when it has an arrival number")
  end
  if place.space ~= "world" and place.space ~= "screen" then
    error("a place is on the world or on the screen, not " .. tostring(place.space))
  end
  book.attempt[#book.attempt + 1] = {
    player = command.player, arrival = command.arrival, verb = command.verb,
    space = place.space, x = place.x, y = place.y,
  }
end
-- }}}

-- {{{ function M.show()
-- Puts a sentence at a place, now. Used for the refusals the input layer makes itself
-- -- a drop it can already tell means nothing -- as well as the simulation's.
function M.show(book, text, place, now)
  table.insert(book.shown, 1, {text = text, space = place.space, x = place.x,
                               y = place.y, born = now})
  while #book.shown > M.settings.most do
    table.remove(book.shown)
  end
end
-- }}}

-- {{{ function M.settle()
-- After a tick: each of `player`'s refusals in `events` goes to the place its command
-- was made. Returns the refusals that had no place -- anybody else's, or a command
-- this viewer did not make -- for the corner list, which still hears everything it
-- always did. Then the book of attempts is emptied, because the tick has answered
-- every one of them.
function M.settle(book, events, player, now)
  local elsewhere = {}
  for _, event in ipairs(events) do
    if event.name == "refused" then
      local found = nil
      if event.player == player then
        for _, attempt in ipairs(book.attempt) do
          if attempt.player == player and attempt.arrival == event.arrival then
            found = attempt
            break
          end
        end
      end
      if found ~= nil then
        if found.verb ~= event.verb then
          -- The same player and the same arrival number is the same command. If the
          -- verbs differ, the numbering is broken, and showing a sentence beside the
          -- wrong thing would teach the wrong rule.
          error(string.format("refusal of %s matched an attempt at %s", event.verb,
                              found.verb))
        end
        M.show(book, event.reason, found, now)
      else
        elsewhere[#elsewhere + 1] = event.reason
      end
    end
  end
  book.attempt = {}
  return elsewhere
end
-- }}}

-- {{{ function M.current()
-- What is showing now, newest first, with how faded each is (0 just made, 1 gone) and
-- which newer ones are close enough to its place that it is stacked above them, as
-- indices into the same list. Indices rather than a count, because a sentence that
-- wraps is taller than one line and only the drawing knows how tall. Forgets whatever
-- has lasted.
function M.current(book, now)
  local settings = M.settings
  for index = #book.shown, 1, -1 do
    if now - book.shown[index].born > settings.lifetime then
      table.remove(book.shown, index)
    end
  end

  local result = {}
  for index, entry in ipairs(book.shown) do
    local crowd = (entry.space == "world") and settings.crowd_world or settings.crowd_screen
    local newer_nearby = {}
    for newer = 1, index - 1 do
      local other = book.shown[newer]
      if other.space == entry.space
          and (other.x - entry.x) ^ 2 + (other.y - entry.y) ^ 2 <= crowd * crowd then
        newer_nearby[#newer_nearby + 1] = newer
      end
    end
    result[index] = {text = entry.text, space = entry.space, x = entry.x, y = entry.y,
                     age = (now - entry.born) / settings.lifetime,
                     newer_nearby = newer_nearby}
  end
  return result
end
-- }}}

return M
