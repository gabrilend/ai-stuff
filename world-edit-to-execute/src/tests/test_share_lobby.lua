#!/usr/bin/env luajit
-- test_share_lobby.lua - the lobby's prompt for a shared list (issue 609c)
--
-- In plain terms: Ana shares her list with Ben. Ben's game shows one
-- dialog at a time: the question (Yes, No, always from Ana, always for
-- this map), then "Ana's models are in use" (Keep, OK), then any notice.
-- A yes puts the list on the loader for this game; End Game takes it off,
-- unless Ben kept it, which makes it an asset pack. A game that ended
-- without saying so is settled at the next start. The prompt on screen is
-- checked by its layout and its clicks, with a stand-in for the renderer.
--
-- Run: luajit src/tests/test_share_lobby.lua [DIR]
-- Issue: issues/completed/609c-the-lobby-prompt.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local list = require("share.list")
local exchange = require("share.exchange")
local hook = require("share.rmail_hook")
local profile = require("share.profile")
local lobby = require("share.lobby")
local share_prompt = require("ui.wc3.share_prompt")

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
write(SCR .. "/maps/castle.w3x", "a map's bytes")
local l = list.build({ map = SCR .. "/maps/castle.w3x", map_name = "Castle Fight", pack = MINE,
                       types = { hfoo = "units/knight/knight.mdx" }, author = "Ana", created = "2026-11-03" })

-- {{{ an in-process rmail (as in test_share_exchange.lua), and a loader that notes its layers
local boxes = { ana = {}, ben = {} }
local function rmail_for(me)
    return { send = function(mail) mail.from = me; table.insert(boxes[mail.to], mail) end }
end
local function deliver(who, X)
    local on_receive = hook.on_receive(X)
    while #boxes[who] > 0 do on_receive(table.remove(boxes[who], 1)) end
end
local layers = {}
local L = {
    push_layer = function(_, name, dir) layers[name] = dir; return 1 end,
    pop_layer = function(_, name) local was = layers[name] ~= nil; layers[name] = nil; return was end,
}
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
-- }}}

local ana = exchange.new({ data = A, me = "ana", pack = MINE, transport = hook.transport(rmail_for("ana")) })
local Lb = lobby.new({ data = B, me = "ben", transport = hook.transport(rmail_for("ben")), loader = L })
local ben = Lb.exchange

