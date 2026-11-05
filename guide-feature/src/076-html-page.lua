#!/usr/bin/env luajit
-- 076-html-page.lua - the HTML page's server side: the page, viewers, sessions.
--
-- In plain terms: a browser away from kuvalu watches the canvas through the
-- canvas server (025), over plain HTTP, so the canvas goes locked
-- (docs/network.md). This file is everything the server needs for that:
--
--   - the page itself (src/077-html-page.html), with the two copied
--     libraries put into it, so GET / is one HTML file and nothing else;
--   - the viewers file: each viewer's own key, made at random for a key in
--     the address, or from a password (PBKDF2, slowly) for a viewer who
--     signs in. It lives outside the project, beside the rmail secrets'
--     kind of place, never in the repository;
--   - sessions: each time a page opens, the server makes a fresh key for it
--     and sends it locked with the viewer's key; every canvas that page asks
--     for is locked with that session key. The server never sees a password.
--
--   local page = dofile(DIR .. "/src/076-html-page.lua")
--   page.build(root)                    -- the page's HTML
--   page.read_viewers(path)             -- name -> { kind, key, salt, rounds }
--   local s = page.sessions({ seconds = 3600, most = 64 })
--   local id, answer = s:start(viewer)  -- the text GET /session sends
--   s:find(id); page.lock_canvas(s:find(id), id, text)
--
-- As a program, it sets a viewer up (scripts/add-viewer):
--   luajit src/076-html-page.lua --dir ROOT --add-viewer NAME [--password]
--       [--address HOST]
-- A key viewer is given an address to bookmark, http://HOST:PORT/#NAME:KEY.
-- A password viewer's password is read from standard input (two lines, the
-- same twice), never from the command line. LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local crypto = dofile(DIR .. "/src/074-crypto.lua")

local M = {}

-- {{{ M.NOBLE
-- The copied library files the page needs, by the name the page asks for
-- (package/file) and where they are in libs/ (libs/noble-*.upstream).
M.NOBLE = {
    { "ciphers/aes.js", "noble-ciphers/aes.js" },
    { "ciphers/_polyval.js", "noble-ciphers/_polyval.js" },
    { "ciphers/utils.js", "noble-ciphers/utils.js" },
    { "hashes/pbkdf2.js", "noble-hashes/pbkdf2.js" },
    { "hashes/hmac.js", "noble-hashes/hmac.js" },
    { "hashes/sha2.js", "noble-hashes/sha2.js" },
    { "hashes/_md.js", "noble-hashes/_md.js" },
    { "hashes/_u64.js", "noble-hashes/_u64.js" },
    { "hashes/utils.js", "noble-hashes/utils.js" },
    { "hashes/crypto.js", "noble-hashes/crypto.js" },
}
-- }}}

-- {{{ M.NAME
-- What a viewer's name may hold: the canvas's own name characters.
M.NAME = "^[%w%._%-]+$"
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local handle = io.open(path, "r")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end
-- }}}

