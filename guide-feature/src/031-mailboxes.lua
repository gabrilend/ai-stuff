-- 031-mailboxes.lua - every rmail mailbox in the system, made one way.
--
-- In plain terms: guide-feature moves canvases between kuvalu and the three
-- voices through rmail mailboxes. This builds those mailboxes, each a folder
-- with rmail's `config` and `contacts` files, from one short list of
-- machines (a "mailbox set", like input/mailboxes). Every pair of linked
-- mailboxes gets its own shared secret, generated here and written into both
-- sides' `contacts` files and nowhere else. The same list format builds the
-- guide mailbox on kuvalu (issue 301), the voices' mailboxes (702) and the
-- stand-ins of the rehearsal (305). (issue 301)
--
-- A mailbox that is already there is adopted, never overwritten: its
-- secrets are kept, a line it lacks is added under a dated comment, and a
-- line it has with another value is refused, naming both values, for the
-- owner to settle.
--
--   local mailboxes = dofile(DIR .. "/src/031-mailboxes.lua")
--   local set = mailboxes.read_set(DIR .. "/input/mailboxes", "input/mailboxes")
--   local report = mailboxes.build(set, { root = DIR })   -- writes the folders
--   mailboxes.read_config(folder .. "/config")            -- rmail's way
--   mailboxes.read_contacts(folder .. "/contacts")        -- { name = { field = value } }
--
--   luajit src/031-mailboxes.lua --dir ROOT [--set FILE]   (scripts/make-mailboxes)
--
-- Starting the daemons and seeing them listen is rmail's, on the owner's
-- machine; the rehearsal (305) starts stand-ins. LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")

local M = {}

-- {{{ M.FIELDS
-- A mailbox set's lines. NAME is the mailbox's name, which is also its
-- rmail `name` and what its contacts call it.
M.FIELDS = {
    ["*.folder"]   = { type = "text" },    -- where the mailbox is made; ~ is home
    ["*.port"]     = { type = "whole" },   -- the port its daemon listens on
    ["*.ip"]       = { type = "text" },    -- an address that reaches it from anywhere
    ["*.local-ip"] = { type = "text" },    -- an address that reaches it on the home network
    ["*.hook"]     = { type = "choice", of = { "arrival", "turn", "none" } },
    ["*.project"]  = { type = "text" },    -- guide-feature on that machine, for its hook
    ["*.contacts"] = { type = "names" },   -- the mailboxes it talks to
}
M.HOOK_SCRIPTS = { arrival = "scripts/arrival-hook", turn = "scripts/turn-hook" }
-- }}}

