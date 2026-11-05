--[[
config.lua - the matchmaking server's configuration file, read and checked (issue 801g)

In plain terms: a configuration file is a Lua file that returns a table.
This reads one (with no globals: it can't run anything but plain Lua),
checks every setting, and turns it into what daemon.lua runs. Paths in
the file are taken from the file's own folder. Every problem is
reported, not only the first, each saying what to do instead.

    return {
        bind = "0.0.0.0:8080",
        max_lobbies = 1000, max_players_per_lobby = 12,
        lobby_timeout_seconds = 3600, idle_timeout_seconds = 120,
        countdown_seconds = 5,
        nat = { enabled = true, port = 3478, alt_ip = "203.0.113.2" },
        asset_mirror = { enabled = true, contact = "mirror@example.org", packs_dir = "./community-packs/" },
        log_file = "./matchmaking.log",
        state_file = "./matchmaking.state", state_interval = 2,
    }

- **`config.load(path) -> settings, problems`**: settings is nil when
  any problem is an error; `problems` lists errors and warnings, each
  `{ level = "error" | "warning", text }`.
- **`config.check(t, base) -> settings, problems`**: the same for a table.
- `settings` (what daemon.run takes): `server` (server.lua's settings),
  `nat` (`port`, `alt_ip`) or nil, `mirror` (`contact`, `packs_dir`) or
  nil, `log_file`, `state_file`, `state_interval`.
]]

local server = require("matchmaking.server")

local config = {}

config.DEFAULTS = { state_file = "matchmaking.state", state_interval = 2 }

-- Settings the issue's sample file has that this server doesn't: what to
-- do instead.
config.HINTS = {
    enable_relay = "there is no relay: a punch that fails is reported (issue 801d, decision 3)",
    enable_nat_punch = "write nat = { enabled = true, port = 3478 }",
    web_dashboard = "there is no web dashboard; `status --json` gives the numbers",
    stats_file = "the state file (state_file) holds the numbers; `status` reads it",
    log_level = "there is one level; leave it out",
    ["asset_mirror.port"] = "packs go over rmail, so the mirror has no port: give its rmail contact",
    ["asset_mirror.bandwidth_limit_mbps"] = "packs go over rmail; a limit belongs to rmail's sending",
    ["asset_mirror.packs"] = "the folder is the list: every *.pack file in packs_dir",
}

local function is_path(base, p)
    if p:sub(1, 1) == "/" or not base then return p end
    return base .. "/" .. p
end

local function folder_exists(path)
    local f = io.open(path .. "/.", "r")
    if f then f:close() return true end
    return false
end

function config.check(t, base)
    local problems = {}
    local function err(text) problems[#problems + 1] = { level = "error", text = text } end
    local function warn(text) problems[#problems + 1] = { level = "warning", text = text } end
    if type(t) ~= "table" then
        err("the file should return a table of settings")
        return nil, problems
    end
    local out = { server = {} }
    local known = { nat = true, asset_mirror = true, log_file = true, state_file = true, state_interval = true }
    for k in pairs(server.DEFAULTS) do known[k] = true end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        if not known[k] then
            local hint = config.HINTS[k]
            err(tostring(k) .. " is not a setting" .. (hint and ("; " .. hint) or ""))
        end
    end

    -- the server's own settings
    for k, default in pairs(server.DEFAULTS) do
        local v = t[k]
        if v ~= nil then
            if type(v) ~= type(default) then
                err(k .. " should be a " .. type(default) .. ", is a " .. type(v))
            elseif k == "bind" then
                local host, port = v:match("^(.+):(%d+)$")
                if not host or tonumber(port) > 65535 then err("bind should be host:port, like 0.0.0.0:8080, not " .. v)
                else out.server.bind = v end
            elseif k == "countdown_seconds" then
                if v < 0 then err("countdown_seconds can't be below 0") else out.server[k] = v end
            elseif k:find("_seconds$") and v <= 0 then
                err(k .. " should be seconds above 0, not " .. v)
            elseif not k:find("_seconds$") and (v < 1 or v ~= math.floor(v)) then
                err(k .. " should be a whole number above 0, not " .. v)
            else
                out.server[k] = v
            end
        end
    end
    if out.server.max_connections and out.server.max_connections > 1000 then
        warn("max_connections over 1000: select() handles at most 1024 sockets")
    end

    -- NAT
    if t.nat ~= nil then
        if type(t.nat) ~= "table" then err("nat should be a table, like { enabled = true, port = 3478 }")
        else
            for k in pairs(t.nat) do
                if k ~= "enabled" and k ~= "port" and k ~= "alt_ip" then err("nat." .. tostring(k) .. " is not a setting") end
            end
            if t.nat.enabled ~= nil and type(t.nat.enabled) ~= "boolean" then err("nat.enabled should be true or false") end
            if t.nat.enabled ~= false then
                local p = t.nat.port
                if type(p) ~= "number" or p < 0 or p > 65534 or p ~= math.floor(p) then
                    err("nat.port should be a port from 0 to 65534 (it takes that one and the next)")
                elseif t.nat.alt_ip ~= nil and (type(t.nat.alt_ip) ~= "string" or not t.nat.alt_ip:match("^%d+%.%d+%.%d+%.%d+$")) then
                    err("nat.alt_ip should be a second IPv4 address of this machine")
                else
                    out.nat = { port = p, alt_ip = t.nat.alt_ip }
                end
            end
        end
    end

    -- the asset mirror
    local m = t.asset_mirror
    if m ~= nil then
        if type(m) ~= "table" then err("asset_mirror should be a table, like { enabled = true, contact = ..., packs_dir = ... }")
        else
            local mk = {}
            for k in pairs(m) do mk[#mk + 1] = tostring(k) end
            table.sort(mk)
            for _, k in ipairs(mk) do
                if k ~= "enabled" and k ~= "contact" and k ~= "packs_dir" then
                    local hint = config.HINTS["asset_mirror." .. k]
                    err("asset_mirror." .. k .. " is not a setting" .. (hint and ("; " .. hint) or ""))
                end
            end
            if m.enabled ~= nil and type(m.enabled) ~= "boolean" then err("asset_mirror.enabled should be true or false") end
            if m.enabled ~= false then
                local good = true
                if type(m.contact) ~= "string" or m.contact == "" then
                    err("asset_mirror.contact should be the mirror's rmail contact") good = false
                end
                if type(m.packs_dir) ~= "string" or m.packs_dir == "" then
                    err("asset_mirror.packs_dir should be the folder of *.pack files") good = false
                elseif not folder_exists(is_path(base, m.packs_dir)) then
                    err("asset_mirror.packs_dir: no folder " .. is_path(base, m.packs_dir)) good = false
                end
                if good then out.mirror = { contact = m.contact, packs_dir = is_path(base, m.packs_dir) } end
            end
        end
    end

    -- files
    for _, k in ipairs({ "log_file", "state_file" }) do
        local v = t[k]
        if v == nil then v = config.DEFAULTS[k] end
        if v ~= nil then
            if type(v) ~= "string" or v == "" then err(k .. " should be a path")
            else out[k] = is_path(base, v) end
        end
    end
    local iv = t.state_interval
    if iv == nil then iv = config.DEFAULTS.state_interval end
    if type(iv) ~= "number" or iv <= 0 then err("state_interval should be seconds above 0") else out.state_interval = iv end

    for _, p in ipairs(problems) do
        if p.level == "error" then return nil, problems end
    end
    return out, problems
end

function config.load(path)
    local chunk, lerr = loadfile(path)
    if not chunk then
        return nil, { { level = "error", text = (lerr or ""):find("No such file") and ("no file " .. path) or tostring(lerr) } }
    end
    setfenv(chunk, {})
    local ok, t = pcall(chunk)
    if not ok then return nil, { { level = "error", text = "the file failed to run: " .. tostring(t) } } end
    local base = path:match("^(.*)/[^/]*$") or "."
    return config.check(t, base)
end

return config
