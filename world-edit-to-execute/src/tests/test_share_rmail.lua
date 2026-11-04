#!/usr/bin/env luajit
-- test_share_rmail.lua - a shared list carried over rmail's real contract (issue 609b)
--
-- In plain terms: two mailboxes laid out the way rmail lays them out
-- (config, contacts, inbox/, outbox/, attachments/), and a small fake of
-- rmail's daemon that does what rmail does with them: sends outbox files,
-- runs the configured hook scripts with rmail's arguments, writes a consent
-- form for each attachment, reads the answer from the form, saves accepted
-- files, and drops an outbox file once its reader deleted their copy. A
-- list goes in one mail with its map and every file it names, and the
-- receiver takes only what it lacks by answering the forms. The
-- glue (share/rmail_hook.lua) only ever touches those files, so this is
-- the same conversation rmail would carry.
--
-- Run: luajit src/tests/test_share_rmail.lua [DIR]
-- Issue: issues/completed/609b-rmail-glue.md

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
package.path = DIR .. "/src/?.lua;" .. DIR .. "/src/?/init.lua;" .. package.path

local list = require("share.list")
local exchange = require("share.exchange")
local hook = require("share.rmail_hook")

local pass, fail = 0, 0
local function test(name, ok, msg)
    if ok then pass = pass + 1; print("  [PASS] " .. name)
    else fail = fail + 1; print("  [FAIL] " .. name .. (msg and (": " .. msg) or "")) end
