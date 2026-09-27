package.path = "./?.lua;" .. package.path
local show = require("src.show")
local a = { id = 3, date = "2026-09-26", text = "fix the #bike", tags = { "bike" } }
local b = { id = 12, date = "2026-09-27", text = "plain", tags = {} }
assert(show.line(a) == "   3  2026-09-26  fix the #bike  [#bike]", "line with tags: " .. show.line(a))
assert(show.line(b) == "  12  2026-09-27  plain", "line without tags")
assert(select(2, show.list({ a, b }):gsub("\n", "")) == 1, "two lines")
assert(show.list({}) == "(no notes)", "empty")
print("201 ok")
