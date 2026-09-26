package.path = "./?.lua;" .. package.path
local store = require("src.store")
local path = os.tmpname()
store.save(path, {
    { id = 1, date = "2026-09-26", tags = { "home" }, text = "buy milk #home" },
    { id = 7, date = "2026-09-27", tags = {}, text = "call back" },
})
local back = store.load(path)
assert(#back == 2 and back[1].text == "buy milk #home" and back[1].tags[1] == "home", "round trip")
assert(back[2].id == 7 and #back[2].tags == 0, "second note")
assert(store.next_id(back) == 8, "next id")
assert(store.next_id({}) == 1, "first id")
os.remove(path)
assert(#store.load(path) == 0, "missing file is empty")
print("101 ok")
