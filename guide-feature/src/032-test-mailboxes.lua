#!/usr/bin/env luajit
-- 032-test-mailboxes.lua
--
-- Tests the mailbox setup (031, scripts/make-mailboxes): the project's own
-- mailbox set reads back as kuvalu's guide mailbox and the three voices;
-- a set with a mistake is refused; building a set makes each folder with
-- rmail's config and contacts as rmail reads them, a secret for each pair
-- shared by both sides and different for every pair, kept private and never
-- printed, and each hook's wrapper; a second run changes nothing; a mailbox
-- already there is adopted with its secrets kept and nothing overwritten, and
-- a disagreement with it is refused before anything is written. Everything
-- is made in a throwaway folder.
--
-- For a general: every mailbox the canvases travel through is made the same
-- way from one list, and its secrets never land in the repository.
--
-- usage:
--   luajit 032-test-mailboxes.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/guide-feature"
for index = 1, #arg do
    if arg[index] == "--dir" then DIR = arg[index + 1] end
end
-- }}}

local ffi = require("ffi")
pcall(ffi.cdef, "int setenv(const char *name, const char *value, int overwrite);")
local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, ok, detail)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed = failed + 1
        io.write("  FAIL  ", name, detail and ("\n        " .. tostring(detail)) or "", "\n")
    end
end
-- }}}

-- {{{ small helpers
local function shell(command)
    local pipe = io.popen(command .. " 2>&1; echo \"exit:$?\"")
    local text = pipe:read("*a")
    pipe:close()
    local body, status = string.match(text, "^(.-)\n?exit:(%d+)\n$")
    return body, tonumber(status)
end
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "w"))
    handle:write(text)
    handle:close()
end
local function has(text, piece) return text ~= nil and string.find(text, piece, 1, true) ~= nil end
local function refused(text, piece)
    local path = os.tmpname()
    write(path, text)
    local ok, why = pcall(mailboxes.read_set, path, "the set")
    os.remove(path)
    return not ok and has(tostring(why), piece), why
end
local function mode(path) return (shell("stat -c %a '" .. path .. "'")) end
-- }}}

local TMP = shell("mktemp -d")
local PROJECT = TMP .. "/project"
shell("mkdir -p '" .. PROJECT .. "/scripts'")