-- {{{ small helpers
local function fail(text) error("mailboxes: " .. text, 0) end

local function home(path)
    return (string.gsub(path, "^~", os.getenv("HOME") or "~"))
end

local function exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close() end
    return handle ~= nil
end

local function slurp(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

local function quote(text) return "'" .. string.gsub(text, "'", "'\\''") .. "'" end

-- Written under a dot name and renamed, so rmail never reads half a file.
local function write(path, text, mode)
    local folder, name = string.match(path, "^(.*)/([^/]+)$")
    local part = folder .. "/." .. name .. ".part"
    local handle = assert(io.open(part, "w"))
    handle:write(text)
    handle:close()
    if mode then os.execute("chmod " .. mode .. " " .. quote(part)) end
    assert(os.rename(part, path))
end

-- A path with every symbolic link and .. resolved, for the inside-the-project
-- check; the part that does not exist yet is joined on as written.
local function real(path)
    local pipe = io.popen("realpath -m " .. quote(path) .. " 2>/dev/null")
    local out = pipe:read("*l")
    pipe:close()
    return out or path
end
-- }}}

-- {{{ function M.read_set()
-- A mailbox set file, checked: { mailboxes = { [name] = { folder, port,
-- ip, local-ip, hook, project, contacts } }, names = sorted names, links =
-- { { a, b } } }. A link is made by either side naming the other in its
-- contacts; naming each other is the same one link.
function M.read_set(path, source)
    source = source or path
    local text = slurp(path) or fail(source .. ": there is no mailbox set here")
    local values = settings.check(settings.parse(text, source), M.FIELDS, source, "mailboxes")
    local set = { mailboxes = {}, names = {}, links = {} }
    for name, value in pairs(values) do
        local box, field = string.match(name, "^(.+)%.([^%.]+)$")
        if box then
            set.mailboxes[box] = set.mailboxes[box] or { name = box }
            set.mailboxes[box][field] = value
        end
    end
    for name, box in pairs(set.mailboxes) do
        set.names[#set.names + 1] = name
        for _, field in ipairs({ "folder", "port", "hook" }) do
            if box[field] == nil then fail(source .. ": " .. name .. " has no " .. name .. "." .. field) end
        end
        if not box.ip and not box["local-ip"] then
            fail(source .. ": " .. name .. " has neither " .. name .. ".ip nor " .. name .. ".local-ip")
        end
        if box.hook ~= "none" and not box.project then
            fail(source .. ": " .. name .. " runs the " .. box.hook .. " hook, so it needs "
                .. name .. ".project (where guide-feature is on that machine)")
        end
        if box.port < 1 or box.port > 65535 then
            fail(source .. ": " .. name .. ".port is " .. box.port .. "; ports run from 1 to 65535")
        end
    end
    table.sort(set.names)
    local seen = {}
    for _, a in ipairs(set.names) do
        for _, b in ipairs(set.mailboxes[a].contacts or {}) do
            if b == a then fail(source .. ": " .. a .. " names itself as a contact") end
            if not set.mailboxes[b] then
                fail(source .. ": " .. a .. ".contacts names " .. b
                    .. ", which is not a mailbox in this set")
            end
            local key = a < b and (a .. ":" .. b) or (b .. ":" .. a)
            if not seen[key] then
                seen[key] = true
                set.links[#set.links + 1] = a < b and { a, b } or { b, a }
            end
        end
    end
    if #set.links == 0 then fail(source .. ": no mailbox names a contact, so none can talk") end
    local ports = {}
    for _, name in ipairs(set.names) do
        local box = set.mailboxes[name]
        local where = (box.ip or box["local-ip"]) .. ":" .. box.port
        if ports[where] then fail(source .. ": " .. ports[where] .. " and " .. name .. " both listen at " .. where) end
        ports[where] = name
    end
    return set
end
-- }}}

-- {{{ reading rmail's own files
-- A config the way rmail reads it: `key = value`, `#` comments, nothing
-- unquoted. Returns { key = value } and the keys in order, or nil.
function M.read_config(path)
    local text = slurp(path)
    if not text then return nil end
    local values, order = {}, {}
    for line in string.gmatch(text, "[^\n]+") do
        line = string.match(line, "^%s*(.-)%s*$")
        if line ~= "" and string.sub(line, 1, 1) ~= "#" then
            local key, value = string.match(line, "^(%S+)%s*=%s*(.+)$")
            if key then
                if values[key] == nil then order[#order + 1] = key end
                values[key] = value
            end
        end
    end
    return values, order
end

-- A contacts file: `name.field = value`, text in quotes, `//` and `#`
-- comments. Returns { name = { field = value } }, or nil.
function M.read_contacts(path)
    local text = slurp(path)
    if not text then return nil end
    local contacts = {}
    for line in string.gmatch(text, "[^\n]+") do
        line = string.match(line, "^%s*(.-)%s*$")
        if line ~= "" and string.sub(line, 1, 1) ~= "#" and string.sub(line, 1, 2) ~= "//" then
            local name, field, value = string.match(line, "^([^%.%s]+)%.(%S+)%s*=%s*(.+)$")
            if name then
                value = string.match(value, '^"(.*)"$') or value
                contacts[name] = contacts[name] or {}
                contacts[name][field] = value
            end
        end
    end
    return contacts
end
-- }}}

-- {{{ function M.secret()
-- A new shared secret: 32 random bytes from the kernel, as 64 hex digits.
function M.secret()
    local handle = assert(io.open("/dev/urandom", "rb"))
    local bytes = handle:read(32)
    handle:close()
    return (string.gsub(bytes, ".", function(c) return string.format("%02x", string.byte(c)) end))
end
-- }}}

-- {{{ local function wanted()
-- What a mailbox's config and contacts should hold, in order.
local function wanted_config(box)
    local lines = {
        { "name", box.name },
        { "port", tostring(box.port) },
        -- the router's port is the owner's to set, never rmail's (docs/network.md)
        { "auto_port_forward", "false" },
    }
    if box.hook ~= "none" then
        lines[#lines + 1] = { "on_receive", "./hooks/guide-hook receive" }
        lines[#lines + 1] = { "on_update", "./hooks/guide-hook update" }
    end
    return lines
end

local function wanted_contacts(set, box, secrets)
    local out = {}
    for _, link in ipairs(set.links) do
        local other = (link[1] == box.name and link[2]) or (link[2] == box.name and link[1])
        if other then
            local peer = set.mailboxes[other]
            local fields = {}
            if peer.ip then fields[#fields + 1] = { "ip", peer.ip } end
            if peer["local-ip"] then fields[#fields + 1] = { "local-ip", peer["local-ip"] } end
            fields[#fields + 1] = { "port", tostring(peer.port) }
            fields[#fields + 1] = { "token", secrets[box.name < other and (box.name .. ":" .. other)
                or (other .. ":" .. box.name)] }
            out[#out + 1] = { name = other, fields = fields }
        end
    end
    table.sort(out, function(x, y) return x.name < y.name end)
    return out
end
-- }}}

-- {{{ function M.build()
-- Makes or adopts every mailbox of a set. opts.root is this project (no
-- mailbox may be made inside it: the secrets must stay out of the
-- repository); opts.now names the day in added lines; opts.secret makes a
-- secret (tests). Checks everything before writing anything, so a refusal
-- leaves every folder as it was. Returns { [name] = { made = true } or
-- { adopted = true, added = { lines } } }.
function M.build(set, opts)
    opts = opts or {}
    local root = real(opts.root or DIR)
    local now = opts.now or os.date("!%Y-%m-%d")
    local make_secret = opts.secret or M.secret

    -- what is there already
    local present, folders = {}, {}
    for _, name in ipairs(set.names) do
        local box = set.mailboxes[name]
        local folder = home(box.folder)
        local resolved = real(folder)
        if resolved == root or string.sub(resolved, 1, #root + 1) == root .. "/" then
            fail(name .. "'s folder " .. folder .. " is inside this project; a mailbox holds "
                .. "secrets, which must stay out of the repository")
        end
        for other, path in pairs(folders) do
            if path == resolved then fail(name .. " and " .. other .. " share the folder " .. folder) end
        end
        folders[name] = resolved
        if exists(folder .. "/config") or exists(folder .. "/contacts") then
            present[name] = { config = M.read_config(folder .. "/config") or {},
                              contacts = M.read_contacts(folder .. "/contacts") or {} }
        end
    end

    -- each link's secret: one already on either side is kept
    local secrets = {}
    for _, link in ipairs(set.links) do
        local a, b = link[1], link[2]
        local key = a < b and (a .. ":" .. b) or (b .. ":" .. a)
        local on_a = present[a] and present[a].contacts[b] and present[a].contacts[b].token
        local on_b = present[b] and present[b].contacts[a] and present[b].contacts[a].token
        if on_a and on_b and on_a ~= on_b then
            fail(a .. " and " .. b .. " already hold different secrets for each other; "
                .. "one must be changed by hand to match the other")
        end
        secrets[key] = on_a or on_b or make_secret()
    end

    -- what each folder gets, checked against what is there
    local plans = {}
    for _, name in ipairs(set.names) do
        local box = set.mailboxes[name]
        local had = present[name]
        local config_add, contact_add = {}, {}
        for _, pair in ipairs(wanted_config(box)) do
            local value = had and had.config[pair[1]]
            if value == nil then
                config_add[#config_add + 1] = pair[1] .. " = " .. pair[2]
            elseif value ~= pair[2] then
                fail(name .. "'s config has " .. pair[1] .. " = " .. value .. "; this set wants "
                    .. pair[2] .. ". Change one of them by hand")
            end
        end
        for _, contact in ipairs(wanted_contacts(set, box, secrets)) do
            local old = had and had.contacts[contact.name] or {}
            for _, pair in ipairs(contact.fields) do
                local value = old[pair[1]]
                local text = pair[1] == "port" and pair[2] or ('"' .. pair[2] .. '"')
                if value == nil then
                    contact_add[#contact_add + 1] = contact.name .. "." .. pair[1] .. " = " .. text
                elseif value ~= pair[2] then
                    fail(name .. "'s contacts have " .. contact.name .. "." .. pair[1] .. " = "
                        .. (pair[1] == "token" and "(a secret)" or value) .. "; this set wants "
                        .. (pair[1] == "token" and "another" or pair[2]) .. ". Change one by hand")
                end
            end
        end
        plans[name] = { box = box, had = had, config = config_add, contacts = contact_add }
    end

    -- writing
    local report = {}
    for _, name in ipairs(set.names) do
        local plan = plans[name]
        local folder = home(plan.box.folder)
        os.execute("mkdir -p " .. quote(folder .. "/inbox") .. " " .. quote(folder .. "/outbox")
            .. " " .. quote(folder .. "/hooks"))
        os.execute("chmod 700 " .. quote(folder))
        local head = plan.had and ("\n# added by guide-feature's scripts/make-mailboxes on " .. now
            .. " (issue 301)\n") or ("# made by guide-feature's scripts/make-mailboxes on " .. now
            .. " (issue 301)\n")
        local function add(file, lines, mode)
            if #lines == 0 then return end
            local old = slurp(folder .. "/" .. file) or ""
            if old ~= "" and string.sub(old, -1) ~= "\n" then old = old .. "\n" end
            write(folder .. "/" .. file, old .. head .. table.concat(lines, "\n") .. "\n", mode)
        end
        add("config", plan.config, "644")
        add("contacts", plan.contacts, "600")
        if plan.box.hook ~= "none" then
            write(folder .. "/hooks/guide-hook", "#!/bin/sh\n"
                .. "# rmail runs this for on_receive and on_update; the first argument,\n"
                .. "# written in the config line, says which (issue 302, 304).\n"
                .. "exec " .. quote(plan.box.project .. "/" .. M.HOOK_SCRIPTS[plan.box.hook])
                .. ' "$@"\n', "755")
        end
        if plan.had then
            local added = {}
            for _, line in ipairs(plan.config) do added[#added + 1] = "config: " .. line end
            for _, line in ipairs(plan.contacts) do
                added[#added + 1] = "contacts: " .. string.gsub(line, '%.token = ".*"$', ".token = (a secret)")
            end
            report[name] = { adopted = true, added = added, folder = folder }
        else
            report[name] = { made = true, folder = folder }
        end
    end
    return report
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "031%-mailboxes%.lua$") then
    local root, set_path = DIR, nil
    for index = 1, #arg do
        if arg[index] == "--dir" then root = arg[index + 1] end
        if arg[index] == "--set" then set_path = arg[index + 1] end
    end
    local path = set_path or (root .. "/input/mailboxes")
    local ok, result = pcall(function()
        return M.build(M.read_set(path, set_path or "input/mailboxes"), { root = root })
    end)
    if not ok then
        io.stderr:write(tostring(result), "\n")
        os.exit(1)
    end
    local names = {}
    for name in pairs(result) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local one = result[name]
        if one.made then
            print(name .. ": made at " .. one.folder)
        elseif #one.added == 0 then
            print(name .. ": already as this set has it, at " .. one.folder)
        else
            print(name .. ": adopted at " .. one.folder .. ", adding:")
            for _, line in ipairs(one.added) do print("  " .. line) end
        end
    end
end
-- }}}

return M
