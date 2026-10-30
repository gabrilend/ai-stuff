-- 056-cards-test.lua - checks every film keeps its card (issue 701e).
--
-- What this is, generally: films a few scenes into a scratch folder and
-- asks: does each film get a card with what made it? Do the approved films
-- start at five? Is a rating appended and never edited, and does the last
-- one count? Does a film made again with new bytes start unrated, keeping
-- the old ratings above? Does the viewer's own reader and writer agree with
-- the maker's? Does the count read the cards right?
--
-- Usage: luajit src/056-cards-test.lua DIR   (DIR = the gif-generator project)
-- Prints one line per check; exits 1 if any failed.

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/gif-generator"
local cards = dofile(DIR .. "/src/055-cards.lua")
local rate = dofile(DIR .. "/viewer/rate.lua")
local SCRATCH = "/dev/shm/gif-generator/cards-test"
os.execute(string.format("rm -rf %q; mkdir -p %q", SCRATCH, SCRATCH))

local passed, failed = 0, 0
-- {{{ local function check()
local function check(label, ok)
    if ok then
        passed = passed + 1
        print("  ok   - " .. label)
    else
        failed = failed + 1
        print("  FAIL - " .. label)
    end
end
-- }}}

-- {{{ local function film()
-- Films scenes with the film tool itself, into the scratch folder.
local function film(names, extra)
    os.execute(string.format("luajit %q %q %s --out=%q %s > /dev/null",
        DIR .. "/src/039-shape-films.lua", DIR, names, SCRATCH, extra or ""))
end
-- }}}

-- {{{ local function lines_of()
local function lines_of(path)
    local list = {}
    local handle = io.open(path, "r")
    if not handle then return list end
    for line in handle:lines() do list[#list + 1] = line end
    handle:close()
    return list
end
-- }}}

-- An approved film, whole, and another scene, short.
film("breathing-solid")
film("blob-jellyfish", "--frames=6")
local approved_card = SCRATCH .. "/breathing-solid.gif.card"
local card = cards.read(approved_card)
check("the film tool writes a card beside its film", card ~= nil)
check("the card names the film, its fingerprint and the scene that made it",
      card and card.film == "breathing-solid.gif"
      and card.fingerprint == cards.fingerprint(SCRATCH .. "/breathing-solid.gif")
      and card.score == "input/shapes/breathing-solid.lua" and card.category == "shapes")
check("the card says what moves in the film, from the scene's own words",
      card and card.about:match("^one shape breathes between a cube and an octahedron") ~= nil)
check("an approved film starts at tier five", card and cards.tier_of(card) == 5)
local other = cards.read(SCRATCH .. "/blob-jellyfish.gif.card")
check("a generated scene's card names its generator too",
      other and other.generator == "input/shapes/generators/blob-jellyfish.lua")
check("a film nobody has rated is not rated", other and cards.tier_of(other) == nil)

-- Ratings are appended; the last counts; nothing above is touched.
local before = lines_of(approved_card)
cards.rate(approved_card, 3, "person", "2026-10-31")
local after = lines_of(approved_card)
local untouched = #after == #before + 1
for i = 1, #before do if before[i] ~= after[i] then untouched = false end end
check("a rating is one line added at the end, every line above unchanged", untouched)
check("the last rating counts", cards.tier_of(cards.read(approved_card)) == 3)
check("a tier outside 1 to 5 is refused", not pcall(cards.rate, approved_card, 6, "person"))

-- The viewer's own lines agree with the maker's.
check("the viewer reads the same tier the maker does", rate.tier(approved_card) == 3)
check("the viewer appends a rating the maker reads", rate.append(approved_card, 4, "2026-11-01")
      and cards.tier_of(cards.read(approved_card)) == 4)
check("the viewer will not rate a film with no card",
      rate.append(SCRATCH .. "/nothing.gif.card", 4) == false and rate.tier(SCRATCH .. "/nothing.gif.card") == false)

-- Made again with the same bytes: the card is left alone.
local same_before = lines_of(approved_card)
film("breathing-solid")
local same_after = lines_of(approved_card)
check("a film made again with the same bytes leaves its card as it was", #same_after == #same_before)

-- Made again with new bytes: a different film, unrated, the old ratings kept.
film("blob-jellyfish", "--frames=4")
other = cards.read(SCRATCH .. "/blob-jellyfish.gif.card")
check("a film made again with new bytes says so on its card, with the new fingerprint",
      other and #other.refilmed == 1
      and cards.current_fingerprint(other) == cards.fingerprint(SCRATCH .. "/blob-jellyfish.gif"))
cards.rate(SCRATCH .. "/blob-jellyfish.gif.card", 2, "person", "2026-10-31")
film("blob-jellyfish", "--frames=5")
other = cards.read(SCRATCH .. "/blob-jellyfish.gif.card")
check("and its ratings stay, but no longer count for the new film",
      #other.ratings == 1 and cards.tier_of(other) == nil and rate.tier(SCRATCH .. "/blob-jellyfish.gif.card") == nil)
film("breathing-solid", "--frames=4")
film("breathing-solid")
check("a film made again into an approved one carries the approval again",
      cards.tier_of(cards.read(approved_card)) == 5)

-- Films made before cards: --write gives each a card; the approved at five.
os.execute(string.format("cp %q %q", SCRATCH .. "/breathing-solid.gif", SCRATCH .. "/orbit-kiss-like.gif"))
os.execute(string.format("rm %q", approved_card))
local written = cards.write_missing(DIR, SCRATCH)
check("--write gives every film with no card a card (" .. tostring(written) .. " written)", written == 2)
check("--write starts an approved film at five, whatever its name",
      cards.tier_of(cards.read(SCRATCH .. "/orbit-kiss-like.gif.card")) == 5)
check("--write finds what made a film by its name",
      cards.read(approved_card).score == "input/shapes/breathing-solid.lua")

-- The count reads the cards alone.
os.execute(string.format("cp %q %q", SCRATCH .. "/blob-jellyfish.gif", SCRATCH .. "/no-card.gif"))
local report = cards.counts(SCRATCH)
local shapes = report.categories.shapes
check("the count puts every film at its tier", shapes and shapes.total == 2 and shapes[5] == 1
      and shapes.unrated == 1 and shapes.waiting == 1)
check("the count names films with no card", #report.no_card == 1 and report.no_card[1] == "no-card.gif")
check("the count says it plainly", cards.describe(report, SCRATCH):match("5  reach for it first%s+1") ~= nil)

os.execute(string.format("rm -r %q", SCRATCH))
print("")
print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
