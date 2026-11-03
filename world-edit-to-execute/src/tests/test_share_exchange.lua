#!/usr/bin/env luajit
-- test_share_exchange.lua - a shared list carried between two players (issue 609a)
--
-- In plain terms: Ana offers her list to Ben; Ben's game reads it (never
-- runs it) and asks him first, unless he trusts Ana or the map; on yes it
-- asks Ana for only the files his store lacks; Ana sends only files she
-- offered to Ben; Ben checks every file and applies the list for one game.
-- Everything goes through a fake rmail built to the contract the issue
-- assumes, so the real glue is the only part left.
--
-- Run: luajit src/tests/test_share_exchange.lua [DIR]
-- Issue: issues/completed/609a-shared-list-over-rmail-and-the-prompt.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local list = require("share.list")
local exchange = require("share.exchange")
local hook = require("share.rmail_hook")
local profile = require("share.profile")
local dedup = require("assets.dedup")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
local function write(path, bytes)
    os.execute("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb")); f:write(bytes); f:close()
end
local function read(path) local f = io.open(path, "rb"); if not f then return nil end local t = f:read("*a"); f:close(); return t end
local function exists(path) return os.rename(path, path) ~= nil end

local SCR = os.tmpname()
os.remove(SCR)
local A, B = SCR .. "/ana", SCR .. "/ben"
local MINE = A .. "/asset-packs/mine"
write(MINE .. "/Textures/Grass.tga", "grass by Ana")
write(MINE .. "/units/knight/knight.mdx", "MDLX a knight, by Ana")
write(MINE .. "/sounds/horn.wav", "RIFF a horn")
write(SCR .. "/maps/castle.w3x", "a map's bytes")
local l = list.build({ map = SCR .. "/maps/castle.w3x", map_name = "Castle Fight", pack = MINE,
                       types = { hfoo = "units/knight/knight.mdx" }, author = "Ana", created = "2026-11-03" })

