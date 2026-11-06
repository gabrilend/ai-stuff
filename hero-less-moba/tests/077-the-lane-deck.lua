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

-- 077-the-lane-deck.lua
--
-- covers: 213
--
-- The lane's deck asked directly, wave after wave, without a match around it.
--
-- **Claims 213 for the half of it that is built** -- the four kinds, their kit, the
-- deck, the purse and the meters -- and for the three tests 213 itself asks for: a
-- mixture over a long run, a lane measurably poorer after heavy infantry, and never
-- three of a kind. What upgrades do to a deck, and placing each kind at its own
-- bearing, are not built and nothing here pretends to test them.
--
-- Most checks call the deck the way the spawner does, a few hundred waves at a time,
-- on a world that never ticks. That is a few milliseconds where a match would be
-- minutes, and it isolates the deck from everything a match would put around it.

local ROOT = debug.getinfo(1, "S").source:match("^@(.*)/tests/[^/]+$") or "."

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
  if condition then
    passed = passed + 1
    print(string.format("  ok    %s", name))
  else
    failed = failed + 1
    print(string.format("  FAIL  %s%s", name, detail and ("  --  " .. detail) or ""))
  end
end
-- }}}

local tick_module = loadfile(ROOT .. "/src/042-the-tick.lua")()

-- {{{ local function fresh_world()
local function fresh_world()
  local modules = tick_module.load_cast(ROOT)
  local parameters = modules.match_parameters.load()
  local world = tick_module.assemble(modules, parameters)
  world.bot = {}
  return world, modules, parameters
end
-- }}}

