#!/usr/bin/env luajit
-- test_share_rmail.lua - a shared list carried over rmail's real contract (issue 609b)
--
-- In plain terms: two mailboxes laid out the way rmail lays them out
-- (config, contacts, inbox/, outbox/, attachments/), and a small fake of
-- rmail's daemon that does what rmail does with them: sends outbox files,
-- runs the configured hook scripts with rmail's arguments, writes a consent
-- form for each attachment, reads the answer from the form, saves accepted
-- files, and drops an outbox file once its reader deleted their copy. The
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
                           on_ready = function(P, q) ready[#ready + 1] = { P = P, q = q } end,
                           on_problem = function(id, what) problems[#problems + 1] = "ben: " .. what end })
local function find(events, event)
    for _, e in ipairs(events) do if e.event == event then return e end end
end

-- {{{ A list, a want, and the files, over rmail
print("\n=== A list goes over rmail and waits for Ben ===")
local id = ana:offer("ben", l)
local LIST = "wete-share-list-" .. id
local text = read(ANA.mail .. "/outbox/" .. LIST)
test("the offer is one outbox file named by its subject", text ~= nil and text:match("^to: ben\n\n%-%- A shared"))
test("written whole (no temporary file left)", #ls(ANA.mail .. "/outbox") == 1)
sync(ANA, BEN)
test("rmail delivers it, and Ben's own hook still ran", read(SCR .. "/notified") == LIST .. "\n")
test("the hook only noted it", #ls(B .. "/share-mail") == 2 and exists(BEN.mail .. "/inbox/" .. LIST))
local ev = CB:poll(ben)
test("Ben's poll hands it over: a question waits", find(ev, "receive") and find(ev, "receive").result == "asking"
    and #ben:pending() == 1 and ben:pending()[1].sender == "ana")
test("the share mail is cleared from Ben's inbox", not exists(BEN.mail .. "/inbox/" .. LIST))
deletes(BEN)
test("which lets Ana's rmail drop it from her outbox", not exists(ANA.mail .. "/outbox/" .. LIST))

print("\n=== Yes: a want, then the files, through consent forms ===")
test("Ben says yes", ben:answer(id, "yes") == "waiting")
local WANT = "wete-share-want-" .. id
text = read(BEN.mail .. "/outbox/" .. WANT) or ""
test("the want names both files", text:match("^to: ana\n\n") and select(2, text:gsub("sha256:", "")) == 2)
sync(BEN, ANA)
ev = CA:poll(ana)
local FILES = "wete-share-files-" .. id
text = read(ANA.mail .. "/outbox/" .. FILES) or ""
test("Ana's poll answers with the files attached", find(ev, "receive") and find(ev, "receive").result == true
    and select(2, text:gsub("\nattach: " .. A:gsub("%p", "%%%0") .. "/share%-outgoing/", "")) == 2)
deletes(ANA)
test("the bundle stays while rmail still needs it", #CA:poll(ana) == 0 and exists(A .. "/share-outgoing/" .. id))

-- someone else's attachment for Ben, which isn't the game's business
write(SCR .. "/beach.jpg", "a photo")
write(ANA.mail .. "/outbox/holiday-photos", "to: ben\nattach: " .. SCR .. "/beach.jpg\n\nfrom the trip\n")
sync(ANA, BEN)
local forms = {}
for _, n in ipairs(ls(BEN.mail .. "/inbox")) do if n:match("consent%-to%-download%-form$") then forms[#forms + 1] = n end end
test("three consent forms wait in Ben's inbox", #forms == 3)
ev = CB:poll(ben)
local accepted = 0
for _, e in ipairs(ev) do if e.event == "consent" and e.result == "accepted" then accepted = accepted + 1 end end
test("Ben's poll accepts the two files he asked Ana for", accepted == 2)
local photo_form = BEN.mail .. "/inbox/holiday-photos-beach.jpg-consent-to-download-form"
test("and leaves the photo's form for Ben", (read(photo_form) or ""):match("\naccept\ndeny$") ~= nil)
test("the files message waits for its files", exists(BEN.mail .. "/inbox/" .. FILES) and #ready == 0)
consent(BEN)
test("rmail saves both files and notes them", #ls(BEN.mail .. "/attachments") == 2)
ev = CB:poll(ben)
test("Ben's poll hands the files over: the list is ready", find(ev, "files") and find(ev, "files").result == "ready"
    and #ready == 1 and ready[1].q.id == id, table.concat(problems, "; "))
test("the files and the message are cleared", #ls(BEN.mail .. "/attachments") == 0 and not exists(BEN.mail .. "/inbox/" .. FILES))
test("the photo is untouched", exists(photo_form))
deletes(BEN)
test("Ana's rmail drops the files message", not exists(ANA.mail .. "/outbox/" .. FILES))
ev = CA:poll(ana)
test("and Ana's poll frees the bundle", find(ev, "sent") and find(ev, "sent").id == id and not exists(A .. "/share-outgoing/" .. id))
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

local id2 = ana:offer("ben", l)
sync(ANA, BEN)
CB:poll(ben)
test("Ben says no to a second list", ben:answer(id2, "no") == "declined")
local hex = l.entries[1].hash:sub(8)
write(SCR .. "/" .. hex, "not what you think")
write(ANA.mail .. "/outbox/wete-share-files-" .. id2, "to: ben\nattach: " .. SCR .. "/" .. hex .. "\n\n" .. hex .. "\n")
sync(ANA, BEN)
ev = CB:poll(ben)
local form2 = BEN.mail .. "/inbox/wete-share-files-" .. id2 .. "-" .. hex .. "-consent-to-download-form"
test("files for a list Ben declined are refused", find(ev, "receive") and find(ev, "receive").err ~= nil
    and not exists(BEN.mail .. "/inbox/wete-share-files-" .. id2))
test("and their form is denied", (read(form2) or ""):match("\ndeny\n$") and not (read(form2) or ""):match("\naccept"))
consent(BEN)
test("so rmail never saves the file", #ls(BEN.mail .. "/attachments") == 0)

-- a third list, with files Ben lacks; Ana's files message gets one extra
local MINE2 = A .. "/asset-packs/second"
write(MINE2 .. "/units/peasant/peasant.mdx", "MDLX a peasant, by Ana")
write(MINE2 .. "/Textures/Stone.tga", "stone by Ana")
local l3 = list.build({ map = SCR .. "/maps/castle.w3x", map_name = "Castle Fight", pack = MINE2,
                        types = { hpea = "units/peasant/peasant.mdx" }, author = "Ana", created = "2026-11-03" })
ana.pack = MINE2
local id3 = ana:offer("ben", l3)
sync(ANA, BEN); CB:poll(ben)
ben:answer(id3, "yes")
sync(BEN, ANA); CA:poll(ana)
local extra = string.rep("e", 64)
write(SCR .. "/" .. extra, "an extra")
local F3 = ANA.mail .. "/outbox/wete-share-files-" .. id3
write(F3, read(F3):gsub("\n\n", "\nattach: " .. SCR .. "/" .. extra .. "\n\n", 1))
sync(ANA, BEN)
ev = CB:poll(ben)
local yes3, no3 = 0, 0
for _, e in ipairs(ev) do
    if e.event == "consent" then if e.result == "accepted" then yes3 = yes3 + 1 else no3 = no3 + 1 end end
end
test("a file Ben didn't ask for is denied; the two he did are accepted", yes3 == 2 and no3 == 1)
consent(BEN)
ev = CB:poll(ben)
test("and the list is ready", find(ev, "files") and find(ev, "files").result == "ready" and #ready == 2,
    table.concat(problems, "; "))

local T = CA:transport()
local ok, err = pcall(T.send, "ben", { kind = "list", id = "big-1", text = string.rep("x", hook.MAX_BODY + 1) })
test("a list over rmail's one-message size is refused, not sent", not ok and err:match("over rmail's")
    and not exists(ANA.mail .. "/outbox/wete-share-list-big-1"))
write(ANA.mail .. "/outbox/wete-share-want-again-1", "to: ben\n\nx\n")
ok, err = pcall(T.send, "ben", { kind = "want", id = "again-1", hashes = { l.entries[1].hash } })
test("a message still in the outbox isn't written over", not ok and err:match("still in the outbox"))
ok = pcall(T.send, "../ben", { kind = "want", id = "x-2", hashes = { l.entries[1].hash } })
test("nor is mail sent to a name that isn't a contact's", not ok)
-- }}}

-- {{{ "Check out my map": the map goes in the list's message
print("\n=== Check out my map: the map file goes with its list ===")
local MINE4 = A .. "/asset-packs/keep"
write(MINE4 .. "/units/archer/archer.mdx", "MDLX an archer, by Ana")
write(SCR .. "/maps/keep.w3x", "Castle Keep's own bytes")
local l4 = list.build({ map = SCR .. "/maps/keep.w3x", map_name = "Castle Keep", pack = MINE4,
                        types = { hrif = "units/archer/archer.mdx" }, author = "Ana", created = "2026-11-04" })
local MAPNAME = l4.map.hash:sub(8) .. ".w3x"
ana.pack = MINE4
local ok4, err4 = pcall(ana.offer, ana, "ben", l4, SCR .. "/maps/castle.w3x")
test("a map that isn't the one the list names isn't sent", not ok4 and err4:match("hash differs"))
local id4 = ana:offer("ben", l4, SCR .. "/maps/keep.w3x")
local L4 = "wete-share-list-" .. id4
text = read(ANA.mail .. "/outbox/" .. L4) or ""
test("the list's one message names the map and attaches a copy of it",
    text:match("^to: ben\nattach: [^\n]*/share%-outgoing/" .. id4:gsub("%p", "%%%0") .. "%.map/" .. MAPNAME .. "\n\nmap: "
        .. MAPNAME .. "\n%-%- A shared") ~= nil)
sync(ANA, BEN)
local MAPFORM = BEN.mail .. "/inbox/" .. L4 .. "-" .. MAPNAME .. "-consent-to-download-form"
test("rmail delivers the list and a consent form for the map", exists(BEN.mail .. "/inbox/" .. L4) and exists(MAPFORM))
before = #ben:pending()
test("nothing reads the inbox until the editor or launcher calls C:poll", #ben:pending() == before
    and #ls(B .. "/share-mail") > 1)
ev = CB:poll(ben)
local q4 = ben:pending()[#ben:pending()]
test("the poll asks once, saying the map comes with the list", find(ev, "receive").result == "asking"
    and q4.id == id4 and q4.map_sent == true and q4.map_held == false)
test("the map's form waits for the answer, and the list mail stays",
    (read(MAPFORM) or ""):match("\naccept\ndeny$") ~= nil and exists(BEN.mail .. "/inbox/" .. L4))
test("a poll before the answer leaves the form alone", #CB:poll(ben) == 0 and (read(MAPFORM) or ""):match("\naccept\ndeny$"))
test("Ben says yes", ben:answer(id4, "yes") == "waiting")
ev = CB:poll(ben)
local c4 = find(ev, "consent")
test("the next poll accepts the map's form", c4 and c4.result == "accepted" and c4.file == MAPNAME
    and (read(MAPFORM) or ""):match("\naccept\n?$") ~= nil)
consent(BEN)
sync(BEN, ANA); CA:poll(ana); sync(ANA, BEN)
local nready = #ready
ev = CB:poll(ben)
test("the map came first and checks out; the list waits for its model", find(ev, "map")
    and find(ev, "map").result == "waiting" and #ready == nready, table.concat(problems, "; "))
consent(BEN)
ev = CB:poll(ben)
local got4 = ready[#ready]
test("with the model in, the list is ready", find(ev, "files") and find(ev, "files").result == "ready"
    and #ready == nready + 1 and got4.q.id == id4, table.concat(problems, "; "))
test("and the map is kept in Ben's maps folder", got4.q.map_file and got4.q.map_file:match("/maps/Castle Keep/Castle Keep%.w3x$")
    and list.hash_file(got4.q.map_file) == l4.map.hash)
test("the list mail and the map's file are cleared", not exists(BEN.mail .. "/inbox/" .. L4)
    and #ls(BEN.mail .. "/attachments") == 0)
deletes(BEN)
ev = CA:poll(ana)
local sent4
for _, e in ipairs(ev) do if e.event == "sent" and e.what == "map" then sent4 = e end end
test("Ana's poll frees the map's copy once rmail is done with it", sent4 and sent4.id == id4
    and not exists(A .. "/share-outgoing/" .. id4 .. ".map"))

print("\n=== What's refused, with a map ===")
-- the same map again: Ben has it, so it isn't downloaded twice
local id5 = ana:offer("ben", l4, SCR .. "/maps/keep.w3x")
sync(ANA, BEN); CB:poll(ben)
nready = #ready
test("a map Ben already has: yes is ready at once", ben:answer(id5, "yes") == "ready" and #ready == nready + 1
    and ready[#ready].q.map_file == got4.q.map_file)
local FORM5 = BEN.mail .. "/inbox/wete-share-list-" .. id5 .. "-" .. MAPNAME .. "-consent-to-download-form"
ev = CB:poll(ben)
test("and its form is denied, so it isn't sent again", find(ev, "map") and (read(FORM5) or ""):match("\ndeny\n$")
    and not (read(FORM5) or ""):match("accept") and not exists(BEN.mail .. "/inbox/wete-share-list-" .. id5))
consent(BEN)
test("rmail saves nothing", #ls(BEN.mail .. "/attachments") == 0)

-- a list whose map file doesn't have the hash the list gives
write(SCR .. "/maps/keep2.w3x", "a second keep")
local l6 = list.build({ map = SCR .. "/maps/keep2.w3x", map_name = "Castle Keep II", pack = MINE4, author = "Ana" })
local BADNAME = l6.map.hash:sub(8) .. ".w3x"
write(SCR .. "/fake/" .. BADNAME, "not the second keep at all")
write(ANA.mail .. "/outbox/wete-share-list-ana-9-9", "to: ben\nattach: " .. SCR .. "/fake/" .. BADNAME .. "\n\nmap: "
    .. BADNAME .. "\n" .. list.encode(l6))
sync(ANA, BEN); CB:poll(ben)
nready = #ready
test("Ben says yes to a list whose map is a fake", ben:answer("ana-9-9", "yes") == "waiting")
CB:poll(ben); consent(BEN)
ev = CB:poll(ben)
test("the map is checked against the list's hash and the list refused whole", find(ev, "map")
    and find(ev, "map").result == nil and find(ev, "map").err:match("doesn't match the hash") and #ready == nready)
test("nothing of the fake is kept", #ls(BEN.mail .. "/attachments") == 0 and not exists(B .. "/maps/Castle Keep II")
    and not ben.store:exists(list.hash_file(SCR .. "/fake/" .. BADNAME)))

-- declined: the map's form is denied
local id7 = ana:offer("ben", l6, SCR .. "/maps/keep2.w3x")
sync(ANA, BEN); CB:poll(ben)
ben:answer(id7, "no")
local FORM7 = BEN.mail .. "/inbox/wete-share-list-" .. id7 .. "-" .. BADNAME .. "-consent-to-download-form"
ev = CB:poll(ben)
test("no to a list denies its map's form", find(ev, "map") and (read(FORM7) or ""):match("\ndeny\n$")
    and not exists(BEN.mail .. "/inbox/wete-share-list-" .. id7))
-- a list naming a map that isn't its own
write(ANA.mail .. "/outbox/wete-share-list-ana-9-10", "to: ben\nattach: " .. SCR .. "/maps/keep.w3x\n\nmap: "
    .. MAPNAME .. "\n" .. list.encode(l6))
sync(ANA, BEN)
before = #ben:pending()
ev = CB:poll(ben)
test("a list naming another map than its own is refused, and its form denied", find(ev, "receive").err ~= nil
    and #ben:pending() == before and not exists(BEN.mail .. "/inbox/wete-share-list-ana-9-10")
    and (read(BEN.mail .. "/inbox/wete-share-list-ana-9-10-keep.w3x-consent-to-download-form") or ""):match("\ndeny\n$"))
-- }}}

-- {{{ The mail format
print("\n=== The mail format ===")
local f = hook.read_form("ana wants to send you an attachment.\n\n  Attached to:   m\n  File:          " .. hex ..
                         "\n  Expected size: 1 KB\n\nDelete one line and leave your choice behind for the system to read:\n\naccept\ndeny")
test("rmail's consent form is read", f and f.from == "ana" and f.attached == "m" and f.file == hex)
test("an answered form isn't pending", hook.read_form("ana wants to send you an attachment.\n\n  Attached to: m\n  File: x\n\naccept") == nil)
local m = hook.decode({ subject = "wete-share-files-ana-1-2", body = hex .. "\n", from = "ana" })
test("a files message over rmail names its files in the body", m and m.id == "ana-1-2" and m.files[1].name == hex and m.files[1].path == nil)
test("a files body with anything but names is malformed", hook.decode({ subject = "wete-share-files-a", body = "../x\n" }) == nil)
-- }}}

os.execute("rm -rf " .. sh(SCR))
print(("\nTests: %d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
