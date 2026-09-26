package.path = "./?.lua;" .. package.path
local tags = require("src.tags")
local found = tags.parse("buy #Milk and #milk #home")
assert(#found == 2 and found[1] == "milk" and found[2] == "home", "parse")
local notes = { { tags = { "home" } }, { tags = { "work" } } }
assert(#tags.filter(notes, "#HOME") == 1 and #tags.filter(notes, "home") == 1, "filter")
print("102 ok")
