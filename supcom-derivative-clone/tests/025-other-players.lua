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

-- 025-other-players.lua
--
-- covers: 701, 702, 703, 704, 705, 706
--
-- Phase 7: two lockstep worlds agree, a missing batch stalls, a bad hash names
-- its tick, the loopback transport.
--
-- There is no wire in these tests. The loopback transport delivers datagrams in
-- order with no network underneath, so every claim here is about the lockstep
-- rules and none is about the room the machines are in. 707 (the handheld's
-- transport) is not claimed: its numbers are pending the sibling project's
-- radio, and a test of a design pending its inputs would be a test of nothing.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."
local harness = loadfile(ROOT .. "/tests/018-the-harness.lua")()
harness.start({...}, "025-other-players")

local SEED = harness.seed()
local FIELD = {size = 64, dune_height = 20, dune_wavelength = 16, roughness = 0.4,
               water_line = 4, hydrocarbon_rate = 0.02}
local DELAY = 5

-- {{{ local function machine()
-- One lockstep machine: a world, a peer name, and a transport end.
local function machine(name, transport)
  local the_tick = harness.load("the-tick", "105")
  local the_world = harness.load("the-world", "104")
  local lockstep = harness.load("lockstep", "701")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  local peer = lockstep.join(world, {name = name, peers = {"left", "right"}, delay = DELAY,
                                     transport = transport, hash_every = 10})
  return {world = world, peer = peer, tick = the_tick, lockstep = lockstep}
end
-- }}}

-- {{{ two worlds agree
harness.suite("two lockstep worlds fed the same batches agree on every hash", function()
  local loopback = harness.load("transport-loopback", "703")
  local snapshot = harness.load("snapshot", "109")
  local wire = loopback.open()
  local left = machine("left", wire:endpoint("left"))
  local right = machine("right", wire:endpoint("right"))
  local disagreed = nil
  for tick = 1, 300 do
    if tick == 20 then
      left.lockstep.issue(left.peer, {verb = "set-energy-level", team = 1, level = 3})
    end
    if tick == 40 then
      right.lockstep.issue(right.peer, {verb = "set-energy-level", team = 2, level = 2})
    end
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
    if left.world.tick == right.world.tick and snapshot.hash(left.world) ~= snapshot.hash(right.world) then
      disagreed = tick
      break
    end
  end
  harness.check("three hundred ticks with commands from both sides never disagreed", disagreed == nil,
                "first at tick " .. tostring(disagreed))
  harness.check("both machines advanced", left.world.tick > 200 and right.world.tick > 200)
  harness.check("a command issued at a tick is applied at tick plus delay",
                left.world.team.energy_level[1] == 3 and right.world.team.energy_level[1] == 3
                and left.world.applied_at["set-energy-level"] == 20 + DELAY)
end)
-- }}}

-- {{{ scheduling
harness.suite("a command for a past tick is refused by name", function()
  local lockstep = harness.load("lockstep", "702")
  local scheduled = lockstep.schedule({verb = "set-energy-level", team = 1, level = 1}, 100, DELAY)
  harness.check("schedule stamps tick plus delay", scheduled.tick == 100 + DELAY)
  local the_world = harness.load("the-world", "104")
  local commands = harness.load("commands", "108")
  local world = the_world.allocate({field = FIELD, units = 256, teams = 2, seed = SEED})
  world.tick = 200
  local refusal = commands.queue(world, scheduled)
  harness.check("the door refuses it and says the tick", type(refusal) == "string"
                and refusal:find(tostring(100 + DELAY), 1, true) ~= nil, refusal)
end)
-- }}}

-- {{{ stalls
harness.suite("a missing batch stalls, and says who it is waiting for", function()
  local loopback = harness.load("transport-loopback", "703")
  local wire = loopback.open()
  local left = machine("left", wire:endpoint("left"))
  local right = machine("right", wire:endpoint("right"))
  for _ = 1, 20 do
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
  end
  local tick_before = left.world.tick
  wire:cut("right")
  for _ = 1, 20 do
    left.lockstep.step(left.peer)
  end
  harness.check("left ran out of right's batches and stopped", left.world.tick <= tick_before + DELAY + 1)
  harness.check("left says who it is waiting for", left.lockstep.waiting_for(left.peer) == "right")
  wire:mend("right")
  for _ = 1, 40 do
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
  end
  harness.check("mended, both machines move again", left.world.tick > tick_before + 20)
end)
-- }}}

