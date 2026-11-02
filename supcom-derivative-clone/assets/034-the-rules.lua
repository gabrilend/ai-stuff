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

-- 034-the-rules.lua
--
-- The match's rules that are not a unit's: the beat, the claim, the sizes of the
-- queues.
--
-- A catalogue table, read once when a world is allocated and copied into it as
-- `world.rule`. Seconds are written here because a person tunes in seconds; they
-- become ticks once, through the tick's `ticks_of`, and no rule reads a clock.
-- Changing a number here changes a match, so it is a balance change: append it to
-- docs/balance-updates.md with the reason.

return {
  -- Open question B4's working ruling: often enough that a shell's flight is
  -- several beats, rarely enough that ten thousand matches overnight is real.
  ticks_per_second = 10,

  -- Open question B6's working ruling: a claim completes after a small number of
  -- claim increments of uninterrupted presence, within two cells of a unit. The
  -- claim counter fires once a claim_seconds; an enforcer's larger radius is its
  -- own catalogue row's business.
  claim_seconds = 1,
  claim_increments = 3,
  claim_radius = 2,

  -- How many commands may wait in the queue at once, and how many refusals the
  -- ring keeps for a viewer to show. These are sizes, not balance: a full queue
  -- is a refusal, never a resize, so they are set well above what a match sends.
  commands = 256,
  refusals = 16,

  -- The most units a match the headless runner plays may hold at once. A test
  -- that allocates its own world names its own; this is the runner's.
  units = 1024,

  -- How often the world is fingerprinted, in ticks; the replay log writes every
  -- fingerprint. A fingerprint folds every cell, so taking one every tick cost
  -- a tenth of a millisecond on a small field and grows with the field's area;
  -- one a second still names the second a match went wrong in.
  fingerprint_every = 10,
}
