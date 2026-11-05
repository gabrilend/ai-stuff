--[[
Test Map: the Edited Map Played in the W Client (Issue 913)

The owner, 2026-11-04: "there should be a button to test the map that
opens the w-client." F5 and the Test Map button run, in order:

  1. save      the map being edited (the editor's own Save), and a .w3x
               of it for the converter when the map is a project
  2. convert   through W02 into a build folder (test_map.build_dir, under
               the project's tmp/): <convert...> <map.w3x> <build folder>
  3. server    the local AzerothCore started, or the one already started
               reused (editor/server_keeper.lua), waited on until it
               accepts logins; started again when the build changed
  4. launch    the W client, straight into the map (the contract below)
  5. play      waited on until it exits; then its goodbye receipt read
               and shown (editor/receipt.lua); no receipt is a crash

Nothing waits in place: start() begins a run and step() moves it on, so
the editor's window keeps drawing while the converter, the server and the
W client run. close() (the editor closing) stops the W client if it is
still open and the server the editor started. A session closes itself
when it is collected too, which is what happens when the editor's window
closes (the viewer's lua_close runs every finalizer).

Each step is logged to <log_dir>/test-map.log (tmp/shared-memory/test-map
by default) with the time; each program's output is beside it. The test
account's password is never in the log, a file or a command line.

The contract with the W client (its issue 1109; built there to this):

  w-client --test-map <folder> --receipt <file> [--camera <x>,<y>]
           [--realm <host>:<port>] [--account <name>]
  W_CLIENT_PASSWORD in its environment, never on the command line
  the receipt: editor/receipt.lua

--camera is where the editor's view was looking, in the W client's own
world: x north and y west, in yards (its src/018-maps.h; 1109: "world x
and y in yards"). The view gives WC3 world units (as the .w3x stores
positions); the converter writes where it placed the map in its
<build>/conversion-report.lua (placement.client, wowbuild/coords.lua), and
the camera is turned through that after converting (T:client_camera). A
point off the map is moved onto its edge, so there is ground under it. A
build whose report gives no placement gets no --camera (said, and
logged): the W client then starts at the map's own start, rather than at
WC3 units read as yards somewhere else. test_map.w_client is the W client's
scripts/run (or a program taking the same arguments), which adds the
client's own --maps, --client, --settings, --world and --assets and passes
these through unchanged; it runs from the client's folder (the one above
scripts/). A failure inside scripts/run before the client starts (a failed
build, no data) leaves no receipt, so it reads as a crash.

Since 2026-11-05, held to the W client as built (its 1109 step 1m,
custom-client PR #19): a run the client would refuse is stopped before
anything is saved or started (test_map.check_launch): no password (the
client needs W_CLIENT_PASSWORD in every test-map run), an account, realm
or path it wouldn't take. scripts/run named alone in the settings is
given its client's folder as its first word (it otherwise runs the
owner's default folder, wherever the script is), and the W client is
given WETE, this project's folder, unless WETE is already set: scripts/run
makes the baseline set from this project's tables found by it. The
build's stamp leaves the converter's report out, so an unchanged map
reuses the server.

Since the W02 chain was merged in (2026-11-05): the build must hold
W02c's map.lua (test_map.read_map_file), which the W client opens the map
by; a build without a good one stops before the server starts. The camera
goes by map.lua's wc3_to_wow, the W client's own rule, checked against the
report's placement.client (whose bounds it borrows); if they ever disagree,
map.lua's rule wins and the disagreement is said (test_map.camera_placement).
The stamp leaves out every report that holds a time
(test_map.STAMP_LEAVES_OUT).

The editor stops the W client only when the editor itself closes (a
killed client writes no receipt, and nobody is left to read one then);
otherwise the client is always left to close itself.

    local test_map = require("editor.test_map")
    local T = test_map.new(E, { root = ROOT, say = function(s) E:say(s) end })
    T:start()                  -- true, or nil and why
    while T:busy() do T:step() end
    T.last                     -- { outcome = "closed"|"lost-connection"|"error"|"crashed"|"refused"|"failed",
                               --   receipt = {...}, message = "..." }
    T:close()
]]

local settings_mod = require("editor.settings")
local receipt = require("editor.receipt")
local server_keeper = require("editor.server_keeper")
local coords = require("wowbuild.coords")

local test_map = {}

test_map.REPORT = "conversion-report.lua"     -- the converter's, in the build folder (wowbuild.REPORT)
test_map.REPORT_FORMAT = 1                   -- the newest report format read here
test_map.REPORT_MAX_BYTES = 32 * 1024 * 1024 -- a 64 x 64-tile map's report is well under a megabyte
test_map.REPORT_MAX_STEPS = 50 * 1000 * 1000
test_map.MAP_FILE = "map.lua"                -- W02c's, in the build folder (wowbuild.MAP_FILE): the map the W client opens
test_map.MAP_FORMAT = 1                      -- the one format the W client reads (its 073-converted-map.c)
test_map.AGREE_SCALE = 1e-12                 -- map.lua's rule and the report's placement agree within this share of the scale
test_map.AGREE_YARDS = 0.001                 -- and this many yards of x0 and y0
-- the build's files left out of its stamp: reports for people and the
-- converter's own record, which the server never reads and which hold
-- when they were written or how long that took (-path patterns from ./)
test_map.STAMP_LEAVES_OUT = {
    "./conversion-report.lua",                -- W02's report
    "./World/Maps/*/registration.lua",        -- W02c's record of the map's slot and rows (the rows reach the server through server/)
    "./server/triggers/*/natives-report.lua", -- W02e's coverage report (the shim reads war3map.lua and map-data.lua)
}

local T = {}
T.__index = T

-- {{{ helpers
local function utc() return os.date("!%Y-%m-%dT%H:%M:%SZ") end

local function absolute(p)
    if not p or p:sub(1, 1) == "/" then return p end
    local here = os.getenv("PWD") or "."
    return (here .. "/" .. p):gsub("/%./", "/")
end

local function dirname(p) return p:match("^(.*)/[^/]*$") or "." end

-- the W client's folder when `prog` is its scripts/run, else nil
function test_map.client_folder(prog)
    if type(prog) ~= "string" or not prog:find("/scripts/run$") then return nil end
    return dirname(dirname(prog))
end
-- }}}

-- {{{ test_map.new
-- opts: root, settings (a loaded table, else read from root), proc (the
-- seam for other programs), say, save (function(copy) -> path of a .w3x
-- to convert: the map saved as the editor saves it, or, for a map
-- project, a .w3x of it written at `copy`),
-- camera (function() -> x, y: where the view looks, WC3 world units), poll_every
function test_map.new(E, opts)
    opts = opts or {}
    local self = setmetatable({ E = E, opts = opts, root = opts.root or ".",
                                proc = opts.proc or require("editor.proc"),
                                say_fn = opts.say or (E and function(s) E:say(s) end) or print,
                                stage = "idle", runs = 0 }, T)
    -- the editor closing (its Lua state closed) stops what it started
    if newproxy then
        self.guard = newproxy(true)
        getmetatable(self.guard).__gc = function() self:close() end
    end
    return self
end
-- }}}

-- {{{ logging and saying
function T:log(line)
    if not self.log_dir then return end
    local f = io.open(self.log_dir .. "/test-map.log", "a")
    if f then f:write(utc(), " ", line, "\n"); f:close() end
end

function T:say(text)
    self:log(text)
    self.say_fn(text)
end

function T:finish(outcome, message, r)
    self.last = { outcome = outcome, message = message, receipt = r, run = self.runs }
    self.stage = "idle"
    self.job = nil
    self:say(message)
    return outcome
end

function T:fail(why)
    return self:finish("failed", "Test Map stopped: " .. tostring(why))
end
-- }}}

-- {{{ T:start
function T:start()
    if self:busy() then
        self:say("Test Map is already running (" .. self.stage .. ")")
        return nil, "already running"
    end
    self.runs, self.closed = self.runs + 1, false
    local s = self.opts.settings or settings_mod.load(self.root)
    self.settings = s
    local tm = s.test_map
    self.log_dir = absolute(tm.log_dir)
    self.build_dir = absolute(tm.build_dir)
    os.execute("mkdir -p " .. self.proc.quote(self.log_dir) .. " " .. self.proc.quote(self.build_dir))
    if not self.keeper or not self.keeper.running then
        self.keeper = server_keeper.new(tm.server, { proc = self.proc, log_dir = self.log_dir,
            say = function(t) self:say(t) end, poll_every = self.opts.poll_every })
    end
    self:log("---- Test Map " .. self.runs .. " (settings: " .. tostring(s.path)
        .. (s.found and "" or ", not found") .. ")")

    -- what the W client would refuse, before anything is saved or started
    local okl, bad = test_map.check_launch(tm, tm.server.host, tm.server.login_port, self.build_dir,
        self.log_dir .. "/receipt.lua")
    if not okl then self:fail(bad) return nil, bad end

    -- 1. save
    self.stage = "saving"
    local map, why
    local copy = dirname(self.build_dir) .. "/test-map.w3x"
    if self.opts.save then map, why = self.opts.save(copy)
    else
        map = copy
        local ok, w = self.E:save(map)
        if not ok then map, why = nil, w end
    end
    if not map then self:fail("couldn't save: " .. tostring(why)) return nil, why end
    self.map = absolute(map)
    self:say("Test Map: saved " .. self.map)

    -- 2. convert
    if not tm.convert or not tm.convert[1] then
        self:fail("no W02 converter in the editor's settings (test_map.convert); W02 isn't built yet")
        return nil, "no converter"
    end
    local argv = {}
    for i, a in ipairs(tm.convert) do argv[i] = a end
    argv[#argv + 1] = self.map
    argv[#argv + 1] = self.build_dir
    local status = self.log_dir .. "/convert.status"
    os.remove(status)
    local pid, err = self.proc.spawn(argv, { dir = self.root, log = self.log_dir .. "/convert.log", status = status })
    if not pid then self:fail(err) return nil, err end
    self:log("convert: " .. table.concat(argv, " "))
    self.job = { pid = pid, status = status, at = self.proc.now(), limit = tm.convert_seconds or 600 }
    self.stage = "converting"
    self:say("Test Map: converting into " .. self.build_dir)
    return true
end
-- }}}

-- {{{ test_map.check_launch: what the W client would refuse, found first
-- The W client checks every option before its window opens and refuses a
-- test-map run on any of these (its 067-test-map.c and 068-goodbye.c, W
-- client issue 1109): no password, or one of 256 bytes or more; an account
-- outside 1 to 63 bytes or holding a space or control byte; a realm that
-- isn't host:port with a port from 1 to 65535; a folder path of 600 bytes
-- or more, a receipt path of 580 or more. A value starting with "--" reads
-- there as a missing value. Each is found here, before the map is saved or
-- a server started, so F5 says what to fix instead of starting AzerothCore
-- for a client that will only write an error receipt.
-- tm: the settings' test_map; host, port: the login server; build_dir and
-- receipt_path: the folder and receipt the client will be given.
-- true, or nil and why
test_map.PASSWORD_MAX = 255     -- 067: char password[256]
test_map.ACCOUNT_MAX = 63       -- 067: char account[64]
test_map.HOST_MAX = 255         -- 067: char host[256]
test_map.FOLDER_MAX = 599       -- 067: char folder[600]
test_map.RECEIPT_MAX = 579      -- 068: a path of PATH_ROOM - 20 (580) bytes or more is refused

local function plain(v) return not v:find("[%z\1-\32\127]") end

function test_map.check_launch(tm, host, port, build_dir, receipt_path)
    local pw = tm.password
    if type(pw) ~= "string" or pw == "" then
        return nil, "the W client needs the test account's password, and none is set: put it in"
            .. " $W_CLIENT_PASSWORD (or test_map.password in the editor's settings)"
    end
    if #pw > test_map.PASSWORD_MAX then
        return nil, string.format("the test account's password is longer than the W client takes (%d bytes)",
            test_map.PASSWORD_MAX)
    end
    local acc = tm.account
    if acc ~= nil and (type(acc) ~= "string" or #acc < 1 or #acc > test_map.ACCOUNT_MAX or not plain(acc)
            or acc:sub(1, 2) == "--") then
        return nil, string.format("the test account's name %q isn't one the W client takes: 1 to %d characters,"
            .. " no spaces, not starting with --", tostring(acc), test_map.ACCOUNT_MAX)
    end
    if type(host) ~= "string" or #host < 1 or #host > test_map.HOST_MAX or not plain(host)
            or host:find(":", 1, true) or host:sub(1, 2) == "--" then
        return nil, string.format("test_map.server.host %q isn't a host the W client's --realm takes"
            .. " (a name or IPv4 address; no IPv6)", tostring(host))
    end
    if type(port) ~= "number" or port ~= math.floor(port) or port < 1 or port > 65535 then
        return nil, string.format("test_map.server.login_port %s isn't a port from 1 to 65535", tostring(port))
    end
    if #build_dir > test_map.FOLDER_MAX then
        return nil, string.format("the build folder's path is longer than the W client takes (%d bytes): %s",
            test_map.FOLDER_MAX, build_dir)
    end
    if #receipt_path > test_map.RECEIPT_MAX then
        return nil, string.format("the receipt's path is longer than the W client takes (%d bytes): %s",
            test_map.RECEIPT_MAX, receipt_path)
    end
    return true
end
-- }}}

-- {{{ test_map.read_placement: where the converter put the map
-- From <build>/conversion-report.lua, read as data (as the receipt is: an
-- empty environment, a count of instructions): its placement.client, or
-- nil and why
function test_map.read_placement(build_dir)
    local path = build_dir .. "/" .. test_map.REPORT
    local f = io.open(path, "rb")
    if not f then return nil, "the converter wrote no " .. test_map.REPORT end
    local text = f:read(test_map.REPORT_MAX_BYTES + 1) or ""
    f:close()
    if #text > test_map.REPORT_MAX_BYTES then return nil, "its " .. test_map.REPORT .. " is too big to be a report" end
    local t, why = receipt.run_data(text, path, test_map.REPORT_MAX_STEPS)
    if not t then return nil, "its " .. test_map.REPORT .. " can't be read: " .. why end
    if type(t.format) ~= "number" or t.format ~= math.floor(t.format) or t.format < 1 then
        return nil, "its " .. test_map.REPORT .. " has no format number"
    end
    if t.format > test_map.REPORT_FORMAT then
        return nil, string.format("its %s's format %d is newer than this editor reads (%d)",
            test_map.REPORT, t.format, test_map.REPORT_FORMAT)
    end
    local p = type(t.placement) == "table" and t.placement.client or nil
    if p == nil then return nil, "its " .. test_map.REPORT .. " gives no placement (placement.client)" end
    local ok, bad = coords.check_placement(p)
    if not ok then return nil, "its " .. test_map.REPORT .. ": " .. bad end
    return p
end
-- }}}

-- {{{ test_map.read_map_file: W02c's map.lua, the map the W client opens
-- The W client opens a test map by <build>/map.lua (its 1109 step 1b:
-- the map's id and folder, its start, and wc3_to_wow, the rule from WC3
-- positions to its world). Read here as data, as the report is; checked
-- only for what the editor relies on: format 1 and the rule. The table,
-- or nil, why and "missing" or "refused"
function test_map.read_map_file(build_dir)
    local path = build_dir .. "/" .. test_map.MAP_FILE
    local f = io.open(path, "rb")
    if not f then return nil, "the converter wrote no " .. test_map.MAP_FILE, "missing" end
    local text = f:read(test_map.REPORT_MAX_BYTES + 1) or ""
    f:close()
    if #text > test_map.REPORT_MAX_BYTES then return nil, "its " .. test_map.MAP_FILE .. " is too big", "refused" end
    local t, why = receipt.run_data(text, path, test_map.REPORT_MAX_STEPS)
    if not t then return nil, "its " .. test_map.MAP_FILE .. " can't be read: " .. why, "refused" end
    if t.format ~= test_map.MAP_FORMAT then
        return nil, string.format("its %s's format is %s; the W client and this editor read %d",
            test_map.MAP_FILE, tostring(t.format), test_map.MAP_FORMAT), "refused"
    end
    local r = t.wc3_to_wow
    local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
    if type(r) ~= "table" or not finite(r.scale) or r.scale <= 0 or not finite(r.x0) or not finite(r.y0) then
        return nil, "its " .. test_map.MAP_FILE .. " has no good wc3_to_wow (scale above 0, x0, y0)", "refused"
    end
    return t
end
-- }}}

-- {{{ test_map.camera_placement: the rule the camera is turned by
-- map.lua's wc3_to_wow is the rule the W client itself places the map by
-- (its start and its placements), so it is the one the camera goes by;
-- the report's placement.client gives the map's bounds (wc3_min, wc3_max:
-- map.lua has none), and its own rule, which must agree: by
-- test_map.AGREE_SCALE of the scale and test_map.AGREE_YARDS of x0 and y0.
-- When they don't, map.lua's rule wins and the disagreement is the note.
-- Returns the placement (scale, x0, y0, wc3_min, wc3_max) and a note, or
-- nil and why
function test_map.camera_placement(build_dir)
    local p, pwhy = test_map.read_placement(build_dir)
    local m, mwhy = test_map.read_map_file(build_dir)
    if not p then
        if m then return nil, pwhy .. ", so the map's bounds aren't known" end
        return nil, pwhy
    end
    if not m then return p, mwhy .. "; the report's placement.client used" end
    local r = m.wc3_to_wow
    local agree = math.abs(r.scale - p.scale) <= test_map.AGREE_SCALE * p.scale
        and math.abs(r.x0 - p.x0) <= test_map.AGREE_YARDS and math.abs(r.y0 - p.y0) <= test_map.AGREE_YARDS
    if agree then return p end
    local note = string.format("%s's wc3_to_wow (scale %.9g, x0 %.3f, y0 %.3f) and %s's placement.client"
        .. " (scale %.9g, x0 %.3f, y0 %.3f) disagree; %s's, the W client's own, used",
        test_map.MAP_FILE, r.scale, r.x0, r.y0, test_map.REPORT, p.scale, p.x0, p.y0, test_map.MAP_FILE)
    return { scale = r.scale, x0 = r.x0, y0 = r.y0, wc3_min = p.wc3_min, wc3_max = p.wc3_max }, note
end
-- }}}

-- {{{ T:client_camera: a point of the view as the W client's --camera
-- wx, wy in WC3 world units -> the W client's world x, y in yards, or nil
-- and why
function T:client_camera(wx, wy)
    local p, why = test_map.camera_placement(self.build_dir)
    if not p then return nil, why end
    if why then self:say("Test Map: " .. why) end
    local x, y, moved = coords.wc3_to_client(p, wx, wy)
    if not x then return nil, y end
    self:log(string.format("camera: the view's (%.1f, %.1f) in WC3 units is the W client's (%.2f, %.2f) in yards%s",
        wx, wy, x, y, moved and ", moved onto the map's edge" or ""))
    return x, y
end
-- }}}

-- {{{ the build's stamp: what decides whether the server starts again
-- the converter's own <build>/server-stamp when it writes one (the parts
-- the server reads), else a checksum of every file in the build but those
-- test_map.STAMP_LEAVES_OUT names
function T:stamp()
    local f = io.open(self.build_dir .. "/server-stamp", "r")
    if f then
        local s = f:read("*a")
        f:close()
        return "stamp:" .. s
    end
    local q = self.proc.quote
    -- the converter's report is left out: the server never reads it, and it
    -- holds when it was written and how long that took, so counting it
    -- would start the server again on every F5 of an unchanged map
    local leave = {}
    for _, pat in ipairs(test_map.STAMP_LEAVES_OUT) do leave[#leave + 1] = "! -path " .. q(pat) end
    local p = io.popen("cd " .. q(self.build_dir) .. " && find . -type f " .. table.concat(leave, " ")
        .. " -print0 | sort -z | xargs -0 -r cksum | cksum")
    local out = p and p:read("*a") or ""
    if p then p:close() end
    return "sum:" .. out:gsub("%s+$", "")
end
-- }}}

-- {{{ T:step
function T:step()
    local stage, p, job = self.stage, self.proc, self.job
    if stage == "idle" or stage == "saving" then return stage end
    local tm = self.settings.test_map

    if stage == "converting" then
        if p.alive(job.pid) then
            if p.now() - job.at > job.limit then
                p.stop(job.pid, 5)
                return self:fail(string.format("the converter took longer than %d s; its log: %s/convert.log",
                    job.limit, self.log_dir))
            end
            return stage
        end
        local code = p.exit_code(job.status)
        if code ~= 0 then
            return self:fail(string.format("the converter failed%s; its log: %s/convert.log",
                code and (" (code " .. code .. ")") or "", self.log_dir))
        end
        self:log("converted")
        -- the W client opens the map by its map.lua (W02c); without a good
        -- one it would only stop with an error receipt, so say it now
        local mf, mwhy = test_map.read_map_file(self.build_dir)
        if not mf then
            return self:fail(mwhy .. ": the W client opens a test map by it (W02c); its log: "
                .. self.log_dir .. "/convert.log")
        end
        local how, why = self.keeper:begin(self.build_dir, self:stamp())
        if not how then return self:fail(why) end
        if how == "reused" then self:say("Test Map: reusing the server the editor started")
        elseif how == "outside" then
            self:say("Test Map: a server the editor didn't start is on " .. self.keeper.host .. ":"
                .. self.keeper.login_port .. "; using it as it is")
        else self:say("Test Map: starting AzerothCore") end
        self.stage = "server"
        return self:step()
    end

    if stage == "server" then
        local st, why = self.keeper:step()
        if not st then return self:fail(why) end
        if st ~= "ready" then return stage end
        if self.keeper.ready_after then
            self:log(string.format("server ready after %.1f s", self.keeper.ready_after))
            self.keeper.ready_after = nil
        end
        return self:launch(tm)
    end

    if stage == "playing" then
        if p.alive(job.pid) then return stage end
        local code = p.exit_code(job.status)
        self:log("w client exited" .. (code and (" with code " .. code) or ""))
        local r, why, kind = receipt.read(self.receipt_path, self.build_dir)
        if r then return self:finish(r.reason, receipt.describe(r), r) end
        if kind == "missing" then
            -- the W client: 2 is an option it refused, 1 any other failure;
            -- scripts/run failing before the client starts leaves none too
            local what = code == 2 and "exit code 2: an option was refused" or
                (code and ("exit code " .. code) or "no exit code")
            return self:finish("crashed", string.format("Test Map: the W client crashed (%s, no receipt); its log: %s",
                what, self.log_dir .. "/w-client.log"))
        end
        return self:finish("refused", "Test Map: the W client's receipt was refused: " .. why
            .. " (" .. self.receipt_path .. ")")
    end
    return stage
end
-- }}}

-- {{{ T:launch: the W client, straight into the map
function T:launch(tm)
    local p = self.proc
    if not tm.w_client or not tm.w_client[1] then
        return self:fail("no W client in the editor's settings (test_map.w_client)")
    end
    self.receipt_path = self.log_dir .. "/receipt.lua"
    os.remove(self.receipt_path)            -- an old receipt never counts
    local argv = {}
    for i, a in ipairs(tm.w_client) do argv[i] = a end
    local function add(...) for _, a in ipairs({ ... }) do argv[#argv + 1] = a end end
    -- scripts/run takes the client's folder as its first word and otherwise
    -- runs the owner's default one (/mnt/kaun/custom-client), wherever the
    -- script itself is: named alone, it is given the folder above scripts/
    local client_dir = test_map.client_folder(tm.w_client[1])
    if #tm.w_client == 1 and client_dir then add(client_dir) end
    add("--test-map", self.build_dir, "--receipt", self.receipt_path)
    -- the view's point, turned into the W client's world (the top of this file)
    local cx, cy
    if self.opts.camera then cx, cy = self.opts.camera() end
    if cx and cy then
        local x, y = self:client_camera(cx, cy)
        if x then add("--camera", string.format("%.2f,%.2f", x, y))
        else
            self:say("Test Map: no camera for the W client (" .. y .. "); it starts at the map's own start")
        end
    end
    add("--realm", self.keeper.host .. ":" .. self.keeper.login_port)
    if tm.account then add("--account", tm.account) end
    local env = {}
    if tm.password then env.W_CLIENT_PASSWORD = tm.password end
    -- scripts/run makes the baseline set from this project's tables
    -- (src/wowbuild) and finds the project by $WETE, defaulting to the
    -- owner's checkout: the editor names itself, unless WETE is already set
    local wete = os.getenv("WETE")
    if wete == nil or wete == "" then env.WETE = absolute(self.root) end
    local status = self.log_dir .. "/w-client.status"
    os.remove(status)
    -- scripts/run runs from the client's folder (the one above scripts/)
    local prog = tm.w_client[1]
    local dir = tm.w_client_dir
        or (prog:find("/scripts/[^/]+$") and dirname(dirname(prog)))
        or (prog:find("/") and dirname(prog)) or self.root
    self:log("w client: WETE=" .. tostring(env.WETE or wete) .. " (where scripts/run finds this project)")
    -- the command line is logged: it holds no password
    self:log("w client: " .. table.concat(argv, " ") .. (tm.password and "  (password in its environment)" or ""))
    local pid, why = p.spawn(argv, { dir = dir, log = self.log_dir .. "/w-client.log", status = status, env = env })
    if not pid then return self:fail(why) end
    self.job = { pid = pid, status = status, at = p.now() }
    self.stage = "playing"
    self:say("Test Map: the W client is open on the map")
    return self.stage
end
-- }}}

-- {{{ T:busy, T:wait, T:close
function T:busy() return self.stage ~= "idle" end

-- step until the run ends or `seconds` pass (the tests and command-line
-- use; the editor's window steps once a frame instead)
function T:wait(seconds, every)
    local until_t = self.proc.now() + (seconds or 60)
    while self:busy() and self.proc.now() < until_t do
        self:step()
        if self:busy() then self.proc.sleep(every or 0.02) end
    end
    return not self:busy()
end

function T:close()
    if self.closed then return end
    self.closed = true
    if self.job and self.job.pid and self.proc.alive(self.job.pid) then
        self.proc.stop(self.job.pid, 5)
        self:log("closed while " .. self.stage .. ": stopped it")
    end
    self.job, self.stage = nil, "idle"
    if self.keeper then
        local n = self.keeper:stop()
        if n > 0 then self:log("editor closed: stopped the server it started") end
    end
end
-- }}}

return test_map
