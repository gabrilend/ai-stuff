package.path = "./?.lua;" .. package.path
local dates = require("src.dates")
assert(dates.is_date(dates.today()), "today is a date")
assert(not dates.is_date("2026-9-1"), "short month refused")
print("103 ok")
