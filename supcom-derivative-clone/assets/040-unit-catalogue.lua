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

-- 040-unit-catalogue.lua
--
-- Every number that describes a kind of unit, one row per kind.
--
-- A catalogue table, keyed by the kind's name, every field a number or a name
-- and nothing else -- no functions, no nested tables -- so it reads as data and
-- diffs as data. The units module loads it once, validates every row, and
-- converts every time written here in seconds into ticks; nothing reads this
-- table raw except that loader and the tests that assert its relations.
--
-- The design is the relations, not the magnitudes: a tank dies in four of its
-- own shells, an anti-air gun in three, a command truck in one, an enforcer in
-- six with a shield of four more; a helicopter in two and a frigate in eight
-- (open question B2's working ruling). What a shell is worth is this table's
-- business. Changing a number here changes a match, so it is a balance change:
-- append it to docs/balance-updates.md with the reason.
--
-- Fields, one meaning each (the companion has the full table):
--   index           -- the kind's integer, which a unit row's `kind` holds
--   name            -- the kind's name, the key it is filed under
--   domain          -- 1 land, 2 air, 3 sea
--   reaches         -- the domains its weapon may target, as bits: 1 land, 2 air, 4 sea
--   tier            -- 1, 2, or 3 for experimental
--   health          -- the heal cap
--   damage          -- per shot, at full strength; zero for a kind with no weapon
--   falloff         -- the name of its falloff curve's shape, a row of the
--                      targeting module's FALLOFF: "linear-to-floor" or "flat"
--   team_sight      -- 1 when it fires at what any unit of its team sees, rather
--                      than at what it sees itself (the artillery); 0 otherwise
--   falloff_full    -- cells out to which damage is full
--   falloff_floor   -- the fraction of damage it never falls below
--   falloff_end     -- cells out to which damage declines in a straight line to
--                      the floor; beyond it, the floor
--   shell_speed     -- cells per tick; decides the arrival tick
--   reload_seconds  -- between shots
--   heal_period     -- seconds between one point of health coming back
--   speed           -- cells per tick on flat ground
--   climb           -- how much a rise slows it: a step up a rise of r per cell
--                      is its speed over (1 + climb * r); downhill is never faster
--   eye, profile    -- how high it looks from, how tall it looks
--   altitude        -- flight height above the ground; zero for land and sea
--   claim_radius    -- cells of territory it claims; zero claims nothing
--   shield          -- the enforcer's sphere; zero elsewhere
--   shield_seconds  -- the sphere's recharge period; zero where there is none
--   cost_mass, cost_energy -- the construction stream's totals
--   build_seconds   -- how long the stream runs at unit build power

return {
  tank = {
    index = 1, name = "tank", domain = 1, reaches = 5, tier = 1,
    falloff = "linear-to-floor", team_sight = 0,
    health = 100, damage = 25, falloff_full = 16, falloff_floor = 0.25, falloff_end = 48,
    shell_speed = 2, reload_seconds = 3, heal_period = 1,
    speed = 0.2, climb = 0.5, eye = 1.5, profile = 2, altitude = 0, claim_radius = 2,
    shield = 0, shield_seconds = 0, cost_mass = 100, cost_energy = 10, build_seconds = 6,
  },
  ["anti-air"] = {
    index = 2, name = "anti-air", domain = 1, reaches = 2, tier = 1,
    falloff = "linear-to-floor", team_sight = 0,
    health = 75, damage = 20, falloff_full = 24, falloff_floor = 0.5, falloff_end = 64,
    shell_speed = 4, reload_seconds = 1.5, heal_period = 1.2,
    speed = 0.15, climb = 0.5, eye = 1.5, profile = 1.5, altitude = 0, claim_radius = 2,
    shield = 0, shield_seconds = 0, cost_mass = 40, cost_energy = 40, build_seconds = 6,
  },
  helicopter = {
    index = 3, name = "helicopter", domain = 2, reaches = 5, tier = 1,
    falloff = "linear-to-floor", team_sight = 0,
    health = 50, damage = 15, falloff_full = 8, falloff_floor = 0.25, falloff_end = 24,
    shell_speed = 3, reload_seconds = 2, heal_period = 0.8,
    speed = 0.6, climb = 0, eye = 1, profile = 1, altitude = 8, claim_radius = 0,
    shield = 0, shield_seconds = 0, cost_mass = 5, cost_energy = 50, build_seconds = 5,
  },
  frigate = {
    index = 4, name = "frigate", domain = 3, reaches = 5, tier = 1,
    falloff = "linear-to-floor", team_sight = 0,
    health = 200, damage = 30, falloff_full = 20, falloff_floor = 0.25, falloff_end = 56,
    shell_speed = 2, reload_seconds = 4, heal_period = 1.5,
    speed = 0.15, climb = 0, eye = 3, profile = 3, altitude = 0, claim_radius = 2,
    shield = 0, shield_seconds = 0, cost_mass = 80, cost_energy = 80, build_seconds = 12,
  },
  ["command-truck"] = {
    index = 5, name = "command-truck", domain = 1, reaches = 0, tier = 1,
    falloff = "linear-to-floor", team_sight = 0,
    health = 25, damage = 0, falloff_full = 0, falloff_floor = 0, falloff_end = 0,
    shell_speed = 0, reload_seconds = 0, heal_period = 2,
    speed = 0.25, climb = 0.5, eye = 1.5, profile = 1.5, altitude = 0, claim_radius = 2,
    shield = 0, shield_seconds = 0, cost_mass = 0, cost_energy = 0, build_seconds = 0,
  },
  enforcer = {
    index = 6, name = "enforcer", domain = 1, reaches = 5, tier = 2,
    falloff = "linear-to-floor", team_sight = 0,
    health = 150, damage = 60, falloff_full = 20, falloff_floor = 0.3, falloff_end = 60,
    shell_speed = 2, reload_seconds = 4, heal_period = 0.5,
    speed = 0.1, climb = 0.3, eye = 5, profile = 6, altitude = 0, claim_radius = 4,
    shield = 100, shield_seconds = 0.5, cost_mass = 500, cost_energy = 50, build_seconds = 30,
  },
  -- The first experimental (issue 502; issue 501 owns the experimentals as a
  -- whole). It maximises range: its shells lose nothing to distance, the
  -- slowest in the catalogue, and it fires at what any unit of its team sees.
  artillery = {
    index = 7, name = "artillery", domain = 1, reaches = 5, tier = 3,
    falloff = "flat", team_sight = 1,
    health = 400, damage = 80, falloff_full = 0, falloff_floor = 1, falloff_end = 0,
    shell_speed = 0.5, reload_seconds = 8, heal_period = 3,
    speed = 0.05, climb = 0.5, eye = 2, profile = 3, altitude = 0, claim_radius = 2,
    shield = 0, shield_seconds = 0, cost_mass = 10000, cost_energy = 1000, build_seconds = 120,
  },
}
