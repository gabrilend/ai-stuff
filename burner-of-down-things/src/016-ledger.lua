-- 016-ledger.lua
--
-- The case's memory: an append-only file, one line per event, each line
-- carrying the checksum of the line before it and a checksum of itself. Change
-- any character of any old line and verification names that line; replace its
-- checksum too and the next line names it. The last line's checksum — the
-- head hash — is a fingerprint of the whole history.
--
-- Line fields, tab-separated (docs/002-the-terms.md, "a ledger line"):
--   seq    integer, 1 for the first line
--   time   YYYY-MM-DD HH:MM:SS
--   kind   one of KINDS below
--   about  what it happened to: an issue id, a request file, a turn id, or -
--   text   a sentence, escaped so it stays on one line
--   prev   the previous line's hash (64 zeroes for line 1)
--   hash   SHA-256 of the six fields before it, as written, joined by tabs
--
-- Hashing the fields *as written* (escaped) means verification never has to
-- re-escape anything: it hashes the bytes on disk.

local text_tables = require("014-text-tables")
local sha_256 = require("015-sha-256")

local ledger = {}

local ZERO_HASH = string.rep("0", 64)
ledger.ZERO_HASH = ZERO_HASH

-- Every kind of event, from docs/003. A new kind is added there first, then
-- here; appending an unknown kind is refused so a typo cannot quietly start
-- a new category the center and the viewers know nothing about.
local KINDS = {
    ["case-opened"] = true, ["request-received"] = true, ["surveyed"] = true,
    ["turn-started"] = true, ["turn-ended"] = true, ["breach"] = true,
    ["outlined"] = true, ["outline-failed"] = true,
    ["described"] = true, ["describe-failed"] = true,
    ["built"] = true, ["build-failed"] = true, ["delivered"] = true,
    ["graded"] = true, ["held"] = true, ["request-done"] = true,
    ["request-failed"] = true, ["goodbye"] = true,
}
ledger.KINDS = KINDS

-- {{{ local function line_hash
local function line_hash(seq, time, kind, about, text, prev)
    return sha_256.of_string(table.concat({ seq, time, kind, about, text, prev }, "\t"))
end
-- }}}

-- {{{ local function last_line
-- Reads only the end of the file: seeks back far enough to hold the last
-- line, doubling the distance until it does. Keeps appends constant-time as
-- the ledger grows.
local function last_line(path)
    local file = io.open(path, "rb")
    if not file then
        error("ledger: cannot open " .. path)
    end
    local size = file:seek("end")
    if size == 0 then
        file:close()
        return nil
    end
    local back = 4096
    while true do
        local from = math.max(0, size - back)
        file:seek("set", from)
        local chunk = file:read("*a")
        -- Strip the final newline, then look for the one before the last line.
        local body = chunk:sub(1, -2)
        local cut = body:match(".*()\n")
        if cut then
            file:close()
            return body:sub(cut + 1)
        end
        if from == 0 then
            -- The whole file is one line.
            file:close()
            return body
        end
        back = back * 2
    end
end
-- }}}

-- {{{ local function now
local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end
-- }}}

-- {{{ local function write_line
local function write_line(path, seq, kind, about, text, prev)
    if not KINDS[kind] then
        error("ledger: unknown kind '" .. tostring(kind) .. "' (add it to docs/003 and KINDS)")
    end
    local fields = {
        tostring(seq), now(), text_tables.escape(kind),
        text_tables.escape(about or "-"), text_tables.escape(text or ""), prev,
    }
    local hash = line_hash(fields[1], fields[2], fields[3], fields[4], fields[5], fields[6])
    local file = assert(io.open(path, "ab"))
    file:write(table.concat(fields, "\t"), "\t", hash, "\n")
    file:close()
    return {
        seq = seq, time = fields[2], kind = kind, about = about or "-",
        text = text or "", prev = prev, hash = hash,
    }
end
-- }}}

-- {{{ function ledger.create
-- Only opening a case creates a ledger: the first line is written into a file
-- that must not exist yet.
function ledger.create(path, text)
    local existing = io.open(path, "rb")
    if existing then
        existing:close()
        error("ledger.create: a ledger already exists at " .. path)
    end
    return write_line(path, 1, "case-opened", "-", text, ZERO_HASH)
end
-- }}}

