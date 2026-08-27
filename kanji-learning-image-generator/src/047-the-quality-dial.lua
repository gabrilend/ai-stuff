-- 047-the-quality-dial.lua
--
-- Turning the quality up on one kind of picture, and being told what that costs
-- before it costs it.
--
-- For a general: the exchange this exists for is
--
--     the forest ones are looking pretty bad -- can we raise their quality?
--   > raising forest from 3 to 4 leaves 31 to draw from instead of 214, so
--   > expect them to start resembling each other.
--     that's fine.
--   > do you want to look through the 47 nobody has rated? it would take a few
--   > minutes.
--     not now.
--
-- Four things are in that exchange and all four are requirements here.
--
-- THE FLOOR IS PER KIND AND SET WHEN IT IS USED. Not a global setting and not
-- something compiled in. Quality is a thing you turn up on *the forest ones*
-- because the forest ones are what is bothering you.
--
-- RAISING IT COSTS VARIETY AND THAT IS SAID FIRST. The size of the surviving
-- set at the current floor and at the proposed one, at the moment of choosing
-- rather than afterwards in the output. This is the same axis that decides
-- whether a trained thing memorises or wanders, pulled out of the internals and
-- put where a person can reach it.
--
-- PROVENANCE IS A SECOND DIAL. "Tier 4 or better" and "tier 4 or better as
-- judged by a person" are different requests; the second is smaller and more
-- trustworthy. Confidence and quality are not the same axis, and collapsing
-- them loses the difference exactly when it matters.
--
-- RE-RATING IS OFFERED WITH ITS COST ATTACHED, AND DECLINING IS FREE. A studio
-- that nags is a studio nobody opens.
--
--   luajit src/047-the-quality-dial.lua --category forest --floor 4

local project = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) ..
                       "/009-where-things-are.lua")
local pool = project.load("045-the-pool-that-remembers")

local M = {}

-- {{{ M.consider(settings, category, by_a_person)
-- What a floor would leave, at every tier, before anybody commits to one.
--
-- Returns the whole ladder rather than one number, because the question is
-- never "how many at four" on its own -- it is "how many do I lose by going
-- from three to four", and that needs both.
function M.consider(settings, category, by_a_person)
  local all = pool.walk(settings, { category = category })
  local ladder = {}
  for floor = 1, 5 do
    ladder[floor] = 0
  end
  local unrated = 0
  local unrated_by_a_person = 0

  for _, entry in ipairs(all) do
    local tier
    if by_a_person then
      tier = pool.tier_by_a_person(entry)
    else
      tier = pool.tier_of(entry)
    end
    if tier then
      -- every floor at or below this tier keeps it
      for floor = 1, tier do ladder[floor] = ladder[floor] + 1 end
    else
      unrated = unrated + 1
    end
    if not pool.tier_by_a_person(entry) then
      unrated_by_a_person = unrated_by_a_person + 1
    end
  end

  return {
    category = category or "everything",
    total = #all,
    ladder = ladder,
    unrated = unrated,
    unrated_by_a_person = unrated_by_a_person,
    by_a_person = by_a_person or false,
  }
end
-- }}}

-- {{{ M.describe(report, from_floor, to_floor)
-- The trade, in the words somebody would use.
function M.describe(report, from_floor, to_floor)
  local lines = {}
  local function say(text) lines[#lines + 1] = text end

  say(string.format("%d %s pictures%s", report.total, report.category,
                    report.by_a_person and ", counting only what a person rated"
                    or ""))
  say("")
  for floor = 5, 1, -1 do
    say(string.format("  at tier %d or better: %5d   %s", floor,
                      report.ladder[floor], pool.TIERS[floor]))
  end
  if report.unrated > 0 then
    say(string.format("  %d have no tier at all and are in none of those counts",
                      report.unrated))
  end

  if from_floor and to_floor then
    local before = report.ladder[from_floor] or 0
    local after = report.ladder[to_floor] or 0
    say("")
    if to_floor > from_floor then
      say(string.format(
        "Raising %s from %d to %d leaves %d to draw from instead of %d.",
        report.category, from_floor, to_floor, after, before))
      if after == 0 then
        say("Which is none. Nothing would be drawn from at all.")
      elseif before > 0 and after < before * 0.3 then
        say("That is most of them gone, so expect them to start resembling")
        say("each other. That is the trade, and it is the point of the dial.")
      end
    elseif to_floor < from_floor then
      say(string.format(
        "Lowering %s from %d to %d gives %d to draw from instead of %d.",
        report.category, from_floor, to_floor, after, before))
      say("More to choose between, and some of it is there because nobody has")
      say("said otherwise yet.")
    end
  end

  -- The offer, with its own cost attached so the answer can be informed, and
  -- made once.
  if report.unrated_by_a_person > 0 then
    say("")
    say(string.format("%d of these carry no rating from a person. Looking " ..
                      "through them would", report.unrated_by_a_person))
    say("make every number above mean more:")
    say("  luajit src/032-a-gallery-you-can-page.lua --pool")
    say("Declining costs nothing and this will not ask again.")
  end

  return lines
end
-- }}}

-- {{{ M.choose(settings, wanted)
-- The pictures that survive a floor -- and the report, always, first.
--
-- The report is not optional and cannot be turned off. A filter that quietly
-- returns thirty-one things where there were two hundred is the failure this
-- whole file exists to prevent, and making the telling optional is how it would
-- come back.
function M.choose(settings, wanted)
  local report = M.consider(settings, wanted.category, wanted.by_a_person)
  local kept = pool.walk(settings, {
    category = wanted.category,
    kind = wanted.kind,
    floor = wanted.floor,
    by_a_person = wanted.by_a_person,
  })
  return kept, report
end
-- }}}

-- {{{ main(argv)
local function main(argv)
  local options = project.arguments(argv)
  local settings = project.hello("047-the-quality-dial")

  local category = type(options.category) == "string" and options.category or nil
  local floor = tonumber(options.floor)
  local from = tonumber(options.from)

  local report = M.consider(settings, category, options.by_a_person and true)
  if report.total == 0 then
    io.write("there are no ", category or "", " pictures in the pool yet.\n")
    io.write("  luajit src/045-the-pool-that-remembers.lua\n")
    project.goodbye("047-the-quality-dial", { "the pool is empty" })
    return
  end

  for _, line in ipairs(M.describe(report, from or (floor and floor - 1), floor)) do
    io.write(line, "\n")
  end

  if floor then
    local kept = M.choose(settings, {
      category = category, floor = floor,
      by_a_person = options.by_a_person and true,
    })
    io.write("\nwhat survives:\n")
    for index = 1, math.min(12, #kept) do
      local tier, who = pool.tier_of(kept[index])
      io.write(string.format("  %s  %-9s tier %d by %s\n", kept[index].character,
               kept[index].category, tier, who))
    end
    if #kept > 12 then
      io.write(string.format("  and %d more\n", #kept - 12))
    end
  end

  project.goodbye("047-the-quality-dial", { report.total .. " considered" })
end
-- }}}

if arg and arg[0] and arg[0]:find("047%-the%-quality%-dial") then
  main(arg)
end

return M