end
local function sh(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end
local function run(cmd) local ok = os.execute(cmd); return ok == true or ok == 0 end
local function write(path, bytes)
    run("mkdir -p " .. sh(path:match("^(.*)/[^/]*$")))
    local f = assert(io.open(path, "wb")); f:write(bytes); f:close()
end
local function read(path) local f = io.open(path, "rb"); if not f then return nil end local t = f:read("*a"); f:close(); return t end
local function exists(path) return run("test -e " .. sh(path)) end
local function ls(dir)
    local out, p = {}, io.popen("ls -1A " .. sh(dir) .. " 2>/dev/null")
    for name in p:lines() do out[#out + 1] = name end
    p:close()
    table.sort(out)
    return out
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local SCR = os.tmpname()
os.remove(SCR)

-- {{{ a fake rmail daemon, working on files the way rmail does
local function mailbox(who, contacts)
    local mail = SCR .. "/mail-" .. who
    for _, d in ipairs({ "inbox", "outbox", "attachments" }) do run("mkdir -p " .. sh(mail .. "/" .. d)) end
    write(mail .. "/config", "# rmail config\nname = " .. who .. "\nport = 7700\n")
    write(mail .. "/contacts", contacts)
    return { name = who, mail = mail, config = mail .. "/config", sent = {}, records = {}, pending = {} }
end

-- rmail's sanitize_filename
local function sanitize(name)
    name = name:match("([^/\\]+)$") or name
    name = name:gsub("^%.+", ""):gsub("[%c/%\\%z]", "_"):gsub(" ", "-")
    return name ~= "" and name or "untitled"
end

-- rmail's hook rule: a relative path is from the config's folder
local function hook_of(box, which)
    local v = (read(box.config) or ""):match("\n" .. which .. "%s*=%s*([^\n]-)%s*\n")
    if not v or v == "" then return nil end
    if v:sub(1, 1) == "/" then return v end
    return box.mail .. "/" .. v:gsub("^%./", "")
end

local function run_hook(box, which, a, b, c)
    local h = hook_of(box, which)
    if h then run(h .. " " .. sh(a) .. " " .. sh(b) .. " " .. sh(c)) end   -- rmail adds " &"; here it waits
end

-- One send pass of FROM's daemon toward TO.
local function sync(from, to)
    for _, file in ipairs(ls(from.mail .. "/outbox")) do
        if not file:match("^%.") then
            local text = read(from.mail .. "/outbox/" .. file)
            local header, pos = {}, 1
            while pos <= #text do                        -- rmail's _scan_outbox_header
                local e = text:find("\n", pos) or #text + 1
                local line = text:sub(pos, e - 1)
                if line:lower():match("^to:") or line:lower():match("^attach:") or line:match("^%s*$") or line:match("^%s*//") then
                    header[#header + 1] = line
                    pos = e + 1
                else break end
            end
            local body = text:sub(pos):gsub("^[\n\r]+", "")
            for i, line in ipairs(header) do
                local name = line:match("^[Tt][Oo]:%s*(.-)%s*$")
                if name == to.name and not (from.sent[file] and from.sent[file][to.name]) then
                    local attach, held = {}, false
                    for j = i + 1, #header do
                        local a = header[j]:match("^[Aa][Tt][Tt][Aa][Cc][Hh]:%s*(.-)%s*$")
                        if a then attach[#attach + 1] = a; if not exists(a) then held = true end end
                    end
                    if not held then                     -- held back until every attached path exists
                        local inbox = sanitize(file)
                        local base, n = inbox, 2
                        while exists(to.mail .. "/inbox/" .. inbox) do inbox = base .. "-" .. n; n = n + 1 end
                        write(to.mail .. "/inbox/" .. inbox, body)
                        to.records[inbox] = { from = from, outbox = file }
                        from.sent[file] = from.sent[file] or {}
                        from.sent[file][to.name] = true
                        run_hook(to, "on_receive", from.name, file, to.mail .. "/inbox/" .. inbox)
                        for _, a in ipairs(attach) do
                            local fname = a:match("([^/]+)$")
                            local form = sanitize(inbox .. "-" .. fname .. "-consent-to-download-form")
                            write(to.mail .. "/inbox/" .. form, string.format(
                                "%s wants to send you an attachment.\n\n  Attached to:   %s\n  File:          %s\n" ..
                                "  Expected size: %s\n  Available:     %s on this drive\n  After:         %s remaining%s\n\n" ..
                                "Delete one line and leave your choice behind for the system to read:\n\naccept\ndeny",
                                from.name, inbox, fname, "1 KB", "9 GB", "9 GB", ""))
                            to.pending[form] = { from = from, src = a, filename = fname }
                        end
                    end
                end
            end
        end
    end
end

-- BOX's daemon reads its consent forms (rmail's check_consent_pending),
-- and saves what was accepted.
local function consent(box)
    for form, p in pairs(box.pending) do
        local text = read(box.mail .. "/inbox/" .. form)
        local yes, no = false, false
        for line in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do
            line = line:match("^%s*(.-)%s*$")
            if line == "accept" then yes = true end
            if line == "deny" then no = true end
        end
        if not text or (no and not yes) then
            box.pending[form] = nil
            os.remove(box.mail .. "/inbox/" .. form)
        elseif yes and not no then
            box.pending[form] = nil
            os.remove(box.mail .. "/inbox/" .. form)
            local name, n = p.filename, 2
            while exists(box.mail .. "/attachments/" .. name) do name = p.filename .. "-" .. n; n = n + 1 end
            local target = box.mail .. "/attachments/" .. name
            write(target, read(p.src))
            run_hook(box, "on_package", p.from.name, p.filename, target)
        end
    end
end

-- BOX's daemon notices inbox files deleted: the sender's to: line goes,
-- and an outbox file with no to: left goes too.
local function deletes(box)
    for inbox, r in pairs(box.records) do
        if not exists(box.mail .. "/inbox/" .. inbox) then
            box.records[inbox] = nil
            local path = r.from.mail .. "/outbox/" .. r.outbox
            local text = read(path)
            if text then
                local out, skip, left = {}, false, 0
                for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                    local to = line:match("^[Tt][Oo]:%s*(.-)%s*$")
                    if to then skip = (to == box.name); if not skip then left = left + 1 end end
                    if not skip then out[#out + 1] = line end
                end
                if left == 0 then os.remove(path) else write(path, table.concat(out, "\n")) end
            end
        end
    end
end
-- }}}

-- {{{ The two players
local ANA = mailbox("ana", "// rmail contacts\nben.ip    = 10.0.0.2\nben.port  = 7700\nben.token = \"aa\"\n")
local BEN = mailbox("ben", "// rmail contacts\nana.ip    = 10.0.0.1\nana.port  = 7700\nana.token = \"bb\"\n\n" ..
                           "eve.token = \"cc\"\neve.listen = true\n")
local EVE = mailbox("eve", "ben.token = \"cc\"\n")
-- Ben already had a hook of his own
write(BEN.mail .. "/hooks/notify.sh", "#!/bin/sh\nprintf '%s\\n' \"$2\" >> " .. sh(SCR .. "/notified") .. "\n")
run("chmod 755 " .. sh(BEN.mail .. "/hooks/notify.sh"))
write(BEN.config, read(BEN.config) .. "on_receive = ./hooks/notify.sh\n")

local A, B = SCR .. "/ana", SCR .. "/ben"
local MINE = A .. "/asset-packs/mine"
write(MINE .. "/Textures/Grass.tga", "grass by Ana")
write(MINE .. "/units/knight/knight.mdx", "MDLX a knight, by Ana")
write(SCR .. "/maps/castle.w3x", "a map's bytes")
local l = list.build({ map = SCR .. "/maps/castle.w3x", map_name = "Castle Fight", pack = MINE,
                       types = { hfoo = "units/knight/knight.mdx" }, author = "Ana", created = "2026-11-03" })
-- }}}

-- {{{ connect and install
print("\n=== Connecting to a mailbox ===")
test("connect needs a config and a data folder", hook.connect() == nil)
local none, why = hook.connect({ config = SCR .. "/nowhere/config", data = B })
test("no config: nil and why", none == nil and why:match("no rmail config"))
none, why = hook.connect({ config = BEN.config, data = SCR .. "/my games" })
test("a data folder rmail can't name unquoted is refused", none == nil and why:match("spaces"))
local CB = hook.connect({ config = BEN.config, data = B })
local CA = hook.connect({ config = ANA.config, data = A })
test("connects to Ben's and Ana's mailboxes", CB ~= nil and CA ~= nil)
local hooked, missing = CB:hooked()
test("not hooked up yet: both hooks are missing", hooked == false and #missing == 2)
local lines = CB:install()
local paths = CB:script_paths()
test("install gives the two config lines", lines == "on_receive = " .. paths.on_receive .. "\non_package = " .. paths.on_package .. "\n")
test("and writes the two scripts, runnable", run("test -x " .. sh(paths.on_receive)) and run("test -x " .. sh(paths.on_package)))
test("Ben's own on_receive is chained, not dropped", read(paths.on_receive):find(BEN.mail .. "/hooks/notify.sh", 1, true) ~= nil)
test("rmail's config is not edited", not read(BEN.config):find("share-mail", 1, true))
-- Ben puts the lines in his config (in place of his own on_receive)
write(BEN.config, read(BEN.config):gsub("on_receive = %./hooks/notify%.sh\n", "") .. lines)
test("once the lines are in, it's hooked up", CB:hooked() == true)
write(ANA.config, read(ANA.config) .. CA:install())
-- }}}

local ready, problems = {}, {}
local ana = exchange.new({ data = A, me = "ana", pack = MINE, transport = CA:transport(),
                           on_problem = function(id, what) problems[#problems + 1] = "ana: " .. what end })
local ben = exchange.new({ data = B, me = "ben", transport = CB:transport(),
                           on_ready = function(pack, q) ready[#ready + 1] = { pack = pack, q = q } end,
                           on_problem = function(id, what) problems[#problems + 1] = "ben: " .. what end })
local function find(events, event)
    for _, e in ipairs(events) do if e.event == event then return e end end
end
local function tally(events)
    local yes, no = 0, 0
    for _, e in ipairs(events) do
        if e.event == "consent" then if e.result == "accepted" then yes = yes + 1 else no = no + 1 end end
    end
    return yes, no
end
local function pending_forms(box)
    local n = 0
    for _, f in ipairs(ls(box.mail .. "/inbox")) do
        if f:match("consent%-to%-download%-form$") and (read(box.mail .. "/inbox/" .. f) or ""):match("\naccept\ndeny$") then n = n + 1 end
    end
    return n
end
local CASTLE = SCR .. "/maps/castle.w3x"
local MAPNAME = l.map.hash:sub(8) .. ".w3x"

-- {{{ Check out my map: one mail, and nothing comes back
print("\n=== Check out my map: the list, its files and the map in one mail ===")
ben.store:store_file(MINE .. "/Textures/Grass.tga")       -- Ben already has Ana's grass
local ok0, err0 = pcall(ana.offer, ana, "ben", l, SCR .. "/maps/nowhere.w3x")
test("a map that isn't the one the list names isn't sent", not ok0 and err0:match("hash differs"))
local id = ana:offer("ben", l, CASTLE)
local LIST = "wete-share-list-" .. id
local text = read(ANA.mail .. "/outbox/" .. LIST) or ""
local OUT = A:gsub("%p", "%%%0") .. "/share%-outgoing/" .. id:gsub("%p", "%%%0") .. "/"
test("one outbox file: the map and both files attached, then the map's line and the list",
    text:match("^to: ben\nattach: " .. OUT .. MAPNAME .. "\n") and select(2, text:gsub("attach: " .. OUT .. "%x+\n", "")) == 2
    and text:match("\n\nmap: " .. MAPNAME .. "\n%-%- A shared") ~= nil)
test("written whole (no temporary file left)", #ls(ANA.mail .. "/outbox") == 1)
-- someone else's attachment for Ben, which isn't the editor's business
write(SCR .. "/beach.jpg", "a photo")
write(ANA.mail .. "/outbox/holiday-photos", "to: ben\nattach: " .. SCR .. "/beach.jpg\n\nfrom the trip\n")
sync(ANA, BEN)
test("rmail delivers it, and Ben's own hook still ran", (read(SCR .. "/notified") or ""):find(LIST .. "\n", 1, true) ~= nil)
test("four consent forms wait in Ben's inbox", pending_forms(BEN) == 4)
test("nothing reads the inbox until the editor or launcher calls C:poll", #ben:pending() == 0
    and #ls(B .. "/share-mail") == 2 and exists(BEN.mail .. "/inbox/" .. LIST))
local ev = CB:poll(ben)
local q = ben:pending()[1]
test("the poll asks once, saying the map comes with the list", find(ev, "receive") and find(ev, "receive").result == "asking"
    and q and q.sender == "ana" and q.map_sent == true and q.map_held == false and q.missing == 1)
test("the forms wait for the answer, and the list mail stays", pending_forms(BEN) == 4 and exists(BEN.mail .. "/inbox/" .. LIST))
test("a poll before the answer changes nothing", #CB:poll(ben) == 0 and pending_forms(BEN) == 4)
test("Ben says yes, and nothing is sent back to Ana", ben:answer(id, "yes") == "waiting" and #ls(BEN.mail .. "/outbox") == 0)
ev = CB:poll(ben)
local yes, no = tally(ev)
test("the next poll accepts the map and the knight, and denies the grass Ben has", yes == 2 and no == 1)
local photo_form = BEN.mail .. "/inbox/holiday-photos-beach.jpg-consent-to-download-form"
test("and leaves the photo's form for Ben", (read(photo_form) or ""):match("\naccept\ndeny$") ~= nil)
consent(BEN)
test("rmail saves the two accepted files and notes them", #ls(BEN.mail .. "/attachments") == 2)
ev = CB:poll(ben)
local got = ready[1]
test("Ben's poll hands them over: the map checks out and the list is kept", find(ev, "files")
    and find(ev, "files").result == "ready" and #ready == 1 and got.q.id == id, table.concat(problems, "; "))
test("as a pack of Ben's own, the knight in it", got and read(got.pack .. "/units/knight/knight.mdx") == "MDLX a knight, by Ana")
test("and the map in Ben's maps folder", got and got.q.map_file and got.q.map_file:match("/maps/Castle Fight/Castle Fight%.w3x$")
    and list.hash_file(got.q.map_file) == l.map.hash)
test("the list mail and its files are cleared", not exists(BEN.mail .. "/inbox/" .. LIST) and #ls(BEN.mail .. "/attachments") == 0)
test("the photo is untouched", exists(photo_form))
deletes(BEN)
test("Ana's rmail drops the list from her outbox", not exists(ANA.mail .. "/outbox/" .. LIST))
ev = CA:poll(ana)
test("and Ana's poll frees her copies", find(ev, "sent") and find(ev, "sent").id == id and not exists(A .. "/share-outgoing/" .. id))
test("Ana never had share mail to answer", #ls(ANA.mail .. "/inbox") == 0)
-- }}}

-- {{{ Refusals
print("\n=== What's refused ===")
write(EVE.mail .. "/outbox/wete-share-list-eve-1-1", "to: ben\n\n" .. list.encode(l))
sync(EVE, BEN)
local before = #ben:pending()
ev = CB:poll(ben)
test("a list from a listen-only contact is refused", find(ev, "receive") and find(ev, "receive").err:match("listen%-only")
    and #ben:pending() == before and not exists(BEN.mail .. "/inbox/wete-share-list-eve-1-1"))

write(B .. "/share-mail/1-1-receive", "receive\nana\nwete-share-list-x\n../../etc\n" .. BEN.mail .. "/inbox/x\n")
ev = CB:poll(ben)
test("a record with a newline smuggled into it is dropped", #ev == 0 and not exists(B .. "/share-mail/1-1-receive"))

write(ANA.mail .. "/outbox/wete-share-want-x-1", "to: ben\n\n" .. l.entries[1].hash .. "\n")
sync(ANA, BEN)
ev = CB:poll(ben)
test("a want is no longer a share message: refused", find(ev, "receive") and find(ev, "receive").err:match("malformed")
    and not exists(BEN.mail .. "/inbox/wete-share-want-x-1"))

-- the same list and map again: Ben has it all, so nothing is downloaded
local id2 = ana:offer("ben", l, CASTLE)
sync(ANA, BEN); CB:poll(ben)
test("a list Ben holds whole: yes keeps it at once", ben:answer(id2, "yes") == "ready" and #ready == 2
    and ready[2].q.map_file == got.q.map_file, table.concat(problems, "; "))
ev = CB:poll(ben)
yes, no = tally(ev)
test("and its three forms are denied, the mail cleared", yes == 0 and no == 3 and not exists(BEN.mail .. "/inbox/wete-share-list-" .. id2))
consent(BEN)
test("so rmail saves nothing", #ls(BEN.mail .. "/attachments") == 0)

-- no: every form denied
local MINE2 = A .. "/asset-packs/second"
write(MINE2 .. "/units/peasant/peasant.mdx", "MDLX a peasant, by Ana")
write(MINE2 .. "/Textures/Stone.tga", "stone by Ana")
write(SCR .. "/maps/keep.w3x", "Castle Keep's own bytes")
local l3 = list.build({ map = SCR .. "/maps/keep.w3x", map_name = "Castle Keep", pack = MINE2,
                        types = { hpea = "units/peasant/peasant.mdx" }, author = "Ana", created = "2026-11-04" })
ana.pack = MINE2
local id3 = ana:offer("ben", l3, SCR .. "/maps/keep.w3x")
sync(ANA, BEN); CB:poll(ben)
test("Ben says no", ben:answer(id3, "no") == "declined")
ev = CB:poll(ben)
yes, no = tally(ev)
test("no denies the map's form and the files'", yes == 0 and no == 3 and not exists(BEN.mail .. "/inbox/wete-share-list-" .. id3))
consent(BEN)
test("so rmail never saves them", #ls(BEN.mail .. "/attachments") == 0 and #ready == 2)

-- a fake map, a swapped file and an extra one, written by hand
local function by_hand(name, l_, attach)
    local head = { "to: ben" }
    for _, a in ipairs(attach) do head[#head + 1] = "attach: " .. a end
    write(ANA.mail .. "/outbox/" .. name, table.concat(head, "\n") .. "\n\nmap: " .. l_.map.hash:sub(8) .. ".w3x\n" .. list.encode(l_))
end
local KEEPNAME = l3.map.hash:sub(8) .. ".w3x"
write(SCR .. "/fake/" .. KEEPNAME, "not Castle Keep at all")
-- (Ana's first models, which Ben holds, on Castle Keep: only the map is taken)
local l4 = list.build({ map = SCR .. "/maps/keep.w3x", map_name = "Castle Keep", pack = MINE, author = "Ana" })
by_hand("wete-share-list-ana-9-9", l4, { SCR .. "/fake/" .. KEEPNAME })
sync(ANA, BEN); CB:poll(ben)
ben:answer("ana-9-9", "yes")
CB:poll(ben); consent(BEN)
ev = CB:poll(ben)
test("a map whose bytes aren't the list's map hash refuses the whole list", find(ev, "files")
    and find(ev, "files").result == nil and find(ev, "files").err:match("doesn't match the hash") and #ready == 2)
test("nothing of the fake is kept", #ls(BEN.mail .. "/attachments") == 0 and not exists(B .. "/maps/Castle Keep")
    and not ben.store:exists(list.hash_file(SCR .. "/fake/" .. KEEPNAME)))

local hexes = {}
for _, e in ipairs(l3.entries) do hexes[e.hash:sub(8)] = e.key end
local attach = { SCR .. "/maps/keep.w3x" }
run("mkdir -p " .. sh(SCR .. "/swap"))
for hex, key in pairs(hexes) do
    write(SCR .. "/swap/" .. hex, key:match("peasant") and "MDLX swapped on the way" or "stone by Ana")
    attach[#attach + 1] = SCR .. "/swap/" .. hex
end
local extra = string.rep("e", 64)
write(SCR .. "/swap/" .. extra, "an extra")
attach[#attach + 1] = SCR .. "/swap/" .. extra
-- (the map goes out under its own name here, so it is renamed first)
write(SCR .. "/swap/" .. KEEPNAME, read(SCR .. "/maps/keep.w3x"))
attach[1] = SCR .. "/swap/" .. KEEPNAME
by_hand("wete-share-list-ana-9-10", l3, attach)
sync(ANA, BEN)
ev = CB:poll(ben)
local y0, n0 = tally(ev)
test("a file the list doesn't name is denied at once, before the answer", y0 == 0 and n0 == 1 and pending_forms(BEN) == 4)   -- three, and the photo
ben:answer("ana-9-10", "yes")
ev = CB:poll(ben)
yes, no = tally(ev)
test("on yes the map and its two files are accepted", yes == 3 and no == 0)
consent(BEN)
ev = CB:poll(ben)
test("one swapped file refuses the whole list", find(ev, "files") and find(ev, "files").err
    and find(ev, "files").err:match("refused whole") and #ready == 2)
test("and nothing is kept", not exists(B .. "/asset-packs/share-ana-9-10") and #ls(BEN.mail .. "/attachments") == 0)

by_hand("wete-share-list-ana-9-11", l, { CASTLE })
local wrong = read(ANA.mail .. "/outbox/wete-share-list-ana-9-11"):gsub("map: %x+", "map: " .. KEEPNAME)
write(ANA.mail .. "/outbox/wete-share-list-ana-9-11", wrong)
sync(ANA, BEN)
before = #ben:pending()
ev = CB:poll(ben)
test("a list naming another map than its own is refused, and its form denied", find(ev, "receive").err ~= nil
    and #ben:pending() == before and not exists(BEN.mail .. "/inbox/wete-share-list-ana-9-11")
    and (read(BEN.mail .. "/inbox/wete-share-list-ana-9-11-castle.w3x-consent-to-download-form") or ""):match("\ndeny\n$"))

local T = CA:transport()
local ok, err = pcall(T.send, "ben", { kind = "list", id = "big-1", text = string.rep("x", hook.MAX_BODY + 1) })
test("a list over rmail's one-message size is refused, not sent", not ok and err:match("over rmail's")
    and not exists(ANA.mail .. "/outbox/wete-share-list-big-1"))
write(ANA.mail .. "/outbox/wete-share-list-again-1", "to: ben\n\nx\n")
ok, err = pcall(T.send, "ben", { kind = "list", id = "again-1", text = list.encode(l) })
test("a message still in the outbox isn't written over", not ok and err:match("still in the outbox"))
ok = pcall(T.send, "../ben", { kind = "list", id = "x-2", text = list.encode(l) })
test("nor is mail sent to a name that isn't a contact's", not ok)
-- }}}

-- {{{ The mail format
print("\n=== The mail format ===")
local hex = l.entries[1].hash:sub(8)
local f = hook.read_form("ana wants to send you an attachment.\n\n  Attached to:   m\n  File:          " .. hex ..
                         "\n  Expected size: 1 KB\n\nDelete one line and leave your choice behind for the system to read:\n\naccept\ndeny")
test("rmail's consent form is read", f and f.from == "ana" and f.attached == "m" and f.file == hex)
test("an answered form isn't pending", hook.read_form("ana wants to send you an attachment.\n\n  Attached to: m\n  File: x\n\naccept") == nil)
local m = hook.decode({ subject = "wete-share-list-ana-1-2", body = "map: " .. MAPNAME .. "\n" .. list.encode(l), from = "ana",
                        attachments = { { name = MAPNAME, path = "/m" }, { name = hex, path = "/f" }, { name = "../x", path = "/x" } } })
test("a list's map and files come from its attachments in process", m and m.map.name == MAPNAME and m.map.path == "/m"
    and #m.files == 1 and m.files[1].path == "/f")
test("over rmail they come later: the list alone", hook.decode({ subject = "wete-share-list-a", body = list.encode(l) }).files[1] == nil)
test("only a list is a share message now", hook.decode({ subject = "wete-share-want-a", body = "" }) == nil
    and hook.decode({ subject = "wete-share-files-a", body = hex .. "\n" }) == nil)
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(("\nTests: %d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
