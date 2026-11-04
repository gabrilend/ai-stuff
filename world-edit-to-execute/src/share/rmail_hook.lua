--[[
rmail Glue for Shared Lists (Issues 609a, 609b)

Carries share/exchange.lua's messages over rmail, Ritz's mail program (its
own repository, gabrilend/r-mail). 609a wrote this file against an assumed
contract; 609b read rmail and replaced the stub with the real one. Which
assumptions held is in issues/completed/609b-rmail-glue.md.

How rmail really works, as far as this file cares:

  hooks      rmail runs an executable named in its config, with shell
             arguments, in the background, and ignores what it prints:
               on_receive  $1 sender, $2 subject, $3 the inbox file
               on_package  $1 sender, $2 file name, $3 the saved file
             A hook can't answer rmail, and can't call into a running program.
  sender     $1 is the contact whose token decrypted the request. A
             contact marked `listen = true` is a door anyone may hold the
             token to, so its mail is refused here.
  sending    a file in the mailbox's outbox/, named by its subject:
             `to: name` and `attach: /path` lines, then the body.
  consent    each attachment first puts a form in the inbox,
             `<message>-<file>-consent-to-download-form`, ending in the
             lines `accept` and `deny`; deleting `deny` accepts.
  subjects   a subject becomes a file name: spaces turn into dashes.
  bodies     over 128 KiB a body is sent as an attachment instead.

So the glue has two halves. Two small hook scripts (written by C:install,
and named in rmail's config by the person) drop a record of each share
mail and each arriving file into <data>/share-mail/. The editor or the
launcher calls C:poll(X) when it wants to know: it reads those records,
hands messages to the exchange, answers consent forms for files the
exchange asked that sender for (and denies the rest), and tidies up what
it has handled. Nothing calls it on a timer: share mail only comes when a
map is shared ("check out my map", issue 609), so the inbox is read when
the person opens the editor or launcher, asks it to look, or answers a
question, and at no other time. Between calls the records just wait.

    local hook = require("share.rmail_hook")
    local C = assert(hook.connect({ config = "~/mail/config", data = data }))
    print(C:install())                 -- the config lines for the person to add
    local X = exchange.new({ ..., transport = C:transport() })
    C:poll(X)                          -- when the editor or launcher opens, or the person asks
    X:answer(id, "yes"); C:poll(X)     -- after an answer, so the map's form is answered now

In-process forms, for tests and any mail program that calls Lua directly:

    hook.transport(rmail)              -- sends through rmail.send(mail)
    hook.on_receive(X)                 -- on_receive(mail): "accept", "decline" or nil
    hook.encode(msg) / hook.decode(mail)

A share mail's subject is "wete-share-<kind>-<id>". A list's body is the
list file (data, never run), after a first line "map: <hex>.<ext>" when
the map file travels with it as the mail's one attachment. A want's body
is one hash a line, and a files message's body names its files (each a
hash's hex); the files travel as attachments.
]]

local hook = {}

hook.SUBJECT = "wete-share"
hook.MAX_BODY = 131072        -- rmail sends a longer body as an attachment (its #308)
hook.MAX_FILES = 4096         -- names in one files message
hook.FORM = "-consent-to-download-form"

-- {{{ local helpers
local function sh(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function run(cmd)
    local ok = os.execute(cmd)
    return ok == true or ok == 0
end

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end

local function write(path, bytes)
    local f, err = io.open(path, "wb")
    if not f then return nil, err end
    f:write(bytes)
    f:close()
    return true
end

local function is_file(path) return run("test -f " .. sh(path)) end
local function is_dir(path) return run("test -d " .. sh(path)) end

local function list_dir(dir)
    local out = {}
    local p = io.popen("ls -1A " .. sh(dir) .. " 2>/dev/null")
    if not p then return out end
    for name in p:lines() do out[#out + 1] = name end
    p:close()
    table.sort(out)
    return out
end

local function dirname(path) return path:match("^(.*)/[^/]*$") or "." end
local function basename(path) return path:match("([^/]+)$") or path end
local function trim(s) return (s:match("^%s*(.-)%s*$")) end

-- a contact's name, as rmail's contacts file allows
local function good_name(s) return type(s) == "string" and s:match("^[%w_%-]+$") ~= nil end
local function good_hex(s) return type(s) == "string" and #s == 64 and s:match("^%x+$") ~= nil end

-- rmail runs a hook as `<path> <args>` through the shell without quoting
-- the path, and expands glob characters in attach: lines; a folder this
-- glue names to rmail has to survive both.
local function plain_path(p) return p:match("^[%w/._%-+,@]+$") ~= nil end

-- rmail's parse_config_file: key = value, # comments, quotes kept.
local function parse_config(text)
    local cfg = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = trim(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local key, value = line:match("^(%S+)%s*=%s*(.+)$")
            if key and value then cfg[key] = value:match("^(.-)%s*$") end
        end
    end
    return cfg
end

-- rmail's hook path rule: "" (or quotes) is off, ~ is home, and a relative
-- path is from the folder holding the config.
local function hook_path(v, config_dir)
    if v == nil or v == "" or v == '""' or v == "''" then return nil end
    v = v:gsub("^~", os.getenv("HOME") or "/tmp")
    if v:sub(1, 1) == "/" then return v end
    return config_dir .. "/" .. v:gsub("^%./", "")
end

-- The contacts rmail knows, and which are listen-only (its contactfile:
-- `name.listen = true`).
local function read_contacts(path)
    local known, listens = {}, {}
    for line in ((read(path) or "") .. "\n"):gmatch("([^\n]*)\n") do
        line = trim(line)
        if line ~= "" and not line:match("^[/#]") then
            local name, field, value = line:match("^([%w_%-]+)%.([%w_%-]+)%[?%d*%]?%s*=%s*(.+)$")
            if name then
                known[name] = true
                value = trim(value)
                value = value:match('^"(.*)"$') or value
                if field == "listen" and value == "true" then listens[name] = true end
            end
        end
    end
    return known, listens
end
-- }}}

-- {{{ function hook.subject / hook.encode / hook.decode
-- The subject of a share message, as rmail delivers it (no spaces: rmail
-- turns a subject into a file name, and spaces into dashes).
function hook.subject(msg)
    return hook.SUBJECT .. "-" .. msg.kind .. "-" .. msg.id
end

-- A share message (share/exchange.lua) as a mail, and back.
function hook.encode(msg)
    local mail = { subject = hook.subject(msg), body = "", attachments = {} }
    if msg.kind == "list" then
        mail.body = msg.text
        if msg.map then
            mail.attachments[1] = { name = msg.map.name, path = msg.map.path }
            mail.body = "map: " .. msg.map.name .. "\n" .. msg.text
        end
    elseif msg.kind == "want" then
        mail.body = table.concat(msg.hashes, "\n") .. "\n"
    elseif msg.kind == "files" then
        local names = {}
        for _, f in ipairs(msg.files) do
            mail.attachments[#mail.attachments + 1] = { name = f.name, path = f.path }
            names[#names + 1] = f.name
        end
        mail.body = table.concat(names, "\n") .. "\n"
    else
        error("rmail hook: no mail for a " .. tostring(msg.kind) .. " message", 2)
    end
    return mail
end

local PREFIX = hook.SUBJECT:gsub("%p", "%%%0")

-- Whether SUBJECT claims to be a share mail (well formed or not).
function hook.is_ours(subject)
    return type(subject) == "string" and subject:match("^" .. PREFIX .. "[%- ]") ~= nil
end

-- A mail as a share message, or nil when it isn't one (or is malformed).
-- Takes the subject as 609a wrote it ("wete-share list <id>") or as rmail
-- delivers it ("wete-share-list-<id>"). A files message's names come from
-- its attachments when the mail carries them (in process), else from its
-- body with no paths yet (over rmail the files come later, one by one).
function hook.decode(mail)
    if type(mail) ~= "table" or type(mail.subject) ~= "string" then return nil end
    local kind, id = mail.subject:match("^" .. PREFIX .. "[%- ](%l+)[%- ]([%w%-_.]+)$")
    if not kind or #id > 64 then return nil end
    local msg = { kind = kind, id = id, from = mail.from }
    if kind == "list" then
        if type(mail.body) ~= "string" then return nil end
        local name, rest = mail.body:match("^map: ([^\n]*)\n(.*)$")
        if name then
            if not name:match("^%x+%.?%w*$") or #name > 80 then return nil end
            msg.map = { name = name }
            for _, a in ipairs(type(mail.attachments) == "table" and mail.attachments or {}) do
                if type(a) == "table" and a.name == name then msg.map.path = a.path end
            end
        end
        msg.text = rest or mail.body
    elseif kind == "want" then
        if type(mail.body) ~= "string" then return nil end
        msg.hashes = {}
        for line in mail.body:gmatch("[^\n]+") do
            if not line:match("^sha256:%x+$") or #line ~= 71 then return nil end
            msg.hashes[#msg.hashes + 1] = line
        end
    elseif kind == "files" then
        msg.files = {}
        if type(mail.attachments) == "table" and #mail.attachments > 0 then
            for _, a in ipairs(mail.attachments) do
                if type(a) == "table" then msg.files[#msg.files + 1] = { name = a.name, path = a.path } end
            end
        elseif type(mail.body) == "string" then
            for line in mail.body:gmatch("[^\n]+") do
                if not good_hex(line) or #msg.files >= hook.MAX_FILES then return nil end
                msg.files[#msg.files + 1] = { name = line:lower() }
            end
        end
    else
        return nil
    end
    return msg
end
-- }}}

-- {{{ function hook.transport / hook.on_receive (in process)
-- A transport for exchange.new that sends through RMAIL (its send).
function hook.transport(rmail)
    assert(rmail and type(rmail.send) == "function", "rmail hook: needs rmail's send")
    return {
        send = function(to, msg)
            local mail = hook.encode(msg)
            mail.to = to
            rmail.send(mail)
        end,
    }
end

-- An on_receive(mail) for exchange X, for a mail program that calls Lua:
-- "accept" for a share message X took, "decline" for one X refused, nil
-- for mail that isn't a share message. (rmail can't use this: its hooks
-- are programs. See hook.connect.)
function hook.on_receive(X)
    return function(mail)
        local msg = hook.decode(mail)
        if not msg then
            if type(mail) == "table" and hook.is_ours(mail.subject) then
                return "decline"     -- ours, but malformed
            end
            return nil
        end
        local result = X:on_message(msg)
        if result == nil then return "decline" end
        return "accept"
    end
end
-- }}}

-- {{{ The hook scripts
-- Each records one event as a file in the drop folder: four lines (the
-- event, then rmail's three arguments). A value with a newline in it makes
-- more lines than that, and poll drops the record. The record is written
-- under a dot name and renamed, so poll never reads half of one. When a
-- chained hook is given (the one the person had before), it runs after,
-- with the same arguments, the way rmail would have run it.
local RECEIVE_SCRIPT = [[#!/bin/sh
# rmail on_receive hook for world-edit-to-execute's shared lists (issue 609b).
# Written by share/rmail_hook.lua (C:install). It notes each share mail for
# the editor or launcher (C:poll); it reads and answers nothing itself.
drop=%s
chain=%s
case "$2" in
    "wete-share-"*|"wete-share "*)
        rec="$(date +%%s)-$$-receive"
        if printf 'receive\n%%s\n%%s\n%%s\n' "$1" "$2" "$3" > "$drop/.$rec"; then
            mv "$drop/.$rec" "$drop/$rec"
        fi
        ;;
esac
if [ -n "$chain" ]; then exec sh -c "$chain \"\$@\"" sh "$@"; fi
exit 0
]]

local PACKAGE_SCRIPT = [[#!/bin/sh
# rmail on_package hook for world-edit-to-execute's shared lists (issue 609b).
# Written by share/rmail_hook.lua (C:install). It notes each arriving file whose
# name starts with a hash's 64 hex digits, for the editor or launcher (C:poll).
drop=%s
chain=%s
if printf '%%s' "$2" | grep -Eq '^[0-9A-Fa-f]{64}'; then
    rec="$(date +%%s)-$$-package"
    if printf 'package\n%%s\n%%s\n%%s\n' "$1" "$2" "$3" > "$drop/.$rec"; then
        mv "$drop/.$rec" "$drop/$rec"
    fi
fi
if [ -n "$chain" ]; then exec sh -c "$chain \"\$@\"" sh "$@"; fi
exit 0
]]
-- }}}

local C = {}
C.__index = C

-- {{{ function hook.connect
-- The real rmail. opts: config (the mailbox's rmail config file, the one
-- rmail is started with; the folder holding it is the mailbox), data (this
-- player's data folder). Gives a connection, or nil and why. Connecting
-- changes nothing of rmail's: the person names the hooks in its config
-- (C:install gives the lines).
function hook.connect(opts)
    if type(opts) ~= "table" or type(opts.config) ~= "string" or type(opts.data) ~= "string" then
        return nil, "rmail hook: connect needs { config = <rmail config file>, data = <player data folder> }"
    end
    local config = opts.config:gsub("^~", os.getenv("HOME") or "/tmp")
    local text = read(config)
    if not text or is_dir(config) then return nil, "no rmail config at " .. config end
    if not plain_path(opts.data) then
        return nil, "rmail runs hooks and reads attach: lines unquoted, so the data folder's path can't have "
            .. "spaces or shell characters in it: " .. opts.data
    end
    local mail = dirname(config):gsub("(.)/+$", "%1")
    local cfg = parse_config(text)
    local c = setmetatable({
        config = config,
        config_dir = mail,
        cfg = cfg,
        inbox = mail .. "/inbox",
        outbox = mail .. "/outbox",
        contacts = mail .. "/contacts",
        attachments = (cfg.attachments or (mail .. "/attachments")):gsub("(.)/+$", "%1"),
        drop = opts.data .. "/share-mail",
        waiting = {},     -- files messages whose files are still coming: inbox name -> { id, from, names, path }
        arrived = {},     -- files that came: sender -> hex -> path
        outgoing = {},    -- messages with attachments sent: outbox name -> { id, what }
    }, C)
    if not is_dir(c.outbox) or not is_dir(c.inbox) then
        return nil, "no rmail mailbox beside " .. config .. " (no inbox/ and outbox/ there)"
    end
    run("mkdir -p " .. sh(c.drop .. "/hooks"))
    return c
end
-- }}}

-- {{{ function C:install / C:hooked
-- The two hook scripts this glue needs, written to <data>/share-mail/hooks/.
-- A hook the config already names (and that isn't ours) is chained: it
-- still runs, after ours. CHAIN ({ on_receive = path, on_package = path })
-- names others instead. Gives the lines for the person to put in rmail's
-- config; the config itself is never edited here.
function C:script_paths()
    local dir = self.drop .. "/hooks"
    return { on_receive = dir .. "/on_receive.sh", on_package = dir .. "/on_package.sh" }
end

function C:install(chain)
    chain = chain or {}
    local paths = self:script_paths()
    local lines = {}
    for _, which in ipairs({ "on_receive", "on_package" }) do
        local before = chain[which]
        if before == nil then
            before = hook_path(self.cfg[which], self.config_dir)
            if before == paths[which] then before = nil end
        end
        local text = (which == "on_receive" and RECEIVE_SCRIPT or PACKAGE_SCRIPT):format(sh(self.drop), sh(before or ""))
        assert(write(paths[which], text))
        run("chmod 755 " .. sh(paths[which]))
        lines[#lines + 1] = which .. " = " .. paths[which]
    end
    return table.concat(lines, "\n") .. "\n"
end

-- True when rmail's config names both scripts; else false and the hooks
-- that are missing. (rmail reads its config when it starts, so a changed
-- config needs rmail restarted.)
function C:hooked()
    local cfg = parse_config(read(self.config) or "")
    local paths, missing = self:script_paths(), {}
    for _, which in ipairs({ "on_receive", "on_package" }) do
        if hook_path(cfg[which], self.config_dir) ~= paths[which] then missing[#missing + 1] = which end
    end
    if #missing == 0 then return true end
    return false, missing
end
-- }}}

-- {{{ function C:transport
-- A transport for exchange.new: each message becomes one outbox file.
-- Errors, and sends nothing, for a body over hook.MAX_BODY (rmail would
-- turn it into an attachment the other side has to consent to) and for a
-- message whose outbox file is still there (rmail would send the new one
-- as an edit of the old).
function C:transport()
    return {
        send = function(to, msg)
            if not good_name(to) then error("rmail hook: no contact called " .. tostring(to), 2) end
            local mail = hook.encode(msg)
            if #mail.body > hook.MAX_BODY then
                error(("rmail hook: a %s message of %d bytes is over rmail's %d for one message"):format(
                    msg.kind, #mail.body, hook.MAX_BODY), 2)
            end
            local name = mail.subject
            local path = self.outbox .. "/" .. name
            if is_file(path) then error("rmail hook: " .. name .. " is still in the outbox", 2) end
            local head = { "to: " .. to }
            for _, a in ipairs(mail.attachments) do head[#head + 1] = "attach: " .. a.path end
            local tmp = self.outbox .. "/." .. name .. ".tmp"   -- rmail skips dot files
            assert(write(tmp, table.concat(head, "\n") .. "\n\n" .. mail.body))
            assert(os.rename(tmp, path))
            if msg.kind == "files" then self.outgoing[name] = { id = msg.id } end
            if msg.kind == "list" and msg.map then self.outgoing[name] = { id = msg.id, what = "map" } end
        end,
    }
end
-- }}}

-- {{{ Consent forms
-- A consent form: who sends, the message it's on, and the file; or nil
-- when the text isn't a form still waiting for an answer.
function hook.read_form(text)
    if type(text) ~= "string" then return nil end
    local from = text:match("^([^\n]-) wants to send you an attachment%.\n")
    local attached = text:match("\n%s*Attached to:%s*([^\n]-)%s*\n")
    local file = text:match("\n%s*File:%s*([^\n]-)%s*\n")
    local yes, no = false, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = trim(line)
        if line == "accept" then yes = true end
        if line == "deny" then no = true end
    end
    if not (from and attached and file and yes and no) then return nil end
    return { from = from, attached = attached, file = file }
end

-- Answers a form the way rmail's raccept and rdeny do: by deleting the
-- other line.
local function answer_form(path, text, yes)
    local drop = yes and "deny" or "accept"
    local out = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if trim(line) ~= drop then out[#out + 1] = line end
    end
    while out[#out] == "" do out[#out] = nil end
    write(path, table.concat(out, "\n") .. "\n")
end

-- Each pending form in the inbox, with its text, for FN(path, text, form).
function C:each_form(fn)
    for _, name in ipairs(list_dir(self.inbox)) do
        if name:sub(-#hook.FORM) == hook.FORM then
            local path = self.inbox .. "/" .. name
            local text = read(path)
            local f = hook.read_form(text)
            if f then fn(path, text, f) end
        end
    end
end

function C:deny_forms(message, from)
    self:each_form(function(path, text, f)
        if f.attached == message and f.from == from then answer_form(path, text, false) end
    end)
end
-- }}}

-- {{{ The receiver's side of poll
local function norm(p) return (p:gsub("/+", "/"):gsub("(.)/$", "%1")) end

local function inside(dir, path)
    return type(path) == "string" and norm(dirname(path)) == norm(dir) and not basename(path):match("^%.")
end

-- The records the hook scripts dropped, oldest first; each is read once.
function C:records()
    local out = {}
    for _, name in ipairs(list_dir(self.drop)) do
        if name:match("^%d+%-%d+%-%l+$") then
            local path = self.drop .. "/" .. name
            local text = read(path) or ""
            os.remove(path)
            local lines = {}
            for line in text:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
            if #lines == 4 and text:sub(-1) == "\n" then
                out[#out + 1] = { event = lines[1], from = lines[2], name = lines[3], path = lines[4] }
            end
        end
    end
    return out
end

-- One share mail. Lists and wants go to the exchange at once; a files
-- message waits here for its files.
function C:receive(X, r, events, known, listens)
    local function done(result, err, id)
        events[#events + 1] = { event = "receive", from = r.from, id = id, result = result, err = err }
    end
    if not hook.is_ours(r.name) or not inside(self.inbox, r.path) then return end
    if not good_name(r.from) or not known[r.from] or listens[r.from] then
        os.remove(r.path)
        local why = listens[r.from] and ("share mail from a listen-only contact (anyone may hold its token): " .. r.from)
            or ("share mail from someone who isn't a contact: " .. tostring(r.from))
        X:problem(nil, why)
        return done(nil, why)
    end
    local msg = hook.decode({ subject = r.name, body = read(r.path), from = r.from })
    if not msg then
        os.remove(r.path)
        local why = "a malformed share mail from " .. r.from .. ": " .. r.name
        X:problem(nil, why)
        return done(nil, why)
    end
    if msg.kind ~= "files" then
        local ok, result, err = pcall(X.on_message, X, msg)
        if not ok then result, err = X:problem(msg.id, tostring(result)) end
        if msg.kind == "list" and msg.map and result ~= nil then
            -- the map is this mail's attachment: the mail stays until the
            -- map has come or isn't wanted (C:complete)
            local hex = msg.map.name:sub(1, 64):lower()
            self.waiting[basename(r.path)] = { id = msg.id, from = r.from, names = { hex }, path = r.path,
                                               map = msg.map.name }
            return done(result, err, msg.id)
        end
        if msg.kind == "list" and msg.map then self:deny_forms(basename(r.path), r.from) end
        os.remove(r.path)
        return done(result, err, msg.id)
    end
    if not X:wants(msg.id, r.from) or #msg.files == 0 then
        msg.files = {}
        local _, err = X:on_message(msg)        -- refused, and counted
        self:deny_forms(basename(r.path), r.from)
        os.remove(r.path)
        return done(nil, err, msg.id)
    end
    local names = {}
    for _, f in ipairs(msg.files) do names[#names + 1] = f.name end
    self.waiting[basename(r.path)] = { id = msg.id, from = r.from, names = names, path = r.path }
end

-- Each pending form on a share mail this glue is waiting on: accepted
-- when the exchange asked that sender for that file, denied otherwise. A
-- list's map is accepted once the player said yes, and its form left for
-- later while they haven't answered. Forms on any other mail are the
-- person's, and are left alone.
function C:answer_forms(X, events)
    self:each_form(function(path, text, f)
        local w = self.waiting[f.attached]
        if not w or w.from ~= f.from then return end
        local yes
        if w.map then
            local want = X:wants_map(w.id, w.from)
            if want == nil then return end
            yes = want and f.file:lower() == w.map:lower()
        else
            local hex, listed = f.file:lower(), false
            for _, n in ipairs(w.names) do if n == hex then listed = true end end
            yes = listed and X:wants(w.id, w.from, hex)
        end
        answer_form(path, text, yes)
        events[#events + 1] = { event = "consent", from = f.from, id = w.id, file = f.file,
                                result = yes and "accepted" or "denied" }
    end)
end

-- A files message whose every file has come goes to the exchange (or one
-- the exchange stopped waiting for, to be refused). Then its files and the
-- message are removed: removing the message is what tells the sender's
-- rmail it was read, and a message's files are never removed with it
-- (rmail's #306).
function C:complete(X, events)
    for message, w in pairs(self.waiting) do
        local got = self.arrived[w.from] or {}
        if w.map then
            self:complete_map(X, events, message, w, got)
        else
            self:complete_files(X, events, message, w, got)
        end
    end
end

function C:complete_files(X, events, message, w, got)
    local whole = true
    for _, n in ipairs(w.names) do if not got[n] then whole = false end end
    if not whole and X:wants(w.id, w.from) then return end
    local files = {}
    for _, n in ipairs(w.names) do
        if got[n] then files[#files + 1] = { name = n, path = got[n] } end
    end
    local ok, result, err = pcall(X.on_message, X, { kind = "files", from = w.from, id = w.id, files = files })
    if not ok then result, err = X:problem(w.id, tostring(result)) end
    for _, f in ipairs(files) do
        if inside(self.attachments, f.path) then os.remove(f.path) end
        got[f.name] = nil
    end
    if not whole then self:deny_forms(message, w.from) end
    os.remove(w.path)
    self.waiting[message] = nil
    events[#events + 1] = { event = "files", from = w.from, id = w.id, result = result, err = err }
end

-- A list's map: handed to the exchange once it has come (it checks the
-- map against the list's hash), or given up when the exchange won't want
-- it (no, refused, or already held). Then the map's file and the list mail
-- are removed, as for a files message.
function C:complete_map(X, events, message, w, got)
    local hex = w.names[1]
    local want = X:wants_map(w.id, w.from)
    if want == nil or (want and not got[hex]) then return end
    local result, err
    if want then
        local ok
        ok, result, err = pcall(X.on_message, X, { kind = "map", from = w.from, id = w.id,
                                                    map = { name = w.map, path = got[hex] } })
        if not ok then result, err = X:problem(w.id, tostring(result)) end
    else
        self:deny_forms(message, w.from)
        result = "not wanted"
    end
    if got[hex] then
        if inside(self.attachments, got[hex]) then os.remove(got[hex]) end
        got[hex] = nil
    end
    os.remove(w.path)
    self.waiting[message] = nil
    events[#events + 1] = { event = "map", from = w.from, id = w.id, result = result, err = err }
end
-- }}}

-- {{{ function C:poll
-- One pass, when the editor or launcher asks for one (never on a timer):
-- share mail and arriving files go to exchange X, consent forms for files
-- X asked for are answered, and the sharer's bundles are removed once
-- rmail is done with them. Gives what happened: a list of { event, from,
-- id, result, err }.
function C:poll(X)
    local events = {}
    local known, listens = read_contacts(self.contacts)
    for _, r in ipairs(self:records()) do
        if r.event == "receive" then
            self:receive(X, r, events, known, listens)
        elseif r.event == "package" and good_name(r.from) and known[r.from] and not listens[r.from] then
            local hex = r.name:match("^(" .. ("%x"):rep(64) .. ")")
            if hex and is_file(r.path) then
                self.arrived[r.from] = self.arrived[r.from] or {}
                self.arrived[r.from][hex:lower()] = r.path
            end
        end
    end
    self:answer_forms(X, events)
    self:complete(X, events)
    -- the sharer: rmail removes an outbox file once every recipient has
    -- deleted their copy, and only then is the bundle it attached free
    for name, o in pairs(self.outgoing) do
        if not is_file(self.outbox .. "/" .. name) then
            X:sent(o.id, o.what)
            self.outgoing[name] = nil
            events[#events + 1] = { event = "sent", id = o.id, what = o.what }
        end
    end
    return events
end
-- }}}

return hook