-- {{{ the loopback
harness.suite("the loopback transport delivers in order and nothing else", function()
  local loopback = harness.load("transport-loopback", "703")
  local wire = loopback.open()
  local a = wire:endpoint("a")
  local b = wire:endpoint("b")
  a:send("b", "one")
  a:send("b", "two")
  a:send("b", "three")
  local got = {}
  for _ = 1, 3 do
    local from, datagram = b:receive()
    got[#got + 1] = datagram
    harness.check("the sender is named", from == "a")
  end
  harness.check("three datagrams arrived in order", got[1] == "one" and got[2] == "two" and got[3] == "three")
  local from, datagram = b:receive()
  harness.check("an empty inbox returns nothing, not an error", from == nil and datagram == nil)
  from, datagram = a:receive()
  harness.check("a's own datagrams did not come back to a", from == nil)
end)
-- }}}

-- {{{ discovery
harness.suite("machines find each other by announcing on a counter, and age out", function()
  local discovery = harness.load("discovery", "704")
  local loopback = harness.load("transport-loopback", "703")
  local timers = harness.load("timers", "106")
  local wire = loopback.open()
  local a = discovery.new({name = "a", transport = wire:endpoint("a"), seed = SEED, period = 5, age_out = 3})
  local b = discovery.new({name = "b", transport = wire:endpoint("b"), seed = SEED, period = 5, age_out = 3})
  for tick = 1, 12 do
    discovery.announce_pass(a, tick)
    discovery.announce_pass(b, tick)
    discovery.listen_pass(a, tick)
    discovery.listen_pass(b, tick)
  end
  harness.check("a heard b", discovery.heard(a, "b") == true)
  harness.check("b heard a", discovery.heard(b, "a") == true)
  harness.check("the lobby agrees on a seed", discovery.lobby(a).seed == discovery.lobby(b).seed)
  wire:cut("b")
  for tick = 13, 40 do
    discovery.announce_pass(a, tick)
    discovery.listen_pass(a, tick)
  end
  harness.check("a peer that stops announcing ages out", discovery.heard(a, "b") == false)
end)
-- }}}

-- {{{ desyncs
harness.suite("a disagreeing hash halts and names its tick", function()
  local lockstep = harness.load("lockstep", "705")
  local loopback = harness.load("transport-loopback", "703")
  local wire = loopback.open()
  local left = machine("left", wire:endpoint("left"))
  local right = machine("right", wire:endpoint("right"))
  for _ = 1, 30 do
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
  end
  -- Corrupt one world behind the rules' back, which is what a desync is.
  right.world.team.mass[1] = right.world.team.mass[1] + 1
  local halted_at = nil
  for _ = 1, 40 do
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
    if left.lockstep.halted(left.peer) then
      halted_at = left.lockstep.halted(left.peer)
      break
    end
  end
  harness.check("the left machine halted", halted_at ~= nil)
  harness.check("it names a tick after the corruption", type(halted_at) == "number" and halted_at >= 30)
  local written = left.lockstep.evidence(left.peer)
  harness.check("it wrote its evidence to the RAM tier", type(written) == "string"
                and written:find("/shared%-memory/") ~= nil, written)
end)
-- }}}

-- {{{ rejoining
harness.suite("a dropped peer rejoins by replaying the command log", function()
  local loopback = harness.load("transport-loopback", "703")
  local snapshot = harness.load("snapshot", "109")
  local wire = loopback.open()
  local left = machine("left", wire:endpoint("left"))
  local right = machine("right", wire:endpoint("right"))
  for tick = 1, 50 do
    if tick == 10 then left.lockstep.issue(left.peer, {verb = "set-energy-level", team = 1, level = 4}) end
    left.lockstep.step(left.peer)
    right.lockstep.step(right.peer)
  end
  local fresh_right = machine("right", wire:endpoint("right-again"))
  fresh_right.lockstep.rejoin(fresh_right.peer, "left")
  for _ = 1, 200 do
    left.lockstep.step(left.peer)
    fresh_right.lockstep.step(fresh_right.peer)
    if fresh_right.world.tick == left.world.tick then break end
  end
  harness.check("the rejoined machine caught up to the same tick", fresh_right.world.tick == left.world.tick)
  harness.check("and holds the same world", snapshot.hash(fresh_right.world) == snapshot.hash(left.world))
end)
-- }}}

harness.finish()
