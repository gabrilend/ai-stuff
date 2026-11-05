-- 041-stand-in-carrier.lua - rmail's part in the rehearsal, played on one
-- machine without the network.
--
-- In plain terms: the rehearsal (043) needs living messages carried between
-- four mailboxes on kuvalu, the guide and three stand-in voices, exactly as
-- rmail would carry them, so the hooks, the turn runner and the blitter can
-- be run together. rmail itself needs LuaSocket, OpenSSL and its compiled
-- helpers, which this project does not install, so the rehearsal plays
-- rmail's part with this: the same files, the same hook calls, the same
-- rules, by reading and writing the mailbox folders directly. On the
-- owner's machine the rehearsal can run the real rmail daemons instead
-- (input/rehearsal, `carrier`). Nothing here talks to the network. (issue
-- 305)
--
-- What it does, from rmail's own code (main, and #215 for on_update):
--   - an outbox file is `to: <contact>` lines, a blank line, the body, and
--     its name is the subject; a name starting with `.` is not sent;
--   - a contact is reached by its `ip` and `port` in the sender's contacts
--     file, and only on this machine (127.x or localhost); the receiver
--     knows the sender as the contact holding the same token;
--   - the first delivery writes inbox/<subject> (`<subject>-from-<sender>`
--     when another sender's message has that name, then `-2`, `-3` ... so
--     nothing is written over) and runs on_receive in the background with
--     the sender, the subject and the inbox file;
--   - every later change of the outbox file is an edit: only the newest
--     body is carried. on_update is run and waited for, with the sender,
--     the inbox file and the new body, the body also on standard input (and
--     the argument empty over 64 KiB, as under #215). What it prints, if
--     anything, replaces the body. If it exits other than 0 the edit is
--     refused and tried again on a later round (#215);
--   - each mailbox keeps a timer per contact, as rmail does (#115): every
--     contact is due at the start, and is next due `pace` seconds (rmail:
--     30) after an exchange, give or take up to `jitter` seconds (rmail:
--     30); a contact that has just delivered to a mailbox is due at once in
--     that mailbox. A change in the outbox waits for its contact's timer.
--
--   local carrier = dofile(DIR .. "/src/041-stand-in-carrier.lua")
--   local c = carrier.new({ folders = { guide, voice1, ... }, pace = 2,
--                           event = function(e) ... end })
--   c:round()    -- carries what is due now; returns how many deliveries
--
-- `event` is given a table for every delivery or refusal: at, from, to,
-- subject, kind (new, edit, refused, unknown-contact, not-here, unknown-
-- sender), the inbox file and the body. LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")

local M = {}
M.BIG = 65536     -- over this, #215 gives on_update's body on standard input only

-- {{{ small helpers
local quote = runner.quote
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
local function write(path, text)
    local handle = assert(io.open(path, "wb"))
    handle:write(text)
    handle:close()
end
local function exists(path)
    local handle = io.open(path, "rb")
    if handle then handle:close() return true end
    return false
end
local function unquote(value)
    return value and (string.match(value, '^"(.*)"$') or value) or nil
end

-- rmail's own: a subject made a file name
function M.file_name(subject)
    if not subject or subject == "" then return "untitled" end
    local name = string.match(subject, "([^/\\]+)$") or subject
    name = string.gsub(name, "^%.+", "")
    name = string.gsub(name, "[%c/%\\%z]", "_")
    name = string.gsub(name, " ", "-")
    if name == "" then return "untitled" end
    return name
end

-- An outbox file's recipients and body, or nil.
function M.parse(text)
    local head, body = string.match(text, "^(.-)\n\n(.*)$")
    if not head then return nil end
    local to = {}
    for line in string.gmatch(head .. "\n", "([^\n]*)\n") do
        local name = string.match(line, "^to:%s*(%S+)%s*$")
        if not name then return nil end
        to[#to + 1] = name
    end
    return to, body
end

-- A hook's command, as rmail makes it from the config line: relative to the
-- mailbox folder, the mode word kept.
local function hook_command(folder, value)
    value = unquote(value)
    if not value or value == "" then return nil end
    if string.sub(value, 1, 1) == "/" then return value end
    return folder .. "/" .. string.gsub(value, "^%./", "")
end
-- }}}

-- {{{ local Carrier
local Carrier = {}
Carrier.__index = Carrier

-- The mailboxes as they are on disk now: name, folder, port, hooks, contacts.
function Carrier:read_boxes()
    local boxes, by_port = {}, {}
    for _, folder in ipairs(self.folders) do
        local config = mailboxes.read_config(folder .. "/config") or {}
        local box = { folder = folder, name = config.name, port = tonumber(config.port),
            on_receive = hook_command(folder, config.on_receive),
            on_update = hook_command(folder, config.on_update),
            contacts = mailboxes.read_contacts(folder .. "/contacts") or {} }
        boxes[#boxes + 1] = box
        if box.port then by_port[box.port] = box end
    end
    return boxes, by_port
end

-- What the receiver calls the sender: its contact holding the same token.
local function sender_name(receiver, token)
    for name, fields in pairs(receiver.contacts) do
        if token and unquote(fields.token) == token then return name end
    end
    return nil
end

local function is_here(ip)
    ip = unquote(ip)
    return ip == "localhost" or (ip ~= nil and string.match(ip, "^127%.") ~= nil)
end

-- One delivery of a message to a receiver. Returns the kind.
function Carrier:deliver(box, subject, receiver, sender, body)
    local key = box.folder .. "\0" .. subject .. "\0" .. receiver.folder
    local sent = self.delivered[key]
    if sent and sent.body == body then return nil end      -- nothing new
    local now = self.now()
    local inbox = receiver.folder .. "/inbox"
    os.execute("mkdir -p " .. quote(inbox))
    local stripped = string.gsub(body, "^[\n\r]+", "")
    if not sent then
        local name = M.file_name(subject)
        if self.inbox_from[inbox .. "/" .. name] and self.inbox_from[inbox .. "/" .. name] ~= key then
            name = M.file_name(subject .. "-from-" .. sender)
        end
        local base, n = name, 2
        while exists(inbox .. "/" .. name) do
            name = M.file_name(base .. "-" .. n)
            n = n + 1
        end
        local target = inbox .. "/" .. name
        write(target, stripped)
        self.inbox_from[target] = key
        self.delivered[key] = { body = body, at = now, target = target }
        if receiver.on_receive then
            os.execute(receiver.on_receive .. " " .. quote(sender) .. " " .. quote(subject)
                .. " " .. quote(target) .. " </dev/null >/dev/null 2>&1 &")
        end
        return "new", target
    end
    local target = sent.target
    if not exists(target) then                 -- the receiver deleted it: rmail's 404
        self.delivered[key] = { body = body, at = now, target = target, gone = true }
        return "deleted", target
    end
    local new_body = body
    if receiver.on_update then
        local argument = #body > M.BIG and "" or body
        local stdin = self.scratch .. "/.carrier-stdin"
        write(stdin, body)
        local pipe = io.popen(receiver.on_update .. " " .. quote(sender) .. " " .. quote(target)
            .. " " .. quote(argument) .. " < " .. quote(stdin) .. "; echo \"\nexit:$?\"")
        local output = pipe:read("*a")
        pipe:close()
        os.remove(stdin)
        local printed, status = string.match(output, "^(.-)\nexit:(%d+)\n$")
        if tonumber(status) ~= 0 then
            return "refused", target           -- tried again when next due (#215)
        end
        if printed and printed ~= "" then new_body = printed end
    end
    write(target, (string.gsub(new_body, "^[\n\r]+", "")))
    self.delivered[key] = { body = body, at = now, target = target }
    return "edit", target
end

-- {{{ function Carrier:round()
-- Carries everything due now. Returns how many deliveries were made.
function Carrier:round()
    local boxes, by_port = self:read_boxes()
    local count, now = 0, self.now()
    for _, box in ipairs(boxes) do
        -- the outbox: subject -> { to = set of contacts, body }
        local outbox = box.folder .. "/outbox"
        local listing = io.popen("ls -A " .. quote(outbox) .. " 2>/dev/null")
        local messages = {}
        for name in listing:lines() do
            if string.sub(name, 1, 1) ~= "." then
                local to, body = M.parse(slurp(outbox .. "/" .. name) or "")
                if to then messages[#messages + 1] = { subject = name, to = to, body = body } end
            end
        end
        listing:close()
        table.sort(messages, function(a, b) return a.subject < b.subject end)
        local timers = self.timers[box.folder] or {}
        self.timers[box.folder] = timers
        for _, message in ipairs(messages) do
            for _, contact in ipairs(message.to) do
                local fields = box.contacts[contact]
                local due = timers[contact] or now            -- every contact is due at start
                if due <= now then
                    local kind, target, receiver, sender, at
                    if not fields then
                        kind = "unknown-contact"
                    elseif not is_here(fields.ip) then
                        kind = "not-here"
                    else
                        receiver = by_port[tonumber(unquote(fields.port))]
                        sender = receiver and sender_name(receiver, unquote(fields.token))
                        if not receiver then
                            kind = "unknown-contact"
                        elseif not sender then
                            kind = "unknown-sender"
                        else
                            at = self.now()            -- when it set off, before the hook ran
                            kind, target = self:deliver(box, message.subject, receiver, sender,
                                message.body)
                        end
                    end
                    -- an unreachable contact is reported once per body
                    local report = kind
                    if receiver == nil or kind == "unknown-sender" then
                        local key = box.folder .. "\0" .. message.subject .. "\0" .. contact
                        if self.unreached[key] == kind .. "\0" .. message.body then report = nil end
                        self.unreached[key] = kind .. "\0" .. message.body
                    end
                    if kind == "new" or kind == "edit" then
                        count = count + 1
                        -- the receiver's timer for the sender is due at once
                        local theirs = self.timers[receiver.folder] or {}
                        self.timers[receiver.folder] = theirs
                        theirs[sender] = now
                    end
                    if report then
                        self.event({ at = at or self.now(), from = box.name, to = contact,
                            sender = sender, subject = message.subject, kind = report,
                            target = target, body = message.body })
                    end
                end
            end
        end
        -- every contact that was due has had its exchange: next due after the floor
        for contact in pairs(box.contacts) do
            if (timers[contact] or now) <= now then
                timers[contact] = now + self.pace + (self.jitter > 0
                    and (self.random() * 2 - 1) * self.jitter or 0)
            end
        end
    end
    return count
end
-- }}}
-- }}}

-- {{{ function M.new()
-- opts: folders (the mailbox folders it carries between), pace and jitter
-- (seconds: a contact's timer), random (0 to 1, for the jitter), now
-- (clock), event
-- (called for each delivery), scratch (a folder for its own use; the first
-- mailbox's by default).
function M.new(opts)
    return setmetatable({
        folders = opts.folders, pace = opts.pace or 0, jitter = opts.jitter or 0,
        random = opts.random or math.random, now = opts.now or runner.now, timers = {},
        event = opts.event or function() end,
        scratch = opts.scratch or opts.folders[1],
        delivered = {}, inbox_from = {}, unreached = {},
    }, Carrier)
end
-- }}}

return M