-- {{{ local function many_waves()
-- Draws `count` waves from one lane, taking turns between the commanders the way a
-- team's players do, and hands each wave to `each`.
local function many_waves(world, modules, team, lane, count, each)
  local commanders = world.parameters.commander.commander
  for wave = 1, count do
    local commander = commanders[((wave - 1) % #commanders) + 1]
    local drawn = modules.lane_deck.draw_wave(world, team, lane, commander)
    each(drawn, world.team[team].lane_deck[lane], commander, wave)
  end
end
-- }}}

-- {{{ local function test_the_shuffle()
-- The pile shuffle is exactly the passes the design names, keeps every card, and
-- involves no random number at all.
local function test_the_shuffle()
  local _, modules, parameters = fresh_world()
  local settings = parameters.unit.deck
  local deck = modules.lane_deck

  local cards = {}
  for index = 1, 40 do cards[index] = index end

  local function by_hand(passes)
    local out = cards
    for _, piles in ipairs(passes) do
      local pile = {}
      for k = 1, piles do pile[k] = {} end
      for index, card in ipairs(out) do
        local into = pile[((index - 1) % piles) + 1]
        into[#into + 1] = card
      end
      out = {}
      for k = 1, piles do
        for _, card in ipairs(pile[k]) do out[#out + 1] = card end
      end
    end
    return out
  end

  local function same(a, b)
    if #a ~= #b then return false end
    for index = 1, #a do
      if a[index] ~= b[index] then return false end
    end
    return true
  end

  check("the first shuffle deals three, four, five, four, seven",
        same(deck.pile_shuffle(cards, settings, 0), by_hand({3, 4, 5, 4, 7})))
  check("the next leads with the next odd count, and every other pass is still four",
        same(deck.pile_shuffle(cards, settings, 1), by_hand({5, 4, 7, 4, 3}))
        and same(deck.pile_shuffle(cards, settings, 2), by_hand({7, 4, 3, 4, 5})))

  local shuffled = deck.pile_shuffle(cards, settings, 0)
  local seen, kept = {}, #shuffled == #cards
  for _, card in ipairs(shuffled) do
    if seen[card] then kept = false end
    seen[card] = true
  end
  check("a shuffle keeps every card exactly once", kept)
  check("and moves them", not same(shuffled, cards))
end
-- }}}

-- {{{ local function test_a_mixture_over_a_long_run()
-- 213's first test: over a long run a lane fields a mixture rather than one thing.
local function test_a_mixture_over_a_long_run()
  local world, modules, parameters = fresh_world()
  local entries = parameters.unit.deck.entry
  local total, bodies, waves = {}, 0, 300
  for index = 1, #entries do total[entries[index].archetype] = 0 end

  many_waves(world, modules, 1, 2, waves, function(drawn)
    for _, body in ipairs(drawn) do
      total[body.archetype] = total[body.archetype] + 1
      bodies = bodies + 1
    end
  end)

  local missing, most, most_name = nil, 0, ""
  for _, entry in ipairs(entries) do
    local count = total[entry.archetype]
    local name = parameters.unit.archetype[entry.archetype].name
    if count == 0 then missing = missing or name end
    if count / bodies > most then most, most_name = count / bodies, name end
  end
  check("over three hundred waves a lane fields every kind", missing == nil,
        tostring(missing) .. " never walked out")
  check("and no kind is more than half of everything it fielded", most <= 0.5,
        string.format("%s was %.0f%%", most_name, most * 100))

  local heavy = total[entries[1].archetype] / bodies
  check("heavy infantry is the rarest kind", (function()
          for index = 2, #entries do
            if total[entries[index].archetype] / bodies <= heavy then return false end
          end
          return true
        end)(), string.format("heavy was %.0f%% of what walked out", heavy * 100))
  check("a wave is about the size it was, give or take one",
        bodies / waves >= 4 and bodies / waves <= 7,
        string.format("%.2f bodies a wave beside the captain", bodies / waves))
end
-- }}}

-- {{{ local function test_never_three_of_a_kind()
-- 213's third test, and the caps around it: never three of a kind, never more than
-- the body cap, and never more of a half than the commander's share allows.
local function test_never_three_of_a_kind()
  local world, modules, parameters = fresh_world()
  local settings = parameters.unit.deck
  local archetype = parameters.unit.archetype
  local worst, over_cap, over_share = 0, 0, 0

  for team = 1, 2 do
    for lane = 1, parameters.lane_count do
      many_waves(world, modules, team, lane, 200, function(drawn, _, commander)
        local of_kind, line = {}, 0
        for _, body in ipairs(drawn) do
          of_kind[body.archetype] = (of_kind[body.archetype] or 0) + 1
          if of_kind[body.archetype] > worst then worst = of_kind[body.archetype] end
          if archetype[body.archetype].reach == 1 then line = line + 1 end
        end
        if #drawn > settings.body_cap then over_cap = over_cap + 1 end
        local line_cap = math.floor(settings.body_cap * commander.melee_share + 0.5)
        if line > line_cap or (#drawn - line) > settings.body_cap - line_cap then
          over_share = over_share + 1
        end
      end)
    end
  end
  check("in twelve hundred waves, no wave ever holds three of a kind", worst <= 2,
        "one held " .. worst)
  check("and none is larger than the body cap", over_cap == 0, over_cap .. " were")
  check("and none has more line or more missile than its commander's share allows",
        over_share == 0, over_share .. " did")
end
-- }}}

-- {{{ local function test_heavy_infantry_makes_a_lane_poorer()
-- 213's second test. A lane that has just fielded heavy infantry goes into its next
-- wave with less in its purse, and fields a lighter wave, than one that has not.
--
-- Lighter rather than smaller: the never-three rule caps the line at four, so a wave
-- usually has the same number of bodies either way, and what a poorer lane loses is
-- the dear ones. Fewer bodies was tried as the measure and it is a coin toss.
local function test_heavy_infantry_makes_a_lane_poorer()
  local world, modules, parameters = fresh_world()
  local heavy = parameters.unit.deck.entry[1].archetype
  local after = {[true] = {purse = 0, next_weight = 0, count = 0},
                 [false] = {purse = 0, next_weight = 0, count = 0}}
  local previous

  many_waves(world, modules, 1, 1, 1200, function(drawn, state)
    if previous ~= nil then
      local bucket = after[previous.had_heavy]
      for _, body in ipairs(drawn) do
        bucket.next_weight = bucket.next_weight + body.cost
      end
    end
    local had_heavy = false
    for _, body in ipairs(drawn) do
      if body.archetype == heavy then had_heavy = true end
    end
    local bucket = after[had_heavy]
    bucket.purse = bucket.purse + state.last.purse_after
    bucket.count = bucket.count + 1
    previous = {had_heavy = had_heavy}
  end)

  local with, without = after[true], after[false]
  check("both kinds of wave turned up often enough to compare",
        with.count >= 30 and without.count >= 30,
        string.format("%d with heavy infantry, %d without", with.count, without.count))
  local purse_with, purse_without = with.purse / with.count, without.purse / without.count
  check("a lane that fielded heavy infantry ends the wave with less in its purse",
        purse_with < purse_without,
        string.format("%.2f against %.2f", purse_with, purse_without))
  local next_with, next_without = with.next_weight / with.count, without.next_weight / without.count
  check("and fields a lighter wave after it, by what its bodies cost",
        next_with < next_without,
        string.format("%.2f against %.2f", next_with, next_without))
end
-- }}}

-- {{{ local function test_the_books()
-- The deck's own rules, each asked once: the discards go under what is undrawn, a
-- meter at its doubling walks a kind out undrawn, and cost follows weight.
local function test_the_books()
  local world, modules, parameters = fresh_world()
  local settings = parameters.unit.deck
  local deck = modules.lane_deck
  local state = world.team[1].lane_deck[1]
  local commander = parameters.commander.commander[1]

  local before = {}
  for index, card in ipairs(state.draw) do before[index] = card end
  deck.draw_wave(world, 1, 1, commander)
  local turned = state.last.spent
  local kept = turned <= #before
  for index = turned + 1, #before do
    if state.draw[index - turned] ~= before[index] then kept = false end
  end
  check("after a wave the tickets nobody drew are still on top, in order",
        kept and turned < #before,
        string.format("%d turned from a deck of %d", turned, #before))
  local tickets = 0
  for _, entry in ipairs(settings.entry) do tickets = tickets + entry.start end
  check("and every ticket is still in the deck, the discards under them",
        #state.draw + #state.discard == tickets and #state.discard == 0,
        string.format("%d in the deck and %d discarded, of %d", #state.draw,
          #state.discard, tickets))

  -- Push the heavy meter to its doubling and take every heavy ticket out of the deck:
  -- the only way one can walk out now is the meter.
  local heavy_entry = settings.entry[1]
  state.meter[1] = settings.meter_doubling * heavy_entry.max
  local stripped = {}
  for _, card in ipairs(state.draw) do
    if card ~= 1 then stripped[#stripped + 1] = card end
  end
  state.draw = stripped
  local drawn = deck.draw_wave(world, 1, 1, commander)
  local heavies = 0
  for _, body in ipairs(drawn) do
    if body.archetype == heavy_entry.archetype then heavies = heavies + 1 end
  end
  check("a meter at twice its most tickets walks one out without being drawn",
        heavies == 1 and state.last.from_meter == 1,
        string.format("%d heavy, %d from the meter", heavies, state.last.from_meter))
  check("and the meter starts again from nothing", state.meter[1] == 0)

  -- Cost follows weight: every optional piece makes a body dearer or no cheaper, and
  -- the full weight of heavy kit is the dearest thing in the deck.
  local archetype = parameters.unit.archetype
  local rising, dearest, dearest_name = true, 0, ""
  for _, entry in ipairs(settings.entry) do
    local row = archetype[entry.archetype]
    local all = 2 ^ #row.kit.maybe - 1
    if deck.cost_of(world, row, all) < deck.cost_of(world, row, 0) then rising = false end
    if deck.cost_of(world, row, all) > dearest then
      dearest, dearest_name = deck.cost_of(world, row, all), row.name
    end
    if deck.cost_of(world, row, 0) < 1 then rising = false end
  end
  check("carrying more never costs less, and nothing is free", rising)
  check("heavy infantry is the dearest kind there is",
        dearest_name == archetype[heavy_entry.archetype].name, dearest_name)
end
-- }}}

-- {{{ local function test_in_a_match()
-- The deck as the spawner uses it: what walks out of the base, what it is wearing,
-- and that the two sides of an untouched match still mirror each other.
local function test_in_a_match()
  local world, modules, parameters = fresh_world()
  local soldier = world.soldier
  local archetype = parameters.unit.archetype
  local deck_rows = {}
  for _, entry in ipairs(parameters.unit.deck.entry) do deck_rows[entry.archetype] = true end

  for _ = 1, parameters.unit.wave.first_at + 2 do
    tick_module.advance(world)
  end

  local stray, by_team = 0, {{}, {}}
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
      local row = archetype[soldier.archetype[id]]
      local wave = world.wave[soldier.wave[id]]
      local is_captain = (soldier.archetype[id] ==
        parameters.commander.commander[wave.commander].captain)
      if not is_captain and not deck_rows[soldier.archetype[id]] then
        stray = stray + 1
      end
      local list = by_team[soldier.team[id]]
      list[#list + 1] = string.format("%d:%d:%d", wave.lane, soldier.archetype[id], soldier.kit[id])
    end
  end
  check("every body of the first waves but the captains came from the deck", stray == 0,
        stray .. " did not")

  table.sort(by_team[1]); table.sort(by_team[2])
  check("and the two sides' first waves are the same bodies in the same kit",
        table.concat(by_team[1], " ") == table.concat(by_team[2], " ")
        and #by_team[1] > 0)

  -- A body wears exactly its kit. Nothing has been placed in any lane yet and nobody
  -- holds a boon, so every number is its row plus what it is carrying, and the sum
  -- can be done by hand from the equipment table.
  local equipment = parameters.unit.equipment
  local wrong, worn_optional = nil, 0
  for id = 1, world.high_water do
    local row = archetype[soldier.archetype[id]]
    if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 and row.kit ~= nil then
      local health, armour, damage = row.health, row.armour, row.damage
      local function wear(piece)
        local add = equipment[piece].add
        health = health + (add.health or 0)
        armour = armour + (add.armour or 0)
        damage = damage + (add.damage or 0)
      end
      for _, piece in ipairs(row.kit.carries) do wear(piece) end
      for index, maybe in ipairs(row.kit.maybe) do
        if math.floor(soldier.kit[id] / 2 ^ (index - 1)) % 2 == 1 then
          wear(maybe[1])
          worn_optional = worn_optional + 1
        end
      end
      if math.abs(soldier.health_max[id] - health) > 1e-9
         or math.abs(soldier.armour[id] - armour) > 1e-9
         or math.abs(soldier.damage[id] - damage) > 1e-9 then
        wrong = wrong or string.format("%s: health %.1f armour %.1f damage %.1f, kit says %.1f %.1f %.1f",
          row.name, soldier.health_max[id], soldier.armour[id], soldier.damage[id],
          health, armour, damage)
      end
    end
  end
  check("every body wears exactly its row and its kit", wrong == nil, wrong)
  check("and some of them drew something optional", worn_optional > 0)

  local before = {}
  for id = 1, world.high_water do
    if soldier.alive[id] == 1 and soldier.wave[id] ~= 0 then
      before[id] = {soldier.health_max[id], soldier.armour[id], soldier.damage[id], soldier.speed[id]}
    end
  end
  world.chest.restamp_team(world, 1)
  local same = true
  for id, was in pairs(before) do
    if soldier.team[id] == 1 then
      local now = {soldier.health_max[id], soldier.armour[id], soldier.damage[id], soldier.speed[id]}
      for index = 1, #was do
        if math.abs(now[index] - was[index]) > 1e-9 then same = false end
      end
    end
  end
  check("and a sweep that rebuilds every body from its row gives each its kit back", same)
end
-- }}}

print("the lane deck")
test_the_shuffle()
test_a_mixture_over_a_long_run()
test_never_three_of_a_kind()
test_heavy_infantry_makes_a_lane_poorer()
test_the_books()
test_in_a_match()

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
  os.exit(1)
end