io.write("\n=== the project's mailbox set ===\n")
-- {{{
local set = mailboxes.read_set(DIR .. "/input/mailboxes", "input/mailboxes")
check("it holds the guide mailbox and the three voices",
    table.concat(set.names, " ") == "fg-sora-1 fg-sora-2 fg-sora-3 guide")
local guide = set.mailboxes.guide
check("the guide mailbox: port 1223 on kuvalu, the arrival hook, its own folder apart from ~/mail",
    guide.port == 1223 and guide["local-ip"] == "192.168.1.100" and guide.hook == "arrival"
    and guide.folder ~= "~/mail" and not has(guide.folder .. "/", "~/mail/"))
check("each voice at its address and port, with the turn hook",
    set.mailboxes["fg-sora-1"].port == 10101 and set.mailboxes["fg-sora-2"].port == 20202
    and set.mailboxes["fg-sora-3"].port == 30303
    and set.mailboxes["fg-sora-3"]["local-ip"] == "192.168.1.13"
    and set.mailboxes["fg-sora-2"].hook == "turn")
local links = {}
for _, link in ipairs(set.links) do links[#links + 1] = link[1] .. "-" .. link[2] end
table.sort(links)
check("three links: the guide with each voice, and no voice with another",
    table.concat(links, " ") == "fg-sora-1-guide fg-sora-2-guide fg-sora-3-guide", table.concat(links, " "))
-- }}}

io.write("\n=== a set with a mistake is refused ===\n")
-- {{{
local GOOD = 'a.folder = "/x/a"\na.port = 1\na.ip = "127.0.0.1"\na.hook = "none"\n'
    .. 'a.contacts = "b"\nb.folder = "/x/b"\nb.port = 2\nb.ip = "127.0.0.1"\nb.hook = "none"\n'
check("a good small set reads", pcall(function()
    local path = os.tmpname()
    write(path, GOOD)
    local small = mailboxes.read_set(path)
    os.remove(path)
    assert(#small.links == 1)
end))
check("a mailbox with no folder", refused(string.gsub(GOOD, 'b.folder = "/x/b"\n', ""), "b has no b.folder"))
check("a mailbox with no address", refused(string.gsub(GOOD, 'b.ip = "127.0.0.1"\n', ""),
    "b has neither b.ip nor b.local-ip"))
check("a hook with nowhere to run it", refused(string.gsub(GOOD, 'b.hook = "none"', 'b.hook = "turn"'),
    "needs b.project"))
check("a port that cannot exist (the vision's 111213)",
    refused(string.gsub(GOOD, "b.port = 2", "b.port = 111213"), "ports run from 1 to 65535"))
check("a hook that is not one of the three", refused(string.gsub(GOOD, 'b.hook = "none"', 'b.hook = "send"'),
    "b.hook"))
check("a contact that is not in the set", refused(string.gsub(GOOD, 'contacts = "b"', 'contacts = "c"'),
    "names c, which is not a mailbox"))
check("a mailbox naming itself", refused(string.gsub(GOOD, 'contacts = "b"', 'contacts = "a"'),
    "names itself"))
check("two mailboxes at one address and port", refused(string.gsub(GOOD, "b.port = 2", "b.port = 1"),
    "both listen at 127.0.0.1:1"))
check("no contacts at all", refused(string.gsub(GOOD, 'a.contacts = "b"\n', ""), "none can talk"))
check("a line that is not a mailbox field", refused(GOOD .. 'a.colour = "red"\n', "a.colour"))
-- }}}

io.write("\n=== building a set ===\n")
-- {{{
local SET = TMP .. "/set"
local function set_text(folders)
    return table.concat({
        'hub.folder = "' .. folders .. '/hub"', "hub.port = 1223", 'hub.local-ip = "192.168.1.100"',
        'hub.hook = "arrival"', 'hub.project = "' .. PROJECT .. '"', 'hub.contacts = "v1 v2"',
        'v1.folder = "' .. folders .. '/v1"', "v1.port = 10101", 'v1.local-ip = "192.168.1.11"',
        'v1.hook = "turn"', 'v1.project = "' .. PROJECT .. '"', 'v1.contacts = "hub"',
        'v2.folder = "~/v2"', "v2.port = 20202", 'v2.ip = "127.0.0.1"', 'v2.hook = "none"', "" }, "\n")
end
write(SET, set_text(TMP .. "/boxes"))
ffi.C.setenv("HOME", TMP .. "/home", 1)
local out, status = shell("'" .. DIR .. "/scripts/make-mailboxes' '" .. PROJECT
    .. "' --set '" .. SET .. "'")
-- the throwaway project needs the real src and libs to run the script
check("the project given has to be the project", status ~= 0)
shell("ln -s '" .. DIR .. "/src' '" .. PROJECT .. "/src' && ln -s '" .. DIR .. "/libs' '"
    .. PROJECT .. "/libs'")
out, status = shell("'" .. DIR .. "/scripts/make-mailboxes' '" .. PROJECT .. "' --set '" .. SET .. "'")
check("scripts/make-mailboxes makes every mailbox of the set and says where",
    status == 0 and has(out, "hub: made at " .. TMP .. "/boxes/hub")
    and has(out, "v2: made at " .. TMP .. "/home/v2"), out)

local hub, v1, v2 = TMP .. "/boxes/hub", TMP .. "/boxes/v1", TMP .. "/home/v2"
local config = mailboxes.read_config(hub .. "/config")
check("the config, as rmail reads it: its name, its port, no port mapping",
    config and config.name == "hub" and config.port == "1223" and config.auto_port_forward == "false")
check("both hooks run the mailbox's own wrapper, told apart by a word in the config line",
    config.on_receive == "./hooks/guide-hook receive" and config.on_update == "./hooks/guide-hook update")
check("the config has no inline comments or quotes, which rmail would keep as part of a value",
    not string.find(slurp(hub .. "/config"), "[^\n]+=[^\n]*[#\"]"))
check("a mailbox with no hook has no hook lines", mailboxes.read_config(v2 .. "/config").on_update == nil)
local contacts = mailboxes.read_contacts(hub .. "/contacts")
check("the hub's contacts: each voice at its address and port",
    contacts.v1["local-ip"] == "192.168.1.11" and contacts.v1.port == "10101"
    and contacts.v2.ip == "127.0.0.1" and contacts.v2.port == "20202" and contacts.v1.ip == nil)
local t1, t2 = contacts.v1.token, contacts.v2.token
check("each pair's secret is 64 hex digits", string.match(t1 or "", "^%x+$") and #t1 == 64 and #t2 == 64)
check("both sides of a pair hold the same secret",
    mailboxes.read_contacts(v1 .. "/contacts").hub.token == t1
    and mailboxes.read_contacts(v2 .. "/contacts").hub.token == t2)
check("and every pair a different one", t1 ~= t2)
local _, token_lines = string.gsub(slurp(hub .. "/contacts"), "\nv1%.token", "")
check("a pair named on both sides is one link: one secret line each side", token_lines == 1, token_lines)
check("a voice knows only the mailboxes it is linked with",
    mailboxes.read_contacts(v1 .. "/contacts").v2 == nil)
check("no secret is printed", not has(out, t1) and not has(out, t2))
check("contacts are private to the owner (600), the mailbox folder too (700)",
    mode(hub .. "/contacts") == "600" and mode(hub) == "700")
check("inbox and outbox are made", shell("test -d '" .. hub .. "/inbox' && test -d '" .. hub
    .. "/outbox' && echo yes") == "yes")
write(PROJECT .. "/scripts/arrival-hook", '#!/bin/sh\nprintf "arrival"; printf "|%s" "$@"\n')
write(PROJECT .. "/scripts/turn-hook", '#!/bin/sh\necho "turn $*"\n')
shell("chmod +x '" .. PROJECT .. "/scripts/arrival-hook' '" .. PROJECT .. "/scripts/turn-hook'")
check("the hub's wrapper runs the project's arrival hook with rmail's arguments, as given",
    (shell("'" .. hub .. "/hooks/guide-hook' update 'v1' '/in box/canvas' 'two words'"))
        == "arrival|update|v1|/in box/canvas|two words")
check("a voice's wrapper runs the turn hook",
    (shell("'" .. v1 .. "/hooks/guide-hook' receive hub the-canvas /x")) == "turn receive hub the-canvas /x")
-- }}}

io.write("\n=== again, and adopting ===\n")
-- {{{
local before = slurp(hub .. "/config") .. slurp(hub .. "/contacts") .. slurp(v1 .. "/contacts")
out, status = shell("'" .. DIR .. "/scripts/make-mailboxes' '" .. PROJECT .. "' --set '" .. SET .. "'")
check("a second run finds everything as the set has it and changes nothing",
    status == 0 and has(out, "hub: already as this set has it")
    and slurp(hub .. "/config") .. slurp(hub .. "/contacts") .. slurp(v1 .. "/contacts") == before, out)

-- a hub the owner made by hand, knowing v1 already
local OWN = TMP .. "/own"
shell("mkdir -p '" .. OWN .. "/hub'")
local own_config = "# my guide mailbox\nname = hub\nport = 1223\nlog_file = \"/tmp/hub.log\"\n"
local own_contacts = '// mine\nv1.local-ip = "192.168.1.11"\nv1.port = 10101\nv1.token = "kept-secret"\n'
write(OWN .. "/hub/config", own_config)
write(OWN .. "/hub/contacts", own_contacts)
write(SET, set_text(OWN))
ffi.C.setenv("HOME", TMP .. "/home2", 1)
local report = mailboxes.build(mailboxes.read_set(SET), { root = PROJECT, now = "2026-11-05" })
check("a mailbox already there is adopted, the others made",
    report.hub.adopted and report.v1.made and report.v2.made)
local adopted = slurp(OWN .. "/hub/config")
check("what the owner wrote is kept as it was, at the top",
    string.sub(adopted, 1, #own_config) == own_config
    and string.sub(slurp(OWN .. "/hub/contacts"), 1, #own_contacts) == own_contacts)
check("only what was missing is added, under a dated note",
    has(adopted, "\n# added by guide-feature's scripts/make-mailboxes on 2026-11-05 (issue 301)\n"
        .. "auto_port_forward = false\non_receive = ./hooks/guide-hook receive\n")
    and not has(string.sub(adopted, #own_config + 1), "name = hub"))
check("its secret is kept, and given to the other side",
    mailboxes.read_contacts(OWN .. "/hub/contacts").v1.token == "kept-secret"
    and mailboxes.read_contacts(OWN .. "/v1/contacts").hub.token == "kept-secret")
check("the report lists what was added without the secret",
    has(table.concat(report.hub.added, "\n"), "contacts: v2.token = (a secret)")
    and not has(table.concat(report.hub.added, "\n"), "kept-secret"))

-- disagreements, refused before anything is written
local function refuses(config_text, contacts_text, piece)
    local here = TMP .. "/clash" .. tostring(math.random(1e9))
    shell("mkdir -p '" .. here .. "/hub'")
    if config_text then write(here .. "/hub/config", config_text) end
    if contacts_text then write(here .. "/hub/contacts", contacts_text) end
    write(SET, set_text(here))
    local ok, why = pcall(mailboxes.build, mailboxes.read_set(SET), { root = PROJECT })
    local untouched = slurp(here .. "/hub/config") == config_text
        and shell("test -e '" .. here .. "/v1' && echo made") == ""
    return not ok and has(tostring(why), piece) and untouched, why
end
check("a port the owner set otherwise is refused, naming both, and nothing is written",
    refuses("name = hub\nport = 1224\n", nil, "config has port = 1224; this set wants 1223"))
check("an address otherwise is refused", refuses("name = hub\n",
    'v1.local-ip = "192.168.1.99"\n', "v1.local-ip = 192.168.1.99; this set wants 192.168.1.11"))
local other = TMP .. "/other"
shell("mkdir -p '" .. other .. "/hub' '" .. other .. "/v1'")
write(other .. "/hub/contacts", 'v1.token = "secret-one"\n')
write(other .. "/v1/contacts", 'hub.token = "secret-two"\n')
write(SET, set_text(other))
local ok, why = pcall(mailboxes.build, mailboxes.read_set(SET), { root = PROJECT })
check("two sides holding different secrets for each other are refused, neither shown",
    not ok and has(tostring(why), "already hold different secrets") and not has(tostring(why), "secret-one")
    and not has(tostring(why), "secret-two"), why)
write(SET, set_text(PROJECT .. "/mail"))
ok, why = pcall(mailboxes.build, mailboxes.read_set(SET), { root = PROJECT })
check("a mailbox inside the project is refused, so no secret lands in the repository",
    not ok and has(tostring(why), "is inside this project")
    and shell("test -e '" .. PROJECT .. "/mail' && echo made") == "", why)
write(SET, string.gsub(set_text(TMP .. "/same"), "same/v1", "same/hub"))
ok, why = pcall(mailboxes.build, mailboxes.read_set(SET), { root = PROJECT })
check("two mailboxes in one folder are refused", not ok and has(tostring(why), "share the folder"), why)
-- }}}

shell("rm -rf '" .. TMP .. "'")
io.write(string.format("\nTests: %d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
