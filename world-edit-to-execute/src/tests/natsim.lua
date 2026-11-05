--[[
natsim.lua - simulated networks with NAT routers in them, for testing nat.lua (issue 801d)

In plain terms: a pretend internet held in a table. Machines with public
addresses, and routers (NATs) with machines behind them, each router of
one of the usual kinds. Datagrams go from endpoint to endpoint at once,
through the routers' rules, and can be lost at a set rate. Nothing
touches a real socket, so every kind of NAT can be tried in one run.

- **`natsim.network(options)`**: `options.clock` (a function giving
  seconds; mapping timeouts use it), `options.loss` (0 to 1, the share
  of datagrams dropped), `options.seed` (for the losses).
- **`net:machine(ip)`**: a machine on the public side (an "open" one).
- **`net:nat(public_ip, kind, options)`**: a router; kind is "full_cone", "restricted_cone",
  "port_restricted", "symmetric" or "blocked" (drops all UDP).
  `options.mapping_timeout` (seconds, default 30) forgets a mapping
  not used outbound for that long; `options.first_port` (default 40000)
  is the first outside port it hands out (ports are not kept).
- **`router:machine(private_ip)`**: a machine behind the router.
- **`machine:udp(port)`**: an endpoint (`send`, `receive`,
  `local_address`, `close`), as nat.lua expects.
- **`net.sent`, `net.delivered`, `net.dropped`**: counts.
]]

local natsim = {}

local Net, Router, Machine, Endpoint = {}, {}, {}, {}
Net.__index, Router.__index, Machine.__index, Endpoint.__index = Net, Router, Machine, Endpoint

function natsim.network(options)
    options = options or {}
    local seed = options.seed or 1
    return setmetatable({ clock = options.clock or os.time, loss = options.loss or 0,
        public = {}, routers = {}, sent = 0, delivered = 0, dropped = 0,
        rand = function()
            seed = (seed * 1103515245 + 12345) % 2147483648
            return seed / 2147483648
        end }, Net)
end

-- {{{ machines and endpoints
local function new_machine(net, ip, router)
    return setmetatable({ net = net, ip = ip, router = router, ports = {}, next_port = 50000 }, Machine)
end

function Net:machine(ip)
    local m = new_machine(self, ip, nil)
    self.public[ip] = m
    return m
end

function Machine:udp(port)
    if not port or port == 0 then
        while self.ports[self.next_port] do self.next_port = self.next_port + 1 end
        port = self.next_port
    end
    if self.ports[port] then error("natsim: " .. self.ip .. ":" .. port .. " is taken", 0) end
    local ep = setmetatable({ machine = self, port = port, queue = {} }, Endpoint)
    self.ports[port] = ep
    return ep
end

function Endpoint:local_address() return self.machine.ip, self.port end
function Endpoint:receive()
    local d = table.remove(self.queue, 1)
    if not d then return nil end
    return d[1], d[2], d[3]
end
function Endpoint:close() self.machine.ports[self.port] = nil end
function Endpoint:send(data, ip, port)
    self.machine.net:route(self.machine, self.port, data, ip, port)
    return #data
end
-- }}}

-- {{{ routers
function Net:nat(public_ip, kind, options)
    options = options or {}
    local r = setmetatable({ net = self, ip = public_ip, kind = kind, inside = {},
        mapping_timeout = options.mapping_timeout or 30, next_port = options.first_port or 40000,
        out = {}, by_port = {} }, Router)
    self.routers[public_ip] = r
    return r
end

function Router:machine(private_ip)
    local m = new_machine(self.net, private_ip, self)
    self.inside[private_ip] = m
    return m
end

-- The outside port for a datagram from the inside endpoint to ip:port,
-- made or refreshed; nil when the router drops it.
function Router:outbound(src_ip, src_port, ip, port)
    if self.kind == "blocked" then return nil end
    local now = self.net.clock()
    local key = src_ip .. ":" .. src_port
    if self.kind == "symmetric" then key = key .. ">" .. ip .. ":" .. port end
    local m = self.out[key]
    if m and now - m.used > self.mapping_timeout then
        self.by_port[m.port] = nil
        m = nil
    end
    if not m then
        m = { port = self.next_port, src_ip = src_ip, src_port = src_port, peers = {}, hosts = {} }
        self.next_port = self.next_port + 1
        self.out[key] = m
        self.by_port[m.port] = m
    end
    m.used = now
    m.peers[ip .. ":" .. port] = true
    m.hosts[ip] = true
    return m.port
end

-- The inside endpoint a datagram from ip:port to the outside `port`
-- goes to, or nil when the router drops it.
function Router:inbound(port, ip, from_port)
    if self.kind == "blocked" then return nil end
    local m = self.by_port[port]
    if not m or self.net.clock() - m.used > self.mapping_timeout then return nil end
    if self.kind == "restricted_cone" and not m.hosts[ip] then return nil end
    if (self.kind == "port_restricted" or self.kind == "symmetric") and not m.peers[ip .. ":" .. from_port] then return nil end
    local machine = self.inside[m.src_ip]
    return machine and machine.ports[m.src_port]
end
-- }}}

-- {{{ routing
function Net:route(machine, src_port, data, ip, port)
    self.sent = self.sent + 1
    local src_ip = machine.ip
    local router = machine.router
    if router then
        -- to a machine behind the same router: straight there
        local peer = router.inside[ip]
        if peer then return self:deliver(peer.ports[port], data, src_ip, src_port) end
        local out = router:outbound(src_ip, src_port, ip, port)
        if not out then self.dropped = self.dropped + 1 return end
        src_ip, src_port = router.ip, out
    end
    if self.loss > 0 and self.rand() < self.loss then self.dropped = self.dropped + 1 return end
    local target = self.public[ip]
    if target then return self:deliver(target.ports[port], data, src_ip, src_port) end
    local r = self.routers[ip]
    if r then return self:deliver(r:inbound(port, src_ip, src_port), data, src_ip, src_port) end
    self.dropped = self.dropped + 1
end

function Net:deliver(ep, data, ip, port)
    if not ep then self.dropped = self.dropped + 1 return end
    self.delivered = self.delivered + 1
    ep.queue[#ep.queue + 1] = { data, ip, port }
end
-- }}}

return natsim
