--[[
Watch by Looking: Folders Compared With Their Last Listing (Issue 606)

The watcher that works everywhere: each call to changes() lists every file
under the folders (with find, following links, as the loader's pack index
does) and compares each file's change time and size with the last listing.
assets/hotreload.lua decides how often to call it.

    local poll = require("assets.watch.poll")
    local W = poll.new({ "/path/to/pack-a", "/path/to/pack-b" })
    for _, c in ipairs(W:changes()) do
        -- c.dir: the folder as given; c.rel: the file within it; c.gone: removed
    end
    W:add(dir)   W:close()
]]

local poll = {}

-- {{{ local helpers
local function sh(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- rel -> "mtime size", for every file under DIR
local function listing(dir)
    local out = {}
    local p = io.popen("find -L " .. sh(dir) .. " -mindepth 1 -type f -printf '%T@ %s\\t%P\\n' 2>/dev/null")
    for line in p:lines() do
        local stamp, rel = line:match("^([^\t]*)\t(.*)$")
        if rel then out[rel] = stamp end
    end
    p:close()
    return out
end
-- }}}

local W = {}
W.__index = W

-- {{{ function poll.new
function poll.new(dirs)
    local self = setmetatable({ dirs = {}, seen = {}, backend = "poll" }, W)
    for _, dir in ipairs(dirs or {}) do self:add(dir) end
    return self
end
-- }}}

-- {{{ function W:add
-- Starts watching DIR; what is in it now is the starting point.
function W:add(dir)
    if self.seen[dir] then return end
    self.dirs[#self.dirs + 1] = dir
    self.seen[dir] = listing(dir)
end
-- }}}

-- {{{ function W:changes
-- What was written, added or removed since the last call, folder by
-- folder, files in name order.
function W:changes()
    local out = {}
    for _, dir in ipairs(self.dirs) do
        local old, now = self.seen[dir], listing(dir)
        local rels = {}
        for rel, stamp in pairs(now) do
            if old[rel] ~= stamp then rels[#rels + 1] = rel end
        end
        for rel in pairs(old) do
            if not now[rel] then rels[#rels + 1] = rel end
        end
        table.sort(rels)
        for _, rel in ipairs(rels) do
            out[#out + 1] = { dir = dir, rel = rel, gone = now[rel] == nil }
        end
        self.seen[dir] = now
    end
    return out
end
-- }}}

-- {{{ function W:close
function W:close()
    self.dirs, self.seen = {}, {}
end
-- }}}

return poll