-- {{{ function M.build()
-- The page: 077 with each library file in a function of its own (the
-- CommonJS shape they are written in: `exports`, and `require` of a
-- sibling), and a small require that runs each once. Their source-map
-- comment lines are left out; the files are otherwise as copied.
function M.build(root)
    local template = assert(slurp(root .. "/src/077-html-page.html"),
        "html page: src/077-html-page.html cannot be read")
    local parts = { "const NOBLE = {};" }
    for _, entry in ipairs(M.NOBLE) do
        local text = slurp(root .. "/libs/" .. entry[2])
        assert(text, "html page: libs/" .. entry[2] .. " is missing (libs/noble-*.upstream)")
        text = string.gsub(text, "\n//# sourceMappingURL=[^\n]*", "")
        assert(not string.find(text, "</script", 1, true),
            "html page: libs/" .. entry[2] .. " holds </script")
        parts[#parts + 1] = "NOBLE[\"" .. entry[1] .. "\"] = function (exports, require) {\n"
            .. text .. "\n};"
    end
    parts[#parts + 1] = [[
function nobleRequire(key) {
  const entry = NOBLE[key];
  if (typeof entry !== "function") return entry;
  const exports = {};
  NOBLE[key] = exports;
  entry(exports, (name) => nobleRequire(name === "@noble/hashes/crypto" ? "hashes/crypto.js"
    : key.split("/")[0] + "/" + name.replace(/^\.\//, "")));
  return exports;
}]]
    local start, finish = string.find(template, "/*NOBLE*/", 1, true)
    assert(start, "html page: src/077-html-page.html has no /*NOBLE*/ line")
    return string.sub(template, 1, start - 1) .. table.concat(parts, "\n")
        .. string.sub(template, finish + 1)
end
-- }}}

-- {{{ the viewers file

-- {{{ function M.viewers_path()
-- The viewers file's path from its setting: `~/` is the home folder. It must
-- be outside the project, as every key file is (docs/endpoints.md).
function M.viewers_path(setting, root)
    local path = setting
    if string.sub(path, 1, 2) == "~/" then
        path = (os.getenv("HOME") or "") .. string.sub(path, 2)
    end
    if string.sub(path, 1, 1) ~= "/" then
        return nil, "viewers-file must be a full path or start with ~/; it is " .. setting
    end
    local inside = root .. "/"
    if string.sub(path, 1, #inside) == inside then
        return nil, "viewers-file " .. path .. " is inside the project; keys live outside it"
    end
    return path
end
-- }}}

-- {{{ function M.read_viewers()
-- name -> { kind = "key" | "password", key, salt, rounds }, keys and salts
-- as bytes. A missing file is no viewers. A line that is wrong is an error
-- naming it.
--   viewer: NAME key KEY                     (KEY: 64 hex digits)
--   viewer: NAME password SALT ROUNDS KEY    (SALT: 32 hex digits)
function M.read_viewers(path)
    local text = slurp(path)
    local viewers = {}
    if not text then return viewers end
    local number = 0
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        number = number + 1
        if not (string.match(line, "^%s*#") or string.match(line, "^%s*$")) then
            local name, rest = string.match(line, "^viewer: (%S+) (.+)$")
            local record
            if name and string.match(name, M.NAME) then
                local key = string.match(rest, "^key (%x+)$")
                if key and #key == 64 then
                    record = { kind = "key", key = crypto.from_hex(key) }
                end
                local salt, rounds, made = string.match(rest, "^password (%x+) (%d+) (%x+)$")
                if salt and #salt == 32 and #made == 64 and tonumber(rounds) >= 1 then
                    record = { kind = "password", salt = crypto.from_hex(salt),
                               rounds = tonumber(rounds), key = crypto.from_hex(made) }
                end
            end
            if not record then
                return nil, path .. ":" .. number .. ": a viewer line is `viewer: NAME key KEY` or "
                    .. "`viewer: NAME password SALT ROUNDS KEY` (hex)"
            end
            if viewers[name] then
                return nil, path .. ":" .. number .. ": the viewer " .. name .. " is here twice"
            end
            viewers[name] = record
        end
    end
    return viewers
end
-- }}}

-- {{{ function M.viewer_line()
-- A new viewer's line: a key made at random, or one made from a password.
function M.viewer_line(name, password, rounds)
    assert(string.match(name, M.NAME), "a viewer's name holds letters, digits, . _ - only")
    if not password then
        local key = crypto.random_bytes(32)
        return "viewer: " .. name .. " key " .. crypto.to_hex(key), key
    end
    local salt = crypto.random_bytes(16)
    local key = crypto.pbkdf2_sha256(password, salt, rounds, 32)
    return string.format("viewer: %s password %s %d %s", name, crypto.to_hex(salt), rounds,
        crypto.to_hex(key)), key
end
-- }}}
-- }}}

-- {{{ sessions

-- {{{ local Sessions
local Sessions = {}
Sessions.__index = Sessions

-- {{{ function Sessions:start()
-- A fresh session for a viewer: its id, and the text GET /session answers,
-- with the session key locked by the viewer's own key. A full table drops
-- the session used longest ago.
function Sessions:start(name, viewer)
    self:expire()
    if self.count >= self.most then
        local oldest
        for id, session in pairs(self.list) do
            if not oldest or session.used < self.list[oldest].used then oldest = id end
        end
        self.list[oldest], self.count = nil, self.count - 1
        self.dropped = self.dropped + 1
    end
    local id = crypto.to_hex(crypto.random_bytes(16))
    local key = crypto.random_bytes(32)
    self.list[id] = { key = key, viewer = name, used = self.now() }
    self.count = self.count + 1
    local answer = table.concat({
        "session: " .. id,
        "viewer: " .. name,
        "kind: " .. viewer.kind,
        "salt: " .. (viewer.salt and crypto.to_hex(viewer.salt) or "-"),
        "rounds: " .. (viewer.rounds and tostring(viewer.rounds) or "-"),
        "key: " .. crypto.to_hex(crypto.seal(viewer.key, key, "guide-feature session " .. id)),
    }, "\n") .. "\n"
    return id, answer
end
-- }}}

-- {{{ function Sessions:find()
-- The session by its id, its last use now; nil once it has ended.
function Sessions:find(id)
    self:expire()
    local session = id and self.list[id]
    if session then session.used = self.now() end
    return session
end

function Sessions:expire()
    local now = self.now()
    for id, session in pairs(self.list) do
        if now - session.used > self.seconds then
            self.list[id], self.count = nil, self.count - 1
        end
    end
end
-- }}}
-- }}}

-- {{{ function M.sessions()
-- opts: seconds (a session unused this long ends), most (how many at once),
-- now (a clock; socket.gettime by default).
function M.sessions(opts)
    return setmetatable({ list = {}, count = 0, dropped = 0, seconds = opts.seconds,
        most = opts.most, now = opts.now or require("socket").gettime }, Sessions)
end
-- }}}

-- {{{ function M.lock_canvas()
-- The canvas text as sent in a session: hex of nonce, ciphertext, tag, and
-- a newline. Bound to the session's id, so it unlocks in that session only.
function M.lock_canvas(session, id, text)
    return crypto.to_hex(crypto.seal(session.key, text, "guide-feature canvas " .. id)) .. "\n"
end
-- }}}
-- }}}

-- {{{ function M.add_viewer()
-- Appends a viewer to the viewers file, which is made readable by its owner
-- only. Returns the line's key (for the address), or nil and why not.
function M.add_viewer(path, name, password, rounds)
    if not string.match(name, M.NAME) then
        return nil, "a viewer's name holds letters, digits, . _ - only: " .. name
    end
    local viewers, problem = M.read_viewers(path)
    if not viewers then return nil, problem end
    if viewers[name] then return nil, "there is already a viewer called " .. name end
    local line, key = M.viewer_line(name, password, rounds)
    local folder = string.match(path, "^(.*)/[^/]*$")
    os.execute("mkdir -p '" .. folder .. "' && touch '" .. path .. "' && chmod 600 '" .. path .. "'")
    local handle, open_problem = io.open(path, "a")
    if not handle then return nil, open_problem end
    if not slurp(path):match("^$") and not slurp(path):match("\n$") then handle:write("\n") end
    handle:write(line, "\n")
    handle:close()
    return key
end
-- }}}

-- {{{ run as a program: --add-viewer
if arg and arg[0] and string.match(arg[0], "076%-html%-page%.lua$") then
    local root, name, password_wanted, address = DIR, nil, false, "192.168.1.100"
    local index = 1
    while index <= #arg do
        local option = arg[index]
        if option == "--dir" then root, index = arg[index + 1], index + 2
        elseif option == "--add-viewer" then name, index = arg[index + 1], index + 2
        elseif option == "--password" then password_wanted, index = true, index + 1
        elseif option == "--address" then address, index = arg[index + 1], index + 2
        else
            io.stderr:write("add-viewer: unknown option ", tostring(option), "\n")
            os.exit(2)
        end
    end
    if not name then
        io.stderr:write("usage: 076-html-page.lua --dir ROOT --add-viewer NAME [--password] [--address HOST]\n")
        os.exit(2)
    end
    local settings = dofile(root .. "/src/001-settings.lua")
    local server = dofile(root .. "/src/025-canvas-server.lua")
    local values = settings.read("canvas-server", server.SETTINGS, { root = root })
    local path, problem = M.viewers_path(values["viewers-file"], root)
    if not path then io.stderr:write("add-viewer: ", problem, "\n") os.exit(1) end
    local password
    if password_wanted then
        password = io.read("*l")
        local again = io.read("*l")
        if not password or password == "" or password ~= again then
            io.stderr:write("add-viewer: the two passwords were empty or not the same; nothing added\n")
            os.exit(1)
        end
    end
    local key
    key, problem = M.add_viewer(path, name, password, values["password-rounds"])
    if not key then io.stderr:write("add-viewer: ", problem, "\n") os.exit(1) end
    if password then
        io.write("added ", name, " to ", path, ": they open http://", address, ":",
            values.port, "/ and sign in as ", name, " with that password\n")
    else
        io.write("added ", name, " to ", path, ". Their address, to bookmark once (the part after #\n",
            "never leaves their browser; keep it as private as a password):\n",
            "http://", address, ":", values.port, "/#", name, ":", crypto.to_hex(key), "\n")
    end
end
-- }}}

return M
