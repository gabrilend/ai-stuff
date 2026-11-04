--[[
rmail Glue for Shared Lists (Issue 609a) - a stub against an assumed contract

rmail is Ritz's mail program, in its own repository (not attached here),
so its hook format couldn't be read while this was built. This file is
written against the contract the issue records as an ASSUMPTION about
rmail; when rmail is read, only this file should need to change.

The assumed contract (issues/completed/609a-shared-list-over-rmail-and-the-prompt.md):

  rmail -> hook   on_receive(message, rmail) for each message that arrives,
                  where message = { from = "<sender>", subject = "...",
                  body = "...", attachments = { { name = "...", path = "/..." } } }
                  and `from` is a sender rmail has authenticated
  hook -> rmail   rmail.send({ to = "...", subject = "...", body = "...",
                  attachments = { { name = "...", path = "/..." } } })
  consent         on_receive returns "accept" (take the message and its
                  attachments), "decline" (drop them), or "ask" (rmail asks
                  the person, as it would without the hook), or nil for a
                  message that isn't ours (rmail goes on as usual)

The mapping: a share message is a mail whose subject is
"wete-share <kind> <id>"; a list's body is the list file (data, never
run), a want's body is one hash a line, and files travel as attachments
named by their hash's hex.

    local hook = require("share.rmail_hook")
    local X = exchange.new({ ..., transport = hook.transport(rmail) })
    rmail_hooks.on_receive = hook.on_receive(X)

    hook.connect()   -- the real rmail: nil and why, until the glue is written
]]

local hook = {}

hook.SUBJECT = "wete-share"

-- {{{ function hook.connect
-- Finds rmail on this machine. A stub: rmail isn't attached to this
-- repository, so it always gives nil and why.
function hook.connect()
    return nil, "rmail isn't attached here: share/rmail_hook.lua is written against an assumed contract (issue 609a)"
end
-- }}}

-- {{{ function hook.encode / hook.decode
-- A share message (share/exchange.lua) as a mail, and back.
function hook.encode(msg)
    local mail = { subject = hook.SUBJECT .. " " .. msg.kind .. " " .. msg.id, body = "", attachments = {} }
    if msg.kind == "list" then
        mail.body = msg.text
    elseif msg.kind == "want" then
        mail.body = table.concat(msg.hashes, "\n") .. "\n"
    elseif msg.kind == "files" then
        for _, f in ipairs(msg.files) do mail.attachments[#mail.attachments + 1] = { name = f.name, path = f.path } end
    else
        error("rmail hook: no mail for a " .. tostring(msg.kind) .. " message", 2)
    end
    return mail
end

-- A mail as a share message, or nil when it isn't one (or is malformed).
function hook.decode(mail)
    if type(mail) ~= "table" or type(mail.subject) ~= "string" then return nil end
    local kind, id = mail.subject:match("^" .. hook.SUBJECT:gsub("%p", "%%%0") .. " (%l+) ([%w%-_.]+)$")
    if not kind then return nil end
    local msg = { kind = kind, id = id, from = mail.from }
    if kind == "list" then
        if type(mail.body) ~= "string" then return nil end
        msg.text = mail.body
    elseif kind == "want" then
        if type(mail.body) ~= "string" then return nil end
        msg.hashes = {}
        for line in mail.body:gmatch("[^\n]+") do
            if not line:match("^sha256:%x+$") or #line ~= 71 then return nil end
            msg.hashes[#msg.hashes + 1] = line
        end
    elseif kind == "files" then
        msg.files = {}
        for _, a in ipairs(type(mail.attachments) == "table" and mail.attachments or {}) do
            if type(a) == "table" then msg.files[#msg.files + 1] = { name = a.name, path = a.path } end
        end
    else
        return nil
    end
    return msg
end
-- }}}

-- {{{ function hook.transport
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
-- }}}

-- {{{ function hook.on_receive
-- rmail's on_receive for exchange X. Gives rmail its consent answer:
-- "accept" for a share message X took (a list carries no files; files are
-- only taken when X asked that sender for them), "decline" for one X
-- refused, nil for mail that isn't a share message.
function hook.on_receive(X)
    return function(mail)
        local msg = hook.decode(mail)
        if not msg then
            if type(mail) == "table" and type(mail.subject) == "string"
                and mail.subject:sub(1, #hook.SUBJECT + 1) == hook.SUBJECT .. " " then
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

return hook
