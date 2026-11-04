#!/usr/bin/env luajit
-- test_share_exchange.lua - a shared list carried between two players (issue 609a)
--
-- In plain terms: Ana sends Ben her list in one message, with every file
-- it names and the map; Ben's editor reads it (never runs it) and asks him
-- first, unless he trusts Ana or the map; on yes it takes only the files
-- his store lacks, checks the map against the list's hash and every file
-- against its own, and keeps the list as a pack. Nothing goes back to Ana.
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
                           on_ready = function(pack, q) ready[#ready + 1] = { pack = pack, q = q } end,
                           on_problem = function(id, what) problems[#problems + 1] = "ben: " .. what end })
local ana_hook, ben_hook = hook.on_receive(ana), hook.on_receive(ben)

-- {{{ connect and the mail format
print("\n=== The rmail glue ===")
local ok_c, why = hook.connect({ config = SCR .. "/no-such-mailbox/config", data = B })
test("connecting where there's no rmail mailbox says why", ok_c == nil and why:match("no rmail config"))
test("only a list has a mail form", not pcall(hook.encode, { kind = "want", id = "x-1", hashes = {} }))
test("a mail that isn't ours is left to rmail", ben_hook({ subject = "lunch?", body = "", from = "ana" }) == nil)
test("a share subject with a bad id is declined", ben_hook({ subject = "wete-share list ../x", body = "", from = "ana" }) == "decline")
test("a want is declined: nothing is asked of a sharer now",
    ana_hook({ subject = "wete-share want x-1", body = l.entries[1].hash .. "\n", from = "ben" }) == "decline")
-- }}}

-- {{{ Asked first, by default
print("\n=== A list from someone not trusted waits for the player ===")
local CASTLE = SCR .. "/maps/castle.w3x"
local id = ana:offer("ben", l, CASTLE)
test("the offer goes out as one mail: the list, the map and its three files", #boxes.ben == 1
    and boxes.ben[1].subject == "wete-share-list-" .. id and #boxes.ben[1].attachments == 4
    and boxes.ben[1].attachments[1].name == l.map.hash:sub(8) .. ".w3x" and boxes.ben[1].body:match("^map: %x+%.w3x\n"))
local mail0 = boxes.ben[1]
local got = deliver("ben", ben_hook)
test("rmail is told to take it", got[1] == "accept")
local waiting = ben:pending()
test("one question waits for Ben", #waiting == 1 and waiting[1].sender == "ana" and waiting[1].missing == 3
    and waiting[1].map_sent and not waiting[1].map_held, tostring(waiting[1] and waiting[1].missing))
test("nothing goes back to Ana", #boxes.ana == 0)
test("before the answer nothing is wanted yet", ben:wants(id, "ana", l.entries[1].hash:sub(8)) == nil
    and ben:wants_map(id, "ana") == nil and ben:awaiting(id, "ana") == nil)
local words = exchange.prompt(waiting[1])
test("the prompt asks the one question", words[1] == "Keep ana's models for this map?")
test("and names the map and each entry's provenance", words[2]:match("^Map: Castle Fight")
    and #words == 3 + #l.entries and table.concat(words, "\n"):match("hfoo uses units/knight/knight.mdx")
    and table.concat(words, "\n"):match("only from ana"))
-- }}}

-- {{{ Yes: only what's missing
print("\n=== On yes, only the missing files are taken ===")
local Bstore = dedup.open(B .. "/blobs")
-- Ben already has the horn
write(SCR .. "/horn.wav", "RIFF a horn")
Bstore:store_file(SCR .. "/horn.wav")
ben.store:load()
local horn = list.hash_file(SCR .. "/horn.wav"):sub(8)
test("Ben answers yes: kept at once, the files having come with the list", ben:answer(id, "yes") == "ready",
    table.concat(problems, "; "))
test("the horn he has isn't taken", ben:wants(id, "ana", horn) == false)
test("the list was kept: ready, as a pack of Ben's own", #ready == 1 and ready[1].pack == B .. "/asset-packs/share-" .. id,
    tostring(ready[1] and ready[1].pack))
test("the pack holds the knight", read(ready[1].pack .. "/units/knight/knight.mdx") == "MDLX a knight, by Ana")
test("and the map is kept in Ben's maps folder", ready[1].q.map_file:match("/maps/Castle Fight/Castle Fight%.w3x$")
    and read(ready[1].q.map_file) == "a map's bytes")
test("the arrived files were cleaned up", not exists(B .. "/share-incoming/" .. id))
test("nothing goes back to Ana, even now", #boxes.ana == 0)
ana:sent(id)
test("Ana's copies can be cleaned up once sent", not exists(A .. "/share-outgoing/" .. id))
test("no question waits now", #ben:pending() == 0)
-- }}}

-- {{{ No
print("\n=== On no, nothing is taken ===")
local id2 = ana:offer("ben", l, CASTLE)
deliver("ben", ben_hook)
test("declined", ben:answer(id2, "no") == "declined" and #boxes.ana == 0 and #ben:pending() == 0
    and ben:wants_map(id2, "ana") == false and #ben:awaiting(id2, "ana") == 0)
test("a second answer is refused", ben:answer(id2, "yes") == nil)
-- }}}

-- {{{ Trusted: no prompt
print("\n=== A trusted sender's list is kept without a prompt ===")
profile.trust(B):always_from("ana", true)
ben.trust = profile.trust(B)
local id3 = ana:offer("ben", l)
deliver("ben", ben_hook)
-- (the first list's files are still in Ben's store, so nothing need be taken)
test("no question, nothing to take: kept at once", #ben:pending() == 0 and #boxes.ana == 0
    and #ready == 2 and ready[2].q.trusted == true and ready[2].q.id == id3
    and read(ready[2].pack .. "/units/knight/knight.mdx") == "MDLX a knight, by Ana")
profile.trust(B):always_from("ana", false)
ben.trust = profile.trust(B)
-- }}}

-- {{{ The consent callback answers now
print("\n=== An editor that asks at once ===")
local asked
local ben2 = exchange.new({ data = B, me = "ben", transport = hook.transport(rmail_for("ben")),
                            consent = function(q) asked = q; return "no" end })
local id4 = ana:offer("ben", l)
deliver("ben", hook.on_receive(ben2))
test("consent got the question and its answer was used", asked and asked.id == id4 and #ben2:pending() == 0 and #boxes.ana == 0)
-- }}}

-- {{{ What is refused
print("\n=== What is refused ===")
-- Ben deletes the packs kept above, so their stored files go and must be taken again
os.execute("rm -rf " .. sh(B .. "/asset-packs") .. " " .. sh(B .. "/maps"))
ben.store:gc()
-- a file swapped on the way
local id5 = ana:offer("ben", l)
local mail = boxes.ben[1]
write(SCR .. "/swapped", "MDLX swapped on the way")
mail.attachments[1].path = SCR .. "/swapped"
deliver("ben", ben_hook)
local n_ready = #ready
ben:answer(id5, "yes")
test("one bad file refuses the whole list", #ready == n_ready and problems[#problems]:match("refused whole"))
test("and nothing was kept", not exists(B .. "/asset-packs/share-" .. id5))
-- Eve sends files under Ana's list's id
write(SCR .. "/evil", "MDLX not Ana's")
local eve = rmail_for("eve")
local id6 = ana:offer("ben", l)
deliver("ben", ben_hook)
ben:answer(id6, "no")
test("files from anyone but the list's sender are refused",
    ben:on_message({ kind = "files", from = "eve", id = id6, files = { { name = l.entries[1].hash:sub(8), path = SCR .. "/evil" } } }) == nil)
test("and a file not in the list is never wanted", ben:wants(id6, "ana", string.rep("0", 64)) == false)
-- an attachment named like a path is never written outside
local id7 = ana:offer("ben", l)
boxes.ben[1].attachments[1].name = "../../escape"
deliver("ben", ben_hook)
ben:answer(id7, "yes")
test("an attachment named like a path is ignored", not exists(B .. "/escape") and not exists(SCR .. "/escape"))
local id8 = "eve-1"
eve.send({ to = "ben", subject = "wete-share list " .. id8, body = "return os.execute('touch " .. SCR .. "/ran')" })
test("a list that tries to run code is declined, and nothing ran", deliver("ben", ben_hook)[1] == "decline" and not exists(SCR .. "/ran"))
-- }}}

-- {{{ Check out my map: the map checked against the list (issue 609b)
print("\n=== The map file goes with its list ===")
write(SCR .. "/maps/keep.w3m", "Castle Keep's bytes")
local lk = list.build({ map = SCR .. "/maps/keep.w3m", map_name = "Castle Keep", pack = MINE, author = "Ana" })
local okk, errk = pcall(ana.offer, ana, "ben", lk, CASTLE)
test("a map that isn't the list's isn't sent", not okk and errk:match("hash differs"))
local idk = ana:offer("ben", lk, SCR .. "/maps/keep.w3m")
test("the map keeps its extension, named by hash", boxes.ben[1].attachments[1].name == lk.map.hash:sub(8) .. ".w3m")
deliver("ben", ben_hook)
n_ready = #ready
ben:answer(idk, "yes")
test("on yes the map is checked and kept beside the models", #ready == n_ready + 1
    and ready[#ready].q.map_file:match("/maps/Castle Keep/Castle Keep%.w3m$")
    and read(ready[#ready].q.map_file) == "Castle Keep's bytes", table.concat(problems, "; "))
test("and isn't wanted again", ben:wants_map(idk, "ana") == false)
-- a map swapped on the way
write(SCR .. "/maps/keep2.w3x", "a second keep")
local lk2 = list.build({ map = SCR .. "/maps/keep2.w3x", map_name = "Keep Two", pack = MINE, author = "Ana" })
local idk2 = ana:offer("ben", lk2, SCR .. "/maps/keep2.w3x")
write(SCR .. "/swapped-map", "not the second keep")
boxes.ben[1].attachments[1].path = SCR .. "/swapped-map"
deliver("ben", ben_hook)
n_ready = #ready
ben:answer(idk2, "yes")
test("a map that doesn't match the list's hash refuses the whole list", #ready == n_ready
    and problems[#problems]:match("doesn't match the hash") and not exists(B .. "/maps/Keep Two"))
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(string.format("\nTests: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