-- {{{ The question
print("\n=== A list arrives: one question ===")
test("nothing to show at first", Lb:dialog() == nil)
local id = ana:offer("ben", l)
deliver("ben", ben)
local d = Lb:dialog()
test("the question shows", d and d.kind == "question" and d.id == id and d.title == "Use ana's models for this game?")
test("with the map and each entry's provenance", d.lines[1]:match("^Map: Castle Fight")
    and table.concat(d.lines, "\n"):match("hfoo uses units/knight/knight.mdx") and table.concat(d.lines, "\n"):match("only from ana"))
local labels = {}
for _, b in ipairs(d.buttons) do labels[#labels + 1] = b.label end
test("and four answers", table.concat(labels, "|") == "Yes|No|Always from ana|Always for this map")
test("Yes asks Ana for the files", Lb:press(d, "yes") == "waiting" and #boxes.ana == 1)
test("the question is gone while they come", Lb:dialog() == nil)
deliver("ana", ana)
deliver("ben", ben)
d = Lb:dialog()
test("once applied, the list is on the loader", count(layers) == 1 and #Lb.applied == 1)
test("and the game says so", d and d.kind == "ready" and d.title == "ana's models are in use"
    and d.buttons[1].id == "keep" and d.buttons[2].id == "ok")
test("OK closes it", Lb:press(d, "ok") == "ok" and Lb:dialog() == nil)
-- }}}

-- {{{ After the game
print("\n=== After the game ===")
local P1 = Lb.applied[1].P
local result = Lb:end_game()
test("End Game takes the list off", count(layers) == 0 and #result == 1 and result[1].kept == nil
    and not exists(P1.dir) and #profile.leftovers(B) == 0)

local id2 = ana:offer("ben", l)
deliver("ben", ben)
Lb:press(Lb:dialog(), "yes")       -- Ben's store has the files now: applied at once
d = Lb:dialog()
test("a list whose files Ben has applies at once", d and d.kind == "ready" and d.id == id2 and #boxes.ana == 0)
local kept, name = Lb:press(d, "keep")
test("Keep is written down at once", kept == "kept" and name == "ana's models for Castle Fight"
    and read(B .. "/profiles/" .. Lb.applied[1].P.name .. ".keep") == name)
result = Lb:end_game()
test("and at End Game it becomes an asset pack", result[1].kept == B .. "/asset-packs/ana's models for Castle Fight"
    and read(B .. "/asset-packs/ana's models for Castle Fight/units/knight/knight.mdx") == "MDLX a knight, by Ana"
    and count(layers) == 0 and #profile.leftovers(B) == 0)
-- }}}

-- {{{ A game that ended without saying so
print("\n=== A game that ended without saying so ===")
local id3 = ana:offer("ben", l)
local id4 = ana:offer("ben", l)
deliver("ben", ben)
Lb:press(Lb:dialog(), "yes")
Lb:press(Lb:dialog(), "yes")
test("two lists applied", #Lb.applied == 2 and #profile.leftovers(B) == 2)
Lb:keep(id4)
-- the window closes: no end_game; the next start settles them
local Lb2 = lobby.new({ data = B, me = "ben", transport = hook.transport(rmail_for("ben")) })
local by = {}
for _, s in ipairs(Lb2.settled) do by[s.name] = s end
test("the next start reverts the one not kept", by["share-" .. id3] and by["share-" .. id3].kept == nil)
test("and keeps the other, under a free name", by["share-" .. id4] and by["share-" .. id4].kept
    == B .. "/asset-packs/ana's models for Castle Fight 2")
test("nothing is left applied", #profile.leftovers(B) == 0 and not exists(B .. "/profiles/share-" .. id4 .. ".keep"))
d = Lb2:dialog()
test("and the player is told what was kept", d and d.kind == "notice" and d.lines[1]:match("Castle Fight 2"))
Lb2:press(d, "ok")
test("a notice goes with OK", Lb2:dialog() == nil)
Lb = Lb2
ben = Lb.exchange
-- }}}

-- {{{ Always
print("\n=== Always from this player, always for this map ===")
local id5 = ana:offer("ben", l)
deliver("ben", ben)
test("'Always from ana' answers yes", Lb:press(Lb:dialog(), "always_player") ~= nil and #Lb.applied == 1)
test("and is remembered", profile.trust(B).players.ana == true)
Lb:press(Lb:dialog(), "ok")
local id6 = ana:offer("ben", l)
deliver("ben", ben)
d = Lb:dialog()
test("the next list from ana asks nothing", d and d.kind == "ready" and d.id == id6
    and d.lines[1] == "Applied without asking, as you chose.")
Lb:press(d, "ok")
Lb:end_game()
profile.trust(B):always_from("ana", false)
ben.trust = profile.trust(B)
local id7 = ana:offer("ben", l)
deliver("ben", ben)
Lb:press(Lb:dialog(), "always_map")
test("'Always for this map' is remembered by the map's hash", profile.trust(B).maps[l.map.hash] == true)
Lb:end_game()
profile.trust(B):always_for_map(l.map.hash, false)
ben.trust = profile.trust(B)
local id8 = ana:offer("ben", l)
deliver("ben", ben)
test("No: declined, nothing applied", Lb:press(Lb:dialog(), "no") == "declined" and #Lb.applied == 0 and Lb:dialog() == nil)
-- }}}

-- {{{ rmail, polled
print("\n=== Polling rmail ===")
local polls, hooked = 0, false
local C = {
    cfg = { name = "ben" },
    hooked = function() if hooked then return true end return false, { "on_receive", "on_package" } end,
    install = function() return "on_receive = /x/on_receive.sh\non_package = /x/on_package.sh\n" end,
    transport = function() return hook.transport(rmail_for("ben")) end,
    poll = function(_, X) polls = polls + 1; return {} end,
}
local Lc = lobby.new({ data = B, connection = C, poll_every = 5 })
d = Lc:dialog()
test("rmail without the hooks: the player is told the lines to add", d and d.kind == "notice"
    and table.concat(d.lines, "\n"):find("on_package = /x/on_package.sh", 1, true))
test("its name is the exchange's", Lc.exchange.me == "ben")
Lc:update(0.1)
Lc:update(2)
Lc:update(2)
test("polls at once, then every 5 seconds", polls == 1)
Lc:update(1)
test("and again after 5", polls == 2)
C.poll = function() error("the inbox can't be read") end
Lc:update(5)
Lc:press(Lc:dialog(), "ok")
d = Lc:dialog()
test("a poll that fails becomes a notice", d and d.kind == "notice" and d.lines[1]:match("can't be read"))
Lc:press(d, "ok")
-- a refused message becomes a notice too
hook.on_receive(Lc.exchange)({ subject = "wete-share-files-nobody-1", from = "eve", attachments = {} })
d = Lc:dialog()
test("a refused share mail becomes a notice", d and d.title == "A shared list was refused")
-- }}}

-- with the real glue (share/rmail_hook.lua) on a mailbox laid out like rmail's
local MAIL = SCR .. "/mail-ben"
os.execute("mkdir -p " .. sh(MAIL .. "/inbox") .. " " .. sh(MAIL .. "/outbox"))
write(MAIL .. "/config", "name = ben\nport = 7700\n")
local CR = assert(hook.connect({ config = MAIL .. "/config", data = B }))
local Lr = lobby.new({ data = B, connection = CR })
d = Lr:dialog()
test("with rmail's own glue, the lines to add are the real scripts'", d and d.kind == "notice"
    and table.concat(d.lines, "\n"):find("on_package = " .. B .. "/share-mail/hooks/on_package.sh", 1, true)
    and Lr.exchange.me == "ben")
test("and its first poll reads the (empty) mailbox", type(Lr:update(0)) == "table")
-- }}}

-- {{{ The prompt on screen
print("\n=== The prompt on screen (layout and clicks; not looked at) ===")
local ui = { ui_text_width = function(s, size) return #s * size * 0.5 end }
for _, f in ipairs({ "ui_rect", "ui_frame", "ui_text" }) do ui[f] = function() end end
local id9 = ana:offer("ben", l)
deliver("ben", ben)
d = Lb:dialog()
local box = share_prompt.layout(ui, d, 1280, 720)
test("the box is in the middle of the screen", box.x == 1280 / 2 - box.w / 2 and box.y >= 20 and box.y + box.h <= 720)
test("with four buttons, top to bottom", #box.buttons == 4 and box.buttons[2].y > box.buttons[1].y and box.buttons[4].id == "always_map")
local small = share_prompt.layout(ui, d, 800, 300)
test("on a small screen lines are cut and counted", small.y + small.h <= 300 and small.lines[#small.lines]:match("more lines"))
local hud = { r = { w = 1280, h = 720 }, share = Lb, ui = ui }
local b = box.buttons[1]
local input = { mx = b.x + 5, my = b.y + 5, lp = true, keys = { "ENTER", "a" } }
share_prompt.draw(hud, ui)
result = share_prompt.update(hud, input)
test("a click on Yes answers yes", result ~= nil and #Lb.applied == 1 and Lb:dialog().kind == "ready")
test("and the click and Enter don't reach the game", input.lp == nil and #input.keys == 1 and input.keys[1] == "a")
input = { mx = 0, my = 0, keys = { "ENTER" } }
share_prompt.update(hud, input)
test("Enter presses Keep on the ready dialog", Lb.applied[1].keep ~= nil and Lb:dialog() == nil)
local id10 = ana:offer("ben", l)
deliver("ben", ben)
input = { mx = 0, my = 0, keys = { "ESCAPE", "ENTER" }, lp = true }
share_prompt.update(hud, input)
test("no key answers a question", Lb:dialog() and Lb:dialog().kind == "question" and #input.keys == 0)
Lb:end_game()
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(("\nTests: %d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
