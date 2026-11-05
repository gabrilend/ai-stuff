-- 033-arrival-hook.lua - kuvalu's arrival hook: a voice's canvas, from the
-- guide mailbox into the blitter's arrivals folder.
--
-- In plain terms: rmail runs this when a voice's canvas reaches kuvalu's
-- guide mailbox, the first time (on_receive) and every time after (on_update,
-- an edit of the same living message). It does one thing, step 6 of
-- docs/datapath-round-trip.md: writes the canvas body to
-- tmp/shared-memory/arrivals/<sender>-<unix time>-<random>, under a dot name
-- first and then renamed, so the blitter never reads half a file. It prints
-- nothing, so rmail keeps the body as sent, and exits at once, because
-- on_update holds rmail up while it runs. The blitter does the checking.
-- (issue 302)
--
-- The mailbox's config tells the two calls apart with a word of its own
-- (031), never by guessing from the other arguments:
--   arrival-hook receive <sender> <subject> <inbox file>     on_receive
--   arrival-hook update  <sender> <inbox file> <new body>    on_update
-- Under rmail #215 on_update's body also comes on standard input, and the
-- argument is empty when the body is over 64 KiB; then it is read from
-- there. A message whose subject is not `canvas` is logged and left alone.
--
--   scripts/arrival-hook receive fg-sora-1 canvas ~/guide-mail/inbox/canvas
--   luajit src/033-arrival-hook.lua --dir ROOT update fg-sora-1 PATH BODY
--
-- Exit status: 0 when the body was written or left alone on purpose; 1 when
-- it could not be written or the call is not one of the two, which under
-- rmail #215 makes rmail refuse the edit and send it again later, rather
-- than lose it. One log line per call, in tmp/shared-memory/arrival-hook.log.
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local M = {}
M.SUBJECT = "canvas"

-- {{{ small helpers
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function random_part()
    local handle = io.open("/dev/urandom", "rb")
    local bytes = handle and handle:read(4) or tostring(os.time())
    if handle then handle:close() end
    return (string.gsub(bytes, ".", function(c) return string.format("%02x", string.byte(c)) end))
end
-- }}}

-- {{{ function M.subject_of()
-- The subject of an inbox file's name. rmail names a message after its
-- subject, or `<subject>-from-<sender>` when another sender's message
-- already has that name (handle_deliver), as the second and third voices'
-- `canvas` in the guide's inbox are. A name numbered -2, -3 ... is a second
-- message, not the living one, and is its own subject.
function M.subject_of(name, sender)
    if name == M.SUBJECT .. "-from-" .. tostring(sender) then return M.SUBJECT end
    return name
end
-- }}}

-- {{{ function M.arrive()
-- One call. `args` are the arguments after --dir; `stdin` a function giving
-- standard input (read only when the body is not in the arguments).
-- Returns the exit status and the log line.
function M.arrive(root, args, stdin, now)
    local kind, sender, subject, body = args[1], args[2], nil, nil
    if kind == "receive" and #args == 4 then
        subject = args[3]
        body = slurp(args[4])
        if not body then
            return 1, string.format("%s receive: the inbox file %s cannot be read", tostring(sender), args[4])
        end
    elseif kind == "update" and #args == 4 then
        subject = string.match(args[3], "([^/]+)$")
        -- rmail names a second sender's message of the same subject
        -- <subject>-from-<sender>
        subject = M.subject_of(subject, sender)
        body = args[4]
        if body == "" then body = stdin() or "" end
    else
        return 1, "not a call this hook takes (receive or update, then rmail's three "
            .. "arguments): " .. table.concat(args, " | ")
    end
    if not string.match(sender or "", "^[%w_%-]+$") then
        return 0, string.format("left alone: the sender '%s' is not a name an arrival can "
            .. "carry", tostring(sender))
    end
    if subject ~= M.SUBJECT then
        return 0, string.format("%s %s: left alone, its subject is '%s', not '%s'",
            sender, kind, tostring(subject), M.SUBJECT)
    end
    if body == "" then
        return 1, string.format("%s %s: the body is empty", sender, kind)
    end

    -- a reboot empties the RAM tiers; make sure of them before writing
    local ok, problem = pcall(function()
        local tiers = dofile(root .. "/libs/ensure-ram-tiers.lua")
        tiers.ensure(root, root)
    end)
    if not ok then
        return 1, string.format("%s %s: the RAM tiers cannot be made: %s", sender, kind,
            tostring(problem))
    end
    local folder = root .. "/tmp/shared-memory/arrivals"
    os.execute("mkdir -p '" .. string.gsub(folder, "'", "'\\''") .. "'")
    local name = string.format("%s-%d-%s", sender, now or os.time(), random_part())
    local part = folder .. "/." .. name
    local handle = io.open(part, "wb")
    if not handle then
        return 1, string.format("%s %s: cannot write in %s", sender, kind, folder)
    end
    handle:write(body)
    handle:close()
    if not os.rename(part, folder .. "/" .. name) then
        os.remove(part)
        return 1, string.format("%s %s: cannot rename into %s", sender, kind, folder)
    end
    return 0, string.format("%s %s: %d bytes -> arrivals/%s", sender, kind, #body, name)
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "033%-arrival%-hook%.lua$") then
    local root, args = DIR, {}
    local index = 1
    while index <= #arg do
        if arg[index] == "--dir" and #args == 0 then
            root = arg[index + 1]
            index = index + 2
        else
            args[#args + 1] = arg[index]
            index = index + 1
        end
    end
    local status, line = M.arrive(root, args, function() return io.read("*a") end)
    -- the log is in RAM; a log that cannot be opened is not a reason to fail
    local log = io.open(root .. "/tmp/shared-memory/arrival-hook.log", "a")
    if log then
        log:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), " ", line, "\n")
        log:close()
    end
    os.exit(status)
end
-- }}}

return M
