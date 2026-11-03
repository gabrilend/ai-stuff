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

-- 076-the-lane-deck.lua
--
-- What a lane can afford: a deck of tickets paid for in discards, a purse, and the
-- meters that keep a kind from vanishing. Issue 213, its first half.
--
-- ## A wave is drawn, not specified
--
-- Each lane of each team keeps a **deck of tickets**, one ticket naming one kind of
-- soldier. Raising a wave is taking the top card -- that kind walks out -- and then
-- drawing and discarding as many more as the body it raised **costs**. An expensive
-- body eats the deck: having taken one, you have less of everything for a while.
--
-- Cost is what the body is carrying. Its kit is drawn at birth from the lane's own
-- stream, and its weight, a point per `weight_per_point`, is how many tickets it
-- burns. **The lane's purse is counted in tickets turned**: every card that leaves
-- the top of the deck -- the one drawn, the ones discarded for it, one set aside --
-- is a point out of the purse, and a wave draws until the purse is spent. So cost is
-- paid in discards and in nothing else, and a heavy body is not refused for being
-- dear: it is drawn, and it eats the rest of the wave.
--
-- The purse refills each wave, may save up to a ceiling, and may end a wave in debt
-- by the discards of the last body drawn -- so a lane that has been fielding heavy
-- infantry fields fewer, lighter bodies next, and a lane that has been cheap for a
-- while can suddenly afford something. Nothing of this is a number a player sees.
-- What they see is what walks out.
--
-- ## Two of a kind, and never three
--
-- A kind that has not walked out for a while has a **meter** that fills by its
-- ticket count each wave it is missing. At twice its most tickets, one walks out
-- without being drawn -- and it can still be drawn as well, which is how two of a
-- kind come out together. A third is never fielded: its card is set aside, and turning
-- it still cost the purse a point.
--
-- ## The commander still sets the proportion
--
-- Which commander's turn it is decides how much of a wave may be line and how much
-- missile, as it always has. The deck decides *which* line and *which* missile. A card
-- for a half that is already full is set aside like a third of a kind.
--
-- ## The shuffle is not a shuffle
--
-- Deal into piles and stack them, five passes: three, four, five, four, seven. The odd
-- counts rotate from one shuffle to the next and every other pass is four. No random
-- number is involved at all, which is worth a great deal in a project whose first
-- invariant is that the same seed plays the same match. After each wave the discards
-- are shuffled this way and put **below** the tickets nobody has drawn yet; when the
-- deck runs out mid-wave, the discards are shuffled and become the deck.
--
-- ## Not here yet
--
-- What upgrades do to a deck -- a ticket for an entry, a point for the purse, an entry
-- traded for a better one -- is 213's second half, and so is placing each kind at its
-- own bearing. Until then every lane's deck holds its starting tickets forever, and a
-- kind stands where its reach already put it: line in front, missile behind.

local M = {}