-- {{{ a fake rmail: one mailbox per player, delivered by hand
local boxes = { ana = {}, ben = {}, eve = {} }
local function rmail_for(me)
    return { send = function(mail)
        mail.from = me                       -- rmail authenticates the sender
        table.insert(boxes[mail.to], mail)
    end }
end
local answers = {}
-- delivers every mail waiting for WHO through its hook; gives the answers
local function deliver(who, on_receive)
    local got = {}
    while #boxes[who] > 0 do
        local mail = table.remove(boxes[who], 1)
        got[#got + 1] = on_receive(mail)
    end
    return got
end
-- }}}

local ready, problems = {}, {}
local ana = exchange.new({ data = A, me = "ana", pack = MINE, transport = hook.transport(rmail_for("ana")),
                           on_problem = function(id, what) problems[#problems + 1] = "ana: " .. what end })
local ben = exchange.new({ data = B, me = "ben", transport = hook.transport(rmail_for("ben")),
                           on_ready = function(P, q) ready[#ready + 1] = { P = P, q = q } end,
                           on_problem = function(id, what) problems[#problems + 1] = "ben: " .. what end })
local ana_hook, ben_hook = hook.on_receive(ana), hook.on_receive(ben)

-- {{{ The stub and the mail format
print("\n=== The rmail glue ===")
local ok_c, why = hook.connect()
test("connecting to the real rmail is a stub that says why", ok_c == nil and why:match("isn't attached"))
local m = hook.decode(hook.encode({ kind = "want", id = "x-1", hashes = { l.entries[1].hash } }))
test("a want survives the mail format", m and m.kind == "want" and m.hashes[1] == l.entries[1].hash)
test("a mail that isn't ours is left to rmail", ben_hook({ subject = "lunch?", body = "", from = "ana" }) == nil)
test("a share subject with a bad id is declined", ben_hook({ subject = "wete-share list ../x", body = "", from = "ana" }) == "decline")
test("a want with something other than hashes is declined",
    ana_hook({ subject = "wete-share want x-1", body = "rm -rf /\n", from = "ben" }) == "decline")
-- }}}

-- {{{ Asked first, by default
print("\n=== A list from someone not trusted waits for the player ===")
local id = ana:offer("ben", l)
test("the offer goes out as one mail with the list as its body", #boxes.ben == 1
    and boxes.ben[1].subject == "wete-share list " .. id and #boxes.ben[1].attachments == 0)
local got = deliver("ben", ben_hook)
test("rmail is told to take it (a list carries no files)", got[1] == "accept")
local waiting = ben:pending()
test("one question waits for Ben", #waiting == 1 and waiting[1].sender == "ana" and waiting[1].missing == 3,
    tostring(waiting[1] and waiting[1].missing))
test("nothing was asked for yet", #boxes.ana == 0)
local words = exchange.prompt(waiting[1])
test("the prompt asks the one question", words[1] == "Use ana's models for this game?")
test("and names the map and each entry's provenance", words[2]:match("^Map: Castle Fight")
    and #words == 3 + #l.entries and table.concat(words, "\n"):match("hfoo uses units/knight/knight.mdx")
    and table.concat(words, "\n"):match("only from ana"))
-- }}}

-- {{{ Yes: only what's missing
print("\n=== On yes, only the missing files are asked for and sent ===")
local Bstore = dedup.open(B .. "/blobs")
-- Ben already has the horn
write(SCR .. "/horn.wav", "RIFF a horn")
Bstore:store_file(SCR .. "/horn.wav")
test("Ben answers yes: waiting for files", ben:answer(id, "yes") == "waiting")
test("the want names two hashes, not the horn's", #boxes.ana == 1 and select(2, boxes.ana[1].body:gsub("\n", "")) == 2
    and not boxes.ana[1].body:find(list.hash_file(SCR .. "/horn.wav"), 1, true))
got = deliver("ana", ana_hook)
test("Ana's hook takes the want", got[1] == "accept")
test("Ana replies with two attachments named by hash", #boxes.ben == 1 and #boxes.ben[1].attachments == 2
    and boxes.ben[1].attachments[1].name:match("^%x+$") and #boxes.ben[1].attachments[1].name == 64)
got = deliver("ben", ben_hook)
test("Ben's hook takes the files", got[1] == "accept", tostring(got[1]) .. " " .. table.concat(problems, "; "))
test("the list was applied: ready, with its profile", #ready == 1 and ready[1].P.types.hfoo == "units/knight/knight.mdx")
test("the profile holds the knight", read(ready[1].P.dir .. "/units/knight/knight.mdx") == "MDLX a knight, by Ana")
test("the arrived files were cleaned up", not exists(B .. "/share-incoming/" .. id))
ana:sent(id)
test("Ana's bundle can be cleaned up once sent", not exists(A .. "/share-outgoing/" .. id))
test("no question waits now", #ben:pending() == 0)
ready[1].P:revert()
-- }}}

-- {{{ No
print("\n=== On no, nothing is asked for ===")
local id2 = ana:offer("ben", l)
deliver("ben", ben_hook)
test("declined", ben:answer(id2, "no") == "declined" and #boxes.ana == 0 and #ben:pending() == 0)
test("a second answer is refused", ben:answer(id2, "yes") == nil)
-- }}}

-- {{{ Trusted: no prompt
print("\n=== A trusted sender's list applies without a prompt ===")
profile.trust(B):always_from("ana", true)
ben.trust = profile.trust(B)
local id3 = ana:offer("ben", l)
deliver("ben", ben_hook)
-- (the first game's files are still in Ben's store, so nothing need be sent)
test("no question, nothing to fetch: applied at once", #ben:pending() == 0 and #boxes.ana == 0
    and #ready == 2 and ready[2].q.trusted == true and ready[2].q.id == id3)
ready[2].P:revert()
profile.trust(B):always_from("ana", false)
ben.trust = profile.trust(B)
-- }}}

-- {{{ The consent callback answers now
print("\n=== A game that asks at once ===")
local asked
local ben2 = exchange.new({ data = B, me = "ben", transport = hook.transport(rmail_for("ben")),
                            consent = function(q) asked = q; return "no" end })
local id4 = ana:offer("ben", l)
deliver("ben", hook.on_receive(ben2))
test("consent got the question and its answer was used", asked and asked.id == id4 and #ben2:pending() == 0 and #boxes.ana == 0)
-- }}}

-- {{{ What each side refuses
print("\n=== What each side refuses ===")
ben.store:gc()      -- the stored files of the games above go, so they must be sent again
local id5 = ana:offer("ben", l)
-- Eve asks Ana for the files offered to Ben
local eve = rmail_for("eve")
eve.send({ to = "ana", subject = "wete-share want " .. id5, body = l.entries[1].hash .. "\n" })
test("Ana won't send files offered to Ben to Eve", deliver("ana", ana_hook)[1] == "decline" and #boxes.eve == 0)
-- Ben asks for a hash that isn't in the list
local other = "sha256:" .. string.rep("ab", 32)
rmail_for("ben").send({ to = "ana", subject = "wete-share want " .. id5, body = other .. "\n" })
test("nor a file that isn't in the list", deliver("ana", ana_hook)[1] == "decline" and #boxes.ben == 1)
deliver("ben", ben_hook)     -- the list itself; Ben hasn't answered
-- Eve sends Ben files he didn't ask her for
write(SCR .. "/evil", "MDLX not Ana's")
eve.send({ to = "ben", subject = "wete-share files " .. id5, attachments = { { name = string.rep("0", 64), path = SCR .. "/evil" } } })
test("Ben won't take files he didn't ask for", deliver("ben", ben_hook)[1] == "decline")
-- Ben says yes; Ana's files arrive but one was swapped on the way
ben:answer(id5, "yes")
deliver("ana", ana_hook)
local mail = boxes.ben[1]
write(SCR .. "/swapped", "MDLX swapped on the way")
mail.attachments[1].path = SCR .. "/swapped"
local n_ready = #ready
deliver("ben", ben_hook)
test("one bad file refuses the whole list", #ready == n_ready and problems[#problems]:match("refused whole"))
test("and nothing was applied", not exists(B .. "/profiles/share-" .. id5))
-- an attachment named like a path is never written outside
local id6 = ana:offer("ben", l)
deliver("ben", ben_hook)
ben:answer(id6, "yes")
deliver("ana", ana_hook)
boxes.ben[1].attachments[1].name = "../../escape"
deliver("ben", ben_hook)
test("an attachment named like a path is ignored", not exists(B .. "/escape") and not exists(SCR .. "/escape"))
local id7 = "eve-1"
eve.send({ to = "ben", subject = "wete-share list " .. id7, body = "return os.execute('touch " .. SCR .. "/ran')" })
test("a list that tries to run code is declined, and nothing ran", deliver("ben", ben_hook)[1] == "decline" and not exists(SCR .. "/ran"))
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