-- {{{ function ledger.append
function ledger.append(path, kind, about, text)
    local existing = io.open(path, "rb")
    if not existing then
        -- A missing ledger in a case folder means the case is broken; appending
        -- would start a new history with no link to the old one.
        error("ledger.append: no ledger at " .. path .. " (only opening a case creates one)")
    end
    existing:close()
    local last = last_line(path)
    if not last then
        error("ledger.append: the ledger at " .. path .. " is empty")
    end
    local fields = text_tables.split_line(last)
    local seq = tonumber(fields[1])
    local prev = fields[7]
    if not seq or not prev or #prev ~= 64 then
        error("ledger.append: the last line of " .. path .. " is not a ledger line")
    end
    return write_line(path, seq + 1, kind, about, text, prev)
end
-- }}}

-- {{{ local function parse_line
local function parse_line(line)
    local f = text_tables.split_line(line)
    if #f ~= 7 then
        return nil, #f
    end
    return {
        seq = tonumber(f[1]), time = f[2], kind = text_tables.unescape(f[3]),
        about = text_tables.unescape(f[4]), text = text_tables.unescape(f[5]),
        prev = f[6], hash = f[7], raw = f,
    }
end
-- }}}

-- {{{ function ledger.verify
-- Walks every line. Returns { ok = true, count, head } or
-- { ok = false, line = n, check = name, expected = .., found = .. }.
-- Nothing is ever repaired.
function ledger.verify(path)
    local file = io.open(path, "rb")
    if not file then
        return { ok = false, line = 0, check = "exists", expected = "a ledger", found = "no file at " .. path }
    end
    local expected_prev = ZERO_HASH
    local n = 0
    for line in file:lines() do
        n = n + 1
        local entry, field_count = parse_line(line)
        -- Each check below names one way a history can be altered.
        if not entry then
            file:close()
            return { ok = false, line = n, check = "fields", expected = "7", found = tostring(field_count) }
        end
        if entry.seq ~= n then
            file:close()
            return { ok = false, line = n, check = "seq", expected = tostring(n), found = tostring(entry.raw[1]) }
        end
        if entry.prev ~= expected_prev then
            file:close()
            return { ok = false, line = n, check = "prev", expected = expected_prev, found = entry.prev }
        end
        local f = entry.raw
        local own = line_hash(f[1], f[2], f[3], f[4], f[5], f[6])
        if own ~= entry.hash then
            file:close()
            return { ok = false, line = n, check = "hash", expected = own, found = entry.hash }
        end
        expected_prev = entry.hash
    end
    file:close()
    if n == 0 then
        return { ok = false, line = 0, check = "empty", expected = "at least one line", found = "none" }
    end
    return { ok = true, count = n, head = expected_prev }
end
-- }}}

-- {{{ function ledger.describe_failure
-- A verification failure as one sentence for a person.
function ledger.describe_failure(result)
    return string.format("ledger line %d fails the %s check: expected %s, found %s",
        result.line, result.check, result.expected, result.found)
end
-- }}}

-- {{{ function ledger.read
-- Every line as a table (seq, time, kind, about, text, prev, hash), for the
-- center and the viewers. Does not verify; callers that act on the history
-- verify first.
function ledger.read(path)
    local file = io.open(path, "rb")
    if not file then
        error("ledger.read: cannot open " .. path)
    end
    local lines = {}
    for line in file:lines() do
        local entry = parse_line(line)
        if not entry then
            file:close()
            error("ledger.read: line " .. (#lines + 1) .. " of " .. path .. " is not a ledger line")
        end
        entry.raw = nil
        lines[#lines + 1] = entry
    end
    file:close()
    return lines
end
-- }}}

-- {{{ function ledger.index
-- The questions later phases ask of a history — "has issue 101 been built?"
-- — answered from lines already read: kind -> about -> the last line of that
-- kind about that thing. `ledger.has(index, kind, about)` reads it.
function ledger.index(lines)
    local index = {}
    for _, line in ipairs(lines) do
        index[line.kind] = index[line.kind] or {}
        index[line.kind][line.about] = line
    end
    return index
end
-- }}}

-- {{{ function ledger.has
function ledger.has(index, kind, about)
    return index[kind] ~= nil and index[kind][about] ~= nil
end
-- }}}

-- {{{ function ledger.head
-- The last line's hash without reading the whole file.
function ledger.head(path)
    local last = last_line(path)
    if not last then
        return nil
    end
    return text_tables.split_line(last)[7]
end
-- }}}

return ledger