-- {{{ local function pile_pass()
-- One pass: deal the cards round into `piles` piles, then stack the piles in order.
local function pile_pass(cards, piles)
  local pile = {}
  for index = 1, piles do
    pile[index] = {}
  end
  for index, card in ipairs(cards) do
    local into = pile[((index - 1) % piles) + 1]
    into[#into + 1] = card
  end
  local stacked = {}
  for index = 1, piles do
    for _, card in ipairs(pile[index]) do
      stacked[#stacked + 1] = card
    end
  end
  return stacked
end
-- }}}

-- {{{ function M.pile_shuffle()
-- The whole shuffle. `rotation` picks which odd count goes first; the passes are
-- always odd, four, odd, four, odd.
function M.pile_shuffle(cards, settings, rotation)
  local odd = settings.odd_piles
  local passes = {}
  for index = 1, #odd do
    passes[#passes + 1] = odd[((index - 1 + rotation) % #odd) + 1]
    if index < #odd then
      passes[#passes + 1] = settings.even_pile
    end
  end
  for _, piles in ipairs(passes) do
    cards = pile_pass(cards, piles)
  end
  return cards
end
-- }}}

-- {{{ local function shuffled_discards()
-- Shuffles a lane's discards and advances its rotation, so the next shuffle leads with
-- the next odd count.
local function shuffled_discards(state, settings)
  local cards = M.pile_shuffle(state.discard, settings, state.shuffles)
  state.shuffles = state.shuffles + 1
  state.discard = {}
  return cards
end
-- }}}

-- {{{ local function take_card()
-- The top card, into the discards, and a point out of the purse. When the deck is
-- empty the discards are shuffled and become it.
local function take_card(state, settings)
  if #state.draw == 0 then
    state.draw = shuffled_discards(state, settings)
    if #state.draw == 0 then
      error("a lane's deck and its discards are both empty -- it was built with no tickets")
    end
  end
  local card = table.remove(state.draw, 1)
  state.discard[#state.discard + 1] = card
  state.purse = state.purse - 1
  return card
end
-- }}}

-- {{{ function M.cost_of()
-- What a body of this row carrying this kit costs its lane: a point per
-- `weight_per_point` of weight, rounded up, and never nothing.
function M.cost_of(world, row, mask)
  local equipment = world.parameters.unit.equipment
  local weight = 0
  for _, piece in ipairs(row.kit.carries) do
    weight = weight + equipment[piece].weight
  end
  for index, maybe in ipairs(row.kit.maybe) do
    if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
      weight = weight + equipment[maybe[1]].weight
    end
  end
  local cost = math.ceil(weight / world.parameters.unit.deck.weight_per_point)
  if cost < 1 then
    cost = 1
  end
  return cost
end
-- }}}

-- {{{ local function roll_kit()
-- What one body is carrying. One draw per optional piece, whatever comes up, so the
-- number of draws a body takes never depends on what the one before it got.
local function roll_kit(world, state, row)
  local mask = 0
  for index, maybe in ipairs(row.kit.maybe) do
    if state.kit_stream:next_float() < maybe[2] then
      mask = mask + 2 ^ (index - 1)
    end
  end
  return mask, M.cost_of(world, row, mask)
end
-- }}}

-- {{{ function M.begin()
-- Every lane's deck, purse and meters, for both teams.
--
-- **Both teams' decks for a lane are built the same and draw their kit from streams
-- of the same name.** Each team has its own stream object, so nothing either team
-- draws depends on what the other did; and they start alike, so an untouched match is
-- still a mirror. A stream per team named for the team would have made the very first
-- wave of each side different, and an asymmetric match before anybody has moved is
-- the one thing an untouched match must not be.
function M.begin(world)
  local settings = world.parameters.unit.deck
  local archetype = world.parameters.unit.archetype

  for _, entry in ipairs(settings.entry) do
    local row = archetype[entry.archetype]
    if row == nil or row.kit == nil or row.flavour ~= 1 then
      error("the lane deck names row " .. tostring(entry.archetype) ..
            ", which is not a wave soldier with a kit")
    end
  end

  for team = 1, 2 do
    world.team[team].lane_deck = {}
    for lane = 1, world.parameters.lane_count do
      local cards = {}
      local tickets, meter, fielded_total = {}, {}, {}
      for index, entry in ipairs(settings.entry) do
        for _ = 1, entry.start do
          cards[#cards + 1] = index
        end
        tickets[index] = entry.start
        meter[index] = 0
        fielded_total[index] = 0
      end
      local state = {
        draw = {}, discard = cards, shuffles = 0,
        tickets = tickets, meter = meter, fielded_total = fielded_total,
        purse = settings.purse_start,
        kit_stream = world.random_streams.new(world.parameters.seed, "kit-lane-" .. lane),
        last = nil,
      }
      state.draw = shuffled_discards(state, settings)
      world.team[team].lane_deck[lane] = state
    end
  end
end
-- }}}

-- {{{ function M.draw_wave()
-- Who walks out of this lane this wave, beside the captain.
--
-- Returns a list of {archetype, kit, cost}, ordered by the deck's entries -- heavy
-- before light, skirmishers before archers -- which is also the order the formation
-- hands out places in, centre first. And settles the lane's books for the wave: its
-- meters, its discards under the undrawn tickets, and its purse refilled.
function M.draw_wave(world, team, lane, commander)
  local settings = world.parameters.unit.deck
  local archetype = world.parameters.unit.archetype
  local state = world.team[team].lane_deck[lane]
  local entries = settings.entry

  local line_cap = math.floor(settings.body_cap * commander.melee_share + 0.5)
  local half_cap = {[1] = line_cap, [2] = settings.body_cap - line_cap}
  local in_half = {[1] = 0, [2] = 0}
  local fielded = {}
  for index = 1, #entries do
    fielded[index] = 0
  end

  local bodies = {}
  local set_aside, from_meter = 0, 0

  local function can_field(index)
    local row = archetype[entries[index].archetype]
    return #bodies < settings.body_cap
       and fielded[index] < settings.most_of_a_kind
       and in_half[row.reach] < half_cap[row.reach]
  end

  -- Only over entries that hold a ticket. One with none can never come up, and asking
  -- whether it could be fielded would keep the draw turning cards forever.
  local function any_can_field()
    for index = 1, #entries do
      if state.tickets[index] > 0 and can_field(index) then
        return true
      end
    end
    return false
  end

  -- A body walks out, and its cost is discarded off the top of the deck.
  local function field(index)
    local row = archetype[entries[index].archetype]
    local mask, cost = roll_kit(world, state, row)
    bodies[#bodies + 1] = {archetype = entries[index].archetype, kit = mask,
                           cost = cost, entry = index}
    fielded[index] = fielded[index] + 1
    in_half[row.reach] = in_half[row.reach] + 1
    for _ = 1, cost do
      take_card(state, settings)
    end
  end

  local purse_before = state.purse

  -- The meters first. A kind that has been missing long enough walks out whatever the
  -- purse says -- that is the point of it. It is not drawn, so it turns no card for
  -- itself, but it still pays its discards like anything else, and the debt it leaves
  -- is the lane's.
  for index, entry in ipairs(entries) do
    if state.meter[index] >= settings.meter_doubling * entry.max and can_field(index) then
      field(index)
      from_meter = from_meter + 1
    end
  end

  -- Then the draw, until the purse is spent or nothing more could walk out.
  while state.purse > 0 and any_can_field() do
    local card = take_card(state, settings)
    if can_field(card) then
      field(card)
    else
      set_aside = set_aside + 1
    end
  end
  local spent = purse_before - state.purse

  -- The books. A kind fielded resets its meter; a kind missing fills it by its tickets.
  for index = 1, #entries do
    if fielded[index] > 0 then
      state.meter[index] = 0
    else
      state.meter[index] = state.meter[index] + state.tickets[index]
    end
    state.fielded_total[index] = state.fielded_total[index] + fielded[index]
  end

  -- The discards, shuffled, **below** what has not been drawn yet.
  local under = shuffled_discards(state, settings)
  for _, card in ipairs(under) do
    state.draw[#state.draw + 1] = card
  end

  state.last = {spent = spent, set_aside = set_aside, from_meter = from_meter,
                fielded = fielded, purse_after = state.purse}

  state.purse = state.purse + settings.income_per_wave
  if state.purse > settings.purse_max then
    state.purse = settings.purse_max
  end

  table.sort(bodies, function(a, b)
    if a.entry ~= b.entry then
      return a.entry < b.entry
    end
    -- The heavier of two of a kind nearer the centre, and the kit as the last word
    -- so the order never depends on what the sort happened to do with a tie.
    if a.cost ~= b.cost then
      return a.cost > b.cost
    end
    return a.kit > b.kit
  end)
  return bodies
end
-- }}}

return M
