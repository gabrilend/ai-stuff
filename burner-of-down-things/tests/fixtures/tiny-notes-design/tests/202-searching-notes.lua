package.path = "./?.lua;" .. package.path
local search = require("src.search")
local notes = { { text = "fix the bike chain" }, { text = "a.b literally" }, { text = "axb" } }
assert(#search.find(notes, "CHAIN") == 1, "case-blind")
local dotted = search.find(notes, "a.b")
assert(#dotted == 1 and dotted[1].text == "a.b literally", "plain text, not a pattern")
print("202 ok")
